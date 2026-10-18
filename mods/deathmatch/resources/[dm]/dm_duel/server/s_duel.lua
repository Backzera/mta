--[[
    Duelo X1: pedidos, aceite, salas privadas (dimensão própria), rodadas e resultado.
]]

local core = exports.dm_core
local CFG
local requests   = {}  -- id -> { from, to, weaponKey, rounds, expires, timer }
local duels      = {}  -- id -> duel
local playerDuel = {}  -- player -> duelId
local outgoing   = {}  -- player -> requestId
local nextId     = 0

local function cfg()
    if not CFG then CFG = core:getConfig() end
    return CFG
end

local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end

local function notify(p, text, t, title)
    core:notifyPlayer(p, text, t or "info", title)
end

local function weaponSet(key)
    for _, set in ipairs(core:getDuelWeaponSets()) do
        if set.key == key then return set end
    end
    return nil
end

local function both(duel) return { duel.p1, duel.p2 } end
local function opponent(duel, p) return duel.p1 == p and duel.p2 or duel.p1 end

local function killTimerSafe(t) if t and isTimer(t) then killTimer(t) end end

addEvent("dm:onPlayerArenaChange")

-- Cópia do mapa X1 na dimensão privada do duelo (se dm_maps estiver rodando e houver mapa)
local function createDuelMap(duel)
    local res = getResourceFromName("dm_maps")
    if not res or getResourceState(res) ~= "running" then return nil end
    local ok, parent = pcall(function() return exports.dm_maps:createArenaMapCopy("x1", duel.dim) end)
    if ok and isElement(parent) then return parent end
    return nil
end

-- ---------------- Pedidos ----------------

local function removeRequest(id, reason, silentFrom)
    local r = requests[id]
    if not r then return end
    killTimerSafe(r.timer)
    requests[id] = nil
    if isElement(r.from) and outgoing[r.from] == id then outgoing[r.from] = nil end
    if isElement(r.to) then triggerClientEvent(r.to, "duel:requestRemoved", resourceRoot, id, reason) end
    if isElement(r.from) and not silentFrom then triggerClientEvent(r.from, "duel:outgoingRemoved", resourceRoot, id, reason) end
end

addEvent("duel:request", true)
addEventHandler("duel:request", root, function(target, weaponKey, rounds)
    local from = client
    if from ~= source then return end
    if not getElementData(from, "dm:ready") then return end
    if not isElement(target) or getElementType(target) ~= "player" then notify(from, "Jogador inválido.", "error") return end
    if target == from then notify(from, "Você não pode desafiar a si mesmo.", "warn") return end
    if not getElementData(target, "dm:ready") then notify(from, "Esse jogador ainda não entrou no jogo.", "warn") return end
    if playerDuel[from] then notify(from, "Você já está em um duelo.", "warn") return end
    if playerDuel[target] then notify(from, nick(target) .. " já está em um duelo.", "warn") return end
    if getElementData(from, "dm:managed") then notify(from, "Saia da partida ranqueada antes de duelar.", "warn") return end
    if getElementData(target, "dm:managed") then notify(from, nick(target) .. " está em uma partida ranqueada.", "warn") return end
    local set = weaponSet(weaponKey)
    if not set then notify(from, "Conjunto de armas inválido.", "error") return end
    rounds = tonumber(rounds) or 1
    if rounds ~= 1 and rounds ~= 3 and rounds ~= 5 then rounds = 1 end

    -- cancela pedido anterior do mesmo remetente
    if outgoing[from] then removeRequest(outgoing[from], "replaced", true) end

    nextId = nextId + 1
    local id = nextId
    local ttl = cfg().duelRequestTTL or 25000
    requests[id] = { from = from, to = target, weaponKey = weaponKey, rounds = rounds, expires = getTickCount() + ttl }
    outgoing[from] = id
    requests[id].timer = setTimer(function()
        if requests[id] then
            if isElement(requests[id].from) then notify(requests[id].from, "Seu desafio para " .. (isElement(requests[id].to) and nick(requests[id].to) or "?") .. " expirou.", "warn", "Duelo") end
            removeRequest(id, "expired")
        end
    end, ttl, 1)

    triggerClientEvent(target, "duel:incoming", resourceRoot, id, nick(from), set.name, rounds, ttl, from)
    triggerClientEvent(from, "duel:outgoing", resourceRoot, id, nick(target), set.name, rounds, ttl)
    notify(target, ("%s te desafiou: %s · primeiro a %d. Pressione Y para aceitar ou N para recusar."):format(nick(from), set.name, rounds), "info", "Desafio de duelo")
    notify(from, ("Desafio enviado para %s."):format(nick(target)), "success", "Duelo")
end)

addEvent("duel:cancel", true)
addEventHandler("duel:cancel", root, function(id)
    local r = requests[id]
    if r and r.from == client then
        if isElement(r.to) then notify(r.to, nick(r.from) .. " cancelou o desafio.", "warn", "Duelo") end
        removeRequest(id, "cancelled")
    end
end)

-- ---------------- Duelo ----------------

