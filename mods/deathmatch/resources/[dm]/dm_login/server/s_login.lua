--[[
    Login / registro usando o sistema de contas do MTA.
    Após autenticar dispara "dm:playerReady" para o dm_core.
    Requer que resource.dm_login esteja no grupo Admin da ACL (function.addAccount).
]]

local core = exports.dm_core
local attempts = {} -- player -> { count, tick } (anti brute-force)

local function fail(player, msg)
    triggerClientEvent(player, "login:result", resourceRoot, false, msg)
end

local function validUser(user)
    return type(user) == "string" and #user >= 3 and #user <= 20 and user:match("^[%w_]+$") ~= nil
end

local function validPass(pass)
    return type(pass) == "string" and #pass >= 4 and #pass <= 32
end

local function tooMany(player)
    local a = attempts[player]
    local now = getTickCount()
    if a and now - a.tick < 60000 and a.count >= 6 then return true end
    if not a or now - a.tick >= 60000 then attempts[player] = { count = 0, tick = now } end
    attempts[player].count = attempts[player].count + 1
    return false
end

local function finish(player, account, remember, pass, message)
    if not account or isGuestAccount(account) then return fail(player, "Entre ou crie uma conta para jogar.") end
    setElementData(player, "dm:guest", false)
    triggerClientEvent(player, "login:result", resourceRoot, true, message, remember and pass or nil)
    triggerEvent("dm:playerReady", player)
end

addEvent("login:ready", true)
addEventHandler("login:ready", root, function()
    if client ~= source then return end
    if getElementData(source, "dm:ready") then return end
    -- câmera sobre o mapa da Arena X1 (fica na dimensão da arena para o mapa aparecer)
    local x1 = core:getArena("x1")
    setElementDimension(source, x1 and x1.dimension or 0)
    setCameraInterior(source, 0)
    setCameraMatrix(source, -1335.0, -905.0, 1010.0, -1368.0, -958.0, 994.0)
    fadeCamera(source, true, 1.0)
    triggerClientEvent(source, "login:show", resourceRoot)
end)

addEvent("login:attempt", true)
addEventHandler("login:attempt", root, function(user, pass, remember)
    local player = client
    if player ~= source or getElementData(player, "dm:ready") then return end
    if tooMany(player) then return fail(player, "Muitas tentativas. Aguarde um minuto.") end
    if not validUser(user) then return fail(player, "Usuário inválido (3-20 letras, números ou _).") end
    if not validPass(pass) then return fail(player, "Senha inválida (4-32 caracteres).") end
    local account = getAccount(user)
    if not account then return fail(player, "Essa conta não existe. Registre-se!") end
    if getAccountPlayer(account) then return fail(player, "Essa conta já está em uso.") end
    if not getAccount(user, pass) then return fail(player, "Senha incorreta.") end
    if not logIn(player, account, pass) then return fail(player, "Falha ao entrar. Tente novamente.") end
    setAccountData(account, "dm.lastSerial", getPlayerSerial(player))
    finish(player, account, remember, pass, "Bem-vindo de volta, " .. user .. "!")
end)

addEvent("login:register", true)
addEventHandler("login:register", root, function(user, pass, remember)
    local player = client
    if player ~= source or getElementData(player, "dm:ready") then return end
    if tooMany(player) then return fail(player, "Muitas tentativas. Aguarde um minuto.") end
    if not validUser(user) then return fail(player, "Usuário inválido (3-20 letras, números ou _).") end
    if not validPass(pass) then return fail(player, "A senha precisa ter de 4 a 32 caracteres.") end
    if getAccount(user) then return fail(player, "Esse usuário já existe.") end
    local account = addAccount(user, pass)
    if not account then
        outputServerLog("[dm_login] addAccount falhou — verifique se resource.dm_login está no grupo Admin da ACL.")
        return fail(player, "Não foi possível criar a conta (servidor sem permissão).")
    end
    setAccountData(account, "dm.registeredAt", getRealTime().timestamp)
    setAccountData(account, "dm.lastSerial", getPlayerSerial(player))
    if not logIn(player, account, pass) then return fail(player, "Conta criada, mas falhou ao entrar. Tente novamente.") end
    finish(player, account, remember, pass, "Conta criada! Bem-vindo, " .. user .. "!")
end)

addEvent("login:guest", true)
addEventHandler("login:guest", root, function()
    local player = client
    if player ~= source or getElementData(player, "dm:ready") then return end
    fail(player, "O acesso como convidado foi desativado. Entre ou crie uma conta para jogar.")
end)

addEventHandler("onPlayerQuit", root, function() attempts[source] = nil end)
