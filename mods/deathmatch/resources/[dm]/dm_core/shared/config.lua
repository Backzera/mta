--[[
    DM Core · Configuração compartilhada (servidor + cliente)
    ---------------------------------------------------------
    Tudo que é "regra do servidor" fica aqui: nome, cores, XP,
    arenas, armas de cada arena, spawns padrão, etc.
]]

DM = DM or {}

DM.server = {
    name            = "UTG MATA-MATA",
    tagline         = "#Return2k26",
    fullName        = "UTG MATA-MATA #Return2k26",
    discord         = "discord.gg/utg",            -- mostrado nas mensagens automáticas (edite)
    chatPrefix      = "#8B5CF6[UTG]#FFFFFF",
    respawnDelay    = 3000,                        -- ms até renascer após morrer
    respawnDelayVip = 2000,                        -- ms para VIP
    spawnProtection = 3000,                        -- ms de proteção ao nascer
    spawnFreeze     = 900,                         -- ms congelado ao nascer (carregar mapa)
    healOnKill      = 25,                          -- vida recuperada ao matar
    refillOnKill    = true,                        -- recarrega munição ao matar
    refillOnSwitch  = true,                        -- arma volta cheia ao trocar e pegar de novo
    saveInterval    = 60000,
    chatCooldown    = 800,
    broadcastEvery  = 180000,                      -- ms entre mensagens automáticas do servidor
    duelRequestTTL  = 25000,
    duelArmor       = 0,
    duelCountdown   = 3,
    weather         = 10,
    time            = { 20, 0 },
}

-- ECONOMIA (kills dão dinheiro, nunca pontos de rank)
DM.economy = {
    kill            = 120,     -- $ por kill em arena
    headshotBonus   = 60,      -- $ extra em headshot
    streakBonusEach = 15,      -- $ extra por kill de sequência (x streak, até 10)
    duelWin         = 500,
    rankedWin       = 1500,    -- $ ao vencer partida ranqueada
    rankedLoss      = 400,
    rankedKill      = 60,      -- $ por kill em partida ranqueada
    playtimeEvery   = 600000,  -- ms (10 min) online -> bônus
    playtimeBonus   = 300,
    dailyBonus      = 1000,    -- bônus diário no primeiro login do dia
    clanCreate      = 50000,   -- custo para criar um clã
    vipMultiplier   = { [1] = 1.25, [2] = 1.5, [3] = 2.0 },  -- multiplicador de $ por nível de VIP
}

-- PONTOS DE RANK (RP): só em partidas ranqueadas e duelos
DM.rp = {
    rankedWin   = 20,   -- + por vitória
    rankedLoss  = -10,  -- por derrota
    rankedKill  = 1,    -- + por kill na partida
    rankedMvp   = 5,    -- + para o melhor da partida
    duelWin     = 5,
    duelLoss    = -3,
}

-- Níveis (elo) por RP
DM.tiers = {
    { min = 0,    name = "Bronze",   short = "BRZ", color = { 205, 127, 50 } },
    { min = 200,  name = "Prata",    short = "PRT", color = { 192, 198, 210 } },
    { min = 500,  name = "Ouro",     short = "OUR", color = { 245, 196, 81 } },
    { min = 900,  name = "Platina",  short = "PLT", color = { 120, 220, 255 } },
    { min = 1400, name = "Diamante", short = "DIA", color = { 110, 160, 255 } },
    { min = 2000, name = "Mestre",   short = "MST", color = { 200, 110, 255 } },
    { min = 3000, name = "Lenda",    short = "LND", color = { 255, 77, 109 } },
}

-- TAGS de staff (grupo da ACL -> tag). Prioridade: staff > VIP > tag comprada > elo
DM.staffTags = {
    { group = "Admin",          text = "ADMIN",      color = { 255, 77, 109 } },
    { group = "SuperModerator", text = "SUPERVISOR", color = { 255, 140, 66 } },
    { group = "Moderator",      text = "MODERADOR",  color = { 86, 180, 255 } },
    { group = "Helper",         text = "AJUDANTE",   color = { 34, 230, 138 } },
}

