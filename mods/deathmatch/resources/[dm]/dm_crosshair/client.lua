--[[
    dm_crosshair — mira customizável do UTG.
    · Ao entrar, o jogador vê a mira ORIGINAL do GTA (enabled = false).
    · F9 (ou /mira) abre o painel de miras no dm_ui; aqui só fica o desenho (dx) e a persistência.
    · Estilos: dot, classic, classicdot, plus, x, circle, circledot, tee.
    · A mira nativa volta sozinha com a sniper (ID 34), porque "crosshair" também controla o scope.
    Exports (cliente): getCrosshair(), setCrosshair(data) [prévia ao vivo], saveCrosshair(data) [salva na conta], resetCrosshair().
]]

local sw, sh = guiGetScreenSize()

local DEFAULTS = {
    enabled = false,
    style = "classic",
    color = "#22E68A",
    size = 6,
    thickness = 2,
    gap = 4,
    opacity = 255,
    outline = true,
    followAim = true,
    offsetX = 0,
    offsetY = 0,
}
local STYLES = { dot = true, classic = true, classicdot = true, plus = true, x = true, circle = true, circledot = true, tee = true }

local function copyTable(src) local out = {} for k, v in pairs(src or {}) do out[k] = v end return out end
local function clamp(v, min, max)
    v = tonumber(v) or min
    if v < min then return min end
    if v > max then return max end
    return v
end

local function sanitize(data)
    data = type(data) == "table" and data or {}
    local out = copyTable(DEFAULTS)
    if type(data.enabled) == "boolean" then out.enabled = data.enabled end
    if type(data.style) == "string" and STYLES[data.style] then out.style = data.style end
    if type(data.color) == "string" and data.color:match("^#%x%x%x%x%x%x$") then out.color = data.color:upper() end
    out.size = math.floor(clamp(data.size or out.size, 2, 18))
    out.thickness = math.floor(clamp(data.thickness or out.thickness, 1, 6))
    out.gap = math.floor(clamp(data.gap or out.gap, 0, 16))
    out.opacity = math.floor(clamp(data.opacity or out.opacity, 40, 255))
    out.offsetX = math.floor(clamp(data.offsetX or out.offsetX, -100, 100))
    out.offsetY = math.floor(clamp(data.offsetY or out.offsetY, -100, 100))
    if type(data.outline) == "boolean" then out.outline = data.outline end
    if type(data.followAim) == "boolean" then out.followAim = data.followAim end
    return out
end

local settings = sanitize(DEFAULTS)

-- ---------------------------------------------------------------- exports
function getCrosshair() return copyTable(settings) end
function setCrosshair(data) settings = sanitize(data) return copyTable(settings) end
function saveCrosshair(data)
    settings = sanitize(data)
    triggerServerEvent("crosshair:save", localPlayer, settings)
    return copyTable(settings)
end
function resetCrosshair()
    settings = sanitize(DEFAULTS)
    triggerServerEvent("crosshair:save", localPlayer, settings)
    return copyTable(settings)
end

-- ---------------------------------------------------------------- desenho
local function hexToColor(hex, alpha)
    local r = tonumber(hex:sub(2, 3), 16) or 255
    local g = tonumber(hex:sub(4, 5), 16) or 255
    local b = tonumber(hex:sub(6, 7), 16) or 255
    return tocolor(r, g, b, alpha or 255)
end

local function aimPosition()
    local x, y = sw * 0.5, sh * 0.5
    if settings.followAim and getPedControlState(localPlayer, "aim_weapon") then
        local tx, ty, tz = getPedTargetEnd(localPlayer)
        if tx then
            local sx, sy = getScreenFromWorldPosition(tx, ty, tz, 0, true)
            if sx then x, y = sx, sy end
        end
    end
    return x + settings.offsetX, y + settings.offsetY
end

local function outlineColor() return tocolor(0, 0, 0, math.min(220, settings.opacity)) end
local function rect(x, y, w, h, color)
    if settings.outline then dxDrawRectangle(x - 1, y - 1, w + 2, h + 2, outlineColor(), true) end
    dxDrawRectangle(x, y, w, h, color, true)
