--[[
    Chat moderno: canais coloridos com ícones, ID do jogador, tag/clã/elo com glifos, emojis por atalho.
      Global (padrão)     ✿ Global » ★ ✦ [1042] [UTG] Nick » mensagem
      /a <msg>            ▲ Arena  — só quem está na mesma arena/dimensão
      /c <msg>            ◆ Clã    — só membros do clã
      /pm <id|nome> <msg> ✉ PM
      /staff <msg>        ♛ Staff  — só staff
      /emojis             lista de atalhos (:skull: ☠ etc.)
    Também: entrada/saída de jogadores com ID.
]]

local lastChat = {}

-- Substitui atalhos :nome: por glifos
function applyEmojis(text)
    return (tostring(text):gsub(":[%w_]+:", function(code)
        return DM.chat.emojis[code:lower()] or code
    end))
end

local function cleanMessage(message)
    message = DM.stripColors(message):gsub("^%s+", ""):gsub("%s+$", "")
    if #message > 160 then message = message:sub(1, 160) end
    return applyEmojis(message)
end

local function canChat(player)
    if getElementData(player, "dm:muted") then
        notifyPlayer(player, "Você está mutado.", "error")
        return false
    end
    local now = getTickCount()
    if lastChat[player] and now - lastChat[player] < DM.server.chatCooldown then
        notifyPlayer(player, "Calma! Você está digitando rápido demais.", "warn")
        return false
    end
    lastChat[player] = now
    return true
end

local function channelPrefix(key)
    local ch = DM.chat.channels[key] or DM.chat.channels.global
    return ("%s%s %s "):format(ch.color, ch.glyph, ch.label)
end

local function buildLine(channelKey, player, message)
    return ("%s%s %s %s%s"):format(channelPrefix(channelKey), formatPlayerName(player), DM.chat.sep, getPlayerMessageColor(player), message)
end

-- Global e /me
addEventHandler("onPlayerChat", root, function(message, messageType)
    if messageType == 2 then return end
    cancelEvent()
    if not canChat(source) then return end
    message = cleanMessage(message)
    if message == "" then return end
    local name = getPlayerVisibleName(source)
    if messageType == 1 then
        outputChatBox(("#C86EFF✦ #FFFFFF%s #E6EEE9%s"):format(name, message), root, 255, 255, 255, true)
        outputServerLog(("ME: %s %s"):format(name, message))
        return
    end
    outputChatBox(buildLine("global", source, message), root, 255, 255, 255, true)
    outputServerLog(("CHAT: %s: %s"):format(name, message))
end)

-- /a — chat da arena
addCommandHandler("a", function(player, cmd, ...)
    local message = table.concat({ ... }, " ")
    if message == "" then sendServerMessage(player, "Uso: #969BB4/a <mensagem> #8FA39A(chat da arena)") return end
    if not canChat(player) then return end
    message = cleanMessage(message)
    local arena = getPlayerArena(player)
    if not arena then return end
    local line = buildLine("arena", player, message)
    for _, p in ipairs(getArenaPlayers(arena.id, getElementDimension(player))) do
        outputChatBox(line, p, 255, 255, 255, true)
    end
    outputServerLog(("ARENA %s: %s: %s"):format(arena.id, getPlayerVisibleName(player), message))
end)

-- /c — chat do clã
addCommandHandler("c", function(player, cmd, ...)
    local message = table.concat({ ... }, " ")
    if message == "" then sendServerMessage(player, "Uso: #969BB4/c <mensagem> #8FA39A(chat do clã)") return end
    local row = getPlayerStats(player)
    if not row or not row.clan_id or row.clan_id == 0 then notifyPlayer(player, "Você não está em um clã.", "warn") return end
    if not canChat(player) then return end
    message = cleanMessage(message)
    local line = buildLine("clan", player, message)
    for _, p in ipairs(getElementsByType("player")) do
        local r = getPlayerStats(p)
        if r and r.clan_id == row.clan_id then outputChatBox(line, p, 255, 255, 255, true) end
    end
end)

-- /staff — chat da equipe
addCommandHandler("staff", function(player, cmd, ...)
    if not isPlayerStaff(player) then return end
    local message = table.concat({ ... }, " ")
    if message == "" then return end
    message = cleanMessage(message)
    local line = buildLine("staff", player, message)
    for _, p in ipairs(getElementsByType("player")) do
        if isPlayerStaff(p) then outputChatBox(line, p, 255, 255, 255, true) end
    end
end)

