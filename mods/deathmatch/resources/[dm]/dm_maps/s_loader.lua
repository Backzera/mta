--[[
    DM Maps v2

    Os mapas principais são carregados NATIVAMENTE pelo MTA através das tags
    <map> do meta.xml. Este script NÃO recria os objetos principais com
    createObject; ele apenas:
      - lê definições para cópias privadas de duelo;
      - aplica removeWorldModel;
      - filtra pickups de armas incompatíveis;
      - identifica os objetos nativos por arena para o cliente validar streaming.
]]

local core = exports.dm_core

local removed = {}
local arenaObjects = {}
local nativeObjects = {}

local NATIVE_MAPS = {
    ak47 = true,
    m4   = true,
    x1   = true,
    cbug = true,
}

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
        if tonumber(w[1]) == tonumber(weaponId) then
            return true
        end
    end
    return false
end

local function createObjectFallback(def, dimension, parent)
    local obj = createObject(def.model, def.x, def.y, def.z, def.rx, def.ry, def.rz, false)
    if not obj then return nil end

    setElementParent(obj, parent)
    setElementDimension(obj, dimension)
    setElementInterior(obj, def.interior or 0)
    setElementData(obj, "dm:mapArena", def.arenaId)

    if def.scale and def.scale ~= 1 then setObjectScale(obj, def.scale) end
    if def.alpha and def.alpha ~= 255 then setElementAlpha(obj, def.alpha) end
    if def.doublesided then setElementDoubleSided(obj, true) end

    setElementCollisionsEnabled(obj, def.collisions ~= false)
    if not def.breakable then setObjectBreakable(obj, false) end
    if def.frozen then setElementFrozen(obj, true) end

    return obj
end

local function parseMapFile(path, arena, stats, spawns)
    local xml = xmlLoadFile(path)
    if not xml then
        outputDebugString("[dm_maps] Não foi possível ler " .. path, 2)
        return false
    end

    arenaObjects[arena.id] = arenaObjects[arena.id] or {}

    for _, node in ipairs(xmlNodeGetChildren(xml)) do
        local tag = xmlNodeGetName(node)

        if tag == "object" then
            local model = num(node, "model")
            if model then
                arenaObjects[arena.id][#arenaObjects[arena.id] + 1] = {
                    arenaId = arena.id,
                    model = model,
                    x = num(node, "posX", 0),
                    y = num(node, "posY", 0),
                    z = num(node, "posZ", 0),
                    rx = num(node, "rotX", 0),
                    ry = num(node, "rotY", 0),
                    rz = num(node, "rotZ", 0),
                    interior = num(node, "interior", 0),
                    scale = num(node, "scale", 1),
                    alpha = num(node, "alpha", 255),
                    doublesided = bool(node, "doublesided", false),
                    collisions = bool(node, "collisions", true),
                    breakable = bool(node, "breakable", true),
                    frozen = bool(node, "frozen", false),
                }
                stats.objects = stats.objects + 1
            end

        elseif tag == "removeWorldObject" then
            -- removeWorldObject do editor não é confiável como elemento genérico
            -- em todos os loaders; aplicamos explicitamente.
            local model = num(node, "model")
            local radius = num(node, "radius", 1)
            local x = num(node, "posX", 0)
            local y = num(node, "posY", 0)
            local z = num(node, "posZ", 0)
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
            -- O próprio MTA cria o pickup pelo <map>. Aqui só contamos;
            -- a filtragem é feita depois que todos os elementos nativos existem.
            stats.pickups = stats.pickups + 1

        elseif tag == "spawnpoint" then
            spawns[#spawns + 1] = {
                num(node, "posX", 0),
                num(node, "posY", 0),
                num(node, "posZ", 0),
                num(node, "rotZ", num(node, "rotation", 0))
            }
        end
    end

    xmlUnloadFile(xml)
    return true
end

