--[[
    Caixas: abrir com $, sorteio ponderado por raridade, inventário (perks "item:<key>"),
    equipar skin (pele) e skin de arma. Itens repetidos devolvem 50% do preço da caixa.
]]

local core = exports.dm_core
local CRATES

local function cfg()
    if not CRATES then CRATES = core:getCratesConfig() end
    return CRATES
end
local function item(key)
    for _, it in ipairs(cfg().items) do if it.key == key then return it end end
end
local function box(key)
    for _, b in ipairs(cfg().boxes) do if b.key == key then return b end end
end
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end

local function pick(b)
    local total = 0
    for _, d in ipairs(b.pool) do total = total + d.weight end
    local r = math.random() * total
    for _, d in ipairs(b.pool) do
        r = r - d.weight
        if r <= 0 then return item(d.item) end
    end
    return item(b.pool[#b.pool].item)
end

addEvent("crates:open", true)
addEventHandler("crates:open", root, function(boxKey)
    local player = client
    if player ~= source or not getElementData(player, "dm:ready") then return end
    local b = box(boxKey)
    if not b then return end
    if not core:takeMoney(player, b.price) then
        core:notifyPlayer(player, ("Saldo insuficiente. A %s custa %s."):format(b.name, core:formatMoney(b.price)), "error", "Caixas")
        return
    end
    local it = pick(b)
    if not it then return end
    local duplicate = false
    if it.type == "money" then
        core:addMoney(player, it.amount, "Caixa", true)
    else
        if core:playerHasPerk(player, "item:" .. it.key) then
            duplicate = true
            core:addMoney(player, math.floor(b.price * 0.5), "Item repetido", true)
        else
            core:givePlayerPerk(player, "item:" .. it.key)
        end
    end
    triggerClientEvent(player, "crates:result", resourceRoot, boxKey, it.key, duplicate)
    if it.rarity == "lendaria" or it.rarity == "epica" then
        core:sendServerMessage(root, ("#F5C451✦ CAIXAS #8FA39A» #FFFFFF%s #969BB4abriu uma %s e tirou #FFFFFF%s #969BB4(%s)!"):format(nick(player), b.name, it.name, it.rarity:upper()))
    end
end)

addEvent("crates:equip", true)
addEventHandler("crates:equip", root, function(key)
    local player = client
    if player ~= source then return end
    if key == "skin:none" then
        core:setPlayerStat(player, "equip_skin", 0)
        setElementData(player, "dm:skin", false)
        core:notifyPlayer(player, "Skin padrão (aleatória) equipada.", "info", "Caixas")
        return
    end
    if key == "wskin:none" then
        core:setPlayerStat(player, "equip_wskin", "")
        setElementData(player, "dm:wskin", false)
        core:notifyPlayer(player, "Skin de arma removida.", "info", "Caixas")
        return
    end
    local it = item(key)
    if not it or not core:playerHasPerk(player, "item:" .. key) then return end
    if it.type == "skin" then
        core:setPlayerStat(player, "equip_skin", it.model)
        setElementData(player, "dm:skin", it.model)
        if not isPedDead(player) then setElementModel(player, it.model) end
        core:notifyPlayer(player, ("Skin equipada: %s"):format(it.name), "success", "Caixas")
    elseif it.type == "wskin" then
        core:setPlayerStat(player, "equip_wskin", it.key)
        setElementData(player, "dm:wskin", it.key)
        core:notifyPlayer(player, ("Skin de arma equipada: %s"):format(it.name), "success", "Caixas")
    end
end)

-- Ao carregar as stats, aplica o que estava equipado
addEvent("dm:onStatsLoaded")
addEventHandler("dm:onStatsLoaded", root, function()
    local row = core:getPlayerStats(source)
    if not row then return end
    if (tonumber(row.equip_skin) or 0) > 0 then setElementData(source, "dm:skin", tonumber(row.equip_skin)) end
    if row.equip_wskin and row.equip_wskin ~= "" then setElementData(source, "dm:wskin", row.equip_wskin) else setElementData(source, "dm:wskin", false) end
end)

addCommandHandler("caixas", function(player) triggerClientEvent(player, "crates:openPanel", resourceRoot) end)
