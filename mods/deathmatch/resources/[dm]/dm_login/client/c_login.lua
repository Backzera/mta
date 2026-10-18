--[[
    Login (UI v2): aurora animada com logo e destaques à esquerda, card com abas deslizantes,
    campos com foco animado, toggle "manter conectado", botão com brilho, convidado.
]]

local core = exports.dm_core
local PANEL = "login"
local login = { open = false, tick = 0, rendering = false, tab = "login", message = nil, msgType = "info", msgTick = 0, busy = false, remember = true, camTick = 0 }
local fUser = { text = "", placeholder = "Usuário", maxLength = 20, allowed = "[%w_]", icon = "target.png" }
local fPass = { text = "", placeholder = "Senha", maxLength = 32, masked = true, icon = "shield.png" }
local fPass2 = { text = "", placeholder = "Confirmar senha", maxLength = 32, masked = true, icon = "shield.png" }
local inputState
local cfgCache
local CRED_FILE = "@credenciais.xml"

local function s(v) return UI.s(v) end
local function key() return getPlayerSerial():sub(1, 16) end

-- ---------- credenciais salvas ----------
local function saveCredentials(user, pass)
    local xml = xmlLoadFile(CRED_FILE) or xmlCreateFile(CRED_FILE, "login")
    if not xml then return end
    xmlNodeSetAttribute(xml, "user", user)
    xmlNodeSetAttribute(xml, "pass", base64Encode(teaEncode(pass, key())))
    xmlSaveFile(xml)
    xmlUnloadFile(xml)
end
local function loadCredentials()
    if not fileExists(CRED_FILE) then return nil end
    local xml = xmlLoadFile(CRED_FILE)
    if not xml then return nil end
    local user = xmlNodeGetAttribute(xml, "user")
    local enc = xmlNodeGetAttribute(xml, "pass")
    xmlUnloadFile(xml)
    if not user or not enc then return nil end
    local ok, pass = pcall(function() return teaDecode(base64Decode(enc), key()) end)
    if ok and pass and pass ~= "" then return user, pass end
    return nil
end
local function clearCredentials()
    if fileExists(CRED_FILE) then fileDelete(CRED_FILE) end
end

-- ---------- ações ----------
local function setMessage(text, t)
    login.message, login.msgType, login.msgTick = text, t or "info", getTickCount()
end
local function submit()
    if login.busy then return end
    local user, pass = fUser.text, fPass.text
    if #user < 3 then return setMessage("Digite um usuário com pelo menos 3 caracteres.", "error") end
    if #pass < 4 then return setMessage("Digite uma senha com pelo menos 4 caracteres.", "error") end
    if login.tab == "register" then
        if fPass2.text ~= pass then return setMessage("As senhas não coincidem.", "error") end
        login.busy = true
        setMessage("Criando conta...", "info")
        triggerServerEvent("login:register", localPlayer, user, pass, login.remember)
    else
        login.busy = true
        setMessage("Entrando...", "info")
        triggerServerEvent("login:attempt", localPlayer, user, pass, login.remember)
    end
end
local function guest()
    if login.busy then return end
    login.busy = true
    setMessage("Entrando como convidado...", "info")
    triggerServerEvent("login:guest", localPlayer)
end

