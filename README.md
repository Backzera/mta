# UTG MATA-MATA #Return2k26 — Servidor MTA:SA

Servidor de PVP completo para Multi Theft Auto: San Andreas. Arenas por arma, duelo X1, arena de C-Bug,
partidas ranqueadas 5x5/10x10 com aquecimento, clãs e clã x clã, economia com loja (tags, VIP, cores),
sistema de dano com headshot, sons de arma próprios e interface moderna (dx, fonte Poppins, logo UTG).

```
mods/deathmatch/
├── mtaserver.conf              configuração do servidor (recursos já listados, na ordem certa)
├── acl-adicionar.txt           linhas para colocar no grupo Admin do acl.xml
└── resources/[dm]/
    ├── dm_core      núcleo: arenas, spawn, armas, kills ($), stats, tags, economia, HUD, painéis, chat, comandos
    ├── dm_maps      carrega maps/<arena>.map na dimensão da arena (+ portão da M4); clona o X1 para os duelos
    ├── dm_weapons   dano por parte do corpo (headshot = morte instantânea, peito x0.5), sons de tiro, skins de arma
    ├── dm_cbug      C-Bug liberado só na Arena C-Bug
    ├── dm_duel      duelo X1 (F3): pedidos, sala privada, rodadas, RP e $
    ├── dm_shop      loja (F4): tags, cores de nick, VIP, extras
    ├── dm_ranked    ranqueadas (F5): 10x10 M4 Las Payasadas · 5x5 Sniper e 5x5 M4 Bayside, aquecimento, times por elo
    ├── dm_clans     clãs (F6): criar, convidar, cargos, ranking, clã x clã
    └── dm_login     login/registro, lembrar-me, convidado
Arena AK47/, Arena CBUG/, Arena M4/, Arena X1/   mapas originais (já copiados para dm_maps/maps)
```

## Instalação

