--[[
    Arenas: entrada, spawn, armas, proteção de spawn e respawn.
    Cada arena é uma dimensão. O estado do jogador fica em elementData:
      dm:arena      id da arena atual
      dm:protected  true durante a proteção de spawn
      dm:inDuel     id do duelo (gerido por dm_duel) — pausa o respawn automático
      dm:ready      jogador já passou pelo login
]]

local arenaSpawns  = {}   -- id -> lista de spawns em uso
local spawnSource  = {}   -- id -> "config" | "map"
local pdata        = {}   -- player -> { respawnTimer, protectTimer, freezeTimer, lastSpawn, streak }

local function getData(player)
    if not pdata[player] then
        pdata[player] = { streak = 0, lastSpawn = 0, spawnSerial = 0, collisionFreeze = false }
    end
    return pdata[player]
end

local function killTimerSafe(t)
    if t and isTimer(t) then killTimer(t) end
end

-- Spawns padrão da config; dm_maps pode sobrescrever com setArenaSpawns()
local function initSpawns()
    for _, arena in ipairs(DM.arenas) do
        arenaSpawns[arena.id] = arena.spawns
        spawnSource[arena.id] = "config"
        setElementData(root, "dm:spawnSource:" .. arena.id, "config")
    end
end

function setArenaSpawns(arenaId, spawns, source)
    if not DM.getArena(arenaId) or type(spawns) ~= "table" or #spawns == 0 then return false end
    arenaSpawns[arenaId] = spawns
    spawnSource[arenaId] = source or "map"
    setElementData(root, "dm:spawnSource:" .. arenaId, spawnSource[arenaId])
    outputDebugString(("[dm_core] Arena '%s': %d spawns (%s)"):format(arenaId, #spawns, spawnSource[arenaId]))
    return true
end

local function pickSpawn(player, arenaId)
    local list = arenaSpawns[arenaId] or DM.getArena(arenaId).spawns
    local data = getData(player)
    local idx = math.random(#list)
    if #list > 1 and idx == data.lastSpawn then
        idx = (idx % #list) + 1
    end
    data.lastSpawn = idx
    return list[idx]
end

local function getPlayerSkin(player)
    local skin = tonumber(getElementData(player, "dm:skin"))
    if skin then return skin end
    skin = DM.skins[math.random(#DM.skins)]
    setElementData(player, "dm:skin", skin)
    return skin
end

-- Entrega SOMENTE as armas da arena e guarda o loadout (para recarga ao trocar de arma)
function giveArenaWeapons(player, weapons)
    if not isElement(player) then return end
    takeAllWeapons(player)
    local loadout = {}
    for i, w in ipairs(weapons or {}) do
        giveWeapon(player, w[1], w[2], i == 1)
        loadout[tostring(w[1])] = w[2]
    end
    setElementData(player, "dm:loadout", loadout, false)
    if #(weapons or {}) == 0 then
        setPedWeaponSlot(player, 0)
    end
end

-- Recarrega uma arma (ou todas) para a munição do loadout
function refillPlayerWeapons(player, weaponId)
    if not isElement(player) then return end
    local loadout = getElementData(player, "dm:loadout")
    if type(loadout) ~= "table" then return end
    for id, ammo in pairs(loadout) do
        id = tonumber(id)
        if id and id > 1 and (not weaponId or weaponId == id) then
            local clip = tonumber(getWeaponProperty(id, "poor", "maximum_clip_ammo")) or 0
            setWeaponAmmo(player, id, ammo, math.min(clip, ammo))
        end
    end
end

-- Tempo de respawn (VIP / perk de respawn rápido)
function getPlayerRespawnDelay(player)
    if getElementData(player, "dm:managed") then return DM.ranked.respawn end
    if isPlayerVip(player) > 0 or playerHasPerk(player, "fastrespawn") then
        return DM.server.respawnDelayVip
    end
    return DM.server.respawnDelay
end

local function setProtected(player, ms)
    local data = getData(player)
    killTimerSafe(data.protectTimer)
    setElementData(player, "dm:protected", true)
    data.protectTimer = setTimer(function()
        if isElement(player) then
            setElementData(player, "dm:protected", false)
        end
    end, ms, 1)
end

function removeSpawnProtection(player)
    if not isElement(player) then return end
    local data = getData(player)
    killTimerSafe(data.protectTimer)
    setElementData(player, "dm:protected", false)
end

--[[
    spawnPlayerInArena(player [, opts])
    opts = {
        spawn     = { x, y, z, rot },  -- posição específica (padrão: aleatória da arena)
        weapons   = { {id, ammo}, ... },-- armas (padrão: armas da arena)
        dimension = número,             -- dimensão (padrão: a da arena)
        armor     = número,             -- colete (padrão: arena.armor)
        freeze    = bool,               -- congelar brevemente (padrão: true)
        protect   = bool,               -- proteção de spawn (padrão: true)
    }
]]
function spawnPlayerInArena(player, opts)
    if not isElement(player) then return false end
    local arena = getPlayerArena(player)
    if not arena then return false end
    opts = opts or {}
    local data = getData(player)
    killTimerSafe(data.respawnTimer)
    killTimerSafe(data.freezeTimer)

    local sp = opts.spawn or pickSpawn(player, arena.id)
    local x, y, z, rot = sp[1], sp[2], sp[3], sp[4] or 0
    local dim = opts.dimension or arena.dimension

    data.spawnSerial = (data.spawnSerial or 0) + 1
    local spawnSerial = data.spawnSerial
    data.collisionFreeze = opts.freeze ~= false

    spawnPlayer(player, x, y, z + 0.5, rot, getPlayerSkin(player), 0, dim, opts.team or getPlayerTeam(player) or nil)
    setElementInterior(player, 0)
    setElementDimension(player, dim)
    setCameraInterior(player, 0)
    setCameraTarget(player, player)
    fadeCamera(player, true, 0.6)
    setElementHealth(player, 100)
    setPedArmor(player, opts.armor or arena.armor or 0)
    giveArenaWeapons(player, opts.weapons or arena.weapons)

    -- Mantém congelado enquanto o cliente espera a colisão/streaming da arena.
    -- O cliente libera antes via dm:spawnCollisionReady. O timer é só um fallback
    -- para nunca deixar o jogador preso se o cliente não responder.
    if opts.freeze ~= false then
        setElementFrozen(player, true)
        local fallback = math.max(tonumber(DM.server.spawnFreeze) or 900, 7000)
        data.freezeTimer = setTimer(function()
            if isElement(player) and data.spawnSerial == spawnSerial and data.collisionFreeze then
                data.collisionFreeze = false
                setElementFrozen(player, false)
                outputDebugString(("[dm_core] Timeout esperando colisão da arena '%s' para %s"):format(arena.id, getPlayerName(player)), 2)
            end
        end, fallback, 1)
    end

    -- Proteção contra spawn-kill
    if opts.protect ~= false then
        if arena.safe then
            setElementData(player, "dm:protected", true)
        else
            setProtected(player, opts.protection or (arena.type == "ranked" and DM.ranked.protection) or DM.server.spawnProtection)
        end
    end

    triggerClientEvent(player, "dm:onSpawn", player, arena.id, spawnSerial, data.collisionFreeze)
    return true
end

-- O cliente confirma que os objetos/chão da arena já estão carregados.
-- O serial impede uma confirmação atrasada de liberar um spawn mais novo.
addEvent("dm:spawnCollisionReady", true)
addEventHandler("dm:spawnCollisionReady", root, function(serial)
    if client ~= source then return end
    local data = getData(source)
    if tonumber(serial) ~= tonumber(data.spawnSerial) then return end
    if not data.collisionFreeze then return end

    data.collisionFreeze = false
    killTimerSafe(data.freezeTimer)
    data.freezeTimer = nil
    if isElementFrozen(source) then
        setElementFrozen(source, false)
    end
end)

function getArenaSpawns(arenaId)
    return arenaSpawns[arenaId], spawnSource[arenaId]
end

-- Coloca o jogador em uma arena (e nasce nela)
function setPlayerArena(player, arenaId, silent, noSpawn)
    local arena = DM.getArena(arenaId)
    if not isElement(player) or not arena then return false end
    local prevId = getElementData(player, "dm:arena")
    local data = getData(player)
    killTimerSafe(data.respawnTimer)
    data.streak = 0
    setElementData(player, "dm:streak", 0)
    setElementData(player, "dm:arena", arenaId)
    setElementData(player, "dm:inDuel", false)
    setElementData(player, "dm:managed", false)
    setElementData(player, "dm:noReward", false)

    -- Permite que outros recursos (dm_duel, dm_ranked) reajam antes do spawn
    triggerEvent("dm:onPlayerArenaChange", player, prevId, arenaId)

    if arena.type == "ranked" then
        -- dm_ranked cuida do spawn e das partidas
        local res = getResourceFromName("dm_ranked")
        if res and getResourceState(res) == "running" then
            triggerEvent("ranked:join", player, arenaId)
        else
            notifyPlayer(player, "As partidas ranqueadas estão desativadas no momento.", "warn")
            return setPlayerArena(player, "lobby", true)
        end
    elseif not noSpawn then
        spawnPlayerInArena(player)
    end
    triggerClientEvent(player, "dm:onEnterArena", player, arenaId, prevId)

    if not silent then
        local hex = DM.rgbToHex(unpack(arena.color))
        if arena.type == "lobby" then
            notifyPlayer(player, "Você voltou ao lobby. Pressione F2 para escolher uma arena.", "info", "Lobby")
        elseif arena.type == "ranked" then
            notifyPlayer(player, arena.desc, "success", arena.name)
        else
            notifyPlayer(player, arena.desc, "success", arena.name)
            sendServerMessage(player, ("Você entrou na %s%s#FFFFFF. Armas: #8B93A7%s"):format(hex, arena.name, DM.arenaWeaponList(arena)))
        end
    end
    return true
end
addEvent("dm:onPlayerArenaChange")
addEvent("ranked:join")

-- Pedido do cliente (painel F2 / comandos)
addEvent("dm:requestArena", true)
addEventHandler("dm:requestArena", root, function(arenaId)
    if client ~= source then return end
    if not getElementData(source, "dm:ready") then return end
    local arena = DM.getArena(arenaId)
    if not arena then return end
    if getElementData(source, "dm:arena") == arenaId and not isPedDead(source) then
        notifyPlayer(source, "Você já está nessa arena.", "warn")
        return
    end
    setPlayerArena(source, arenaId)
end)

-- Jogador pronto (após login) -> lobby
addEvent("dm:playerReady")
addEventHandler("dm:playerReady", root, function()
    local player = source
    if not isElement(player) then return end
    setElementData(player, "dm:ready", true)
    if not getPlayerStats(player) then loadPlayerStats(player) end
    setPlayerArena(player, "lobby", true)
    notifyPlayer(player, "Bem-vindo ao " .. DM.server.fullName .. "! Pressione F2 para escolher uma arena.", "success", "Bem-vindo")
    sendServerMessage(player, "#969BB4Teclas: #FFFFFFF1 #969BB4ajuda · #FFFFFFF2 #969BB4arenas · #FFFFFFF3 #969BB4duelo · #FFFFFFF4 #969BB4loja · #FFFFFFF5 #969BB4ranqueadas · #FFFFFFF6 #969BB4clã · #FFFFFFTAB #969BB4placar · #FFFFFF/emojis")
end)

local function isLoginRunning()
    local res = getResourceFromName("dm_login")
    return res and getResourceState(res) == "running"
end

addEventHandler("onPlayerJoin", root, function()
    local player = source
    setElementData(player, "dm:ready", false)
    setElementData(player, "dm:arena", false)
    setElementData(player, "dm:inDuel", false)
    setElementData(player, "dm:protected", false)
    setElementData(player, "dm:streak", 0)
    setPlayerNametagShowing(player, false)
    if not isLoginRunning() then
        setTimer(function()
            if isElement(player) and not getElementData(player, "dm:ready") then
                triggerEvent("dm:playerReady", player)
            end
        end, 800, 1)
    end
end)

-- Respawn automático após a morte (dm_duel cuida dos duelos)
addEventHandler("onPlayerWasted", root, function()
    local player = source
    local arena = getPlayerArena(player)
    if not arena then return end
    local data = getData(player)
    killTimerSafe(data.respawnTimer)
    if getElementData(player, "dm:inDuel") or getElementData(player, "dm:managed") then return end
    data.respawnTimer = setTimer(function()
        if isElement(player) and not getElementData(player, "dm:inDuel") and not getElementData(player, "dm:managed") and getPlayerArena(player) then
            spawnPlayerInArena(player)
        end
    end, getPlayerRespawnDelay(player), 1)
end)

addEventHandler("onPlayerQuit", root, function()
    local data = pdata[source]
    if data then
        killTimerSafe(data.respawnTimer)
        killTimerSafe(data.protectTimer)
        killTimerSafe(data.freezeTimer)
    end
    pdata[source] = nil
end)

-- Atirar remove a proteção de spawn (evita abuso)
addEvent("dm:breakProtection", true)
addEventHandler("dm:breakProtection", root, function()
    if client ~= source then return end
    local arena = getPlayerArena(source)
    if arena and not arena.safe then removeSpawnProtection(source) end
end)

-- Rede de segurança: o cliente detectou que caiu no vazio logo após nascer
addEvent("dm:badSpawn", true)
addEventHandler("dm:badSpawn", root, function()
    if client ~= source then return end
    local arena = getPlayerArena(source)
    if not arena or getElementData(source, "dm:inDuel") then return end
    local data = getData(source)
    local now = getTickCount()
    data.badSpawns = (data.badSpawnTick and now - data.badSpawnTick < 20000) and (data.badSpawns or 0) + 1 or 1
    data.badSpawnTick = now
    if data.badSpawns > 3 then return end -- evita loop
    if getElementData(source, "dm:managed") then return end -- partidas ranqueadas cuidam do próprio spawn
    local list = arenaSpawns[arena.id] or arena.spawns
    outputServerLog(("[dm_core] %s caiu no vazio na arena %s — reposicionando (spawn âncora)"):format(getPlayerVisibleName(source), arena.id))
    spawnPlayerInArena(source, { spawn = list[1], dimension = getElementDimension(source) })
end)

-- Streak (usado por s_kills)
function getPlayerStreak(player) return getData(player).streak end
function setPlayerStreak(player, value)
    getData(player).streak = value
    setElementData(player, "dm:streak", value)
end

addEventHandler("onResourceStart", resourceRoot, function()
    initSpawns()
    -- Reinício com jogadores online
    for _, player in ipairs(getElementsByType("player")) do
        setPlayerNametagShowing(player, false)
        if getElementData(player, "dm:ready") or not isLoginRunning() then
            triggerEvent("dm:playerReady", player)
        end
    end
end)
