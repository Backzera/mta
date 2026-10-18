--[[
    HUB (F2) renderizado em CEF (HTML/CSS/React).
    Lua cuida de: criar o browser (assíncrono), F2/ESC, cursor, controles, chat (via UI.setPanelOpen),
    câmera cinematográfica no local selecionado, dados reais (arenas, modos, contagens, jogador) e
    os eventos de entrada já existentes (dm:requestArena / ranked:requestJoin).
    Ponte: JS -> Lua com mta.triggerEvent("hub:*"); Lua -> JS com executeBrowserJavascript(window.hub.*).
]]

local core = exports.dm_core
local PANEL = "hub"
local sw, sh = guiGetScreenSize()
local browser, ready = nil, false
local hub = { open = false, origDim = 0, camStart = 0, selected = nil, pendingOpen = false }
local countTimer

-- Sinaliza para o dm_core que o F2 é deste recurso (o hub dx antigo fica desativado)
setElementData(localPlayer, "dm:hubCEF", true, false)

-- ---------- dados ----------
local function hexToRGB(hex)
    if type(hex) ~= "string" or #hex < 7 then return { 255, 255, 255 } end
    return { tonumber(hex:sub(2, 3), 16) or 255, tonumber(hex:sub(4, 5), 16) or 255, tonumber(hex:sub(6, 7), 16) or 255 }
end

local function counts()
    local map = {}
    for _, p in ipairs(getElementsByType("player")) do
        local id = getElementData(p, "dm:arena")
        if id then map[id] = (map[id] or 0) + 1 end
    end
    return map
end

