# Auditoria prévia — UTG AntiCheat

Data: 19/10/2026. Análise estática, antes da implementação. Não é certificação de segurança nem teste no servidor FTP.

## Versões e escopo

- UTG: `1e7ab2e31f02ffe53bfb90d80ba86b6fe4099fdb`, base de `origin/claude/modest-cray-8tz6fw`.
- [Claire](https://github.com/erknneto/mtasa-claire-anticheat/tree/973f3876e59f6173c78c9d5e45a69dd7d59ab9bb): `973f3876e59f6173c78c9d5e45a69dd7d59ab9bb`.
- [uW33D](https://github.com/ruip005/mta_anticheat/tree/c89959db829cf2812e5c5f900e49cc0512730bfa): `c89959db829cf2812e5c5f900e49cc0512730bfa`; principalmente `v2.3.0.03` e conferência de módulos de `Development`. Os vários anticheats em `Others AC` não são tratados como se fossem a implementação principal.
- Nenhum código das referências foi executado ou incorporado. A arquitetura e os arquivos Lua deste resource são novos. Referências utilizadas para análise de riscos e conceitos.
- A pasta original do usuário tem alterações anteriores não commitadas. Elas foram preservadas. Esta branch parte da versão remota indicada, em worktree separado, e altera apenas `utg_anticheat`.

## Claire

| Local | Achado e consequência | Decisão |
|---|---|---|
| `server/core.lua`, evento remoto `clairePunish` | Aceita motivo do cliente e chama punição sem evidência no servidor. Usa `client`, portanto nesse caminho o problema é autopunição sem validação, não atribuição arbitrária a outro jogador. | Não implementar evento remoto de punição. |
| `server/aimbot.lua`, handler de `onPlayerWeaponFire` | Parâmetros deslocados: segundo argumento tratado como arma, sétimo como alvo. São coordenadas na assinatura do servidor. Além disso, precisão elevada vira punição. | Reescrever coleta e usar pontuação somente para revisão. |
| `server/fastfire.lua` | `firing_speed` não estabelece intervalo entre eventos em milissegundos. Acrescentar ping ao mínimo torna jogadores com latência mais suspeitos. Ausência de adaptação ao C-BUG. | Timestamps, perfis conservadores por arma, descarte de rajadas de rede e períodos de troca. |
| `server/fastfire.lua`, limpeza | Callback de quit recebe tipo da saída, mas a função de limpeza espera jogador. | Estado por jogador removido usando `source`. |
| `server/elementdata.lua` | Lista genérica de chaves e cancelamento de alteração incompatível com MTA 1.6. | Lista das chaves realmente usadas; espelho server-side; restauração explícita somente em ENFORCE. |
| `client/function_blocker.lua` | Hook sem filtro por nome, bloqueio de funções legítimas incluindo `pcall`, busca de palavras em GUI/clipboard. `onClientGUIChanged` não fornece o elemento como primeiro argumento. | Descartar bloqueios e inspeção de clipboard. Hook opcional, filtrado, sem `skip`. |
| `server/screenshot.lua` | Captura desabilitada gera punição; arquivo de captura é apagado imediatamente. | Status de captura nunca prova cheat; retenção temporária limitada e correlação da solicitação. |
| `meta.xml`, `whitelist.lua` | Lista de seriais enviada como shared. | ACL/conta no servidor; nenhuma whitelist de serial enviada. |
| `server/vpncheck.lua` | Serviço externo `ip-api.com` por HTTP; proxy/hosting usado para punir, sem prova de cheat. | Descartado. Não bloquear VPN ou hospedar bans globais. |
| `server/godmode.lua` | Vida alta/inalterada após dano pode ser proteção, cura por kill ou dano customizado. | Não copiar detecção de invulnerabilidade. Observar aumentos sem autorização, apenas como contexto. |

Conceitos úteis: módulos pequenos, tolerância temporal, reset após spawn/dimension, cache com expiração. Não foram copiadas implementações. Não foi encontrado caminho de execução remota equivalente ao `downloadCode` do uW33D nos módulos Claire examinados; sua dependência de VPN é consulta externa, distinção importante.

## uW33D

Referências de linha abaixo pertencem a `v2.3.0.03` nesse commit.

| Local | Achado e consequência | Decisão |
|---|---|---|
| `sMain.lua:209–224`, `downloadCode` | `fetchRemote` seguido de `pcall(loadstring(code))`. Código remoto com privilégios do resource. | Proibido; não existe carregador, updater executável ou verificação de licença externa no UTG. |
| `sMain.lua:114–127`, `MD.LogDC` | Evento remoto aceita webhook/destino e mensagem do cliente. Permite requisições externas arbitrárias pelo servidor e spam. | Destino fixo e exclusivamente server-side; fila limitada. |
| `sMain.lua:174–186`, `onTriggerPrint` | Jogador, tag e webhook vêm como argumentos remotos; validação de elemento usa condição incorreta com `and/not`. | Nenhum evento remoto de screenshot; somente staff autorizada e política server-side. |
| `sMain.lua:1343`, `onBANWEAPONCHEATER` | Arma informada pelo cliente pode provocar ban sem consultar inventário real. | Inventário observado no servidor + loadout por arena. |
| `sMain.lua:1369`, `1386`, `1519` | Eventos de speed/fly/fire-rate acionam punição a partir do relato. | Heurísticas não podem produzir kick/ban neste lançamento. |
| `cMain.lua:98–120` | Cinco headshots em janela curta disparam suspeita. Bons jogadores e armas/arenas especializadas invalidam essa regra. | Headshots isolados têm peso zero. |
| `cMain.lua:257–275` | Contagem genérica acima de 27 tiros em 2 segundos, sem perfil suficiente de arma/C-BUG. | Descartada. |
| `sMain.lua:1408`; `Development/src/modules/Blacklist/sVehicles.lua` | Assinatura client-side usada em evento server-side de tiro. | Assinaturas conferidas no Wiki MTA. |
| `sMain.lua:1550`, `jac:detected` | Usa `source` para punir e atributos do relato para log, sem vinculá-los ao remetente real; inclui destino externo hardcoded. | Não reproduzir destino/segredo; telemetria só pode descrever o próprio remetente. |
| `sMain.lua`, handler de ElementData | Reverte em `client`, embora o elemento alterado seja `source`. Verificação de cliente também pode executar sobre nil. | Validar ator e elemento separadamente; reverter no elemento afetado. |
| `Development/src/modules/Player/cLua.lua` | Hook de `pcall/load/loadstring`: uso legítimo não é prova de executor. | `pcall` não é monitorado nem bloqueado. Telemetria de execução dinâmica é contextual e opcional. |
| `sMain.lua`, consultas de global ban/spoofer/VPN, updater | Serviços externos e atualizações ampliam confiança e dependências operacionais. | Bans locais UTG, Discord opcional apenas para saída de logs. |
| `sMain.lua:862`, `1672` | Falha/desativação de screenshot pode gerar ban. | Falha de captura é status operacional, nunca detecção. |

Conceito reaproveitado: capturas vinculadas a investigações e logs para staff. Reimplementado com tag gerada no servidor, destino fixo, timeout, limite global e expiração. Não há código copiado de Claire ou uW33D.

## Compatibilidade do servidor atual

Todos os caminhos abaixo foram examinados antes de escolher regras. Paths relativos a `mods/deathmatch/resources/[dm]`.

| Sistema | Comportamento legítimo e adaptação |
|---|---|
| `dm_core/shared/config.lua` | Lobby dimensão 0; AK47 1/arma 30; M4 2/31; X1 3/conjunto de duelo; C-BUG 4/24,25,34; katana 8/8. Ranqueadas M4 também permitem sniper por função. Configuração do AC declara esses modos e utiliza o loadout individual server-side para refinar. |
| `dm_core/server/s_arenas.lua:74–98` | `takeAllWeapons`, entrega, `dm:loadout` não sincronizado; recarga ao trocar de arma e matar. Aumento de munição não é automaticamente cheat. |
| `dm_core/server/s_arenas.lua`, `s_kills.lua` | Spawn, health 100, armor por modo, proteção temporária, cura por kill, respawn e congelamento até colisão. Janelas curtas de tolerância e acompanhamento de mutações autorizadas. |
| `dm_core/client/c_spawn.lua` | Corrige Z ao carregar colisão e pede recuperação de spawn. Spawn ganha carência estendida; movimento continua heurístico. |
| `dm_ui/client/c_screens.lua:65–115` | F2 altera dimensão local, câmera, congela e restaura posição. Servidor não observa diretamente a autoria dessas chamadas locais. Não prometer diferenciar esse fluxo de um executor; nenhum movimento gera punição automática. |
| `dm_cbug/s_cbug.lua`, `c_cbug.lua` | `crouchbug` e `quickstand` habilitados globalmente; bloqueio de agachar fora da arena é client-side. O AC não altera glitches, controles, animação ou arma. Limites conservadores de C-BUG também evitam acusar trocas rápidas fora da arena. |
| `dm_ranked/server/s_ranked.lua` | Dimensões de instância, aquecimento, papéis sniper/M4, morte súbita com teleport, spectate de mortos, `dm:managed/noRespawn/noReward`. Mutações legítimas concedem carência; mortos não são amostrados. |
| `dm_duel/server/s_duel.lua` | Instâncias e spawn por round, arma escolhida, armor e proteção de contagem. O AC usa loadout do jogador, não presume arena X1 desarmada durante duelo. |
| `dm_maps/s_loader.lua`, `s_extras.lua` | Mapas com objetos e colisões próprias, dimensões clonadas. Ground/colisão não é prova isolada de fly/noclip; suspensão temporária durante início/parada de mapa. |
| `dm_login/server/s_login.lua` | Câmera/dimensão antes do login; convidado já recusado nessa versão. Não avaliar movimento/armas antes de `dm:ready`. |
| `dm_core/server/s_util.lua`, `s_commands.lua`, `acl-adicionar.txt` | Admin/SuperModerator/Moderator por ACL de conta. Staff do AC usa os mesmos grupos; Helper não ganha acesso automaticamente. Seriais não autorizam comandos. |
| `dm_crates`, `dm_skins`, `dm_armas` | Skins, modelos e equipamentos cosméticos legítimos. Nenhum detector usa modelo de personagem ou aparência da arma como prova. |
| `dm_weapons/server/s_damage.lua` | Dano próprio; `ac:hit` nasce de relato da vítima. É dado correlacionável, não confirmação independente e infalível do servidor. |
| `mtaserver.conf` | `bullet_sync=1`, player sync 100 ms, camera sync 500 ms, `dm_anticheat` no startup. Timestamps são de chegada dos pacotes; tolerância à rede é indispensável. ACL real do host não está versionada. |

## Eventos e problemas existentes — não alterados

1. **Crítico — `dm_anticheat/server/s_ac.lua`, `ac:report` (a partir de 208)**: cliente escolhe suspeito/kind/detail/strong. Mesma dimensão não comprova acusação. Repetição de relatos pode levar a autoban. `AUTOBAN=true` por padrão. Há ainda referência a `ACC_MIN_SHOTS` antes do seu escopo local no callback de tiro e a `aimReports` antes do local no callback de quit. Revisão/correção é necessária no resource antigo, ou sua retirada operacional antes do teste do novo. Não foi modificado.
2. **Alto — `dm_weapons/server/s_damage.lua:20–80`, `wep:hit`**: vítima informa atacante/arma/bodypart/loss. Existe vínculo `client==source`, checagens de arena/arma e teto de loss, mas não limite inferior/finito. Loss negativo pode aumentar vida/armor. Não há associação obrigatória com tiro real; omitir relatos é possível. O novo AC não transforma esse evento em prova para ban. Corrigir o pipeline de dano exige trabalho separado, testes de combate e autorização para modificar `dm_weapons`.
3. **Médio — `dm_core/server/s_arenas.lua:358`, `dm:badSpawn`**: pedido de respawn legítimo depende de declaração do cliente; sem validação de queda/posição no servidor nem janela estrita após spawn. Pode ser usado como fuga/reset. Não é correto punir o teleport resultante, pois é o próprio core que o realiza.
4. **Médio — `dm:requestArena`, `ranked:requestInfo/setRole/requestJoin`, `clans:requestInfo`, `duel:request`, `crates:open/equip/trail`, `shop:buy`, `crosshair:save/request`**: há validações de identidade e/ou domínio em diferentes graus, mas falta rate-limit consistente; spam pode gerar broadcast, DB, timers ou notificações. Não se afirma que todos permitem roubo de dinheiro ou impersonação. `crosshair` usa `client` como ator e ignora `source`, o que é seguro quanto à identidade, embora falte controle de frequência.
5. **Médio — `clans:create`**: valida nome/tag/saldo, mas SELECT de confirmação é assíncrono; revisar bloqueio de operação pendente e unicidade no DB para pedidos concorrentes. Risco a testar, não exploração confirmada.
6. **ElementData**: `dm:arena`, `dm:ready`, `dm:protected`, `dm:loadout`, `dm:money`, `dm:vip`, `dm:perks`, `dm:managed`, `dm:inDuel`, dados de rank/ID e cosméticos são escritos no servidor. Não usar nomes genéricos `admin`/`money` que não correspondem ao projeto. Dados locais de painel/câmera não entram na lista. O novo resource observa tentativas e mantém espelho interno; em LOG_ONLY não desfaz alteração do jogo.

O módulo de segurança novo protege os eventos **do próprio AC**, observa eventos inválidos e o limiar global nativo. Ele não é um firewall automático para todos os eventos de outros resources. Tentar remendar esses eventos por hooks globais alteraria mecânicas e aumentaria riscos.

## Integrações planejadas antes da implementação

- Somente arquivos dentro de `utg_anticheat`; nenhuma alteração de config, ACL, scripts ou resource antigo.
- Adaptador de mutações server-side com `addDebugHook` e lista específica de funções, limitado a resources auditados. Apenas concede tolerância curta; não bloqueia funções.
- Exports server-side `allowTeleport`, `allowVelocity`, `allowHealth`, `allowArmor`, `allowWeapons`, com resource chamador autorizado e timeout máximo. Chamadas extras são opcionais quando o adaptador não cobre um novo sistema.
- Espelho de ElementData atualizado apenas a partir de escrita server-side. Dados de outros resources não se tornam automaticamente confiáveis só por passarem por evento local.
- Novo AC nunca desliga o antigo sozinho. Antes do teste: parar `dm_anticheat` e depois iniciar `utg_anticheat`; revisar startup manualmente. Caso contrário, LOG_ONLY do novo não impede bans feitos pelo antigo.

## Documentação primária consultada

- [Tiro server-side](https://wiki.multitheftauto.com/wiki/OnPlayerWeaponFire): assinatura diferente do cliente; `hitElement` pode estar incorreto, portanto não é verdade autoritativa.
- [Tiro client-side](https://wiki.multitheftauto.com/wiki/OnClientPlayerWeaponFire).
- [ElementData](https://wiki.multitheftauto.com/wiki/OnElementDataChange): MTA 1.6 precisa restauração explícita; cancelamento só documentado em 1.7.
- [Debug hooks](https://wiki.multitheftauto.com/wiki/AddDebugHook): custo, lista de nomes, callbacks e não recursividade.
- [Solicitação de screenshot](https://wiki.multitheftauto.com/wiki/TakePlayerScreenShot) e [resposta](https://wiki.multitheftauto.com/wiki/OnPlayerScreenShot).
- [Rede](https://wiki.multitheftauto.com/wiki/GetNetworkStats): loss é porcentagem; dado de envio não mede toda a qualidade de recepção.
- [Evento inválido](https://wiki.multitheftauto.com/wiki/OnPlayerTriggerInvalidEvent) e [limiar](https://wiki.multitheftauto.com/wiki/OnPlayerTriggerEventThreshold): versões mínimas e parâmetro opcional nas builds antigas.
- [Alvo](https://wiki.multitheftauto.com/wiki/OnPlayerTarget), [dano](https://wiki.multitheftauto.com/wiki/OnPlayerDamage), [ground](https://wiki.multitheftauto.com/wiki/IsPedOnGround), [raycast](https://wiki.multitheftauto.com/wiki/ProcessLineOfSight), [ban local](https://wiki.multitheftauto.com/wiki/BanPlayer).
