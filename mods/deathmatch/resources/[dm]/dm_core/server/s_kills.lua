--[[
    Kills: kill chat, killfeed, sequências, XP, headshots.
]]

local function isHeadshot(bodypart)
    return bodypart == 9
end

addEventHandler("onPlayerWasted", root, function(ammo, killer, weapon, bodypart)
    local victim = source
    local arena = getPlayerArena(victim)
    if not arena then return end

    local arenaPlayers = getArenaPlayers(arena.id)
    local victimName = getPlayerVisibleName(victim)
    local headshot = isHeadshot(bodypart)
    local weaponName = DM.weaponName(weapon)

    -- Morte do próprio jogador
    addPlayerStat(victim, "deaths", 1)
    setPlayerStreak(victim, 0)

    local killerValid = isElement(killer) and getElementType(killer) == "player" and killer ~= victim
    if killerValid and getElementData(killer, "dm:arena") ~= arena.id then
        -- morto por alguém de outra arena? (não deveria acontecer) — trata como morte sem killer
        killerValid = false
    end

    if killerValid then
        local killerName = getPlayerVisibleName(killer)
        local streak = getPlayerStreak(killer) + 1
        setPlayerStreak(killer, streak)
        setPlayerStatMax(killer, "best_streak", streak)

        local xp = DM.server.xpKill + math.min(streak - 1, 10) * DM.server.xpStreakBonus
        if headshot then
            xp = xp + DM.server.xpHeadshot
            addPlayerStat(killer, "headshots", 1)
        end
        addPlayerStat(killer, "kills", 1)
        addPlayerStat(killer, "xp", xp)

        -- Recompensas ao matar
        if DM.server.healOnKill > 0 then
            setElementHealth(killer, math.min(100, getElementHealth(killer) + DM.server.healOnKill))
        end
        if DM.server.refillOnKill and not getElementData(killer, "dm:inDuel") then
            for _, w in ipairs(arena.weapons) do
                local current = getPedTotalAmmo(killer, getSlotFromWeapon(w[1]))
                if current < w[2] then giveWeapon(killer, w[1], w[2] - current, false) end
            end
        end

        -- Kill chat (para a arena inteira)
        local hs = headshot and " #FFB547[HEADSHOT]" or ""
        for _, p in ipairs(arenaPlayers) do
            outputChatBox(("#FF4D6D[KILL] #FFFFFF%s #8B93A7matou #FFFFFF%s #8B93A7com #00E5A8%s%s"):format(
                killerName, victimName, weaponName, hs), p, 255, 255, 255, true)
        end

        -- Killfeed + feedback individual
        triggerClientEvent(arenaPlayers, "dm:onKill", resourceRoot, killerName, victimName, weapon, headshot, killer, victim)
        triggerClientEvent(killer, "dm:onKillReward", resourceRoot, victimName, xp, headshot, streak)
        triggerClientEvent(victim, "dm:onDeath", resourceRoot, killerName, weapon, headshot, DM.server.respawnDelay)

        -- Sequência
        local streakInfo = DM.streaks[streak]
        if streakInfo then
            local msg = ("%s[SEQUÊNCIA] #FFFFFF%s #FFFFFF%s #8B93A7(%d kills)"):format(streakInfo.color, killerName, streakInfo.text, streak)
            local target = streak >= 8 and root or arenaPlayers
            if type(target) == "table" then
                for _, p in ipairs(target) do outputChatBox(msg, p, 255, 255, 255, true) end
            else
                outputChatBox(msg, root, 255, 255, 255, true)
            end
            triggerClientEvent(target, "dm:onStreak", resourceRoot, killerName, streak, streakInfo.text)
        end
    else
        -- Morte sem assassino (queda, suicídio, explosão...)
        for _, p in ipairs(arenaPlayers) do
            outputChatBox(("#8B93A7[MORTE] #FFFFFF%s #8B93A7morreu (%s)"):format(victimName, weaponName), p, 255, 255, 255, true)
        end
        triggerClientEvent(arenaPlayers, "dm:onKill", resourceRoot, false, victimName, weapon, false, false, victim)
        triggerClientEvent(victim, "dm:onDeath", resourceRoot, false, weapon, false, DM.server.respawnDelay)
    end
end)
