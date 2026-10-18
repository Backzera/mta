--[[
    Estatísticas persistentes (SQLite). Chave = conta (ou serial para convidados).
    Campos: kills, deaths, headshots, best_streak, duels_won, duels_lost,
            money ($), rp (pontos de rank), ranked_wins/losses/kills,
            vip (0-3), vip_until, tag, name_color, perks (json), clan_id, clan_role, daily_last, playtime
]]

local db
local stats = {}        -- player -> row (cache)
local sessionStart = {} -- player -> tick
local loading = {}      -- player -> key em carregamento

local INT_COLUMNS = { "kills", "deaths", "headshots", "best_streak", "duels_won", "duels_lost", "money", "rp",
    "ranked_wins", "ranked_losses", "ranked_kills", "vip", "vip_until", "clan_id", "daily_last", "playtime", "first_seen", "last_seen" }
local TEXT_COLUMNS = { "tag", "name_color", "perks", "clan_role", "custom_tag" }

local function initDB()
    db = dbConnect("sqlite", "data/stats.db")
    if not db then
        outputDebugString("[dm_core] Falha ao abrir banco de dados stats.db", 1)
        return
    end
    dbExec(db, [[CREATE TABLE IF NOT EXISTS players (
        key TEXT PRIMARY KEY, name TEXT,
        kills INTEGER DEFAULT 0, deaths INTEGER DEFAULT 0, headshots INTEGER DEFAULT 0, best_streak INTEGER DEFAULT 0,
        duels_won INTEGER DEFAULT 0, duels_lost INTEGER DEFAULT 0,
        xp INTEGER DEFAULT 0, playtime INTEGER DEFAULT 0, first_seen INTEGER DEFAULT 0, last_seen INTEGER DEFAULT 0
    )]])
    -- migração: colunas novas (ALTER falha silenciosamente se já existir)
    local adds = {
        money = "INTEGER DEFAULT 0", rp = "INTEGER DEFAULT 0", ranked_wins = "INTEGER DEFAULT 0", ranked_losses = "INTEGER DEFAULT 0",
        ranked_kills = "INTEGER DEFAULT 0", vip = "INTEGER DEFAULT 0", vip_until = "INTEGER DEFAULT 0", tag = "TEXT DEFAULT ''",
        custom_tag = "TEXT DEFAULT ''", name_color = "TEXT DEFAULT ''", perks = "TEXT DEFAULT ''", clan_id = "INTEGER DEFAULT 0",
        clan_role = "TEXT DEFAULT ''", daily_last = "INTEGER DEFAULT 0",
    }
    local existing = {}
    local qh = dbQuery(db, "PRAGMA table_info(players)")
    for _, col in ipairs(dbPoll(qh, -1) or {}) do existing[col.name] = true end
    local migrated = false
    for name, def in pairs(adds) do
        if not existing[name] then
            dbExec(db, "ALTER TABLE players ADD COLUMN " .. name .. " " .. def)
            migrated = true
        end
    end
    if migrated and existing.xp and not existing.rp then
        dbExec(db, "UPDATE players SET rp = xp WHERE rp = 0") -- progresso antigo vira RP
    end
    dbExec(db, "CREATE INDEX IF NOT EXISTS idx_players_kills ON players(kills DESC)")
    dbExec(db, "CREATE INDEX IF NOT EXISTS idx_players_rp ON players(rp DESC)")
end

function getDB() return db end

function getStatsKey(player)
    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        return "acc:" .. getAccountName(account)
    end
    return "serial:" .. (getPlayerSerial(player) or getPlayerName(player))
end

-- perks (tabela) <-> texto
local function decodePerks(text)
    if not text or text == "" then return {} end
    local ok, t = pcall(fromJSON, text)
    return (ok and type(t) == "table") and t or {}
end

function playerHasPerk(player, key)
    local row = stats[player]
    return row ~= nil and row._perks[key] == true
end

function givePlayerPerk(player, key)
    local row = stats[player]
    if not row then return false end
    row._perks[key] = true
    row.perks = toJSON(row._perks)
    pushStatsToClient(player)
    return true
