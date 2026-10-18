--[[
    HUD UTG (UI v2). Canto inferior esquerdo, empilhado de baixo para cima:
    logo -> bloco de status (nick + tags, elo, dinheiro animado, vida com rastro, colete).
    Arma/munição no canto inferior direito, arena no topo, info do servidor em uma linha.
]]

local HUD = { visible = true, fps = 0, fpsTick = getTickCount(), frames = 0 }
local moneyPops = {}
local LOGO_W, LOGO_H = 640, 200

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

addEvent("dm:onMoney", true)
addEventHandler("dm:onMoney", root, function(amount, reason, total)
    if amount == 0 then return end
    table.insert(moneyPops, 1, { amount = amount, reason = reason, tick = getTickCount() })
    if #moneyPops > 4 then table.remove(moneyPops) end
    if amount > 0 then playUISound("click", 0.3) end
end)

-- ---------- Logo (base) ----------
local function drawLogo()
    local s = UI.s
    local w = s(236)
    local h = w * LOGO_H / LOGO_W
    local x, y = s(20), UI.sh - h - s(14)
    if not UI.image("logo.png", x, y, w, h) then
        UI.textGlow("UTG", x, y, w, h * 0.6, UI.color("accent"), UI.color("accent", 120), "bold", 32, "left", "center")
        UI.text("MATA-MATA #Return2k26", x, y + h * 0.6, w, h * 0.4, UI.color("text"), "semibold", 10, "left", "center")
    end
    return x, y, w, h
end

