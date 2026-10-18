--[[
    Clãs. Tabela "clans" no banco do dm_core; o vínculo do jogador fica em players.clan_id / clan_role.
    Papéis: leader | officer | member. Clã x clã: desafio entre líderes/oficiais -> dm_ranked.startClanMatch.
]]

local core = exports.dm_core
local CFG, ECO, MODES
local db
local clans = {}         -- id -> { id, name, tag, color, leader_key, points, wins, losses, created }
local invites = {}       -- player -> { clanId, from, expires }
local challenges = {}    -- targetClanId -> { fromClanId, modeId, from, expires }
local COLORS = { { 34, 230, 138 }, { 120, 255, 180 }, { 34, 230, 138 }, { 245, 196, 81 }, { 255, 77, 109 }, { 255, 140, 66 }, { 255, 105, 180 }, { 120, 220, 255 } }

local function cfg()
    if not CFG then CFG = core:getClanConfig() ECO = core:getEconomyConfig() MODES = core:getRankedModes() end
end
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local function notify(p, text, t, title) core:notifyPlayer(p, text, t or "info", title or "Clã") end
local function hex(c) return string.format("#%02X%02X%02X", c[1], c[2], c[3]) end

local function initDB()
    db = core:getDB()
    if not db then return end
    dbExec(db, [[CREATE TABLE IF NOT EXISTS clans (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, tag TEXT UNIQUE, color INTEGER DEFAULT 1,
        leader_key TEXT, points INTEGER DEFAULT 0, wins INTEGER DEFAULT 0, losses INTEGER DEFAULT 0, created INTEGER DEFAULT 0
    )]])
    dbQuery(function(qh)
        local rows = dbPoll(qh, 0) or {}
        for _, r in ipairs(rows) do
            r.id = tonumber(r.id); r.color = tonumber(r.color) or 1; r.points = tonumber(r.points) or 0
            r.wins = tonumber(r.wins) or 0; r.losses = tonumber(r.losses) or 0
            clans[r.id] = r
        end
        for _, p in ipairs(getElementsByType("player")) do refreshClanData(p) end
    end, db, "SELECT * FROM clans")
end

local function saveClan(c)
    if not db then return end
    dbExec(db, "UPDATE clans SET name=?, tag=?, color=?, leader_key=?, points=?, wins=?, losses=? WHERE id=?", c.name, c.tag, c.color, c.leader_key, c.points, c.wins, c.losses, c.id)
end

local function playerClan(player)
    local row = core:getPlayerStats(player)
    if not row or not row.clan_id or row.clan_id == 0 then return nil, row end
    local c = clans[row.clan_id]
    if not c then return nil, row end
    return c, row
end

function refreshClanData(player)
    local c, row = playerClan(player)
    if c then
        setElementData(player, "dm:clanTag", { text = c.tag, hex = hex(COLORS[c.color] or COLORS[1]), id = c.id, name = c.name, role = row.clan_role })
    else
        setElementData(player, "dm:clanTag", false)
    end
end

