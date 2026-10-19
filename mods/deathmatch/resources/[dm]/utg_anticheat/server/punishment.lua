local AC = AntiCheat
local deterministicCodes = { protected_data = true, event_schema = true, remote_source = true,
    witness_rapid = true, witness_silent = true, witness_snap = true, witness_lock = true }
local actions = { LOG = true, WARN = true, SCREENSHOT = true, STAFF_ALERT = true, KICK = true, TEMPBAN = true, BAN = true }
function AC.punish(p, action, evidence)
    local s = AC.players[p]
    if not s or not actions[action] then return false, "invalid_action" end
    local found = false
    for _, e in ipairs(s.evidence) do if e == evidence then found = true; break end end
    if not found or AC.now()-evidence.tick >= AC.settings.evidenceTTL then return false, "no_evidence" end
    if action == "LOG" then return true end
    if AC.mode() == "LOG_ONLY" then return false, "log_only" end
    if action == "SCREENSHOT" then return AC.requestScreenshot(p, evidence.type, false) end
    if action == "STAFF_ALERT" or action == "WARN" then
        local key, now = "action_"..action, AC.now()
        if s.cooldowns[key] and now-s.cooldowns[key] < 30000 then return false, "cooldown" end
        s.cooldowns[key] = now
        if action == "WARN" then outputChatBox("[UTG AC] Sua sessao foi registrada para revisao da staff.", p, 255, 190, 80)
        else AC.staffAlert(p, evidence) end
        return true
    end
    -- Hard boundary: heuristic detectors cannot remove players, even in ENFORCE.
    if AC.mode() ~= "ENFORCE" or not evidence.deterministic or not deterministicCodes[evidence.type]
        or evidence.confidence < 0.99 or AC.settings.actions[evidence.type] ~= action then return false, "policy" end
    local confirmations = 0
    for _, e in ipairs(s.evidence) do
        if e.type == evidence.type and e.deterministic and e.confidence >= 0.99
            and AC.now()-e.tick < AC.settings.evidenceTTL then confirmations = confirmations+1 end
    end
    local required = (AC.settings.confirmations or {})[evidence.type] or AC.settings.confirmedRequired
    if confirmations < required then return false, "confirmations" end
    if AC.isStaff(p) then AC.log("staff_exempt", p, { action = action, detection = evidence.type }); return false, "staff" end
    if s.removalAttempt and AC.now()-s.removalAttempt < 30000 then return false, "cooldown" end
    if action == "BAN" and not AC.settings.allowPermanentBan then return false, "permanent_disabled" end
    if action == "TEMPBAN" and (not UTGUtils.number(AC.settings.tempBanSeconds, 60, 604800)
        or AC.settings.tempBanSeconds%1 ~= 0) then return false, "invalid_duration" end
    local right = action == "KICK" and "function.kickPlayer" or "function.banPlayer"
    if not hasObjectPermissionTo(getThisResource(), right, false) then
        AC.log("permission_denied", p, { action = action, right = right }); return false, "acl"
    end
    s.removalAttempt = AC.now()
    AC.log("punishment_attempt", p, { action = action, evidence = evidence.id, detection = evidence.type })
    local detail = evidence.metadata and evidence.metadata.detail or evidence.type
    local reason = "Anti-cheat: "..tostring(detail):sub(1, 90)
    if action == "KICK" then return kickPlayer(p, "UTG", reason) end
    -- Ban local por serial (e IP, se configurado); sem banco global.
    local name = UTGUtils.text(getPlayerName(p), 40)
    outputChatBox(("#FF4D6D⚠ #FFFFFF%s #8FA39Afoi banido pelo anti-cheat: #FF4D6D%s"):format(name, tostring(detail):sub(1, 60)), root, 255, 255, 255, true)
    for staff in pairs(AC.players) do
        if AC.isStaff(staff) then triggerClientEvent(staff, "utg_ac:alert", resourceRoot, "BAN AUTOMÁTICO", name .. " · " .. reason) end
    end
    return banPlayer(p, AC.settings.banIP == true, false, true, "UTG", reason, action == "TEMPBAN" and AC.settings.tempBanSeconds or 0)
end
