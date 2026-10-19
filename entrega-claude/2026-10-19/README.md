# Entrega ao Claude Code — 19/10/2026

Esta pasta reúne as alterações feitas pelo Codex a pedido do usuário, para revisão e integração pelo Claude Code. É um pacote de referência; não é um recurso MTA nem uma cópia completa do servidor.

## Comece aqui

- Branch de trabalho: `claude/modest-cray-8tz6fw`.
- Base original da cópia local do Codex: `45d8b45462e2fcd40fcb3d5438c58bec6f9b9324`.
- Último commit remoto conferido antes desta entrega: `5378cbdcc4d31c43121d61dc1fd428f3eb93be77`.
- **O remoto já contém trabalho mais novo do Claude. Não substituir o projeto atual pelos arquivos desta pasta em bloco.**
- `arquivos/`: conteúdo final dos arquivos criados/modificados, preservando os caminhos originais.
- `alteracoes.patch`: diff completo, incluindo arquivos novos e exclusão do bundle antigo, contra a base original acima.
- `ARQUIVOS.md` e `manifest.json`: lista de mudanças, hashes e indicação de arquivos que também mudaram no remoto.
- `VALIDACAO.md`: testes executados e limites da validação.

## O que o usuário pediu para preservar

Manter o design atual (verde/escuro, molduras, tipografia, efeitos), recursos existentes, itens adquiridos, dinheiro, rastros e a roleta de caixas. Uma reorganização anterior, muito maior, foi rejeitada e revertida. **Essa versão rejeitada não faz parte desta entrega.** O pedido mais recente foi melhorar a interação e separar os personagens, sem refazer a interface inteira.

## Mudanças finais do Codex

### Correções iniciais

1. Stats carregadas antes do spawn; fila de callbacks durante carregamento assíncrono. Skin equipada restaurada antes do spawn e ao carregar/reiniciar recursos.
2. Prêmios/perks e equipamentos salvos imediatamente; validação de prêmio antes de cobrar, estorno em falha, preservação do reembolso de repetidos.
3. ID público baseado no rowid SQLite sem adicionar 1000. Nenhuma exclusão/migração destrutiva das contas.
4. Removida a opção de convidado na tela de login; evento de convidado rejeitado no servidor e logout que voltaria a convidado bloqueado.
5. `/skin` também persiste o equipamento. `dm_skins` adicionado ao startup. O arquivo completo de configuração da hospedagem não deve ser substituído; a única alteração de mtaserver.conf está no patch.

### Interação e organização dos personagens

1. Corrigido o escopo de `cratesState`: o handler de element data estava declarado antes da função local e tentava chamar uma global inexistente. Isso impedia o retorno visual imediato; a tela só se atualizava no timer de quatro segundos.
2. Mudanças de dinheiro/perks/skin/rastro agrupadas no próximo frame com `UI.defer`; envio de estados idênticos ao CEF suprimido. `UI.merge` invalida esse cache.
3. F2 mantém o cenário selecionado em memória, em vez de consultar configurações de arenas/modos a cada frame. Criação de timers evita duplicar um timer existente de mesmo nome.
4. HUD mantém índice de skins e contabiliza população no máximo uma vez por segundo. Menus React e fundo evitam reconstruções por atualizações alheias; contadores não animam valores inalterados. Algumas transições/entradas ficaram mais curtas, preservando os efeitos.
5. Novo painel **F10 / `/personagens`**, em `Characters.jsx`, com abas Meus Personagens e Todos os Personagens, posse, estado equipado, equipar, padrão e acesso às caixas. Usa `Frame`, `Tabs`, `ItemCard` e botões do projeto existente.
6. Inventário F7 mostra apenas skins de armas, mantendo rastros e armas padrão. Personagens mantêm as mesmas chaves `item:<key>` e a mesma posse no banco; somente a apresentação foi separada.
7. Munição ($5.000), Tática ($15.000) e Elite ($40.000) mantêm preços, probabilidades por raridade e prêmios de dinheiro, retirando personagens dos pools. Pesos são redistribuídos entre os candidatos restantes da mesma raridade.
8. Uma quarta caixa no **mesmo F7**: Personagens, $15.000, exclusivamente personagens; rara 55%, épica 30%, lendária 12%, mítica 3%. Todos os 13 personagens do catálogo desta base têm chance; os sete personalizados continuam incluídos.
9. `tools/crate_catalog.py` centraliza as caixas e é usado por `tools/build_skins.py`. Permite atualizar só as definições sem reextrair modelos/imagens.
10. Abertura de caixa sinaliza ABRINDO e bloqueia clique duplicado enquanto aguarda resposta. `crates:openFailed` libera o estado em falhas; a roleta de 5,5 segundos foi mantida.
11. `resetPlayerSkin`, exportado pelo core, aplica o modelo padrão imediatamente usando a lista de spawn, sem respawn e sem remover a posse. Chances pequenas agora mostram decimais em vez de 0%.

