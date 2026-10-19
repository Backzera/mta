# Homologação

## Automação reproduzível

Requisitos somente para o computador de desenvolvimento: Python e pacote `lupa` com runtime Lua 5.1. O servidor MTA não precisa de Python nem desses arquivos.

```text
python -m pip install -r tests/requirements.txt
python tests/test_resource.py
```

Execute dentro da pasta `utg_anticheat`. A suíte cria mocks isolados: não conecta em FTP, não envia webhook, não bane ninguém e não abre servidor de jogo. Ela compila todos os scripts com o parser real Lua 5.1 e executa caminhos de segurança e ciclo de vida. Não substitui validação da API nativa em execução.

Casos automatizados incluem: manifesto e fronteira server/client; globais intencionais versus acidentais; origem e schema; NaN/tabela cíclica/argumentos a mais; spam com memória limitada; LOG_ONLY; configuração inválida; bloqueio de ban heurístico; confirmação e ACL; skill alta sem acumulação; TTL; API de tolerância; spawn não encurtado por hook; restauração no alvo correto; movimento legítimo; C-BUG, troca e batching; inventário/recarga; aim correlacionado; hitElement ignorado; perda/jitter; screenshots inválidos/atrasados; Discord fixo/menções; comandos; rollover; quit e stop.

## Sessão inicial no MTA

Use uma instância de homologação, com duas ou mais contas de teste. Faça backup da configuração operacional antes de alterar startup. Não use cheats reais nem execute exploits contra jogadores do servidor público.

1. Pare `dm_anticheat`, mantenha o anticheat nativo do MTA e inicie `utg_anticheat` em LOG_ONLY.
2. Confira no log `startup` e modo LOG_ONLY. Ative `/debugscript 3` no cliente da staff e observe erros de Lua no console do servidor.
3. Entre/saia da conta, morra, renasça, troque de arena, abra/feche F1/F2/F3/P repetidamente, altere skin/mira, entre/saia de duelo e ranqueada, use spectate e morte súbita. Não deve haver bloqueio de interface, alteração de controles ou punição.
4. Registre CPU/memória por resource no `performancebrowser`, FPS e ping antes/depois. Repita com carga representativa. A suíte offline não fornece benchmark real.
5. Confira `/acinfo ID` e arquivos JSONL. Um sinal é algo a investigar, não prova. Registre arena, arma, ping, momento e ação legítima correspondente.

## Teste por detector

| Detector | Controle legítimo | Teste controlado e resultado esperado |
|---|---|---|
| Event security | Fluxo normal dos painéis e coleta do AC. | No harness offline, source de outro jogador, NaN, tabelas e spam: descartados e atribuídos ao remetente. Não criar endpoint de teste em produção. |
| Evento inválido/limiar | Reiniciar resource cliente pode produzir evento atrasado. | Enviar evento inexistente apenas na instância de teste; log contextual, nunca ban. Limiar depende de configuração nativa do host. |
| ElementData | Loja, VIP, caixas, rank, proteção e troca de arena server-side. | Em fixture cliente de homologação, tente alterar `dm:money` próprio e de outra conta consentida. LOG_ONLY registra autor correto e não reverte; REVIEW também só observa; ENFORCE com ações LOG restaura o alvo. Nunca testar em economia real. |
| Aim | Jogadores experientes com muitos HS, precisão alta e trocas rápidas. | Harness verifica combinação de tiros/hits/targets/telemetria. No jogo, colete baseline com armas e distâncias diversas. Accuracy/HS sozinhos não devem escalar. Não há teste honesto que certifique detectar todo aimbot. |
| Silent aim | Terceira pessoa, sniper, mira customizada, look-behind e ping variado. | Compare evidências de desvio com vídeo da sessão de teste; trate divergência como experimental. Nenhum ban. |
| Fire-rate | C-BUG rápido em Deagle/Shotgun/Sniper; troca, reload e recarga automática. | Harness injeta intervalos impossíveis persistentes e bursts de rede. Somente o padrão persistente gera `fire_cadence`; no jogo calibre usando cadência legítima máxima. |
| Teleport | F2, troca de arena, respawn, recuperação de colisão, sudden death e comando admin. | Harness compara salto sem tolerância com mutation hook/export; nenhum salto autorizado deve gerar suspeita. Em jogo não desative integrações de produção para forçar detecção. |
| Speed | Sprint, quedas, rampas, colisão e veículos. | Harness/fixture de teste com deslocamento persistente sem permissão gera contexto. Não é prova independente de speedhack. |
| Fly/airbreak | Queda longa, salto, objetos customizados, espectador e jogador congelado. | Fixture mantém deslocamento suspenso sem contato por mais de 6 s; log experimental. Plataformas móveis e streaming exigem revisão. |
| Noclip | Portas, corredores estreitos e mapas com objetos dinâmicos. | Fixture/harness combina relato de colisão com deslocamento repetido; relato isolado ou posição enviada pelo cliente não autoriza punição. |
| Vida/armor | Cura por kill e colete de arena. | Compare mudanças com hook/export e sem contexto em homologação; só aumento inesperado gera sinal fraco. Não há detector de invulnerabilidade baseado em vida inalterada. |
| Armas/munição | Todas as arenas, cada conjunto X1, papel sniper/M4, recarga por kill/troca. | Harness usa inventário fora do loadout durante três amostras. Equipamento novo legítimo precisa de integração antes de aplicar políticas. |
| Lua executor | Resources normais com código dinâmico. | Habilite opcionalmente o hook e teste em fixture diagnóstica; registre resource/arquivo/linha/função/tamanho. `pcall` continua funcionando. Não prova integridade do cliente. |
| Screenshot | LOG_ONLY recusa captura. | Em REVIEW, `/acscreenshot ID`: capture válida é salva; minimizar/desabilitar captura só registra status. Tag errada, outro resource, timeout e arquivo grande são rejeitados no harness. |
| Discord | Desativado por padrão. | Webhook privado de teste opcional, somente após configurar localmente: confira identidade/score/evidência, sem menções e sem IP por padrão. Não use webhook real no Git. |
| Staff | Usuário comum, Helper, Moderator e Admin autenticados. | Apenas grupos/direito autorizados respondem. `/acignore` expira em 120 s e não dispensa proteção determinística. |

## Critérios de avanço

- Sem erros novos de Lua durante login/quit/restart e nos fluxos de combate.
- Zero kick/ban pelo novo AC em LOG_ONLY/REVIEW, inclusive ao simular payload inválido.
- Nenhuma alteração nos controles/C-BUG, skin, HUD, câmera ou painéis pelo AC.
- Classificar os sinais de jogadores legítimos antes de reduzir tolerâncias.
- Medir custo com população representativa, mapas pesados, ping alto e perda de pacotes.
- Separar falhas de integração de violações de protocolo. Resolver `wep:hit` e `ac:report` do projeto antigo em alteração própria, com testes, antes de confiar em métricas de combate para punições.
- Só considerar ENFORCE determinístico após homologação. Heurísticas permanecem bloqueadas para remoção nesta versão.

Não há comando escondido que fabrique evidências em produção. Os testes de protocolos e de anomalias sintéticas ficam exclusivamente no harness que não é carregado pelo `meta.xml`.
