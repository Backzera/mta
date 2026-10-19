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
local SNAP_DEG           = 22      -- salto de mira (graus) entre duas atualizações de sync (~100 ms) considerado suspeito
local SNAP_MAX_DT        = 260     -- ms: só vale se as duas atualizações forem próximas (sync normal)
local SNAP_WINDOW_MS     = 320     -- o tiro que acerta tem de vir até este tempo depois do salto
local MAX_DIST           = 90      -- só observa suspeitos a até esta distância da câmera
local REPORT_SILENT      = 5       -- pontos para reportar (pontos decaem com o tempo)
local REPORT_SNAP        = 3
-- SNAP-ON-FIRE (aimbot que só gruda no clique): erro da mira para a cabeça da vítima alguns ms ANTES do tiro
-- grande, e no instante do tiro quase zero. Humano que acerta já vinha perto antes.
local SOF_BEFORE_MIN_MS, SOF_BEFORE_MAX_MS = 120, 450
local SOF_ERR_BEFORE     = 5       -- graus: estava pelo menos isto fora da cabeça antes do tiro
local SOF_ERR_AT_SHOT    = 1.2     -- graus: e no tiro estava dentro disto
-- LOCK (aimbot suave/humanizado): a mira fica grudada na cabeça de um alvo em movimento, com erro mínimo,
-- por várias atualizações de sync seguidas. Humano treme e atrasa; aimbot acompanha perfeito.
local LOCK_MAX_ERR       = 1.3     -- graus de erro máximo entre a mira e a cabeça do alvo durante o lock
local LOCK_UPDATES       = 8       -- atualizações de sync seguidas (~0,8 s) para contar 1 ponto
local LOCK_MIN_MOVE      = 5       -- graus que o alvo tem de ter se deslocado (relativo ao atirador) no período
local LOCK_MAX_RANGE     = 120
local REPORT_LOCK        = 3
local DECAY_MS           = 90000
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
    if not o then o = { silent = {}, snap = {}, lockPts = {}, lastReport = {} } obs[p] = o end
    return o
