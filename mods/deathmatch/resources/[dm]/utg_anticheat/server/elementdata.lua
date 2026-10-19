local AC = AntiCheat
local reverting = false
addEventHandler("onElementDataChange", root, function(key, oldValue, newValue)
    if reverting or not AC.protectedData[key] or not AC.player(source) then return end
    local target, actor = source, client
    local s = AC.players[target]
    if not s then s = AC.initPlayer(target) end
    if not actor then
        -- Exact player keys were audited as server-owned. Other resources remain
        -- responsible for validating their own remote handlers before writing them.
        s.data[key] = newValue
        if key == "dm:arena" or key == "dm:ready" then
            AC.grant(target, "teleport", AC.settings.spawnGrace, "server_data_transition")
            AC.grant(target, "weapons", AC.settings.spawnGrace, "server_data_transition")
            s.movement, s.combat, s.inventory = nil, nil, nil
        end
        return
    end
    if not AC.player(actor) or not AC.enabled("elementdata") then return end
    AC.initPlayer(actor)
    -- Do not accept the new value into our server-owned context, even LOG_ONLY.
    if AC.mode() == "ENFORCE" then
        reverting = true
        local restore = s.data[key]
        if restore == nil then restore = oldValue end
        if restore == nil then removeElementData(target, key)
        else setElementData(target, key, restore, key ~= "dm:loadout") end
        reverting = false
    end
    AC.record(actor, "protected_data", "elementdata", "data", 4, 1,
        { key = key, target = tonumber(AC.data(target, "dm:id")) or -1,
          valueType = type(newValue), restored = AC.mode() == "ENFORCE" }, true)
end)
