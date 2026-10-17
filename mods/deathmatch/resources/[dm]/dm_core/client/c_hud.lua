--[[
    HUD moderno: vida/colete, arma/munição, arena, stats, FPS/ping.
]]

local HUD = { visible = true, fps = 0, fpsTick = getTickCount(), frames = 0 }
local lastHealth, dispHealth, dispArmor = 100, 100, 0

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

local function drawPlayerCard()
    local s = UI.s
    local w, h = s(380), s(104)
    local x, y = s(24), UI.sh - h - s(24)

    local health = math.max(0, getElementHealth(localPlayer))
    local armor = getPedArmor(localPlayer)
    dispHealth = lerp(dispHealth, health, 0.15)
    dispArmor = lerp(dispArmor, armor, 0.15)

    UI.card(x, y, w, h, s(16))

    -- Avatar / nível
    local level = tonumber(getElementData(localPlayer, "dm:level")) or 1
    local rank = DM.rankForLevel(level)
    local av = s(64)
    local ax, ay = x + s(20), y + (h - av) / 2
    UI.rect(ax, ay, av, av, UI.rgb(rank.color, 40), s(14))
    UI.border(ax, ay, av, av, UI.rgb(rank.color, 160), s(14))
    UI.text("NÍVEL", ax, ay + s(8), av, s(12), UI.rgb(rank.color, 220), "semibold", 8, "center", "top")
    UI.text(tostring(level), ax, ay + s(16), av, av - s(20), UI.color("text"), "bold", 22, "center", "center")

    -- Nome + rank
    local nx = ax + av + s(16)
    local nw = w - (nx - x) - s(20)
    local name = DM.stripColors(getPlayerName(localPlayer))
    UI.text(UI.truncate(name, "semibold", 14, nw - s(70)), nx, y + s(14), nw, s(20), UI.color("text"), "semibold", 14, "left", "center")
    UI.pill(rank.name:upper(), nx + nw - UI.textWidth(rank.name:upper(), "semibold", 8) - s(20), y + s(16), s(16), UI.rgb(rank.color, 40), UI.rgb(rank.color), "semibold", 8)

    -- Barra de vida
    local by = y + s(44)
    local bw = nw
    local hp = dispHealth / 100
    local hpColor = hp > 0.5 and UI.palette.health or (hp > 0.25 and UI.palette.warn or UI.palette.danger)
    UI.bar(nx, by, bw, s(10), hp, UI.rgb(hpColor, 240), tocolor(255, 255, 255, 16))
    UI.text(("%d"):format(math.ceil(health)), nx, by + s(12), bw, s(14), UI.color("muted"), "medium", 9, "left", "center")
    UI.text("VIDA", nx, by + s(12), bw, s(14), UI.color("muted", 150), "semibold", 8, "right", "center")

    -- Barra de colete
    local ay2 = by + s(30)
    UI.bar(nx, ay2, bw, s(6), dispArmor / 100, UI.color("armor", 240), tocolor(255, 255, 255, 14))
    UI.text(("COLETE %d"):format(math.ceil(armor)), nx, ay2 + s(7), bw, s(12), UI.color("muted", 150), "semibold", 8, "right", "center")
end

local function drawWeaponCard()
    local s = UI.s
    local weapon = getPedWeapon(localPlayer)
    local w, h = s(250), s(104)
    local x, y = UI.sw - w - s(24), UI.sh - h - s(24)
    UI.card(x, y, w, h, s(16))

    local arena = getArenaOf(localPlayer)
    local name = DM.weaponName(weapon)
    local clip = getPedAmmoInClip(localPlayer)
    local total = getPedTotalAmmo(localPlayer)
    local reserve = math.max(0, total - clip)

    UI.text("ARMA", x + s(20), y + s(14), w - s(40), s(12), UI.color("muted", 160), "semibold", 8, "left", "top")
    UI.text(name:upper(), x + s(20), y + s(26), w - s(40), s(24), UI.color("text"), "bold", 16, "left", "center")

    if weapon > 1 and total > 0 then
        UI.text(tostring(clip), x + s(20), y + s(52), s(80), s(40), UI.color("accent"), "bold", 28, "left", "center")
        local cw = UI.textWidth(tostring(clip), "bold", 28)
        UI.text("/ " .. tostring(reserve), x + s(20) + cw + s(8), y + s(60), s(120), s(26), UI.color("muted"), "medium", 13, "left", "center")
    else
        UI.text(arena and arena.safe and "Zona segura" or "Corpo a corpo", x + s(20), y + s(58), w - s(40), s(30), UI.color("muted"), "medium", 11, "left", "center")
    end

    -- Streak atual
    local streak = tonumber(getElementData(localPlayer, "dm:streak")) or 0
    if streak >= 2 then
        local txt = ("SEQUÊNCIA %d"):format(streak)
        local pw = UI.textWidth(txt, "semibold", 9) + s(20)
        UI.pill(txt, x + w - pw - s(16), y + s(16), s(18), UI.color("danger", 50), UI.color("danger"), "semibold", 9)
    end
