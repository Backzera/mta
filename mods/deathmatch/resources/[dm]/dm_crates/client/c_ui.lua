--[[
    UI v2 · framework de interface do UTG MATA-MATA
    ------------------------------------------------
    Shaders (cantos AA + brilho, blur, aurora, vinheta), motor de animação (tweens, molas,
    contadores), componentes (card de vidro, botões com hover animado, abas com indicador
    deslizante, barras com rastro, anéis, campos de texto, listas com rolagem suave),
    moldura padrão de painel (backdrop desfocado + cabeçalho + fechar) e registro de cliques.

    Este arquivo é copiado byte a byte para dm_duel, dm_login, dm_shop, dm_ranked e dm_clans.
    Fora do dm_core a global DM não existe: tudo aqui funciona sem ela.
    Assets e shaders vêm sempre de :dm_core/.
]]

UI = UI or {}

local sw, sh = guiGetScreenSize()
UI.sw, UI.sh = sw, sh
UI.scale = math.max(0.75, math.min(1.3, math.min(sw / 1920, sh / 1080)))
UI.RES = ":dm_core/"
UI.IMG = UI.RES .. "assets/img/"
UI.SHADERS = UI.RES .. "shaders/"
UI.FONT_PATHS = {
    regular  = UI.RES .. "assets/fonts/Poppins-Regular.ttf",
    medium   = UI.RES .. "assets/fonts/Poppins-Medium.ttf",
    semibold = UI.RES .. "assets/fonts/Poppins-SemiBold.ttf",
    bold     = UI.RES .. "assets/fonts/Poppins-Bold.ttf",
}

function UI.s(v) return v * UI.scale end
function UI.clamp(v, a, b) return math.max(a, math.min(b, v)) end
function UI.lerp(a, b, t) return a + (b - a) * t end

-- ============================================================
-- Paleta
-- ============================================================
local palette = (DM and DM.colors) or {
    bg = { 6, 10, 8 }, card = { 12, 18, 14 }, card2 = { 18, 27, 21 }, border = { 255, 255, 255 },
    accent = { 34, 230, 138 }, accent2 = { 120, 255, 180 }, gold = { 245, 196, 81 }, success = { 34, 230, 138 },
    danger = { 255, 77, 109 }, warn = { 255, 181, 71 }, info = { 120, 255, 180 }, text = { 240, 245, 242 },
    muted = { 140, 160, 150 }, health = { 34, 230, 138 }, armor = { 120, 210, 255 }, money = { 245, 196, 81 },
}
UI.palette = palette

function UI.color(name, alpha)
    local c = palette[name] or palette.text
    return tocolor(c[1], c[2], c[3], alpha or 255)
end
function UI.rgb(c, alpha) return tocolor(c[1], c[2], c[3], alpha or 255) end
function UI.hex(c) return string.format("#%02X%02X%02X", c[1], c[2], c[3]) end
function UI.hexToRGB(hex)
    if type(hex) ~= "string" or #hex < 7 then return 255, 255, 255 end
    return tonumber(hex:sub(2, 3), 16) or 255, tonumber(hex:sub(4, 5), 16) or 255, tonumber(hex:sub(6, 7), 16) or 255
end
function UI.mix(c1, c2, t)
    t = UI.clamp(t, 0, 1)
    return { c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t, c1[3] + (c2[3] - c1[3]) * t }
end
-- cor 0xAARRGGBB -> r,g,b,a
function UI.split(color)
    local a = math.floor(color / 16777216) % 256
    local r = math.floor(color / 65536) % 256
    local g = math.floor(color / 256) % 256
    local b = color % 256
    return r, g, b, a
end

-- ============================================================
-- Tempo / frame
-- ============================================================
UI.now = getTickCount()
UI.dt = 16
UI.frame = 0
addEventHandler("onClientPreRender", root, function(timeSlice)
    UI.now = getTickCount()
    UI.dt = math.min(100, timeSlice or 16)
    UI.frame = UI.frame + 1
end)

-- ============================================================
-- Easings
-- ============================================================
UI.easing = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return 1 - (1 - t) ^ 2 end,
    inOutQuad = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end,
    outCubic = function(t) return 1 - (1 - t) ^ 3 end,
    inCubic = function(t) return t * t * t end,
    inOutCubic = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end,
    outQuart = function(t) return 1 - (1 - t) ^ 4 end,
    outExpo = function(t) return t >= 1 and 1 or 1 - 2 ^ (-10 * t) end,
    outBack = function(t) local c1, c3 = 1.70158, 2.70158 return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 end,
    inBack = function(t) local c1, c3 = 1.70158, 2.70158 return c3 * t * t * t - c1 * t * t end,
    outElastic = function(t)
        if t <= 0 then return 0 elseif t >= 1 then return 1 end
        return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
    end,
    outBounce = function(t)
        local n1, d1 = 7.5625, 2.75
        if t < 1 / d1 then return n1 * t * t
        elseif t < 2 / d1 then t = t - 1.5 / d1 return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then t = t - 2.25 / d1 return n1 * t * t + 0.9375
        else t = t - 2.625 / d1 return n1 * t * t + 0.984375 end
    end,
}
function UI.ease(t, name)
    t = UI.clamp(t, 0, 1)
    return (UI.easing[name or "outCubic"] or UI.easing.outCubic)(t)
end

-- ============================================================
-- Motor de animação
-- ============================================================
local tweens = {}
-- UI.tween(id, target, duration, easing) -> valor animado em direção a target (reinicia do valor atual ao mudar o alvo)
function UI.tween(id, target, duration, easing)
    duration = duration or 300
    local tw = tweens[id]
    if not tw then
        tw = { from = target, to = target, start = UI.now, value = target }
        tweens[id] = tw
    end
    if tw.to ~= target then
        tw.from = tw.value
        tw.to = target
        tw.start = UI.now
    end
    local t = duration > 0 and UI.clamp((UI.now - tw.start) / duration, 0, 1) or 1
    tw.value = tw.from + (tw.to - tw.from) * UI.ease(t, easing)
    tw.touched = UI.now
    return tw.value
end

