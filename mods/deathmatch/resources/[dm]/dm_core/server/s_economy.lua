--[[
    Economia: bônus diário, bônus por tempo online, mensagens automáticas, comandos de $.
]]

local playtimeTimers = {}

local function today()
    local t = getRealTime()
    return t.year * 10000 + t.month * 100 + t.monthday
end

-- Bônus diário + timer de tempo online quando as stats carregam
addEventHandler("dm:onStatsLoaded", root, function()
    local player = source
    local row = getPlayerStats(player)
    if not row then return end
    local d = today()
    if row.daily_last ~= d then
        row.daily_last = d
        local vip = isPlayerVip(player)
        local amount = vip > 0 and DM.vip[vip].daily or DM.economy.dailyBonus
        addMoney(player, amount, "Bônus diário", true)
        notifyPlayer(player, ("Bônus diário: %s. Volte amanhã para mais!"):format(DM.formatMoney(amount)), "success", "Bem-vindo de volta")
    end
    if playtimeTimers[player] and isTimer(playtimeTimers[player]) then killTimer(playtimeTimers[player]) end
    playtimeTimers[player] = setTimer(function()
        if not isElement(player) then return end
        local ok, amount = addMoney(player, DM.economy.playtimeBonus, "Tempo online")
        if ok then notifyPlayer(player, ("+%s por ficar online. Continue jogando!"):format(DM.formatMoney(amount)), "success", "Bônus de tempo") end
    end, DM.economy.playtimeEvery, 0)
end)

addEventHandler("onPlayerQuit", root, function()
    if playtimeTimers[source] and isTimer(playtimeTimers[source]) then killTimer(playtimeTimers[source]) end
    playtimeTimers[source] = nil
end)

-- Mensagens automáticas
local broadcastIndex = 0
addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(function()
        if #DM.broadcasts == 0 then return end
        broadcastIndex = (broadcastIndex % #DM.broadcasts) + 1
        local msg = DM.broadcasts[broadcastIndex]
        msg = msg:gsub("{online}", tostring(#getElementsByType("player"))):gsub("{discord}", DM.server.discord or "")
        outputChatBox(msg, root, 255, 255, 255, true)
    end, DM.server.broadcastEvery, 0)
end)

-- Comandos
addCommandHandler("saldo", function(player)
    sendServerMessage(player, ("Seu saldo: #F5C451%s"):format(DM.formatMoney(getPlayerMoney(player))))
end)

addCommandHandler("pagar", function(player, cmd, target, amount)
    amount = math.floor(tonumber(amount) or 0)
    if not target or amount < 100 then
        sendServerMessage(player, "Uso: #969BB4/pagar <jogador> <valor>  (mínimo $100)")
        return
    end
    local other = findPlayer(target)
    if not other or other == player then notifyPlayer(player, "Jogador inválido.", "error") return end
    if not getPlayerStats(other) then notifyPlayer(player, "Esse jogador ainda não carregou.", "warn") return end
    if not takeMoney(player, amount) then notifyPlayer(player, "Saldo insuficiente.", "error") return end
    addMoney(other, amount, "Transferência de " .. getPlayerVisibleName(player), true)
    notifyPlayer(player, ("Você enviou %s para %s."):format(DM.formatMoney(amount), getPlayerVisibleName(other)), "success")
    notifyPlayer(other, ("%s te enviou %s."):format(getPlayerVisibleName(player), DM.formatMoney(amount)), "success", "Transferência")
end)

-- Admin: /dar <jogador> <valor>, /setvip <jogador> <0-3> [dias], /darrp <jogador> <valor>
addCommandHandler("dar", function(player, cmd, target, amount)
    if not isPlayerAdmin(player) then return end
    local other = target and findPlayer(target)
    amount = tonumber(amount)
    if not other or not amount then sendServerMessage(player, "Uso: #969BB4/dar <jogador> <valor>") return end
    addMoney(other, amount, "Admin", true)
    notifyPlayer(player, ("%s recebeu %s."):format(getPlayerVisibleName(other), DM.formatMoney(amount)), "success")
end)

addCommandHandler("setvip", function(player, cmd, target, level, days)
    if not isPlayerAdmin(player) then return end
    local other = target and findPlayer(target)
    level = tonumber(level)
    if not other or not level then sendServerMessage(player, "Uso: #969BB4/setvip <jogador> <0-3> [dias]") return end
    setPlayerVip(other, level, tonumber(days) or 30)
    local name = DM.vipName(level) or "sem VIP"
    notifyPlayer(other, ("Seu VIP agora é: %s"):format(name), "success", "VIP")
    notifyPlayer(player, ("%s: %s"):format(getPlayerVisibleName(other), name), "success")
end)

addCommandHandler("darrp", function(player, cmd, target, amount)
    if not isPlayerAdmin(player) then return end
    local other = target and findPlayer(target)
    amount = tonumber(amount)
    if not other or not amount then sendServerMessage(player, "Uso: #969BB4/darrp <jogador> <valor>") return end
    addPlayerStat(other, "rp", amount)
    notifyPlayer(player, ("%s recebeu %d RP."):format(getPlayerVisibleName(other), amount), "success")
end)
