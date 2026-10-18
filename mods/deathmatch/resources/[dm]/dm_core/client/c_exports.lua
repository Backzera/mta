-- Funções exportadas (lado cliente)
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
function getRankedModes() return DM.rankedModes end
function getPlayerArena(player)
    player = player or localPlayer
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end
