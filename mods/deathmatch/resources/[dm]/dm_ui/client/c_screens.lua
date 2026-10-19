--[[
    Telas (CEF): hub F2, loja F4, duelo F3, ranqueadas F5, clãs F6, caixas F7, mira F9, personagens F10, placar TAB, ajuda F1, login.
    Cada tela: monta os dados reais, abre com UI.open(nome, dados) e registra ações vindas do JS com UI.on.
    Protocolos com os servidores (dm:requestArena, shop:buy, duel:*, ranked:*, clans:*, crates:*, login:*) preservados.
]]
local core = exports.dm_core
local function nick(p) return (getPlayerName(p):gsub("#%x%x%x%x%x%x", "")) end
local function ready() return getElementData(localPlayer, "dm:ready") == true end
local function money() return tonumber(getElementData(localPlayer, "dm:money")) or 0 end
local function hasPerk(key) local perks = getElementData(localPlayer, "dm:perks") return type(perks) == "table" and perks[key] == true end
local function findPlayerById(id)
    id = tonumber(id)
    for _, p in ipairs(getElementsByType("player")) do if tonumber(getElementData(p, "dm:id")) == id then return p end end
end
local function meInfo()
    local rp = tonumber(getElementData(localPlayer, "dm:rp")) or 0
    local tier = core:getTierForRP(rp)
    return { name = nick(localPlayer), tier = tier.name:upper(), tierColor = tier.color, money = money(), rp = rp }
end
local timers = {}
local function stopTimer(name) if timers[name] and isTimer(timers[name]) then killTimer(timers[name]) end timers[name] = nil end
local function every(name, ms, fn) stopTimer(name) timers[name] = setTimer(fn, ms, 0) end

-- ============================================================
-- HUB (F2): arenas + ranqueadas, câmera no local selecionado
-- ============================================================
local hub = { selected = nil, origDim = 0, camStart = 0 }
local function counts()
    local map = {}
    for _, p in ipairs(getElementsByType("player")) do
        local id = getElementData(p, "dm:arena")
        if id then map[id] = (map[id] or 0) + 1 end
    end
    return map
