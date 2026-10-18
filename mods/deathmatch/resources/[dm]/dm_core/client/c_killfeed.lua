--[[
    Killfeed (topo direito, por arena) com deslize e brilho; feedback de kill no centro
    (ícone pulsando, ELIMINADO/HEADSHOT! com glow, +$ subindo); banner de sequência; elo.
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
        tick = getTickCount(), mine = killer == localPlayer, me = victim == localPlayer, id = getTickCount() + math.random(999),
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
    local w, h = s(360), s(34)
    local x, y = UI.sw - w - s(24), s(24)
    for _, e in ipairs(KillFeed.entries) do
        local age = now - e.tick
        local a = 1
        if age > KillFeed.LIFE - 500 then a = math.max(0, (KillFeed.LIFE - age) / 500) end
        local slide = (1 - UI.ease(math.min(1, age / 420), "outBack")) * s(80)
        local ex = x + slide
        local ey = UI.tween("kf:y:" .. e.id, y, 200, "outCubic")
        local c = e.mine and UI.palette.accent or (e.me and UI.palette.danger or nil)
        UI.rrect(ex, ey, w, h, UI.color("card", 215 * a), s(8), {
            border = 1, borderColor = c and tocolor(c[1], c[2], c[3], 120 * a) or tocolor(255, 255, 255, 18 * a),
            glow = c and s(10) or 0, glowColor = c and tocolor(c[1], c[2], c[3], 70 * a) or nil,
            gradient = c and tocolor(c[1], c[2], c[3], 40 * a) or nil, gradientMode = 2,
        })
        UI.image(e.headshot and "headshot.png" or "skull.png", ex + s(10), ey + s(7), s(20), s(20), tocolor(255, 255, 255, 230 * a))
        local line
        if e.killer then
            line = ("%s%s #8FA39A» %s%s #8FA39A· #7CFFB2%s%s"):format(e.mine and "#7CFFB2" or "#FFFFFF", e.killer, e.me and "#FF4D6D" or "#FFFFFF", e.victim, e.weapon, e.headshot and " #FFB547✦" or "")
        else
            line = ("#FFFFFF%s #8FA39Amorreu · %s"):format(e.victim, e.weapon)
        end
        UI.text(line, ex + s(36), ey, w - s(50), h, tocolor(255, 255, 255, 255 * a), "medium", 10, "right", "center", true, false, true)
        y = y + h + s(6)
    end

    -- Feedback de kill no centro
    for i = #rewards, 1, -1 do if now - rewards[i].tick > 2600 then table.remove(rewards, i) end end
    local ry = UI.sh / 2 + s(70)
    for _, r in ipairs(rewards) do
        local age = now - r.tick
        local a = age < 150 and UI.ease(age / 150) or (age > 2000 and math.max(0, (2600 - age) / 600) or 1)
        local rise = UI.ease(math.min(1, age / 2600)) * s(34)
        local pop = 1 + (1 - UI.ease(math.min(1, age / 380), "outBack")) * 0.6
        local isz = s(46) * pop
        local col = r.headshot and UI.palette.warn or UI.palette.accent
        UI.image(r.headshot and "headshot.png" or "skull.png", UI.sw / 2 - isz / 2, ry - rise - s(56) - (isz - s(46)) / 2, isz, isz, tocolor(255, 255, 255, 255 * a))
        UI.textGlow(r.headshot and "HEADSHOT!" or "ELIMINADO", 0, ry - rise, UI.sw, s(24), tocolor(col[1], col[2], col[3], 255 * a), tocolor(col[1], col[2], col[3], 140 * a), "bold", 15, "center", "center")
        UI.textShadow(r.text .. (r.money > 0 and ("   +" .. DM.formatMoney(r.money)) or ""), 0, ry - rise + s(24), UI.sw, s(20), r.money > 0 and UI.color("money", 255 * a) or UI.color("muted", 255 * a), "semibold", 12, "center", "center")
        ry = ry + s(70)
    end

    -- Banner de sequência
    if streakBanner then
        local age = now - streakBanner.tick
        if age > 3500 then
            streakBanner = nil
        else
            local a = age < 250 and UI.ease(age / 250, "outBack") or (age > 3000 and math.max(0, (3500 - age) / 500) or 1)
            local text = ("%s %s"):format(streakBanner.name, streakBanner.text)
            local tw = UI.textWidth(text, "bold", 15) + s(90)
            local bx, by = (UI.sw - tw) / 2, s(92)
            local pulse = UI.pulse(600, 0.7, 1)
            UI.rrect(bx, by, tw, s(46), UI.color("card", 235 * a), s(12), { border = 1, borderColor = UI.color("danger", 170 * a), glow = s(10) + s(10) * pulse, glowColor = UI.color("danger", 120 * a), gradient = UI.color("danger", 30 * a), gradientMode = 2 })
            UI.image("flame.png", bx + s(10), by + s(9), s(28) * (0.9 + 0.1 * pulse), s(28) * (0.9 + 0.1 * pulse), tocolor(255, 255, 255, 255 * a))
            UI.textGlow(("%d"):format(streakBanner.streak), bx + s(42), by, s(30), s(46), UI.color("danger", 255 * a), UI.color("danger", 140 * a), "bold", 18, "center", "center")
            UI.text(text, bx + s(76), by, tw - s(90), s(46), tocolor(255, 255, 255, 255 * a), "bold", 15, "left", "center")
        end
    end
end)
