-- Server resource identity and account ACL, never serial authorization.
AntiCheat.permissions = {
    staffGroups = { "Admin", "SuperModerator", "Moderator" },
    staffRight = "resource.utg_anticheat.staff",
    ignoreMs = 120000,
    resources = { dm_core = true, dm_ranked = true, dm_duel = true,
        dm_login = true, dm_maps = true, dm_weapons = true, admin = true },
}
