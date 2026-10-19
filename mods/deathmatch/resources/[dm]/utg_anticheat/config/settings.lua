-- SERVER ONLY. Restart the resource after configuration changes.
AntiCheat = { version = "1.0.0", settings = {} }
local settings = AntiCheat.settings
settings.debugMode = false
settings.punishmentMode = "ENFORCE" -- LOG_ONLY | REVIEW | ENFORCE. Unknown => LOG_ONLY.
settings.detectors = {
    aimbot = true, silentaim = true, firerate = true, speedhack = true,
    teleport = true, fly = true, noclip = true, weaponhack = true,
    eventabuse = true, elementdata = true, luaexecutor = true, screenshot = true, vitals = true,
}
settings.evidenceTTL = 180000
settings.maxEvidence = 64
settings.evidenceCooldown = 10000
settings.familyCaps = { aim = 8, movement = 6, combat = 4, inventory = 5, integrity = 2, protocol = 10, data = 10, witness = 12 }
settings.defaultFamilyCap = 3
settings.maxGrace = 15000
settings.spawnGrace = 12000
settings.mutationGrace = 2000
settings.maxPing = 250
settings.maxPacketLoss = 2
settings.maxPingJitter = 80
settings.sampleInterval = 500
settings.sampleBudget = 32 -- Max players per 250 ms tick; under overload skip stale comparisons.
settings.movement = { horizontalSpeed = 16, teleportDistance = 65, consecutive = 4, hoverMs = 6000 }
settings.combatWindow = 60000
settings.maxShots = 512
settings.minAimShots = 100
settings.minAimCombatMs = 20000
settings.allowPermanentBan = true
settings.banIP = true -- ban por serial E IP
settings.tempBanSeconds = 900
-- Heurísticas do próprio suspeito nunca removem. Relatos de TESTEMUNHAS (outros clientes) podem: ver witness.lua.
settings.actions = { protected_data = "LOG", event_schema = "LOG", remote_source = "LOG",
    witness_rapid = "BAN", witness_silent = "BAN", witness_snap = "BAN", witness_lock = "BAN" }
settings.confirmedRequired = 3
settings.confirmations = { witness_rapid = 2, witness_silent = 2, witness_snap = 3, witness_lock = 3 }
settings.codeCooldown = { witness_rapid = 1500, witness_silent = 1500, witness_snap = 1500, witness_lock = 1500 }
settings.detectors.witness = true
settings.enableMutationHook = true
settings.enableClientIntegrityHook = false -- Optional diagnostic; never treats pcall as suspicious.
settings.screenshot = { width = 800, height = 450, quality = 40, bandwidth = 50000,
    timeout = 45000, cooldown = 60000, ttl = 900000, maxBytes = 1048576,
    maxFiles = 20, maxPending = 4 }
settings.maxLogBytes = 2097152 -- 3 rotating JSONL files, maximum ~6 MiB.
