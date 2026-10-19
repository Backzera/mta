--[[
    Relatos das testemunhas (client/witness.lua). Diferente da telemetria do próprio suspeito, estes dados vêm
    de outros clientes, que o trapaceiro não controla: por isso entram como evidência DETERMINÍSTICA e podem
    levar a ban automático (política em punishment.lua + settings.actions/confirmations).
      rapid           → ban com 2 relatos (cadência é objetiva)
      silent (FORTE)  → ban com 2 relatos; silent fraco só alerta
      snap / lock     → ban com 3 relatos
    Staff nunca é banida automaticamente (só alertada). Todo relato gera alerta na tela da staff.
]]
local AC, U = AntiCheat, UTGUtils
local KIND = { rapid = "RAPID FIRE", silent = "SILENT AIM", snap = "AIMBOT", lock = "AIMBOT (lock)" }
local CODE = { rapid = "witness_rapid", silent = "witness_silent", snap = "witness_snap", lock = "witness_lock" }
AC.schemas.player = function(v) return isElement(v) and getElementType(v) == "player" end
AC.schemas.kind = function(v) return type(v) == "string" and KIND[v] ~= nil end

local function label(p)
    return ("%s [%s]"):format(U.text(getPlayerName(p), 40), tostring(AC.data(p, "dm:id") or "?"))
end

function AC.witnessAlert(suspect, kind, level, text)
    local msg = ("%s · %s"):format(label(suspect), text)
    AC.log("witness_alert", suspect, { kind = kind, level = level, text = U.text(text, 200) })
    for staff in pairs(AC.players) do
        if AC.isStaff(staff) then triggerClientEvent(staff, "utg_ac:alert", resourceRoot, KIND[kind] .. " · " .. level, msg) end
    end
end

AC.registerRemote("utg_ac:report", { AC.schemas.player, AC.schemas.kind, AC.schemas.string(200), AC.schemas.boolean }, 1, 4,
    function(witness, suspect, kind, detail, strong)
        if suspect == witness or not AC.player(suspect) then return end
        if getElementDimension(suspect) ~= getElementDimension(witness) then return end
        AC.initPlayer(suspect)
        local s = AC.players[suspect]
        local now = AC.now()
        -- memória de testemunhas distintas por tipo (TTL das evidências)
        s.witnesses = s.witnesses or {}
        s.witnesses[kind] = s.witnesses[kind] or {}
        s.witnesses[kind][witness] = now
        local distinct = 0
        for w, t in pairs(s.witnesses[kind]) do
            if not AC.player(w) or now - t > AC.settings.evidenceTTL then s.witnesses[kind][w] = nil else distinct = distinct + 1 end
        end
        local deterministic = kind == "rapid" or kind == "snap" or kind == "lock" or (kind == "silent" and strong)
        local e = AC.record(suspect, CODE[kind], "witness", "witness", 4, deterministic and 1 or 0.6,
            { detail = U.text(detail, 200), witness = U.text(getPlayerName(witness), 40), witnesses = distinct, strong = strong == true }, deterministic)
        local level = (strong or distinct >= 2) and "FORTE" or "SUSPEITA"
        if e then AC.witnessAlert(suspect, kind, level, U.text(detail, 160) .. (" · %d testemunha(s)"):format(distinct)) end
    end)
