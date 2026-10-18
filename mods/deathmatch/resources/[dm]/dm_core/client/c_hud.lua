--[[
    HUD minimalista UTG: logo no canto inferior esquerdo, status compacto (vida, colete, $),
    arma/munição discreta, arena no topo, info do servidor em uma linha. Sem poluição.
]]

local HUD = { visible = true, fps = 0, fpsTick = getTickCount(), frames = 0 }
local dispHealth, dispArmor = 100, 0
local moneyPops = {}

addEventHandler("onClientResourceStart", resourceRoot, function()
    setPlayerHudComponentVisible("all", false)
    setPlayerHudComponentVisible("crosshair", true)
    showChat(true)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setPlayerHudComponentVisible("all", true)
    showCursor(false)
end)

local function getArenaOf(player)
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end

local function lerp(a, b, t) return a + (b - a) * t end

addEvent("dm:onMoney", true)
addEventHandler("dm:onMoney", root, function(amount, reason, total)
    if amount == 0 then return end
    table.insert(moneyPops, 1, { amount = amount, reason = reason, tick = getTickCount() })
    if #moneyPops > 4 then table.remove(moneyPops) end
    if amount > 0 then playUISound("click", 0.3) end
end)

-- ---------- Logo (inferior esquerdo) ----------
local LOGO_W, LOGO_H = 640, 200
local function drawLogo()
    local s = UI.s
    local w = s(210)
    local h = w * LOGO_H / LOGO_W
    local x, y = s(20), UI.sh - h - s(16)
    if not UI.image("logo.png", x, y, w, h) then
        UI.textShadow("UTG", x, y, w, h * 0.6, UI.color("accent"), "bold", 30, "left", "center")
        UI.textShadow("MATA-MATA #Return2k26", x, y + h * 0.6, w, h * 0.4, UI.color("text"), "semibold", 10, "left", "center")
    end
    return x + w + s(14), y, h
end

-- ---------- Status compacto ----------
local function drawStatus(x, logoY, logoH)
    local s = UI.s
    local w, h = s(260), s(64)
    local y = UI.sh - h - s(20)
    local health = math.max(0, getElementHealth(localPlayer))
    local armor = getPedArmor(localPlayer)
    dispHealth = lerp(dispHealth, health, 0.15)
    dispArmor = lerp(dispArmor, armor, 0.15)

    UI.rect(x, y, w, h, tocolor(6, 10, 8, 150), s(8))

    -- linha 1: tag + nome ............ $
    local tag = getElementData(localPlayer, "dm:tag")
    local clan = getElementData(localPlayer, "dm:clanTag")
    local tx = x + s(12)
    if type(clan) == "table" and clan.text then tx = tx + UI.tagPill(clan, tx, y + s(9), s(15), 1, 7) + s(5) end
    if type(tag) == "table" then tx = tx + UI.tagPill(tag, tx, y + s(9), s(15), 1, 7) + s(5) end
    local r, g, b = UI.hexToRGB(getElementData(localPlayer, "dm:nameColor"))
    local money = DM.formatMoney(getElementData(localPlayer, "dm:money") or 0)
    local mw = UI.textWidth(money, "bold", 11)
    local name = UI.truncate(DM.stripColors(getPlayerName(localPlayer)), "semibold", 11, w - (tx - x) - mw - s(24))
    UI.text(name, tx, y + s(6), w, s(20), tocolor(r, g, b), "semibold", 11, "left", "center")
    UI.text(money, x + w - mw - s(12), y + s(6), mw, s(20), UI.color("money"), "bold", 11, "left", "center")

    -- linha 2: vida
    local bx, bw = x + s(12), w - s(24)
    local hp = dispHealth / 100
    local hpColor = hp > 0.5 and UI.palette.health or (hp > 0.25 and UI.palette.warn or UI.palette.danger)
    UI.bar(bx, y + s(32), bw - s(34), s(7), hp, UI.rgb(hpColor, 240), tocolor(255, 255, 255, 14), s(3))
    UI.text(("%d"):format(math.ceil(health)), bx + bw - s(30), y + s(26), s(30), s(18), UI.rgb(hpColor), "bold", 10, "right", "center")
    -- linha 3: colete
    UI.bar(bx, y + s(46), bw - s(34), s(4), dispArmor / 100, UI.color("armor", 230), tocolor(255, 255, 255, 10), s(2))
    UI.text(("%d"):format(math.ceil(armor)), bx + bw - s(30), y + s(40), s(30), s(16), UI.color("armor", 220), "semibold", 9, "right", "center")

    -- popups de $
    local now = getTickCount()
    for i = #moneyPops, 1, -1 do if now - moneyPops[i].tick > 2200 then table.remove(moneyPops, i) end end
    for i, p in ipairs(moneyPops) do
        local age = now - p.tick
        local a = age < 150 and age / 150 or (age > 1700 and math.max(0, (2200 - age) / 500) or 1)
        local rise = UI.ease(age / 2200) * s(34)
        local txt = (p.amount > 0 and "+" or "-") .. DM.formatMoney(math.abs(p.amount)) .. (p.reason ~= "" and ("  " .. p.reason) or "")
        UI.textShadow(txt, x, y - s(12) - rise - (i - 1) * s(16), w, s(16), p.amount > 0 and UI.color("money", 255 * a) or UI.color("danger", 255 * a), "bold", 10, "right", "center")
    end
