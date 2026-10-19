--[[
    UTG Anti-Cheat — lado do cliente.
    1) Alerta na tela do admin (toast + som).
    2) TESTEMUNHA de aimbot / silent aim: este cliente observa os OUTROS jogadores (nunca a si mesmo) usando o sync
       do MTA — para onde o ped está mirando (getPedTargetStart/End) e onde a bala dele acertou
       (onClientPlayerWeaponFire). O trapaceiro não controla o cliente das testemunhas, então não dá para desligar.
       · SILENT AIM: a bala acerta um jogador em uma direção bem diferente da que a mira aponta (ângulo > limiar),
         repetidamente.
       · AIMBOT (snap): a direção da mira gira dezenas de graus entre dois frames e, logo em seguida, o tiro acerta
         um jogador; repetidamente.
       Cada testemunha acumula pontos por suspeito e só reporta ao servidor com evidência consistente; o servidor
       cruza relatos de testemunhas diferentes e a precisão real antes de alertar/banir.
]]

-- ---------- alerta para admins ----------
addEvent("ac:alert", true)
addEventHandler("ac:alert", resourceRoot, function(kind, text)
    local ui = getResourceFromName("dm_ui")
    if ui and getResourceState(ui) == "running" then
        exports.dm_ui:notify(text, "error", "ANTI-CHEAT · " .. kind)
    else
        outputChatBox("[ANTI-CHEAT " .. kind .. "] " .. text, 255, 77, 109)
    end
    playSoundFrontEnd(16)
end)

-- ---------- testemunha ----------
local SILENT_ANGLE_HIT   = 14      -- graus: bala em jogador fora da direção da mira (tolerância ao lag do sync)
local SILENT_ANGLE_FAR   = 30      -- graus: bala em qualquer coisa muito fora da mira
local SNAP_DEG_PER_S     = 900     -- velocidade angular da mira considerada "salto" (humano forte ≈ 300–500°/s)
local SNAP_WINDOW_MS     = 220     -- o tiro que acerta tem de vir até este tempo depois do salto
local MAX_DIST           = 90      -- só observa suspeitos a até esta distância da câmera
local REPORT_SILENT      = 6       -- pontos para reportar (pontos decaem com o tempo)
local REPORT_SNAP        = 5
local DECAY_MS           = 30000
local REPORT_COOLDOWN    = 15000
local WATCHED = { [22]=true,[23]=true,[24]=true,[25]=true,[26]=true,[27]=true,[28]=true,[29]=true,[30]=true,[31]=true,[32]=true,[33]=true,[34]=true,[38]=true }

local obs = {}   -- [player] = { dx,dy,dz, t, angSpeed, lastSnap, silent = {pts}, snap = {pts}, lastReport = {} }

local function norm(x, y, z)
    local l = math.sqrt(x * x + y * y + z * z)
    if l < 1e-6 then return nil end
    return x / l, y / l, z / l
end
local function angleBetween(ax, ay, az, bx, by, bz)
    local d = ax * bx + ay * by + az * bz
    if d > 1 then d = 1 elseif d < -1 then d = -1 end
    return math.deg(math.acos(d))
end
local function prune(list, now)
    while list[1] and now - list[1] > DECAY_MS do table.remove(list, 1) end
end
local function observed(p)
    local o = obs[p]
    if not o then o = { silent = {}, snap = {}, lastReport = {} } obs[p] = o end
    return o
end
local function report(p, kind, detail)
    local o = observed(p)
    local now = getTickCount()
    if o.lastReport[kind] and now - o.lastReport[kind] < REPORT_COOLDOWN then return end
    o.lastReport[kind] = now
    o[kind] = {}
    triggerServerEvent("ac:report", localPlayer, p, kind, detail)
end

-- direção de mira dos outros jogadores a cada frame → velocidade angular
addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local cx, cy, cz = getCameraMatrix()
    for _, p in ipairs(getElementsByType("player", root, true)) do
        if p ~= localPlayer and getElementDimension(p) == getElementDimension(localPlayer) then
            local sx, sy, sz = getPedTargetStart(p)
            local ex, ey, ez = getPedTargetEnd(p)
            if sx and ex and getDistanceBetweenPoints3D(sx, sy, sz, cx, cy, cz) < MAX_DIST then
                local dx, dy, dz = norm(ex - sx, ey - sy, ez - sz)
                if dx then
                    local o = observed(p)
                    if o.dx and o.t then
                        local dt = (now - o.t) / 1000
                        if dt > 0.004 then
                            local ang = angleBetween(o.dx, o.dy, o.dz, dx, dy, dz)
                            o.angSpeed = ang / dt
                            if o.angSpeed > SNAP_DEG_PER_S and ang > 18 then o.lastSnap = now o.snapDeg = ang end
                        end
                    end
                    o.dx, o.dy, o.dz, o.t = dx, dy, dz, now
                end
            end
        end
    end
end)

-- tiro de outro jogador: compara a bala com a mira dele
addEventHandler("onClientPlayerWeaponFire", root, function(weapon, ammo, clip, hx, hy, hz, hitElement)
    if source == localPlayer or not WATCHED[weapon] then return end
    local o = obs[source]
    if not o or not o.dx or getTickCount() - (o.t or 0) > 300 then return end
    local now = getTickCount()
    local sx, sy, sz = getPedTargetStart(source)
    if not sx then return end
    local bx, by, bz = norm(hx - sx, hy - sy, hz - sz)
    if not bx then return end
    local dist = getDistanceBetweenPoints3D(sx, sy, sz, hx, hy, hz)
    if dist < 2 then return end   -- muito perto: ângulos ficam instáveis
    local hitPlayer = isElement(hitElement) and getElementType(hitElement) == "player"
    local ang = angleBetween(o.dx, o.dy, o.dz, bx, by, bz)

    -- SILENT AIM: bala em jogador longe da direção da mira
    if (hitPlayer and ang > SILENT_ANGLE_HIT) or ang > SILENT_ANGLE_FAR then
        prune(o.silent, now)
        o.silent[#o.silent + 1] = now
        if #o.silent >= REPORT_SILENT then
            report(source, "silent", ("%s · desvio médio > %d° em %d tiros"):format(getWeaponNameFromID(weapon) or weapon, SILENT_ANGLE_HIT, REPORT_SILENT))
        end
    end
    -- AIMBOT (snap): salto brusco de mira seguido de tiro que acerta jogador
    if hitPlayer and o.lastSnap and now - o.lastSnap <= SNAP_WINDOW_MS then
        o.lastSnap = nil
        prune(o.snap, now)
        o.snap[#o.snap + 1] = now
        if #o.snap >= REPORT_SNAP then
            report(source, "snap", ("%s · %d saltos de mira > %d° seguidos de acerto"):format(getWeaponNameFromID(weapon) or weapon, REPORT_SNAP, 18))
        end
    end
end)

addEventHandler("onClientPlayerQuit", root, function() obs[source] = nil end)
