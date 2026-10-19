# UTG AntiCheat — DM / PVP / C-BUG

Resource independente para o servidor UTG, implementado após a auditoria em [AUDIT.md](AUDIT.md). A versão inicial observa e registra: **`debugMode = true` e `punishmentMode = "LOG_ONLY"`**. Não contém código remoto, bans globais, licença externa, updater ou dependência dos anticheats de referência.

É uma base funcional para homologação, não uma promessa de detectar todo cheat. Não houve execução no seu servidor FTP nem teste com jogadores reais. Os testes automatizados executam Lua 5.1 com APIs MTA simuladas; detalhes de rede, streaming, renderização e desempenho precisam da etapa dentro do jogo.

## Instalação e primeiro teste

1. Copie **somente esta pasta `utg_anticheat`**, inteira, para `mods/deathmatch/resources/[dm]/utg_anticheat` no servidor. Não substitua outros resources.
2. Confirme MTA server **1.6.0 build 22459 ou posterior** e client **1.6.0 build 21695 ou posterior**. `bullet_sync` já está habilitado na configuração versionada. Preserve o anticheat nativo do MTA.
3. Mantenha os valores padrão em `config/settings.lua`.
4. No console do servidor, em ambiente de teste, execute:

```text
stop dm_anticheat
refresh
start utg_anticheat
```

O `dm_anticheat` existente contém autoban e um evento de acusação vulnerável. **LOG_ONLY do novo resource não controla punições feitas pelo antigo.** O novo apenas avisa se o antigo estiver ativo; não o desliga automaticamente. Parar o antigo não desliga o anticheat nativo do MTA. Seus clientes ainda podem tentar enviar `ac:report`, agora sem handler: isso será apenas contexto `invalid_event`, nunca ban automático. Revisar/remover essas chamadas pertence à manutenção futura do resource antigo.

Depois de homologar, ajuste manualmente o startup de `mtaserver.conf`: desative o startup de `dm_anticheat` e acrescente `<resource src="utg_anticheat" startup="1" protected="0" />` depois dos resources DM. **Esse arquivo não foi alterado nesta branch.** Não é necessário reiniciar todo o servidor para iniciar o novo resource.

Para reverter o teste, `stop utg_anticheat`. Não há migração de banco, alteração de armas, HUD, skins, controles, glitches ou layouts a desfazer. A eventual reativação do antigo deve considerar os riscos registrados na auditoria.

## Modos e configuração

| Configuração | Resultado |
|---|---|
| `debugMode = true` | Força LOG_ONLY mesmo se outro modo estiver escrito. |
| `debugMode = false`, `punishmentMode = "LOG_ONLY"` | Só logs/evidências; sem alertas automáticos, avisos, capturas, rollback, kick ou ban. |
| `debugMode = false`, `punishmentMode = "REVIEW"` | Permite alertas/capturas por score e captura manual de staff; sem kick/ban/rollback. |
| `debugMode = false`, `punishmentMode = "ENFORCE"` | Restaura ElementData protegida; permite punições determinísticas explicitamente configuradas e confirmadas. Heurísticas continuam sem kick/ban. |
| Modo desconhecido | LOG_ONLY, por segurança. |

Validação de protocolo e descarte de pacotes inválidos funcionam em todos os modos. LOG_ONLY não oferece endpoints inseguros só por ser modo de teste. Comandos de consulta respondem à staff; `/acignore` continua sendo uma ação explícita da staff. Discord, se habilitado, é saída de logs e pode ser usado em LOG_ONLY.

As opções `settings.detectors` desligam individualmente `aimbot`, `silentaim`, `firerate`, `speedhack`, `teleport`, `fly`, `noclip`, `weaponhack`, `eventabuse`, `elementdata`, `luaexecutor`, `screenshot`. A opção adicional `vitals` controla observações de aumento de vida/armor. Reinicie o resource após editar configurações.

Desligar `eventabuse` desliga sua detecção/log de suspeita, **não** a validação dos eventos do AC. Desligar `elementdata` desliga detecção/restauração; a leitura de contexto interno não aceita escrita client-side. `luaexecutor` tem ainda `enableClientIntegrityHook = false` por padrão: habilite somente para diagnóstico controlado.

Arquivos de configuração são todos server-side, inclusive armas, permissões e webhook. O cliente recebe apenas três booleanos para ativar coleta de aim, colisão e integridade.

## Arquitetura e arquivos

