-- Afterburner plume
-- Authored by ohyeah2389

local SHADER_CACHE_KEY = 14
local SHADER = [[
    float3 blackbody(float T) {
        if (T < 1) return 0;
        float3 u = float3(21158, 26160, 32700) / T;
        float3 e = exp(-u);
        return e / max(1 - e, 1e-6) * float3(0.35, 1, 3.05);
    }
    float hash(float2 p) {
        return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
    }
    float wrap(float x, float per) {
        return x - per * floor(x / per);
    }
    float valueNoiseY(float2 p, float perY) {
        float2 i = floor(p), f = frac(p);
        f = f * f * (3 - 2 * f);
        float y0 = wrap(i.y, perY), y1 = wrap(i.y + 1, perY);
        return lerp(
            lerp(hash(float2(i.x, y0)), hash(float2(i.x + 1, y0)), f.x),
            lerp(hash(float2(i.x, y1)), hash(float2(i.x + 1, y1)), f.x), f.y);
    }
    float fbm(float2 p, float perY) {
        return valueNoiseY(p, perY) * 0.65 + valueNoiseY(p * 2 + float2(17.13, 0), perY * 2) * 0.35;
    }
    float4 main(PS_IN pin) {
        float3 posW = pin.PosC + gCameraPosition;
        float t = lerp(gT0, gT1, pin.Tex.x);
        float3 center, tangent;
        if (t <= gFixedT) {
            center = gP0 + gDir * (gLength * (t - gFixedT));
            tangent = gDir;
        } else {
            float u = (t - gFixedT) / max(1 - gFixedT, 1e-4);
            float flexLen = gLength * (1 - gFixedT);
            float ug = pow(saturate(u), gGamma);
            center = gP0 + gDir * (flexLen * (u - ug)) + gTargetDir * (flexLen * ug);
            float k = gGamma * pow(max(u, 1e-4), gGamma - 1);
            tangent = normalize(gDir * (1 - k) + gTargetDir * k);
        }
        float along = 1 - lerp(gAlong0, gAlong1, pin.Tex.x);
        float plumeT = lerp(gAlong0, gAlong1, pin.Tex.x);
        float3 rel = posW - center;
        float3 radial = normalize(rel - tangent * dot(rel, tangent));
        float3 refA = normalize(cross(abs(tangent.y) < 0.99 ? float3(0, 1, 0) : float3(1, 0, 0), tangent));
        float theta = atan2(dot(radial, cross(tangent, refA)), dot(radial, refA)) / 6.2831853;
        theta = theta - floor(theta);
        float perY = max(round(gNoiseFreq.y), 1);
        float mask = saturate((plumeT - gCoreT) * 8);
        float n = fbm(float2(plumeT * gNoiseFreq.x - gTime * gNoiseFlow, theta * perY + gNoiseSeed), perY) * 2 - 1;

        float3 normal = normalize(radial - tangent * (t <= gFixedT ? gSlope0 : gSlope1));

        float ndv = saturate(1 - abs(dot(normal, normalize(-pin.PosC))));
        float fresnel = (0.1 + 0.9 * pow(ndv, 1.5)) * (1 - pow(ndv, 2.5));
        float T = gTempK * gTempMul * pow(saturate(along), gFadePower) * (1 + gNoiseAmp * n * mask);
        float3 color;
        if (gColorOverride > 0.5) {
            color = gColor * (gTempMul * pow(saturate(along), gFadePower) * (1 + gNoiseAmp * n * mask));
        } else {
            float3 bb = blackbody(T);
            float3 bb0 = blackbody(gTempK);
            color = bb / max(dot(bb0, float3(0.3, 0.6, 0.1)), 1e-8);
        }
        float fade = gEdgeFade > 1e-5
            ? smoothstep(0, gEdgeFade, pin.Tex.x) * smoothstep(0, gEdgeFade, 1 - pin.Tex.x)
            : 1;
        float holes = saturate(1 - gNoiseHoles * mask * saturate(0.5 - n));
        return pin.ApplyFog(float4(color * fresnel * fade * holes * gBrightness * pin.GetEmissiveMult(), 1));
    }
]]

