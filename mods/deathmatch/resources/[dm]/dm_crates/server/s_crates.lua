--[[
    Caixas: abrir com $, sorteio ponderado por raridade, inventário (perks "item:<key>"),
    equipar skin (pele) e skins de arma POR ARMA (uma por tipo: ak47, m4, all). Repetidos devolvem 50% do preço.
    dm:wskin = { ak47 = key, m4 = key, all = key } (salvo em equip_wskin como JSON).
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
local RARITY_RANK = { comum = 1, rara = 2, epica = 3, lendaria = 4, mitica = 5, ultimate = 6 }

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

-- equipados por arma
local function getEquipped(player)
    local e = getElementData(player, "dm:wskin")
    if type(e) == "string" then return { all = e } end
    return type(e) == "table" and e or {}
end
local TRAIL_RARITY = { mitica = true, ultimate = true }
local function ownsTrailSkin(player)
    for _, it in ipairs(cfg().items) do
        if it.type == "wskin" and TRAIL_RARITY[it.rarity] and core:playerHasPerk(player, "item:" .. it.key) then return true end
    end
    return false
end
local function saveEquipped(player, e)
    local n = 0
    for w in pairs(e) do if w ~= "trail" then n = n + 1 end end
    setElementData(player, "dm:wskin", n > 0 and e or false)
    core:setPlayerStat(player, "equip_wskin", n > 0 and toJSON(e) or "")
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
    local rank = RARITY_RANK[it.rarity] or 0
    local rname = (cfg().rarities[it.rarity] and cfg().rarities[it.rarity].name or it.rarity):upper()
    if rank >= 6 then
        core:sendServerMessage(root, ("#7CFFB2✦✦✦ ULTIMATE #8FA39A» #FFFFFF%s #969BB4abriu uma %s e tirou a #7CFFB2%s#969BB4! Uma das skins mais raras do servidor!"):format(nick(player), b.name, it.name))
    elseif rank >= 4 then
        core:sendServerMessage(root, ("#F5C451✦ CAIXAS #8FA39A» #FFFFFF%s #969BB4abriu uma %s e tirou #FFFFFF%s #969BB4(%s)!"):format(nick(player), b.name, it.name, rname))
    end
end)

-- cor do rastro (skins Mítica/Ultimate): "skin" (padrão), "rgb" ou "#RRGGBB"
addEvent("crates:trail", true)
addEventHandler("crates:trail", root, function(value)
    local player = client
    if player ~= source then return end
    if not ownsTrailSkin(player) and not core:isPlayerAdmin(player) then core:notifyPlayer(player, "Você precisa de uma skin Mítica ou Ultimate.", "warn", "Rastro") return end
    local e = getEquipped(player)
    if value == "rgb" then e.trail = "rgb"
    elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then e.trail = value:upper()
    else e.trail = nil end
    saveEquipped(player, e)
    core:notifyPlayer(player, e.trail == "rgb" and "Rastro RGB ativado!" or (e.trail and "Cor do rastro: " .. e.trail or "Rastro na cor da skin."), "success", "Rastro")
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
        saveEquipped(player, {})
        core:notifyPlayer(player, "Skins de arma removidas.", "info", "Caixas")
        return
    end
    local slot = key:match("^wskin:none:(%w+)$")
    if slot then
        local e = getEquipped(player)
        e[slot] = nil
        saveEquipped(player, e)
        core:notifyPlayer(player, "Skin removida.", "info", "Caixas")
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
        local e = getEquipped(player)
        local w = it.weapon or "all"
        if e[w] == it.key then
            e[w] = nil
            saveEquipped(player, e)
            core:notifyPlayer(player, ("Skin removida: %s"):format(it.name), "info", "Caixas")
        else
            e[w] = it.key
            saveEquipped(player, e)
            core:notifyPlayer(player, ("Skin equipada: %s"):format(it.name), "success", "Caixas")
        end
    end
end)

-- Ao carregar as stats, aplica o que estava equipado
addEvent("dm:onStatsLoaded")
addEventHandler("dm:onStatsLoaded", root, function()
    local row = core:getPlayerStats(source)
    if not row then return end
    if (tonumber(row.equip_skin) or 0) > 0 then setElementData(source, "dm:skin", tonumber(row.equip_skin)) end
    local saved = row.equip_wskin
    if saved and saved ~= "" then
        local e = saved:sub(1, 1) == "[" and fromJSON(saved) or { all = saved }
        local clean = {}
        for w, k in pairs(type(e) == "table" and e or {}) do if w == "trail" or item(k) then clean[w] = k end end
        local n = 0
        for _ in pairs(clean) do n = n + 1 end
        setElementData(source, "dm:wskin", n > 0 and clean or false)
    else
        setElementData(source, "dm:wskin", false)
    end
end)

addCommandHandler("caixas", function(player) triggerClientEvent(player, "crates:openPanel", resourceRoot) end)

-- ---------- comandos de admin para testar ----------
-- /skins [ak47|m4]        lista as chaves das skins
-- /darskin <chave>        dá a skin e já equipa (admin)
-- /darskin todas          dá todas as skins (admin)
local function equipKey(player, key)
    local it = item(key)
    if not it then return false end
    if not core:playerHasPerk(player, "item:" .. key) then core:givePlayerPerk(player, "item:" .. key) end
    if it.type == "wskin" then
        local e = getEquipped(player)
        e[it.weapon or "all"] = key
        saveEquipped(player, e)
    elseif it.type == "skin" then
        core:setPlayerStat(player, "equip_skin", it.model)
        setElementData(player, "dm:skin", it.model)
        if not isPedDead(player) then setElementModel(player, it.model) end
    end
    return it
end
addCommandHandler("skins", function(player, _, filter)
    local out = {}
    for _, it in ipairs(cfg().items) do
        if it.type == "wskin" and (not filter or it.weapon == filter) then out[#out + 1] = it.key end
    end
    -- o chat do MTA descarta mensagens longas: 4 chaves por linha
    outputChatBox(("#7CFFB2[skins] #FFFFFF%d skins%s · use /darskin <chave> (admin)"):format(#out, filter and (" de " .. filter) or ""), player, 255, 255, 255, true)
    for i = 1, #out, 4 do
        outputChatBox("#7CFFB2» #FFFFFF" .. table.concat(out, "  ", i, math.min(i + 3, #out)), player, 255, 255, 255, true)
    end
end)
-- /darskin <chave|todas>            para você
-- /darskin <jogador|id> <chave|todas>  para outro jogador
addCommandHandler("darskin", function(player, _, a, b)
    if not core:isPlayerAdmin(player) then core:notifyPlayer(player, "Só admin.", "error", "Skins") return end
    if not a then core:notifyPlayer(player, "Use /darskin <chave|todas> ou /darskin <jogador> <chave|todas>. Veja /skins.", "warn", "Skins") return end
    local target, key = player, a
    if b then
        target = core:findPlayer(a)
        key = b
        if not target then core:notifyPlayer(player, "Jogador não encontrado: " .. a, "error", "Skins") return end
    end
    if key == "todas" then
        local n = 0
        for _, it in ipairs(cfg().items) do
            if it.type ~= "money" and not core:playerHasPerk(target, "item:" .. it.key) then core:givePlayerPerk(target, "item:" .. it.key) n = n + 1 end
        end
        core:notifyPlayer(target, ("%d itens adicionados ao inventário (F7)."):format(n), "success", "Skins")
        if target ~= player then core:notifyPlayer(player, ("%d itens dados para %s."):format(n, nick(target)), "success", "Skins") end
        return
    end
    local it = equipKey(target, key)
    if it then
        core:notifyPlayer(target, ("Equipada: %s (%s)"):format(it.name, it.rarity), "success", "Skins")
        if target ~= player then core:notifyPlayer(player, ("%s equipada em %s."):format(it.name, nick(target)), "success", "Skins") end
    else core:notifyPlayer(player, "Chave inválida. Veja /skins.", "error", "Skins") end
end)
