--[[
    Lado da vítima: cancela o dano padrão das armas de fogo e envia para o servidor calcular.
]]

local GUNS = { [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true,
               [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [38] = true }

-- ---------- "cabeça do servidor": o dano só vale se a MIRA do atacante (pelo sync) aponta para a parte atingida ----------
-- Silent aim redireciona a bala sem mover a mira: a bala "acerta", mas a mira está longe. Aqui o acerto é anulado
-- e reportado ao anti-cheat. O cliente da vítima faz a checagem, então o trapaceiro não controla.
local BONE_OF = { [3] = 3, [4] = 3, [5] = 24, [6] = 34, [7] = 44, [8] = 54, [9] = 8 }   -- parte do corpo -> osso
local HIPFIRE = { [22] = true, [28] = true, [29] = true, [32] = true }              -- armas que atiram sem mirar
local AIM_TOL_FAR, AIM_TOL_NEAR, NEAR_DIST = 10, 28, 4                              -- graus; perto a paralaxe é maior
local function angleDeg(ax, ay, az, bx, by, bz)
    local la, lb = math.sqrt(ax * ax + ay * ay + az * az), math.sqrt(bx * bx + by * by + bz * bz)
    if la < 1e-6 or lb < 1e-6 then return 0 end
    local d = (ax * bx + ay * by + az * bz) / (la * lb)
    if d > 1 then d = 1 elseif d < -1 then d = -1 end
    return math.deg(math.acos(d))
end
-- retorna true se o acerto é coerente com a mira do atacante; senão false + motivo
local function aimMatches(attacker, weapon, bodypart)
    local sx, sy, sz = getPedTargetStart(attacker)
    local ex, ey, ez = getPedTargetEnd(attacker)
    if not sx or not ex then
        if HIPFIRE[weapon] then return true end
        return false, "acertou sem estar mirando"
    end
    local bx, by, bz = getPedBonePosition(localPlayer, BONE_OF[bodypart] or 3)
    if not bx then return true end
    local dist = getDistanceBetweenPoints3D(sx, sy, sz, bx, by, bz)
    local ang = angleDeg(ex - sx, ey - sy, ez - sz, bx - sx, by - sy, bz - sz)
    local tol = dist < NEAR_DIST and AIM_TOL_NEAR or AIM_TOL_FAR
    if ang <= tol then return true end
    return false, ("mira a %.0f° da parte atingida (tolerância %d°, %.0f m)"):format(ang, tol, dist)
end

local silentHits = {}   -- [attacker] = { t... } acertos anulados recentes (para o relato forte)
addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    if not GUNS[weapon] then return end
    if not isElement(attacker) or getElementType(attacker) ~= "player" or attacker == localPlayer then return end
    cancelEvent()
    if getElementData(localPlayer, "dm:protected") then return end
    local arena = exports.dm_core:getPlayerArena(localPlayer)
    if arena and arena.safe and not getElementData(localPlayer, "dm:inDuel") then return end
    local ok, why = aimMatches(attacker, weapon, bodypart)
    if not ok then
        -- acerto incoerente com a mira: sem dano; 3 em 20 s = relato FORTE de silent aim
        local now = getTickCount()
        local list = silentHits[attacker] or {}
        list[#list + 1] = now
        while list[1] and now - list[1] > 20000 do table.remove(list, 1) end
        silentHits[attacker] = list
        if #list >= 3 then
            silentHits[attacker] = {}
            local ac = getResourceFromName("utg_anticheat")
            if ac and getResourceState(ac) == "running" then
                triggerServerEvent("utg_ac:report", getResourceRootElement(ac), attacker, "silent", "FORTE: 3 acertos anulados em 20 s (" .. why .. ")", true)
            end
        end
        return
    end
    triggerServerEvent("wep:hit", localPlayer, attacker, weapon, bodypart, loss or 0)
end)
addEventHandler("onClientPlayerQuit", root, function() silentHits[source] = nil end)

-- Confirmação de acerto (hitmarker é desenhado pelo dm_core via este evento)
addEvent("wep:hitConfirm", true)
addEventHandler("wep:hitConfirm", root, function(damage, headshot, victim, killed)
    triggerEvent("dm:hitConfirm", localPlayer, damage, headshot, victim, killed)
end)
