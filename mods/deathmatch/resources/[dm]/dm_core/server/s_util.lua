-- Utilitários do servidor

function getArenas() return DM.arenas end
function getArena(id) return DM.getArena(id) end
function getDuelWeaponSets() return DM.duelWeapons end
function getConfig() return DM.server end
function getRpConfig() return DM.rp end
function getEconomyConfig() return DM.economy end
function getRankedConfig() return DM.ranked end
function getShopConfig() return DM.shop end
function getVipConfig() return DM.vip end
function getClanConfig() return DM.clans end
function formatMoney(v) return DM.formatMoney(v) end
function getTierForRP(rp) return DM.tierForRP(rp) end

function getPlayerArena(player)
    if not isElement(player) then return nil end
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end

-- Mensagem no chat com cores
function sendMessage(target, text, r, g, b)
    outputChatBox(text, target or root, r or 255, g or 255, b or 255, true)
end

function sendServerMessage(target, text)
    outputChatBox(DM.server.chatPrefix .. " " .. text, target or root, 255, 255, 255, true)
end

-- Notificação (toast) no cliente: type = info | success | error | warn
function notifyPlayer(player, text, ntype, title)
    if not isElement(player) then return end
    triggerClientEvent(player, "dm:notify", resourceRoot, text, ntype or "info", title)
end

function getPlayerVisibleName(player)
    return DM.stripColors(getPlayerName(player))
end

-- Procura jogador por nome parcial (sem cores, case-insensitive)
function findPlayer(partial)
    if not partial or partial == "" then return nil end
    local id = tonumber(partial)
    if id then
        for _, p in ipairs(getElementsByType("player")) do
            if tonumber(getElementData(p, "dm:id")) == id then return p end
        end
    end
    partial = DM.stripColors(partial):lower()
    local exact, matches = nil, {}
    for _, p in ipairs(getElementsByType("player")) do
        local name = getPlayerVisibleName(p):lower()
        if name == partial then exact = p end
        if name:find(partial, 1, true) then matches[#matches + 1] = p end
    end
    if exact then return exact end
    if #matches == 1 then return matches[1] end
    return nil, #matches
end

function isPlayerAdmin(player)
    if not isElement(player) then return false end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return false end
    local name = getAccountName(account)
    for _, group in ipairs({ "Admin", "SuperModerator", "Moderator" }) do
        local g = aclGetGroup(group)
        if g and isObjectInACLGroup("user." .. name, g) then return true end
    end
    return false
end

-- Jogadores de uma arena
function getArenaPlayers(arenaId, dimension)
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:arena") == arenaId and (not dimension or getElementDimension(p) == dimension) then
            list[#list + 1] = p
        end
    end
    return list
end

function getRankedModes() return DM.rankedModes end

function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function tableContains(t, value)
    for _, v in pairs(t) do if v == value then return true end end
    return false
end
