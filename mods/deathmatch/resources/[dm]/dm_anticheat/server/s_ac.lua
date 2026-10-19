--[[
    UTG Anti-Cheat — servidor.
    · RAPID FIRE (abaixo).
    · AIMBOT / SILENT AIM: relatos das TESTEMUNHAS (c_ac.lua: outros clientes observam a mira e as balas do suspeito via
      sync) cruzados com a PRECISÃO real medida aqui (tiros x acertos x headshots, via dm_weapons "ac:hit").
      Alerta: relatos de 2 testemunhas diferentes (ou 3 relatos) em 3 min, OU precisão impossível.
      Ban automático: alerta + precisão suspeita juntos, ou 3 testemunhas diferentes.
    Tudo no servidor (não dá para burlar editando o cliente): conta os tiros de cada jogador por arma numa janela
    de 1 s (onPlayerWeaponFire) e compara com a cadência máxima real da arma, lida das propriedades do GTA
    (anim_loop_start/stop no nível "pro"), com tolerância para lag/FPS. Pistolas e shotguns, que o C-Bug acelera
    de verdade, têm tolerância maior. 2 violações em 60 s = jogador marcado: alerta na tela de todos os admins
    (toast + som), log no console e lista em /ac. 3 violações em 60 s = BAN AUTOMÁTICO (serial + IP, permanente),
    anunciado no chat. Admins nunca são banidos automaticamente (só alertados).
    Precisa de ACL para banir: no console do servidor, uma vez: aclrequest allow dm_anticheat all
]]
local core = exports.dm_core

local TOLERANCE_DEFAULT = 1.35      -- 35% acima da cadência máxima ainda é aceito (jitter de rede, FPS alto)
local TOLERANCE_CBUG    = 2.4       -- pistolas/shotguns: C-Bug e animação cancelada aceleram legitimamente
local WINDOW_MS         = 1000
local MIN_SHOTS         = 4         -- só avalia a janela com pelo menos este número de tiros
local VIOLATIONS_TO_FLAG = 2       -- alerta aos admins
local VIOLATIONS_TO_BAN  = 3       -- ban automático (permanente, serial + IP)
local AUTOBAN = true
local VIOLATION_TTL     = 60000
local ALERT_COOLDOWN    = 20000     -- não repete o alerta do mesmo jogador antes disso

