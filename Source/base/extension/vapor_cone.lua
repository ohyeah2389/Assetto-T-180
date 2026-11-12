-- Vapor cone
-- Authored by ohyeah2389

local SHADER_CACHE_KEY = 22
local SHADER = [[
    float hash(float2 p) {
        p = p - 4096 * floor(p / 4096);
        return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
    }
    float wrap(float x, float per) {
        return x - per * floor(x / per);
    }
    float vnoise(float2 p, float per) {
        float2 i = floor(p), f = frac(p);
        f = f * f * (3 - 2 * f);
        float x0 = wrap(i.x, per), x1 = wrap(i.x + 1, per);
        float y0 = wrap(i.y, per), y1 = wrap(i.y + 1, per);
        return lerp(
            lerp(hash(float2(x0, y0)), hash(float2(x1, y0)), f.x),
            lerp(hash(float2(x0, y1)), hash(float2(x1, y1)), f.x), f.y);
    }
    float4 main(PS_IN pin) {
        float along = lerp(gAlong0, gAlong1, pin.Tex.x);
        float3 posW = pin.PosC + gCameraPosition;
        float3 axis = gApex + gDir * (gLength * saturate(along));
        float3 radial = posW - axis;
        radial -= gDir * dot(radial, gDir);
        float3 radialN = radial / max(length(radial), 1e-4);
        float3 normal = gCap > 0.5 ? gDir : normalize(radialN - gDir * gSlope);

        float2 w = posW.xz * 0.25 + posW.y * float2(0.12, 0.09) + gSeed;
        float n = (vnoise(w, 32) * 0.65 + vnoise(w * 1.7 + float2(8.2, 3.4), 54) * 0.35) * 2 - 1;
        float vapor = saturate(1 + 0.7 * n) * saturate(1 - 0.95 * saturate(0.2 - n));

        float fade = (gCap > 0.5 ? 1 : smoothstep(0.0, 0.05, along)) * (1 - smoothstep(0.84, 1.0, along));
        float depth = pow(saturate(abs(dot(normal, normalize(-pin.PosC)))), 1.7);
        float sheet = depth;
        float nearFade = smoothstep(0.15, 0.7, length(pin.PosC));
        float fragRay = max(length(pin.PosC), 1e-3);
        float cosView = max(abs(dot(pin.PosC / fragRay, normalize(gCameraDirLook))), 0.05);
        float gap = (linearizeDepth(pin.GetDepth()) - fragRay * cosView) / cosView;
        float intersect = saturate(gap / gDepthFade);

        float sun = saturate(dot(normal, -gLightDirection));
        float3 color = (gAmbientColor + gLightColor * (0.4 + 0.7 * sun)) * float3(0.92, 0.95, 1);
        color *= lerp(0.9, 1.08, depth);
        color += gLightColor * pow(saturate(dot(normalize(pin.PosC), -gLightDirection)), 3) * 0.1 * depth;
        color += gWhiteRefPoint * 0.05;
        return pin.ApplyFog(float4(color, saturate(gAlpha * sheet * fade * vapor * nearFade * intersect)));
    }
]]

local defaults = {
    segments = 24,
    segmentsAlong = 4,
    machStart = 0.94,
    machHold = 1.05,
    machEnd = 1.5,
    humidityStart = 0.25,
    humidityFull = 0.85,
    alphaDry = 0.38,
    alphaWet = 0.62,
    origin = vec3(0, 0.5, 2.0),
    depthFade = 0.3
}

local function hash2(ix, iz)
    ix = ix - 4096 * math.floor(ix / 4096)
    iz = iz - 4096 * math.floor(iz / 4096)
    local s = math.sin(ix * 127.1 + iz * 311.7) * 43758.5453
    return s - math.floor(s)
end

local function worldNoise(x, z)
    local ix, iz = math.floor(x), math.floor(z)
    local fx, fz = x - ix, z - iz
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)
    local a, b = hash2(ix, iz), hash2(ix + 1, iz)
    local c, d = hash2(ix, iz + 1), hash2(ix + 1, iz + 1)
    return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz
end

local VaporCone = class("VaporCone")

