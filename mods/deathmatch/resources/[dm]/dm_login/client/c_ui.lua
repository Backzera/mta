--[[
    UI Lib · utilitários dx para uma interface moderna (2026)
    Este arquivo é copiado para dm_duel e dm_login (mesma API).
    As fontes vêm sempre de :dm_core/assets/fonts.
]]

UI = UI or {}

local sw, sh = guiGetScreenSize()
UI.sw, UI.sh = sw, sh
UI.scale = math.max(0.75, math.min(1.25, math.min(sw / 1920, sh / 1080)))
UI.FONT_PATHS = {
    regular  = ":dm_core/assets/fonts/Poppins-Regular.ttf",
    medium   = ":dm_core/assets/fonts/Poppins-Medium.ttf",
    semibold = ":dm_core/assets/fonts/Poppins-SemiBold.ttf",
    bold     = ":dm_core/assets/fonts/Poppins-Bold.ttf",
}

function UI.s(v) return v * UI.scale end

-- Paleta: reutiliza DM.colors quando disponível
local palette = (DM and DM.colors) or {
    bg = { 6, 10, 8 }, card = { 12, 18, 14 }, card2 = { 18, 27, 21 }, border = { 255, 255, 255 },
    accent = { 34, 230, 138 }, accent2 = { 120, 255, 180 }, gold = { 245, 196, 81 }, success = { 34, 230, 138 },
    danger = { 255, 77, 109 }, warn = { 255, 181, 71 }, info = { 120, 255, 180 }, text = { 240, 245, 242 },
    muted = { 140, 160, 150 }, health = { 34, 230, 138 }, armor = { 120, 210, 255 }, money = { 245, 196, 81 },
}
UI.IMG = ":dm_core/assets/img/"
UI.palette = palette

function UI.color(name, alpha)
    local c = palette[name] or palette.text
    return tocolor(c[1], c[2], c[3], alpha or 255)
end

function UI.rgb(c, alpha)
    return tocolor(c[1], c[2], c[3], alpha or 255)
end

function UI.hex(c)
    return string.format("#%02X%02X%02X", c[1], c[2], c[3])
end

-- ---------- Fontes ----------
local fontCache = {}
function UI.font(kind, size)
    kind = kind or "regular"
    size = size or 12
    local key = kind .. ":" .. size
    if fontCache[key] ~= nil then return fontCache[key] end
    local path = UI.FONT_PATHS[kind] or UI.FONT_PATHS.regular
    local font = false
    if fileExists(path) then
        font = dxCreateFont(path, math.max(6, math.floor(UI.s(size) + 0.5)), false, "antialiased")
    end
    if not font then
        font = (kind == "bold" or kind == "semibold") and "default-bold" or "default"
    end
    fontCache[key] = font
    return font
end

-- Escala para fontes nativas (quando a fonte .ttf falhou)
local function fontScale(font, size)
    if type(font) == "string" then return UI.s(size) / 10 end
    return 1
end

function UI.textWidth(text, kind, size)
    local font = UI.font(kind, size)
    return dxGetTextWidth(tostring(text), fontScale(font, size), font, true)
end

function UI.textHeight(kind, size)
    local font = UI.font(kind, size)
    return dxGetFontHeight(fontScale(font, size), font)
end

-- Desenha texto. align: "left" | "center" | "right"; valign: "top" | "center" | "bottom"
function UI.text(text, x, y, w, h, color, kind, size, align, valign, clip, wordBreak, colorCoded)
    local font = UI.font(kind, size)
    dxDrawText(tostring(text), x, y, x + (w or 0), y + (h or 0), color or UI.color("text"), fontScale(font, size), font,
        align or "left", valign or "top", clip or false, wordBreak or false, false, colorCoded or false, true)
end

-- Texto com sombra sutil
function UI.textShadow(text, x, y, w, h, color, kind, size, align, valign, colorCoded)
    local font = UI.font(kind, size)
    local sc = fontScale(font, size)
    local off = math.max(1, UI.s(1.2))
    dxDrawText(DM and DM.stripColors(tostring(text)) or tostring(text), x + off, y + off, x + (w or 0) + off, y + (h or 0) + off,
        tocolor(0, 0, 0, 150), sc, font, align or "left", valign or "top", false, false, false, false, true)
    dxDrawText(tostring(text), x, y, x + (w or 0), y + (h or 0), color or UI.color("text"), sc, font,
        align or "left", valign or "top", false, false, false, colorCoded or false, true)
end

