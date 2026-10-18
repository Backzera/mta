-- DM Skins: carrega os 7 modelos personalizados para IDs de ped usados pelo inventário de caixas.
-- Miku e Sakura usam as variantes DFF_Normal; as animações extras do Modloader não são ativadas.
local SKINS = {
    { id = 298, name = "Hatsune Miku", dff = "1/DFF_Normal/M077SonicMiku.dff", txd = "1/Textures(TXD)/M077SonicMiku.txd" },
    { id = 299, name = "Sakura Miku", dff = "2/DFF_Normal/M082SakuraMiku.dff", txd = "2/Textures(TXD)/M082SakuraMiku.txd" },
    { id = 300, name = "Roronoa Zoro", dff = "3/Zoro.dff", txd = "3/Zoro.txd" },
    { id = 301, name = "Monkey D. Luffy", dff = "4/Lufy.dff", txd = "4/Lufy.txd" },
    { id = 302, name = "Usada Pekora", dff = "5/Usada_Pekora.dff", txd = "5/Usada_Pekora.txd" },
    { id = 303, name = "Tanjiro Kamado", dff = "6/TanjiroDS.dff", txd = "6/TanjiroDS.txd" },
    { id = 304, name = "Naruto Bijuu", dff = "7/Naruto_Bijuu.dff", txd = "7/Naruto_Bijuu.txd" },
}

local loadedModels = {}

local function loadSkins()
    local loaded = 0

    for _, skin in ipairs(SKINS) do
        if not fileExists(skin.txd) or not fileExists(skin.dff) then
            outputDebugString(("[dm_skins] Arquivo ausente para %s (ID %d)."):format(skin.name, skin.id), 1)
        else
            -- Ordem correta: TXD primeiro, depois DFF.
            local txd = engineLoadTXD(skin.txd, false)
            if not txd then
                outputDebugString(("[dm_skins] Falha ao carregar TXD de %s: %s"):format(skin.name, skin.txd), 1)
            else
                local imported = engineImportTXD(txd, skin.id)
                if not imported then
                    outputDebugString(("[dm_skins] Falha ao importar a TXD de %s (ID %d): %s"):format(skin.name, skin.id, skin.txd), 1)
                    if isElement(txd) then destroyElement(txd) end
                else
                    local dff = engineLoadDFF(skin.dff)
                    if not dff then
                        outputDebugString(("[dm_skins] Falha ao carregar o DFF de %s (ID %d): %s"):format(skin.name, skin.id, skin.dff), 1)
                        if isElement(txd) then destroyElement(txd) end
                    elseif not engineReplaceModel(dff, skin.id) then
                        outputDebugString(("[dm_skins] engineReplaceModel falhou para %s (ID %d). Veja o erro acima no debugscript."):format(skin.name, skin.id), 1)
                        if isElement(dff) then destroyElement(dff) end
                        if isElement(txd) then destroyElement(txd) end
                        engineRestoreModel(skin.id)
                    else
                        loadedModels[skin.id] = { txd = txd, dff = dff }
                        loaded = loaded + 1

                        outputDebugString(("[dm_skins] Skin carregada: %s (ID %d)."):format(skin.name, skin.id), 3)
                    end
                end
            end
        end
    end

    outputDebugString(("[dm_skins] %d/%d skins carregadas."):format(loaded, #SKINS), loaded == #SKINS and 3 or 2)
end

addEventHandler("onClientResourceStart", resourceRoot, loadSkins)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for modelID, data in pairs(loadedModels) do
        engineRestoreModel(modelID)
        if isElement(data.dff) then destroyElement(data.dff) end
        if isElement(data.txd) then destroyElement(data.txd) end
    end
    loadedModels = {}
end)
