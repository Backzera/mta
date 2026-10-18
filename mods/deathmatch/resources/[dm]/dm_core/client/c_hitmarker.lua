--[[
    Hitmarker + número de dano. Armas de fogo: confirmação do servidor (dm_weapons).
    Corpo a corpo: evento de dano padrão.
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
    if GUNS[weapon] and weaponsResourceRunning() then return end -- vem pelo dm:hitConfirm
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
        if age > 700 then
            table.remove(hits, i)
        else
            local a = 1 - age / 700
            if i == 1 and age < 220 then
                local color = h.headshot and UI.color("warn", 255 * (1 - age / 220)) or tocolor(255, 255, 255, 230 * (1 - age / 220))
                if h.killed then color = UI.color("danger", 255 * (1 - age / 220)) end
                local len, gap, t = s(10), s(6), s(2)
                dxDrawLine(cx - gap - len, cy - gap - len, cx - gap, cy - gap, color, t)
                dxDrawLine(cx + gap + len, cy - gap - len, cx + gap, cy - gap, color, t)
                dxDrawLine(cx - gap - len, cy + gap + len, cx - gap, cy + gap, color, t)
                dxDrawLine(cx + gap + len, cy + gap + len, cx + gap, cy + gap, color, t)
            end
            if h.damage > 0 then
                local rise = UI.ease(age / 700) * s(40)
                UI.textShadow(("-%d%s"):format(h.damage, h.headshot and " HS" or ""), cx + s(30), cy - s(40) - rise - (i - 1) * s(18), s(100), s(20),
                    h.headshot and UI.color("warn", 255 * a) or tocolor(255, 255, 255, 255 * a), "bold", 13, "left", "center")
            end
        end
    end
end)
