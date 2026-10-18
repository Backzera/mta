--[[
    LOJA (F4) — composição em tela cheia sobre a cena desfocada:
      · navegação lateral esquerda por categoria (Tags · Cores de nick · VIP · Extras) com ícones
      · cabeçalho da categoria com título, descrição e cartão de saldo
      · grade de produtos 3 colunas: faixa de cor, nome, descrição, preço, estado (comprar /
        confirmar / equipar / equipado / sem saldo) com ações reais (shop:buy / unequip)
    Protocolo preservado: shop:buy, shop:open, shop:result, F4, ESC, openShop/closeShop.
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

local CATS = {
    { key = "tags", label = "Tags", icon = "tag.png", title = "TAGS", desc = "Exibidas no chat, no placar e acima do seu nick." },
    { key = "nameColors", label = "Cores de nick", icon = "target.png", title = "CORES DE NICK", desc = "Cor do seu nome em todo o servidor." },
    { key = "vip", label = "VIP", icon = "crown.png", title = "VIP", desc = "Mais $, bônus diário maior, respawn rápido, skins e tag." },
    { key = "extras", label = "Extras", icon = "shield.png", title = "EXTRAS", desc = "Vantagens permanentes para a sua conta." },
}

-- Produto. state: "buy" | "owned" | "equipped"; extra.color = cor do produto; extra.sample = texto de amostra
local function product(id, x, y, w, h, a, title, desc, price, color, state, onAction, badge, sample)
    local hovering = UI.isMouseIn(x, y, w, h)
    local t = UI.hover("shop:p:" .. id, hovering)
    local afford = money() >= price
    local locked = state == "buy" and not afford
    local ca = locked and a * 0.75 or a
    UI.rrect(x, y - s(2) * t, w, h + s(2) * t, tocolor(10, 14, 12, (228 + 20 * t) * ca), s(12), {
        border = 1, borderColor = state == "equipped" and UI.rgb(color, 200 * ca) or tocolor(255, 255, 255, (22 + 40 * t) * ca),
        glow = state == "equipped" and s(10) or s(10) * t, glowColor = UI.rgb(color, (state == "equipped" and 70 or 50) * ca),
    })
    -- faixa de cor no topo
    UI.rrect(x, y - s(2) * t, w, s(56), UI.rgb(color, (locked and 40 or 90) * ca), s(12), { gradient = UI.rgb(color, 10 * ca), gradientMode = 1 })
    UI.rrect(x, y + s(44) - s(2) * t, w, s(12), tocolor(10, 14, 12, (228 + 20 * t) * ca), 0)
    UI.text(title, x + s(16), y + s(12), w - s(32), s(26), locked and UI.color("muted", 255 * a) or UI.color("text", 255 * ca), "bold", 13, "left", "center", true)
    if badge then
        local bw = UI.textWidth(badge, "bold", 7) + s(14)
        UI.rrect(x + w - bw - s(14), y + s(16), bw, s(18), UI.rgb(color, 230 * ca), s(9))
        UI.text(badge, x + w - bw - s(14), y + s(16), bw, s(18), tocolor(10, 14, 12, 255 * ca), "bold", 7, "center", "center")
    end
    UI.text(desc, x + s(16), y + s(64), w - s(32), s(44), UI.color("muted", 255 * ca), "regular", 9, "left", "top", false, true)
    if sample then UI.text(sample, x + s(16), y + s(106), w - s(32), s(18), UI.rgb(color, 255 * ca), "bold", 11, "left", "center") end
    -- rodapé: preço / estado + botão
    UI.divider(x + s(16), y + h - s(54), w - s(32), 18 * ca)
    local bw, bh = s(118), s(30)
    local bx, by = x + w - bw - s(14), y + h - bh - s(12)
    if state == "equipped" then
        UI.text("EM USO", x + s(16), by, s(120), bh, UI.rgb(color, 255 * ca), "semibold", 9, "left", "center")
        UI.rrect(bx, by, bw, bh, UI.rgb(color, 36 * ca), s(8), { border = 1, borderColor = UI.rgb(color, 150 * ca) })
        UI.text("EQUIPADO", bx, by, bw, bh, UI.rgb(color, 255 * ca), "semibold", 9, "center", "center")
    elseif state == "owned" then
        UI.text("ADQUIRIDO", x + s(16), by, s(120), bh, UI.color("success", 255 * ca), "semibold", 9, "left", "center")
        UI.button("shop:btn:" .. id, "EQUIPAR", bx, by, bw, bh, { kind = "outline", size = 9, alpha = ca, onClick = onAction })
    else
        local confirming = panel.confirm == id and getTickCount() - panel.confirmTick < 4000
        UI.text(formatMoney(price), x + s(16), by - s(2), s(140), bh, locked and UI.color("danger", 255 * a) or UI.color("gold", 255 * ca), "bold", 13, "left", "center")
        if locked then
            UI.text("saldo insuficiente", x + s(16), by + s(14), s(140), s(14), UI.color("danger", 220 * a), "regular", 7, "left", "center")
            UI.rrect(bx, by, bw, bh, tocolor(255, 255, 255, 8 * a), s(8), { border = 1, borderColor = tocolor(255, 255, 255, 16 * a) })
            UI.text("BLOQUEADO", bx, by, bw, bh, UI.color("muted", 200 * a), "semibold", 9, "center", "center")
        else
            UI.button("shop:btn:" .. id, confirming and "CONFIRMAR" or "COMPRAR", bx, by, bw, bh, { kind = "primary", color = confirming and "warn" or "accent", size = 9, alpha = ca,
                onClick = function()
                    if confirming then panel.confirm = nil onAction()
                    else panel.confirm = id panel.confirmTick = getTickCount() end
                end })
            if confirming then UI.text("clique de novo para confirmar", x + s(16), by + s(14), s(140), s(14), UI.color("warn", 220 * ca), "regular", 7, "left", "center") end
        end
    end
end

local function render()
    cfg()
    local raw = UI.clamp((UI.now - panel.tick) / 300, 0, 1)
    local a = panel.open and UI.ease(raw, "outCubic") or 1 - UI.ease(raw, "inCubic")
    if a <= 0.001 then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    UI.beginFrame()
    local G = s(24)
    UI.backdrop(a, 150, 2)
    -- moldura geral
    local fx, fy, fw, fh = s(120), s(70), UI.sw - s(240), UI.sh - s(140)
    local dy = (1 - a) * s(16)
    fy = fy + dy
    UI.rrect(fx, fy, fw, fh, tocolor(8, 12, 10, 225 * a), s(18), { border = 1, borderColor = tocolor(255, 255, 255, 26 * a) })

    -- navegação lateral
    local navW = s(230)
    UI.rrect(fx, fy, navW, fh, tocolor(6, 9, 8, 200 * a), s(18), { gradient = tocolor(6, 9, 8, 120 * a), gradientMode = 1 })
    UI.rrect(fx + navW - s(1), fy + s(20), s(1), fh - s(40), tocolor(255, 255, 255, 20 * a), 0)
    UI.image("coin.png", fx + G, fy + G, s(30), s(30), tocolor(255, 255, 255, 255 * a))
    UI.text("LOJA", fx + G + s(40), fy + G - s(2), navW, s(34), UI.color("text", 255 * a), "bold", 20, "left", "center")
    local ny = fy + G + s(60)
    for i, c in ipairs(CATS) do
        local p = UI.stagger(a, i, #CATS, 0.4)
        local x, y, w, h = fx + s(14), ny + (i - 1) * s(50), navW - s(28), s(44)
        local isSel = panel.tab == c.key
        local hv = UI.hover("shop:nav:" .. c.key, UI.isMouseIn(x, y, w, h))
        UI.rrect(x, y, w, h, isSel and UI.color("accent", 34 * a * p) or tocolor(255, 255, 255, (0 + 12 * hv) * a * p), s(10), isSel and { border = 1, borderColor = UI.color("accent", 150 * a * p) } or nil)
        if isSel then UI.rrect(x, y + s(10), s(3), h - s(20), UI.color("accent", 255 * a * p), s(2)) end
        UI.image(c.icon, x + s(14), y + s(12), s(20), s(20), isSel and UI.color("accent2", 255 * a * p) or UI.color("muted", 255 * a * p))
        UI.text(c.label, x + s(44), y, w, h, isSel and UI.color("text", 255 * a * p) or UI.color("muted", 255 * a * p), "semibold", 11, "left", "center")
        local key = c.key
        UI.addClick(x, y, w, h, function() panel.tab = key panel.confirm = nil end, "shop:nav:" .. key)
    end
    UI.text("F4 ou ESC fecha", fx + G, fy + fh - s(40), navW, s(20), UI.color("muted", 160 * a), "regular", 8, "left", "center")
    UI.text("/saldo · /pagar <id> <valor>", fx + G, fy + fh - s(26), navW, s(16), UI.color("muted", 140 * a), "regular", 8, "left", "center")

    -- cabeçalho da categoria
    local cat
    for _, c in ipairs(CATS) do if c.key == panel.tab then cat = c end end
    local cx, cy, cw = fx + navW + G, fy + G, fw - navW - G * 2
    UI.text(cat.title, cx, cy, cw, s(30), UI.color("text", 255 * a), "bold", 22, "left", "center")
    UI.text(cat.desc, cx, cy + s(30), cw, s(18), UI.color("muted", 255 * a), "regular", 10, "left", "center")
    -- cartão de saldo
    local balW, balH = s(220), s(56)
    local balX, balY = cx + cw - balW - s(44), cy - s(4)
    UI.rrect(balX, balY, balW, balH, UI.color("gold", 22 * a), s(12), { border = 1, borderColor = UI.color("gold", 120 * a) })
    UI.text("SEU SALDO", balX + s(14), balY + s(8), balW, s(14), UI.color("muted", 255 * a), "semibold", 7, "left", "center")
    UI.text(formatMoney(math.floor(UI.counter("shop:money", money(), 800) + 0.5)), balX + s(14), balY + s(24), balW, s(26), UI.color("gold", 255 * a), "bold", 16, "left", "center")
    UI.closeButton("shop:close", fx + fw - G - s(32), fy + G, closeShop, a)

    -- grade de produtos
    local gy = cy + s(76)
    local cols = 3
    local pw = (cw - s(16) * (cols - 1)) / cols
    local ph = s(190)
    local i, total = 0, 0
    local function place(fn)
        local col, row = i % cols, math.floor(i / cols)
        local p = UI.stagger(a, i + 1, math.max(1, total), 0.5)
        fn(cx + col * (pw + s(16)), gy + row * (ph + s(16)) + (1 - p) * s(12), pw, ph, a * p)
        i = i + 1
    end
    local tagData = getElementData(localPlayer, "dm:tag")
    local vipLevel = tonumber(getElementData(localPlayer, "dm:vip")) or 0

    if panel.tab == "tags" then
        total = #SHOP.tags + 1
        for _, item in ipairs(SHOP.tags) do
            local owned = hasPerk("tag:" .. item.key)
            local equipped = owned and type(tagData) == "table" and tagData.kind == "shop" and (item.custom or tagData.text == item.text)
            place(function(x, y, w, h, pa)
                product(item.key, x, y, w, h, pa, item.custom and "TAG PERSONALIZADA" or item.text,
                    item.custom and "Seu próprio texto (2 a 12 caracteres) com /tag <texto>." or "Tag com ícone no chat, no placar e acima do nick.",
                    item.price, item.color, equipped and "equipped" or (owned and "owned" or "buy"),
                    function() triggerServerEvent("shop:buy", localPlayer, "tags", item.key) end, nil, ("[%s %s]"):format(item.glyph or "", item.custom and "SUA TAG" or item.text))
            end)
        end
        place(function(x, y, w, h, pa)
            product("tag_none", x, y, w, h, pa, "TAG DO ELO", "Volta a exibir o seu elo (Bronze, Prata, Ouro...) no lugar da tag comprada.", 0, { 150, 165, 155 },
                (type(tagData) == "table" and tagData.kind == "tier") and "equipped" or "owned", function() triggerServerEvent("shop:buy", localPlayer, "unequip", "tag") end)
        end)
    elseif panel.tab == "nameColors" then
        total = #SHOP.nameColors + 1
        local current = getElementData(localPlayer, "dm:nameColor")
        for _, item in ipairs(SHOP.nameColors) do
            local owned = hasPerk("color:" .. item.key)
            local equipped = owned and current == rgbToHex(item.color[1], item.color[2], item.color[3])
            place(function(x, y, w, h, pa)
                product("color_" .. item.key, x, y, w, h, pa, item.name:upper(), "Cor do seu nick no chat, no placar e sobre o boneco.", item.price, item.color,
                    equipped and "equipped" or (owned and "owned" or "buy"), function() triggerServerEvent("shop:buy", localPlayer, "nameColors", item.key) end,
                    nil, (getPlayerName(localPlayer):gsub("#%x%x%x%x%x%x", "")))
            end)
        end
        place(function(x, y, w, h, pa)
            product("color_none", x, y, w, h, pa, "COR PADRÃO", "Nick branco (ou a cor do seu VIP).", 0, { 150, 165, 155 },
                (not current or current == "#FFFFFF") and "equipped" or "owned", function() triggerServerEvent("shop:buy", localPlayer, "unequip", "color") end)
        end)
    elseif panel.tab == "vip" then
        total = 3
        for level = 1, 3 do
            local item = VIP[level]
            local mult = ECO.vipMultiplier[level]
            place(function(x, y, w, h, pa)
                product("vip_" .. level, x, y, w, h, pa, item.name:upper(),
                    ("%d dias · %.2fx de $ · bônus diário %s · respawn rápido · nick colorido · todas as skins"):format(item.days, mult, formatMoney(item.daily)),
                    item.price, item.color, vipLevel == level and "equipped" or "buy",
                    function() triggerServerEvent("shop:buy", localPlayer, "vip", tostring(level)) end, vipLevel == level and "ATIVO" or nil, ("[%s %s]"):format(item.glyph or "★", item.tag))
            end)
        end
    elseif panel.tab == "extras" then
        total = #SHOP.extras
        for _, item in ipairs(SHOP.extras) do
            place(function(x, y, w, h, pa)
                product("extra_" .. item.key, x, y, w, h, pa, item.name:upper(), item.desc, item.price, { 120, 255, 180 }, hasPerk(item.key) and "equipped" or "buy",
                    function() triggerServerEvent("shop:buy", localPlayer, "extras", item.key) end)
            end)
        end
    end
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
