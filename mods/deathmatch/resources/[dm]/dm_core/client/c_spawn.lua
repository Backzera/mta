--[[
    Spawn: ajuste ao chão (apenas em arenas sem mapa), tela de morte,
    indicador de proteção de spawn, zonas seguras.
]]

local death = nil        -- { killer, weapon, headshot, until }
local spawnTick = 0

local function arenaOf(player)
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end

-- Ajusta ao chão (correções pequenas apenas; mapas flutuantes não são afetados)
local function snapToGround()
    local arena = arenaOf(localPlayer)
    if not arena or getElementData(localPlayer, "dm:inDuel") then return end
    local x, y, z = getElementPosition(localPlayer)
    local ground = getGroundPosition(x, y, z + (arena.native and 60 or 1))
    if ground and ground > 0 then
        local diff = z - ground
        local limit = arena.native and 60 or 12
        if (diff > 1.5 and diff < limit) or (diff < -0.3 and diff > -limit) then
            setElementPosition(localPlayer, x, y, ground + 1.0)
        end
    end
end

-- Caiu no vazio logo após nascer (mapa não carregou / spawn fora do chão) -> pede reposicionamento
local badSpawnReported = false
local function checkFalling()
    if badSpawnReported or isPedDead(localPlayer) then return end
    if getElementData(localPlayer, "dm:inDuel") then return end
    if isElementFrozen(localPlayer) then return end
    local vx, vy, vz = getElementVelocity(localPlayer)
    if not isPedOnGround(localPlayer) and vz < -0.25 then
        badSpawnReported = true
        triggerServerEvent("dm:badSpawn", localPlayer)
    end
end

addEvent("dm:onSpawn", true)
addEventHandler("dm:onSpawn", root, function(arenaId)
    death = nil
    spawnTick = getTickCount()
    badSpawnReported = false
    setTimer(snapToGround, 400, 1)
    setTimer(snapToGround, 1300, 1)
    setTimer(checkFalling, 1900, 1)
    setTimer(checkFalling, 3200, 1)
    setCameraTarget(localPlayer)
end)

addEvent("dm:onEnterArena", true)
addEventHandler("dm:onEnterArena", root, function(arenaId, prevId)
    local arena = DM.getArena(arenaId)
    if not arena then return end
    playUISound("click", 0.4)
end)

addEvent("dm:onDeath", true)
addEventHandler("dm:onDeath", root, function(killerName, weapon, headshot, respawnDelay)
    death = { killer = killerName, weapon = DM.weaponName(weapon), headshot = headshot, until_ = getTickCount() + (respawnDelay or 3000), tick = getTickCount() }
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
    -- Dano de jogador em outra dimensão/arena não é permitido
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
            local a = math.min(1, age / 300)
            dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(10, 5, 8, 150 * a))
            UI.gradientH(0, UI.sh / 2 - s(1), UI.sw, s(2), { 255, 77, 109, 0 }, { 255, 77, 109, 200 * a }, 30)
            UI.gradientH(UI.sw / 2, UI.sh / 2 - s(1), UI.sw / 2, s(2), { 255, 77, 109, 200 * a }, { 255, 77, 109, 0 }, 30)
            UI.textShadow("VOCÊ MORREU", 0, UI.sh / 2 - s(110), UI.sw, s(60), UI.color("danger", 255 * a), "bold", 40, "center", "center")
            local sub
            if death.killer then
                sub = ("Eliminado por %s com %s%s"):format(death.killer, death.weapon, death.headshot and " (Headshot)" or "")
            else
                sub = ("Causa: %s"):format(death.weapon)
            end
            UI.textShadow(sub, 0, UI.sh / 2 - s(50), UI.sw, s(30), tocolor(255, 255, 255, 220 * a), "medium", 14, "center", "center")
            local remaining = math.max(0, (death.until_ - now) / 1000)
            if remaining > 0 then
                UI.textShadow("RENASCENDO EM", 0, UI.sh / 2 + s(20), UI.sw, s(20), UI.color("muted", 255 * a), "semibold", 11, "center", "center")
                UI.textShadow(("%d"):format(math.ceil(remaining)), 0, UI.sh / 2 + s(40), UI.sw, s(70), tocolor(255, 255, 255, 255 * a), "bold", 48, "center", "center")
            end
        end
    end

    -- Indicador de proteção de spawn
    local arena = arenaOf(localPlayer)
    if arena and not arena.safe and getElementData(localPlayer, "dm:protected") and not isPedDead(localPlayer) then
        local total = DM.server.spawnProtection
        local remaining = total - (now - spawnTick)
        if remaining > 0 and remaining <= total then
            local w, h = s(220), s(40)
            local x, y = (UI.sw - w) / 2, UI.sh - s(160)
            UI.rect(x, y, w, h, UI.color("card", 220), h / 2)
            UI.border(x, y, w, h, UI.color("accent", 120), h / 2)
            UI.text(("PROTEÇÃO  %.1fs"):format(remaining / 1000), x, y, w, h, UI.color("accent"), "semibold", 11, "center", "center")
            UI.rect(x + s(16), y + h - s(6), (w - s(32)) * math.min(1, remaining / total), s(3), UI.color("accent", 200), 1)
        end
    end
end)