| Arquivo/pasta | Responsabilidade |
|---|---|
| `meta.xml` | Ordem de carga, versões mínimas, exports exclusivos do servidor. |
| `config/settings.lua` | Modo, toggles, limites, expiração, ações por detecção. |
| `config/weapons.lua` | Perfil de cada arma e conjuntos permitidos por arena. |
| `config/permissions.lua` | ACL da staff e resources autorizados a conceder tolerância. |
| `config/protected_data.lua` | Chaves `dm:*` realmente escritas pelo servidor. |
| `config/discord.lua` | Saída opcional de logs e opções de privacidade. |
| `shared/utils.lua` | Funções matemáticas, números finitos, sanitização; sem segredos. |
| `server/core.lua` | Ciclo de vida, relógio monotônico, amostragem, rede, logs e estado por jogador. |
| `server/integration.lua` | Exports e hook específico para mutações legítimas. |
| `server/event_security.lua` | Identidade `client`, source esperado, schemas, ranges, limites por evento/global. |
| `server/evidence.lua` | Histórico temporário, score, famílias e limites. |
| `server/punishment.lua` | Único lugar que pode chamar kick/ban; política central. |
| `server/combat.lua` | Disparos, correlação de hits, estatísticas, aim e cadência. |
| `server/movement.lua` | Saltos de posição, velocidade persistente, hover, contexto de colisão e vitais. |
| `server/weapons.lua` | Inventário real versus arena/loadout server-side. |
| `server/elementdata.lua` | Atribuição correta do autor e proteção das chaves verificadas. |
| `server/integrity.lua` | Recebe contexto limitado do próprio cliente, sem punição direta. |
| `server/screenshot.lua` | Solicitações, correlação, status, armazenamento e descarte. |
| `server/discord.lua` | Webhook fixo, fila limitada, nenhuma execução de resposta. |
| `server/staff.lua` | Quatro comandos e alertas por ACL/conta. |
| `client/core.lua`, `aim.lua`, `movement.lua`, `integrity.lua` | Coleta limitada, apenas do próprio jogador. |
| `tests/` | Testes Lua 5.1 via Python/Lupa; não são carregados pelo MTA. |
| `AUDIT.md`, `TESTING.md` | Auditoria anterior à implementação e roteiro de homologação. |

Não há `client/screenshot.lua`: a API nativa já captura a imagem pedida pelo servidor. Adicionar um protocolo client-side de seleção de captura ampliaria a superfície de ataque sem benefício.

## Detectores e confiança

| Sinal | Confiança e decisão | Falsos positivos/limites |
|---|---|---|
| `protected_data` | Alta: o engine atribui a escrita remota a `client`; o elemento afetado é `source`. ENFORCE pode restaurar e aplicar ação configurada após repetição. | Resource novo pode legitimamente precisar escrita client-side numa chave; auditar antes de alterar lista. LOG_ONLY não reverte. |
| `event_schema`, `remote_source` | Alta para violação do contrato do AC; não prova a motivação do jogador. Identidade, tipos, argumentos a mais, NaN/infinito e ranges validados. | Versão errada/bug do cliente pode causar violação; ações padrão são LOG. |
| Spam e evento inválido | Média/baixa, contexto de protocolo. Sem remoção automática. | Reconexão, resource parado, scripts antigos e bursts legítimos. |
| `aim_accuracy` | Baixa, peso 0,75; exige 100 tiros, 20 s e 3 alvos na janela. | Jogador habilidoso pode ter precisão elevada. Repetição desse sinal nunca cresce além de 0,75. |
| `aim_snap` | Heurística, peso 3,5: múltiplas aquisições rápidas e amplas com hit correlacionado, distância e rede estável. | Pacotes agrupados e target sync não revelam o instante exato em que a mira mudou. |
| `silent_alignment` | Experimental, peso 2: desvio relatado localmente + amostra grande de hits correlacionados. | Câmera terceira pessoa, sincronização, look-behind e telemetria adulterável. Não identifica todo silent aim. |
| `aim_combination` | Peso 2 adicional quando diferentes sinais de aim coexistem. | Não representa provas independentes: parte dos dados nasce no mesmo cliente. |
| `fire_cadence` | Heurística, peso 2; timestamps de chegada por arma, persistência por 5 s e orçamento de burst. | Não são timestamps físicos do disparo. Pacotes, troca, recarga e C-BUG impedem ban seguro. |
| `position_jump`, `sustained_speed` | Heurísticas, peso 2 cada, várias amostras para velocidade. | Teleport client-side legítimo, rampas, lag, colisões e scripts novos. |
| `sustained_hover` | Experimental, peso 2: deslocamento suspenso persistente sem ground/contato/queda; indício de fly/airbreak. | Objetos customizados e streaming. Não cobre todo fly/airbreak, principalmente parado. |
| `collision_crossing` | Experimental, peso 1,5: passagem reportada pelo cliente + deslocamento compatível repetido no servidor. | Colisão não carregada, geometria dinâmica e raycast impreciso. |
| `health_increase`, `armor_increase` | Contexto, peso 0,5; só aumentos sem tolerância conhecida. | Não é detector de godmode. Cura por kill e alterações server-side auditadas são toleradas. |
| `unexpected_weapon`, `unexpected_ammo` | Média, peso 3; três amostras confrontadas com inventário, arena e loadout. | Nova mecânica, arma de admin sem atualização do loadout ou chegada fora de ordem. Sem ban automático. |
| `dynamic_lua_context` | Baixa, peso 1, diagnóstico opcional. | Código dinâmico pode ser legítimo; a ausência de relato não atesta integridade. |

