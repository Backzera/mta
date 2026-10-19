--[[
    HUD (CEF): status, arma, arena, dicas, killfeed, notificações, feedback de kill, sequências,
    popups de $ — dados enviados ~10x/s para a página; eventos viram "push".
]]
local core = exports.dm_core
local fps, frames, fpsTick = 0, 0, getTickCount()
local spawnTick = 0
local lastSig = nil
local skinCatalog, skinByKey
local population = { tick = -1000, online = 0, counts = {} }
local function refreshPopulation()
    local now = getTickCount()
    if now - population.tick < 1000 then return end
    local players, counts = getElementsByType("player"), {}
    for _, p in ipairs(players) do
        local key = tostring(getElementData(p, "dm:arena")) .. ":" .. getElementDimension(p)
        counts[key] = (counts[key] or 0) + 1
    end
    population = { tick = now, online = #players, counts = counts }
end
addEventHandler("onClientResourceStart", root, function(res)
    if getResourceName(res) == "dm_core" then skinCatalog, skinByKey = nil, nil end
end)

local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local WEAPON_ICONS = { [4] = true, [16] = true, [23] = true, [24] = true, [25] = true, [29] = true, [30] = true, [31] = true, [34] = true }
local WEAPON_KEY = { [30] = "ak47", [31] = "m4" }
local function hexColor(c) return ("#%02X%02X%02X"):format(c[1], c[2], c[3]) end
-- skin equipada por um jogador na arma (nome, cor da raridade, preview) ou false
local function skinInfo(player, weapon)
    local wkey = WEAPON_KEY[weapon]
    if not wkey then return false end
    local e = getElementData(player, "dm:wskin")
    if type(e) ~= "table" or not e[wkey] then return false end
    if not skinCatalog then
        skinCatalog, skinByKey = core:getCratesConfig(), {}
        for _, it in ipairs(skinCatalog.items) do skinByKey[it.key] = it end
    end
    local it = skinByKey[e[wkey]]
    if it then
        local r = skinCatalog.rarities[it.rarity]
        return { name = (it.name:gsub("^[^|]*| ", "")), rarity = r and r.name or it.rarity, color = r and hexColor(r.color) or "#FFFFFF", preview = it.preview and (it.key .. ".png") or false, trail = e.trail or false }
    end
    return false
end
local function tagOf(data)
    if type(data) ~= "table" or not data.text then return false end
    local hex = data.hex
    if not hex and type(data.color) == "table" then hex = ("#%02X%02X%02X"):format(data.color[1], data.color[2], data.color[3]) end
    return { text = data.text, hex = hex or "#7CFFB2", glyph = data.glyph or "" }
end

local function arenaInfo()
    local arena = core:getPlayerArena(localPlayer)
    if not arena then return false end
    refreshPopulation()
    local players = population.counts[tostring(arena.id) .. ":" .. getElementDimension(localPlayer)] or 0
    return { id = arena.id, name = arena.name, color = arena.color, players = players, safe = arena.safe == true, type = arena.type }
end

local function hints(arena)
    if not arena or UI.getOpenPanel() then return {} end
    if arena.type == "lobby" then return { { "F2", "Jogar" }, { "F3", "Duelo" }, { "F4", "Loja" }, { "F6", "Clã" }, { "F7", "Caixas" }, { "F10", "Personagens" }, { "TAB", "Placar" } } end
    if arena.type == "duel" then return { { "F3", "Desafiar" }, { "F2", "Arenas" }, { "/lobby", "Voltar" } } end
    return {}
end

local function pushHud()
    local open = UI.getOpenPanel()
    if open and open ~= "board" then return end   -- HUD fica oculto com painel aberto: não reenvia
    if not getElementData(localPlayer, "dm:ready") then
        if lastSig ~= "off" then lastSig = "off" UI.set("hud", { visible = false }) end
        return
    end
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    refreshPopulation()
    local tier = core:getTierForRP(rp)
    local weapon = getPedWeapon(localPlayer)
    local clip, total = getPedAmmoInClip(localPlayer), getPedTotalAmmo(localPlayer)
    local arena = arenaInfo()
    local protTotal = core:getConfig().spawnProtection or 3000
    local prot = getElementData(localPlayer, "dm:protected") and math.max(0, protTotal - (getTickCount() - spawnTick)) or 0
    local h = {
        visible = isHudVisible(), name = nick(localPlayer), nameColor = getElementData(localPlayer, "dm:nameColor") or "#FFFFFF",
        tag = tagOf(getElementData(localPlayer, "dm:tag")), clan = tagOf(getElementData(localPlayer, "dm:clanTag")),
        tier = tier.name:upper(), tierShort = tier.short, tierColor = tier.color,
        money = tonumber(getElementData(localPlayer, "dm:money")) or 0, rp = rp,
        health = math.max(0, getElementHealth(localPlayer)), armor = getPedArmor(localPlayer),
        weapon = (getWeaponNameFromID(weapon) or "Mãos"):upper(), clip = clip, reserve = math.max(0, total - clip),
        weaponIcon = WEAPON_ICONS[weapon] and (weapon .. ".png") or false, skin = skinInfo(localPlayer, weapon),
        clipSize = tonumber(getWeaponProperty(weapon, "pro", "maximum_clip_ammo")) or math.max(clip, 1), hasAmmo = weapon > 1 and total > 0,
        streak = tonumber(getElementData(localPlayer, "dm:streak")) or 0,
        arena = arena, server = core:getConfig().fullName, online = population.online, fps = fps, ping = getPlayerPing(localPlayer),
        protected = prot, protectedTotal = protTotal, hints = hints(arena), dead = isPedDead(localPlayer),
        duel = DuelLive and DuelLive() or false, ranked = RankedLive and RankedLive() or false,
    }
    UI.set("hud", h)
end

addEventHandler("onClientRender", root, function()
    frames = frames + 1
    local now = getTickCount()
    if now - fpsTick >= 1000 then fps, frames, fpsTick = frames, 0, now end
end)
setTimer(pushHud, 150, 0)

addEvent("dm:onSpawn", true)
addEventHandler("dm:onSpawn", root, function() spawnTick = getTickCount() end)

-- ---------- notificações ----------
function notify(text, ntype, title)
    ntype = (ntype == "success" or ntype == "error" or ntype == "warn") and ntype or "info"
    UI.push("toast", { text = tostring(text), type = ntype, title = title or false })
    UI.sound(ntype == "error" and "error" or "notify", 0.5)
end
addEvent("dm:notify", true)
addEventHandler("dm:notify", root, function(text, ntype, title) notify(text, ntype, title) end)
addEvent("ui:notify")
addEventHandler("ui:notify", root, function(text, ntype, title) notify(text, ntype, title) end)

-- ---------- kills ----------
addEvent("dm:onKill", true)
addEventHandler("dm:onKill", root, function(killerName, victimName, weapon, headshot, killer, victim)
    UI.push("kill", { killer = killerName or false, victim = victimName, weapon = getWeaponNameFromID(weapon or 0) or "?", headshot = headshot == true,
        mine = killer == localPlayer, me = victim == localPlayer, skin = (killer and isElement(killer)) and skinInfo(killer, weapon or 0) or false })
end)
addEvent("dm:onKillReward", true)
addEventHandler("dm:onKillReward", root, function(victimName, money, headshot, streak)
    UI.sound(headshot and "headshot" or "kill", 0.8)
    UI.push("reward", { text = ("Você eliminou %s"):format(victimName), money = money or 0, headshot = headshot == true })
end)
addEvent("dm:onStreak", true)
addEventHandler("dm:onStreak", root, function(name, streak, text)
    UI.push("streak", { name = name, streak = streak, text = text })
    UI.sound("streak", 0.6)
end)
addEvent("dm:tierChange", true)
addEventHandler("dm:tierChange", root, function(tierName, up)
    UI.sound(up and "levelup" or "lose", 0.7)
    notify(up and ("Você subiu para o elo %s!"):format(tierName) or ("Você caiu para o elo %s."):format(tierName), up and "success" or "warn", "Elo")
end)
addEvent("dm:onMoney", true)
addEventHandler("dm:onMoney", root, function(amount, reason, total)
    if not amount or amount == 0 then return end
    UI.push("pop", { amount = amount, reason = reason or "" })
    if amount > 0 then UI.sound("click", 0.3) end
end)
