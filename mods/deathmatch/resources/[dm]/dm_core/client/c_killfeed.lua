--[[
    Killfeed (canto superior direito, por arena/dimensão) + feedback de kill no centro
    (ícone de caveira / headshot, $ ganho) + banner de sequência.
]]

KillFeed = { entries = {}, LIFE = 6500, MAX = 6 }
local rewards = {}
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
addEventHandler("dm:onKillReward", root, function(victimName, money, headshot, streak)
    playUISound(headshot and "headshot" or "kill", 0.8)
    table.insert(rewards, 1, { text = ("Você eliminou %s"):format(victimName), money = money or 0, headshot = headshot, tick = getTickCount() })
    if #rewards > 3 then table.remove(rewards) end
end)

addEvent("dm:onStreak", true)
addEventHandler("dm:onStreak", root, function(name, streak, text)
    streakBanner = { name = name, streak = streak, text = text, tick = getTickCount() }
    playUISound("streak", 0.6)
end)

addEvent("dm:tierChange", true)
addEventHandler("dm:tierChange", root, function(tierName, up)
    playUISound(up and "levelup" or "lose", 0.7)
    notify(up and ("Você subiu para o elo %s!"):format(tierName) or ("Você caiu para o elo %s."):format(tierName), up and "success" or "warn", "Elo")
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local s = UI.s
    for i = #KillFeed.entries, 1, -1 do
        if now - KillFeed.entries[i].tick > KillFeed.LIFE then table.remove(KillFeed.entries, i) end
    end
    local w = s(360)
    local x = UI.sw - w - s(24)
    local y = s(24)
    for _, e in ipairs(KillFeed.entries) do
        local age = now - e.tick
        local a = 1
        if age < 180 then a = UI.ease(age / 180) end
        if age > KillFeed.LIFE - 500 then a = math.max(0, (KillFeed.LIFE - age) / 500) end
        local h = s(34)
        local ex = x + (1 - a) * s(30)
        UI.rect(ex, y, w, h, UI.color("card", 220 * a), s(8))
        if e.mine then UI.rect(ex, y, w, h, UI.color("accent", 60 * a), s(8)) end
        if e.me then UI.rect(ex, y, w, h, UI.color("danger", 60 * a), s(8)) end
        UI.border(ex, y, w, h, tocolor(255, 255, 255, 18 * a), s(8))
        UI.image(e.headshot and "headshot.png" or "skull.png", ex + s(10), y + s(7), s(20), s(20), tocolor(255, 255, 255, 230 * a))
        local line
        if e.killer then
            line = ("%s%s #969BB4» %s%s #969BB4· #7CFFB2%s%s"):format(
                e.mine and "#7CFFB2" or "#FFFFFF", e.killer,
                e.me and "#FF4D6D" or "#FFFFFF", e.victim, e.weapon, e.headshot and " #FFB547HS" or "")
        else
            line = ("#FFFFFF%s #969BB4morreu · %s"):format(e.victim, e.weapon)
        end
        UI.text(line, ex + s(36), y, w - s(50), h, tocolor(255, 255, 255, 255 * a), "medium", 10, "right", "center", true, false, true)
        y = y + h + s(6)
    end

    -- Feedback de kill no centro
    for i = #rewards, 1, -1 do
        if now - rewards[i].tick > 2600 then table.remove(rewards, i) end
    end
    local ry = UI.sh / 2 + s(60)
    for _, r in ipairs(rewards) do
        local age = now - r.tick
        local a = age < 150 and UI.ease(age / 150) or (age > 2000 and math.max(0, (2600 - age) / 600) or 1)
        local rise = UI.ease(math.min(1, age / 2600)) * s(30)
        local pop = age < 250 and (1 + (1 - age / 250) * 0.5) or 1
        local iconSize = s(44) * pop
        UI.image(r.headshot and "headshot.png" or "skull.png", UI.sw / 2 - iconSize / 2, ry - rise - s(50) - (iconSize - s(44)) / 2, iconSize, iconSize, tocolor(255, 255, 255, 255 * a))
        UI.textShadow(r.headshot and "HEADSHOT!" or "ELIMINADO", 0, ry - rise, UI.sw, s(22), r.headshot and UI.color("warn", 255 * a) or UI.color("text", 255 * a), "bold", 14, "center", "center")
        UI.textShadow(r.text .. (r.money > 0 and ("   +" .. DM.formatMoney(r.money)) or ""), 0, ry - rise + s(22), UI.sw, s(20), r.money > 0 and UI.color("money", 255 * a) or UI.color("muted", 255 * a), "semibold", 12, "center", "center")
        ry = ry + s(64)
    end

    if streakBanner then
        local age = now - streakBanner.tick
        if age > 3500 then
            streakBanner = nil
        else
            local a = age < 200 and UI.ease(age / 200) or (age > 3000 and math.max(0, (3500 - age) / 500) or 1)
            local text = ("%s %s"):format(streakBanner.name, streakBanner.text)
            local tw = UI.textWidth(text, "bold", 15) + s(80)
            local bx, by = (UI.sw - tw) / 2, s(92)
            UI.rect(bx, by, tw, s(44), UI.color("card", 235 * a), s(10))
            UI.border(bx, by, tw, s(44), UI.color("danger", 160 * a), s(10))
            UI.image("flame.png", bx + s(10), by + s(8), s(28), s(28), tocolor(255, 255, 255, 255 * a))
            UI.text(("%d"):format(streakBanner.streak), bx + s(40), by, s(28), s(44), UI.color("danger", 255 * a), "bold", 16, "center", "center")
            UI.text(text, bx + s(70), by, tw - s(82), s(44), tocolor(255, 255, 255, 255 * a), "bold", 15, "left", "center")
        end
    end
end)
