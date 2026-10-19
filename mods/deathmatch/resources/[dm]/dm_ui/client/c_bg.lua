--[[
    Fundo animado dos painéis, desenhado em dx (GPU) em vez de canvas dentro do CEF.
    Antes: um <canvas> 1920x1080 redesenhado a 15 fps obrigava o CEF (rasterização por software) a repintar a
    tela inteira e reenviar a textura toda a cada quadro, o que travava o painel e o mouse.
    Agora a página só contém o painel (transparente ao redor) e o fundo verde vivo é desenhado aqui, por trás do
    browser, com meia dúzia de sprites — custo desprezível e sem interferir no CEF.
]]
local sw, sh = guiGetScreenSize()
local glow                       -- textura radial branca (fx/glow.png), tingida por cor
local alpha, target = 0, 0       -- fade do fundo (0..1)
local FADE_MS = 180
local lastTick = getTickCount()
local parts, blobs = {}, {}
local started = false

local function rnd(a, b) return a + math.random() * (b - a) end
local function init()
    glow = dxCreateTexture("fx/glow.png", "argb", true, "clamp")
    for i = 1, 40 do
        parts[i] = { x = math.random(), y = math.random(), r = rnd(2, 5), s = rnd(0.012, 0.04), p = rnd(0, 6.28) }
    end
    blobs = {
        { x = 0.18, y = 0.30, r = 0.62, c = { 34, 230, 138 }, a = 0.30, f = 0.11 },
        { x = 0.82, y = 0.25, r = 0.55, c = { 124, 255, 178 }, a = 0.18, f = 0.07 },
        { x = 0.55, y = 0.98, r = 0.80, c = { 15, 120, 70 }, a = 0.34, f = 0.05 },
        { x = 0.90, y = 0.80, r = 0.50, c = { 34, 230, 138 }, a = 0.16, f = 0.09 },
    }
    started = true
end

local function wantBackground()
    local p = UI.getOpenPanel()
    return p ~= nil and p ~= "board"
end

local function draw()
    local now = getTickCount()
    local dt = math.min(0.1, (now - lastTick) / 1000)
    lastTick = now
    target = wantBackground() and 1 or 0
    if alpha ~= target then
        local step = dt * 1000 / FADE_MS
        alpha = target > alpha and math.min(1, alpha + step) or math.max(0, alpha - step)
    end
    if alpha <= 0 then return end
    if not started then init() end
    local strength = (UI.getOpenPanel() == "login") and 1.3 or 1
    local s = now / 1000
    local A = alpha

    -- escurecimento verde da cena (mais escuro embaixo, como o gradiente da página)
    dxDrawRectangle(0, 0, sw, sh, tocolor(5, 14, 9, 200 * A))
    dxDrawRectangle(0, sh * 0.5, sw, sh * 0.5, tocolor(5, 14, 9, 25 * A))
    if not glow then return end

    dxSetBlendMode("add")
    -- aurora: 4 manchas de luz que respiram devagar
    for _, b in ipairs(blobs) do
        local x = (b.x + math.sin(s * b.f * 2 + b.r) * 0.08) * sw
        local y = (b.y + math.cos(s * b.f * 1.6 + b.a) * 0.06) * sh
        local r = b.r * math.max(sw, sh) * (1 + math.sin(s * b.f) * 0.08)
        dxDrawImage(x - r, y - r, r * 2, r * 2, glow, 0, 0, 0, tocolor(b.c[1], b.c[2], b.c[3], 255 * b.a * strength * A))
    end
    -- feixes de luz girando devagar (sprite esticado e rotacionado)
    for i = 0, 3 do
        local rot = 20 + i * 4 + math.sin(s * 0.08 + i) * 2
        local w, h = sw * 0.07, sh * 2.2
        dxDrawImage(sw * 0.75 - w / 2 - i * sw * 0.03, -sh * 0.3, w, h, glow, rot, 0, -h * 0.4, tocolor(124, 255, 178, 26 * strength * A))
    end
    -- partículas subindo
    for _, p in ipairs(parts) do
        p.y = p.y - p.s * dt
        if p.y < -0.02 then p.y, p.x = 1.02, math.random() end
        local tw = 0.4 + 0.6 * math.abs(math.sin(s * 1.3 + p.p))
        local x = p.x * sw + math.sin(s * 0.7 + p.p) * 18
        dxDrawImage(x - p.r * 2, p.y * sh - p.r * 2, p.r * 4, p.r * 4, glow, 0, 0, 0, tocolor(160, 255, 200, 140 * tw * strength * A))
    end
    dxSetBlendMode("blend")
    -- grade sutil em perspectiva
    local col = tocolor(124, 255, 178, 9 * strength * A)
    local step = math.max(28, sw / 24)
    local off = (s * 6) % step
    for x = -step + off, sw + step, step do dxDrawLine(x, 0, x - sh * 0.25, sh, col) end
    for y = -step + off * 0.5, sh + step, step do dxDrawLine(0, y, sw, y, col) end
end
-- "low-4" roda antes do browser ("low-5"): o fundo fica atrás do painel
addEventHandler("onClientRender", root, draw, true, "low-4")
