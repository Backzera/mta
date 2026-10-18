--[[
    Efeitos de arma (cliente):
      · RASTRO na ponta da arma para skins Mítica / Ultimate: uma fita de luz que segue o cano (todos veem).
      · BALA TRAÇANTE em todo tiro: linha do cano até o ponto de impacto, na cor da skin (ou padrão).
      · CLARÃO no cano na cor da skin a cada tiro.
    Cor: item.fx (hex) > cor da raridade. Tudo com dxDrawLine3D / dxDrawMaterialLine3D (barato).
]]
local core = exports.dm_core
local CRATES
local WEAPON_KEY = { [30] = "ak47", [31] = "m4" }
local TRAIL_RARITY = { mitica = true, ultimate = true }
local TRAIL_LIFE, TRAIL_MAX = 650, 48
local TRACER_LIFE, FLASH_LIFE = 140, 130
local sparks = {}   -- faíscas flutuando na ponta das armas Mítica/Ultimate
local trails, tracers, flashes = {}, {}, {}
local glow

local function cfg()
    if not CRATES then CRATES = core:getCratesConfig() end
    return CRATES
end
local function item(key)
    for _, it in ipairs(cfg().items) do if it.key == key then return it end end
end
local function hexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) or 255, tonumber(hex:sub(3, 4), 16) or 255, tonumber(hex:sub(5, 6), 16) or 255
end
-- cor RGB girando (arco-íris) a partir do tempo
local function rainbow(offset)
    local h = ((getTickCount() / 1800) + (offset or 0)) % 1
    local i, f = math.floor(h * 6), h * 6 - math.floor(h * 6)
    local q, t = 1 - f, f
    local r, g, b
    if i == 0 then r, g, b = 1, t, 0 elseif i == 1 then r, g, b = q, 1, 0 elseif i == 2 then r, g, b = 0, 1, t
    elseif i == 3 then r, g, b = 0, q, 1 elseif i == 4 then r, g, b = t, 0, 1 else r, g, b = 1, 0, q end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end
-- cor escolhida pelo jogador (dm:wskin.trail): "rgb", "#RRGGBB" ou nada (cor da skin)
local function chosenColor(player, offset)
    local e = getElementData(player, "dm:wskin")
    local c = type(e) == "table" and e.trail or nil
    if c == "rgb" then return rainbow(offset) end
    if type(c) == "string" and #c == 7 and c:sub(1, 1) == "#" then return hexToRGB(c:sub(2)) end
    return nil
end
local function colorOf(it)
    if it.fx then return hexToRGB(it.fx) end
    local r = cfg().rarities[it.rarity]
    if r then return r.color[1], r.color[2], r.color[3] end
    return 255, 230, 150
end

-- skin equipada na arma que o jogador está segurando
local function currentSkin(player)
    local wkey = WEAPON_KEY[getPedWeapon(player)]
    if not wkey then return nil end
    local e = getElementData(player, "dm:wskin")
    if type(e) ~= "table" then return nil end
    local key = e[wkey]
    return key and item(key) or nil
end

local function muzzle(player)
    local ok, x, y, z = pcall(getPedWeaponMuzzlePosition, player)
    if ok and x then return x, y, z end
    return getElementPosition(player)
end

