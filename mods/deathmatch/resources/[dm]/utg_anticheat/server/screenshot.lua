local AC, U = AntiCheat, UTGUtils
local pending, files, sequence, slot = {}, {}, 0, 0
function AC.cancelScreenshot(p) pending[p] = nil end
function AC.screenshotStartup()
    -- Fixed local filenames prevent traversal and permit cleanup after an unclean shutdown.
    for i = 1, AC.settings.screenshot.maxFiles do
        local path = "@capture-"..i..".jpg"
        if fileExists(path) then fileDelete(path) end
    end
end
function AC.requestScreenshot(p, reason, manual)
    local s, now, cfg = AC.players[p], AC.now(), AC.settings.screenshot
    if not s or not AC.player(p) or not AC.enabled("screenshot") then return false, "disabled" end
    -- LOG_ONLY suppresses automated and manual capture. Staff must opt into REVIEW.
    if AC.mode() == "LOG_ONLY" then return false, "LOG_ONLY: capturas desativadas; use REVIEW para testar" end
    if pending[p] or (s.screenshotTick and now-s.screenshotTick < cfg.cooldown) then return false, "cooldown" end
    local count = 0
    for _ in pairs(pending) do count = count+1 end
    if count >= cfg.maxPending then return false, "queue_full" end
    sequence = sequence+1
    local tag = "utg_ac:"..sequence..":"..math.floor(now)
    pending[p] = { tag = tag, tick = now, reason = U.text(reason, 80), manual = manual == true }
    s.screenshotTick = now
    if not takePlayerScreenShot(p, cfg.width, cfg.height, tag, cfg.quality, cfg.bandwidth, 500) then
        pending[p] = nil
        AC.log("screenshot_failed", p, { reason = "request_rejected" }); return false, "request_rejected"
    end
    AC.log("screenshot_requested", p, { tag = tag, reason = reason, manual = manual == true })
    return true
end
addEventHandler("onPlayerScreenShot", root, function(theResource, status, imageData, timestamp, tag)
    local p, cfg = source, AC.settings.screenshot
    if client or theResource ~= getThisResource() or not AC.player(p) then return end
    local request = pending[p]
    if not request or tag ~= request.tag then return end
    pending[p] = nil
    if AC.now()-request.tick > cfg.timeout then return end
    if AC.mode() == "LOG_ONLY" or not AC.enabled("screenshot") then return end
    if status ~= "ok" then
        AC.log("screenshot_status", p, { status = U.text(status,20), tag = tag })
        return -- disabled/minimized/error is not cheating and never increases score
    end
    if type(imageData) ~= "string" or #imageData < 4 or #imageData > cfg.maxBytes
        or imageData:sub(1,2) ~= string.char(255,216) then
        AC.log("screenshot_status", p, { status = "invalid_image", tag = tag }); return
    end
    slot = slot%cfg.maxFiles+1
    local path = "@capture-"..slot..".jpg"
    if fileExists(path) then fileDelete(path) end
    local f = fileCreate(path)
    if not f then AC.log("screenshot_status", p, { status = "storage_error" }); return end
    local written = fileWrite(f, imageData)
    fileClose(f)
    if written ~= #imageData then fileDelete(path); return end
    files[slot] = { path = path, expires = AC.now()+cfg.ttl }
    AC.log("screenshot_saved", p, { tag = tag, path = path, bytes = #imageData,
        reason = request.reason, clientTimestamp = tonumber(timestamp) or 0 })
end)
function AC.screenshotMaintenance()
    local now = AC.now()
    for p, request in pairs(pending) do
        if not AC.player(p) or now-request.tick > AC.settings.screenshot.timeout then
            pending[p] = nil
            if AC.player(p) then AC.log("screenshot_status", p, { status = "timeout", tag = request.tag }) end
        end
    end
    for i, item in pairs(files) do
        if now >= item.expires then
            if fileExists(item.path) then fileDelete(item.path) end
            files[i] = nil
        end
    end
end
function AC.screenshotShutdown()
    pending = {}
    for _, item in pairs(files) do if fileExists(item.path) then fileDelete(item.path) end end
    files = {}
end
