-- CSP Physics Script - Helper Functions Module
-- Authored by ohyeah2389


local script_helpers = {}


-- math helper function, like Map Range in Blender
function script_helpers.mapRange(n, start, stop, newStart, newStop, withinBounds)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) + newStart

    -- Returns basic value
    if not withinBounds then
        return value
    end

    -- Returns values constrained to exact range
    if newStart < newStop then
        return math.max(math.min(value, newStop), newStart)
    else
        return math.max(math.min(value, newStart), newStop)
    end
end


-- math helper function, returns quartic of input
function script_helpers.quarticInverse(x)
    return 1 - (1 - x) ^ 4
end

-- math helper function, returns inverse quartic of input
function script_helpers.quartic(x)
    return x ^ 4
end

function script_helpers.erf(x)
    local sign = (x >= 0) and 1 or -1
    x = math.abs(x)
    local t = 1 / (1 + 0.3275911 * x)
    local y = 1 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * math.exp(-x * x)
    return sign * y
end

function script_helpers.normalDistributionPDF(x, mean, stdDev)
    local normalizer = math.exp(0) / (stdDev * math.sqrt(2 * math.pi))
    return (math.exp(-((x - mean) ^ 2) / (2 * stdDev ^ 2)) / (stdDev * math.sqrt(2 * math.pi))) / normalizer
end

function script_helpers.normalDistributionCDF(x, mean, stdDev)
    return (1 + script_helpers.erf((x - mean) / (stdDev * math.sqrt(2)))) / 2
end

function script_helpers.logit(x)
    return math.log(x / (1 - x))
end

return script_helpers