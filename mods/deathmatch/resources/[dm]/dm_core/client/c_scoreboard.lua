--[[
    Placar (TAB): fundo desfocado, cabeçalho com logo, linhas em cascata, top 3 com cor de medalha,
    pílulas de tag/clã/elo, ID, linha do jogador local brilhando.
]]

local board = { open = false, tick = 0, rendering = false }
local MEDALS = { { 245, 196, 81 }, { 200, 205, 215 }, { 205, 127, 50 } }

local function collect()
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:ready") then
            local kills = tonumber(getElementData(p, "dm:kills")) or 0
            local deaths = tonumber(getElementData(p, "dm:deaths")) or 0
            local rp = tonumber(getElementData(p, "dm:rp")) or 0
            list[#list + 1] = {
                player = p, name = DM.stripColors(getPlayerName(p)), id = tonumber(getElementData(p, "dm:id")) or 0,
                rp = rp, tier = DM.tierForRP(rp), kills = kills, deaths = deaths, kd = deaths > 0 and kills / deaths or kills,
                arena = DM.getArena(getElementData(p, "dm:arena") or ""), ping = getPlayerPing(p),
                streak = tonumber(getElementData(p, "dm:streak")) or 0,
                tag = getElementData(p, "dm:tag"), clan = getElementData(p, "dm:clanTag"), nameColor = getElementData(p, "dm:nameColor"),
            }
        end
    end
    table.sort(list, function(a, b)
        if a.rp ~= b.rp then return a.rp > b.rp end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.name:lower() < b.name:lower()
    end)
    return list
end