1. Baixe o servidor MTA:SA (https://multitheftauto.com) e extraia.
2. Copie `mods/deathmatch/mtaserver.conf` e a pasta `mods/deathmatch/resources/[dm]` para a mesma
   estrutura do servidor (mantenha os recursos padrão do pacote: admin, resourcemanager...).
3. No `mods/deathmatch/acl.xml` do servidor, dentro de `<group name="Admin">`, adicione as linhas de
   `acl-adicionar.txt` (`resource.dm_core`, `resource.dm_login`, `resource.dm_duel`). Sem isso o registro
   de contas e `/kick` `/ban` não funcionam.
4. Inicie o servidor. Os 9 recursos `dm_*` iniciam pelo `mtaserver.conf`.
5. Admin: registre-se no jogo e adicione `<object name="user.SEUUSUARIO" />` no grupo Admin do `acl.xml`
   (o servidor pode pedir `authserial SEUUSUARIO` no console na primeira vez). A tag no chat/nametag vem
   do grupo: Admin → ADMIN, SuperModerator → SUPERVISOR, Moderator → MODERADOR, Helper → AJUDANTE.

## Teclas

| Tecla | Função                | Tecla | Função                         |
|-------|-----------------------|-------|--------------------------------|
| F1    | Ajuda                 | F4    | Loja (tags, cores, VIP, extras)|
| F2    | Arenas                | F5    | Partidas ranqueadas            |
| F3    | Duelo X1              | F6    | Clã                            |
| F7    | Caixas e inventário de armas | F9  | Mira (galeria e ajuste fino) |
|       |                       | F10   | Personagens                    |
| TAB   | Placar (tags, clã, elo, RP, K/D) | Y / N | Aceitar / recusar duelo |

Comandos: `/arena <id>` `/lobby` `/duelo <jogador>` `/stats` `/top rp|kills|money|duelos` `/saldo`
`/pagar <jogador> <valor>` `/tag <texto>` `/cla criar <TAG> <nome>` `/skin <id>` `/pm` `/kill`.
Admin: `/kick` `/ban` `/mute` `/unmute` `/tp` `/anuncio` `/dar <jogador> <$>` `/setvip <jogador> <0-3> [dias]` `/darrp`.

## Como o progresso funciona (feito para segurar o jogador)

- **Kills dão só $** (`$120` + `$60` headshot + bônus de sequência). **RP e elo** vêm apenas de
  ranqueadas (vitória +20, derrota -10, +1 por kill, MVP +5) e duelos (+5 / -3).
- Elos por RP: Bronze 0 · Prata 200 · Ouro 500 · Platina 900 · Diamante 1400 · Mestre 2000 · Lenda 3000.
- $ também por tempo online (`$300` a cada 10 min), bônus diário (`$1.000`, VIP mais), duelo (`$500`),
  ranqueada (`$1.500` vitória / `$400` derrota).
- **Loja (F4)**: tags Veterano `$15k` · Assassino/Sniper `$40k` · Lenda `$100k` · Personalizada `$150k`
  (`/tag`), cores de nick `$30k–45k`, VIP Bronze/Prata/Ouro (30 dias) `$60k/150k/300k` com 1.25x/1.5x/2x
  de $, bônus diário maior, respawn rápido, nick colorido, todas as skins e tag VIP destacada; extras
  (pacote de skins `$25k`, respawn rápido `$50k`). Comprou uma vez, equipa quando quiser.
- **Clã**: criar custa `$50k`. Pontos de clã por clã x clã (+30 / -15).
Tudo em `dm_core/shared/config.lua` (`DM.economy`, `DM.rp`, `DM.tiers`, `DM.shop`, `DM.vip`, `DM.clans`).

## Arenas (F2)

| id | Arena | Armas | Mapa |
|----|-------|-------|------|
| `lobby` | Lobby (seguro) | — | Pershing Square |
| `ak47` | Arena AK-47 | AK-47 | `ak47.map` (Las Venturas) |
| `m4` | Arena M4 | M4 | `m4.map` (Verdant Bluffs) + portão |
| `x1` | Arena X1 | escolhida no duelo | `x1.map` (sala de espera; cada duelo recebe uma cópia do mapa) |
| `cbug` | Arena C-Bug | Deagle, Shotgun, Sniper | `cbug.map`, **C-Bug liberado** |
| `deagle` `sniper` `shotgun` `melee` `livre` | arenas sem mapa | Deagle / Sniper / Combat Shotgun / Katana / mix | chão nativo do GTA |

Spawns dos mapas sem `<spawnpoint>` foram calculados pela geometria e estão em `config.lua`
(`spawns`, e `duelSpots` para o X1). Se um jogador nascer no vazio, o cliente detecta a queda e o servidor
reposiciona no spawn âncora.

## Ranqueadas (F5) — MD3

| Modo | Local | Jogadores | Armas | Papéis |
|------|-------|-----------|-------|--------|
| 10x10 M4 | Las Payasadas | 20 | M4, colete 100 | 1 sniper por time (Sniper + M4), resto só M4 |
| 5x5 Sniper | Bayside Trailer Park | 10 | Sniper | todos iguais |
| 5x5 M4 | Bayside Trailer Park | 10 | M4, colete 100 | 1 sniper por time (Sniper + M4), resto só M4 |

Fluxo: entra → **aquecimento** (FFA com as armas do modo, sem recompensa) até completar os jogadores →
**contagem de 20 s** com os times já formados por RP (Time Verde x Time Laranja) e a **escolha de papel**
(SNIPER ou M4; só um sniper por time — se ninguém escolher, um é sorteado) → **melhor de 3 rounds de
5 minutos, sem respawn**: o time que eliminar o outro vence o round; se o tempo acabar com jogadores vivos
dos dois lados, todos os vivos são teleportados para a **morte súbita** (área pequena cercada por um
col-shape; quem sair é devolvido) até sobrar um lado (limite de 90 s: mais vivos vence) → primeiro a 2
rounds vence → resultado (RP, $, MVP) → volta ao aquecimento. Quem morre assiste um companheiro até o fim
do round. Cada instância tem a sua dimensão; partidas em andamento não aceitam entrada. Sair no meio conta
derrota. Tudo em `DM.ranked` (`roundTime`, `roundsToWin`, `suddenDeathMax`, `sniperLoadout`).

**Spawns dos times e da morte súbita são aproximados** (`DM.rankedModes[*].teamSpawns` / `suddenDeath`,
chão nativo com ajuste automático ao solo). Me mande as posições marcadas (`x, y, z, rotação`) e eu
atualizo — ou edite direto.

## Clãs (F6) e clã x clã

Criar (`TAG` 2-5 letras, nome 3-20), convidar jogadores online, cargos (líder, oficial, membro), cor da
tag, ranking de clãs. Líder/oficial seleciona um clã no ranking, escolhe o modo e desafia; o outro clã
aceita no F6 e os membros online dos dois (mesmo número por lado, mínimo 2) entram em uma partida de times
privada com as tags dos clãs. Resultado anunciado para o servidor com o placar.

## Sistemas de combate

- **Dano**: o cliente da vítima cancela o dano padrão das armas de fogo e o servidor aplica por parte do
  corpo: **cabeça = morte instantânea com qualquer arma de fogo (ignora vida e colete)**, peito/quadril x0.5, braços x0.8, pernas x0.7. Mortes passam
  por `killPed`, então killer/arma ficam corretos no kill chat. Sem fogo amigo nas ranqueadas.
- **Kill feedback**: caveira/ícone de headshot no centro, som de headshot, `+$` ganho; killfeed no canto
  superior direito só da sua arena/dimensão; sequências com banner.
- **Sons de arma**: os do GTA são silenciados (grupo 5) e substituídos por `dm_weapons/sounds/<id>.wav`
  (gerados proceduralmente — troque pelos seus .wav mantendo o nome).
- **Skins de arma**: precisam de `.dff/.txd` (binários de pack de skins). Coloque em `dm_weapons/models/`
  e liste no `meta.xml` conforme `models/LEIA-ME.txt`; o carregador aplica automaticamente.
- **Munição**: ao trocar de arma e pegar de novo ela volta cheia; ao matar recarrega.
- **Nametags**: tag (staff/VIP/comprada/elo) e tag do clã destacadas acima do nick colorido, vida e colete.

## Skins de arma (caixas F7)

Packs CS:GO em `dm_crates/models/weapons/` (AK-47: 29 skins, M4A1-S: 7). `tools/build_skins.py` extrai
a textura principal de cada `.txd` para `dm_crates/skins/<arma>/<key>.png`, o ícone para a interface, copia
o modelo base para `dm_crates/models/<arma>.dff/.txd` e gera `dm_core/shared/skins_generated.lua`
(itens, raridades, caixas) e o `meta.xml` do `dm_crates`. Como funciona no jogo: o modelo base (CS:GO)
substitui a AK-47 e a M4 para todos; a skin de cada jogador é só a textura, aplicada com shader
restrito ao ped dele, então cada um vê a skin de cada um. Se o seu MTA não aplicar shader por ped na
arma, troque `DM.crates.skinMode` para `"local"` (você vê a sua skin em todas as armas daquele tipo).

As fotos das skins (HUD, inventário, roleta) são renderizadas pelo `tools/dff_render.py` direto do `.dff` com
a textura da skin (vista lateral para armas, frontal para personagens), sem depender de imagens dos packs.

Skins de personagem: pastas em `dm_skins/<n>/` (dff + txd) listadas em `PED_SKINS` no `build_skins.py`, com
nome, raridade e o **ID do ped** que substituem (fora de `DM.skins` e sem repetir; o script confere). Atenção:
os `.txd` de personagem são grandes (~95 MB no total) e todo jogador baixa ao entrar — se o download ficar
lento, remova os maiores (Usada Pekora e Naruto Bijuu já foram retirados por isso).

Raridades: Comum, Rara, Épica, Lendária, Mítica, Ultimate (AK Fire Serpent e M4 Masterpiece).
Caixas: Munição $5.000 (ultimate 0,01%), Tática $15.000 (0,1%), Elite $40.000 (1%); repetidos devolvem
metade. Uma skin equipada por arma (AK-47, M4, outras). Para adicionar packs: coloque as pastas, edite
os dicionários `AK`/`M4` do script com nome e raridade, rode o script e depois `npm run build` no `dm_ui/web`.

Personagens ficam no painel F10 (também `/personagens`), com as abas Meus Personagens e Todos os
Personagens. A Caixa de Personagens fica no mesmo painel F7 e custa $15.000: rara 55%, épica 30%,
lendária 12% e mítica 3%. As outras três caixas continuam com armas e dinheiro, sem personagens.
As chaves dos itens e a posse nas contas permanecem iguais; não há migração de banco de dados.
As definições das caixas ficam em `tools/crate_catalog.py`, compartilhadas com `build_skins.py`.
Para atualizar somente as caixas, sem regenerar modelos/imagens: `python tools/crate_catalog.py` (requer `lupa`).

Atualizações de equipamento/rastro são enviadas no próximo frame após a sincronização do servidor,
sem depender do timer de quatro segundos. A câmera do F2 mantém o cenário selecionado em memória;
o HUD não reenvia estados idênticos nem consulta o catálogo de skins a cada atualização.
Testes locais: `python -m unittest discover -s tools/tests -v`. A validação de desempenho dentro do
CEF do MTA deve ser feita após reiniciar o servidor e reconectar.

## Mira (F9)

Ao entrar, todo jogador usa a **mira original do GTA**. O painel F9 (ou `/mira`) mostra uma galeria de miras
(ponto, clássica, clássica + ponto, estilo CS, estilo Valorant, cruz cheia, X, círculo, círculo + ponto, T, fina)
com prévia ao vivo e ajuste fino: cor (paleta ou hex), tamanho, espessura, espaço do centro, opacidade, contorno
preto e deslocamento horizontal/vertical. A mira personalizada se comporta como a do GTA: aparece só enquanto o
jogador está mirando, em posição fixa na tela (nunca segue o alvo). **SALVAR** grava na conta (`dm_crosshair/server.lua`, `setAccountData`);
**VOLTAR AO ORIGINAL** devolve a mira do GTA; fechar sem salvar cancela as mudanças. O desenho é dx
(`dm_crosshair/client.lua`) e a sniper sempre usa o scope original do jogo. A tela fica em
`dm_ui/web/src/screens/Crosshair.jsx` (presets em `PRESETS`; a prévia SVG usa a mesma geometria do dx).

## Soul particles (morte por arma com rastro)

Quando um jogador morre por uma AK-47 ou M4 com skin **Mítica ou Ultimate** equipada pelo matador (as armas que têm
ponta e rastro), a alma da vítima se desprende do corpo na **cor do rastro do matador** (cor da skin, cor escolhida
ou RGB): a silhueta do ped brilha nos ossos, um anel de energia abre no chão e centenas de partículas luminosas
sobem em espiral, pulsam e se dissipam em ~3 s. Tudo em `dm_crates/client/c_fx.lua` (`SOUL_*`), desenhado com
`dxDrawMaterialLine3D` a partir de `getPedBonePosition`, só para mortes a até 140 m da câmera e na mesma dimensão.

## Anti-cheat (`dm_anticheat`)

Fase 1: **rapid fire**. Tudo no servidor: conta os tiros de cada jogador por arma numa janela de 1 s
(`onPlayerWeaponFire`) e compara com a cadência máxima real da arma (propriedades `anim_loop_start/stop`,
nível "pro") com 35% de tolerância (pistolas/shotguns 140%, porque o C-Bug acelera de verdade). Duas violações
em 60 s marcam o jogador: alerta na tela de todos os admins (toast vermelho + som), log no console do servidor
e lista em `/ac`. **Três violações em 60 s = ban automático** (permanente, serial + IP, anunciado no chat; admins
nunca são banidos automaticamente). Para o ban funcionar, uma vez no console do servidor: `aclrequest allow dm_anticheat all`.

Fase 2: **aimbot e silent aim por testemunhas** (`client/c_ac.lua`). Cada cliente observa os *outros* jogadores pelo
sync do MTA: direção da mira (`getPedTargetStart/End`) e ponto de impacto de cada tiro (`onClientPlayerWeaponFire`).
Silent aim = bala acerta um jogador a mais de 14° da direção da mira (ou qualquer coisa a mais de 30°), 6 vezes em
30 s. Aimbot = a mira gira a mais de 900°/s (salto > 18°) e até 220 ms depois o tiro acerta um jogador, 5 vezes.
O trapaceiro não controla o cliente das testemunhas. O servidor cruza os relatos com a **precisão real** (via
`ac:hit` do dm_weapons: ≥ 85% de acerto e ≥ 75% de headshot nos últimos 40 tiros é impossível sem ajuda).
Alerta: 2 testemunhas diferentes, 3 relatos ou precisão impossível. Ban automático: 3 testemunhas, ou 2 testemunhas
+ precisão impossível. Limiares no topo de cada arquivo. Adicione ao `mtaserver.conf`:
`<resource src="dm_anticheat" startup="1" protected="0" />`.

## Chat

Estilo moderno com ícones de texto, ID e cores (o chat padrão do MTA renderiza os glifos):

```
✿ Global  ★ ✦ [1042] [UTG] Nick » mensagem      (global, padrão)
▲ Arena   ...                                  /a <msg>   só a sua arena/dimensão
◆ Clã     ...                                  /c <msg>   só o seu clã
✉ PM de Nick [1042] » msg                       /pm <id ou nome> <msg>
♛ Staff   ...                                  /staff <msg>
```

- Antes do nick: glifo da tag (♛ staff, ★ VIP, ◆ comprada), glifo do elo (● ◆ ★ ✦ ❖ ♛ ☠), `[ID]`, `[TAG]`, `[CLÃ]`.
- Cor do nick = cor comprada/VIP; cor da mensagem muda para VIP e staff.
- Emojis por atalho em qualquer canal: `:skull:` ☠ `:star:` ★ `:crown:` ♛ `:heart:` ♥ `:flower:` ✿ ... (`/emojis` lista todos).
- ID público por conta (`/id`), aceito em `/pm`, `/tp`, `/kick`, `/pagar` etc. Entrada e saída anunciadas com ID.
- Kills aparecem só no killfeed da interface (não no chat); sequências `★`, X1 `✦`, ranqueadas `★`, clã x clã `◆`, anúncios `♛`.
Tudo em `dm_core/shared/config.lua` → `DM.chat` (canais, glifos, emojis, cores).

## Interface

UI v2 (`dm_core/client/c_ui.lua`, copiada para os outros recursos): shaders HLSL em `dm_core/shaders/`
(cantos arredondados com anti-aliasing e brilho, fundo desfocado em duas passagens, gradiente animado
"aurora", vinheta), motor de animação (tweens com easing/overshoot, molas, contadores, hover, cascata),
componentes (card de vidro, botões, abas deslizantes, barras com rastro, anéis, campos, toggles) e a
moldura padrão de painel (`UI.panelFrame`). Paleta verde (`#22E68A` / `#7CFFB2`), dourado VIP `#F5C451`,
fonte Poppins, logo em `dm_core/assets/img/logo.png` (canto inferior esquerdo, com nick/elo/$/vida
empilhados em cima — substitua pela sua, 640x200 PNG). Se a placa de vídeo não compilar os shaders, tudo
cai para primitivas dx automaticamente. Guia para novos painéis: `docs/UI_SPEC.md`.

### Interface em CEF (`dm_ui`)

Toda a interface (HUD, hub de arenas F2, loja F4, duelo F3, ranqueadas F5, clãs F6, caixas F7, placar TAB,
ajuda F1 e login) é uma página HTML/CSS/React renderizada dentro do MTA via CEF em um único browser
transparente (`createBrowser` + `dxDrawImage`), com fundo animado verde (aurora, feixes, partículas) atrás
dos painéis e a cena do GTA visível. O fundo animado (aurora, feixes, partículas, grade) é desenhado em dx pelo Lua
(`dm_ui/client/c_bg.lua`, GPU) por trás do browser; a página fica transparente fora do painel, então o CEF só
repinta o que muda no painel. O Lua (`dm_ui/client/`) cuida do browser, teclas, cursor, chat oculto,
câmera, dados reais e dos eventos já existentes dos servidores; o JS só desenha. Ponte: JS → Lua com
`mta.triggerEvent("ui:act", tela, ação, json)`; Lua → JS com `window.ui.set/open/close/push`. Os arquivos
servidos são estáticos (`dm_ui/dist/`, `http://mta/local/dist/index.html`), sem CDN nem servidor de
desenvolvimento — o `dist/` já vem compilado. Para alterar o visual:

```
cd "mods/deathmatch/resources/[dm]/dm_ui/web"
npm install
npm run build        # gera ../dist (listado no meta.xml)
```

Pré-visualização fora do jogo com dados de exemplo: sirva `dist/` por HTTP e abra
`index.html?demo=hub` (ou shop, duel, ranked, clans, crates, board, help, login, hud, rhud, rhud2, reel).
Ficaram em dx apenas a mira, o hitmarker, os nametags e a tela de morte (`dm_core/client/`).
