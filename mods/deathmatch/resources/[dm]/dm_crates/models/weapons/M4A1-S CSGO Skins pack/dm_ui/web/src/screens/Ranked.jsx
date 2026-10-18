import React from 'react'
import { toLua, asArray } from '../bridge.js'
import { Frame, Btn, Bar, Pill, rgb, rgba, useCountdown, mmss, money } from '../ui.jsx'

const TEAM = { A: [34, 230, 138], B: [255, 181, 71] }

export default function Ranked({ st }) {
  const modes = asArray(st.modes)
  return (
    <Frame title="PARTIDAS RANQUEADAS" icon="trophy.png" badge={st.me ? `${st.me.tier} · ${st.me.rp} RP` : null} badgeColor={[245, 196, 81]}
      subtitle="Melhor de 3 rounds de 5 minutos, sem respawn. Times por elo. Um sniper por time. Vitória: +RP e $. Derrota ou abandono: -RP."
      onClose={() => toLua('ranked', 'close')} width="60vw" height="auto"
      footer="F5 ou ESC fecha · sair de uma partida em andamento (F2) conta como derrota">
      <div className="modes">
        {modes.map((m, i) => {
          const need = m.teamSize * 2
          const here = st.current === m.id
          return (
            <article key={m.id} className="mode" style={{ '--c': rgb(m.color), animationDelay: `${i * 60}ms` }}>
              <div className="mode__bar" />
              <div className="mode__body">
                <h3>{m.name}</h3>
                <p>{m.place} · {m.weapons} · {need} jogadores · colete {m.armor || 0}</p>
                <small>MD3 · rounds de {Math.floor((m.roundTime || 300) / 60)} min · morte súbita se o tempo acabar{m.roles ? ' · 1 sniper por time (Sniper + M4)' : ''}</small>
                <span className="mode__status"><i className={m.waiting > 0 ? 'live' : ''} />{m.waiting} aguardando · {m.playing} jogando ({m.matches} partida{m.matches === 1 ? '' : 's'})</span>
              </div>
              <div className="mode__warm">
                <span className="eyebrow eyebrow--muted">Aquecimento</span>
                <Bar value={(m.waiting % need) / need} color={m.color} />
                <b>{m.waiting % need} / {need}</b>
              </div>
              {here ? <span className="mode__here">VOCÊ ESTÁ AQUI</span>
                : <Btn kind="primary" color={[245, 196, 81]} onClick={() => toLua('ranked', 'join', { id: m.id })}>ENTRAR</Btn>}
            </article>
          )
        })}
      </div>
    </Frame>
  )
}