-- UI.spring(id, target, speed) -> aproximação exponencial suave (independente de FPS)
local springs = {}
function UI.spring(id, target, speed)
    speed = speed or 12
    local v = springs[id]
    if v == nil then v = target end
    v = v + (target - v) * (1 - math.exp(-UI.dt / 1000 * speed))
    if math.abs(target - v) < 0.0005 then v = target end
    springs[id] = v
    return v
end
function UI.resetSpring(id, value) springs[id] = value end
function UI.resetTween(id) tweens[id] = nil end

-- UI.hover(id, hovered) -> 0..1 animado
function UI.hover(id, hovered, speed) return UI.spring("hover:" .. tostring(id), hovered and 1 or 0, speed or 14) end

-- UI.counter(id, value, duration) -> número animado (dinheiro, RP, placar)
function UI.counter(id, value, duration) return UI.tween("counter:" .. tostring(id), tonumber(value) or 0, duration or 700, "outCubic") end

-- UI.pulse(period, min, max) -> oscilação senoidal
function UI.pulse(period, min, max)
    min, max = min or 0, max or 1
    return min + (max - min) * (0.5 + 0.5 * math.sin(UI.now / (period or 1000) * math.pi * 2))
end

-- Progresso por item para listas em cascata (0..1 cada)
function UI.stagger(progress, index, count, spread, easing)
    spread = spread or 0.5
    count = math.max(1, count)
    local start = ((index - 1) / count) * spread
    local t = UI.clamp((progress - start) / math.max(0.0001, 1 - spread), 0, 1)
    return UI.ease(t, easing or "outCubic")
end

-- limpeza periódica de tweens não usados
setTimer(function()
    for id, tw in pairs(tweens) do
        if tw.touched and UI.now - tw.touched > 30000 then tweens[id] = nil end
    end
end, 30000, 0)

-- ============================================================
-- Shaders
-- ============================================================
local shaders = {}
local shaderTried = {}
local function getShader(name)
    if shaders[name] ~= nil then return shaders[name] end
    if shaderTried[name] then return false end
    shaderTried[name] = true
    local path = UI.SHADERS .. name .. ".fx"
    local sh_ = fileExists(path) and dxCreateShader(path) or false
    shaders[name] = sh_ or false
    if not sh_ then outputDebugString("[ui] shader indisponível: " .. name .. " (usando fallback)", 2) end
    return shaders[name]
end
function UI.hasShader(name) return getShader(name) ~= false end
function UI.disableShaders() shaders = { rounded = false, blur = false, aurora = false, vignette = false } end

local function toFloat4(color)
    local r, g, b, a = UI.split(color)
    return r / 255, g / 255, b / 255, a / 255
end

-- ============================================================
-- Formas
-- ============================================================
local function rectPrimitive(x, y, w, h, color, radius, postGUI)
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

--[[
    UI.rrect(x, y, w, h, color, radius, opts)
    opts = { border = px, borderColor = cor, glow = px, glowColor = cor, gradient = cor2,
             gradientMode = 1 vertical | 2 horizontal | 3 diagonal, shine = 0..1, postGUI = bool }
]]
function UI.rrect(x, y, w, h, color, radius, opts)
    opts = opts or {}
    if w <= 0 or h <= 0 then return end
    radius = radius or 0
    local shader = getShader("rounded")
    if not shader then
        if opts.glow and opts.glow > 0 and opts.glowColor then
            local gr, gg, gb, ga = UI.split(opts.glowColor)
            rectPrimitive(x - 2, y - 2, w + 4, h + 4, tocolor(gr, gg, gb, ga * 0.35), radius + 2, opts.postGUI)
        end
        rectPrimitive(x, y, w, h, color, radius, opts.postGUI)
        if opts.border and opts.border > 0 and opts.borderColor then UI.border(x, y, w, h, opts.borderColor, radius) end
        return
    end
    local glow = opts.glow or 0
    if glow < 0.5 then glow = 0 end
    radius = math.min(radius, w / 2, h / 2)
    local r, g, b, a = toFloat4(color)
    dxSetShaderValue(shader, "sSize", w + glow * 2, h + glow * 2)
    dxSetShaderValue(shader, "sRadius", radius)
    dxSetShaderValue(shader, "sBorder", opts.border or 0)
    dxSetShaderValue(shader, "sGlow", glow)
    dxSetShaderValue(shader, "sGlowK", glow > 0 and (3 / glow) or 1)
    dxSetShaderValue(shader, "sShine", opts.shine or 0)
    dxSetShaderValue(shader, "sColor", r, g, b, a)
    if opts.gradient then
        local r2, g2, b2, a2 = toFloat4(opts.gradient)
        local mode = opts.gradientMode or 1
        dxSetShaderValue(shader, "sGradientOn", 1)
        dxSetShaderValue(shader, "sGradientX", mode == 2 and 1 or (mode == 3 and 0.5 or 0))
        dxSetShaderValue(shader, "sColor2", r2, g2, b2, a2)
    else
        dxSetShaderValue(shader, "sGradientOn", 0)
        dxSetShaderValue(shader, "sGradientX", 0)
        dxSetShaderValue(shader, "sColor2", r, g, b, a)
    end
    if opts.border and opts.border > 0 then
        local br, bg, bb, ba = toFloat4(opts.borderColor or tocolor(255, 255, 255, 30))
        dxSetShaderValue(shader, "sBorderColor", br, bg, bb, ba)
    else
        dxSetShaderValue(shader, "sBorderColor", 0, 0, 0, 0)
    end
    if glow > 0 then
        local gr, gg, gb, ga = toFloat4(opts.glowColor or UI.color("accent", 120))
        dxSetShaderValue(shader, "sGlowColor", gr, gg, gb, ga)
    else
        dxSetShaderValue(shader, "sGlowColor", 0, 0, 0, 0)
    end
    dxDrawImage(x - glow, y - glow, w + glow * 2, h + glow * 2, shader, 0, 0, 0, tocolor(255, 255, 255, 255), opts.postGUI or false)
end

-- Compatível com a v1: retângulo arredondado simples
function UI.rect(x, y, w, h, color, radius, postGUI)
    radius = radius or 0
    if radius >= 2 and getShader("rounded") then
        UI.rrect(x, y, w, h, color, radius, { postGUI = postGUI })
    else
        rectPrimitive(x, y, w, h, color, radius, postGUI)
    end
end

