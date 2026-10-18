--[[
    SELEÇÃO DE ARENAS / MODOS (F2) — composição em tela cheia:
      · barra superior: logo · seletor de modo (ARENAS | RANQUEADAS) · chip do jogador · fechar
      · painel lateral esquerdo (translúcido): lista de arenas com cor, nome, armas e ocupação
      · cena do jogo ao fundo: a câmera voa e orbita o local do item selecionado
      · dock inferior (translúcido): nome grande, tipo, descrição, tiles de informação e ENTRAR
    Protocolo preservado: dm:requestArena, ranked:requestJoin, F2, ESC, openArenaPanel/closeArenaPanel/
    toggleArenaPanel/isPanelOpen, addEvent("ranked:openPanel").
]]

local PANEL = "arenas"
local hub = { open = false, tick = 0, rendering = false, tab = "arenas", selected = 1, origDim = 0, camStart = 0, scroll = 0 }

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

local function typeLabel(item)
    if item.type == "ranked" then return "RANQUEADA" end
    if item.type == "lobby" then return "ZONA SEGURA" end
    if item.type == "duel" then return "DUELOS 1v1" end
    return "TODOS CONTRA TODOS"
end

local function enter(item)
    closeArenaPanel()
    if item.type == "ranked" then
        triggerServerEvent("ranked:requestJoin", localPlayer, item.id)
    else
        triggerServerEvent("dm:requestArena", localPlayer, item.id)
    end
end

local function updateCamera(item)
    local px, py, pz, dim = previewPoint(item)
    if getElementDimension(localPlayer) ~= dim then setElementDimension(localPlayer, dim) end
    local t = (getTickCount() - hub.camStart) / 1000
    local cx = UI.tween("hub:cam:x", px, 1000, "outCubic")
    local cy = UI.tween("hub:cam:y", py, 1000, "outCubic")
    local cz = UI.tween("hub:cam:z", pz, 1000, "outCubic")
    local radius = 40
    setCameraMatrix(cx + math.cos(t * 0.2) * radius, cy + math.sin(t * 0.2) * radius, cz + 15 + math.sin(t * 0.45) * 1.5, cx, cy, cz + 2)
end