end
local function report(p, kind, detail)
    local o = observed(p)
    local now = getTickCount()
    if o.lastReport[kind] and now - o.lastReport[kind] < REPORT_COOLDOWN then return end
    o.lastReport[kind] = now
    if kind == "lock" then o.lockPts = {} else o[kind] = {} end
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
                        local ang = angleBetween(o.dx, o.dy, o.dz, dx, dy, dz)
                        if ang > 0.5 then   -- só conta quando o sync realmente atualizou a mira
                            local dtms = now - (o.tUpd or o.t)
                            o.lastAng, o.lastDt = ang, dtms
                            if ang >= SNAP_DEG and dtms <= SNAP_MAX_DT then o.lastSnap = now o.snapDeg = ang end
                            o.tUpd = now
                        end
                    end
                    -- LOCK: mira grudada na cabeça de alguém?
                    if o.lastAng and o.tUpd == now then
                        local best, bestErr, bestDir = nil, 99, nil
                        for _, tgt in ipairs(getElementsByType("player", root, true)) do
                            if tgt ~= p and getElementDimension(tgt) == getElementDimension(p) and not isPedDead(tgt) then
                                local hx, hy, hz = getPedBonePosition(tgt, 8)
                                if hx and getDistanceBetweenPoints3D(sx, sy, sz, hx, hy, hz) < LOCK_MAX_RANGE then
                                    local tx, ty, tz = norm(hx - sx, hy - sy, hz - sz)
                                    if tx then
                                        local err = angleBetween(dx, dy, dz, tx, ty, tz)
                                        if err < bestErr then best, bestErr, bestDir = tgt, err, { tx, ty, tz } end
                                    end
                                end
                            end
                        end
                        o.tgt, o.tgtErr = best, bestErr
                        o.errHist = o.errHist or {}
                        o.errHist[#o.errHist + 1] = { t = now, tgt = best, err = bestErr }
                        while o.errHist[1] and now - o.errHist[1].t > 800 do table.remove(o.errHist, 1) end
                        -- estatísticas para o /acdebug (janela de 60 s)
                        o.st = o.st or { upd = 0, under = 0, minErr = 99, t0 = now }
                        if now - o.st.t0 > 60000 then o.st = { upd = 0, under = 0, minErr = 99, t0 = now } end
                        if best then
                            o.st.upd = o.st.upd + 1
                            if bestErr <= LOCK_MAX_ERR then o.st.under = o.st.under + 1 end
                            if bestErr < o.st.minErr then o.st.minErr = bestErr end
                        end
                        local lk = o.lock
                        if best and bestErr <= LOCK_MAX_ERR then
                            local vx, vy, vz = getElementVelocity(best)
                            local moving = (vx * vx + vy * vy + vz * vz) > 0.0016   -- alvo andando/correndo
                            if lk and lk.target == best then
                                lk.n = lk.n + 1
                                lk.maxErr = math.max(lk.maxErr, bestErr)
                                lk.move = angleBetween(lk.d0[1], lk.d0[2], lk.d0[3], bestDir[1], bestDir[2], bestDir[3])
                                if moving then lk.moved = lk.moved + 1 end
                                if lk.n >= LOCK_UPDATES and lk.move >= LOCK_MIN_MOVE and lk.moved >= LOCK_UPDATES / 2 and not lk.counted then
                                    lk.counted = true
                                    prune(o.lockPts, now)
                                    o.lockPts[#o.lockPts + 1] = now
                                    o.lockLast = ("LOCK em %s: %d upd, erro máx %.1f°, alvo moveu %.0f°"):format(getPlayerName(best):gsub("#%x%x%x%x%x%x", ""), lk.n, lk.maxErr, lk.move)
                                    if #o.lockPts >= REPORT_LOCK then
                                        report(p, "lock", ("mira grudada na cabeça de alvo em movimento (%d vezes, erro < %.1f°)"):format(REPORT_LOCK, LOCK_MAX_ERR))
                                    end
                                end
                            else
                                o.lock = { target = best, n = 1, maxErr = bestErr, d0 = bestDir, move = 0, moved = 0 }
                            end
                        else
                            o.lock = nil
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
    local snapRecent = o.lastSnap and now - o.lastSnap <= SNAP_WINDOW_MS

    -- SILENT AIM: bala em jogador longe da direção da mira
    if (hitPlayer and ang > SILENT_ANGLE_HIT) or ang > SILENT_ANGLE_FAR then
        prune(o.silent, now)
        o.silent[#o.silent + 1] = now
        if #o.silent >= REPORT_SILENT then
            report(source, "silent", ("%s · desvio médio > %d° em %d tiros"):format(getWeaponNameFromID(weapon) or weapon, SILENT_ANGLE_HIT, REPORT_SILENT))
        end
    end
    -- AIMBOT (snap-on-fire): antes do tiro a mira estava longe da cabeça da vítima; no tiro, em cima dela
    local sof = false
    if hitPlayer then
        local hx2, hy2, hz2 = getPedBonePosition(hitElement, 8)
        if hx2 then
            local tx, ty, tz = norm(hx2 - sx, hy2 - sy, hz2 - sz)
            local errNow = tx and angleBetween(o.dx, o.dy, o.dz, tx, ty, tz) or 99
            local errBefore, nBefore = 0, 0
            for _, h in ipairs(o.errHist or {}) do
                local age = now - h.t
                if age >= SOF_BEFORE_MIN_MS and age <= SOF_BEFORE_MAX_MS and h.tgt == hitElement then
                    nBefore = nBefore + 1
                    if h.err > errBefore then errBefore = h.err end
                end
            end
            o.sofLast = ("antes %.1f° → no tiro %.1f°"):format(errBefore, errNow)
            if nBefore > 0 and errNow <= SOF_ERR_AT_SHOT and errBefore >= SOF_ERR_BEFORE then sof = true end
        end
    end
    o.log = o.log or {}
    o.sh = o.sh or { hits = 0, hitDev = 0, miss = 0, missDev = 0 }
    if hitPlayer then o.sh.hits, o.sh.hitDev = o.sh.hits + 1, o.sh.hitDev + ang else o.sh.miss, o.sh.missDev = o.sh.miss + 1, o.sh.missDev + ang end
    table.insert(o.log, 1, ("%s %s desvio %.0f° %s%s"):format(getWeaponNameFromID(weapon) or weapon, hitPlayer and "ACERTOU jogador" or "errou",
        ang, (snapRecent and ("SALTO " .. math.floor(o.snapDeg or 0) .. "° ") or "") .. (hitPlayer and o.sofLast and (o.sofLast .. (sof and " SNAP-ON-FIRE " or " ")) or ""), ("sil %d/%d snap %d/%d"):format(#o.silent, REPORT_SILENT, #o.snap, REPORT_SNAP)))
    while #o.log > 6 do table.remove(o.log) end
    -- AIMBOT (snap): salto brusco de mira seguido de tiro que acerta jogador, ou snap-on-fire
    if hitPlayer and (snapRecent or sof) then
        o.lastSnap = nil
        prune(o.snap, now)
        o.snap[#o.snap + 1] = now
        if #o.snap >= REPORT_SNAP then
            report(source, "snap", ("%s · %d saltos de mira > %d° seguidos de acerto"):format(getWeaponNameFromID(weapon) or weapon, REPORT_SNAP, 18))
        end
    end
end)

addEventHandler("onClientPlayerQuit", root, function() obs[source] = nil end)

-- ---------- /acdebug: mostra na tela o que as testemunhas estão medindo (para calibrar) ----------
local debugOn = false
addCommandHandler("acdebug", function() debugOn = not debugOn outputChatBox("[ANTI-CHEAT] debug " .. (debugOn and "ligado" or "desligado"), 124, 255, 178) end)
addEventHandler("onClientRender", root, function()
    if not debugOn then return end
    local y = 0.22 * select(2, guiGetScreenSize())
    for p, o in pairs(obs) do
        if isElement(p) and o.t and getTickCount() - o.t < 5000 then
            local name = getPlayerName(p):gsub("#%x%x%x%x%x%x", "")
            dxDrawText(("%s  mira: Δ%.0f° em %d ms  %s"):format(name, o.lastAng or 0, o.lastDt or 0, (o.lastSnap and getTickCount() - o.lastSnap < 1000) and "<< SALTO" or ""), 22, y, 0, 0, tocolor(124, 255, 178), 1.1, "default-bold")
            y = y + 18
            local lk = o.lock
            dxDrawText(("alvo: %s erro %.1f°  lock %s  pontos lock %d/%d  %s"):format(isElement(o.tgt) and getPlayerName(o.tgt):gsub("#%x%x%x%x%x%x", "") or "-", o.tgtErr or 99,
                lk and ("%d upd / máx %.1f° / moveu %.0f°"):format(lk.n, lk.maxErr, lk.move) or "-", #(o.lockPts or {}), REPORT_LOCK, o.lockLast or ""), 34, y, 0, 0, tocolor(255, 200, 120), 1, "default")
            y = y + 16
            local st, sh = o.st or { upd = 0, under = 0, minErr = 99 }, o.sh or { hits = 0, hitDev = 0, miss = 0, missDev = 0 }
            dxDrawText(("60s: %d upd mirando alguém, %d com erro < %.1f° (%.0f%%), menor erro %.1f°  |  tiros: %d acertos (desvio médio %.1f°), %d erros (desvio médio %.1f°)"):format(
                st.upd, st.under, LOCK_MAX_ERR, st.upd > 0 and st.under / st.upd * 100 or 0, st.minErr,
                sh.hits, sh.hits > 0 and sh.hitDev / sh.hits or 0, sh.miss, sh.miss > 0 and sh.missDev / sh.miss or 0), 34, y, 0, 0, tocolor(255, 240, 160), 1, "default")
            y = y + 16
            for _, line in ipairs(o.log or {}) do dxDrawText(line, 34, y, 0, 0, tocolor(230, 230, 230), 1, "default") y = y + 16 end
            y = y + 8
        end
    end
end)
