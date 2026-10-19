// Dados de exemplo para visualizar as telas fora do jogo: index.html?demo=<tela>
const rgb = (r, g, b) => [r, g, b]
const G = rgb(34, 230, 138), G2 = rgb(124, 255, 178), GOLD = rgb(245, 196, 81)
const arenas = [
  { id: 'lobby', name: 'Lobby', type: 'lobby', safe: true, color: rgb(124, 255, 178), weapons: 'Sem armas', players: 12, cap: 64, desc: 'Zona segura. Escolha uma arena para começar.', place: 'Pershing Square · Los Santos' },
  { id: 'ak47', name: 'Arena AK-47', type: 'ffa', color: rgb(34, 230, 138), weapons: 'AK-47', players: 9, cap: 32, desc: 'Somente AK-47. Mapa fechado em Las Venturas.', place: 'Las Venturas · mapa próprio' },
  { id: 'm4', name: 'Arena M4', type: 'ffa', color: rgb(70, 240, 160), weapons: 'M4', players: 6, cap: 32, desc: 'Somente M4. Base militar em Verdant Bluffs.', place: 'Verdant Bluffs · mapa próprio' },
  { id: 'x1', name: 'Arena X1', type: 'duel', safe: true, color: rgb(160, 255, 200), weapons: 'Arma escolhida no duelo', players: 4, cap: 32, desc: 'Duelos 1v1 em sala privada. Pressione F3 para desafiar.', place: 'Mapa flutuante' },
  { id: 'cbug', name: 'Arena C-Bug', type: 'ffa', cbug: true, color: rgb(20, 200, 120), weapons: 'Deagle · Shotgun · Sniper', players: 5, cap: 32, desc: 'C-Bug liberado somente aqui.', place: 'Mapa próprio' },
  { id: 'deagle', name: 'Arena Deagle', type: 'ffa', color: rgb(0, 170, 100), weapons: 'Deagle', players: 1, cap: 32, desc: 'Somente Deagle.', place: 'San Fierro' },
  { id: 'sniper', name: 'Arena Sniper', type: 'ffa', color: rgb(110, 220, 170), weapons: 'Sniper', players: 0, cap: 32, desc: 'Somente Sniper.', place: 'Verdant Meadows' },
  { id: 'livre', name: 'Arena Livre', type: 'ffa', color: rgb(200, 255, 220), weapons: 'Deagle · Shotgun · MP5 · AK-47 · M4 · Sniper', players: 0, cap: 32, desc: 'Todas as armas.', place: 'Area 69' },
]
const modes = [
  { id: 'm4_10x10', name: '10x10 M4', type: 'ranked', color: G, weapons: 'M4', players: 13, cap: 20, teamSize: 10, roundTime: 300, roles: true, desc: '10x10 · Las Payasadas · MD3', place: 'Las Payasadas', armor: 100, waiting: 13, playing: 20, matches: 1 },
  { id: 'sniper_5x5', name: '5x5 Sniper', type: 'ranked', color: rgb(110, 220, 170), weapons: 'Sniper', players: 4, cap: 10, teamSize: 5, roundTime: 300, roles: false, desc: '5x5 Sniper · Bayside', place: 'Bayside Trailer Park', armor: 0, waiting: 4, playing: 0, matches: 0 },
  { id: 'm4_5x5', name: '5x5 M4', type: 'ranked', color: G2, weapons: 'M4', players: 0, cap: 10, teamSize: 5, roundTime: 300, roles: true, desc: '5x5 M4 · Bayside', place: 'Bayside Trailer Park', armor: 100, waiting: 0, playing: 10, matches: 1 },
]
const player = { name: 'hehenr', tier: 'OURO', tierColor: GOLD, money: 626000, rp: 640 }
const hud = {
  visible: true, name: 'hehenr', nameColor: '#7CFFB2', tag: { text: 'VIP OURO', hex: '#F5C451', glyph: '♛' }, clan: { text: 'UTG', hex: '#22E68A', glyph: '◆' },
  tier: 'OURO', tierShort: 'OUR', tierColor: GOLD, money: 626000, rp: 640, health: 72, armor: 40, weapon: 'M4', clip: 23, reserve: 577, clipSize: 50, hasAmmo: true, streak: 4, weaponIcon: '31.png', skin: { name: 'Masterpiece', rarity: 'Ultimate', color: '#7CFFB2', preview: 'wskins/m4_masterpiece.png' },
  arena: { name: 'Arena M4', color: rgb(70, 240, 160), players: 6, safe: false, type: 'ffa' }, server: 'UTG MATA-MATA #Return2k26', online: 37, fps: 98, ping: 42, protected: 0,
  hints: [['F2', 'Jogar'], ['F3', 'Duelo'], ['F4', 'Loja'], ['F6', 'Clã'], ['F7', 'Caixas'], ['TAB', 'Placar']],
}
export function run(screen) {
  document.body.style.background = 'radial-gradient(80vw 60vh at 70% 40%, #2f3a34, #121a15 70%)'
  const ui = window.ui
  ui.set('hud', hud)
  ui.set('duel', { incoming: [] })
  if (screen === 'hud') {
    ui.push('kill', { killer: 'hehenr', victim: 'Zeca', weapon: 'M4', headshot: true, mine: true, skin: { name: 'Masterpiece', color: '#7CFFB2' } })
    ui.push('kill', { killer: 'Tony', victim: 'hehenr', weapon: 'AK-47', me: true })
    ui.push('toast', { text: 'Você subiu para o elo Ouro!', type: 'success', title: 'Elo' })
    ui.push('reward', { text: 'Você eliminou Zeca', money: 250, headshot: true })
    ui.push('pop', { amount: 250, reason: 'Headshot' })
    ui.push('streak', { name: 'hehenr', streak: 5, text: 'está IMPARÁVEL!' })
    ui.set('duel', { incoming: [{ id: 1, from: 'Tony', weapon: 'Deagle', rounds: 3, left: 25, ttl: 30 }] })
    return
  }
  if (screen === 'rhud') { ui.merge('hud', { ranked: { state: 'countdown', left: 14, nameA: 'Time Verde', nameB: 'Time Laranja', myTeam: 'A', roles: { A: { sniper: 'Zeca' }, B: { sniper: null } }, myRole: 'm4', rolePick: true, players: 10, needed: 10 } }); return }
  if (screen === 'rhud2') { ui.merge('hud', { ranked: { state: 'round', left: 212, round: 2, roundsA: 1, roundsB: 0, roundsToWin: 2, aliveA: 4, aliveB: 3, nameA: 'Time Verde', nameB: 'Time Laranja', myTeam: 'A', myRole: 'sniper' } }); return }
  const data = {
    hub: { arenas, modes, current: 'lobby', online: 37, player },
    shop: { money: 626000, cats: [
      { key: 'tags', label: 'Tags', title: 'TAGS', desc: 'Exibidas no chat, no placar e acima do seu nick.', items: [
        { id: 'veterano', cat: 'tags', key: 'veterano', title: 'VETERANO', desc: 'Tag com ícone no chat, no placar e acima do nick.', price: 15000, color: rgb(120, 220, 255), state: 'owned', sample: '[✦ VETERANO]' },
        { id: 'assassino', cat: 'tags', key: 'assassino', title: 'ASSASSINO', desc: 'Tag com ícone no chat, no placar e acima do nick.', price: 40000, color: rgb(255, 77, 109), state: 'buy', sample: '[☠ ASSASSINO]' },
        { id: 'lenda', cat: 'tags', key: 'lenda', title: 'LENDA', desc: 'Tag com ícone no chat.', price: 100000, color: GOLD, state: 'equipped', sample: '[♛ LENDA]' },
        { id: 'custom', cat: 'tags', key: 'custom', title: 'TAG PERSONALIZADA', desc: 'Seu próprio texto (2 a 12 caracteres) com /tag <texto>.', price: 950000, color: G2, state: 'buy', sample: '[✿ SUA TAG]' },
        { id: 'tag_none', cat: 'unequip', key: 'tag', title: 'TAG DO ELO', desc: 'Volta a exibir o seu elo no lugar da tag comprada.', price: 0, color: rgb(150, 165, 155), state: 'owned' },
      ] },
      { key: 'nameColors', label: 'Cores de nick', title: 'CORES DE NICK', desc: 'Cor do seu nome em todo o servidor.', items: [] },
      { key: 'vip', label: 'VIP', title: 'VIP', desc: 'Mais $, bônus diário maior, respawn rápido, skins e tag.', items: [] },
      { key: 'extras', label: 'Extras', title: 'EXTRAS', desc: 'Vantagens permanentes.', items: [] },
    ] },
    duel: { players: [{ id: 1001, name: 'Tony', tierShort: 'PRT', tierColor: rgb(192, 198, 210) }, { id: 1002, name: 'Zeca', tierShort: 'OUR', tierColor: GOLD, inDuel: true }, { id: 1003, name: 'Marcelinho', tierShort: 'BRZ', tierColor: rgb(205, 127, 50) }],
      sets: [{ key: 'deagle', name: 'Deagle' }, { key: 'shotgun', name: 'Shotgun' }, { key: 'combat', name: 'Combat Shotgun' }, { key: 'sawnoff', name: 'Sawn-off' }, { key: 'mp5', name: 'MP5' }, { key: 'ak47', name: 'AK-47' }, { key: 'm4', name: 'M4' }, { key: 'rifle', name: 'Rifle' }, { key: 'sniper', name: 'Sniper' }, { key: 'katana', name: 'Katana' }, { key: 'fists', name: 'Soco' }, { key: 'classic', name: 'Clássico (D+S+S)' }],
      incoming: [{ id: 7, from: 'Tony', weapon: 'Deagle', rounds: 3, left: 22, ttl: 30 }], outgoing: null },
    ranked: { modes, current: 'lobby', me: { tier: 'OURO', rp: 640 } },
    clans: { loaded: true, money: 626000, myName: 'hehenr', createCost: 50000, minClanMatch: 2, palette: [G, rgb(34, 211, 238), rgb(139, 92, 246), GOLD, rgb(255, 77, 109), rgb(255, 140, 66), rgb(255, 105, 180), rgb(120, 220, 255)],
      clan: { id: 1, name: 'Unidos do Gueto', tag: 'UTG', color: G, points: 120, wins: 5, losses: 1, role: 'leader', members: [{ name: 'hehenr', role: 'leader', rp: 640, online: true }, { name: 'Tony', role: 'officer', rp: 320, online: true }, { name: 'Zeca', role: 'member', rp: 90, online: false }] },
      clans: [{ id: 1, tag: 'UTG', name: 'Unidos do Gueto', points: 120, wins: 5, losses: 1, online: 2, color: G }, { id: 2, tag: 'DMZ', name: 'Dimensão Z', points: 60, wins: 2, losses: 2, online: 1, color: rgb(139, 92, 246) }],
      invites: [], challenge: null, modes: modes.map((m) => ({ id: m.id, name: m.name, teamSize: m.teamSize })), candidates: [{ id: 1003, name: 'Marcelinho' }] },
    crates: { money: 626000, hasTrail: true, trail: 'rgb', owned: ['wskin_neon', 'skin_305', 'skin_zoro', 'ak47_asiimov', 'ak47_fire_serpent', 'm4_hyper_beast', 'ak47_redline', 'm4_masterpiece'], equippedW: { ak47: 'ak47_asiimov', all: 'wskin_neon' }, equippedSkin: 0,
      rarities: { comum: { name: 'Comum', color: rgb(150, 165, 155) }, rara: { name: 'Rara', color: rgb(86, 180, 255) }, epica: { name: 'Épica', color: rgb(190, 110, 255) }, lendaria: { name: 'Lendária', color: GOLD }, mitica: { name: 'Mítica', color: rgb(255, 77, 109) }, ultimate: { name: 'Ultimate', color: G2 } },
      items: [{ key: 'money_3k', type: 'money', name: '$3.000', rarity: 'comum' }, { key: 'money_25k', type: 'money', name: '$25.000', rarity: 'rara' }, { key: 'wskin_neon', type: 'wskin', name: 'Neon Verde', texture: 'neon.png', rarity: 'rara' }, { key: 'wskin_dourado', type: 'wskin', name: 'Dourado', texture: 'dourado.png', rarity: 'lendaria' }, { key: 'wskin_fogo', type: 'wskin', name: 'Fogo', texture: 'fogo.png', rarity: 'epica' }, { key: 'skin_305', type: 'skin', name: 'Lenda Urbana', model: 305, rarity: 'rara' }, { key: 'skin_zoro', type: 'skin', name: 'Roronoa Zoro', model: 11, rarity: 'lendaria', preview: 'pskins/skin_zoro.png' }, { key: 'skin_163', type: 'skin', name: 'Agente Sombra', model: 163, rarity: 'lendaria' }, { key: 'ak47_asiimov', type: 'wskin', weapon: 'ak47', weaponLabel: 'AK-47', name: 'AK-47 | Asiimov', rarity: 'mitica', preview: 'wskins/ak47_asiimov.png' }, { key: 'ak47_fire_serpent', type: 'wskin', weapon: 'ak47', weaponLabel: 'AK-47', name: 'AK-47 | Fire Serpent', rarity: 'ultimate', preview: 'wskins/ak47_fire_serpent.png' }, { key: 'm4_hyper_beast', type: 'wskin', weapon: 'm4', weaponLabel: 'M4', name: 'M4 | Hyper Beast', rarity: 'lendaria', preview: 'wskins/m4_hyper_beast.png' }, { key: 'ak47_redline', type: 'wskin', weapon: 'ak47', weaponLabel: 'AK-47', name: 'AK-47 | Redline', rarity: 'epica', preview: 'wskins/ak47_redline.png' }, { key: 'm4_masterpiece', type: 'wskin', weapon: 'm4', weaponLabel: 'M4', name: 'M4 | Masterpiece', rarity: 'ultimate', preview: 'wskins/m4_masterpiece.png' }],
      boxes: [
        { key: 'comum', name: 'Caixa Comum', price: 12000, color: G2, icon: 'target.png', desc: 'Dinheiro e skins de arma comuns, com chance de rara.', pool: [{ item: 'money_3k', weight: 40 }, { item: 'wskin_neon', weight: 8 }, { item: 'skin_305', weight: 3 }] },
        { key: 'rara', name: 'Caixa Rara', price: 40000, color: rgb(120, 210, 255), icon: 'shield.png', desc: 'Skins raras e épicas, dinheiro alto e chance de lendária.', pool: [{ item: 'money_25k', weight: 18 }, { item: 'wskin_fogo', weight: 6 }, { item: 'wskin_dourado', weight: 2 }] },
        { key: 'lendaria', name: 'Caixa Lendária', price: 100000, color: GOLD, icon: 'trophy.png', desc: 'Só épicos e lendários: skins exclusivas e a arma dourada.', pool: [{ item: 'wskin_fogo', weight: 16 }, { item: 'wskin_dourado', weight: 5 }, { item: 'skin_163', weight: 4 }, { item: 'ak47_asiimov', weight: 3 }, { item: 'm4_masterpiece', weight: 1 }] },
      ] },
    board: { server: 'UTG MATA-MATA #Return2k26', rows: Array.from({ length: 14 }, (_, i) => ({ id: 1000 + i, name: ['hehenr', 'Tony', 'Zeca', 'Marcelinho', 'Bia', 'Rafa'][i % 6] + (i > 5 ? i : ''), me: i === 0, tag: i % 3 === 0 ? { text: 'VIP', hex: '#F5C451', glyph: '★' } : null, clan: i % 2 === 0 ? { text: 'UTG', hex: '#22E68A' } : null, tier: ['Ouro', 'Prata', 'Bronze'][i % 3], tierColor: [GOLD, rgb(192, 198, 210), rgb(205, 127, 50)][i % 3], rp: 900 - i * 40, kills: 300 - i * 12, deaths: 120 + i * 3, kd: (300 - i * 12) / (120 + i * 3), arena: ['M4', 'AK-47', 'LOBBY'][i % 3], arenaColor: G, ping: 30 + i * 9, streak: i === 1 ? 5 : 0, nameColor: '#fff' })) },
    login: { message: 'Bem-vindo de volta, hehenr! Clique em ENTRAR para jogar.', type: 'success', user: 'hehenr', pass: '12345678', remember: true },
    help: {},
  }
  // A prévia também respeita a separação usada pelo catálogo real do servidor.
  const characters = data.crates.items.filter((it) => it.type === 'skin')
  const characterKeys = new Set(characters.map((it) => it.key))
  data.crates.boxes = data.crates.boxes.map((b) => ({ ...b, pool: b.pool.filter((p) => !characterKeys.has(p.item)) }))
  data.crates.boxes.push({ key: 'personagens', name: 'Caixa de Personagens', price: 15000, color: rgb(190, 110, 255), icon: 'shield.png',
    desc: 'Somente skins de personagens. Equipe seus prêmios no painel F10.', pool: characters.map((it) => ({ item: it.key, weight: 1 })) })
  data.crosshair = { settings: { enabled: true, style: 'classicdot', color: '#22E68A', size: 7, thickness: 2, gap: 4, opacity: 255, outline: true, followAim: true, offsetX: 0, offsetY: 0 } }
  data.characters = { items: characters, owned: data.crates.owned.filter((key) => characterKeys.has(key)), rarities: data.crates.rarities, equippedSkin: data.crates.equippedSkin }
  if (screen === 'inv') { ui.open('crates', data.crates); return }
  if (screen === 'reel') {
    ui.open('crates', data.crates)
    ui.push('reel', { box: 'rara', result: 'ak47_fire_serpent', duplicate: false, target: 34, items: Array.from({ length: 40 }, (_, i) => (i === 33 ? 'ak47_fire_serpent' : ['money_3k', 'ak47_redline', 'wskin_neon', 'm4_hyper_beast', 'ak47_asiimov'][i % 5])) })
    return
  }
  ui.open(screen, data[screen])
}