-- ---------- Formas ----------
function UI.rect(x, y, w, h, color, radius, postGUI)
    radius = math.min(radius or 0, w / 2, h / 2)
    if radius < 1 then
        dxDrawRectangle(x, y, w, h, color, postGUI)
        return
    end
    dxDrawRectangle(x + radius, y, w - radius * 2, h, color, postGUI)
    dxDrawRectangle(x, y + radius, radius, h - radius * 2, color, postGUI)
    dxDrawRectangle(x + w - radius, y + radius, radius, h - radius * 2, color, postGUI)
    local seg = radius > 12 and 16 or 10
    dxDrawCircle(x + radius, y + radius, radius, 180, 270, color, color, seg, 1, postGUI)
    dxDrawCircle(x + w - radius, y + radius, radius, 270, 360, color, color, seg, 1, postGUI)
    dxDrawCircle(x + w - radius, y + h - radius, radius, 0, 90, color, color, seg, 1, postGUI)
    dxDrawCircle(x + radius, y + h - radius, radius, 90, 180, color, color, seg, 1, postGUI)
end

-- Borda fina (1px) com cantos arredondados simulados
function UI.border(x, y, w, h, color, radius)
    radius = math.min(radius or 0, w / 2, h / 2)
    local t = 1
    dxDrawRectangle(x + radius, y, w - radius * 2, t, color)
    dxDrawRectangle(x + radius, y + h - t, w - radius * 2, t, color)
    dxDrawRectangle(x, y + radius, t, h - radius * 2, color)
    dxDrawRectangle(x + w - t, y + radius, t, h - radius * 2, color)
end

-- Card padrão UTG: fundo escuro, borda sutil, linha de destaque no topo
function UI.card(x, y, w, h, radius, alphaMul, accentName)
    alphaMul = alphaMul or 1
    radius = radius or UI.s(12)
    UI.rect(x + UI.s(2), y + UI.s(5), w, h, tocolor(0, 0, 0, 110 * alphaMul), radius) -- sombra
    UI.rect(x, y, w, h, UI.color("card", 240 * alphaMul), radius)
    UI.rect(x, y, w, h / 2, tocolor(255, 255, 255, 5 * alphaMul), radius)
    UI.border(x, y, w, h, tocolor(255, 255, 255, 24 * alphaMul), radius)
    if accentName ~= false then
        local c = palette[accentName or "accent"]
        UI.gradientH(x + radius, y, (w - radius * 2) * 0.6, UI.s(2), { c[1], c[2], c[3], 230 * alphaMul }, { c[1], c[2], c[3], 0 }, 20)
    end
end

-- Imagem dos assets do dm_core (cache de existência)
local imgCache = {}
function UI.image(name, x, y, w, h, color, rotation)
    local path = imgCache[name]
    if path == nil then
        local p = UI.IMG .. name
        path = fileExists(p) and p or false
        imgCache[name] = path
    end
    if not path then return false end
    dxDrawImage(x, y, w, h, path, rotation or 0, 0, 0, color or tocolor(255, 255, 255, 255))
    return true
end

-- Pílula de tag { text, hex } (hex "#RRGGBB")
function UI.hexToRGB(hex)
    if type(hex) ~= "string" or #hex < 7 then return 255, 255, 255 end
    return tonumber(hex:sub(2, 3), 16) or 255, tonumber(hex:sub(4, 5), 16) or 255, tonumber(hex:sub(6, 7), 16) or 255
end
function UI.tagPill(tag, x, y, h, alpha, size)
    if type(tag) ~= "table" or not tag.text then return 0 end
    alpha = alpha or 1
    local r, g, b = UI.hexToRGB(tag.hex)
    return UI.pill(tag.text, x, y, h, tocolor(r, g, b, 45 * alpha), tocolor(r, g, b, 255 * alpha), "bold", size or 8, UI.s(8))
end

-- Gradiente horizontal simples (n faixas)
function UI.gradientH(x, y, w, h, c1, c2, steps, radius)
    steps = steps or 24
    local sw_ = w / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local r = c1[1] + (c2[1] - c1[1]) * t
        local g = c1[2] + (c2[2] - c1[2]) * t
        local b = c1[3] + (c2[3] - c1[3]) * t
        local a = (c1[4] or 255) + ((c2[4] or 255) - (c1[4] or 255)) * t
        dxDrawRectangle(x + i * sw_, y, sw_ + 1, h, tocolor(r, g, b, a))
    end
end

