local AC, U = AntiCheat, UTGUtils
local queue, busy, inFlight, started = {}, false, nil, 0
local generation = 0
local function validWebhook(url)
    return type(url) == "string" and url:match("^https://discord%.com/api/webhooks/%d+/[%w_%-]+$") ~= nil
end
function AC.discordLog(p, e, score)
    local cfg = AC.discordConfig
    if not cfg.enabled or not validWebhook(cfg.webhook) or not AC.player(p) then return end
    if #queue >= cfg.maxQueue then return end
    local account = getPlayerAccount(p)
    local lines = {
        "UTG AC | "..e.type.." | score "..string.format("%.2f",score),
        "Player: "..U.text(getPlayerName(p),64),
        "Account: "..(account and not isGuestAccount(account) and U.text(getAccountName(account),64) or "guest"),
        "Weapon: "..getPedWeapon(p).." | Ping: "..getPlayerPing(p),
        "Dimension: "..getElementDimension(p).." | Arena: "..U.text(AC.data(p,"dm:arena") or "unknown",32),
        "Evidence: "..e.id.." | Timestamp: "..e.timestamp.." | Mode: "..AC.mode(),
        "Details: "..U.text(toJSON(e.metadata,true),700),
    }
    if cfg.includeSerial then lines[#lines+1] = "Serial: "..getPlayerSerial(p) end
    if cfg.includeIP then lines[#lines+1] = "IP: "..getPlayerIP(p) end
    -- No player elements retained by the queue; cannot leak disconnected players.
    queue[#queue+1] = table.concat(lines,"\n"):sub(1,1800)
end
function AC.discordDrain()
    local cfg = AC.discordConfig
    if not cfg.enabled then queue = {}; return end
    if busy and AC.now()-started > 15000 then
        generation = generation+1
        if inFlight then abortRemoteRequest(inFlight) end
        busy, inFlight = false, nil
        AC.log("discord_status", nil, { status = "request_timeout" })
        return
    end
    if busy or #queue == 0 or not validWebhook(cfg.webhook) then return end
    local message = table.remove(queue,1)
    -- MTA toJSON wraps objects in an outer array; Discord expects an object.
    local body = toJSON({ content = message },true)
    if body:sub(1,1) == "[" then body = body:sub(2,-2) end
    -- Explicit JSON array: an empty Lua table may serialize as an object.
    body = body:gsub("}%s*$", ',"allowed_mentions":{"parse":[]}}')
    busy = true
    started = AC.now()
    generation = generation+1
    local requestGeneration = generation
    local request = fetchRemote(cfg.webhook, {
        queueName = "utg_anticheat_logs", connectionAttempts = 1, connectTimeout = 5000,
        method = "POST", postData = body, maxRedirects = 0, headers = { ["Content-Type"] = "application/json" },
    }, function(_, info)
        if requestGeneration ~= generation then return end
        busy, inFlight = false, nil
        -- Response bodies are never evaluated, compiled, loaded or displayed.
        if not info or not info.success then AC.log("discord_status", nil, { status = "delivery_failed" }) end
    end)
    if not request then busy = false elseif busy then inFlight = request end
end
function AC.discordShutdown()
    generation = generation+1
    if inFlight then abortRemoteRequest(inFlight) end
    queue, busy, inFlight = {}, false, nil
end
