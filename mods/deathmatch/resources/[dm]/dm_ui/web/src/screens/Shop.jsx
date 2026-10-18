import React, { useEffect, useState } from 'react'
import { toLua, asArray } from '../bridge.js'
import { Counter, money, rgb, rgba, Btn } from '../ui.jsx'

const ICONS = { tags: 'tag.png', nameColors: 'target.png', vip: 'crown.png', extras: 'shield.png' }

function Product({ p, money: bal, confirm, setConfirm }) {
  const locked = p.state === 'buy' && bal < p.price
  const confirming = confirm === p.id
  const act = () => {
    if (p.state === 'buy') {
      if (confirming) { setConfirm(null); toLua('shop', 'buy', { cat: p.cat, key: p.key }) }
      else { setConfirm(p.id); setTimeout(() => setConfirm((c) => (c === p.id ? null : c)), 4000) }
    } else if (p.state === 'owned') toLua('shop', 'buy', { cat: p.cat, key: p.key })
  }
  return (
    <article className={`product ${p.state === 'equipped' ? 'is-equipped' : ''} ${locked ? 'is-locked' : ''}`} style={{ '--c': rgb(p.color) }}>
      <div className="product__band">
        <h3>{p.title}</h3>
        {p.badge && <span className="product__badge">{p.badge}</span>}
      </div>
      <p className="product__desc">{p.desc}</p>
      {p.sample && <div className="product__sample">{p.sample}</div>}
      <footer className="product__foot">
        {p.state === 'equipped' ? (
          <><span className="product__state product__state--eq">EM USO</span><Btn kind="outline" disabled>EQUIPADO</Btn></>
        ) : p.state === 'owned' ? (
          <><span className="product__state product__state--ok">ADQUIRIDO</span><Btn kind="outline" onClick={act}>EQUIPAR</Btn></>
        ) : (
          <>
            <span className="product__price">
              <b className={locked ? 'is-bad' : ''}>{money(p.price)}</b>
              <small>{locked ? 'saldo insuficiente' : confirming ? 'clique de novo para confirmar' : 'compra única'}</small>
            </span>
            {locked ? <Btn kind="ghost" disabled>BLOQUEADO</Btn> : <Btn kind="primary" color={confirming ? [255, 181, 71] : undefined} onClick={act}>{confirming ? 'CONFIRMAR' : 'COMPRAR'}</Btn>}
          </>
        )}
      </footer>
    </article>
  )
}

export default function Shop({ st }) {
  const cats = asArray(st.cats)
  const [tab, setTab] = useState(cats[0] ? cats[0].key : 'tags')
  const [confirm, setConfirm] = useState(null)
  const cat = cats.find((c) => c.key === tab) || cats[0]
  useEffect(() => setConfirm(null), [tab])
  return (
    <div className="shop">
      <aside className="shop__nav">
        <div className="shop__brand"><img src="./img/coin.png" alt="" /><span>LOJA</span></div>
        {cats.map((c) => (
          <button key={c.key} className={`shop__cat ${c.key === tab ? 'is-active' : ''}`} onClick={() => setTab(c.key)}>
            <img src={`./img/${ICONS[c.key] || 'target.png'}`} alt="" /><span>{c.label}</span><small>{asArray(c.items).length}</small>
          </button>
        ))}
        <div className="shop__nav-foot">
          <p>F4 ou ESC fecha</p>
          <p>/saldo · /pagar &lt;id&gt; &lt;valor&gt;</p>
        </div>
      </aside>
      <section className="shop__main">
        <header className="shop__head">
          <div>
            <h1>{cat ? cat.title : ''}</h1>
            <p>{cat ? cat.desc : ''}</p>
          </div>
          <div className="balance">
            <span>SEU SALDO</span>
            <b><Counter value={st.money} format={money} dur={800} /></b>
          </div>
          <button className="close" onClick={() => toLua('shop', 'close')} aria-label="Fechar">✕</button>
        </header>
        <div className="shop__grid">
          {cat && asArray(cat.items).map((p, i) => (
            <div key={p.id} className="shop__cell" style={{ animationDelay: `${i * 40}ms` }}>
              <Product p={p} money={st.money || 0} confirm={confirm} setConfirm={setConfirm} />
            </div>
          ))}
        </div>
      </section>
    </div>
  )
}
