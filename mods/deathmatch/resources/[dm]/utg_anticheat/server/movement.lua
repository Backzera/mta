local AC, U = AntiCheat, UTGUtils
AC.registerRemote("utg_ac:collision", { AC.schemas.boolean }, 2.5, 5, function(p, blocked)
    if not AC.enabled("noclip") then return end
    local s = AC.players[p]
    s.collision = { tick = AC.now(), blocked = blocked }
end)
function AC.sampleMovement(p)
    local s, now = AC.players[p], AC.now()
    if not s then return end
    if not AC.ready(p) or isPedInVehicle(p) or isElementFrozen(p) or isElementInWater(p)
        or AC.hasGrace(p,"teleport") or AC.hasGrace(p,"velocity") or not AC.networkOK(p) then
        s.movement = nil; return
    end
    -- O(1) sample, no raycasts and no search through players. Custom map contact
    -- invalidates ground-only assumptions; no movement signal is deterministic.
    local pos, dim, interior = AC.position(p), getElementDimension(p), getElementInterior(p)
    local old = s.movement
    local sample = { pos = pos, tick = now, dim = dim, interior = interior,
        health = getElementHealth(p), armor = getPedArmor(p), speedCount = 0, hover = 0, noclip = 0 }
    s.movement = sample
    if not old or old.dim ~= dim or old.interior ~= interior then
        AC.grant(p, "teleport", 2500, "world_transition"); return
    end
    local dt = now-old.tick
    if dt < 250 or dt > 1500 then return end -- scheduler stalls / stale sync
    local dx, dy, dz = pos[1]-old.pos[1], pos[2]-old.pos[2], pos[3]-old.pos[3]
    local horizontal = math.sqrt(dx*dx+dy*dy)
    local speed = horizontal/(dt/1000)
    local distance = U.distance(pos, old.pos)
    local vx, vy, vz = getElementVelocity(p)
    local grounded = isPedOnGround(p)
    local contact = getPedContactElement(p)
    if horizontal > AC.settings.movement.teleportDistance and math.abs(dz) < horizontal*2 then
        AC.record(p, "position_jump", "teleport", "movement", 2, 0.4,
            { distance = distance, elapsedMs = dt, dimension = dim, provenance = "position_sync" }, false)
        return
    end
    if speed > AC.settings.movement.horizontalSpeed and math.abs(dz) < 3 and grounded then
        sample.speedCount = old.speedCount+1
        if sample.speedCount >= AC.settings.movement.consecutive then
            AC.record(p, "sustained_speed", "speedhack", "movement", 2, 0.5,
                { speed = speed, samples = sample.speedCount, vx = vx, vy = vy }, false)
        end
    end
    if not grounded and not isElement(contact) and math.abs(dz) < 0.2 and math.abs(vz) < 0.03 and horizontal > 0.5 then
        sample.hover = old.hover+dt
        if sample.hover >= AC.settings.movement.hoverMs then
            AC.record(p, "sustained_hover", "fly", "movement", 2, 0.35,
                { durationMs = sample.hover, speed = speed, vz = vz, note = "custom_map_or_airbreak_possible" }, false)
        end
    end
    if s.collision and now-s.collision.tick < 1000 and s.collision.blocked and horizontal > 2 and horizontal < 20 then
        sample.noclip = old.noclip+1
        if sample.noclip >= 6 then
            AC.record(p, "collision_crossing", "noclip", "movement", 1.5, 0.25,
                { samples = sample.noclip, distance = horizontal, provenance = "client_collision_plus_position_sync" }, false)
        end
    end
    -- Optional contextual health/armor observations, never a godmode conviction.
    if AC.enabled("vitals") then
        if sample.health > old.health+20 and not AC.hasGrace(p,"health") then
            AC.record(p, "health_increase", "vitals", "movement", 0.5, 0.2, { before = old.health, after = sample.health }, false)
        end
        if sample.armor > old.armor+20 and not AC.hasGrace(p,"armor") then
            AC.record(p, "armor_increase", "vitals", "movement", 0.5, 0.2, { before = old.armor, after = sample.armor }, false)
        end
    end
end
