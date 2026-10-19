# Validação

Em 19/10/2026, reexecutados na cópia local completa do Codex:

```text
python -m unittest discover -s tools/tests -v
Ran 16 tests — OK
```

Os testes executam Lua 5.1 com `lupa.lua51`, SQLite em memória e stubs de funções MTA. Cobrem carregamento assíncrono, IDs, convidado/logout, persistência e reconexão, premiação dos sete personagens personalizados, separação dos pools, preservação de armas/dinheiro, reembolso de repetidos, configuração/gerador, resposta de falha, padrão imediato, atualização no próximo frame, navegação F10/F7, cliques duplicados e consultas da câmera.

Na implementação de 18/10/2026: `npm run build` passou; navegação dos menus F1–F7/F10, inventário, equipamentos e roleta foi conferida em Edge via Playwright com dados do catálogo, em 1440×900 e 1024×768, sem erros JavaScript ou assets ausentes. O relatório local mediu troca de abas após clique entre aproximadamente 6 e 75 ms no navegador de teste. Isso não mede o CEF do MTA, ping, FPS no jogo nem operação ao vivo.

Dependências para reproduzir em uma raiz integrada: Python com `lupa` e Node/npm para `mods/deathmatch/resources/[dm]/dm_ui/web`. Executar `npm ci` e `npm run build` nessa pasta web. Não rodar o gerador completo de skins só para testar a interface: ele reextrai assets e precisa ser conciliado com o renderizador mais novo.

As confirmações de upload do Codex eram hashes dos arquivos enviados, não um teste dentro do jogo. O comportamento ao vivo e a integração com o trabalho posterior do Claude ainda precisam ser verificados.
