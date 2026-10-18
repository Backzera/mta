import React, { useEffect, useState } from 'react'
import { toLua } from '../bridge.js'
import { Btn, Tabs } from '../ui.jsx'

const FEATS = [
  ['target.png', 'Arenas por arma', 'AK-47, M4, Deagle, Sniper, C-Bug e mais'],
  ['swords.png', 'Duelos X1 e ranqueadas MD3', 'Suba de elo: Bronze até Lenda'],
  ['shield.png', 'Clãs e clã x clã', 'Tags, loja, caixas, VIP e economia própria'],
]

export default function Login({ st }) {
  const d = st || {}
  const [tab, setTab] = useState('login')
  const [user, setUser] = useState(d.user || '')
  const [pass, setPass] = useState(d.pass || '')
  const [pass2, setPass2] = useState('')
  const [remember, setRemember] = useState(d.remember !== false)
  const [local, setLocal] = useState(null)
  useEffect(() => { if (d.user) setUser(d.user); if (d.pass) setPass(d.pass) }, [d.user, d.pass])
  const msg = local || (d.message ? { text: d.message, type: d.type } : null)

  const submit = () => {
    if (d.busy) return
    if (user.length < 3) return setLocal({ text: 'Digite um usuário com pelo menos 3 caracteres.', type: 'error' })
    if (pass.length < 4) return setLocal({ text: 'Digite uma senha com pelo menos 4 caracteres.', type: 'error' })
    if (tab === 'register' && pass2 !== pass) return setLocal({ text: 'As senhas não coincidem.', type: 'error' })
    setLocal(null)
    toLua('login', tab === 'register' ? 'register' : 'login', { user, pass, remember })
  }
  const onKey = (e) => { if (e.key === 'Enter') submit() }

  return (
    <div className="login">
      <div className="login__brand">
        <img src="./img/logo.png" alt="UTG" />
        <p>#Return2k26 · mata-mata, X1, ranqueadas MD3 e clãs</p>
        <ul>
          {FEATS.map(([ic, t, s], i) => <li key={t} style={{ animationDelay: `${200 + i * 90}ms` }}><img src={`./img/${ic}`} alt="" /><div><b>{t}</b><small>{s}</small></div></li>)}
        </ul>
      </div>
      <div className="login__card">
        <Tabs tabs={[['login', 'ENTRAR'], ['register', 'REGISTRAR']]} value={tab} onChange={(k) => { setTab(k); setLocal(null); setPass2('') }} />
        <label className="field"><span className="field__label">USUÁRIO</span>
          <input className="input" value={user} maxLength={20} onChange={(e) => setUser(e.target.value.replace(/[^\w]/g, ''))} onKeyDown={onKey} autoFocus /></label>
        <label className="field"><span className="field__label">SENHA</span>
          <input className="input" type="password" value={pass} maxLength={32} onChange={(e) => setPass(e.target.value)} onKeyDown={onKey} /></label>
        {tab === 'register' && (
          <label className="field"><span className="field__label">CONFIRMAR SENHA</span>
            <input className="input" type="password" value={pass2} maxLength={32} onChange={(e) => setPass2(e.target.value)} onKeyDown={onKey} /></label>
        )}
        <label className="toggle"><input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} /><i /><span>Manter conectado neste computador</span></label>
        <Btn kind="primary" disabled={d.busy} onClick={submit}>{d.busy ? 'AGUARDE...' : tab === 'register' ? 'CRIAR CONTA' : 'ENTRAR'}</Btn>
        <Btn kind="outline" disabled={d.busy} onClick={() => !d.busy && toLua('login', 'guest')}>Jogar como convidado</Btn>
        {msg && <p className={`login__msg is-${msg.type || 'info'}`}>{msg.text}</p>}
        <small className="login__hint">ENTER confirma · TAB troca de campo</small>
      </div>
    </div>
  )
}
