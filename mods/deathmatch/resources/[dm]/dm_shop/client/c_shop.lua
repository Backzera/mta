--[[
    Loja (F4) — UI v2: saldo animado no cabeçalho, abas deslizantes, cards em cascata com estado
    comprar/equipar/equipado, confirmação em dois cliques, VIP dourado com vantagens.
]]

local core = exports.dm_core
local PANEL = "shop"
local panel = { open = false, tick = 0, rendering = false, tab = "tags", confirm = nil, confirmTick = 0 }
local SHOP, VIP, ECO

local function s(v) return UI.s(v) end
local function formatMoney(v) return core:formatMoney(v) end
local function rgbToHex(r, g, b) return string.format("#%02X%02X%02X", r, g, b) end
local function cfg()
    if not SHOP then SHOP = core:getShopConfig() VIP = core:getVipConfig() ECO = core:getEconomyConfig() end
end
local function hasPerk(key)
    local perks = getElementData(localPlayer, "dm:perks")
    return type(perks) == "table" and perks[key] == true
end
local function money() return tonumber(getElementData(localPlayer, "dm:money")) or 0 end

local TABS = { { "tags", "TAGS" }, { "nameColors", "CORES DE NICK" }, { "vip", "VIP" }, { "extras", "EXTRAS" } }

-- Card de item. state: nil (comprar) | "owned" | "equipped"
local function itemCard(id, x, y, w, h, a, title, subtitle, price, color, state, onBuy, badge)
    local hovering = UI.isMouseIn(x, y, w, h)
    local t = UI.hover("shop:item:" .. id, hovering)
    UI.rrect(x, y - s(3) * t, w, h + s(3) * t, UI.color("card2", (220 + 30 * t) * a), s(12), {
        border = 1, borderColor = state == "equipped" and UI.rgb(color, 220 * a) or tocolor(255, 255, 255, (20 + 50 * t) * a),
        glow = s(4) + s(14) * t + (state == "equipped" and s(8) or 0), glowColor = UI.rgb(color, (40 + 80 * t) * a),
        gradient = UI.rgb(color, (10 + 14 * t) * a), gradientMode = 3, shine = 0.1,
    })
    UI.rrect(x, y + s(14), s(4), h - s(28), UI.rgb(color, 255 * a), s(2), { glow = s(6), glowColor = UI.rgb(color, 120 * a) })
    UI.text(title, x + s(20), y + s(12), w - s(40), s(20), UI.rgb(color, 255 * a), "bold", 13, "left", "center", true)
    UI.text(subtitle, x + s(20), y + s(34), w - s(40), s(34), UI.color("muted", 255 * a), "regular", 9, "left", "top", false, true)
    if badge then UI.pill(badge, x + w - UI.textWidth(badge, "semibold", 8) - s(32), y + s(12), s(18), UI.color("gold", 50 * a), UI.color("gold", 255 * a), "semibold", 8) end
    local bw, bh = s(118), s(28)
    local bx, by = x + w - bw - s(14), y + h - bh - s(12)
    if state == "equipped" then
        UI.rrect(bx, by, bw, bh, UI.rgb(color, 30 * a), s(8))
        UI.text("EQUIPADO", bx, by, bw, bh, UI.rgb(color, 255 * a), "semibold", 9, "center", "center")
    elseif state == "owned" then
        UI.button("shop_btn_" .. id, "EQUIPAR", bx, by, bw, bh, { kind = "outline", size = 9, alpha = a, onClick = onBuy })
    else
        local confirming = panel.confirm == id and getTickCount() - panel.confirmTick < 4000
        local afford = money() >= price
        UI.button("shop_btn_" .. id, confirming and "CONFIRMAR?" or formatMoney(price), bx, by, bw, bh,
            { kind = confirming and "primary" or (afford and "primary" or "outline"), color = confirming and "warn" or "gold", size = 9, alpha = a,
              onClick = function()
                  if confirming then panel.confirm = nil onBuy()
                  else panel.confirm = id panel.confirmTick = getTickCount() end
              end })
        UI.text(afford and "Você tem saldo" or "Saldo insuficiente", x + s(20), by, bx - x - s(30), bh, afford and UI.color("success", 200 * a) or UI.color("danger", 200 * a), "regular", 8, "left", "center")
    end
end