local defaults = {
    radiusStart = 0.0,
    radiusChoke = 0.15,
    radiusEnd = 0.1,
    rings = 8,
    segments = 12,
    chokeFixedLength = 0.3,
    diamondPeriod = 0.35,
    diamondJitterAmp = 0.0065,
    diamondJitterFreq = 10,
    diamondLength = 0.275,
    diamondFade = 0.65,
    diamondStart = 0.3,
    diamondEnd = 1.0,
    jetSpeed = 80,
    deflectGamma = 1.65,
    noiseAmp = 0.15,
    noiseHoles = 0.8,
    noiseFlow = 50,
    noiseFreqT = 2,
    noiseFreqTheta = 6,
    lightIntensity = 20,
    lightRange = 15,
    jitterAmp = 0.04,
    jitterFreq = 10,
    length = 4,
    tempK = 2500,
    brightness = 35,
    fadePower = 0.8,
    color = false
}

local function blackbody(T)
    if T < 1 then return 0, 0, 0 end
    local er, eg, eb = math.exp(-21158 / T), math.exp(-26160 / T), math.exp(-32700 / T)
    return er / math.max(1 - er, 1e-6) * 0.35,
           eg / math.max(1 - eg, 1e-6),
           eb / math.max(1 - eb, 1e-6) * 3.05
end

local AfterburnerPlume = class("AfterburnerPlume")

function AfterburnerPlume:initialize(params)
    params = params or {}
    local cfg = {}
    for k, v in pairs(defaults) do cfg[k] = v end
    for k, v in pairs(params) do cfg[k] = v end
    self.cfg = cfg
    self.source = cfg.source or "rear"
    self.level = 0
    self.time = 0

    self.from = (cfg.from or vec3(0, 0.77, -2.5)):clone()
    local dirLocal = (cfg.direction or vec3(0, 0, -1)):clone():normalize()
    self.to = cfg.to and cfg.to:clone() or self.from:clone():addScaled(dirLocal, cfg.length or 4)
    self.axis = self.to - self.from
    self.length = #self.axis
    self.dir = self.axis:clone():normalize()
    self.phase = cfg.phase or (self.from.x * 13.7 + self.from.y * 7.1)

    self.spine = {
        nozzle = vec3(), dir = vec3(), hinge = vec3(), tangent = vec3(),
        offset = vec3(), air = vec3(), targetDir = vec3(),
        up = vec3(), right = vec3(), fixedT = 0
    }
    self.rings = {}
    self.cos, self.sin = {}, {}
    for i = 1, cfg.rings + 1 do
        self.rings[i] = { center = vec3(), sideA = vec3(), sideB = vec3(), radius = 0, t = 0 }
    end
    for j = 1, cfg.segments + 1 do
        local a = (j - 1) / cfg.segments * math.pi * 2
        self.cos[j], self.sin[j] = math.cos(a), math.sin(a)
    end
    self.diamond = {
        base = vec3(), apex = vec3(), tangent = vec3(),
        sideA = vec3(), sideB = vec3(), mid = vec3()
    }
    self.quad = {
        p1 = vec3(), p2 = vec3(), p3 = vec3(), p4 = vec3(),
        async = true,
        cacheKey = SHADER_CACHE_KEY,
        values = {
            gP0 = vec3(), gP1 = vec3(), gP2 = vec3(),
            gDir = vec3(), gTargetDir = vec3(),
            gFixedT = 0, gGamma = 1, gLength = 1,
            gT0 = 0, gT1 = 1, gAlong0 = 0, gAlong1 = 1,
            gSlope0 = 0, gSlope1 = 0,
            gTempK = cfg.tempK, gTempMul = 0, gBrightness = cfg.brightness,
            gFadePower = cfg.fadePower, gEdgeFade = 0, gTime = 0,
            gTheta0 = 0, gTheta1 = 1, gCoreT = 0,
            gNoiseAmp = 0, gNoiseHoles = 0, gNoiseFlow = 0, gNoiseSeed = 0,
            gNoiseFreq = vec2(cfg.noiseFreqT, cfg.noiseFreqTheta),
            gColor = vec3(0, 0, 0),
            gColorOverride = 0
        },
        shader = SHADER
    }
    local col = cfg.color
    if col then
        self.quad.values.gColorOverride = 1
        self.quad.values.gColor:set(col.r, col.g, col.b)
    end
    self.light, self.lightLinked, self.lightTried = nil, false, false
end

