--[[
    Spawn: ajuste ao chão, rede de segurança contra queda no vazio, zonas seguras / proteção,
    tela de morte (backdrop + vinheta + anel de contagem) e indicador de proteção.
]]

local death = nil
local spawnTick = 0
local badSpawnReported = false
local spawnCheckTimer = nil
local activeSpawnSerial = 0
local spawnBaseZ = 0

local function arenaOf(player)
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end

local function forceObjectCollision(obj)
    if not isElement(obj) or getElementType(obj) ~= "object" then return end
    if not getElementData(obj, "dm:mapArena") then return end

    setElementCollisionsEnabled(obj, true)

    -- A relação player <-> objeto é client-side. Força explicitamente para
    -- impedir ghost/collision state residual de outro resource.
    if not getPedOccupiedVehicle(localPlayer) then
        setElementCollisionsEnabled(localPlayer, true)
        if type(setElementCollidableWith) == "function" then
            setElementCollidableWith(localPlayer, obj, true)
            setElementCollidableWith(obj, localPlayer, true)
        end
    end
end

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "object" and getElementData(source, "dm:mapArena") then
        forceObjectCollision(source)
    end
end)

local function stopSpawnCheck()
    if spawnCheckTimer and isTimer(spawnCheckTimer) then
        killTimer(spawnCheckTimer)
    end
    spawnCheckTimer = nil
end

-- Quantos objetos do mapa desta arena já existem fisicamente no cliente.
-- Só conta objetos da dimensão atual e próximos do jogador.
local function streamedMapObjects(arenaId, radius)
    if getElementData(root, "dm:hasMap:" .. tostring(arenaId)) ~= true then
        return true, 0
    end

    local px, py, pz = getElementPosition(localPlayer)
    local dim = getElementDimension(localPlayer)
    local r2 = (radius or 180) ^ 2
    local count = 0

    for _, obj in ipairs(getElementsByType("object")) do
        if isElement(obj)
            and getElementDimension(obj) == dim
            and getElementData(obj, "dm:mapArena") == arenaId
            and isElementStreamedIn(obj) then

            forceObjectCollision(obj)
            local ox, oy, oz = getElementPosition(obj)
            local dx, dy, dz = ox - px, oy - py, oz - pz
            if dx * dx + dy * dy + dz * dz <= r2 then
                count = count + 1
                if count >= 3 then return true, count end
            end
        end
    end

    return false, count
end

-- Encontra o piso REAL logo abaixo do spawn. Diferente de getGroundPosition,
-- este raycast também enxerga objetos criados pelo dm_maps.
local function collisionBelow()
    local x, y, z = getElementPosition(localPlayer)
    local hit, _, _, hitZ = processLineOfSight(
        x, y, z + 3.0,
        x, y, z - 100.0,
        true,   -- prédios/chão nativo
        false,  -- veículos
        false,  -- players/peds
        true,   -- objetos do mapa
        false,  -- dummies
        false, false, false,
        localPlayer
    )

    if hit and hitZ and hitZ <= z + 2.5 and (z - hitZ) < 95 then
        return hitZ
    end
    return nil
end

local function waitingForWorld()
    if type(isElementWaitingForGroundToLoad) == "function" then
        return isElementWaitingForGroundToLoad(localPlayer) == true
    end
    return false
end

-- Caiu no vazio depois de ser liberado -> pede reposicionamento ao servidor.
local function checkFalling()
    if badSpawnReported or isPedDead(localPlayer) then return end
    if getElementData(localPlayer, "dm:inDuel") then return end
    if isElementFrozen(localPlayer) then return end
    local _, _, z = getElementPosition(localPlayer)
    local _, _, vz = getElementVelocity(localPlayer)

    -- Só considera spawn ruim se realmente despencou vários metros.
    -- Isso não confunde pulo/queda normal durante a partida com "limbo".
    if z < spawnBaseZ - 8 and not isPedOnGround(localPlayer) and vz < -0.15 then
        badSpawnReported = true
        triggerServerEvent("dm:badSpawn", localPlayer, "fell_through")
    end
end

local function finishSpawnValidation(serial, groundZ, collisionFreeze)
    if serial ~= activeSpawnSerial then return end
    stopSpawnCheck()

    if groundZ then
        local x, y, z = getElementPosition(localPlayer)
        local safeZ = groundZ + 1.0
        if math.abs(z - safeZ) > 0.12 and math.abs(z - safeZ) < 95 then
            setElementPosition(localPlayer, x, y, safeZ)
        end
    end

    if collisionFreeze then
        triggerServerEvent("dm:spawnCollisionReady", localPlayer, serial)
    end

    setTimer(checkFalling, 1200, 1)
    setTimer(checkFalling, 2600, 1)
end

local function beginSpawnValidation(arenaId, serial, collisionFreeze)
    stopSpawnCheck()
    activeSpawnSerial = tonumber(serial) or (activeSpawnSerial + 1)

    local mySerial = activeSpawnSerial
    local started = getTickCount()
    local timeout = 6200
    local completed = false

    local function attempt()
        if mySerial ~= activeSpawnSerial or isPedDead(localPlayer) then
            stopSpawnCheck()
            return
        end
        if getElementData(localPlayer, "dm:arena") ~= arenaId then
            stopSpawnCheck()
            return
        end

        local mapReady = streamedMapObjects(arenaId, 180)
        local groundZ = collisionBelow()
        local worldReady = not waitingForWorld()

        if mapReady and groundZ and worldReady then
            completed = true
            finishSpawnValidation(mySerial, groundZ, collisionFreeze)
            return
        end

        if getTickCount() - started >= timeout then
            completed = true
            stopSpawnCheck()

            if groundZ and mapReady then
                finishSpawnValidation(mySerial, groundZ, collisionFreeze)
            else
                -- Não libera o jogador no vazio. O servidor tenta um spawn
                -- âncora e, se repetir, devolve ao lobby em vez de loopar.
                badSpawnReported = true
                triggerServerEvent("dm:badSpawn", localPlayer, "no_collision")
            end
        end
    end

    attempt()
    if not completed and mySerial == activeSpawnSerial and not spawnCheckTimer then
        spawnCheckTimer = setTimer(attempt, 180, 0)
    end
