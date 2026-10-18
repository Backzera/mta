--[[
    Spawn: ajuste ao chão, rede de segurança contra queda no vazio, zonas seguras / proteção,
    tela de morte (backdrop + vinheta + anel de contagem) e indicador de proteção.
]]

local death = nil
local spawnTick = 0
local badSpawnReported = false

local function arenaOf(player)
    local id = getElementData(player, "dm:arena")
    return id and DM.getArena(id) or nil
end

-- Ajusta ao chão (correções pequenas; chão nativo do GTA aceita correções maiores)
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

-- Caiu no vazio logo após nascer -> pede reposicionamento ao servidor
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
    UI.resetTween("bar:hud:hp")
    setTimer(snapToGround, 400, 1)
    setTimer(snapToGround, 1300, 1)
    setTimer(checkFalling, 1900, 1)
    setTimer(checkFalling, 3200, 1)
    setCameraTarget(localPlayer)
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
