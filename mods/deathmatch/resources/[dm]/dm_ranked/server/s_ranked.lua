--[[
    Partidas ranqueadas (team deathmatch) em instâncias com dimensão própria.
    Fluxo: aquecimento (FFA, sem recompensas) -> completou 2*teamSize -> contagem -> partida
    (times balanceados por RP, respawn na base) -> resultado (RP, $) -> volta ao aquecimento.
    Clã x clã usa o mesmo motor com times fixos (startClanMatch).
]]

local core = exports.dm_core
local MODES, CFG, RP, ECO
local instances = {}   -- id -> inst
local playerInst = {}  -- player -> inst
local pendingClan = {} -- player -> inst (entrada direcionada para partida de clã)
local nextInstance = 0
local instanceCounter = {} -- modeId -> n

local TEAM_COLORS = { A = { 34, 211, 238 }, B = { 139, 92, 246 } }

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
    return nil
end

local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local function killTimerSafe(t) if t and isTimer(t) then killTimer(t) end end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- ---------------- Estado para o cliente ----------------
local function stateFor(inst, player)
    local team = inst.teamOf[player]
    local st = {
        state = inst.state, mode = inst.mode.name, place = inst.mode.place, players = count(inst.players), needed = inst.mode.teamSize * 2,
        scoreA = inst.score.A, scoreB = inst.score.B, myTeam = team, killTarget = inst.mode.killTarget,
        nameA = inst.teamNames.A, nameB = inst.teamNames.B, clan = inst.fixedTeams == true,
        secondsLeft = 0,
    }
    if inst.state == "countdown" and inst.countdownEnd then st.secondsLeft = math.max(0, math.ceil((inst.countdownEnd - getTickCount()) / 1000)) end
    if inst.state == "match" and inst.endTick then st.secondsLeft = math.max(0, math.ceil((inst.endTick - getTickCount()) / 1000)) end
    st.kills = inst.kills[player] or 0
    st.deaths = inst.deaths[player] or 0
    return st
end

local function broadcast(inst)
    for p in pairs(inst.players) do
        if isElement(p) then triggerClientEvent(p, "ranked:state", resourceRoot, stateFor(inst, p)) end
    end
end

-- ---------------- Instâncias ----------------
local function createInstance(mode, fixedTeams)
    nextInstance = nextInstance + 1
    instanceCounter[mode.id] = ((instanceCounter[mode.id] or 0) % 99) + 1
    local inst = {
        id = nextInstance, mode = mode, dim = mode.dimension + instanceCounter[mode.id],
        state = "warmup", players = {}, teamOf = {}, teams = { A = {}, B = {} }, score = { A = 0, B = 0 },
        kills = {}, deaths = {}, fixedTeams = fixedTeams or false,
        teamNames = { A = "Time Ciano", B = "Time Roxo" },
        teamElems = { A = createTeam("Ranked " .. nextInstance .. " A", unpack(TEAM_COLORS.A)), B = createTeam("Ranked " .. nextInstance .. " B", unpack(TEAM_COLORS.B)) },
    }
    for _, t in pairs(inst.teamElems) do setTeamFriendlyFire(t, false) end
    instances[inst.id] = inst
    return inst
end

local function destroyInstance(inst)
    killTimerSafe(inst.timer)
    for _, t in pairs(inst.teamElems) do if isElement(t) then destroyElement(t) end end
    instances[inst.id] = nil
end

local function findOpenInstance(mode)
    for _, inst in pairs(instances) do
        if inst.mode == mode and not inst.fixedTeams and (inst.state == "warmup" or inst.state == "countdown") and count(inst.players) < mode.teamSize * 2 then
            return inst
        end
    end
    return nil
end

