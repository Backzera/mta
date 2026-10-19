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
local chatPending = false  -- painel aberto antes da página carregar: chat fica visível até lá
local lastOpen = {}       -- [tela] = últimos dados (para reabrir se a página recarregar)
local lastPayload = {}
local deferred = {}

-- Agrupa mudanças de element data no mesmo frame, sem esperar pelo timer do painel.
function UI.defer(key, fn) deferred[key] = fn end
addEventHandler("onClientPreRender", root, function()
    if not next(deferred) then return end
    local work = deferred
    deferred = {}
    for _, fn in pairs(work) do fn() end
end)

setElementData(localPlayer, "dm:hubCEF", true, false)

-- ---------- JS ----------
local function js(code)
    if browser and ready then executeBrowserJavascript(browser, code)
    else
        queue[#queue + 1] = code
        if #queue > 60 then table.remove(queue, 1) end
    end
end
function UI.isReady() return ready end
function UI.set(key, value)
    if current == key then lastOpen[key] = value end
    if not ready and key == "hud" then return end   -- não enche a fila antes de a página carregar
    local payload = toJSON(value or {})
    if ready and lastPayload[key] == payload then return end
    if ready then lastPayload[key] = payload end
    js(("window.ui.set(%q,%s)"):format(key, payload))
end
function UI.merge(key, value)
    lastPayload[key] = nil
    if lastOpen[key] then for k, v in pairs(value or {}) do lastOpen[key][k] = v end end
    js(("window.ui.merge(%q,%s)"):format(key, toJSON(value or {})))
end
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
    if ready then showChat(false) else chatPending = true end
    toggleAllControls(false, true, false)
    lastOpen[name] = data or {}
    lastPayload[name] = nil
    js(("window.ui.open(%q,%s)"):format(name, toJSON(data or {})))
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
    chatPending = false
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
    if screen == "app" and action == "mounted" then triggerEvent("ui:mounted", localPlayer, payload.build) return end
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

-- ---------- mouse -> browser ----------
-- createBrowser é off-screen: o MTA só manda teclado (focusBrowser); o mouse precisa ser injetado.
local function inputActive() return browser and ready and current and current ~= "board" end
addEventHandler("onClientCursorMove", root, function(_, _, ax, ay)
    if inputActive() then injectBrowserMouseMove(browser, ax, ay) end
end)
addEventHandler("onClientClick", root, function(button, state, ax, ay)
    if not inputActive() then return end
    injectBrowserMouseMove(browser, ax, ay)
    if state == "down" then injectBrowserMouseDown(browser, button) else injectBrowserMouseUp(browser, button) end
end)
addEventHandler("onClientKey", root, function(key, press)
    if not inputActive() or not press then return end
    if key == "mouse_wheel_up" then injectBrowserMouseWheel(browser, 90, 0)
    elseif key == "mouse_wheel_down" then injectBrowserMouseWheel(browser, -90, 0) end
end)

-- ---------- HUD ----------
function setHudVisible(state) hudVisible = state end
function isHudVisible() return hudVisible end
function isPanelOpen() return UI.getOpenPanel() ~= nil end

-- ---------- browser ----------
local function render()
    if browser then dxDrawImage(0, 0, sw, sh, browser) end
end

local URL = "http://mta/local/dist/index.html"

local created = false
local diagLines, readyTick = {}, nil
local function diag(msg, level)
    outputDebugString("[dm_ui] " .. msg, level or 3)
    diagLines[#diagLines + 1] = msg
    if #diagLines > 8 then table.remove(diagLines, 1) end
end
-- Diagnóstico desenhado na tela (não depende do chat): some 6 s depois de a página carregar
local function drawDiag()
    if ready and readyTick and getTickCount() - readyTick > 6000 then return end
    local y = 8
    dxDrawText("UTG UI (CEF)  browser=" .. tostring(browser ~= nil) .. "  criado=" .. tostring(created) .. "  pronto=" .. tostring(ready), 9, y + 1, 0, 0, tocolor(0, 0, 0, 200), 1.1, "default-bold")
    dxDrawText("UTG UI (CEF)  browser=" .. tostring(browser ~= nil) .. "  criado=" .. tostring(created) .. "  pronto=" .. tostring(ready), 8, y, 0, 0, ready and tocolor(124, 255, 178) or tocolor(255, 181, 71), 1.1, "default-bold")
    for i, line in ipairs(diagLines) do
        y = y + 16
        dxDrawText(line, 9, y + 1, 0, 0, tocolor(0, 0, 0, 200), 1, "default")
        dxDrawText(line, 8, y, 0, 0, tocolor(255, 255, 255), 1, "default")
    end
end
local function createUIBrowser()
    if browser then return end
    addEventHandler("onClientRender", root, drawDiag)
    local bs = getBrowserSettings and getBrowserSettings() or {}
    diag(("criando browser %dx%d (remoto=%s js=%s)"):format(sw, sh, tostring(bs.RemoteEnabled), tostring(bs.RemoteJavascript)))
    browser = createBrowser(sw, sh, true, true)   -- local, transparente
    if not browser then
        diag("createBrowser falhou: ative o navegador em Configurações > Navegador (CEF) e reconecte", 1)
        outputChatBox("#FF4D6D[UTG] A interface não pôde ser criada: ative o navegador interno em Configurações > Navegador e reconecte.", 255, 77, 109, true)
        return
    end
    addEventHandler("onClientBrowserCreated", browser, function()
        created = true
        diag("browser criado, carregando " .. URL)
        loadBrowserURL(browser, URL .. "?v=" .. (UI_BUILD or "0"))
    end)
    addEventHandler("onClientBrowserDocumentReady", browser, function(url)
        -- o MTA dispara este evento também para a página em branco inicial: só aceita a nossa página
        if not tostring(url):find("dist/index.html", 1, true) then
            diag("documento ignorado: " .. tostring(url))
            return
        end
        local first = not ready
        ready = true
        lastPayload = {}
        readyTick = getTickCount()
        diag("documento pronto: " .. tostring(url))
        if chatPending then chatPending = false showChat(false) end
        for _, code in ipairs(queue) do executeBrowserJavascript(browser, code) end
        queue = {}
        -- garante que a tela aberta antes do carregamento apareça (a fila pode ter sido podada) e receba o teclado
        if current and lastOpen[current] then
            js(("window.ui.open(%q,%s)"):format(current, toJSON(lastOpen[current])))
            if current ~= "board" then focusBrowser(browser) end
        end
        if first then
            addEventHandler("onClientRender", root, render, true, "low-5")
            outputChatBox("#7CFFB2[UTG] Interface carregada.", 255, 255, 255, true)
            triggerEvent("ui:ready", localPlayer)
        end
    end)
    -- diagnóstico: se em 12 s nada carregou, avisa no chat (sem travar o jogador)
    setTimer(function()
        if ready then return end
        local why = not created and "o navegador não foi criado (CEF desativado ou bloqueado?)" or ("a página não carregou: " .. URL)
        diag("interface não carregou em 12 s: " .. why, 1)
        outputChatBox("#FF4D6D[UTG] Interface não carregou: " .. why .. ". Use /uidebug e me mande o resultado.", 255, 77, 109, true)
    end, 12000, 1)
end
addEvent("ui:jserror")
addEventHandler("ui:jserror", root, function(msg) diag("ERRO JS: " .. tostring(msg), 1) readyTick = getTickCount() end)
addEvent("ui:mounted")
addEventHandler("ui:mounted", root, function(build)
    local expected = UI_BUILD or "?"
    if tostring(build) ~= expected then
        diag(("app montado com build %s, esperado %s: arquivos dist/ desatualizados na hospedagem"):format(tostring(build), expected), 1)
        readyTick = nil
    else
        diag("app React montado (build " .. expected .. ")")
    end
end)
-- /uitest: pinta a página de verde por 3 s para separar "página não desenha" de "erro no JS"
addCommandHandler("uitest", function()
    if not browser then return end
    executeBrowserJavascript(browser, "document.documentElement.style.background='rgba(0,255,120,.35)';setTimeout(function(){document.documentElement.style.background='transparent'},3000)")
    diag("teste: a tela deveria ficar esverdeada por 3 s")
    readyTick = getTickCount()
end)
addCommandHandler("uidebug", function()
    outputChatBox(("#7CFFB2[dm_ui] browser=%s criado=%s pronto=%s url=%s res=%dx%d"):format(tostring(browser ~= nil), tostring(created), tostring(ready), browser and tostring(getBrowserURL(browser)) or "-", sw, sh), 255, 255, 255, true)
    if browser then outputChatBox(("#7CFFB2[dm_ui] carregando=%s titulo=%s"):format(tostring(isBrowserLoading(browser)), tostring(getBrowserTitle(browser))), 255, 255, 255, true) end
end)

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
