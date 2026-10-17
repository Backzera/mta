commando = { }
tempo = 3000

function Tele( playerSource )
	if (commando[playerSource]) then
		return outputChatBox ( "Aguarde 3 Segundos Para Usar o Tele Novamente!", playerSource, 0, 255, 0 )
	end
		setElementPosition(playerSource, -3770.161, 1893.17, 6.97)
		outputChatBox ('#FF0000→ #FFFFFF[ #FF0000Tᴇʟᴇᴘᴏʀᴛ #FFFFFF] #696969' .. getPlayerName(playerSource) .. ' #FFFFFFFoi para o #FF0000/pvp', root, 255, 255, 255, true)		
	commando[playerSource] = true
	setTimer( function()
		commando[playerSource] = false
	end, tempo, 1)
end
addCommandHandler( "pvp",Tele)
