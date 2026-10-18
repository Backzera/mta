--[[
    dm_crosshair — mira customizável do UTG.
    · /mira abre o painel
    · padrão: somente um ponto branco
    · segue a posição real de mira do MTA quando o jogador está mirando
    · ajustes são pré-visualizados em tempo real e salvos por conta
]]

local sw, sh = guiGetScreenSize()
local browser, browserReady = nil, false
local panelOpen = false
local panelOriginal = nil

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

local settings = {}
local styles = { dot = true, classic = true, plus = true, x = true }

local function copyTable(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

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
    if type(data.style) == "string" and styles[data.style] then out.style = data.style end
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

settings = sanitize(DEFAULTS)

local function notify(text, kind)
    local ui = getResourceFromName("dm_ui")
    if ui and getResourceState(ui) == "running" then
        exports.dm_ui:notify(text, kind or "info", "Mira")
    else
        outputChatBox("[UTG] " .. text, 124, 255, 178)
    end
end

local function applyNativeCrosshair()
    -- Com a mira customizada ligada, esconde somente a mira nativa.
    -- Se o jogador desligar a customizada, a mira original do GTA/MTA volta.
    showPlayerHudComponent("crosshair", settings.enabled ~= true)
end

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
        if tx and ty and tz then
            local sx, sy = getScreenFromWorldPosition(tx, ty, tz, 0, true)
            if sx and sy then
                x, y = sx, sy
            end
        end
    end

    return x + settings.offsetX, y + settings.offsetY
end

local function rect(x, y, w, h, color)
    if settings.outline then
        dxDrawRectangle(x - 1, y - 1, w + 2, h + 2, tocolor(0, 0, 0, math.min(220, settings.opacity)), true)
    end
    dxDrawRectangle(x, y, w, h, color, true)
end

local function line(x1, y1, x2, y2, color, thickness)
    if settings.outline then
        dxDrawLine(x1, y1, x2, y2, tocolor(0, 0, 0, math.min(220, settings.opacity)), thickness + 2, true)
    end
    dxDrawLine(x1, y1, x2, y2, color, thickness, true)
end

local function drawCrosshair()
    if panelOpen or not settings.enabled then return end
    if getElementData(localPlayer, "dm:ready") ~= true or isPedDead(localPlayer) then return end

    local cx, cy = aimPosition()
    local color = hexToColor(settings.color, settings.opacity)
    local size = settings.size
    local thickness = settings.thickness
    local gap = settings.gap

    if settings.style == "dot" then
        local radius = math.max(1, size * 0.5)
        if settings.outline then
            dxDrawCircle(cx, cy, radius + 1.3, 0, 360, tocolor(0, 0, 0, math.min(220, settings.opacity)), tocolor(0, 0, 0, math.min(220, settings.opacity)), 24, 1, true)
        end
        dxDrawCircle(cx, cy, radius, 0, 360, color, color, 24, 1, true)

    elseif settings.style == "classic" then
        rect(cx - gap - size, cy - thickness * 0.5, size, thickness, color)
        rect(cx + gap, cy - thickness * 0.5, size, thickness, color)
        rect(cx - thickness * 0.5, cy - gap - size, thickness, size, color)
        rect(cx - thickness * 0.5, cy + gap, thickness, size, color)

    elseif settings.style == "plus" then
        rect(cx - size, cy - thickness * 0.5, size * 2, thickness, color)
        rect(cx - thickness * 0.5, cy - size, thickness, size * 2, color)

    elseif settings.style == "x" then
        line(cx - size, cy - size, cx + size, cy + size, color, thickness)
        line(cx + size, cy - size, cx - size, cy + size, color, thickness)
    end
end
addEventHandler("onClientRender", root, drawCrosshair)

local function sendStateToBrowser()
    if not browser or not browserReady then return end
    executeBrowserJavascript(browser, ("window.crosshairSet && window.crosshairSet(%s)"):format(toJSON(settings)))
end

local function renderPanel()
    if browser and isElement(browser) then
        dxDrawImage(0, 0, sw, sh, browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function ensureBrowser()
    if browser and isElement(browser) then return end

    browserReady = false
    browser = createBrowser(sw, sh, true, true)
    addEventHandler("onClientBrowserCreated", browser, function()
        loadBrowserURL(source, "http://mta/local/ui/index.html")
    end)
    addEventHandler("onClientBrowserDocumentReady", browser, function()
        browserReady = true
        sendStateToBrowser()
    end)
end

local blockedControls = {
    "fire", "aim_weapon", "next_weapon", "previous_weapon",
    "enter_exit", "vehicle_fire", "vehicle_secondary_fire",
}

local function setPanelControls(enabled)
    for _, control in ipairs(blockedControls) do
        toggleControl(control, enabled)
    end
end

local function closePanel(keepChanges)
    if not panelOpen then return end

    if not keepChanges and panelOriginal then
        settings = sanitize(panelOriginal)
        applyNativeCrosshair()
    end

    panelOpen = false
    panelOriginal = nil
    removeEventHandler("onClientRender", root, renderPanel)

    if getElementData(localPlayer, "dm:panel") == "crosshair" then
        setElementData(localPlayer, "dm:panel", false, false)
    end

    showCursor(false)
    showChat(true)
    setPanelControls(true)
    guiSetInputMode("allow_binds")
    if browser and isElement(browser) then focusBrowser(nil) end
end

local function openPanel()
    if panelOpen then return end

    local opened = getElementData(localPlayer, "dm:panel")
    if opened and opened ~= false and opened ~= "crosshair" then
        notify("Feche o painel atual antes de editar a mira.", "warn")
        return
    end

    ensureBrowser()
    panelOriginal = copyTable(settings)
    panelOpen = true
    setElementData(localPlayer, "dm:panel", "crosshair", false)

    addEventHandler("onClientRender", root, renderPanel)
    showCursor(true)
    showChat(false)
    setPanelControls(false)
    guiSetInputMode("no_binds_when_editing")

    if browser and isElement(browser) then focusBrowser(browser) end
    sendStateToBrowser()
end

local function togglePanel()
    if panelOpen then closePanel(false) else openPanel() end
end

addCommandHandler("mira", togglePanel)
addCommandHandler("crosshair", togglePanel)

bindKey("escape", "down", function()
    if panelOpen then
        closePanel(false)
        cancelEvent()
    end
end)

addEvent("crosshair:action", true)
addEventHandler("crosshair:action", root, function(action, json)
    if not panelOpen then return end

    local payload = {}
    if type(json) == "string" and json ~= "" then
        payload = fromJSON(json) or {}
    elseif type(json) == "table" then
        payload = json
    end

    if action == "change" then
        settings = sanitize(payload)
        applyNativeCrosshair()

    elseif action == "reset" then
        settings = sanitize(DEFAULTS)
        applyNativeCrosshair()
        sendStateToBrowser()

    elseif action == "save" then
        settings = sanitize(payload)
        applyNativeCrosshair()
        triggerServerEvent("crosshair:save", localPlayer, settings)
        notify("Configuração da mira salva.", "success")
        closePanel(true)

    elseif action == "close" then
        closePanel(false)
    end
end)

addEvent("crosshair:load", true)
addEventHandler("crosshair:load", resourceRoot, function(data)
    settings = sanitize(data)
    applyNativeCrosshair()
    if panelOpen then
        panelOriginal = copyTable(settings)
        sendStateToBrowser()
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    applyNativeCrosshair()
    setTimer(function()
        triggerServerEvent("crosshair:request", localPlayer)
    end, 800, 1)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    showPlayerHudComponent("crosshair", true)
    if panelOpen then
        showCursor(false)
        showChat(true)
        setPanelControls(true)
        if getElementData(localPlayer, "dm:panel") == "crosshair" then
            setElementData(localPlayer, "dm:panel", false, false)
        end
    end
end)
