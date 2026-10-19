local C, U = ACClient, UTGUtils
local previous, lastTarget, targetTick, previousTick
local batch = { snaps = 0, angle = 0, divergence = 0, acquisition = 0 }
function C.sampleAim()
    if not C.enabled.aim or not C.ready() or not getPedControlState(localPlayer,"aim_weapon") then
        previous, lastTarget, targetTick, previousTick = nil,nil,nil,nil; return
    end
    -- One local camera sample, 10 Hz; never loops through players or hooks render.
    local x,y,z,tx,ty,tz = getCameraMatrix()
    local direction, target, now = {tx-x,ty-y,tz-z}, getPedTarget(localPlayer), getTickCount()
    if previous and previousTick and now-previousTick >= 50 and now-previousTick <= 250 then
        local angle = U.angle(previous,direction)
        batch.angle = math.max(batch.angle,angle)
        if target ~= lastTarget and isElement(target) and getElementType(target) == "player" and angle >= 60 then
            batch.snaps = math.min(20,batch.snaps+1)
        end
    end
    if target ~= lastTarget then targetTick = now end
    previous, lastTarget, previousTick = direction, target, now
end
addEventHandler("onClientPlayerWeaponFire",localPlayer,function(weapon,ammo,ammoInClip,hx,hy,hz,hitElement,sx,sy,sz)
    if not C.enabled.aim or not C.ready() or not previous then return end
    if not U.finite(hx) or not U.finite(hy) or not U.finite(hz) or not U.finite(sx) or not U.finite(sy) or not U.finite(sz) then return end
    local bullet = {hx-sx,hy-sy,hz-sz}
    if math.sqrt(bullet[1]^2+bullet[2]^2+bullet[3]^2) > 15 and U.angle(previous,bullet) > 35 then
        batch.divergence = math.min(20,batch.divergence+1)
    end
    batch.acquisition = math.max(0,math.min(5000,getTickCount()-(targetTick or getTickCount())))
end)
function C.sendAim()
    if C.enabled.aim and C.ready() then C.send("utg_ac:aim",batch.snaps,batch.angle,batch.divergence,batch.acquisition) end
    batch = { snaps = 0, angle = 0, divergence = 0, acquisition = 0 }
end
