--[[
    Tags e cor de nick. Prioridade da tag: staff (ACL) > VIP > tag comprada > elo.
    elementData: dm:tag = { text, hex, kind }, dm:nameColor = "#RRGGBB"
]]

local function staffTag(player)
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return nil end
    local name = getAccountName(account)
    for _, t in ipairs(DM.staffTags) do
        local g = aclGetGroup(t.group)
        if g and isObjectInACLGroup("user." .. name, g) then
            return { text = t.text, hex = DM.rgbToHex(unpack(t.color)), kind = "staff" }
        end
    end
    return nil
end

function getPlayerTag(player)
    local row = getPlayerStats(player)
    local tag = staffTag(player)
    if tag then return tag end
    local vip = isPlayerVip(player)
    if vip > 0 then
        local v = DM.vip[vip]
        return { text = v.tag, hex = DM.rgbToHex(unpack(v.color)), kind = "vip" }
    end
    if row and row.tag ~= "" then
        for _, t in ipairs(DM.shop.tags) do
            if t.key == row.tag then
                local text = t.custom and (row.custom_tag ~= "" and row.custom_tag or "UTG") or t.text
                return { text = text, hex = DM.rgbToHex(unpack(t.color)), kind = "shop" }
            end
        end
    end
    local tier = DM.tierForRP(row and row.rp or 0)
    return { text = tier.name:upper(), hex = DM.rgbToHex(unpack(tier.color)), kind = "tier" }
end

function getPlayerNameColor(player)
    local row = getPlayerStats(player)
    if row and row.name_color ~= "" then
        for _, c in ipairs(DM.shop.nameColors) do
            if c.key == row.name_color then return DM.rgbToHex(unpack(c.color)) end
        end
    end
    local vip = isPlayerVip(player)
    if vip > 0 then return DM.rgbToHex(unpack(DM.vip[vip].color)) end
    return "#FFFFFF"
end

function refreshPlayerTag(player)
    if not isElement(player) then return end
    setElementData(player, "dm:tag", getPlayerTag(player))
    setElementData(player, "dm:nameColor", getPlayerNameColor(player))
end

function isPlayerStaff(player)
    return staffTag(player) ~= nil
end

-- Nick formatado para o chat: [CLÃ] [TAG] Nome
function formatPlayerName(player)
    local tag = getElementData(player, "dm:tag") or getPlayerTag(player)
    local clan = getElementData(player, "dm:clanTag")
    local parts = {}
    if clan and clan.text then parts[#parts + 1] = ("%s[%s]"):format(clan.hex or "#969BB4", clan.text) end
    parts[#parts + 1] = ("%s[%s]"):format(tag.hex, tag.text)
    parts[#parts + 1] = getPlayerNameColor(player) .. getPlayerVisibleName(player)
    return table.concat(parts, " ")
end

addEventHandler("onPlayerLogin", root, function() setTimer(refreshPlayerTag, 500, 1, source) end)
addEventHandler("onPlayerLogout", root, function() setTimer(refreshPlayerTag, 500, 1, source) end)

-- /tag <texto>: define a tag personalizada (precisa ter comprado)
addCommandHandler("tag", function(player, cmd, ...)
    local row = getPlayerStats(player)
    if not row then return end
    if row.tag ~= "custom" then
        notifyPlayer(player, "Você precisa comprar a Tag Personalizada na loja (F4).", "warn")
        return
    end
    local text = table.concat({ ... }, " ")
    text = DM.stripColors(text):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
    if #text < 2 or #text > 12 then
        notifyPlayer(player, "A tag deve ter de 2 a 12 caracteres (letras, números, - e _).", "error")
        return
    end
    row.custom_tag = text
    refreshPlayerTag(player)
    notifyPlayer(player, "Tag personalizada definida: " .. text, "success")
end)