-- Barra de progresso arredondada
function UI.bar(x, y, w, h, progress, colorFill, colorBg, radius)
    progress = math.max(0, math.min(1, progress or 0))
    radius = radius or h / 2
    UI.rect(x, y, w, h, colorBg or tocolor(255, 255, 255, 18), radius)
    if progress > 0 then
        UI.rect(x, y, math.max(h, w * progress), h, colorFill, radius)
    end
end

-- ---------- Mouse ----------
function UI.mouse()
    if not isCursorShowing() then return nil, nil end
    local cx, cy = getCursorPosition()
    if not cx then return nil, nil end
    return cx * sw, cy * sh
end

function UI.isMouseIn(x, y, w, h)
    local mx, my = UI.mouse()
    if not mx then return false end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- ---------- Animação ----------
function UI.ease(t)
    t = math.max(0, math.min(1, t))
    return 1 - (1 - t) ^ 3
end

-- Interpolação de progresso de abertura. state = { open=bool, tick=ms }
function UI.openProgress(state, duration)
    duration = duration or 180
    local t = (getTickCount() - (state.tick or 0)) / duration
    t = math.max(0, math.min(1, t))
    if state.open then return UI.ease(t) end
    return 1 - UI.ease(t)
end

-- ---------- Botão ----------
-- opts: { kind="primary"|"ghost"|"danger"|"outline", radius, size, font, disabled, icon }
function UI.button(id, text, x, y, w, h, opts)
    opts = opts or {}
    local hover = UI.isMouseIn(x, y, w, h) and not opts.disabled
    local kind = opts.kind or "primary"
    local radius = opts.radius or UI.s(10)
    local alpha = opts.alpha or 1
    local bgColor, textColor
    if kind == "primary" then
        local c = palette[opts.color or "accent"]
        bgColor = tocolor(c[1], c[2], c[3], (hover and 255 or 220) * alpha)
        textColor = tocolor(8, 12, 18, 255 * alpha)
    elseif kind == "danger" then
        bgColor = UI.color("danger", (hover and 255 or 215) * alpha)
        textColor = tocolor(255, 255, 255, 255 * alpha)
    elseif kind == "outline" then
        bgColor = tocolor(255, 255, 255, (hover and 26 or 12) * alpha)
        textColor = UI.color("text", 255 * alpha)
    else -- ghost
        bgColor = tocolor(255, 255, 255, (hover and 18 or 0) * alpha)
        textColor = UI.color(hover and "text" or "muted", 255 * alpha)
    end
    if opts.disabled then
        bgColor = tocolor(255, 255, 255, 10 * alpha)
        textColor = UI.color("muted", 160 * alpha)
    end
    UI.rect(x, y, w, h, bgColor, radius)
    if kind == "outline" then UI.border(x, y, w, h, tocolor(255, 255, 255, 40 * alpha), radius) end
    UI.text(text, x, y, w, h, textColor, opts.font or "semibold", opts.size or 12, "center", "center")
    if hover and UI._hoverId ~= id then
        UI._hoverId = id
        if UI.sound then UI.sound("hover") end
    elseif not hover and UI._hoverId == id then
        UI._hoverId = nil
    end
    return hover
end

-- ---------- Gerenciador de painéis ----------
-- Um painel por vez em todo o cliente (compartilhado entre recursos via elementData).
function UI.getOpenPanel()
    local p = getElementData(localPlayer, "dm:panel")
    return p and p ~= false and p or nil
end

function UI.canOpenPanel(name)
    local open = UI.getOpenPanel()
    return not open or open == name
end

function UI.setPanelOpen(name, open)
    local current = UI.getOpenPanel()
    if open then
        if current and current ~= name then return false end
        setElementData(localPlayer, "dm:panel", name, false)
        showCursor(true)
        toggleAllControls(false, true, false)
        return true
    else
        if current == name then
            setElementData(localPlayer, "dm:panel", false, false)
            showCursor(false)
            toggleAllControls(true, true, true)
        end
        return true
    end
end

-- ESC fecha o painel aberto (e não abre o menu do MTA)
UI.escapeHandlers = UI.escapeHandlers or {}
function UI.registerEscape(panelName, fn)
    UI.escapeHandlers[panelName] = fn
end
addEventHandler("onClientKey", root, function(key, press)
    if key ~= "escape" or not press then return end
    local open = UI.getOpenPanel()
    if open and UI.escapeHandlers[open] then
        UI.escapeHandlers[open]()
        cancelEvent()
    end
end)

-- ---------- Campo de texto (dx) ----------
-- field = { text="", focus=false, masked=false, placeholder="", maxLength=24 }
UI.inputs = UI.inputs or {}

