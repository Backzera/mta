"""Execute real UI Lua against client stubs; no live MTA connection required."""
from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime

RES = Path(__file__).resolve().parents[2] / 'mods/deathmatch/resources/[dm]'


class MenuTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            root, resourceRoot = {}, {}
            localPlayer = { ['dm:ready']=true, ['dm:perks']={['item:skin_miku']=true}, ['dm:arena']='lobby' }
            handlers, actions, binds, timers, deferred, sent = {}, {}, {}, {}, {}, {}
            local opened = nil
            states, updates, queries = {}, 0, 0
            UI = {}
            function UI.open(name, state) if opened and opened ~= name then return false end opened=name; states[name]=state; return true end
            function UI.close() opened=nil end
            function UI.toggle(name, fn) if opened==name then UI.close() elseif not opened then fn() end end
            function UI.isOpen(name) return opened==name end
            function UI.getOpenPanel() return opened end
            function UI.set(name, state) states[name]=state; updates=updates+1 end
            function UI.merge(name, values) for k,v in pairs(values) do states[name][k]=v end end
            function UI.defer(key, fn) deferred[key]=fn end
            function frame() local work=deferred; deferred={}; for _,fn in pairs(work) do fn() end end
            function UI.on(screen, action, fn) actions[screen..':'..action]=fn end
            function UI.onClose() end function UI.onEscape() end function UI.push() end function UI.sound() end
            function addEvent() end
            function addEventHandler(name, element, fn) handlers[name]=handlers[name] or {}; table.insert(handlers[name],fn) end
            function removeEventHandler() end
            function emit(name, ...) for _,fn in ipairs(handlers[name] or {}) do fn(...) end end
            function setTimer(fn, ms, times) local t={fn=fn,ms=ms}; timers[#timers+1]=t; return t end
            function isTimer(t) return not t.killed end function killTimer(t) t.killed=true end
            function bindKey(key, state, fn) binds[key]=fn end
            function addCommandHandler() end
            function getTickCount() return 1000 end
            function getPlayerName() return 'Tester' end
            function getElementData(p,k) return p[k] end
            function getElementDimension() return 0 end
            function setElementDimension() end function setCameraMatrix() end function setCameraTarget() end
            function getElementPosition() return 0,0,10 end function getElementRotation() return 0,0,0 end
            function setElementPosition() end function setElementRotation() end function setElementFrozen() end
            function getDistanceBetweenPoints3D() return 0 end
            function getElementsByType() return {localPlayer} end
            function getWeaponNameFromID(id) return tostring(id) end
            function isElement(v) return type(v)=='table' end
            function triggerServerEvent(name, player, ...) table.insert(sent,{name,...}) end
            exports={dm_core=setmetatable({}, {__index=function(_,key)
                return function(_,...) queries=queries+1; return _G[key](...) end
            end})}
        ''')
        for path in ('dm_core/shared/config.lua', 'dm_core/shared/skins_generated.lua',
                     'dm_core/client/c_exports.lua', 'dm_ui/client/c_screens.lua'):
            self.lua.execute((RES / path).read_text(encoding='utf-8'))

    def test_inventory_refreshes_on_next_frame_without_four_second_poll(self):
        self.lua.execute('''
            openCratesPanel()
            localPlayer['dm:skin']=298
            emit('onClientElementDataChange','dm:skin')
            localPlayer['dm:wskin']={ak47='ak47_asiimov'}
            emit('onClientElementDataChange','dm:wskin')
            localPlayer['dm:money']=60000
            emit('onClientElementDataChange','dm:money')
            assert(updates==0)
            frame()
            assert(updates==1)
            assert(states.crates.equippedSkin==298)
            assert(states.crates.equippedW.ak47=='ak47_asiimov')
            assert(states.crates.money==60000)
        ''')

    def test_character_panel_is_separate_and_reuses_ownership(self):
        self.lua.execute('''
            binds.F10()
            assert(UI.isOpen('characters'))
            assert(states.characters.owned[1]=='skin_miku')
            assert(#states.characters.items==11)
            for _,it in ipairs(states.characters.items) do assert(it.type=='skin') end
            actions['characters:equip']({key='ak47_asiimov'})
            assert(#sent==0)
            actions['characters:equip']({key='skin_miku'})
            assert(sent[1][1]=='crates:equip' and sent[1][2]=='skin_miku')
            localPlayer['dm:skin']=298
            emit('onClientElementDataChange','dm:skin'); frame()
            assert(states.characters.equippedSkin==298)
            actions['characters:boxes']()
            assert(UI.isOpen('crates') and #states.crates.boxes==4)
            actions['crates:characters']()
            assert(UI.isOpen('characters'))
        ''')

    def test_repeated_open_clicks_send_only_one_purchase_until_response(self):
        self.lua.execute('''
            openCratesPanel()
            actions['crates:open']({box='personagens'})
            actions['crates:open']({box='personagens'})
            assert(#sent==1 and states.crates.opening=='personagens')
            emit('crates:openFailed')
            assert(states.crates.opening==false)
            actions['crates:open']({box='personagens'})
            assert(#sent==2)
            emit('crates:result','personagens','skin_miku',false)
            assert(states.crates.opening==false)
            actions['crates:open']({box='personagens'})
            assert(#sent==2) -- reel still playing
        ''')

    def test_arena_camera_does_not_fetch_catalogs_every_frame(self):
        self.lua.execute('''
            openHub()
            local before=queries
            for i=1,120 do emit('onClientRender') end
            assert(queries==before)
            actions['hub:select']({id='lobby'})
            before=queries
            for i=1,120 do emit('onClientRender') end
            assert(queries==before)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
