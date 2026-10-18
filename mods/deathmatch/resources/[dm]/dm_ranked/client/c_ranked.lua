--[[
    Ranqueadas — cliente: painel (F5) com os modos, HUD de aquecimento/contagem/partida, resultado.
]]

local core = exports.dm_core
local PANEL = "ranked"
local panel = { open = false, tick = 0 }
local MODES
local info = {}
local state = nil        -- estado da instância atual (false/nil = fora)
local stateTick = 0
local result = nil
local clicks = {}

local function s(v) return UI.s(v) end
local function sound(n, v) core:playUISound(n, v) end
UI.sound = sound
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

-- ---------------- Painel ----------------
local RENDER_ON = false
local function render()
    local progress = UI.openProgress(panel)
    if progress <= 0 then
        if not panel.open then removeEventHandler("onClientRender", root, render) RENDER_ON = false end
        return
    end
    local a = progress
    clicks = {}
    local list = modes()
    local w, h = s(860), s(200) + #list * s(118)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + (1 - a) * s(20)
    local pad = s(28)
    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 5, 12, 170 * a))
    UI.card(x, y, w, h, s(16), a, "gold")
    UI.image("trophy.png", x + pad, y + pad - s(2), s(30), s(30), tocolor(255, 255, 255, 255 * a))
    UI.text("PARTIDAS RANQUEADAS", x + pad + s(40), y + pad - s(4), w, s(30), UI.color("text", 255 * a), "bold", 24, "left", "center")
    UI.text("Times balanceados por elo. Enquanto não completa, você treina no aquecimento. Vitória: +RP e $. Derrota ou abandono: -RP.", x + pad, y + pad + s(28), w - pad * 2, s(20), UI.color("muted", 255 * a), "regular", 10, "left", "center")
    local cx, cy = x + w - pad - s(32), y + pad - s(6)
    UI.button("rk_close", "×", cx, cy, s(32), s(32), { kind = "ghost", size = 14, alpha = a })
    clicks[#clicks + 1] = { cx, cy, s(32), s(32), function() closeRankedPanel() end }

    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = core:getTierForRP(rp)
    local eloTxt = ("SEU ELO: %s · %d RP"):format(tier.name:upper(), rp)
    UI.pill(eloTxt, x + w - pad - UI.textWidth(eloTxt, "bold", 10) - s(28) - s(44), y + pad, s(30), UI.rgb(tier.color, 40 * a), UI.rgb(tier.color, 255 * a), "bold", 10, s(14))

    local ly = y + pad + s(64)
    for _, mode in ipairs(list) do
        local mh = s(104)
        local hover = UI.isMouseIn(x + pad, ly, w - pad * 2, mh)
        UI.rect(x + pad, ly, w - pad * 2, mh, UI.color("card2", (hover and 255 or 225) * a), s(10))
        UI.border(x + pad, ly, w - pad * 2, mh, tocolor(255, 255, 255, (hover and 50 or 20) * a), s(10))
        UI.rect(x + pad, ly + s(14), s(5), mh - s(28), UI.rgb(mode.color, 255 * a), s(2))
        UI.text(mode.name:upper(), x + pad + s(22), ly + s(12), s(400), s(24), UI.color("text", 255 * a), "bold", 16, "left", "center")
        UI.text(("%s  ·  %s  ·  %d jogadores"):format(mode.place, weaponList(mode), mode.teamSize * 2), x + pad + s(22), ly + s(38), s(500), s(18), UI.color("muted", 255 * a), "regular", 10, "left", "center")
        UI.text(("Meta: %d kills ou %d min  ·  colete %d"):format(mode.killTarget, math.floor(mode.duration / 60), mode.armor or 0), x + pad + s(22), ly + s(58), s(500), s(18), UI.color("muted", 200 * a), "regular", 9, "left", "center")
        local mi
        for _, i in ipairs(info) do if i.id == mode.id then mi = i end end
        local status = mi and (("%d aguardando  ·  %d jogando (%d partida%s)"):format(mi.waiting, mi.playing, mi.matches, mi.matches == 1 and "" or "s")) or "—"
        UI.text(status, x + pad + s(22), ly + s(78), s(500), s(16), UI.color("accent2", 230 * a), "semibold", 9, "left", "center")
        -- barra de preenchimento do aquecimento
        local need = mode.teamSize * 2
        local waiting = mi and mi.waiting or 0
        UI.bar(x + w - pad - s(300), ly + s(22), s(150), s(8), math.min(1, (waiting % need) / need), UI.rgb(mode.color, 230 * a), tocolor(255, 255, 255, 14 * a), s(3))
        UI.text(("%d/%d"):format(waiting % need, need), x + w - pad - s(300), ly + s(34), s(150), s(16), UI.color("muted", 255 * a), "semibold", 9, "center", "center")
        local bw, bh = s(120), s(36)
        local bx, by = x + w - pad - bw - s(16), ly + (mh - bh) / 2
        local current = getElementData(localPlayer, "dm:arena") == mode.id
        if current then
            UI.rect(bx, by, bw, bh, UI.rgb(mode.color, 30 * a), s(8))
            UI.text("VOCÊ ESTÁ AQUI", bx, by, bw, bh, UI.rgb(mode.color, 255 * a), "semibold", 9, "center", "center")
        else
            UI.button("rk_join_" .. mode.id, "ENTRAR", bx, by, bw, bh, { kind = hover and "primary" or "outline", size = 11, alpha = a })
            local id = mode.id
            clicks[#clicks + 1] = { bx, by, bw, bh, function()
                triggerServerEvent("ranked:requestJoin", localPlayer, id)
                sound("click", 0.5)
                closeRankedPanel()
            end }
        end
        ly = ly + mh + s(14)
    end
    UI.text("F5 ou ESC fecha  ·  Para sair de uma partida use F2 (conta como derrota se estiver em andamento)", x + pad, y + h - s(40), w - pad * 2, s(24), UI.color("muted", 200 * a), "regular", 10, "left", "center")
end

local function onClick(button, st)
    if button ~= "left" or st ~= "down" or not panel.open then return end
    for _, c in ipairs(clicks) do
        if UI.isMouseIn(c[1], c[2], c[3], c[4]) then c[5]() return end
    end
end

function openRankedPanel()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    triggerServerEvent("ranked:requestInfo", localPlayer)
    panel.infoTimer = setTimer(function() if panel.open then triggerServerEvent("ranked:requestInfo", localPlayer) end end, 3000, 0)
    if not RENDER_ON then RENDER_ON = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    sound("click", 0.4)
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
    if st and st.state == "countdown" and st.secondsLeft and st.secondsLeft > 0 then
        -- nada: o render usa secondsLeft + stateTick
    end
end)

