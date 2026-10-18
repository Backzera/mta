import React, { useState } from 'react'
import { toLua, asArray, asObj } from '../bridge.js'
import { Frame, Btn, Counter, Empty, Pill, rgb, rgba, money } from '../ui.jsx'

const ROLE = { leader: 'LÍDER', officer: 'OFICIAL', member: 'MEMBRO' }
const GOLD = [245, 196, 81]

function Ranking({ clans, selected, onSelect, myId }) {
  return (
    <div className="ranking">
      <span className="eyebrow">Ranking de clãs</span>
      {clans.length === 0 && <Empty>Nenhum clã ainda. Seja o primeiro!</Empty>}
      <ul>
        {clans.slice(0, 10).map((c, i) => (
          <li key={c.id} className={`ranking__row ${selected === c.id ? 'is-selected' : ''} ${myId === c.id ? 'is-mine' : ''}`} onClick={() => onSelect && onSelect(c.id)} style={{ animationDelay: `${i * 35}ms` }}>
            <span className="ranking__pos">#{i + 1}</span>
            <b style={{ color: rgb(c.color) }}>[{c.tag}]</b>
            <span className="ranking__name">{c.name}</span>
            <small>{c.points} pts · {c.wins}V {c.losses}D · {c.online} on</small>
          </li>
        ))}
      </ul>
    </div>
  )
}