-- Borda fina de 1px (fallback sem shader; com shader prefira rrect{border=1})
function UI.border(x, y, w, h, color, radius)
    if getShader("rounded") then
        UI.rrect(x, y, w, h, tocolor(0, 0, 0, 0), radius or 0, { border = 1, borderColor = color })
        return
    end
    radius = math.min(radius or 0, w / 2, h / 2)
    dxDrawRectangle(x + radius, y, w - radius * 2, 1, color)
    dxDrawRectangle(x + radius, y + h - 1, w - radius * 2, 1, color)
    dxDrawRectangle(x, y + radius, 1, h - radius * 2, color)
    dxDrawRectangle(x + w - 1, y + radius, 1, h - radius * 2, color)
end

-- Brilho externo isolado (sem preenchimento)
function UI.glow(x, y, w, h, radius, size, color)
    UI.rrect(x, y, w, h, tocolor(0, 0, 0, 0), radius, { glow = size, glowColor = color })
end

-- Gradientes por faixas (sem shader) — úteis para linhas e barras
function UI.gradientH(x, y, w, h, c1, c2, steps, radius)
    steps = steps or 24
    local stepW = w / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        dxDrawRectangle(x + i * stepW, y, stepW + 1, h, tocolor(
            c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t, c1[3] + (c2[3] - c1[3]) * t,
            (c1[4] or 255) + ((c2[4] or 255) - (c1[4] or 255)) * t))
    end
end
function UI.gradientV(x, y, w, h, c1, c2, steps)
    steps = steps or 24
    local stepH = h / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        dxDrawRectangle(x, y + i * stepH, w, stepH + 1, tocolor(
            c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t, c1[3] + (c2[3] - c1[3]) * t,
            (c1[4] or 255) + ((c2[4] or 255) - (c1[4] or 255)) * t))
    end
end

-- Linha de destaque (gradiente que some) — usada em cabeçalhos
function UI.accentLine(x, y, w, h, c, alpha)
    alpha = alpha or 1
    UI.gradientH(x, y, w, h, { c[1], c[2], c[3], 230 * alpha }, { c[1], c[2], c[3], 0 }, 20)
end

-- Divisor sutil
function UI.divider(x, y, w, alpha)
    dxDrawRectangle(x, y, w, 1, tocolor(255, 255, 255, alpha or 16))
end

-- ============================================================
-- Fundo desfocado (blur) e efeitos de tela
-- ============================================================
local blur = { source = nil, rt = nil, lastUse = 0, frame = -1 }
local BLUR_DIV = 4

local function ensureBlur()
    if blur.source then return true end
    if not getShader("blur") then return false end
    blur.source = dxCreateScreenSource(math.floor(sw / BLUR_DIV), math.floor(sh / BLUR_DIV))
    if not blur.source then return false end
    blur.rt = dxCreateRenderTarget(math.floor(sw / BLUR_DIV), math.floor(sh / BLUR_DIV), false) or nil
    return true
end
local function releaseBlur()
    if blur.source and isElement(blur.source) then destroyElement(blur.source) end
    if blur.rt and isElement(blur.rt) then destroyElement(blur.rt) end
    blur.source, blur.rt = nil, nil
end
setTimer(function()
    if blur.source and UI.now - blur.lastUse > 3000 then releaseBlur() end
end, 1000, 0)

-- UI.backdrop(alpha, tintAlpha, strength): desfoca a tela inteira e escurece. alpha 0..1
function UI.backdrop(alpha, tintAlpha, strength)
    alpha = UI.clamp(alpha or 1, 0, 1)
    tintAlpha = tintAlpha == nil and 150 or tintAlpha
    local shader = getShader("blur")
    if alpha > 0.01 and shader and ensureBlur() then
        blur.lastUse = UI.now
        if blur.frame ~= UI.frame then
            blur.frame = UI.frame
            dxUpdateScreenSource(blur.source, true)
            if blur.rt then
                -- passagem 1: fonte -> render target
                dxSetRenderTarget(blur.rt, true)
                dxSetShaderValue(shader, "sTex", blur.source)
                dxSetShaderValue(shader, "sTexel", BLUR_DIV / sw, BLUR_DIV / sh)
                dxSetShaderValue(shader, "sStrength", strength or 1.6)
                dxDrawImage(0, 0, math.floor(sw / BLUR_DIV), math.floor(sh / BLUR_DIV), shader)
                dxSetRenderTarget()
            end
        end
        -- passagem 2: render target (ou fonte) -> tela
        dxSetShaderValue(shader, "sTex", blur.rt or blur.source)
        dxSetShaderValue(shader, "sTexel", BLUR_DIV / sw, BLUR_DIV / sh)
        dxSetShaderValue(shader, "sStrength", strength or 1.6)
        dxDrawImage(0, 0, sw, sh, shader, 0, 0, 0, tocolor(255, 255, 255, 255 * alpha))
    end
    if tintAlpha > 0 then
        local c = palette.bg
        dxDrawRectangle(0, 0, sw, sh, tocolor(c[1], c[2], c[3], tintAlpha * alpha))
    end
end

-- Vinheta colorida nas bordas (vida baixa, morte, dano)
function UI.vignette(color, alpha, inner, outer)
    alpha = UI.clamp(alpha or 1, 0, 1)
    if alpha <= 0.01 then return end
    local shader = getShader("vignette")
    local r, g, b, a = UI.split(color)
    if shader then
        dxSetShaderValue(shader, "sColor", r / 255, g / 255, b / 255, a / 255)
        dxSetShaderValue(shader, "sInner", inner or 0.55)
        dxSetShaderValue(shader, "sOuter", outer or 1.35)
        dxDrawImage(0, 0, sw, sh, shader, 0, 0, 0, tocolor(255, 255, 255, 255 * alpha))
    else
        local t = math.floor(sh * 0.18)
        UI.gradientV(0, 0, sw, t, { r, g, b, a * alpha }, { r, g, b, 0 }, 16)
        UI.gradientV(0, sh - t, sw, t, { r, g, b, 0 }, { r, g, b, a * alpha }, 16)
    end
end

