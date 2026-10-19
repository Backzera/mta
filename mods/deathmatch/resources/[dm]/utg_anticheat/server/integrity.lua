local AC = AntiCheat
local S, I = AC.schemas.string, AC.schemas.integer
AC.registerRemote("utg_ac:integrity", { S(64), S(120), I(0,1000000), S(16), I(0,10000000) }, 0.1, 2,
    function(p, resourceName, file, line, functionName, argumentBytes)
        if not AC.enabled("luaexecutor") or not AC.settings.enableClientIntegrityHook then return end
        if functionName ~= "loadstring" and functionName ~= "load" then return end
        -- Untrusted self-report; source names may be forged and dynamic Lua may be legitimate.
        AC.record(p,"dynamic_lua_context","luaexecutor","integrity",1,0.15,
            { resource = resourceName, file = file, line = line, fn = functionName,
              argumentBytes = argumentBytes, provenance = "untrusted_self_telemetry" },false)
    end)
