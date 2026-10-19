-- Exact server-written player keys audited in dm_core, dm_ranked, dm_duel,
-- dm_login, dm_clans and dm_crates. No generic admin/money/godmode keys.
AntiCheat.protectedData = {}
for _, key in ipairs({ "dm:id", "dm:ready", "dm:arena", "dm:protected", "dm:loadout",
    "dm:managed", "dm:inDuel", "dm:noReward", "dm:noRespawn", "dm:guest",
    "dm:money", "dm:rp", "dm:level", "dm:tier", "dm:vip", "dm:perks",
    "dm:kills", "dm:deaths", "dm:headshots", "dm:bestStreak", "dm:streak",
    "dm:duelsWon", "dm:duelsLost", "dm:rankedWins", "dm:rankedLosses",
    "dm:clanId", "dm:clanTag", "dm:muted", "dm:skin", "dm:wskin",
    "dm:tag", "dm:nameColor" }) do AntiCheat.protectedData[key] = true end
