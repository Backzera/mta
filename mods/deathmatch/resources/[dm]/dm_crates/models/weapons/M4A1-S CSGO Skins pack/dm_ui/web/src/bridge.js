// Ponte JS <-> Lua (CEF do MTA).
//   Lua -> JS : executeBrowserJavascript(browser, "window.ui.set('hud', {...})") / open / close / push
//   JS  -> Lua: mta.triggerEvent('ui:act', screen, action, JSON) — recebido em dm_ui/client/c_ui.lua
// O toJSON() do MTA envolve o valor em um array ("[ {...} ]") e tabelas vazias viram "[]": unwrap() trata.

const listeners = new Set()
let state = {
  screen: null,          // tela aberta (hub, shop, duel, ranked, clans, crates, board, help, login) ou null
  hub: null, shop: null, duel: null, ranked: null, clans: null, crates: null, board: null, login: null,
  hud: null,             // dados do HUD (atualizados ~10x/s pelo Lua)
  feed: { kills: [], toasts: [], rewards: [], pops: [], streak: null, duelResult: null, rankedResult: null, reel: null },
}

const unwrap = (v) => (Array.isArray(v) ? (v[0] ?? null) : v)
export const asArray = (v) => (Array.isArray(v) ? v : [])
export const asObj = (v) => (v && typeof v === 'object' && !Array.isArray(v) ? v : {})

export function getState() { return state }
export function subscribe(fn) { listeners.add(fn); fn(state); return () => listeners.delete(fn) }
function emit() { listeners.forEach((fn) => fn(state)) }

export function toLua(screen, action, payload) {
  const json = JSON.stringify(payload ?? {})
  if (window.mta && typeof window.mta.triggerEvent === 'function') {
    window.mta.triggerEvent('ui:act', screen, action, json)
    return true
  }
  console.log('[ui -> lua]', screen, action, json)
  return false
}

let seq = 0
const TTL = { kills: 6500, toasts: 5000, rewards: 2600, pops: 2200 }
function pushList(kind, item, max) {
  const id = ++seq
  const list = [{ ...item, id, at: Date.now() }, ...state.feed[kind]].slice(0, max)
  state = { ...state, feed: { ...state.feed, [kind]: list } }
  emit()
  setTimeout(() => {
    state = { ...state, feed: { ...state.feed, [kind]: state.feed[kind].filter((e) => e.id !== id) } }
    emit()
  }, TTL[kind])
}

window.ui = {
  set(key, value) { state = { ...state, [key]: unwrap(value) }; emit() },
  merge(key, value) { state = { ...state, [key]: { ...(state[key] || {}), ...asObj(unwrap(value)) } }; emit() },
  open(screen, value) {
    state = { ...state, screen, ...(value !== undefined ? { [screen]: unwrap(value) } : {}) }
    emit()
  },
  close() { state = { ...state, screen: null }; emit() },
  push(kind, item) {
    item = unwrap(item) || {}
    if (kind === 'kill') pushList('kills', item, 6)
    else if (kind === 'toast') pushList('toasts', item, 5)
    else if (kind === 'reward') pushList('rewards', item, 3)
    else if (kind === 'pop') pushList('pops', item, 4)
    else if (kind === 'streak' || kind === 'duelResult' || kind === 'rankedResult') {
      const id = ++seq
      state = { ...state, feed: { ...state.feed, [kind]: { ...item, id, at: Date.now() } } }
      emit()
      setTimeout(() => {
        if (state.feed[kind] && state.feed[kind].id === id) { state = { ...state, feed: { ...state.feed, [kind]: null } }; emit() }
      }, kind === 'streak' ? 3500 : kind === 'duelResult' ? 4500 : 10000)
    } else if (kind === 'reel') {
      state = { ...state, feed: { ...state.feed, reel: { ...item, id: ++seq, at: Date.now() } } }
      emit()
    } else if (kind === 'reelClose') {
      state = { ...state, feed: { ...state.feed, reel: null } }
      emit()
    }
  },
  state: () => state,
}

// ---- Pré-visualização fora do jogo (?demo=hub|shop|duel|ranked|clans|crates|board|help|login|hud)
import { run as runDemo } from './demo.js'
if (!window.mta) {
  const demo = new URLSearchParams(location.search).get('demo')
  if (demo) setTimeout(() => runDemo(demo), 0)
}