Os valores de confiança são categorias operacionais, não probabilidades calibradas estatisticamente. **Nenhuma heurística desta versão é elegível para kick ou ban**, mesmo com score alto ou entrada de configuração tentando fazê-lo. Não existe ban por headshots, sequência de cinco HS ou habilidade alta.

### Combate e C-BUG

`onPlayerWeaponFire` usa a assinatura do servidor: `weaponID, endX, endY, endZ, hitElement, startX, startY, startZ`. `hitElement` é ignorado como confirmação de acerto porque o Wiki documenta inconsistências.

Cada tiro precisa corresponder à arma observada no servidor. Hits são associados uma vez a tiro recente da mesma arma, com jogadores na mesma dimension/interior e distância plausível. Dano nativo e `ac:hit` são deduplicados. Shotguns não entram no cálculo de precisão de uma bala/um hit.

O bridge `ac:hit` é local, aceita apenas origem `dm_weapons` e não aceita chamada remota. **O pipeline original depende do relato da vítima**, portanto essa associação é correlação e nunca prova independente para ban. O AC não corrige a vulnerabilidade de `wep:hit` registrada na auditoria. Eventos de dano que chegam antes do tiro podem deixar hits sem correlação; isso reduz sensibilidade, em vez de inventar certeza.

Estatísticas: tiros, hits correlacionados, tiros sem hit confirmado (`misses`), headshots, proporções, maior sequência de hits, alvo anterior, aquisições, mudanças de alvo/ângulo, distância, arma, parte atingida e duração da janela. `misses` não significa erro comprovado. `/acinfo` exibe um resumo, evidências guardam metadados e o histórico de tiros é temporário.

Perfis cobrem Deagle, Shotgun, Sawn-off, Combat Shotgun, MP5, AK47, M4, Rifle e Sniper. Katana/soco têm validação de inventário, não cadência de bala. Limites são **pontos iniciais conservadores a calibrar**, não mínimos físicos certificados. O menor piso C-BUG é considerado inclusive fora da arena para não confundir troca rápida com cheat. Não há alteração de `firing_speed`, glitches, animações ou controles.

Ping acima de 250 ms, loss acima de 2%, variação de ping acima de 80 ms, pausas/rajadas agrupadas e troca de arma suspendem comparações. Aumento de munição é esperado: o servidor recarrega ao trocar e matar. Repetir disparos no mesmo tick não provoca ban.

## Score e evidências

Estado privado em `AntiCheat.players[player].evidence`, sem ElementData pública de suspeita. Cada evidência contém `id`, tipo, detector, família, peso, confiança, timestamp, tick, metadados e classificação determinística.

- Expiração padrão: 180 s; no máximo 64 registros por jogador.
- Peso decai linearmente até zero dentro do TTL. Quit remove estado e referências a esse jogador em outros históricos.
- Cada tipo heurístico contribui apenas com sua observação mais forte ainda válida. Repetir accuracy elevada não cria uma acusação crescente.
- Limites por família: aim 8, movimento 6, cadência 4, inventário 5, integridade 2, protocolo/dados 10; score total limitado a 20.
- Cooldown padrão de 10 s por tipo evita log excessivo. Comprovações determinísticas repetidas permanecem separadas para a política explícita de confirmação.

| Score | Comportamento conceitual |
|---|---|
| 0–2 | Log silencioso. |
| 3–4 | Aparece em `/acsuspects`. |
| 5–6 | Alerta staff em REVIEW/ENFORCE. |
| 7–8 | Alerta e tentativa de screenshot em REVIEW/ENFORCE. |
| 9+ | Continua revisão; só ação configurada e evidência determinística autorizam remoção. |