-- VIP (30 dias). advantages: multiplicador de $, respawn mais rápido, cor de nick, skins extras, bônus diário maior
DM.vip = {
    [1] = { name = "VIP Bronze", price = 60000,  days = 30, color = { 205, 127, 50 }, tag = "VIP",       daily = 2000, armor = 0 },
    [2] = { name = "VIP Prata",  price = 150000, days = 30, color = { 192, 198, 210 }, tag = "VIP+",     daily = 3500, armor = 0 },
    [3] = { name = "VIP Ouro",   price = 300000, days = 30, color = { 245, 196, 81 }, tag = "VIP OURO", daily = 6000, armor = 0 },
}

-- LOJA (F4)
DM.shop = {
    tags = {
        { key = "veterano",  text = "VETERANO",  price = 15000,  color = { 120, 220, 255 } },
        { key = "assassino", text = "ASSASSINO", price = 40000,  color = { 255, 77, 109 } },
        { key = "sniper",    text = "SNIPER",    price = 40000,  color = { 200, 110, 255 } },
        { key = "lenda",     text = "LENDA",     price = 100000, color = { 245, 196, 81 } },
        { key = "custom",    text = "PERSONALIZADA", price = 150000, color = { 34, 211, 238 }, custom = true }, -- /tag <texto>
    },
    nameColors = {
        { key = "roxo",    name = "Roxo",    price = 30000, color = { 139, 92, 246 } },
        { key = "ciano",   name = "Ciano",   price = 30000, color = { 34, 211, 238 } },
        { key = "verde",   name = "Verde",   price = 30000, color = { 34, 230, 138 } },
        { key = "dourado", name = "Dourado", price = 45000, color = { 245, 196, 81 } },
        { key = "rosa",    name = "Rosa",    price = 45000, color = { 255, 105, 180 } },
    },
    extras = {
        { key = "skins",  name = "Pacote de skins",   desc = "Libera /skin com qualquer id",      price = 25000 },
        { key = "fastrespawn", name = "Respawn rápido", desc = "Renasce em 2s em vez de 3s",     price = 50000 },
    },
}

