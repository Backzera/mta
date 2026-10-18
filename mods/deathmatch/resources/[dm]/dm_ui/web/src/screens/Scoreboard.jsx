import React from 'react'
import { asArray } from '../bridge.js'
import { rgb } from '../ui.jsx'

const MEDALS = [[245, 196, 81], [200, 205, 215], [205, 127, 50]]

export default function Scoreboard({ st }) {
  const rows = asArray(st.rows)
  const shown = rows.slice(0, 18)
  return (
    <div className="board">
      <header className="board__head">
        <img src="./img/logo.png" alt="UTG" />
        <div><b>{rows.length} jogadores online · ordenado por elo</b><small>{st.server}</small></div>
      </header>
      <table>
        <thead>
          <tr><th>#</th><th>ID</th><th>TAG</th><th className="l">JOGADOR</th><th>CLÃ</th><th>ELO</th><th>RP</th><th>KILLS</th><th>MORTES</th><th>K/D</th><th>ARENA</th><th>PING</th></tr>
        </thead>
        <tbody>
          {shown.map((r, i) => (
            <tr key={r.id} className={r.me ? 'is-me' : ''} style={{ animationDelay: `${i * 25}ms` }}>
              <td>{MEDALS[i] ? <span className="medal" style={{ background: rgb(MEDALS[i]) }}>{i + 1}</span> : i + 1}</td>
              <td className="muted">{r.id}</td>
              <td>{r.tag && <span className="pill" style={{ '--c': r.tag.hex }}>{r.tag.glyph && <i>{r.tag.glyph}</i>}{r.tag.text}</span>}</td>
              <td className="l"><span style={{ color: r.me ? 'rgb(124,255,178)' : r.nameColor || '#fff' }}>{r.name}</span>{r.streak >= 3 && <span className="pill pill--danger">x{r.streak}</span>}</td>
              <td>{r.clan ? <b style={{ color: r.clan.hex }}>{r.clan.text}</b> : <span className="muted">—</span>}</td>
              <td style={{ color: rgb(r.tierColor) }}>{r.tier}</td>
              <td><b>{r.rp}</b></td><td><b>{r.kills}</b></td><td className="muted">{r.deaths}</td><td>{Number(r.kd || 0).toFixed(2)}</td>
              <td style={{ color: rgb(r.arenaColor) }}>{r.arena || ''}</td>
              <td className={r.ping < 80 ? 'is-good' : r.ping < 150 ? 'is-warn' : 'is-bad'}>{r.ping}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {rows.length > shown.length && <p className="board__more">+ {rows.length - shown.length} jogadores</p>}
      <footer className="board__foot">Solte TAB para fechar · /top rp|kills|money|duelos</footer>
    </div>
  )
}
