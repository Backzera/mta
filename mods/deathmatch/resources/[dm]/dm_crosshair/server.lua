-- Persistência das configurações de mira por conta MTA.
local KEY = "dm.crosshair"
local allowedStyles = { dot = true, classic = true, plus = true, x = true }

local DEFAULTS = {
    enabled = true,
    style = "dot",
    color = "#FFFFFF",
    size = 4,
    thickness = 2,
    gap = 4,
    opacity = 255,
    outline = true,
    followAim = true,
    offsetX = 0,
    offsetY = 0,
}

local function clamp(v, min, max)
    v = tonumber(v) or min
    if v < min then return min end
    if v > max then return max end
    return v
end

local function sanitize(data)
    data = type(data) == "table" and data or {}
    local out = {}

    out.enabled = type(data.enabled) == "boolean" and data.enabled or DEFAULTS.enabled
    out.style = type(data.style) == "string" and allowedStyles[data.style] and data.style or DEFAULTS.style
    out.color = type(data.color) == "string" and data.color:match("^#%x%x%x%x%x%x$") and data.color:upper() or DEFAULTS.color
    out.size = math.floor(clamp(data.size or DEFAULTS.size, 2, 18))
    out.thickness = math.floor(clamp(data.thickness or DEFAULTS.thickness, 1, 6))
    out.gap = math.floor(clamp(data.gap or DEFAULTS.gap, 0, 16))
    out.opacity = math.floor(clamp(data.opacity or DEFAULTS.opacity, 40, 255))
    out.offsetX = math.floor(clamp(data.offsetX or DEFAULTS.offsetX, -100, 100))
    out.offsetY = math.floor(clamp(data.offsetY or DEFAULTS.offsetY, -100, 100))
    out.outline = type(data.outline) == "boolean" and data.outline or DEFAULTS.outline
    out.followAim = type(data.followAim) == "boolean" and data.followAim or DEFAULTS.followAim

    return out
end

local function loadFor(player)
    if not isElement(player) then return sanitize(DEFAULTS) end

    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        local raw = getAccountData(account, KEY)
        if type(raw) == "string" and raw ~= "" then
            local parsed = fromJSON(raw)
            if type(parsed) == "table" then return sanitize(parsed) end
        end
    end

    local session = getElementData(player, "dm:crosshair")
    if type(session) == "table" then return sanitize(session) end
    return sanitize(DEFAULTS)
end

local function send(player)
    if isElement(player) then
        triggerClientEvent(player, "crosshair:load", resourceRoot, loadFor(player))
    end
end

addEvent("crosshair:request", true)
addEventHandler("crosshair:request", root, function()
    local player = client
    if not player or not isElement(player) then return end
    send(player)
end)

addEvent("crosshair:save", true)
addEventHandler("crosshair:save", root, function(data)
    local player = client
    if not player or not isElement(player) then return end

    data = sanitize(data)
    setElementData(player, "dm:crosshair", data, false)

    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        setAccountData(account, KEY, toJSON(data))
    end
end)

addEventHandler("onPlayerLogin", root, function()
    setTimer(send, 250, 1, source)
end)
