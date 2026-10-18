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
    ├── dm_weapons   dano por parte do corpo (headshot x2.2, peito x0.5), sons de tiro, skins de arma
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

## Ranqueadas (F5)

| Modo | Local | Jogadores | Armas | Meta |
|------|-------|-----------|-------|------|
| 10x10 M4 | Las Payasadas | 20 | M4, colete 100 | 80 kills ou 10 min |
| 5x5 Sniper | Bayside Trailer Park | 10 | Sniper | 30 kills ou 8 min |
| 5x5 M4 | Bayside Trailer Park | 10 | M4, colete 100 | 40 kills ou 8 min |

Fluxo: entra → **aquecimento** (FFA com as armas do modo, sem recompensa) até completar os jogadores →
contagem 15 s → times balanceados por RP (Time Ciano x Time Roxo) → team deathmatch com respawn na base
→ resultado (RP, $, MVP) → volta ao aquecimento. Cada instância tem a sua dimensão; quando uma partida
começa, novos jogadores vão para uma nova instância. Sair no meio conta derrota.

**Spawns dos times são aproximados** (`DM.rankedModes[*].teamSpawns`, chão nativo com ajuste automático ao
solo). Me mande as posições marcadas (`x, y, z, rotação`) de cada time e eu atualizo — ou edite direto.

## Clãs (F6) e clã x clã

Criar (`TAG` 2-5 letras, nome 3-20), convidar jogadores online, cargos (líder, oficial, membro), cor da
tag, ranking de clãs. Líder/oficial seleciona um clã no ranking, escolhe o modo e desafia; o outro clã
aceita no F6 e os membros online dos dois (mesmo número por lado, mínimo 2) entram em uma partida de times
privada com as tags dos clãs. Resultado anunciado para o servidor com o placar.

## Sistemas de combate

- **Dano**: o cliente da vítima cancela o dano padrão das armas de fogo e o servidor aplica por parte do
  corpo: cabeça x2.2 (sniper/rifle mata), peito/quadril x0.5, braços x0.8, pernas x0.7. Mortes passam
  por `killPed`, então killer/arma ficam corretos no kill chat. Sem fogo amigo nas ranqueadas.
- **Kill feedback**: caveira/ícone de headshot no centro, som de headshot, `+$` ganho; killfeed no canto
  superior direito só da sua arena/dimensão; sequências com banner.
- **Sons de arma**: os do GTA são silenciados (grupo 5) e substituídos por `dm_weapons/sounds/<id>.wav`
  (gerados proceduralmente — troque pelos seus .wav mantendo o nome).
- **Skins de arma**: precisam de `.dff/.txd` (binários de pack de skins). Coloque em `dm_weapons/models/`
  e liste no `meta.xml` conforme `models/LEIA-ME.txt`; o carregador aplica automaticamente.
- **Munição**: ao trocar de arma e pegar de novo ela volta cheia; ao matar recarrega.
- **Nametags**: tag (staff/VIP/comprada/elo) e tag do clã destacadas acima do nick colorido, vida e colete.

## Interface

Paleta UTG (violeta `#8B5CF6`, ciano `#22D3EE`, dourado VIP `#F5C451`), fonte Poppins, logo em
`dm_core/assets/img/logo.png` (canto inferior esquerdo — substitua pela sua, 640x200 PNG). Ícones em
`assets/img`. Tudo escalonável por resolução.
