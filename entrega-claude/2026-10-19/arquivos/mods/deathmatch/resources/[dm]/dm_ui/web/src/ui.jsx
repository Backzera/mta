import React, { useEffect, useRef, useState } from 'react'

export const money = (v) => '$' + Math.floor(v || 0).toLocaleString('pt-BR')
export const rgb = (c) => (Array.isArray(c) ? `rgb(${c.join(',')})` : c || 'rgb(34,230,138)')
export const rgba = (c, a) => (Array.isArray(c) ? `rgba(${c.join(',')},${a})` : `rgba(34,230,138,${a})`)

// Número que anima até o valor
export function Counter({ value, format = (v) => v, dur = 600 }) {
  const [shown, setShown] = useState(value || 0)
  const ref = useRef(value || 0)
  useEffect(() => {
    const from = ref.current, to = value || 0, start = performance.now()
    if (from === to) return
    let raf
    const step = (t) => {
      const p = Math.min(1, (t - start) / dur)
      const e = 1 - Math.pow(1 - p, 3)
      ref.current = from + (to - from) * e
      setShown(ref.current)
      if (p < 1) raf = requestAnimationFrame(step)
      else ref.current = to
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [value])
  return <>{format(Math.round(shown))}</>
}

// Contagem regressiva local a partir de "segundos restantes" recebidos do Lua
export function useCountdown(seconds, key) {
  const [left, setLeft] = useState(seconds || 0)
  useEffect(() => {
    setLeft(seconds || 0)
    const start = Date.now()
    const t = setInterval(() => setLeft(Math.max(0, (seconds || 0) - Math.floor((Date.now() - start) / 1000))), 250)
    return () => clearInterval(t)
  }, [seconds, key])
  return left
}

export const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`

// Moldura padrão dos painéis centrais
export function Frame({ title, subtitle, badge, badgeColor, icon, onClose, footer, width = '64vw', height = '70vh', children, className = '' }) {
  return (
    <div className={`frame ${className}`} style={{ width, height }}>
      <header className="frame__head">
        {icon && <img className="frame__icon" src={`./img/${icon}`} alt="" />}
        <div className="frame__titles">
          <h2 className="frame__title">{title}</h2>
          {subtitle && <p className="frame__sub">{subtitle}</p>}
        </div>
        {badge && <span className="badge" style={badgeColor ? { '--c': rgb(badgeColor) } : undefined}>{badge}</span>}
        {onClose && <button className="close" onClick={onClose} aria-label="Fechar">✕</button>}
      </header>
      <div className="frame__body">{children}</div>
      {footer && <footer className="frame__foot">{footer}</footer>}
    </div>
  )
}

export function Btn({ kind = 'primary', color, children, className = '', ...rest }) {
  return (
    <button className={`btn btn--${kind} ${className}`} style={color ? { '--c': rgb(color) } : undefined} {...rest}>
      {kind === 'primary' && <span className="btn__shine" />}
      <span className="btn__label">{children}</span>
    </button>
  )
}

export function Tabs({ tabs, value, onChange }) {
  const idx = Math.max(0, tabs.findIndex((t) => t[0] === value))
  return (
    <nav className="tabs" style={{ '--n': tabs.length }}>
      {tabs.map(([k, label]) => (
        <button key={k} className={`tabs__btn ${value === k ? 'is-active' : ''}`} onClick={() => onChange(k)}>{label}</button>
      ))}
      <span className="tabs__line" style={{ transform: `translateX(${idx * 100}%)` }} />
    </nav>
  )
}

export function Pill({ color, children, glyph, className = '' }) {
  return <span className={`pill ${className}`} style={{ '--c': rgb(color) }}>{glyph && <i>{glyph}</i>}{children}</span>
}

export function Kbd({ children }) { return <kbd>{children}</kbd> }

export function Input({ label, ...rest }) {
  return (
    <label className="field">
      {label && <span className="field__label">{label}</span>}
      <input className="input" spellCheck={false} autoComplete="off" {...rest} />
    </label>
  )
}

export function Bar({ value, color, className = '', height }) {
  return (
    <span className={`bar ${className}`} style={{ '--c': rgb(color), height }}>
      <span style={{ width: `${Math.max(0, Math.min(100, (value || 0) * 100))}%` }} />
    </span>
  )
}

export function Ring({ value, size = 44, stroke = 4, color }) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r
  return (
    <svg className="ring" width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={size / 2} cy={size / 2} r={r} stroke="rgba(255,255,255,.12)" strokeWidth={stroke} fill="none" />
      <circle cx={size / 2} cy={size / 2} r={r} stroke={rgb(color)} strokeWidth={stroke} fill="none" strokeLinecap="round"
        strokeDasharray={c} strokeDashoffset={c * (1 - Math.max(0, Math.min(1, value)))} transform={`rotate(-90 ${size / 2} ${size / 2})`} />
    </svg>
  )
}

export function Empty({ children }) { return <div className="empty">{children}</div> }
