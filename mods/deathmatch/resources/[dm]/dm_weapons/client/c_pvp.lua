-- Sem dano de queda (PVP) e sem dano de fogo/afogamento acidental
addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon)
    if weapon == 54 or weapon == 37 then cancelEvent() end
end)
