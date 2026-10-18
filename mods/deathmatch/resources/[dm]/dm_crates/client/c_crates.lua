--[[
    Caixas (F7): caixas com preço e raridades, roleta animada ao abrir, inventário e equipar.
]]

local core = exports.dm_core
local PANEL = "crates"
local panel = { open = false, tick = 0, rendering = false, tab = "boxes" }
local CRATES
local reel = nil    -- { items = {...}, target = idx, start = tick, duration, box, result, duplicate, done }

local function s(v) return UI.s(v) end
local function formatMoney(v) return core:formatMoney(v) end
local function cfg()
    if not CRATES then CRATES = core:getCratesConfig() end
    return CRATES
end
local function item(key)
    for _, it in ipairs(cfg().items) do if it.key == key then return it end end
end
local function rarity(it) return cfg().rarities[it.rarity] or cfg().rarities.comum end
local function hasItem(key)
    local perks = getElementData(localPlayer, "dm:perks")
    return type(perks) == "table" and perks["item:" .. key] == true
end
local function money() return tonumber(getElementData(localPlayer, "dm:money")) or 0 end
local function itemIcon(it)
    if it.type == "wskin" then return "target.png" elseif it.type == "skin" then return "shield.png" else return "coin.png" end
end

local function itemCard(it, x, y, w, h, a, hoverId, selected)
    local rc = rarity(it).color
    local t = hoverId and UI.hover(hoverId, UI.isMouseIn(x, y, w, h)) or 0
    UI.rrect(x, y - s(3) * t, w, h + s(3) * t, UI.color("card2", (225 + 30 * t) * a), s(10), {
        border = 1, borderColor = selected and tocolor(rc[1], rc[2], rc[3], 220 * a) or tocolor(rc[1], rc[2], rc[3], (90 + 100 * t) * a),
        glow = s(4) + s(12) * t + (selected and s(8) or 0), glowColor = tocolor(rc[1], rc[2], rc[3], (60 + 90 * t) * a),
        gradient = tocolor(rc[1], rc[2], rc[3], (16 + 10 * t) * a), gradientMode = 1,
    })
    if it.type == "wskin" and it.texture then
        local path = "textures/" .. it.texture
        if fileExists(path) then dxDrawImage(x + s(12), y + s(12), w - s(24), h - s(52), path, 0, 0, 0, tocolor(255, 255, 255, 230 * a)) end
    else
        UI.image(itemIcon(it), x + w / 2 - s(20), y + s(14), s(40), s(40), tocolor(rc[1], rc[2], rc[3], 255 * a))
    end
    UI.text(it.name, x + s(6), y + h - s(38), w - s(12), s(18), UI.color("text", 255 * a), "semibold", 9, "center", "center", true)
    UI.text(rarity(it).name:upper(), x, y + h - s(20), w, s(14), tocolor(rc[1], rc[2], rc[3], 255 * a), "bold", 7, "center", "center")
end