end

function isPlayerVip(player)
    local row = stats[player]
    if not row or row.vip <= 0 then return 0 end
    if row.vip_until > 0 and row.vip_until < getRealTime().timestamp then
        row.vip = 0
        row.vip_until = 0
        pushStatsToClient(player)
        return 0
    end
    return row.vip
end

function pushStatsToClient(player)
    local row = stats[player]
    if not row then return end
    local tier = DM.tierForRP(row.rp)
    setElementData(player, "dm:kills", row.kills)
    setElementData(player, "dm:deaths", row.deaths)
    setElementData(player, "dm:money", row.money)
    setElementData(player, "dm:rp", row.rp)
    setElementData(player, "dm:level", DM.levelFromXP(row.rp))
    setElementData(player, "dm:tier", tier.name)
    setElementData(player, "dm:headshots", row.headshots)
    setElementData(player, "dm:bestStreak", row.best_streak)
    setElementData(player, "dm:duelsWon", row.duels_won)
    setElementData(player, "dm:duelsLost", row.duels_lost)
    setElementData(player, "dm:rankedWins", row.ranked_wins)
    setElementData(player, "dm:rankedLosses", row.ranked_losses)
    setElementData(player, "dm:vip", isPlayerVip(player))
    setElementData(player, "dm:perks", row._perks)
    setElementData(player, "dm:clanId", row.clan_id)
    if refreshPlayerTag then refreshPlayerTag(player) end
end

local function newRow(key, player)
    local now = getRealTime().timestamp
    return {
        key = key, name = getPlayerVisibleName(player),
        kills = 0, deaths = 0, headshots = 0, best_streak = 0, duels_won = 0, duels_lost = 0,
        money = 0, rp = 0, ranked_wins = 0, ranked_losses = 0, ranked_kills = 0,
        vip = 0, vip_until = 0, tag = "", custom_tag = "", name_color = "", perks = "", clan_id = 0, clan_role = "",
        daily_last = 0, playtime = 0, first_seen = now, last_seen = now, _new = true,
    }
end

function loadPlayerStats(player, callback)
    if not db or not isElement(player) then return end
    local key = getStatsKey(player)
    if loading[player] == key then return end
    loading[player] = key
    sessionStart[player] = getTickCount()
    dbQuery(function(qh, p, k)
        local result = dbPoll(qh, 0)
        if loading[p] == k then loading[p] = nil end
        if not isElement(p) then return end
        if getStatsKey(p) ~= k then return end
        local row
        if result and result[1] then
            row = result[1]
            for _, col in ipairs(INT_COLUMNS) do row[col] = tonumber(row[col]) or 0 end
            for _, col in ipairs(TEXT_COLUMNS) do if type(row[col]) ~= "string" then row[col] = "" end end
            row.name = getPlayerVisibleName(p)
        else
            row = newRow(k, p)
            dbExec(db, "INSERT OR IGNORE INTO players (key, name, first_seen, last_seen) VALUES (?, ?, ?, ?)",
                k, row.name, row.first_seen, row.last_seen)
        end
        row._perks = decodePerks(row.perks)
        stats[p] = row
        pushStatsToClient(p)
        triggerEvent("dm:onStatsLoaded", p, row._new == true)
        if callback then callback(p, row) end
    end, { player, key }, db, "SELECT * FROM players WHERE key = ?", key)
end
addEvent("dm:onStatsLoaded")

