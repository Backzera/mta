-- Alerta do anti-cheat na tela do admin: toast vermelho + som. Só admins recebem este evento.
addEvent("ac:alert", true)
addEventHandler("ac:alert", resourceRoot, function(kind, text, suspect)
    local ui = getResourceFromName("dm_ui")
    if ui and getResourceState(ui) == "running" then
        exports.dm_ui:notify(text, "error", "ANTI-CHEAT · " .. kind)
    else
        outputChatBox("[ANTI-CHEAT " .. kind .. "] " .. text, 255, 77, 109)
    end
    playSoundFrontEnd(16)
end)
