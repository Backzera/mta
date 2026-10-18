#!/usr/bin/env python3
"""
Gera o sistema de skins de arma a partir dos packs em dm_crates/models/weapons/:
  - dm_crates/models/<arma>.dff/.txd       modelo base (visto por todos)
  - dm_crates/skins/<arma>/<key>.png       textura de cada skin (aplicada por jogador via shader)
  - dm_ui/web/public/img/wskins/<key>.png  preview (ícone do próprio TXD) para a interface
  - dm_core/shared/skins_generated.lua     itens, raridades e caixas
  - dm_crates/meta.xml                     lista de arquivos
Rode: python3 tools/build_skins.py   (depois: cd dm_ui/web && npm run build)
"""
import os, sys, glob, shutil, re, unicodedata
sys.path.insert(0, os.path.dirname(__file__))
from extract_txd import extract
from dff_render import render_dff
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "mods", "deathmatch", "resources", "[dm]")
CRATES = os.path.join(ROOT, "dm_crates")
PACKS = os.path.join(CRATES, "models", "weapons")
UI_IMG = os.path.join(ROOT, "dm_ui", "web", "public", "img", "wskins")
UI_PIMG = os.path.join(ROOT, "dm_ui", "web", "public", "img", "pskins")
UI_WIMG = os.path.join(ROOT, "dm_ui", "web", "public", "img", "weapons")
ARMAS = os.path.join(ROOT, "dm_armas")
PSKINS = os.path.join(ROOT, "dm_skins")

# fotos frontais das skins de personagem: chave do item (lista `skins` abaixo) -> arquivos em dm_skins/
# (os modelos são carregados pelo resource dm_skins nos IDs 298-304; aqui só geramos a foto para a interface)
PED_PREVIEWS = {
    "skin_miku": ("1", "DFF_Normal/M077SonicMiku.dff", "Textures(TXD)/M077SonicMiku.txd"),
    "skin_sakura_miku": ("2", "DFF_Normal/M082SakuraMiku.dff", "Textures(TXD)/M082SakuraMiku.txd"),
    "skin_zoro": ("3", "Zoro.dff", "Zoro.txd"),
    "skin_luffy": ("4", "Lufy.dff", "Lufy.txd"),
    "skin_usada_pekora": ("5", "Usada_Pekora.dff", "Usada_Pekora.txd"),
    "skin_tanjiro": ("6", "TanjiroDS.dff", "TanjiroDS.txd"),
    "skin_naruto_bijuu": ("7", "Naruto_Bijuu.dff", "Naruto_Bijuu.txd"),
}
# ícones de armas sem skin: modelos do dm_armas (id da arma -> arquivo)
ARMAS_ICONS = {23: "silenced", 24: "desert_eagle", 25: "shotgspa", 29: "mp5lng", 34: "sniper", 16: "grenade", 4: "knifecur"}


def load_textures(txd, tmp):
    shutil.rmtree(tmp, ignore_errors=True)
    return {n.lower(): Image.open(os.path.join(tmp, n + ".png")) for n, *_ in extract(txd, tmp, 1024)}
TIERS = ["comum", "rara", "epica", "lendaria", "mitica", "ultimate"]
FAST = "--fast" in sys.argv   # reaproveita fotos de arma já geradas