local function collectDefinitions(arena)
    local files = {}
    local first = "maps/" .. arena.id .. ".map"

    if fileExists(first) then
        files[#files + 1] = first
    end

    for i = 2, 9 do
        local p = ("maps/%s_%d.map"):format(arena.id, i)
        if fileExists(p) then
            files[#files + 1] = p
        end
    end

    if #files == 0 then
        setElementData(root, "dm:hasMap:" .. arena.id, false)
        setElementData(root, "dm:mapObjectCount:" .. arena.id, 0)
        return
    end

    local stats = { objects = 0, removed = 0, pickups = 0 }
    local spawns = {}

    for _, path in ipairs(files) do
        parseMapFile(path, arena, stats, spawns)
    end

    setElementData(root, "dm:hasMap:" .. arena.id, stats.objects > 0)
    setElementData(root, "dm:mapObjectCount:" .. arena.id, stats.objects)

    if #spawns > 0 then
        core:setArenaSpawns(arena.id, spawns, "map")
    end

    outputServerLog(("[dm_maps] %s: mapa nativo, %d objeto(s), %d remoção(ões), %d pickup(s), %d spawnpoint(s)"):format(
        arena.name, stats.objects, stats.removed, stats.pickups, #spawns))
end

local function indexNativeObjects()
    nativeObjects = {}

    for _, arena in ipairs(core:getArenas()) do
        if NATIVE_MAPS[arena.id] then
            nativeObjects[arena.id] = {}

            for _, obj in ipairs(getElementsByType("object", resourceRoot)) do
                if isElement(obj) and getElementDimension(obj) == arena.dimension then
                    -- O mapa principal veio do loader nativo do MTA.
                    -- Garante a flag e a colisão sem recriar o elemento.
                    setElementData(obj, "dm:mapArena", arena.id)
                    setElementCollisionsEnabled(obj, true)
                    nativeObjects[arena.id][#nativeObjects[arena.id] + 1] = obj
                end
            end

            setElementData(root, "dm:hasMap:" .. arena.id, #nativeObjects[arena.id] > 0)
            setElementData(root, "dm:mapObjectCount:" .. arena.id, #nativeObjects[arena.id])

            -- O carregamento nativo também cria pickups. Mantém vida/colete e
            -- remove apenas armas que não pertencem à arena.
            for _, pickup in ipairs(getElementsByType("pickup", resourceRoot)) do
                if isElement(pickup) and getElementDimension(pickup) == arena.dimension then
                    if getPickupType(pickup) == 2 then
                        local weapon = getPickupWeapon(pickup)
                        if not arenaHasWeapon(arena, weapon) then
                            destroyElement(pickup)
                        end
                    end
                end
            end

            outputServerLog(("[dm_maps] %s: %d objeto(s) nativos indexados na dimensão %d"):format(
                arena.name, #nativeObjects[arena.id], arena.dimension))
        end
    end
end

-- Cópias privadas de duelo. Primeiro tentamos clonar os objetos que o MTA
-- carregou nativamente; se por algum motivo ainda não foram indexados,
-- usamos as definições apenas como fallback.
function createArenaMapCopy(arenaId, dimension)
    local parent = createElement("arena-map-copy", ("copy_%s_%d"):format(arenaId, dimension))
    local created = 0

    local source = nativeObjects[arenaId]
    if source and #source > 0 then
        for _, obj in ipairs(source) do
            if isElement(obj) then
                local x, y, z = getElementPosition(obj)
                local clone = cloneElement(obj, x, y, z, false)
                if clone then
                    setElementParent(clone, parent)
                    setElementDimension(clone, dimension)
                    setElementData(clone, "dm:mapArena", arenaId)
                    setElementCollisionsEnabled(clone, true)
                    created = created + 1
                end
            end
        end
    else
        for _, def in ipairs(arenaObjects[arenaId] or {}) do
            if createObjectFallback(def, dimension, parent) then
                created = created + 1
            end
        end
    end

    if created == 0 then
        destroyElement(parent)
        return false
    end

    return parent
end

function hasArenaMap(arenaId)
    return arenaObjects[arenaId] ~= nil and #arenaObjects[arenaId] > 0
end

addEventHandler("onResourceStart", resourceRoot, function()
    -- As tags <map> já pertencem ao resource. Coletamos metadados e, logo em
    -- seguida, indexamos os elementos criados pelo loader nativo do MTA.
    for _, arena in ipairs(core:getArenas()) do
        collectDefinitions(arena)
    end

    setTimer(indexNativeObjects, 250, 1)
    setTimer(indexNativeObjects, 1200, 1) -- segunda passada para clientes/servidores lentos
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, r in ipairs(removed) do
        restoreWorldModel(r[1], r[2], r[3], r[4], r[5], r[6])
    end
    removed = {}
    nativeObjects = {}
end)
