local AC, U = AntiCheat, UTGUtils
AC.players, AC.order, AC.timers, AC.hooks = {}, {}, {}, {}
AC.clock = { last = getTickCount(), value = 0 }
-- Monotonic elapsed clock handles signed/unsigned getTickCount rollover.
function AC.now()
    local tick = getTickCount()
    local delta = (tick - AC.clock.last) % 4294967296
    AC.clock.last = tick
    AC.clock.value = AC.clock.value + delta
    return AC.clock.value
end
function AC.player(p) return isElement(p) and getElementType(p) == "player" end
function AC.mode()
    local m = AC.settings.punishmentMode
    if AC.settings.debugMode or (m ~= "REVIEW" and m ~= "ENFORCE") then return "LOG_ONLY" end
    return m
end
function AC.enabled(name) return AC.settings.detectors[name] == true end
function AC.initPlayer(p)
    if not AC.player(p) then return nil end
    if AC.players[p] then return AC.players[p] end
    local s = { data = {}, evidence = {}, cooldowns = {}, buckets = {}, grace = {}, created = AC.now() }
    for key in pairs(AC.protectedData) do s.data[key] = getElementData(p, key) end
    AC.players[p] = s
    AC.order[#AC.order+1] = p
    s.index = #AC.order
    s.grace.teleport = AC.now() + AC.settings.spawnGrace
    s.grace.weapons = s.grace.teleport
    return s
end
function AC.data(p, key) local s = AC.players[p]; return s and s.data[key] end
function AC.ready(p) return AC.player(p) and AC.data(p, "dm:ready") == true and not isPedDead(p) end
function AC.sameWorld(a, b)
    return AC.player(a) and AC.player(b) and getElementDimension(a) == getElementDimension(b)
        and getElementInterior(a) == getElementInterior(b)
end
function AC.position(p) return { getElementPosition(p) } end
function AC.networkOK(p)
    local s, now = AC.players[p], AC.now()
    if not s then return false end
    if s.network and now-s.network.tick < 1000 then return s.network.ok end
    local ping = getPlayerPing(p)
    local stats = getNetworkStats(p)
    local loss = stats and stats.packetlossLastSecond
    local jitter = s.network and math.abs(ping-s.network.ping) or 0
    local ok = U.number(ping, 0, AC.settings.maxPing) and U.number(loss, 0, AC.settings.maxPacketLoss)
        and jitter <= AC.settings.maxPingJitter
        and not (stats.isLimitedByCongestionControl == true)
    s.network = { tick = now, ping = ping, loss = loss or -1, jitter = jitter, ok = ok }
    return ok
end
function AC.grant(p, kind, duration, reason)
    local s = AC.players[p]
    if not s or not U.number(duration, 1, AC.settings.maxGrace) then return false end
    s.grace[kind] = math.max(s.grace[kind] or 0, AC.now()+duration)
    s.lastGrace = { kind = kind, reason = U.text(reason, 80), expires = s.grace[kind] }
    return true
end
function AC.hasGrace(p, kind)
    local s = AC.players[p]
    return s and (s.grace[kind] or 0) > AC.now() or false
end
function AC.trustedResource(r)
    return r and AC.permissions.resources[getResourceName(r)] == true
end
function AC.timer(fn, ms)
    local t = setTimer(fn, ms, 0)
    if t then AC.timers[#AC.timers+1] = t end
    return t
end
function AC.log(kind, p, info, evidenceData)
    local row = { timestamp = getRealTime().timestamp, type = kind, mode = AC.mode(), metadata = U.metadata(info) }
    if evidenceData then row.evidence = U.metadata(evidenceData) end
    if AC.player(p) then
        local account = getPlayerAccount(p)
        row.player = U.text(getPlayerName(p), 64)
        row.account = account and not isGuestAccount(account) and U.text(getAccountName(account), 64) or "guest"
        row.serial = getPlayerSerial(p)
        row.ping, row.dimension = getPlayerPing(p), getElementDimension(p)
        row.arena = U.text(AC.data(p, "dm:arena") or "unknown", 32)
        local id = AC.data(p, "dm:id")
        row.id = U.finite(id) and id or -1
    end
    local encoded = toJSON(row, true)
    if type(encoded) ~= "string" then return end
    outputServerLog("[utg_anticheat] "..encoded)
    -- Bounded local audit trail. Server's main log retention is a host setting.
    local path = "@audit-"..tostring(AC.logSlot or 1)..".jsonl"
    local f = fileOpen(path) or fileCreate(path)
    if f then
        if fileGetSize(f) + #encoded > AC.settings.maxLogBytes then
            fileClose(f)
            AC.logSlot = (AC.logSlot or 1)%3+1
            path = "@audit-"..AC.logSlot..".jsonl"
            if fileExists(path) then fileDelete(path) end
            f = fileCreate(path)
        end
        if f then fileSetPos(f, fileGetSize(f)); fileWrite(f, encoded.."\n"); fileClose(f) end
    end
end
function AC.forget(p)
    local s = AC.players[p]
    if not s then return end
    local last = AC.order[#AC.order]
    AC.order[s.index] = last
    AC.order[#AC.order] = nil
    if last ~= p and AC.players[last] then AC.players[last].index = s.index end
    AC.players[p] = nil
    -- Remove references in other players' short combat records on disconnect.
    for _, other in pairs(AC.players) do
        local c = other.combat
        if c then
            if c.target == p then c.target = nil end
            if c.previousTarget == p then c.previousTarget = nil end
            for _, shot in ipairs(c.shots) do if shot.victim == p then shot.victim = nil end end
        end
    end
    if AC.cancelScreenshot then AC.cancelScreenshot(p) end
end
addEventHandler("onPlayerJoin", root, function() AC.initPlayer(source) end)
addEventHandler("onPlayerQuit", root, function() AC.forget(source) end)
addEventHandler("onPlayerSpawn", root, function()
    local s = AC.initPlayer(source)
    if not s then return end
    s.movement, s.combat, s.inventory = nil, nil, nil
    for _, kind in ipairs({ "teleport", "velocity", "health", "armor", "weapons" }) do
        AC.grant(source, kind, AC.settings.spawnGrace, "spawn")
    end
end)
addEventHandler("onPlayerWasted", root, function()
    local s = AC.players[source]
    if s then s.movement, s.inventory = nil, nil end
end)
addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do AC.initPlayer(p) end
    AC.installMutationHook()
    AC.screenshotStartup()
    AC.log("startup", nil, { version = AC.version, mode = AC.mode() })
    local old = getResourceFromName("dm_anticheat")
    if old and getResourceState(old) == "running" then
        AC.log("configuration_warning", nil, { message = "dm_anticheat ativo: ele ainda pode banir. Pare-o antes do teste LOG_ONLY." })
    end
    local cursor = 1
    AC.timer(function()
        local now, n = AC.now(), #AC.order
        for _ = 1, math.min(n, AC.settings.sampleBudget) do
            if cursor > n then cursor = 1 end
            local p = AC.order[cursor]
            cursor = cursor+1
            local s = AC.players[p]
            if s and (not s.lastSample or now-s.lastSample >= AC.settings.sampleInterval) then
                s.lastSample = now
                AC.pruneEvidence(p)
                AC.sampleMovement(p)
                AC.sampleWeapons(p)
                AC.evaluateCombat(p)
            end
        end
    end, 250)
    AC.timer(AC.screenshotMaintenance, 1000)
    AC.timer(AC.discordDrain, AC.discordConfig.interval)
end)
addEventHandler("onResourceStop", resourceRoot, function()
    for _, t in ipairs(AC.timers) do if isTimer(t) then killTimer(t) end end
    for _, h in ipairs(AC.hooks) do removeDebugHook(h.kind, h.fn) end
    AC.screenshotShutdown()
    AC.discordShutdown()
    AC.players, AC.order, AC.timers, AC.hooks = {}, {}, {}, {}
end)
