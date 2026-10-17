--[[
    Estatísticas persistentes (SQLite): kills, mortes, headshots, maior sequência,
    duelos, XP/nível e tempo de jogo. A chave é a conta (se logado) ou o serial.
]]

local db
local stats = {}        -- player -> row (cache)
local sessionStart = {} -- player -> tick

local COLUMNS = { "kills", "deaths", "headshots", "best_streak", "duels_won", "duels_lost", "xp", "playtime" }

local function initDB()
    db = dbConnect("sqlite", "data/stats.db")
    if not db then
        outputDebugString("[dm_core] Falha ao abrir banco de dados stats.db", 1)
        return
    end
    dbExec(db, [[CREATE TABLE IF NOT EXISTS players (
        key TEXT PRIMARY KEY,
        name TEXT,
        kills INTEGER DEFAULT 0,
        deaths INTEGER DEFAULT 0,
        headshots INTEGER DEFAULT 0,
        best_streak INTEGER DEFAULT 0,
        duels_won INTEGER DEFAULT 0,
        duels_lost INTEGER DEFAULT 0,
        xp INTEGER DEFAULT 0,
        playtime INTEGER DEFAULT 0,
        first_seen INTEGER DEFAULT 0,
        last_seen INTEGER DEFAULT 0
    )]])
    dbExec(db, "CREATE INDEX IF NOT EXISTS idx_players_kills ON players(kills DESC)")
end

function getStatsKey(player)
    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        return "acc:" .. getAccountName(account)
    end
    return "serial:" .. (getPlayerSerial(player) or getPlayerName(player))
end

local function pushStatsToClient(player)
    local row = stats[player]
    if not row then return end
    local level = DM.levelFromXP(row.xp)
    setElementData(player, "dm:kills", row.kills)
    setElementData(player, "dm:deaths", row.deaths)
    setElementData(player, "dm:xp", row.xp)
    setElementData(player, "dm:level", level)
    setElementData(player, "dm:headshots", row.headshots)
    setElementData(player, "dm:bestStreak", row.best_streak)
    setElementData(player, "dm:duelsWon", row.duels_won)
    setElementData(player, "dm:duelsLost", row.duels_lost)
end

local function newRow(key, player)
    local now = getRealTime().timestamp
    return {
        key = key, name = getPlayerVisibleName(player),
        kills = 0, deaths = 0, headshots = 0, best_streak = 0,
        duels_won = 0, duels_lost = 0, xp = 0, playtime = 0,
        first_seen = now, last_seen = now, _new = true,
    }
end

-- Carrega (ou cria) as stats do jogador. callback opcional é chamado após carregar.
function loadPlayerStats(player, callback)
    if not db or not isElement(player) then return end
    local key = getStatsKey(player)
    sessionStart[player] = getTickCount()
    dbQuery(function(qh, p, k)
        local result = dbPoll(qh, 0)
        if not isElement(p) then return end
        -- O jogador pode ter trocado de conta enquanto a query rodava
        if getStatsKey(p) ~= k then return end
        local row
        if result and result[1] then
            row = result[1]
            for _, col in ipairs(COLUMNS) do row[col] = tonumber(row[col]) or 0 end
            row.name = getPlayerVisibleName(p)
        else
            row = newRow(k, p)
            dbExec(db, "INSERT OR IGNORE INTO players (key, name, first_seen, last_seen) VALUES (?, ?, ?, ?)",
                k, row.name, row.first_seen, row.last_seen)
        end
        stats[p] = row
        pushStatsToClient(p)
        if callback then callback(p, row) end
    end, { player, key }, db, "SELECT * FROM players WHERE key = ?", key)
end

function savePlayerStats(player)
    local row = stats[player]
    if not db or not row or not isElement(player) then return end
    if sessionStart[player] then
        row.playtime = row.playtime + math.floor((getTickCount() - sessionStart[player]) / 1000)
        sessionStart[player] = getTickCount()
    end
    row.last_seen = getRealTime().timestamp
    row.name = getPlayerVisibleName(player)
    dbExec(db, [[UPDATE players SET name=?, kills=?, deaths=?, headshots=?, best_streak=?,
        duels_won=?, duels_lost=?, xp=?, playtime=?, last_seen=? WHERE key=?]],
        row.name, row.kills, row.deaths, row.headshots, row.best_streak,
        row.duels_won, row.duels_lost, row.xp, row.playtime, row.last_seen, row.key)
end

function getPlayerStats(player)
    return stats[player]
end

-- Incrementa um campo. Retorna o novo valor. Trata subida de nível.
function addPlayerStat(player, field, amount)
    local row = stats[player]
    if not row or row[field] == nil then return nil end
    amount = tonumber(amount) or 1
    local oldLevel = DM.levelFromXP(row.xp)
    row[field] = math.max(0, row[field] + amount)
    pushStatsToClient(player)
    if field == "xp" then
        local newLevel = DM.levelFromXP(row.xp)
        if newLevel > oldLevel then
            triggerClientEvent(player, "dm:levelUp", resourceRoot, newLevel, DM.rankForLevel(newLevel).name)
            local rank = DM.rankForLevel(newLevel)
            sendServerMessage(root, string.format("#FFFFFF%s #8B93A7subiu para o nível %s%d #8B93A7(%s)",
                getPlayerVisibleName(player), DM.rgbToHex(unpack(rank.color)), newLevel, rank.name))
        end
    end
    return row[field]
end

function setPlayerStatMax(player, field, value)
    local row = stats[player]
    if row and row[field] ~= nil and value > row[field] then
        row[field] = value
        pushStatsToClient(player)
    end
end

-- Top jogadores por kills
function getTopPlayers(limit, callback)
    if not db then return end
    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        callback(result or {})
    end, db, "SELECT name, kills, deaths, xp FROM players ORDER BY kills DESC LIMIT ?", tonumber(limit) or 10)
end

-- Eventos
addEventHandler("onResourceStart", resourceRoot, function()
    initDB()
    setTimer(function()
        for player in pairs(stats) do
            if isElement(player) then savePlayerStats(player) else stats[player] = nil end
        end
    end, DM.server.saveInterval, 0)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(stats) do
        if isElement(player) then savePlayerStats(player) end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    savePlayerStats(source)
    stats[source] = nil
    sessionStart[source] = nil
end)

-- Ao logar em uma conta, recarrega as stats da conta (migra do serial se era convidado)
addEventHandler("onPlayerLogin", root, function()
    if stats[source] then savePlayerStats(source) end
    stats[source] = nil
    loadPlayerStats(source)
end)

addEventHandler("onPlayerLogout", root, function()
    if stats[source] then savePlayerStats(source) end
    stats[source] = nil
    loadPlayerStats(source)
end)