end
local function serialize(item, map)
    local weapons = {}
    for _, w in ipairs(item.weapons or {}) do weapons[#weapons + 1] = getWeaponNameFromID(w[1]) or tostring(w[1]) end
    local wtxt = #weapons > 0 and table.concat(weapons, " · ") or (item.type == "duel" and "Arma escolhida no duelo" or "Sem armas")
    local place = item.place or (item.id == "lobby" and "Pershing Square · Los Santos" or (item.native and "Mapa do GTA" or "Mapa próprio"))
    return {
        id = item.id, name = item.name, type = item.type, desc = item.desc or "", color = item.color, weapons = wtxt,
        players = map[item.id] or 0, cap = item.type == "ranked" and item.teamSize * 2 or 32, place = place,
        cbug = item.cbug == true, safe = item.safe == true, teamSize = item.teamSize, roundTime = item.roundTime, roles = item.roles == true,
    }
end
local function hubState()
    local map = counts()
    local arenas, modes = {}, {}
    for _, a in ipairs(core:getArenas()) do arenas[#arenas + 1] = serialize(a, map) end
    for _, m in ipairs(core:getRankedModes()) do modes[#modes + 1] = serialize(m, map) end
    return { arenas = arenas, modes = modes, current = getElementData(localPlayer, "dm:arena") or false, online = #getElementsByType("player"), player = meInfo() }
end
local function findItem(id)
    for _, a in ipairs(core:getArenas()) do if a.id == id then return a end end
    for _, m in ipairs(core:getRankedModes()) do if m.id == id then return m end end
end
local function previewPoint(item)
    if item.center then return item.center[1], item.center[2], item.center[3], item.dimension end
    local sp = item.spawns and item.spawns[1]
    if sp then return sp[1], sp[2], sp[3], item.dimension end
    return 0, 0, 10, 0
end
local cam = { x = 0, y = 0, z = 0, tx = 0, ty = 0, tz = 0 }
local function hubRender()
    local item = hub.item
    if not item then return end
    local px, py, pz, dim = previewPoint(item)
    if getElementDimension(localPlayer) ~= dim then setElementDimension(localPlayer, dim) end
    cam.tx, cam.ty, cam.tz = px, py, pz
    cam.x = cam.x + (cam.tx - cam.x) * 0.06
    cam.y = cam.y + (cam.ty - cam.y) * 0.06
    cam.z = cam.z + (cam.tz - cam.z) * 0.06
    local t = (getTickCount() - hub.camStart) / 1000
    setCameraMatrix(cam.x + math.cos(t * 0.2) * 40, cam.y + math.sin(t * 0.2) * 40, cam.z + 15 + math.sin(t * 0.45) * 1.5, cam.x, cam.y, cam.z + 2)
end
function openHub()
    if not ready() then return end
    if not UI.open("hub", hubState()) then return end
    hub.camStart = getTickCount()
    hub.origDim = getElementDimension(localPlayer)
    hub.selected = getElementData(localPlayer, "dm:arena")
    local item = hub.selected and findItem(hub.selected)
    hub.item = item
    if item then cam.x, cam.y, cam.z = previewPoint(item) end
    addEventHandler("onClientRender", root, hubRender)
    every("hub", 2500, function() UI.set("hub", hubState()) end)
end
UI.onClose("hub", function()
    removeEventHandler("onClientRender", root, hubRender)
    stopTimer("hub")
    setElementDimension(localPlayer, hub.origDim)
    setCameraTarget(localPlayer)
end)
UI.on("hub", "select", function(p) hub.selected, hub.item = p.id, findItem(p.id) end)
UI.on("hub", "enter", function(p)
    local item = findItem(p.id)
    UI.close("hub")
    if not item then return end
    if item.type == "ranked" then triggerServerEvent("ranked:requestJoin", localPlayer, item.id)
    else triggerServerEvent("dm:requestArena", localPlayer, item.id) end
end)
bindKey("F2", "down", function() UI.toggle("hub", openHub) end)

-- ============================================================
-- LOJA (F4)
-- ============================================================
local function shopState()
    local SHOP, VIP, ECO = core:getShopConfig(), core:getVipConfig(), core:getEconomyConfig()
    local tagData = getElementData(localPlayer, "dm:tag")
    local vipLevel = tonumber(getElementData(localPlayer, "dm:vip")) or 0
    local current = getElementData(localPlayer, "dm:nameColor")
    local function hex(c) return ("#%02X%02X%02X"):format(c[1], c[2], c[3]) end
    local cats = {}
    -- tags
    local items = {}
    for _, it in ipairs(SHOP.tags) do
        local owned = hasPerk("tag:" .. it.key)
        local equipped = owned and type(tagData) == "table" and tagData.kind == "shop" and (it.custom or tagData.text == it.text)
        items[#items + 1] = { id = "tag_" .. it.key, cat = "tags", key = it.key, title = it.custom and "TAG PERSONALIZADA" or it.text,
            desc = it.custom and "Seu próprio texto (2 a 12 caracteres) com /tag <texto>." or "Tag com ícone no chat, no placar e acima do nick.",
            price = it.price, color = it.color, state = equipped and "equipped" or (owned and "owned" or "buy"), sample = ("[%s %s]"):format(it.glyph or "", it.custom and "SUA TAG" or it.text) }
    end
    items[#items + 1] = { id = "tag_none", cat = "unequip", key = "tag", title = "TAG DO ELO", desc = "Volta a exibir o seu elo (Bronze, Prata, Ouro...) no lugar da tag comprada.", price = 0, color = { 150, 165, 155 },
        state = (type(tagData) == "table" and tagData.kind == "tier") and "equipped" or "owned" }
    cats[#cats + 1] = { key = "tags", label = "Tags", title = "TAGS", desc = "Exibidas no chat, no placar e acima do seu nick.", items = items }
    -- cores
    items = {}
    for _, it in ipairs(SHOP.nameColors) do
        local owned = hasPerk("color:" .. it.key)
        items[#items + 1] = { id = "color_" .. it.key, cat = "nameColors", key = it.key, title = it.name:upper(), desc = "Cor do seu nick no chat, no placar e sobre o boneco.", price = it.price, color = it.color,
            state = (owned and current == hex(it.color)) and "equipped" or (owned and "owned" or "buy"), sample = nick(localPlayer) }
    end
    items[#items + 1] = { id = "color_none", cat = "unequip", key = "color", title = "COR PADRÃO", desc = "Nick branco (ou a cor do seu VIP).", price = 0, color = { 150, 165, 155 }, state = (not current or current == "#FFFFFF") and "equipped" or "owned" }
    cats[#cats + 1] = { key = "nameColors", label = "Cores de nick", title = "CORES DE NICK", desc = "Cor do seu nome em todo o servidor.", items = items }
    -- vip
    items = {}
    for level = 1, 3 do
        local v = VIP[level]
        items[#items + 1] = { id = "vip_" .. level, cat = "vip", key = tostring(level), title = v.name:upper(),
            desc = ("%d dias · %.2fx de $ · bônus diário %s · respawn rápido · nick colorido · todas as skins"):format(v.days, ECO.vipMultiplier[level], core:formatMoney(v.daily)),
            price = v.price, color = v.color, state = vipLevel == level and "equipped" or "buy", badge = vipLevel == level and "ATIVO" or false, sample = ("[%s %s]"):format(v.glyph or "★", v.tag) }
    end
    cats[#cats + 1] = { key = "vip", label = "VIP", title = "VIP", desc = "Mais $, bônus diário maior, respawn rápido, skins e tag.", items = items }
    -- extras
    items = {}
    for _, it in ipairs(SHOP.extras) do
        items[#items + 1] = { id = "extra_" .. it.key, cat = "extras", key = it.key, title = it.name:upper(), desc = it.desc, price = it.price, color = { 124, 255, 178 }, state = hasPerk(it.key) and "equipped" or "buy" }
    end
    cats[#cats + 1] = { key = "extras", label = "Extras", title = "EXTRAS", desc = "Vantagens permanentes para a sua conta.", items = items }
    return { money = money(), cats = cats }
end
function openShop()
    if not ready() then return end
    if UI.open("shop", shopState()) then every("shop", 4000, function() UI.set("shop", shopState()) end) end
end
UI.onClose("shop", function() stopTimer("shop") end)
UI.on("shop", "buy", function(p) triggerServerEvent("shop:buy", localPlayer, p.cat, p.key) end)
bindKey("F4", "down", function() UI.toggle("shop", openShop) end)
addEvent("shop:open", true)
addEventHandler("shop:open", root, function() openShop() end)
addEvent("shop:result", true)
addEventHandler("shop:result", root, function(ok) UI.sound(ok and "levelup" or "error", 0.5) end)

-- ============================================================
-- DUELO (F3): painel, pedidos, HUD do duelo
-- ============================================================
local duel = { incoming = {}, outgoing = nil, live = nil, selected = nil }
local function duelState()
    local now = getTickCount()
    local players = {}
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer and getElementData(p, "dm:ready") then
            local rp = tonumber(getElementData(p, "dm:rp")) or 0
            local tier = core:getTierForRP(rp)
            players[#players + 1] = { id = tonumber(getElementData(p, "dm:id")) or 0, name = nick(p), tierShort = tier.short, tierColor = tier.color, inDuel = getElementData(p, "dm:inDuel") == true }
        end
    end
    table.sort(players, function(a, b) return a.name:lower() < b.name:lower() end)
    local sets = {}
    for _, s in ipairs(core:getDuelWeaponSets()) do sets[#sets + 1] = { key = s.key, name = s.name } end
    local inc = {}
    for _, r in ipairs(duel.incoming) do inc[#inc + 1] = { id = r.id, from = r.from, weapon = r.weapon, rounds = r.rounds, left = math.max(0, math.ceil((r.expires - now) / 1000)), ttl = math.ceil(r.ttl / 1000) } end
    local out = duel.outgoing and { id = duel.outgoing.id, target = duel.outgoing.target, weapon = duel.outgoing.weapon, rounds = duel.outgoing.rounds, left = math.max(0, math.ceil((duel.outgoing.expires - now) / 1000)), ttl = math.ceil(duel.outgoing.ttl / 1000) } or false
    local selectedId = duel.selected and isElement(duel.selected) and tonumber(getElementData(duel.selected, "dm:id")) or false
    return { players = players, sets = sets, incoming = inc, outgoing = out, inDuel = duel.live ~= nil, selectedId = selectedId }
end
local function pushDuel() UI.set("duel", duelState()) end
function openDuelPanel(target)
    if isElement(target) then duel.selected = target end
    if not ready() then return end
    if UI.open("duel", duelState()) then every("duel", 3000, pushDuel) end
end
UI.onClose("duel", function() stopTimer("duel") duel.selected = nil end)
UI.on("duel", "request", function(p)
    local target = findPlayerById(p.id)
    if target then triggerServerEvent("duel:request", localPlayer, target, p.weapon, tonumber(p.rounds) or 3) end
end)
UI.on("duel", "cancel", function(p) triggerServerEvent("duel:cancel", localPlayer, p.id) end)
UI.on("duel", "respond", function(p) triggerServerEvent("duel:respond", localPlayer, p.id, p.accept == true) end)
bindKey("F3", "down", function() UI.toggle("duel", openDuelPanel) end)
addEvent("duel:openPanel", true)
addEventHandler("duel:openPanel", root, function(target) openDuelPanel(target or nil) end)
addEvent("duel:incoming", true)
addEventHandler("duel:incoming", root, function(id, fromName, weaponName, rounds, ttl, fromPlayer)
    for i = #duel.incoming, 1, -1 do if duel.incoming[i].player == fromPlayer then table.remove(duel.incoming, i) end end
    duel.incoming[#duel.incoming + 1] = { id = id, from = fromName, weapon = weaponName, rounds = rounds, ttl = ttl, expires = getTickCount() + ttl, player = fromPlayer }
    UI.sound("notify", 0.6)
    pushDuel()
end)
addEvent("duel:requestRemoved", true)
addEventHandler("duel:requestRemoved", root, function(id)
    for i = #duel.incoming, 1, -1 do if duel.incoming[i].id == id then table.remove(duel.incoming, i) end end
    pushDuel()
end)
addEvent("duel:outgoing", true)
addEventHandler("duel:outgoing", root, function(id, targetName, weaponName, rounds, ttl)
    duel.outgoing = { id = id, target = targetName, weapon = weaponName, rounds = rounds, ttl = ttl, expires = getTickCount() + ttl }
    pushDuel()
end)
addEvent("duel:outgoingRemoved", true)
addEventHandler("duel:outgoingRemoved", root, function(id) if duel.outgoing and duel.outgoing.id == id then duel.outgoing = nil pushDuel() end end)
-- expiração local dos pedidos
every("duelExpire", 1000, function()
    local now, changed = getTickCount(), false
    for i = #duel.incoming, 1, -1 do if duel.incoming[i].expires <= now then table.remove(duel.incoming, i) changed = true end end
    if duel.outgoing and duel.outgoing.expires <= now then duel.outgoing = nil changed = true end
    if changed then pushDuel() end
end)
bindKey("y", "down", function() if duel.incoming[1] and not duel.live and not UI.getOpenPanel() then triggerServerEvent("duel:respond", localPlayer, duel.incoming[1].id, true) end end)
bindKey("n", "down", function() if duel.incoming[1] and not duel.live and not UI.getOpenPanel() then triggerServerEvent("duel:respond", localPlayer, duel.incoming[1].id, false) end end)
-- HUD do duelo
function DuelLive()
    local d = duel.live
    if not d then return false end
    local left = d.countdownEnd and math.max(0, math.ceil((d.countdownEnd - getTickCount()) / 1000)) or 0
    return { opponent = d.opponent, weapon = d.weapon, target = d.target, me = d.me, opp = d.opp, round = d.round, state = d.state, left = left, me_name = nick(localPlayer) }
end
addEvent("duel:start", true)
addEventHandler("duel:start", root, function(opponentName, weaponName, target, opponent)
    duel.live = { opponent = opponentName, weapon = weaponName, target = target, me = 0, opp = 0, round = 0, state = "countdown" }
    duel.incoming, duel.outgoing = {}, nil
    UI.close("duel")
    pushDuel()
end)
addEvent("duel:round", true)
addEventHandler("duel:round", root, function(scoreMe, scoreOpp, round, seconds)
    if not duel.live then return end
    duel.live.me, duel.live.opp, duel.live.round, duel.live.state = scoreMe, scoreOpp, round, "countdown"
    duel.live.countdownEnd = getTickCount() + seconds * 1000
    for i = seconds, 1, -1 do setTimer(function() if duel.live and duel.live.state == "countdown" then UI.sound("tick", 0.6) end end, (seconds - i) * 1000 + 1, 1) end
end)
addEvent("duel:fight", true)
addEventHandler("duel:fight", root, function() if duel.live then duel.live.state = "fight" UI.sound("go", 0.8) setTimer(function() if duel.live and duel.live.state == "fight" then duel.live.state = "live" end end, 900, 1) end end)
addEvent("duel:score", true)
addEventHandler("duel:score", root, function(scoreMe, scoreOpp) if duel.live then duel.live.me, duel.live.opp, duel.live.state = scoreMe, scoreOpp, "between" end end)
addEvent("duel:end", true)
addEventHandler("duel:end", root, function(won, scoreMe, scoreOpp, rpDelta, reason, money)
    UI.push("duelResult", { won = won == true, me = scoreMe, opp = scoreOpp, rp = rpDelta or 0, money = money or 0, reason = reason or "", opponent = duel.live and duel.live.opponent or "?" })
    duel.live = nil
    UI.sound(won and "win" or "lose", 0.7)
    pushDuel()
end)

-- ============================================================
-- RANQUEADAS (F5): painel + HUD da instância (MD3, papéis)
-- ============================================================
local ranked = { info = {}, state = nil, stateTick = 0 }
local function rankedState()
    local modes = {}
    for _, m in ipairs(core:getRankedModes()) do
        local weapons = {}
        for _, w in ipairs(m.weapons or {}) do weapons[#weapons + 1] = getWeaponNameFromID(w[1]) or tostring(w[1]) end
        local mi = { waiting = 0, playing = 0, matches = 0 }
        for _, it in ipairs(ranked.info) do if it.id == m.id then mi = it end end
        modes[#modes + 1] = { id = m.id, name = m.name, place = m.place, teamSize = m.teamSize, weapons = table.concat(weapons, " · "), armor = m.armor or 0, color = m.color,
            roles = m.roles == true, roundTime = m.roundTime or (core:getRankedConfig().roundTime or 300), waiting = mi.waiting, playing = mi.playing, matches = mi.matches }
    end
    local me = meInfo()
    return { modes = modes, current = getElementData(localPlayer, "dm:arena") or false, me = { tier = me.tier, rp = me.rp } }
end
function openRankedPanel()
    if not ready() then return end
    if UI.open("ranked", rankedState()) then
        triggerServerEvent("ranked:requestInfo", localPlayer)
        every("ranked", 3000, function() triggerServerEvent("ranked:requestInfo", localPlayer) end)
    end
end
UI.onClose("ranked", function() stopTimer("ranked") end)
UI.on("ranked", "join", function(p) triggerServerEvent("ranked:requestJoin", localPlayer, p.id) UI.close("ranked") end)
UI.on("ranked", "role", function(p) triggerServerEvent("ranked:setRole", localPlayer, p.role) end)
bindKey("F5", "down", function() UI.toggle("ranked", openRankedPanel) end)
addEvent("ranked:info", true)
addEventHandler("ranked:info", root, function(list) ranked.info = list or {} if UI.isOpen("ranked") then UI.set("ranked", rankedState()) end end)
function RankedLive()
    local s = ranked.state
    if not s then return false end
    local left = math.max(0, (s.secondsLeft or 0) - math.floor((getTickCount() - ranked.stateTick) / 1000))
    local out = {}
    for k, v in pairs(s) do out[k] = v end
    out.left = left
    out.dead = isPedDead(localPlayer)
    out.suddenNew = s.state == "sudden" and (getTickCount() - ranked.stateTick) < 1500
    return out
end
addEvent("ranked:state", true)
addEventHandler("ranked:state", root, function(st)
    local prev = ranked.state
    ranked.state = st or nil
    ranked.stateTick = getTickCount()
    if st and prev and prev.state ~= st.state then
        if st.state == "round" then UI.sound("go", 0.8) elseif st.state == "sudden" then UI.sound("streak", 0.8) elseif st.state == "countdown" then UI.sound("notify", 0.6) end
    end
end)
addEvent("ranked:spectate", true)
addEventHandler("ranked:spectate", root, function(target)
    if isElement(target) then setCameraTarget(target) if ranked.state then ranked.state.spectating = nick(target) end else setCameraTarget(localPlayer) end
end)
addEvent("ranked:start", true)
addEventHandler("ranked:start", root, function(team, teamName) UI.sound("go", 0.8) notify(("Você está no %s. Boa partida!"):format(teamName), "success", "Partida iniciada") end)
addEvent("ranked:end", true)
addEventHandler("ranked:end", root, function(res)
    UI.push("rankedResult", res)
    UI.sound(res.won and "win" or (res.draw and "notify" or "lose"), 0.8)
end)

-- ============================================================
-- CLÃS (F6)
-- ============================================================
local clans = { data = nil }
local PALETTE = { { 34, 230, 138 }, { 34, 211, 238 }, { 139, 92, 246 }, { 245, 196, 81 }, { 255, 77, 109 }, { 255, 140, 66 }, { 255, 105, 180 }, { 120, 220, 255 } }
local function clansState()
    local d = clans.data
    if not d then return { loaded = false } end
    local cands = {}
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer and getElementData(p, "dm:ready") and not getElementData(p, "dm:clanTag") then
            cands[#cands + 1] = { id = tonumber(getElementData(p, "dm:id")) or 0, name = nick(p) }
        end
    end
    table.sort(cands, function(a, b) return a.name:lower() < b.name:lower() end)
    return { loaded = true, clan = d.clan or false, invites = d.invites or {}, challenge = d.challenge or false, clans = d.clans or {}, modes = d.modes or {},
        createCost = d.createCost or 0, minClanMatch = d.minClanMatch or 2, money = money(), myName = nick(localPlayer), candidates = cands, palette = PALETTE }
end
function openClanPanel()
    if not ready() then return end
    clans.data = nil
    if UI.open("clans", clansState()) then triggerServerEvent("clans:requestInfo", localPlayer) end
end
addEvent("clans:info", true)
addEventHandler("clans:info", root, function(d) clans.data = d if UI.isOpen("clans") then UI.set("clans", clansState()) end end)
UI.on("clans", "create", function(p) triggerServerEvent("clans:create", localPlayer, tostring(p.name or ""), tostring(p.tag or "")) end)
UI.on("clans", "respondInvite", function(p) triggerServerEvent("clans:respondInvite", localPlayer, p.accept == true) end)
UI.on("clans", "invite", function(p) local t = findPlayerById(p.id) if t then triggerServerEvent("clans:invite", localPlayer, t) end end)
UI.on("clans", "kick", function(p) triggerServerEvent("clans:kick", localPlayer, p.name) end)
UI.on("clans", "promote", function(p) triggerServerEvent("clans:promote", localPlayer, p.name) end)
UI.on("clans", "leave", function() triggerServerEvent("clans:leave", localPlayer) end)
UI.on("clans", "challenge", function(p) triggerServerEvent("clans:challenge", localPlayer, tonumber(p.clanId), p.modeId) end)
UI.on("clans", "respondChallenge", function(p) triggerServerEvent("clans:respondChallenge", localPlayer, p.accept == true) end)
UI.on("clans", "setColor", function(p) triggerServerEvent("clans:setColor", localPlayer, tonumber(p.idx) or 1) end)
bindKey("F6", "down", function() UI.toggle("clans", openClanPanel) end)

-- ============================================================
-- CAIXAS (F7)
-- ============================================================
local openingBox = false
local function cratesState()
    local C = core:getCratesConfig()
    local owned = {}
    for _, it in ipairs(C.items) do if hasPerk("item:" .. it.key) then owned[#owned + 1] = it.key end end
    local items = {}
    for _, it in ipairs(C.items) do
        items[#items + 1] = { key = it.key, type = it.type, name = it.name, rarity = it.rarity, texture = it.texture or false, model = it.model or false,
            weapon = it.weapon or false, preview = it.preview or false,
            weaponLabel = it.weapon and (C.weaponSkins and C.weaponSkins[it.weapon] and C.weaponSkins[it.weapon].label or "Outras armas") or false }
    end
    local eq = getElementData(localPlayer, "dm:wskin")
    if type(eq) == "string" then eq = { all = eq } end
    local hasTrail = false
    for _, it in ipairs(C.items) do
        if it.type == "wskin" and (it.rarity == "mitica" or it.rarity == "ultimate") and hasPerk("item:" .. it.key) then hasTrail = true end
    end
    return { money = money(), rarities = C.rarities, items = items, boxes = C.boxes, owned = owned, hasTrail = hasTrail, opening = openingBox,
        trail = type(eq) == "table" and eq.trail or false,
        equippedSkin = tonumber(getElementData(localPlayer, "dm:skin")) or 0, equippedW = type(eq) == "table" and eq or {} }
end
local reelOpen = false
function openCratesPanel()
    if not ready() then return end
    if UI.open("crates", cratesState()) then every("crates", 4000, function() UI.set("crates", cratesState()) end) end
end
UI.onClose("crates", function() stopTimer("crates") reelOpen = false UI.push("reelClose", {}) end)
UI.onEscape("crates", function() if not reelOpen then UI.close("crates") end end)
UI.on("crates", "close", function() if not reelOpen then UI.close("crates") end end)
UI.on("crates", "open", function(p)
    if openingBox or reelOpen or not UI.isOpen("crates") or type(p.box) ~= "string" then return end
    openingBox = p.box
    UI.merge("crates", { opening = openingBox })
    triggerServerEvent("crates:open", localPlayer, p.box)
end)
addEvent("crates:openFailed", true)
addEventHandler("crates:openFailed", root, function()
    openingBox = false
    UI.merge("crates", { opening = false })
end)
UI.on("crates", "equip", function(p) triggerServerEvent("crates:equip", localPlayer, p.key) end)
UI.on("crates", "trail", function(p) triggerServerEvent("crates:trail", localPlayer, p.value) end)
UI.on("crates", "reelClose", function() reelOpen = false UI.push("reelClose", {}) end)
addEvent("crates:result", true)
addEventHandler("crates:result", root, function(boxKey, itemKey, duplicate)
    openingBox = false
    UI.set("crates", cratesState())
    local C = core:getCratesConfig()
    local box
    for _, b in ipairs(C.boxes) do if b.key == boxKey then box = b end end
    if not box then return end
    local items = {}
    for i = 1, 40 do items[i] = box.pool[math.random(#box.pool)].item end
    items[34] = itemKey
    reelOpen = true
    if not UI.isOpen("crates") then openCratesPanel() end
    UI.push("reel", { box = boxKey, result = itemKey, duplicate = duplicate == true, target = 34, items = items })
    UI.sound("go", 0.5)
    for i = 1, 24 do setTimer(function() if reelOpen then UI.sound("tick", 0.3) end end, 120 + i * (i * 9), 1) end
    setTimer(function() if reelOpen then UI.sound(duplicate and "notify" or "levelup", 0.8) end end, 5400, 1)
end)
bindKey("F7", "down", function() if UI.isOpen("crates") then if not reelOpen then UI.close("crates") end else UI.toggle("crates", openCratesPanel) end end)
addEvent("crates:openPanel", true)
addEventHandler("crates:openPanel", root, function() openCratesPanel() end)

-- PERSONAGENS (F10): mantém os mesmos itens e a mesma posse salva na conta.
local function charactersState()
    local C = core:getCratesConfig()
    local items, owned = {}, {}
    for _, it in ipairs(C.items) do
        if it.type == "skin" then
            items[#items + 1] = { key = it.key, type = it.type, name = it.name, rarity = it.rarity, model = it.model, preview = it.preview }
            if hasPerk("item:" .. it.key) then owned[#owned + 1] = it.key end
        end
    end
    return { items = items, owned = owned, rarities = C.rarities,
        equippedSkin = tonumber(getElementData(localPlayer, "dm:skin")) or 0 }
end
function openCharactersPanel()
    if ready() then UI.open("characters", charactersState()) end
end
UI.on("characters", "equip", function(p)
    if not UI.isOpen("characters") then return end
    if p.key == "skin:none" then triggerServerEvent("crates:equip", localPlayer, p.key) return end
    for _, it in ipairs(core:getCratesConfig().items) do
        if it.type == "skin" and it.key == p.key then
            triggerServerEvent("crates:equip", localPlayer, it.key)
            return
        end
    end
end)
UI.on("characters", "boxes", function() UI.close("characters") openCratesPanel() end)
UI.on("crates", "characters", function()
    if reelOpen or openingBox then return end
    UI.close("crates") openCharactersPanel()
end)
bindKey("F10", "down", function() UI.toggle("characters", openCharactersPanel) end)
addCommandHandler("personagens", function() UI.toggle("characters", openCharactersPanel) end)

-- Declarado depois dos construtores locais: antes cratesState era resolvido como
-- global inexistente, abortando a atualização até o próximo timer de 4 segundos.
local inventoryKeys = { ["dm:money"] = true, ["dm:perks"] = true, ["dm:skin"] = true, ["dm:wskin"] = true }
local shopKeys = { ["dm:money"] = true, ["dm:perks"] = true, ["dm:tag"] = true, ["dm:vip"] = true, ["dm:nameColor"] = true }
addEventHandler("onClientElementDataChange", localPlayer, function(name)
    if inventoryKeys[name] then
        UI.defer("inventory", function()
            if UI.isOpen("crates") then UI.set("crates", cratesState()) end
            if UI.isOpen("characters") then UI.set("characters", charactersState()) end
        end)
    end
    if shopKeys[name] then
        UI.defer("shop", function() if UI.isOpen("shop") then UI.set("shop", shopState()) end end)
    end
end)

-- ============================================================
-- MIRA (F9): galeria de miras + ajuste fino; desenho e salvamento no dm_crosshair
-- ============================================================
local crosshairOriginal = nil   -- ajustes antes de abrir (para cancelar)
local function crosshairCall(fn, ...)
    local ok, res = pcall(function(...) return exports.dm_crosshair[fn](exports.dm_crosshair, ...) end, ...)
    if ok then return res end
    return nil
end
local function crosshairState()
    return { settings = crosshairCall("getCrosshair") or { enabled = false } }
end
function openCrosshairPanel()
    if not ready() then return end
    crosshairOriginal = crosshairCall("getCrosshair")
    UI.open("crosshair", crosshairState())
end
UI.on("crosshair", "change", function(p) crosshairCall("setCrosshair", p) end)
UI.on("crosshair", "save", function(p)
    crosshairCall("saveCrosshair", p)
    crosshairOriginal = nil
    UI.close("crosshair")
    notify(p.enabled and "Mira salva na sua conta." or "Mira original do GTA ativada.", "success", "Mira")
end)
UI.on("crosshair", "reset", function()
    crosshairCall("resetCrosshair")
    crosshairOriginal = nil
    UI.set("crosshair", crosshairState())
end)
UI.on("crosshair", "close", function() UI.close("crosshair") end)
UI.onClose("crosshair", function()
    if crosshairOriginal then crosshairCall("setCrosshair", crosshairOriginal) crosshairOriginal = nil end   -- cancelou: volta ao que estava
end)
addEvent("crosshair:openPanel", false)
addEventHandler("crosshair:openPanel", localPlayer, function() UI.toggle("crosshair", openCrosshairPanel) end)
addEvent("crosshair:refreshPanel", false)
addEventHandler("crosshair:refreshPanel", localPlayer, function() if UI.isOpen("crosshair") then UI.set("crosshair", crosshairState()) end end)
bindKey("F9", "down", function() UI.toggle("crosshair", openCrosshairPanel) end)

-- ============================================================
-- PLACAR (TAB, segurar)
-- ============================================================
local function boardState()
    local rows = {}
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "dm:ready") then
            local kills = tonumber(getElementData(p, "dm:kills")) or 0
            local deaths = tonumber(getElementData(p, "dm:deaths")) or 0
            local rp = tonumber(getElementData(p, "dm:rp")) or 0
            local tier = core:getTierForRP(rp)
            local arena = core:getArena(getElementData(p, "dm:arena") or "")
            local tag, clan = getElementData(p, "dm:tag"), getElementData(p, "dm:clanTag")
            rows[#rows + 1] = { id = tonumber(getElementData(p, "dm:id")) or 0, name = nick(p), me = p == localPlayer,
                tag = type(tag) == "table" and { text = tag.text, hex = tag.hex, glyph = tag.glyph or "" } or false,
                clan = type(clan) == "table" and { text = clan.text, hex = clan.hex } or false,
                tier = tier.name, tierColor = tier.color, rp = rp, kills = kills, deaths = deaths, kd = deaths > 0 and kills / deaths or kills,
                arena = arena and arena.short or "", arenaColor = arena and arena.color or { 150, 165, 155 }, ping = getPlayerPing(p),
                streak = tonumber(getElementData(p, "dm:streak")) or 0, nameColor = getElementData(p, "dm:nameColor") or "#FFFFFF" }
        end
    end
    table.sort(rows, function(a, b)
        if a.rp ~= b.rp then return a.rp > b.rp end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.name:lower() < b.name:lower()
    end)
    return { rows = rows, server = core:getConfig().fullName }
end
bindKey("tab", "down", function()
    if not ready() or UI.getOpenPanel() then return end
    if UI.open("board", boardState(), { noCursor = true }) then every("board", 1500, function() UI.set("board", boardState()) end) end
end)
bindKey("tab", "up", function() if UI.isOpen("board") then UI.close("board") end end)
UI.onClose("board", function() stopTimer("board") end)

-- ============================================================
-- AJUDA (F1)
-- ============================================================
local function toggleHelp() UI.toggle("help", function() if ready() then UI.open("help", {}) end end) end
bindKey("F1", "down", toggleHelp)
addEvent("dm:toggleHelp", true)
addEventHandler("dm:toggleHelp", root, toggleHelp)

-- ============================================================
-- LOGIN (sem auto-login; credenciais salvas só preenchem)
-- ============================================================
local login = { camTick = 0, busy = false, message = nil, mtype = "info" }
local CRED_FILE = "@credenciais.xml"
local function key() return getPlayerSerial():sub(1, 16) end
local function saveCredentials(user, pass)
    local xml = xmlLoadFile(CRED_FILE) or xmlCreateFile(CRED_FILE, "login")
    if not xml then return end
    xmlNodeSetAttribute(xml, "user", user)
    xmlNodeSetAttribute(xml, "pass", base64Encode(teaEncode(pass, key())))
    xmlSaveFile(xml) xmlUnloadFile(xml)
end
local function loadCredentials()
    if not fileExists(CRED_FILE) then return nil end
    local xml = xmlLoadFile(CRED_FILE)
    if not xml then return nil end
    local user, enc = xmlNodeGetAttribute(xml, "user"), xmlNodeGetAttribute(xml, "pass")
    xmlUnloadFile(xml)
    if not user or not enc then return nil end
    local ok, pass = pcall(function() return teaDecode(base64Decode(enc), key()) end)
    if ok and pass and pass ~= "" then return user, pass end
end
local function clearCredentials() if fileExists(CRED_FILE) then fileDelete(CRED_FILE) end end
local loginUser = ""
local function loginState(extra)
    local st = { message = login.message or false, type = login.mtype, busy = login.busy }
    if extra then for k, v in pairs(extra) do st[k] = v end end
    return st
end
local function loginCam()
    local t = (getTickCount() - login.camTick) / 1000
    local cx, cy, radius = -1368, -958, 70
    setCameraMatrix(cx + math.cos(t * 0.08) * radius, cy + math.sin(t * 0.08) * radius, 1012 + math.sin(t * 0.2) * 3, cx, cy, 994)
end
local function showLogin()
    login.camTick = getTickCount()
    login.busy = false
    local user, pass = loadCredentials()
    if user then login.message, login.mtype = "Bem-vindo de volta, " .. user .. "! Clique em ENTRAR para jogar.", "success" end
    UI.open("login", loginState({ user = user or "", pass = pass or "", remember = true }))
    addEventHandler("onClientRender", root, loginCam)
end
UI.onClose("login", function() removeEventHandler("onClientRender", root, loginCam) setCameraTarget(localPlayer) end)
UI.on("login", "login", function(p)
    if login.busy then return end
    login.busy, loginUser = true, tostring(p.user or "")
    login.message, login.mtype = "Entrando...", "info"
    UI.set("login", loginState())
    triggerServerEvent("login:attempt", localPlayer, loginUser, tostring(p.pass or ""), p.remember == true)
end)
UI.on("login", "register", function(p)
    if login.busy then return end
    login.busy, loginUser = true, tostring(p.user or "")
    login.message, login.mtype = "Criando conta...", "info"
    UI.set("login", loginState())
    triggerServerEvent("login:register", localPlayer, loginUser, tostring(p.pass or ""), p.remember == true)
end)
UI.on("login", "close", function() end)   -- login não fecha pelo ESC/JS
addEvent("login:show", true)
addEventHandler("login:show", root, showLogin)
addEvent("login:result", true)
addEventHandler("login:result", root, function(ok, message, passToSave)
    login.busy = false
    if ok then
        if passToSave and loginUser ~= "" then saveCredentials(loginUser, passToSave) elseif not passToSave then clearCredentials() end
        login.message, login.mtype = message, "success"
        UI.set("login", loginState())
        UI.sound("levelup", 0.5)
        setTimer(function() UI.close("login") end, 500, 1)
    else
        login.message, login.mtype = message, "error"
        UI.set("login", loginState())
        UI.sound("error", 0.5)
        if message and message:find("Senha incorreta") then clearCredentials() end
    end
end)
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- a câmera abre e a tela de login é enfileirada até a página do CEF carregar
    triggerServerEvent("login:ready", localPlayer)
end)