function AfterburnerPlume:radiusAt(t)
    local cfg, fixedT = self.cfg, self.spine.fixedT
    if t <= fixedT then
        return math.lerp(cfg.radiusStart, cfg.radiusChoke, t / math.max(fixedT, 1e-4))
    end
    return math.lerp(cfg.radiusChoke, cfg.radiusEnd, (t - fixedT) / math.max(1 - fixedT, 1e-4))
end

function AfterburnerPlume:sampleSpine(t, outCenter, outTangent)
    local s, len = self.spine, self.length
    if t <= s.fixedT then
        outCenter:set(s.nozzle):addScaled(s.dir, t * len)
        outTangent:set(s.dir)
        return
    end
    local u = (t - s.fixedT) / math.max(1 - s.fixedT, 1e-4)
    local flexLen = len * (1 - s.fixedT)
    local g = math.max(self.cfg.deflectGamma or 1, 0.01)
    local ug = u ^ g
    outCenter:set(s.hinge):addScaled(s.dir, flexLen * (u - ug)):addScaled(s.targetDir, flexLen * ug)
    local k = g * (math.max(u, 1e-4) ^ (g - 1))
    outTangent:setScaled(s.dir, 1 - k):addScaled(s.targetDir, k):normalize()
end

function AfterburnerPlume:ensureLight()
    if self.lightTried then return end
    self.lightTried = true
    if self.cfg.light == false or (self.cfg.lightIntensity or 0) <= 0 then return end
    local ok, light = pcall(ac.LightSource, ac.LightType.Regular)
    if not ok or not light then return end
    self.light = light
    local body = ac.findNodes('BODYTR')
    if body and body:size() > 0 then
        light:linkTo(body)
        self.lightLinked = true
        light.position:set(self.from):addScaled(self.dir, 0.3)
        light.direction:set(self.dir)
    end
    light.range = self.cfg.lightRange or 12
    light.rangeGradientOffset = 0
    light.spot = 280
    light.spotSharpness = 0
    light.shadows = false
    light.volumetricLight = false
    light.skipLightMap = true
    light.showInReflections = false
    light.fadeAt = 60
    light.fadeSmooth = 30
    light.color:set(0, 0, 0)
end

function AfterburnerPlume:updateLight()
    self:ensureLight()
    if not self.light then return end
    local k = self.level
    if k < 0.002 then
        self.light.color:set(0, 0, 0)
        return
    end
    local col = self.cfg.color
    if col then
        local i = (self.cfg.lightIntensity or 5) * k
        self.light.color:set(col.r * i, col.g * i, col.b * i)
    else
        local Tk = self.quad.values.gTempK
        local r, g, b = blackbody(Tk * k)
        local r0, g0, b0 = blackbody(Tk)
        local n = (self.cfg.lightIntensity or 5) / math.max(r0 * 0.3 + g0 * 0.6 + b0 * 0.1, 1e-8)
        self.light.color:set(r * n, g * n, b * n)
    end
    if not self.lightLinked then
        self.light.position:set(self.spine.nozzle):addScaled(self.spine.dir, 0.3)
        self.light.direction:set(self.spine.dir)
    end
end

