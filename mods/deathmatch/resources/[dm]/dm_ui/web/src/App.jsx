import React, { useEffect, useState } from 'react'
import { subscribe, toLua, asArray } from './bridge.js'
import Background from './Background.jsx'
import Hub from './screens/Hub.jsx'
import Shop from './screens/Shop.jsx'
import Duel from './screens/Duel.jsx'
import Ranked from './screens/Ranked.jsx'
import Clans from './screens/Clans.jsx'
import Crates from './screens/Crates.jsx'
import Scoreboard from './screens/Scoreboard.jsx'
import Help from './screens/Help.jsx'
import Login from './screens/Login.jsx'
import Hud from './screens/Hud.jsx'

export default function App() {
  const [st, setSt] = useState(() => ({}))
  useEffect(() => { toLua('app', 'mounted'); return subscribe(setSt) }, [])
  const screen = st.screen
  const hud = st.hud && !Array.isArray(st.hud) ? st.hud : null
  const feed = st.feed || {}

  // ESC fecha qualquer tela (o Lua também trata, por segurança)
  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape' && screen && screen !== 'board' && screen !== 'login') toLua(screen, 'close') }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [screen])

  const bg = screen && screen !== 'board'
  return (
    <>
      {bg && <div className={`scene scene--${screen}`}><Background strength={screen === 'login' ? 1.3 : 1} /><div className="scene__grain" /></div>}
      <div className={`screen ${screen ? 'is-open' : ''}`} key={screen || 'none'}>
        {screen === 'hub' && st.hub && <Hub st={st.hub} />}
        {screen === 'shop' && st.shop && <Shop st={st.shop} />}
        {screen === 'duel' && st.duel && <Duel st={st.duel} />}
        {screen === 'ranked' && st.ranked && <Ranked st={st.ranked} />}
        {screen === 'clans' && <Clans st={st.clans} />}
        {screen === 'crates' && st.crates && <Crates st={st.crates} reel={feed.reel} />}
        {screen === 'board' && st.board && <Scoreboard st={st.board} />}
        {screen === 'help' && <Help server={hud && hud.server} />}
        {screen === 'login' && <Login st={st.login} />}
      </div>
      {hud && <Hud h={hud} feed={feed} duelIncoming={st.duel ? st.duel.incoming : []} screen={screen} />}
    </>
  )
}
