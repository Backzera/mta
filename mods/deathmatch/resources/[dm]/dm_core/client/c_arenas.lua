--[[
    Painel de arenas (F2): cards com nome, armas, jogadores online e botão de entrar.
]]

local panel = { open = false, tick = 0, hoverCard = nil }
local PANEL = "arenas"

local function countPlayers()
    local counts = {}
    for _, p in ipairs(getElementsByType("player")) do
        local id = getElementData(p, "dm:arena")
        if id then counts[id] = (counts[id] or 0) + 1 end
    end
    return counts
end

local function layout()
    local s = UI.s
    local cols = 3
    local cardW, cardH, gap = s(300), s(150), s(16)
    local pad = s(28)
    local rows = math.ceil(#DM.arenas / cols)
    local w = pad * 2 + cols * cardW + (cols - 1) * gap
    local h = pad + s(80) + rows * cardH + (rows - 1) * gap + s(70)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2
    return x, y, w, h, cols, cardW, cardH, gap, pad
end

local function render()
    local progress = UI.openProgress(panel)
    if progress <= 0 then
        if not panel.open then removeEventHandler("onClientRender", root, render) end
        return
    end
    local s = UI.s
    local a = progress
    local x, y, w, h, cols, cardW, cardH, gap, pad = layout()
    y = y + (1 - a) * s(20)

    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 7, 12, 160 * a))
    UI.card(x, y, w, h, s(20), a)

    -- Cabeçalho
    UI.text("ARENAS", x + pad, y + pad - s(4), w, s(30), UI.color("text", 255 * a), "bold", 24, "left", "center")
    UI.text("Escolha onde quer lutar. Cada arena tem suas próprias armas.", x + pad, y + pad + s(28), w, s(20), UI.color("muted", 255 * a), "regular", 11, "left", "center")
    local current = getElementData(localPlayer, "dm:arena")
    local total = #getElementsByType("player")
    local tt = ("%d online"):format(total)
    UI.pill(tt, x + w - pad - UI.textWidth(tt, "semibold", 10) - s(20), y + pad + s(2), s(24), UI.color("accent", 40 * a), UI.color("accent", 255 * a), "semibold", 10)

    -- Fechar
    local cx, cy = x + w - pad - s(32), y + pad - s(6)
    if UI.button("arena_close", "×", cx, cy, s(32), s(32), { kind = "ghost", size = 12, alpha = a }) then end
    panel.closeBounds = { cx, cy, s(32), s(32) }

    local counts = countPlayers()
    local startY = y + pad + s(70)
    panel.cards = {}
    panel.hoverCard = nil
    for i, arena in ipairs(DM.arenas) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cxp = x + pad + col * (cardW + gap)
        local cyp = startY + row * (cardH + gap)
        local hover = UI.isMouseIn(cxp, cyp, cardW, cardH)
        local isCurrent = current == arena.id
        if hover then panel.hoverCard = arena.id end
        panel.cards[#panel.cards + 1] = { arena.id, cxp, cyp, cardW, cardH }

        UI.rect(cxp, cyp, cardW, cardH, UI.color("card2", (hover and 255 or 220) * a), s(14))
        UI.border(cxp, cyp, cardW, cardH, isCurrent and UI.rgb(arena.color, 200 * a) or tocolor(255, 255, 255, (hover and 50 or 20) * a), s(14))
        -- faixa de cor
        UI.rect(cxp, cyp + s(16), s(5), cardH - s(32), UI.rgb(arena.color, 255 * a), s(3))
        -- título
        UI.text(arena.name, cxp + s(22), cyp + s(16), cardW - s(44), s(22), UI.color("text", 255 * a), "bold", 14, "left", "center")
        -- tipo
        local typeLabel = arena.type == "lobby" and "SEGURO" or (arena.type == "duel" and "1v1" or "TODOS CONTRA TODOS")
        if arena.cbug then typeLabel = typeLabel .. " · C-BUG" end
        UI.text(typeLabel, cxp + s(22), cyp + s(38), cardW - s(44), s(14), UI.rgb(arena.color, 230 * a), "semibold", 8, "left", "center")
        -- armas
        UI.text(DM.arenaWeaponList(arena), cxp + s(22), cyp + s(56), cardW - s(44), s(34), UI.color("muted", 255 * a), "regular", 10, "left", "top", false, true)
        -- jogadores
        local n = counts[arena.id] or 0
        local pTxt = ("%d %s"):format(n, n == 1 and "jogador" or "jogadores")
        UI.rect(cxp + s(22), cyp + cardH - s(40), s(8), s(8), n > 0 and UI.color("accent", 255 * a) or UI.color("muted", 120 * a), s(4))
        UI.text(pTxt, cxp + s(36), cyp + cardH - s(46), cardW, s(20), UI.color("muted", 255 * a), "medium", 10, "left", "center")
        -- botão
        local bw, bh = s(92), s(30)
        local bx, by = cxp + cardW - bw - s(16), cyp + cardH - bh - s(14)
        if isCurrent then
            UI.rect(bx, by, bw, bh, UI.rgb(arena.color, 30 * a), s(8))
            UI.text("ATUAL", bx, by, bw, bh, UI.rgb(arena.color, 255 * a), "semibold", 10, "center", "center")
        else
            UI.button("arena_btn_" .. arena.id, "ENTRAR", bx, by, bw, bh, { kind = hover and "primary" or "outline", size = 10, alpha = a })
        end
    end

    -- Rodapé
    UI.divider(x + pad, y + h - s(52), w - pad * 2, 18 * a)
    UI.text("F2 ou ESC para fechar  ·  /arena <nome>  ·  /lobby", x + pad, y + h - s(44), w - pad * 2, s(30), UI.color("muted", 200 * a), "regular", 10, "left", "center")
    UI.text("Clique em um card para entrar", x + pad, y + h - s(44), w - pad * 2, s(30), UI.color("muted", 140 * a), "regular", 10, "right", "center")
end

local function onClick(button, state)
    if button ~= "left" or state ~= "down" or not panel.open then return end
    if panel.closeBounds and UI.isMouseIn(unpack(panel.closeBounds)) then
        closeArenaPanel()
        return
    end
    for _, c in ipairs(panel.cards or {}) do
        if UI.isMouseIn(c[2], c[3], c[4], c[5]) then
            playUISound("click")
            triggerServerEvent("dm:requestArena", localPlayer, c[1])
            closeArenaPanel()
            return
        end
    end
end

function openArenaPanel()
    if panel.open then return end
    if not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    addEventHandler("onClientRender", root, render)
    addEventHandler("onClientClick", root, onClick)
    playUISound("click", 0.4)
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

bindKey("F2", "down", toggleArenaPanel)
UI.registerEscape(PANEL, closeArenaPanel)

function isPanelOpen() return UI.getOpenPanel() ~= nil end
