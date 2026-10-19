import React, { useEffect, useRef, useState } from 'react'
import { toLua, asArray } from '../bridge.js'
import { Counter, money, rgb } from '../ui.jsx'

const typeLabel = (a) =>
  a.type === 'ranked' ? 'Partida ranqueada MD3' : a.type === 'lobby' ? 'Zona segura' : a.type === 'duel' ? 'Duelos 1v1' : 'Todos contra todos'

export default function Hub({ st, closing }) {
  const arenas = asArray(st.arenas), modes = asArray(st.modes)
  const [tab, setTab] = useState('arenas')
  const [sel, setSel] = useState(0)
  const listRef = useRef(null)
  const list = tab === 'ranked' ? modes : arenas
  const item = list[Math.min(sel, Math.max(0, list.length - 1))]

  useEffect(() => {
    const idx = arenas.findIndex((a) => a.id === st.current)
    if (idx >= 0) setSel(idx)
  }, [])
  useEffect(() => {
    const el = listRef.current && listRef.current.querySelector('.row.is-selected')
    if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest' })
  }, [sel, tab])
  useEffect(() => { if (item) toLua('hub', 'select', { id: item.id }) }, [item && item.id])

  const enter = () => { if (item && item.id !== st.current) toLua('hub', 'enter', { id: item.id }) }
  const close = () => toLua('hub', 'close')

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'ArrowDown') { setSel((s) => Math.min(list.length - 1, s + 1)); e.preventDefault() }
      else if (e.key === 'ArrowUp') { setSel((s) => Math.max(0, s - 1)); e.preventDefault() }
      else if (e.key === 'ArrowRight' || e.key === 'ArrowLeft' || e.key === 'Tab') { setTab((t) => (t === 'arenas' ? 'ranked' : 'arenas')); setSel(0); e.preventDefault() }
      else if (e.key === 'Enter') enter()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [list.length, item && item.id, st.current])

  const accent = item ? rgb(item.color) : 'rgb(34,230,138)'
  const isCurrent = item && item.id === st.current
  const stats = !item ? [] : item.type === 'ranked'
    ? [
        { k: 'Jogadores', v: `${item.players} / ${item.cap}` },
        { k: 'Formato', v: `${item.teamSize} x ${item.teamSize} · MD3` },
        { k: 'Round', v: `${Math.floor((item.roundTime || 300) / 60)} min · sem respawn` },
        { k: 'Papéis', v: item.roles ? '1 sniper por time' : 'Todos iguais' },
      ]
    : [
        { k: 'Jogadores', v: `${item.players}` },
        { k: 'Local', v: item.place || '—' },
        { k: 'Regras', v: item.cbug ? 'C-Bug liberado' : item.safe ? 'Sem dano' : 'Headshot x2.2' },
        { k: 'Respawn', v: item.safe ? '—' : '3 s' },
      ]

  return (
    <div className={`hub ${closing ? 'hub--leaving' : ''}`} style={{ '--accent': accent }}>
      <div className="frame-corner frame--tl" /><div className="frame-corner frame--tr" /><div className="frame-corner frame--bl" /><div className="frame-corner frame--br" />
      <header className="top">
        <div className="brand">
          <img className="brand__logo" src="./img/logo.png" alt="UTG" />
        </div>
        <nav className="tabs tabs--pill" style={{ '--n': 2 }}>
          {[['arenas', 'Arenas'], ['ranked', 'Ranqueadas']].map(([k, label]) => (
            <button key={k} className={`tabs__btn ${tab === k ? 'is-active' : ''}`} onClick={() => { setTab(k); setSel(0) }}>{label}</button>
          ))}
          <span className="tabs__line" style={{ transform: `translateX(${tab === 'ranked' ? 100 : 0}%)` }} />
        </nav>
        <div className="me">
          {st.player && (
            <>
              <span className="me__name">{st.player.name}</span>
              <span className="me__tier" style={{ '--tier': rgb(st.player.tierColor) }}>{st.player.tier}</span>
              <span className="me__money"><Counter value={st.player.money} format={money} /></span>
            </>
          )}
          <span className="online"><i />{st.online} online</span>
          <button className="close" onClick={close} aria-label="Fechar">✕</button>
        </div>
      </header>

      <aside className="list">
        <div className="list__head">
          <span className="eyebrow">{tab === 'ranked' ? 'Modos ranqueados' : 'Arenas'}</span>
          <span className="list__count">{list.length}</span>
        </div>
        <ul ref={listRef}>
          {list.map((a, i) => (
            <li key={a.id} className={`row ${i === sel ? 'is-selected' : ''} ${a.id === st.current ? 'is-current' : ''}`}
              style={{ '--row': rgb(a.color), animationDelay: `${60 + i * 45}ms` }}
              onMouseEnter={() => setSel(i)} onClick={() => (i === sel ? enter() : setSel(i))}>
              <span className="row__idx">{String(i + 1).padStart(2, '0')}</span>
              <span className="row__body">
                <span className="row__name">{a.name}</span>
                <span className="row__sub">{a.type === 'ranked' ? `${a.place} · ${a.teamSize}x${a.teamSize} · MD3` : a.weapons}</span>
              </span>
              <span className="row__players"><i className={a.players > 0 ? 'live' : ''} />{a.players}</span>
              <span className="row__bar"><span style={{ width: `${Math.min(100, (a.players / (a.cap || 32)) * 100)}%` }} /></span>
            </li>
          ))}
        </ul>
        <div className="list__hint"><kbd>↑</kbd><kbd>↓</kbd> navegar <kbd>Enter</kbd> entrar <kbd>Esc</kbd> voltar</div>
      </aside>

      {item && (
        <section className="detail" key={item.id}>
          <div className="detail__eyebrow">
            <span className="chip chip--accent">{typeLabel(item)}</span>
            {item.cbug && <span className="chip">C-Bug</span>}
            {item.safe && item.type !== 'lobby' && <span className="chip">Zona segura</span>}
          </div>
          <h1 className="detail__title">{item.name}</h1>
          <div className="rule"><span /></div>
          <p className="detail__desc">{item.desc}</p>
          <div className="stats">
            {stats.map((s, i) => (
              <div className="stat" key={s.k} style={{ animationDelay: `${120 + i * 70}ms` }}>
                <span className="stat__k">{s.k}</span><span className="stat__v">{s.v}</span>
              </div>
            ))}
          </div>
          <div className="weapons">
            <span className="eyebrow">Armas</span>
            <div className="weapons__chips">
              {String(item.weapons || '').split('·').map((w) => w.trim()).filter(Boolean).map((w) => <span key={w} className="chip chip--w">{w}</span>)}
            </div>
          </div>
          <div className="actions">
            <button className={`btn btn--primary ${isCurrent ? 'is-disabled' : ''}`} onClick={enter} disabled={isCurrent}>
              <span className="btn__shine" />
              <span className="btn__label">{isCurrent ? 'Você está aqui' : item.type === 'ranked' ? 'Entrar na partida' : 'Entrar na arena'}</span>
              {!isCurrent && <kbd>↵</kbd>}
            </button>
            <button className="btn btn--ghost" onClick={close}><span className="btn__label">Voltar <kbd>Esc</kbd></span></button>
          </div>
        </section>
      )}
    </div>
  )
}
