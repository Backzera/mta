--[[
    Clãs — cliente (F6): criar clã, convites, membros, desafios clã x clã, ranking de clãs.
]]

local core = exports.dm_core
local PANEL = "clans"
local panel = { open = false, tick = 0, tab = "clan", selectedPlayer = nil, selectedClan = nil, modeId = nil, scroll = 0 }
local data = nil
local fName = { text = "", placeholder = "Nome do clã (3-20)", maxLength = 20 }
local fTag = { text = "", placeholder = "TAG (2-5)", maxLength = 5, allowed = "[%w]" }
local inputState
local clicks = {}

local function s(v) return UI.s(v) end
local function sound(n, v) core:playUISound(n, v) end
UI.sound = sound
local function formatMoney(v) return core:formatMoney(v) end
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end

local ROLE = { leader = "LÍDER", officer = "OFICIAL", member = "MEMBRO" }

local function header(x, y, w, a, title, subtitle)
    UI.image("shield.png", x + s(28), y + s(26), s(30), s(30), tocolor(255, 255, 255, 255 * a))
    UI.text(title, x + s(68), y + s(24), w, s(30), UI.color("text", 255 * a), "bold", 24, "left", "center")
    UI.text(subtitle, x + s(28), y + s(56), w - s(56), s(20), UI.color("muted", 255 * a), "regular", 10, "left", "center")
end