-- Gradiente animado (aurora). colors = { A, B, C } em RGB tabelas
function UI.aurora(x, y, w, h, alpha, colors, radius)
    alpha = UI.clamp(alpha or 1, 0, 1)
    local shader = getShader("aurora")
    colors = colors or { palette.accent, palette.accent2, palette.bg }
    if shader then
        dxSetShaderValue(shader, "sTime", (UI.now % 1000000) / 1000)
        dxSetShaderValue(shader, "sAlpha", alpha)
        dxSetShaderValue(shader, "sColorA", colors[1][1] / 255, colors[1][2] / 255, colors[1][3] / 255, 1)
        dxSetShaderValue(shader, "sColorB", colors[2][1] / 255, colors[2][2] / 255, colors[2][3] / 255, 1)
        dxSetShaderValue(shader, "sColorC", colors[3][1] / 255, colors[3][2] / 255, colors[3][3] / 255, 1)
        dxDrawImage(x, y, w, h, shader)
    else
        local t = UI.pulse(4000, 0.25, 0.6)
        UI.gradientH(x, y, w, h, { colors[1][1], colors[1][2], colors[1][3], 120 * alpha * t }, { colors[2][1], colors[2][2], colors[2][3], 40 * alpha }, 24)
    end
end

-- ============================================================
-- Fontes e texto
-- ============================================================
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
    if not font then font = (kind == "bold" or kind == "semibold") and "default-bold" or "default" end
    fontCache[key] = font
    return font
end
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
function UI.text(text, x, y, w, h, color, kind, size, align, valign, clip, wordBreak, colorCoded, postGUI)
    local font = UI.font(kind, size)
    dxDrawText(tostring(text), x, y, x + (w or 0), y + (h or 0), color or UI.color("text"), fontScale(font, size), font,
        align or "left", valign or "top", clip or false, wordBreak or false, postGUI or false, colorCoded or false, true)
end
function UI.textShadow(text, x, y, w, h, color, kind, size, align, valign, colorCoded)
    local font = UI.font(kind, size)
    local sc = fontScale(font, size)
    local off = math.max(1, UI.s(1.2))
    local plain = tostring(text):gsub("#%x%x%x%x%x%x", "")
    dxDrawText(plain, x + off, y + off, x + (w or 0) + off, y + (h or 0) + off, tocolor(0, 0, 0, 160), sc, font, align or "left", valign or "top", false, false, false, false, true)
    dxDrawText(tostring(text), x, y, x + (w or 0), y + (h or 0), color or UI.color("text"), sc, font, align or "left", valign or "top", false, false, false, colorCoded or false, true)
end
-- Texto com brilho colorido (títulos, números grandes)
function UI.textGlow(text, x, y, w, h, color, glowColor, kind, size, align, valign)
    local font = UI.font(kind, size)
    local sc = fontScale(font, size)
    local gr, gg, gb, ga = UI.split(glowColor or color or UI.color("accent"))
    local o = math.max(1, UI.s(2))
    local gc = tocolor(gr, gg, gb, ga * 0.22)
    for _, d in ipairs({ { o, 0 }, { -o, 0 }, { 0, o }, { 0, -o }, { o, o }, { -o, -o }, { o, -o }, { -o, o } }) do
        dxDrawText(tostring(text), x + d[1], y + d[2], x + (w or 0) + d[1], y + (h or 0) + d[2], gc, sc, font, align or "left", valign or "top", false, false, false, false, true)
    end
    dxDrawText(tostring(text), x, y, x + (w or 0), y + (h or 0), color or UI.color("text"), sc, font, align or "left", valign or "top", false, false, false, false, true)
end
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
function UI.formatNumber(n)
    n = tonumber(n) or 0
    local str = tostring(math.floor(n))
    local out = str:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return (out:gsub("^%.", ""))
end
function UI.money(n) return "$" .. UI.formatNumber(n) end

