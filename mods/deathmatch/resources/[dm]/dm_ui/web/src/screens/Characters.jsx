import React, { useState } from 'react'
import { toLua, asArray, asObj } from '../bridge.js'
import { Frame, Btn, Tabs, Empty } from '../ui.jsx'
import { ItemCard, RARITY_ORDER } from './Crates.jsx'

export default function Characters({ st }) {
  const d = st || {}
  const [tab, setTab] = useState('owned')
  const owned = asArray(d.owned), rarities = asObj(d.rarities)
  const characters = asArray(d.items).filter((it) => it.type === 'skin')
  const items = characters.filter((it) => tab === 'all' || owned.includes(it.key))
    .sort((a, b) => RARITY_ORDER.indexOf(b.rarity) - RARITY_ORDER.indexOf(a.rarity))
  const equipped = characters.find((it) => it.model === d.equippedSkin)

  return (
    <Frame title="PERSONAGENS" icon="shield.png"
      subtitle="Suas skins de personagens, salvas na conta. Ganhe novas na Caixa de Personagens do F7."
      badge={`${owned.length} / ${characters.length}`} width="70vw" height="86vh"
      onClose={() => toLua('characters', 'close')}
      footer="F10 ou ESC fecha · a skin equipada continua na sua conta ao reconectar">
      <Tabs tabs={[[ 'owned', 'MEUS PERSONAGENS' ], [ 'all', 'TODOS OS PERSONAGENS' ]]} value={tab} onChange={setTab} />
      <div className="inv">
        <div className="hrow"><span className="hint">Equipada: {equipped ? equipped.name : d.equippedSkin ? `Skin ${d.equippedSkin}` : 'Padrão'}</span></div>
        {items.length === 0 && <Empty>Você ainda não tem personagens. Abra a Caixa de Personagens no F7!</Empty>}
        <div className="inv__grid">
          {items.map((it) => {
            const has = owned.includes(it.key), eq = d.equippedSkin === it.model
            return (
              <ItemCard key={it.key} it={it} rar={rarities[it.rarity] || { name: it.rarity, color: [150, 165, 155] }} selected={eq}>
                <Btn kind={eq ? 'ghost' : 'outline'} disabled={!has || eq} onClick={() => toLua('characters', 'equip', { key: it.key })}>
                  {eq ? 'EQUIPADA ✓' : has ? 'EQUIPAR' : 'NÃO OBTIDA'}
                </Btn>
              </ItemCard>
            )
          })}
        </div>
        <div className="hrow">
          <Btn kind="ghost" onClick={() => toLua('characters', 'equip', { key: 'skin:none' })}>SKIN PADRÃO</Btn>
          <Btn kind="outline" onClick={() => toLua('characters', 'boxes')}>ABRIR CAIXAS · F7</Btn>
        </div>
      </div>
    </Frame>
  )
}
