--[[
    Carregador de mapas: lê maps/<arena>.map (e <arena>_2.map ...) e cria os
    elementos na dimensão da arena. Pickups de arma só são criados se a arma
    fizer parte da arena. <spawnpoint> substitui os spawns da config.
]]

local core = exports.dm_core
local removed = {}     -- removeWorldModel aplicados (para restaurar no stop)
local roots = {}       -- arenaId -> elemento pai
local arenaObjects = {} -- arenaId -> lista de definições de objetos (para cópias em outras dimensões)

local function attr(node, name, default)
    local v = xmlNodeGetAttribute(node, name)
    if v == nil or v == "" then return default end
    return v
end
local function num(node, name, default)
    return tonumber(attr(node, name)) or default
end
local function bool(node, name, default)
    local v = attr(node, name)
    if v == nil then return default end
    return v == "true" or v == "1"
end

local function arenaHasWeapon(arena, weaponId)
    for _, w in ipairs(arena.weapons or {}) do
        if w[1] == weaponId then return true end
    end
    return false
end

local function createObjectFrom(def, dimension, parent)
    local obj = createObject(def.model, def.x, def.y, def.z, def.rx, def.ry, def.rz, def.lod)
    if not obj then return nil end
    setElementParent(obj, parent)
    setElementDimension(obj, dimension)
    setElementInterior(obj, def.interior)

    -- Identifica o objeto para o cliente saber quando a geometria da arena já foi streamada.
    if def.arenaId then
        setElementData(obj, "dm:mapArena", def.arenaId)
    end

    if def.scale ~= 1 then setObjectScale(obj, def.scale) end
    if def.alpha ~= 255 then setElementAlpha(obj, def.alpha) end
    if def.doublesided then setElementDoubleSided(obj, true) end

    -- Não dependa do valor padrão do GTA: aplica a colisão explicitamente.
    -- Isso evita objetos visíveis porém atravessáveis depois de trocar de dimensão.
    setElementCollisionsEnabled(obj, def.collisions ~= false)

    if not def.breakable then setObjectBreakable(obj, false) end
    if def.frozen then setElementFrozen(obj, true) end
    return obj
end

-- Cria uma cópia dos objetos do mapa da arena em outra dimensão (salas privadas de duelo).
-- Retorna o elemento pai (destrua-o com destroyElement para remover a cópia).
function createArenaMapCopy(arenaId, dimension)
    local defs = arenaObjects[arenaId]
    if not defs or #defs == 0 then return false end
    local parent = createElement("arena-map-copy", ("copy_%s_%d"):format(arenaId, dimension))
    for _, def in ipairs(defs) do
        createObjectFrom(def, dimension, parent)
    end
    return parent
end

function hasArenaMap(arenaId)
    return arenaObjects[arenaId] ~= nil and #arenaObjects[arenaId] > 0
end

