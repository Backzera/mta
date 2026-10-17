function tele (thePlayer)
	setElementPosition ( thePlayer, -1356.416, -924.233, 992.383 )
	outputChatBox ('#FFFFFF[ #00FFFFTele#FFFFFF ]: #00FFFF' .. getPlayerName(thePlayer) .. ' #828282Foi Para A Area de x1 #FFFFFF(#00FFFF /x1 #FFFFFF)', root, 255, 255, 255, true)
end
addCommandHandler ( "x1", tele )

