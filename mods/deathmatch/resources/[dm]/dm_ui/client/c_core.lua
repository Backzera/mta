--[[
    dm_ui — núcleo da interface em CEF (HTML/CSS/React) renderizada dentro do MTA.
      · um único browser local e transparente desenhado em tela cheia (HUD + painéis)
      · gerenciador de painéis: cursor, chat oculto (showChat), controles travados, só um painel por vez
      · ponte: Lua -> JS (window.ui.set/open/close/push/merge) e JS -> Lua (mta.triggerEvent("ui:act", tela, ação, json))
    Os outros arquivos (c_hud.lua, c_screens.lua) registram telas com UI.on(tela, ação, fn).
]]
UI = {}
local sw, sh = guiGetScreenSize()
UI.sw, UI.sh = sw, sh
local browser, ready = nil, false
local queue = {}            -- JS enfileirado até o documento carregar
local handlers = {}         -- [tela][ação] = fn(payload)
local escapeFns = {}        -- [tela] = fn
local openFns, closeFns = {}, {}
local current = nil         -- tela aberta
local hudVisible = true

setElementData(localPlayer, "dm:hubCEF", true, false)

-- ---------- JS ----------
local function js(code)
    if browser and ready then executeBrowserJavascript(browser, code)
    else queue[#queue + 1] = code end
end
function UI.set(key, value) js(("window.ui.set(%q,%s)"):format(key, toJSON(value or {}))) end
function UI.merge(key, value) js(("window.ui.merge(%q,%s)"):format(key, toJSON(value or {}))) end
function UI.push(kind, value) js(("window.ui.push(%q,%s)"):format(kind, toJSON(value or {}))) end
function UI.js(code) js(code) end

-- ---------- sons (do dm_core) ----------
function UI.sound(name, vol)
    if exports.dm_core and exports.dm_core.playUISound then exports.dm_core:playUISound(name, vol or 0.5) end
end

-- ---------- painéis ----------
function UI.getOpenPanel()
    local p = getElementData(localPlayer, "dm:panel")
    return p and p ~= false and p or nil
end
function UI.isOpen(name) return current == name end

-- Abre uma tela: cursor + chat oculto + controles travados. Retorna false se outra tela está aberta.
function UI.open(name, data, opts)
    opts = opts or {}
    local other = UI.getOpenPanel()
    if other and other ~= name then return false end
    if current == name then
        if data then UI.set(name, data) end
        return true
    end
    current = name
    setElementData(localPlayer, "dm:panel", name, false)
    if not opts.noCursor then showCursor(true) end
    showChat(false)
    toggleAllControls(false, true, false)
    if data then js(("window.ui.open(%q,%s)"):format(name, toJSON(data))) else js(("window.ui.open(%q)"):format(name)) end
    if browser and ready and not opts.noCursor then focusBrowser(browser) end
    if openFns[name] then openFns[name]() end
    UI.sound("click", 0.4)
    return true
end

function UI.close(name)
    if not current or (name and current ~= name) then return end
    local closing = current
    current = nil
    if UI.getOpenPanel() == closing then setElementData(localPlayer, "dm:panel", false, false) end
    showCursor(false)
    showChat(true)
    toggleAllControls(true, true, true)
    js("window.ui.close()")
    focusBrowser(nil)
    if closeFns[closing] then closeFns[closing]() end
end

function UI.toggle(name, openFn)
    if current == name then UI.close(name) elseif not UI.getOpenPanel() then openFn() end
end

-- Registra ações vindas do JS: UI.on("shop", "buy", function(payload) ... end)
function UI.on(screen, action, fn)
    handlers[screen] = handlers[screen] or {}
    handlers[screen][action] = fn
end
function UI.onOpen(screen, fn) openFns[screen] = fn end
function UI.onClose(screen, fn) closeFns[screen] = fn end

addEvent("ui:act")
addEventHandler("ui:act", root, function(screen, action, json)
    local payload = {}
    if type(json) == "string" and json ~= "" then
        local ok, decoded = pcall(fromJSON, json)
        if ok and type(decoded) == "table" then payload = decoded end
    end
    local h = handlers[screen] and handlers[screen][action]
    if action == "close" and not h then UI.close(screen) return end
    if h then h(payload) end
end)

-- ESC fecha a tela atual (o JS também envia "close"; aqui é a segurança)
addEventHandler("onClientKey", root, function(key, press)
    if key ~= "escape" or not press then return end
    if current and current ~= "login" then
        cancelEvent()
        if escapeFns[current] then escapeFns[current]() else UI.close(current) end
    end
end)
function UI.onEscape(screen, fn) escapeFns[screen] = fn end

-- ---------- HUD ----------
function setHudVisible(state) hudVisible = state end
function isHudVisible() return hudVisible end
function isPanelOpen() return UI.getOpenPanel() ~= nil end

-- ---------- browser ----------
local function render()
    if browser then dxDrawImage(0, 0, sw, sh, browser) end
end

local function createUIBrowser()
    if browser then return end
    browser = createBrowser(sw, sh, true, true)   -- local, transparente
    if not browser then outputDebugString("[dm_ui] createBrowser falhou (CEF desativado nas opções do MTA?)", 1) return end
    addEventHandler("onClientBrowserCreated", browser, function()
        loadBrowserURL(browser, "http://mta/local/dist/index.html")
    end)
    addEventHandler("onClientBrowserDocumentReady", browser, function()
        ready = true
        for _, code in ipairs(queue) do executeBrowserJavascript(browser, code) end
        queue = {}
        addEventHandler("onClientRender", root, render, true, "low-5")
        triggerEvent("ui:ready", localPlayer)
    end)
end

addEvent("ui:ready")
addEventHandler("onClientResourceStart", resourceRoot, function()
    setPlayerHudComponentVisible("all", false)
    setPlayerHudComponentVisible("crosshair", true)
    showChat(true)
    createUIBrowser()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if current then UI.close(current) end
    setElementData(localPlayer, "dm:hubCEF", false, false)
    setPlayerHudComponentVisible("all", true)
    showCursor(false)
    if browser and isElement(browser) then destroyElement(browser) end
end)
