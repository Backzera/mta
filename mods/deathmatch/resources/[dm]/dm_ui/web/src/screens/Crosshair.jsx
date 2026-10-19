import React, { useEffect, useRef, useState } from 'react'
import { toLua, asObj } from '../bridge.js'
import { Frame, Btn } from '../ui.jsx'

// Galeria de miras. "native" = mira original do GTA (padrão ao entrar). Os demais são presets ajustáveis.
const BASE = { enabled: true, style: 'classic', color: '#22E68A', size: 6, thickness: 2, gap: 4, opacity: 255, outline: true, offsetX: 0, offsetY: 0 }
export const PRESETS = [
  { key: 'native', name: 'Original do GTA', desc: 'A mira padrão do jogo', native: true },
  { key: 'dot', name: 'Ponto', s: { style: 'dot', size: 4, color: '#FFFFFF' } },
  { key: 'dot_green', name: 'Ponto verde', s: { style: 'dot', size: 5, color: '#22E68A' } },
  { key: 'classic', name: 'Clássica', s: { style: 'classic', size: 6, thickness: 2, gap: 4, color: '#FFFFFF' } },
  { key: 'classic_green', name: 'Clássica UTG', s: { style: 'classic', size: 7, thickness: 2, gap: 3, color: '#22E68A' } },
  { key: 'classicdot', name: 'Clássica + ponto', s: { style: 'classicdot', size: 6, thickness: 2, gap: 5, color: '#7CFFB2' } },
  { key: 'cs', name: 'Estilo CS', s: { style: 'classic', size: 5, thickness: 2, gap: 3, color: '#00FF00' } },
  { key: 'val', name: 'Estilo Valorant', s: { style: 'classic', size: 4, thickness: 2, gap: 2, color: '#00FFEE' } },
  { key: 'plus', name: 'Cruz cheia', s: { style: 'plus', size: 7, thickness: 2, gap: 0, color: '#FFFFFF' } },
  { key: 'x', name: 'X', s: { style: 'x', size: 6, thickness: 2, gap: 0, color: '#FF4D9D' } },
  { key: 'circle', name: 'Círculo', s: { style: 'circle', size: 6, thickness: 2, gap: 2, color: '#F5C451' } },
  { key: 'circledot', name: 'Círculo + ponto', s: { style: 'circledot', size: 7, thickness: 2, gap: 2, color: '#22E68A' } },
  { key: 'tee', name: 'T', s: { style: 'tee', size: 6, thickness: 2, gap: 4, color: '#FFFFFF' } },
  { key: 'sniper', name: 'Fina', s: { style: 'classicdot', size: 10, thickness: 1, gap: 6, color: '#FFFFFF' } },
]
const COLORS = ['#FFFFFF', '#22E68A', '#7CFFB2', '#00FF00', '#00FFEE', '#F5C451', '#FF8C32', '#FF4D9D', '#C76BFF', '#FF4A1E']
const STYLE_NAMES = { dot: 'Ponto', classic: 'Clássica', classicdot: 'Clássica + ponto', plus: 'Cruz cheia', x: 'X', circle: 'Círculo', circledot: 'Círculo + ponto', tee: 'T' }

