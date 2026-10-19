local AC, U = AntiCheat, UTGUtils
local function combat(p)
    local s = AC.players[p]
    if not s then return nil end
    if not s.combat then s.combat = { shots = {}, targetTick = AC.now(), created = AC.now() } end
    return s.combat
end
local function trim(c, now)
    while c.shots[1] and (now-c.shots[1].tick > AC.settings.combatWindow or #c.shots > AC.settings.maxShots) do
        table.remove(c.shots, 1)
    end
end
-- O(1) per target event. Target sync is a hint, not proof of aimbot.
addEventHandler("onPlayerTarget", root, function(target)
    if client or not AC.ready(source) then return end
    local c = combat(source)
    if not c or not AC.player(target) or not AC.sameWorld(source, target) or target == c.target then return end
    c.targetAngle = 0
    if AC.player(c.target) then
        local origin, a, b = AC.position(source), AC.position(c.target), AC.position(target)
        c.targetAngle = U.angle({a[1]-origin[1],a[2]-origin[2],a[3]-origin[3]},
            {b[1]-origin[1],b[2]-origin[2],b[3]-origin[3]})
    end
    c.previousTarget, c.target, c.targetTick = c.target, target, AC.now()
end)
local function cadence(p, c, weapon, now)
    if not AC.enabled("firerate") then return end
    local profile = AC.weaponProfiles[weapon]
    if not profile or not AC.networkOK(p) or AC.hasGrace(p, "weapons") or (c.switchUntil or 0) > now then
        c.cadence = nil; return
    end
    local f = c.cadence
    if not f or f.weapon ~= weapon then
        c.cadence = { weapon = weapon, start = now, last = now, intervals = 0, short = 0 }; return
    end
    local dt = now-f.last
    f.last = now
    -- Coalesced packets and reload pauses reset the measurement, never count as violations.
    if dt < 8 or dt > 1500 then c.cadence = nil; c.switchUntil = now+1000; return end
    local floor = math.max(10, math.min(profile.minimumMs, profile.cbugMs)-profile.toleranceMs-getPlayerPing(p)*0.05)
    f.intervals = f.intervals+1
    if dt < floor then f.short = f.short+1 end
    if now-f.start >= 5000 then
        if f.short-profile.burst >= profile.violations and f.short/math.max(1,f.intervals) > 0.7 then
            AC.record(p, "fire_cadence", "firerate", "combat", 2, 0.55,
                { weapon = weapon, intervals = f.intervals, violations = f.short, floorMs = floor,
                  durationMs = now-f.start, cbug = AC.data(p, "dm:arena") == "cbug", provenance = "arrival_timestamps" }, false)
        end
        c.cadence = nil
    end
end
-- Correct SERVER signature. hitElement is explicitly ignored: MTA documents it as unreliable.
addEventHandler("onPlayerWeaponFire", root, function(weapon, endX, endY, endZ, hitElement, startX, startY, startZ)
    local p = source
    if client or not AC.ready(p) or not AC.weaponProfiles[weapon] then return end
    local c, now = combat(p), AC.now()
    if not c then return end
    if getPedWeapon(p) ~= weapon then c.cadence = nil; return end -- weapon switch packet ordering
    cadence(p, c, weapon, now)
    if not AC.enabled("aimbot") and not AC.enabled("silentaim") then return end
    trim(c, now)
    local shot = { tick = now, weapon = weapon, hit = false, headshot = false,
        acquisitionMs = now-c.targetTick, targetAngle = c.targetAngle or 0,
        switched = AC.player(c.previousTarget) and c.previousTarget ~= c.target }
    if U.number(startX,-20000,20000) and U.number(startY,-20000,20000) and U.number(startZ,-20000,20000)
        and U.number(endX,-20000,20000) and U.number(endY,-20000,20000) and U.number(endZ,-20000,20000) then
        shot.distance = U.distance({ startX, startY, startZ }, { endX, endY, endZ })
    end
    c.shots[#c.shots+1] = shot
    trim(c, now)
end)
addEventHandler("onPlayerWeaponSwitch", root, function()
    local c = combat(source)
    if c then c.switchUntil = AC.now()+750; c.cadence = nil end
end)
function AC.correlateHit(attacker, victim, weapon, bodypart, provenance)
    if not AC.ready(attacker) or not AC.player(victim) or attacker == victim or not AC.sameWorld(attacker, victim) then return end
    local profile = AC.weaponProfiles[weapon]
    if not profile or profile.pellets then return end -- pellet damage is not one bullet/one hit
    local c = combat(attacker)
    if not c then return end
    local distance, now = U.distance(AC.position(attacker), AC.position(victim)), AC.now()
    if distance > profile.range+15 then return end
    -- Native and custom damage can refer to the same bullet; never double-count it.
    for i = #c.shots, 1, -1 do
        local shot = c.shots[i]
        if now-shot.tick > 800 then break end
        if shot.hit and shot.victim == victim and shot.weapon == weapon and now-shot.hitTick < 80 then return end
    end
    for i = #c.shots, 1, -1 do
        local shot = c.shots[i]
        if now-shot.tick > math.min(800, 250+getPlayerPing(attacker)+getPlayerPing(victim)) then break end
        if not shot.hit and shot.weapon == weapon then
            shot.hit, shot.headshot, shot.victim, shot.hitTick = true, bodypart == 9, victim, now
            shot.bodypart, shot.distance, shot.provenance = bodypart, distance, provenance
            shot.snap = shot.switched and shot.acquisitionMs <= 100 and shot.targetAngle >= 60
                and c.target == victim and distance >= 15 and getPlayerPing(attacker) <= 80
            return
        end
    end
end
addEventHandler("onPlayerDamage", root, function(attacker, weapon, bodypart, loss)
    if client or not U.number(loss, 0, 1000) then return end
    AC.correlateHit(attacker, source, weapon, bodypart, "native_damage_sync")
end)
-- Local-only compatibility bridge. Must originate in dm_weapons, never a remote declaration.
addEvent("ac:hit", false)
addEventHandler("ac:hit", root, function(attacker, victim, weapon, headshot)
    if client or not sourceResource or getResourceName(sourceResource) ~= "dm_weapons" or source ~= attacker then return end
    if type(headshot) ~= "boolean" then return end
    AC.correlateHit(attacker, victim, weapon, headshot and 9 or 3, "dm_weapons_victim_report")
end)
addEventHandler("onPlayerWasted", root, function(ammo, killer, weapon, bodypart)
    if not client then AC.correlateHit(killer, source, weapon, bodypart, "native_wasted") end
end)
local N, I = AC.schemas.number, AC.schemas.integer
AC.registerRemote("utg_ac:aim", { I(0,20), N(0,180), I(0,20), N(0,5000) }, 2.5, 5,
    function(p, snaps, angle, divergence, acquisition)
        if not AC.enabled("aimbot") and not AC.enabled("silentaim") then return end
        local c = combat(p)
        if c then c.telemetry = { tick = AC.now(), snaps = snaps, angle = angle, divergence = divergence, acquisition = acquisition } end
    end)
function AC.combatStats(p)
    local c = combat(p)
    local m = { shots = 0, hits = 0, misses = 0, headshots = 0, hitRatio = 0, headshotRatio = 0,
        streak = 0, snaps = 0, distinctTargets = 0, combatMs = 0, aim_suspicion_score = AC.score(p, "aim") }
    if not c then return m end
    trim(c, AC.now())
    local streak, targets = 0, {}
    for _, shot in ipairs(c.shots) do
        if not AC.weaponProfiles[shot.weapon].pellets then
            m.shots = m.shots+1
            if shot.hit then
                m.hits = m.hits+1; streak = streak+1
                if shot.headshot then m.headshots = m.headshots+1 end
                if shot.snap then m.snaps = m.snaps+1 end
                if AC.player(shot.victim) then targets[shot.victim] = true end
                m.distance, m.weapon, m.bodypart = shot.distance, shot.weapon, shot.bodypart
                m.acquisitionMs, m.targetAngle = shot.acquisitionMs, shot.targetAngle
            else streak = 0 end
            m.streak = math.max(m.streak, streak)
        end
    end
    for _ in pairs(targets) do m.distinctTargets = m.distinctTargets+1 end
    m.misses = m.shots-m.hits -- Unmatched shots, NOT proven misses (custom damage/sync can omit hits).
    m.hitRatio, m.headshotRatio = m.hits/math.max(1,m.shots), m.headshots/math.max(1,m.hits)
    if #c.shots > 1 then m.combatMs = c.shots[#c.shots].tick-c.shots[1].tick end
    return m
end
function AC.evaluateCombat(p)
    local s, now = AC.players[p], AC.now()
    if not s or not s.combat or (s.lastCombatEval and now-s.lastCombatEval < 5000) then return end
    s.lastCombatEval = now
    if not AC.ready(p) or not AC.networkOK(p) then return end
    local m, c = AC.combatStats(p), s.combat
    if m.shots < AC.settings.minAimShots or m.combatMs < AC.settings.minAimCombatMs then return end
    if m.hitRatio > 0.94 and m.distinctTargets >= 3 then
        AC.record(p, "aim_accuracy", "aimbot", "aim", 0.75, 0.25, m, false)
        if m.snaps >= 8 then AC.record(p, "aim_snap", "aimbot", "aim", 3.5, 0.6, m, false) end
        local t = c.telemetry
        if t and now-t.tick <= 1500 and t.divergence >= 5 then
            AC.record(p, "silent_alignment", "silentaim", "aim", 2, 0.3,
                { divergence = t.divergence, hits = m.hits, ratio = m.hitRatio, provenance = "untrusted_self_telemetry_plus_damage" }, false)
        end
        if m.snaps >= 8 and t and now-t.tick <= 1500 and t.snaps >= 3 and t.angle >= 60 then
            AC.record(p, "aim_combination", "aimbot", "aim", 2, 0.6,
                { snaps = m.snaps, clientSnaps = t.snaps, hits = m.hits, provenance = "correlated_not_independent_proof" }, false)
        end
    end
end