-- ---------- render ----------
local function render()
    local raw = UI.clamp((getTickCount() - login.tick) / 400, 0, 1)
    local a = login.open and UI.ease(raw, "outCubic") or 1 - UI.ease(raw, "inCubic")
    if a <= 0.001 then
        if not login.open then
            removeEventHandler("onClientRender", root, render)
            login.rendering = false
            setCameraTarget(localPlayer)
        end
        return
    end
    UI.beginFrame()
    cfgCache = cfgCache or core:getConfig()
    local cfg = cfgCache
    -- câmera lenta girando sobre a arena X1
    if login.open then
        local t = (getTickCount() - login.camTick) / 1000
        local cx, cy, radius = -1368, -958, 70
        setCameraMatrix(cx + math.cos(t * 0.08) * radius, cy + math.sin(t * 0.08) * radius, 1012 + math.sin(t * 0.2) * 3, cx, cy, 994)
    end
    if login.tab == "login" and fPass2.focus then fPass2.focus = false fUser.focus = true end

    -- fundo
    UI.backdrop(a, 120, 2.2)
    UI.aurora(0, 0, UI.sw * 0.55, UI.sh, 0.35 * a, { UI.palette.accent, UI.palette.accent2, UI.palette.bg })
    UI.gradientH(UI.sw * 0.35, 0, UI.sw * 0.3, UI.sh, { 6, 10, 8, 0 }, { 6, 10, 8, 120 * a }, 24)

    -- marca à esquerda
    local lx = s(90)
    local lw = s(520)
    local slide = (1 - a) * s(40)
    UI.image("logo.png", lx - slide, UI.sh / 2 - s(170), lw, lw * 200 / 640, tocolor(255, 255, 255, 255 * a))
    UI.text(cfg.tagline .. "  ·  mata-mata, X1, ranqueadas e clãs", lx - slide, UI.sh / 2 + s(6), lw, s(24), UI.color("muted", 255 * a), "medium", 12, "left", "center")
    local feats = { { "target.png", "Arenas por arma", "AK-47, M4, Deagle, Sniper, C-Bug e mais" }, { "swords.png", "Duelos X1 e ranqueadas 5x5 / 10x10", "Suba de elo: Bronze até Lenda" }, { "shield.png", "Clãs e clã x clã", "Tags, loja, VIP e economia própria" } }
    for i, ft in ipairs(feats) do
        local p = UI.stagger(a, i, #feats, 0.5)
        local fy = UI.sh / 2 + s(50) + (i - 1) * s(58)
        local fx = lx + (1 - p) * s(30)
        UI.rrect(fx, fy, s(40), s(40), UI.color("accent", 30 * a * p), s(10), { border = 1, borderColor = UI.color("accent", 90 * a * p) })
        UI.image(ft[1], fx + s(9), fy + s(9), s(22), s(22), tocolor(255, 255, 255, 255 * a * p))
        UI.text(ft[2], fx + s(54), fy, lw, s(22), UI.color("text", 255 * a * p), "semibold", 12, "left", "center")
        UI.text(ft[3], fx + s(54), fy + s(21), lw, s(16), UI.color("muted", 255 * a * p), "regular", 9, "left", "center")
    end

    -- card à direita
    local w, h = s(410), login.tab == "register" and s(540) or s(486)
    local x, y = UI.sw - w - s(110), (UI.sh - h) / 2 + (1 - a) * s(24)
    UI.card(x, y, w, h, s(18), a, "accent", { glow = s(30) })
    local pad = s(30)
    UI.tabs("login:tabs", { { "login", "ENTRAR" }, { "register", "REGISTRAR" } }, x + pad, y + pad, s(34), login.tab, function(k)
        if login.tab ~= k then login.tab = k login.message = nil fPass2.text = "" end
    end, a, 11)
    local fy = y + pad + s(56)
    local fh = s(46)
    UI.text("USUÁRIO", x + pad, fy, w, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
    UI.inputField(fUser, x + pad, fy + s(18), w - pad * 2, fh, { size = 12 })
    fy = fy + s(18) + fh + s(14)
    UI.text("SENHA", x + pad, fy, w, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
    UI.inputField(fPass, x + pad, fy + s(18), w - pad * 2, fh, { size = 12 })
    fy = fy + s(18) + fh + s(14)
    if login.tab == "register" then
        UI.text("CONFIRMAR SENHA", x + pad, fy, w, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
        UI.inputField(fPass2, x + pad, fy + s(18), w - pad * 2, fh, { size = 12 })
        fy = fy + s(18) + fh + s(14)
    else
        fPass2._bounds = nil
    end
    UI.toggle("login:remember", x + pad, fy + s(2), login.remember, function(v) login.remember = v end, a)
    UI.text("Manter conectado neste computador", x + pad + s(50), fy, w, s(26), UI.color("muted", 255 * a), "regular", 10, "left", "center")
    fy = fy + s(42)
    local label = login.busy and "AGUARDE..." or (login.tab == "register" and "CRIAR CONTA" or "ENTRAR")
    UI.button("login_submit", label, x + pad, fy, w - pad * 2, s(48), { kind = "primary", size = 12, alpha = a, disabled = login.busy, onClick = submit })
    fy = fy + s(58)
    UI.button("login_guest", "Jogar como convidado", x + pad, fy, w - pad * 2, s(36), { kind = "outline", size = 10, alpha = a, disabled = login.busy, onClick = guest })
    fy = fy + s(46)
    if login.message then
        local age = getTickCount() - login.msgTick
        local ma = UI.ease(math.min(1, age / 300), "outCubic") * a
        local col = login.msgType == "error" and "danger" or (login.msgType == "success" and "success" or "muted")
        UI.text(login.message, x + pad, fy, w - pad * 2, s(36), UI.color(col, 255 * ma), "medium", 10, "center", "center", false, true)
    end
    UI.text("ENTER confirma   ·   TAB troca de campo", x, y + h - s(28), w, s(16), UI.color("muted", 120 * a), "regular", 8, "center", "center")
    UI.endFrame()
end

local function onClick(button, state)
    if login.open then UI.processClick(button, state) end
end

local function show()
    if login.open then return end
    login.open = true
    login.tick = getTickCount()
    login.camTick = getTickCount()
    login.busy = false
    UI.setPanelOpen(PANEL, true)
    showCursor(true)
    if not login.rendering then login.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    inputState = UI.bindInputs({ fUser, fPass, fPass2 }, function() submit() end)
    fUser.focus = true
    local user, pass = loadCredentials()
    if user and pass then
        fUser.text, fPass.text = user, pass
        login.busy = true
        setMessage("Entrando automaticamente como " .. user .. "...", "info")
        setTimer(function()
            if login.open then triggerServerEvent("login:attempt", localPlayer, user, pass, true) end
        end, 900, 1)
    end
end

local function hide()
    if not login.open then return end
    login.open = false
    login.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
    UI.unbindInputs(inputState)
    inputState = nil
    showCursor(false)
    toggleAllControls(true, true, true)
    setCameraTarget(localPlayer)
end

addEvent("login:show", true)
addEventHandler("login:show", root, show)

addEvent("login:result", true)
addEventHandler("login:result", root, function(ok, message, passToSave)
    login.busy = false
    if ok then
        if passToSave and fUser.text ~= "" then
            saveCredentials(fUser.text, passToSave)
        elseif not passToSave then
            clearCredentials()
        end
        setMessage(message, "success")
        UI.sound("levelup", 0.5)
        setTimer(hide, 500, 1)
        fPass.text, fPass2.text = "", ""
    else
        setMessage(message, "error")
        UI.sound("error", 0.5)
        if message and message:find("Senha incorreta") then clearCredentials() end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("login:ready", localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if login.open then hide() end
end)