// Mesma geometria do desenho dx do dm_crosshair, em SVG (1 unidade = 1 px do jogo, ampliado por `scale`)
export function CrossPreview({ s, scale = 2.2, box = 120 }) {
  const c = box / 2, k = scale
  const a = Math.max(0, Math.min(1, (s.opacity || 255) / 255))
  const size = (s.size || 6) * k, th = (s.thickness || 2) * k, gap = (s.gap || 0) * k
  const outline = s.outline !== false
  const shapes = []
  const rect = (x, y, w, h) => shapes.push({ t: 'r', x, y, w, h })
  const line = (x1, y1, x2, y2) => shapes.push({ t: 'l', x1, y1, x2, y2 })
  const dot = (r) => shapes.push({ t: 'd', r })
  const ring = (r) => shapes.push({ t: 'c', r })
  const arms = (noTop) => {
    rect(c - gap - size, c - th / 2, size, th); rect(c + gap, c - th / 2, size, th)
    if (!noTop) rect(c - th / 2, c - gap - size, th, size)
    rect(c - th / 2, c + gap, th, size)
  }
  switch (s.style) {
    case 'dot': dot(Math.max(1, size / 2)); break
    case 'classic': arms(); break
    case 'classicdot': arms(); dot(Math.max(1, th * 0.8)); break
    case 'plus': rect(c - size, c - th / 2, size * 2, th); rect(c - th / 2, c - size, th, size * 2); break
    case 'x': line(c - size, c - size, c + size, c + size); line(c + size, c - size, c - size, c + size); break
    case 'circle': ring(size + gap / 2); break
    case 'circledot': ring(size + gap / 2); dot(Math.max(1, th * 0.8)); break
    case 'tee': arms(true); break
    default: arms()
  }
  const draw = (sh, i, ol) => {
    const col = ol ? '#000' : s.color || '#fff', op = ol ? Math.min(0.86, a) : a
    const o = ol ? 1 : 0
    if (sh.t === 'r') return <rect key={`${i}${ol}`} x={sh.x - o} y={sh.y - o} width={sh.w + o * 2} height={sh.h + o * 2} fill={col} opacity={op} />
    if (sh.t === 'l') return <line key={`${i}${ol}`} x1={sh.x1} y1={sh.y1} x2={sh.x2} y2={sh.y2} stroke={col} strokeWidth={th + o * 2} opacity={op} strokeLinecap="butt" />
    if (sh.t === 'd') return <circle key={`${i}${ol}`} cx={c} cy={c} r={sh.r + o * 1.3} fill={col} opacity={op} />
    return <circle key={`${i}${ol}`} cx={c} cy={c} r={sh.r} fill="none" stroke={col} strokeWidth={th + o * 2} opacity={op} />
  }
  return (
    <svg className="xpv" viewBox={`0 0 ${box} ${box}`} width="100%" height="100%">
      {outline && shapes.map((sh, i) => draw(sh, i, true))}
      {shapes.map((sh, i) => draw(sh, i, false))}
    </svg>
  )
}

const presetOf = (s) => {
  if (!s.enabled) return 'native'
  const p = PRESETS.find((p) => p.s && ['style', 'size', 'thickness', 'gap', 'color'].every((k) => (p.s[k] ?? BASE[k]) === s[k]))
  return p ? p.key : 'custom'
}

