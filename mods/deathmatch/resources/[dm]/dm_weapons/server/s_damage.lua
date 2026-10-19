--[[
    Sistema de dano customizado.
    O cliente da VÍTIMA cancela o dano padrão e envia "wep:hit"; o servidor calcula o dano
    por parte do corpo e aplica. Mortes passam por killPed -> onPlayerWasted com killer correto.
]]

local core = exports.dm_core

-- Multiplicadores por parte do corpo (3 torso, 4 quadril, 5/6 braços, 7/8 pernas). Cabeça (9) não usa
-- multiplicador: HEADSHOT É MORTE INSTANTÂNEA com qualquer arma de fogo, ignorando vida e colete.
local MULT = { [3] = 0.5, [4] = 0.5, [5] = 0.8, [6] = 0.8, [7] = 0.7, [8] = 0.7 }
local MAX_LOSS = { [24] = 70, [25] = 90, [26] = 80, [27] = 75, [28] = 25, [29] = 30, [32] = 25, [30] = 40, [31] = 40, [33] = 90, [34] = 120, [22] = 30, [23] = 45, [38] = 40 }
local GUNS = {}
for id in pairs(MAX_LOSS) do GUNS[id] = true end

function isCustomDamageWeapon(id) return GUNS[id] == true end

local lastHit = {} -- victim -> tick (anti-flood)

addEvent("wep:hit", true)
addEventHandler("wep:hit", root, function(attacker, weapon, bodypart, loss)
    local victim = client
    if victim ~= source then return end
    if not isElement(attacker) or getElementType(attacker) ~= "player" or attacker == victim then return end
    weapon, bodypart, loss = tonumber(weapon), tonumber(bodypart) or 3, tonumber(loss) or 0
    if not weapon or not GUNS[weapon] then return end
    if isPedDead(victim) or isPedDead(attacker) then return end
    if getElementDimension(attacker) ~= getElementDimension(victim) then return end
    if getElementData(victim, "dm:protected") then return end
    local arena = core:getPlayerArena(victim)
    if arena and arena.safe and not getElementData(victim, "dm:inDuel") then return end
    -- sem fogo amigo em times (ranqueadas / clã x clã)
    local ta, tv = getPlayerTeam(attacker), getPlayerTeam(victim)
    if ta and tv and ta == tv then return end
    -- arma errada na mão do atacante? (anti-cheat leve)
    if getPedWeapon(attacker) ~= weapon and getPedWeapon(attacker) ~= 0 then
        if not (weapon == 34 or weapon == 33) then return end
    end
    local now = getTickCount()
    if lastHit[victim] and now - lastHit[victim] < 15 then return end
    lastHit[victim] = now

    loss = math.min(loss, MAX_LOSS[weapon])
    local mult = MULT[bodypart] or 1
    local damage = loss * mult
    local headshot = bodypart == 9
    if headshot then
        -- tiro na cabeça = morte, com qualquer arma, sem passar pelo colete
        setPedArmor(victim, 0)
        setElementHealth(victim, 1)
        killPed(victim, attacker, weapon, bodypart)
        triggerClientEvent(attacker, "wep:hitConfirm", resourceRoot, 100, true, victim, true)
        triggerEvent("ac:hit", attacker, attacker, victim, weapon, true)   -- anti-cheat: precisão
        return
    end

    local armor = getPedArmor(victim)
    local health = getElementHealth(victim)
    if armor > 0 then
        local absorbed = math.min(armor, damage)
        armor = armor - absorbed
        damage = damage - absorbed
        setPedArmor(victim, armor)
    end
    health = health - damage
    if health <= 1 then
        setElementHealth(victim, 1)
        killPed(victim, attacker, weapon, bodypart)
    else
        setElementHealth(victim, health)
    end
    triggerClientEvent(attacker, "wep:hitConfirm", resourceRoot, math.floor(loss * mult + 0.5), headshot, victim, health <= 1)
    triggerEvent("ac:hit", attacker, attacker, victim, weapon, false)   -- anti-cheat: precisão
end)

addEventHandler("onPlayerQuit", root, function() lastHit[source] = nil end)
