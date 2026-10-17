--[[
    Anti C-Bug fora da arena C-Bug: após atirar com armas de tiro lento, o agachar
    fica bloqueado pelo tempo do ciclo da arma. Na Arena C-Bug nada é bloqueado.
]]

local core = exports.dm_core
-- armas em que o C-Bug faz diferença e o tempo (ms) de bloqueio do agachar após o tiro
local SLOW = { [24] = 650, [25] = 950, [26] = 500, [27] = 450, [33] = 900, [34] = 1100 }
local blockTimer
local sw, sh = guiGetScreenSize()

local function currentArena()
    return core:getPlayerArena(localPlayer)
end

local function cbugAllowed()
    local arena = currentArena()
    return arena and arena.cbug == true
end

local function unblock()
    toggleControl("crouch", true)
    blockTimer = nil
end

addEventHandler("onClientPlayerWeaponFire", localPlayer, function(weapon)
    if cbugAllowed() then return end
    local ms = SLOW[weapon]
    if not ms then return end
    toggleControl("crouch", false)
    if blockTimer and isTimer(blockTimer) then killTimer(blockTimer) end
    blockTimer = setTimer(unblock, ms, 1)
end)

-- Ao entrar/sair da arena C-Bug
addEventHandler("onClientElementDataChange", localPlayer, function(key, old, new)
    if key ~= "dm:arena" or not getElementData(localPlayer, "dm:ready") then return end
    if blockTimer and isTimer(blockTimer) then killTimer(blockTimer) end
    unblock()
    local arena = currentArena()
    if arena and arena.cbug then
        core:notify("C-Bug LIBERADO nesta arena. Agache após atirar para cancelar a animação.", "success", "C-Bug")
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    toggleControl("crouch", true)
end)

-- Badge discreto no HUD indicando o estado do C-Bug com arma lenta na mão
addEventHandler("onClientRender", root, function()
    if not getElementData(localPlayer, "dm:ready") then return end
    local arena = currentArena()
    if not arena or arena.safe then return end
    local weapon = getPedWeapon(localPlayer)
    if not SLOW[weapon] then return end
    local allowed = arena.cbug == true
    local scale = math.max(0.75, math.min(1.25, math.min(sw / 1920, sh / 1080)))
    local w, h = 150 * scale, 26 * scale
    local x, y = sw - w - 24 * scale, sh - 104 * scale - 24 * scale - h - 10 * scale
    local r, g, b = 0, 229, 168
    if not allowed then r, g, b = 255, 77, 109 end
    dxDrawRectangle(x, y, w, h, tocolor(18, 22, 32, 220))
    dxDrawRectangle(x, y, 4 * scale, h, tocolor(r, g, b, 255))
    dxDrawText(allowed and "C-BUG LIBERADO" or "C-BUG BLOQUEADO", x + 12 * scale, y, x + w, y + h, tocolor(r, g, b, 255), scale * 0.95, "default-bold", "left", "center")
end)
