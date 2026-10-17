--[[
    O MTA bloqueia o C-Bug por padrão (glitch "crouchbug"). Aqui ele é liberado
    globalmente e o cliente (c_cbug.lua) bloqueia fora da arena marcada com cbug = true.
]]

addEventHandler("onResourceStart", resourceRoot, function()
    setGlitchEnabled("crouchbug", true)
    setGlitchEnabled("quickstand", true)
    outputServerLog("[dm_cbug] C-Bug habilitado (restrito pelo cliente às arenas com cbug = true).")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    setGlitchEnabled("crouchbug", false)
end)
