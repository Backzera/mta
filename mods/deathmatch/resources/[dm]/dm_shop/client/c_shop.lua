--[[
    Loja (F4): abas Tags / Cores / VIP / Extras. Compra em dois cliques (confirmação).
]]

local core = exports.dm_core
local PANEL = "shop"
local panel = { open = false, tick = 0, tab = "tags", confirm = nil }
local SHOP, VIP
local clicks = {}

local function s(v) return UI.s(v) end
local function sound(n, v) core:playUISound(n, v) end
UI.sound = sound
local function formatMoney(v) return core:formatMoney(v) end
local function rgbToHex(r, g, b) return string.format("#%02X%02X%02X", r, g, b) end

local function cfg()
    if not SHOP then SHOP = core:getShopConfig() VIP = core:getVipConfig() end
end

local function hasPerk(key)
    local perks = getElementData(localPlayer, "dm:perks")
    return type(perks) == "table" and perks[key] == true
end

local function money() return tonumber(getElementData(localPlayer, "dm:money")) or 0 end

local TABS = { { "tags", "TAGS" }, { "nameColors", "CORES DE NICK" }, { "vip", "VIP" }, { "extras", "EXTRAS" } }

local function itemCard(x, y, w, h, a, title, subtitle, price, color, state, onClick, badge)
    local hover = UI.isMouseIn(x, y, w, h)
    UI.rect(x, y, w, h, UI.color("card2", (hover and 255 or 225) * a), s(10))
    UI.border(x, y, w, h, state == "equipped" and UI.rgb(color, 220 * a) or tocolor(255, 255, 255, (hover and 50 or 20) * a), s(10))
    UI.rect(x, y + s(14), s(5), h - s(28), UI.rgb(color, 255 * a), s(2))
    UI.text(title, x + s(20), y + s(12), w - s(40), s(20), UI.rgb(color, 255 * a), "bold", 13, "left", "center", true)
    UI.text(subtitle, x + s(20), y + s(34), w - s(40), s(32), UI.color("muted", 255 * a), "regular", 9, "left", "top", false, true)
    if badge then UI.pill(badge, x + w - UI.textWidth(badge, "semibold", 8) - s(32), y + s(12), s(18), UI.color("gold", 50 * a), UI.color("gold", 255 * a), "semibold", 8) end
    local bw, bh = s(110), s(28)
    local bx, by = x + w - bw - s(14), y + h - bh - s(12)
    local label, kind, disabled
    if state == "equipped" then label, kind, disabled = "EQUIPADO", "ghost", true
    elseif state == "owned" then label, kind = "EQUIPAR", "outline"
    elseif panel.confirm == title then label, kind = "CONFIRMAR?", "primary"
    else label, kind = formatMoney(price), money() >= price and "primary" or "outline" end
    UI.button("shop_" .. title, label, bx, by, bw, bh, { kind = kind, size = 9, alpha = a, disabled = disabled, color = state == nil and "gold" or nil })
    if state ~= "equipped" then
        clicks[#clicks + 1] = { bx, by, bw, bh, function()
            if state == "owned" then onClick() return end
            if panel.confirm == title then panel.confirm = nil onClick()
            else panel.confirm = title sound("click", 0.4) end
        end }
    end
    if state == nil then
        UI.text(money() >= price and "Você tem saldo" or "Saldo insuficiente", x + s(20), by, bx - x - s(30), bh, money() >= price and UI.color("success", 200 * a) or UI.color("danger", 200 * a), "regular", 8, "left", "center")
    end
end

