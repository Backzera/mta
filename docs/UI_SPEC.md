# UTG MATA-MATA — Especificação de interface (UI v2)

Documento de referência para quem reescreve um painel/HUD. O framework está em
`mods/deathmatch/resources/[dm]/dm_core/client/c_ui.lua` (copiado byte a byte para os outros
recursos: a API é idêntica em todos). **Leia o c_ui.lua inteiro antes de escrever.**

## Linguagem visual

- **Tema**: escuro, verde. Paleta `UI.palette`: `accent` verde `#22E68A`, `accent2` menta `#7CFFB2`,
  `gold` `#F5C451` (VIP/ranqueadas), `danger` `#FF4D6D`, `warn`, `info`, `text`, `muted`, `card`, `card2`, `bg`.
  Sempre `UI.color("nome", alpha)`; nunca cor literal fora da paleta (exceto branco/preto para contraste).
- **Vidro**: painéis e cards usam `UI.card` (fundo translúcido + borda 1px + brilho verde externo +
  linha de acento no topo) sobre **fundo desfocado** (`UI.backdrop`, feito automaticamente por `UI.panelFrame`).
- **Cantos**: 10–18px via `UI.rrect` (anti-aliasing por shader). Raio grande em painéis (18), médio em
  cards (10–12), pílulas 100%.
- **Tipografia**: Poppins. Títulos `bold` 22–32 com `UI.textGlow`; rótulos `semibold` 8–9 em
  CAIXA ALTA e cor `muted`; corpo `regular/medium` 10–12; números grandes `bold` 16–48.
- **Hierarquia por luz, não por caixas**: menos bordas, mais contraste de alfa e brilho.
  Rótulo pequeno em cima, valor grande embaixo (`UI.stat`).
- **Movimento é obrigatório**:
  - Abertura: `UI.panelFrame` já faz escala 0.94→1 com overshoot + fade + backdrop.
  - Conteúdo em cascata: `UI.stagger(f.a, i, n)` por item (deslize de 12–20px + fade).
  - Hover: todo elemento clicável reage (`UI.hover` / `UI.listRow` / `UI.button`): fundo clareia,
    borda acende, brilho verde sobe, leve expansão de 2px. Som de hover vem do `UI.button`.
  - Números: `UI.counter(id, valor)` para dinheiro, RP, placar, contagens.
  - Barras: `UI.bar(..., { id = "x", ghost = true, glow = true })` (rastro vermelho ao perder vida).
  - Pulsos: `UI.pulse(periodo, min, max)` para destaques (ex.: contagem regressiva, alerta).
  - Nunca "teleporte" um valor ou um painel: tudo transiciona.
- **Feedback**: clique chama som automaticamente (`UI.processClick`); ações importantes chamam
  `UI.sound("levelup"|"win"|"lose"|"error"|"notify"|"tick"|"go")`.
- **Limpeza**: HUD discreto quando nada acontece; destaques (kill, headshot, sequência, elo) são grandes,
  rápidos e somem. Sem texto desnecessário.

## Esqueleto obrigatório de um painel

```lua
local PANEL = "nome"            -- chave única do painel (UI.setPanelOpen)
local panel = { open = false, tick = 0, rendering = false }

local function render()
    local f = UI.panelFrame(panel, {
        w = UI.s(900), h = UI.s(600), title = "TÍTULO", subtitle = "Explicação curta.",
        icon = "trophy.png", accent = "accent", badge = "SALDO $1.000", badgeColor = "gold",
        onClose = closeX,
    })
    if not f then
        if not panel.open then removeEventHandler("onClientRender", root, render) panel.rendering = false end
        return
    end
    -- conteúdo: use f.cx, f.cy, f.cw, f.ch e f.a (alpha) em TODAS as cores
    -- cliques: UI.button(..., { onClick = fn }) ou UI.addClick(x, y, w, h, fn, id)
    UI.panelFooter(f, "F4 ou ESC fecha")
    UI.endFrame()                    -- desenha tooltips
end

local function onClick(button, state) if panel.open then UI.processClick(button, state) end end

function openX()
    if panel.open or not getElementData(localPlayer, "dm:ready") then return end
    if not UI.setPanelOpen(PANEL, true) then return end
    panel.open = true
    panel.tick = getTickCount()
    if not panel.rendering then panel.rendering = true addEventHandler("onClientRender", root, render) end
    addEventHandler("onClientClick", root, onClick)
end
function closeX()
    if not panel.open then return end
    panel.open = false
    panel.tick = getTickCount()
    UI.setPanelOpen(PANEL, false)
    removeEventHandler("onClientClick", root, onClick)
end
bindKey("F4", "down", function() if panel.open then closeX() else openX() end end)
UI.registerEscape(PANEL, closeX)
```

