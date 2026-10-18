--[[
    Notificações (toasts) no topo direito, abaixo do killfeed: deslizam com overshoot, barra de tempo,
    ícone por tipo e brilho na cor do tipo.
]]

local toasts = {}
local MAX, LIFE = 5, 5000
local TYPES = {
    info    = { color = "accent2", icon = "i" },
    success = { color = "success", icon = "+" },
    error   = { color = "danger", icon = "x" },
    warn    = { color = "warn", icon = "!" },
}

function notify(text, ntype, title)
    ntype = TYPES[ntype] and ntype or "info"
    table.insert(toasts, 1, { text = tostring(text), type = ntype, title = title, tick = getTickCount(), id = getTickCount() + math.random(1000) })
    if #toasts > MAX then table.remove(toasts) end
    playUISound(ntype == "error" and "error" or "notify", 0.5)
end

addEvent("dm:notify", true)
addEventHandler("dm:notify", root, function(text, ntype, title) notify(text, ntype, title) end)

addEventHandler("onClientRender", root, function()
    if #toasts == 0 then return end
    local now = getTickCount()
    local s = UI.s
    local w = s(340)
    local x = UI.sw - w - s(24)
    local y = s(24)
    if KillFeed and KillFeed.height and KillFeed.height() > 0 then y = y + KillFeed.height() + s(12) end
    for i = #toasts, 1, -1 do
        if now - toasts[i].tick > LIFE then table.remove(toasts, i) end
    end
    for _, t in ipairs(toasts) do
        local age = now - t.tick
        local a = 1
        if age < 320 then a = UI.ease(age / 320, "outCubic") end
        if age > LIFE - 400 then a = math.max(0, (LIFE - age) / 400) end
        local slide = (1 - UI.ease(math.min(1, age / 420), "outBack")) * s(60)
        if age > LIFE - 400 then slide = (1 - a) * s(30) end
        local info = TYPES[t.type]
        local c = UI.palette[info.color]
        local pad = s(14)
        local textW = w - pad * 3 - s(30)
        local lines = math.max(1, math.ceil(UI.textWidth(t.text, "regular", 11) / textW))
        local h = pad * 2 + (t.title and s(18) or 0) + lines * s(17)
        local tx = x + slide
        local ty = UI.tween("toast:y:" .. t.id, y, 220, "outCubic")
        UI.rrect(tx, ty, w, h, UI.color("card", 235 * a), s(12), {
            border = 1, borderColor = tocolor(255, 255, 255, 24 * a),
            glow = s(12), glowColor = tocolor(c[1], c[2], c[3], 70 * a),
            gradient = UI.color("card2", 235 * a), gradientMode = 3,
        })
        UI.rrect(tx, ty + s(10), s(4), h - s(20), tocolor(c[1], c[2], c[3], 255 * a), s(2), { glow = s(5), glowColor = tocolor(c[1], c[2], c[3], 140 * a) })
        local ix = tx + pad + s(4)
        UI.rrect(ix, ty + pad, s(26), s(26), tocolor(c[1], c[2], c[3], 40 * a), s(8))
        UI.text(info.icon, ix, ty + pad, s(26), s(26), tocolor(c[1], c[2], c[3], 255 * a), "bold", 13, "center", "center")
        local cx, cy = ix + s(26) + pad, ty + pad
        if t.title then
            UI.text(t.title, cx, cy - s(2), textW, s(18), UI.color("text", 255 * a), "semibold", 12, "left", "top")
            cy = cy + s(18)
        end
        UI.text(t.text, cx, cy, textW, lines * s(17), UI.color(t.title and "muted" or "text", 255 * a), "regular", 11, "left", "top", false, true)
        UI.rrect(tx + s(12), ty + h - s(4), (w - s(24)) * (1 - age / LIFE), s(2), tocolor(c[1], c[2], c[3], 150 * a), 1)
        y = y + h + s(8)
    end
end)
