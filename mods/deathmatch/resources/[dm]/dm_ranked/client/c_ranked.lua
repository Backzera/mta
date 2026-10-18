--[[
    Ranqueadas — cliente (UI v2): painel (F5) com cards de modo, HUD de aquecimento/contagem/partida
    com placar animado, resultado em painel de vidro com tabela em cascata.
]]

local core = exports.dm_core
local PANEL = "ranked"
local panel = { open = false, tick = 0, rendering = false }
local MODES
local info = {}
local state = nil
local stateTick = 0
local result = nil
local lastTick

local function s(v) return UI.s(v) end
local function formatMoney(v) return core:formatMoney(v) end
local function modes()
    if not MODES then MODES = core:getRankedModes() end
    return MODES
end
local function weaponList(mode)
    local names = {}
    for _, w in ipairs(mode.weapons or {}) do names[#names + 1] = getWeaponNameFromID(w[1]) or tostring(w[1]) end
    return table.concat(names, " · ")
end
local TEAM_A, TEAM_B = { 34, 230, 138 }, { 255, 181, 71 }

-- ---------------- Painel ----------------
local function render()
    local list = modes()
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = core:getTierForRP(rp)
    local f = UI.panelFrame(panel, {
        w = s(880), h = s(190) + #list * s(122), title = "PARTIDAS RANQUEADAS",
        subtitle = "Times balanceados por elo. Aquecimento até completar. Vitória: +RP e $. Derrota ou abandono: -RP.",
        icon = "trophy.png", accent = "gold", badge = ("%s · %d RP"):format(tier.name:upper(), rp), badgeColor = "gold", onClose = closeRankedPanel,
    })
    if not f then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    local a = f.a
    local ly = f.cy
    for i, mode in ipairs(list) do
        local p = UI.stagger(a, i, #list, 0.5)
        local mh = s(108)
        local y = ly + (1 - p) * s(18)
        local hovering = UI.isMouseIn(f.cx, y, f.cw, mh)
        local t = UI.hover("rk:mode:" .. mode.id, hovering)
        local c = mode.color
        local pa = a * p
        UI.rrect(f.cx, y - s(2) * t, f.cw, mh + s(2) * t, UI.color("card2", (220 + 30 * t) * pa), s(12), {
            border = 1, borderColor = tocolor(255, 255, 255, (20 + 50 * t) * pa), glow = s(4) + s(14) * t, glowColor = tocolor(c[1], c[2], c[3], (40 + 80 * t) * pa),
            gradient = tocolor(c[1], c[2], c[3], (10 + 12 * t) * pa), gradientMode = 3, shine = 0.1,
        })
        UI.rrect(f.cx, y + s(14), s(4), mh - s(28), tocolor(c[1], c[2], c[3], 255 * pa), s(2), { glow = s(6), glowColor = tocolor(c[1], c[2], c[3], 120 * pa) })
        UI.text(mode.name:upper(), f.cx + s(22), y + s(12), s(400), s(24), UI.color("text", 255 * pa), "bold", 16, "left", "center")
        UI.text(("%s   ·   %s   ·   %d jogadores"):format(mode.place, weaponList(mode), mode.teamSize * 2), f.cx + s(22), y + s(38), s(520), s(18), UI.color("muted", 255 * pa), "regular", 10, "left", "center")
        UI.text(("Meta: %d kills ou %d min   ·   colete %d"):format(mode.killTarget, math.floor(mode.duration / 60), mode.armor or 0), f.cx + s(22), y + s(58), s(520), s(16), UI.color("muted", 200 * pa), "regular", 9, "left", "center")
        local mi
        for _, it in ipairs(info) do if it.id == mode.id then mi = it end end
        local need = mode.teamSize * 2
        local waiting = mi and mi.waiting or 0
        local status = mi and ("%d aguardando   ·   %d jogando (%d partida%s)"):format(mi.waiting, mi.playing, mi.matches, mi.matches == 1 and "" or "s") or "—"
        local dot = waiting > 0 and UI.pulse(1200, 0.5, 1) or 0.3
        UI.rrect(f.cx + s(22), y + s(84), s(7), s(7), tocolor(c[1], c[2], c[3], 255 * pa * dot), s(4), { glow = s(5) * dot, glowColor = tocolor(c[1], c[2], c[3], 160 * pa) })
        UI.text(status, f.cx + s(36), y + s(78), s(520), s(18), UI.color("accent2", 230 * pa), "semibold", 9, "left", "center")
        -- aquecimento
        local bx = f.cx + f.cw - s(310)
        UI.text("AQUECIMENTO", bx, y + s(14), s(150), s(14), UI.color("muted", 220 * pa), "semibold", 7, "left", "center")
        UI.bar(bx, y + s(30), s(150), s(8), math.min(1, (waiting % need) / need), tocolor(c[1], c[2], c[3], 230 * pa), tocolor(255, 255, 255, 14 * pa), s(3), { id = "rk:warm:" .. mode.id, glow = true })
        UI.text(("%d / %d"):format(waiting % need, need), bx, y + s(42), s(150), s(16), UI.color("text", 230 * pa), "bold", 10, "left", "center")
        local bw, bh = s(126), s(38)
        local btx, bty = f.cx + f.cw - bw - s(16), y + (mh - bh) / 2
        if getElementData(localPlayer, "dm:arena") == mode.id then
            UI.rrect(btx, bty, bw, bh, tocolor(c[1], c[2], c[3], 36 * pa), s(10), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 140 * pa) })
            UI.text("VOCÊ ESTÁ AQUI", btx, bty, bw, bh, tocolor(c[1], c[2], c[3], 255 * pa), "semibold", 9, "center", "center")
        else
            local id = mode.id
            UI.button("rk_join_" .. id, "ENTRAR", btx, bty, bw, bh, { kind = t > 0.5 and "primary" or "outline", color = "gold", size = 11, alpha = pa,
                onClick = function() triggerServerEvent("ranked:requestJoin", localPlayer, id) closeRankedPanel() end })
        end
        ly = ly + mh + s(14)
    end
    UI.panelFooter(f, "F5 ou ESC fecha   ·   sair de uma partida em andamento (F2) conta como derrota")
    UI.endFrame()
