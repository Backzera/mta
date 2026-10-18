--[[
    Hitmarker: traços que se expandem e somem + número de dano subindo (headshot em dourado).
    Armas de fogo: confirmação do servidor (dm:hitConfirm, via dm_weapons). Corpo a corpo: dano padrão.
]]

local hits = {}
local GUNS = { [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true,
               [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [38] = true }

local function weaponsResourceRunning()
    local res = getResourceFromName("dm_weapons")
    return res and getResourceState(res) == "running"
end

local function addHit(damage, headshot, killed)
    table.insert(hits, 1, { tick = getTickCount(), headshot = headshot, damage = math.floor(damage or 0), killed = killed })
    if #hits > 6 then table.remove(hits) end
    if not killed then playUISound(headshot and "headshot" or "hit", headshot and 0.6 or 0.45) end
end

addEvent("dm:hitConfirm")
addEventHandler("dm:hitConfirm", root, function(damage, headshot, victim, killed)
    addHit(damage, headshot, killed)
end)

addEventHandler("onClientPlayerDamage", root, function(attacker, weapon, bodypart, loss)
    if source == localPlayer or attacker ~= localPlayer then return end
    if GUNS[weapon] and weaponsResourceRunning() then return end
    if getElementData(source, "dm:protected") then return end
    addHit(loss, bodypart == 9, false)
end)

addEventHandler("onClientRender", root, function()
    if #hits == 0 then return end
    local now = getTickCount()
    local s = UI.s
    local cx, cy = UI.sw / 2, UI.sh / 2
    for i = #hits, 1, -1 do
        local h = hits[i]
        local age = now - h.tick
        if age > 750 then
            table.remove(hits, i)
        else
            local a = 1 - age / 750
            if i == 1 and age < 260 then
                local t = age / 260
                local color = h.headshot and UI.palette.warn or (h.killed and UI.palette.danger or { 255, 255, 255 })
                local alpha = 255 * (1 - UI.ease(t, "inQuad"))
                local spread = s(6) + UI.ease(t, "outCubic") * s(8)
                local len, th = s(10), s(2.2)
                local col = tocolor(color[1], color[2], color[3], alpha)
                dxDrawLine(cx - spread - len, cy - spread - len, cx - spread, cy - spread, col, th)
                dxDrawLine(cx + spread + len, cy - spread - len, cx + spread, cy - spread, col, th)
                dxDrawLine(cx - spread - len, cy + spread + len, cx - spread, cy + spread, col, th)
                dxDrawLine(cx + spread + len, cy + spread + len, cx + spread, cy + spread, col, th)
                if h.killed then
                    UI.ring(cx, cy, s(16) + spread, s(2), 1, tocolor(color[1], color[2], color[3], alpha * 0.6))
                end
            end
            if h.damage > 0 then
                local rise = UI.ease(age / 750, "outCubic") * s(44)
                UI.textGlow(("-%d%s"):format(h.damage, h.headshot and " ✦" or ""), cx + s(28), cy - s(44) - rise - (i - 1) * s(18), s(120), s(20),
                    h.headshot and UI.color("warn", 255 * a) or tocolor(255, 255, 255, 255 * a), h.headshot and UI.color("warn", 120 * a) or tocolor(0, 0, 0, 120 * a), "bold", 13, "left", "center")
            end
        end
    end
end)
