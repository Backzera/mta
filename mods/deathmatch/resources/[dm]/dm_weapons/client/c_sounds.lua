--[[
    Sons de arma customizados: silencia o grupo de sons de armas do GTA e toca os nossos.
]]

local sounds = {}
for _, id in ipairs({ 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 38 }) do
    local path = ("sounds/%d.wav"):format(id)
    if fileExists(path) then sounds[id] = path end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    setWorldSoundEnabled(5, false)   -- grupo 5 = sons de armas
end)
addEventHandler("onClientResourceStop", resourceRoot, function()
    setWorldSoundEnabled(5, true)
end)

addEventHandler("onClientPlayerWeaponFire", root, function(weapon, ammo, ammoInClip, hitX, hitY, hitZ, hitElement, startX, startY, startZ)
    local path = sounds[weapon]
    if not path then return end
    if source == localPlayer then
        local snd = playSound(path, false)
        if snd then setSoundVolume(snd, 0.9) end
    else
        local x, y, z = getElementPosition(source)
        local snd = playSound3D(path, x, y, z, false)
        if snd then
            setSoundMaxDistance(snd, 140)
            setSoundVolume(snd, 1.0)
        end
    end
end)