-- ============================================================
-- Imagens
-- ============================================================
local imgCache = {}
function UI.image(name, x, y, w, h, color, rotation, postGUI)
    local path = imgCache[name]
    if path == nil then
        local p = UI.IMG .. name
        path = fileExists(p) and p or false
        imgCache[name] = path
    end
    if not path then return false end
    dxDrawImage(x, y, w, h, path, rotation or 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    return true
end

-- ============================================================
-- Mouse e cliques
-- ============================================================
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

-- Registro de cliques por frame: UI.beginFrame() no início do render, UI.addClick(...) ao desenhar,
-- UI.processClick(button, state) no handler de onClientClick. O último registrado (desenhado por cima) tem prioridade.
local clickRegions = {}
local mouseDownAt = nil
function UI.beginFrame() clickRegions = {} end
function UI.addClick(x, y, w, h, fn, id)
    clickRegions[#clickRegions + 1] = { x, y, w, h, fn, id }
end
function UI.processClick(button, state)
    if button ~= "left" then return false end
    if state == "down" then
        local mx, my = UI.mouse()
        mouseDownAt = mx and { mx, my } or nil
        return false
    end
    if state ~= "up" then return false end
    for i = #clickRegions, 1, -1 do
        local r = clickRegions[i]
        if UI.isMouseIn(r[1], r[2], r[3], r[4]) and mouseDownAt and mouseDownAt[1] >= r[1] and mouseDownAt[1] <= r[1] + r[3] and mouseDownAt[2] >= r[2] and mouseDownAt[2] <= r[2] + r[4] then
            if UI.sound then UI.sound("click", 0.45) end
            r[5]()
            return true
        end
    end
    return false
end
function UI.isMouseDown() return getKeyState("mouse1") end

-- Tooltip (desenhada no fim do frame por UI.endFrame)
local pendingTooltip
function UI.tooltip(text) pendingTooltip = text end
function UI.endFrame()
    if pendingTooltip then
        local mx, my = UI.mouse()
        if mx then
            local w = UI.textWidth(pendingTooltip, "medium", 10) + UI.s(20)
            local h = UI.s(26)
            local x = UI.clamp(mx + UI.s(14), 0, sw - w)
            local y = UI.clamp(my + UI.s(18), 0, sh - h)
            UI.rrect(x, y, w, h, UI.color("card", 245), UI.s(6), { border = 1, borderColor = tocolor(255, 255, 255, 30) })
            UI.text(pendingTooltip, x, y, w, h, UI.color("text"), "medium", 10, "center", "center")
        end
        pendingTooltip = nil
    end
end

-- ============================================================
-- Sons (dm_core define playUISound; os outros recursos usam o export)
-- ============================================================
if type(playUISound) == "function" then
    UI.sound = function(n, v) playUISound(n, v) end
else
    UI.sound = function(n, v)
        pcall(function() exports.dm_core:playUISound(n, v) end)
    end
end

-- ============================================================
-- Componentes
-- ============================================================

-- Card de vidro: fundo escuro translúcido, borda sutil, brilho externo e linha de acento no topo
function UI.card(x, y, w, h, radius, alphaMul, accentName, opts)
    alphaMul = alphaMul or 1
    radius = radius or UI.s(14)
    opts = opts or {}
    local accent = accentName ~= false and (palette[accentName or "accent"] or palette.accent) or nil
    UI.rrect(x, y, w, h, UI.color("card", (opts.alpha or 248) * alphaMul), radius, {
        border = 1, borderColor = tocolor(255, 255, 255, 34 * alphaMul),
        glow = accent and (opts.glow or UI.s(18)) or 0, glowColor = accent and tocolor(accent[1], accent[2], accent[3], 70 * alphaMul) or nil,
        gradient = UI.color("card2", (opts.alpha or 248) * alphaMul), gradientMode = 3, shine = 0.08,
    })
    if accent then
        UI.accentLine(x + radius, y, (w - radius * 2) * 0.55, UI.s(2), accent, alphaMul)
    end
end

-- Superfície interna (seção dentro de um card)
function UI.glass(x, y, w, h, radius, alphaMul, hoverT)
    alphaMul = alphaMul or 1
    hoverT = hoverT or 0
    UI.rrect(x, y, w, h, tocolor(255, 255, 255, (14 + 14 * hoverT) * alphaMul), radius or UI.s(10), {
        border = 1, borderColor = tocolor(255, 255, 255, (28 + 50 * hoverT) * alphaMul),
    })
end

-- Pílula
function UI.pill(text, x, y, h, colorBg, colorText, kind, size, padX)
    padX = padX or UI.s(10)
    local w = UI.textWidth(text, kind or "semibold", size or 10) + padX * 2
    UI.rrect(x, y, w, h, colorBg, h / 2)
    UI.text(text, x, y, w, h, colorText, kind or "semibold", size or 10, "center", "center")
    return w
end
function UI.tagPill(tag, x, y, h, alpha, size)
    if type(tag) ~= "table" or not tag.text then return 0 end
    alpha = alpha or 1
    local r, g, b = UI.hexToRGB(tag.hex)
    local solid = tag.kind == "vip" or tag.kind == "staff"
    local icon = tag.icon and h * 0.8 or 0
    local w = UI.textWidth(tag.text, "bold", size or 8) + UI.s(16) + (icon > 0 and icon + UI.s(4) or 0)
    UI.rrect(x, y, w, h, solid and tocolor(r, g, b, 240 * alpha) or tocolor(r, g, b, 70 * alpha), h / 2, { border = 1, borderColor = tocolor(r, g, b, (solid and 0 or 160) * alpha), glow = solid and UI.s(6) or 0, glowColor = tocolor(r, g, b, 90 * alpha) })
    local tc = solid and tocolor(10, 14, 12, 255 * alpha) or tocolor(r, g, b, 255 * alpha)
    if icon > 0 then
        UI.image(tag.icon, x + UI.s(7), y + (h - icon) / 2, icon, icon, tc)
        UI.text(tag.text, x + UI.s(7) + icon + UI.s(3), y, w - icon - UI.s(10), h, tc, "bold", size or 8, "center", "center")
    else
        UI.text(tag.text, x, y, w, h, tc, "bold", size or 8, "center", "center")
    end
    return w
end

--[[
    Botão com hover animado, brilho, feedback de clique e ícone opcional.
    opts = { kind = "primary"|"outline"|"ghost"|"danger", color = nome da paleta, size, font, radius,
             disabled, alpha, icon = "x.png", onClick = fn (registra o clique automaticamente), tooltip }
    Retorna hover (bool).
]]
function UI.button(id, text, x, y, w, h, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local hovering = not opts.disabled and UI.isMouseIn(x, y, w, h)
    local t = UI.hover(id, hovering)
    local pressed = hovering and UI.isMouseDown()
    local kind = opts.kind or "primary"
    local radius = opts.radius or UI.s(10)
    local grow = UI.s(2) * t - (pressed and UI.s(1) or 0)
    local bx, by, bw, bh = x - grow, y - grow, w + grow * 2, h + grow * 2
    local c = palette[opts.color or "accent"] or palette.accent
    local textColor
    if opts.disabled then
        UI.rrect(bx, by, bw, bh, tocolor(255, 255, 255, 8 * alpha), radius, { border = 1, borderColor = tocolor(255, 255, 255, 14 * alpha) })
        textColor = UI.color("muted", 150 * alpha)
    elseif kind == "primary" then
        UI.rrect(bx, by, bw, bh, tocolor(c[1], c[2], c[3], (215 + 40 * t) * alpha), radius, {
            glow = UI.s(4) + UI.s(14) * t, glowColor = tocolor(c[1], c[2], c[3], (60 + 90 * t) * alpha),
            gradient = tocolor(math.min(255, c[1] + 40), math.min(255, c[2] + 40), math.min(255, c[3] + 40), (215 + 40 * t) * alpha), gradientMode = 1, shine = 0.3,
        })
        textColor = tocolor(8, 14, 10, 255 * alpha)
    elseif kind == "danger" then
        local d = palette.danger
        UI.rrect(bx, by, bw, bh, tocolor(d[1], d[2], d[3], (205 + 50 * t) * alpha), radius, { glow = UI.s(3) + UI.s(12) * t, glowColor = tocolor(d[1], d[2], d[3], (50 + 90 * t) * alpha), shine = 0.2 })
        textColor = tocolor(255, 255, 255, 255 * alpha)
    elseif kind == "outline" then
        UI.rrect(bx, by, bw, bh, tocolor(c[1], c[2], c[3], (26 + 60 * t) * alpha), radius, { border = 1, borderColor = tocolor(c[1], c[2], c[3], (120 + 135 * t) * alpha), glow = UI.s(10) * t, glowColor = tocolor(c[1], c[2], c[3], 70 * t * alpha) })
        textColor = tocolor(c[1], c[2], c[3], 255 * alpha)
    else -- ghost
        UI.rrect(bx, by, bw, bh, tocolor(255, 255, 255, (10 + 30 * t) * alpha), radius, { border = 1, borderColor = tocolor(255, 255, 255, (20 + 40 * t) * alpha) })
        textColor = t > 0.5 and UI.color("text", 255 * alpha) or UI.color("muted", 255 * alpha)
    end
    local tx, tw = bx, bw
    if opts.icon then
        local isz = bh * 0.55
        local textW = UI.textWidth(text, opts.font or "semibold", opts.size or 12)
        local total = isz + UI.s(8) + textW
        local ix = bx + (bw - total) / 2
        UI.image(opts.icon, ix, by + (bh - isz) / 2, isz, isz, textColor)
        tx, tw = ix + isz + UI.s(8), textW
        UI.text(text, tx, by, tw, bh, textColor, opts.font or "semibold", opts.size or 12, "left", "center")
    else
        UI.text(text, tx, by, tw, bh, textColor, opts.font or "semibold", opts.size or 12, "center", "center")
    end
    if hovering and UI._hoverId ~= id then
        UI._hoverId = id
        if UI.sound then UI.sound("hover", 0.25) end
    elseif not hovering and UI._hoverId == id then
        UI._hoverId = nil
    end
    if hovering and opts.tooltip then UI.tooltip(opts.tooltip) end
    if opts.onClick and not opts.disabled then UI.addClick(x, y, w, h, opts.onClick, id) end
    return hovering
end

-- Botão de ícone (quadrado)
function UI.iconButton(id, icon, x, y, size, opts)
    opts = opts or {}
    local hovering = UI.isMouseIn(x, y, size, size)
    local t = UI.hover(id, hovering)
    local c = palette[opts.color or "accent"] or palette.accent
    local alpha = opts.alpha or 1
    UI.rrect(x, y, size, size, tocolor(255, 255, 255, (8 + 18 * t) * alpha), opts.radius or UI.s(8), { border = 1, borderColor = tocolor(255, 255, 255, (16 + 40 * t) * alpha) })
    local pad = size * 0.25
    if not UI.image(icon, x + pad, y + pad, size - pad * 2, size - pad * 2, tocolor(255, 255, 255, (200 + 55 * t) * alpha)) then
        UI.text(icon, x, y, size, size, tocolor(255, 255, 255, (200 + 55 * t) * alpha), "bold", opts.size or 13, "center", "center")
    end
    if hovering and opts.tooltip then UI.tooltip(opts.tooltip) end
    if opts.onClick then UI.addClick(x, y, size, size, opts.onClick, id) end
    return hovering
end

-- Botão fechar padrão (×)
function UI.closeButton(id, x, y, onClose, alpha)
    local size = UI.s(32)
    local hovering = UI.isMouseIn(x, y, size, size)
    local t = UI.hover(id, hovering)
    local d = palette.danger
    UI.rrect(x, y, size, size, tocolor(d[1], d[2], d[3], 160 * t * (alpha or 1)), size / 2, { border = 1, borderColor = tocolor(255, 255, 255, (20 + 40 * t) * (alpha or 1)) })
    UI.text("×", x, y - UI.s(1), size, size, tocolor(255, 255, 255, (170 + 85 * t) * (alpha or 1)), "bold", 16, "center", "center")
    if onClose then UI.addClick(x, y, size, size, onClose, id) end
    return hovering
end

--[[
    Barra de progresso animada.
    opts = { id = chave para animar (tween), ghost = true (rastro vermelho ao descer), glow = bool, gradient = cor2 }
]]
function UI.bar(x, y, w, h, progress, colorFill, colorBg, radius, opts)
    progress = UI.clamp(progress or 0, 0, 1)
    opts = opts or {}
    radius = radius or h / 2
    UI.rrect(x, y, w, h, colorBg or tocolor(255, 255, 255, 16), radius)
    local shown = progress
    if opts.id then
        shown = UI.tween("bar:" .. opts.id, progress, 260, "outCubic")
        if opts.ghost then
            local ghost = UI.spring("barghost:" .. opts.id, progress, 2.5)
            if ghost < shown then UI.resetSpring("barghost:" .. opts.id, shown) ghost = shown end
            if ghost > shown + 0.002 then
                local d = palette.danger
                UI.rrect(x, y, math.max(h, w * ghost), h, tocolor(d[1], d[2], d[3], 150), radius)
            end
        end
    end
    if shown > 0.001 then
        local fr, fg, fb, fa = UI.split(colorFill)
        UI.rrect(x, y, math.max(h, w * shown), h, colorFill, radius, {
            glow = opts.glow and UI.s(6) or 0, glowColor = tocolor(fr, fg, fb, 90),
            gradient = opts.gradient, gradientMode = 2, shine = 0.25,
        })
    end
    return shown
end

-- Anel de progresso (0 = topo, sentido horário)
function UI.ring(cx, cy, r, thickness, progress, color, bgColor, startAngle)
    local function arc(from, to, col)
        local span = to - from
        if span <= 0 then return end
        local n = math.max(2, math.floor(64 * span / 360))
        local step = span / n
        for i = 0, n - 1 do
            local a1 = math.rad(from + i * step - 90)
            local a2 = math.rad(from + (i + 1) * step - 90)
            dxDrawLine(cx + math.cos(a1) * r, cy + math.sin(a1) * r, cx + math.cos(a2) * r, cy + math.sin(a2) * r, col, thickness)
        end
    end
    if bgColor then arc(0, 360, bgColor) end
    progress = UI.clamp(progress or 0, 0, 1)
    if progress > 0 then arc(startAngle or 0, (startAngle or 0) + 360 * progress, color) end
end

--[[
    Abas com indicador deslizante.
    items = { { key, label }, ... }; retorna nada; registra cliques que chamam onSelect(key).
]]
function UI.tabs(id, items, x, y, h, selectedKey, onSelect, alpha, size)
    alpha = alpha or 1
    local cx = x
    local bounds = {}
    for i, item in ipairs(items) do
        local tw = UI.textWidth(item[2], "semibold", size or 10) + UI.s(28)
        bounds[i] = { cx, tw }
        local sel = item[1] == selectedKey
        local hovering = UI.isMouseIn(cx, y, tw, h)
        local t = UI.hover(id .. ":" .. item[1], hovering)
        UI.rrect(cx, y, tw, h, tocolor(255, 255, 255, (sel and 14 or 0) + 12 * t), UI.s(8))
        UI.text(item[2], cx, y, tw, h, sel and UI.color("text", 255 * alpha) or UI.color("muted", (200 + 55 * t) * alpha), "semibold", size or 10, "center", "center")
        local key = item[1]
        UI.addClick(cx, y, tw, h, function() if onSelect then onSelect(key) end end, id .. ":" .. key)
        if sel then
            local ix = UI.tween("tabs:" .. id .. ":x", cx, 220, "outCubic")
            local iw = UI.tween("tabs:" .. id .. ":w", tw, 220, "outCubic")
            local c = palette.accent
            UI.rrect(ix + UI.s(10), y + h - UI.s(3), iw - UI.s(20), UI.s(3), tocolor(c[1], c[2], c[3], 255 * alpha), UI.s(2), { glow = UI.s(8), glowColor = tocolor(c[1], c[2], c[3], 120 * alpha) })
        end
        cx = cx + tw + UI.s(6)
    end
    return cx - x
end

-- Rolagem suave: chame UI.scroll(id, targetOffset) e use o valor devolvido
function UI.scroll(id, target) return UI.tween("scroll:" .. id, target, 180, "outCubic") end
-- Barra de rolagem vertical
function UI.scrollbar(x, y, h, total, visible, offset, alpha)
    if total <= visible then return end
    local barH = math.max(UI.s(20), h * (visible / total))
    local barY = y + (h - barH) * (offset / math.max(1, total - visible))
    UI.rrect(x, y, UI.s(4), h, tocolor(255, 255, 255, 10 * (alpha or 1)), UI.s(2))
    UI.rrect(x, barY, UI.s(4), barH, UI.color("accent", 160 * (alpha or 1)), UI.s(2))
end

-- Campo de texto (dx) com foco animado. field = { text, focus, masked, placeholder, maxLength, allowed, icon }
function UI.inputField(field, x, y, w, h, opts)
    opts = opts or {}
    local radius = opts.radius or UI.s(10)
    local hovering = UI.isMouseIn(x, y, w, h)
    local f = UI.spring("input:" .. tostring(field), field.focus and 1 or 0, 14)
    local c = palette.accent
    UI.rrect(x, y, w, h, tocolor(255, 255, 255, 8 + 6 * f), radius, {
        border = 1, borderColor = tocolor(255 - (255 - c[1]) * f, 255 - (255 - c[2]) * f, 255 - (255 - c[3]) * f, 28 + (hovering and 20 or 0) + 150 * f),
        glow = UI.s(10) * f, glowColor = tocolor(c[1], c[2], c[3], 70 * f),
    })
    local pad = UI.s(14)
    if field.icon then
        UI.image(field.icon, x + pad, y + (h - UI.s(16)) / 2, UI.s(16), UI.s(16), UI.color("muted"))
        pad = pad + UI.s(24)
    end
    local shown = field.text or ""
    if field.masked then shown = string.rep("•", utf8.len(shown) or #shown) end
    if shown == "" and not field.focus then
        UI.text(field.placeholder or "", x + pad, y, w - pad * 2, h, UI.color("muted", 170), "regular", opts.size or 12, "left", "center")
    else
        local caret = (field.focus and (UI.now % 1000) < 500) and "|" or ""
        UI.text(shown .. caret, x + pad, y, w - pad - UI.s(14), h, UI.color("text"), "regular", opts.size or 12, "left", "center", true)
    end
    field._bounds = { x, y, w, h }
    return hovering
end

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
        if not f or not press then return end
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
            cancelEvent()
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

-- Toggle (interruptor)
function UI.toggle(id, x, y, value, onChange, alpha)
    local w, h = UI.s(40), UI.s(22)
    local t = UI.spring("toggle:" .. id, value and 1 or 0, 14)
    local c = palette.accent
    UI.rrect(x, y, w, h, tocolor(c[1] * t + 255 * (1 - t) * 0.1, c[2] * t + 255 * (1 - t) * 0.1, c[3] * t + 255 * (1 - t) * 0.1, (60 + 160 * t) * (alpha or 1)), h / 2, { glow = UI.s(8) * t, glowColor = tocolor(c[1], c[2], c[3], 90 * t) })
    local kx = x + UI.s(3) + (w - h) * t
    UI.rrect(kx, y + UI.s(3), h - UI.s(6), h - UI.s(6), tocolor(255, 255, 255, 240 * (alpha or 1)), (h - UI.s(6)) / 2)
    if onChange then UI.addClick(x, y, w, h, function() onChange(not value) end, id) end
end

-- Badge numérico (contador em cima de ícone)
function UI.badge(text, x, y, colorName, alpha)
    local h = UI.s(16)
    local c = palette[colorName or "danger"]
    local w = UI.pill(tostring(text), x, y, h, tocolor(c[1], c[2], c[3], 230 * (alpha or 1)), tocolor(10, 14, 12, 255 * (alpha or 1)), "bold", 8, UI.s(6))
    return w
end

-- ============================================================
-- Gerenciador de painéis
-- ============================================================
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
UI.escapeHandlers = UI.escapeHandlers or {}
function UI.registerEscape(panelName, fn) UI.escapeHandlers[panelName] = fn end
addEventHandler("onClientKey", root, function(key, press)
    if key ~= "escape" or not press then return end
    local open = UI.getOpenPanel()
    if open and UI.escapeHandlers[open] then
        UI.escapeHandlers[open]()
        cancelEvent()
    end
end)

-- Progresso de abertura 0..1 (state = { open = bool, tick = ms })
function UI.openProgress(state, duration)
    duration = duration or 260
    local t = UI.clamp((UI.now - (state.tick or 0)) / duration, 0, 1)
    if state.open then return UI.ease(t, "outCubic") end
    return 1 - UI.ease(t, "inCubic")
end

--[[
    Animação padrão de painel: retorna a (alpha 0..1), scale e deslocamento vertical.
    Abrindo: escala 0.94 -> 1 com overshoot (outBack); fechando: encolhe e desvanece.
]]
function UI.panelAnim(state, duration)
    duration = duration or 280
    local raw = UI.clamp((UI.now - (state.tick or 0)) / duration, 0, 1)
    if state.open then
        return UI.ease(raw, "outCubic"), 0.94 + 0.06 * UI.ease(raw, "outBack"), (1 - UI.ease(raw, "outCubic")) * UI.s(18)
    end
    local p = 1 - UI.ease(raw, "inCubic")
    return p, 0.96 + 0.04 * p, (1 - p) * UI.s(-10)
end

--[[
    Moldura padrão de painel. Desenha backdrop desfocado, card, cabeçalho (ícone, título,
    subtítulo, badge) e botão fechar. Deve ser chamada no início do render do painel.

    state = { open = bool, tick = ms }
    opts  = { w, h, title, subtitle, icon = "trophy.png", accent = "accent"|"gold"|..., badge = "texto",
              badgeColor = "gold", onClose = fn, blur = true (padrão), aurora = true (fundo animado no cabeçalho) }
    Retorna nil quando totalmente fechado; senão a tabela:
      { x, y, w, h, a, scale, pad, cx, cy, cw, ch }  (cx/cy = origem da área de conteúdo; cw/ch = tamanho)
]]
function UI.panelFrame(state, opts)
    local a, scale, dy = UI.panelAnim(state, opts.duration)
    if a <= 0.001 then return nil end
    UI.beginFrame()
    local w, h = opts.w * scale, opts.h * scale
    local x, y = (sw - w) / 2, (sh - h) / 2 + dy
    local pad = UI.s(28)
    if opts.blur ~= false then UI.backdrop(a, 170) else dxDrawRectangle(0, 0, sw, sh, UI.color("bg", 170 * a)) end
    UI.card(x, y, w, h, UI.s(18), a, opts.accent or "accent", { glow = UI.s(26) })
    local headerH = UI.s(opts.subtitle and 86 or 70)
    if opts.aurora ~= false then
        local c = palette[opts.accent or "accent"] or palette.accent
        UI.aurora(x + UI.s(2), y + UI.s(2), w - UI.s(4), headerH, 0.16 * a, { c, palette.accent2, palette.bg })
    end
    local tx = x + pad
    if opts.icon then
        local isz = UI.s(34)
        local c = palette[opts.accent or "accent"] or palette.accent
        UI.rrect(tx, y + UI.s(22), isz + UI.s(12), isz + UI.s(12), tocolor(c[1], c[2], c[3], 30 * a), UI.s(10), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 80 * a) })
        if not UI.image(opts.icon, tx + UI.s(6), y + UI.s(28), isz, isz, tocolor(255, 255, 255, 255 * a)) then
            UI.text(opts.icon, tx, y + UI.s(22), isz + UI.s(12), isz + UI.s(12), tocolor(c[1], c[2], c[3], 255 * a), "bold", 16, "center", "center")
        end
        tx = tx + isz + UI.s(26)
    end
    UI.textGlow(opts.title or "", tx, y + UI.s(18), w, UI.s(36), UI.color("text", 255 * a), UI.color(opts.accent or "accent", 110 * a), "bold", 22, "left", "center")
    if opts.subtitle then
        UI.text(opts.subtitle, tx, y + UI.s(52), w - (tx - x) - pad - UI.s(140), UI.s(22), UI.color("muted", 255 * a), "regular", 10, "left", "center", true)
    end
    if opts.badge then
        local bc = palette[opts.badgeColor or opts.accent or "accent"] or palette.accent
        local bw = UI.textWidth(opts.badge, "bold", 10) + UI.s(28)
        UI.rrect(x + w - pad - UI.s(44) - bw, y + UI.s(24), bw, UI.s(30), tocolor(bc[1], bc[2], bc[3], 36 * a), UI.s(15), { border = 1, borderColor = tocolor(bc[1], bc[2], bc[3], 120 * a) })
        UI.text(opts.badge, x + w - pad - UI.s(44) - bw, y + UI.s(24), bw, UI.s(30), tocolor(bc[1], bc[2], bc[3], 255 * a), "bold", 10, "center", "center")
    end
    UI.closeButton("panel_close:" .. (opts.title or ""), x + w - pad - UI.s(32), y + UI.s(22), opts.onClose, a)
    UI.divider(x + pad, y + headerH, w - pad * 2, 18 * a)
    return { x = x, y = y, w = w, h = h, a = a, scale = scale, pad = pad, cx = x + pad, cy = y + headerH + UI.s(18), cw = w - pad * 2, ch = h - headerH - UI.s(18) - pad }
end

-- Rodapé padrão (dica de teclas) dentro de um painel
function UI.panelFooter(f, text)
    UI.divider(f.cx, f.y + f.h - UI.s(46), f.cw, 14 * f.a)
    UI.text(text, f.cx, f.y + f.h - UI.s(40), f.cw, UI.s(28), UI.color("muted", 180 * f.a), "regular", 9, "left", "center")
end

-- Bloco "estatística" (rótulo pequeno em cima, valor grande embaixo)
function UI.stat(x, y, w, label, value, colorName, alpha, size)
    alpha = alpha or 1
    UI.text(label, x, y, w, UI.s(12), UI.color("muted", 220 * alpha), "semibold", 8, "left", "center")
    UI.text(value, x, y + UI.s(12), w, UI.s(26), UI.color(colorName or "text", 255 * alpha), "bold", size or 16, "left", "center")
end

-- Linha de lista com hover (retorna hover t para o chamador)
function UI.listRow(id, x, y, w, h, selected, alpha)
    local hovering = UI.isMouseIn(x, y, w, h)
    local t = UI.hover(id, hovering)
    local c = palette.accent
    if selected then
        UI.rrect(x, y, w, h, tocolor(c[1], c[2], c[3], 34 * (alpha or 1)), UI.s(8), { border = 1, borderColor = tocolor(c[1], c[2], c[3], 140 * (alpha or 1)) })
    else
        UI.rrect(x, y, w, h, tocolor(255, 255, 255, (5 + 12 * t) * (alpha or 1)), UI.s(8))
    end
    return t, hovering
end