-- ---------- Bloco de status (acima da logo) ----------
local function drawStatus(lx, ly, lw)
    local s = UI.s
    local w, h = math.max(lw, s(270)), s(128)
    local x, y = lx, ly - h - s(8)
    local health = math.max(0, getElementHealth(localPlayer))
    local armor = getPedArmor(localPlayer)

    UI.rrect(x, y, w, h, UI.color("card", 200), s(12), {
        border = 1, borderColor = tocolor(255, 255, 255, 22),
        glow = s(14), glowColor = UI.color("accent", 45),
        gradient = UI.color("card2", 200), gradientMode = 3, shine = 0.06,
    })
    UI.accentLine(x + s(12), y, w * 0.5, s(2), UI.palette.accent, 1)

    -- linha 1: tags + nick | elo
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = DM.tierForRP(rp)
    local tag = getElementData(localPlayer, "dm:tag")
    local clan = getElementData(localPlayer, "dm:clanTag")
    local tx = x + s(14)
    if type(clan) == "table" and clan.text then tx = tx + UI.tagPill(clan, tx, y + s(12), s(16), 1, 7) + s(5) end
    if type(tag) == "table" then tx = tx + UI.tagPill(tag, tx, y + s(12), s(16), 1, 7) + s(5) end
    local eloW = UI.textWidth(tier.short, "bold", 9) + s(18)
    local r, g, b = UI.hexToRGB(getElementData(localPlayer, "dm:nameColor"))
    local name = UI.truncate(DM.stripColors(getPlayerName(localPlayer)), "semibold", 12, w - (tx - x) - eloW - s(26))
    UI.text(name, tx, y + s(8), w, s(24), tocolor(r, g, b), "semibold", 12, "left", "center")
    UI.rrect(x + w - eloW - s(12), y + s(11), eloW, s(18), UI.rgb(tier.color, 40), s(9), { border = 1, borderColor = UI.rgb(tier.color, 170), glow = s(6), glowColor = UI.rgb(tier.color, 70) })
    UI.text(tier.short, x + w - eloW - s(12), y + s(11), eloW, s(18), UI.rgb(tier.color), "bold", 9, "center", "center")

    -- linha 2: dinheiro animado + RP
    local money = UI.counter("hud:money", tonumber(getElementData(localPlayer, "dm:money")) or 0, 900)
    UI.image("coin.png", x + s(14), y + s(40), s(16), s(16))
    UI.text(DM.formatMoney(money), x + s(34), y + s(36), w, s(24), UI.color("money"), "bold", 13, "left", "center")
    UI.text(("%d RP  ·  %s"):format(math.floor(UI.counter("hud:rp", rp, 900) + 0.5), tier.name:upper()), x, y + s(36), w - s(12), s(24), UI.color("muted"), "semibold", 8, "right", "center")

    -- linha 3: vida
    local bx, bw = x + s(14), w - s(28)
    local hp = health / 100
    local hpColor = hp > 0.5 and UI.palette.health or (hp > 0.25 and UI.palette.warn or UI.palette.danger)
    UI.text("VIDA", bx, y + s(62), bw, s(12), UI.color("muted", 200), "semibold", 7, "left", "center")
    UI.text(("%d"):format(math.ceil(health)), bx, y + s(60), bw, s(16), UI.rgb(hpColor), "bold", 10, "right", "center")
    UI.bar(bx, y + s(76), bw, s(9), hp, UI.rgb(hpColor, 240), tocolor(255, 255, 255, 14), s(4), { id = "hud:hp", ghost = true, glow = true })
    -- linha 4: colete
    UI.text("COLETE", bx, y + s(92), bw, s(12), UI.color("muted", 200), "semibold", 7, "left", "center")
    UI.text(("%d"):format(math.ceil(armor)), bx, y + s(90), bw, s(16), UI.color("armor", 220), "bold", 9, "right", "center")
    UI.bar(bx, y + s(106), bw, s(5), armor / 100, UI.color("armor", 230), tocolor(255, 255, 255, 10), s(2), { id = "hud:armor", glow = true })

    -- vida baixa: vinheta pulsante
    if hp > 0 and hp < 0.3 and not isPedDead(localPlayer) then
        UI.vignette(UI.color("danger", 200), UI.pulse(900, 0.2, 0.5) * (1 - hp / 0.3 + 0.3))
    end

    -- popups de $
    local now = getTickCount()
    for i = #moneyPops, 1, -1 do if now - moneyPops[i].tick > 2200 then table.remove(moneyPops, i) end end
    for i, p in ipairs(moneyPops) do
        local age = now - p.tick
        local a = age < 150 and age / 150 or (age > 1700 and math.max(0, (2200 - age) / 500) or 1)
        local rise = UI.ease(age / 2200, "outCubic") * s(36)
        local txt = (p.amount > 0 and "+" or "-") .. DM.formatMoney(math.abs(p.amount)) .. (p.reason ~= "" and ("  " .. p.reason) or "")
        UI.textShadow(txt, x, y - s(14) - rise - (i - 1) * s(16), w, s(16), p.amount > 0 and UI.color("money", 255 * a) or UI.color("danger", 255 * a), "bold", 10, "left", "center")
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
    local hasAmmo = weapon > 1 and total > 0
    local w, h = s(230), s(62)
    local x, y = UI.sw - w - s(20), UI.sh - h - s(20)
    UI.rrect(x, y, w, h, UI.color("card", 200), s(12), { border = 1, borderColor = tocolor(255, 255, 255, 22), glow = s(12), glowColor = UI.color("accent2", 40), gradient = UI.color("card2", 200), gradientMode = 3 })
    UI.rrect(x + s(12), y + s(14), s(3), h - s(28), UI.color("accent"), s(2), { glow = s(5), glowColor = UI.color("accent", 120) })
    UI.text(name, x + s(24), y + s(8), w - s(36), s(16), UI.color("muted"), "semibold", 9, "left", "center")
    if hasAmmo then
        local shownClip = math.floor(UI.counter("hud:clip", clip, 160) + 0.5)
        UI.textGlow(tostring(shownClip), x + s(24), y + s(22), s(80), s(30), UI.color("text"), UI.color("accent", 70), "bold", 22, "left", "center")
        local cw = UI.textWidth(tostring(shownClip), "bold", 22)
        UI.text("/ " .. reserve, x + s(24) + cw + s(8), y + s(28), s(100), s(22), UI.color("muted"), "medium", 11, "left", "center")
        local clipSize = tonumber(getWeaponProperty(weapon, "pro", "maximum_clip_ammo")) or math.max(clip, 1)
        UI.bar(x + s(24), y + h - s(10), w - s(40), s(3), clip / math.max(1, clipSize), UI.color("accent", 220), tocolor(255, 255, 255, 12), 1, { id = "hud:clipbar" })
    else
        local arena = getArenaOf(localPlayer)
        UI.text(arena and arena.safe and "Zona segura" or "Corpo a corpo", x + s(24), y + s(26), w - s(36), s(24), UI.color("text", 200), "medium", 11, "left", "center")
    end
    -- sequência
    local streak = tonumber(getElementData(localPlayer, "dm:streak")) or 0
    if streak >= 2 then
        local pulse = UI.pulse(700, 0.85, 1)
        local txt = ("SEQUÊNCIA x%d"):format(streak)
        local pw = UI.textWidth(txt, "bold", 9) + s(20)
        local px, py = x + w - pw, y - s(26)
        UI.rrect(px, py, pw, s(20), UI.color("danger", 55), s(10), { glow = s(8) * pulse, glowColor = UI.color("danger", 120) })
        UI.text(txt, px, py, pw, s(20), UI.color("danger"), "bold", 9, "center", "center")
        UI.image("flame.png", px - s(22), py - s(2), s(22) * pulse, s(22) * pulse)
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
    local label = ("%s   ·   %d %s"):format(arena.name:upper(), players, players == 1 and "jogador" or "jogadores")
    local lw = UI.textWidth(label, "semibold", 10) + s(44)
    local x, y, h = (UI.sw - lw) / 2, s(16), s(28)
    local c = arena.color
    UI.rrect(x, y, lw, h, UI.color("card", 190), h / 2, { border = 1, borderColor = tocolor(255, 255, 255, 20), glow = s(10), glowColor = tocolor(c[1], c[2], c[3], 50) })
    local pulse = UI.pulse(1400, 0.5, 1)
    UI.rrect(x + s(14), y + h / 2 - s(4), s(8), s(8), tocolor(c[1], c[2], c[3], 255 * pulse), s(4), { glow = s(6) * pulse, glowColor = tocolor(c[1], c[2], c[3], 180) })
    UI.text(label, x + s(28), y, lw - s(34), h, UI.color("text", 235), "semibold", 10, "left", "center")
    local ping = getPlayerPing(localPlayer)
    local info = ("%s   ·   %d online   ·   %d fps   ·   %d ms"):format(DM.server.fullName, #getElementsByType("player"), HUD.fps, ping)
    UI.textShadow(info, s(20), s(16), s(700), h, UI.color("muted", 210), "medium", 9, "left", "center")
end

local function drawLobbyHint()
    local arena = getArenaOf(localPlayer)
    if not arena or (arena.type ~= "lobby" and arena.type ~= "duel") then return end
    if UI.getOpenPanel() then return end
    local s = UI.s
    local items = arena.type == "lobby"
        and { { "F2", "Jogar" }, { "F3", "Duelo" }, { "F4", "Loja" }, { "F6", "Clã" }, { "F7", "Caixas" }, { "TAB", "Placar" } }
        or { { "F3", "Desafiar" }, { "F2", "Arenas" }, { "/lobby", "Voltar" } }
    local total = 0
    local widths = {}
    for i, it in ipairs(items) do
        widths[i] = UI.textWidth(it[1], "bold", 9) + s(14)
        total = total + widths[i] + s(6) + UI.textWidth(it[2], "medium", 10) + s(20)
    end
    local x, y = (UI.sw - total) / 2, UI.sh - s(96)
    local a = UI.pulse(3000, 0.75, 1)
    for i, it in ipairs(items) do
        UI.rrect(x, y, widths[i], s(20), UI.color("accent", 50 * a), s(5), { border = 1, borderColor = UI.color("accent", 110 * a) })
        UI.text(it[1], x, y, widths[i], s(20), UI.color("accent2", 255 * a), "bold", 9, "center", "center")
        local tw = UI.textWidth(it[2], "medium", 10)
        UI.textShadow(it[2], x + widths[i] + s(6), y, tw, s(20), UI.color("text", 210 * a), "medium", 10, "left", "center")
        x = x + widths[i] + s(6) + tw + s(20)
    end
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
    local lx, ly, lw = drawLogo()
    drawStatus(lx, ly, lw)
    drawWeapon()
    drawLobbyHint()
end)

function setHudVisible(state) HUD.visible = state end
function isHudVisible() return HUD.visible end
