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
-- O servidor pode disparar estes eventos antes de o dm_ui terminar de carregar; registrá-los aqui evita
-- "event is not added clientside" (os handlers do dm_ui recebem normalmente quando ele sobe).
for _, ev in ipairs({ "dm:notify", "dm:toggleHelp", "dm:onMoney", "dm:onKill", "dm:onKillReward", "dm:onStreak", "dm:tierChange",
    "shop:open", "shop:result", "duel:openPanel", "duel:incoming", "duel:requestRemoved", "duel:outgoing", "duel:outgoingRemoved",
    "duel:start", "duel:round", "duel:fight", "duel:score", "duel:end", "ranked:info", "ranked:state", "ranked:spectate", "ranked:start", "ranked:end",
    "clans:info", "crates:result", "crates:openFailed", "crates:openPanel", "login:show", "login:result" }) do
    addEvent(ev, true)
end
function isPanelOpen() return UI.getOpenPanel() ~= nil end
