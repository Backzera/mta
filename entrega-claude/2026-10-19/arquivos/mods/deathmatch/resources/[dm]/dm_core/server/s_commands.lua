--[[
    Comandos de jogador e de administração.
]]

local function usage(player, text)
    sendServerMessage(player, "Uso: #8B93A7" .. text)
end

local function requireReady(player)
    if not getElementData(player, "dm:ready") then
        notifyPlayer(player, "Faça login primeiro.", "warn")
        return false
    end
    return true
end

local function requireAdmin(player)
    if not isPlayerAdmin(player) then
        notifyPlayer(player, "Você não tem permissão para isso.", "error")
        return false
    end
    return true
end

local function resolveArena(text)
    if not text then return nil end
    text = text:lower()
    if DM.getArena(text) then return DM.getArena(text) end
    for _, a in ipairs(DM.arenas) do
        if a.name:lower():find(text, 1, true) or a.short:lower():find(text, 1, true) then return a end
    end
    return nil
end

-- /arena <id>
addCommandHandler("arena", function(player, cmd, id)
    if not requireReady(player) then return end
    local arena = resolveArena(id)
    if not arena then
        usage(player, "/arena <nome>  #8B93A7— arenas: " .. table.concat((function()
            local t = {} for _, a in ipairs(DM.arenas) do t[#t + 1] = a.id end return t end)(), ", "))
        return
    end
    setPlayerArena(player, arena.id)
end)

addCommandHandler("arenas", function(player)
    sendServerMessage(player, "Arenas disponíveis:")
    for _, a in ipairs(DM.arenas) do
        outputChatBox(("  %s%-8s #FFFFFF%-16s #8B93A7%s  (%d online)"):format(DM.rgbToHex(unpack(a.color)), a.id, a.name, DM.arenaWeaponList(a), #getArenaPlayers(a.id)), player, 255, 255, 255, true)
    end
end)

addCommandHandler("lobby", function(player)
    if not requireReady(player) then return end
    setPlayerArena(player, "lobby")
end)

addCommandHandler("x1", function(player)
    if not requireReady(player) then return end
    setPlayerArena(player, "x1")
end)

addCommandHandler("kill", function(player)
    if not requireReady(player) then return end
    if isPedDead(player) then return end
    local arena = getPlayerArena(player)
    if arena and arena.safe then
        notifyPlayer(player, "Você está em uma zona segura.", "warn")
        return
    end
    killPed(player)
end)

addCommandHandler("skin", function(player, cmd, id)
    id = tonumber(id)
    if not id or id < 0 or id > 311 or id == 0 then usage(player, "/skin <0-311>") return end
    if not (isPlayerVip(player) > 0 or playerHasPerk(player, "skins")) then
        local allowed = false
        for _, s in ipairs(DM.skins) do if s == id then allowed = true break end end
        if not allowed then
            notifyPlayer(player, "Essa skin é exclusiva. Compre o pacote de skins na loja (F4) ou seja VIP.", "warn")
            return
        end
    end
    setElementData(player, "dm:skin", id)
    setPlayerStat(player, "equip_skin", id)
    if not isPedDead(player) then setElementModel(player, id) end
    notifyPlayer(player, "Skin alterada para " .. id .. ".", "success")
end)

-- /stats [jogador]
addCommandHandler("stats", function(player, cmd, target)
    local who = player
    if target then
        who = findPlayer(target)
        if not who then notifyPlayer(player, "Jogador não encontrado.", "error") return end
    end
    local s = getPlayerStats(who)
    if not s then notifyPlayer(player, "Stats ainda não carregadas.", "warn") return end
    local tier = DM.tierForRP(s.rp)
    local kd = s.deaths > 0 and s.kills / s.deaths or s.kills
    sendServerMessage(player, ("Stats de #FFFFFF%s #969BB4— elo %s%s #969BB4(%d RP)  saldo #F5C451%s"):format(getPlayerVisibleName(who), DM.rgbToHex(unpack(tier.color)), tier.name, s.rp, DM.formatMoney(s.money)))
    outputChatBox(("  #969BB4Kills: #FFFFFF%d  #969BB4Mortes: #FFFFFF%d  #969BB4K/D: #FFFFFF%.2f  #969BB4Headshots: #FFFFFF%d  #969BB4Maior seq.: #FFFFFF%d"):format(s.kills, s.deaths, kd, s.headshots, s.best_streak), player, 255, 255, 255, true)
    outputChatBox(("  #969BB4Duelos: #22E68A%dV #FF4D6D%dD  #969BB4Ranqueadas: #22E68A%dV #FF4D6D%dD #969BB4(%d kills)  #969BB4Tempo: #FFFFFF%dh%02dm"):format(
        s.duels_won, s.duels_lost, s.ranked_wins, s.ranked_losses, s.ranked_kills, math.floor(s.playtime / 3600), math.floor(s.playtime % 3600 / 60)), player, 255, 255, 255, true)
end)

-- /top [rp|kills|money|duelos]
addCommandHandler("top", function(player, cmd, what)
    local fields = { rp = "rp", kills = "kills", money = "money", dinheiro = "money", duelos = "duels_won", x1 = "duels_won" }
    local field = fields[(what or "rp"):lower()] or "rp"
    local titles = { rp = "TOP 10 — elo (RP)", kills = "TOP 10 — kills", money = "TOP 10 — mais ricos", duels_won = "TOP 10 — duelos X1" }
    getTopPlayers(field, 10, function(rows)
        if not isElement(player) then return end
        sendServerMessage(player, titles[field] .. "  #969BB4(/top rp|kills|money|duelos)")
        for i, r in ipairs(rows) do
            local tier = DM.tierForRP(tonumber(r.rp) or 0)
            outputChatBox(("  #FFB547#%d #FFFFFF%-20s %s%s #969BB4%d RP  kills #FFFFFF%d  #969BB4$ #F5C451%s  #969BB4X1 #FFFFFF%dV"):format(
                i, r.name, DM.rgbToHex(unpack(tier.color)), tier.name, tonumber(r.rp) or 0, tonumber(r.kills) or 0, DM.formatMoney(r.money), tonumber(r.duels_won) or 0), player, 255, 255, 255, true)
        end
    end)
end)

addCommandHandler("ajuda", function(player)
    triggerClientEvent(player, "dm:toggleHelp", resourceRoot)
end)

-- ======================= ADMIN =======================

local function targetAndReason(player, target, ...)
    local other, count = findPlayer(target)
    if not other then
        notifyPlayer(player, count and count > 1 and "Vários jogadores com esse nome." or "Jogador não encontrado.", "error")
        return nil
    end
    local reason = table.concat({ ... }, " ")
    if reason == "" then reason = "Sem motivo" end
    return other, reason
end

addCommandHandler("kick", function(player, cmd, target, ...)
    if not requireAdmin(player) then return end
    if not target then usage(player, "/kick <jogador> [motivo]") return end
    local other, reason = targetAndReason(player, target, ...)
    if not other then return end
    sendServerMessage(root, ("#FFFFFF%s #8B93A7foi expulso por #FFFFFF%s#8B93A7. Motivo: %s"):format(getPlayerVisibleName(other), getPlayerVisibleName(player), reason))
    kickPlayer(other, player, reason)
end)

addCommandHandler("ban", function(player, cmd, target, ...)
    if not requireAdmin(player) then return end
    if not target then usage(player, "/ban <jogador> [motivo]") return end
    local other, reason = targetAndReason(player, target, ...)
    if not other then return end
    sendServerMessage(root, ("#FFFFFF%s #8B93A7foi banido por #FFFFFF%s#8B93A7. Motivo: %s"):format(getPlayerVisibleName(other), getPlayerVisibleName(player), reason))
    banPlayer(other, false, false, true, player, reason)
end)

addCommandHandler("mute", function(player, cmd, target, minutes)
    if not requireAdmin(player) then return end
    if not target then usage(player, "/mute <jogador> [minutos]") return end
    local other = targetAndReason(player, target)
    if not other then return end
    minutes = math.max(1, math.floor(tonumber(minutes) or 5))
    setElementData(other, "dm:muted", true)
    setTimer(function()
        if isElement(other) then
            setElementData(other, "dm:muted", false)
            notifyPlayer(other, "Seu mute acabou.", "info")
        end
    end, minutes * 60000, 1)
    sendServerMessage(root, ("#FFFFFF%s #8B93A7foi mutado por #FFFFFF%s #8B93A7(%d min)"):format(getPlayerVisibleName(other), getPlayerVisibleName(player), minutes))
end)

addCommandHandler("unmute", function(player, cmd, target)
    if not requireAdmin(player) then return end
    if not target then usage(player, "/unmute <jogador>") return end
    local other = targetAndReason(player, target)
    if not other then return end
    setElementData(other, "dm:muted", false)
    notifyPlayer(other, "Você foi desmutado.", "info")
    notifyPlayer(player, "Jogador desmutado.", "success")
end)

-- /tp <jogador> [arena] : move o jogador para uma arena (padrão: a sua)
addCommandHandler("tp", function(player, cmd, target, arenaId)
    if not requireAdmin(player) then return end
    if not target then usage(player, "/tp <jogador> [arena]") return end
    local other = targetAndReason(player, target)
    if not other then return end
    local arena = arenaId and resolveArena(arenaId) or getPlayerArena(player)
    if not arena then notifyPlayer(player, "Arena inválida.", "error") return end
    setPlayerArena(other, arena.id)
    notifyPlayer(player, ("%s movido para %s."):format(getPlayerVisibleName(other), arena.name), "success")
end)

addCommandHandler("anuncio", function(player, cmd, ...)
    if not requireAdmin(player) then return end
    local text = table.concat({ ... }, " ")
    if text == "" then usage(player, "/anuncio <mensagem>") return end
    outputChatBox(("#FF4D6D♛ ANÚNCIO #8FA39A» #FFFFFF%s"):format(DM.stripColors(text)), root, 255, 255, 255, true)
    triggerClientEvent(root, "dm:notify", resourceRoot, DM.stripColors(text), "warn", "Anúncio")
end)

addCommandHandler("admins", function(player)
    local list = {}
    for _, p in ipairs(getElementsByType("player")) do
        if isPlayerAdmin(p) then list[#list + 1] = getPlayerVisibleName(p) end
    end
    sendServerMessage(player, #list > 0 and ("Admins online: #FFFFFF" .. table.concat(list, ", ")) or "Nenhum admin online.")
end)
