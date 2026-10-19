--[[
    UTG Anti-Cheat — fase 1: RAPID FIRE.
    Tudo no servidor (não dá para burlar editando o cliente): conta os tiros de cada jogador por arma numa janela
    de 1 s (onPlayerWeaponFire) e compara com a cadência máxima real da arma, lida das propriedades do GTA
    (anim_loop_start/stop no nível "pro"), com tolerância para lag/FPS. Pistolas e shotguns, que o C-Bug acelera
    de verdade, têm tolerância maior. Duas violações em 60 s = jogador marcado: alerta na tela de todos os admins
    (toast + som), log no console e lista em /ac. Não pune sozinho: a decisão é do admin (/kick, /ban).
]]
local core = exports.dm_core

local TOLERANCE_DEFAULT = 1.35      -- 35% acima da cadência máxima ainda é aceito (jitter de rede, FPS alto)
local TOLERANCE_CBUG    = 2.4       -- pistolas/shotguns: C-Bug e animação cancelada aceleram legitimamente
local WINDOW_MS         = 1000
local MIN_SHOTS         = 4         -- só avalia a janela com pelo menos este número de tiros
local VIOLATIONS_TO_FLAG = 2
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

addEventHandler("onPlayerWeaponFire", root, function(weapon)
    if not WATCHED[weapon] then return end
    local now = getTickCount()
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
    if #v >= VIOLATIONS_TO_FLAG then
        violations[source] = {}
        alert(source, weapon, rate, limit)
    end
end)

addEventHandler("onPlayerQuit", root, function() shots[source], violations[source], flagged[source], lastAlert[source] = nil, nil, nil, nil end)

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
