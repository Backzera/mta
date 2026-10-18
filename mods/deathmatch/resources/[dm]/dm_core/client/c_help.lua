--[[
    Ajuda (F1): teclas em "keycaps" e comandos em duas colunas, com cascata.
]]

local PANEL = "help"
local help = { open = false, tick = 0, rendering = false }

local KEYS = {
    { "F1", "Esta ajuda" }, { "F2", "Arenas" }, { "F3", "Duelo X1" }, { "F4", "Loja" },
    { "F5", "Ranqueadas" }, { "F6", "Clã" }, { "TAB", "Placar" }, { "Y / N", "Aceitar / recusar duelo" }, { "ESC", "Fechar painel" },
}
local COMMANDS = {
    { "/arena <nome>", "Entrar em uma arena" }, { "/lobby", "Voltar ao lobby" },
    { "/duelo <jogador>", "Desafiar no X1" }, { "/a  /c  /pm <id>", "Chat da arena, do clã, privado" },
    { "/id  /emojis", "Seu ID · atalhos de emoji" }, { "/stats  /top", "Estatísticas e rankings" },
    { "/saldo  /pagar", "Dinheiro" }, { "/tag <texto>", "Tag personalizada (loja)" },
    { "/cla criar <TAG> <nome>", "Fundar um clã" }, { "/skin <id>", "Trocar skin" }, { "/kill", "Suicídio" },
}

local function render()
    local s = UI.s
    local f = UI.panelFrame(help, {
        w = s(760), h = s(540), title = "AJUDA", subtitle = ("Bem-vindo ao %s. Kills dão $, ranqueadas e duelos dão RP e elo."):format(DM.server.fullName),
        icon = "target.png", accent = "accent2", onClose = closeHelp,
    })
    if not f then
        if not help.open then removeEventHandler("onClientRender", root, render) help.rendering = false end
        return
    end
    local a = f.a
    local colW = (f.cw - s(24)) / 2
    UI.text("TECLAS", f.cx, f.cy, colW, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local ky = f.cy + s(26)
    for i, k in ipairs(KEYS) do
        local p = UI.stagger(a, i, #KEYS + #COMMANDS, 0.5)
        local kw = UI.textWidth(k[1], "bold", 10) + s(18)
        local ox = (1 - p) * s(16)
        UI.rrect(f.cx + ox, ky, kw, s(26), tocolor(255, 255, 255, 14 * a * p), s(6), { border = 1, borderColor = tocolor(255, 255, 255, 40 * a * p), glow = s(4), glowColor = UI.color("accent", 40 * a * p) })
        UI.text(k[1], f.cx + ox, ky, kw, s(26), UI.color("accent2", 255 * a * p), "bold", 10, "center", "center")
        UI.text(k[2], f.cx + ox + kw + s(10), ky, colW - kw, s(26), UI.color("text", 230 * a * p), "regular", 11, "left", "center")
        ky = ky + s(36)
    end
    local rx = f.cx + colW + s(24)
    UI.text("COMANDOS", rx, f.cy, colW, s(16), UI.color("accent", 255 * a), "semibold", 9, "left", "center")
    local cy = f.cy + s(26)
    for i, c in ipairs(COMMANDS) do
        local p = UI.stagger(a, #KEYS + i, #KEYS + #COMMANDS, 0.5)
        local ox = (1 - p) * s(16)
        UI.text(c[1], rx + ox, cy, colW, s(22), UI.color("text", 255 * a * p), "semibold", 10, "left", "center")
        UI.text(c[2], rx + ox, cy, colW, s(22), UI.color("muted", 255 * a * p), "regular", 9, "right", "center")
        cy = cy + s(28)
    end
    UI.panelFooter(f, "F1 ou ESC fecha  ·  Headshot x2.2, peito reduzido  ·  C-Bug liberado só na Arena C-Bug")
    UI.endFrame()
end

local function onClick(button, state)
    if help.open then UI.processClick(button, state) end
end

function openHelp()
    if help.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    help.open = true
    help.tick = getTickCount()
    if not help.rendering then help.rendering = true addEventHandler("onClientRender", root, render) end
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