// HUD da instância ranqueada (aquecimento, contagem com escolha de papel, round, morte súbita)
export function RankedHud({ s }) {
  const left = useCountdown(s.left, `${s.state}:${s.round}:${s.left}`)
  const mine = s.myTeam
  const roles = s.roles || {}
  const canPick = s.rolePick && mine
  const mySniper = mine && roles[mine] && roles[mine].sniper
  return (
    <>
      <div className={`rhud rhud--${s.state}`}>
        {s.state === 'warmup' && (
          <>
            <span className="rhud__title">AQUECIMENTO</span>
            <small>{s.players} / {s.needed} jogadores — começa quando completar</small>
            <Bar value={s.players / Math.max(1, s.needed)} color={[124, 255, 178]} />
          </>
        )}
        {s.state === 'countdown' && (
          <>
            <span className="rhud__title rhud__title--gold">A PARTIDA VAI COMEÇAR</span>
            <small><b style={{ color: rgb(TEAM.A) }}>{s.nameA}</b> vs <b style={{ color: rgb(TEAM.B) }}>{s.nameB}</b></small>
          </>
        )}
        {(s.state === 'round' || s.state === 'sudden' || s.state === 'roundEnd') && (
          <div className="rhud__match">
            <div className="rhud__team" style={{ '--c': rgb(TEAM.A) }}><span>{s.nameA}</span><b>{s.roundsA}</b><small>{s.aliveA} vivos</small></div>
            <div className="rhud__mid">
              <b className={s.state === 'sudden' ? 'is-danger' : ''}>{s.state === 'sudden' ? 'MORTE SÚBITA' : mmss(left)}</b>
              <span>ROUND {s.round} / 3 · primeiro a {s.roundsToWin}</span>
              {s.myRole && <Pill color={s.myRole === 'sniper' ? [200, 110, 255] : [124, 255, 178]}>{s.myRole === 'sniper' ? 'SNIPER + M4' : 'M4'}</Pill>}
            </div>
            <div className="rhud__team rhud__team--b" style={{ '--c': rgb(TEAM.B) }}><span>{s.nameB}</span><b>{s.roundsB}</b><small>{s.aliveB} vivos</small></div>
          </div>
        )}
        {mine && s.state !== 'warmup' && <span className={`rhud__mine rhud__mine--${mine}`}>SEU TIME</span>}
      </div>

      {s.state === 'countdown' && (
        <div className="rolepick">
          <div className="bigcount bigcount--inline" key={left}><b>{left}</b></div>
          {s.roles !== false && (
            <div className="rolepick__box">
              <span className="eyebrow">Escolha seu papel</span>
              <div className="rolepick__opts">
                <button className={`rolebtn ${s.myRole === 'sniper' ? 'is-active' : ''} ${mySniper && s.myRole !== 'sniper' ? 'is-taken' : ''}`}
                  disabled={!canPick || (mySniper && s.myRole !== 'sniper')} onClick={() => toLua('ranked', 'role', { role: 'sniper' })}>
                  <b>SNIPER</b><small>Sniper + M4</small>
                  <em>{mySniper ? `${mySniper}` : 'livre'}</em>
                </button>
                <button className={`rolebtn ${s.myRole === 'm4' ? 'is-active' : ''}`} disabled={!canPick} onClick={() => toLua('ranked', 'role', { role: 'm4' })}>
                  <b>M4</b><small>Somente M4</small>
                  <em>ilimitado</em>
                </button>
              </div>
              <p>Só um sniper por time. Se ninguém escolher, um jogador é sorteado.</p>
            </div>
          )}
        </div>
      )}
      {s.state === 'roundEnd' && s.lastRoundWinner && (
        <div className="bigscore bigscore--round" style={{ '--c': rgb(TEAM[s.lastRoundWinner]) }}>
          <b>{s.lastRoundWinner === 'A' ? s.nameA : s.nameB}</b><span>venceu o round {s.round}</span>
        </div>
      )}
      {s.state === 'sudden' && s.suddenNew && <div className="bigfight bigfight--sudden">MORTE SÚBITA</div>}
      {s.dead && (s.state === 'round' || s.state === 'sudden') && (
        <div className="deadnote"><b>VOCÊ MORREU</b><span>aguarde o fim do round · assistindo {s.spectating || 'o time'}</span></div>
      )}
    </>
  )
}

export function RankedResult({ r }) {
  const rows = asArray(r.results).slice().sort((a, b) => (b.kills || 0) - (a.kills || 0)).slice(0, 12)
  const col = r.cancelled ? [124, 255, 178] : r.draw ? [245, 196, 81] : r.won ? [34, 230, 138] : [255, 77, 109]
  return (
    <div className="result result--table" style={{ '--c': rgb(col) }}>
      <h1>{r.cancelled ? 'PARTIDA CANCELADA' : r.draw ? 'EMPATE' : r.won ? 'VITÓRIA' : 'DERROTA'}</h1>
      <p><b style={{ color: rgb(TEAM.A) }}>{r.nameA}</b> {r.roundsA} x {r.roundsB} <b style={{ color: rgb(TEAM.B) }}>{r.nameB}</b></p>
      <small>{r.cancelled ? 'Sem alteração de RP' : `${r.rp >= 0 ? '+' : ''}${r.rp} RP · +${money(r.money)} · ${r.kills} K / ${r.deaths} M${r.mvp ? ` · MVP: ${r.mvp}` : ''}`}</small>
      <table>
        <tbody>
          {rows.map((p, i) => (
            <tr key={i} style={{ animationDelay: `${i * 50}ms` }}>
              <td style={{ color: rgb(TEAM[p.team] || [255, 255, 255]) }}>{p.name === r.mvp && <img src="./img/crown.png" alt="" />}{p.name}</td>
              <td>{p.role === 'sniper' ? 'SNIPER' : p.role === 'm4' ? 'M4' : ''}</td>
              <td>{p.kills} K</td><td>{p.deaths} M</td><td>{(p.rp || 0) >= 0 ? '+' : ''}{p.rp} RP</td>
            </tr>
          ))}
        </tbody>
      </table>
      <span className="result__foot">Voltando ao aquecimento...</span>
    </div>
  )
}