function VaporCone:initialize(params)
    local cfg = {}
    for k, v in pairs(defaults) do cfg[k] = v end
    if params then
        for k, v in pairs(params) do cfg[k] = v end
    end
    self.cfg = cfg
    self.level = 0
    self.mach = 0
    self.humidity = 0
    self.coneDeg = 0
    self.pocketAlpha = 1
    self.phase = math.random() * 40
    self.time = 0
    self.bodyReady = false
    self.built = false

    self.apexLocal = vec3()
    self.apex = vec3()
    self.base = vec3()
    self.dir = vec3()
    self.up = vec3()
    self.sideA = vec3()
    self.sideB = vec3()
    self.unitAft = vec3(0, 0, -1)
    self.unitY = vec3(0, 1, 0)
    self.unitX = vec3(1, 0, 0)
    self.baseRadius = 2.62
    self.baseRadiusNow = 2.62
    self.lengthMax = 8
    self.length = 0
    self.slope = 1
    self.layers = {
        { scale = 0.86, axial = -0.05, alpha = 0.5 },
        { scale = 1, axial = 0, alpha = 1 },
        { scale = 1.16, axial = 0.07, alpha = 0.65 },
    }

    self.rings = {}
    self.rimScale = {}
    self.cos, self.sin = {}, {}
    for i = 1, cfg.segmentsAlong + 1 do
        self.rings[i] = { center = vec3(), radius = 0, t = 0 }
    end
    for j = 1, cfg.segments + 1 do
        local a = (j - 1) / cfg.segments * math.pi * 2
        self.cos[j], self.sin[j] = math.cos(a), math.sin(a)
        self.rimScale[j] = 1
    end

    self.quad = {
        p1 = vec3(), p2 = vec3(), p3 = vec3(), p4 = vec3(),
        async = true,
        cacheKey = SHADER_CACHE_KEY,
        values = {
            gApex = vec3(), gDir = vec3(),
            gLength = 1, gSlope = 1,
            gAlong0 = 0, gAlong1 = 1,
            gAlpha = 0, gCap = 0, gTime = 0, gSeed = self.phase, gDepthFade = cfg.depthFade
        },
        shader = SHADER
    }
end

function VaporCone:resolveBody()
    if self.bodyReady then return true end
    local size = car.aabbSize
    if not size or size.z < 0.5 or size.x < 0.2 then return false end

    local cfg = self.cfg
    self.apexLocal:set(cfg.origin)
    local span = math.max(size.x, size.y)
    self.baseRadius = cfg.maxRadius or math.max(span * 0.218 + 1.97, 2.62)
    self.lengthMax = cfg.maxLength or math.max(size.z * 1.6, 8)
    self.bodyReady = true
    return true
end

function VaporCone:response(mach, humidity)
    local cfg = self.cfg
    local rise = math.smoothstep(math.lerpInvSat(mach, cfg.machStart, 1))
    local fall = math.smoothstep(math.lerpInvSat(mach, cfg.machHold, cfg.machEnd))
    local wet = math.max(humidity, sim.rainIntensity or 0)
    local spread = math.smoothstep(math.lerpInvSat(wet, cfg.humidityStart, cfg.humidityFull))
    return (rise * (1 - fall)) * math.lerp(cfg.alphaDry, cfg.alphaWet, spread)
end

function VaporCone:sampleAir()
    local wind = sim.windVelocityKmh
    local velocity = car.velocity
    local vx = velocity.x - (wind and wind.x or 0) / 3.6
    local vz = velocity.z - (wind and wind.y or 0) / 3.6
    local speed = math.sqrt(vx * vx + velocity.y * velocity.y + vz * vz)
    local sound = ac.getSoundSpeedMs()
    if not sound or sound < 50 then sound = 340 end
    local mach = speed / sound
    if mach ~= mach or mach > 20 then mach = 0 end
    local humidity = ac.getAirHumidity(car.position) or 0
    return mach, humidity
end

function VaporCone:build(mach)
    if not self:resolveBody() then
        self.built = false
        return
    end

    local body = car.bodyTransform
    body:transformPointTo(self.apex, self.apexLocal)
    body:transformVectorTo(self.dir, self.unitAft)
    if #self.dir < 1e-5 then
        self.built = false
        return
    end
    self.dir:normalize()
    body:transformVectorTo(self.up, self.unitY)
    if #self.up < 1e-5 then body:transformVectorTo(self.up, self.unitX) end
    self.up:normalize()
    if math.abs(math.dot(self.dir, self.up)) > 0.97 then
        body:transformVectorTo(self.up, self.unitX)
        self.up:normalize()
    end
    self.sideA:set(math.cross(self.dir, self.up)):normalize()
    self.sideB:set(math.cross(self.dir, self.sideA))

    local cfg = self.cfg
    local px, pz = car.position.x, car.position.z
    local pocket = worldNoise(px * 0.032, pz * 0.032)
    local pocketR = worldNoise(px * 0.041 + 11, pz * 0.041 - 6)
    local flutter = worldNoise(px * 0.22, pz * 0.22)
    local sweep = math.lerpInvSat(mach, cfg.machStart, cfg.machHold)
    local halfDeg = math.lerp(43, 37, sweep) - 2.5 * math.lerpInvSat(mach, cfg.machHold, cfg.machEnd) + (flutter - 0.5) * 0.6
    halfDeg = math.max(22, math.min(64, halfDeg))
    local slope = math.tan(math.rad(halfDeg))
    local baseRadius = self.baseRadius * math.lerp(0.96, 1.04, pocketR)
    local length = baseRadius / slope
    if length > self.lengthMax then
        length = self.lengthMax
        baseRadius = slope * length
    end

    self.length = length
    self.slope = slope
    self.baseRadiusNow = baseRadius
    self.coneDeg = halfDeg
    self.pocketAlpha = math.lerp(0.9, 1.08, pocket)
    self.base:set(self.apex):addScaled(self.dir, length)

    local steps = cfg.segmentsAlong
    for i = 1, steps + 1 do
        local t = (i - 1) / steps
        local ring = self.rings[i]
        ring.t = t
        ring.radius = baseRadius * t
        ring.center:set(self.apex):addScaled(self.dir, t * length)
    end

    for j = 1, cfg.segments + 1 do
        local c, s = self.cos[j], self.sin[j]
        local ox = self.sideA.x * c + self.sideB.x * s
        local oz = self.sideA.z * c + self.sideB.z * s
        local n = worldNoise((self.base.x + ox * baseRadius) * 0.28, (self.base.z + oz * baseRadius) * 0.28) * 0.5
            + worldNoise((self.base.x + ox * baseRadius) * 0.72 + 4, (self.base.z + oz * baseRadius) * 0.72) * 0.5
        self.rimScale[j] = math.lerp(0.97, 1.03, n)
    end
    self.built = true
