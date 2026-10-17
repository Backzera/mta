# ARENA PVP — Servidor MTA:SA Mata-mata

Servidor de PVP completo para Multi Theft Auto: San Andreas, com arenas por arma, duelo X1 com painel,
arena de C-Bug, kill chat, killfeed, ranking/níveis, login e interface moderna (dx, fonte Poppins).

```
mods/deathmatch/
├── mtaserver.conf                 configuração do servidor (recursos já listados)
├── acl-adicionar.txt              linhas para colocar no grupo Admin do acl.xml
└── resources/[dm]/
    ├── dm_core/                   núcleo: arenas, spawn, armas, kills, stats, HUD, painéis, chat, comandos
    ├── dm_maps/                   carrega maps/<arena>.map na dimensão de cada arena (+ portão da M4)
    ├── dm_duel/                   duelo X1 (F3): pedidos, aceite, sala privada, rodadas, resultado
    ├── dm_cbug/                   C-Bug liberado só na Arena C-Bug (bloqueado nas outras)
    └── dm_login/                  painel de login/registro, lembrar-me, convidado
Arena AK47/, Arena CBUG/, Arena M4/, Arena X1/   mapas originais (os .map já foram copiados para dm_maps/maps)
```

## Instalação

1. Baixe o servidor MTA:SA (https://multitheftauto.com) e extraia.
2. Copie `mods/deathmatch/mtaserver.conf` e a pasta `mods/deathmatch/resources/[dm]` para a mesma
   estrutura dentro do servidor (mantenha os recursos padrão que vêm no pacote: admin, resourcemanager...).
3. Abra `mods/deathmatch/acl.xml` do servidor e, dentro de `<group name="Admin">`, adicione as
   linhas de `acl-adicionar.txt`:
   ```xml
   <object name="resource.dm_core" />
   <object name="resource.dm_login" />
   <object name="resource.dm_duel" />
   ```
   Sem isso o registro de contas e os comandos /kick e /ban não funcionam.
4. Inicie o servidor. Os 5 recursos `dm_*` já iniciam automaticamente pelo `mtaserver.conf`.
5. Para virar admin: registre-se no jogo e depois adicione `<object name="user.SEUUSUARIO" />`
   dentro de `<group name="Admin">` no `acl.xml` (ou use o recurso `admin` com a conta Console).
   Na primeira vez o servidor pode pedir para autorizar o serial no console: `authserial SEUUSUARIO`.

## Arenas

| id        | Arena          | Dimensão | Armas                      | Observação                               |
|-----------|----------------|----------|----------------------------|------------------------------------------|
| `lobby`   | Lobby          | 0        | nenhuma                    | zona segura (Pershing Square, LS)        |
| `ak47`    | Arena AK-47    | 1        | AK-47                      | mapa `ak47.map` (Las Venturas)           |
| `m4`      | Arena M4       | 2        | M4                         | mapa `m4.map` (Verdant Bluffs) + portão  |
| `x1`      | Arena X1       | 3        | escolhida no duelo         | mapa `x1.map`; sala de espera + duelos   |
| `cbug`    | Arena C-Bug    | 4        | Deagle, Shotgun, Sniper    | mapa `cbug.map`; **C-Bug liberado**      |
| `deagle`  | Arena Deagle   | 5        | Deagle                     | sem mapa (San Fierro)                    |
| `sniper`  | Arena Sniper   | 6        | Sniper                     | sem mapa (Verdant Meadows)               |
| `shotgun` | Arena Shotgun  | 7        | Combat Shotgun             | sem mapa (Unity Station)                 |
| `melee`   | Arena Katana   | 8        | Katana                     | sem mapa (Santa Maria Beach)             |
| `livre`   | Arena Livre    | 9        | Deagle, Shotgun, MP5, AK, M4, Sniper | sem mapa (Area 69), colete 50  |

Tudo isso fica em `dm_core/shared/config.lua` (tabela `DM.arenas`): nome, cor, dimensão, armas,
spawns, `cbug = true`, `safe = true`. Para criar uma arena nova basta adicionar um bloco e,
se quiser, um `dm_maps/maps/<id>.map`.

### Spawns
Os mapas não tinham `<spawnpoint>`, então os spawns foram calculados pela geometria de cada mapa
(pickups do mapper, pontos dos scripts originais e áreas abertas longe dos objetos) e ficam em
`config.lua`. No X1, `duelSpots` tem pares de posições frente a frente (30–45 m) usados nos duelos;
os `spawns` do X1 são a sala de espera. Se algum spawn ficar ruim, edite o número ali — ou adicione
`<spawnpoint>` no `.map`, que então substitui a config automaticamente.

Rede de segurança: se um jogador nascer no vazio (mapa ainda não carregou, posição ruim), o cliente
detecta a queda e o servidor o reposiciona no primeiro spawn (âncora) da arena.

## Teclas e comandos

| Tecla | Função                 |  | Comando               | Função                   |
|-------|------------------------|--|-----------------------|--------------------------|
| F1    | Ajuda                  |  | `/arena <id>`         | Entrar em uma arena      |
| F2    | Painel de arenas       |  | `/arenas` `/lobby` `/x1` | Listar / voltar / ir X1 |
| F3    | Painel de duelo X1     |  | `/duelo <jogador>`    | Abrir painel já com o alvo |
| TAB   | Placar                 |  | `/aceitar` `/recusar` | Responder desafio        |
| Y / N | Aceitar / recusar duelo|  | `/stats [jogador]` `/top` | Estatísticas / top 10 |
| ESC   | Fechar painel          |  | `/skin <id>` `/pm` `/kill` | Skin / privado / suicídio |

Admin (grupo Admin/Moderator da ACL): `/kick`, `/ban`, `/mute <jogador> [min]`, `/unmute`,
`/tp <jogador> [arena]`, `/anuncio <msg>`, `/admins`.

## Sistemas

- **Kill chat** `[KILL] Fulano matou Ciclano com AK-47 [HEADSHOT]` para a arena + killfeed animado
  no canto, hitmarker com número de dano, recompensa “+XP” no centro.
- **Sequências** (3/5/8/12/20 kills) com banner e som; 8+ anunciadas no servidor todo.
- **XP e níveis** (nível = √(xp/25)+1), ranks Bronze → Lenda, tags no chat, nametags com nível e vida.
- **Stats persistentes** em SQLite (`dm_core/data/stats.db`): kills, mortes, headshots, maior
  sequência, duelos, XP, tempo de jogo. Chave = conta (ou serial para convidados).
- **Duelo X1**: F3 → escolhe jogador, conjunto de armas (12 opções) e “primeiro a 1/3/5”. O outro
  jogador recebe popup (Y/N). Sala privada em dimensão própria, contagem 3-2-1, placar, W.O. se sair,
  vencedor ganha 60 XP e volta para onde estava.
- **C-Bug**: o MTA bloqueia o crouch-bug por padrão; o servidor libera o glitch e o cliente bloqueia o
  agachar após o tiro (Deagle/Shotgun/Sniper/Rifle) em toda arena que não tenha `cbug = true`.
- **Proteção de spawn** 3 s (quebra ao atirar), congelamento curto para o mapa carregar, zonas seguras
  sem dano (lobby e X1), pickups de arma do mapa só se forem da arena.
- **Login**: contas do MTA, lembrar-me (senha salva criptografada no cliente), modo convidado.

## Ajustes rápidos (`dm_core/shared/config.lua`)
`DM.server` controla nome, tempo de respawn, proteção, XP por kill/headshot/duelo, vida ao matar,
clima/hora. `DM.duelWeapons` são os conjuntos do painel X1. `DM.colors` é a paleta da interface.