local function randomSpawn(list, used)
    if not list or #list == 0 then return { 0, 0, 5, 0 } end
    local idx = math.random(#list)
    return list[idx]
end

local function spawnWarmup(inst, player)
    core:spawnPlayerInArena(player, { spawn = randomSpawn(inst.mode.warmupSpawns), weapons = inst.mode.weapons, armor = inst.mode.armor, dimension = inst.dim })
end

local function spawnInTeam(inst, player)
    local team = inst.teamOf[player]
    local list = team and inst.mode.teamSpawns[team] or inst.mode.warmupSpawns
    core:spawnPlayerInArena(player, { spawn = randomSpawn(list), weapons = inst.mode.weapons, armor = inst.mode.armor, dimension = inst.dim })
end

-- ---------------- Entrada / saída ----------------
local function addPlayer(inst, player)
    inst.players[player] = true
    playerInst[player] = inst
    inst.kills[player] = 0
    inst.deaths[player] = 0
    setElementData(player, "dm:managed", inst.id)
    setElementData(player, "dm:noReward", inst.state ~= "match")
    if inst.state == "match" and not inst.fixedTeams then
        -- entrou no meio da partida: vai para o time com menos jogadores
        local a, b = count(inst.teams.A), count(inst.teams.B)
        local team = a <= b and "A" or "B"
        inst.teamOf[player] = team
        inst.teams[team][player] = true
        setPlayerTeam(player, inst.teamElems[team])
        setElementData(player, "dm:noReward", false)
        spawnInTeam(inst, player)
    else
        spawnWarmup(inst, player)
    end
    core:notifyPlayer(player, inst.state == "match" and "Partida em andamento — você entrou no time com menos jogadores." or
        ("Aquecimento: a partida começa com %d jogadores. Treine enquanto espera!"):format(inst.mode.teamSize * 2), "info", inst.mode.name)
    checkStart(inst)
    broadcast(inst)
end

local function endMatch(inst, winner, reason)
    if inst.state ~= "match" and inst.state ~= "countdown" then return end
    killTimerSafe(inst.timer)
    inst.state = "results"
    local wasMatch = reason ~= "cancelled"
    local mvp, mvpKills = nil, -1
    for p in pairs(inst.players) do
        if isElement(p) and (inst.kills[p] or 0) > mvpKills then mvp, mvpKills = p, inst.kills[p] or 0 end
    end
    local results = {}
    for p in pairs(inst.players) do
        if isElement(p) then
            local team = inst.teamOf[p]
            local won = winner ~= nil and team == winner
            local draw = winner == nil
            local rp, money = 0, 0
            if wasMatch and team then
                if draw then rp = 0 else rp = won and RP.rankedWin or RP.rankedLoss end
                rp = rp + (inst.kills[p] or 0) * RP.rankedKill + (p == mvp and RP.rankedMvp or 0)
                money = won and ECO.rankedWin or ECO.rankedLoss
                core:addPlayerStat(p, "rp", rp)
                core:addPlayerStat(p, won and "ranked_wins" or "ranked_losses", 1)
                core:addPlayerStat(p, "ranked_kills", inst.kills[p] or 0)
                core:addMoney(p, money, won and "Vitória ranqueada" or "Partida ranqueada")
            end
            results[#results + 1] = { name = nick(p), team = team, kills = inst.kills[p] or 0, deaths = inst.deaths[p] or 0, rp = rp }
            triggerClientEvent(p, "ranked:end", resourceRoot, {
                won = won, draw = draw, cancelled = not wasMatch, scoreA = inst.score.A, scoreB = inst.score.B, myTeam = team,
                rp = rp, money = money, mvp = mvp and nick(mvp) or "", nameA = inst.teamNames.A, nameB = inst.teamNames.B,
                kills = inst.kills[p] or 0, deaths = inst.deaths[p] or 0, results = results,
            })
        end
    end
    if wasMatch then
        local winName = winner and inst.teamNames[winner] or "Empate"
        core:sendServerMessage(root, ("#F5C451[RANQUEADA] #FFFFFF%s #969BB4— %s venceu por #FFFFFF%d x %d#969BB4%s"):format(
            inst.mode.name, winName, inst.score.A, inst.score.B, mvp and (" · MVP #FFFFFF" .. nick(mvp)) or ""))
    end
    if inst.fixedTeams then
        triggerEvent("ranked:clanMatchEnd", resourceRoot, inst.clanInfo, winner, inst.score.A, inst.score.B, results)
    end
    inst.timer = setTimer(function()
        if not instances[inst.id] then return end
        if inst.fixedTeams then
            -- partida de clã: todos voltam para o lobby
            for p in pairs(inst.players) do
                if isElement(p) then
                    setPlayerTeam(p, nil)
                    playerInst[p] = nil
                    inst.players[p] = nil
                    core:setPlayerArena(p, "lobby", true)
                end
            end
            destroyInstance(inst)
        else
            inst.state = "warmup"
            inst.score = { A = 0, B = 0 }
            inst.teams = { A = {}, B = {} }
            inst.teamOf = {}
            for p in pairs(inst.players) do
                if isElement(p) then
                    setPlayerTeam(p, nil)
                    inst.kills[p], inst.deaths[p] = 0, 0
                    setElementData(p, "dm:noReward", true)
                    spawnWarmup(inst, p)
                end
            end
            broadcast(inst)
            checkStart(inst)
        end
    end, CFG.resultsTime * 1000, 1)
end

local function removePlayer(player, quitting)
    local inst = playerInst[player]
    if not inst then return end
    playerInst[player] = nil
    inst.players[player] = nil
    local team = inst.teamOf[player]
    if team then inst.teams[team][player] = nil end
    inst.teamOf[player] = nil
    if isElement(player) then
        setPlayerTeam(player, nil)
        setElementData(player, "dm:managed", false)
        setElementData(player, "dm:noReward", false)
        triggerClientEvent(player, "ranked:state", resourceRoot, false)
        if inst.state == "match" and team then
            -- abandono conta como derrota
            core:addPlayerStat(player, "rp", RP.rankedLoss)
            core:addPlayerStat(player, "ranked_losses", 1)
            core:notifyPlayer(player, ("Você abandonou a partida: %d RP."):format(RP.rankedLoss), "error", "Ranqueada")
        end
    end
    if inst.state == "match" then
        if count(inst.teams.A) == 0 or count(inst.teams.B) == 0 then
            endMatch(inst, count(inst.teams.A) > 0 and "A" or (count(inst.teams.B) > 0 and "B" or nil), "forfeit")
        end
    elseif inst.state == "countdown" and count(inst.players) < inst.mode.teamSize * 2 and not inst.fixedTeams then
        killTimerSafe(inst.timer)
        inst.state = "warmup"
        for p in pairs(inst.players) do core:notifyPlayer(p, "Um jogador saiu — contagem cancelada, de volta ao aquecimento.", "warn", inst.mode.name) end
    end
    if count(inst.players) == 0 then
        destroyInstance(inst)
    else
        broadcast(inst)
    end
end

-- ---------------- Início da partida ----------------
local function startMatch(inst)
    if not instances[inst.id] then return end
    inst.state = "match"
    inst.score = { A = 0, B = 0 }
    if not inst.fixedTeams then
        -- balanceamento por RP: ordena e alterna
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
    inst.startTick = getTickCount()
    inst.endTick = inst.startTick + inst.mode.duration * 1000
    for p in pairs(inst.players) do
        if isElement(p) then
            inst.kills[p], inst.deaths[p] = 0, 0
            setPlayerTeam(p, inst.teamElems[inst.teamOf[p]])
            setElementData(p, "dm:noReward", false)
            spawnInTeam(inst, p)
            triggerClientEvent(p, "ranked:start", resourceRoot, inst.teamOf[p], inst.teamNames[inst.teamOf[p]])
        end
    end
    broadcast(inst)
    killTimerSafe(inst.timer)
    inst.timer = setTimer(function()
        if instances[inst.id] and inst.state == "match" then
            local winner = inst.score.A > inst.score.B and "A" or (inst.score.B > inst.score.A and "B" or nil)
            endMatch(inst, winner, "time")
        end
    end, inst.mode.duration * 1000, 1)
end

function checkStart(inst)
    if inst.state ~= "warmup" or inst.fixedTeams then return end
    if count(inst.players) >= inst.mode.teamSize * 2 then
        inst.state = "countdown"
        inst.countdownEnd = getTickCount() + CFG.countdown * 1000
        killTimerSafe(inst.timer)
        inst.timer = setTimer(function()
            if instances[inst.id] and inst.state == "countdown" then startMatch(inst) end
        end, CFG.countdown * 1000, 1)
        for p in pairs(inst.players) do core:notifyPlayer(p, ("Jogadores completos! A partida começa em %d segundos."):format(CFG.countdown), "success", inst.mode.name) end
        broadcast(inst)
    end
end

-- ---------------- Eventos ----------------
-- dm_core chama ao entrar em uma "arena" do tipo ranked
addEvent("ranked:join")
addEventHandler("ranked:join", root, function(modeId)
    local player = source
    local mode = modeById(modeId)
    if not mode then return end
    if playerInst[player] then removePlayer(player) end
    local inst = pendingClan[player]
    pendingClan[player] = nil
    if not inst or not instances[inst.id] then
        inst = findOpenInstance(mode) or createInstance(mode)
    end
    addPlayer(inst, player)
end)

addEvent("ranked:requestJoin", true)
addEventHandler("ranked:requestJoin", root, function(modeId)
    if client ~= source or not getElementData(source, "dm:ready") then return end
    if not modeById(modeId) then return end
    if getElementData(source, "dm:inDuel") then core:notifyPlayer(source, "Termine o duelo primeiro.", "warn") return end
    core:setPlayerArena(source, modeId)
end)

-- Informações para o painel (F5)
function getModeInfo()
    cfg()
    local info = {}
    for _, mode in ipairs(MODES) do
        local waiting, playing, matches = 0, 0, 0
        for _, inst in pairs(instances) do
            if inst.mode == mode then
                if inst.state == "match" or inst.state == "results" then playing = playing + count(inst.players) matches = matches + 1
                else waiting = waiting + count(inst.players) end
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

-- Saiu da arena (F2, /lobby, duelo) -> remove da instância
addEvent("dm:onPlayerArenaChange")
addEventHandler("dm:onPlayerArenaChange", root, function(prevId, newId)
    if playerInst[source] then removePlayer(source) end
end)

addEventHandler("onPlayerQuit", root, function()
    pendingClan[source] = nil
    if playerInst[source] then removePlayer(source, true) end
end)

-- Respawn dentro da instância
addEventHandler("onPlayerWasted", root, function()
    local inst = playerInst[source]
    if not inst then return end
    local player = source
    inst.deaths[player] = (inst.deaths[player] or 0) + 1
    local delay = inst.state == "match" and CFG.respawn or core:getConfig().respawnDelay
    setTimer(function()
        local cur = playerInst[player]
        if isElement(player) and cur == inst and instances[inst.id] then
            if inst.state == "match" then spawnInTeam(inst, player) else spawnWarmup(inst, player) end
        end
    end, delay, 1)
end)

-- Kill durante a partida -> placar
addEvent("dm:onPlayerKill")
addEventHandler("dm:onPlayerKill", root, function(victim, weapon, headshot)
    local killer = source
    local inst = playerInst[killer]
    if not inst or inst.state ~= "match" or playerInst[victim] ~= inst then return end
    local tk, tv = inst.teamOf[killer], inst.teamOf[victim]
    if not tk or tk == tv then return end
    inst.kills[killer] = (inst.kills[killer] or 0) + 1
    inst.score[tk] = inst.score[tk] + 1
    broadcast(inst)
    if inst.score[tk] >= inst.mode.killTarget then endMatch(inst, tk, "target") end
end)

-- ---------------- Clã x clã ----------------
-- startClanMatch(modeId, playersA, playersB, info) ; info = { nameA, tagA, nameB, tagB, idA, idB }
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
            if isElement(p) then
                pendingClan[p] = inst
                core:setPlayerArena(p, modeId, true)
            end
        end
    end
    inst.countdownEnd = getTickCount() + CFG.countdown * 1000
    killTimerSafe(inst.timer)
    inst.timer = setTimer(function()
        if instances[inst.id] and inst.state == "countdown" then startMatch(inst) end
    end, CFG.countdown * 1000, 1)
    broadcast(inst)
    return inst.id
end
addEvent("ranked:clanMatchEnd")

-- jogadores de clã entram direto em "countdown": addPlayer não deve spawnar no aquecimento genérico
local _addPlayer = addPlayer
addPlayer = function(inst, player)
    if inst.fixedTeams then
        inst.players[player] = true
        playerInst[player] = inst
        inst.kills[player], inst.deaths[player] = 0, 0
        setElementData(player, "dm:managed", inst.id)
        setElementData(player, "dm:noReward", false)
        setPlayerTeam(player, inst.teamElems[inst.teamOf[player] or "A"])
        spawnInTeam(inst, player)
        core:notifyPlayer(player, "Clã x clã! A partida começa em instantes.", "success", inst.mode.name)
        return
    end
    _addPlayer(inst, player)
end

addEventHandler("onResourceStop", resourceRoot, function()
    for _, inst in pairs(instances) do
        for p in pairs(inst.players) do
            if isElement(p) then
                setPlayerTeam(p, nil)
                setElementData(p, "dm:managed", false)
                setElementData(p, "dm:noReward", false)
                core:setPlayerArena(p, "lobby", true)
            end
        end
        destroyInstance(inst)
    end
end)
