g_base_cols = createColCuboid(1107.385, -2080.347, 68.008, 101, 86, 22) -------- Area da arena
hits = function(l_1_0, l_1_1)
  outputChatBox("#FFFFFF#FFFFFFVocê entrou em uma arena de x1 e recebeu uma #FF0000ak-47", l_1_0, 0, 255, 0, true)  ----------- Mensagem que vai aparecer quando entra
  giveWeapon(l_1_0, 30, 1500, true) ---------- ID DA ARMA
end

addEventHandler("onColShapeHit", g_base_cols, hits)
leaves = function(l_2_0, l_2_1)
  outputChatBox("#FFFFFFVocê saiu da arena x1 e devolveu sua #FF0000AK-47 ", l_2_0, 255, 255, 0, true) ----------- Mensagem que vai aparecer quando sai
  takeWeapon(l_2_0, 30) ------------ ID DA ARMA
end

addEventHandler("onColShapeLeave", g_base_cols, leaves)
spawn = function(l_3_0)
  local spawns = {}
  spawns[1] = {} ------- Dentro do aviao
  spawns[1].x = 1194.718
  spawns[1].y = -2013.075
  spawns[1].z = 69.266
  spawns[2] = {}
  spawns[2].x = 1187.978 ------- Encima do lado direito
  spawns[2].y = -1998.145
  spawns[2].z = 84.978
  spawns[3] = {}  ---------- No meio do mapa encima
  spawns[3].x = 1157.539
  spawns[3].y = -2037.521
  spawns[3].z = 85.331
  local rnd = math.random(#spawns)
  setElementPosition(l_3_0, spawns[rnd].x, spawns[rnd].y, spawns[rnd].z)
  fadeCamera(l_3_0, true)
  setCameraTarget(l_3_0, l_3_0)
  outputChatBox("" .. getPlayerName(l_3_0) .. " #1E90FF Foi Para arena de x1", getRootElement(), 255, 255, 255, true)
end

addCommandHandler("telemjmods", spawn) ---------- Comando teleporte
tempo = function()
  outputChatBox("#1E90FFQuer disputar um x1 ? vá ao icone de interrogação no mapa", getRootElement(), 255, 255, 255, true)
end

setTimer(tempo, 750000, 0)

