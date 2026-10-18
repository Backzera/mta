--[[
    Ponte para a interface CEF (dm_ui). Mantém os exports antigos do dm_core (notify, isPanelOpen)
    funcionando: outros recursos chamam exports.dm_core:notify(...) e o toast aparece no HUD em HTML.
    O HUD do GTA é escondido aqui para o caso do dm_ui ainda não ter subido.
]]
addEventHandler("onClientResourceStart", resourceRoot, function()
    setPlayerHudComponentVisible("all", false)
    setPlayerHudComponentVisible("crosshair", true)
    showChat(true)
end)
addEventHandler("onClientResourceStop", resourceRoot, function()
    setPlayerHudComponentVisible("all", true)
    showCursor(false)
end)

function notify(text, ntype, title)
    triggerEvent("ui:notify", localPlayer, text, ntype, title)
end
addEvent("ui:notify")
addEvent("dm:toggleHelp", true)
function isPanelOpen() return UI.getOpenPanel() ~= nil end