local function loadMapFile(path, arena, parent, stats, spawns)
    local xml = xmlLoadFile(path)
    if not xml then
        outputDebugString("[dm_maps] Não foi possível ler " .. path, 2)
        return false
    end
    for _, node in ipairs(xmlNodeGetChildren(xml)) do
        local tag = xmlNodeGetName(node)
        if tag == "object" then
            local model = num(node, "model")
            if model then
                local def = {
                    arenaId = arena.id,
                    model = model, x = num(node, "posX", 0), y = num(node, "posY", 0), z = num(node, "posZ", 0),
                    rx = num(node, "rotX", 0), ry = num(node, "rotY", 0), rz = num(node, "rotZ", 0), lod = bool(node, "lod", false),
                    interior = num(node, "interior", 0), scale = num(node, "scale", 1), alpha = num(node, "alpha", 255),
                    doublesided = bool(node, "doublesided", false), collisions = bool(node, "collisions", true),
                    breakable = bool(node, "breakable", true), frozen = bool(node, "frozen", false),
                }
                arenaObjects[arena.id] = arenaObjects[arena.id] or {}
                table.insert(arenaObjects[arena.id], def)
                if createObjectFrom(def, arena.dimension, parent) then
                    stats.objects = stats.objects + 1
                end
            end
        elseif tag == "removeWorldObject" then
            local model = num(node, "model")
            local radius = num(node, "radius", 1)
            local x, y, z = num(node, "posX", 0), num(node, "posY", 0), num(node, "posZ", 0)
            local interior = num(node, "interior", 0)
            if model then
                removeWorldModel(model, radius, x, y, z, interior)
                removed[#removed + 1] = { model, radius, x, y, z, interior }
                local lod = num(node, "lodModel", 0)
                if lod and lod > 0 then
                    removeWorldModel(lod, radius, x, y, z, interior)
                    removed[#removed + 1] = { lod, radius, x, y, z, interior }
                end
                stats.removed = stats.removed + 1
            end
        elseif tag == "pickup" then
            local ptype = attr(node, "type", "health")
            local x, y, z = num(node, "posX", 0), num(node, "posY", 0), num(node, "posZ", 0)
            local respawn = num(node, "respawn", 30000)
            if respawn <= 0 then respawn = 20000 end
            local pickup
            if ptype == "health" then
                pickup = createPickup(x, y, z, 0, num(node, "amount", 100), respawn)
            elseif ptype == "armor" then
                pickup = createPickup(x, y, z, 1, num(node, "amount", 100), respawn)
            else
                local weaponId = tonumber(ptype)
                if weaponId and arenaHasWeapon(arena, weaponId) then
                    pickup = createPickup(x, y, z, 2, weaponId, respawn, num(node, "amount", 100))
                else
                    stats.skippedPickups = stats.skippedPickups + 1
                end
            end
            if pickup then
                setElementParent(pickup, parent)
                setElementDimension(pickup, arena.dimension)
                setElementInterior(pickup, num(node, "interior", 0))
                stats.pickups = stats.pickups + 1
            end
        elseif tag == "spawnpoint" then
            spawns[#spawns + 1] = { num(node, "posX", 0), num(node, "posY", 0), num(node, "posZ", 0), num(node, "rotZ", num(node, "rotation", 0)) }
        end
    end
    xmlUnloadFile(xml)
    return true
end

local function loadArenaMaps(arena)
    local files = {}
    if fileExists("maps/" .. arena.id .. ".map") then files[#files + 1] = "maps/" .. arena.id .. ".map" end
    for i = 2, 9 do
        local p = ("maps/%s_%d.map"):format(arena.id, i)
        if fileExists(p) then files[#files + 1] = p end
    end
    if #files == 0 then
        setElementData(root, "dm:hasMap:" .. arena.id, false)
        setElementData(root, "dm:mapObjectCount:" .. arena.id, 0)
        return
    end

    local parent = createElement("arena-map", "map_" .. arena.id)
    roots[arena.id] = parent
    local stats = { objects = 0, removed = 0, pickups = 0, skippedPickups = 0 }
    local spawns = {}
    for _, path in ipairs(files) do
        loadMapFile(path, arena, parent, stats, spawns)
    end
    setElementData(root, "dm:hasMap:" .. arena.id, stats.objects > 0)
    setElementData(root, "dm:mapObjectCount:" .. arena.id, stats.objects)

    if #spawns > 0 then
        core:setArenaSpawns(arena.id, spawns, "map")
    end
    outputServerLog(("[dm_maps] %s: %d arquivo(s), %d objetos, %d remoções, %d pickups (%d de arma ignorados), %d spawnpoints"):format(
        arena.name, #files, stats.objects, stats.removed, stats.pickups, stats.skippedPickups, #spawns))
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, arena in ipairs(core:getArenas()) do
        loadArenaMaps(arena)
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, r in ipairs(removed) do
        restoreWorldModel(r[1], r[2], r[3], r[4], r[5], r[6])
    end
    removed = {}
end)
