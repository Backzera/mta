import React from 'react'
import { toLua } from '../bridge.js'
import { Frame } from '../ui.jsx'

const KEYS = [
  ['F1', 'Esta ajuda'], ['F2', 'Arenas e ranqueadas'], ['F3', 'Duelo X1'], ['F4', 'Loja'], ['F5', 'Ranqueadas'], ['F6', 'Clã'], ['F7', 'Caixas'],
  ['TAB', 'Placar'], ['Y / N', 'Aceitar / recusar duelo'], ['ESC', 'Fechar painel'],
]
const COMMANDS = [
  ['/arena <nome>', 'Entrar em uma arena'], ['/lobby', 'Voltar ao lobby'], ['/duelo <jogador>', 'Desafiar no X1'],
  ['/a  /c  /pm <id>', 'Chat da arena, do clã, privado'], ['/id', 'Seu ID'], ['/stats  /top', 'Estatísticas e rankings'],
  ['/saldo  /pagar', 'Dinheiro'], ['/tag <texto>', 'Tag personalizada (loja)'], ['/cla criar <TAG> <nome>', 'Fundar um clã'], ['/skin <id>', 'Trocar skin'], ['/kill', 'Suicídio'],
]

export default function Help({ server }) {
  return (
    <Frame title="AJUDA" subtitle={`Bem-vindo ao ${server || 'UTG MATA-MATA'}. Kills dão $, ranqueadas e duelos dão RP e elo.`} icon="target.png"
      onClose={() => toLua('help', 'close')} width="56vw" height="auto"
      footer="F1 ou ESC fecha · Headshot x2.2, peito reduzido · C-Bug liberado só na Arena C-Bug · Ranqueadas em MD3">
      <div className="help">
        <div>
          <span className="eyebrow">Teclas</span>
          <ul>{KEYS.map(([k, v], i) => <li key={k} style={{ animationDelay: `${i * 35}ms` }}><kbd>{k}</kbd><span>{v}</span></li>)}</ul>
        </div>
        <div>
          <span className="eyebrow">Comandos</span>
          <ul>{COMMANDS.map(([k, v], i) => <li key={k} style={{ animationDelay: `${i * 35}ms` }}><b>{k}</b><small>{v}</small></li>)}</ul>
        </div>
      </div>
    </Frame>
  )
}