end

local function drawTopBar()
    local s = UI.s
    local arena = getArenaOf(localPlayer)
    if not arena then return end
    local players = 0
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:arena") == arena.id then players = players + 1 end
    end
    local label = arena.name:upper()
    local sub = ("%d %s"):format(players, players == 1 and "jogador" or "jogadores")
    local lw = UI.textWidth(label, "bold", 13)
    local sw_ = UI.textWidth(sub, "medium", 10)
    local w = math.max(lw, sw_) + s(60)
    local h = s(52)
    local x, y = (UI.sw - w) / 2, s(20)
    UI.card(x, y, w, h, s(14))
    UI.rect(x + s(14), y + s(14), s(6), h - s(28), UI.rgb(arena.color), s(3))
    UI.text(label, x + s(30), y + s(8), w - s(40), s(20), UI.color("text"), "bold", 13, "left", "center")
    UI.text(sub, x + s(30), y + s(27), w - s(40), s(16), UI.color("muted"), "medium", 10, "left", "center")
end

local function drawBrand()
    local s = UI.s
    local x, y = s(24), s(20)
    local name = DM.server.name
    local nw = UI.textWidth(name, "bold", 14)
    UI.card(x, y, nw + s(36), s(52), s(14))
    UI.rect(x + s(14), y + s(16), s(8), s(20), UI.color("accent"), s(2))
    UI.text(name, x + s(30), y + s(8), nw, s(20), UI.color("text"), "bold", 14, "left", "center")
    UI.text(DM.server.tagline, x + s(30), y + s(27), nw + s(40), s(16), UI.color("muted"), "medium", 9, "left", "center")

    -- FPS / ping
    local px = x + nw + s(36) + s(10)
    local ping = getPlayerPing(localPlayer)
    local pingColor = ping < 80 and "accent" or (ping < 150 and "warn" or "danger")
    local txt = ("%d FPS"):format(HUD.fps)
    local txt2 = ("%d ms"):format(ping)
    local pw = UI.textWidth(txt, "semibold", 10) + UI.textWidth(txt2, "semibold", 10) + s(44)
    UI.card(px, y, pw, s(52), s(14))
    UI.text(txt, px + s(14), y, pw, s(52), UI.color("muted"), "semibold", 10, "left", "center")
    UI.text(txt2, px, y, pw - s(14), s(52), UI.color(pingColor), "semibold", 10, "right", "center")
end

local function drawLobbyHint()
    local arena = getArenaOf(localPlayer)
    if not arena or (arena.type ~= "lobby" and arena.type ~= "duel") then return end
    if UI.getOpenPanel() then return end
    local s = UI.s
    local items = arena.type == "lobby"
        and { { "F2", "Arenas" }, { "F3", "Duelo X1" }, { "F1", "Ajuda" }, { "TAB", "Placar" } }
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
    local y = UI.sh - s(150)
    for _, p in ipairs(parts) do
        UI.rect(x, y, p[3], s(24), tocolor(255, 255, 255, 20), s(6))
        UI.text(p[1], x, y, p[3], s(24), UI.color("accent"), "bold", 10, "center", "center")
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
    drawPlayerCard()
    drawWeaponCard()
    drawLobbyHint()
end)

function setHudVisible(state) HUD.visible = state end
function isHudVisible() return HUD.visible end
