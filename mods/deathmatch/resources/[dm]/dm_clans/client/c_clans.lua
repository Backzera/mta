--[[
    Clãs — cliente (UI v2, F6): criar clã, convites, ranking; com clã: cabeçalho na cor do clã,
    stats, membros com ações por cargo, convidar, clã x clã dourado, cores da tag.
]]

local core = exports.dm_core
local PANEL = "clans"
local panel = { open = false, tick = 0, rendering = false, selectedPlayer = nil, selectedClan = nil, modeId = nil, scroll = 0 }
local data = nil
local fName = { text = "", placeholder = "Nome do clã (3-20)", maxLength = 20, icon = "shield.png" }
local fTag = { text = "", placeholder = "TAG", maxLength = 5, allowed = "[%w]" }
local inputState

local function s(v) return UI.s(v) end
local function formatMoney(v) return core:formatMoney(v) end
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local ROLE = { leader = "LÍDER", officer = "OFICIAL", member = "MEMBRO" }
local PALETTE = { { 139, 92, 246 }, { 34, 211, 238 }, { 34, 230, 138 }, { 245, 196, 81 }, { 255, 77, 109 }, { 255, 140, 66 }, { 255, 105, 180 }, { 120, 220, 255 } }

local function renderRanking(f, rx, rw, ry)
    local a = f.a
    UI.text("RANKING DE CLÃS", rx, ry, rw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    ry = ry + s(24)
    if #data.clans == 0 then UI.text("Nenhum clã ainda. Seja o primeiro!", rx, ry, rw, s(20), UI.color("muted", 200 * a), "regular", 10, "left", "center") end
    for i, c in ipairs(data.clans) do
        if i > 9 then break end
        local p = UI.stagger(a, i, 9, 0.5)
        local rh = s(32)
        local ox = (1 - p) * s(16)
        local sel = panel.selectedClan == c.id
        UI.listRow("clan:rank:" .. c.id, rx + ox, ry, rw, rh - s(3), sel, a * p)
        UI.text(("#%d"):format(i), rx + ox + s(8), ry, s(28), rh - s(3), UI.color("muted", 255 * a * p), "bold", 9, "left", "center")
        UI.text(("[%s]"):format(c.tag), rx + ox + s(34), ry, s(60), rh - s(3), UI.rgb(c.color, 255 * a * p), "bold", 11, "left", "center")
        UI.text(UI.truncate(c.name, "medium", 10, rw - s(230)), rx + ox + s(94), ry, rw - s(230), rh - s(3), UI.color("text", 255 * a * p), "medium", 10, "left", "center")
        UI.text(("%d pts · %dV %dD · %d on"):format(c.points, c.wins, c.losses, c.online), rx + ox, ry, rw - s(8), rh - s(3), UI.color("muted", 255 * a * p), "regular", 8, "right", "center")
        local id = c.id
        UI.addClick(rx, ry, rw, rh - s(3), function() panel.selectedClan = id end, "clan:rank:" .. id)
        ry = ry + rh
    end
end

local function renderNoClan(f)
    local a = f.a
    local cx, cy, cw = f.cx, f.cy, s(380)
    UI.text("CRIAR CLÃ", cx, cy, cw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    UI.inputField(fTag, cx, cy + s(24), s(110), s(40), { size = 12 })
    UI.inputField(fName, cx + s(120), cy + s(24), cw - s(120), s(40), { size = 12 })
    local money = tonumber(getElementData(localPlayer, "dm:money")) or 0
    local can = money >= (data.createCost or 0)
    UI.button("clan_create", ("FUNDAR CLÃ  ·  %s"):format(formatMoney(data.createCost or 0)), cx, cy + s(76), cw, s(42), { kind = "primary", size = 11, alpha = a, disabled = not can, icon = "shield.png",
        onClick = function() triggerServerEvent("clans:create", localPlayer, fName.text, fTag.text) end })
    if not can then UI.text("Saldo insuficiente — kills, duelos e ranqueadas dão $.", cx, cy + s(122), cw, s(18), UI.color("danger", 220 * a), "regular", 9, "left", "center") end
    local iy = cy + s(152)
    UI.text("CONVITES", cx, iy, cw, s(16), UI.color("gold", 255 * a), "semibold", 9, "left", "center")
    if #data.invites == 0 then
        UI.text("Nenhum convite pendente.", cx, iy + s(22), cw, s(20), UI.color("muted", 200 * a), "regular", 10, "left", "center")
    else
        local inv = data.invites[1]
        local c = UI.palette.gold
        UI.rrect(cx, iy + s(22), cw, s(68), tocolor(c[1], c[2], c[3], 24 * a), s(10), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 120 * a), glow = s(10) * UI.pulse(1200, 0.5, 1), glowColor = tocolor(c[1], c[2], c[3], 70 * a) })
        UI.text(("[%s] %s"):format(inv.tag, inv.name), cx + s(12), iy + s(28), cw, s(18), UI.color("text", 255 * a), "semibold", 11, "left", "center")
        UI.text("Convidado por " .. inv.from, cx + s(12), iy + s(46), cw, s(14), UI.color("muted", 255 * a), "regular", 9, "left", "center")
        local bw = (cw - s(24) - s(8)) / 2
        UI.button("clan_acc", "Aceitar", cx + s(12), iy + s(64), bw, s(20), { kind = "primary", color = "gold", size = 8, alpha = a, radius = s(6), onClick = function() triggerServerEvent("clans:respondInvite", localPlayer, true) end })
        UI.button("clan_dec", "Recusar", cx + s(12) + bw + s(8), iy + s(64), bw, s(20), { kind = "outline", color = "danger", size = 8, alpha = a, radius = s(6), onClick = function() triggerServerEvent("clans:respondInvite", localPlayer, false) end })
    end
    renderRanking(f, cx + cw + s(32), f.cw - cw - s(32), cy)