local CBUG_WEAPONS = { [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true }
local WATCHED = { [22]=true,[23]=true,[24]=true,[25]=true,[26]=true,[27]=true,[28]=true,[29]=true,[30]=true,[31]=true,[32]=true,[33]=true,[34]=true,[38]=true }

-- cadência máxima (tiros/s) por arma, a partir das propriedades reais do jogo
local maxRate = {}
local function rateOf(weapon)
    if maxRate[weapon] then return maxRate[weapon] end
    local a = tonumber(getWeaponProperty(weapon, "pro", "anim_loop_start")) or 0
    local b = tonumber(getWeaponProperty(weapon, "pro", "anim_loop_stop")) or 0
    local interval = b - a
    if interval <= 0.02 then interval = 0.1 end
    -- shotguns/sniper/deagle têm recarga de animação maior que o loop; usa o maior entre loop e anim_breakout
    local breakout = tonumber(getWeaponProperty(weapon, "pro", "anim_breakout_time")) or 0
    if breakout > interval and (weapon == 25 or weapon == 27 or weapon == 34 or weapon == 24) then interval = breakout end
    maxRate[weapon] = 1 / interval
    return maxRate[weapon]
end

local shots, violations, flagged, lastAlert = {}, {}, {}, {}
local acc = {}          -- [player] = { shots = {t...}, hits = {t...}, hs = {t...} } (precisão; definido abaixo)
local accOf, trim

local function adminsOnline()
    local out = {}
    for _, p in ipairs(getElementsByType("player")) do if core:isPlayerAdmin(p) then out[#out + 1] = p end end
    return out
end

local function alert(player, weapon, rate, limit)
    local now = getTickCount()
    if lastAlert[player] and now - lastAlert[player] < ALERT_COOLDOWN then return end
    lastAlert[player] = now
    local name = getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
    local id = tonumber(getElementData(player, "dm:id")) or 0
    local wname = getWeaponNameFromID(weapon) or tostring(weapon)
    local text = ("%s [%d] · %s · %.1f tiros/s (máx. %.1f)"):format(name, id, wname, rate, limit)
    flagged[player] = { text = text, t = now, count = (flagged[player] and flagged[player].count or 0) + 1 }
    outputServerLog(("[ANTI-CHEAT] RAPID FIRE: %s (serial %s)"):format(text, getPlayerSerial(player)))
    local admins = adminsOnline()
    if #admins > 0 then triggerClientEvent(admins, "ac:alert", resourceRoot, "RAPID FIRE", text, player) end
end

function autoban(player, weapon, rate, limit)
    local name = getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
    local wname = getWeaponNameFromID(weapon) or tostring(weapon)
    local reason = ("Anti-cheat: rapid fire (%s, %.1f tiros/s, max %.1f)"):format(wname, rate, limit)
    outputServerLog(("[ANTI-CHEAT] BAN AUTOMÁTICO: %s serial %s ip %s — %s"):format(name, getPlayerSerial(player), getPlayerIP(player), reason))
    local admins = adminsOnline()
    if #admins > 0 then triggerClientEvent(admins, "ac:alert", resourceRoot, "BAN AUTOMÁTICO", name .. " · " .. reason, player) end
    outputChatBox(("#FF4D6D⚠ #FFFFFF%s #8FA39Afoi banido pelo anti-cheat: #FF4D6Drapid fire"):format(name), root, 255, 255, 255, true)
    local ok = banPlayer(player, true, false, true, nil, reason, 0)
    if not ok then
        outputServerLog("[ANTI-CHEAT] banPlayer falhou: falta ACL. Rode no console: aclrequest allow dm_anticheat all")
        kickPlayer(player, reason)
    end
end

local sawFireEvent = false
addEventHandler("onPlayerWeaponFire", root, function(weapon)
    if not sawFireEvent then sawFireEvent = true outputServerLog("[ANTI-CHEAT] onPlayerWeaponFire está chegando ao servidor") end
    if not WATCHED[weapon] then return end
    local now = getTickCount()
    do local a = accOf(source) a.shots[#a.shots + 1] = now trim(a.shots, ACC_MIN_SHOTS) end
    local s = shots[source]
    if not s or s.weapon ~= weapon then s = { weapon = weapon, t = {} } shots[source] = s end
    local t = s.t
    t[#t + 1] = now
    while t[1] and now - t[1] > WINDOW_MS do table.remove(t, 1) end
    if #t < MIN_SHOTS then return end
    local span = math.max(now - t[1], 1)
    local rate = (#t - 1) / (span / 1000)
    local limit = rateOf(weapon) * (CBUG_WEAPONS[weapon] and TOLERANCE_CBUG or TOLERANCE_DEFAULT)
    if rate <= limit then return end
    -- violação: registra e só alerta com reincidência na janela de 60 s
    local v = violations[source] or {}
    v[#v + 1] = now
    while v[1] and now - v[1] > VIOLATION_TTL do table.remove(v, 1) end
    violations[source] = v
    t[#t] = nil   -- não deixa a mesma rajada gerar várias violações seguidas
    if #v >= VIOLATIONS_TO_BAN and AUTOBAN and not core:isPlayerAdmin(source) then
        violations[source] = {}
        autoban(source, weapon, rate, limit)
    elseif #v == VIOLATIONS_TO_FLAG then
        alert(source, weapon, rate, limit)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    shots[source], violations[source], flagged[source], lastAlert[source], aimReports[source], acc[source] = nil, nil, nil, nil, nil, nil
    for _, list in pairs(aimReports) do for i = #list, 1, -1 do if list[i].witness == source then table.remove(list, i) end end end
end)

-- ---------------------------------------------------------------- AIMBOT / SILENT AIM
local AIM_REPORT_TTL     = 180000
local AIM_WITNESSES_ALERT = 2
local AIM_REPORTS_ALERT   = 3
local AIM_WITNESSES_BAN   = 3       -- ou 2 testemunhas + precisão impossível, ou 1 testemunha com 4 relatos + precisão
local AIM_REPORTS_BAN_ACC = 4
local ACC_MIN_SHOTS       = 40      -- precisão só é avaliada com pelo menos este número de tiros (janela móvel)
local ACC_HIT_RATIO       = 0.85    -- acertos/tiros impossíveis de sustentar sem ajuda
local ACC_HS_RATIO        = 0.75    -- headshots/acertos
local KIND_NAME = { silent = "SILENT AIM", snap = "AIMBOT", lock = "AIMBOT (lock)", rapid = "RAPID FIRE" }
local RAPID_REPORTS_BAN = 2        -- cadência é objetiva: 2 relatos de testemunha banem
local SINGLE_WITNESS_REPORTS_BAN = 6 -- aimbot/silent: 1 testemunha sozinha bane com 6 relatos em 3 min

local aimReports = {}   -- [suspect] = { {witness=, kind=, t=, detail=}, ... }

accOf = function(p)
    local a = acc[p]
    if not a then a = { shots = {}, hits = {}, hs = {} } acc[p] = a end
    return a
end
trim = function(list, max) while #list > max do table.remove(list, 1) end end
-- precisão suspeita? (janela móvel dos últimos ACC_MIN_SHOTS tiros)
local function suspiciousAccuracy(p)
    local a = acc[p]
    if not a or #a.shots < ACC_MIN_SHOTS then return false end
    local since = a.shots[1]
    local hits, hs = 0, 0
    for _, t in ipairs(a.hits) do if t >= since then hits = hits + 1 end end
    for _, t in ipairs(a.hs) do if t >= since then hs = hs + 1 end end
    local hitRatio, hsRatio = hits / #a.shots, hits > 0 and hs / hits or 0
    if hitRatio >= ACC_HIT_RATIO and hsRatio >= ACC_HS_RATIO then
        return true, ("%d%% de acerto, %d%% headshot em %d tiros"):format(hitRatio * 100, hsRatio * 100, #a.shots)
    end
    return false
end

-- acertos confirmados pelo dm_weapons (evento local do servidor)
addEvent("ac:hit")
addEventHandler("ac:hit", root, function(attacker, victim, weapon, headshot)
    if not isElement(attacker) then return end
    local a = accOf(attacker)
    local now = getTickCount()
    a.hits[#a.hits + 1] = now
    if headshot then a.hs[#a.hs + 1] = now end
    trim(a.hits, ACC_MIN_SHOTS) trim(a.hs, ACC_MIN_SHOTS)
end)

local function evaluateAim(suspect, kind, latestDetail)
    local now = getTickCount()
    local list = aimReports[suspect] or {}
    while list[1] and now - list[1].t > AIM_REPORT_TTL do table.remove(list, 1) end
    aimReports[suspect] = list
    local witnesses, total = {}, 0
    for _, r in ipairs(list) do
        if r.kind == kind then total = total + 1 witnesses[r.witness] = true end
    end
    local nWit = 0
    for _ in pairs(witnesses) do nWit = nWit + 1 end
    local badAcc, accText = suspiciousAccuracy(suspect)
    local name = getPlayerName(suspect):gsub("#%x%x%x%x%x%x", "")
    local id = tonumber(getElementData(suspect, "dm:id")) or 0
    local text = ("%s [%d] · %s · %d testemunha(s), %d relato(s)%s"):format(name, id, latestDetail or "", nWit, total, badAcc and (" · " .. accText) or "")
    local isAdmin = core:isPlayerAdmin(suspect)
    local banNow = nWit >= AIM_WITNESSES_BAN or (nWit >= AIM_WITNESSES_ALERT and badAcc) or (total >= AIM_REPORTS_BAN_ACC and badAcc) or total >= SINGLE_WITNESS_REPORTS_BAN
    if kind == "rapid" then banNow = total >= RAPID_REPORTS_BAN end
    if banNow and AUTOBAN and not isAdmin then
        aimReports[suspect] = {}
        local reason = ("Anti-cheat: %s (%d testemunhas%s)"):format(KIND_NAME[kind], nWit, badAcc and ", " .. accText or "")
        outputServerLog(("[ANTI-CHEAT] BAN AUTOMÁTICO: %s serial %s ip %s — %s"):format(name, getPlayerSerial(suspect), getPlayerIP(suspect), reason))
        local admins = adminsOnline()
        if #admins > 0 then triggerClientEvent(admins, "ac:alert", resourceRoot, "BAN AUTOMÁTICO", name .. " · " .. reason, suspect) end
        outputChatBox(("#FF4D6D⚠ #FFFFFF%s #8FA39Afoi banido pelo anti-cheat: #FF4D6D%s"):format(name, KIND_NAME[kind]:lower()), root, 255, 255, 255, true)
        if not banPlayer(suspect, true, false, true, nil, reason, 0) then kickPlayer(suspect, reason) end
    else
        -- qualquer relato já alerta os admins (1 testemunha = "suspeita"; 2+ testemunhas ou precisão = "forte")
        if lastAlert[suspect] and now - lastAlert[suspect] < ALERT_COOLDOWN then return end
        lastAlert[suspect] = now
        local level = (nWit >= AIM_WITNESSES_ALERT or total >= AIM_REPORTS_ALERT or badAcc) and "FORTE" or "SUSPEITA"
        local title = KIND_NAME[kind] .. " · " .. level
        flagged[suspect] = { text = title .. " · " .. text, t = now, count = (flagged[suspect] and flagged[suspect].count or 0) + 1 }
        outputServerLog(("[ANTI-CHEAT] %s: %s (serial %s)"):format(title, text, getPlayerSerial(suspect)))
        local admins = adminsOnline()
        if #admins > 0 then triggerClientEvent(admins, "ac:alert", resourceRoot, title, text, suspect) end
    end
end

addEvent("ac:report", true)
addEventHandler("ac:report", root, function(suspect, kind, detail)
    local witness = client
    if not witness or witness ~= source then return end
    if not isElement(suspect) or getElementType(suspect) ~= "player" or suspect == witness then return end
    if not KIND_NAME[kind] then return end
    if getElementDimension(suspect) ~= getElementDimension(witness) then return end
    local list = aimReports[suspect] or {}
    list[#list + 1] = { witness = witness, kind = kind, t = getTickCount(), detail = tostring(detail or "") }
    aimReports[suspect] = list
    evaluateAim(suspect, kind, tostring(detail or ""))
end)

-- /ac: lista os jogadores marcados nesta sessão (admin)
addCommandHandler("ac", function(player)
    if not core:isPlayerAdmin(player) then return end
    local n = 0
    for p, f in pairs(flagged) do
        if isElement(p) then
            n = n + 1
            outputChatBox(("#FF4D6D⚠ #FFFFFF%s #8FA39A(%dx, há %ds)"):format(f.text, f.count, math.floor((getTickCount() - f.t) / 1000)), player, 255, 255, 255, true)
        end
    end
    if n == 0 then core:notifyPlayer(player, "Nenhum jogador marcado nesta sessão.", "info", "Anti-cheat") end
end)