local function serialize(item, map)
    local weapons = {}
    for _, w in ipairs(item.weapons or {}) do weapons[#weapons + 1] = getWeaponNameFromID(w[1]) or tostring(w[1]) end
    local wtxt = #weapons > 0 and table.concat(weapons, " · ") or (item.type == "duel" and "Arma escolhida no duelo" or "Sem armas")
    local place = item.place or (item.id == "lobby" and "Pershing Square · Los Santos" or (item.native and "Mapa do GTA" or "Mapa próprio"))
    return {
        id = item.id, name = item.name, short = item.short, type = item.type, desc = item.desc or "",
        color = item.color, weapons = wtxt, players = map[item.id] or 0, cap = item.type == "ranked" and item.teamSize * 2 or 32,
        place = place, native = item.native == true, cbug = item.cbug == true, safe = item.safe == true,
        teamSize = item.teamSize, killTarget = item.killTarget, duration = item.duration,
    }
end

local function buildState()
    local map = counts()
    local arenas, modes = {}, {}
    for _, a in ipairs(core:getArenas()) do arenas[#arenas + 1] = serialize(a, map) end
    for _, m in ipairs(core:getRankedModes()) do modes[#modes + 1] = serialize(m, map) end
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = core:getTierForRP(rp)
    return {
        arenas = arenas, modes = modes, current = getElementData(localPlayer, "dm:arena") or false,
        online = #getElementsByType("player"),
        player = { name = (getPlayerName(localPlayer):gsub("#%x%x%x%x%x%x", "")), tier = tier.name:upper(), tierColor = tier.color,
                   money = tonumber(getElementData(localPlayer, "dm:money")) or 0, rp = rp },
    }
end

local function js(code)
    if browser and ready then executeBrowserJavascript(browser, code) end
end

local function pushState()
    js("window.hub && window.hub.setState(" .. toJSON(buildState()) .. ")")
end

-- ---------- browser ----------
local function createHubBrowser()
    if browser then return end
    browser = createBrowser(sw, sh, true, true)   -- local, transparente
    if not browser then outputDebugString("[dm_hub] createBrowser falhou (CEF desativado?)", 1) return end
    addEventHandler("onClientBrowserCreated", browser, function()
        loadBrowserURL(browser, "http://mta/local/dist/index.html")
    end)
    addEventHandler("onClientBrowserDocumentReady", browser, function()
        ready = true
        setBrowserRenderingPaused(browser, true)
        if hub.pendingOpen then hub.pendingOpen = false openHub() end
    end)
end

-- ---------- câmera ----------
local function findItem(id)
    for _, a in ipairs(core:getArenas()) do if a.id == id then return a end end
    for _, m in ipairs(core:getRankedModes()) do if m.id == id then return m end end
end
local function previewPoint(item)
    if item.center then return item.center[1], item.center[2], item.center[3], item.dimension end
    local sp = item.spawns and item.spawns[1]
    if sp then return sp[1], sp[2], sp[3], item.dimension end
    return 0, 0, 10, 0
end

local function render()
    if not hub.open or not browser then return end
    dxDrawImage(0, 0, sw, sh, browser)
    local item = hub.selected and findItem(hub.selected)
    if item then
        local px, py, pz, dim = previewPoint(item)
        if getElementDimension(localPlayer) ~= dim then setElementDimension(localPlayer, dim) end
        local t = (getTickCount() - hub.camStart) / 1000
        local cx = UI.tween("hub:cam:x", px, 1000, "outCubic")
        local cy = UI.tween("hub:cam:y", py, 1000, "outCubic")
        local cz = UI.tween("hub:cam:z", pz, 1000, "outCubic")
        local r = 40
        setCameraMatrix(cx + math.cos(t * 0.2) * r, cy + math.sin(t * 0.2) * r, cz + 15 + math.sin(t * 0.45) * 1.5, cx, cy, cz + 2)
    end
end

-- ---------- abrir / fechar ----------
function openHub()
    if hub.open then return end
    if not getElementData(localPlayer, "dm:ready") then return end
    if not browser then createHubBrowser() end
    if not ready then hub.pendingOpen = true return end
    if not UI.setPanelOpen(PANEL, true) then return end
    hub.open = true
    hub.camStart = getTickCount()
    hub.origDim = getElementDimension(localPlayer)
    hub.selected = getElementData(localPlayer, "dm:arena")
    UI.resetTween("hub:cam:x") UI.resetTween("hub:cam:y") UI.resetTween("hub:cam:z")
    setBrowserRenderingPaused(browser, false)
    pushState()
    js("window.hub && window.hub.open()")
    focusBrowser(browser)
    addEventHandler("onClientRender", root, render)
    countTimer = setTimer(function() js("window.hub && window.hub.counts(" .. toJSON(counts()) .. ")") end, 1000, 0)
    UI.sound("click", 0.4)
end

function closeHub()
    if not hub.open then return end
    hub.open = false
    removeEventHandler("onClientRender", root, render)
    if countTimer and isTimer(countTimer) then killTimer(countTimer) end
    js("window.hub && window.hub.close()")
    setBrowserRenderingPaused(browser, true)
    focusBrowser(nil)
    UI.setPanelOpen(PANEL, false)
    setElementDimension(localPlayer, hub.origDim)
    setCameraTarget(localPlayer)
end

bindKey("F2", "down", function() if hub.open then closeHub() else openHub() end end)
UI.registerEscape(PANEL, closeHub)

-- ---------- eventos vindos do JS ----------
addEvent("hub:ready")
addEvent("hub:select")
addEventHandler("hub:select", root, function(id) hub.selected = id end)
addEvent("hub:close")
addEventHandler("hub:close", root, function() closeHub() end)
addEvent("hub:enter")
addEventHandler("hub:enter", root, function(id)
    local item = findItem(id)
    closeHub()
    if not item then return end
    if item.type == "ranked" then
        triggerServerEvent("ranked:requestJoin", localPlayer, item.id)
    else
        triggerServerEvent("dm:requestArena", localPlayer, item.id)
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if isBrowserDomainBlocked and isBrowserDomainBlocked("mta", true) then
        outputDebugString("[dm_hub] domínio local bloqueado?", 2)
    end
    createHubBrowser()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if hub.open then closeHub() end
    setElementData(localPlayer, "dm:hubCEF", false, false)
    if browser and isElement(browser) then destroyElement(browser) end
end)