-- MODOS RANQUEADOS (partidas em dimensões próprias; aquecimento até completar os jogadores)
-- Spawns: edite à vontade (ou me mande as posições marcadas). native = chão do GTA (ajuste automático ao solo).
DM.rankedModes = {
    {
        id = "m4_10x10", name = "10x10 M4", place = "Las Payasadas", teamSize = 10,
        weapons = { { 31, 600 } }, armor = 100, killTarget = 80, duration = 600, color = { 86, 180, 255 },
        center = { -250.0, 2620.0, 63.0 }, native = true,
        teamSpawns = {
            A = { { -205.0, 2592.0, 63.0, 90 }, { -208.0, 2598.0, 63.0, 90 }, { -211.0, 2604.0, 63.0, 90 }, { -205.0, 2610.0, 63.0, 90 }, { -209.0, 2616.0, 63.0, 90 },
                  { -202.0, 2586.0, 63.0, 90 }, { -214.0, 2590.0, 63.0, 90 }, { -214.0, 2610.0, 63.0, 90 }, { -200.0, 2602.0, 63.0, 90 }, { -206.0, 2622.0, 63.0, 90 } },
            B = { { -295.0, 2648.0, 63.0, 270 }, { -292.0, 2642.0, 63.0, 270 }, { -289.0, 2636.0, 63.0, 270 }, { -295.0, 2630.0, 63.0, 270 }, { -291.0, 2624.0, 63.0, 270 },
                  { -298.0, 2654.0, 63.0, 270 }, { -286.0, 2650.0, 63.0, 270 }, { -286.0, 2630.0, 63.0, 270 }, { -300.0, 2638.0, 63.0, 270 }, { -294.0, 2618.0, 63.0, 270 } },
        },
        warmupSpawns = { { -250.0, 2620.0, 63.0, 0 }, { -230.0, 2600.0, 63.0, 90 }, { -270.0, 2640.0, 63.0, 270 }, { -240.0, 2650.0, 63.0, 180 }, { -265.0, 2595.0, 63.0, 45 } },
    },
    {
        id = "sniper_5x5", name = "5x5 Sniper", place = "Bayside Trailer Park", teamSize = 5,
        weapons = { { 34, 150 } }, armor = 0, killTarget = 30, duration = 480, color = { 200, 110, 255 },
        center = { -2480.0, 2320.0, 5.0 }, native = true,
        teamSpawns = {
            A = { { -2530.0, 2360.0, 5.0, 135 }, { -2526.0, 2354.0, 5.0, 135 }, { -2534.0, 2354.0, 5.0, 135 }, { -2522.0, 2362.0, 5.0, 135 }, { -2538.0, 2362.0, 5.0, 135 } },
            B = { { -2430.0, 2280.0, 5.0, 315 }, { -2426.0, 2286.0, 5.0, 315 }, { -2434.0, 2286.0, 5.0, 315 }, { -2422.0, 2278.0, 5.0, 315 }, { -2438.0, 2278.0, 5.0, 315 } },
        },
        warmupSpawns = { { -2480.0, 2320.0, 5.0, 0 }, { -2500.0, 2340.0, 5.0, 90 }, { -2460.0, 2300.0, 5.0, 270 }, { -2470.0, 2345.0, 5.0, 180 } },
    },
    {
        id = "m4_5x5", name = "5x5 M4", place = "Bayside Trailer Park", teamSize = 5,
        weapons = { { 31, 600 } }, armor = 100, killTarget = 40, duration = 480, color = { 34, 211, 238 },
        center = { -2480.0, 2320.0, 5.0 }, native = true,
        teamSpawns = {
            A = { { -2530.0, 2360.0, 5.0, 135 }, { -2526.0, 2354.0, 5.0, 135 }, { -2534.0, 2354.0, 5.0, 135 }, { -2522.0, 2362.0, 5.0, 135 }, { -2538.0, 2362.0, 5.0, 135 } },
            B = { { -2430.0, 2280.0, 5.0, 315 }, { -2426.0, 2286.0, 5.0, 315 }, { -2434.0, 2286.0, 5.0, 315 }, { -2422.0, 2278.0, 5.0, 315 }, { -2438.0, 2278.0, 5.0, 315 } },
        },
        warmupSpawns = { { -2480.0, 2320.0, 5.0, 0 }, { -2500.0, 2340.0, 5.0, 90 }, { -2460.0, 2300.0, 5.0, 270 }, { -2470.0, 2345.0, 5.0, 180 } },
    },
}
DM.ranked = {
    countdown     = 15,    -- s entre completar os jogadores e começar
    resultsTime   = 12,    -- s mostrando o resultado
    respawn       = 4000,  -- ms respawn durante a partida
    protection    = 2000,  -- ms proteção ao nascer na partida
    dimensionBase = 2000,  -- cada instância usa dimensionBase + (índice do modo * 100) + nº da instância
    minClanMatch  = 2,     -- mínimo de jogadores por lado em clã x clã
}

-- CLÃS
DM.clans = {
    tagMin = 2, tagMax = 5, nameMin = 3, nameMax = 20, maxMembers = 30,
    pointsWin = 30, pointsLoss = -15,
}

-- Mensagens automáticas do servidor ({online} e {discord} são substituídos)
DM.broadcasts = {
    "#8B5CF6[UTG] #FFFFFF{online} jogadores online agora. Chame seus amigos!",
    "#8B5CF6[UTG] #FFFFFFPressione #22D3EEF5 #FFFFFFpara entrar nas partidas ranqueadas 5x5 e 10x10 e subir de elo.",
    "#8B5CF6[UTG] #FFFFFFKills dão #22E68A$ #FFFFFF— use na loja (#22D3EEF4#FFFFFF) para tags, VIP e cores de nick.",
    "#8B5CF6[UTG] #FFFFFFDesafie alguém no X1 com #22D3EEF3#FFFFFF. Vitórias no X1 dão RP.",
    "#8B5CF6[UTG] #FFFFFFCrie ou entre em um clã (#22D3EEF6#FFFFFF) e dispute clã x clã.",
    "#8B5CF6[UTG] #FFFFFFHeadshot vale mais: dano no peito é reduzido, mire na cabeça.",
    "#8B5CF6[UTG] #FFFFFFFique online: a cada 10 minutos você ganha bônus em $. Bônus diário no primeiro login do dia.",
    "#8B5CF6[UTG] #FFFFFFDiscord: #22D3EE{discord}",
}

