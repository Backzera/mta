local AC, U = AntiCheat, UTGUtils
local sequence = 0
function AC.pruneEvidence(p)
    local s, now = AC.players[p], AC.now()
    if not s then return end
    for i = #s.evidence, 1, -1 do
        if now-s.evidence[i].tick >= AC.settings.evidenceTTL then table.remove(s.evidence, i) end
    end
    -- Keys are server-owned detector codes, never arbitrary event names from clients.
    for key, tick in pairs(s.cooldowns) do if now-tick > AC.settings.evidenceTTL then s.cooldowns[key] = nil end end
end
function AC.score(p, onlyFamily)
    AC.pruneEvidence(p)
    local s, now, families, strongest = AC.players[p], AC.now(), {}, {}
    if not s then return 0, 0 end
    for _, e in ipairs(s.evidence) do
        if not onlyFamily or e.family == onlyFamily then
            local value = e.weight * math.max(0, 1-(now-e.tick)/AC.settings.evidenceTTL)
            if e.deterministic then families[e.family] = (families[e.family] or 0)+value
            else
                -- Repeated copies of the same heuristic do not turn skill into a
                -- high score. Only its strongest still-live observation contributes.
                local previous = strongest[e.type] or 0
                if value > previous then
                    families[e.family] = (families[e.family] or 0)+value-previous
                    strongest[e.type] = value
                end
            end
        end
    end
    local sum, independent = 0, 0
    for family, value in pairs(families) do
        sum = sum + math.min(value, AC.settings.familyCaps[family] or AC.settings.defaultFamilyCap)
        if value >= 1 then independent = independent+1 end
    end
    return math.min(20, sum), independent
end
function AC.record(p, code, detector, family, weight, confidence, metadata, deterministic)
    local s, now = AC.players[p], AC.now()
    if not s or not AC.enabled(detector) then return nil end
    if not deterministic and (s.ignoreUntil or 0) > now then return nil end
    if s.cooldowns[code] and now-s.cooldowns[code] < AC.settings.evidenceCooldown then return nil end
    s.cooldowns[code] = now
    AC.pruneEvidence(p)
    sequence = sequence+1
    local e = { id = sequence, type = code, detector = detector, family = family,
        weight = math.max(0, math.min(10, weight)), confidence = math.max(0, math.min(1, confidence)),
        tick = now, timestamp = getRealTime().timestamp, metadata = U.metadata(metadata),
        deterministic = deterministic == true }
    s.evidence[#s.evidence+1] = e
    if #s.evidence > AC.settings.maxEvidence then table.remove(s.evidence, 1) end
    local score, families = AC.score(p)
    AC.log("evidence", p, { detection = code, evidence = e.id, score = score, confidence = e.confidence,
        weapon = getPedWeapon(p), deterministic = e.deterministic }, e.metadata)
    AC.discordLog(p, e, score)
    local action = AC.settings.actions[code]
    if action and action ~= "LOG" then AC.punish(p, action, e) end
    if score >= 7 then AC.punish(p, "SCREENSHOT", e) end
    if score >= 5 then AC.punish(p, "STAFF_ALERT", e) end
    -- Score alone NEVER authorizes punishment. Families != independent proof:
    -- bullet sync, target sync and client telemetry can share a compromised origin.
    s.lastScoreFamilies = families
    return e
end
