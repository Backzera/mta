--[[
    Aplica skins de arma (texturas) por jogador via shader de troca de textura, e carrega
    modelos de skin personalizados (models/skins/<model>.dff/.txd) quando existirem.
]]

local core = exports.dm_core
local CRATES
local shaders = {}       -- key -> shader
local applied = {}       -- player -> { key = ..., names = {...} }
local GUN_MODELS = { 346, 347, 348, 349, 350, 351, 352, 353, 355, 356, 357, 358, 362, 372 }
local textureNames

local function cfg()
    if not CRATES then CRATES = core:getCratesConfig() end
    return CRATES
end

local function item(key)
    for _, it in ipairs(cfg().items) do if it.key == key then return it end end
end

local function getNames()
    if textureNames then return textureNames end
    textureNames = {}
    for _, model in ipairs(GUN_MODELS) do
        local names = engineGetModelTextureNames and engineGetModelTextureNames(tostring(model)) or nil
        if names then for _, n in ipairs(names) do textureNames[#textureNames + 1] = n end end
    end
    return textureNames
end

local function getShader(key)
    if shaders[key] ~= nil then return shaders[key] end
    local it = item(key)
    local path = it and it.texture and ("textures/" .. it.texture) or nil
    if not path or not fileExists(path) then shaders[key] = false return false end
    local shader = dxCreateShader("texreplace.fx", 0, 0, false, "ped")
    local tex = dxCreateTexture(path)
    if not shader or not tex then shaders[key] = false return false end
    dxSetShaderValue(shader, "Tex0", tex)
    shaders[key] = shader
    return shader
end

local function clearPlayer(player)
    local a = applied[player]
    if not a then return end
    local shader = shaders[a.key]
    if shader then
        for _, n in ipairs(a.names) do engineRemoveShaderFromWorldTexture(shader, n, player) end
    end
    applied[player] = nil
end

local function applyPlayer(player)
    clearPlayer(player)
    local key = getElementData(player, "dm:wskin")
    if not key or key == false then return end
    local shader = getShader(key)
    if not shader then return end
    local names = {}
    for _, n in ipairs(getNames()) do
        if engineApplyShaderToWorldTexture(shader, n, player) then names[#names + 1] = n end
    end
    applied[player] = { key = key, names = names }
end

addEventHandler("onClientElementDataChange", root, function(key)
    if key == "dm:wskin" and getElementType(source) == "player" then applyPlayer(source) end
end)
addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "player" then applyPlayer(source) end
end)
addEventHandler("onClientPlayerQuit", root, function() clearPlayer(source) end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- skins personalizadas de pele (opcional): models/skins/<model>.dff/.txd
    for _, it in ipairs(cfg().items) do
        if it.type == "skin" and it.model then
            local dff, txd = ("models/skins/%d.dff"):format(it.model), ("models/skins/%d.txd"):format(it.model)
            if fileExists(dff) and fileExists(txd) then
                local t = engineLoadTXD(txd) if t then engineImportTXD(t, it.model) end
                local d = engineLoadDFF(dff) if d then engineReplaceModel(d, it.model) end
            end
        end
    end
    setTimer(function()
        for _, p in ipairs(getElementsByType("player", root, true)) do applyPlayer(p) end
        applyPlayer(localPlayer)
    end, 1500, 1)
end)
