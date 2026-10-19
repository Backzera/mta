"""Run with Python + lupa: python tools/tests/test_server_regressions.py.

Executes the actual Lua 5.1 scripts against SQLite and an asynchronous MTA stub.
No live server or player database is accessed.
"""
import json
from pathlib import Path
import sqlite3
import unittest

from lupa.lua51 import LuaRuntime, lua_type

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / 'mods/deathmatch/resources/[dm]'


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.pending = []
        g = self.lua.globals()

        def table(value):
            if isinstance(value, (list, tuple)):
                return self.lua.table_from([table(v) for v in value])
            if isinstance(value, dict):
                return self.lua.table_from({k: table(v) for k, v in value.items()})
            return value

        def plain(value):
            if lua_type(value) == 'table':
                return {k: plain(v) for k, v in value.items()}
            return value

        def query(*args):
            if callable(args[0]):
                callback, cbargs, _, sql, *params = args
                result = table([dict(r) for r in self.db.execute(sql, params)])
                self.pending.append(lambda: callback(result, *cbargs.values()))
                return result
            _, sql, *params = args
            return table([dict(r) for r in self.db.execute(sql, params)])

        def execute(_, sql, *params):
            self.db.execute(sql, params)
            return True

        g.dbConnect = lambda *_: True
        g.dbExec = execute
        g.dbQuery = query
        g.dbPoll = lambda result, _: result
        g.toJSON = lambda value: json.dumps(plain(value))
        g.fromJSON = lambda value: table(json.loads(value))
        self.lua.execute('''
            root, resourceRoot = {}, {}
            handlers, commands, events, players = {}, {}, {}, {}
            function addEvent() end
            function addEventHandler(name, attached, fn)
                handlers[name] = handlers[name] or {}
                table.insert(handlers[name], { attached, fn })
            end
            function emit(name, player, ...)
                local prev = source
                source = player
                for _, h in ipairs(handlers[name] or {}) do
                    if h[1] == root or h[1] == player then h[2](...) end
                end
                source = prev
            end
            function triggerEvent(...) emit(...) end
            function triggerClientEvent(player, name, _, ...)
                table.insert(events, { player, name, ... })
            end
            function addCommandHandler(name, fn) commands[name] = fn end
            function getRealTime() return {timestamp=123456} end
            function getTickCount() return 1000 end
            function isElement(p) return type(p) == 'table' and not p.destroyed end
            function getPlayerAccount(p) return p.account end
            function isGuestAccount(a) return not a or a.guest == true end
            function getAccountName(a) return a.name end
            function getPlayerSerial(p) return p.name end
            function getPlayerName(p) return p.name end
            function getPlayerVisibleName(p) return p.name end
            function getElementData(p, k) return p[k] end
            function setElementData(p, k, v) p[k] = v end
            function isPedDead() return false end
            function setElementModel(p, model) p.model = model end
            function getElementsByType() return players end
            function setTimer() return {} end
            function outputDebugString() end
            function outputChatBox() end
            function sendServerMessage() end
            function notifyPlayer() end
            function cancelEvent() cancelled = true end
            function isPlayerAdmin() return true end
            function getResourceFromName() return {} end
            function getResourceState() return 'running' end
            exports = {dm_core=setmetatable({}, {__index=function(_, name)
                return function(_, ...) return _G[name](...) end
            end})}
        ''')
        for path in ('dm_core/shared/config.lua', 'dm_core/shared/skins_generated.lua',
                     'dm_core/server/s_stats.lua', 'dm_core/server/s_arenas.lua',
                     'dm_core/server/s_commands.lua', 'dm_crates/server/s_crates.lua',
                     'dm_login/server/s_login.lua'):
            self.lua.execute((RES / path).read_text(encoding='utf-8'))
        self.lua.execute('''
            function getCratesConfig() return DM.crates end
            function getPlayerArena(p) return p['dm:arena'] end
            function setPlayerArena(p, arena)
                p['dm:arena'], p.model = arena, p['dm:skin']
            end
            -- Initialize the database without starting the arena/map system.
            handlers.onResourceStart[1][2]()
            p = {name='Tester', account={name='test'}}
            players[1] = p
        ''')

    def tearDown(self):
        self.db.close()

    def flush(self):
        while self.pending:
            self.pending.pop(0)()

    def login(self):
        self.lua.execute("loadPlayerStats(p); emit('dm:playerReady', p)")
        self.flush()

    def test_id_starts_at_one_and_login_waits_for_stats(self):
        self.lua.execute("loadPlayerStats(p); emit('dm:playerReady', p)")
        self.assertFalse(self.lua.eval("p['dm:ready']"))
        self.flush()
        self.assertEqual(self.lua.eval("p['dm:id']"), 1)
        self.assertTrue(self.lua.eval("p['dm:ready']"))

    def test_equipped_skin_is_applied_after_reconnect(self):
        self.login()
        self.lua.execute("commands.darskin(p, 'darskin', 'skin_miku'); emit('onPlayerQuit', p)")
        row = self.db.execute('SELECT equip_skin, perks FROM players').fetchone()
        self.assertEqual(row['equip_skin'], 298)
        self.assertTrue(json.loads(row['perks'])['item:skin_miku'])
        self.lua.execute("p['dm:ready']=false; p['dm:arena']=false; p['dm:skin']=false; p.model=7")
        self.login()
        self.assertEqual(self.lua.eval('p.model'), 298)
        self.assertEqual(self.lua.eval("p['dm:id']"), 1)

    def test_skin_command_persists_immediately(self):
        self.login()
        self.lua.execute("commands.skin(p, 'skin', '7')")
        self.assertEqual(self.db.execute('SELECT equip_skin FROM players').fetchone()[0], 7)

    def test_default_skin_button_changes_model_immediately_and_preserves_ownership(self):
        self.login()
        self.lua.execute('''
            commands.darskin(p, 'darskin', 'skin_miku')
            client=p; emit('crates:equip',p,'skin:none')
            assert(p.model ~= 298 and p.model == p['dm:skin'])
            local valid=false
            for _, model in ipairs(DM.skins) do if model == p.model then valid=true end end
            assert(valid)
        ''')
        row = self.db.execute('SELECT equip_skin, perks FROM players').fetchone()
        self.assertEqual(row['equip_skin'], 0)
        self.assertTrue(json.loads(row['perks'])['item:skin_miku'])

    def test_every_custom_character_can_be_awarded_and_saved(self):
        self.login()
        keys = ['miku', 'sakura_miku', 'zoro', 'luffy', 'usada_pekora', 'tanjiro', 'naruto_bijuu']
        for name in keys:
            key = 'skin_' + name
            self.lua.globals().testKey = key
            self.lua.execute('''
                DM.crates.boxes={{key='test',name='Teste',price=100,
                    pool={{item=testKey,weight=1}}}}
                setPlayerStat(p, 'money', 100)
                client=p
                emit('crates:open', p, 'test')
            ''')
            row = self.db.execute('SELECT money, perks FROM players').fetchone()
            self.assertEqual(row['money'], 0)
            self.assertTrue(json.loads(row['perks'])['item:' + key])

    def test_boxes_separate_all_characters_without_removing_currency_or_weapons(self):
        self.lua.execute('''
            local items, available = {}, {}
            for _, it in ipairs(DM.crates.items) do items[it.key] = it end
            local characters = 0
            assert(#DM.crates.boxes == 4)
            for _, b in ipairs(DM.crates.boxes) do
                local money = false
                if b.category == 'characters' then characters = characters + 1 end
                for _, entry in ipairs(b.pool) do
                    assert(entry.weight > 0)
                    local it = assert(items[entry.item])
                    available[it.key] = true
                    if b.category == 'characters' then
                        assert(it.type == 'skin')
                    else
                        assert(it.type ~= 'skin')
                        if it.type == 'money' then money = true end
                    end
                end
                if b.category ~= 'characters' then assert(money, b.key .. ' lost currency') end
            end
            assert(characters == 1)
            for _, it in ipairs(DM.crates.items) do
                if it.type ~= 'money' then assert(available[it.key], it.key .. ' unreachable') end
            end
        ''')

    def test_generated_boxes_match_generator_and_original_prices(self):
        import sys
        sys.path.insert(0, str(ROOT / 'tools'))
        from crate_catalog import render_boxes, BOXES
        items = [dict(it) for it in self.lua.globals().DM.crates['items'].values()]
        text = (RES / 'dm_core/shared/skins_generated.lua').read_text(encoding='utf-8')
        self.assertTrue(text.endswith(render_boxes(items) + '\n'))
        self.assertEqual([(b['key'], b['price']) for b in BOXES[:3]],
                         [('municao', 5000), ('tatica', 15000), ('elite', 40000)])

    def test_character_box_duplicate_refunds_half_and_preserves_weapon(self):
        self.login()
        self.lua.execute('''
            commands.darskin(p, 'darskin', 'ak47_asiimov')
            commands.darskin(p, 'darskin', 'skin_miku')
            for _, b in ipairs(DM.crates.boxes) do
                if b.key == 'personagens' then b.pool = {{item='skin_miku', weight=1}} end
            end
            setPlayerStat(p, 'money', 15000); client=p
            emit('crates:open', p, 'personagens')
        ''')
        self.assertEqual(self.lua.eval('getPlayerStats(p).money'), 7500)
        self.assertEqual(self.lua.eval("p['dm:wskin'].ak47"), 'ak47_asiimov')
        self.assertTrue(self.lua.eval('events[#events][5]'))

    def test_unknown_box_releases_pending_without_charge(self):
        self.login()
        self.lua.execute("setPlayerStat(p,'money',100); client=p; emit('crates:open',p,'missing')")
        self.assertEqual(self.lua.eval('getPlayerStats(p).money'), 100)
        self.assertEqual(self.lua.eval('events[#events][2]'), 'crates:openFailed')

    def test_empty_box_does_not_charge(self):
        self.login()
        self.lua.execute('''
            DM.crates.boxes={{key='empty',name='Empty',price=100,pool={}}}
            setPlayerStat(p,'money',100); client=p
            emit('crates:open',p,'empty')
        ''')
        self.assertEqual(self.lua.eval('getPlayerStats(p).money'), 100)

    def test_guest_cannot_enter_or_bypass_login_event(self):
        self.lua.execute("p.account={guest=true}; client=p; emit('login:guest',p); emit('dm:playerReady',p)")
        self.assertFalse(self.lua.eval("p['dm:ready']"))
        self.assertIsNone(self.lua.eval('p.model'))
        self.assertEqual(self.lua.eval('events[#events][3]'), False)

    def test_logout_cannot_switch_to_guest(self):
        self.login()
        self.lua.execute("emit('onPlayerLogout',p)")
        self.assertTrue(self.lua.eval('cancelled'))



if __name__ == '__main__':
    unittest.main(verbosity=2)
