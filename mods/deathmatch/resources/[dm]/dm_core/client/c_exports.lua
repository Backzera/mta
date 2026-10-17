-- Funções exportadas (lado cliente)
function getArenas() return DM.arenas end
function getArena(id) return DM.getArena(id) end
function getDuelWeaponSets() return DM.duelWeapons end
function getConfig() return DM.server end
function getPlayerArena(player)
    player = player or localPlayer
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end
