-- Isolated test double. Never listed in meta.xml and never installed as gameplay code.
Mock = { tick = 100000, elements = {}, events = {}, handlers = {}, commands = {}, hooks = {}, timers = {},
    files = {}, logs = {}, requests = {}, bans = 0, kicks = 0, chats = 0, captures = 0, remoteCalls = 0 }
root = { kind = "root" }
resourceRoot = { kind = "resource-root" }
local resources = { utg_anticheat = { name = "utg_anticheat", state = "running" } }
function Mock.resource(name)
    resources[name] = resources[name] or { name = name, state = "running" }
    return resources[name]
end
function Mock.player(id)
    local p = { kind = "player", id = id, name = "P"..id, pos = {0,0,10}, dimension = 2, interior = 0,
        data = { ["dm:id"] = id, ["dm:ready"] = true, ["dm:arena"] = "m4", ["dm:loadout"] = { ["31"] = 500 } },
        health = 100, armor = 0, weapon = 31, inventory = { [5] = {31,500} }, ping = 30, loss = 0,
        velocity = {0,0,0}, grounded = true, account = { name = "a"..id } }
    Mock.elements[#Mock.elements+1] = p
    if AntiCheat then AntiCheat.initPlayer(p) end
    return p
end
function Mock.emit(name, element, actor, origin, ...)
    local oldSource, oldClient, oldResource = source, client, sourceResource
    source, client, sourceResource = element, actor, origin
    for _, entry in ipairs(Mock.handlers[name] or {}) do
        if entry.element == root or entry.element == element then entry.fn(...) end
    end
    source, client, sourceResource = oldSource, oldClient, oldResource
end
function Mock.advance(ms) Mock.tick = Mock.tick+ms end
function Mock.mutation(resource, name, ...)
    for _, hook in ipairs(Mock.hooks) do
        for _, allowed in ipairs(hook.names) do
            if name == allowed then hook.fn(Mock.resource(resource), name, true, "server/test.lua", 10, ...) end
        end
    end
end
function isElement(e) return type(e) == "table" and e.kind ~= nil and not e.destroyed end
function getElementType(e) return isElement(e) and e.kind or false end
function getElementsByType(kind)
    local out = {}
    for _, e in ipairs(Mock.elements) do if isElement(e) and e.kind == kind then out[#out+1] = e end end
    return out
end
function getTickCount() return Mock.tick end
function getRealTime() return { timestamp = 1792368000+math.floor(Mock.tick/1000) } end
function getThisResource() return resources.utg_anticheat end
function getResourceFromName(name) return resources[name] or false end
function getResourceName(r) return r.name end
function getResourceState(r) return r.state end
function getElementData(p,key) return p.data and p.data[key] or false end
function setElementData(p,key,value)
    local old = p.data[key]; p.data[key] = value
    Mock.emit("onElementDataChange",p,nil,resources.utg_anticheat,key,old,value)
    return true
end
function removeElementData(p,key) p.data[key] = nil; return true end
function getElementPosition(p) return unpack(p.pos) end
function getElementDimension(p) return p.dimension end
function getElementInterior(p) return p.interior end
function getElementVelocity(p) return unpack(p.velocity) end
function isElementFrozen(p) return p.frozen == true end
function isElementInWater(p) return p.water == true end
function isPedDead(p) return p.dead == true end
function isPedInVehicle(p) return p.vehicle == true end
function isPedOnGround(p) return p.grounded end
function getPedContactElement(p) return p.contact end
function getElementHealth(p) return p.health end
function getPedArmor(p) return p.armor end
function getPedWeapon(p,slot) return slot and (p.inventory[slot] and p.inventory[slot][1] or 0) or p.weapon end
function getPedTotalAmmo(p,slot) return p.inventory[slot] and p.inventory[slot][2] or 0 end
function getPlayerPing(p) return p.ping end
function getNetworkStats(p) return { packetlossLastSecond = p.loss } end
function getPlayerName(p) return p.name end
function getPlayerAccount(p) return p.account end
function getAccountName(a) return a.name end
function isGuestAccount(a) return a.guest == true end
function getPlayerSerial(p) return string.rep(tostring(p.id%10),32) end
function getPlayerIP() return "127.0.0.1" end
function hasObjectPermissionTo(object) return object.rights == true end
function aclGetGroup(name) return { name = name } end
function isObjectInACLGroup(name,group) return Mock.staffAccount == name and group.name == "Admin" end
function addEvent(name,remote) if Mock.events[name] ~= nil then return false end; Mock.events[name] = remote == true; return true end
function addEventHandler(name,element,fn)
    Mock.handlers[name] = Mock.handlers[name] or {}; table.insert(Mock.handlers[name],{ element = element, fn = fn }); return true
end
function addCommandHandler(name,fn) Mock.commands[name] = fn; return true end
function triggerClientEvent(...) Mock.remoteCalls = Mock.remoteCalls+1; return true end
function triggerServerEvent(...) Mock.remoteCalls = Mock.remoteCalls+1; return true end
function addDebugHook(kind,fn,names) table.insert(Mock.hooks,{kind=kind,fn=fn,names=names}); return true end
function removeDebugHook(kind,fn)
    for i=#Mock.hooks,1,-1 do if Mock.hooks[i].kind==kind and Mock.hooks[i].fn==fn then table.remove(Mock.hooks,i) end end
    return true
end
function setTimer(fn,ms,times,...) local t={fn=fn,ms=ms,times=times,args={...},active=true}; Mock.timers[#Mock.timers+1]=t; return t end
function isTimer(t) return t.active end
function killTimer(t) t.active = false; return true end
function outputServerLog(message) Mock.logs[#Mock.logs+1]=message end
function outputChatBox(...) Mock.chats=Mock.chats+1 end
function kickPlayer(...) Mock.kicks=Mock.kicks+1; return true end
function banPlayer(...) Mock.bans=Mock.bans+1; return true end
function toJSON(value)
    -- Sufficient deterministic serializer for tests; MTA serialization verified separately by docs.
    local function encode(v)
        if type(v)=="string" then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"' end
        if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
        if type(v)~="table" then return "null" end
        local out={}
        for k,x in pairs(v) do out[#out+1]=encode(tostring(k))..":"..encode(x) end
        table.sort(out); return "{"..table.concat(out,",").."}"
    end
    return encode(value)
end
function fileExists(path) return Mock.files[path] ~= nil end
function fileCreate(path) Mock.files[path]=""; return {path=path} end
function fileOpen(path) return fileExists(path) and {path=path} or false end
function fileGetSize(f) return #Mock.files[f.path] end
function fileSetPos() return true end
function fileWrite(f,text) Mock.files[f.path]=Mock.files[f.path]..text; return #text end
function fileClose() return true end
function fileDelete(path) Mock.files[path]=nil; return true end
function takePlayerScreenShot(p,w,h,tag)
    Mock.captures=Mock.captures+1; Mock.requests[#Mock.requests+1]={p=p,tag=tag}; return true
end
function fetchRemote(url,options,callback) Mock.lastFetch={url=url,options=options}; callback("",{success=true}); return true end
function abortRemoteRequest() Mock.aborted=true; return true end
function getPedControlState() return true end
function getPedTarget() return false end
function getCameraMatrix() return 0,0,10,100,0,10 end
function processLineOfSight() return false end