Regras:
- `UI.processClick` dispara no **mouse up** e só se o mouse down foi no mesmo elemento.
- Rolagem: `onClientKey` com `mouse_wheel_up/down` → altera `panel.scroll` → desenhe com `UI.scroll(id, panel.scroll * rowH)`.
- Campos de texto: `UI.inputField` + `UI.bindInputs` / `UI.unbindInputs` (já existentes).
- Fora do `dm_core` **não existe `DM`**: use `exports.dm_core:getConfig()/getEconomyConfig()/getShopConfig()/getVipConfig()/getRankedModes()/getDuelWeaponSets()/getTierForRP(rp)/formatMoney(v)/getPlayerArena(player)` (cacheie o resultado em local).
- Não mude nomes de eventos, ordem de argumentos, nomes de funções globais usadas por outros arquivos,
  nem `bindKey`s. O protocolo com o servidor é fixo.
- Cada arquivo deve terminar com sintaxe válida de Lua 5.1 (sem `goto`, sem `//`, sem `!=`, sem `continue`).

## HUD (dm_core/client/c_hud.lua)

Canto inferior esquerdo, **empilhado de baixo para cima**:
1. Logo `logo.png` (largura ~210px) na base.
2. Acima dela, um bloco de vidro (`UI.card` sem accent ou `UI.rrect` escuro translúcido) com:
   nick (cor `dm:nameColor`) + pílulas de tag/clã à esquerda, elo (`UI.tierForRP` via `DM.tierForRP`)
   como badge pequeno à direita, dinheiro com `UI.counter`, barra de vida (`ghost`, `glow`, id) com
   número, barra de colete fina. Tudo ocupa ~ 260×110px.
3. Vida baixa (<30%): `UI.vignette(UI.color("danger"), UI.pulse(900, 0.15, 0.45))`.

Canto inferior direito: arma e munição (`clip / reserva`) em pílula de vidro, munição grande com
`UI.counter`, barra fina do pente abaixo. Sequência de kills: pílula com `flame.png` que pulsa.
Topo centro: pílula da arena (ponto colorido pulsando + nome + jogadores). Topo esquerdo: uma linha
`muted` com servidor · online · fps · ms. Dica de teclas do lobby: uma linha no rodapé central.

## Killfeed / notificações / hitmarker / morte (c_killfeed, c_notify, c_hitmarker, c_spawn)

- Killfeed: canto superior direito, linhas deslizam da direita com `outBack`, ícone caveira/headshot,
  linha do próprio jogador com brilho verde (kill) ou vermelho (morte).
- Kill no centro: ícone pulsando (escala 1.4→1 outBack), "ELIMINADO"/"HEADSHOT!" com `textGlow`,
  `+$` subindo e sumindo.
- Hitmarker: 4 traços que se expandem e somem; número de dano sobe; headshot em `warn`.
- Morte: backdrop desfocado + vinheta vermelha + "VOCÊ MORREU" com glow + anel de contagem
  (`UI.ring`) com o número no centro.
- Notificações: pilha no topo direito abaixo do killfeed, deslizam com `outBack`, barra de tempo,
  ícone por tipo, som.
- Proteção de spawn: anel verde pequeno acima da barra de vida ou pílula com barra.

## Placar (TAB)

Painel largo (1000px), cabeçalho com logo, linhas em cascata, linha do jogador local brilhando,
tags/clã/elo como pílulas, ordenado por RP, top 3 com medalha dourada/prata/bronze (cor da posição).

## Painéis de recurso

- **Arenas (F2)**: cards 3 colunas, cada um com barra lateral da cor da arena, nome, tipo, armas,
  contagem de jogadores com ponto pulsante, hover levanta o card (expande 3px + brilho), card atual
  marcado. Card "Ranqueadas" dourado abre F5.
- **Duelo (F3)**: três colunas (jogadores com busca e rolagem suave, armas em grade de chips com
  hover, rodadas em segmentos + resumo + botão enviar com brilho). Popup de pedido no topo com anel
  de tempo. HUD do duelo: placar `A x B` grande com `counter`, contagem 3-2-1 gigante com `textGlow`
  e escala pulsante, "LUTE!" explodindo, resultado com painel de vidro e `win/lose`.
- **Loja (F4)**: abas deslizantes, cards de item com preço, estado (comprar/equipar/equipado), botão
  de confirmação em dois cliques com cor de aviso, saldo animado no badge do cabeçalho.
- **Ranqueadas (F5)**: cards de modo com barra de preenchimento do aquecimento animada, status
  "aguardando/jogando", botão entrar. HUD: aquecimento com barra; contagem com anel; partida com
  placar grande dos dois times, tempo, meta, meu time destacado; resultado com tabela em cascata.
- **Clã (F6)**: sem clã → formulário de criação + convites + ranking; com clã → cabeçalho com tag
  grande na cor do clã, membros com ponto online, ações por cargo, área de clã x clã dourada, ranking
  com o clã selecionado destacado.
- **Login**: tela cheia com `UI.aurora` grande à esquerda (logo + slogan + 3 destaques com ícones),
  card à direita com abas Entrar/Registrar deslizantes, campos com foco animado, botão com brilho,
  convidado em outline, mensagem de status com cor. Câmera continua girando sobre o X1.
