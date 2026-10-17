--[[
    Duelo X1 — cliente: painel (F3), pedidos recebidos/enviados, HUD do duelo e resultado.
]]

local core = exports.dm_core
local PANEL = "duel"
local panel = { open = false, tick = 0, selected = nil, weaponKey = "deagle", rounds = 3, scroll = 0 }
local search = { text = "", placeholder = "Buscar jogador...", maxLength = 20 }
local inputState
local incoming = {}      -- lista de pedidos recebidos { id, from, weapon, rounds, expires, player }
local outgoing = nil     -- pedido enviado { id, target, weapon, rounds, expires }
local duel = nil         -- estado do duelo atual
local result = nil       -- resultado final
local weaponSets

local function sets()
    if not weaponSets then weaponSets = core:getDuelWeaponSets() end
    return weaponSets
end

local function s(v) return UI.s(v) end
local function sound(n, v) core:playUISound(n, v) end
UI.sound = sound
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end

-- ---------------- Painel ----------------

local function playerList()
    local list = {}
    local q = search.text:lower()
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer and getElementData(p, "dm:ready") then
            local name = nick(p)
            if q == "" or name:lower():find(q, 1, true) then
                list[#list + 1] = { player = p, name = name, level = tonumber(getElementData(p, "dm:level")) or 1, inDuel = getElementData(p, "dm:inDuel") }
            end
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

local function layout()
    local w, h = s(940), s(580)
    return (UI.sw - w) / 2, (UI.sh - h) / 2, w, h
end

local clicks = {}

local function render()
    local progress = UI.openProgress(panel)
    if progress <= 0 then
        if not panel.open then removeEventHandler("onClientRender", root, render) end
        return
    end
    local a = progress
    local x, y, w, h = layout()
    y = y + (1 - a) * s(20)
    local pad = s(28)
    clicks = {}

    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 7, 12, 160 * a))
    UI.card(x, y, w, h, s(20), a)

    UI.text("DUELO X1", x + pad, y + pad - s(4), w, s(30), UI.color("text", 255 * a), "bold", 24, "left", "center")
    UI.text("Desafie um jogador para um 1v1 em sala privada. O vencedor ganha XP.", x + pad, y + pad + s(28), w, s(20), UI.color("muted", 255 * a), "regular", 11, "left", "center")
    local cx, cy = x + w - pad - s(32), y + pad - s(6)
    UI.button("duel_close", "×", cx, cy, s(32), s(32), { kind = "ghost", size = 14, alpha = a })
    clicks[#clicks + 1] = { cx, cy, s(32), s(32), function() closeDuelPanel() end }

    local top = y + pad + s(66)
    local colH = h - (top - y) - pad
    -- ---------- Coluna 1: jogadores ----------
    local c1x, c1w = x + pad, s(280)
    UI.text("JOGADORES", c1x, top, c1w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    UI.inputField(search, c1x, top + s(24), c1w, s(36), { size = 11 })
    local listY = top + s(70)
    local rowH = s(40)
    local listH = colH - s(70)
    local list = playerList()
    local maxRows = math.floor(listH / rowH)
    panel.scroll = UI.clamp(panel.scroll, 0, math.max(0, #list - maxRows))
    panel.listBounds = { c1x, listY, c1w, listH }
    if #list == 0 then
        UI.text(search.text ~= "" and "Nenhum jogador encontrado." or "Nenhum outro jogador online.", c1x, listY, c1w, s(60), UI.color("muted", 200 * a), "regular", 11, "center", "center", false, true)
    end
    for i = panel.scroll + 1, math.min(#list, panel.scroll + maxRows) do
        local r = list[i]
        local ry = listY + (i - panel.scroll - 1) * rowH
        local hover = UI.isMouseIn(c1x, ry, c1w, rowH - s(4))
        local sel = panel.selected == r.player
        UI.rect(c1x, ry, c1w, rowH - s(4), sel and UI.color("accent2", 60 * a) or tocolor(255, 255, 255, (hover and 14 or 6) * a), s(8))
        if sel then UI.border(c1x, ry, c1w, rowH - s(4), UI.color("accent2", 200 * a), s(8)) end
        UI.pill(tostring(r.level), c1x + s(10), ry + (rowH - s(4) - s(18)) / 2, s(18), tocolor(255, 255, 255, 18 * a), UI.color("text", 255 * a), "bold", 8, s(7))
        UI.text(UI.truncate(r.name, "medium", 11, c1w - s(110)), c1x + s(44), ry, c1w - s(100), rowH - s(4), UI.color("text", 255 * a), "medium", 11, "left", "center")
        if r.inDuel then
            UI.text("EM DUELO", c1x, ry, c1w - s(12), rowH - s(4), UI.color("danger", 255 * a), "semibold", 8, "right", "center")
        end
        local pl = r.player
        clicks[#clicks + 1] = { c1x, ry, c1w, rowH - s(4), function()
            panel.selected = pl
            sound("click", 0.4)
        end }
    end
    if #list > maxRows then
        local barH = listH * (maxRows / #list)
        local barY = listY + (listH - barH) * (panel.scroll / (#list - maxRows))
        UI.rect(c1x + c1w + s(6), barY, s(3), barH, tocolor(255, 255, 255, 60 * a), 1)
    end

    -- ---------- Coluna 2: armas ----------
    local c2x, c2w = c1x + c1w + s(32), s(300)
    UI.text("ARMA", c2x, top, c2w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local chipW, chipH, gap = (c2w - s(10)) / 2, s(44), s(10)
    for i, set in ipairs(sets()) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local chx = c2x + col * (chipW + gap)
        local chy = top + s(24) + row * (chipH + gap)
        local hover = UI.isMouseIn(chx, chy, chipW, chipH)
        local sel = panel.weaponKey == set.key
        UI.rect(chx, chy, chipW, chipH, sel and UI.color("accent", 40 * a) or tocolor(255, 255, 255, (hover and 16 or 7) * a), s(10))
        UI.border(chx, chy, chipW, chipH, sel and UI.color("accent", 220 * a) or tocolor(255, 255, 255, 18 * a), s(10))
        UI.text(set.name, chx + s(12), chy, chipW - s(24), chipH, sel and UI.color("accent", 255 * a) or UI.color("text", 255 * a), "semibold", 10, "left", "center", true)
        local key = set.key
        clicks[#clicks + 1] = { chx, chy, chipW, chipH, function() panel.weaponKey = key sound("click", 0.4) end }
    end

    -- ---------- Coluna 3: configuração / pedidos ----------
    local c3x = c2x + c2w + s(32)
    local c3w = x + w - pad - c3x
    UI.text("RODADAS (PRIMEIRO A)", c3x, top, c3w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local rb = (c3w - s(16)) / 3
    for i, n in ipairs({ 1, 3, 5 }) do
        local bx = c3x + (i - 1) * (rb + s(8))
        local by = top + s(24)
        local sel = panel.rounds == n
        UI.rect(bx, by, rb, s(40), sel and UI.color("accent2", 70 * a) or tocolor(255, 255, 255, (UI.isMouseIn(bx, by, rb, s(40)) and 16 or 7) * a), s(10))
        UI.border(bx, by, rb, s(40), sel and UI.color("accent2", 220 * a) or tocolor(255, 255, 255, 18 * a), s(10))
        UI.text(tostring(n), bx, by, rb, s(40), UI.color("text", 255 * a), "bold", 14, "center", "center")
        clicks[#clicks + 1] = { bx, by, rb, s(40), function() panel.rounds = n sound("click", 0.4) end }
    end

    -- Resumo
    local sy = top + s(84)
    UI.rect(c3x, sy, c3w, s(96), tocolor(255, 255, 255, 6 * a), s(12))
    UI.border(c3x, sy, c3w, s(96), tocolor(255, 255, 255, 14 * a), s(12))
    local setSel
    for _, st in ipairs(sets()) do if st.key == panel.weaponKey then setSel = st end end
    local target = panel.selected and isElement(panel.selected) and nick(panel.selected) or "—"
    UI.text("RESUMO", c3x + s(14), sy + s(10), c3w, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
    UI.text(("Você  vs  %s"):format(target), c3x + s(14), sy + s(28), c3w - s(28), s(22), UI.color("text", 255 * a), "semibold", 12, "left", "center", true)
    UI.text(("%s  ·  Primeiro a %d"):format(setSel and setSel.name or "?", panel.rounds), c3x + s(14), sy + s(54), c3w - s(28), s(22), UI.color("muted", 255 * a), "regular", 11, "left", "center", true)

    -- Enviar
    local canSend = panel.selected and isElement(panel.selected) and not outgoing and not duel
    local by = sy + s(110)
    UI.button("duel_send", outgoing and "AGUARDANDO RESPOSTA..." or "ENVIAR DESAFIO", c3x, by, c3w, s(44), { kind = "primary", size = 11, alpha = a, disabled = not canSend })
    if canSend then
        clicks[#clicks + 1] = { c3x, by, c3w, s(44), function()
            triggerServerEvent("duel:request", localPlayer, panel.selected, panel.weaponKey, panel.rounds)
            sound("click", 0.5)
        end }
    end
    if outgoing then
        local remaining = math.max(0, (outgoing.expires - getTickCount()) / 1000)
        UI.text(("Desafio para %s · %s · %ds"):format(outgoing.target, outgoing.weapon, math.ceil(remaining)), c3x, by + s(48), c3w - s(90), s(18), UI.color("muted", 255 * a), "regular", 9, "left", "center", true)
        UI.button("duel_cancel", "Cancelar", c3x + c3w - s(84), by + s(46), s(84), s(22), { kind = "ghost", size = 9, alpha = a })
        local oid = outgoing.id
        clicks[#clicks + 1] = { c3x + c3w - s(84), by + s(46), s(84), s(22), function() triggerServerEvent("duel:cancel", localPlayer, oid) end }
    end

    -- Pedidos recebidos
    local iy = by + s(84)
    UI.text(("PEDIDOS RECEBIDOS (%d)"):format(#incoming), c3x, iy, c3w, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    iy = iy + s(24)
    if #incoming == 0 then
        UI.text("Nenhum pedido no momento.", c3x, iy, c3w, s(30), UI.color("muted", 180 * a), "regular", 10, "left", "center")
    end
    for i, req in ipairs(incoming) do
        if i > 3 then break end
        local rh = s(64)
        UI.rect(c3x, iy, c3w, rh, UI.color("accent2", 24 * a), s(10))
        UI.border(c3x, iy, c3w, rh, UI.color("accent2", 120 * a), s(10))
        UI.text(req.from, c3x + s(12), iy + s(6), c3w - s(24), s(18), UI.color("text", 255 * a), "semibold", 11, "left", "center", true)
        UI.text(("%s · primeiro a %d"):format(req.weapon, req.rounds), c3x + s(12), iy + s(24), c3w - s(24), s(14), UI.color("muted", 255 * a), "regular", 9, "left", "center", true)
        local bw = (c3w - s(24) - s(8)) / 2
        UI.button("duel_acc" .. req.id, "Aceitar", c3x + s(12), iy + s(40), bw, s(18), { kind = "primary", size = 8, alpha = a, radius = s(6) })
        UI.button("duel_dec" .. req.id, "Recusar", c3x + s(12) + bw + s(8), iy + s(40), bw, s(18), { kind = "outline", size = 8, alpha = a, radius = s(6) })
        local rid = req.id
        clicks[#clicks + 1] = { c3x + s(12), iy + s(40), bw, s(18), function() triggerServerEvent("duel:respond", localPlayer, rid, true) end }
        clicks[#clicks + 1] = { c3x + s(12) + bw + s(8), iy + s(40), bw, s(18), function() triggerServerEvent("duel:respond", localPlayer, rid, false) end }
        iy = iy + rh + s(8)
    end

    UI.text("F3 ou ESC para fechar  ·  /duelo <jogador>  ·  Y aceita · N recusa", x + pad, y + h - s(30), w - pad * 2, s(20), UI.color("muted", 180 * a), "regular", 9, "left", "center")
end

local function onClick(button, state)
    if button ~= "left" or state ~= "down" or not panel.open then return end
    for _, c in ipairs(clicks) do
        if UI.isMouseIn(c[1], c[2], c[3], c[4]) then
            c[5]()
            return
        end
    end
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
    addEventHandler("onClientRender", root, render)
    addEventHandler("onClientClick", root, onClick)
    addEventHandler("onClientKey", root, onWheel)
    inputState = UI.bindInputs({ search })
    sound("click", 0.4)
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

bindKey("F3", "down", function()
    if panel.open then closeDuelPanel() else openDuelPanel() end
end)
UI.registerEscape(PANEL, closeDuelPanel)

addEvent("duel:openPanel", true)
addEventHandler("duel:openPanel", root, function(target)
    openDuelPanel(target or nil)
end)

-- ---------------- Pedidos ----------------

addEvent("duel:incoming", true)
addEventHandler("duel:incoming", root, function(id, fromName, weaponName, rounds, ttl, fromPlayer)
    -- substitui pedido anterior do mesmo jogador
    for i = #incoming, 1, -1 do
        if incoming[i].player == fromPlayer then table.remove(incoming, i) end
    end
    incoming[#incoming + 1] = { id = id, from = fromName, weapon = weaponName, rounds = rounds, expires = getTickCount() + ttl, player = fromPlayer }
    sound("notify", 0.6)
end)

addEvent("duel:requestRemoved", true)
addEventHandler("duel:requestRemoved", root, function(id)
    for i = #incoming, 1, -1 do
        if incoming[i].id == id then table.remove(incoming, i) end
    end
end)

addEvent("duel:outgoing", true)
addEventHandler("duel:outgoing", root, function(id, targetName, weaponName, rounds, ttl)
    outgoing = { id = id, target = targetName, weapon = weaponName, rounds = rounds, expires = getTickCount() + ttl }
end)

addEvent("duel:outgoingRemoved", true)
addEventHandler("duel:outgoingRemoved", root, function(id)
    if outgoing and outgoing.id == id then outgoing = nil end
end)

bindKey("y", "down", function()
    if incoming[1] and not duel then triggerServerEvent("duel:respond", localPlayer, incoming[1].id, true) end
end)
bindKey("n", "down", function()
    if incoming[1] and not duel then triggerServerEvent("duel:respond", localPlayer, incoming[1].id, false) end
end)

-- Popup de pedido (quando o painel está fechado)
addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    for i = #incoming, 1, -1 do
        if incoming[i].expires <= now then table.remove(incoming, i) end
    end
    if outgoing and outgoing.expires <= now then outgoing = nil end
    if panel.open or duel or #incoming == 0 then return end
    local req = incoming[1]
    local w, h = s(380), s(118)
    local x, y = (UI.sw - w) / 2, s(96)
    UI.card(x, y, w, h, s(14))
    UI.rect(x, y + s(14), s(5), h - s(28), UI.color("accent2"), s(3))
    UI.text("DESAFIO DE DUELO", x + s(22), y + s(12), w, s(16), UI.color("accent2"), "semibold", 9, "left", "center")
    UI.text(req.from, x + s(22), y + s(28), w - s(44), s(22), UI.color("text"), "bold", 14, "left", "center", true)
    UI.text(("%s  ·  Primeiro a %d"):format(req.weapon, req.rounds), x + s(22), y + s(50), w - s(44), s(16), UI.color("muted"), "regular", 10, "left", "center", true)
    local bw = s(150)
    UI.rect(x + s(22), y + s(74), bw, s(28), UI.color("accent", 230), s(8))
    UI.text("ACEITAR  [Y]", x + s(22), y + s(74), bw, s(28), tocolor(8, 12, 18), "bold", 10, "center", "center")
    UI.rect(x + s(22) + bw + s(10), y + s(74), bw, s(28), tocolor(255, 255, 255, 18), s(8))
    UI.text("RECUSAR  [N]", x + s(22) + bw + s(10), y + s(74), bw, s(28), UI.color("text"), "bold", 10, "center", "center")
    local total = 25000
    UI.rect(x + s(14), y + h - s(4), (w - s(28)) * UI.clamp((req.expires - now) / total, 0, 1), s(2), UI.color("accent2", 180), 1)
    if #incoming > 1 then
        UI.text(("+%d pedidos"):format(#incoming - 1), x, y, w - s(14), s(30), UI.color("muted"), "regular", 9, "right", "center")
    end
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
    sound("go", 0.7)
end)

addEvent("duel:score", true)
addEventHandler("duel:score", root, function(scoreMe, scoreOpp, lastKiller)
    if not duel then return end
    duel.me, duel.opp = scoreMe, scoreOpp
    duel.state = "between"
end)

addEvent("duel:end", true)
addEventHandler("duel:end", root, function(won, scoreMe, scoreOpp, xp, reason)
    result = { won = won, me = scoreMe, opp = scoreOpp, xp = xp, reason = reason, tick = getTickCount(), opponent = duel and duel.opponent or "?" }
    duel = nil
    sound(won and "win" or "lose", 0.7)
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    if duel then
        -- Placar no topo
        local myName = nick(localPlayer)
        local w, h = s(420), s(64)
        local x, y = (UI.sw - w) / 2, s(84)
        UI.card(x, y, w, h, s(14))
        UI.text(UI.truncate(myName, "semibold", 12, s(140)), x + s(16), y + s(10), s(140), s(22), UI.color("accent"), "semibold", 12, "left", "center")
        UI.text(UI.truncate(duel.opponent, "semibold", 12, s(140)), x + w - s(156), y + s(10), s(140), s(22), UI.color("danger"), "semibold", 12, "right", "center")
        UI.text(("%d"):format(duel.me), x + s(16), y + s(30), s(140), s(26), UI.color("text"), "bold", 20, "left", "center")
        UI.text(("%d"):format(duel.opp), x + w - s(156), y + s(30), s(140), s(26), UI.color("text"), "bold", 20, "right", "center")
        UI.text(("RODADA %d"):format(duel.round), x, y + s(10), w, s(18), UI.color("muted"), "semibold", 9, "center", "center")
        UI.text(("%s · primeiro a %d"):format(duel.weapon, duel.target), x, y + s(30), w, s(24), UI.color("text", 220), "medium", 10, "center", "center")

        -- Contagem
        if duel.state == "countdown" then
            local remaining = duel.countdownEnd - now
            if remaining > 0 then
                local sec = math.ceil(remaining / 1000)
                if duel.lastTick ~= sec then
                    duel.lastTick = sec
                    sound("tick", 0.6)
                end
                local frac = (remaining % 1000) / 1000
                local scale = 1 + (1 - frac) * 0.25
                UI.textShadow(tostring(sec), 0, UI.sh / 2 - s(120) * scale, UI.sw, s(120) * scale, UI.color("accent"), "bold", math.floor(72 * scale), "center", "center")
                UI.textShadow("PREPARE-SE", 0, UI.sh / 2 + s(10), UI.sw, s(24), tocolor(255, 255, 255, 220), "semibold", 14, "center", "center")
            end
        elseif duel.state == "fight" and duel.fightTick and now - duel.fightTick < 900 then
            local a = 1 - (now - duel.fightTick) / 900
            UI.textShadow("LUTE!", 0, UI.sh / 2 - s(80), UI.sw, s(90), UI.color("danger", 255 * a), "bold", 60, "center", "center")
        elseif duel.state == "between" then
            UI.textShadow(("%d  x  %d"):format(duel.me, duel.opp), 0, UI.sh / 2 - s(90), UI.sw, s(60), tocolor(255, 255, 255, 230), "bold", 34, "center", "center")
        end
    end

    if result then
        local age = now - result.tick
        if age > 4500 then
            result = nil
        else
            local a = age < 250 and UI.ease(age / 250) or (age > 4000 and math.max(0, (4500 - age) / 500) or 1)
            local w, h = s(460), s(200)
            local x, y = (UI.sw - w) / 2, UI.sh / 2 - h / 2 - s(40)
            dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 7, 12, 120 * a))
            UI.card(x, y, w, h, s(18), a)
            local col = result.won and "accent" or "danger"
            UI.rect(x + s(24), y + s(24), w - s(48), s(4), UI.color(col, 255 * a), 2)
            UI.text(result.won and "VITÓRIA" or "DERROTA", x, y + s(36), w, s(50), UI.color(col, 255 * a), "bold", 36, "center", "center")
            UI.text(("%d  x  %d   contra %s"):format(result.me, result.opp, result.opponent), x, y + s(90), w, s(26), UI.color("text", 255 * a), "semibold", 14, "center", "center")
            local sub = result.reason == "forfeit" and (result.won and "O oponente abandonou o duelo (W.O.)" or "Você abandonou o duelo") or (result.won and ("+%d XP"):format(result.xp) or "Mais sorte na próxima!")
            UI.text(sub, x, y + s(122), w, s(24), UI.color(result.won and "accent" or "muted", 255 * a), "medium", 12, "center", "center")
            UI.text("Voltando para a arena...", x, y + h - s(40), w, s(20), UI.color("muted", 200 * a), "regular", 10, "center", "center")
        end
    end
end)
