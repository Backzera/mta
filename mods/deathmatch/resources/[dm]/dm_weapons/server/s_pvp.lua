--[[
    Ajustes de PVP: armas sem recoil/spread (precisão máxima em todos os níveis de skill),
    skill "pro" para todos os jogadores, sem dano de queda.
]]

local core = exports.dm_core
local WEAPONS = { 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 38 }
local SKILL_STATS = { [22] = 69, [23] = 70, [24] = 71, [25] = 72, [26] = 73, [27] = 74, [28] = 75, [29] = 76, [30] = 77, [31] = 78, [34] = 79, [32] = 75 }
local original = {}

addEventHandler("onResourceStart", resourceRoot, function()
    for _, id in ipairs(WEAPONS) do
        for _, skill in ipairs({ "poor", "std", "pro" }) do
            original[id .. skill] = getWeaponProperty(id, skill, "accuracy")
            setWeaponProperty(id, skill, "accuracy", 10)           -- sem spread/recoil
        end
    end
    -- todo mundo com skill pro (anima e precisão de profissional)
    for _, p in ipairs(getElementsByType("player")) do setProSkills(p) end
    outputServerLog("[dm_weapons] Armas sem recoil (accuracy 10) e skills pro aplicadas.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, id in ipairs(WEAPONS) do
        for _, skill in ipairs({ "poor", "std", "pro" }) do
            if original[id .. skill] then setWeaponProperty(id, skill, "accuracy", original[id .. skill]) end
        end
    end
end)

function setProSkills(player)
    for _, stat in pairs(SKILL_STATS) do setPedStat(player, stat, 999) end
end

addEventHandler("onPlayerSpawn", root, function() setProSkills(source) end)
addEventHandler("onPlayerJoin", root, function() setProSkills(source) end)