local function render()
    cfg()
    local bal = math.floor(UI.counter("shop:money", money(), 800) + 0.5)
    local f = UI.panelFrame(panel, {
        w = s(920), h = s(620), title = "LOJA", subtitle = "Kills, duelos, tempo online e ranqueadas dão $. Compre uma vez, equipe quando quiser.",
        icon = "coin.png", accent = "gold", badge = "SALDO  " .. formatMoney(bal), badgeColor = "gold", onClose = closeShop,
    })
    if not f then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    local a = f.a
    UI.tabs("shop:tabs", TABS, f.cx, f.cy, s(34), panel.tab, function(key) panel.tab = key panel.confirm = nil end, a)
    local gy = f.cy + s(50)
    local cols = 2
    local cw = (f.cw - s(16)) / cols
    local ch = s(122)
    local i = 0
    local total = 0
    local function place(fn)
        local col, row = i % cols, math.floor(i / cols)
        local p = UI.stagger(a, i + 1, math.max(1, total), 0.5)
        fn(f.cx + col * (cw + s(16)), gy + row * (ch + s(14)) + (1 - p) * s(14), cw, ch, a * p)
        i = i + 1
    end
    local tagData = getElementData(localPlayer, "dm:tag")
    local vipLevel = tonumber(getElementData(localPlayer, "dm:vip")) or 0

    if panel.tab == "tags" then
        total = #SHOP.tags + 1
        for _, item in ipairs(SHOP.tags) do
            local owned = hasPerk("tag:" .. item.key)
            local equipped = owned and type(tagData) == "table" and tagData.kind == "shop" and (item.custom or tagData.text == item.text)
            local state = equipped and "equipped" or (owned and "owned" or nil)
            place(function(ix, iy, iw, ih, ia)
                itemCard(item.key, ix, iy, iw, ih, ia, item.custom and "TAG PERSONALIZADA" or item.text,
                    item.custom and "Seu próprio texto (2-12 caracteres) com /tag <texto>. Aparece no chat, no placar e sobre o boneco." or "Tag exibida no chat, no placar e acima do seu nick.",
                    item.price, item.color, state, function() triggerServerEvent("shop:buy", localPlayer, "tags", item.key) end)
            end)
        end
        place(function(ix, iy, iw, ih, ia)
            itemCard("tag_none", ix, iy, iw, ih, ia, "USAR TAG DO ELO", "Remove a tag comprada e volta a exibir o seu elo (Bronze, Prata, Ouro...).", 0, { 140, 160, 150 }, "owned",
                function() triggerServerEvent("shop:buy", localPlayer, "unequip", "tag") end)
        end)
    elseif panel.tab == "nameColors" then
        total = #SHOP.nameColors + 1
        local current = getElementData(localPlayer, "dm:nameColor")
        for _, item in ipairs(SHOP.nameColors) do
            local owned = hasPerk("color:" .. item.key)
            local equipped = owned and current == rgbToHex(item.color[1], item.color[2], item.color[3])
            place(function(ix, iy, iw, ih, ia)
                itemCard("color_" .. item.key, ix, iy, iw, ih, ia, item.name:upper(), "Cor do seu nick no chat, no placar e sobre o boneco.", item.price, item.color,
                    equipped and "equipped" or (owned and "owned" or nil), function() triggerServerEvent("shop:buy", localPlayer, "nameColors", item.key) end)
                UI.text("Nick de exemplo", ix + s(20), iy + s(66), iw, s(18), UI.rgb(item.color, 255 * ia), "bold", 11, "left", "center")
            end)
        end
        place(function(ix, iy, iw, ih, ia)
            itemCard("color_none", ix, iy, iw, ih, ia, "COR PADRÃO", "Volta o nick para branco (ou a cor do seu VIP).", 0, { 140, 160, 150 }, "owned",
                function() triggerServerEvent("shop:buy", localPlayer, "unequip", "color") end)
        end)
    elseif panel.tab == "vip" then
        total = 3
        for level = 1, 3 do
            local item = VIP[level]
            local mult = ECO.vipMultiplier[level]
            place(function(ix, iy, iw, ih, ia)
                itemCard("vip_" .. level, ix, iy, iw, ih, ia, item.name:upper(),
                    ("%d dias · %.2fx de $ · bônus diário %s · respawn rápido · nick colorido · todas as skins · tag %s"):format(item.days, mult, formatMoney(item.daily), item.tag),
                    item.price, item.color, vipLevel == level and "equipped" or nil,
                    function() triggerServerEvent("shop:buy", localPlayer, "vip", tostring(level)) end, vipLevel == level and "ATIVO" or nil)
                UI.image("crown.png", ix + iw - s(44), iy + s(8), s(26), s(26), UI.rgb(item.color, 255 * ia))
            end)
        end
    elseif panel.tab == "extras" then
        total = #SHOP.extras
        for _, item in ipairs(SHOP.extras) do
            place(function(ix, iy, iw, ih, ia)
                itemCard("extra_" .. item.key, ix, iy, iw, ih, ia, item.name:upper(), item.desc, item.price, { 120, 255, 180 }, hasPerk(item.key) and "equipped" or nil,
                    function() triggerServerEvent("shop:buy", localPlayer, "extras", item.key) end)
            end)
        end
    end
    UI.panelFooter(f, "F4 ou ESC fecha   ·   clique duas vezes no preço para confirmar   ·   /saldo   /pagar <id> <valor>")
    UI.endFrame()
end

local function onClick(button, state)
    if panel.open then UI.processClick(button, state) end
end

function openShop()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    panel.confirm = nil
    if not panel.rendering then panel.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
    UI.sound("click", 0.4)
end

function closeShop()
    if not panel.open then return end
    panel.open = false
    panel.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
end

bindKey("F4", "down", function() if panel.open then closeShop() else openShop() end end)
UI.registerEscape(PANEL, closeShop)

addEvent("shop:open", true)
addEventHandler("shop:open", root, openShop)
addEvent("shop:result", true)
addEventHandler("shop:result", root, function(ok) UI.sound(ok and "levelup" or "error", 0.5) end)