end

local function onClick(button, st)
    if panel.open then UI.processClick(button, st) end
end

function openRankedPanel()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    triggerServerEvent("ranked:requestInfo", localPlayer)
    panel.infoTimer = setTimer(function() if panel.open then triggerServerEvent("ranked:requestInfo", localPlayer) end end, 3000, 0)
    if not panel.rendering then panel.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    UI.sound("click", 0.4)
end

function closeRankedPanel()
    if not panel.open then return end
    panel.open = false
    panel.tick = getTickCount()
    if panel.infoTimer and isTimer(panel.infoTimer) then killTimer(panel.infoTimer) end
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
end

bindKey("F5", "down", function() if panel.open then closeRankedPanel() else openRankedPanel() end end)
UI.registerEscape(PANEL, closeRankedPanel)
addEvent("ranked:openPanel")
addEventHandler("ranked:openPanel", root, function() openRankedPanel() end)

addEvent("ranked:info", true)
addEventHandler("ranked:info", root, function(list) info = list or {} end)

-- ---------------- Estado / HUD ----------------
addEvent("ranked:state", true)
addEventHandler("ranked:state", root, function(st)
    state = st or nil
    stateTick = getTickCount()
end)
addEvent("ranked:start", true)
addEventHandler("ranked:start", root, function(team, teamName)
    UI.sound("go", 0.8)
    core:notify(("Você está no %s. Boa partida!"):format(teamName), "success", "Partida iniciada")
end)
addEvent("ranked:end", true)
addEventHandler("ranked:end", root, function(res)
    result = res
    result.tick = getTickCount()
    UI.sound(res.won and "win" or (res.draw and "notify" or "lose"), 0.8)
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    if state and getElementData(localPlayer, "dm:ready") then
        local secondsLeft = math.max(0, (state.secondsLeft or 0) - math.floor((now - stateTick) / 1000))
        local w, h = s(460), s(74)
        local x, y = (UI.sw - w) / 2, s(84)
        if state.state == "warmup" then
            UI.rrect(x, y, w, h, UI.color("card", 215), s(14), { border = 1, borderColor = tocolor(255, 255, 255, 22), glow = s(12), glowColor = UI.color("accent2", 50), gradient = UI.color("card2", 215), gradientMode = 3 })
            UI.text("AQUECIMENTO", x, y + s(10), w, s(20), UI.color("accent2"), "bold", 12, "center", "center")
            UI.text(("%d / %d jogadores — começa quando completar"):format(state.players, state.needed), x, y + s(32), w, s(18), UI.color("text", 230), "medium", 10, "center", "center")
            UI.bar(x + s(24), y + h - s(14), w - s(48), s(6), state.players / math.max(1, state.needed), UI.color("accent2", 230), tocolor(255, 255, 255, 14), 3, { id = "rk:hud:warm", glow = true })
        elseif state.state == "countdown" then
            UI.rrect(x, y, w, h, UI.color("card", 215), s(14), { border = 1, borderColor = UI.color("gold", 140), glow = s(12) + s(8) * UI.pulse(800, 0, 1), glowColor = UI.color("gold", 80) })
            UI.text("A PARTIDA VAI COMEÇAR", x, y + s(10), w, s(20), UI.color("gold"), "bold", 12, "center", "center")
            UI.text(("%s   vs   %s"):format(state.nameA, state.nameB), x, y + s(34), w, s(18), UI.color("text", 230), "medium", 10, "center", "center")
            local total = 15
            UI.ring(UI.sw / 2, UI.sh / 2 - s(40), s(60), s(5), secondsLeft / total, UI.color("gold"), tocolor(255, 255, 255, 18))
            local pulse = 1 + 0.1 * UI.pulse(1000, 0, 1)
            UI.textGlow(tostring(secondsLeft), UI.sw / 2 - s(80), UI.sh / 2 - s(40) - s(60) * pulse, s(160), s(120) * pulse, UI.color("gold"), UI.color("gold", 150), "bold", math.floor(56 * pulse), "center", "center")
            if lastTick ~= secondsLeft and secondsLeft <= 5 and secondsLeft > 0 then lastTick = secondsLeft UI.sound("tick", 0.5) end
        elseif state.state == "match" then
            UI.rrect(x, y, w, h, UI.color("card", 215), s(14), { border = 1, borderColor = tocolor(255, 255, 255, 22), glow = s(12), glowColor = UI.color("gold", 40), gradient = UI.color("card2", 215), gradientMode = 3 })
            local mine = state.myTeam
            local ca, cb = UI.rgb(TEAM_A), UI.rgb(TEAM_B)
            UI.text(state.nameA, x + s(16), y + s(8), s(170), s(20), ca, "semibold", 11, "left", "center", true)
            UI.text(state.nameB, x + w - s(186), y + s(8), s(170), s(20), cb, "semibold", 11, "right", "center", true)
            local sa = math.floor(UI.counter("rk:scoreA", state.scoreA or 0, 500) + 0.5)
            local sb = math.floor(UI.counter("rk:scoreB", state.scoreB or 0, 500) + 0.5)
            UI.textGlow(tostring(sa), x + s(16), y + s(28), s(170), s(36), UI.color("text"), UI.rgb(TEAM_A, 120), "bold", 26, "left", "center")
            UI.textGlow(tostring(sb), x + w - s(186), y + s(28), s(170), s(36), UI.color("text"), UI.rgb(TEAM_B, 120), "bold", 26, "right", "center")
            UI.text(("%02d:%02d"):format(math.floor(secondsLeft / 60), secondsLeft % 60), x, y + s(8), w, s(22), UI.color("text"), "bold", 14, "center", "center")
            UI.text(("meta %d   ·   você: %d K / %d M"):format(state.killTarget, state.kills or 0, state.deaths or 0), x, y + s(32), w, s(16), UI.color("muted"), "medium", 9, "center", "center")
            if mine then
                local mc = mine == "A" and TEAM_A or TEAM_B
                UI.pill("SEU TIME", mine == "A" and x + s(16) or x + w - s(16) - s(70), y + h - s(22), s(16), UI.rgb(mc, 50), UI.rgb(mc), "bold", 7)
            end
            UI.bar(x + s(24), y + h - s(6), w - s(48), s(3), secondsLeft / math.max(1, state.duration or 600), UI.color("gold", 200), tocolor(255, 255, 255, 12), 1)
        end
    end

    if result then
        local age = now - result.tick
        if age > 10000 then
            result = nil
        else
            local a = age < 350 and UI.ease(age / 350, "outBack") or (age > 9500 and math.max(0, (10000 - age) / 500) or 1)
            local rows = result.results or {}
            table.sort(rows, function(p, q) return (p.kills or 0) > (q.kills or 0) end)
            local n = math.min(10, #rows)
            local w, h = s(640), s(190) + n * s(24) + s(40)
            local x, y = (UI.sw - w) / 2, UI.sh / 2 - h / 2 - s(20)
            local col = result.won and "success" or (result.draw and "gold" or "danger")
            UI.backdrop(math.min(1, a) * 0.8, 110)
            UI.card(x, y, w, h, s(18), math.min(1, a), col, { glow = s(30) })
            local title = result.cancelled and "PARTIDA CANCELADA" or (result.draw and "EMPATE" or (result.won and "VITÓRIA" or "DERROTA"))
            UI.textGlow(title, x, y + s(26), w, s(48), UI.color(col, 255 * a), UI.color(col, 170 * a), "bold", 34, "center", "center")
            UI.text(("%s  %d  x  %d  %s"):format(result.nameA or "A", result.scoreA or 0, result.scoreB or 0, result.nameB or "B"), x, y + s(76), w, s(26), UI.color("text", 255 * a), "semibold", 15, "center", "center")
            local sub = result.cancelled and "Sem alteração de RP" or ("%s%d RP   ·   +%s   ·   %d K / %d M%s"):format(result.rp >= 0 and "+" or "", result.rp, formatMoney(result.money or 0), result.kills or 0, result.deaths or 0, result.mvp ~= "" and ("   ·   MVP: " .. result.mvp) or "")
            UI.text(sub, x, y + s(104), w, s(22), UI.color("muted", 255 * a), "medium", 11, "center", "center")
            UI.divider(x + s(40), y + s(134), w - s(80), 18 * a)
            local ry = y + s(142)
            for i = 1, n do
                local r = rows[i]
                local p = UI.stagger(math.min(1, a), i, n, 0.6)
                local tc = r.team == "A" and UI.rgb(TEAM_A, 255 * a * p) or UI.rgb(TEAM_B, 255 * a * p)
                local ox = (1 - p) * s(20)
                if r.name == result.mvp then UI.image("crown.png", x + s(40) + ox - s(22), ry + s(3), s(16), s(16), UI.color("gold", 255 * a * p)) end
                UI.text(r.name, x + s(40) + ox, ry, s(300), s(22), tc, "medium", 10, "left", "center")
                UI.text(("%d K   %d M   %s%d RP"):format(r.kills or 0, r.deaths or 0, (r.rp or 0) >= 0 and "+" or "", r.rp or 0), x + w - s(300) - ox, ry, s(260), s(22), UI.color("text", 220 * a * p), "medium", 10, "right", "center")
                ry = ry + s(24)
            end
            UI.text("Voltando ao aquecimento...", x, y + h - s(34), w, s(20), UI.color("muted", 200 * a), "regular", 9, "center", "center")
        end
    end
end)
