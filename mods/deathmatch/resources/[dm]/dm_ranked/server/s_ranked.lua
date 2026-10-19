--[[
    Partidas ranqueadas em MD3 (melhor de 3 rounds), em instâncias com dimensão própria.
    Fluxo: aquecimento (FFA, sem recompensas) -> completou 2*teamSize -> contagem (times formados por elo,
    escolha de papel: 1 sniper por time) -> round 1..3 (5 min, sem respawn; time eliminado perde o round;
    tempo esgotado -> MORTE SÚBITA: todos os vivos teleportados para uma área pequena cercada até sobrar um lado)
    -> primeiro a 2 rounds vence -> resultado (RP, $) -> volta ao aquecimento.
    Clã x clã usa o mesmo motor com times fixos (startClanMatch).
]]
local core = exports.dm_core
local MODES, CFG, RP, ECO
local instances = {}   -- id -> inst
local playerInst = {}  -- player -> inst
local pendingClan = {} -- player -> inst
local nextInstance = 0
local instanceCounter = {}
local TEAM_COLORS = { A = { 34, 230, 138 }, B = { 255, 181, 71 } }
local DEFAULT_SNIPER_LOADOUT = { { 34, 150 }, { 31, 600 } }

local function cfg()
    if not MODES then
        MODES = core:getRankedModes()
        CFG = core:getRankedConfig()
        RP = core:getRpConfig()
        ECO = core:getEconomyConfig()
    end
end
local function modeById(id)
    cfg()
    for _, m in ipairs(MODES) do if m.id == id then return m end end
end
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local function killTimerSafe(t) if t and isTimer(t) then killTimer(t) end end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function other(team) return team == "A" and "B" or "A" end
local function roundTime(inst) return inst.mode.roundTime or CFG.roundTime or 300 end
local function roundsToWin(inst) return CFG.roundsToWin or 2 end
local function usesRoles(inst) return inst.mode.roles == true end
local function aliveCount(inst, team)
    local n = 0
    for p in pairs(inst.teams[team]) do if isElement(p) and inst.alive[p] then n = n + 1 end end
    return n
end
local function sniperName(inst, team)
    local p = inst.sniperOf[team]
    return (p and isElement(p)) and nick(p) or false
end

-- ---------------- Estado para o cliente ----------------
local function stateFor(inst, player)
    local team = inst.teamOf[player]
    local st = {
        state = inst.state, mode = inst.mode.name, place = inst.mode.place, players = count(inst.players), needed = inst.mode.teamSize * 2,
        roundsA = inst.rounds.A, roundsB = inst.rounds.B, round = inst.round, roundsToWin = roundsToWin(inst), myTeam = team or false,
        nameA = inst.teamNames.A, nameB = inst.teamNames.B, clan = inst.fixedTeams == true, secondsLeft = 0, roundTime = roundTime(inst),
        aliveA = aliveCount(inst, "A"), aliveB = aliveCount(inst, "B"), lastRoundWinner = inst.lastRoundWinner or false,
        roles = usesRoles(inst) and { A = { sniper = sniperName(inst, "A") }, B = { sniper = sniperName(inst, "B") } } or false,
        myRole = usesRoles(inst) and (inst.roleOf[player] or (inst.rolePick[player] and inst.rolePick[player].role) or false) or false,
        rolePick = usesRoles(inst) and inst.state == "countdown" and team ~= nil,
        kills = inst.kills[player] or 0, deaths = inst.deaths[player] or 0,
    }
    local now = getTickCount()
    if inst.state == "countdown" and inst.countdownEnd then st.secondsLeft = math.max(0, math.ceil((inst.countdownEnd - now) / 1000)) end
    if inst.state == "round" and inst.roundEndTick then st.secondsLeft = math.max(0, math.ceil((inst.roundEndTick - now) / 1000)) end
    if inst.state == "sudden" and inst.suddenEndTick then st.secondsLeft = math.max(0, math.ceil((inst.suddenEndTick - now) / 1000)) end
    return st
end
local function broadcast(inst)
    for p in pairs(inst.players) do
        if isElement(p) then triggerClientEvent(p, "ranked:state", resourceRoot, stateFor(inst, p)) end
    end
end
local function notifyAll(inst, text, t) for p in pairs(inst.players) do if isElement(p) then core:notifyPlayer(p, text, t or "info", inst.mode.name) end end end