function AfterburnerPlume:update(level, dt)
    self.level = math.applyLag(self.level, level or 0, (self.level > (level or 0)) and 0.9 or 0.5, dt)
    self.time = self.time + dt

    local cfg, s, v = self.cfg, self.spine, self.quad.values
    local right, up, look = car.side, car.up, car.look

    s.nozzle:set(car.position):addScaled(right, self.from.x):addScaled(up, self.from.y):addScaled(look, self.from.z)
    s.dir:set(0, 0, 0):addScaled(right, self.dir.x):addScaled(up, self.dir.y):addScaled(look, self.dir.z)
    s.up:set(up)
    s.right:set(right)

    s.offset:set(s.nozzle):addScaled(car.position, -1)
    s.air:set(car.angularVelocity):cross(s.offset):add(car.velocity)
    s.air.x = s.air.x - sim.windVelocityKmh.x / 3.6
    s.air.z = s.air.z - sim.windVelocityKmh.y / 3.6

    local jetSpeed = math.max(cfg.jetSpeed or 80, 1)
    s.targetDir:setScaled(s.dir, jetSpeed):addScaled(s.air, -1)
    if #s.targetDir < 0.001 then s.targetDir:set(s.dir) else s.targetDir:normalize() end

    local fixedLen = math.min(math.max(cfg.chokeFixedLength or 0, 0), self.length)
    local flexLen = self.length - fixedLen
    s.hinge:set(s.nozzle):addScaled(s.dir, fixedLen)

    local ja = cfg.jitterAmp or 0
    if ja > 0 and flexLen > 1e-4 then
        local w = (self.time + self.phase) * (cfg.jitterFreq or 0) * 6.2831853
        local j = ja / flexLen
        s.targetDir:addScaled(s.right, math.sin(w) * j):addScaled(s.up, math.sin(w * 1.37 + 1.7) * j):normalize()
    end

    v.gP0:set(s.hinge)
    v.gDir:set(s.dir)
    v.gTargetDir:set(s.targetDir)
    v.gGamma = math.max(cfg.deflectGamma or 1, 0.01)
    v.gFixedT = self.length > 1e-4 and (fixedLen / self.length) or 0
    s.fixedT = v.gFixedT
    v.gLength = self.length
    v.gCoreT = v.gFixedT
    v.gTempMul = self.level
    v.gTime = self.time
    v.gNoiseFlow = cfg.noiseFlow
    v.gNoiseAmp = cfg.noiseAmp or 0.35
    v.gNoiseHoles = cfg.noiseHoles or 0.45
    v.gNoiseFreq.x = cfg.noiseFreqT or 4
    v.gNoiseFreq.y = cfg.noiseFreqTheta or 6
    v.gSlope0 = fixedLen > 1e-4 and (cfg.radiusChoke - cfg.radiusStart) / fixedLen or 0
    v.gSlope1 = flexLen > 1e-4 and (cfg.radiusEnd - cfg.radiusChoke) / flexLen or 0

    local ringCount = cfg.rings + 1
    for i = 1, ringCount do
        local ring = self.rings[i]
        local t
        if flexLen < 1e-4 then
            t = (i - 1) / cfg.rings
        elseif i == 1 then
            t = 0
        elseif i == 2 then
            t = v.gFixedT
        else
            t = v.gFixedT + (1 - v.gFixedT) * (i - 2) / (ringCount - 2)
        end
        ring.t = t
        if t <= v.gFixedT then
            ring.radius = math.lerp(cfg.radiusStart, cfg.radiusChoke, t / math.max(v.gFixedT, 1e-4))
        else
            ring.radius = math.lerp(cfg.radiusChoke, cfg.radiusEnd, (t - v.gFixedT) / math.max(1 - v.gFixedT, 1e-4))
        end
        if t <= v.gFixedT or flexLen < 1e-4 then
            ring.center:set(s.nozzle):addScaled(s.dir, t * self.length)
            s.tangent:set(s.dir)
        else
            self:sampleSpine(t, ring.center, s.tangent)
        end
        if i == 1 then
            local helper = math.abs(math.dot(s.tangent, up)) > 0.99 and right or up
            ring.sideA:set(math.cross(s.tangent, helper)):normalize()
        else
            ring.sideA:set(self.rings[i - 1].sideA)
                :addScaled(s.tangent, -math.dot(self.rings[i - 1].sideA, s.tangent)):normalize()
        end
        ring.sideB:set(math.cross(s.tangent, ring.sideA))
    end

    self:updateLight()
end

