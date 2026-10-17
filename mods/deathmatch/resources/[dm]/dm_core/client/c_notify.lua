--[[
    Notificações (toasts) no canto superior direito, com animação.
]]

local toasts = {}
local MAX = 5
local LIFE = 5000
local TYPES = {
    info    = { color = "info",   icon = "i" },
    success = { color = "accent", icon = "+" },
    error   = { color = "danger", icon = "x" },
    warn    = { color = "warn",   icon = "!" },
}

function notify(text, ntype, title)
    ntype = TYPES[ntype] and ntype or "info"
    table.insert(toasts, 1, { text = tostring(text), type = ntype, title = title, tick = getTickCount() })
    if #toasts > MAX then table.remove(toasts) end
    playUISound(ntype == "error" and "error" or "notify", 0.5)
end

addEvent("dm:notify", true)
addEventHandler("dm:notify", root, function(text, ntype, title)
    notify(text, ntype, title)
end)

addEventHandler("onClientRender", root, function()
    if #toasts == 0 then return end
    local now = getTickCount()
    local w = UI.s(340)
    local x = UI.sw - w - UI.s(24)
    local y = UI.s(24)
    -- Empurra para baixo se o killfeed estiver visível
    if KillFeed and KillFeed.height and KillFeed.height() > 0 then
        y = y + KillFeed.height() + UI.s(12)
    end
    for i = #toasts, 1, -1 do
        local t = toasts[i]
        local age = now - t.tick
        if age > LIFE then
            table.remove(toasts, i)
        end
    end
    for _, t in ipairs(toasts) do
        local age = now - t.tick
        local a = 1
        if age < 200 then a = UI.ease(age / 200) end
        if age > LIFE - 400 then a = math.max(0, (LIFE - age) / 400) end
        local slide = (1 - a) * UI.s(40)
        local info = TYPES[t.type]
        local pad = UI.s(14)
        local textW = w - pad * 3 - UI.s(30)
        local lines = math.max(1, math.ceil(UI.textWidth(t.text, "regular", 11) / textW))
        local h = pad * 2 + (t.title and UI.s(18) or 0) + lines * UI.s(17)
        local tx = x + slide
        UI.rect(tx + UI.s(2), y + UI.s(3), w, h, tocolor(0, 0, 0, 90 * a), UI.s(12))
        UI.rect(tx, y, w, h, UI.color("card", 240 * a), UI.s(12))
        UI.border(tx, y, w, h, tocolor(255, 255, 255, 24 * a), UI.s(12))
        -- faixa colorida à esquerda
        UI.rect(tx, y + UI.s(10), UI.s(4), h - UI.s(20), UI.color(info.color, 255 * a), UI.s(2))
        -- ícone
        local ix = tx + pad + UI.s(4)
        UI.rect(ix, y + pad, UI.s(26), UI.s(26), UI.color(info.color, 40 * a), UI.s(8))
        UI.text(info.icon, ix, y + pad, UI.s(26), UI.s(26), UI.color(info.color, 255 * a), "bold", 13, "center", "center")
        local cx = ix + UI.s(26) + pad
        local cy = y + pad
        if t.title then
            UI.text(t.title, cx, cy - UI.s(2), textW, UI.s(18), UI.color("text", 255 * a), "semibold", 12, "left", "top")
            cy = cy + UI.s(18)
        end
        UI.text(t.text, cx, cy, textW, lines * UI.s(17), UI.color(t.title and "muted" or "text", 255 * a), "regular", 11, "left", "top", false, true)
        -- barra de tempo
        UI.rect(tx + UI.s(12), y + h - UI.s(3), (w - UI.s(24)) * (1 - age / LIFE), UI.s(2), UI.color(info.color, 120 * a), 1)
        y = y + h + UI.s(8)
    end
end)