local function renderNoClan(x, y, w, h, a)
    local pad = s(28)
    header(x, y, w, a, "CLÃ", ("Crie o seu clã (%s) ou aceite um convite. Clãs disputam clã x clã nos modos ranqueados."):format(formatMoney(data.createCost or 0)))
    -- criar
    local cx, cy = x + pad, y + s(100)
    local cw = s(380)
    UI.text("CRIAR CLÃ", cx, cy, cw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    UI.inputField(fTag, cx, cy + s(24), s(110), s(40), { size = 12 })
    UI.inputField(fName, cx + s(120), cy + s(24), cw - s(120), s(40), { size = 12 })
    local money = tonumber(getElementData(localPlayer, "dm:money")) or 0
    local can = money >= (data.createCost or 0)
    UI.button("clan_create", ("FUNDAR CLÃ · %s"):format(formatMoney(data.createCost or 0)), cx, cy + s(76), cw, s(42), { kind = "primary", size = 11, alpha = a, disabled = not can })
    if can then
        clicks[#clicks + 1] = { cx, cy + s(76), cw, s(42), function()
            triggerServerEvent("clans:create", localPlayer, fName.text, fTag.text)
            sound("click", 0.5)
        end }
    else
        UI.text("Saldo insuficiente — kills, duelos e ranqueadas dão $.", cx, cy + s(122), cw, s(18), UI.color("danger", 220 * a), "regular", 9, "left", "center")
    end
    -- convites
    local iy = cy + s(150)
    UI.text("CONVITES", cx, iy, cw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    if #data.invites == 0 then
        UI.text("Nenhum convite pendente.", cx, iy + s(22), cw, s(20), UI.color("muted", 200 * a), "regular", 10, "left", "center")
    else
        local inv = data.invites[1]
        UI.rect(cx, iy + s(22), cw, s(64), UI.color("accent", 24 * a), s(10))
        UI.border(cx, iy + s(22), cw, s(64), UI.color("accent", 120 * a), s(10))
        UI.text(("[%s] %s"):format(inv.tag, inv.name), cx + s(12), iy + s(28), cw, s(18), UI.color("text", 255 * a), "semibold", 11, "left", "center")
        UI.text("Convidado por " .. inv.from, cx + s(12), iy + s(46), cw, s(14), UI.color("muted", 255 * a), "regular", 9, "left", "center")
        local bw = (cw - s(24) - s(8)) / 2
        UI.button("clan_acc", "Aceitar", cx + s(12), iy + s(62), bw, s(20), { kind = "primary", size = 8, alpha = a, radius = s(6) })
        UI.button("clan_dec", "Recusar", cx + s(12) + bw + s(8), iy + s(62), bw, s(20), { kind = "outline", size = 8, alpha = a, radius = s(6) })
        clicks[#clicks + 1] = { cx + s(12), iy + s(62), bw, s(20), function() triggerServerEvent("clans:respondInvite", localPlayer, true) end }
        clicks[#clicks + 1] = { cx + s(12) + bw + s(8), iy + s(62), bw, s(20), function() triggerServerEvent("clans:respondInvite", localPlayer, false) end }
    end
end

local function renderRanking(x, y, w, h, a, rx, rw)
    UI.text("RANKING DE CLÃS", rx, y + s(100), rw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local ry = y + s(124)
    if #data.clans == 0 then
        UI.text("Nenhum clã ainda. Seja o primeiro!", rx, ry, rw, s(20), UI.color("muted", 200 * a), "regular", 10, "left", "center")
    end
    for i, c in ipairs(data.clans) do
        if i > 10 then break end
        local rh = s(34)
        local sel = panel.selectedClan == c.id
        UI.rect(rx, ry, rw, rh, sel and UI.color("accent2", 40 * a) or tocolor(255, 255, 255, (i % 2 == 0 and 4 or 8) * a), s(6))
        UI.text(("#%d"):format(i), rx + s(8), ry, s(30), rh, UI.color("muted", 255 * a), "bold", 10, "left", "center")
        UI.text(("[%s]"):format(c.tag), rx + s(36), ry, s(60), rh, UI.rgb(c.color, 255 * a), "bold", 11, "left", "center")
        UI.text(UI.truncate(c.name, "medium", 10, rw - s(220)), rx + s(96), ry, rw - s(220), rh, UI.color("text", 255 * a), "medium", 10, "left", "center")
        UI.text(("%d pts · %dV %dD · %d on"):format(c.points, c.wins, c.losses, c.online), rx, ry, rw - s(8), rh, UI.color("muted", 255 * a), "regular", 9, "right", "center")
        local id = c.id
        clicks[#clicks + 1] = { rx, ry, rw, rh, function() panel.selectedClan = id sound("click", 0.3) end }
        ry = ry + rh + s(4)
    end
end

local function renderClan(x, y, w, h, a)
    local pad = s(28)
    local c = data.clan
    header(x, y, w, a, ("[%s]  %s"):format(c.tag, c.name), ("%d pontos  ·  %d vitórias  ·  %d derrotas  ·  você é %s"):format(c.points, c.wins, c.losses, ROLE[c.role] or c.role))
    UI.rect(x + s(28), y + s(82), s(70), s(4), UI.rgb(c.color, 255 * a), 2)

    -- membros
    local mx, my, mw = x + pad, y + s(100), s(330)
    UI.text(("MEMBROS (%d)"):format(#c.members), mx, my, mw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local ry = my + s(24)
    local rowH = s(32)
    local maxRows = math.floor((h - s(100) - s(150)) / rowH)
    panel.scroll = UI.clamp(panel.scroll, 0, math.max(0, #c.members - maxRows))
    panel.listBounds = { mx, ry, mw, maxRows * rowH }
    local isLeader = c.role == "leader"
    local isOfficer = isLeader or c.role == "officer"
    for i = panel.scroll + 1, math.min(#c.members, panel.scroll + maxRows) do
        local m = c.members[i]
        UI.rect(mx, ry, mw, rowH - s(3), tocolor(255, 255, 255, (i % 2 == 0 and 4 or 8) * a), s(6))
        UI.rect(mx + s(8), ry + (rowH - s(3)) / 2 - s(4), s(8), s(8), m.online and UI.color("success", 255 * a) or UI.color("muted", 90 * a), s(4))
        UI.text(m.name, mx + s(22), ry, mw, rowH - s(3), UI.color(m.online and "text" or "muted", 255 * a), "medium", 10, "left", "center")
        local role = ROLE[m.role] or "MEMBRO"
        UI.text(("%s · %d RP"):format(role, m.rp or 0), mx, ry, mw - s(90), rowH - s(3), m.role == "leader" and UI.color("gold", 255 * a) or UI.color("muted", 255 * a), "semibold", 8, "right", "center")
        if isOfficer and m.role ~= "leader" and m.name ~= nick(localPlayer) then
            UI.button("clan_kick_" .. m.name, "×", mx + mw - s(26), ry + s(4), s(22), rowH - s(11), { kind = "ghost", size = 9, alpha = a })
            local n = m.name
            clicks[#clicks + 1] = { mx + mw - s(26), ry + s(4), s(22), rowH - s(11), function() triggerServerEvent("clans:kick", localPlayer, n) end }
            if isLeader and m.online then
                UI.button("clan_prom_" .. m.name, "+", mx + mw - s(52), ry + s(4), s(22), rowH - s(11), { kind = "ghost", size = 9, alpha = a })
                clicks[#clicks + 1] = { mx + mw - s(52), ry + s(4), s(22), rowH - s(11), function() triggerServerEvent("clans:promote", localPlayer, n) end }
            end
        end
        ry = ry + rowH
    end

    -- convidar
    local iy = y + h - s(140)
    UI.text("CONVIDAR", mx, iy, mw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    if isOfficer then
        local list = {}
        for _, p in ipairs(getElementsByType("player")) do
            if p ~= localPlayer and getElementData(p, "dm:ready") and not getElementData(p, "dm:clanTag") then list[#list + 1] = p end
        end
        if not isElement(panel.selectedPlayer) then panel.selectedPlayer = list[1] end
        local name = isElement(panel.selectedPlayer) and nick(panel.selectedPlayer) or "ninguém disponível"
        UI.rect(mx, iy + s(22), mw - s(110), s(34), tocolor(255, 255, 255, 10 * a), s(8))
        UI.text("‹", mx, iy + s(22), s(26), s(34), UI.color("text", 255 * a), "bold", 14, "center", "center")
        UI.text(name, mx + s(26), iy + s(22), mw - s(110) - s(52), s(34), UI.color("text", 255 * a), "medium", 10, "center", "center", true)
        UI.text("›", mx + mw - s(110) - s(26), iy + s(22), s(26), s(34), UI.color("text", 255 * a), "bold", 14, "center", "center")
        local function cycle(dir)
            if #list == 0 then return end
            local idx = 1
            for i, p in ipairs(list) do if p == panel.selectedPlayer then idx = i end end
            idx = ((idx - 1 + dir) % #list) + 1
            panel.selectedPlayer = list[idx]
        end
        clicks[#clicks + 1] = { mx, iy + s(22), s(26), s(34), function() cycle(-1) end }
        clicks[#clicks + 1] = { mx + mw - s(110) - s(26), iy + s(22), s(26), s(34), function() cycle(1) end }
        UI.button("clan_invite", "CONVIDAR", mx + mw - s(100), iy + s(22), s(100), s(34), { kind = "primary", size = 9, alpha = a, disabled = not isElement(panel.selectedPlayer) })
        if isElement(panel.selectedPlayer) then
            local target = panel.selectedPlayer
            clicks[#clicks + 1] = { mx + mw - s(100), iy + s(22), s(100), s(34), function() triggerServerEvent("clans:invite", localPlayer, target) end }
        end
    else
        UI.text("Só líder e oficiais convidam.", mx, iy + s(22), mw, s(20), UI.color("muted", 200 * a), "regular", 9, "left", "center")
    end
    UI.button("clan_leave", c.role == "leader" and "SAIR / PASSAR LIDERANÇA" or "SAIR DO CLÃ", mx, y + h - s(66), mw, s(30), { kind = "outline", size = 9, alpha = a })
    clicks[#clicks + 1] = { mx, y + h - s(66), mw, s(30), function() triggerServerEvent("clans:leave", localPlayer) end }

    -- coluna direita: clã x clã + ranking
    local rx = mx + mw + s(32)
    local rw = x + w - pad - rx
    UI.text("CLÃ x CLÃ", rx, my, rw, s(16), UI.color("gold", 255 * a), "semibold", 9, "left", "center")
    if data.challenge then
        local ch = data.challenge
        UI.rect(rx, my + s(22), rw, s(64), UI.color("gold", 24 * a), s(10))
        UI.border(rx, my + s(22), rw, s(64), UI.color("gold", 140 * a), s(10))
        local modeName = ch.modeId
        for _, m in ipairs(data.modes) do if m.id == ch.modeId then modeName = m.name end end
        UI.text(("[%s] %s desafiou vocês · %s"):format(ch.fromTag, ch.fromName, modeName), rx + s(12), my + s(28), rw - s(24), s(18), UI.color("text", 255 * a), "semibold", 10, "left", "center", true)
        if isOfficer then
            local bw = (rw - s(24) - s(8)) / 2
            UI.button("clan_chacc", "Aceitar", rx + s(12), my + s(56), bw, s(22), { kind = "primary", size = 8, alpha = a, radius = s(6), color = "gold" })
            UI.button("clan_chdec", "Recusar", rx + s(12) + bw + s(8), my + s(56), bw, s(22), { kind = "outline", size = 8, alpha = a, radius = s(6) })
            clicks[#clicks + 1] = { rx + s(12), my + s(56), bw, s(22), function() triggerServerEvent("clans:respondChallenge", localPlayer, true) end }
            clicks[#clicks + 1] = { rx + s(12) + bw + s(8), my + s(56), bw, s(22), function() triggerServerEvent("clans:respondChallenge", localPlayer, false) end }
        else
            UI.text("Aguardando o líder/oficiais responderem.", rx + s(12), my + s(50), rw, s(30), UI.color("muted", 255 * a), "regular", 9, "left", "center")
        end
    else
        -- modo
        local bx = rx
        for _, m in ipairs(data.modes) do
            local bw = UI.textWidth(m.name, "semibold", 9) + s(20)
            local sel = panel.modeId == m.id
            if not panel.modeId then panel.modeId = m.id sel = true end
            UI.rect(bx, my + s(22), bw, s(26), sel and UI.color("gold", 60 * a) or tocolor(255, 255, 255, 10 * a), s(6))
            UI.text(m.name, bx, my + s(22), bw, s(26), sel and UI.color("gold", 255 * a) or UI.color("muted", 255 * a), "semibold", 9, "center", "center")
            local id = m.id
            clicks[#clicks + 1] = { bx, my + s(22), bw, s(26), function() panel.modeId = id sound("click", 0.3) end }
            bx = bx + bw + s(6)
        end
        local target
        for _, cl in ipairs(data.clans) do if cl.id == panel.selectedClan then target = cl end end
        local label = target and (target.id ~= c.id) and ("DESAFIAR [" .. target.tag .. "]") or "SELECIONE UM CLÃ NO RANKING"
        UI.button("clan_challenge", label, rx, my + s(56), rw, s(30), { kind = "primary", size = 9, alpha = a, color = "gold", disabled = not (isOfficer and target and target.id ~= c.id) })
        if isOfficer and target and target.id ~= c.id then
            clicks[#clicks + 1] = { rx, my + s(56), rw, s(30), function() triggerServerEvent("clans:challenge", localPlayer, target.id, panel.modeId) sound("click", 0.5) end }
        end
        UI.text(("Mínimo %d por lado · times = menor clã online · vitória +%d pts"):format(data.minClanMatch or 2, 30), rx, my + s(88), rw, s(14), UI.color("muted", 200 * a), "regular", 8, "left", "center")
    end
    -- cores (líder)
    if isLeader then
        local cxp = rx
        local cy = y + h - s(66)
        UI.text("COR DA TAG", rx, cy - s(18), rw, s(14), UI.color("muted", 255 * a), "semibold", 8, "left", "center")
        local palette = { { 34, 230, 138 }, { 120, 255, 180 }, { 34, 230, 138 }, { 245, 196, 81 }, { 255, 77, 109 }, { 255, 140, 66 }, { 255, 105, 180 }, { 120, 220, 255 } }
        for i, col in ipairs(palette) do
            UI.rect(cxp, cy, s(24), s(24), UI.rgb(col, 255 * a), s(6))
            local idx = i
            clicks[#clicks + 1] = { cxp, cy, s(24), s(24), function() triggerServerEvent("clans:setColor", localPlayer, idx) end }
            cxp = cxp + s(30)
        end
    end
    renderRanking(x, y + s(10), w, h, a, rx, rw)
end

local RENDER_ON = false
local function render()
    local progress = UI.openProgress(panel)
    if progress <= 0 then
        if not panel.open then removeEventHandler("onClientRender", root, render) RENDER_ON = false end
        return
    end
    local a = progress
    clicks = {}
    local w, h = s(900), s(600)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + (1 - a) * s(20)
    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 5, 12, 170 * a))
    UI.card(x, y, w, h, s(16), a)
    local cx, cy = x + w - s(28) - s(32), y + s(22)
    UI.button("clan_close", "×", cx, cy, s(32), s(32), { kind = "ghost", size = 14, alpha = a })
    clicks[#clicks + 1] = { cx, cy, s(32), s(32), function() closeClanPanel() end }
    if not data then
        UI.text("Carregando...", x, y, w, h, UI.color("muted", 255 * a), "medium", 12, "center", "center")
        return
    end
    if data.clan then
        renderClan(x, y, w, h, a)
    else
        renderNoClan(x, y, w, h, a)
        renderRanking(x, y + s(10), w, h, a, x + s(28) + s(380) + s(32), w - s(28) * 2 - s(380) - s(32))
    end
    UI.text("F6 ou ESC fecha  ·  /cla criar <TAG> <nome>", x + s(28), y + h - s(30), w - s(56), s(20), UI.color("muted", 160 * a), "regular", 9, "left", "center")
end

local function onClick(button, st)
    if button ~= "left" or st ~= "down" or not panel.open then return end
    for _, c in ipairs(clicks) do
        if UI.isMouseIn(c[1], c[2], c[3], c[4]) then c[5]() return end
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

function openClanPanel()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    data = nil
    triggerServerEvent("clans:requestInfo", localPlayer)
    if not RENDER_ON then RENDER_ON = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    addEventHandler("onClientKey", root, onWheel)
    inputState = UI.bindInputs({ fTag, fName })
    sound("click", 0.4)
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