end
local function line(x1, y1, x2, y2, color, thickness)
    if settings.outline then dxDrawLine(x1, y1, x2, y2, outlineColor(), thickness + 2, true) end
    dxDrawLine(x1, y1, x2, y2, color, thickness, true)
end
local function dot(cx, cy, radius, color)
    if settings.outline then dxDrawCircle(cx, cy, radius + 1.3, 0, 360, outlineColor(), outlineColor(), 24, 1, true) end
    dxDrawCircle(cx, cy, radius, 0, 360, color, color, 24, 1, true)
end
local function ring(cx, cy, radius, thickness, color)
    if settings.outline then
        dxDrawCircle(cx, cy, radius + 1, 0, 360, outlineColor(), outlineColor(), 40, thickness + 2, true)
    end
    dxDrawCircle(cx, cy, radius, 0, 360, color, color, 40, thickness, true)
end
local function arms(cx, cy, size, thickness, gap, color, noTop)
    rect(cx - gap - size, cy - thickness * 0.5, size, thickness, color)
    rect(cx + gap, cy - thickness * 0.5, size, thickness, color)
    if not noTop then rect(cx - thickness * 0.5, cy - gap - size, thickness, size, color) end
    rect(cx - thickness * 0.5, cy + gap, thickness, size, color)
end

local function drawCrosshair()
    local scoped = getPedWeapon(localPlayer) == 34
    local showNative = (not settings.enabled) or scoped
    showPlayerHudComponent("crosshair", showNative)   -- reaplicado sempre: outros resources mexem no HUD ao iniciar
    if showNative then return end
    if getElementData(localPlayer, "dm:panel") == "crosshair" then return end   -- o painel mostra a prévia
    if getElementData(localPlayer, "dm:ready") ~= true or isPedDead(localPlayer) then return end

    local cx, cy = aimPosition()
    local color = hexToColor(settings.color, settings.opacity)
    local size, thickness, gap, style = settings.size, settings.thickness, settings.gap, settings.style

    if style == "dot" then
        dot(cx, cy, math.max(1, size * 0.5), color)
    elseif style == "classic" then
        arms(cx, cy, size, thickness, gap, color)
    elseif style == "classicdot" then
        arms(cx, cy, size, thickness, gap, color)
        dot(cx, cy, math.max(1, thickness * 0.8), color)
    elseif style == "plus" then
        rect(cx - size, cy - thickness * 0.5, size * 2, thickness, color)
        rect(cx - thickness * 0.5, cy - size, thickness, size * 2, color)
    elseif style == "x" then
        line(cx - size, cy - size, cx + size, cy + size, color, thickness)
        line(cx + size, cy - size, cx - size, cy + size, color, thickness)
    elseif style == "circle" then
        ring(cx, cy, size + gap * 0.5, thickness, color)
    elseif style == "circledot" then
        ring(cx, cy, size + gap * 0.5, thickness, color)
        dot(cx, cy, math.max(1, thickness * 0.8), color)
    elseif style == "tee" then
        arms(cx, cy, size, thickness, gap, color, true)
    end
end
addEventHandler("onClientRender", root, drawCrosshair)

-- ---------------------------------------------------------------- painel (fica no dm_ui)
local function openPanel()
    triggerEvent("crosshair:openPanel", localPlayer)
end
addCommandHandler("mira", openPanel)
addCommandHandler("crosshair", openPanel)

-- ---------------------------------------------------------------- persistência
addEvent("crosshair:load", true)
addEventHandler("crosshair:load", resourceRoot, function(data)
    settings = sanitize(data)
    if getElementData(localPlayer, "dm:panel") == "crosshair" then
        triggerEvent("crosshair:refreshPanel", localPlayer)
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    setTimer(function() triggerServerEvent("crosshair:request", localPlayer) end, 800, 1)
end)
addEventHandler("onClientResourceStop", resourceRoot, function()
    showPlayerHudComponent("crosshair", true)
end)
