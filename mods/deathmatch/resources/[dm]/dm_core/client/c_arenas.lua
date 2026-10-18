--[[
    HUB de jogo (F2) — tela cheia estilo moderno: o mundo do jogo é o fundo (a câmera voa até o
    local da arena/modo selecionado), abas de modo no topo (ARENAS / RANQUEADAS), lista à esquerda,
    destaque grande do selecionado e botão ENTRAR embaixo à direita.
]]

local PANEL = "arenas"
local hub = { open = false, tick = 0, rendering = false, tab = "arenas", selected = 1, origDim = 0, camStart = 0 }

local function items()
    if hub.tab == "ranked" then return DM.rankedModes end
    return DM.arenas
end

local function previewPoint(item)
    if item.center then return item.center[1], item.center[2], item.center[3], item.dimension end
    local sp = item.spawns and item.spawns[1]
    if sp then return sp[1], sp[2], sp[3], item.dimension end
    return 0, 0, 10, 0
end

local function countPlayers()
    local counts = {}
    for _, p in ipairs(getElementsByType("player")) do
        local id = getElementData(p, "dm:arena")
        if id then counts[id] = (counts[id] or 0) + 1 end
    end
    return counts
end

local function enter(item)
    closeArenaPanel()
    if item.type == "ranked" then
        triggerServerEvent("ranked:requestJoin", localPlayer, item.id)
    else
        triggerServerEvent("dm:requestArena", localPlayer, item.id)
    end
end

local function updateCamera(item, a)
    local px, py, pz, dim = previewPoint(item)
    if getElementDimension(localPlayer) ~= dim then setElementDimension(localPlayer, dim) end
    local t = (getTickCount() - hub.camStart) / 1000
    local radius = 42
    local cx = UI.tween("hub:cam:x", px, 900, "outCubic")
    local cy = UI.tween("hub:cam:y", py, 900, "outCubic")
    local cz = UI.tween("hub:cam:z", pz, 900, "outCubic")
    setCameraMatrix(cx + math.cos(t * 0.22) * radius, cy + math.sin(t * 0.22) * radius, cz + 16 + math.sin(t * 0.5) * 2, cx, cy, cz + 2)
end

