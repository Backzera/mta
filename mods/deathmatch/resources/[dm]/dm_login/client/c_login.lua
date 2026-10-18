--[[
    Painel de login moderno (dx): entrar, registrar, lembrar e convidado.
]]

local core = exports.dm_core
local PANEL = "login"
local login = { open = false, tick = 0, tab = "login", message = nil, msgType = "info", busy = false, remember = true, camTick = 0 }
local fUser = { text = "", placeholder = "Usuário", maxLength = 20, allowed = "[%w_]" }
local fPass = { text = "", placeholder = "Senha", maxLength = 32, masked = true }
local fPass2 = { text = "", placeholder = "Confirmar senha", maxLength = 32, masked = true }
local inputState
local clicks = {}
local CRED_FILE = "@credenciais.xml"

local function s(v) return UI.s(v) end
local function sound(n, v) core:playUISound(n, v) end
UI.sound = sound
local cfgCache

-- ---------- credenciais salvas (lembrar-me) ----------
local function key() return getPlayerSerial():sub(1, 16) end

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
    sound("click", 0.5)
end

local function guest()
    if login.busy then return end
    login.busy = true
    setMessage("Entrando como convidado...", "info")
    triggerServerEvent("login:guest", localPlayer)
    sound("click", 0.5)
end

-- ---------- render ----------
local RENDER_ON = false
local function render()
    local progress = UI.openProgress(login, 300)
    if progress <= 0 then
        if not login.open then
            removeEventHandler("onClientRender", root, render) RENDER_ON = false
            setCameraTarget(localPlayer)
        end
        return
    end
    local a = progress
    clicks = {}
    -- câmera lenta girando sobre a arena X1
    local t = (getTickCount() - login.camTick) / 1000
    local cx, cy = -1368, -958
    local radius = 70
    local camX = cx + math.cos(t * 0.08) * radius
    local camY = cy + math.sin(t * 0.08) * radius
    if login.open then setCameraMatrix(camX, camY, 1012 + math.sin(t * 0.2) * 3, cx, cy, 994) end

    -- fundo
    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(6, 8, 14, 170 * a))
    UI.gradientH(0, UI.sh - s(3), UI.sw / 2, s(3), { 0, 229, 168, 0 }, { 0, 229, 168, 255 * a }, 40)
    UI.gradientH(UI.sw / 2, UI.sh - s(3), UI.sw / 2, s(3), { 0, 229, 168, 255 * a }, { 124, 92, 255, 0 }, 40)

    -- marca à esquerda
    cfgCache = cfgCache or core:getConfig()
    local cfg = cfgCache
    UI.text(cfg.name, s(80), UI.sh / 2 - s(90), UI.sw / 2, s(60), UI.color("text", 255 * a), "bold", 48, "left", "center")
    UI.rect(s(82), UI.sh / 2 - s(24), s(70), s(5), UI.color("accent", 255 * a), 2)
    UI.text(cfg.tagline, s(80), UI.sh / 2 - s(8), UI.sw / 2, s(26), UI.color("muted", 255 * a), "medium", 15, "left", "center")
    UI.text("Arenas por arma  ·  Duelos X1  ·  Ranking e níveis  ·  C-Bug na arena certa", s(80), UI.sh / 2 + s(20), UI.sw / 2, s(22), UI.color("muted", 200 * a), "regular", 11, "left", "center")

    -- card
    if login.tab == "login" and fPass2.focus then fPass2.focus = false fUser.focus = true end
    local w, h = s(400), (login.tab == "register" and s(520) or s(470))
    local x, y = UI.sw - w - s(100), (UI.sh - h) / 2 + (1 - a) * s(24)
    UI.card(x, y, w, h, s(20), a)
    local pad = s(30)

    -- abas
    local tabW = (w - pad * 2) / 2
    for i, tab in ipairs({ { "login", "ENTRAR" }, { "register", "REGISTRAR" } }) do
        local tx = x + pad + (i - 1) * tabW
        local sel = login.tab == tab[1]
        UI.text(tab[2], tx, y + pad, tabW, s(28), sel and UI.color("text", 255 * a) or UI.color("muted", 255 * a), "bold", 13, "center", "center")
        UI.rect(tx + s(10), y + pad + s(30), tabW - s(20), s(3), sel and UI.color("accent", 255 * a) or tocolor(255, 255, 255, 14 * a), 1)
        local id = tab[1]
        clicks[#clicks + 1] = { tx, y + pad, tabW, s(34), function()
            if login.tab ~= id then login.tab = id login.message = nil fPass2.text = "" sound("click", 0.4) end
        end }
    end

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

    -- lembrar
    local cb = s(18)
    UI.rect(x + pad, fy + s(4), cb, cb, login.remember and UI.color("accent", 255 * a) or tocolor(255, 255, 255, 16 * a), s(5))
    if login.remember then UI.text("v", x + pad, fy + s(4), cb, cb, tocolor(8, 12, 18, 255 * a), "bold", 10, "center", "center") end
    UI.text("Manter conectado neste computador", x + pad + cb + s(10), fy, w, s(26), UI.color("muted", 255 * a), "regular", 10, "left", "center")
    clicks[#clicks + 1] = { x + pad, fy, w - pad * 2, s(26), function() login.remember = not login.remember sound("click", 0.3) end }
    fy = fy + s(40)

    -- botão principal
    local label = login.busy and "AGUARDE..." or (login.tab == "register" and "CRIAR CONTA" or "ENTRAR")
    UI.button("login_submit", label, x + pad, fy, w - pad * 2, s(48), { kind = "primary", size = 12, alpha = a, disabled = login.busy })
    clicks[#clicks + 1] = { x + pad, fy, w - pad * 2, s(48), submit }
    fy = fy + s(58)
    UI.button("login_guest", "Jogar como convidado", x + pad, fy, w - pad * 2, s(36), { kind = "outline", size = 10, alpha = a, disabled = login.busy })
    clicks[#clicks + 1] = { x + pad, fy, w - pad * 2, s(36), guest }
    fy = fy + s(46)

    -- mensagem
    if login.message then
        local col = login.msgType == "error" and "danger" or (login.msgType == "success" and "accent" or "muted")
        UI.text(login.message, x + pad, fy, w - pad * 2, s(36), UI.color(col, 255 * a), "medium", 10, "center", "center", false, true)
    end
    UI.text("ENTER confirma · TAB troca de campo", x, y + h - s(28), w, s(16), UI.color("muted", 120 * a), "regular", 8, "center", "center")
end

local function onClick(button, state)
    if button ~= "left" or state ~= "down" or not login.open then return end
    for _, c in ipairs(clicks) do
        if UI.isMouseIn(c[1], c[2], c[3], c[4]) then c[5]() return end
    end
end

local function show()
    if login.open then return end
    login.open = true
    login.tick = getTickCount()
    login.camTick = getTickCount()
    login.busy = false
    UI.setPanelOpen(PANEL, true)
    showCursor(true)
    if not RENDER_ON then RENDER_ON = true addEventHandler("onClientRender", root, render) end
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
        sound("levelup", 0.5)
        setTimer(hide, 500, 1)
        fPass.text, fPass2.text = "", ""
    else
        setMessage(message, "error")
        sound("error", 0.5)
        -- credenciais salvas inválidas: limpa para não repetir
        if message and message:find("Senha incorreta") then clearCredentials() end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    triggerServerEvent("login:ready", localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if login.open then hide() end
end)
