--[[
    Duelo X1 — cliente (UI v2): painel (F3) em três colunas, popup de pedido com anel de tempo,
    HUD do duelo com placar animado, contagem gigante, "LUTE!" e resultado em painel de vidro.
]]

local core = exports.dm_core
local PANEL = "duel"
local panel = { open = false, tick = 0, rendering = false, selected = nil, weaponKey = "deagle", rounds = 3, scroll = 0 }
local search = { text = "", placeholder = "Buscar jogador...", maxLength = 20, icon = "target.png" }
local inputState
local incoming = {}
local outgoing = nil
local duel = nil
local result = nil
local weaponSets

local function s(v) return UI.s(v) end
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local function sets()
    if not weaponSets then weaponSets = core:getDuelWeaponSets() end
    return weaponSets
end

local function playerList()
    local list = {}
    local q = search.text:lower()
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer and getElementData(p, "dm:ready") then
            local name = nick(p)
            if q == "" or name:lower():find(q, 1, true) then
                list[#list + 1] = { player = p, name = name, rp = tonumber(getElementData(p, "dm:rp")) or 0, inDuel = getElementData(p, "dm:inDuel"), tag = getElementData(p, "dm:tag") }
            end
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

-- ---------------- Painel ----------------
local function render()
    local f = UI.panelFrame(panel, {
        w = s(960), h = s(600), title = "DUELO X1", subtitle = "Desafie alguém para um 1v1 em sala privada. Vitória dá RP e $.",
        icon = "swords.png", accent = "accent", onClose = closeDuelPanel,
        badge = outgoing and "AGUARDANDO RESPOSTA" or (#incoming > 0 and ("%d PEDIDO%s"):format(#incoming, #incoming > 1 and "S" or "") or nil),
        badgeColor = outgoing and "warn" or "gold",
    })
    if not f then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    local a = f.a
    local top = f.cy

    -- Coluna 1: jogadores
    local c1x, c1w = f.cx, s(280)
    UI.text("JOGADORES", c1x, top, c1w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    UI.inputField(search, c1x, top + s(22), c1w, s(36), { size = 11 })
    local listY, rowH = top + s(68), s(40)
    local listH = f.ch - s(68)
    local list = playerList()
    local maxRows = math.floor(listH / rowH)
    panel.scroll = UI.clamp(panel.scroll, 0, math.max(0, #list - maxRows))
    panel.listBounds = { c1x, listY, c1w, listH }
    if #list == 0 then
        UI.text(search.text ~= "" and "Nenhum jogador encontrado." or "Nenhum outro jogador online.", c1x, listY, c1w, s(60), UI.color("muted", 200 * a), "regular", 11, "center", "center", false, true)
    end
    local off = UI.scroll("duel:list", panel.scroll)
    for i = math.floor(off) + 1, math.min(#list, math.floor(off) + maxRows + 1) do
        local r = list[i]
        local ry = listY + (i - 1 - off) * rowH
        if ry >= listY - s(2) and ry + rowH <= listY + listH + s(2) then
            local p = UI.stagger(a, i - math.floor(off), maxRows, 0.4)
            local sel = panel.selected == r.player
            local t = UI.listRow("duel:row:" .. tostring(r.player), c1x, ry, c1w, rowH - s(4), sel, a * p)
            local tier = core:getTierForRP(r.rp)
            UI.pill(tier.short, c1x + s(10), ry + (rowH - s(4) - s(18)) / 2, s(18), UI.rgb(tier.color, 40 * a * p), UI.rgb(tier.color, 255 * a * p), "bold", 8, s(7))
            UI.text(UI.truncate(r.name, "medium", 11, c1w - s(130)), c1x + s(58), ry, c1w - s(100), rowH - s(4), UI.color("text", 255 * a * p), "medium", 11, "left", "center")
            if r.inDuel then UI.text("EM DUELO", c1x, ry, c1w - s(12), rowH - s(4), UI.color("danger", 255 * a * p), "semibold", 8, "right", "center") end
            local pl = r.player
            UI.addClick(c1x, ry, c1w, rowH - s(4), function() panel.selected = pl end, "duel:row:" .. tostring(pl))
        end
    end
    UI.scrollbar(c1x + c1w + s(6), listY, listH, #list, maxRows, off, a)

    -- Coluna 2: armas
    local c2x, c2w = c1x + c1w + s(30), s(300)
    UI.text("ARMA", c2x, top, c2w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local chipW, chipH, gap = (c2w - s(10)) / 2, s(44), s(10)
    for i, set in ipairs(sets()) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local p = UI.stagger(a, i, #sets(), 0.5)
        local chx, chy = c2x + col * (chipW + gap), top + s(22) + row * (chipH + gap) + (1 - p) * s(10)
        local sel = panel.weaponKey == set.key
        local t = UI.hover("duel:chip:" .. set.key, UI.isMouseIn(chx, chy, chipW, chipH))
        local c = UI.palette.accent
        UI.rrect(chx, chy, chipW, chipH, sel and tocolor(c[1], c[2], c[3], 45 * a * p) or tocolor(255, 255, 255, (7 + 12 * t) * a * p), s(10), {
            border = 1, borderColor = sel and tocolor(c[1], c[2], c[3], 220 * a * p) or tocolor(255, 255, 255, (18 + 40 * t) * a * p),
            glow = (sel and s(10) or 0) + s(8) * t, glowColor = tocolor(c[1], c[2], c[3], 80 * a * p),
        })
        UI.text(set.name, chx + s(12), chy, chipW - s(24), chipH, sel and UI.color("accent2", 255 * a * p) or UI.color("text", 255 * a * p), "semibold", 10, "left", "center", true)
        local key = set.key
        UI.addClick(chx, chy, chipW, chipH, function() panel.weaponKey = key end, "duel:chip:" .. key)
    end

    -- Coluna 3: rodadas, resumo, enviar, pedidos
    local c3x = c2x + c2w + s(30)
    local c3w = f.cx + f.cw - c3x
    UI.text("PRIMEIRO A", c3x, top, c3w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local segW = (c3w - s(16)) / 3
    for i, n in ipairs({ 1, 3, 5 }) do
        local bx, by = c3x + (i - 1) * (segW + s(8)), top + s(22)
        local sel = panel.rounds == n
        local t = UI.hover("duel:rounds:" .. n, UI.isMouseIn(bx, by, segW, s(40)))
        local c = UI.palette.gold
        UI.rrect(bx, by, segW, s(40), sel and tocolor(c[1], c[2], c[3], 50 * a) or tocolor(255, 255, 255, (7 + 12 * t) * a), s(10), { border = 1, borderColor = sel and tocolor(c[1], c[2], c[3], 220 * a) or tocolor(255, 255, 255, (18 + 40 * t) * a), glow = sel and s(10) or 0, glowColor = tocolor(c[1], c[2], c[3], 70 * a) })
        UI.text(tostring(n), bx, by, segW, s(40), sel and UI.color("gold", 255 * a) or UI.color("text", 255 * a), "bold", 14, "center", "center")
        UI.addClick(bx, by, segW, s(40), function() panel.rounds = n end, "duel:rounds:" .. n)
    end
    local sy = top + s(78)
    UI.glass(c3x, sy, c3w, s(96), s(12), a)
    local setSel
    for _, st in ipairs(sets()) do if st.key == panel.weaponKey then setSel = st end end
    local target = panel.selected and isElement(panel.selected) and nick(panel.selected) or "—"
    UI.text("RESUMO", c3x + s(14), sy + s(10), c3w, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
    UI.text(("Você  vs  %s"):format(target), c3x + s(14), sy + s(28), c3w - s(28), s(24), UI.color("text", 255 * a), "bold", 13, "left", "center", true)
    UI.text(("%s   ·   primeiro a %d"):format(setSel and setSel.name or "?", panel.rounds), c3x + s(14), sy + s(56), c3w - s(28), s(22), UI.color("muted", 255 * a), "regular", 11, "left", "center", true)
    local canSend = panel.selected and isElement(panel.selected) and not outgoing and not duel
    local by = sy + s(110)
    UI.button("duel_send", outgoing and "AGUARDANDO RESPOSTA..." or "ENVIAR DESAFIO", c3x, by, c3w, s(44), { kind = "primary", size = 11, alpha = a, disabled = not canSend, icon = "swords.png",
        onClick = function() triggerServerEvent("duel:request", localPlayer, panel.selected, panel.weaponKey, panel.rounds) end })
    if outgoing then
        local remaining = math.max(0, (outgoing.expires - getTickCount()) / 1000)
        UI.ring(c3x + s(10), by + s(58), s(7), s(3), remaining / (outgoing.ttl / 1000), UI.color("warn", 255 * a), tocolor(255, 255, 255, 25 * a))
        UI.text(("%s · %s · %ds"):format(outgoing.target, outgoing.weapon, math.ceil(remaining)), c3x + s(24), by + s(48), c3w - s(110), s(20), UI.color("muted", 255 * a), "regular", 9, "left", "center", true)
        local oid = outgoing.id
        UI.button("duel_cancel", "Cancelar", c3x + c3w - s(84), by + s(47), s(84), s(22), { kind = "ghost", size = 9, alpha = a, onClick = function() triggerServerEvent("duel:cancel", localPlayer, oid) end })
    end
    local iy = by + s(84)
    UI.text(("PEDIDOS RECEBIDOS (%d)"):format(#incoming), c3x, iy, c3w, s(16), UI.color("gold", 255 * a), "semibold", 9, "left", "center")
    iy = iy + s(24)
    if #incoming == 0 then UI.text("Nenhum pedido no momento.", c3x, iy, c3w, s(30), UI.color("muted", 180 * a), "regular", 10, "left", "center") end
    for i, req in ipairs(incoming) do
        if i > 2 then break end
        local rh = s(64)
        local p = UI.stagger(a, i, 2, 0.3)
        local c = UI.palette.gold
        UI.rrect(c3x, iy, c3w, rh, tocolor(c[1], c[2], c[3], 22 * a * p), s(10), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 120 * a * p), glow = s(8), glowColor = tocolor(c[1], c[2], c[3], 50 * a * p) })
        UI.text(req.from, c3x + s(12), iy + s(6), c3w - s(24), s(18), UI.color("text", 255 * a * p), "semibold", 11, "left", "center", true)
        UI.text(("%s · primeiro a %d"):format(req.weapon, req.rounds), c3x + s(12), iy + s(24), c3w - s(24), s(14), UI.color("muted", 255 * a * p), "regular", 9, "left", "center", true)
        local bw = (c3w - s(24) - s(8)) / 2
        local rid = req.id
        UI.button("duel_acc" .. rid, "Aceitar", c3x + s(12), iy + s(40), bw, s(18), { kind = "primary", size = 8, alpha = a * p, radius = s(6), onClick = function() triggerServerEvent("duel:respond", localPlayer, rid, true) end })
        UI.button("duel_dec" .. rid, "Recusar", c3x + s(12) + bw + s(8), iy + s(40), bw, s(18), { kind = "outline", color = "danger", size = 8, alpha = a * p, radius = s(6), onClick = function() triggerServerEvent("duel:respond", localPlayer, rid, false) end })
        iy = iy + rh + s(8)
    end
    UI.panelFooter(f, "F3 ou ESC fecha   ·   /duelo <jogador>   ·   Y aceita · N recusa")
    UI.endFrame()
end

local function onClick(button, state)
    if panel.open then UI.processClick(button, state) end
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

function openDuelPanel(target)
    if panel.open then
        if isElement(target) then panel.selected = target end
        return
    end
    if not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    if isElement(target) then panel.selected = target end
    search.text = ""
    if not panel.rendering then panel.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    addEventHandler("onClientKey", root, onWheel)
    inputState = UI.bindInputs({ search })
    UI.sound("click", 0.4)
end

function closeDuelPanel()
    if not panel.open then return end
    panel.open = false
    panel.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
    removeEventHandler("onClientKey", root, onWheel)
    UI.unbindInputs(inputState)
    inputState = nil
end

bindKey("F3", "down", function() if panel.open then closeDuelPanel() else openDuelPanel() end end)
UI.registerEscape(PANEL, closeDuelPanel)

addEvent("duel:openPanel", true)
addEventHandler("duel:openPanel", root, function(target) openDuelPanel(target or nil) end)

-- ---------------- Pedidos ----------------
addEvent("duel:incoming", true)
addEventHandler("duel:incoming", root, function(id, fromName, weaponName, rounds, ttl, fromPlayer)
    for i = #incoming, 1, -1 do if incoming[i].player == fromPlayer then table.remove(incoming, i) end end
    incoming[#incoming + 1] = { id = id, from = fromName, weapon = weaponName, rounds = rounds, ttl = ttl, expires = getTickCount() + ttl, player = fromPlayer, tick = getTickCount() }
    UI.sound("notify", 0.6)
end)
addEvent("duel:requestRemoved", true)
addEventHandler("duel:requestRemoved", root, function(id)
    for i = #incoming, 1, -1 do if incoming[i].id == id then table.remove(incoming, i) end end
end)
addEvent("duel:outgoing", true)
addEventHandler("duel:outgoing", root, function(id, targetName, weaponName, rounds, ttl)
    outgoing = { id = id, target = targetName, weapon = weaponName, rounds = rounds, ttl = ttl, expires = getTickCount() + ttl }
end)
addEvent("duel:outgoingRemoved", true)
addEventHandler("duel:outgoingRemoved", root, function(id)
    if outgoing and outgoing.id == id then outgoing = nil end
end)

bindKey("y", "down", function() if incoming[1] and not duel then triggerServerEvent("duel:respond", localPlayer, incoming[1].id, true) end end)
bindKey("n", "down", function() if incoming[1] and not duel then triggerServerEvent("duel:respond", localPlayer, incoming[1].id, false) end end)

-- Popup de pedido (painel fechado)
addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    for i = #incoming, 1, -1 do if incoming[i].expires <= now then table.remove(incoming, i) end end
    if outgoing and outgoing.expires <= now then outgoing = nil end
    if panel.open or duel or #incoming == 0 then return end
    local req = incoming[1]
    local age = now - req.tick
    local p = UI.ease(math.min(1, age / 400), "outBack")
    local w, h = s(400), s(118)
    local x, y = (UI.sw - w) / 2, s(96) - (1 - p) * s(30)
    local c = UI.palette.gold
    UI.rrect(x, y, w, h, UI.color("card", 236 * p), s(14), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 140 * p), glow = s(16) * UI.pulse(1200, 0.7, 1), glowColor = tocolor(c[1], c[2], c[3], 90 * p), gradient = UI.color("card2", 236 * p), gradientMode = 3 })
    UI.ring(x + s(34), y + h / 2, s(20), s(4), (req.expires - now) / req.ttl, tocolor(c[1], c[2], c[3], 255 * p), tocolor(255, 255, 255, 20 * p))
    UI.image("swords.png", x + s(22), y + h / 2 - s(12), s(24), s(24), tocolor(255, 255, 255, 255 * p))
    UI.text("DESAFIO DE DUELO", x + s(70), y + s(12), w, s(16), tocolor(c[1], c[2], c[3], 255 * p), "semibold", 9, "left", "center")
    UI.text(req.from, x + s(70), y + s(28), w - s(90), s(22), UI.color("text", 255 * p), "bold", 14, "left", "center", true)
    UI.text(("%s   ·   primeiro a %d"):format(req.weapon, req.rounds), x + s(70), y + s(50), w - s(90), s(16), UI.color("muted", 255 * p), "regular", 10, "left", "center", true)
    local bw = s(140)
    UI.rrect(x + s(70), y + s(76), bw, s(28), tocolor(c[1], c[2], c[3], 230 * p), s(8), { glow = s(6), glowColor = tocolor(c[1], c[2], c[3], 100 * p) })
    UI.text("ACEITAR  [Y]", x + s(70), y + s(76), bw, s(28), tocolor(12, 18, 14, 255 * p), "bold", 10, "center", "center")
    UI.rrect(x + s(70) + bw + s(10), y + s(76), bw, s(28), tocolor(255, 255, 255, 18 * p), s(8), { border = 1, borderColor = tocolor(255, 255, 255, 40 * p) })
    UI.text("RECUSAR  [N]", x + s(70) + bw + s(10), y + s(76), bw, s(28), UI.color("text", 255 * p), "bold", 10, "center", "center")
    if #incoming > 1 then UI.text(("+%d"):format(#incoming - 1), x, y, w - s(14), s(30), UI.color("muted", 255 * p), "regular", 9, "right", "center") end
end)

-- ---------------- Duelo em andamento ----------------
addEvent("duel:start", true)
addEventHandler("duel:start", root, function(opponentName, weaponName, target, opponent)
    duel = { opponent = opponentName, opponentEl = opponent, weapon = weaponName, target = target, me = 0, opp = 0, round = 0, state = "countdown", countdownEnd = 0 }
    result = nil
    incoming = {}
    outgoing = nil
    closeDuelPanel()
end)
addEvent("duel:round", true)
addEventHandler("duel:round", root, function(scoreMe, scoreOpp, round, seconds)
    if not duel then return end
    duel.me, duel.opp, duel.round = scoreMe, scoreOpp, round
    duel.state = "countdown"
    duel.countdownEnd = getTickCount() + seconds * 1000
    duel.lastTick = nil
end)
addEvent("duel:fight", true)
addEventHandler("duel:fight", root, function(scoreMe, scoreOpp)
    if not duel then return end
    duel.state = "fight"
    duel.fightTick = getTickCount()
    UI.sound("go", 0.8)
end)
addEvent("duel:score", true)
addEventHandler("duel:score", root, function(scoreMe, scoreOpp, lastKiller)
    if not duel then return end
    duel.me, duel.opp = scoreMe, scoreOpp
    duel.state = "between"
    duel.betweenTick = getTickCount()
end)
addEvent("duel:end", true)
addEventHandler("duel:end", root, function(won, scoreMe, scoreOpp, rpDelta, reason, money)
    result = { won = won, me = scoreMe, opp = scoreOpp, rp = rpDelta or 0, money = money or 0, reason = reason, tick = getTickCount(), opponent = duel and duel.opponent or "?" }
    duel = nil
    UI.sound(won and "win" or "lose", 0.7)
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    if duel then
        local w, h = s(440), s(72)
        local x, y = (UI.sw - w) / 2, s(84)
        UI.rrect(x, y, w, h, UI.color("card", 215), s(14), { border = 1, borderColor = tocolor(255, 255, 255, 24), glow = s(14), glowColor = UI.color("accent", 50), gradient = UI.color("card2", 215), gradientMode = 3 })
        UI.text(UI.truncate(nick(localPlayer), "semibold", 11, s(150)), x + s(16), y + s(8), s(150), s(20), UI.color("accent2"), "semibold", 11, "left", "center")
        UI.text(UI.truncate(duel.opponent, "semibold", 11, s(150)), x + w - s(166), y + s(8), s(150), s(20), UI.color("danger"), "semibold", 11, "right", "center")
        local me = math.floor(UI.counter("duel:me", duel.me, 500) + 0.5)
        local op = math.floor(UI.counter("duel:opp", duel.opp, 500) + 0.5)
        UI.textGlow(tostring(me), x + s(16), y + s(28), s(150), s(36), UI.color("text"), UI.color("accent", 120), "bold", 26, "left", "center")
        UI.textGlow(tostring(op), x + w - s(166), y + s(28), s(150), s(36), UI.color("text"), UI.color("danger", 120), "bold", 26, "right", "center")
        UI.text(("RODADA %d"):format(duel.round), x, y + s(10), w, s(18), UI.color("muted"), "semibold", 9, "center", "center")
        UI.text(("%s · primeiro a %d"):format(duel.weapon, duel.target), x, y + s(32), w, s(24), UI.color("text", 220), "medium", 10, "center", "center")
        if duel.state == "countdown" then
            local remaining = duel.countdownEnd - now
            if remaining > 0 then
                local sec = math.ceil(remaining / 1000)
                if duel.lastTick ~= sec then duel.lastTick = sec UI.sound("tick", 0.6) end
                local frac = (remaining % 1000) / 1000
                local scale = 1 + (1 - UI.ease(1 - frac, "outCubic")) * 0.35
                local size = s(140) * scale
                UI.ring(UI.sw / 2, UI.sh / 2 - s(40), s(70), s(5), frac, UI.color("accent"), tocolor(255, 255, 255, 18))
                UI.textGlow(tostring(sec), UI.sw / 2 - size / 2, UI.sh / 2 - s(40) - size / 2, size, size, UI.color("accent2"), UI.color("accent", 160), "bold", math.floor(64 * scale), "center", "center")
                UI.textShadow("PREPARE-SE", 0, UI.sh / 2 + s(44), UI.sw, s(24), tocolor(255, 255, 255, 220), "semibold", 14, "center", "center")
            end
        elseif duel.state == "fight" and duel.fightTick and now - duel.fightTick < 900 then
            local t = (now - duel.fightTick) / 900
            local a = 1 - UI.ease(t, "inQuad")
            local scale = 1 + UI.ease(t, "outCubic") * 0.6
            UI.textGlow("LUTE!", 0, UI.sh / 2 - s(90) * scale, UI.sw, s(100) * scale, UI.color("danger", 255 * a), UI.color("danger", 180 * a), "bold", math.floor(60 * scale), "center", "center")
        elseif duel.state == "between" then
            local a = duel.betweenTick and math.min(1, (now - duel.betweenTick) / 250) or 1
            UI.textGlow(("%d  x  %d"):format(duel.me, duel.opp), 0, UI.sh / 2 - s(90), UI.sw, s(60), tocolor(255, 255, 255, 230 * a), UI.color("accent", 120 * a), "bold", 34, "center", "center")
        end
    end
    if result then
        local age = now - result.tick
        if age > 4500 then
            result = nil
        else
            local a = age < 300 and UI.ease(age / 300, "outBack") or (age > 4000 and math.max(0, (4500 - age) / 500) or 1)
            local w, h = s(480), s(210)
            local x, y = (UI.sw - w) / 2, UI.sh / 2 - h / 2 - s(40)
            UI.backdrop(math.min(1, a) * 0.7, 90)
            local col = result.won and "success" or "danger"
            UI.card(x, y, w, h, s(18), math.min(1, a), col, { glow = s(30) })
            UI.textGlow(result.won and "VITÓRIA" or "DERROTA", x, y + s(30), w, s(50), UI.color(col, 255 * a), UI.color(col, 170 * a), "bold", 36, "center", "center")
            UI.text(("%d  x  %d   contra %s"):format(result.me, result.opp, result.opponent), x, y + s(88), w, s(26), UI.color("text", 255 * a), "semibold", 14, "center", "center")
            local sub
            if result.reason == "forfeit" then sub = result.won and "O oponente abandonou o duelo (W.O.)" or "Você abandonou o duelo"
            elseif result.won then sub = ("+%d RP   ·   +$%d"):format(result.rp, result.money)
            else sub = ("%d RP · mais sorte na próxima!"):format(result.rp) end
            UI.text(sub, x, y + s(120), w, s(24), UI.color(result.won and "gold" or "muted", 255 * a), "medium", 12, "center", "center")
            UI.text("Voltando para a arena...", x, y + h - s(40), w, s(20), UI.color("muted", 200 * a), "regular", 10, "center", "center")
        end
    end
end)
