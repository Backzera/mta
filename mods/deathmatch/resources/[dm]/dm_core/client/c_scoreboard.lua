--[[
    Placar (TAB): tag, jogador, clã, elo/RP, kills, mortes, K/D, arena, ping.
]]

local board = { open = false, tick = 0, rendering = false }

local function collect()
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:ready") then
            local kills = tonumber(getElementData(p, "dm:kills")) or 0
            local deaths = tonumber(getElementData(p, "dm:deaths")) or 0
            local rp = tonumber(getElementData(p, "dm:rp")) or 0
            list[#list + 1] = {
                player = p, name = DM.stripColors(getPlayerName(p)),
                rp = rp, tier = DM.tierForRP(rp),
                kills = kills, deaths = deaths, kd = deaths > 0 and kills / deaths or kills,
                arena = DM.getArena(getElementData(p, "dm:arena") or ""),
                ping = getPlayerPing(p), streak = tonumber(getElementData(p, "dm:streak")) or 0,
                tag = getElementData(p, "dm:tag"), clan = getElementData(p, "dm:clanTag"),
                nameColor = getElementData(p, "dm:nameColor"),
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
    local progress = UI.openProgress(board, 140)
    if progress <= 0 then
        if not board.open then
            removeEventHandler("onClientRender", root, render)
            board.rendering = false
        end
        return
    end
    local a = progress
    local s = UI.s
    local list = collect()
    local rowH = s(36)
    local maxRows = math.min(#list, 18)
    local w = s(1000)
    local h = s(116) + maxRows * rowH + s(44)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + (1 - a) * s(16)

    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 5, 12, 140 * a))
    UI.card(x, y, w, h, s(16), a)
    local pad = s(28)
    UI.image("logo.png", x + pad, y + s(16), s(160), s(50), tocolor(255, 255, 255, 255 * a))
    UI.text(("%d jogadores online  ·  ordenado por elo"):format(#list), x + pad + s(176), y + s(22), w, s(20), UI.color("text", 255 * a), "semibold", 12, "left", "center")
    UI.text(DM.server.fullName, x + pad + s(176), y + s(44), w, s(18), UI.color("muted", 255 * a), "regular", 10, "left", "center")

    local cols = {
        { "#", s(36), "center" }, { "TAG", s(110), "center" }, { "JOGADOR", s(220), "left" }, { "CLÃ", s(70), "center" },
        { "ELO", s(96), "center" }, { "RP", s(60), "center" }, { "KILLS", s(70), "center" }, { "MORTES", s(70), "center" },
        { "K/D", s(60), "center" }, { "ARENA", s(100), "center" }, { "PING", s(52), "center" },
    }
    local hy = y + s(84)
    UI.rect(x + pad - s(8), hy, w - pad * 2 + s(16), s(24), tocolor(255, 255, 255, 8 * a), s(6))
    local cx = x + pad
    for _, c in ipairs(cols) do
        UI.text(c[1], cx, hy, c[2], s(24), UI.color("muted", 220 * a), "semibold", 9, c[3], "center")
        cx = cx + c[2]
    end

    local ry = hy + s(30)
    for i = 1, maxRows do
        local r = list[i]
        local isMe = r.player == localPlayer
        if isMe then
            UI.rect(x + pad - s(8), ry, w - pad * 2 + s(16), rowH, UI.color("accent", 30 * a), s(8))
        elseif i % 2 == 0 then
            UI.rect(x + pad - s(8), ry, w - pad * 2 + s(16), rowH, tocolor(255, 255, 255, 4 * a), s(8))
        end
        cx = x + pad
        local posColor = i == 1 and UI.color("gold", 255 * a) or (i <= 3 and UI.color("text", 255 * a) or UI.color("muted", 255 * a))
        UI.text(tostring(i), cx, ry, cols[1][2], rowH, posColor, "bold", 11, "center", "center"); cx = cx + cols[1][2]
        -- tag
        if type(r.tag) == "table" then
            local tw = UI.textWidth(r.tag.text, "bold", 8) + s(16)
            UI.tagPill(r.tag, cx + (cols[2][2] - tw) / 2, ry + (rowH - s(18)) / 2, s(18), a, 8)
        end
        cx = cx + cols[2][2]
        -- nome
        local nr, ng, nb = UI.hexToRGB(r.nameColor)
        local nameTxt = UI.truncate(r.name, "medium", 12, cols[3][2] - s(60))
        UI.text(nameTxt, cx, ry, cols[3][2], rowH, isMe and UI.color("accent2", 255 * a) or tocolor(nr, ng, nb, 255 * a), "medium", 12, "left", "center")
        if r.streak >= 3 then
            local nw = UI.textWidth(nameTxt, "medium", 12)
            UI.pill(("%d"):format(r.streak), cx + nw + s(8), ry + (rowH - s(16)) / 2, s(16), UI.color("danger", 50 * a), UI.color("danger", 255 * a), "bold", 8, s(6))
        end
        cx = cx + cols[3][2]
        if type(r.clan) == "table" and r.clan.text then
            local cr, cg, cb = UI.hexToRGB(r.clan.hex)
            UI.text(r.clan.text, cx, ry, cols[4][2], rowH, tocolor(cr, cg, cb, 255 * a), "bold", 10, "center", "center")
        else
            UI.text("—", cx, ry, cols[4][2], rowH, UI.color("muted", 120 * a), "medium", 10, "center", "center")
        end
        cx = cx + cols[4][2]
        UI.text(r.tier.name, cx, ry, cols[5][2], rowH, UI.rgb(r.tier.color, 255 * a), "semibold", 10, "center", "center"); cx = cx + cols[5][2]
        UI.text(tostring(r.rp), cx, ry, cols[6][2], rowH, UI.color("text", 255 * a), "semibold", 11, "center", "center"); cx = cx + cols[6][2]
        UI.text(tostring(r.kills), cx, ry, cols[7][2], rowH, UI.color("text", 255 * a), "semibold", 11, "center", "center"); cx = cx + cols[7][2]
        UI.text(tostring(r.deaths), cx, ry, cols[8][2], rowH, UI.color("muted", 255 * a), "medium", 11, "center", "center"); cx = cx + cols[8][2]
        UI.text(("%.2f"):format(r.kd), cx, ry, cols[9][2], rowH, UI.color("text", 255 * a), "medium", 11, "center", "center"); cx = cx + cols[9][2]
        if r.arena then
            UI.text(r.arena.short, cx, ry, cols[10][2], rowH, UI.rgb(r.arena.color, 255 * a), "semibold", 9, "center", "center", true)
        end
        cx = cx + cols[10][2]
        local pc = r.ping < 80 and "success" or (r.ping < 150 and "warn" or "danger")
        UI.text(tostring(r.ping), cx, ry, cols[11][2], rowH, UI.color(pc, 255 * a), "medium", 10, "center", "center")
        ry = ry + rowH
    end
    if #list > maxRows then
        UI.text(("+ %d jogadores"):format(#list - maxRows), x, ry, w, s(20), UI.color("muted", 200 * a), "regular", 10, "center", "center")
    end
    UI.text("Solte TAB para fechar  ·  /top rp|kills|money|duelos", x + pad, y + h - s(36), w - pad * 2, s(20), UI.color("muted", 160 * a), "regular", 10, "right", "center")
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
