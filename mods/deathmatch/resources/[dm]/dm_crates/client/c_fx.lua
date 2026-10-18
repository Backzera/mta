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
local TRAIL_LIFE, TRAIL_MAX = 320, 16
local TRACER_LIFE, FLASH_LIFE = 140, 70
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
    if it then r, g, b = colorOf(it) end
    local now = getTickCount()
    tracers[#tracers + 1] = { mx, my, mz, hx, hy, hz, now, r, g, b }
    flashes[#flashes + 1] = { player = player, t = now, r = r, g = g, b = b, skin = it ~= nil }
end)

-- ---------- render ----------
addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    -- rastro das skins Mítica / Ultimate
    for _, p in ipairs(getElementsByType("player", root, true)) do
        local it = currentSkin(p)
        if it and TRAIL_RARITY[it.rarity] and not isPedDead(p) then
            local tr = trails[p]
            if not tr then
                local r, g, b = colorOf(it)
                tr = { points = {}, r = r, g = g, b = b }
                trails[p] = tr
            end
            local x, y, z = muzzle(p)
            local pts = tr.points
            local last = pts[#pts]
            if not last or (x - last[1]) ^ 2 + (y - last[2]) ^ 2 + (z - last[3]) ^ 2 > 0.0004 then
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
                    dxDrawLine3D(a[1], a[2], a[3], bpt[1], bpt[2], bpt[3], tocolor(tr.r, tr.g, tr.b, 200 * f), 1 + 5 * f)
                    dxDrawLine3D(a[1], a[2], a[3], bpt[1], bpt[2], bpt[3], tocolor(255, 255, 255, 140 * f), 1 + 1.5 * f)
                end
            end
            -- ponto de luz na ponta
            if glow then dxDrawMaterialLine3D(x, y, z - 0.06, x, y, z + 0.06, glow, 0.14, tocolor(tr.r, tr.g, tr.b, 230)) end
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
    -- clarões
    for i = #flashes, 1, -1 do
        local fl = flashes[i]
        local age = now - fl.t
        if age > FLASH_LIFE or not isElement(fl.player) then
            table.remove(flashes, i)
        elseif glow then
            local f = 1 - age / FLASH_LIFE
            local x, y, z = muzzle(fl.player)
            local size = (fl.skin and 0.55 or 0.35) * (0.7 + 0.3 * f)
            dxDrawMaterialLine3D(x, y, z - size / 2, x, y, z + size / 2, glow, size, tocolor(fl.r, fl.g, fl.b, 255 * f))
            dxDrawMaterialLine3D(x, y, z - size / 4, x, y, z + size / 4, glow, size / 2, tocolor(255, 255, 255, 220 * f))
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    glow = dxCreateTexture("fx/glow.png", "argb", true, "clamp")
end)
addEventHandler("onClientPlayerQuit", root, function() trails[source] = nil end)
