--[[
    Nametags: tag (staff/VIP/comprada/elo) + clã destacados acima do nick, nick colorido, vida/colete.
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
    local myTeam = getPlayerTeam(localPlayer)
    for _, player in ipairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and isElementOnScreen(player) and not isPedDead(player) then
            local x, y, z = getPedBonePosition(player, 8)
            if x then
                local dist = getDistanceBetweenPoints3D(cx, cy, cz, x, y, z)
                if dist <= MAX_DIST and isLineOfSightClear(cx, cy, cz, x, y, z, true, false, false, true, false, false, false, localPlayer) then
                    local sx, sy = getScreenFromWorldPosition(x, y, z + 0.35, 0)
                    if sx then
                        local scale = UI.clamp(1.15 - dist / MAX_DIST, 0.6, 1)
                        local alpha = UI.clamp(1.4 - dist / MAX_DIST, 0.35, 1)
                        local name = DM.stripColors(getPlayerName(player))
                        local health = math.max(0, getElementHealth(player)) / 100
                        local armor = getPedArmor(player) / 100
                        local tag = getElementData(player, "dm:tag")
                        local clan = getElementData(player, "dm:clanTag")
                        local team = getPlayerTeam(player)
                        local nr, ng, nb = UI.hexToRGB(getElementData(player, "dm:nameColor"))
                        if myTeam and team == myTeam then nr, ng, nb = 34, 230, 138 end
                        if getElementData(player, "dm:protected") then nr, ng, nb = 150, 155, 180 end

                        local nf = UI.font("semibold", 12)
                        local nameW = dxGetTextWidth(name, scale, nf)
                        local barW = math.max(s(90) * scale, nameW + s(10))
                        local bx = sy and (sx - barW / 2) or 0
                        local by = sy - s(24) * scale
                        -- Nick
                        dxDrawText(name, bx + 1, by - s(18) * scale + 1, bx + barW + 1, by + 1, tocolor(0, 0, 0, 170 * alpha), scale, nf, "center", "center")
                        dxDrawText(name, bx, by - s(18) * scale, bx + barW, by, tocolor(nr, ng, nb, 255 * alpha), scale, nf, "center", "center")
                        -- Tags acima do nick (destacadas)
                        local ty = by - s(18) * scale - s(19) * scale
                        local pills = {}
                        if type(clan) == "table" and clan.text then pills[#pills + 1] = clan end
                        if type(tag) == "table" and tag.text then pills[#pills + 1] = tag end
                        if #pills > 0 then
                            local tf = UI.font("bold", 9)
                            local total = 0
                            local widths = {}
                            for i, p in ipairs(pills) do
                                widths[i] = dxGetTextWidth(p.text, scale, tf) + s(12) * scale
                                total = total + widths[i] + (i > 1 and s(4) * scale or 0)
                            end
                            local px = sx - total / 2
                            for i, p in ipairs(pills) do
                                local r, g, b = UI.hexToRGB(p.hex)
                                local ph = s(16) * scale
                                UI.rect(px, ty, widths[i], ph, tocolor(r, g, b, (p.kind == "vip" or p.kind == "staff") and 230 * alpha or 70 * alpha), ph / 2)
                                local tc = (p.kind == "vip" or p.kind == "staff") and tocolor(12, 12, 20, 255 * alpha) or tocolor(r, g, b, 255 * alpha)
                                dxDrawText(p.text, px, ty, px + widths[i], ty + ph, tc, scale, tf, "center", "center")
                                if p.kind == "vip" then UI.image("crown.png", px - s(14) * scale, ty + s(1), s(13) * scale, s(13) * scale, tocolor(245, 196, 81, 255 * alpha)) end
                                px = px + widths[i] + s(4) * scale
                            end
                        end
                        -- Vida / colete
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