local function render()
    local progress = UI.openProgress(panel)
    if progress <= 0 then
        if not panel.open then removeEventHandler("onClientRender", root, render) end
        return
    end
    cfg()
    local a = progress
    clicks = {}
    local w, h = s(900), s(600)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + (1 - a) * s(20)
    local pad = s(28)
    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 5, 12, 170 * a))
    UI.card(x, y, w, h, s(16), a, "gold")
    UI.image("coin.png", x + pad, y + pad - s(2), s(30), s(30), tocolor(255, 255, 255, 255 * a))
    UI.text("LOJA", x + pad + s(40), y + pad - s(4), w, s(30), UI.color("text", 255 * a), "bold", 24, "left", "center")
    UI.text("Kills, duelos, tempo online e ranqueadas dão $. Compre uma vez, equipe quando quiser.", x + pad, y + pad + s(28), w, s(20), UI.color("muted", 255 * a), "regular", 11, "left", "center")
    local bal = "SALDO  " .. formatMoney(money())
    local bw = UI.textWidth(bal, "bold", 12) + s(28)
    UI.pill(bal, x + w - pad - bw - s(44), y + pad, s(30), UI.color("gold", 40 * a), UI.color("gold", 255 * a), "bold", 12, s(14))
    local cx, cy = x + w - pad - s(32), y + pad - s(6)
    UI.button("shop_close", "×", cx, cy, s(32), s(32), { kind = "ghost", size = 14, alpha = a })
    clicks[#clicks + 1] = { cx, cy, s(32), s(32), function() closeShop() end }

    -- abas
    local tx = x + pad
    local ty = y + pad + s(60)
    for _, t in ipairs(TABS) do
        local tw = UI.textWidth(t[2], "semibold", 10) + s(32)
        local sel = panel.tab == t[1]
        UI.rect(tx, ty, tw, s(32), sel and UI.color("accent", 60 * a) or tocolor(255, 255, 255, (UI.isMouseIn(tx, ty, tw, s(32)) and 14 or 6) * a), s(8))
        if sel then UI.border(tx, ty, tw, s(32), UI.color("accent", 200 * a), s(8)) end
        UI.text(t[2], tx, ty, tw, s(32), sel and UI.color("text", 255 * a) or UI.color("muted", 255 * a), "semibold", 10, "center", "center")
        local key = t[1]
        clicks[#clicks + 1] = { tx, ty, tw, s(32), function() panel.tab = key panel.confirm = nil sound("click", 0.4) end }
        tx = tx + tw + s(8)
    end

    -- itens
    local gy = ty + s(48)
    local cols = 2
    local cw = (w - pad * 2 - s(16)) / cols
    local ch = s(118)
    local i = 0
    local function place(fn)
        local col = i % cols
        local row = math.floor(i / cols)
        fn(x + pad + col * (cw + s(16)), gy + row * (ch + s(14)), cw, ch)
        i = i + 1
    end
    local currentTag = nil
    local tagData = getElementData(localPlayer, "dm:tag")
    local vipLevel = tonumber(getElementData(localPlayer, "dm:vip")) or 0

    if panel.tab == "tags" then
        for _, item in ipairs(SHOP.tags) do
            local owned = hasPerk("tag:" .. item.key)
            local equipped = owned and type(tagData) == "table" and tagData.kind == "shop" and tagData.text == (item.custom and tagData.text or item.text) and (item.custom and true or tagData.text == item.text)
            local state = equipped and "equipped" or (owned and "owned" or nil)
            place(function(ix, iy, iw, ih)
                itemCard(ix, iy, iw, ih, a, item.custom and "TAG PERSONALIZADA" or item.text,
                    item.custom and "Escolha seu próprio texto (2-12 caracteres) com /tag <texto>. Aparece no chat, no placar e sobre o seu boneco." or "Tag exibida no chat, no placar e acima do seu nick.",
                    item.price, item.color, state, function() triggerServerEvent("shop:buy", localPlayer, "tags", item.key) end)
            end)
        end
        place(function(ix, iy, iw, ih)
            itemCard(ix, iy, iw, ih, a, "USAR TAG DO ELO", "Remove a tag comprada e volta a exibir o seu elo (Bronze, Prata, Ouro...).", 0, { 150, 155, 180 }, "owned",
                function() triggerServerEvent("shop:buy", localPlayer, "unequip", "tag") end)
        end)
    elseif panel.tab == "nameColors" then
        local current = getElementData(localPlayer, "dm:nameColor")
        for _, item in ipairs(SHOP.nameColors) do
            local owned = hasPerk("color:" .. item.key)
            local equipped = owned and current == rgbToHex(unpack(item.color))
            place(function(ix, iy, iw, ih)
                itemCard(ix, iy, iw, ih, a, item.name:upper(), "Cor do seu nick no chat, no placar e sobre o boneco.", item.price, item.color,
                    equipped and "equipped" or (owned and "owned" or nil), function() triggerServerEvent("shop:buy", localPlayer, "nameColors", item.key) end)
            end)
        end
        place(function(ix, iy, iw, ih)
            itemCard(ix, iy, iw, ih, a, "COR PADRÃO", "Volta o nick para branco (ou a cor do seu VIP).", 0, { 150, 155, 180 }, "owned",
                function() triggerServerEvent("shop:buy", localPlayer, "unequip", "color") end)
        end)
    elseif panel.tab == "vip" then
        for level = 1, 3 do
            local item = VIP[level]
            local mult = core:getEconomyConfig().vipMultiplier[level]
            place(function(ix, iy, iw, ih)
                itemCard(ix, iy, iw, ih, a, item.name:upper(),
                    ("%d dias · %.2fx de $ em kills · bônus diário %s · respawn rápido · nick colorido · todas as skins · tag %s"):format(item.days, mult, formatMoney(item.daily), item.tag),
                    item.price, item.color, vipLevel == level and "equipped" or nil,
                    function() triggerServerEvent("shop:buy", localPlayer, "vip", tostring(level)) end, vipLevel == level and "ATIVO" or nil)
            end)
        end
    elseif panel.tab == "extras" then
        for _, item in ipairs(SHOP.extras) do
            place(function(ix, iy, iw, ih)
                itemCard(ix, iy, iw, ih, a, item.name:upper(), item.desc, item.price, { 34, 211, 238 }, hasPerk(item.key) and "equipped" or nil,
                    function() triggerServerEvent("shop:buy", localPlayer, "extras", item.key) end)
            end)
        end
    end

    UI.divider(x + pad, y + h - s(52), w - pad * 2, 18 * a)
    UI.text("F4 ou ESC fecha  ·  Clique duas vezes no preço para confirmar a compra  ·  /saldo  /pagar <jogador> <valor>", x + pad, y + h - s(44), w - pad * 2, s(30), UI.color("muted", 200 * a), "regular", 10, "left", "center")
end

local function onClick(button, state)
    if button ~= "left" or state ~= "down" or not panel.open then return end
    for _, c in ipairs(clicks) do
        if UI.isMouseIn(c[1], c[2], c[3], c[4]) then c[5]() return end
    end
    panel.confirm = nil
end

function openShop()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    panel.confirm = nil
    addEventHandler("onClientRender", root, render)
    addEventHandler("onClientClick", root, onClick)
    sound("click", 0.4)
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
addEventHandler("shop:result", root, function(ok) sound(ok and "levelup" or "error", 0.5) end)
