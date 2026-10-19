"""Run: python tests/test_resource.py. Requires lupa (Lua 5.1 binding).
No game server, cheats, network requests or live player data are used.
"""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

RESOURCE = Path(__file__).resolve().parents[1]
META = ET.parse(RESOURCE / "meta.xml").getroot()


class ResourceTests(unittest.TestCase):
    def runtime(self, side="server"):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((RESOURCE / "tests/mta_mock.lua").read_text(encoding="utf-8"))
        if side == "client":
            lua.execute("localPlayer = Mock.player(1)")
        lua.execute("""
            local permitted = { AntiCheat=true, UTGUtils=true, ACClient=true,
                allowTeleport=true, allowVelocity=true, allowHealth=true, allowArmor=true, allowWeapons=true,
                source=true, client=true, sourceResource=true }
            setmetatable(_G, { __newindex=function(t,k,v)
                if not permitted[k] then error('Accidental global: '..tostring(k),2) end
                rawset(t,k,v)
            end })
        """)
        for script in META.findall("script"):
            if script.attrib["type"] in (side, "shared"):
                lua.execute((RESOURCE / script.attrib["src"]).read_text(encoding="utf-8"))
        if side == "server":
            # A produção roda em ENFORCE (ban automático por testemunhas); os testes partem do modo mais
            # conservador e ligam ENFORCE explicitamente onde precisam.
            lua.execute("AntiCheat.settings.debugMode = true; AntiCheat.settings.punishmentMode = 'LOG_ONLY'")
        return lua

    def test_witness_reports_ban_only_with_confirmations_and_never_staff(self):
        lua = self.runtime()
        lua.execute("""
            local ac = AntiCheat
            ac.settings.debugMode=false; ac.settings.punishmentMode='ENFORCE'
            getThisResource().rights = true
            local w1, w2, s = Mock.player(1), Mock.player(2), Mock.player(3)
            local function report(witness, kind, strong)
                Mock.emit('utg_ac:report', resourceRoot, witness, nil, s, kind, 'teste', strong)
            end
            -- silent fraco: só alerta, nunca bane
            report(w1, 'silent', false); Mock.advance(2000); report(w2, 'silent', false)
            assert(Mock.bans==0, 'silent fraco não bane')
            -- rapid fire: 2 relatos (de qualquer testemunha) banem
            report(w1, 'rapid', false); assert(Mock.bans==0, 'um relato não bane')
            Mock.advance(2000); report(w1, 'rapid', false)
            assert(Mock.bans==1, 'rapid fire deveria banir com 2 relatos')
            -- silent FORTE: 2 relatos banem
            local s2 = Mock.player(4)
            Mock.emit('utg_ac:report', resourceRoot, w1, nil, s2, 'silent', 'FORTE', true); Mock.advance(2000)
            Mock.emit('utg_ac:report', resourceRoot, w2, nil, s2, 'silent', 'FORTE', true)
            assert(Mock.bans==2, 'silent forte deveria banir com 2 relatos')
        """)
        lua = self.runtime()
        lua.execute("""
            local ac = AntiCheat
            ac.settings.debugMode=false; ac.settings.punishmentMode='ENFORCE'
            getThisResource().rights = true
            local w, s = Mock.player(1), Mock.player(2)
            Mock.staffAccount = 'user.a2'
            for i = 1, 3 do
                Mock.emit('utg_ac:report', resourceRoot, w, nil, s, 'rapid', 'teste', false); Mock.advance(2000)
            end
            assert(Mock.bans==0, 'staff nunca é banida automaticamente')
            assert(Mock.remoteCalls>0, 'staff deve receber alerta')
        """)
    def test_manifest_syntax_and_server_secret_boundary(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        compile_lua = lua.eval("function(s,n) local f,e=loadstring(s,n); return f~=nil,e end")
        seen = set()
        for node in META.findall("script"):
            path = RESOURCE / node.attrib["src"]
            self.assertTrue(path.is_file(), path)
            self.assertNotIn(path, seen)
            seen.add(path)
            ok, error = compile_lua(path.read_text(encoding="utf-8"), str(path))
            self.assertTrue(ok, error)
            if node.attrib["src"].startswith("config/"):
                self.assertEqual(node.attrib["type"], "server")
        self.assertEqual(set(RESOURCE.glob("*/*.lua")) - set(RESOURCE.glob("tests/*.lua")), seen)
        for export in META.findall("export"):
            self.assertEqual(export.attrib["type"], "server")

    def test_no_accidental_globals_or_start_stop_leaks(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            Mock.emit('onResourceStart',resourceRoot,nil,getThisResource(),getThisResource())
            for _,t in ipairs(Mock.timers) do t.fn() end
            Mock.emit('onPlayerQuit',p,nil,nil,'Quit')
            assert(AntiCheat.players[p]==nil and #AntiCheat.order==0)
            Mock.emit('onResourceStop',resourceRoot,nil,getThisResource(),getThisResource())
            assert(#Mock.hooks==0)
            for _,t in ipairs(Mock.timers) do assert(not t.active) end
        """)
        client = self.runtime("client")
        client.execute("""
            Mock.emit('onClientResourceStart',resourceRoot,nil,nil)
            Mock.emit('utg_ac:configure',resourceRoot,nil,nil,true,true,true)
            for _,t in ipairs(Mock.timers) do t.fn() end
            Mock.emit('onClientResourceStop',resourceRoot,nil,nil)
            assert(#Mock.hooks==0)
            for _,t in ipairs(Mock.timers) do assert(not t.active) end
        """)

    def test_remote_actor_schema_rate_and_bounded_state(self):
        lua = self.runtime()
        lua.execute("""
            local a,b=Mock.player(1),Mock.player(2)
            Mock.emit('utg_ac:aim',b,a,nil,0,0,0,0)
            assert(#AntiCheat.players[b].evidence==0)
            assert(AntiCheat.players[a].evidence[1].type=='remote_source')
            Mock.emit('utg_ac:aim',resourceRoot,nil,nil,0,0,0,0)
            assert(AntiCheat.players[a].combat==nil)
            Mock.advance(11000)
            Mock.emit('utg_ac:aim',resourceRoot,a,nil,0,0/0,0,0)
            assert(AntiCheat.players[a].evidence[2].type=='event_schema')
            local cyclic={}; cyclic.self=cyclic
            Mock.advance(11000)
            Mock.emit('utg_ac:aim',resourceRoot,a,nil,cyclic,0,0,0)
            assert(AntiCheat.players[a].combat==nil)
            for i=1,1000 do Mock.emit('utg_ac:aim',resourceRoot,a,nil,0,0,0,0) end
            assert(#AntiCheat.players[a].evidence < 10)
            local n=0; for _ in pairs(AntiCheat.players[a].buckets) do n=n+1 end
            assert(n==2)
            assert(Mock.bans==0 and Mock.kicks==0)
        """)

    def test_log_only_is_absolute_and_heuristics_cannot_ban(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            getThisResource().rights=true
            local ac=AntiCheat
            ac.settings.actions.protected_data='BAN'; ac.settings.allowPermanentBan=true
            for i=1,4 do
                local e=ac.record(p,'protected_data','elementdata','data',4,1,{},true)
                for _,action in ipairs({'WARN','STAFF_ALERT','SCREENSHOT','KICK','TEMPBAN','BAN'}) do ac.punish(p,action,e) end
                Mock.advance(11000)
            end
            assert(Mock.bans==0 and Mock.kicks==0 and Mock.chats==0 and Mock.captures==0)
            ac.settings.debugMode=false; ac.settings.punishmentMode='TYPO'
            assert(ac.mode()=='LOG_ONLY')
            ac.settings.punishmentMode='ENFORCE'
            ac.settings.actions.aim_snap='BAN'
            local e=ac.record(p,'aim_snap','aimbot','aim',10,1,{},false)
            ac.punish(p,'BAN',e)
            assert(Mock.bans==0)
            assert(not ac.punish(p,'BAN',{deterministic=true,type='protected_data',confidence=1}))
        """)

    def test_confirmed_enforcement_requires_acl_and_configuration(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            local ac=AntiCheat
            ac.settings.debugMode=false; ac.settings.punishmentMode='ENFORCE'
            ac.settings.actions.protected_data='KICK'
            for i=1,3 do ac.record(p,'protected_data','elementdata','data',4,1,{},true); Mock.advance(11000) end
            assert(Mock.kicks==0)
            getThisResource().rights=true
            ac.record(p,'protected_data','elementdata','data',4,1,{},true)
            assert(Mock.kicks==1 and Mock.bans==0)
            ac.settings.actions.protected_data='TEMPBAN'; ac.settings.tempBanSeconds=0
            Mock.advance(31000)
            ac.record(p,'protected_data','elementdata','data',4,1,{},true)
            assert(Mock.bans==0) -- zero must not turn a temporary ban into permanent
        """)

    def test_high_skill_alone_and_ttl(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            for i=1,30 do
                AntiCheat.record(p,'aim_accuracy','aimbot','aim',0.75,0.25,{headshots=100},false)
                Mock.advance(11000)
            end
            assert(AntiCheat.score(p)<=0.75)
            Mock.advance(AntiCheat.settings.evidenceTTL+1)
            assert(AntiCheat.score(p)==0 and #AntiCheat.players[p].evidence==0)
        """)

    def test_authorized_grace_has_timeout_and_no_remote_grant(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            Mock.advance(16000)
            sourceResource=Mock.resource('dm_core')
            assert(allowTeleport(p,2000,'arena'))
            assert(not allowTeleport(p,999999,'permanent'))
            client=p
            assert(not allowTeleport(p,2000,'remote'))
            client=nil; sourceResource=Mock.resource('unknown')
            assert(not allowTeleport(p,2000,'unknown'))
            Mock.advance(2001)
            assert(not AntiCheat.hasGrace(p,'teleport'))
            AntiCheat.installMutationHook()
            Mock.mutation('dm_core','setElementPosition',p,10,20,30)
            assert(AntiCheat.hasGrace(p,'teleport'))
        """)

    def test_protected_data_uses_actor_and_restores_target_only_in_enforce(self):
        lua = self.runtime()
        lua.execute("""
            local a,b=Mock.player(1),Mock.player(2)
            b.data['dm:money']=10
            Mock.emit('onElementDataChange',b,nil,Mock.resource('dm_core'),'dm:money',false,10)
            b.data['dm:money']=999
            Mock.emit('onElementDataChange',b,a,nil,'dm:money',10,999)
            assert(AntiCheat.data(b,'dm:money')==10 and b.data['dm:money']==999)
            assert(#AntiCheat.players[a].evidence==1 and #AntiCheat.players[b].evidence==0)
            AntiCheat.settings.debugMode=false; AntiCheat.settings.punishmentMode='ENFORCE'
            Mock.advance(11000)
            Mock.emit('onElementDataChange',b,a,nil,'dm:money',999,12345)
            assert(b.data['dm:money']==10)
            setElementData(b,'dm:money',20)
            assert(AntiCheat.data(b,'dm:money')==20)
        """)

    def test_movement_spawn_world_fall_vehicle_and_legitimate_mutation(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            local ac=AntiCheat
            p.pos={1000,0,10}; ac.sampleMovement(p)
            assert(#ac.players[p].evidence==0)
            Mock.advance(16000); ac.sampleMovement(p); Mock.advance(2600)
            ac.sampleMovement(p); Mock.advance(500)
            p.dimension=4; p.pos={-2000,100,1000}; ac.sampleMovement(p)
            assert(#ac.players[p].evidence==0)
            Mock.advance(3000); ac.sampleMovement(p); Mock.advance(500)
            p.pos[3]=-50; p.velocity={0,0,-1}; p.grounded=false; ac.sampleMovement(p)
            assert(#ac.players[p].evidence==0)
            p.vehicle=true; p.pos={3000,0,20}; ac.sampleMovement(p)
            assert(#ac.players[p].evidence==0)
            p.vehicle=false; p.grounded=true; p.velocity={0,0,0}
            ac.installMutationHook()
            Mock.mutation('dm_ranked','setElementPosition',p,0,0,10)
            p.pos={0,0,10}; ac.sampleMovement(p)
            assert(#ac.players[p].evidence==0)
        """)

    def test_cbug_switching_batching_and_sustained_cadence(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            p.weapon=24; Mock.advance(16000)
            local function shot(ms)
                Mock.advance(ms)
                Mock.emit('onPlayerWeaponFire',p,nil,nil,24,100,0,10,false,0,0,10)
            end
            for i=1,120 do shot(60) end
            assert(#AntiCheat.players[p].evidence==0)
            for i=1,80 do shot(0) end -- coalesced network batch, not an automatic conviction
            assert(#AntiCheat.players[p].evidence==0)
            for i=1,20 do
                Mock.emit('onPlayerWeaponSwitch',p,nil,nil,24,25); shot(12)
            end
            assert(#AntiCheat.players[p].evidence==0)
            Mock.advance(2000)
            for i=1,550 do shot(12) end
            local found=false
            for _,e in ipairs(AntiCheat.players[p].evidence) do if e.type=='fire_cadence' then found=true end end
            assert(found and Mock.bans==0)
        """)

    def test_weapons_loadout_refill_and_repeated_mismatch(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            Mock.advance(16000)
            for i=1,5 do AntiCheat.sampleWeapons(p); Mock.advance(500) end
            assert(#AntiCheat.players[p].evidence==0)
            p.inventory[5]={31,480}; AntiCheat.sampleWeapons(p)
            p.inventory[5]={31,500}; AntiCheat.sampleWeapons(p)
            assert(#AntiCheat.players[p].evidence==0)
            p.inventory[7]={38,9999}
            for i=1,3 do AntiCheat.sampleWeapons(p); Mock.advance(500) end
            assert(AntiCheat.players[p].evidence[1].type=='unexpected_weapon')
            assert(Mock.bans==0)
        """)

    def test_capture_origin_tag_failure_expiry_and_bounds(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            assert(not AntiCheat.requestScreenshot(p,'test',true))
            AntiCheat.settings.debugMode=false; AntiCheat.settings.punishmentMode='REVIEW'
            assert(AntiCheat.requestScreenshot(p,'test',true))
            local tag=Mock.requests[1].tag
            local jpeg=string.char(255,216)..'JPEG'
            Mock.emit('onPlayerScreenShot',p,nil,nil,Mock.resource('other'),'ok',jpeg,1,tag)
            assert(not fileExists('@capture-1.jpg'))
            Mock.emit('onPlayerScreenShot',p,nil,nil,getThisResource(),'ok',jpeg,1,'forged')
            assert(not fileExists('@capture-1.jpg'))
            Mock.emit('onPlayerScreenShot',p,nil,nil,getThisResource(),'ok',jpeg,1,tag)
            assert(fileExists('@capture-1.jpg'))
            Mock.advance(AntiCheat.settings.screenshot.ttl+1)
            AntiCheat.screenshotMaintenance()
            assert(not fileExists('@capture-1.jpg'))
            assert(AntiCheat.requestScreenshot(p,'test',true))
            Mock.emit('onPlayerScreenShot',p,nil,nil,getThisResource(),'disabled','',1,Mock.requests[2].tag)
            assert(#AntiCheat.players[p].evidence==0 and Mock.bans==0)
        """)

    def test_staff_identity_not_elementdata_or_serial(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            p.data.admin=true; p.data.staff=true
            assert(not AntiCheat.isStaff(p))
            Mock.commands.acignore(p,'acignore','1')
            assert(not AntiCheat.players[p].ignoreUntil)
            Mock.staffAccount='user.a1'
            assert(AntiCheat.isStaff(p))
            Mock.commands.acignore(p,'acignore','1')
            assert(AntiCheat.players[p].ignoreUntil>AntiCheat.now())
            assert(not AntiCheat.record(p,'aim_snap','aimbot','aim',3,0.5,{},false))
            assert(AntiCheat.record(p,'protected_data','elementdata','data',4,1,{},true))
        """)

    def test_static_ban_boundary_and_no_remote_code(self):
        for path in RESOURCE.glob("*/*.lua"):
            if path.parent.name == "tests":
                continue
            text = path.read_text(encoding="utf-8")
            if re.search(r"\b(?:banPlayer|kickPlayer)\s*\(", text):
                self.assertEqual(path.name, "punishment.lua")
            self.assertNotRegex(text, r"\b(?:loadstring|load|dofile)\s*\(")
            if "fetchRemote(" in text:
                self.assertEqual(path.name, "discord.lua")
            self.assertNotIn('"onClientRender"', text)

    def test_spawn_grace_is_not_shortened_by_post_function_hook(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            AntiCheat.installMutationHook()
            Mock.emit('onPlayerSpawn',p,nil,nil)
            Mock.mutation('dm_core','spawnPlayer',p)
            Mock.mutation('dm_core','setElementPosition',p,1,2,3)
            Mock.advance(5000)
            assert(AntiCheat.hasGrace(p,'teleport'))
            Mock.advance(8000)
            assert(not AntiCheat.hasGrace(p,'teleport'))
        """)

    def test_correlated_aim_requires_shots_and_unreliable_hit_element_is_ignored(self):
        lua = self.runtime()
        lua.execute("""
            local a,b,c,d=Mock.player(1),Mock.player(2),Mock.player(3),Mock.player(4)
            b.pos={30,0,10}; c.pos={-30,30,10}; d.pos={-30,-30,10}
            local targets={b,c,d}
            Mock.advance(16000)
            -- A forged remote bridge cannot produce a hit or incriminate another player.
            Mock.emit('ac:hit',a,b,Mock.resource('dm_weapons'),a,b,31,true)
            assert(AntiCheat.combatStats(a).hits==0)
            Mock.emit('onPlayerWeaponFire',a,nil,nil,31,30,0,10,b,0,0,10)
            assert(AntiCheat.combatStats(a).hits==0)
            Mock.emit('onPlayerDamage',b,nil,nil,a,31,9,20)
            Mock.emit('ac:hit',a,nil,Mock.resource('dm_weapons'),a,b,31,true)
            assert(AntiCheat.combatStats(a).hits==1) -- native + bridge deduplicated
            for i=1,120 do
                Mock.advance(200)
                local target=targets[(i%3)+1]
                Mock.emit('onPlayerTarget',a,nil,nil,target)
                Mock.emit('onPlayerWeaponFire',a,nil,nil,31,30,0,10,false,0,0,10)
                Mock.emit('ac:hit',a,nil,Mock.resource('dm_weapons'),a,target,31,true)
            end
            local m=AntiCheat.combatStats(a)
            assert(m.shots==121 and m.hits==121 and m.headshots==121 and m.distinctTargets==3)
            Mock.emit('utg_ac:aim',resourceRoot,a,nil,4,90,8,0)
            AntiCheat.evaluateCombat(a)
            assert(AntiCheat.score(a)>=7)
            assert(Mock.bans==0 and Mock.kicks==0 and Mock.captures==0)
            assert(#AntiCheat.players[b].evidence==0)
            Mock.emit('onPlayerQuit',b,nil,nil,'Quit')
            for _,shot in ipairs(AntiCheat.players[a].combat.shots) do assert(shot.victim~=b) end
        """)

    def test_network_loss_and_jitter_invalidate_cadence(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1); p.loss=30; p.weapon=24
            Mock.advance(16000)
            for i=1,600 do
                Mock.advance(12)
                Mock.emit('onPlayerWeaponFire',p,nil,nil,24,100,0,10,false,0,0,10)
            end
            assert(#AntiCheat.players[p].evidence==0)
            p.loss=0; p.ping=220; Mock.advance(1100)
            assert(not AntiCheat.networkOK(p))
        """)

    def test_bounded_history_capture_timeout_and_all_toggles(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            local ac=AntiCheat
            ac.settings.maxEvidence=4
            for i=1,10 do
                ac.record(p,'protected_data','elementdata','data',4,1,{},true); Mock.advance(11000)
            end
            assert(#ac.players[p].evidence==4)
            for key in pairs(ac.settings.detectors) do
                ac.settings.detectors[key]=false
                assert(not ac.record(p,'disabled_'..key,key,'aim',9,1,{},true))
            end
            ac.settings.detectors.screenshot=true
            ac.settings.debugMode=false; ac.settings.punishmentMode='REVIEW'
            assert(ac.requestScreenshot(p,'test',true))
            local tag=Mock.requests[1].tag
            Mock.advance(ac.settings.screenshot.timeout+1); ac.screenshotMaintenance()
            Mock.emit('onPlayerScreenShot',p,nil,nil,getThisResource(),'ok',string.char(255,216)..'JPEG',1,tag)
            assert(not fileExists('@capture-1.jpg'))
            Mock.advance(20000)
            assert(ac.requestScreenshot(p,'test',true))
        """)

    def test_discord_is_server_fixed_and_suppresses_mentions(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            local ac=AntiCheat
            ac.discordConfig.enabled=true; ac.discordConfig.webhook='https://example.invalid/anything'
            ac.record(p,'protected_data','elementdata','data',4,1,{},true)
            ac.discordDrain()
            assert(Mock.lastFetch==nil)
            ac.discordConfig.webhook='https://discord.com/api/webhooks/123/test_token'
            Mock.advance(11000)
            ac.record(p,'protected_data','elementdata','data',4,1,{key='dm:money'},true)
            ac.discordDrain()
            assert(Mock.lastFetch.url==ac.discordConfig.webhook)
            assert(Mock.lastFetch.options.maxRedirects==0)
            assert(Mock.lastFetch.options.postData:find('"parse":[]',1,true))
        """)

    def test_monotonic_clock_rollover(self):
        lua = self.runtime()
        lua.execute("""
            AntiCheat.clock.last=4294967290; AntiCheat.clock.value=100
            Mock.tick=5
            assert(AntiCheat.now()==111)
        """)

    def test_discord_timeout_aborts_without_executing_response(self):
        lua = self.runtime()
        lua.execute("""
            local p=Mock.player(1)
            local ac=AntiCheat
            ac.discordConfig.enabled=true
            ac.discordConfig.webhook='https://discord.com/api/webhooks/123/test_token'
            fetchRemote=function(url,opts,callback) Mock.httpCallback=callback; return 'request' end
            ac.record(p,'protected_data','elementdata','data',4,1,{},true)
            ac.discordDrain()
            Mock.advance(16000); ac.discordDrain()
            assert(Mock.aborted)
            Mock.httpCallback('banPlayer(root)',{success=true})
            assert(Mock.bans==0 and Mock.kicks==0)
        """)

    def test_remote_extra_arguments_and_unknown_toggle_do_not_change_identity(self):
        lua = self.runtime()
        lua.execute("""
            local a,b=Mock.player(1),Mock.player(2)
            Mock.emit('utg_ac:aim',resourceRoot,a,nil,0,0,0,0,b)
            assert(AntiCheat.players[a].evidence[1].type=='event_schema')
            assert(#AntiCheat.players[b].evidence==0)
            AntiCheat.settings.detectors.eventabuse=false
            Mock.advance(11000)
            Mock.emit('utg_ac:aim',resourceRoot,a,nil,0,math.huge,0,0)
            assert(AntiCheat.players[a].combat==nil)
            assert(#AntiCheat.players[a].evidence==1)
        """)


if __name__ == "__main__":
    unittest.main(verbosity=2)
