local AC, U = AntiCheat, UTGUtils
function AC.sampleWeapons(p)
    local s = AC.players[p]
    if not s then return end
    if not AC.enabled("weaponhack") or not AC.ready(p) or AC.hasGrace(p,"weapons") or not AC.networkOK(p) then
        s.inventory = nil; return
    end
    local allowed = AC.arenaWeapons[AC.data(p,"dm:arena")]
    if not allowed then s.inventory = nil; return end -- unknown modes must be integrated, not accused
    local loadout = AC.data(p,"dm:loadout")
    if type(loadout) ~= "table" then s.inventory = nil; return end
    local badWeapon, badAmmo, amount
    -- Fixed 13 slots, twice/second maximum per player. Does not scan all elements.
    for slot = 0, 12 do
        local weapon = getPedWeapon(p, slot)
        if weapon and weapon > 0 then
            local ammo = getPedTotalAmmo(p, slot)
            local granted = tonumber(loadout[tostring(weapon)])
            if not allowed[weapon] or not granted then badWeapon = weapon end
            if U.finite(ammo) and (ammo > AC.maxObservedAmmo or (granted and ammo > granted+32)) then
                badAmmo, amount = weapon, ammo
            end
        end
    end
    if not badWeapon and not badAmmo then s.inventory = nil; return end
    local signature = tostring(badWeapon)..":"..tostring(badAmmo)
    local old = s.inventory
    s.inventory = { signature = signature, count = old and old.signature == signature and old.count+1 or 1 }
    if s.inventory.count >= 3 then
        AC.record(p, badWeapon and "unexpected_weapon" or "unexpected_ammo", "weaponhack", "inventory", 3, 0.7,
            { weapon = badWeapon or badAmmo, ammo = amount or 0, samples = s.inventory.count,
              arena = AC.data(p,"dm:arena"), provenance = "server_inventory_vs_trusted_loadout" }, false)
    end
end
