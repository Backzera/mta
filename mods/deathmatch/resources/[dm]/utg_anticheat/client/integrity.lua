local C = ACClient
local installed, lastReport = false, nil
local function observe(r, fn, allowed, file, line, argument)
    if not C.enabled.integrity then return end
    local now = getTickCount()
    if lastReport and now-lastReport < 10000 then return end
    -- Resource-authored dynamic code is legitimate unless investigated separately.
    -- Missing resource / runtime string is context, not proof of executor.
    if r and type(file) == "string" and not file:find("[string",1,true) then return end
    lastReport = now
    C.send("utg_ac:integrity",r and getResourceName(r):sub(1,64) or "unknown",
        type(file) == "string" and file:sub(1,120) or "unknown",math.max(0,math.min(1000000,tonumber(line) or 0)),
        fn, type(argument) == "string" and math.min(#argument,10000000) or 0)
    -- No code/clipboard/password contents sent; never returns 'skip'.
end
function C.configureIntegrity(enabled)
    if enabled and not installed then installed = addDebugHook("preFunction",observe,{"loadstring","load"}) == true
    elseif not enabled and installed then removeDebugHook("preFunction",observe); installed = false end
end
