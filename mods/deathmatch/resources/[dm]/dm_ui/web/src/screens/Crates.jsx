import React, { useEffect, useState } from 'react'
import { toLua, asArray, asObj } from '../bridge.js'
import { Frame, Btn, Tabs, Counter, Empty, Pill, rgb, rgba, money } from '../ui.jsx'

const GOLD = [245, 196, 81]
const RARITY_ORDER = ['comum', 'rara', 'epica', 'lendaria']

function ItemCard({ it, rar, selected, children, className = '' }) {
  const rc = rar.color
  return (
    <div className={`item ${selected ? 'is-selected' : ''} ${className}`} style={{ '--c': rgb(rc) }}>
      <div className="item__art">
        {it.type === 'wskin' && it.texture ? <img src={`./img/wskins/${it.texture}`} alt="" />
          : <img className="item__icon" src={`./img/${it.type === 'skin' ? 'shield.png' : 'coin.png'}`} alt="" />}
      </div>
      <b>{it.name}</b>
      <small>{rar.name.toUpperCase()}</small>
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
  const inv = items.filter((i) => i.type !== 'money' && owned.includes(i.key))

  return (
    <Frame title="CAIXAS" subtitle="Abra caixas com $ e ganhe skins exclusivas, skins de arma e dinheiro. Itens repetidos devolvem metade do valor." icon="trophy.png"
      badge={<>SALDO <Counter value={bal} format={money} dur={800} /></>} badgeColor={GOLD} onClose={() => toLua('crates', 'close')} width="66vw" height="74vh"
      footer="F7 ou ESC fecha · skins de arma são texturas por jogador · skins exclusivas ficam salvas na sua conta">
      <Tabs tabs={[['boxes', 'CAIXAS'], ['inv', 'MEU INVENTÁRIO']]} value={tab} onChange={setTab} />
      {tab === 'boxes' ? (
        <div className="boxes">
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
                  {RARITY_ORDER.filter((r) => byR[r]).map((r) => <Pill key={r} color={(rarities[r] || {}).color}>{(rarities[r] || {}).name} {Math.round((byR[r] / total) * 100)}%</Pill>)}
                </div>
                <Btn kind="primary" color={GOLD} disabled={bal < b.price || !!reel} onClick={() => toLua('crates', 'open', { box: b.key })}>ABRIR · {money(b.price)}</Btn>
              </article>
            )
          })}
        </div>
      ) : (
        <div className="inv">
          {inv.length === 0 && <Empty>Você ainda não tem itens. Abra uma caixa!</Empty>}
          <div className="inv__grid">
            {inv.map((it) => {
              const eq = (it.type === 'skin' && d.equippedSkin === it.model) || (it.type === 'wskin' && d.equippedW === it.key)
              return (
                <ItemCard key={it.key} it={it} rar={rar(it)} selected={eq}>
                  <Btn kind={eq ? 'ghost' : 'outline'} disabled={eq} onClick={() => toLua('crates', 'equip', { key: it.key })}>{eq ? 'EQUIPADO' : 'EQUIPAR'}</Btn>
                </ItemCard>
              )
            })}
          </div>
          <div className="hrow">
            <Btn kind="ghost" onClick={() => toLua('crates', 'equip', { key: 'skin:none' })}>SKIN PADRÃO</Btn>
            <Btn kind="ghost" onClick={() => toLua('crates', 'equip', { key: 'wskin:none' })}>ARMA PADRÃO</Btn>
          </div>
        </div>
      )}
      {reel && <Reel reel={reel} item={item} rar={rar} />}
    </Frame>
  )
}

function Reel({ reel, item, rar }) {
  const keys = asArray(reel.items)
  const target = reel.target || 34
  const [go, setGo] = useState(false)
  const [done, setDone] = useState(false)
  useEffect(() => { const a = setTimeout(() => setGo(true), 60); const b = setTimeout(() => setDone(true), 5400); return () => { clearTimeout(a); clearTimeout(b) } }, [reel.id])
  const result = item(reel.result)
  const cardW = 9, gap = 0.6 // vw
  const offset = (target - 1) * (cardW + gap)
  return (
    <div className="reel">
      <div className="reel__track" style={{ transform: `translateX(calc(50vw - ${cardW / 2}vw - ${go ? offset : 0}vw))`, transition: go ? 'transform 5.2s cubic-bezier(.12,.9,.14,1)' : 'none' }}>
        {keys.map((k, i) => { const it = item(k); return it ? <ItemCard key={i} it={it} rar={rar(it)} selected={done && i === target - 1} className="item--reel" /> : null })}
      </div>
      <div className="reel__needle" />
      {done && result && (
        <div className="reel__done" style={{ '--c': rgb(rar(result).color) }}>
          <h2>{reel.duplicate ? 'REPETIDO — metade do valor devolvida' : `VOCÊ GANHOU: ${result.name.toUpperCase()}`}</h2>
          <Btn kind="primary" color={GOLD} onClick={() => toLua('crates', 'reelClose')}>CONTINUAR</Btn>
        </div>
      )}
    </div>
  )
}
