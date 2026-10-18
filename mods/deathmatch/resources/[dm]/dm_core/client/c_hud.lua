--[[
    HUD UTG: logo (inferior esquerdo), card do jogador (tag, elo, $, vida, colete),
    arma/munição, barra da arena, marca + FPS/ping, dicas do lobby, popups de $.
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

-- ---------- Logo ----------
local LOGO_W, LOGO_H = 640, 200
local function drawLogo()
    local s = UI.s
    local w = s(290)
    local h = w * LOGO_H / LOGO_W
    local x, y = s(24), UI.sh - h - s(20)
    if not UI.image("logo.png", x, y, w, h) then
        UI.text("UTG", x, y, w, h * 0.6, UI.color("accent"), "bold", 40, "left", "center")
        UI.text("MATA-MATA  #Return2k26", x, y + h * 0.6, w, h * 0.4, UI.color("text"), "semibold", 12, "left", "center")
    end
    return x + w + s(16)
end

-- ---------- Card do jogador ----------
local function drawPlayerCard(x)
    local s = UI.s
    local w, h = s(400), s(110)
    local y = UI.sh - h - s(24)

    local health = math.max(0, getElementHealth(localPlayer))
    local armor = getPedArmor(localPlayer)
    dispHealth = lerp(dispHealth, health, 0.15)
    dispArmor = lerp(dispArmor, armor, 0.15)

    UI.card(x, y, w, h, s(12))

    -- Elo
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = DM.tierForRP(rp)
    local av = s(70)
    local ax, ay = x + s(18), y + (h - av) / 2
    UI.rect(ax, ay, av, av, UI.rgb(tier.color, 36), s(10))
    UI.border(ax, ay, av, av, UI.rgb(tier.color, 170), s(10))
    UI.text(tier.short, ax, ay + s(8), av, s(22), UI.rgb(tier.color), "bold", 15, "center", "center")
    UI.text(("%d RP"):format(rp), ax, ay + s(32), av, s(14), UI.color("muted"), "semibold", 8, "center", "center")
    UI.text(tier.name:upper(), ax, ay + s(48), av, s(14), UI.rgb(tier.color, 220), "semibold", 7, "center", "center")

    -- Tag + nome
    local nx = ax + av + s(14)
    local nw = w - (nx - x) - s(18)
    local tag = getElementData(localPlayer, "dm:tag")
    local clan = getElementData(localPlayer, "dm:clanTag")
    local tx = nx
    if type(clan) == "table" and clan.text then
        tx = tx + UI.tagPill(clan, tx, y + s(12), s(16), 1, 8) + s(6)
    end
    if type(tag) == "table" then
        tx = tx + UI.tagPill(tag, tx, y + s(12), s(16), 1, 8) + s(6)
    end
    local nameColor = getElementData(localPlayer, "dm:nameColor")
    local r, g, b = UI.hexToRGB(nameColor)
    local name = DM.stripColors(getPlayerName(localPlayer))
    UI.text(UI.truncate(name, "semibold", 13, nw - (tx - nx) - s(90)), tx, y + s(10), nw, s(20), tocolor(r, g, b), "semibold", 13, "left", "center")

    -- Dinheiro
    local money = DM.formatMoney(getElementData(localPlayer, "dm:money") or 0)
    local mw = UI.textWidth(money, "bold", 12)
    UI.image("coin.png", nx + nw - mw - s(22), y + s(11), s(18), s(18))
    UI.text(money, nx + nw - mw, y + s(10), mw, s(20), UI.color("money"), "bold", 12, "left", "center")

    -- Vida
    local by = y + s(44)
    local hp = dispHealth / 100
    local hpColor = hp > 0.5 and UI.palette.health or (hp > 0.25 and UI.palette.warn or UI.palette.danger)
    UI.bar(nx, by, nw, s(10), hp, UI.rgb(hpColor, 240), tocolor(255, 255, 255, 14), s(3))
    UI.text(("%d"):format(math.ceil(health)), nx, by + s(12), nw, s(14), UI.color("text", 220), "semibold", 9, "left", "center")
    UI.text("VIDA", nx, by + s(12), nw, s(14), UI.color("muted", 160), "semibold", 8, "right", "center")

    -- Colete
    local ay2 = by + s(32)
    UI.bar(nx, ay2, nw, s(6), dispArmor / 100, UI.color("armor", 240), tocolor(255, 255, 255, 12), s(2))
    UI.text(("COLETE %d"):format(math.ceil(armor)), nx, ay2 + s(7), nw, s(12), UI.color("muted", 160), "semibold", 8, "right", "center")

    -- popups de dinheiro
    local now = getTickCount()
    for i = #moneyPops, 1, -1 do if now - moneyPops[i].tick > 2200 then table.remove(moneyPops, i) end end
    for i, p in ipairs(moneyPops) do
        local age = now - p.tick
        local a = age < 150 and age / 150 or (age > 1700 and math.max(0, (2200 - age) / 500) or 1)
        local rise = UI.ease(age / 2200) * s(40)
        local txt = (p.amount > 0 and "+" or "-") .. DM.formatMoney(math.abs(p.amount)) .. (p.reason ~= "" and ("  " .. p.reason) or "")
        UI.textShadow(txt, x + w - s(200), y - s(14) - rise - (i - 1) * s(18), s(190), s(18), p.amount > 0 and UI.color("money", 255 * a) or UI.color("danger", 255 * a), "bold", 11, "right", "center")
    end
end

-- ---------- Arma ----------
local function drawWeaponCard()
    local s = UI.s
    local weapon = getPedWeapon(localPlayer)
    local w, h = s(250), s(110)
    local x, y = UI.sw - w - s(24), UI.sh - h - s(24)
    UI.card(x, y, w, h, s(12), 1, "accent2")

    local arena = getArenaOf(localPlayer)
    local name = DM.weaponName(weapon)
    local clip = getPedAmmoInClip(localPlayer)
    local total = getPedTotalAmmo(localPlayer)
    local reserve = math.max(0, total - clip)

    UI.text("ARMA", x + s(20), y + s(14), w - s(40), s(12), UI.color("muted", 160), "semibold", 8, "left", "top")
    UI.text(name:upper(), x + s(20), y + s(26), w - s(40), s(24), UI.color("text"), "bold", 16, "left", "center")

    if weapon > 1 and total > 0 then
        UI.text(tostring(clip), x + s(20), y + s(54), s(80), s(40), UI.color("accent2"), "bold", 28, "left", "center")
        local cw = UI.textWidth(tostring(clip), "bold", 28)
        UI.text("/ " .. tostring(reserve), x + s(20) + cw + s(8), y + s(62), s(120), s(26), UI.color("muted"), "medium", 13, "left", "center")
    else
        UI.text(arena and arena.safe and "Zona segura" or "Corpo a corpo", x + s(20), y + s(60), w - s(40), s(30), UI.color("muted"), "medium", 11, "left", "center")
    end

    local streak = tonumber(getElementData(localPlayer, "dm:streak")) or 0
    if streak >= 2 then
        local txt = ("SEQUÊNCIA %d"):format(streak)
        local pw = UI.textWidth(txt, "semibold", 9) + s(20)
        UI.image("flame.png", x + w - pw - s(36), y + s(14), s(18), s(18))
        UI.pill(txt, x + w - pw - s(16), y + s(14), s(18), UI.color("danger", 50), UI.color("danger"), "semibold", 9)
    end
end

-- ---------- Topo ----------
local function drawTopBar()
    local s = UI.s
    local arena = getArenaOf(localPlayer)
    if not arena then return end
    local players = 0
    local dim = getElementDimension(localPlayer)
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:arena") == arena.id and getElementDimension(p) == dim then players = players + 1 end
    end
    local label = arena.name:upper()
    local sub = ("%d %s"):format(players, players == 1 and "jogador" or "jogadores")
    if arena.cbug then sub = sub .. "  ·  C-BUG LIBERADO" end
    local lw = UI.textWidth(label, "bold", 13)
    local sw_ = UI.textWidth(sub, "medium", 10)
    local w = math.max(lw, sw_) + s(60)
    local h = s(52)
    local x, y = (UI.sw - w) / 2, s(20)
    UI.card(x, y, w, h, s(12), 1, false)
    UI.rect(x + s(14), y + s(14), s(5), h - s(28), UI.rgb(arena.color), s(2))
    UI.text(label, x + s(30), y + s(8), w - s(40), s(20), UI.color("text"), "bold", 13, "left", "center")
    UI.text(sub, x + s(30), y + s(27), w - s(40), s(16), UI.color("muted"), "medium", 10, "left", "center")
end

local function drawBrand()
    local s = UI.s
    local x, y = s(24), s(20)
    local name = DM.server.name
    local nw = UI.textWidth(name, "bold", 13)
    local online = #getElementsByType("player")
    local sub = ("%s  ·  %d online"):format(DM.server.tagline, online)
    local w = math.max(nw, UI.textWidth(sub, "medium", 9)) + s(36)
    UI.card(x, y, w, s(52), s(12))
    UI.rect(x + s(14), y + s(16), s(5), s(20), UI.color("accent"), s(2))
    UI.text(name, x + s(28), y + s(8), w, s(20), UI.color("text"), "bold", 13, "left", "center")
    UI.text(sub, x + s(28), y + s(27), w, s(16), UI.color("muted"), "medium", 9, "left", "center")

    local px = x + w + s(10)
    local ping = getPlayerPing(localPlayer)
    local pingColor = ping < 80 and "success" or (ping < 150 and "warn" or "danger")
    local txt = ("%d FPS"):format(HUD.fps)
    local txt2 = ("%d ms"):format(ping)
    local pw = UI.textWidth(txt, "semibold", 10) + UI.textWidth(txt2, "semibold", 10) + s(44)
    UI.card(px, y, pw, s(52), s(12), 1, false)
    UI.text(txt, px + s(14), y, pw, s(52), UI.color("muted"), "semibold", 10, "left", "center")
    UI.text(txt2, px, y, pw - s(14), s(52), UI.color(pingColor), "semibold", 10, "right", "center")
end

local function drawLobbyHint()
    local arena = getArenaOf(localPlayer)
    if not arena or (arena.type ~= "lobby" and arena.type ~= "duel") then return end
    if UI.getOpenPanel() then return end
    local s = UI.s
    local items = arena.type == "lobby"
        and { { "F2", "Arenas" }, { "F3", "Duelo X1" }, { "F4", "Loja" }, { "F5", "Ranqueadas" }, { "F6", "Clã" }, { "TAB", "Placar" } }
        or  { { "F3", "Desafiar" }, { "F2", "Arenas" }, { "/lobby", "Voltar" } }
    local totalW = 0
    local parts = {}
    for _, it in ipairs(items) do
        local kw = UI.textWidth(it[1], "bold", 10) + s(16)
        local tw = UI.textWidth(it[2], "medium", 11)
        parts[#parts + 1] = { it[1], it[2], kw, tw }
        totalW = totalW + kw + s(8) + tw + s(24)
    end
    local x = (UI.sw - totalW) / 2
    local y = UI.sh - s(160)
    for _, p in ipairs(parts) do
        UI.rect(x, y, p[3], s(24), UI.color("accent", 60), s(6))
        UI.text(p[1], x, y, p[3], s(24), UI.color("text"), "bold", 10, "center", "center")
        UI.textShadow(p[2], x + p[3] + s(8), y, p[4], s(24), UI.color("text", 230), "medium", 11, "left", "center")
        x = x + p[3] + s(8) + p[4] + s(24)
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
    drawBrand()
    drawTopBar()
    local nextX = drawLogo()
    drawPlayerCard(nextX)
    drawWeaponCard()
    drawLobbyHint()
end)

function setHudVisible(state) HUD.visible = state end
function isHudVisible() return HUD.visible end