-- ---------- tiros: traçante + clarão ----------
addEventHandler("onClientPlayerWeaponFire", root, function(weapon, ammo, clip, hx, hy, hz, hitElement)
    local player = source
    if not isElementStreamedIn(player) and player ~= localPlayer then return end
    local mx, my, mz = muzzle(player)
    if not hx then return end
    local it = currentSkin(player)
    local r, g, b = 255, 225, 140
    if it then
        r, g, b = colorOf(it)
        if TRAIL_RARITY[it.rarity] then local cr, cg, cb = chosenColor(player) if cr then r, g, b = cr, cg, cb end end
    end
    local now = getTickCount()
    tracers[#tracers + 1] = { mx, my, mz, hx, hy, hz, now, r, g, b }
    -- raios do clarão: 7 direções aleatórias em volta do cano
    local rays = {}
    for i = 1, 7 do rays[i] = { math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1, 0.25 + math.random() * 0.45 } end
    flashes[#flashes + 1] = { player = player, t = now, r = r, g = g, b = b, skin = it ~= nil, rays = rays, big = it ~= nil and TRAIL_RARITY[it.rarity] }
end)

-- ---------- render ----------
addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    -- rastro das skins Mítica / Ultimate
    for _, p in ipairs(getElementsByType("player", root, true)) do
        local it = currentSkin(p)
        if it and TRAIL_RARITY[it.rarity] and not isPedDead(p) then
            local tr = trails[p]
            if not tr then tr = { points = {} } trails[p] = tr end
            local cr, cg, cb = chosenColor(p)
            if not cr then cr, cg, cb = colorOf(it) end
            tr.r, tr.g, tr.b = cr, cg, cb
            local isRgb = type(getElementData(p, "dm:wskin")) == "table" and getElementData(p, "dm:wskin").trail == "rgb"
            local x, y, z = muzzle(p)
            local pts = tr.points
            local last = pts[#pts]
            if not last or (x - last[1]) ^ 2 + (y - last[2]) ^ 2 + (z - last[3]) ^ 2 > 0.0001 then
                pts[#pts + 1] = { x, y, z, now }
                if #pts > TRAIL_MAX then table.remove(pts, 1) end
            end
            -- desenha a fita (do mais antigo ao mais novo, afinando e apagando para trás)
            for i = 2, #pts do
                local a = pts[i - 1]
                local age = now - a[4]
                if age < TRAIL_LIFE then
                    local f = 1 - age / TRAIL_LIFE
                    local bpt = pts[i]
                    local r, g, b = tr.r, tr.g, tr.b
                    if isRgb then r, g, b = rainbow(i * 0.04) end
                    dxDrawLine3D(a[1], a[2], a[3], bpt[1], bpt[2], bpt[3], tocolor(r, g, b, 200 * f), 1 + 5 * f)
                    dxDrawLine3D(a[1], a[2], a[3], bpt[1], bpt[2], bpt[3], tocolor(255, 255, 255, 140 * f), 1 + 1.5 * f)
                end
            end
            -- ponto de luz na ponta
            if glow then
                local pulse = 0.85 + 0.15 * math.sin(now / 90)
                dxDrawMaterialLine3D(x, y, z - 0.2 * pulse, x, y, z + 0.2 * pulse, glow, 0.42 * pulse, tocolor(tr.r, tr.g, tr.b, 150))
                dxDrawMaterialLine3D(x, y, z - 0.08, x, y, z + 0.08, glow, 0.16, tocolor(255, 255, 255, 230))
                -- faíscas místicas: nascem no cano e sobem flutuando
                if math.random() < 0.45 then
                    sparks[#sparks + 1] = { x = x + (math.random() - 0.5) * 0.1, y = y + (math.random() - 0.5) * 0.1, z = z, t = now,
                        vx = (math.random() - 0.5) * 0.5, vy = (math.random() - 0.5) * 0.5, vz = 0.3 + math.random() * 0.6, r = tr.r, g = tr.g, b = tr.b, life = 500 + math.random(400) }
                end
            end
        elseif trails[p] then
            trails[p] = nil
        end
    end
    -- traçantes
    for i = #tracers, 1, -1 do
        local t = tracers[i]
        local age = now - t[7]
        if age > TRACER_LIFE then
            table.remove(tracers, i)
        else
            local f = 1 - age / TRACER_LIFE
            -- a bala "corre": a cabeça avança do cano ao alvo nos primeiros 60 ms
            local k = math.min(1, age / 60)
            local x2, y2, z2 = t[1] + (t[4] - t[1]) * k, t[2] + (t[5] - t[2]) * k, t[3] + (t[6] - t[3]) * k
            dxDrawLine3D(t[1], t[2], t[3], x2, y2, z2, tocolor(t[8], t[9], t[10], 230 * f), 2.5)
            dxDrawLine3D(t[1], t[2], t[3], x2, y2, z2, tocolor(255, 255, 255, 120 * f), 1)
        end
    end
    -- faíscas
    for i = #sparks, 1, -1 do
        local sp = sparks[i]
        local age = now - sp.t
        if age > sp.life then
            table.remove(sparks, i)
        elseif glow then
            local k = age / 1000
            local f = 1 - age / sp.life
            local x, y, z = sp.x + sp.vx * k, sp.y + sp.vy * k, sp.z + sp.vz * k
            local sz = 0.05 + 0.06 * f
            dxDrawMaterialLine3D(x, y, z - sz, x, y, z + sz, glow, sz * 2, tocolor(sp.r, sp.g, sp.b, 220 * f))
        end
    end
    -- clarões estilo CrossFire: núcleo que explode e some + raios radiais + anel
    for i = #flashes, 1, -1 do
        local fl = flashes[i]
        local age = now - fl.t
        if age > FLASH_LIFE or not isElement(fl.player) then
            table.remove(flashes, i)
        elseif glow then
            local p = age / FLASH_LIFE
            local f = 1 - p
            local x, y, z = muzzle(fl.player)
            local base = fl.big and 0.9 or (fl.skin and 0.6 or 0.4)
            local grow = 0.6 + 0.6 * math.min(1, age / 40)      -- expande nos primeiros 40 ms
            local size = base * grow
            -- núcleo
            dxDrawMaterialLine3D(x, y, z - size / 2, x, y, z + size / 2, glow, size, tocolor(fl.r, fl.g, fl.b, 230 * f))
            dxDrawMaterialLine3D(x, y, z - size / 4, x, y, z + size / 4, glow, size / 2, tocolor(255, 255, 255, 240 * f))
            -- raios
            local rl = size * 1.3
            for _, ry in ipairs(fl.rays) do
                local len = rl * ry[4] * (0.5 + 0.5 * grow)
                local n = math.sqrt(ry[1] ^ 2 + ry[2] ^ 2 + ry[3] ^ 2) + 0.001
                dxDrawMaterialLine3D(x, y, z, x + ry[1] / n * len, y + ry[2] / n * len, z + ry[3] / n * len, glow, 0.05 + 0.08 * f, tocolor(fl.r, fl.g, fl.b, 200 * f))
            end
            -- anel de choque (só skins)
            if fl.skin then
                local ring = size * (0.8 + 1.4 * p)
                dxDrawMaterialLine3D(x, y, z - 0.01, x, y, z + 0.01, glow, ring, tocolor(fl.r, fl.g, fl.b, 60 * f))
            end
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    glow = dxCreateTexture("fx/glow.png", "argb", true, "clamp")
end)
addEventHandler("onClientPlayerQuit", root, function() trails[source] = nil end)
