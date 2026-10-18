--[[
    Skins de arma: substitui o modelo de cada arma que tiver models/<id>.dff + models/<id>.txd
    (os arquivos precisam estar listados no meta.xml — veja models/LEIA-ME.txt).
]]

local WEAPON_MODELS = { [22] = 346, [23] = 347, [24] = 348, [25] = 349, [26] = 350, [27] = 351, [28] = 352, [29] = 353,
                        [30] = 355, [31] = 356, [32] = 372, [33] = 357, [34] = 358, [38] = 362, [8] = 339, [4] = 335 }

addEventHandler("onClientResourceStart", resourceRoot, function()
    local applied = 0
    for weaponId, model in pairs(WEAPON_MODELS) do
        local dffPath, txdPath = ("models/%d.dff"):format(weaponId), ("models/%d.txd"):format(weaponId)
        if fileExists(dffPath) and fileExists(txdPath) then
            local txd = engineLoadTXD(txdPath)
            if txd then engineImportTXD(txd, model) end
            local dff = engineLoadDFF(dffPath)
            if dff and engineReplaceModel(dff, model) then applied = applied + 1 end
        end
    end
    if applied > 0 then outputDebugString(("[dm_weapons] %d skin(s) de arma aplicadas"):format(applied)) end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, model in pairs(WEAPON_MODELS) do engineRestoreModel(model) end
end)
