import React, { useEffect, useMemo, useState } from 'react'
import { toLua, asArray } from '../bridge.js'
import { Frame, Btn, Pill, Ring, Empty, rgb, useCountdown } from '../ui.jsx'

export default function Duel({ st }) {
  const players = asArray(st.players), sets = asArray(st.sets), incoming = asArray(st.incoming)
  const [q, setQ] = useState('')
  const [selId, setSelId] = useState(st.selectedId || null)
  const [weapon, setWeapon] = useState(sets[0] ? sets[0].key : 'deagle')
  const [rounds, setRounds] = useState(3)
  useEffect(() => { if (st.selectedId) setSelId(st.selectedId) }, [st.selectedId])

  const list = useMemo(() => players.filter((p) => !q || p.name.toLowerCase().includes(q.toLowerCase())), [players, q])
  const target = players.find((p) => p.id === selId)
  const setSel = sets.find((s) => s.key === weapon)
  const outgoing = st.outgoing || null
  const outLeft = useCountdown(outgoing ? outgoing.left : 0, outgoing && outgoing.id)
  const canSend = target && !outgoing && !st.inDuel

  return (
    <Frame title="DUELO X1" subtitle="Desafie alguém para um 1v1 em sala privada. Vitória dá RP e $." icon="swords.png"
      badge={outgoing ? 'AGUARDANDO RESPOSTA' : incoming.length ? `${incoming.length} PEDIDO${incoming.length > 1 ? 'S' : ''}` : null}
      badgeColor={outgoing ? [255, 181, 71] : [245, 196, 81]} onClose={() => toLua('duel', 'close')} width="66vw" height="72vh"
      footer={<>F3 ou ESC fecha · /duelo &lt;jogador&gt; · <kbd>Y</kbd> aceita · <kbd>N</kbd> recusa</>}>
      <div className="duel">
        <div className="duel__col">
          <span className="eyebrow">Jogadores</span>
          <input className="input" placeholder="Buscar jogador..." value={q} onChange={(e) => setQ(e.target.value)} maxLength={20} />
          <ul className="plist">
            {list.length === 0 && <Empty>{q ? 'Nenhum jogador encontrado.' : 'Nenhum outro jogador online.'}</Empty>}
            {list.map((p, i) => (
              <li key={p.id} className={`plist__row ${p.id === selId ? 'is-selected' : ''}`} style={{ animationDelay: `${i * 30}ms` }} onClick={() => setSelId(p.id)}>
                <Pill color={p.tierColor}>{p.tierShort}</Pill>
                <span className="plist__name">{p.name}</span>
                <span className="plist__id">#{p.id}</span>
                {p.inDuel && <span className="plist__flag">EM DUELO</span>}
              </li>
            ))}
          </ul>
        </div>
        <div className="duel__col">
          <span className="eyebrow">Arma</span>
          <div className="chips chips--grid">
            {sets.map((s) => (
              <button key={s.key} className={`chipbtn ${weapon === s.key ? 'is-active' : ''}`} onClick={() => setWeapon(s.key)}>{s.name}</button>
            ))}
          </div>
        </div>
        <div className="duel__col">
          <span className="eyebrow">Primeiro a</span>
          <div className="seg">
            {[1, 3, 5].map((n) => <button key={n} className={`seg__btn ${rounds === n ? 'is-active' : ''}`} onClick={() => setRounds(n)}>{n}</button>)}
          </div>
          <div className="summary">
            <span className="eyebrow eyebrow--muted">Resumo</span>
            <b>Você <i>vs</i> {target ? target.name : '—'}</b>
            <small>{setSel ? setSel.name : '?'} · primeiro a {rounds}</small>
          </div>
          <Btn kind="primary" disabled={!canSend} onClick={() => canSend && toLua('duel', 'request', { id: target.id, weapon, rounds })}>
            {outgoing ? 'AGUARDANDO RESPOSTA...' : 'ENVIAR DESAFIO'}
          </Btn>
          {outgoing && (
            <div className="outgoing">
              <Ring value={outLeft / Math.max(1, outgoing.ttl)} size={28} stroke={3} color={[255, 181, 71]} />
              <span>{outgoing.target} · {outgoing.weapon} · {outLeft}s</span>
              <button className="link" onClick={() => toLua('duel', 'cancel', { id: outgoing.id })}>Cancelar</button>
            </div>
          )}
          <span className="eyebrow eyebrow--gold" style={{ marginTop: '1.2vw' }}>Pedidos recebidos ({incoming.length})</span>
          {incoming.length === 0 && <Empty>Nenhum pedido no momento.</Empty>}
          {incoming.slice(0, 2).map((r) => <Incoming key={r.id} r={r} />)}
        </div>
      </div>
    </Frame>
  )
}