export default function Crosshair({ st }) {
  const incoming = asObj(st && st.settings)
  const [s, setS] = useState(() => ({ ...BASE, ...incoming }))
  const [hex, setHex] = useState(incoming.color || BASE.color)
  const last = useRef(null)
  useEffect(() => { const n = { ...BASE, ...incoming }; setS(n); setHex(n.color) }, [JSON.stringify(incoming)])
  // prévia ao vivo no jogo (fora do painel)
  useEffect(() => {
    const json = JSON.stringify(s)
    if (last.current === json) return
    last.current = json
    toLua('crosshair', 'change', s)
  }, [s])

  const set = (patch) => setS((o) => ({ ...o, ...patch }))
  const pick = (p) => {
    if (p.native) set({ enabled: false })
    else { set({ enabled: true, ...p.s }); setHex(p.s.color) }
  }
  const onHex = (v) => {
    v = v.toUpperCase().replace(/[^#0-9A-F]/g, '')
    if (!v.startsWith('#')) v = '#' + v
    setHex(v.slice(0, 7))
    if (/^#[0-9A-F]{6}$/.test(v)) set({ color: v, enabled: true })
  }
  const current = presetOf(s)
  const Slider = ({ label, k, min, max, fmt = (v) => v }) => (
    <label className="xrange">
      <span>{label}<b>{fmt(s[k])}</b></span>
      <input type="range" min={min} max={max} step="1" value={s[k]} onChange={(e) => set({ [k]: +e.target.value, enabled: true })} />
    </label>
  )

  return (
    <Frame title="MIRA" subtitle="Escolha uma mira da galeria ou monte a sua. Ao entrar no servidor você usa a mira original do GTA; troque aqui quando quiser." icon="target.png"
      badge={s.enabled ? STYLE_NAMES[s.style] || 'Personalizada' : 'ORIGINAL DO GTA'} onClose={() => toLua('crosshair', 'close')} width="70vw" height="76vh"
      footer="F9 ou ESC fecha · SALVAR grava na sua conta · a mira aparece só ao mirar, fixa como a do GTA · a sniper sempre usa o scope original">
      <div className="xh">
        <div className="xh__gallery">
          <span className="eyebrow">Galeria de miras</span>
          <div className="xh__grid">
            {PRESETS.map((p) => (
              <button key={p.key} className={`xcard ${current === p.key ? 'is-active' : ''} ${p.native ? 'xcard--native' : ''}`} onClick={() => pick(p)}>
                <span className="xcard__pv">{p.native ? <i className="xcard__gta">GTA</i> : <CrossPreview s={{ ...BASE, ...p.s }} scale={1.6} box={64} />}</span>
                <b>{p.name}</b>
              </button>
            ))}
          </div>
        </div>
        <div className="xh__side">
          <span className="eyebrow">Prévia</span>
          <div className={`xh__preview ${s.enabled ? '' : 'is-native'}`}>
            {s.enabled ? <CrossPreview s={s} scale={2.6} box={180} /> : <div className="xh__nativemsg"><b>Mira original do GTA</b><span>Nada é desenhado por cima. É o que todo jogador vê ao entrar.</span></div>}
          </div>
          <div className={`xh__tune ${s.enabled ? '' : 'is-off'}`}>
            <span className="eyebrow">Ajuste fino</span>
            <div className="xh__colors">
              {COLORS.map((c) => <button key={c} className={`trail__sw ${s.color === c ? 'is-active' : ''}`} style={{ background: c, boxShadow: `0 0 .8vw ${c}88` }} onClick={() => { set({ color: c, enabled: true }); setHex(c) }} title={c} />)}
              <input className="input xh__hex" value={hex} maxLength={7} spellCheck={false} onChange={(e) => onHex(e.target.value)} />
            </div>
            <Slider label="Tamanho" k="size" min={2} max={18} />
            <Slider label="Espessura" k="thickness" min={1} max={6} />
            <Slider label="Espaço do centro" k="gap" min={0} max={16} />
            <Slider label="Opacidade" k="opacity" min={40} max={255} fmt={(v) => Math.round((v / 255) * 100) + '%'} />
            <div className="xh__two">
              <Slider label="Deslocar horizontal" k="offsetX" min={-40} max={40} fmt={(v) => (v > 0 ? '+' : '') + v + ' px'} />
              <Slider label="Deslocar vertical" k="offsetY" min={-40} max={40} fmt={(v) => (v > 0 ? '+' : '') + v + ' px'} />
            </div>
            <div className="xh__toggles">
              <label className="toggle"><input type="checkbox" checked={s.outline !== false} onChange={(e) => set({ outline: e.target.checked, enabled: true })} /><i /> Contorno preto</label>
            </div>
          </div>
          <div className="hrow xh__acts">
            <Btn kind="primary" onClick={() => toLua('crosshair', 'save', s)}>SALVAR</Btn>
            <Btn kind="ghost" onClick={() => toLua('crosshair', 'reset')}>VOLTAR AO ORIGINAL</Btn>
            <Btn kind="ghost" onClick={() => toLua('crosshair', 'close')}>CANCELAR</Btn>
          </div>
        </div>
      </div>
    </Frame>
  )
}