local function render()
    cfg()
    local f = UI.panelFrame(panel, {
        w = s(960), h = s(640), title = "CAIXAS", subtitle = "Abra caixas com $ e ganhe skins exclusivas, skins de arma e dinheiro. Itens repetidos devolvem metade do valor.",
        icon = "trophy.png", accent = "gold", badge = "SALDO  " .. formatMoney(math.floor(UI.counter("crates:money", money(), 800) + 0.5)), badgeColor = "gold", onClose = closeCratesPanel,
    })
    if not f then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    local a = f.a
    UI.tabs("crates:tabs", { { "boxes", "CAIXAS" }, { "inv", "MEU INVENTÁRIO" } }, f.cx, f.cy, s(34), panel.tab, function(k) panel.tab = k end, a)
    local gy = f.cy + s(52)
    if panel.tab == "boxes" then
        local boxes = cfg().boxes
        local bw = (f.cw - s(16) * (#boxes - 1)) / #boxes
        for i, b in ipairs(boxes) do
            local p = UI.stagger(a, i, #boxes, 0.5)
            local x, y = f.cx + (i - 1) * (bw + s(16)), gy + (1 - p) * s(16)
            local h = s(300)
            local t = UI.hover("crates:box:" .. b.key, UI.isMouseIn(x, y, bw, h))
            local c = b.color
            UI.rrect(x, y - s(4) * t, bw, h + s(4) * t, UI.color("card2", (225 + 30 * t) * a * p), s(14), {
                border = 1, borderColor = tocolor(c[1], c[2], c[3], (120 + 100 * t) * a * p), glow = s(10) + s(16) * t, glowColor = tocolor(c[1], c[2], c[3], (60 + 90 * t) * a * p),
                gradient = tocolor(c[1], c[2], c[3], (20 + 14 * t) * a * p), gradientMode = 1, shine = 0.15,
            })
            local pulse = 1 + 0.06 * UI.pulse(1400 + i * 200, 0, 1)
            local isz = s(84) * pulse
            UI.image(b.icon or "trophy.png", x + bw / 2 - isz / 2, y + s(70) - isz / 2 + s(10), isz, isz, tocolor(c[1], c[2], c[3], 255 * a * p))
            UI.textGlow(b.name:upper(), x, y + s(132), bw, s(26), UI.color("text", 255 * a * p), tocolor(c[1], c[2], c[3], 130 * a * p), "bold", 15, "center", "center")
            UI.text(b.desc or "", x + s(16), y + s(160), bw - s(32), s(40), UI.color("muted", 255 * a * p), "regular", 9, "center", "top", false, true)
            -- chances
            local cy = y + s(206)
            local totalW = 0
            for _, d in ipairs(b.pool) do totalW = totalW + d.weight end
            local shown = {}
            for _, d in ipairs(b.pool) do
                local it = item(d.item)
                if it then
                    local r = it.rarity
                    shown[r] = (shown[r] or 0) + d.weight
                end
            end
            local sx = x + s(16)
            for _, rk in ipairs({ "comum", "rara", "epica", "lendaria" }) do
                if shown[rk] then
                    local rc = cfg().rarities[rk].color
                    local txt = ("%s %d%%"):format(cfg().rarities[rk].name, math.floor(shown[rk] / totalW * 100 + 0.5))
                    local pw = UI.pill(txt, sx, cy, s(18), tocolor(rc[1], rc[2], rc[3], 40 * a * p), tocolor(rc[1], rc[2], rc[3], 255 * a * p), "semibold", 7, s(7))
                    sx = sx + pw + s(4)
                    if sx > x + bw - s(60) then sx = x + s(16) cy = cy + s(22) end
                end
            end
            local bk = b.key
            UI.button("crates:open:" .. bk, ("ABRIR  ·  %s"):format(formatMoney(b.price)), x + s(16), y + h - s(54), bw - s(32), s(40), { kind = "primary", color = "gold", size = 11, alpha = a * p, disabled = money() < b.price or reel ~= nil,
                onClick = function() triggerServerEvent("crates:open", localPlayer, bk) end })
        end
    else
        -- inventário
        local owned = {}
        for _, it in ipairs(cfg().items) do if it.type ~= "money" and hasItem(it.key) then owned[#owned + 1] = it end end
        if #owned == 0 then
            UI.text("Você ainda não tem itens. Abra uma caixa!", f.cx, gy, f.cw, s(60), UI.color("muted", 255 * a), "medium", 12, "center", "center")
        end
        local cols = 6
        local cw = (f.cw - s(12) * (cols - 1)) / cols
        local ch = s(150)
        local equippedSkin = tonumber(getElementData(localPlayer, "dm:skin")) or 0
        local equippedW = getElementData(localPlayer, "dm:wskin")
        for i, it in ipairs(owned) do
            if i > 12 then break end
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            local p = UI.stagger(a, i, math.min(12, #owned), 0.5)
            local x, y = f.cx + col * (cw + s(12)), gy + row * (ch + s(14)) + (1 - p) * s(12)
            local eq = (it.type == "skin" and equippedSkin == it.model) or (it.type == "wskin" and equippedW == it.key)
            itemCard(it, x, y, cw, ch, a * p, "crates:inv:" .. it.key, eq)
            local key = it.key
            UI.button("crates:eq:" .. key, eq and "EQUIPADO" or "EQUIPAR", x + s(8), y + ch - s(28) - s(72), cw - s(16), s(22), { kind = eq and "ghost" or "outline", size = 8, alpha = a * p, radius = s(6), disabled = eq,
                onClick = function() triggerServerEvent("crates:equip", localPlayer, key) end })
        end
        UI.button("crates:noskin", "SKIN PADRÃO", f.cx, f.y + f.h - s(92), s(150), s(30), { kind = "ghost", size = 9, alpha = a, onClick = function() triggerServerEvent("crates:equip", localPlayer, "skin:none") end })
        UI.button("crates:nowskin", "ARMA PADRÃO", f.cx + s(160), f.y + f.h - s(92), s(150), s(30), { kind = "ghost", size = 9, alpha = a, onClick = function() triggerServerEvent("crates:equip", localPlayer, "wskin:none") end })
    end
    UI.panelFooter(f, "F7 ou ESC fecha   ·   skins de arma são texturas por jogador   ·   skins exclusivas ficam salvas na sua conta")

    -- roleta por cima
    if reel then
        local age = getTickCount() - reel.start
        local t = UI.clamp(age / reel.duration, 0, 1)
        local e = UI.ease(t, "outQuart")
        UI.backdrop(1, 190)
        local cw, gap = s(130), s(10)
        local centerX = UI.sw / 2
        local offset = (reel.target - 1) * (cw + gap) * e
        local y = UI.sh / 2 - s(90)
        for i, it in ipairs(reel.items) do
            local x = centerX - cw / 2 + (i - 1) * (cw + gap) - offset
            if x > -cw and x < UI.sw then
                local dist = math.abs(x + cw / 2 - centerX) / (cw + gap)
                local sc = 1 - UI.clamp(dist, 0, 1) * 0.12
                itemCard(it, x + cw * (1 - sc) / 2, y + s(160) * (1 - sc) / 2, cw * sc, s(160) * sc, 1 - UI.clamp(dist, 0, 3) * 0.18, nil, t >= 1 and i == reel.target)
            end
        end
        UI.rrect(centerX - s(2), y - s(16), s(4), s(192), UI.color("gold"), s(2), { glow = s(10), glowColor = UI.color("gold", 160) })
        if t < 1 then
            local tick = math.floor(offset / (cw + gap))
            if reel.lastTick ~= tick then reel.lastTick = tick UI.sound("tick", 0.3) end
        else
            if not reel.done then reel.done = true UI.sound(reel.result.rarity == "lendaria" and "win" or "levelup", 0.8) reel.doneTick = getTickCount() end
            local rc = rarity(reel.result).color
            local da = UI.ease(math.min(1, (getTickCount() - reel.doneTick) / 400), "outBack")
            UI.textGlow(reel.duplicate and "REPETIDO — metade do valor devolvida" or ("VOCÊ GANHOU: " .. reel.result.name:upper()), 0, y + s(190), UI.sw, s(40) * da, tocolor(rc[1], rc[2], rc[3], 255 * da), tocolor(rc[1], rc[2], rc[3], 150 * da), "bold", 20, "center", "center")
            UI.button("crates:close_reel", "CONTINUAR", centerX - s(90), y + s(240), s(180), s(40), { kind = "primary", color = "gold", size = 11, onClick = function() reel = nil end })
        end
    end
    UI.endFrame()
end

addEvent("crates:result", true)
addEventHandler("crates:result", root, function(boxKey, itemKey, duplicate)
    cfg()
    local b
    for _, bx in ipairs(cfg().boxes) do if bx.key == boxKey then b = bx end end
    local result = item(itemKey)
    if not b or not result then return end
    local items = {}
    for i = 1, 40 do
        local d = b.pool[math.random(#b.pool)]
        items[i] = item(d.item) or result
    end
    items[34] = result
    reel = { items = items, target = 34, start = getTickCount(), duration = 5200, box = b, result = result, duplicate = duplicate, lastTick = 0 }
    UI.sound("go", 0.5)
end)

local function onClick(button, state)
    if panel.open then UI.processClick(button, state) end
end

function openCratesPanel()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    if not panel.rendering then panel.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    UI.sound("click", 0.4)
end

function closeCratesPanel()
    if not panel.open then return end
    if reel and not reel.done then return end
    reel = nil
    panel.open = false
    panel.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
end

bindKey("F7", "down", function() if panel.open then closeCratesPanel() else openCratesPanel() end end)
UI.registerEscape(PANEL, closeCratesPanel)
addEvent("crates:openPanel", true)
addEventHandler("crates:openPanel", root, openCratesPanel)