function UI.inputField(field, x, y, w, h, opts)
    opts = opts or {}
    local radius = opts.radius or UI.s(10)
    local hover = UI.isMouseIn(x, y, w, h)
    UI.rect(x, y, w, h, tocolor(255, 255, 255, field.focus and 16 or 10), radius)
    UI.border(x, y, w, h, field.focus and UI.color("accent", 200) or tocolor(255, 255, 255, hover and 50 or 28), radius)
    local pad = UI.s(14)
    local shown = field.text or ""
    if field.masked then shown = string.rep("•", utf8.len(shown) or #shown) end
    if shown == "" and not field.focus then
        UI.text(field.placeholder or "", x + pad, y, w - pad * 2, h, UI.color("muted", 180), "regular", opts.size or 12, "left", "center")
    else
        local caret = (field.focus and (getTickCount() % 1000) < 500) and "|" or ""
        UI.text(shown .. caret, x + pad, y, w - pad * 2, h, UI.color("text"), "regular", opts.size or 12, "left", "center", true)
    end
    field._bounds = { x, y, w, h }
    return hover
end

-- Chamada única: registra handlers de teclado para campos
local function anyFocused(fields)
    for _, f in ipairs(fields) do if f.focus then return f end end
    return nil
end

function UI.bindInputs(fields, onEnter)
    local state = { fields = fields, onEnter = onEnter }
    state.onChar = function(char)
        local f = anyFocused(fields)
        if not f then return end
        if (utf8.len(f.text) or #f.text) >= (f.maxLength or 24) then return end
        if f.allowed and not char:match(f.allowed) then return end
        f.text = f.text .. char
    end
    state.onKey = function(key, press)
        local f = anyFocused(fields)
        if not f then return end
        if not press then return end
        if key == "backspace" then
            local len = utf8.len(f.text) or #f.text
            if len > 0 then f.text = utf8.sub and utf8.sub(f.text, 1, len - 1) or f.text:sub(1, -2) end
            cancelEvent()
        elseif key == "enter" or key == "num_enter" then
            if onEnter then onEnter(f) end
            cancelEvent()
        elseif key == "tab" then
            for i, fld in ipairs(fields) do
                if fld == f then
                    fld.focus = false
                    fields[(i % #fields) + 1].focus = true
                    break
                end
            end
            cancelEvent()
        elseif key ~= "escape" and not key:match("^F%d+$") and not key:match("^mouse") then
            cancelEvent() -- bloqueia binds enquanto digita
        end
    end
    state.onClick = function(button, pressState)
        if button ~= "left" or pressState ~= "down" then return end
        for _, fld in ipairs(fields) do
            local b = fld._bounds
            fld.focus = b and UI.isMouseIn(b[1], b[2], b[3], b[4]) or false
        end
    end
    addEventHandler("onClientCharacter", root, state.onChar)
    addEventHandler("onClientKey", root, state.onKey)
    addEventHandler("onClientClick", root, state.onClick)
    return state
end

function UI.unbindInputs(state)
    if not state then return end
    removeEventHandler("onClientCharacter", root, state.onChar)
    removeEventHandler("onClientKey", root, state.onKey)
    removeEventHandler("onClientClick", root, state.onClick)
    for _, f in ipairs(state.fields) do f.focus = false end
end

-- ---------- Diversos ----------
function UI.formatNumber(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end

function UI.clamp(v, a, b) return math.max(a, math.min(b, v)) end

function UI.truncate(text, kind, size, maxWidth)
    text = tostring(text)
    if UI.textWidth(text, kind, size) <= maxWidth then return text end
    local len = utf8.len(text) or #text
    while len > 1 do
        len = len - 1
        local cut = utf8.sub and utf8.sub(text, 1, len) or text:sub(1, len)
        if UI.textWidth(cut .. "…", kind, size) <= maxWidth then return cut .. "…" end
    end
    return "…"
end

-- Divisor
function UI.divider(x, y, w, alpha)
    dxDrawRectangle(x, y, w, 1, tocolor(255, 255, 255, alpha or 20))
end

-- Pílula (tag)
function UI.pill(text, x, y, h, colorBg, colorText, kind, size, padX)
    padX = padX or UI.s(10)
    local w = UI.textWidth(text, kind or "semibold", size or 10) + padX * 2
    UI.rect(x, y, w, h, colorBg, h / 2)
    UI.text(text, x, y, w, h, colorText, kind or "semibold", size or 10, "center", "center")
    return w
end