## Conciliação com os avanços mais recentes do Claude

O remoto avançou depois da base usada pelo Codex, com painel de mira, mudanças de arenas/mapas/colisões, renderização de previews reais e deploy FTP via Actions. Preservar essas mudanças na integração.

Pontos especialmente importantes:

- O remoto possui `tools/dff_render.py` e imagens reais em `img/pskins` e `img/wskins`. A versão do Codex foi construída antes desses commits: os cartões de personagens deste pacote usam o ícone antigo de escudo, **não contêm preview 3D nem as novas fotos**. Integrar a separação F10 com os previews reais do remoto, em vez de voltar às imagens antigas.
- `skins_generated.lua` deve preservar metadados novos dos itens/previews e receber a separação dos pools. Conciliar `build_skins.py` para não perder a renderização adicionada pelo Claude.
- Conciliar `s_arenas.lua` com as correções novas de spawn/colisões e a remoção de arenas. Não restaurar arenas removidas pelo usuário.
- Verificar os atalhos atuais, inclusive os do painel de mira, antes de integrar F10.
- `dist/`, `c_build.lua` e `meta.xml` do pacote documentam o build enviado anteriormente. Após integrar as fontes no remoto novo, executar novo build; não substituir o bundle remoto por esse bundle antigo.
- O patch foi gerado contra `45d8b45`: `git apply --check` em outra base pode falhar. Resolver as mudanças sobre o código atual; não fazer reset para a base antiga.

## Como continuar

1. Ler este guia e `ARQUIVOS.md`; comparar o branch atual com a base documentada.
2. Integrar as alterações de fonte em pequenos grupos, preservando os avanços do Claude descritos acima.
3. Usar os testes de `arquivos/tools/tests/` nos caminhos equivalentes da raiz após integração. Eles dependem dos recursos reais da raiz e não devem ser executados dentro da cópia parcial `arquivos/`.
4. Executar os testes Python e o build npm; validar no MTA login, F1–F7, F10, equipar/padrão, abrir as duas categorias de caixas e reconectar mantendo o equipamento.
5. Conferir o workflow de deploy do branch antes de publicar alterações em `mods/deathmatch`.

## Estado de entrega e hospedagem

As alterações do Codex foram enviadas por FTP em 18/10/2026, e o último envio teve 12 arquivos verificados por SHA-256. Isso descreve aquele envio; **não garante o conteúdo atual do servidor**, pois os commits remotos posteriores configuraram e podem ter executado deploy automático. Esta entrega não consulta nem altera a hospedagem.

Este commit adiciona somente `entrega-claude/2026-10-19/`. O workflow conferido seleciona mudanças sob `mods/deathmatch/`, portanto esta pasta não entra no envio FTP. Sem credenciais, bancos, caches Python, node_modules ou backups brutos da hospedagem no pacote.