LOG_ONLY sempre prevalece sobre esses níveis. O score não é uma licença para ban. `aim_suspicion_score` é calculado separadamente sobre a família aim e aparece em `/acinfo`.

## Punições e ACL mínima

Todas passam por `AntiCheat.punish`: `LOG`, `WARN`, `SCREENSHOT`, `STAFF_ALERT`, `KICK`, `TEMPBAN`, `BAN`. O objeto de evidência precisa existir no histórico do jogador; não se aceita uma tabela fabricada como autorização.

Para remoção, exige ENFORCE, classificação determinística, tipo permitido (`protected_data`, `event_schema`, `remote_source`), confiança alta, pelo menos três ocorrências espaçadas dentro do TTL, ação explicitamente configurada, cooldown e direito ACL da função. BAN permanente também exige `allowPermanentBan = true`. TEMPBAN usa 900 segundos por padrão. Bans são locais, por serial obtido pela API server-side, sem ban por IP.

**Recomendação inicial: mantenha todas as ações como LOG.** Depois da homologação, prefira avaliar KICK temporariamente para violações comprovadas do protocolo/dados antes de pensar em ban. Não habilite ban automático para aim, silent aim, fire-rate, movimento, arma/munição heurística, Lua por relato, evento inválido genérico ou falha de screenshot.

LOG_ONLY/REVIEW não precisam conceder `function.banPlayer` ou `function.kickPlayer`. Não coloque o resource inteiro no grupo Admin. Se optar futuramente por ENFORCE, crie grupo/ACL específicos apenas com os direitos de função necessários. Discord pode precisar de `function.fetchRemote`, conforme ACL do host. A ACL real do servidor não está neste repositório; não foi modificada nem presumida.

## Integração sem alterar mecânicas

O adaptador acompanha somente estas funções server-side, com `nameList`: spawn, posição, dimension/interior, velocidade, health, armor, give/take weapon, munição e congelamento. Apenas resources auditados em `config/permissions.lua` podem conceder tolerância. Não bloqueia nenhuma chamada. `pcall` nunca é bloqueado ou monitorado.

Resources atuais autorizados: `dm_core`, `dm_ranked`, `dm_duel`, `dm_login`, `dm_maps`, `dm_weapons`, `admin`. Cada chamada relevante concede 2 s; spawn concede 12 s. Uma tolerância curta nunca encurta uma maior já ativa. Mudança de mapa/spawn reseta comparação. Não há whitelist permanente de jogador/staff/serial.

Para resource novo, audite-o e acrescente seu nome na lista server-side. Quando necessário, use o export **antes da alteração legítima**, no script do servidor:

```lua
local ac = getResourceFromName("utg_anticheat")
if ac and getResourceState(ac) == "running" then
    exports.utg_anticheat:allowTeleport(player, 3000, "entrada_da_arena")
end
setElementPosition(player, x, y, z)
```

Exports disponíveis, todos com `(player, durationMs, reason)`:

```lua
exports.utg_anticheat:allowTeleport(player, 3000, "mapa")
exports.utg_anticheat:allowVelocity(player, 1500, "impulso_legitimo")
exports.utg_anticheat:allowHealth(player, 1500, "cura")
exports.utg_anticheat:allowArmor(player, 1500, "colete")
exports.utg_anticheat:allowWeapons(player, 1500, "novo_loadout")
```

Retornam booleano. Rejeitam origem não autorizada, contexto remoto, jogador inválido, motivo inválido e duração fora de 1–15000 ms. Timeout não equivale a permitir arma para sempre: mantenha `dm:loadout` e a configuração por modo consistentes quando introduzir armas novas.

O F2 e a correção de colisão fazem mudanças client-side legítimas que não aparecem nesse hook. O AC não aceita um relato do cliente como permissão autoritativa. Carências, reset, congelamento e ausência de punição heurística evitam medidas destrutivas; qualquer sinal remanescente deve ser classificado durante a homologação. Não foram feitas mudanças no F2, nos mapas ou no C-BUG.

## Staff

Somente contas autenticadas dos grupos `Admin`, `SuperModerator`, `Moderator`, ou com direito ACL `resource.utg_anticheat.staff`. Helper não é incluído automaticamente. ElementData `admin/staff` e serial não autorizam comandos.

| Comando | Resultado |
|---|---|
| `/acsuspects` | Até 15 jogadores com maior score a partir de 3. |
| `/acinfo ID` | Score geral/aim, ping, arena, tiros/hits/HS/snaps e seis evidências recentes. |
| `/acscreenshot ID` | Captura solicitada pela staff, com cooldown e limite global. Em LOG_ONLY explica que é preciso REVIEW. |
| `/acignore ID` | Ignora novas evidências heurísticas por 120 s. Não apaga histórico nem dispensa validação de eventos/dados. |