addEvent("ranked:start", true)
addEventHandler("ranked:start", root, function(team, teamName)
    sound("go", 0.8)
    core:notify(("Você está no %s. Boa partida!"):format(teamName), "success", "Partida iniciada")
end)

addEvent("ranked:end", true)
addEventHandler("ranked:end", root, function(res)
    result = res
    result.tick = getTickCount()
    sound(res.won and "win" or (res.draw and "notify" or "lose"), 0.8)
end)

local lastTick
addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    if state and getElementData(localPlayer, "dm:ready") then
        local secondsLeft = math.max(0, (state.secondsLeft or 0) - math.floor((now - stateTick) / 1000))
        local w, h = s(460), s(70)
        local x, y = (UI.sw - w) / 2, s(84)
        if state.state == "warmup" then
            UI.card(x, y, w, h, s(12), 1, "accent2")
            UI.text("AQUECIMENTO", x, y + s(10), w, s(20), UI.color("accent2"), "bold", 12, "center", "center")
            UI.text(("%d / %d jogadores — a partida começa quando completar"):format(state.players, state.needed), x, y + s(32), w, s(18), UI.color("text", 230), "medium", 10, "center", "center")
            UI.bar(x + s(24), y + h - s(12), w - s(48), s(5), state.players / state.needed, UI.color("accent2", 230), tocolor(255, 255, 255, 14), 2)
        elseif state.state == "countdown" then
            UI.card(x, y, w, h, s(12), 1, "gold")
            UI.text("A PARTIDA VAI COMEÇAR", x, y + s(10), w, s(20), UI.color("gold"), "bold", 12, "center", "center")
            UI.text(("%d segundos  ·  %s vs %s"):format(secondsLeft, state.nameA, state.nameB), x, y + s(32), w, s(18), UI.color("text", 230), "medium", 10, "center", "center")
            if lastTick ~= secondsLeft and secondsLeft <= 5 and secondsLeft > 0 then lastTick = secondsLeft sound("tick", 0.5) end
        elseif state.state == "match" then
            UI.card(x, y, w, h, s(12), 1, false)
            local ca, cb = tocolor(34, 230, 138), tocolor(255, 181, 71)
            local mine = state.myTeam
            UI.text(state.nameA, x + s(16), y + s(8), s(170), s(20), ca, "semibold", 11, "left", "center", true)
            UI.text(state.nameB, x + w - s(186), y + s(8), s(170), s(20), cb, "semibold", 11, "right", "center", true)
            UI.text(tostring(state.scoreA), x + s(16), y + s(28), s(170), s(34), UI.color("text"), "bold", 26, "left", "center")
            UI.text(tostring(state.scoreB), x + w - s(186), y + s(28), s(170), s(34), UI.color("text"), "bold", 26, "right", "center")
            local m, sec = math.floor(secondsLeft / 60), secondsLeft % 60
            UI.text(("%02d:%02d"):format(m, sec), x, y + s(8), w, s(22), UI.color("text"), "bold", 14, "center", "center")
            UI.text(("meta %d  ·  você: %d K / %d M"):format(state.killTarget, state.kills or 0, state.deaths or 0), x, y + s(32), w, s(16), UI.color("muted"), "medium", 9, "center", "center")
            if mine then
                UI.pill(mine == "A" and "SEU TIME" or "SEU TIME", mine == "A" and x + s(16) or x + w - s(16) - s(70), y + h - s(20), s(16), mine == "A" and tocolor(34, 230, 138, 50) or tocolor(255, 181, 71, 60), mine == "A" and ca or cb, "bold", 7)
            end
            UI.bar(x + s(24), y + h - s(6), w - s(48), s(3), secondsLeft / math.max(1, state.duration or 600), UI.color("gold", 200), tocolor(255, 255, 255, 12), 1)
        end
    end

    if result then
        local age = now - result.tick
        if age > 10000 then
            result = nil
        else
            local a = age < 250 and UI.ease(age / 250) or (age > 9500 and math.max(0, (10000 - age) / 500) or 1)
            local w, h = s(620), s(170 + math.min(10, #(result.results or {})) * 22 + 40)
            local x, y = (UI.sw - w) / 2, UI.sh / 2 - h / 2 - s(20)
            dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 5, 12, 130 * a))
            UI.card(x, y, w, h, s(16), a, result.won and "success" or (result.draw and "gold" or "danger"))
            local title = result.cancelled and "PARTIDA CANCELADA" or (result.draw and "EMPATE" or (result.won and "VITÓRIA" or "DERROTA"))
            local col = result.won and "success" or (result.draw and "gold" or "danger")
            UI.text(title, x, y + s(22), w, s(44), UI.color(col, 255 * a), "bold", 32, "center", "center")
            UI.text(("%s  %d  x  %d  %s"):format(result.nameA or "A", result.scoreA or 0, result.scoreB or 0, result.nameB or "B"), x, y + s(66), w, s(26), UI.color("text", 255 * a), "semibold", 15, "center", "center")
            local sub = result.cancelled and "Sem alteração de RP" or ("%s%d RP   ·   +%s   ·   %d K / %d M%s"):format(result.rp >= 0 and "+" or "", result.rp, formatMoney(result.money or 0), result.kills or 0, result.deaths or 0, result.mvp ~= "" and ("   ·   MVP: " .. result.mvp) or "")
            UI.text(sub, x, y + s(94), w, s(22), UI.color("muted", 255 * a), "medium", 11, "center", "center")
            -- tabela resumida
            local ry = y + s(126)
            local rows = result.results or {}
            table.sort(rows, function(p, q) return (p.kills or 0) > (q.kills or 0) end)
            for i = 1, math.min(10, #rows) do
                local r = rows[i]
                local tc = r.team == "A" and tocolor(34, 230, 138, 255 * a) or tocolor(255, 181, 71, 255 * a)
                UI.text(r.name, x + s(40), ry, s(300), s(20), tc, "medium", 10, "left", "center")
                UI.text(("%d K  %d M   %s%d RP"):format(r.kills or 0, r.deaths or 0, (r.rp or 0) >= 0 and "+" or "", r.rp or 0), x + w - s(300), ry, s(260), s(20), UI.color("text", 220 * a), "medium", 10, "right", "center")
                ry = ry + s(22)
            end
            UI.text("Voltando ao aquecimento...", x, y + h - s(32), w, s(20), UI.color("muted", 200 * a), "regular", 9, "center", "center")
        end
    end
end)