function Incoming({ r, compact }) {
  const left = useCountdown(r.left, r.id)
  return (
    <div className={`incoming ${compact ? 'incoming--popup' : ''}`}>
      <Ring value={left / Math.max(1, r.ttl)} size={compact ? 44 : 30} stroke={3} color={[245, 196, 81]} />
      <div className="incoming__body">
        {compact && <span className="eyebrow eyebrow--gold">Desafio de duelo</span>}
        <b>{r.from}</b>
        <small>{r.weapon} · primeiro a {r.rounds}</small>
      </div>
      <div className="incoming__btns">
        <Btn kind="primary" color={[245, 196, 81]} onClick={() => toLua('duel', 'respond', { id: r.id, accept: true })}>ACEITAR{compact && <kbd>Y</kbd>}</Btn>
        <Btn kind="outline" color={[255, 77, 109]} onClick={() => toLua('duel', 'respond', { id: r.id, accept: false })}>RECUSAR{compact && <kbd>N</kbd>}</Btn>
      </div>
    </div>
  )
}

// Popup no topo (painel fechado) com o primeiro pedido
export function DuelPopup({ incoming }) {
  const r = incoming[0]
  if (!r) return null
  return (
    <div className="duelpop">
      <Incoming r={r} compact />
      {incoming.length > 1 && <span className="duelpop__more">+{incoming.length - 1}</span>}
    </div>
  )
}

// HUD do duelo em andamento
export function DuelHud({ d }) {
  const left = useCountdown(d.left, `${d.round}:${d.state}`)
  return (
    <>
      <div className="dhud">
        <div className="dhud__side dhud__side--me"><span>{d.me_name}</span><b>{d.me}</b></div>
        <div className="dhud__mid"><span>RODADA {d.round}</span><small>{d.weapon} · primeiro a {d.target}</small></div>
        <div className="dhud__side dhud__side--opp"><span>{d.opponent}</span><b>{d.opp}</b></div>
      </div>
      {d.state === 'countdown' && left > 0 && (
        <div className="bigcount" key={left}><b>{left}</b><span>PREPARE-SE</span></div>
      )}
      {d.state === 'fight' && <div className="bigfight">LUTE!</div>}
      {d.state === 'between' && <div className="bigscore">{d.me} <i>x</i> {d.opp}</div>}
    </>
  )
}

export function DuelResult({ r }) {
  const sub = r.reason === 'forfeit' ? (r.won ? 'O oponente abandonou o duelo (W.O.)' : 'Você abandonou o duelo')
    : r.won ? `+${r.rp} RP · +$${r.money}` : `${r.rp} RP · mais sorte na próxima!`
  return (
    <div className={`result ${r.won ? 'result--win' : 'result--loss'}`}>
      <h1>{r.won ? 'VITÓRIA' : 'DERROTA'}</h1>
      <p>{r.me} x {r.opp} contra {r.opponent}</p>
      <small>{sub}</small>
      <span className="result__foot">Voltando para a arena...</span>
    </div>
  )
}