local function onlineMembers(clanId)
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        local row = core:getPlayerStats(p)
        if row and row.clan_id == clanId then list[#list + 1] = p end
    end
    return list
end

local function isOfficer(player)
    local c, row = playerClan(player)
    return c and (row.clan_role == "leader" or row.clan_role == "officer"), c, row
end

-- Dados do clã para o painel do jogador
local function sendClanInfo(player)
    local c, row = playerClan(player)
    local data = { clan = nil, invites = {}, challenge = nil, clans = {}, modes = {} }
    if c then
        data.clan = { id = c.id, name = c.name, tag = c.tag, color = COLORS[c.color] or COLORS[1], points = c.points, wins = c.wins, losses = c.losses, role = row.clan_role, members = {} }
        for _, p in ipairs(onlineMembers(c.id)) do
            local r = core:getPlayerStats(p)
            data.clan.members[#data.clan.members + 1] = { name = nick(p), role = r and r.clan_role or "member", rp = r and r.rp or 0, online = true }
        end
        if challenges[c.id] then
            local ch = challenges[c.id]
            local from = clans[ch.fromClanId]
            if from then data.challenge = { fromTag = from.tag, fromName = from.name, modeId = ch.modeId, fromClanId = ch.fromClanId } end
        end
    end
    if invites[player] then
        local ic = clans[invites[player].clanId]
        if ic then data.invites[1] = { clanId = ic.id, tag = ic.tag, name = ic.name, from = invites[player].from } end
    end
    for id, cl in pairs(clans) do
        data.clans[#data.clans + 1] = { id = cl.id, tag = cl.tag, name = cl.name, points = cl.points, wins = cl.wins, losses = cl.losses, online = #onlineMembers(cl.id), color = COLORS[cl.color] or COLORS[1] }
    end
    table.sort(data.clans, function(a, b) return a.points > b.points end)
    cfg()
    for _, m in ipairs(MODES) do data.modes[#data.modes + 1] = { id = m.id, name = m.name, teamSize = m.teamSize } end
    data.createCost = ECO.clanCreate
    data.minClanMatch = core:getRankedConfig().minClanMatch
    if c and db then
        -- membros offline: consulta assíncrona, envia quando chegar
        dbQuery(function(qh, p, d)
            local rows = dbPoll(qh, 0) or {}
            if not isElement(p) then return end
            local onlineNames = {}
            for _, m in ipairs(d.clan.members) do onlineNames[m.name] = true end
            for _, r in ipairs(rows) do
                if not onlineNames[r.name] then
                    d.clan.members[#d.clan.members + 1] = { name = r.name, role = r.clan_role, rp = tonumber(r.rp) or 0, online = false }
                end
            end
            triggerClientEvent(p, "clans:info", resourceRoot, d)
        end, { player, data }, db, "SELECT name, clan_role, rp FROM players WHERE clan_id = ? ORDER BY rp DESC LIMIT 40", c.id)
        return
    end
    triggerClientEvent(player, "clans:info", resourceRoot, data)
end

addEvent("clans:requestInfo", true)
addEventHandler("clans:requestInfo", root, function() if client == source then sendClanInfo(source) end end)

-- ---------------- Ações ----------------
local function validName(name) cfg() return type(name) == "string" and #name >= CFG.nameMin and #name <= CFG.nameMax and name:match("^[%w%s_%-]+$") end
local function validTag(tag) cfg() return type(tag) == "string" and #tag >= CFG.tagMin and #tag <= CFG.tagMax and tag:match("^[%w]+$") end

addEvent("clans:create", true)
addEventHandler("clans:create", root, function(name, tag)
    local player = source
    if (client and client ~= source) or not db then return end
    cfg()
    local c, row = playerClan(player)
    if c then return notify(player, "Você já está em um clã.", "warn") end
    if not row then return end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return notify(player, "Faça login em uma conta para criar um clã.", "warn") end
    if not validName(name) then return notify(player, ("Nome inválido (%d-%d caracteres, letras/números)."):format(CFG.nameMin, CFG.nameMax), "error") end
    if not validTag(tag) then return notify(player, ("Tag inválida (%d-%d letras/números)."):format(CFG.tagMin, CFG.tagMax), "error") end
    tag = tag:upper()
    for _, cl in pairs(clans) do
        if cl.tag:upper() == tag then return notify(player, "Essa tag já existe.", "error") end
        if cl.name:lower() == name:lower() then return notify(player, "Esse nome já existe.", "error") end
    end
    if not core:takeMoney(player, ECO.clanCreate) then return notify(player, ("Criar um clã custa %s."):format(core:formatMoney(ECO.clanCreate)), "error") end
    local key = "acc:" .. getAccountName(account)
    local now = getRealTime().timestamp
    dbExec(db, "INSERT INTO clans (name, tag, color, leader_key, created) VALUES (?, ?, ?, ?, ?)", name, tag, math.random(#COLORS), key, now)
    dbQuery(function(qh, p)
        local rows = dbPoll(qh, 0)
        if not rows or not rows[1] or not isElement(p) then return end
        local r = rows[1]
        r.id = tonumber(r.id); r.color = tonumber(r.color) or 1; r.points = 0; r.wins = 0; r.losses = 0
        clans[r.id] = r
        core:setPlayerStat(p, "clan_id", r.id)
        core:setPlayerStat(p, "clan_role", "leader")
        refreshClanData(p)
        notify(p, ("Clã %s [%s] criado! Convide jogadores pelo painel (F6)."):format(r.name, r.tag), "success")
        core:sendServerMessage(root, ("#FFFFFF%s #969BB4fundou o clã %s[%s] %s#969BB4!"):format(nick(p), hex(COLORS[r.color]), r.tag, r.name))
        sendClanInfo(p)
    end, { player }, db, "SELECT * FROM clans WHERE tag = ?", tag)
end)

addEvent("clans:invite", true)
addEventHandler("clans:invite", root, function(target)
    local player = client
    if player ~= source then return end
    local ok, c = isOfficer(player)
    if not ok then return notify(player, "Só líder e oficiais convidam.", "warn") end
    if not isElement(target) or getElementType(target) ~= "player" then return end
    local tc = playerClan(target)
    if tc then return notify(player, nick(target) .. " já está em um clã.", "warn") end
    cfg()
    if #onlineMembers(c.id) >= CFG.maxMembers then return notify(player, "Clã cheio.", "warn") end
    invites[target] = { clanId = c.id, from = nick(player), expires = getTickCount() + 60000 }
    notify(target, ("%s te convidou para o clã [%s] %s. Abra F6 para aceitar."):format(nick(player), c.tag, c.name), "info", "Convite de clã")
    notify(player, "Convite enviado para " .. nick(target) .. ".", "success")
    sendClanInfo(target)
end)

addEvent("clans:respondInvite", true)
addEventHandler("clans:respondInvite", root, function(accept)
    local player = client
    if player ~= source then return end
    local inv = invites[player]
    invites[player] = nil
    if not inv then return end
    local c = clans[inv.clanId]
    if not accept or not c then sendClanInfo(player) return end
    if playerClan(player) then return notify(player, "Você já está em um clã.", "warn") end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return notify(player, "Faça login em uma conta para entrar em um clã.", "warn") end
    core:setPlayerStat(player, "clan_id", c.id)
    core:setPlayerStat(player, "clan_role", "member")
    refreshClanData(player)
    for _, m in ipairs(onlineMembers(c.id)) do notify(m, nick(player) .. " entrou no clã!", "success") end
    sendClanInfo(player)
end)

addEvent("clans:leave", true)
addEventHandler("clans:leave", root, function()
    local player = client
    if player ~= source then return end
    local c, row = playerClan(player)
    if not c then return end
    if row.clan_role == "leader" then
        -- líder sai: passa liderança para um oficial/membro online, ou dissolve
        local successor
        for _, m in ipairs(onlineMembers(c.id)) do
            if m ~= player then successor = m break end
        end
        if successor then
            core:setPlayerStat(successor, "clan_role", "leader")
            local acc = getPlayerAccount(successor)
            c.leader_key = acc and not isGuestAccount(acc) and ("acc:" .. getAccountName(acc)) or c.leader_key
            saveClan(c)
            refreshClanData(successor)
            notify(successor, "Você agora é o líder do clã.", "success")
        else
            dbExec(db, "DELETE FROM clans WHERE id = ?", c.id)
            dbExec(db, "UPDATE players SET clan_id = 0, clan_role = '' WHERE clan_id = ?", c.id)
            clans[c.id] = nil
            core:sendServerMessage(root, ("#969BB4O clã #FFFFFF[%s] %s #969BB4foi dissolvido."):format(c.tag, c.name))
        end
    end
    core:setPlayerStat(player, "clan_id", 0)
    core:setPlayerStat(player, "clan_role", "")
    refreshClanData(player)
    notify(player, "Você saiu do clã.", "info")
    sendClanInfo(player)
end)

addEvent("clans:kick", true)
addEventHandler("clans:kick", root, function(targetName)
    local player = client
    if player ~= source then return end
    local ok, c, row = isOfficer(player)
    if not ok then return end
    local target
    for _, m in ipairs(onlineMembers(c.id)) do
        if nick(m) == targetName then target = m end
    end
    if target then
        local tc, trow = playerClan(target)
        if tc ~= c or trow.clan_role == "leader" then return end
        core:setPlayerStat(target, "clan_id", 0)
        core:setPlayerStat(target, "clan_role", "")
        refreshClanData(target)
        notify(target, "Você foi removido do clã.", "warn")
    else
        dbExec(db, "UPDATE players SET clan_id = 0, clan_role = '' WHERE clan_id = ? AND name = ? AND clan_role <> 'leader'", c.id, targetName)
    end
    notify(player, targetName .. " removido.", "success")
    sendClanInfo(player)
end)

addEvent("clans:promote", true)
addEventHandler("clans:promote", root, function(targetName)
    local player = client
    if player ~= source then return end
    local c, row = playerClan(player)
    if not c or row.clan_role ~= "leader" then return end
    local target = core:findPlayer(targetName)
    if not target then return notify(player, "O jogador precisa estar online.", "warn") end
    local tc, trow = playerClan(target)
    if tc ~= c then return end
    local newRole = trow.clan_role == "officer" and "member" or "officer"
    core:setPlayerStat(target, "clan_role", newRole)
    refreshClanData(target)
    notify(target, newRole == "officer" and "Você foi promovido a oficial!" or "Você voltou a ser membro.", "info")
    sendClanInfo(player)
end)

addEvent("clans:setColor", true)
addEventHandler("clans:setColor", root, function(index)
    local player = client
    if player ~= source then return end
    local c, row = playerClan(player)
    if not c or row.clan_role ~= "leader" then return end
    index = tonumber(index)
    if not index or not COLORS[index] then return end
    c.color = index
    saveClan(c)
    for _, m in ipairs(onlineMembers(c.id)) do refreshClanData(m) end
    sendClanInfo(player)
end)

-- ---------------- Clã x clã ----------------
addEvent("clans:challenge", true)
addEventHandler("clans:challenge", root, function(targetClanId, modeId)
    local player = client
    if player ~= source then return end
    local ok, c = isOfficer(player)
    if not ok then return notify(player, "Só líder e oficiais desafiam.", "warn") end
    local target = clans[tonumber(targetClanId)]
    if not target or target == c then return end
    cfg()
    local mode
    for _, m in ipairs(MODES) do if m.id == modeId then mode = m end end
    if not mode then return end
    local minN = core:getRankedConfig().minClanMatch
    if #onlineMembers(c.id) < minN then return notify(player, ("Seu clã precisa de pelo menos %d membros online."):format(minN), "warn") end
    if #onlineMembers(target.id) < minN then return notify(player, ("O clã [%s] não tem %d membros online."):format(target.tag, minN), "warn") end
    challenges[target.id] = { fromClanId = c.id, modeId = modeId, from = player, expires = getTickCount() + 90000 }
    setTimer(function() if challenges[target.id] and challenges[target.id].fromClanId == c.id then challenges[target.id] = nil end end, 90000, 1)
    for _, m in ipairs(onlineMembers(target.id)) do
        local r = core:getPlayerStats(m)
        notify(m, ("O clã [%s] %s desafiou vocês para %s! %s"):format(c.tag, c.name, mode.name, (r and (r.clan_role ~= "member")) and "Abra F6 para aceitar." or ""), "info", "Clã x Clã")
        sendClanInfo(m)
    end
    notify(player, ("Desafio enviado para [%s]."):format(target.tag), "success")
end)

addEvent("clans:respondChallenge", true)
addEventHandler("clans:respondChallenge", root, function(accept)
    local player = client
    if player ~= source then return end
    local ok, c = isOfficer(player)
    if not ok then return end
    local ch = challenges[c.id]
    if not ch then return end
    challenges[c.id] = nil
    local from = clans[ch.fromClanId]
    if not from then return end
    if not accept then
        for _, m in ipairs(onlineMembers(from.id)) do notify(m, ("[%s] recusou o desafio."):format(c.tag), "warn", "Clã x Clã") end
        sendClanInfo(player)
        return
    end
    cfg()
    local mode
    for _, m in ipairs(MODES) do if m.id == ch.modeId then mode = m end end
    if not mode then return end
    -- monta os times: só membros fora de duelo; tamanho = menor clã (limitado ao modo)
    local function eligible(clanId)
        local list = {}
        for _, p in ipairs(onlineMembers(clanId)) do
            if not getElementData(p, "dm:inDuel") then list[#list + 1] = p end
        end
        return list
    end
    local a, b = eligible(from.id), eligible(c.id)
    local size = math.min(#a, #b, mode.teamSize)
    if size < core:getRankedConfig().minClanMatch then return notify(player, "Jogadores insuficientes online.", "warn") end
    local teamA, teamB = {}, {}
    for i = 1, size do teamA[i] = a[i] teamB[i] = b[i] end
    local id = exports.dm_ranked:startClanMatch(mode.id, teamA, teamB, { idA = from.id, idB = c.id, tagA = from.tag, tagB = c.tag, nameA = from.name, nameB = c.name })
    if id then
        core:sendServerMessage(root, ("#F5C451[CLÃ x CLÃ] #FFFFFF[%s] %s #969BB4vs #FFFFFF[%s] %s #969BB4— %s (%dx%d) começou!"):format(from.tag, from.name, c.tag, c.name, mode.name, size, size))
    end
end)

addEventHandler("ranked:clanMatchEnd", root, function(info, winner, scoreA, scoreB, results)
    if not info then return end
    cfg()
    local a, b = clans[info.idA], clans[info.idB]
    if not a or not b then return end
    if winner == "A" then
        a.points = a.points + CFG.pointsWin; a.wins = a.wins + 1
        b.points = math.max(0, b.points + CFG.pointsLoss); b.losses = b.losses + 1
    elseif winner == "B" then
        b.points = b.points + CFG.pointsWin; b.wins = b.wins + 1
        a.points = math.max(0, a.points + CFG.pointsLoss); a.losses = a.losses + 1
    end
    saveClan(a); saveClan(b)
    local winTag = winner == "A" and a.tag or (winner == "B" and b.tag or nil)
    core:sendServerMessage(root, ("#F5C451[CLÃ x CLÃ] #FFFFFF[%s] %d x %d [%s] #969BB4— %s"):format(a.tag, scoreA, scoreB, b.tag, winTag and ("vitória de [" .. winTag .. "]") or "empate"))
    triggerClientEvent(root, "dm:notify", resourceRoot, ("[%s] %d x %d [%s] — %s"):format(a.tag, scoreA, scoreB, b.tag, winTag and ("[" .. winTag .. "] venceu!") or "empate"), "info", "Clã x Clã")
end)

-- ---------------- Comandos ----------------
addCommandHandler("cla", function(player, cmd, sub, ...)
    local args = { ... }
    if sub == "criar" and args[1] and args[2] then
        triggerEvent("clans:create", player, table.concat(args, " ", 2), args[1])
        return
    end
    core:sendServerMessage(player, "Clã: use #FFFFFFF6#969BB4 (painel) ou #969BB4/cla criar <TAG> <nome>")
end)

-- ---------------- Eventos de jogador ----------------
addEventHandler("dm:onStatsLoaded", root, function() refreshClanData(source) end)
addEvent("dm:onStatsLoaded")
addEventHandler("onPlayerQuit", root, function() invites[source] = nil end)
addEventHandler("onResourceStart", resourceRoot, function()
    -- aguarda o dm_core abrir o banco
    setTimer(initDB, 1000, 1)
end)