function savePlayerStats(player)
    local row = stats[player]
    if not db or not row or not isElement(player) then return end
    if sessionStart[player] then
        row.playtime = row.playtime + math.floor((getTickCount() - sessionStart[player]) / 1000)
        sessionStart[player] = getTickCount()
    end
    row.last_seen = getRealTime().timestamp
    row.name = getPlayerVisibleName(player)
    dbExec(db, [[UPDATE players SET name=?, kills=?, deaths=?, headshots=?, best_streak=?, duels_won=?, duels_lost=?,
        money=?, rp=?, ranked_wins=?, ranked_losses=?, ranked_kills=?, vip=?, vip_until=?, tag=?, custom_tag=?, name_color=?,
        perks=?, clan_id=?, clan_role=?, daily_last=?, playtime=?, last_seen=? WHERE key=?]],
        row.name, row.kills, row.deaths, row.headshots, row.best_streak, row.duels_won, row.duels_lost,
        row.money, row.rp, row.ranked_wins, row.ranked_losses, row.ranked_kills, row.vip, row.vip_until, row.tag, row.custom_tag,
        row.name_color, row.perks, row.clan_id, row.clan_role, row.daily_last, row.playtime, row.last_seen, row.key)
end

function getPlayerStats(player) return stats[player] end

-- Define um campo diretamente (texto ou número)
function setPlayerStat(player, field, value)
    local row = stats[player]
    if not row or row[field] == nil then return false end
    row[field] = value
    pushStatsToClient(player)
    return true
end

-- Incrementa um campo numérico. Para "rp" trata mudança de elo.
function addPlayerStat(player, field, amount)
    local row = stats[player]
    if not row or type(row[field]) ~= "number" then return nil end
    amount = tonumber(amount) or 1
    local oldTier = DM.tierForRP(row.rp)
    row[field] = math.max(0, row[field] + amount)
    pushStatsToClient(player)
    if field == "rp" then
        local newTier = DM.tierForRP(row.rp)
        if newTier ~= oldTier then
            local up = newTier.min > oldTier.min
            triggerClientEvent(player, "dm:tierChange", resourceRoot, newTier.name, up)
            if up then
                sendServerMessage(root, string.format("#FFFFFF%s #969BB4subiu para o elo %s%s#969BB4!",
                    getPlayerVisibleName(player), DM.rgbToHex(unpack(newTier.color)), newTier.name))
            end
        end
    end
    return row[field]
end

-- $: aplica multiplicador de VIP em ganhos; motivo vai para o cliente
function addMoney(player, amount, reason, noMultiplier)
    local row = stats[player]
    if not row then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 and not noMultiplier then
        local vip = isPlayerVip(player)
        local mult = DM.economy.vipMultiplier[vip]
        if mult then amount = math.floor(amount * mult) end
    end
    row.money = math.max(0, row.money + amount)
    pushStatsToClient(player)
    if amount ~= 0 then
        triggerClientEvent(player, "dm:onMoney", resourceRoot, amount, reason or "", row.money)
    end
    return true, amount
end

function takeMoney(player, amount)
    local row = stats[player]
    amount = math.floor(tonumber(amount) or 0)
    if not row or amount < 0 or row.money < amount then return false end
    row.money = row.money - amount
    pushStatsToClient(player)
    triggerClientEvent(player, "dm:onMoney", resourceRoot, -amount, "", row.money)
    return true
end

function getPlayerMoney(player)
    local row = stats[player]
    return row and row.money or 0
end

function setPlayerVip(player, level, days)
    local row = stats[player]
    if not row then return false end
    level = math.max(0, math.min(3, tonumber(level) or 0))
    if level == 0 then
        row.vip_until = 0
    else
        local now = getRealTime().timestamp
        local base = (row.vip_until > now and row.vip == level) and row.vip_until or now
        row.vip_until = base + (tonumber(days) or 30) * 86400
    end
    row.vip = level
    pushStatsToClient(player)
    return true
end

function setPlayerStatMax(player, field, value)
    local row = stats[player]
    if row and type(row[field]) == "number" and value > row[field] then
        row[field] = value
        pushStatsToClient(player)
    end
end

-- Rankings
function getTopPlayers(field, limit, callback)
    if not db then return end
    local allowed = { kills = true, rp = true, money = true, duels_won = true, headshots = true }
    if not allowed[field] then field = "kills" end
    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        callback(result or {})
    end, db, "SELECT name, kills, deaths, rp, money, duels_won FROM players ORDER BY " .. field .. " DESC LIMIT ?", tonumber(limit) or 10)
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
    loading[source] = nil
end)

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