end

-- ---------- Arma (inferior direito) ----------
local function drawWeapon()
    local s = UI.s
    local weapon = getPedWeapon(localPlayer)
    local name = DM.weaponName(weapon):upper()
    local clip = getPedAmmoInClip(localPlayer)
    local total = getPedTotalAmmo(localPlayer)
    local reserve = math.max(0, total - clip)
    local ammoTxt = (weapon > 1 and total > 0) and ("%d / %d"):format(clip, reserve) or ""
    local nw = UI.textWidth(name, "semibold", 11)
    local aw = ammoTxt ~= "" and UI.textWidth(ammoTxt, "bold", 16) or 0
    local w = nw + aw + s(ammoTxt ~= "" and 40 or 24)
    local h = s(40)
    local x, y = UI.sw - w - s(20), UI.sh - h - s(20)
    UI.rect(x, y, w, h, tocolor(6, 10, 8, 150), s(8))
    UI.rect(x, y + s(10), s(3), h - s(20), UI.color("accent"), 1)
    UI.text(name, x + s(12), y, nw, h, UI.color("muted"), "semibold", 11, "left", "center")
    if ammoTxt ~= "" then
        UI.text(ammoTxt, x + s(12) + nw + s(12), y, aw + s(4), h, UI.color("text"), "bold", 16, "left", "center")
    end
    local streak = tonumber(getElementData(localPlayer, "dm:streak")) or 0
    if streak >= 2 then
        local txt = ("x%d"):format(streak)
        local pw = UI.textWidth(txt, "bold", 10) + s(16)
        UI.image("flame.png", x + w - pw - s(22), y - s(24), s(18), s(18))
        UI.pill(txt, x + w - pw, y - s(24), s(18), UI.color("danger", 60), UI.color("danger"), "bold", 10)
    end
end

-- ---------- Topo ----------
local function drawTop()
    local s = UI.s
    local arena = getArenaOf(localPlayer)
    if not arena then return end
    local players = 0
    local dim = getElementDimension(localPlayer)
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:arena") == arena.id and getElementDimension(p) == dim then players = players + 1 end
    end
    -- centro: arena
    local label = ("%s  ·  %d"):format(arena.name:upper(), players)
    local lw = UI.textWidth(label, "semibold", 10) + s(36)
    local x, y, h = (UI.sw - lw) / 2, s(16), s(26)
    UI.rect(x, y, lw, h, tocolor(6, 10, 8, 150), h / 2)
    UI.rect(x + s(12), y + h / 2 - s(4), s(8), s(8), UI.rgb(arena.color), s(4))
    UI.text(label, x + s(26), y, lw - s(30), h, UI.color("text", 235), "semibold", 10, "left", "center")
    -- esquerda: servidor em uma linha
    local ping = getPlayerPing(localPlayer)
    local info = ("%s  ·  %d online  ·  %d fps  ·  %d ms"):format(DM.server.fullName, #getElementsByType("player"), HUD.fps, ping)
    UI.textShadow(info, s(20), s(16), s(600), h, UI.color("muted", 220), "medium", 9, "left", "center")
end

local function drawLobbyHint()
    local arena = getArenaOf(localPlayer)
    if not arena or (arena.type ~= "lobby" and arena.type ~= "duel") then return end
    if UI.getOpenPanel() then return end
    local s = UI.s
    local txt = arena.type == "lobby" and "F2 Arenas   ·   F3 Duelo X1   ·   F4 Loja   ·   F5 Ranqueadas   ·   F6 Clã   ·   TAB Placar"
        or "F3 Desafiar   ·   F2 Arenas   ·   /lobby Voltar"
    UI.textShadow(txt, 0, UI.sh - s(110), UI.sw, s(20), UI.color("text", 200), "medium", 10, "center", "center")
end

addEventHandler("onClientRender", root, function()
    HUD.frames = HUD.frames + 1
    local now = getTickCount()
    if now - HUD.fpsTick >= 1000 then
        HUD.fps = HUD.frames
        HUD.frames = 0
        HUD.fpsTick = now
    end
    if not HUD.visible then return end
    if not getElementData(localPlayer, "dm:ready") then return end
    if not getArenaOf(localPlayer) then return end
    drawTop()
    local nextX, logoY, logoH = drawLogo()
    drawStatus(nextX, logoY, logoH)
    drawWeapon()
    drawLobbyHint()
end)

function setHudVisible(state) HUD.visible = state end
function isHudVisible() return HUD.visible end
