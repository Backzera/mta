--[[
    Chat: formatação com nível/rank, anti-flood, mute, /pm
]]

local lastChat = {}


addEventHandler("onPlayerChat", root, function(message, messageType)
    if messageType == 2 then return end -- team chat (não usado)
    cancelEvent()

    if getElementData(source, "dm:muted") then
        notifyPlayer(source, "Você está mutado.", "error")
        return
    end
    local now = getTickCount()
    if lastChat[source] and now - lastChat[source] < DM.server.chatCooldown then
        notifyPlayer(source, "Calma! Você está digitando rápido demais.", "warn")
        return
    end
    lastChat[source] = now

    message = DM.stripColors(message):gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then return end
    if #message > 160 then message = message:sub(1, 160) end

    local name = getPlayerVisibleName(source)

    if messageType == 1 then
        -- /me
        outputChatBox(("#C86EFF* %s %s"):format(name, message), root, 255, 255, 255, true)
        outputServerLog(("ME: %s %s"):format(name, message))
        return
    end

    local line = ("%s#FFFFFF: #E6E9F0%s"):format(formatPlayerName(source), message)
    outputChatBox(line, root, 255, 255, 255, true)
    outputServerLog(("CHAT: %s: %s"):format(name, message))
end)

addEventHandler("onPlayerQuit", root, function() lastChat[source] = nil end)

-- Mensagem privada
addCommandHandler("pm", function(player, cmd, target, ...)
    local text = table.concat({ ... }, " ")
    if not target or text == "" then
        sendServerMessage(player, "Uso: #8B93A7/pm <jogador> <mensagem>")
        return
    end
    local other, count = findPlayer(target)
    if not other then
        notifyPlayer(player, count and count > 1 and "Vários jogadores com esse nome." or "Jogador não encontrado.", "error")
        return
    end
    if other == player then notifyPlayer(player, "Você não pode enviar PM para si mesmo.", "warn") return end
    text = DM.stripColors(text):sub(1, 160)
    outputChatBox(("#22E68A[PM para %s] #E6E9F0%s"):format(getPlayerVisibleName(other), text), player, 255, 255, 255, true)
    outputChatBox(("#22E68A[PM de %s] #E6E9F0%s"):format(getPlayerVisibleName(player), text), other, 255, 255, 255, true)
    triggerClientEvent(other, "dm:notify", resourceRoot, text, "info", "PM de " .. getPlayerVisibleName(player))
end)