export default function Clans({ st }) {
  const d = st || {}
  const clan = d.clan && !Array.isArray(d.clan) ? d.clan : null
  const clans = asArray(d.clans), invites = asArray(d.invites), modes = asArray(d.modes), candidates = asArray(d.candidates), palette = asArray(d.palette)
  const [name, setName] = useState('')
  const [tag, setTag] = useState('')
  const [selClan, setSelClan] = useState(null)
  const [modeId, setModeId] = useState(modes[0] ? modes[0].id : null)
  const [inviteId, setInviteId] = useState(candidates[0] ? candidates[0].id : null)
  const bal = d.money || 0
  const close = () => toLua('clans', 'close')

  if (!d.loaded) return <Frame title="CLÃS" subtitle="Carregando..." icon="shield.png" onClose={close} width="62vw" height="70vh"><Empty>Carregando...</Empty></Frame>

  if (!clan) {
    const can = bal >= (d.createCost || 0)
    const inv = invites[0]
    return (
      <Frame title="CLÃS" subtitle={`Crie o seu clã (${money(d.createCost || 0)}) ou aceite um convite.`} icon="shield.png" onClose={close} width="62vw" height="70vh"
        footer="F6 ou ESC fecha · /cla criar <TAG> <nome> · /c <mensagem> fala no chat do clã">
        <div className="clans clans--none">
          <div className="clans__left">
            <span className="eyebrow">Criar clã</span>
            <div className="hrow">
              <input className="input input--tag" placeholder="TAG" maxLength={5} value={tag} onChange={(e) => setTag(e.target.value.replace(/[^A-Za-z0-9]/g, '').toUpperCase())} />
              <input className="input" placeholder="Nome do clã (3-20)" maxLength={20} value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <Btn kind="primary" disabled={!can || tag.length < 2 || name.length < 3} onClick={() => toLua('clans', 'create', { name, tag })}>FUNDAR CLÃ · {money(d.createCost || 0)}</Btn>
            {!can && <p className="hint hint--bad">Saldo insuficiente — kills, duelos e ranqueadas dão $.</p>}
            <span className="eyebrow eyebrow--gold" style={{ marginTop: '1.4vw' }}>Convites</span>
            {!inv ? <Empty>Nenhum convite pendente.</Empty> : (
              <div className="invite">
                <b>[{inv.tag}] {inv.name}</b><small>Convidado por {inv.from}</small>
                <div className="hrow">
                  <Btn kind="primary" color={GOLD} onClick={() => toLua('clans', 'respondInvite', { accept: true })}>Aceitar</Btn>
                  <Btn kind="outline" color={[255, 77, 109]} onClick={() => toLua('clans', 'respondInvite', { accept: false })}>Recusar</Btn>
                </div>
              </div>
            )}
          </div>
          <Ranking clans={clans} selected={selClan} onSelect={setSelClan} />
        </div>
      </Frame>
    )
  }

  const isLeader = clan.role === 'leader', isOfficer = isLeader || clan.role === 'officer'
  const members = asArray(clan.members)
  const ch = clan && d.challenge && !Array.isArray(d.challenge) ? d.challenge : null
  const target = clans.find((c) => c.id === selClan)
  const okChallenge = isOfficer && target && target.id !== clan.id && modeId
  return (
    <Frame title="MEU CLÃ" subtitle="Convide jogadores, suba no ranking e dispute clã x clã nas ranqueadas." icon="shield.png" onClose={close} width="64vw" height="74vh"
      footer="F6 ou ESC fecha · /cla criar <TAG> <nome> · /c <mensagem> fala no chat do clã">
      <div className="clans">
        <header className="clanhead" style={{ '--c': rgb(clan.color) }}>
          <b className="clanhead__tag">[{clan.tag}]</b>
          <div className="clanhead__name"><h3>{clan.name}</h3><small>você é {ROLE[clan.role] || clan.role}</small></div>
          <div className="clanhead__stats">
            <div><span>PONTOS</span><b style={{ color: rgb(GOLD) }}><Counter value={clan.points} /></b></div>
            <div><span>VITÓRIAS</span><b className="is-good">{clan.wins}</b></div>
            <div><span>DERROTAS</span><b className="is-bad">{clan.losses}</b></div>
          </div>
        </header>
        <div className="clans__cols">
          <div className="clans__left">
            <span className="eyebrow">Membros ({members.length})</span>
            <ul className="members">
              {members.map((m) => (
                <li key={m.name} className={m.online ? 'is-online' : ''}>
                  <i /><span className="members__name">{m.name}</span>
                  <small style={m.role === 'leader' ? { color: rgb(GOLD) } : undefined}>{ROLE[m.role] || 'MEMBRO'} · {m.rp || 0} RP</small>
                  {isOfficer && m.role !== 'leader' && m.name !== d.myName && (
                    <span className="members__acts">
                      {isLeader && m.online && <button title={m.role === 'officer' ? 'Rebaixar' : 'Promover a oficial'} onClick={() => toLua('clans', 'promote', { name: m.name })}>{m.role === 'officer' ? '–' : '+'}</button>}
                      <button title="Expulsar" onClick={() => toLua('clans', 'kick', { name: m.name })}>×</button>
                    </span>
                  )}
                </li>
              ))}
            </ul>
            <span className="eyebrow">Convidar</span>
            {isOfficer ? (
              <div className="hrow">
                <select className="input" value={inviteId || ''} onChange={(e) => setInviteId(Number(e.target.value))}>
                  {candidates.length === 0 && <option value="">ninguém disponível</option>}
                  {candidates.map((c) => <option key={c.id} value={c.id}>{c.name} (#{c.id})</option>)}
                </select>
                <Btn kind="primary" disabled={!inviteId} onClick={() => toLua('clans', 'invite', { id: inviteId })}>CONVIDAR</Btn>
              </div>
            ) : <p className="hint">Só líder e oficiais convidam.</p>}
            <Btn kind="outline" color={[255, 77, 109]} className="clans__leave" onClick={() => toLua('clans', 'leave')}>{isLeader ? 'SAIR / PASSAR LIDERANÇA' : 'SAIR DO CLÃ'}</Btn>
          </div>
          <div className="clans__right">
            <span className="eyebrow eyebrow--gold">Clã x clã</span>
            {ch ? (
              <div className="invite invite--gold">
                <b>[{ch.fromTag}] {ch.fromName} desafiou vocês</b><small>{(modes.find((m) => m.id === ch.modeId) || {}).name || ch.modeId}</small>
                {isOfficer ? (
                  <div className="hrow">
                    <Btn kind="primary" color={GOLD} onClick={() => toLua('clans', 'respondChallenge', { accept: true })}>ACEITAR</Btn>
                    <Btn kind="outline" color={[255, 77, 109]} onClick={() => toLua('clans', 'respondChallenge', { accept: false })}>RECUSAR</Btn>
                  </div>
                ) : <p className="hint">Aguardando o líder/oficiais responderem.</p>}
              </div>
            ) : (
              <>
                <div className="chips">
                  {modes.map((m) => <button key={m.id} className={`chipbtn chipbtn--gold ${modeId === m.id ? 'is-active' : ''}`} onClick={() => setModeId(m.id)}>{m.name}</button>)}
                </div>
                <Btn kind="primary" color={GOLD} disabled={!okChallenge} onClick={() => okChallenge && toLua('clans', 'challenge', { clanId: target.id, modeId })}>
                  {okChallenge ? `DESAFIAR [${target.tag}]` : 'SELECIONE UM CLÃ NO RANKING'}
                </Btn>
                <p className="hint">Mínimo {d.minClanMatch || 2} por lado · times = menor clã online · vitória +30 pts</p>
              </>
            )}
            <Ranking clans={clans} selected={selClan} onSelect={setSelClan} myId={clan.id} />
            {isLeader && (
              <div className="palette">
                <span className="eyebrow eyebrow--muted">Cor da tag</span>
                <div>{palette.map((c, i) => <button key={i} style={{ background: rgb(c), boxShadow: `0 0 10px ${rgba(c, .5)}` }} onClick={() => toLua('clans', 'setColor', { idx: i + 1 })} />)}</div>
              </div>
            )}
          </div>
        </div>
      </div>
    </Frame>
  )
}
