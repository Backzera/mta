local AC, U = AntiCheat, UTGUtils
AC.schemas = {
    number = function(low, high) return function(v) return U.number(v, low, high) end end,
    integer = function(low, high) return function(v) return U.number(v, low, high) and v%1 == 0 end end,
    string = function(max) return function(v) return type(v) == "string" and #v <= max end end,
    boolean = function(v) return type(v) == "boolean" end,
}
function AC.consume(p, key, rate, burst)
    local s, now = AC.players[p], AC.now()
    if not s then return false end
    local b = s.buckets[key]
    if not b then b = { tokens = burst, tick = now }; s.buckets[key] = b end
    b.tokens = math.min(burst, b.tokens + (now-b.tick)*rate/1000)
    b.tick = now
    if b.tokens < 1 then return false end
    b.tokens = b.tokens-1
    return true
end
function AC.registerRemote(name, schema, rate, burst, callback)
    addEvent(name, true)
    -- root attachment observes spoofed sources too. The source is checked below;
    -- it is never used as the actor and cannot nominate a different player.
    addEventHandler(name, root, function(...)
        local p = client
        if not AC.player(p) then return end -- local triggerEvent isn't this protocol.
        AC.initPlayer(p)
        if not AC.consume(p, "total", 12, 24) or not AC.consume(p, name, rate, burst) then
            AC.record(p, "event_spam", "eventabuse", "protocol", 2, 0.6, { event = name }, false)
            return
        end
        if source ~= resourceRoot then
            AC.record(p, "remote_source", "eventabuse", "protocol", 3, 1, { event = name }, true)
            return
        end
        local args, count = { ... }, select("#", ...)
        local valid = count == #schema
        if valid then for i, rule in ipairs(schema) do if not rule(args[i]) then valid = false; break end end end
        if not valid then
            AC.record(p, "event_schema", "eventabuse", "protocol", 3, 1, { event = name, count = count }, true)
            return
        end
        callback(p, unpack(args, 1, count))
    end)
end
addEventHandler("onPlayerTriggerInvalidEvent", root, function(name, added, remote)
    -- Native event: source is the offender. Never register this remotely.
    if not AC.player(source) then return end
    AC.initPlayer(source)
    AC.record(source, "invalid_event", "eventabuse", "protocol", 1, 0.5,
        { event = U.text(name, 100), added = added == true, remote = remote == true }, false)
end)
addEventHandler("onPlayerTriggerEventThreshold", root, function(name)
    if not AC.player(source) then return end
    AC.initPlayer(source)
    AC.record(source, "native_event_threshold", "eventabuse", "protocol", 2, 0.7,
        { event = U.text(name, 100) }, false)
end)
AC.registerRemote("utg_ac:hello", {}, 0.2, 2, function(p)
    -- Only public booleans are sent; no server configuration/ACL/secrets.
    triggerClientEvent(p, "utg_ac:configure", resourceRoot,
        AC.enabled("aimbot") or AC.enabled("silentaim"), AC.enabled("noclip"),
        AC.enabled("luaexecutor") and AC.settings.enableClientIntegrityHook)
end)