function AfterburnerPlume:drawShockCone(r0, r1, t0, t1)
    local d, v, cfg = self.diamond, self.quad.values, self.cfg
    local axisLen = #(d.apex - d.base)
    if axisLen < 1e-4 or (r0 < 1e-4 and r1 < 1e-4) then return end

    d.tangent:set(d.apex):addScaled(d.base, -1):normalize()
    local helper = math.abs(math.dot(d.tangent, self.spine.up)) > 0.99 and self.spine.right or self.spine.up
    d.sideA:set(math.cross(d.tangent, helper)):normalize()
    d.sideB:set(math.cross(d.tangent, d.sideA))
    d.mid:setLerp(d.base, d.apex, 0.5)

    v.gP0:set(d.base)
    v.gP2:set(d.apex)
    v.gP1:setScaled(d.mid, 2):addScaled(d.base, -0.5):addScaled(d.apex, -0.5)
    v.gDir:set(d.tangent)
    v.gTargetDir:set(d.tangent)
    v.gFixedT = 0
    v.gGamma = 1
    v.gLength = axisLen
    v.gT0, v.gT1 = 0, 1
    v.gAlong0, v.gAlong1 = t0, t1
    local slope = (r1 - r0) / axisLen
    v.gSlope0, v.gSlope1 = slope, slope
    v.gEdgeFade = cfg.diamondFade or 0
    v.gNoiseAmp = (cfg.noiseAmp or 0.35) * 0.35
    v.gNoiseHoles = (cfg.noiseHoles or 0.45) * 0.35
    v.gNoiseFlow = (cfg.noiseFlow or 12) * (0.35 + 0.65 * self.level) * 0.4
    v.gNoiseSeed = 19.7 + self.phase

    for j = 1, cfg.segments do
        local c0, s0, c1, s1 = self.cos[j], self.sin[j], self.cos[j + 1], self.sin[j + 1]
        self.quad.p1:set(d.base):addScaled(d.sideA, c0 * r0):addScaled(d.sideB, s0 * r0)
        self.quad.p2:set(d.apex):addScaled(d.sideA, c0 * r1):addScaled(d.sideB, s0 * r1)
        self.quad.p3:set(d.apex):addScaled(d.sideA, c1 * r1):addScaled(d.sideB, s1 * r1)
        self.quad.p4:set(d.base):addScaled(d.sideA, c1 * r0):addScaled(d.sideB, s1 * r0)
        v.gTheta0 = (j - 1) / cfg.segments
        v.gTheta1 = j / cfg.segments
        render.shaderedQuad(self.quad)
    end
end

function AfterburnerPlume:draw()
    if self.level < 0.001 then return end
    local cfg, v = self.cfg, self.quad.values
    v.gEdgeFade = 0
    v.gNoiseSeed = self.phase
    v.gNoiseAmp = cfg.noiseAmp or 0.35
    v.gNoiseHoles = cfg.noiseHoles or 0.45
    for i = 1, cfg.rings do
        local r0, r1 = self.rings[i], self.rings[i + 1]
        v.gT0, v.gT1 = r0.t, r1.t
        v.gAlong0, v.gAlong1 = r0.t, r1.t
        for j = 1, cfg.segments do
            local c0, s0, c1, s1 = self.cos[j], self.sin[j], self.cos[j + 1], self.sin[j + 1]
            self.quad.p1:set(r0.center):addScaled(r0.sideA, c0 * r0.radius):addScaled(r0.sideB, s0 * r0.radius)
            self.quad.p2:set(r1.center):addScaled(r1.sideA, c0 * r1.radius):addScaled(r1.sideB, s0 * r1.radius)
            self.quad.p3:set(r1.center):addScaled(r1.sideA, c1 * r1.radius):addScaled(r1.sideB, s1 * r1.radius)
            self.quad.p4:set(r0.center):addScaled(r0.sideA, c1 * r0.radius):addScaled(r0.sideB, s1 * r0.radius)
            v.gTheta0 = (j - 1) / cfg.segments
            v.gTheta1 = j / cfg.segments
            render.shaderedQuad(self.quad)
        end
    end

    local period = math.max(0.08, (cfg.diamondPeriod or 0.45) * (0.4 + 0.6 * self.level))
    local dja = cfg.diamondJitterAmp or 0
    if dja > 0 then
        period = math.max(0.08, period + math.sin((self.time + self.phase) * (cfg.diamondJitterFreq or 0) * 6.2831853) * dja)
    end
    local length = math.min(math.max(cfg.diamondLength or period * 0.5, 0.01), period * 0.9)
    local f0, f1 = cfg.diamondStart or 0, cfg.diamondEnd or 1
    local d = self.diamond
    d.base:set(self.spine.nozzle)
    d.apex:set(self.spine.nozzle):addScaled(self.spine.dir, math.min(length, self.length))
    local t0, t1 = 0, math.min(length, self.length) / self.length
    self:drawShockCone(self:radiusAt(t0) * f0, self:radiusAt(t1) * f1, t0, t1)

    for k = 1, 12 do
        local s0 = k * period
        if s0 >= self.length - 0.02 then break end
        local s1 = math.min(s0 + length, self.length)
        t0, t1 = s0 / self.length, s1 / self.length
        self:sampleSpine(t0, d.base, d.tangent)
        self:sampleSpine(t1, d.apex, self.spine.tangent)
        self:drawShockCone(self:radiusAt(t0) * f0, self:radiusAt(t1) * f1, t0, t1)
    end
end

return AfterburnerPlume
