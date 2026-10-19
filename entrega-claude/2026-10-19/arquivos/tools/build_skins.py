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
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "mods", "deathmatch", "resources", "[dm]")
CRATES = os.path.join(ROOT, "dm_crates")
PACKS = os.path.join(CRATES, "models", "weapons")
UI_IMG = os.path.join(ROOT, "dm_ui", "web", "public", "img", "wskins")
TIERS = ["comum", "rara", "epica", "lendaria", "mitica", "ultimate"]

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
            # preview: ícone do TXD (ou a textura, se não houver)
            src = os.path.join(tmp, (w["icon"] if w["icon"] in found else w["texture"]) + ".png")
            im = Image.open(src).convert("RGBA")
            im.thumbnail((320, 320), Image.LANCZOS)
            im.save(os.path.join(UI_IMG, key + ".png"), optimize=True)
            items.append(dict(key=key, weapon=wkey, name=f'{w["label"]} | {name}', rarity=rarity))
            print(f"{key:36} {rarity:9} {found[w['texture']]}")

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
        d = dict(key=it["key"], type="wskin", weapon=it["weapon"], name=it["name"], rarity=it["rarity"], preview=1)
        if it["key"] in FX: d["fx"] = FX[it["key"]]
        all_items.append(d)
    for k, n, m, r in skins: all_items.append(dict(key=k, type="skin", name=n, model=m, rarity=r))

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
    out.append('}')
    from crate_catalog import render_boxes
    out.extend(render_boxes(all_items).splitlines())
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
