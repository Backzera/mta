--[[
    Nametags customizadas: nível, nome e barra de vida sobre a cabeça.
]]

local MAX_DIST = 60

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do setPlayerNametagShowing(p, false) end
end)
addEventHandler("onClientPlayerJoin", root, function() setPlayerNametagShowing(source, false) end)

addEventHandler("onClientRender", root, function()
    if not getElementData(localPlayer, "dm:ready") then return end
    local s = UI.s
    local cx, cy, cz = getCameraMatrix()
    for _, player in ipairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and isElementOnScreen(player) and not isPedDead(player) then
            local x, y, z = getPedBonePosition(player, 8)
            if x then
                local dist = getDistanceBetweenPoints3D(cx, cy, cz, x, y, z)
                if dist <= MAX_DIST and isLineOfSightClear(cx, cy, cz, x, y, z, true, false, false, true, false, false, false, localPlayer) then
                    local sx, sy = getScreenFromWorldPosition(x, y, z + 0.35, 0)
                    if sx then
                        local scale = UI.clamp(1.15 - dist / MAX_DIST, 0.55, 1)
                        local alpha = UI.clamp(1.4 - dist / MAX_DIST, 0.35, 1)
                        local name = DM.stripColors(getPlayerName(player))
                        local level = tonumber(getElementData(player, "dm:level")) or 1
                        local rank = DM.rankForLevel(level)
                        local health = math.max(0, getElementHealth(player)) / 100
                        local armor = getPedArmor(player) / 100
                        local protected = getElementData(player, "dm:protected")

                        local fontSize = 11
                        local nameW = UI.textWidth(name, "semibold", fontSize) * scale
                        local lvl = tostring(level)
                        local lvlW = (UI.textWidth(lvl, "bold", 9) + s(10)) * scale
                        local barW = math.max(s(90) * scale, nameW + lvlW + s(8))
                        local bx = sx - barW / 2
                        local by = sy - s(26) * scale
                        -- nível
                        UI.rect(bx, by - s(16) * scale, lvlW, s(16) * scale, UI.rgb(rank.color, 220 * alpha), s(4))
                        local f = UI.font("bold", 9)
                        dxDrawText(lvl, bx, by - s(16) * scale, bx + lvlW, by, tocolor(10, 12, 18, 255 * alpha), scale * (type(f) == "string" and 1 or 1), f, "center", "center")
                        -- nome
                        local nf = UI.font("semibold", fontSize)
                        dxDrawText(name, bx + lvlW + s(6) + 1, by - s(16) * scale + 1, bx + barW + 1, by + 1, tocolor(0, 0, 0, 160 * alpha), scale, nf, "left", "center")
                        dxDrawText(name, bx + lvlW + s(6), by - s(16) * scale, bx + barW, by, protected and UI.color("accent", 255 * alpha) or tocolor(255, 255, 255, 255 * alpha), scale, nf, "left", "center")
                        -- vida
                        local hcol = health > 0.5 and UI.palette.health or (health > 0.25 and UI.palette.warn or UI.palette.danger)
                        UI.bar(bx, by + s(3), barW, s(5) * scale, health, UI.rgb(hcol, 230 * alpha), tocolor(0, 0, 0, 120 * alpha), 2)
                        if armor > 0 then
                            UI.bar(bx, by + s(3) + s(6) * scale, barW, s(3) * scale, armor, UI.color("armor", 230 * alpha), tocolor(0, 0, 0, 120 * alpha), 1)
                        end
                    end
                end
            end
        end
    end
end)