-- ---------------- Instâncias ----------------
local function createInstance(mode, fixedTeams)
    nextInstance = nextInstance + 1
    instanceCounter[mode.id] = ((instanceCounter[mode.id] or 0) % 99) + 1
    local inst = {
        id = nextInstance, mode = mode, dim = mode.dimension + instanceCounter[mode.id],
        state = "warmup", players = {}, teamOf = {}, teams = { A = {}, B = {} }, rounds = { A = 0, B = 0 }, round = 0,
        kills = {}, deaths = {}, alive = {}, roleOf = {}, rolePick = {}, sniperOf = {}, fixedTeams = fixedTeams or false, respawnTimers = {},
        teamNames = { A = "Time Verde", B = "Time Laranja" },
        teamElems = { A = createTeam("Ranked " .. nextInstance .. " A", unpack(TEAM_COLORS.A)), B = createTeam("Ranked " .. nextInstance .. " B", unpack(TEAM_COLORS.B)) },
    }
    for _, t in pairs(inst.teamElems) do setTeamFriendlyFire(t, false) end
    instances[inst.id] = inst
    return inst
end
local function destroySudden(inst)
    if inst.col and isElement(inst.col) then destroyElement(inst.col) end
    inst.col = nil
end
local function destroyInstance(inst)
    killTimerSafe(inst.timer)
    for _, t in pairs(inst.respawnTimers or {}) do killTimerSafe(t) end
    destroySudden(inst)
    for _, t in pairs(inst.teamElems) do if isElement(t) then destroyElement(t) end end
    instances[inst.id] = nil
end
local function findOpenInstance(mode)
    for _, inst in pairs(instances) do
        if inst.mode == mode and not inst.fixedTeams and inst.state == "warmup" and count(inst.players) < mode.teamSize * 2 then return inst end
    end