-- painel translúcido padrão desta tela (sem brilho exagerado)
local function surface(x, y, w, h, a, radius)
    UI.rrect(x, y, w, h, tocolor(8, 12, 10, 205 * a), radius or UI.s(14), {
        border = 1, borderColor = tocolor(255, 255, 255, 26 * a),
        gradient = tocolor(14, 20, 16, 205 * a), gradientMode = 1,
    })
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
    if hub.open then updateCamera(sel) end
    local counts = countPlayers()
    local G = s(24)                      -- gutter da grade
    local topH = s(72)

    -- tratamento da cena: escurece bordas e mantém o centro visível
    UI.vignette(tocolor(4, 8, 6, 255), 0.9 * a, 0.3, 1.5)
    UI.gradientV(0, 0, UI.sw, topH + s(40), { 4, 8, 6, 230 * a }, { 4, 8, 6, 0 }, 14)

    -- ===== barra superior =====
    UI.image("logo.png", G, s(14), s(140), s(44), tocolor(255, 255, 255, 255 * a))
    local segW, segH = s(180), s(40)
    local segX, segY = UI.sw / 2 - segW, s(16)
    UI.rrect(segX - s(4), segY - s(4), segW * 2 + s(8), segH + s(8), tocolor(8, 12, 10, 200 * a), (segH + s(8)) / 2, { border = 1, borderColor = tocolor(255, 255, 255, 26 * a) })
    local selIdx = hub.tab == "ranked" and 1 or 0
    local ix = UI.tween("hub:seg", segX + selIdx * segW, 220, "outCubic")
    UI.rrect(ix, segY, segW, segH, UI.color("accent", 230 * a), segH / 2, { glow = s(8), glowColor = UI.color("accent", 90 * a) })
    for i, t in ipairs({ { "arenas", "ARENAS" }, { "ranked", "RANQUEADAS" } }) do
        local x = segX + (i - 1) * segW
        local isSel = hub.tab == t[1]
        UI.text(t[2], x, segY, segW, segH, isSel and tocolor(8, 14, 10, 255 * a) or UI.color("muted", 255 * a), "bold", 11, "center", "center")
        local key = t[1]
        UI.addClick(x, segY, segW, segH, function() if hub.tab ~= key then hub.tab = key hub.selected = 1 hub.scroll = 0 end end, "hub:tab:" .. key)
    end
    -- chip do jogador
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = DM.tierForRP(rp)
    local chipTxt = ("%s  ·  %s  ·  %s"):format(DM.stripColors(getPlayerName(localPlayer)), tier.name:upper(), DM.formatMoney(getElementData(localPlayer, "dm:money") or 0))
    local chipW = UI.textWidth(chipTxt, "semibold", 10) + s(40)
    local chipX = UI.sw - G - s(32) - s(12) - chipW
    UI.rrect(chipX, segY, chipW, segH, tocolor(8, 12, 10, 200 * a), segH / 2, { border = 1, borderColor = tocolor(255, 255, 255, 26 * a) })
    UI.rrect(chipX + s(14), segY + segH / 2 - s(5), s(10), s(10), UI.rgb(tier.color, 255 * a), s(5))
    UI.text(chipTxt, chipX + s(32), segY, chipW - s(40), segH, UI.color("text", 255 * a), "semibold", 10, "left", "center")
    UI.closeButton("hub:close", UI.sw - G - s(32), segY + s(4), closeArenaPanel, a)

    -- ===== painel lateral (lista) =====
    local sideX, sideY, sideW = G, topH + s(8), s(420)
    local dockH = s(200)
    local sideH = UI.sh - sideY - dockH - G * 2
    surface(sideX, sideY, sideW, sideH, a)
    UI.text(hub.tab == "ranked" and "MODOS RANQUEADOS" or "ARENAS", sideX + s(22), sideY + s(18), sideW, s(18), UI.color("text", 255 * a), "bold", 13, "left", "center")
    UI.text(("%d disponíveis"):format(#list), sideX + s(22), sideY + s(18), sideW - s(44), s(18), UI.color("muted", 255 * a), "regular", 9, "right", "center")
    UI.divider(sideX + s(22), sideY + s(46), sideW - s(44), 22 * a)
    local rowH = s(74)
    local listY = sideY + s(58)
    local listH = sideH - s(70)
    local maxRows = math.floor(listH / rowH)
    hub.scroll = UI.clamp(hub.scroll, 0, math.max(0, #list - maxRows))
    hub.listBounds = { sideX, listY, sideW, listH }
    local off = UI.scroll("hub:list", hub.scroll)
    for i, item in ipairs(list) do
        local y = listY + (i - 1 - off) * rowH
        if y >= listY - s(1) and y + rowH <= listY + listH + s(1) then
            local p = UI.stagger(a, i, #list, 0.5)
            local x, w, h = sideX + s(14), sideW - s(28), rowH - s(8)
            local isSel = i == hub.selected
            local hv = UI.hover("hub:row:" .. item.id, UI.isMouseIn(x, y, w, h))
            local c = item.color
            UI.rrect(x, y, w, h, isSel and tocolor(c[1], c[2], c[3], 34 * a * p) or tocolor(255, 255, 255, (6 + 12 * hv) * a * p), s(10), {
                border = 1, borderColor = isSel and tocolor(c[1], c[2], c[3], 200 * a * p) or tocolor(255, 255, 255, (14 + 40 * hv) * a * p),
            })
            -- bloco de cor (miniatura)
            UI.rrect(x + s(10), y + s(10), s(46), h - s(20), tocolor(c[1], c[2], c[3], (isSel and 230 or 150) * a * p), s(8), { gradient = tocolor(c[1], c[2], c[3], 60 * a * p), gradientMode = 1 })
            UI.text(item.short or item.name, x + s(10), y + s(10), s(46), h - s(20), tocolor(8, 14, 10, 255 * a * p), "bold", 7, "center", "center", true)
            UI.text(item.name:upper(), x + s(68), y + s(10), w - s(150), s(20), UI.color(isSel and "text" or "muted", 255 * a * p), "bold", 11, "left", "center", true)
            local sub = item.type == "ranked" and ("%s · %dx%d"):format(item.place, item.teamSize, item.teamSize) or DM.arenaWeaponList(item)
            UI.text(UI.truncate(sub, "regular", 9, w - s(160)), x + s(68), y + s(32), w - s(150), s(16), UI.color("muted", 230 * a * p), "regular", 9, "left", "center")
            -- ocupação
            local n = counts[item.id] or 0
            local cap = item.type == "ranked" and item.teamSize * 2 or 32
            UI.bar(x + s(68), y + h - s(14), w - s(150), s(3), n / cap, tocolor(c[1], c[2], c[3], 220 * a * p), tocolor(255, 255, 255, 14 * a * p), 1)
            UI.text(tostring(n), x + w - s(70), y, s(60), h, UI.color("text", 255 * a * p), "bold", 14, "right", "center")
            UI.text("ONLINE", x + w - s(70), y + h / 2 + s(8), s(60), s(12), UI.color("muted", 200 * a * p), "semibold", 6, "right", "center")
            local idx = i
            UI.addClick(x, y, w, h, function() if hub.selected == idx then enter(item) else hub.selected = idx UI.sound("hover", 0.3) end end, "hub:row:" .. item.id)
        end
    end
    UI.scrollbar(sideX + sideW - s(8), listY, listH, #list, maxRows, off, a)

    -- ===== dock inferior (detalhes + ação) =====
    local dockX, dockY, dockW = G, UI.sh - dockH - G, UI.sw - G * 2
    surface(dockX, dockY, dockW, dockH, a)
    local c = sel.color
    UI.rrect(dockX, dockY + s(18), s(5), dockH - s(36), tocolor(c[1], c[2], c[3], 255 * a), s(2))
    local dx = dockX + s(30)
    UI.pill(typeLabel(sel), dx, dockY + s(22), s(22), tocolor(c[1], c[2], c[3], 40 * a), tocolor(c[1], c[2], c[3], 255 * a), "bold", 8, s(10))
    UI.textGlow(sel.name:upper(), dx, dockY + s(46), s(620), s(50), UI.color("text", 255 * a), tocolor(c[1], c[2], c[3], 110 * a), "bold", 30, "left", "center")
    UI.text(sel.desc or "", dx, dockY + s(100), s(620), s(40), UI.color("muted", 255 * a), "regular", 11, "left", "top", false, true)
    -- tiles
    local n = counts[sel.id] or 0
    local tiles
    if sel.type == "ranked" then
        tiles = { { "JOGADORES", ("%d / %d"):format(n, sel.teamSize * 2) }, { "META", ("%d kills"):format(sel.killTarget) }, { "TEMPO", ("%d min"):format(math.floor(sel.duration / 60)) }, { "ARMAS", DM.arenaWeaponList(sel) } }
    else
        tiles = { { "JOGADORES", tostring(n) }, { "ARMAS", DM.arenaWeaponList(sel) }, { "MAPA", sel.id == "lobby" and "Los Santos" or (sel.native and "GTA" or "Mapa próprio") }, { "REGRAS", sel.cbug and "C-Bug liberado" or (sel.safe and "Sem dano" or "Headshot x2.2") } }
    end
    local tw, th = s(170), s(64)
    local tilesX = dockX + dockW - s(30) - s(250) - G - tw * 4 - s(12) * 3
    for i, t in ipairs(tiles) do
        local p = UI.stagger(a, i, 4, 0.4)
        local x = tilesX + (i - 1) * (tw + s(12))
        local y = dockY + (dockH - th) / 2 + (1 - p) * s(8)
        UI.rrect(x, y, tw, th, tocolor(255, 255, 255, 8 * a * p), s(10), { border = 1, borderColor = tocolor(255, 255, 255, 22 * a * p) })
        UI.text(t[1], x + s(14), y + s(10), tw, s(14), UI.color("muted", 230 * a * p), "semibold", 8, "left", "center")
        UI.text(UI.truncate(t[2], "bold", 12, tw - s(28)), x + s(14), y + s(28), tw - s(28), s(24), UI.color("text", 255 * a * p), "bold", 12, "left", "center")
    end
    -- ação
    local bw, bh = s(250), s(54)
    local bx, by = dockX + dockW - s(30) - bw, dockY + (dockH - bh) / 2 - s(12)
    local isCurrent = getElementData(localPlayer, "dm:arena") == sel.id
    if isCurrent then
        UI.rrect(bx, by, bw, bh, tocolor(c[1], c[2], c[3], 36 * a), s(12), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 170 * a) })
        UI.text("VOCÊ ESTÁ AQUI", bx, by, bw, bh, tocolor(c[1], c[2], c[3], 255 * a), "bold", 12, "center", "center")
    else
        UI.button("hub:enter", sel.type == "ranked" and "ENTRAR NA PARTIDA" or "ENTRAR NA ARENA", bx, by, bw, bh, { kind = "primary", color = sel.type == "ranked" and "gold" or "accent", size = 12, alpha = a, onClick = function() enter(sel) end })
    end
    UI.text("ESC voltar   ·   duplo clique na lista entra", bx, by + bh + s(8), bw, s(16), UI.color("muted", 180 * a), "regular", 8, "center", "center")
    UI.endFrame()
end

local function onClick(button, state)
    if hub.open then UI.processClick(button, state) end
end

local function onWheel(key, press)
    if not hub.open or not press then return end
    if key == "mouse_wheel_up" or key == "mouse_wheel_down" then
        local b = hub.listBounds
        if b and UI.isMouseIn(b[1], b[2], b[3], b[4]) then
            hub.scroll = math.max(0, hub.scroll + (key == "mouse_wheel_down" and 1 or -1))
        end
    end
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
    UI.resetTween("hub:cam:x") UI.resetTween("hub:cam:y") UI.resetTween("hub:cam:z")
    if not hub.rendering then hub.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    addEventHandler("onClientKey", root, onWheel)
    UI.sound("click", 0.4)
end

function closeArenaPanel()
    if not hub.open then return end
    hub.open = false
    hub.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
    removeEventHandler("onClientKey", root, onWheel)
end

function toggleArenaPanel()
    if hub.open then closeArenaPanel() else openArenaPanel() end
end

addEvent("ranked:openPanel")
bindKey("F2", "down", toggleArenaPanel)
UI.registerEscape(PANEL, closeArenaPanel)

function isPanelOpen() return UI.getOpenPanel() ~= nil end
