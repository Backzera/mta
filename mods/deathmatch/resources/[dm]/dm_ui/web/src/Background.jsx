import React, { useEffect, useRef } from 'react'

// Fundo vivo do servidor: aurora verde, feixes de luz, partículas subindo e grade sutil.
// Desenhado em canvas (leve), por cima da cena do GTA (que continua visível, escurecida em verde).
function Background({ strength = 1 }) {
  const ref = useRef(null)
  useEffect(() => {
    const canvas = ref.current
    const ctx = canvas.getContext('2d')
    let raf, last = 0, w = 0, h = 0
    const parts = Array.from({ length: 36 }, () => ({ x: Math.random(), y: Math.random(), r: 0.6 + Math.random() * 1.8, s: 0.02 + Math.random() * 0.05, p: Math.random() * Math.PI * 2 }))
    const blobs = [
      { x: 0.18, y: 0.3, r: 0.55, c: '34,230,138', a: 0.22, f: 0.11 },
      { x: 0.82, y: 0.25, r: 0.5, c: '124,255,178', a: 0.14, f: 0.07 },
      { x: 0.55, y: 0.95, r: 0.7, c: '15,120,70', a: 0.26, f: 0.05 },
      { x: 0.9, y: 0.8, r: 0.45, c: '34,230,138', a: 0.12, f: 0.09 },
    ]
    const resize = () => { w = canvas.width = Math.floor(innerWidth * 0.3); h = canvas.height = Math.floor(innerHeight * 0.3) }
    resize(); addEventListener('resize', resize)
    const draw = (t) => {
      raf = requestAnimationFrame(draw)
      if (t - last < 66) return   // ~15 fps: o CEF do MTA rasteriza por software
      last = t
      const s = t / 1000
      ctx.clearRect(0, 0, w, h)
      // aurora
      ctx.globalCompositeOperation = 'lighter'
      for (const b of blobs) {
        const x = (b.x + Math.sin(s * b.f * 2 + b.r) * 0.08) * w
        const y = (b.y + Math.cos(s * b.f * 1.6 + b.a) * 0.06) * h
        const r = b.r * Math.max(w, h) * (1 + Math.sin(s * b.f) * 0.08)
        const g = ctx.createRadialGradient(x, y, 0, x, y, r)
        g.addColorStop(0, `rgba(${b.c},${b.a * strength})`)
        g.addColorStop(0.5, `rgba(${b.c},${b.a * 0.35 * strength})`)
        g.addColorStop(1, 'rgba(0,0,0,0)')
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
      }
      // feixes de luz girando devagar
      ctx.save()
      ctx.translate(w * 0.75, -h * 0.2)
      for (let i = 0; i < 4; i++) {
        ctx.rotate(0.35 + Math.sin(s * 0.08 + i) * 0.03)
        const g = ctx.createLinearGradient(0, 0, 0, h * 1.8)
        g.addColorStop(0, `rgba(124,255,178,${0.05 * strength})`)
        g.addColorStop(1, 'rgba(124,255,178,0)')
        ctx.fillStyle = g
        ctx.fillRect(-w * 0.03 - i * w * 0.02, 0, w * 0.06, h * 1.8)
      }
      ctx.restore()
      // partículas
      for (const p of parts) {
        p.y -= p.s * 0.016
        if (p.y < -0.02) { p.y = 1.02; p.x = Math.random() }
        const tw = 0.4 + 0.6 * Math.abs(Math.sin(s * 1.3 + p.p))
        ctx.fillStyle = `rgba(160,255,200,${0.35 * tw * strength})`
        ctx.beginPath(); ctx.arc(p.x * w + Math.sin(s * 0.7 + p.p) * 6, p.y * h, p.r, 0, Math.PI * 2); ctx.fill()
      }
      // grade sutil
      ctx.globalCompositeOperation = 'source-over'
      ctx.strokeStyle = `rgba(124,255,178,${0.035 * strength})`
      ctx.lineWidth = 1
      const step = Math.max(28, w / 24)
      const off = (s * 6) % step
      ctx.beginPath()
      for (let x = -step + off; x < w + step; x += step) { ctx.moveTo(x, 0); ctx.lineTo(x - h * 0.25, h) }
      for (let y = -step + off * 0.5; y < h + step; y += step) { ctx.moveTo(0, y); ctx.lineTo(w, y) }
      ctx.stroke()
    }
    raf = requestAnimationFrame(draw)
    return () => { cancelAnimationFrame(raf); removeEventListener('resize', resize) }
  }, [strength])
  return <canvas ref={ref} className="bgfx" />
}
export default React.memo(Background)