end

addEvent("dm:onSpawn", true)
addEventHandler("dm:onSpawn", root, function(arenaId, serial, collisionFreeze)
    death = nil
    spawnTick = getTickCount()
    badSpawnReported = false

    local _, _, z = getElementPosition(localPlayer)
    spawnBaseZ = z

    if not getPedOccupiedVehicle(localPlayer) then
        setElementCollisionsEnabled(localPlayer, true)
    end

    -- Reaplica colisão nos objetos que já estavam streamed antes do spawn.
    for _, obj in ipairs(getElementsByType("object")) do
        if isElementStreamedIn(obj) and getElementData(obj, "dm:mapArena") == arenaId then
            forceObjectCollision(obj)
        end
    end

    UI.resetTween("bar:hud:hp")
    setCameraTarget(localPlayer)
    beginSpawnValidation(arenaId, tonumber(serial) or 0, collisionFreeze == true)
end)

addEvent("dm:onEnterArena", true)
addEventHandler("dm:onEnterArena", root, function(arenaId, prevId)
    if DM.getArena(arenaId) then playUISound("click", 0.4) end
end)

addEvent("dm:onDeath", true)
addEventHandler("dm:onDeath", root, function(killerName, weapon, headshot, respawnDelay)
    death = { killer = killerName, weapon = DM.weaponName(weapon), headshot = headshot, total = respawnDelay or 3000,
        until_ = getTickCount() + (respawnDelay or 3000), tick = getTickCount() }
    playUISound("death", 0.6)
end)

-- Zonas seguras / proteção de spawn: cancela dano no cliente da vítima
addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart)
    local arena = arenaOf(localPlayer)
    if arena and arena.safe and not getElementData(localPlayer, "dm:inDuel") then
        cancelEvent()
        return
    end
    if getElementData(localPlayer, "dm:protected") then
        cancelEvent()
        return
    end
    if attacker and getElementType(attacker) == "player" and attacker ~= localPlayer then
        if getElementData(attacker, "dm:arena") ~= getElementData(localPlayer, "dm:arena") then
            cancelEvent()
        end
    end
end)

-- Atirar quebra a sua própria proteção
addEventHandler("onClientPlayerWeaponFire", localPlayer, function()
    if getElementData(localPlayer, "dm:protected") then
        local arena = arenaOf(localPlayer)
        if arena and not arena.safe then
            triggerServerEvent("dm:breakProtection", localPlayer)
        end
    end
end)

addEventHandler("onClientRender", root, function()
    local s = UI.s
    local now = getTickCount()

    -- Tela de morte
    if death then
        if not isPedDead(localPlayer) and now - death.tick > 800 then
            death = nil
        else
            local age = now - death.tick
            local a = UI.ease(math.min(1, age / 350), "outCubic")
            UI.backdrop(a * 0.9, 110)
            UI.vignette(UI.color("danger", 230), a * UI.pulse(1600, 0.6, 1), 0.35, 1.3)
            local scale = 0.9 + 0.1 * UI.ease(math.min(1, age / 500), "outBack")
            UI.textGlow("VOCÊ MORREU", 0, UI.sh / 2 - s(150) * scale, UI.sw, s(70) * scale, UI.color("danger", 255 * a), UI.color("danger", 160 * a), "bold", math.floor(42 * scale), "center", "center")
            local sub = death.killer and ("Eliminado por %s  ·  %s%s"):format(death.killer, death.weapon, death.headshot and "  ·  HEADSHOT" or "") or ("Causa: %s"):format(death.weapon)
            UI.textShadow(sub, 0, UI.sh / 2 - s(76), UI.sw, s(26), tocolor(255, 255, 255, 220 * a), "medium", 13, "center", "center")
            local remaining = math.max(0, (death.until_ - now) / 1000)
            if getElementData(localPlayer, "dm:noRespawn") then
                UI.text("Aguarde o fim do round", 0, UI.sh / 2 + s(10), UI.sw, s(20), UI.color("muted", 255 * a), "semibold", 10, "center", "center")
            elseif remaining > 0 then
                local total = math.max(0.001, death.total / 1000)
                local cx, cy, r = UI.sw / 2, UI.sh / 2 + s(30), s(44)
                UI.ring(cx, cy, r, s(5), remaining / total, UI.color("accent", 255 * a), tocolor(255, 255, 255, 20 * a))
                local frac = remaining % 1
                local pop = 1 + (1 - UI.ease(1 - frac, "outCubic")) * 0.25
                UI.textGlow(("%d"):format(math.ceil(remaining)), cx - r, cy - r * pop, r * 2, r * 2 * pop, tocolor(255, 255, 255, 255 * a), UI.color("accent", 120 * a), "bold", math.floor(30 * pop), "center", "center")
                UI.text("RENASCENDO", cx - s(100), cy + r + s(10), s(200), s(18), UI.color("muted", 255 * a), "semibold", 9, "center", "center")
            end
        end
    end

end)
