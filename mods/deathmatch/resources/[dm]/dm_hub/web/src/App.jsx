import React, { useEffect, useMemo, useRef, useState } from 'react'
import { subscribe, toLua } from './bridge.js'

const money = (v) => '$' + Math.floor(v || 0).toLocaleString('pt-BR')
const typeLabel = (a) =>
  a.type === 'ranked' ? 'Partida ranqueada' : a.type === 'lobby' ? 'Zona segura' : a.type === 'duel' ? 'Duelos 1v1' : 'Todos contra todos'

// Número que anima até o valor
function Counter({ value, format = (v) => v }) {
  const [shown, setShown] = useState(value)
  const ref = useRef(value)
  useEffect(() => {
    const from = ref.current, to = value, start = performance.now(), dur = 600
    let raf
    const step = (t) => {
      const p = Math.min(1, (t - start) / dur)
      const e = 1 - Math.pow(1 - p, 3)
      setShown(from + (to - from) * e)
      if (p < 1) raf = requestAnimationFrame(step)
      else ref.current = to
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [value])
  return <>{format(Math.round(shown))}</>
}

export default function App() {
  const [st, setSt] = useState({ arenas: [], modes: [], visible: false })
  const [tab, setTab] = useState('arenas')
  const [sel, setSel] = useState(0)
  const [leaving, setLeaving] = useState(false)
  useEffect(() => subscribe(setSt), [])

  const list = tab === 'ranked' ? st.modes : st.arenas
  const item = list[Math.min(sel, Math.max(0, list.length - 1))]
  const listRef = useRef(null)

  // mantém a linha selecionada visível ao navegar pelo teclado
  useEffect(() => {
    const el = listRef.current && listRef.current.querySelector('.row.is-selected')
    if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest' })
  }, [sel, tab])

  // seleção inicial = arena atual
  useEffect(() => {
    if (!st.visible) return
    const idx = st.arenas.findIndex((a) => a.id === st.current)
    if (idx >= 0 && tab === 'arenas') setSel(idx)
    setLeaving(false)
  }, [st.visible])

  // informa o Lua para mover a câmera até o local selecionado
  useEffect(() => { if (item && st.visible) toLua('hub:select', item.id) }, [item && item.id, st.visible])

  const enter = () => {
    if (!item || item.id === st.current) return
    setLeaving(true)
    setTimeout(() => toLua('hub:enter', item.id), 260)
  }
  const close = () => { setLeaving(true); setTimeout(() => toLua('hub:close'), 220) }

  // teclado: setas, Enter, ESC, Tab/←→ para trocar aba
  useEffect(() => {
    if (!st.visible) return
    const onKey = (e) => {
      if (e.key === 'ArrowDown') { setSel((s) => Math.min(list.length - 1, s + 1)); e.preventDefault() }
      else if (e.key === 'ArrowUp') { setSel((s) => Math.max(0, s - 1)); e.preventDefault() }
      else if (e.key === 'ArrowRight' || e.key === 'ArrowLeft' || e.key === 'Tab') { setTab((t) => (t === 'arenas' ? 'ranked' : 'arenas')); setSel(0); e.preventDefault() }
      else if (e.key === 'Enter') enter()
      else if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [st.visible, list.length, item && item.id, st.current])

  if (!st.visible && !leaving) return null
  const accent = item ? `rgb(${item.color.join(',')})` : '#c9a46b'
  const isCurrent = item && item.id === st.current
  const stats = item
    ? item.type === 'ranked'
      ? [
          { k: 'Jogadores', v: `${item.players} / ${item.cap}` },
          { k: 'Formato', v: `${item.teamSize} x ${item.teamSize}` },
          { k: 'Meta', v: `${item.killTarget} kills` },
          { k: 'Tempo', v: `${Math.floor(item.duration / 60)} min` },
        ]
      : [
          { k: 'Jogadores', v: `${item.players}` },
          { k: 'Local', v: item.place || '—' },
          { k: 'Regras', v: item.cbug ? 'C-Bug liberado' : item.safe ? 'Sem dano' : 'Headshot x2.2' },
          { k: 'Respawn', v: item.safe ? '—' : '3 s' },
        ]
    : []

  return (
    <div className={`hub ${leaving ? 'hub--leaving' : ''}`} style={{ '--accent': accent }}>
      <div className="scrim scrim--left" />
      <div className="scrim scrim--bottom" />
      <div className="grain" />
      <div className="leak" />
      <div className="frame frame--tl" /><div className="frame frame--tr" /><div className="frame frame--bl" /><div className="frame frame--br" />

      <header className="top">
        <div className="brand">
          <span className="brand__mark">UTG</span>
          <span className="brand__sub">Mata-mata · #Return2k26</span>
        </div>
        <nav className="tabs">
          {[['arenas', 'Arenas'], ['ranked', 'Ranqueadas']].map(([k, label]) => (
            <button key={k} className={`tabs__btn ${tab === k ? 'is-active' : ''}`} onClick={() => { setTab(k); setSel(0) }}>
              {label}
            </button>
          ))}
          <span className="tabs__line" style={{ transform: `translateX(${tab === 'ranked' ? 100 : 0}%)` }} />
        </nav>
        <div className="me">
          {st.player && (
            <>
              <span className="me__name">{st.player.name}</span>
              <span className="me__tier" style={{ '--tier': `rgb(${st.player.tierColor.join(',')})` }}>{st.player.tier}</span>
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
            <li
              key={a.id}
              className={`row ${i === sel ? 'is-selected' : ''} ${a.id === st.current ? 'is-current' : ''}`}
              style={{ '--row': `rgb(${a.color.join(',')})`, animationDelay: `${60 + i * 45}ms` }}
              onMouseEnter={() => setSel(i)}
              onClick={() => (i === sel ? enter() : setSel(i))}
            >
              <span className="row__idx">{String(i + 1).padStart(2, '0')}</span>
              <span className="row__body">
                <span className="row__name">{a.name}</span>
                <span className="row__sub">{a.type === 'ranked' ? `${a.place} · ${a.teamSize}x${a.teamSize}` : a.weapons}</span>
              </span>
              <span className="row__players">
                <i className={a.players > 0 ? 'live' : ''} />
                {a.players}
              </span>
              <span className="row__bar"><span style={{ width: `${Math.min(100, (a.players / (a.cap || 32)) * 100)}%` }} /></span>
            </li>
          ))}
        </ul>
        <div className="list__hint">
          <kbd>↑</kbd><kbd>↓</kbd> navegar <kbd>Enter</kbd> entrar <kbd>Esc</kbd> voltar
        </div>
      </aside>

      {item && (
        <section className="detail" key={item.id}>
          <div className="detail__eyebrow">
            <span className="chip chip--accent">{typeLabel(item)}</span>
            {item.cbug && <span className="chip">C-Bug</span>}
            {item.safe && <span className="chip">Zona segura</span>}
          </div>
          <h1 className="detail__title">{item.name}</h1>
          <div className="rule"><span /></div>
          <p className="detail__desc">{item.desc}</p>
          <div className="stats">
            {stats.map((s, i) => (
              <div className="stat" key={s.k} style={{ animationDelay: `${120 + i * 70}ms` }}>
                <span className="stat__k">{s.k}</span>
                <span className="stat__v">{s.v}</span>
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
            <button className={`enter ${isCurrent ? 'is-disabled' : ''}`} onClick={enter} disabled={isCurrent}>
              <span className="enter__shine" />
              <span>{isCurrent ? 'Você está aqui' : item.type === 'ranked' ? 'Entrar na partida' : 'Entrar na arena'}</span>
              {!isCurrent && <kbd>↵</kbd>}
            </button>
            <button className="ghost" onClick={close}>Voltar <kbd>Esc</kbd></button>
          </div>
        </section>
      )}
    </div>
  )
}
