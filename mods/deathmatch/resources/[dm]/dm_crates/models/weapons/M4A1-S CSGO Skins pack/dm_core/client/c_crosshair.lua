--[[
    Mira redonda fixa no centro da tela (PVP). A mira padrão do GTA fica oculta, exceto na luneta da sniper.
    Ponto central + anel fino; o anel "pisca" verde ao acertar e vermelho ao matar; abre um pouco ao atirar.
]]

local flash = { tick = 0, color = nil }
local kick = 0

addEventHandler("onClientResourceStart", resourceRoot, function()
    setPlayerHudComponentVisible("crosshair", false)
end)

addEventHandler("dm:hitConfirm", root, function(damage, headshot, victim, killed)
    flash.tick = getTickCount()
    flash.color = killed and UI.palette.danger or (headshot and UI.palette.warn or UI.palette.accent)
end)

addEventHandler("onClientPlayerWeaponFire", localPlayer, function() kick = 1 end)

addEventHandler("onClientRender", root, function()
    if not getElementData(localPlayer, "dm:ready") then return end
    if UI.getOpenPanel() or isPedDead(localPlayer) then return end
    local weapon = getPedWeapon(localPlayer)
    if weapon == 34 and getControlState("aim_weapon") then
        setPlayerHudComponentVisible("crosshair", true)
        return
    end
    setPlayerHudComponentVisible("crosshair", false)
    if weapon < 22 or weapon > 38 then return end
    kick = kick * (1 - math.min(1, UI.dt / 140))
    local cx, cy = UI.sw / 2, UI.sh / 2
    local age = getTickCount() - flash.tick
    local f = age < 180 and (1 - age / 180) or 0
    local col = UI.palette.accent2
    if f > 0 and flash.color then col = flash.color end
    local alpha = 230
    local r = UI.s(9) + UI.s(5) * kick + UI.s(4) * f
    UI.ring(cx, cy, r + 1, UI.s(3.2), 1, tocolor(0, 0, 0, 110))
    UI.ring(cx, cy, r, UI.s(1.6), 1, tocolor(col[1], col[2], col[3], alpha))
    UI.rrect(cx - UI.s(1.5), cy - UI.s(1.5), UI.s(3), UI.s(3), tocolor(col[1], col[2], col[3], alpha), UI.s(1.5), { glow = UI.s(3), glowColor = tocolor(col[1], col[2], col[3], 120) })
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setPlayerHudComponentVisible("crosshair", true)
end)
