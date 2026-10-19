local C, U = ACClient, UTGUtils
local previous
function C.sampleCollision()
    if not C.enabled.collision or not C.ready() then previous = nil; return end
    local x,y,z = getElementPosition(localPlayer)
    local current = {x,y,z, tick = getTickCount(), dim = getElementDimension(localPlayer), interior = getElementInterior(localPlayer)}
    local blocked = false
    if previous and current.dim == previous.dim and current.interior == previous.interior then
        local dt, distance = current.tick-previous.tick, U.distance(current,previous)
        if dt >= 250 and dt <= 1000 and distance > 2 and distance < 20 then
            -- At most one local raycast per 500 ms, only while moving. Vehicles and
            -- players excluded. Missing/late custom collisions make this diagnostic only.
            blocked = processLineOfSight(previous[1],previous[2],previous[3],x,y,z,
                true,false,false,true,false,false,false,false,localPlayer) == true
        end
    end
    previous = current
    C.send("utg_ac:collision",blocked)
end
