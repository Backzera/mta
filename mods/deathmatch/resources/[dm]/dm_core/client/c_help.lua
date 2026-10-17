--[[
    Painel de ajuda (F1): teclas e comandos.
]]

local help = { open = false, tick = 0 }
local PANEL = "help"

local KEYS = {
    { "F1", "Esta ajuda" }, { "F2", "Painel de arenas" }, { "F3", "Painel de duelo X1" },
    { "TAB", "Placar" }, { "T", "Chat" }, { "ESC", "Fechar painéis" },
}
local COMMANDS = {
    { "/arena <nome>", "Entrar em uma arena" }, { "/arenas", "Listar arenas" }, { "/lobby", "Voltar ao lobby" },
    { "/x1", "Ir para a arena X1" }, { "/duelo <jogador>", "Desafiar rapidamente" },
    { "/stats [jogador]", "Ver estatísticas" }, { "/top", "Top 10 kills" },
    { "/skin <id>", "Trocar skin" }, { "/pm <jogador> <msg>", "Mensagem privada" },
    { "/kill", "Suicídio" }, { "/admins", "Admins online" },
}

local function render()
    local progress = UI.openProgress(help)
    if progress <= 0 then
        if not help.open then removeEventHandler("onClientRender", root, render) end
        return
    end
    local a = progress
    local s = UI.s
    local w, h = s(640), s(460)
    local x, y = (UI.sw - w) / 2, (UI.sh - h) / 2 + (1 - a) * s(20)
    local pad = s(28)
    dxDrawRectangle(0, 0, UI.sw, UI.sh, tocolor(5, 7, 12, 160 * a))
    UI.card(x, y, w, h, s(20), a)
    UI.text("AJUDA", x + pad, y + pad - s(4), w, s(30), UI.color("text", 255 * a), "bold", 24, "left", "center")
    UI.text(("Bem-vindo ao %s. Mate, suba de nível e domine as arenas."):format(DM.server.name), x + pad, y + pad + s(28), w, s(20), UI.color("muted", 255 * a), "regular", 11, "left", "center")

    local cx, cy = x + w - pad - s(32), y + pad - s(6)
    UI.button("help_close", "×", cx, cy, s(32), s(32), { kind = "ghost", size = 12, alpha = a })
    help.closeBounds = { cx, cy, s(32), s(32) }

    local colW = (w - pad * 2 - s(20)) / 2
    local ly = y + pad + s(70)
    UI.text("TECLAS", x + pad, ly, colW, s(18), UI.color("accent", 255 * a), "semibold", 10, "left", "center")
    local ky = ly + s(26)
    for _, k in ipairs(KEYS) do
        local kw = UI.textWidth(k[1], "bold", 10) + s(16)
        UI.rect(x + pad, ky, kw, s(24), tocolor(255, 255, 255, 18 * a), s(6))
        UI.text(k[1], x + pad, ky, kw, s(24), UI.color("text", 255 * a), "bold", 10, "center", "center")
        UI.text(k[2], x + pad + kw + s(10), ky, colW - kw, s(24), UI.color("muted", 255 * a), "regular", 11, "left", "center")
        ky = ky + s(34)
    end

    local rx = x + pad + colW + s(20)
    UI.text("COMANDOS", rx, ly, colW, s(18), UI.color("accent", 255 * a), "semibold", 10, "left", "center")
    local cy2 = ly + s(26)
    for _, c in ipairs(COMMANDS) do
        UI.text(c[1], rx, cy2, colW, s(22), UI.color("text", 255 * a), "semibold", 10, "left", "center")
        UI.text(c[2], rx, cy2, colW, s(22), UI.color("muted", 255 * a), "regular", 10, "right", "center")
        cy2 = cy2 + s(26)
    end

    UI.divider(x + pad, y + h - s(52), w - pad * 2, 18 * a)
    UI.text("Dica: na Arena C-Bug o C-Bug é liberado; nas outras ele é bloqueado automaticamente.", x + pad, y + h - s(44), w - pad * 2, s(30), UI.color("muted", 200 * a), "regular", 10, "left", "center")
end

local function onClick(button, state)
    if button ~= "left" or state ~= "down" or not help.open then return end
    if help.closeBounds and UI.isMouseIn(unpack(help.closeBounds)) then closeHelp() end
end

function openHelp()
    if help.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    help.open = true
    help.tick = getTickCount()
    addEventHandler("onClientRender", root, render)
    addEventHandler("onClientClick", root, onClick)
    playUISound("click", 0.4)
end

function closeHelp()
    if not help.open then return end
    help.open = false
    help.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
end

local function toggleHelp()
    if help.open then closeHelp() else openHelp() end
end

addEvent("dm:toggleHelp", true)
addEventHandler("dm:toggleHelp", root, toggleHelp)
bindKey("F1", "down", toggleHelp)
UI.registerEscape(PANEL, closeHelp)
