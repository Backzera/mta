--[[
    Hitmarker + número de dano quando você acerta alguém.
]]

local hits = {}  -- { tick, headshot, damage }

addEventHandler("onClientPlayerDamage", root, function(attacker, weapon, bodypart, loss)
    if source == localPlayer then return end
    if attacker ~= localPlayer then return end
    if getElementData(source, "dm:protected") then return end
    local headshot = bodypart == 9
    table.insert(hits, 1, { tick = getTickCount(), headshot = headshot, damage = math.floor(loss or 0) })
    if #hits > 6 then table.remove(hits) end
    playUISound(headshot and "headshot" or "hit", headshot and 0.6 or 0.45)
end)

addEventHandler("onClientRender", root, function()
    if #hits == 0 then return end
    local now = getTickCount()
    local s = UI.s
    local cx, cy = UI.sw / 2, UI.sh / 2
    for i = #hits, 1, -1 do
        local h = hits[i]
        local age = now - h.tick
        if age > 700 then
            table.remove(hits, i)
        else
            local a = 1 - age / 700
            if i == 1 and age < 220 then
                local color = h.headshot and UI.color("warn", 255 * (1 - age / 220)) or tocolor(255, 255, 255, 230 * (1 - age / 220))
                local len, gap, t = s(10), s(6), s(2)
                dxDrawLine(cx - gap - len, cy - gap - len, cx - gap, cy - gap, color, t)
                dxDrawLine(cx + gap + len, cy - gap - len, cx + gap, cy - gap, color, t)
                dxDrawLine(cx - gap - len, cy + gap + len, cx - gap, cy + gap, color, t)
                dxDrawLine(cx + gap + len, cy + gap + len, cx + gap, cy + gap, color, t)
            end
            if h.damage > 0 then
                local rise = UI.ease(age / 700) * s(40)
                UI.textShadow(("-%d"):format(h.damage), cx + s(30), cy - s(40) - rise - (i - 1) * s(18), s(80), s(20),
                    h.headshot and UI.color("warn", 255 * a) or tocolor(255, 255, 255, 255 * a), "bold", 13, "left", "center")
            end
        end
    end
end)
