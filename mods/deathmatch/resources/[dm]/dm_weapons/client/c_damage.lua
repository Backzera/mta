--[[
    Lado da vítima: cancela o dano padrão das armas de fogo e envia para o servidor calcular.
]]

local GUNS = { [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true,
               [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [38] = true }

addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    if not GUNS[weapon] then return end
    if not isElement(attacker) or getElementType(attacker) ~= "player" or attacker == localPlayer then return end
    cancelEvent()
    if getElementData(localPlayer, "dm:protected") then return end
    local arena = exports.dm_core:getPlayerArena(localPlayer)
    if arena and arena.safe and not getElementData(localPlayer, "dm:inDuel") then return end
    triggerServerEvent("wep:hit", localPlayer, attacker, weapon, bodypart, loss or 0)
end)

-- Confirmação de acerto (hitmarker é desenhado pelo dm_core via este evento)
addEvent("wep:hitConfirm", true)
addEventHandler("wep:hitConfirm", root, function(damage, headshot, victim, killed)
    triggerEvent("dm:hitConfirm", localPlayer, damage, headshot, victim, killed)
end)
