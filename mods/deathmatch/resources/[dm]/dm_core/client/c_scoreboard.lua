--[[
    Placar (TAB): jogadores ordenados por kills.
]]

local board = { open = false, tick = 0 }

local function collect()
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:ready") then
            local kills = tonumber(getElementData(p, "dm:kills")) or 0
            local deaths = tonumber(getElementData(p, "dm:deaths")) or 0
            list[#list + 1] = {
                player = p, name = DM.stripColors(getPlayerName(p)),
                level = tonumber(getElementData(p, "dm:level")) or 1,
                kills = kills, deaths = deaths,
                kd = deaths > 0 and kills / deaths or kills,
                arena = DM.getArena(getElementData(p, "dm:arena") or ""),
                ping = getPlayerPing(p),
                streak = tonumber(getElementData(p, "dm:streak")) or 0,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.name:lower() < b.name:lower()
    end)
    return list
end

local function render()
    local progress = UI.openProgress(board, 140)
    if progress <= 0 then
        if not board.open then removeEventHandler("onClientRender", root, render) end
        return
    end
    local a = progress
    local s = UI.s
    local list = collect()
    local rowH = s(36)
    local maxRows = math.min(#list, 18)
    local w = s(820)
    local h = s(110) + maxRows * rowH + s(44)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + (1 - a) * s(16)

    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 7, 12, 120 * a))
    UI.card(x, y, w, h, s(20), a)
    local pad = s(28)
    UI.text(DM.server.name, x + pad, y + s(22), w, s(30), UI.color("text", 255 * a), "bold", 22, "left", "center")
    UI.text(("%d jogadores online  ·  %s"):format(#list, DM.server.tagline), x + pad, y + s(52), w, s(18), UI.color("muted", 255 * a), "regular", 11, "left", "center")

    -- Cabeçalho das colunas
    local cols = {
        { "#", s(40), "center" }, { "JOGADOR", s(250), "left" }, { "NÍVEL", s(70), "center" },
        { "KILLS", s(80), "center" }, { "MORTES", s(80), "center" }, { "K/D", s(70), "center" },
        { "ARENA", s(110), "center" }, { "PING", s(60), "center" },
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
            UI.rect(x + pad - s(8), ry, w - pad * 2 + s(16), rowH, UI.color("accent", 22 * a), s(8))
        elseif i % 2 == 0 then
            UI.rect(x + pad - s(8), ry, w - pad * 2 + s(16), rowH, tocolor(255, 255, 255, 4 * a), s(8))
        end
        local rank = DM.rankForLevel(r.level)
        cx = x + pad
        local posColor = i == 1 and UI.color("warn", 255 * a) or (i <= 3 and UI.color("text", 255 * a) or UI.color("muted", 255 * a))
        UI.text(tostring(i), cx, ry, cols[1][2], rowH, posColor, "bold", 11, "center", "center"); cx = cx + cols[1][2]
        local nameTxt = UI.truncate(r.name, "medium", 12, cols[2][2] - s(80))
        UI.text(nameTxt, cx, ry, cols[2][2], rowH, isMe and UI.color("accent", 255 * a) or UI.color("text", 255 * a), "medium", 12, "left", "center")
        if r.streak >= 3 then
            local nw = UI.textWidth(nameTxt, "medium", 12)
            UI.pill(("%d"):format(r.streak), cx + nw + s(8), ry + (rowH - s(16)) / 2, s(16), UI.color("danger", 50 * a), UI.color("danger", 255 * a), "bold", 8, s(6))
        end
        cx = cx + cols[2][2]
        UI.pill(tostring(r.level), cx + (cols[3][2] - UI.textWidth(tostring(r.level), "bold", 9) - s(16)) / 2, ry + (rowH - s(18)) / 2, s(18), UI.rgb(rank.color, 40 * a), UI.rgb(rank.color, 255 * a), "bold", 9, s(8)); cx = cx + cols[3][2]
        UI.text(tostring(r.kills), cx, ry, cols[4][2], rowH, UI.color("text", 255 * a), "semibold", 11, "center", "center"); cx = cx + cols[4][2]
        UI.text(tostring(r.deaths), cx, ry, cols[5][2], rowH, UI.color("muted", 255 * a), "medium", 11, "center", "center"); cx = cx + cols[5][2]
        UI.text(("%.2f"):format(r.kd), cx, ry, cols[6][2], rowH, UI.color("text", 255 * a), "medium", 11, "center", "center"); cx = cx + cols[6][2]
        if r.arena then
            UI.text(r.arena.short, cx, ry, cols[7][2], rowH, UI.rgb(r.arena.color, 255 * a), "semibold", 10, "center", "center")
        end
        cx = cx + cols[7][2]
        local pc = r.ping < 80 and "accent" or (r.ping < 150 and "warn" or "danger")
        UI.text(tostring(r.ping), cx, ry, cols[8][2], rowH, UI.color(pc, 255 * a), "medium", 10, "center", "center")
        ry = ry + rowH
    end
    if #list > maxRows then
        UI.text(("+ %d jogadores"):format(#list - maxRows), x, ry, w, s(20), UI.color("muted", 200 * a), "regular", 10, "center", "center")
    end
    UI.text("Solte TAB para fechar", x + pad, y + h - s(36), w - pad * 2, s(20), UI.color("muted", 160 * a), "regular", 10, "right", "center")
end

bindKey("tab", "down", function()
    if board.open or not getElementData(localPlayer, "dm:ready") then return end
    if UI.getOpenPanel() then return end
    board.open = true
    board.tick = getTickCount()
    addEventHandler("onClientRender", root, render)
end)

bindKey("tab", "up", function()
    if not board.open then return end
    board.open = false
    board.tick = getTickCount()
end)