end

function VaporCone:update(dt)
    self.time = self.time + dt
    local mach, humidity = self:sampleAir()
    self.mach, self.humidity = mach, humidity
    local target = self:response(mach, humidity)
    self.level = math.applyLag(self.level, target, target > self.level and 0.1 or 0.32, dt)
    if self.level < 0.001 then
        self.built = false
        return
    end
    self:build(mach)
end

function VaporCone:draw()
    if not self.built or self.level < 0.001 or self.length < 1e-3 then return end
    local cfg, v = self.cfg, self.quad.values
    local dim = (sim.isFocusedOnInterior and car.index == sim.focusedCar) and 0.22 or 1
    local sideA, sideB, dir = self.sideA, self.sideB, self.dir
    v.gApex:set(self.apex)
    v.gDir:set(dir)
    v.gLength = self.length
    v.gSlope = self.slope
    v.gTime = self.time
    v.gSeed = self.phase
    v.gDepthFade = cfg.depthFade
    v.gCap = 0

    local layers = self.layers
    for L = 1, #layers do
        local layer = layers[L]
        v.gAlpha = self.level * layer.alpha * dim * self.pocketAlpha
        v.gCap = 0
        for i = 1, cfg.segmentsAlong do
            local r0, r1 = self.rings[i], self.rings[i + 1]
            v.gAlong0, v.gAlong1 = r0.t, r1.t
            for j = 1, cfg.segments do
                local c0, s0 = self.cos[j], self.sin[j]
                local c1, s1 = self.cos[j + 1], self.sin[j + 1]
                local a0 = r0.radius * self.rimScale[j] * layer.scale
                local b0 = r0.radius * self.rimScale[j + 1] * layer.scale
                local a1 = r1.radius * self.rimScale[j] * layer.scale
                local b1 = r1.radius * self.rimScale[j + 1] * layer.scale
                self.quad.p1:set(r0.center):addScaled(dir, layer.axial):addScaled(sideA, c0 * a0):addScaled(sideB, s0 * a0)
                self.quad.p2:set(r1.center):addScaled(dir, layer.axial):addScaled(sideA, c0 * a1):addScaled(sideB, s0 * a1)
                self.quad.p3:set(r1.center):addScaled(dir, layer.axial):addScaled(sideA, c1 * b1):addScaled(sideB, s1 * b1)
                self.quad.p4:set(r0.center):addScaled(dir, layer.axial):addScaled(sideA, c1 * b0):addScaled(sideB, s1 * b0)
                render.shaderedQuad(self.quad)
            end
        end

        v.gCap = 1
        local bands = { 0, 0.5, 1 }
        for b = 1, 2 do
            v.gAlong0, v.gAlong1 = bands[b], bands[b + 1]
            for j = 1, cfg.segments do
                local c0, s0 = self.cos[j], self.sin[j]
                local c1, s1 = self.cos[j + 1], self.sin[j + 1]
                local r0 = self.baseRadiusNow * self.rimScale[j] * layer.scale * bands[b]
                local r1 = self.baseRadiusNow * self.rimScale[j + 1] * layer.scale * bands[b]
                local q0 = self.baseRadiusNow * self.rimScale[j] * layer.scale * bands[b + 1]
                local q1 = self.baseRadiusNow * self.rimScale[j + 1] * layer.scale * bands[b + 1]
                self.quad.p1:set(self.base):addScaled(dir, layer.axial):addScaled(sideA, c0 * r0):addScaled(sideB, s0 * r0)
                self.quad.p2:set(self.base):addScaled(dir, layer.axial):addScaled(sideA, c0 * q0):addScaled(sideB, s0 * q0)
                self.quad.p3:set(self.base):addScaled(dir, layer.axial):addScaled(sideA, c1 * q1):addScaled(sideB, s1 * q1)
                self.quad.p4:set(self.base):addScaled(dir, layer.axial):addScaled(sideA, c1 * r1):addScaled(sideB, s1 * r1)
                render.shaderedQuad(self.quad)
            end
        end
    end
end

return VaporCone