IDs vêm do `dm:id` mantido pelo servidor. ID inexistente/duplicado não seleciona jogador arbitrariamente. Comandos têm rate-limit e ações manuais são registradas.

## Logs, screenshots e privacidade

Logs JSON saem em `server.log` e em três arquivos privados rotativos `@audit-1.jsonl` a `@audit-3.jsonl`, de até aproximadamente 2 MiB cada. Incluem player, conta, serial server-side, ping, arena, dimension, detecção, score, evidência e timestamp quando aplicável. Rotação do `server.log` é responsabilidade do host.

Capturas usam exclusivamente a API nativa do servidor. A resposta precisa corresponder ao jogador, resource e tag pendentes. Cliente não escolhe jogador, tag, URL ou destino. Máximo 4 pendências, 1 captura por jogador/minuto, timeout 45 s, máximo 1 MiB por imagem, 20 arquivos e TTL 15 min. Arquivos privados `@capture-N.jpg` são descartados por TTL, parada e reinício; copie evidências relevantes para investigação antes disso. Guardar só metadados não preserva a imagem após expiração. Não se envia imagem automaticamente para serviço externo.

`disabled`, `minimized`, `error`, timeout ou JPEG inválido não somam score. Screenshot pode não mostrar menus/overlays e não prova sozinho ausência ou presença de cheat. Não há acesso ao clipboard.

Discord é opcional e desativado. Coloque o webhook apenas na cópia local de `config/discord.lua`; nunca publique um valor real. Só aceita endpoint HTTPS oficial `discord.com/api/webhooks/...`, sem redirecionamento; fila de 40, uma requisição a cada 2 s, limite de 15 s para pendência, sem retentativas ilimitadas e com menções desativadas. Respostas não são executadas. Serial pode ser omitido em Discord; IP é omitido por padrão. Arquivos locais contêm identificadores: restrinja acesso à staff responsável.

## Custos e limites

- Nenhum handler de renderização do AC e nenhum loop por todos os jogadores a cada frame.
- Cliente: 10 amostras locais de mira/s, 2 envios resumidos/s; colisão em 2 Hz, até um raycast por amostra somente se houve deslocamento elegível. Sem varredura de jogadores.
- Servidor: até 32 jogadores por tick de 250 ms; um jogador é amostrado no máximo a cada 500 ms. Sob carga maior, observações antigas são descartadas em vez de virarem acusações.
- Inventário: 13 slots por amostra; avaliação de aim a cada 5 s, histórico limitado a 512 tiros/60 s por jogador. O custo de sumarização é proporcional a esse histórico limitado.
- Evidências, fila Discord, pendências, arquivos e buckets têm limites. Quit remove referências de jogador; parada destrói timers, hooks, pendências e captura temporária. Requisição HTTP pendente é abortada.
- Hook server-side observa apenas a lista explícita de mutações. Hook client-side é diagnóstico opcional e usa apenas `loadstring/load`; nunca bloqueia funções.

Não foi medido FPS/CPU sob carga real. Use `performancebrowser`, logs e medições antes/depois conforme [TESTING.md](TESTING.md). Sobrecarga, pacotes agrupados, perdas e contexto desconhecido reduzem sensibilidade deliberadamente.

## Entrega e validação

- Arquivos existentes modificados: **nenhum**. Apenas arquivos novos neste resource, na branch `codex/utg-anticheat`.
- Testes automatizados: **22 casos aprovados**, [tests/test_resource.py](tests/test_resource.py), executados com Lua 5.1 via Lupa. Incluem manifesto/sintaxe, globais acidentais, protocolo, limites, impersonação, LOG_ONLY, ACL, TTL, C-BUG, troca, rede, bridge de dano, captura, expiração e limpeza.
- Módulos experimentais: aim/silent aim, fire-rate, movimento/colisão/vitais e telemetria de executor. Inventário é comparador funcional mas permanece somente para revisão por depender do loadout e integrações.
- Não implementados deliberadamente: ban global, VPN ban, fingerprint externo, inspeção de clipboard, bloqueio de `pcall`, classificação por skill, veículo proibido genérico, aimbot determinístico, correção automática dos eventos vulneráveis de outros resources.
- Pendência operacional: homologação no MTA, calibração e correção separada do pipeline de dano/eventos antigos. A entrega não altera nem atualiza automaticamente o servidor FTP.
