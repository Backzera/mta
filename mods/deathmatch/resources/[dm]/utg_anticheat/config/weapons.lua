-- Calibration starting points, NOT claims about GTA engine physical limits.
-- minimumMs is a conservative observation floor; C-BUG always gets its lower floor.
-- Never use firing_speed as a millisecond interval. All profiles are review-only.
AntiCheat.weaponProfiles = {
    [24] = { name = "Desert Eagle", minimumMs = 120, cbugMs = 45, toleranceMs = 20, burst = 4, violations = 12, range = 100 },
    [25] = { name = "Shotgun", minimumMs = 180, cbugMs = 65, toleranceMs = 25, burst = 4, violations = 12, range = 100, pellets = true },
    [26] = { name = "Sawn-off", minimumMs = 70, cbugMs = 40, toleranceMs = 20, burst = 6, violations = 14, range = 80, pellets = true },
    [27] = { name = "Combat Shotgun", minimumMs = 100, cbugMs = 50, toleranceMs = 20, burst = 5, violations = 12, range = 100, pellets = true },
    [29] = { name = "MP5", minimumMs = 55, cbugMs = 55, toleranceMs = 20, burst = 5, violations = 14, range = 120 },
    [30] = { name = "AK-47", minimumMs = 65, cbugMs = 65, toleranceMs = 20, burst = 5, violations = 14, range = 150 },
    [31] = { name = "M4", minimumMs = 55, cbugMs = 55, toleranceMs = 20, burst = 5, violations = 14, range = 180 },
    [33] = { name = "Rifle", minimumMs = 220, cbugMs = 70, toleranceMs = 25, burst = 4, violations = 12, range = 350 },
    [34] = { name = "Sniper", minimumMs = 250, cbugMs = 75, toleranceMs = 25, burst = 4, violations = 12, range = 400 },
}
AntiCheat.arenaWeapons = {
    lobby = { [0] = true }, ak47 = { [0] = true, [30] = true },
    m4 = { [0] = true, [31] = true }, cbug = { [0] = true, [24] = true, [25] = true, [34] = true },
    melee = { [0] = true, [8] = true },
    x1 = { [0] = true, [8] = true, [24] = true, [25] = true, [26] = true, [27] = true,
        [29] = true, [30] = true, [31] = true, [33] = true, [34] = true },
    m4_10x10 = { [0] = true, [31] = true, [34] = true },
    m4_5x5 = { [0] = true, [31] = true, [34] = true }, sniper_5x5 = { [0] = true, [34] = true },
}
AntiCheat.maxObservedAmmo = 10000 -- also compare with trusted individual loadout; refills allowed.