-- /pm <id|nome> <mensagem>
addCommandHandler("pm", function(player, cmd, target, ...)
    local text = table.concat({ ... }, " ")
    if not target or text == "" then
        sendServerMessage(player, "Uso: #969BB4/pm <id ou nome> <mensagem>")
        return
    end
    local other, count = findPlayer(target)
    if not other then
        notifyPlayer(player, count and count > 1 and "Vários jogadores com esse nome. Use o ID." or "Jogador não encontrado.", "error")
        return
    end
    if other == player then notifyPlayer(player, "Você não pode enviar PM para si mesmo.", "warn") return end
    if not canChat(player) then return end
    text = cleanMessage(text)
    local ch = DM.chat.channels.pm
    local myId, otherId = getElementData(player, "dm:id") or 0, getElementData(other, "dm:id") or 0
    outputChatBox(("%s%s PM para #FFFFFF%s %s[%d] %s %s%s"):format(ch.color, ch.glyph, getPlayerVisibleName(other), DM.chat.idColor, otherId, DM.chat.sep, "#FFE6FA", text), player, 255, 255, 255, true)
    outputChatBox(("%s%s PM de #FFFFFF%s %s[%d] %s %s%s"):format(ch.color, ch.glyph, getPlayerVisibleName(player), DM.chat.idColor, myId, DM.chat.sep, "#FFE6FA", text), other, 255, 255, 255, true)
    triggerClientEvent(other, "dm:notify", resourceRoot, text, "info", "PM de " .. getPlayerVisibleName(player))
end)

-- /id — mostra o seu ID
addCommandHandler("id", function(player, cmd, target)
    local who = player
    if target then who = findPlayer(target) end
    if not who then notifyPlayer(player, "Jogador não encontrado.", "error") return end
    sendServerMessage(player, ("ID de #FFFFFF%s#FFFFFF: #7CFFB2%d"):format(getPlayerVisibleName(who), getElementData(who, "dm:id") or 0))
end)

-- /emojis — lista de atalhos
addCommandHandler("emojis", function(player)
    sendServerMessage(player, "Emojis do chat (digite o atalho na mensagem):")
    local items, seen = {}, {}
    for code, glyph in pairs(DM.chat.emojis) do
        if not seen[glyph] then
            seen[glyph] = true
            items[#items + 1] = ("#7CFFB2%s #FFFFFF%s"):format(code, glyph)
        end
    end
    table.sort(items)
    local line = {}
    for i, item in ipairs(items) do
        line[#line + 1] = item
        if #line == 6 or i == #items then
            outputChatBox("  " .. table.concat(line, "  "), player, 255, 255, 255, true)
            line = {}
        end
    end
end)

-- Entrada / saída
addEventHandler("dm:onStatsLoaded", root, function(isNew)
    local player = source
    if getElementData(player, "dm:welcomed") then return end
    setElementData(player, "dm:welcomed", true, false)
    local id = getElementData(player, "dm:id") or 0
    outputChatBox(("#22E68A» #FFFFFF%s %s[%d] #8FA39A%s"):format(getPlayerVisibleName(player), DM.chat.idColor, id,
        isNew and "entrou pela primeira vez no servidor ✿ deem as boas-vindas!" or "entrou no servidor"), root, 255, 255, 255, true)
end)

addEventHandler("onPlayerQuit", root, function(reason)
    lastChat[source] = nil
    if not getElementData(source, "dm:ready") then return end
    local id = getElementData(source, "dm:id") or 0
    outputChatBox(("#FF4D6D« #FFFFFF%s %s[%d] #8FA39Asaiu (%s)"):format(getPlayerVisibleName(source), DM.chat.idColor, id, reason or "saiu"), root, 255, 255, 255, true)
end)

addEventHandler("onPlayerChangeNick", root, function(oldNick, newNick)
    outputChatBox(("#8FA39A✦ #FFFFFF%s #8FA39Aagora se chama #FFFFFF%s"):format(DM.stripColors(oldNick), DM.stripColors(newNick)), root, 255, 255, 255, true)
end)