-- Paleta de cores da interface (RGB). O cliente converte com tocolor().
DM.colors = {
    bg      = { 8, 8, 16 },
    card    = { 16, 16, 30 },
    card2   = { 24, 24, 44 },
    border  = { 255, 255, 255 },
    accent  = { 139, 92, 246 },  -- violeta UTG
    accent2 = { 34, 211, 238 },  -- ciano
    gold    = { 245, 196, 81 },  -- VIP
    success = { 34, 230, 138 },
    danger  = { 255, 77, 109 },
    warn    = { 255, 181, 71 },
    info    = { 86, 180, 255 },
    text    = { 245, 245, 250 },
    muted   = { 150, 155, 180 },
    health  = { 34, 230, 138 },
    armor   = { 34, 211, 238 },
    money   = { 245, 196, 81 },
}

-- Skins aleatórias ao nascer (o jogador pode trocar com /skin <id>)
DM.skins = { 7, 14, 15, 18, 21, 22, 23, 24, 25, 26, 28, 29, 30, 46, 47, 48, 57, 58, 60, 66, 67, 68, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 120, 121, 122, 123, 124, 125, 126, 127, 128, 170, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 206, 217, 223, 230, 240, 250, 258, 259, 261, 262, 264, 268, 270, 271, 272, 285, 286, 287, 288 }

-- Nomes das armas (PT-BR). Fallback: getWeaponNameFromID.
DM.weaponNames = {
    [0] = "Soco", [1] = "Soco Inglês", [2] = "Taco de Golfe", [3] = "Cassetete", [4] = "Faca",
    [5] = "Bastão", [6] = "Pá", [7] = "Taco de Sinuca", [8] = "Katana", [9] = "Serra Elétrica",
    [16] = "Granada", [17] = "Gás Lacrimogêneo", [18] = "Molotov",
    [22] = "Pistola", [23] = "Pistola Silenciada", [24] = "Deagle",
    [25] = "Shotgun", [26] = "Sawn-off", [27] = "Combat Shotgun",
    [28] = "Uzi", [29] = "MP5", [32] = "Tec-9",
    [30] = "AK-47", [31] = "M4", [33] = "Rifle", [34] = "Sniper",
    [35] = "RPG", [36] = "Heat Seeker", [37] = "Lança-chamas", [38] = "Minigun",
    [39] = "Satchel", [40] = "Detonador", [41] = "Spray", [42] = "Extintor", [43] = "Câmera",
    [49] = "Atropelamento", [50] = "Hélice", [51] = "Explosão", [53] = "Afogamento", [54] = "Queda",
    [55] = "Fogo", [56] = "Fogo", [57] = "Fogo", [59] = "Paraquedas", [63] = "Desconhecido",
}

function DM.weaponName(id)
    id = tonumber(id) or 0
    if DM.weaponNames[id] then return DM.weaponNames[id] end
    local n = getWeaponNameFromID(id)
    return n or "Desconhecido"
end

function DM.tierForRP(rp)
    rp = tonumber(rp) or 0
    local tier = DM.tiers[1]
    for _, t in ipairs(DM.tiers) do
        if rp >= t.min then tier = t end
    end
    return tier
end

function DM.nextTier(rp)
    for _, t in ipairs(DM.tiers) do
        if (tonumber(rp) or 0) < t.min then return t end
    end
    return nil
end

-- compatibilidade: "nível" exibido = índice do elo
function DM.levelFromXP(rp)
    local tier = DM.tierForRP(rp)
    for i, t in ipairs(DM.tiers) do if t == tier then return i end end
    return 1