end
local function randomSpawn(list)
    if not list or #list == 0 then return { 0, 0, 5, 0 } end
    return list[math.random(#list)]
end
local function loadoutFor(inst, player)
    if usesRoles(inst) and inst.roleOf[player] == "sniper" then return inst.mode.sniperWeapons or CFG.sniperLoadout or DEFAULT_SNIPER_LOADOUT end
    return inst.mode.weapons
end
local function spawnWarmup(inst, player)
    core:spawnPlayerInArena(player, { spawn = randomSpawn(inst.mode.warmupSpawns), weapons = inst.mode.weapons, armor = inst.mode.armor, dimension = inst.dim })
end
local function spawnInTeam(inst, player, spawnList)
    local team = inst.teamOf[player]
    local list = spawnList or (team and inst.mode.teamSpawns[team]) or inst.mode.warmupSpawns
    core:spawnPlayerInArena(player, { spawn = randomSpawn(list), weapons = loadoutFor(inst, player), armor = inst.mode.armor, dimension = inst.dim,
        team = team and inst.teamElems[team] or nil, protection = CFG.protection })
    if team then setPlayerTeam(player, inst.teamElems[team]) end
end
local function killRespawn(inst, player)
    local t = inst.respawnTimers and inst.respawnTimers[player]
    if t and isTimer(t) then killTimer(t) end
    if inst.respawnTimers then inst.respawnTimers[player] = nil end
end
local function spectate(player, target)
    if isElement(player) then triggerClientEvent(player, "ranked:spectate", resourceRoot, target or false) end
end

-- ---------------- Papéis (1 sniper por time) ----------------
local function recomputeSnipers(inst)
    if not usesRoles(inst) then return end
    for _, team in ipairs({ "A", "B" }) do
        local best, bestTick = nil, math.huge
        for p in pairs(inst.teams[team]) do
            local pick = inst.rolePick[p]
            if isElement(p) and pick and pick.role == "sniper" and pick.tick < bestTick then best, bestTick = p, pick.tick end
        end
        inst.sniperOf[team] = best
    end
end
local function finalizeRoles(inst)
    inst.roleOf = {}
    if not usesRoles(inst) then return end
    recomputeSnipers(inst)
    for _, team in ipairs({ "A", "B" }) do
        if not inst.sniperOf[team] then
            -- ninguém escolheu: sorteia um
            local list = {}
            for p in pairs(inst.teams[team]) do if isElement(p) then list[#list + 1] = p end end
            if #list > 0 then inst.sniperOf[team] = list[math.random(#list)] end
        end
        for p in pairs(inst.teams[team]) do inst.roleOf[p] = (p == inst.sniperOf[team]) and "sniper" or "m4" end
        if inst.sniperOf[team] and isElement(inst.sniperOf[team]) then core:notifyPlayer(inst.sniperOf[team], "Você é o SNIPER do seu time: Sniper + M4.", "success", inst.mode.name) end
    end
end
addEvent("ranked:setRole", true)
addEventHandler("ranked:setRole", root, function(role)
    if client ~= source then return end
    local inst = playerInst[source]
    if not inst or not usesRoles(inst) or inst.state ~= "countdown" then return end
    local team = inst.teamOf[source]
    if not team then return end
    if role == "sniper" then
        if inst.sniperOf[team] and inst.sniperOf[team] ~= source and isElement(inst.sniperOf[team]) then
            core:notifyPlayer(source, ("%s já é o sniper do seu time."):format(nick(inst.sniperOf[team])), "warn", inst.mode.name)
            return
        end
        inst.rolePick[source] = { role = "sniper", tick = getTickCount() }
    else
        inst.rolePick[source] = { role = "m4", tick = getTickCount() }
    end
    recomputeSnipers(inst)
    broadcast(inst)
end)

-- ---------------- Times ----------------
local function formTeams(inst)
    if inst.fixedTeams then return end
    local list = {}
    for p in pairs(inst.players) do if isElement(p) then list[#list + 1] = p end end
    table.sort(list, function(a, b) return (tonumber(getElementData(a, "dm:rp")) or 0) > (tonumber(getElementData(b, "dm:rp")) or 0) end)
    inst.teams = { A = {}, B = {} }
    inst.teamOf = {}
    for i, p in ipairs(list) do
        local team = (i % 4 == 1 or i % 4 == 0) and "A" or "B"
        inst.teamOf[p] = team
        inst.teams[team][p] = true
    end
end
local function dissolveTeams(inst)
    inst.teams = { A = {}, B = {} }
    inst.teamOf = {}
    inst.roleOf, inst.rolePick, inst.sniperOf = {}, {}, {}
    for p in pairs(inst.players) do if isElement(p) then setPlayerTeam(p, nil) end end
end

-- ---------------- Rounds ----------------
local startRound, endRound, endMatch, checkStart

local function suddenDeath(inst)
    if inst.state ~= "round" then return end
    inst.state = "sudden"
    killTimerSafe(inst.timer)
    local sd = inst.mode.suddenDeath
    if sd then
        local c = sd.center
        inst.col = createColSphere(c[1], c[2], c[3], sd.radius or 18)
        setElementDimension(inst.col, inst.dim)
        addEventHandler("onColShapeLeave", inst.col, function(el)
            if getElementType(el) ~= "player" or playerInst[el] ~= inst or not inst.alive[el] then return end
            local team = inst.teamOf[el]
            local list = team and sd[team] or nil
            local sp = randomSpawn(list) or { c[1], c[2], c[3], 0 }
            setElementPosition(el, sp[1], sp[2], sp[3])
            core:notifyPlayer(el, "Morte súbita: fique dentro da área!", "warn", inst.mode.name)
        end)
        for p in pairs(inst.players) do
            if isElement(p) and inst.alive[p] then
                local team = inst.teamOf[p]
                local sp = randomSpawn(team and sd[team] or nil)
                setElementPosition(p, sp[1], sp[2], sp[3])
                if sp[4] then setPedRotation(p, sp[4]) end
                setElementFrozen(p, true)
                setTimer(function() if isElement(p) then setElementFrozen(p, false) end end, 1500, 1)
            end
        end
    end
    inst.suddenEndTick = getTickCount() + (CFG.suddenDeathMax or 90) * 1000
    inst.timer = setTimer(function()
        if not instances[inst.id] or inst.state ~= "sudden" then return end
        -- limite de segurança: mais vivos vence; empate -> mais kills no round; senão sorteio
        local a, b = aliveCount(inst, "A"), aliveCount(inst, "B")
        local winner = a > b and "A" or (b > a and "B" or nil)
        if not winner then
            local ka, kb = inst.roundKills.A, inst.roundKills.B
            winner = ka > kb and "A" or (kb > ka and "B" or (math.random(2) == 1 and "A" or "B"))
        end
        endRound(inst, winner)
    end, (CFG.suddenDeathMax or 90) * 1000, 1)
    notifyAll(inst, "Tempo esgotado! MORTE SÚBITA: todos para a arena final. Quem sobrar vence o round.", "warn")
    broadcast(inst)
end

startRound = function(inst, n)
    if not instances[inst.id] then return end
    inst.round = n
    inst.state = "round"
    inst.lastRoundWinner = nil
    inst.roundKills = { A = 0, B = 0 }
    inst.alive = {}
    destroySudden(inst)
    for p in pairs(inst.players) do
        if isElement(p) then
            killRespawn(inst, p)
            inst.alive[p] = true
            setElementData(p, "dm:noRespawn", true)
            spectate(p, nil)
            spawnInTeam(inst, p)
        end
    end
    inst.roundEndTick = getTickCount() + roundTime(inst) * 1000
    killTimerSafe(inst.timer)
    inst.timer = setTimer(function() if instances[inst.id] and inst.state == "round" then suddenDeath(inst) end end, roundTime(inst) * 1000, 1)
    notifyAll(inst, ("Round %d de 3 — %d minutos, sem respawn. Primeiro a %d rounds vence."):format(n, math.floor(roundTime(inst) / 60), roundsToWin(inst)), "info")
    broadcast(inst)
end

endRound = function(inst, winner)
    if inst.state ~= "round" and inst.state ~= "sudden" then return end
    killTimerSafe(inst.timer)
    destroySudden(inst)
    inst.state = "roundEnd"
    inst.rounds[winner] = inst.rounds[winner] + 1
    inst.lastRoundWinner = winner
    for p in pairs(inst.players) do if isElement(p) then setElementFrozen(p, false) end end
    broadcast(inst)
    inst.timer = setTimer(function()
        if not instances[inst.id] then return end
        if inst.rounds[winner] >= roundsToWin(inst) then endMatch(inst, winner, "rounds")
        elseif inst.round >= (CFG.rounds or 3) then
            local w = inst.rounds.A > inst.rounds.B and "A" or (inst.rounds.B > inst.rounds.A and "B" or nil)
            endMatch(inst, w, "rounds")
        else startRound(inst, inst.round + 1) end
    end, (CFG.roundBreak or 5) * 1000, 1)
end

local function checkRoundEnd(inst)
    if inst.state ~= "round" and inst.state ~= "sudden" then return end
    local a, b = aliveCount(inst, "A"), aliveCount(inst, "B")
    if a == 0 and b == 0 then endRound(inst, inst.roundKills.A >= inst.roundKills.B and "A" or "B")
    elseif a == 0 then endRound(inst, "B")
    elseif b == 0 then endRound(inst, "A")
    else broadcast(inst) end
end

-- ---------------- Partida ----------------
local function startMatch(inst)
    if not instances[inst.id] then return end
    inst.rounds = { A = 0, B = 0 }
    finalizeRoles(inst)
    for p in pairs(inst.players) do
        if isElement(p) then
            inst.kills[p], inst.deaths[p] = 0, 0
            setPlayerTeam(p, inst.teamElems[inst.teamOf[p]])
            setElementData(p, "dm:noReward", false)
            triggerClientEvent(p, "ranked:start", resourceRoot, inst.teamOf[p], inst.teamNames[inst.teamOf[p]])
        end
    end
    startRound(inst, 1)
end

endMatch = function(inst, winner, reason)
    if inst.state == "results" or inst.state == "warmup" then return end
    killTimerSafe(inst.timer)
    destroySudden(inst)
    inst.state = "results"
    local wasMatch = reason ~= "cancelled"
    local mvp, mvpKills = nil, -1
    for p in pairs(inst.players) do
        if isElement(p) and (inst.kills[p] or 0) > mvpKills then mvp, mvpKills = p, inst.kills[p] or 0 end
    end
    local results, rpOf, moneyOf = {}, {}, {}
    for p in pairs(inst.players) do
        if isElement(p) then
            local team = inst.teamOf[p]
            local won = winner ~= nil and team == winner
            local draw = winner == nil
            local rp, money = 0, 0
            if wasMatch and team then
                if not draw then rp = won and RP.rankedWin or RP.rankedLoss end
                rp = rp + (inst.kills[p] or 0) * RP.rankedKill + (p == mvp and RP.rankedMvp or 0)
                money = won and ECO.rankedWin or ECO.rankedLoss
                core:addPlayerStat(p, "rp", rp)
                core:addPlayerStat(p, won and "ranked_wins" or "ranked_losses", 1)
                core:addPlayerStat(p, "ranked_kills", inst.kills[p] or 0)
                core:addMoney(p, money, won and "Vitória ranqueada" or "Partida ranqueada")
            end
            rpOf[p], moneyOf[p] = rp, money
            results[#results + 1] = { name = nick(p), team = team, kills = inst.kills[p] or 0, deaths = inst.deaths[p] or 0, rp = rp, role = inst.roleOf[p] or false }
        end
    end
    for p in pairs(inst.players) do
        if isElement(p) then
            local team = inst.teamOf[p]
            setElementData(p, "dm:noRespawn", false)
            setElementFrozen(p, false)
            triggerClientEvent(p, "ranked:end", resourceRoot, {
                won = winner ~= nil and team == winner, draw = winner == nil, cancelled = not wasMatch, roundsA = inst.rounds.A, roundsB = inst.rounds.B, myTeam = team,
                rp = rpOf[p] or 0, money = moneyOf[p] or 0, mvp = mvp and nick(mvp) or "", nameA = inst.teamNames.A, nameB = inst.teamNames.B,
                kills = inst.kills[p] or 0, deaths = inst.deaths[p] or 0, results = results,
            })
        end
    end
    if wasMatch then
        local winName = winner and inst.teamNames[winner] or "Empate"
        core:sendServerMessage(root, ("#F5C451★ RANQUEADA #8FA39A» #FFFFFF%s #969BB4— %s venceu por #FFFFFF%d x %d#969BB4 (MD3)%s"):format(
            inst.mode.name, winName, inst.rounds.A, inst.rounds.B, mvp and (" · MVP #FFFFFF" .. nick(mvp)) or ""))
    end
    if inst.fixedTeams then
        triggerEvent("ranked:clanMatchEnd", resourceRoot, inst.clanInfo, winner, inst.rounds.A, inst.rounds.B, results)
    end
    inst.timer = setTimer(function()
        if not instances[inst.id] then return end
        if inst.fixedTeams then
            for p in pairs(inst.players) do
                if isElement(p) then
                    setPlayerTeam(p, nil)
                    setElementData(p, "dm:managed", false)
                    playerInst[p] = nil
                    inst.players[p] = nil
                    core:setPlayerArena(p, "lobby", true)
                end
            end
            destroyInstance(inst)
        else
            inst.state = "warmup"
            inst.rounds = { A = 0, B = 0 }
            inst.round = 0
            inst.lastRoundWinner = nil
            dissolveTeams(inst)
            for p in pairs(inst.players) do
                if isElement(p) then
                    killRespawn(inst, p)
                    inst.kills[p], inst.deaths[p] = 0, 0
                    setElementData(p, "dm:noReward", true)
                    spectate(p, nil)
                    spawnWarmup(inst, p)
                end
            end
            broadcast(inst)
            checkStart(inst)
        end
    end, CFG.resultsTime * 1000, 1)
end

checkStart = function(inst)
    if inst.state ~= "warmup" or inst.fixedTeams then return end
    if count(inst.players) >= inst.mode.teamSize * 2 then
        inst.state = "countdown"
        formTeams(inst)
        inst.rolePick, inst.roleOf, inst.sniperOf = {}, {}, {}
        for p in pairs(inst.players) do if isElement(p) then setPlayerTeam(p, inst.teamElems[inst.teamOf[p]]) end end
        inst.countdownEnd = getTickCount() + CFG.countdown * 1000
        killTimerSafe(inst.timer)
        inst.timer = setTimer(function() if instances[inst.id] and inst.state == "countdown" then startMatch(inst) end end, CFG.countdown * 1000, 1)
        notifyAll(inst, ("Jogadores completos! Times formados por elo. %sA partida começa em %d segundos."):format(usesRoles(inst) and "Escolha seu papel (1 sniper por time). " or "", CFG.countdown), "success")
        broadcast(inst)
    end
end

-- ---------------- Entrada / saída ----------------
local function addPlayer(inst, player)
    inst.players[player] = true
    playerInst[player] = inst
    inst.kills[player], inst.deaths[player] = 0, 0
    setElementData(player, "dm:managed", inst.id)
    setElementData(player, "dm:noReward", true)
    setElementData(player, "dm:noRespawn", false)
    if inst.fixedTeams then
        setElementData(player, "dm:noReward", false)
        setPlayerTeam(player, inst.teamElems[inst.teamOf[player] or "A"])
        spawnInTeam(inst, player)
        core:notifyPlayer(player, "Clã x clã (MD3)! Escolha seu papel — a partida começa em instantes.", "success", inst.mode.name)
    else
        spawnWarmup(inst, player)
        core:notifyPlayer(player, ("Aquecimento: a partida (MD3) começa com %d jogadores. Treine enquanto espera!"):format(inst.mode.teamSize * 2), "info", inst.mode.name)
        checkStart(inst)
    end
    broadcast(inst)
end

local function removePlayer(player, quitting)
    local inst = playerInst[player]
    if not inst then return end
    killRespawn(inst, player)
    playerInst[player] = nil
    inst.players[player] = nil
    local team = inst.teamOf[player]
    if team then inst.teams[team][player] = nil end
    inst.teamOf[player] = nil
    inst.alive[player] = nil
    inst.rolePick[player] = nil
    if inst.sniperOf.A == player then inst.sniperOf.A = nil end
    if inst.sniperOf.B == player then inst.sniperOf.B = nil end
    local inMatch = inst.state == "round" or inst.state == "sudden" or inst.state == "roundEnd"
    if isElement(player) then
        setPlayerTeam(player, nil)
        setElementFrozen(player, false)
        setElementData(player, "dm:managed", false)
        setElementData(player, "dm:noReward", false)
        setElementData(player, "dm:noRespawn", false)
        triggerClientEvent(player, "ranked:state", resourceRoot, false)
        spectate(player, nil)
        if inMatch and team then
            core:addPlayerStat(player, "rp", RP.rankedLoss)
            core:addPlayerStat(player, "ranked_losses", 1)
            core:notifyPlayer(player, ("Você abandonou a partida: %d RP."):format(RP.rankedLoss), "error", "Ranqueada")
        end
    end
    if inMatch then
        if count(inst.teams.A) == 0 or count(inst.teams.B) == 0 then
            endMatch(inst, count(inst.teams.A) > 0 and "A" or (count(inst.teams.B) > 0 and "B" or nil), "forfeit")
        else
            if inst.state == "round" or inst.state == "sudden" then checkRoundEnd(inst) end
        end
    elseif inst.state == "countdown" then
        if inst.fixedTeams and (count(inst.teams.A) == 0 or count(inst.teams.B) == 0) then
            endMatch(inst, count(inst.teams.A) > 0 and "A" or (count(inst.teams.B) > 0 and "B" or nil), "forfeit")
        elseif not inst.fixedTeams and count(inst.players) < inst.mode.teamSize * 2 then
            killTimerSafe(inst.timer)
            inst.state = "warmup"
            dissolveTeams(inst)
            notifyAll(inst, "Um jogador saiu — contagem cancelada, de volta ao aquecimento.", "warn")
        else
            recomputeSnipers(inst)
        end
    end
    if count(inst.players) == 0 then destroyInstance(inst) else broadcast(inst) end
end

-- ---------------- Eventos ----------------
addEvent("ranked:join")
addEventHandler("ranked:join", root, function(modeId)
    local player = source
    local mode = modeById(modeId)
    if not mode then return end
    if playerInst[player] then removePlayer(player) end
    local inst = pendingClan[player]
    pendingClan[player] = nil
    if not inst or not instances[inst.id] then inst = findOpenInstance(mode) or createInstance(mode) end
    addPlayer(inst, player)
end)
addEvent("ranked:requestJoin", true)
addEventHandler("ranked:requestJoin", root, function(modeId)
    if client ~= source or not getElementData(source, "dm:ready") then return end
    if not modeById(modeId) then return end
    if getElementData(source, "dm:inDuel") then core:notifyPlayer(source, "Termine o duelo primeiro.", "warn") return end
    core:setPlayerArena(source, modeId)
end)

function getModeInfo()
    cfg()
    local info = {}
    for _, mode in ipairs(MODES) do
        local waiting, playing, matches = 0, 0, 0
        for _, inst in pairs(instances) do
            if inst.mode == mode then
                if inst.state == "warmup" or inst.state == "countdown" then waiting = waiting + count(inst.players)
                else playing = playing + count(inst.players) matches = matches + 1 end
            end
        end
        info[#info + 1] = { id = mode.id, waiting = waiting, playing = playing, matches = matches }
    end
    return info
end
addEvent("ranked:requestInfo", true)
addEventHandler("ranked:requestInfo", root, function()
    if client ~= source then return end
    triggerClientEvent(source, "ranked:info", resourceRoot, getModeInfo())
end)

addEvent("dm:onPlayerArenaChange")
addEventHandler("dm:onPlayerArenaChange", root, function() if playerInst[source] then removePlayer(source) end end)
addEventHandler("onPlayerQuit", root, function()
    pendingClan[source] = nil
    if playerInst[source] then removePlayer(source, true) end
end)

-- Morte dentro da instância
addEventHandler("onPlayerWasted", root, function()
    local inst = playerInst[source]
    if not inst then return end
    local player = source
    inst.deaths[player] = (inst.deaths[player] or 0) + 1
    if getElementData(player, "dm:inDuel") then return end
    if inst.state == "round" or inst.state == "sudden" then
        inst.alive[player] = false
        -- assiste um companheiro vivo
        local team = inst.teamOf[player]
        local mate
        if team then for p in pairs(inst.teams[team]) do if isElement(p) and inst.alive[p] then mate = p break end end end
        setTimer(function() if isElement(player) and playerInst[player] == inst and not inst.alive[player] and mate and isElement(mate) then spectate(player, mate) end end, 1500, 1)
        checkRoundEnd(inst)
        return
    end
    if inst.state == "roundEnd" or inst.state == "results" then return end
    local delay = core:getConfig().respawnDelay
    killRespawn(inst, player)
    inst.respawnTimers[player] = setTimer(function()
        inst.respawnTimers[player] = nil
        if isElement(player) and playerInst[player] == inst and instances[inst.id] and isPedDead(player) then
            if inst.state == "countdown" then spawnInTeam(inst, player) else spawnWarmup(inst, player) end
        end
    end, delay, 1)
end)

-- Kill durante o round -> estatísticas
addEvent("dm:onPlayerKill")
addEventHandler("dm:onPlayerKill", root, function(victim)
    local killer = source
    local inst = playerInst[killer]
    if not inst or (inst.state ~= "round" and inst.state ~= "sudden") or playerInst[victim] ~= inst then return end
    local tk, tv = inst.teamOf[killer], inst.teamOf[victim]
    if not tk or tk == tv then return end
    inst.kills[killer] = (inst.kills[killer] or 0) + 1
    inst.roundKills[tk] = (inst.roundKills[tk] or 0) + 1
end)

-- ---------------- Clã x clã ----------------
function startClanMatch(modeId, playersA, playersB, info)
    local mode = modeById(modeId)
    if not mode then return false end
    local inst = createInstance(mode, true)
    inst.clanInfo = info
    inst.teamNames = { A = info.tagA or "Clã A", B = info.tagB or "Clã B" }
    inst.state = "countdown"
    for _, p in ipairs(playersA) do inst.teamOf[p] = "A" inst.teams.A[p] = true end
    for _, p in ipairs(playersB) do inst.teamOf[p] = "B" inst.teams.B[p] = true end
    for _, list in ipairs({ playersA, playersB }) do
        for _, p in ipairs(list) do
            if isElement(p) then pendingClan[p] = inst core:setPlayerArena(p, modeId, true) end
        end
    end
    inst.countdownEnd = getTickCount() + CFG.countdown * 1000
    killTimerSafe(inst.timer)
    inst.timer = setTimer(function() if instances[inst.id] and inst.state == "countdown" then startMatch(inst) end end, CFG.countdown * 1000, 1)
    broadcast(inst)
    return inst.id
end
addEvent("ranked:clanMatchEnd")

addEventHandler("onResourceStop", resourceRoot, function()
    for _, inst in pairs(instances) do
        for p in pairs(inst.players) do
            if isElement(p) then
                setPlayerTeam(p, nil)
                setElementFrozen(p, false)
                setElementData(p, "dm:managed", false)
                setElementData(p, "dm:noReward", false)
                setElementData(p, "dm:noRespawn", false)
                core:setPlayerArena(p, "lobby", true)
            end
        end
        destroyInstance(inst)
    end
end)
