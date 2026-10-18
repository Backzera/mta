--[[
    Painel de arenas (F2) — UI v2: moldura com fundo desfocado, cards em cascata com hover
    que levanta o card, ponto pulsante de jogadores, card dourado "Ranqueadas" (abre o F5).
]]

local PANEL = "arenas"
local panel = { open = false, tick = 0, rendering = false }
local CARDS

local function cards()
    if CARDS then return CARDS end
    CARDS = {}
    for _, a in ipairs(DM.arenas) do CARDS[#CARDS + 1] = a end
    CARDS[#CARDS + 1] = { id = "__ranked", name = "Partidas Ranqueadas", type = "ranked", color = { 245, 196, 81 },
        desc = "5x5 e 10x10 com aquecimento. Ganhe RP e suba de elo.", weapons = {} }
    return CARDS
end

local function countPlayers()
    local counts = {}
    for _, p in ipairs(getElementsByType("player")) do
        local id = getElementData(p, "dm:arena")
        if id then counts[id] = (counts[id] or 0) + 1 end
    end
    return counts
end

local function enterArena(id)
    closeArenaPanel()
    if id == "__ranked" then
        setTimer(function() triggerEvent("ranked:openPanel", localPlayer) end, 60, 1)
    else
        triggerServerEvent("dm:requestArena", localPlayer, id)
    end
end

local function render()
    local s = UI.s
    local list = cards()
    local cols = 3
    local cardW, cardH, gap = s(292), s(154), s(14)
    local rows = math.ceil(#list / cols)
    local pad = s(28)
    local w = pad * 2 + cols * cardW + (cols - 1) * gap
    local h = s(86) + s(18) + rows * cardH + (rows - 1) * gap + s(74)

    local f = UI.panelFrame(panel, {
        w = w, h = h, title = "ARENAS", subtitle = "Escolha onde lutar. Cada arena tem suas próprias armas e regras.",
        icon = "target.png", accent = "accent", onClose = closeArenaPanel,
        badge = ("%d ONLINE"):format(#getElementsByType("player")),
    })
    if not f then
        if not panel.open then
            removeEventHandler("onClientRender", root, render)
            panel.rendering = false
        end
        return
    end
    local a = f.a
    local counts = countPlayers()
    local current = getElementData(localPlayer, "dm:arena")
    local n = #list
    for i, arena in ipairs(list) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local p = UI.stagger(a, i, n, 0.55)
        local cx = f.cx + col * (cardW + gap)
        local cy = f.cy + row * (cardH + gap) + (1 - p) * s(22)
        local ca = a * p
        local hovering = UI.isMouseIn(cx, cy, cardW, cardH)
        local t = UI.hover("arena:" .. arena.id, hovering)
        local lift = s(4) * t
        local x, y = cx - lift / 2, cy - lift
        local cw, ch = cardW + lift, cardH + lift
        local isCurrent = current == arena.id
        local ranked = arena.type == "ranked"
        local c = arena.color
        UI.rrect(x, y, cw, ch, UI.color("card2", (215 + 30 * t) * ca), s(12), {
            border = 1, borderColor = isCurrent and tocolor(c[1], c[2], c[3], 200 * ca) or tocolor(255, 255, 255, (22 + 60 * t) * ca),
            glow = s(6) + s(16) * t + (isCurrent and s(8) or 0), glowColor = tocolor(c[1], c[2], c[3], (40 + 90 * t + (isCurrent and 40 or 0)) * ca),
            gradient = tocolor(c[1], c[2], c[3], (12 + 16 * t) * ca), gradientMode = 3, shine = 0.1 + 0.15 * t,
        })
        UI.rrect(x, y + s(16), s(4), ch - s(32), tocolor(c[1], c[2], c[3], 255 * ca), s(2), { glow = s(6), glowColor = tocolor(c[1], c[2], c[3], 120 * ca) })
        UI.text(arena.name, x + s(20), y + s(14), cw - s(40), s(24), UI.color("text", 255 * ca), "bold", 14, "left", "center")
        local typeLabel = arena.type == "lobby" and "ZONA SEGURA" or (arena.type == "duel" and "DUELOS 1v1" or (ranked and "RANQUEADO · F5" or "TODOS CONTRA TODOS"))
        if arena.cbug then typeLabel = typeLabel .. "  ·  C-BUG" end
        UI.text(typeLabel, x + s(20), y + s(38), cw - s(40), s(14), tocolor(c[1], c[2], c[3], 230 * ca), "semibold", 8, "left", "center")
        UI.text(ranked and arena.desc or DM.arenaWeaponList(arena), x + s(20), y + s(58), cw - s(40), s(36), UI.color("muted", 255 * ca), "regular", 10, "left", "top", false, true)
        -- jogadores
        local count = counts[arena.id] or 0
        if ranked then
            count = 0
            for _, m in ipairs(DM.rankedModes) do count = count + (counts[m.id] or 0) end
        end
        local dotA = count > 0 and UI.pulse(1200, 0.55, 1) or 0.35
        UI.rrect(x + s(20), y + ch - s(36), s(8), s(8), count > 0 and tocolor(c[1], c[2], c[3], 255 * ca * dotA) or UI.color("muted", 120 * ca), s(4), count > 0 and { glow = s(5), glowColor = tocolor(c[1], c[2], c[3], 160 * ca * dotA) } or nil)
        UI.text(("%d %s"):format(count, count == 1 and "jogador" or "jogadores"), x + s(34), y + ch - s(42), cw, s(20), UI.color("muted", 255 * ca), "medium", 10, "left", "center")
        -- botão
        local bw, bh = s(92), s(30)
        local bx, by = x + cw - bw - s(16), y + ch - bh - s(14)
        if isCurrent then
            UI.rrect(bx, by, bw, bh, tocolor(c[1], c[2], c[3], 36 * ca), s(8), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 120 * ca) })
            UI.text("VOCÊ ESTÁ AQUI", bx, by, bw, bh, tocolor(c[1], c[2], c[3], 255 * ca), "semibold", 8, "center", "center")
        else
            UI.button("arena_btn_" .. arena.id, ranked and "ABRIR" or "ENTRAR", bx, by, bw, bh,
                { kind = t > 0.5 and "primary" or "outline", color = ranked and "gold" or "accent", size = 10, alpha = ca })
        end
        local id = arena.id
        if not isCurrent then UI.addClick(x, y, cw, ch, function() enterArena(id) end, "arena_card_" .. id) end
    end
    UI.panelFooter(f, "F2 ou ESC fecha  ·  clique no card para entrar  ·  /arena <nome>  ·  /lobby")
    UI.endFrame()
end

local function onClick(button, state)
    if panel.open then UI.processClick(button, state) end
end

function openArenaPanel()
    if panel.open then return end
    if not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    if not panel.rendering then
        panel.rendering = true
        addEventHandler("onClientRender", root, render)
    end
    addEventHandler("onClientClick", root, onClick)
    UI.sound("click", 0.4)
end

function closeArenaPanel()
    if not panel.open then return end
    panel.open = false
    panel.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
end

function toggleArenaPanel()
    if panel.open then closeArenaPanel() else openArenaPanel() end
end

addEvent("ranked:openPanel")
bindKey("F2", "down", toggleArenaPanel)
UI.registerEscape(PANEL, closeArenaPanel)

function isPanelOpen() return UI.getOpenPanel() ~= nil end
