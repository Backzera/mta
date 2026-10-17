objeto = createObject ( 16773, 1207.5, -2037.4000244141, 70.800003051758, 0, 0, 89.499969482422 )
x,y,z = getElementPosition (objeto)
Zona = createColCircle ( x,y, 6, 6 )
--portao aberto--
function Funcion ()
moveObject ( objeto, 500, 1207.5, -2037.4000244141, 76.599998474121 )
end
addEventHandler ( "onColShapeHit", Zona, Funcion )
--portao fechado--
function Funcion2 ()
moveObject ( objeto, 500, 1207.5, -2037.4000244141, 70.800003051758 )
end
addEventHandler ( "onColShapeLeave", Zona, Funcion2 )