# nome russo/pasta -> (nome exibido, raridade)
AK = {
    "AK-47": ("Clássica", "comum"),
    "AK-47 Африканская Сетка": ("Safari Mesh", "comum"),
    "AK-47 Цвет Джунглей": ("Jungle Spray", "comum"),
    "AK-47 Черный Глянец": ("Black Laminate", "comum"),
    "AK-47 Хищник": ("Predator", "comum"),
    "AK-47 Синий Глянец": ("Blue Laminate", "rara"),
    "AK-47 Красный Глянец": ("Red Laminate", "rara"),
    "AK-47 Элитное Снаряжение": ("Elite Build", "rara"),
    "AK-47 Первый Класс": ("First Class", "rara"),
    "AK-47 Путешественник": ("Jet Set", "rara"),
    "AK-47 Изумрудные Завитки": ("Emerald Pinstripe", "rara"),
    "AK-47 Орбита Вер. 01": ("Orbit Mk01", "rara"),
    "AK-47 Красная Линия": ("Redline", "epica"),
    "AK-47 Поверхностная Закалка": ("Case Hardened", "epica"),
    "AK-47 Ягуар": ("Jaguar", "epica"),
    "AK-47 Снежный Вихрь": ("Frontside Misty", "epica"),
    "AK-47 Неоновый Гонщик": ("Neon Rider", "epica"),
    "AK-47 Буйство Красок": ("Point Disarray", "epica"),
    "AK-47 Гидропоника": ("Hydroponic", "epica"),
    "AK-47 Картель": ("Cartel", "epica"),
    "AK-47 Вулкан": ("Vulcan", "lendaria"),
    "AK-47 Аквамариновая Месть": ("Aquamarine Revenge", "lendaria"),
    "AK-47 Пустынный Повстанец": ("Wasteland Rebel", "lendaria"),
    "AK-47 Кровавый Cпорт": ("Bloodsport", "lendaria"),
    "AK-47 Неоновая Революция": ("Neon Revolution", "lendaria"),
    "AK-47 Императрица": ("The Empress", "lendaria"),
    "AK-47 Азимов": ("Asiimov", "mitica"),
    "AK-47 Топливный Инжектор": ("Fuel Injector", "mitica"),
    "AK-47 Огненный Змей": ("Fire Serpent", "ultimate"),
}
M4 = {
    "M4A1-S Basilisk": ("Basilisk", "epica"),
    "M4A1-S Freeze": ("Freeze", "epica"),
    "M4A1-S Lince": ("Lince", "rara"),
    "M4A1-S Cyrex": ("Cyrex", "lendaria"),
    "M4A1-S Hyper Beast": ("Hyper Beast", "lendaria"),
    "M4A1-S Gold Coil": ("Golden Coil", "mitica"),
    "M4A1-S Masterpiece": ("Masterpiece", "ultimate"),
}
WEAPONS = {
    "ak47": dict(model=355, texture="AK47_BOBA_BOB", icon="ak47icon", label="AK-47",
                 base_dff=os.path.join(PACKS, "AK-47 Skin Pack из CSGO", "AK-47", "ak47.dff"),
                 base_txd=os.path.join(PACKS, "AK-47 Skin Pack из CSGO", "AK-47", "ak47.txd"),
                 folders={os.path.join(PACKS, "AK-47 Skin Pack из CSGO", k): v for k, v in AK.items()},
                 txd_name="ak47.txd"),
    "m4": dict(model=356, texture="m4a1", icon="m4icon", label="M4",
               base_dff=os.path.join(PACKS, "M4A1-S CSGO Skins pack", "DFF", "No Reflection", "m4.dff"),
               base_txd=os.path.join(PACKS, "M4A1-S CSGO Skins pack", "TXD", "M4A1-S Basilisk", "m4.txd"),
               folders={os.path.join(PACKS, "M4A1-S CSGO Skins pack", "TXD", k): v for k, v in M4.items()},
               txd_name="m4.txd"),
}


