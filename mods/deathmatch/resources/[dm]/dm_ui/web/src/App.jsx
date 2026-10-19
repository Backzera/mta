import React, { useEffect, useState } from 'react'
import { subscribe, toLua, asArray } from './bridge.js'
import Background from './Background.jsx'
import Hub from './screens/Hub.jsx'
import Shop from './screens/Shop.jsx'
import Duel from './screens/Duel.jsx'
import Ranked from './screens/Ranked.jsx'
import Clans from './screens/Clans.jsx'
import Crates from './screens/Crates.jsx'
import Characters from './screens/Characters.jsx'
import Crosshair from './screens/Crosshair.jsx'
import Scoreboard from './screens/Scoreboard.jsx'
import Help from './screens/Help.jsx'
import Login from './screens/Login.jsx'
import Hud from './screens/Hud.jsx'

// Eventos do HUD/toasts não precisam reconstruir o menu nem seus listeners.
const Panel = React.memo(function Panel({ screen, data, reel, server }) {
  if (screen === 'help') return <Help server={server} />
  if (screen === 'clans') return <Clans st={data} />
  if (screen === 'login') return <Login st={data} />
  if (!data) return null
  const screens = { hub: Hub, shop: Shop, duel: Duel, ranked: Ranked, characters: Characters, crosshair: Crosshair, board: Scoreboard }
  if (screen === 'crates') return <Crates st={data} reel={reel} />
  const Component = screens[screen]
  return Component ? <Component st={data} /> : null
})

export default function App() {
  const [st, setSt] = useState(() => ({}))
  useEffect(() => { toLua('app', 'mounted', { build: typeof __BUILD__ !== 'undefined' ? __BUILD__ : '?' }); return subscribe(setSt) }, [])
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
      {bg && <div className={`scene scene--${screen}`}><Background strength={screen === 'login' ? 1.3 : 1} /></div>}
      <div className={`screen ${screen ? 'is-open' : ''}`} key={screen || 'none'}>
        <Panel screen={screen} data={st[screen]} reel={screen === 'crates' ? feed.reel : null} server={hud && hud.server} />
      </div>
      {hud && <Hud h={hud} feed={feed} duelIncoming={st.duel ? st.duel.incoming : []} screen={screen} />}
    </>
  )
}
