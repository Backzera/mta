--[[
    Killfeed no canto superior direito + feedback de kill no centro.
]]

KillFeed = { entries = {}, LIFE = 6500, MAX = 6 }
local rewards = {}  -- textos de recompensa no centro
local streakBanner

function KillFeed.height()
    if #KillFeed.entries == 0 then return 0 end
    return #KillFeed.entries * (UI.s(34) + UI.s(6))
end

addEvent("dm:onKill", true)
addEventHandler("dm:onKill", root, function(killerName, victimName, weapon, headshot, killer, victim)
    table.insert(KillFeed.entries, 1, {
        killer = killerName, victim = victimName, weapon = DM.weaponName(weapon), headshot = headshot,
        tick = getTickCount(), mine = killer == localPlayer, me = victim == localPlayer,
    })
    if #KillFeed.entries > KillFeed.MAX then table.remove(KillFeed.entries) end
end)

addEvent("dm:onKillReward", true)
addEventHandler("dm:onKillReward", root, function(victimName, xp, headshot, streak)
    playUISound(headshot and "headshot" or "kill", 0.7)
    table.insert(rewards, 1, { text = ("Você eliminou %s"):format(victimName), xp = xp, headshot = headshot, tick = getTickCount() })
    if #rewards > 3 then table.remove(rewards) end
end)

addEvent("dm:onStreak", true)
addEventHandler("dm:onStreak", root, function(name, streak, text)
    streakBanner = { name = name, streak = streak, text = text, tick = getTickCount() }
    playUISound("streak", 0.6)
end)

addEvent("dm:levelUp", true)
addEventHandler("dm:levelUp", root, function(level, rankName)
    playUISound("levelup", 0.7)
    notify(("Você alcançou o nível %d (%s)!"):format(level, rankName), "success", "Subiu de nível")
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local s = UI.s
    -- Killfeed
    for i = #KillFeed.entries, 1, -1 do
        if now - KillFeed.entries[i].tick > KillFeed.LIFE then table.remove(KillFeed.entries, i) end
    end
    local w = s(340)
    local x = UI.sw - w - s(24)
    local y = s(24)
    for _, e in ipairs(KillFeed.entries) do
        local age = now - e.tick
        local a = 1
        if age < 180 then a = UI.ease(age / 180) end
        if age > KillFeed.LIFE - 500 then a = math.max(0, (KillFeed.LIFE - age) / 500) end
        local h = s(34)
        local ex = x + (1 - a) * s(30)
        local bg = (e.mine or e.me) and UI.color(e.mine and "accent" or "danger", 50 * a) or UI.color("card", 215 * a)
        UI.rect(ex, y, w, h, UI.color("card", 215 * a), h / 2)
        if e.mine or e.me then UI.rect(ex, y, w, h, bg, h / 2) end
        UI.border(ex, y, w, h, tocolor(255, 255, 255, 18 * a), h / 2)
        local padX = s(16)
        local line
        if e.killer then
            line = ("%s%s #8B93A7» %s%s #8B93A7· #00E5A8%s%s"):format(
                e.mine and "#00E5A8" or "#FFFFFF", e.killer,
                e.me and "#FF4D6D" or "#FFFFFF", e.victim, e.weapon, e.headshot and " #FFB547(HS)" or "")
        else
            line = ("#FFFFFF%s #8B93A7morreu · %s"):format(e.victim, e.weapon)
        end
        UI.text(line, ex + padX, y, w - padX * 2, h, tocolor(255, 255, 255, 255 * a), "medium", 10, "right", "center", true, false, true)
        y = y + h + s(6)
    end

    -- Recompensas (centro, abaixo da mira)
    for i = #rewards, 1, -1 do
        if now - rewards[i].tick > 2600 then table.remove(rewards, i) end
    end
    local ry = UI.sh / 2 + s(60)
    for _, r in ipairs(rewards) do
        local age = now - r.tick
        local a = age < 150 and UI.ease(age / 150) or (age > 2000 and math.max(0, (2600 - age) / 600) or 1)
        local rise = UI.ease(math.min(1, age / 2600)) * s(30)
        UI.textShadow(r.text, 0, ry - rise, UI.sw, s(22), tocolor(255, 255, 255, 230 * a), "semibold", 13, "center", "center")
        UI.textShadow(("+%d XP%s"):format(r.xp, r.headshot and "  ·  HEADSHOT" or ""), 0, ry - rise + s(22), UI.sw, s(20),
            UI.color(r.headshot and "warn" or "accent", 255 * a), "bold", 12, "center", "center")
        ry = ry + s(46)
    end

    -- Banner de sequência
    if streakBanner then
        local age = now - streakBanner.tick
        if age > 3500 then
            streakBanner = nil
        else
            local a = age < 200 and UI.ease(age / 200) or (age > 3000 and math.max(0, (3500 - age) / 500) or 1)
            local text = ("%s %s"):format(streakBanner.name, streakBanner.text)
            local tw = UI.textWidth(text, "bold", 15) + s(60)
            local bx, by = (UI.sw - tw) / 2, s(92)
            UI.rect(bx, by, tw, s(44), UI.color("card", 230 * a), s(22))
            UI.border(bx, by, tw, s(44), UI.color("danger", 160 * a), s(22))
            UI.text(("%d"):format(streakBanner.streak), bx + s(12), by + s(8), s(28), s(28), UI.color("danger", 255 * a), "bold", 14, "center", "center")
            UI.rect(bx + s(12), by + s(8), s(28), s(28), UI.color("danger", 40 * a), s(8))
            UI.text(text, bx + s(44), by, tw - s(56), s(44), tocolor(255, 255, 255, 255 * a), "bold", 15, "center", "center")
        end
    end
end)