# cor do rastro / traçante / clarão das skins Mítica e Ultimate (hex RRGGBB)
FX = {"ak47_asiimov": "FF8C32", "ak47_fuel_injector": "FFB020", "ak47_fire_serpent": "FF4A1E", "m4_golden_coil": "F5C451", "m4_masterpiece": "7CC8FF"}


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def main():
    items = []
    files = []
    os.makedirs(UI_IMG, exist_ok=True)
    for wkey, w in WEAPONS.items():
        os.makedirs(os.path.join(CRATES, "models"), exist_ok=True)
        shutil.copyfile(w["base_dff"], os.path.join(CRATES, "models", wkey + ".dff"))
        shutil.copyfile(w["base_txd"], os.path.join(CRATES, "models", wkey + ".txd"))
        files += [f"models/{wkey}.dff", f"models/{wkey}.txd"]
        skindir = os.path.join(CRATES, "skins", wkey)
        os.makedirs(skindir, exist_ok=True)
        for folder, (name, rarity) in w["folders"].items():
            txd = os.path.join(folder, w["txd_name"])
            if not os.path.exists(txd):
                print("AVISO: não achei", txd); continue
            key = f"{wkey}_{slug(name)}"
            tmp = os.path.join("/tmp", "utg_skin_" + key)
            shutil.rmtree(tmp, ignore_errors=True)
            found = {n: (ww, hh, f) for n, ww, hh, f in extract(txd, tmp, 1024)}
            if w["texture"] not in found:
                print("AVISO: textura", w["texture"], "não está em", txd, "->", list(found)); continue
            shutil.copyfile(os.path.join(tmp, w["texture"] + ".png"), os.path.join(skindir, key + ".png"))
            files.append(f"skins/{wkey}/{key}.png")
            # preview: foto lateral do modelo com a textura desta skin
            out_png = os.path.join(UI_IMG, key + ".png")
            if not (FAST and os.path.exists(out_png)):
                texs = {n.lower(): Image.open(os.path.join(tmp, n + ".png")) for n in found}
                render_dff(w["base_dff"], texs, out_png, "side", (480, 200))
            items.append(dict(key=key, weapon=wkey, name=f'{w["label"]} | {name}', rarity=rarity))
            print(f"{key:36} {rarity:9} {found[w['texture']]}")

    # ---- fotos laterais das outras armas (modelos do dm_armas) para o HUD
    os.makedirs(UI_WIMG, exist_ok=True)
    for wid, base in ARMAS_ICONS.items():
        dff, txd = os.path.join(ARMAS, base + ".dff"), os.path.join(ARMAS, base + ".txd")
        if os.path.exists(dff) and os.path.exists(txd) and not (FAST and os.path.exists(os.path.join(UI_WIMG, f"{wid}.png"))):
            render_dff(dff, load_textures(txd, "/tmp/utg_armas_" + base), os.path.join(UI_WIMG, f"{wid}.png"), "side", (480, 200))
    for wid, src in {30: "ak47_classica", 31: "m4_basilisk"}.items():
        if os.path.exists(os.path.join(UI_IMG, src + ".png")):
            shutil.copyfile(os.path.join(UI_IMG, src + ".png"), os.path.join(UI_WIMG, f"{wid}.png"))

    # ---- fotos frontais das skins de personagem (modelos ficam no resource dm_skins)
    os.makedirs(UI_PIMG, exist_ok=True)
    ped_previews = {}
    for key, (folder, dff, txd) in PED_PREVIEWS.items():
        src_dff, src_txd = os.path.join(PSKINS, folder, dff), os.path.join(PSKINS, folder, txd)
        if not (os.path.exists(src_dff) and os.path.exists(src_txd)):
            print("AVISO: skin de personagem ausente:", src_dff); continue
        out_png = os.path.join(UI_PIMG, key + ".png")
        if not (FAST and os.path.exists(out_png)):
            render_dff(src_dff, load_textures(src_txd, "/tmp/utg_ped_" + key), out_png, "auto", (240, 420))
        ped_previews[key] = f"pskins/{key}.png"

    # ---- itens de dinheiro + skins antigas (texturas das outras armas) continuam
    money = [("money_2k", "$2.000", 2000, "comum"), ("money_5k", "$5.000", 5000, "comum"), ("money_12k", "$12.000", 12000, "rara"), ("money_30k", "$30.000", 30000, "epica")]
    legacy = [("wskin_carbono", "Carbono", "carbono.png", "comum"), ("wskin_neon", "Neon Verde", "neon.png", "rara"), ("wskin_rosa", "Camo Rosa", "camo_rosa.png", "rara"),
              ("wskin_galaxia", "Galáxia", "galaxia.png", "epica"), ("wskin_fogo", "Fogo", "fogo.png", "epica"), ("wskin_dourado", "Dourado", "dourado.png", "lendaria")]
    skins = [
        ("skin_305", "Lenda Urbana", 305, "rara"), ("skin_294", "Operador", 294, "rara"),
        ("skin_287", "Soldado Elite", 287, "epica"), ("skin_285", "SWAT Fantasma", 285, "epica"),
        ("skin_163", "Agente Sombra", 163, "lendaria"), ("skin_312", "Assassino UTG", 312, "mitica"),
        ("skin_miku", "Hatsune Miku", 298, "rara"),
        ("skin_sakura_miku", "Sakura Miku", 299, "epica"),
        ("skin_zoro", "Roronoa Zoro", 300, "epica"),
        ("skin_luffy", "Monkey D. Luffy", 301, "epica"),
        ("skin_usada_pekora", "Usada Pekora", 302, "lendaria"),
        ("skin_tanjiro", "Tanjiro Kamado", 303, "rara"),
        ("skin_naruto_bijuu", "Naruto Bijuu", 304, "lendaria"),
    ]

    def lua_item(d):
        return "        { " + ", ".join(f'{k} = {v if isinstance(v, (int, float)) else chr(34) + str(v) + chr(34)}' for k, v in d.items()) + " },"

    all_items = []
    for k, n, a, r in money: all_items.append(dict(key=k, type="money", name=n, amount=a, rarity=r))
    for k, n, t, r in legacy: all_items.append(dict(key=k, type="wskin", weapon="all", name=n + " (outras armas)", texture=t, rarity=r))
    for it in items:
        d = dict(key=it["key"], type="wskin", weapon=it["weapon"], name=it["name"], rarity=it["rarity"], preview=f'wskins/{it["key"]}.png')
        if it["key"] in FX: d["fx"] = FX[it["key"]]
        all_items.append(d)
    for k, n, m, r in skins:
        d = dict(key=k, type="skin", name=n, model=m, rarity=r)
        if k in ped_previews: d["preview"] = ped_previews[k]
        all_items.append(d)
    # conferência de IDs: nenhum modelo de personagem repetido
    seen = {}
    for it in all_items:
        if it["type"] == "skin":
            assert it["model"] not in seen, f"ID {it['model']} repetido: {seen[it['model']]} e {it['key']}"
            seen[it["model"]] = it["key"]

    # ---- caixas: peso por raridade dividido entre os itens daquela raridade
    boxes = [
        dict(key="municao", name="Caixa de Munição", price=5000, color=(124, 255, 178), icon="target.png",
             desc="Barata e viciante: skins comuns e raras, com uma chance pequena de algo grande.",
             tiers=dict(comum=72, rara=22, epica=5, lendaria=0.9, mitica=0.09, ultimate=0.01)),
        dict(key="tatica", name="Caixa Tática", price=15000, color=(86, 180, 255), icon="shield.png",
             desc="Skins raras e épicas com chance real de lendária.",
             tiers=dict(comum=25, rara=45, epica=24, lendaria=5, mitica=0.9, ultimate=0.1)),
        dict(key="elite", name="Caixa de Elite", price=40000, color=(245, 196, 81), icon="trophy.png",
             desc="Só o topo: épicas, lendárias, míticas e a chance da ULTIMATE.",
             tiers=dict(rara=20, epica=50, lendaria=24, mitica=5, ultimate=1)),
    ]
    out = ['-- GERADO por tools/build_skins.py — não edite à mão (edite o script e rode de novo)',
           'DM.crates.rarities = {',
           '    comum    = { name = "Comum",    color = { 150, 165, 155 } },',
           '    rara     = { name = "Rara",     color = { 86, 180, 255 } },',
           '    epica    = { name = "Épica",    color = { 190, 110, 255 } },',
           '    lendaria = { name = "Lendária", color = { 245, 196, 81 } },',
           '    mitica   = { name = "Mítica",   color = { 255, 77, 109 } },',
           '    ultimate = { name = "Ultimate", color = { 124, 255, 178 } },',
           '}',
           '-- armas com modelo base próprio (todos veem) e textura por jogador (shader)',
           'DM.crates.weaponSkins = {']
    for wkey, w in WEAPONS.items():
        out.append(f'    {wkey} = {{ model = {w["model"]}, texture = "{w["texture"]}", label = "{w["label"]}" }},')
    out += ['}', 'DM.crates.skinMode = "player"   -- "player": cada jogador vê a skin de cada um; "local": você vê a sua em todas as armas do tipo', 'DM.crates.items = {']
    for d in all_items: out.append(lua_item(d))
    out += ['}', 'DM.crates.boxes = {']
    for b in boxes:
        pool = []
        for tier, weight in b["tiers"].items():
            # dinheiro só entra nas raridades baixas da caixa (comum/rara) para não "roubar" os pesos altos
            cand = [it for it in all_items if it["rarity"] == tier and (it["type"] != "money" or tier in ("comum", "rara"))]
            if not cand: continue
            for it in cand: pool.append((it["key"], round(weight / len(cand), 5)))
        out.append(f'    {{ key = "{b["key"]}", name = "{b["name"]}", price = {b["price"]}, color = {{ {b["color"][0]}, {b["color"][1]}, {b["color"][2]} }}, icon = "{b["icon"]}",')
        out.append(f'      desc = "{b["desc"]}",')
        out.append('      pool = { ' + ", ".join(f'{{ item = "{k}", weight = {w} }}' for k, w in pool) + ' } },')
    out.append('}')
    gen = os.path.join(ROOT, "dm_core", "shared", "skins_generated.lua")
    open(gen, "w", encoding="utf-8").write("\n".join(out) + "\n")

    # ---- meta.xml do dm_crates
    meta = ['<meta>',
            '    <info author="UTG" name="DM Crates" description="Caixas (F7): skins de arma por jogador (CS:GO AK-47 / M4A1-S), skins exclusivas, dinheiro; inventário e equipar" type="script" version="2.0.0" />',
            '    <include resource="dm_core" />',
            '    <script src="server/s_crates.lua" type="server" />',
            '    <script src="client/c_skins.lua" type="client" />',
            '    <script src="client/c_fx.lua" type="client" />',
            '    <file src="texreplace.fx" />',
            '    <file src="fx/glow.png" />']
    meta += [f'    <file src="textures/{t}" />' for _, _, t, _ in legacy]
    meta += [f'    <file src="{f}" />' for f in files]
    meta += ['    <min_mta_version server="1.5.9" client="1.5.9" />', '</meta>']
    open(os.path.join(CRATES, "meta.xml"), "w", encoding="utf-8").write("\n".join(meta) + "\n")
    print(f"\n{len(items)} skins, {len(all_items)} itens, {len(files)} arquivos no meta")


if __name__ == "__main__":
    main()