local function duelSpots()
    local x1 = core:getArena("x1")
    local spawns, source = core:getArenaSpawns("x1")
    if source == "map" and spawns and #spawns >= 2 then
        local i = math.random(#spawns)
        local j = math.random(#spawns - 1)
        if j >= i then j = j + 1 end
        return { spawns[i], spawns[j] }
    end
    if x1 and x1.duelSpots and #x1.duelSpots > 0 then
        local pair = x1.duelSpots[math.random(#x1.duelSpots)]
        if math.random(2) == 1 then return { pair[1], pair[2] } end
        return { pair[2], pair[1] }
    end
    spawns = spawns or x1.spawns
    return { spawns[1], spawns[2] or spawns[1] }
end

local function sendState(duel, event, ...)
    for _, p in ipairs(both(duel)) do
        if isElement(p) then
            local opp = opponent(duel, p)
            triggerClientEvent(p, event, resourceRoot, duel.score[p] or 0, duel.score[opp] or 0, ...)
        end
    end
end

local function startRound(duel)
    if not duels[duel.id] then return end
    duel.round = duel.round + 1
    duel.state = "countdown"
    local spots = duelSpots()
    local set = weaponSet(duel.weaponKey)
    local players = both(duel)
    for i, p in ipairs(players) do
        if isElement(p) then
            core:spawnPlayerInArena(p, {
                spawn = spots[i], weapons = set.weapons, dimension = duel.dim,
                armor = cfg().duelArmor or 0, freeze = false, protect = false,
            })
            setElementFrozen(p, true)
            setElementData(p, "dm:protected", true)
        end
    end
    local seconds = cfg().duelCountdown or 3
    sendState(duel, "duel:round", duel.round, seconds)
    killTimerSafe(duel.timer)
    duel.timer = setTimer(function()
        if not duels[duel.id] then return end
        duel.state = "fight"
        for _, p in ipairs(both(duel)) do
            if isElement(p) then
                setElementFrozen(p, false)
                setElementData(p, "dm:protected", false)
            end
        end
        sendState(duel, "duel:fight")
    end, seconds * 1000, 1)
end

local function endDuel(duel, winner, reason, skipReturn)
    if not duels[duel.id] then return end
    duels[duel.id] = nil
    killTimerSafe(duel.timer)
    if duel.mapRoot and isElement(duel.mapRoot) then
        local rootEl = duel.mapRoot
        setTimer(function() if isElement(rootEl) then destroyElement(rootEl) end end, 4000, 1)
    end
    local loser = winner and opponent(duel, winner) or nil
    local rpCfg = core:getRpConfig()
    local eco = core:getEconomyConfig()
    local winName = isElement(winner) and nick(winner) or "?"
    local loseName = isElement(loser) and nick(loser) or "?"
    local set = weaponSet(duel.weaponKey)

    for _, p in ipairs(both(duel)) do
        playerDuel[p] = nil
        if isElement(p) then
            setElementData(p, "dm:inDuel", false)
            setElementFrozen(p, false)
            local won = p == winner
            local rpDelta = 0
            if won then
                core:addPlayerStat(p, "duels_won", 1)
                rpDelta = rpCfg.duelWin or 5
                core:addPlayerStat(p, "rp", rpDelta)
                core:addMoney(p, eco.duelWin or 500, "Vitória no X1")
            elseif winner then
                core:addPlayerStat(p, "duels_lost", 1)
                rpDelta = rpCfg.duelLoss or -3
                core:addPlayerStat(p, "rp", rpDelta)
            end
            local opp = opponent(duel, p)
            triggerClientEvent(p, "duel:end", resourceRoot, won, duel.score[p] or 0, duel.score[opp] or 0, rpDelta, reason, eco.duelWin or 500)
            if p ~= skipReturn then
                local back = duel.prevArena[p] or "x1"
                if not core:getArena(back) then back = "x1" end
                setTimer(function()
                    if isElement(p) and not playerDuel[p] then
                        core:setPlayerArena(p, back, true)
                    end
                end, 2500, 1)
            end
        end
    end

    if winner then
        local msg = ("#F5C451✦ X1 #8FA39A» #FFFFFF%s #8B93A7venceu #FFFFFF%s #8B93A7por #FFFFFF%d x %d #8B93A7(%s)%s"):format(
            winName, loseName, duel.score[winner] or 0, duel.score[loser] or 0, set and set.name or "?",
            reason == "forfeit" and " #FFB547— W.O." or "")
        outputChatBox(msg, root, 255, 255, 255, true)
        -- notificação para todo o servidor com o placar
        triggerClientEvent(root, "dm:notify", resourceRoot,
            ("%s venceu %s por %d x %d (%s)%s"):format(winName, loseName, duel.score[winner] or 0, duel.score[loser] or 0, set and set.name or "?", reason == "forfeit" and " — W.O." or ""),
            "info", "Duelo X1")
    end
end

local function startDuel(from, to, weaponKey, rounds)
    nextId = nextId + 1
    local id = nextId
    local duel = {
        id = id, p1 = from, p2 = to, weaponKey = weaponKey, target = rounds,
        dim = 60000 + (id % 5000), round = 0, state = "countdown",
        score = { [from] = 0, [to] = 0 },
        prevArena = { [from] = getElementData(from, "dm:arena"), [to] = getElementData(to, "dm:arena") },
    }
    duels[id] = duel
    playerDuel[from] = id
    playerDuel[to] = id
    -- sala privada: cópia do mapa X1 nessa dimensão; sem mapa, usa a própria dimensão da arena
    duel.mapRoot = createDuelMap(duel)
    if not duel.mapRoot then
        local x1 = core:getArena("x1")
        duel.dim = x1 and x1.dimension or duel.dim
    end
    local set = weaponSet(weaponKey)
    for _, p in ipairs(both(duel)) do
        setElementData(p, "dm:inDuel", id)
        setElementData(p, "dm:arena", "x1")   -- aparece como X1 no HUD/placar
        setElementData(p, "dm:streak", 0)
        -- cancela pedidos pendentes envolvendo os dois
        for rid, r in pairs(requests) do
            if r.from == p or r.to == p then removeRequest(rid, "started") end
        end
    end
    triggerClientEvent(from, "duel:start", resourceRoot, nick(to), set.name, rounds, to)
    triggerClientEvent(to, "duel:start", resourceRoot, nick(from), set.name, rounds, from)
    startRound(duel)
end

addEvent("duel:respond", true)
addEventHandler("duel:respond", root, function(id, accept)
    local r = requests[id]
    if not r or r.to ~= source then return end
    if client and client ~= source then return end
    local from, to = r.from, r.to
    if not accept then
        if isElement(from) then notify(from, nick(to) .. " recusou o desafio.", "warn", "Duelo") end
        removeRequest(id, "declined")
        return
    end
    if not isElement(from) then removeRequest(id, "offline") notify(to, "O desafiante saiu.", "error") return end
    if playerDuel[from] or playerDuel[to] then removeRequest(id, "busy") notify(to, "Um dos jogadores já está em duelo.", "warn") return end
    if getElementData(from, "dm:managed") or getElementData(to, "dm:managed") then removeRequest(id, "busy") notify(to, "Um dos jogadores está em partida ranqueada.", "warn") return end
    removeRequest(id, "accepted", true)
    startDuel(from, to, r.weaponKey, r.rounds)
end)

-- Morte em duelo
addEventHandler("onPlayerWasted", root, function(ammo, killer)
    local id = playerDuel[source]
    local duel = id and duels[id]
    if not duel then return end
    if duel.state ~= "fight" then return end
    duel.state = "between"
    local winnerRound = opponent(duel, source)
    duel.score[winnerRound] = (duel.score[winnerRound] or 0) + 1
    sendState(duel, "duel:score", isElement(killer) and nick(killer) or nick(winnerRound))
    killTimerSafe(duel.timer)
    if duel.score[winnerRound] >= duel.target then
        duel.timer = setTimer(function() endDuel(duel, winnerRound, "win") end, 1500, 1)
    else
        duel.timer = setTimer(function() startRound(duel) end, 2500, 1)
    end
end)

-- Saiu da arena durante o duelo (F2, /lobby, /arena) -> W.O.
addEventHandler("dm:onPlayerArenaChange", root, function(prevId, newId)
    local id = playerDuel[source]
    local duel = id and duels[id]
    if not duel then return end
    endDuel(duel, opponent(duel, source), "forfeit", source)
end)

addEventHandler("onPlayerQuit", root, function()
    local id = playerDuel[source]
    local duel = id and duels[id]
    if duel then endDuel(duel, opponent(duel, source), "forfeit", source) end
    for rid, r in pairs(requests) do
        if r.from == source or r.to == source then removeRequest(rid, "offline") end
    end
    playerDuel[source] = nil
    outgoing[source] = nil
end)

-- /duelo <jogador>
addCommandHandler("duelo", function(player, cmd, target)
    if not getElementData(player, "dm:ready") then return end
    local other = target and core:findPlayer(target) or nil
    if target and not other then notify(player, "Jogador não encontrado.", "error") return end
    triggerClientEvent(player, "duel:openPanel", resourceRoot, other or false)
end)

addCommandHandler("aceitar", function(player)
    for id, r in pairs(requests) do
        if r.to == player then triggerEvent("duel:respond", player, id, true) return end
    end
    notify(player, "Você não tem desafios pendentes.", "warn")
end)

addCommandHandler("recusar", function(player)
    for id, r in pairs(requests) do
        if r.to == player then triggerEvent("duel:respond", player, id, false) return end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for id, duel in pairs(duels) do
        duels[id] = nil
        if duel.mapRoot and isElement(duel.mapRoot) then destroyElement(duel.mapRoot) end
        for _, p in ipairs(both(duel)) do
            if isElement(p) then
                setElementData(p, "dm:inDuel", false)
                setElementFrozen(p, false)
                core:setPlayerArena(p, "x1", true)
            end
        end
    end
end)
