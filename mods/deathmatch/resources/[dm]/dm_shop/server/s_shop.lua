--[[
    Loja: compra e equipa tags/cores, VIP e extras. Itens comprados ficam em perks ("tag:<key>", "color:<key>").
]]

local core = exports.dm_core
local SHOP, VIP

local function cfg()
    if not SHOP then
        SHOP = core:getShopConfig()
        VIP = core:getVipConfig()
    end
end

local function find(list, key)
    for _, item in ipairs(list) do if item.key == key then return item end end
    return nil
end

local function result(player, ok, msg)
    triggerClientEvent(player, "shop:result", resourceRoot, ok, msg)
    core:notifyPlayer(player, msg, ok and "success" or "error", "Loja")
end

addEvent("shop:buy", true)
addEventHandler("shop:buy", root, function(category, key)
    local player = client
    if player ~= source or not getElementData(player, "dm:ready") then return end
    cfg()
    if category == "tags" then
        local item = find(SHOP.tags, key)
        if not item then return end
        if core:playerHasPerk(player, "tag:" .. key) then
            core:setPlayerStat(player, "tag", key)
            core:refreshPlayerTag(player)
            return result(player, true, "Tag equipada: " .. item.text)
        end
        if not core:takeMoney(player, item.price) then return result(player, false, "Saldo insuficiente. Faltam " .. core:formatMoney(item.price - core:getPlayerMoney(player)) .. ".") end
        core:givePlayerPerk(player, "tag:" .. key)
        core:setPlayerStat(player, "tag", key)
        core:refreshPlayerTag(player)
        result(player, true, ("Você comprou a tag %s!%s"):format(item.text, item.custom and " Use /tag <texto> para definir." or ""))
    elseif category == "nameColors" then
        local item = find(SHOP.nameColors, key)
        if not item then return end
        if core:playerHasPerk(player, "color:" .. key) then
            core:setPlayerStat(player, "name_color", key)
            core:refreshPlayerTag(player)
            return result(player, true, "Cor de nick equipada: " .. item.name)
        end
        if not core:takeMoney(player, item.price) then return result(player, false, "Saldo insuficiente.") end
        core:givePlayerPerk(player, "color:" .. key)
        core:setPlayerStat(player, "name_color", key)
        core:refreshPlayerTag(player)
        result(player, true, "Cor de nick comprada: " .. item.name)
    elseif category == "vip" then
        local level = tonumber(key)
        local item = level and VIP[level]
        if not item then return end
        local current = core:isPlayerVip(player)
        if current > level then return result(player, false, "Você já tem um VIP superior.") end
        if not core:takeMoney(player, item.price) then return result(player, false, "Saldo insuficiente.") end
        core:setPlayerVip(player, level, item.days)
        core:refreshPlayerTag(player)
        result(player, true, ("%s ativado por %d dias!"):format(item.name, item.days))
        core:sendServerMessage(root, ("#FFFFFF%s #969BB4agora é #F5C451%s#969BB4!"):format(core:getPlayerVisibleName(player), item.name))
    elseif category == "extras" then
        local item = find(SHOP.extras, key)
        if not item then return end
        if core:playerHasPerk(player, key) then return result(player, false, "Você já tem esse item.") end
        if not core:takeMoney(player, item.price) then return result(player, false, "Saldo insuficiente.") end
        core:givePlayerPerk(player, key)
        result(player, true, "Comprado: " .. item.name)
    elseif category == "unequip" then
        if key == "tag" then core:setPlayerStat(player, "tag", "") end
        if key == "color" then core:setPlayerStat(player, "name_color", "") end
        core:refreshPlayerTag(player)
        result(player, true, "Item removido.")
    end
end)

addCommandHandler("loja", function(player)
    triggerClientEvent(player, "shop:open", resourceRoot)
end)
