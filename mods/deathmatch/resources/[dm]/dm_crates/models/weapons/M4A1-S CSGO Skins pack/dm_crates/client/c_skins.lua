--[[
    Skins de arma por jogador.
      · Modelo base (models/<arma>.dff/.txd, packs CS:GO) substitui a arma do GTA para todos.
      · A skin de cada jogador é a TEXTURA principal do modelo (skins/<arma>/<key>.png) aplicada com um
        shader de troca de textura restrito ao ped daquele jogador: cada um vê a skin de cada um.
      · DM.crates.skinMode = "local": alternativa (você vê a SUA skin em todas as armas daquele tipo).
      · Skins antigas (weapon = "all") continuam trocando as texturas das outras armas do GTA.
      · Skins de pele personalizadas (models/skins/<model>.dff/.txd) quando existirem.
]]
local core = exports.dm_core
local CRATES
local shaders = {}       -- key -> shader (ou false)
local applied = {}       -- player -> { { shader, names } ... }
local GUN_MODELS = { 346, 347, 348, 349, 350, 351, 352, 353, 357, 358, 362, 372 }  -- outras armas (AK/M4 têm modelo próprio)
local legacyNames

local function cfg()
    if not CRATES then CRATES = core:getCratesConfig() end
    return CRATES
end
local function item(key)
    for _, it in ipairs(cfg().items) do if it.key == key then return it end end
end
local function mode() return cfg().skinMode or "player" end

local function getLegacyNames()
    if legacyNames then return legacyNames end
    legacyNames = {}
    for _, model in ipairs(GUN_MODELS) do
        local names = engineGetModelTextureNames and engineGetModelTextureNames(tostring(model)) or nil
        if names then for _, n in ipairs(names) do legacyNames[#legacyNames + 1] = n end end
    end
    return legacyNames
end

-- Textura da skin: skins/<arma>/<key>.png (CS:GO) ou textures/<arquivo> (antigas)
local function texturePath(it)
    if it.weapon and it.weapon ~= "all" then return ("skins/%s/%s.png"):format(it.weapon, it.key) end
    return it.texture and ("textures/" .. it.texture) or nil
end

local function getShader(key)
    if shaders[key] ~= nil then return shaders[key] end
    local it = item(key)
    local path = it and texturePath(it)
    if not path or not fileExists(path) then shaders[key] = false return false end
    local shader = dxCreateShader("texreplace.fx", 0, 0, false, mode() == "player" and "ped" or "all")
    local tex = dxCreateTexture(path, "dxt5", true)
    if not shader or not tex then shaders[key] = false return false end
    dxSetShaderValue(shader, "Tex0", tex)
    shaders[key] = shader
    return shader
end

-- nomes de textura que uma skin troca
local function namesFor(it)
    if it.weapon and it.weapon ~= "all" then
        local w = cfg().weaponSkins and cfg().weaponSkins[it.weapon]
        return w and { w.texture } or {}
    end
    return getLegacyNames()
end

local function clearPlayer(player)
    local list = applied[player]
    if not list then return end
    for _, a in ipairs(list) do
        for _, n in ipairs(a.names) do
            if mode() == "player" then engineRemoveShaderFromWorldTexture(a.shader, n, player) else engineRemoveShaderFromWorldTexture(a.shader, n) end
        end
    end
    applied[player] = nil
end

local function applyPlayer(player)
    clearPlayer(player)
    if mode() == "local" and player ~= localPlayer then return end
    local equipped = getElementData(player, "dm:wskin")
    if type(equipped) == "string" then equipped = { all = equipped } end
    if type(equipped) ~= "table" then return end
    local list = {}
    for _, key in pairs(equipped) do
        local it = item(key)
        local shader = it and getShader(key)
        if shader then
            local names = {}
            for _, n in ipairs(namesFor(it)) do
                local ok
                if mode() == "player" then ok = engineApplyShaderToWorldTexture(shader, n, player) else ok = engineApplyShaderToWorldTexture(shader, n) end
                if ok then names[#names + 1] = n end
            end
            list[#list + 1] = { shader = shader, names = names }
        end
    end
    applied[player] = list
end

addEventHandler("onClientElementDataChange", root, function(key)
    if key == "dm:wskin" and getElementType(source) == "player" then applyPlayer(source) end
end)
addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "player" then applyPlayer(source) end
end)
addEventHandler("onClientPlayerQuit", root, function() clearPlayer(source) end)

-- Modelos base das armas com skin (todos veem o mesmo modelo; a textura é por jogador)
local function loadBaseModels()
    for wkey, w in pairs(cfg().weaponSkins or {}) do
        local dff, txd = ("models/%s.dff"):format(wkey), ("models/%s.txd"):format(wkey)
        if fileExists(dff) and fileExists(txd) then
            local t = engineLoadTXD(txd)
            if t then engineImportTXD(t, w.model) end
            local d = engineLoadDFF(dff)
            if d then engineReplaceModel(d, w.model) end
        else
            outputDebugString("[dm_crates] modelo base ausente: " .. dff, 2)
        end
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadBaseModels()
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
addEventHandler("onClientResourceStop", resourceRoot, function()
    for wkey, w in pairs(cfg().weaponSkins or {}) do engineRestoreModel(w.model) end
end)
