ACClient = { enabled = { aim = false, collision = false, integrity = false }, timers = {}, hooks = {}, lastTick = getTickCount() }
local C = ACClient
function C.timer(fn, ms)
    local timer = setTimer(fn,ms,0)
    if timer then C.timers[#C.timers+1] = timer end
end
function C.send(name, ...) triggerServerEvent(name,resourceRoot,...) end
function C.ready()
    return getElementData(localPlayer,"dm:ready") == true and not isPedDead(localPlayer)
        and not isPedInVehicle(localPlayer) and not isElementFrozen(localPlayer)
end
addEvent("utg_ac:configure",true)
addEventHandler("utg_ac:configure",resourceRoot,function(aim,collision,integrity)
    if source ~= resourceRoot or type(aim) ~= "boolean" or type(collision) ~= "boolean" or type(integrity) ~= "boolean" then return end
    C.enabled = { aim = aim, collision = collision, integrity = integrity }
    C.configureIntegrity(integrity)
end)
addEventHandler("onClientResourceStart",resourceRoot,function()
    C.send("utg_ac:hello")
    C.timer(C.sampleAim,100)
    C.timer(C.sendAim,500)
    C.timer(C.sampleCollision,500)
end)
addEventHandler("onClientResourceStop",resourceRoot,function()
    for _, timer in ipairs(C.timers) do if isTimer(timer) then killTimer(timer) end end
    C.configureIntegrity(false)
    C.timers = {}
end)
