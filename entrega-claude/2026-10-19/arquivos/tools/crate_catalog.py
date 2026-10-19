"""Box definitions shared by the asset generator and the config-only updater.

Keep existing weapon box prices, rarity tiers, currency rewards and item keys.
Character ownership uses the same item keys, so this needs no account migration.
"""
import json

BOXES = [
    dict(key="municao", name="Caixa de Munição", price=5000, color=(124, 255, 178), icon="target.png", category="weapons",
         desc="Barata e viciante: skins de armas e dinheiro, com uma chance pequena de algo grande.",
         tiers=dict(comum=72, rara=22, epica=5, lendaria=0.9, mitica=0.09, ultimate=0.01)),
    dict(key="tatica", name="Caixa Tática", price=15000, color=(86, 180, 255), icon="shield.png", category="weapons",
         desc="Skins de armas raras e épicas, dinheiro e chance real de lendária.",
         tiers=dict(comum=25, rara=45, epica=24, lendaria=5, mitica=0.9, ultimate=0.1)),
    dict(key="elite", name="Caixa de Elite", price=40000, color=(245, 196, 81), icon="trophy.png", category="weapons",
         desc="Armas épicas, lendárias, míticas e a chance da ULTIMATE. Também contém dinheiro.",
         tiers=dict(rara=20, epica=50, lendaria=24, mitica=5, ultimate=1)),
    dict(key="personagens", name="Caixa de Personagens", price=15000, color=(190, 110, 255), icon="shield.png", category="characters",
         desc="Somente skins de personagens. Equipe seus prêmios no painel F10.",
         tiers=dict(rara=55, epica=30, lendaria=12, mitica=3)),
]


def render_boxes(items):
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    lines = ['DM.crates.boxes = {']
    for box in BOXES:
        pool = []
        for tier, weight in box['tiers'].items():
            candidates = [it for it in items if it['rarity'] == tier and (
                it['type'] == 'skin' if box['category'] == 'characters' else
                it['type'] == 'wskin' or (it['type'] == 'money' and tier in ('comum', 'rara')))]
            if not candidates:
                raise ValueError(f"{box['key']}: no items for {tier}")
            pool.extend((it['key'], round(weight / len(candidates), 5)) for it in candidates)
        fields = ', '.join(f'{key} = {quote(box[key])}' for key in ('key', 'name', 'category'))
        color = ', '.join(map(str, box['color']))
        lines.append(f'    {{ {fields}, price = {box["price"]}, color = {{ {color} }}, icon = {quote(box["icon"])},')
        lines.append(f'      desc = {quote(box["desc"])},')
        lines.append('      pool = { ' + ', '.join(f'{{ item = {quote(key)}, weight = {weight} }}' for key, weight in pool) + ' } },')
    return '\n'.join(lines + ['}'])


if __name__ == '__main__':
    # Only rewrites box definitions; never re-extracts/replaces existing art/models.
    from pathlib import Path
    from lupa.lua51 import LuaRuntime
    path = Path(__file__).resolve().parents[1] / 'mods/deathmatch/resources/[dm]/dm_core/shared/skins_generated.lua'
    source = path.read_text(encoding='utf-8')
    lua = LuaRuntime()
    lua.execute('DM = { crates = {} }')
    lua.execute(source)
    items = [dict(it) for it in lua.globals().DM.crates['items'].values()]
    path.write_text(source.split('DM.crates.boxes = {', 1)[0] + render_boxes(items) + '\n', encoding='utf-8')
