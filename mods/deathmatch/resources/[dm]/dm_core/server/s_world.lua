--[[
    Configuração do mundo: clima, hora, glitches, gametype.
]]

addEventHandler("onResourceStart", resourceRoot, function()
    setGameType("Mata-mata")
    setMapName("Arenas PVP")
    setWeather(DM.server.weather)
    setTime(DM.server.time[1], DM.server.time[2])
    setMinuteDuration(2147483647) -- hora congelada
    setOcclusionsEnabled(true)
    setGravity(0.008)
    setWaveHeight(0)
    setMoonSize(6)

    -- Glitches básicos: quickstand liberado (movimento fluido). O crouchbug é
    -- controlado por dm_cbug (liberado globalmente e bloqueado fora da arena C-Bug).
    setGlitchEnabled("quickstand", true)
    setGlitchEnabled("fastmove", false)
    setGlitchEnabled("fastfire", false)
    setGlitchEnabled("fastsprint", false)

    -- Sem dano de queda quase nulo não é possível via API; mantemos padrão.
    outputServerLog("[dm_core] Servidor mata-mata iniciado com " .. #DM.arenas .. " arenas.")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        setPlayerNametagShowing(player, true)
        setElementFrozen(player, false)
    end
end)

-- Arma volta com munição completa ao trocar e pegar de novo
addEventHandler("onPlayerWeaponSwitch", root, function(prevSlot, newSlot)
    if not DM.server.refillOnSwitch then return end
    local weapon = getPedWeapon(source, newSlot)
    if weapon and weapon > 1 then refillPlayerWeapons(source, weapon) end
end)

-- Previne que o jogador fique com armas de pickups do mundo (mantém regra da arena)
addEventHandler("onPlayerPickupHit", root, function(pickup)
    local arena = getPlayerArena(source)
    if not arena then return end
    if getPickupType(pickup) == 2 then -- arma
        local weapon = getPickupWeapon(pickup)
        for _, w in ipairs(arena.weapons or {}) do
            if w[1] == weapon then return end
        end
        cancelEvent()
    end
end)
