-- Sons da interface
local SOUNDS = {
    click = "assets/sounds/click.wav", hover = "assets/sounds/hover.wav", hit = "assets/sounds/hit.wav",
    headshot = "assets/sounds/headshot.wav", kill = "assets/sounds/kill.wav", death = "assets/sounds/death.wav",
    notify = "assets/sounds/notify.wav", error = "assets/sounds/error.wav", tick = "assets/sounds/tick.wav",
    go = "assets/sounds/go.wav", levelup = "assets/sounds/levelup.wav", streak = "assets/sounds/streak.wav",
    win = "assets/sounds/win.wav", lose = "assets/sounds/lose.wav",
}
local lastPlay = {}

function playUISound(name, volume)
    local path = SOUNDS[name]
    if not path then return false end
    local now = getTickCount()
    if lastPlay[name] and now - lastPlay[name] < 40 then return false end
    lastPlay[name] = now
    local snd = playSound(path, false)
    if snd then setSoundVolume(snd, volume or 0.6) end
    return snd
end

UI.sound = function(name, volume) playUISound(name, volume) end
