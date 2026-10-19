-- The only shared namespace; no settings, serials, ACLs or secrets here.
UTGUtils = {}
function UTGUtils.finite(n) return type(n) == "number" and n == n and n > -math.huge and n < math.huge end
function UTGUtils.number(n, low, high) return UTGUtils.finite(n) and n >= low and n <= high end
function UTGUtils.text(value, limit)
    if type(value) ~= "string" then return "?" end
    return value:gsub("#%x%x%x%x%x%x", ""):gsub("[%z\1-\31\127]", " "):sub(1, limit or 160)
end
function UTGUtils.distance(a, b)
    return math.sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2 + (a[3]-b[3])^2)
end
function UTGUtils.angle(a, b)
    local na = math.sqrt(a[1]^2+a[2]^2+a[3]^2)
    local nb = math.sqrt(b[1]^2+b[2]^2+b[3]^2)
    if na < 0.001 or nb < 0.001 then return 0 end
    local dot = (a[1]*b[1]+a[2]*b[2]+a[3]*b[3])/(na*nb)
    return math.deg(math.acos(math.max(-1, math.min(1, dot))))
end
function UTGUtils.metadata(input)
    local out, count = {}, 0
    for k, v in pairs(input or {}) do
        count = count + 1
        if count > 24 then break end
        if type(k) == "string" then
            k = UTGUtils.text(k, 40)
            if type(v) == "string" then out[k] = UTGUtils.text(v, 200)
            elseif UTGUtils.finite(v) or type(v) == "boolean" then out[k] = v end
        end
    end
    return out
end
