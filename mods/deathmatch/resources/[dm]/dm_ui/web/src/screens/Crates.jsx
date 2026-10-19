import React, { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { toLua, asArray, asObj } from '../bridge.js'
import { Frame, Btn, Tabs, Counter, Empty, Pill, rgb, rgba, money } from '../ui.jsx'

const GOLD = [245, 196, 81]
export const RARITY_ORDER = ['comum', 'rara', 'epica', 'lendaria', 'mitica', 'ultimate']

export function ItemCard({ it, rar, selected, children, className = '' }) {
  const rc = rar.color
  const art = it.preview ? `./img/${it.preview}` : it.type === 'wskin' && it.texture ? `./img/wskins/${it.texture}` : null
  return (
    <div className={`item item--${it.rarity} ${selected ? 'is-selected' : ''} ${className}`} style={{ '--c': rgb(rc) }}>
      <div className={`item__art ${it.preview ? 'item__art--icon' : ''} ${it.type === 'skin' ? 'item__art--ped' : ''}`}>
        {art ? <img src={art} alt="" /> : <img className="item__icon" src={`./img/${it.type === 'skin' ? 'shield.png' : 'coin.png'}`} alt="" />}
      </div>
      <b>{it.name}</b>
      <small>{rar.name.toUpperCase()}{it.weaponLabel && it.weapon !== 'all' ? ` · ${it.weaponLabel}` : ''}</small>
      {children}
    </div>
  )
}

export default function Crates({ st, reel }) {
  const d = st || {}
  const rarities = asObj(d.rarities), items = asArray(d.items), boxes = asArray(d.boxes), owned = asArray(d.owned)
  const item = (k) => items.find((i) => i.key === k)
  const rar = (it) => rarities[it.rarity] || rarities.comum || { name: 'Comum', color: [150, 165, 155] }
  const [tab, setTab] = useState('boxes')
  const bal = d.money || 0
  const inv = items.filter((i) => i.type === 'wskin' && owned.includes(i.key)).sort((a, b) => RARITY_ORDER.indexOf(b.rarity) - RARITY_ORDER.indexOf(a.rarity))
  const eqW = asObj(d.equippedW)

  return (
    <Frame title="CAIXAS" subtitle="Abra caixas com $ e ganhe skins exclusivas, skins de arma e dinheiro. Itens repetidos devolvem metade do valor." icon="trophy.png"
      badge={<>SALDO <Counter value={bal} format={money} dur={800} /></>} badgeColor={GOLD} onClose={() => toLua('crates', 'close')} width="66vw" height="74vh"
      footer="F7 ou ESC fecha · armas no inventário · personagens no F10 · itens salvos na sua conta">
      <Tabs tabs={[['boxes', 'CAIXAS'], ['inv', 'MEU INVENTÁRIO']]} value={tab} onChange={setTab} />
      {tab === 'boxes' ? (
        <div className={`boxes ${boxes.length === 4 ? 'boxes--four' : ''}`}>
          {boxes.map((b, i) => {
            const total = asArray(b.pool).reduce((s, p) => s + p.weight, 0)
            const byR = {}
            for (const p of asArray(b.pool)) { const it = item(p.item); if (it) byR[it.rarity] = (byR[it.rarity] || 0) + p.weight }
            return (
              <article key={b.key} className="box" style={{ '--c': rgb(b.color), animationDelay: `${i * 70}ms` }}>
                <div className="box__glow" />
                <img className="box__icon" src={`./img/${b.icon || 'trophy.png'}`} alt="" />
                <h3>{b.name}</h3>
                <p>{b.desc}</p>
                <div className="box__odds">
                  {RARITY_ORDER.filter((r) => byR[r]).map((r) => <Pill key={r} color={(rarities[r] || {}).color}>{(rarities[r] || {}).name} {((byR[r] / total) * 100).toLocaleString('pt-BR', { maximumFractionDigits: 2 })}%</Pill>)}
                </div>
                <Btn kind="primary" color={GOLD} disabled={bal < b.price || !!reel || !!d.opening} onClick={() => toLua('crates', 'open', { box: b.key })}>{d.opening === b.key ? 'ABRINDO...' : <>ABRIR · {money(b.price)}</>}</Btn>
              </article>
            )
          })}
        </div>
      ) : (
        <div className="inv">
          {inv.length === 0 && <Empty>Você ainda não tem skins de armas. Abra uma caixa!</Empty>}
          <div className="inv__grid">
            {inv.map((it) => {
              const eq = eqW[it.weapon || 'all'] === it.key
              return (
                <ItemCard key={it.key} it={it} rar={rar(it)} selected={eq}>
                  <Btn kind={eq ? 'ghost' : 'outline'} onClick={() => toLua('crates', 'equip', { key: it.key })}>{eq ? 'EQUIPADA ✓' : 'EQUIPAR'}</Btn>
                </ItemCard>
              )
            })}
          </div>
          {d.hasTrail && <TrailPicker value={d.trail} />}
          <div className="hrow">
            <Btn kind="ghost" onClick={() => toLua('crates', 'characters')}>PERSONAGENS · F10</Btn>
            <Btn kind="ghost" onClick={() => toLua('crates', 'equip', { key: 'wskin:none' })}>ARMAS PADRÃO</Btn>
            <span className="hint">Uma skin por arma (AK-47, M4, outras). Clique na skin equipada para remover.</span>
          </div>
        </div>
      )}
      {reel && <Reel reel={reel} item={item} rar={rar} />}
    </Frame>
  )
}

const TRAIL_COLORS = ['#FF4A1E', '#FF8C32', '#F5C451', '#22E68A', '#7CC8FF', '#4D6BFF', '#C76BFF', '#FF4D9D', '#FFFFFF']
// Cor do rastro da ponta da arma (skins Mítica/Ultimate): cor da skin, cores fixas ou RGB
function TrailPicker({ value }) {
  const pick = (v) => toLua('crates', 'trail', { value: v })
  return (
    <div className="trail">
      <span className="eyebrow">Rastro da ponta da arma <small>(skins Mítica e Ultimate)</small></span>
      <div className="trail__opts">
        <button className={`trail__sw trail__sw--skin ${!value ? 'is-active' : ''}`} onClick={() => pick('skin')} title="Cor da skin">SKIN</button>
        {TRAIL_COLORS.map((c) => <button key={c} className={`trail__sw ${value === c ? 'is-active' : ''}`} style={{ background: c, boxShadow: `0 0 .8vw ${c}88` }} onClick={() => pick(c)} />)}
        <button className={`trail__sw trail__sw--rgb ${value === 'rgb' ? 'is-active' : ''}`} onClick={() => pick('rgb')} title="RGB (arco-íris)">RGB</button>
      </div>
    </div>
  )
}

function Reel({ reel, item, rar }) {
  const keys = asArray(reel.items)
  const target = reel.target || 34
  const trackRef = useRef(null)
  const [tx, setTx] = useState(null)
  const [done, setDone] = useState(false)
  useEffect(() => {
    setTx(null); setDone(false)
    // posição final medida no DOM: centro da carta alvo alinhado com a agulha (50% da tela)
    const a = setTimeout(() => {
      const el = trackRef.current && trackRef.current.children[target - 1]
      if (el) setTx(window.innerWidth / 2 - (el.offsetLeft + el.offsetWidth / 2))
    }, 80)
    const b = setTimeout(() => setDone(true), 5500)
    return () => { clearTimeout(a); clearTimeout(b) }
  }, [reel.id])
  const result = item(reel.result)
  const start = `translateX(calc(50vw - 4.5vw))`
  return createPortal(
    <div className="reel">
      <div ref={trackRef} className="reel__track" style={{ transform: tx === null ? start : `translateX(${tx}px)`, transition: tx === null ? 'none' : 'transform 5.2s cubic-bezier(.12,.9,.14,1)' }}>
        {keys.map((k, i) => { const it = item(k); return it ? <ItemCard key={i} it={it} rar={rar(it)} selected={done && i === target - 1} className="item--reel" /> : null })}
      </div>
      <div className="reel__needle" />
      {done && result && (
        <div className="reel__done" style={{ '--c': rgb(rar(result).color) }}>
          <h2>{reel.duplicate ? 'REPETIDO — metade do valor devolvida' : `VOCÊ GANHOU: ${result.name.toUpperCase()}`}</h2>
          <Btn kind="primary" color={GOLD} onClick={() => toLua('crates', 'reelClose')}>CONTINUAR</Btn>
        </div>
      )}
    </div>,
    document.body
  )
}