end

local function renderClan(f)
    local a = f.a
    local c = data.clan
    local isLeader = c.role == "leader"
    local isOfficer = isLeader or c.role == "officer"
    -- cabeçalho do clã
    local hx, hy, hw = f.cx, f.cy, f.cw
    UI.rrect(hx, hy, hw, s(64), UI.rgb(c.color, 18 * a), s(12), { border = 1, borderColor = UI.rgb(c.color, 90 * a), glow = s(12), glowColor = UI.rgb(c.color, 60 * a), gradient = UI.rgb(c.color, 4 * a), gradientMode = 2 })
    UI.textGlow(("[%s]"):format(c.tag), hx + s(16), hy, s(140), s(64), UI.rgb(c.color, 255 * a), UI.rgb(c.color, 150 * a), "bold", 26, "left", "center")
    local tagW = UI.textWidth(("[%s]"):format(c.tag), "bold", 26)
    UI.text(c.name, hx + s(16) + tagW + s(16), hy + s(10), hw, s(26), UI.color("text", 255 * a), "bold", 16, "left", "center")
    UI.text(("você é %s"):format(ROLE[c.role] or c.role), hx + s(16) + tagW + s(16), hy + s(36), hw, s(18), UI.color("muted", 255 * a), "regular", 9, "left", "center")
    UI.stat(hx + hw - s(300), hy + s(12), s(90), "PONTOS", tostring(math.floor(UI.counter("clan:pts", c.points, 800) + 0.5)), "gold", a, 15)
    UI.stat(hx + hw - s(200), hy + s(12), s(90), "VITÓRIAS", tostring(c.wins), "success", a, 15)
    UI.stat(hx + hw - s(100), hy + s(12), s(90), "DERROTAS", tostring(c.losses), "danger", a, 15)

    -- membros
    local mx, my, mw = f.cx, f.cy + s(80), s(340)
    UI.text(("MEMBROS (%d)"):format(#c.members), mx, my, mw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local ry, rowH = my + s(24), s(32)
    local listH = f.ch - s(80) - s(150)
    local maxRows = math.max(1, math.floor(listH / rowH))
    panel.scroll = UI.clamp(panel.scroll, 0, math.max(0, #c.members - maxRows))
    panel.listBounds = { mx, ry, mw, maxRows * rowH }
    local off = UI.scroll("clan:members", panel.scroll)
    for i = math.floor(off) + 1, math.min(#c.members, math.floor(off) + maxRows + 1) do
        local m = c.members[i]
        local y = ry + (i - 1 - off) * rowH
        if y >= ry - s(2) and y + rowH <= ry + maxRows * rowH + s(2) then
            UI.listRow("clan:member:" .. m.name, mx, y, mw, rowH - s(3), false, a)
            local dot = m.online and UI.pulse(1500, 0.6, 1) or 0.3
            UI.rrect(mx + s(8), y + (rowH - s(3)) / 2 - s(4), s(8), s(8), m.online and UI.color("success", 255 * a * dot) or UI.color("muted", 80 * a), s(4), m.online and { glow = s(5), glowColor = UI.color("success", 120 * a) } or nil)
            UI.text(m.name, mx + s(22), y, mw, rowH - s(3), UI.color(m.online and "text" or "muted", 255 * a), "medium", 10, "left", "center")
            UI.text(("%s · %d RP"):format(ROLE[m.role] or "MEMBRO", m.rp or 0), mx, y, mw - (isOfficer and s(60) or s(10)), rowH - s(3), m.role == "leader" and UI.color("gold", 255 * a) or UI.color("muted", 255 * a), "semibold", 8, "right", "center")
            if isOfficer and m.role ~= "leader" and m.name ~= nick(localPlayer) then
                local n = m.name
                UI.iconButton("clan_kick_" .. n, "×", mx + mw - s(26), y + s(3), s(22), { alpha = a, size = 11, tooltip = "Expulsar", onClick = function() triggerServerEvent("clans:kick", localPlayer, n) end })
                if isLeader and m.online then
                    UI.iconButton("clan_prom_" .. n, m.role == "officer" and "–" or "+", mx + mw - s(52), y + s(3), s(22), { alpha = a, size = 11, tooltip = m.role == "officer" and "Rebaixar" or "Promover a oficial", onClick = function() triggerServerEvent("clans:promote", localPlayer, n) end })
                end
            end
        end
    end
    UI.scrollbar(mx + mw + s(6), ry, maxRows * rowH, #c.members, maxRows, off, a)

    -- convidar / sair
    local iy = f.y + f.h - s(142)
    UI.text("CONVIDAR", mx, iy, mw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    if isOfficer then
        local list = {}
        for _, p in ipairs(getElementsByType("player")) do
            if p ~= localPlayer and getElementData(p, "dm:ready") and not getElementData(p, "dm:clanTag") then list[#list + 1] = p end
        end
        if not isElement(panel.selectedPlayer) then panel.selectedPlayer = list[1] end
        local name = isElement(panel.selectedPlayer) and nick(panel.selectedPlayer) or "ninguém disponível"
        local function cycle(dir)
            if #list == 0 then return end
            local idx = 1
            for i, p in ipairs(list) do if p == panel.selectedPlayer then idx = i end end
            panel.selectedPlayer = list[((idx - 1 + dir) % #list) + 1]
        end
        UI.glass(mx, iy + s(22), mw - s(110), s(34), s(8), a)
        UI.iconButton("clan_prev", "‹", mx + s(4), iy + s(26), s(26), { alpha = a, size = 13, onClick = function() cycle(-1) end })
        UI.text(name, mx + s(32), iy + s(22), mw - s(110) - s(64), s(34), UI.color("text", 255 * a), "medium", 10, "center", "center", true)
        UI.iconButton("clan_next", "›", mx + mw - s(110) - s(30), iy + s(26), s(26), { alpha = a, size = 13, onClick = function() cycle(1) end })
        local target = panel.selectedPlayer
        UI.button("clan_invite", "CONVIDAR", mx + mw - s(100), iy + s(22), s(100), s(34), { kind = "primary", size = 9, alpha = a, disabled = not isElement(target),
            onClick = function() if isElement(target) then triggerServerEvent("clans:invite", localPlayer, target) end end })
    else
        UI.text("Só líder e oficiais convidam.", mx, iy + s(22), mw, s(20), UI.color("muted", 200 * a), "regular", 9, "left", "center")
    end
    UI.button("clan_leave", isLeader and "SAIR / PASSAR LIDERANÇA" or "SAIR DO CLÃ", mx, f.y + f.h - s(78), mw, s(30), { kind = "outline", color = "danger", size = 9, alpha = a, onClick = function() triggerServerEvent("clans:leave", localPlayer) end })

    -- clã x clã
    local rx = mx + mw + s(32)
    local rw = f.cx + f.cw - rx
    UI.text("CLÃ x CLÃ", rx, my, rw, s(16), UI.color("gold", 255 * a), "semibold", 9, "left", "center")
    local gy = my + s(22)
    if data.challenge then
        local ch = data.challenge
        local g = UI.palette.gold
        local modeName = ch.modeId
        for _, m in ipairs(data.modes) do if m.id == ch.modeId then modeName = m.name end end
        UI.rrect(rx, gy, rw, s(70), tocolor(g[1], g[2], g[3], 24 * a), s(10), { border = 1, borderColor = tocolor(g[1], g[2], g[3], 140 * a), glow = s(10) * UI.pulse(1000, 0.5, 1), glowColor = tocolor(g[1], g[2], g[3], 80 * a) })
        UI.text(("[%s] %s desafiou vocês   ·   %s"):format(ch.fromTag, ch.fromName, modeName), rx + s(12), gy + s(8), rw - s(24), s(20), UI.color("text", 255 * a), "semibold", 10, "left", "center", true)
        if isOfficer then
            local bw = (rw - s(24) - s(8)) / 2
            UI.button("clan_chacc", "ACEITAR", rx + s(12), gy + s(38), bw, s(24), { kind = "primary", color = "gold", size = 8, alpha = a, radius = s(6), onClick = function() triggerServerEvent("clans:respondChallenge", localPlayer, true) end })
            UI.button("clan_chdec", "RECUSAR", rx + s(12) + bw + s(8), gy + s(38), bw, s(24), { kind = "outline", color = "danger", size = 8, alpha = a, radius = s(6), onClick = function() triggerServerEvent("clans:respondChallenge", localPlayer, false) end })
        else
            UI.text("Aguardando o líder/oficiais responderem.", rx + s(12), gy + s(36), rw, s(28), UI.color("muted", 255 * a), "regular", 9, "left", "center")
        end
        gy = gy + s(84)
    else
        local bx = rx
        for _, m in ipairs(data.modes) do
            local bw = UI.textWidth(m.name, "semibold", 9) + s(20)
            if not panel.modeId then panel.modeId = m.id end
            local sel = panel.modeId == m.id
            local t = UI.hover("clan:mode:" .. m.id, UI.isMouseIn(bx, gy, bw, s(26)))
            local g = UI.palette.gold
            UI.rrect(bx, gy, bw, s(26), sel and tocolor(g[1], g[2], g[3], 60 * a) or tocolor(255, 255, 255, (8 + 12 * t) * a), s(6), { border = 1, borderColor = sel and tocolor(g[1], g[2], g[3], 200 * a) or tocolor(255, 255, 255, (16 + 40 * t) * a) })
            UI.text(m.name, bx, gy, bw, s(26), sel and UI.color("gold", 255 * a) or UI.color("muted", 255 * a), "semibold", 9, "center", "center")
            local id = m.id
            UI.addClick(bx, gy, bw, s(26), function() panel.modeId = id end, "clan:mode:" .. id)
            bx = bx + bw + s(6)
        end
        local target
        for _, cl in ipairs(data.clans) do if cl.id == panel.selectedClan then target = cl end end
        local ok = isOfficer and target and target.id ~= c.id
        UI.button("clan_challenge", ok and ("DESAFIAR [" .. target.tag .. "]") or "SELECIONE UM CLÃ NO RANKING", rx, gy + s(34), rw, s(32), { kind = "primary", color = "gold", size = 9, alpha = a, disabled = not ok, icon = "swords.png",
            onClick = function() if ok then triggerServerEvent("clans:challenge", localPlayer, target.id, panel.modeId) end end })
        UI.text(("Mínimo %d por lado · times = menor clã online · vitória +30 pts"):format(data.minClanMatch or 2), rx, gy + s(70), rw, s(14), UI.color("muted", 200 * a), "regular", 8, "left", "center")
        gy = gy + s(92)
    end
    renderRanking(f, rx, rw, gy)
    if isLeader then
        local cy = f.y + f.h - s(78)
        UI.text("COR DA TAG", rx, cy - s(16), rw, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
        local px = rx
        for i, col in ipairs(PALETTE) do
            local t = UI.hover("clan:color:" .. i, UI.isMouseIn(px, cy, s(24), s(24)))
            UI.rrect(px, cy - s(2) * t, s(24), s(24) + s(2) * t, UI.rgb(col, 255 * a), s(7), { glow = s(4) + s(8) * t, glowColor = UI.rgb(col, 150 * a) })
            local idx = i
            UI.addClick(px, cy, s(24), s(24), function() triggerServerEvent("clans:setColor", localPlayer, idx) end, "clan:color:" .. i)
            px = px + s(30)
        end
    end
end

local function render()
    local f = UI.panelFrame(panel, {
        w = s(940), h = s(620), title = data and data.clan and "MEU CLÃ" or "CLÃS",
        subtitle = data and (data.clan and "Convide jogadores, suba no ranking e dispute clã x clã nas ranqueadas." or ("Crie o seu clã (%s) ou aceite um convite."):format(formatMoney(data.createCost or 0))) or "Carregando...",
        icon = "shield.png", accent = data and data.clan and "gold" or "accent", onClose = closeClanPanel,
    })
    if not f then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    if not data then
        UI.text("Carregando...", f.cx, f.cy, f.cw, f.ch, UI.color("muted", 255 * f.a), "medium", 12, "center", "center")
    elseif data.clan then
        renderClan(f)
    else
        renderNoClan(f)
    end
    UI.panelFooter(f, "F6 ou ESC fecha   ·   /cla criar <TAG> <nome>   ·   /c <mensagem> fala no chat do clã")
    UI.endFrame()
end

local function onClick(button, st)
    if panel.open then UI.processClick(button, st) end
end

local function onWheel(key, press)
    if not panel.open or not press then return end
    if key == "mouse_wheel_up" or key == "mouse_wheel_down" then
        local b = panel.listBounds
        if b and UI.isMouseIn(b[1], b[2], b[3], b[4]) then
            panel.scroll = math.max(0, panel.scroll + (key == "mouse_wheel_down" and 1 or -1))
        end
    end
end

function openClanPanel()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    data = nil
    triggerServerEvent("clans:requestInfo", localPlayer)
    if not panel.rendering then panel.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    addEventHandler("onClientKey", root, onWheel)
    inputState = UI.bindInputs({ fTag, fName })
    UI.sound("click", 0.4)
end

function closeClanPanel()
    if not panel.open then return end
    panel.open = false
    panel.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
    removeEventHandler("onClientKey", root, onWheel)
    UI.unbindInputs(inputState)
    inputState = nil
end

bindKey("F6", "down", function() if panel.open then closeClanPanel() else openClanPanel() end end)
UI.registerEscape(PANEL, closeClanPanel)

addEvent("clans:info", true)
addEventHandler("clans:info", root, function(d)
    data = d
    if d and d.clan then fName.text, fTag.text = "", "" end
end)