local function render()
    local a, scale, dy = UI.panelAnim(board, 220)
    if a <= 0.001 then
        if not board.open then removeEventHandler("onClientRender", root, render) board.rendering = false end
        return
    end
    local s = UI.s
    local list = collect()
    local rowH = s(36)
    local maxRows = math.min(#list, 18)
    local w = s(1040) * scale
    local h = (s(120) + maxRows * rowH + s(50)) * scale
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + dy
    UI.backdrop(a * 0.8, 110)
    UI.card(x, y, w, h, s(18), a, "accent", { glow = s(26) })
    local pad = s(28)
    UI.aurora(x + s(2), y + s(2), w - s(4), s(80), 0.14 * a, { UI.palette.accent, UI.palette.accent2, UI.palette.bg })
    UI.image("logo.png", x + pad, y + s(14), s(180), s(56), tocolor(255, 255, 255, 255 * a))
    UI.text(("%d jogadores online   ·   ordenado por elo"):format(#list), x + pad + s(196), y + s(22), w, s(20), UI.color("text", 255 * a), "semibold", 12, "left", "center")
    UI.text(DM.server.fullName, x + pad + s(196), y + s(44), w, s(18), UI.color("muted", 255 * a), "regular", 10, "left", "center")

    local cols = {
        { "#", s(36), "center" }, { "ID", s(58), "center" }, { "TAG", s(104), "center" }, { "JOGADOR", s(210), "left" }, { "CLÃ", s(66), "center" },
        { "ELO", s(96), "center" }, { "RP", s(58), "center" }, { "KILLS", s(64), "center" }, { "MORTES", s(66), "center" },
        { "K/D", s(56), "center" }, { "ARENA", s(96), "center" }, { "PING", s(50), "center" },
    }
    local hy = y + s(90)
    UI.rrect(x + pad - s(8), hy, w - pad * 2 + s(16), s(24), tocolor(255, 255, 255, 8 * a), s(6))
    local cx = x + pad
    for _, c in ipairs(cols) do
        UI.text(c[1], cx, hy, c[2], s(24), UI.color("muted", 220 * a), "semibold", 8, c[3], "center")
        cx = cx + c[2]
    end
    local ry = hy + s(30)
    for i = 1, maxRows do
        local r = list[i]
        local p = UI.stagger(a, i, maxRows, 0.6)
        local ra = a * p
        local ox = (1 - p) * s(20)
        local isMe = r.player == localPlayer
        local rx = x + pad - s(8) + ox
        if isMe then
            UI.rrect(rx, ry, w - pad * 2 + s(16), rowH, UI.color("accent", 30 * ra), s(8), { border = 1, borderColor = UI.color("accent", 120 * ra), glow = s(8), glowColor = UI.color("accent", 60 * ra) })
        elseif i % 2 == 0 then
            UI.rrect(rx, ry, w - pad * 2 + s(16), rowH, tocolor(255, 255, 255, 4 * ra), s(8))
        end
        cx = x + pad + ox
        local medal = MEDALS[i]
        if medal then
            UI.rrect(cx + (cols[1][2] - s(20)) / 2, ry + (rowH - s(20)) / 2, s(20), s(20), UI.rgb(medal, 220 * ra), s(10), { glow = s(6), glowColor = UI.rgb(medal, 120 * ra) })
            UI.text(tostring(i), cx, ry, cols[1][2], rowH, tocolor(12, 18, 14, 255 * ra), "bold", 10, "center", "center")
        else
            UI.text(tostring(i), cx, ry, cols[1][2], rowH, UI.color("muted", 255 * ra), "bold", 11, "center", "center")
        end
        cx = cx + cols[1][2]
        UI.text(tostring(r.id), cx, ry, cols[2][2], rowH, UI.color("muted", 255 * ra), "medium", 10, "center", "center"); cx = cx + cols[2][2]
        if type(r.tag) == "table" then
            local tw = UI.textWidth(r.tag.text, "bold", 8) + s(16)
            UI.tagPill(r.tag, cx + (cols[3][2] - tw) / 2, ry + (rowH - s(18)) / 2, s(18), ra, 8)
        end
        cx = cx + cols[3][2]
        local nr, ng, nb = UI.hexToRGB(r.nameColor)
        local nameTxt = UI.truncate(r.name, "medium", 12, cols[4][2] - s(60))
        UI.text(nameTxt, cx, ry, cols[4][2], rowH, isMe and UI.color("accent2", 255 * ra) or tocolor(nr, ng, nb, 255 * ra), "medium", 12, "left", "center")
        if r.streak >= 3 then
            UI.pill(("x%d"):format(r.streak), cx + UI.textWidth(nameTxt, "medium", 12) + s(8), ry + (rowH - s(16)) / 2, s(16), UI.color("danger", 50 * ra), UI.color("danger", 255 * ra), "bold", 8, s(6))
        end
        cx = cx + cols[4][2]
        if type(r.clan) == "table" and r.clan.text then
            local cr, cg, cb = UI.hexToRGB(r.clan.hex)
            UI.text(r.clan.text, cx, ry, cols[5][2], rowH, tocolor(cr, cg, cb, 255 * ra), "bold", 10, "center", "center")
        else
            UI.text("—", cx, ry, cols[5][2], rowH, UI.color("muted", 100 * ra), "medium", 10, "center", "center")
        end
        cx = cx + cols[5][2]
        UI.text(r.tier.name, cx, ry, cols[6][2], rowH, UI.rgb(r.tier.color, 255 * ra), "semibold", 10, "center", "center"); cx = cx + cols[6][2]
        UI.text(tostring(r.rp), cx, ry, cols[7][2], rowH, UI.color("text", 255 * ra), "semibold", 11, "center", "center"); cx = cx + cols[7][2]
        UI.text(tostring(r.kills), cx, ry, cols[8][2], rowH, UI.color("text", 255 * ra), "semibold", 11, "center", "center"); cx = cx + cols[8][2]
        UI.text(tostring(r.deaths), cx, ry, cols[9][2], rowH, UI.color("muted", 255 * ra), "medium", 11, "center", "center"); cx = cx + cols[9][2]
        UI.text(("%.2f"):format(r.kd), cx, ry, cols[10][2], rowH, UI.color("text", 255 * ra), "medium", 11, "center", "center"); cx = cx + cols[10][2]
        if r.arena then UI.text(r.arena.short, cx, ry, cols[11][2], rowH, UI.rgb(r.arena.color, 255 * ra), "semibold", 9, "center", "center", true) end
        cx = cx + cols[11][2]
        local pc = r.ping < 80 and "success" or (r.ping < 150 and "warn" or "danger")
        UI.text(tostring(r.ping), cx, ry, cols[12][2], rowH, UI.color(pc, 255 * ra), "medium", 10, "center", "center")
        ry = ry + rowH
    end
    if #list > maxRows then
        UI.text(("+ %d jogadores"):format(#list - maxRows), x, ry, w, s(20), UI.color("muted", 200 * a), "regular", 10, "center", "center")
    end
    UI.text("Solte TAB para fechar   ·   /top rp|kills|money|duelos", x + pad, y + h - s(36), w - pad * 2, s(20), UI.color("muted", 160 * a), "regular", 9, "right", "center")
end

bindKey("tab", "down", function()
    if board.open or not getElementData(localPlayer, "dm:ready") then return end
    if UI.getOpenPanel() then return end
    board.open = true
    board.tick = getTickCount()
    if not board.rendering then
        board.rendering = true
        addEventHandler("onClientRender", root, render)
    end
end)

bindKey("tab", "up", function()
    if not board.open then return end
    board.open = false
    board.tick = getTickCount()
end)