local function render()
    local raw = UI.clamp((UI.now - hub.tick) / 320, 0, 1)
    local a = hub.open and UI.ease(raw, "outCubic") or 1 - UI.ease(raw, "inCubic")
    if a <= 0.001 then
        if not hub.open then
            removeEventHandler("onClientRender", root, render)
            hub.rendering = false
            setElementDimension(localPlayer, hub.origDim)
            setCameraTarget(localPlayer)
        end
        return
    end
    UI.beginFrame()
    local s = UI.s
    local list = items()
    hub.selected = UI.clamp(hub.selected, 1, #list)
    local sel = list[hub.selected]
    if hub.open then updateCamera(sel, a) end

    -- gradientes de cena (esquerda escura, topo e rodapé)
    UI.gradientH(0, 0, UI.sw * 0.5, UI.sh, { 6, 10, 8, 235 * a }, { 6, 10, 8, 0 }, 28)
    UI.gradientV(0, 0, UI.sw, s(120), { 6, 10, 8, 220 * a }, { 6, 10, 8, 0 }, 16)
    UI.gradientV(0, UI.sh - s(220), UI.sw, s(220), { 6, 10, 8, 0 }, { 6, 10, 8, 230 * a }, 16)

    -- topo: logo, abas, online, fechar
    UI.image("logo.png", s(40), s(22), s(150), s(47), tocolor(255, 255, 255, 255 * a))
    local tabs = { { "arenas", "ARENAS" }, { "ranked", "RANQUEADAS" } }
    local tx = UI.sw / 2 - s(170)
    for _, t in ipairs(tabs) do
        local tw = s(170)
        local isSel = hub.tab == t[1]
        local hv = UI.hover("hub:tab:" .. t[1], UI.isMouseIn(tx, s(24), tw, s(44)))
        UI.textGlow(t[2], tx, s(24), tw, s(44), isSel and UI.color("text", 255 * a) or UI.color("muted", (160 + 95 * hv) * a), isSel and UI.color("accent", 120 * a) or tocolor(0, 0, 0, 0), "bold", 16, "center", "center")
        if isSel then
            local ix = UI.tween("hub:tabline", tx, 220, "outCubic")
            UI.rrect(ix + s(40), s(66), tw - s(80), s(3), UI.color("accent", 255 * a), s(2), { glow = s(10), glowColor = UI.color("accent", 140 * a) })
        end
        local key = t[1]
        UI.addClick(tx, s(24), tw, s(44), function() if hub.tab ~= key then hub.tab = key hub.selected = 1 end end, "hub:tab:" .. key)
        tx = tx + tw
    end
    local online = ("%d ONLINE"):format(#getElementsByType("player"))
    UI.pill(online, UI.sw - s(40) - UI.textWidth(online, "bold", 10) - s(28) - s(48), s(30), s(30), UI.color("accent", 40 * a), UI.color("accent2", 255 * a), "bold", 10, s(14))
    UI.closeButton("hub:close", UI.sw - s(40) - s(32), s(29), closeArenaPanel, a)

    -- lista à esquerda
    local counts = countPlayers()
    local lx, ly, lw = s(40), s(112), s(400)
    UI.text(hub.tab == "ranked" and "ESCOLHA O MODO" or "ESCOLHA A ARENA", lx, ly, lw, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local rowH = s(66)
    local y = ly + s(26)
    for i, item in ipairs(list) do
        local p = UI.stagger(a, i, #list, 0.5)
        local ox = (1 - p) * s(-30)
        local isSel = i == hub.selected
        local hv = UI.hover("hub:row:" .. item.id, UI.isMouseIn(lx, y, lw, rowH - s(6)))
        local c = item.color
        local rx = lx + ox + s(6) * hv
        UI.rrect(rx, y, lw, rowH - s(6), isSel and tocolor(c[1], c[2], c[3], 36 * a * p) or tocolor(255, 255, 255, (8 + 12 * hv) * a * p), s(10), {
            border = 1, borderColor = isSel and tocolor(c[1], c[2], c[3], 190 * a * p) or tocolor(255, 255, 255, (20 + 40 * hv) * a * p),
            glow = isSel and s(12) or 0, glowColor = tocolor(c[1], c[2], c[3], 70 * a * p),
        })
        UI.rrect(rx, y + s(12), s(4), rowH - s(30), tocolor(c[1], c[2], c[3], 255 * a * p), s(2))
        UI.text(item.name:upper(), rx + s(18), y + s(8), lw - s(120), s(22), UI.color(isSel and "text" or "muted", 255 * a * p), "bold", 12, "left", "center")
        local sub = item.type == "ranked" and ("%s · %dx%d"):format(item.place, item.teamSize, item.teamSize) or DM.arenaWeaponList(item)
        UI.text(UI.truncate(sub, "regular", 9, lw - s(130)), rx + s(18), y + s(32), lw - s(120), s(16), UI.color("muted", 230 * a * p), "regular", 9, "left", "center")
        local n = counts[item.id] or 0
        local pulse = n > 0 and UI.pulse(1200, 0.5, 1) or 0.3
        UI.rrect(rx + lw - s(16) - s(8), y + (rowH - s(6)) / 2 - s(4), s(8), s(8), tocolor(c[1], c[2], c[3], 255 * a * p * pulse), s(4))
        UI.text(tostring(n), rx + lw - s(60), y, s(30), rowH - s(6), UI.color("text", 230 * a * p), "semibold", 11, "right", "center")
        local idx = i
        UI.addClick(lx, y, lw, rowH - s(6), function() if hub.selected == idx then enter(item) else hub.selected = idx end end, "hub:row:" .. item.id)
        y = y + rowH
    end

    -- destaque do selecionado (direita/baixo)
    local c = sel.color
    local dx, dw = UI.sw - s(40) - s(560), s(560)
    local dy = UI.sh - s(236)
    local isCurrent = getElementData(localPlayer, "dm:arena") == sel.id
    UI.text(sel.type == "ranked" and "PARTIDA RANQUEADA" or (sel.type == "lobby" and "ZONA SEGURA" or (sel.type == "duel" and "DUELOS 1v1" or "TODOS CONTRA TODOS")), dx, dy - s(40), dw, s(16), tocolor(c[1], c[2], c[3], 255 * a), "semibold", 10, "right", "center")
    UI.textGlow(sel.name:upper(), dx - s(300), dy - s(26), dw + s(300), s(60), UI.color("text", 255 * a), tocolor(c[1], c[2], c[3], 150 * a), "bold", 38, "right", "center")
    UI.text(sel.desc or "", dx, dy + s(34), dw, s(20), UI.color("muted", 255 * a), "regular", 11, "right", "center")
    -- tiles de estatística
    local n = counts[sel.id] or 0
    local tiles = sel.type == "ranked"
        and { { "JOGADORES", ("%d / %d"):format(n, sel.teamSize * 2) }, { "META", ("%d kills · %d min"):format(sel.killTarget, math.floor(sel.duration / 60)) }, { "ARMAS", DM.arenaWeaponList(sel) } }
        or { { "JOGADORES", tostring(n) }, { "ARMAS", DM.arenaWeaponList(sel) }, { "LOCAL", sel.id == "lobby" and "Los Santos" or (sel.native and "GTA" or "Mapa próprio") } }
    local tw = s(176)
    local tx2 = dx + dw - tw * 3 - s(24)
    for i, t in ipairs(tiles) do
        local p = UI.stagger(a, i, 3, 0.4)
        local x = tx2 + (i - 1) * (tw + s(12))
        UI.rrect(x, dy + s(64) + (1 - p) * s(10), tw, s(58), tocolor(255, 255, 255, 10 * a * p), s(10), { border = 1, borderColor = tocolor(255, 255, 255, 22 * a * p) })
        UI.text(t[1], x + s(14), dy + s(70), tw, s(14), UI.color("muted", 230 * a * p), "semibold", 8, "left", "center")
        UI.text(UI.truncate(t[2], "bold", 12, tw - s(28)), x + s(14), dy + s(88), tw - s(28), s(26), UI.color("text", 255 * a * p), "bold", 12, "left", "center")
    end
    -- ações
    local bw, bh = s(220), s(50)
    local bx, by = dx + dw - bw, dy + s(140)
    if isCurrent then
        UI.rrect(bx, by, bw, bh, tocolor(c[1], c[2], c[3], 40 * a), s(12), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 160 * a) })
        UI.text("VOCÊ ESTÁ AQUI", bx, by, bw, bh, tocolor(c[1], c[2], c[3], 255 * a), "bold", 12, "center", "center")
    else
        UI.button("hub:enter", sel.type == "ranked" and "ENTRAR NA PARTIDA" or "ENTRAR NA ARENA", bx, by, bw, bh, { kind = "primary", color = sel.type == "ranked" and "gold" or "accent", size = 12, alpha = a, onClick = function() enter(sel) end })
    end
    UI.text("ESC voltar   ·   clique duas vezes na lista para entrar   ·   a câmera mostra o local antes de entrar", dx - s(200), by + s(56), dw + s(200), s(18), UI.color("muted", 180 * a), "regular", 9, "right", "center")
    UI.endFrame()
end

local function onClick(button, state)
    if hub.open then UI.processClick(button, state) end
end

function openArenaPanel()
    if hub.open then return end
    if not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    hub.open = true
    hub.tick = getTickCount()
    hub.camStart = getTickCount()
    hub.origDim = getElementDimension(localPlayer)
    local list = items()
    for i, it in ipairs(list) do if it.id == getElementData(localPlayer, "dm:arena") then hub.selected = i end end
    local px, py, pz = previewPoint(list[hub.selected])
    UI.resetTween("hub:cam:x") UI.resetTween("hub:cam:y") UI.resetTween("hub:cam:z")
    if setHudVisible then setHudVisible(false) end
    if not hub.rendering then hub.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    UI.sound("click", 0.4)
end

function closeArenaPanel()
    if not hub.open then return end
    hub.open = false
    hub.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
    if setHudVisible then setHudVisible(true) end
end

function toggleArenaPanel()
    if hub.open then closeArenaPanel() else openArenaPanel() end
end

addEvent("ranked:openPanel")
bindKey("F2", "down", toggleArenaPanel)
UI.registerEscape(PANEL, closeArenaPanel)

function isPanelOpen() return UI.getOpenPanel() ~= nil end
