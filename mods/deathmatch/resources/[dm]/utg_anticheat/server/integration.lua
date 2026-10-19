local AC, U = AntiCheat, UTGUtils
local function allow(p, kind, duration, reason)
    -- sourceResource is supplied by MTA exports, never accepted as an argument.
    if client or not AC.trustedResource(sourceResource) or not AC.player(p) then return false end
    if type(reason) ~= "string" or #reason < 1 or #reason > 120 then return false end
    return AC.grant(p, kind, duration, reason)
end
-- Intentional globals: server-only exports in meta.xml.
function allowTeleport(p, duration, reason) return allow(p, "teleport", duration, reason) end
function allowVelocity(p, duration, reason) return allow(p, "velocity", duration, reason) end
function allowHealth(p, duration, reason) return allow(p, "health", duration, reason) end
function allowArmor(p, duration, reason) return allow(p, "armor", duration, reason) end
function allowWeapons(p, duration, reason) return allow(p, "weapons", duration, reason) end

local changes = {
    spawnPlayer = "teleport", setElementPosition = "teleport", setElementDimension = "teleport",
    setElementInterior = "teleport", setElementVelocity = "velocity", setElementHealth = "health",
    setPedArmor = "armor", giveWeapon = "weapons", takeWeapon = "weapons",
    takeAllWeapons = "weapons", setWeaponAmmo = "weapons", setElementFrozen = "teleport",
}
function AC.installMutationHook()
    if not AC.settings.enableMutationHook then return end
    -- Event-driven O(1) per listed API call, no global preFunction hook and no skip.
    -- A successful call is not guaranteed by postFunction: an unnecessary grace is
    -- safer than a false accusation; caller must still be an audited server resource.
    local function mutation(r, name, allowed, file, line, p)
        if not allowed or not AC.trustedResource(r) or not AC.player(p) then return end
        local s = AC.players[p]
        if not s then return end
        AC.grant(p, changes[name], AC.settings.mutationGrace, getResourceName(r)..":"..name)
        if changes[name] == "teleport" then s.movement = nil end
        if changes[name] == "weapons" then s.inventory = nil end
        s.lastMutation = { resource = getResourceName(r), fn = name, file = U.text(file, 120), line = line, tick = AC.now() }
    end
    local names = {}
    for name in pairs(changes) do names[#names+1] = name end
    if addDebugHook("postFunction", mutation, names) then
        AC.hooks[#AC.hooks+1] = { kind = "postFunction", fn = mutation }
    else AC.log("configuration_warning", nil, { message = "Hook de integracao indisponivel: use exports antes de mutacoes legitimas." }) end
end
-- Map reload affects every player's collision. Fixed short grace, not a whitelist.
local function mapTransition(r)
    if not r or getResourceName(r) ~= "dm_maps" then return end
    for p, s in pairs(AC.players) do
        AC.grant(p, "teleport", AC.settings.spawnGrace, "map_resource_transition")
        s.movement = nil
    end
end
addEventHandler("onResourceStart", root, mapTransition)
addEventHandler("onResourceStop", root, mapTransition)
