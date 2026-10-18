import React from 'react'
import { asArray } from '../bridge.js'
import { Counter, Bar, Ring, Pill, money, rgb, rgba } from '../ui.jsx'
import { DuelHud, DuelPopup, DuelResult } from './Duel.jsx'
import { RankedHud, RankedResult } from './Ranked.jsx'

function TagPill({ t }) {
  if (!t || Array.isArray(t)) return null
  return <span className="pill pill--tag" style={{ '--c': t.hex || '#7CFFB2' }}>{t.glyph && <i>{t.glyph}</i>}{t.text}</span>
}

export default function Hud({ h, feed, duelIncoming, screen }) {
  const hpc = h.health > 50 ? [34, 230, 138] : h.health > 25 ? [255, 181, 71] : [255, 77, 109]
  const arena = h.arena && !Array.isArray(h.arena) ? h.arena : null
  const showMain = h.visible && !screen && arena
  return (
    <div className="hud">
      {showMain && (
        <>
          {/* topo */}
          <div className="hud__info"><b>{h.server}</b><span>{h.online} online</span><span>{h.fps} fps</span><span className={h.ping < 80 ? 'is-good' : h.ping < 150 ? 'is-warn' : 'is-bad'}>{h.ping} ms</span></div>
          <div className="hud__arena" style={{ '--c': rgb(arena.color) }}><i />{arena.name.toUpperCase()} · {arena.players} {arena.players === 1 ? 'jogador' : 'jogadores'}</div>

          {/* status + logo (inferior esquerdo, empilhado) */}
          <div className="hud__left">
            {h.protected > 0 && !arena.safe && (
              <div className="hud__prot"><Ring value={h.protected / (h.protectedTotal || 3000)} size={18} stroke={3} color={[34, 230, 138]} />PROTEGIDO {(h.protected / 1000).toFixed(1)}s</div>
            )}
            <div className="pops">{asArray(feed.pops).map((p, i) => (
              <span key={p.id} className={p.amount > 0 ? 'is-good' : 'is-bad'} style={{ animationDelay: `${i * 30}ms` }}>{p.amount > 0 ? '+' : '-'}{money(Math.abs(p.amount))} {p.reason}</span>
            ))}</div>
            <div className="status">
              <div className="status__row">
                <TagPill t={h.clan} /><TagPill t={h.tag} />
                <span className="status__name" style={{ color: h.nameColor || '#fff' }}>{h.name}</span>
                <span className="status__tier" style={{ '--c': rgb(h.tierColor) }}>{h.tierShort}</span>
              </div>
              <div className="status__row">
                <img src="./img/coin.png" alt="" /><b className="status__money"><Counter value={h.money} format={money} dur={900} /></b>
                <span className="status__rp"><Counter value={h.rp} dur={900} /> RP · {h.tier}</span>
              </div>
              <div className="status__bar"><span>VIDA</span><b style={{ color: rgb(hpc) }}>{Math.ceil(h.health)}</b></div>
              <Bar value={h.health / 100} color={hpc} className="bar--hp" />
              <div className="status__bar"><span>COLETE</span><b>{Math.ceil(h.armor)}</b></div>
              <Bar value={h.armor / 100} color={[124, 200, 255]} className="bar--armor" />
            </div>
            <img className="hud__logo" src="./img/logo.png" alt="UTG" />
          </div>

          {/* arma */}
          <div className={`weapon ${h.skin ? 'weapon--skin' : ''}`} style={h.skin ? { '--c': h.skin.color } : undefined}>
            {h.streak >= 2 && <span className="weapon__streak"><img src="./img/flame.png" alt="" />SEQUÊNCIA x{h.streak}</span>}
            <div className="weapon__art">
              {h.skin && h.skin.preview ? <img src={`./img/wskins/${h.skin.preview}`} alt="" />
                : h.weaponIcon ? <img src={`./img/weapons/${h.weaponIcon}`} alt="" /> : <span className="weapon__noicon">{h.weapon.slice(0, 2)}</span>}
            </div>
            <div className="weapon__body">
              <span className="weapon__name">{h.weapon}</span>
              {h.skin && <span className="weapon__skin"><i>{h.skin.rarity}</i> {h.skin.name}</span>}
              {h.hasAmmo ? (
                <><div className="weapon__ammo"><b>{h.clip}</b><span>/ {h.reserve}</span></div><Bar value={h.clip / Math.max(1, h.clipSize)} color={h.skin ? h.skin.color : [34, 230, 138]} className="bar--clip" /></>
              ) : <span className="weapon__none">{arena.safe ? 'Zona segura' : 'Corpo a corpo'}</span>}
            </div>
          </div>

          {/* dicas do lobby */}
          {asArray(h.hints).length > 0 && (
            <div className="hints">{asArray(h.hints).map(([k, v]) => <span key={k}><kbd>{k}</kbd>{v}</span>)}</div>
          )}
          {h.health > 0 && h.health < 30 && !h.dead && <div className="lowhp" />}
        </>
      )}

      {/* killfeed + toasts (direita, em cima) */}
      {!screen && (
        <div className="feedcol">
          {asArray(feed.kills).map((k) => (
            <div key={k.id} className={`kill ${k.mine ? 'is-mine' : ''} ${k.me ? 'is-me' : ''}`}>
              <img src={`./img/${k.headshot ? 'headshot' : 'skull'}.png`} alt="" />
              {k.killer ? <><b className={k.mine ? 'is-good' : ''}>{k.killer}</b><i>»</i><b className={k.me ? 'is-bad' : ''}>{k.victim}</b><span>· {k.weapon}{k.headshot ? ' ✦' : ''}</span>{k.skin && !Array.isArray(k.skin) && <em className="kill__skin" style={{ '--c': k.skin.color }}>{k.skin.name}</em>}</>
                : <><b>{k.victim}</b><span>morreu · {k.weapon}</span></>}
            </div>
          ))}
          {asArray(feed.toasts).map((t) => (
            <div key={t.id} className={`toast toast--${t.type || 'info'}`}>
              <i>{{ success: '+', error: '×', warn: '!' }[t.type] || 'i'}</i>
              <div>{t.title && <b>{t.title}</b>}<span>{t.text}</span></div>
              <em />
            </div>
          ))}
        </div>
      )}

      {/* feedback central de kill, sequência, duelo, ranqueada */}
      {!screen && (
        <>
          <div className="rewards">{asArray(feed.rewards).map((r) => (
            <div key={r.id} className={`reward ${r.headshot ? 'is-hs' : ''}`}>
              <img src={`./img/${r.headshot ? 'headshot' : 'skull'}.png`} alt="" /><b>{r.headshot ? 'HEADSHOT!' : 'ELIMINADO'}</b><span>{r.text}{r.money > 0 ? ` +${money(r.money)}` : ''}</span>
            </div>
          ))}</div>
          {feed.streak && <div className="streak"><img src="./img/flame.png" alt="" /><b>{feed.streak.streak}</b><span>{feed.streak.name} {feed.streak.text}</span></div>}
          {h.duel && !Array.isArray(h.duel) && <DuelHud d={h.duel} />}
          {!h.duel && asArray(duelIncoming).length > 0 && <DuelPopup incoming={asArray(duelIncoming)} />}
          {feed.duelResult && <DuelResult r={feed.duelResult} />}
          {h.ranked && !Array.isArray(h.ranked) && h.visible && <RankedHud s={h.ranked} />}
          {feed.rankedResult && <RankedResult r={feed.rankedResult} />}
        </>
      )}
    </div>
  )
}
