local AC, U = AntiCheat, UTGUtils
function AC.isStaff(p)
    if not AC.player(p) then return false end
    local account = getPlayerAccount(p)
    if not account or isGuestAccount(account) then return false end
    if hasObjectPermissionTo(p, AC.permissions.staffRight, false) then return true end
    local name = "user."..getAccountName(account)
    for _, groupName in ipairs(AC.permissions.staffGroups) do
        local group = aclGetGroup(groupName)
        if group and isObjectInACLGroup(name, group) then return true end
    end
    return false
end
function AC.staffAlert(p, evidence)
    local message = ("[UTG AC] #%s %s | %s | score %.2f | evidencia %d (revisar)"):format(
        tostring(AC.data(p,"dm:id") or "?"), U.text(getPlayerName(p),50), evidence.type, AC.score(p), evidence.id)
    for staff in pairs(AC.players) do if AC.isStaff(staff) then outputChatBox(message,staff,255,180,70) end end
end
local function resolve(id)
    if type(id) ~= "string" or not id:match("^%d+$") or #id > 10 then return nil end
    local num, found = tonumber(id), nil
    for p in pairs(AC.players) do
        if tonumber(AC.data(p,"dm:id")) == num then
            if found then return nil end -- duplicate ID is ambiguous, do not select arbitrarily
            found = p
        end
    end
    return found
end
local function say(p, message) outputChatBox("[UTG AC] "..message,p,150,225,200) end
local function command(name, callback)
    addCommandHandler(name, function(p, _, id)
        if not AC.isStaff(p) then return end
        AC.initPlayer(p)
        if not AC.consume(p,"staff_commands",1,3) then return end
        callback(p,id)
    end)
end
command("acsuspects",function(staff)
    local list = {}
    for p in pairs(AC.players) do
        local score = AC.score(p)
        if score >= 3 then list[#list+1] = { p = p, score = score } end
    end
    table.sort(list,function(a,b) return a.score > b.score end)
    say(staff,"Modo "..AC.mode().." | "..#list.." suspeito(s). Score nao prova cheat.")
    for i = 1, math.min(15,#list) do
        local item = list[i]
        say(staff,("#%s %s: %.2f"):format(tostring(AC.data(item.p,"dm:id")),U.text(getPlayerName(item.p),40),item.score))
    end
end)
command("acinfo",function(staff,id)
    local p = resolve(id)
    if not p then return say(staff,"Use /acinfo ID (ID unico do jogador).") end
    local s, score = AC.players[p], AC.score(p)
    say(staff,("%s | score %.2f | ping %d | arena %s"):format(U.text(getPlayerName(p),40),score,getPlayerPing(p),U.text(AC.data(p,"dm:arena"),32)))
    local m = AC.combatStats(p)
    say(staff,("Aim %.2f | tiros %d | hits correlacionados %d | nao confirmados %d | HS %d | snaps %d"):format(
        m.aim_suspicion_score,m.shots,m.hits,m.misses,m.headshots,m.snaps))
    for i = math.max(1,#s.evidence-5), #s.evidence do
        local e = s.evidence[i]
        say(staff,("E%d %s | confianca %.2f | %ds | %s"):format(e.id,e.type,e.confidence,
            math.floor((AC.now()-e.tick)/1000),U.text(toJSON(e.metadata,true),180)))
    end
end)
command("acscreenshot",function(staff,id)
    local p = resolve(id)
    if not p then return say(staff,"Use /acscreenshot ID.") end
    local ok, reason = AC.requestScreenshot(p,"staff_request",true)
    AC.log("staff_screenshot",staff,{ target = tonumber(id), accepted = ok == true })
    say(staff,ok and "Captura solicitada; consulte o log de evidencias." or "Captura nao solicitada: "..tostring(reason))
end)
command("acignore",function(staff,id)
    local p = resolve(id)
    if not p then return say(staff,"Use /acignore ID.") end
    AC.players[p].ignoreUntil = AC.now()+AC.permissions.ignoreMs
    AC.log("staff_ignore",staff,{ target = tonumber(id), durationMs = AC.permissions.ignoreMs })
    say(staff,"Heuristicas ignoradas temporariamente por "..AC.permissions.ignoreMs/1000 .."s. Protecao de eventos/dados continua ativa.")
end)