end
function DM.rankForLevel(level)
    return DM.tiers[math.max(1, math.min(#DM.tiers, tonumber(level) or 1))]
end

function DM.formatMoney(v)
    v = math.floor(tonumber(v) or 0)
    local s = tostring(v)
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return "$" .. (out:gsub("^%.", ""))
end

function DM.vipName(level)
    local v = DM.vip[tonumber(level) or 0]
    return v and v.name or nil
end

-- Mensagens de sequência de kills
DM.streaks = {
    [3]  = { text = "está em SEQUÊNCIA!",   color = "#FFB547" },
    [5]  = { text = "está DOMINANDO!",      color = "#FF8C42" },
    [8]  = { text = "está IMPARÁVEL!",      color = "#FF4D6D" },
    [12] = { text = "está LENDÁRIO!",       color = "#C86EFF" },
    [20] = { text = "é um DEUS DA ARENA!",  color = "#00E5A8" },
}

--[[
    ARENAS
    ------
    id        : identificador usado em /arena <id>, nos mapas (dm_maps/maps/<id>.map) e no código
    dimension : cada arena vive em uma dimensão própria (jogadores de arenas diferentes não se veem)
    type      : "lobby" (zona segura), "ffa" (todos contra todos), "duel" (sala de espera do X1)
    weapons   : { {idArma, munição}, ... } — SOMENTE essas armas existem na arena
    spawns    : spawns padrão { x, y, z, rotação }. Se houver <spawnpoint> no .map da arena,
                os spawns do mapa substituem estes automaticamente.
    cbug      : true = script de C-Bug liberado nesta arena
    safe      : true = sem dano
]]
DM.arenas = {
    {
        id = "lobby", name = "Lobby", short = "LOBBY",
        desc = "Zona segura. F2 arenas · F3 duelo · F4 loja · F5 ranqueadas · F6 clã.",
        type = "lobby", safe = true, dimension = 0,
        color = { 0, 229, 168 }, weapons = {},
        spawns = {
            { 1544.9, -1675.6, 13.56, 90 }, { 1537.4, -1674.3, 13.56, 270 },
            { 1552.9, -1676.5, 13.56, 90 }, { 1545.1, -1668.5, 13.56, 180 },
            { 1545.7, -1684.1, 13.56, 0 },  { 1532.0, -1681.0, 13.56, 300 },
        },
    },
    {
        id = "ak47", name = "Arena AK-47", short = "AK-47",
        desc = "Somente AK-47. Mapa fechado em Las Venturas.",
        type = "ffa", dimension = 1, color = { 255, 120, 40 },
        weapons = { { 30, 500 } }, armor = 0,
        spawns = {
            { 1069.57, 1774.26, 10.82, 177.6 }, { 1087.76, 1775.06, 10.82, 126.8 },
            { 1031.23, 1774.39, 10.82, 250.5 }, { 1034.86, 1741.16, 10.82, 300.2 },
            { 1087.91, 1742.88, 10.82, 46.2 }, { 1104.42, 1760.47, 10.82, 89.1 },
            { 1039.59, 1780.91, 10.82, 235.9 }, { 1054.34, 1793.56, 10.82, 204.2 },
            { 1042.28, 1729.88, 10.82, 319.3 }, { 1029.28, 1776.29, 10.82, 248.9 },
            { 1105.21, 1758.00, 10.82, 85.3 },
        },
    },
    {
        id = "m4", name = "Arena M4", short = "M4",
        desc = "Somente M4. Base militar em Verdant Bluffs.",
        type = "ffa", dimension = 2, color = { 86, 180, 255 },
        weapons = { { 31, 500 } }, armor = 0,
        spawns = {
            { 1194.72, -2013.08, 69.27, 134.1 }, { 1187.98, -1998.14, 84.98, 155.2 },
            { 1157.54, -2037.52, 85.33, 272.4 }, { 1158.74, -2040.11, 68.42, 285.4 },
            { 1136.90, -2027.06, 68.58, 253.3 }, { 1137.09, -2046.56, 68.51, 286.2 },
            { 1141.83, -2033.94, 68.40, 263.8 }, { 1136.96, -2012.74, 68.40, 233.7 },
            { 1137.09, -2061.14, 68.49, 306.3 }, { 1203.14, -2039.93, 68.55, 84.9 },
            { 1186.95, -2034.02, 68.40, 100.0 },
        },
    },
    {
        id = "x1", name = "Arena X1", short = "X1",
        desc = "Duelos 1v1 em sala privada. Pressione F3 para desafiar.",
        type = "duel", safe = true, dimension = 3, color = { 124, 92, 255 },
        weapons = {},
        spawns = {
            { -1356.42, -924.23, 992.40, 200.0 }, { -1390.00, -981.00, 992.40, 310.6 },
            { -1338.00, -923.00, 992.40, 144.8 }, { -1400.00, -919.00, 992.40, 225.0 },
            { -1350.00, -989.00, 992.40, 20.6 }, { -1370.00, -947.00, 992.40, 218.7 },
            { -1400.00, -951.00, 992.40, 261.0 }, { -1368.00, -975.00, 992.40, 341.6 },
            { -1374.00, -995.00, 992.40, 342.5 },
        },
        -- pares de posições para os duelos (um par por rodada, escolhido aleatoriamente)
        duelSpots = {
            { { -1390.00, -981.00, 992.40, 324.5 }, { -1370.00, -953.00, 992.40, 144.5 } },
            { { -1400.00, -923.00, 992.40, 226.8 }, { -1368.00, -953.00, 992.40, 46.8 } },
            { { -1400.00, -919.00, 992.40, 220.2 }, { -1378.00, -945.00, 992.40, 40.2 } },
            { { -1400.00, -971.00, 992.40, 299.4 }, { -1368.00, -953.00, 992.40, 119.4 } },
        },
    },
    {
        id = "cbug", name = "Arena C-Bug", short = "C-BUG",
        desc = "Deagle, Shotgun e Sniper. C-Bug LIBERADO somente aqui.",
        type = "ffa", dimension = 4, color = { 255, 77, 109 }, cbug = true,
        weapons = { { 24, 500 }, { 25, 500 }, { 34, 200 } }, armor = 0,
        spawns = {
            { -3770.16, 1893.17, 6.97, 180.0 }, { -3750.00, 1839.00, 7.00, 252.3 },
            { -3684.00, 1773.00, 7.00, 36.7 }, { -3684.00, 1891.00, 7.00, 143.3 },
            { -3770.00, 1773.00, 7.00, 324.6 }, { -3688.00, 1827.00, 7.00, 82.9 },
            { -3738.00, 1891.00, 7.00, 189.6 }, { -3726.00, 1797.00, 7.00, 3.3 },
            { -3712.00, 1859.00, 7.00, 149.3 }, { -3770.00, 1871.00, 7.00, 227.1 },
            { -3770.00, 1809.00, 7.00, 298.7 },
        },
    },
    {
        id = "deagle", name = "Arena Deagle", short = "DEAGLE",
        desc = "Somente Deagle. Cada tiro conta.",
        type = "ffa", dimension = 5, color = { 255, 181, 71 },
        weapons = { { 24, 500 } }, armor = 0,
        spawns = {
            { -1935.5, 239.5, 34.3, 90 },  { -1960.0, 260.0, 34.3, 180 },
            { -1910.0, 220.0, 34.3, 0 },   { -1945.0, 280.0, 34.3, 270 },
            { -1980.0, 230.0, 34.3, 45 },  { -1920.0, 300.0, 34.3, 315 },
        },
    },
    {
        id = "sniper", name = "Arena Sniper", short = "SNIPER",
        desc = "Somente Sniper. Um tiro, uma morte.",
        type = "ffa", dimension = 6, color = { 200, 110, 255 },
        weapons = { { 34, 200 } }, armor = 0,
        spawns = {
            { 420.0, 2500.0, 16.5, 90 },  { 380.0, 2530.0, 16.5, 180 },
            { 460.0, 2470.0, 16.5, 0 },   { 340.0, 2480.0, 16.5, 270 },
            { 480.0, 2540.0, 16.5, 45 },  { 400.0, 2440.0, 16.5, 315 },
        },
    },
    {
        id = "shotgun", name = "Arena Shotgun", short = "SHOTGUN",
        desc = "Somente Combat Shotgun. Combate aproximado.",
        type = "ffa", dimension = 7, color = { 255, 140, 66 },
        weapons = { { 27, 300 } }, armor = 0,
        spawns = {
            { 1740.0, -1860.0, 13.5, 90 },  { 1770.0, -1880.0, 13.5, 180 },
            { 1710.0, -1840.0, 13.5, 0 },   { 1760.0, -1830.0, 13.5, 270 },
            { 1720.0, -1890.0, 13.5, 45 },  { 1790.0, -1850.0, 13.5, 315 },
        },
    },
    {
        id = "melee", name = "Arena Katana", short = "KATANA",
        desc = "Somente Katana. Sem armas de fogo.",
        type = "ffa", dimension = 8, color = { 192, 198, 210 },
        weapons = { { 8, 1 } }, armor = 0,
        spawns = {
            { 370.0, -2040.0, 7.8, 90 },  { 340.0, -2060.0, 7.8, 180 },
            { 400.0, -2020.0, 7.8, 0 },   { 360.0, -2000.0, 7.8, 270 },
            { 330.0, -2020.0, 7.8, 45 },  { 410.0, -2060.0, 7.8, 315 },
        },
    },
    {
        id = "livre", name = "Arena Livre", short = "LIVRE",
        desc = "Todas as armas clássicas. Caos total.",
        type = "ffa", dimension = 9, color = { 0, 229, 168 },
        weapons = { { 24, 300 }, { 25, 200 }, { 29, 400 }, { 30, 400 }, { 31, 400 }, { 34, 100 } }, armor = 50,
        spawns = {
            { 215.0, 1860.0, 17.65, 90 },  { 250.0, 1880.0, 17.65, 180 },
            { 190.0, 1830.0, 17.65, 0 },   { 240.0, 1820.0, 17.65, 270 },
            { 270.0, 1850.0, 17.65, 45 },  { 200.0, 1900.0, 17.65, 315 },
        },
    },
}

-- Conjuntos de armas disponíveis no painel de duelo (F3)
DM.duelWeapons = {
    { key = "deagle",   name = "Deagle",         weapons = { { 24, 200 } } },
    { key = "shotgun",  name = "Shotgun",        weapons = { { 25, 200 } } },
    { key = "combat",   name = "Combat Shotgun", weapons = { { 27, 200 } } },
    { key = "sawnoff",  name = "Sawn-off",       weapons = { { 26, 200 } } },
    { key = "mp5",      name = "MP5",            weapons = { { 29, 400 } } },
    { key = "ak47",     name = "AK-47",          weapons = { { 30, 400 } } },
    { key = "m4",       name = "M4",             weapons = { { 31, 400 } } },
    { key = "rifle",    name = "Rifle",          weapons = { { 33, 100 } } },
    { key = "sniper",   name = "Sniper",         weapons = { { 34, 100 } } },
    { key = "katana",   name = "Katana",         weapons = { { 8, 1 } } },
    { key = "fists",    name = "Soco",           weapons = {} },
    { key = "classic",  name = "Clássico (D+S+S)", weapons = { { 24, 200 }, { 25, 200 }, { 34, 60 } } },
}

DM.duelRounds = { 1, 3, 5 }   -- "primeiro a N"

-- Índices auxiliares
DM.arenaById = {}
for i, arena in ipairs(DM.arenas) do
    arena.index = i
    arena.native = arena.native ~= false and (arena.id == "lobby" or arena.id == "ak47" or arena.id == "m4" or arena.id == "deagle" or arena.id == "sniper" or arena.id == "shotgun" or arena.id == "melee" or arena.id == "livre")
    DM.arenaById[arena.id] = arena
end

-- Modos ranqueados também são "arenas" (type = "ranked"), geridas pelo dm_ranked
DM.rankedById = {}
for i, mode in ipairs(DM.rankedModes) do
    mode.index = i
    mode.type = "ranked"
    mode.short = mode.name:upper()
    mode.desc = ("%s · %s · partida ranqueada"):format(mode.name, mode.place)
    mode.dimension = DM.ranked.dimensionBase + i * 100
    mode.spawns = mode.warmupSpawns
    mode.safe = false
    DM.rankedById[mode.id] = mode
    DM.arenaById[mode.id] = mode
end

function DM.getArena(id)
    return DM.arenaById[id]
end

function DM.getDuelWeaponSet(key)
    for _, set in ipairs(DM.duelWeapons) do
        if set.key == key then return set end
    end
    return nil
end

-- Lista legível das armas de uma arena
function DM.arenaWeaponList(arena)
    if not arena or #(arena.weapons or {}) == 0 then
        if arena and arena.type == "duel" then return "Arma escolhida no duelo" end
        return "Sem armas"
    end
    local names = {}
    for _, w in ipairs(arena.weapons) do
        names[#names + 1] = DM.weaponName(w[1])
    end
    return table.concat(names, " · ")
end

-- Remove códigos de cor #RRGGBB
function DM.stripColors(text)
    return (tostring(text or ""):gsub("#%x%x%x%x%x%x", ""))
end

function DM.rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end
