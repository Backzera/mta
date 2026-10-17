--[[
    Extras dos mapas (scripts que vieram junto com as arenas, adaptados para dimensões).
    - Arena M4: portão automático (abre quando alguém se aproxima).
]]

local core = exports.dm_core

addEventHandler("onResourceStart", resourceRoot, function()
    local m4 = core:getArena("m4")
    if not m4 then return end
    local gx, gy, gz = 1207.5, -2037.4, 70.8
    local gate = createObject(16773, gx, gy, gz, 0, 0, 89.5)
    if not gate then return end
    setElementDimension(gate, m4.dimension)
    local zone = createColCircle(gx, gy, 6)
    setElementDimension(zone, m4.dimension)
    local inside = 0
    addEventHandler("onColShapeHit", zone, function(el, matching)
        if not matching or getElementType(el) ~= "player" then return end
        inside = inside + 1
        if inside == 1 then moveObject(gate, 500, gx, gy, gz + 5.8) end
    end)
    addEventHandler("onColShapeLeave", zone, function(el, matching)
        if not matching or getElementType(el) ~= "player" then return end
        inside = math.max(0, inside - 1)
        if inside == 0 then moveObject(gate, 500, gx, gy, gz) end
    end)
end)
