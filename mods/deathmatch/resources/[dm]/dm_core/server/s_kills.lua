--[[
    Kills: kill chat (por arena/dimensão), killfeed, sequências, dinheiro, headshots.
    Kills NÃO dão RP (só partidas ranqueadas e duelos).
]]

local function isHeadshot(bodypart)
    return bodypart == 9
end

addEventHandler("onPlayerWasted", root, function(ammo, killer, weapon, bodypart)
    local victim = source
    local arena = getPlayerArena(victim)
    if not arena then return end

    local arenaPlayers = getArenaPlayers(arena.id, getElementDimension(victim))
    local victimName = getPlayerVisibleName(victim)
    local headshot = isHeadshot(bodypart)
    local weaponName = DM.weaponName(weapon)
    local noReward = getElementData(victim, "dm:noReward") == true

    addPlayerStat(victim, "deaths", 1)
    setPlayerStreak(victim, 0)

    local killerValid = isElement(killer) and getElementType(killer) == "player" and killer ~= victim
    if killerValid and getElementDimension(killer) ~= getElementDimension(victim) then killerValid = false end

    if killerValid then
        local killerName = getPlayerVisibleName(killer)
        local streak = getPlayerStreak(killer) + 1
        setPlayerStreak(killer, streak)
        setPlayerStatMax(killer, "best_streak", streak)
        addPlayerStat(killer, "kills", 1)
        if headshot then addPlayerStat(killer, "headshots", 1) end

        -- Dinheiro
        local money = 0
        if not noReward then
            local base = arena.type == "ranked" and DM.economy.rankedKill or DM.economy.kill
            money = base + math.min(streak - 1, 10) * DM.economy.streakBonusEach + (headshot and DM.economy.headshotBonus or 0)
            local ok, given = addMoney(killer, money, "Kill")
            money = ok and given or 0
        end

        -- Recompensas ao matar
        if DM.server.healOnKill > 0 then
            setElementHealth(killer, math.min(100, getElementHealth(killer) + DM.server.healOnKill))
        end
        if DM.server.refillOnKill and not getElementData(killer, "dm:inDuel") then
            refillPlayerWeapons(killer)
        end

        -- Kill chat (só para quem está na mesma arena/dimensão)
        local hs = headshot and " #FFB547[HEADSHOT]" or ""
        for _, p in ipairs(arenaPlayers) do
            outputChatBox(("#FF4D6D[KILL] #FFFFFF%s #969BB4matou #FFFFFF%s #969BB4com #22D3EE%s%s"):format(
                killerName, victimName, weaponName, hs), p, 255, 255, 255, true)
        end

        triggerClientEvent(arenaPlayers, "dm:onKill", resourceRoot, killerName, victimName, weapon, headshot, killer, victim)
        triggerClientEvent(killer, "dm:onKillReward", resourceRoot, victimName, money, headshot, streak)
        triggerClientEvent(victim, "dm:onDeath", resourceRoot, killerName, weapon, headshot, getPlayerRespawnDelay(victim))

        local streakInfo = DM.streaks[streak]
        if streakInfo then
            local msg = ("%s[SEQUÊNCIA] #FFFFFF%s #FFFFFF%s #969BB4(%d kills)"):format(streakInfo.color, killerName, streakInfo.text, streak)
            local target = streak >= 8 and root or arenaPlayers
            if type(target) == "table" then
                for _, p in ipairs(target) do outputChatBox(msg, p, 255, 255, 255, true) end
            else
                outputChatBox(msg, root, 255, 255, 255, true)
            end
            triggerClientEvent(target, "dm:onStreak", resourceRoot, killerName, streak, streakInfo.text)
        end
        triggerEvent("dm:onPlayerKill", killer, victim, weapon, headshot)
    else
        for _, p in ipairs(arenaPlayers) do
            outputChatBox(("#969BB4[MORTE] #FFFFFF%s #969BB4morreu (%s)"):format(victimName, weaponName), p, 255, 255, 255, true)
        end
        triggerClientEvent(arenaPlayers, "dm:onKill", resourceRoot, false, victimName, weapon, false, false, victim)
        triggerClientEvent(victim, "dm:onDeath", resourceRoot, false, weapon, false, getPlayerRespawnDelay(victim))
    end
end)
addEvent("dm:onPlayerKill")
