// Ponte JS <-> Lua (CEF do MTA).
// Lua -> JS: executeBrowserJavascript(browser, "window.hub.setState(...)") etc.
// JS -> Lua: mta.triggerEvent("hub:<acao>", ...args) — recebido com addEvent/addEventHandler no cliente Lua.

const listeners = new Set()
let state = { arenas: [], modes: [], current: null, player: null, online: 0, visible: false }

export function getState() { return state }
export function subscribe(fn) { listeners.add(fn); fn(state); return () => listeners.delete(fn) }
function emit() { listeners.forEach((fn) => fn(state)) }

export function toLua(event, ...args) {
  if (window.mta && typeof window.mta.triggerEvent === 'function') {
    window.mta.triggerEvent(event, ...args)
    return true
  }
  // fora do MTA (pré-visualização): só registra no console
  console.log('[hub -> lua]', event, args)
  return false
}

// toJSON() do MTA sempre devolve um array envolvendo o valor ("[ {...} ]"); tabelas vazias viram "[]".
const unwrap = (v) => (Array.isArray(v) ? (v[0] ?? {}) : (v ?? {}))

window.hub = {
  setState(partial) { state = { ...state, ...unwrap(partial) }; emit() },
  counts(raw) {
    const map = unwrap(raw)
    const apply = (list) => list.map((a) => ({ ...a, players: map[a.id] ?? a.players }))
    state = { ...state, arenas: apply(state.arenas), modes: apply(state.modes) }
    emit()
  },
  open() { state = { ...state, visible: true }; emit() },
  close() { state = { ...state, visible: false }; emit() },
}

// Pré-visualização fora do jogo (?demo): dados de exemplo só para desenvolvimento do visual.
if (!window.mta && new URLSearchParams(location.search).has('demo')) {
  const rgb = (r, g, b) => [r, g, b]
  // simula a cena do GTA atrás (no jogo o fundo é transparente)
  document.body.style.background = 'radial-gradient(80vw 60vh at 70% 40%, #3a3f48, #171a1f 70%)'
  window.hub.setState({
    visible: true, online: 37, current: 'lobby',
    player: { name: 'hehenr', tier: 'OURO', tierColor: rgb(245, 196, 81), money: 626000, rp: 640 },
    arenas: [
      { id: 'lobby', name: 'Lobby', short: 'LOBBY', type: 'lobby', safe: true, color: rgb(201, 164, 107), weapons: 'Sem armas', players: 12, cap: 64, desc: 'Zona segura. Escolha uma arena para começar.', place: 'Pershing Square · Los Santos' },
      { id: 'ak47', name: 'Arena AK-47', short: 'AK-47', type: 'ffa', color: rgb(255, 120, 40), weapons: 'AK-47', players: 9, cap: 32, desc: 'Somente AK-47. Mapa fechado em Las Venturas.', place: 'Las Venturas · mapa próprio' },
      { id: 'm4', name: 'Arena M4', short: 'M4', type: 'ffa', color: rgb(86, 180, 255), weapons: 'M4', players: 6, cap: 32, desc: 'Somente M4. Base militar em Verdant Bluffs.', place: 'Verdant Bluffs · mapa próprio' },
      { id: 'x1', name: 'Arena X1', short: 'X1', type: 'duel', safe: true, color: rgb(170, 120, 255), weapons: 'Arma escolhida no duelo', players: 4, cap: 32, desc: 'Duelos 1v1 em sala privada. Pressione F3 para desafiar.', place: 'Mapa flutuante' },
      { id: 'cbug', name: 'Arena C-Bug', short: 'C-BUG', type: 'ffa', cbug: true, color: rgb(255, 77, 109), weapons: 'Deagle · Shotgun · Sniper', players: 5, cap: 32, desc: 'Deagle, Shotgun e Sniper. C-Bug liberado somente aqui.', place: 'Mapa próprio' },
      { id: 'deagle', name: 'Arena Deagle', short: 'DEAGLE', type: 'ffa', color: rgb(255, 181, 71), weapons: 'Deagle', players: 1, cap: 32, desc: 'Somente Deagle. Cada tiro conta.', place: 'San Fierro' },
      { id: 'sniper', name: 'Arena Sniper', short: 'SNIPER', type: 'ffa', color: rgb(200, 110, 255), weapons: 'Sniper', players: 0, cap: 32, desc: 'Somente Sniper. Um tiro, uma morte.', place: 'Verdant Meadows' },
      { id: 'livre', name: 'Arena Livre', short: 'LIVRE', type: 'ffa', color: rgb(34, 230, 138), weapons: 'Deagle · Shotgun · MP5 · AK-47 · M4 · Sniper', players: 0, cap: 32, desc: 'Todas as armas clássicas. Caos total.', place: 'Area 69' },
    ],
    modes: [
      { id: 'm4_10x10', name: '10x10 M4', short: '10X10 M4', type: 'ranked', color: rgb(34, 230, 138), weapons: 'M4', players: 13, cap: 20, teamSize: 10, killTarget: 80, duration: 600, desc: '10x10 M4 · Las Payasadas · partida ranqueada', place: 'Las Payasadas' },
      { id: 'sniper_5x5', name: '5x5 Sniper', short: '5X5 SNIPER', type: 'ranked', color: rgb(200, 110, 255), weapons: 'Sniper', players: 4, cap: 10, teamSize: 5, killTarget: 30, duration: 480, desc: '5x5 Sniper · Bayside Trailer Park · partida ranqueada', place: 'Bayside Trailer Park' },
      { id: 'm4_5x5', name: '5x5 M4', short: '5X5 M4', type: 'ranked', color: rgb(120, 255, 180), weapons: 'M4', players: 0, cap: 10, teamSize: 5, killTarget: 40, duration: 480, desc: '5x5 M4 · Bayside Trailer Park · partida ranqueada', place: 'Bayside Trailer Park' },
    ],
  })
}
