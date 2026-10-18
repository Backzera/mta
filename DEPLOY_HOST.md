# Subindo o UTG em uma hospedagem (Heavy Host / TCAdmin ou similar)

Enviar só a pasta `[dm]` não basta: o servidor da hospedagem tem o **próprio** `mods/deathmatch/mtaserver.conf`
(com a lista do que inicia) e o próprio `acl.xml`. Sem esses dois ajustes nenhum resource do UTG liga e o
gamemode padrão (`play`) continua rodando.

## 1. Arquivos

1. Extraia o `[dm].zip` dentro de `mods/deathmatch/resources/` (fica `resources/[dm]/dm_core`, `dm_ui`, ...).
2. **Apague o `[dm].zip`** da pasta `resources` (o MTA tenta carregar .zip como resource e gera erro).
3. As pastas `Arena AK47`, `Arena CBUG`, `Arena M4`, `Arena X1` na raiz de `resources` não são usadas
   (os mapas já estão em `[dm]/dm_maps/maps/`). Pode apagar ou deixar.

## 2. `mods/deathmatch/mtaserver.conf` (Gerenciador de Arquivos → editar)

Dentro de `<config>`, na parte das `<resource ... />`:

- **Remova** (ou comente) a linha do gamemode padrão: `<resource src="play" startup="1" protected="0" />`
  e qualquer outra de gamemode (`freeroam`, `race`, `tdm`, `stealth`...). Mantenha `admin`, `resourcemanager`,
  `resourcebrowser`, `webadmin`, `helpmanager`, `defaultstats`, `performancebrowser`.
- **Adicione**, nesta ordem:

```xml
<resource src="dm_core" startup="1" protected="0" />
<resource src="dm_maps" startup="1" protected="0" />
<resource src="dm_weapons" startup="1" protected="0" />
<resource src="dm_cbug" startup="1" protected="0" />
<resource src="dm_duel" startup="1" protected="0" />
<resource src="dm_shop" startup="1" protected="0" />
<resource src="dm_ranked" startup="1" protected="0" />
<resource src="dm_clans" startup="1" protected="0" />
<resource src="dm_crates" startup="1" protected="0" />
<resource src="dm_login" startup="1" protected="0" />
<resource src="dm_ui" startup="1" protected="0" />
<resource src="dm_armas" startup="1" protected="0" />
```

- Opcional, mas recomendado: `<fpslimit>100</fpslimit>` e `<voice>0</voice>`.

## 3. Permissões (`mods/deathmatch/acl.xml`)

Dentro de `<group name="Admin">`, junto dos outros `<object name="resource.*" />`, adicione:

```xml
<object name="resource.dm_core" />
<object name="resource.dm_login" />
<object name="resource.dm_duel" />
```

Ou, no console do servidor (painel → Console), depois de iniciar:

```
aclrequest allow dm_core all
aclrequest allow dm_login all
aclrequest allow dm_duel all
```

Para você ser ADMIN no jogo: `addaccount SEUUSUARIO SENHA` e `aclgroup addobject Admin user.SEUUSUARIO`
no console (ou edite o `acl.xml`). As tags de staff seguem os grupos Admin / SuperModerator / Moderator / Helper.

## 4. Reinicie o servidor e confira o log

`mods/deathmatch/logs/server.log` deve mostrar `Starting dm_core`, `Starting dm_ui` ... sem
`Couldn't find`, `Loading script failed` ou `ERROR`. Se aparecer algo, me mande as linhas.

No console também dá para testar na mão: `refresh` → `start dm_core` → `start dm_ui` (e ver o motivo caso falhe).

## 5. No cliente

- O cliente precisa ter o navegador interno ativo: MTA → Configurações → Navegador → **Enable web browser**.
  Sem isso a interface (CEF) não aparece; o jogo avisa no chat e `/uidebug` mostra o estado.
- `/debugscript 3` mostra `[dm_ui] criando browser` → `browser criado` → `documento pronto` quando tudo carregou.

## 6. Atualizar em um clique (sem baixar zip)

Instale uma vez o **Git para Windows** e o **WinSCP**, clone o repositório (`git clone <url-do-repo>`), copie
`deploy\ftp.exemplo.txt` para `deploy\ftp.local.txt` e preencha com usuário, senha, IP e porta do FTP que o
painel mostra. Depois, a cada alteração minha, basta dar **dois cliques em `deploy\deploy.bat`**: ele faz
`git pull` e envia por FTP apenas os arquivos que mudaram dentro de `resources\[dm]` (e apaga na hospedagem o
que saiu do repositório). No fim, no console do painel: `restart dm_ui` (ou o resource alterado) — não
precisa reiniciar o servidor inteiro.

Alternativa manual: WinSCP → conectar no FTP → menu Comandos → **Sincronizar** (local `resources\[dm]` ↔
remoto `/mods/deathmatch/resources/[dm]`, direção "remoto").

## Checklist rápido quando "não funciona"

| Sintoma | Causa provável |
|---------|----------------|
| Nasce no freeroam, sem login/HUD do UTG | `play` ainda ligado e/ou resources do UTG não estão no `mtaserver.conf` |
| Tela preta ao entrar | `dm_login`/`dm_core` não iniciaram (veja o log) |
| "Access denied @ kickPlayer/addAccount" no log | ACL do passo 3 |
| Interface não aparece, chat avisa `[UTG] Interface não carregou` | navegador interno desligado no cliente ou `dm_ui` não iniciou |
| `Loading of resource '[dm]' failed` | o `[dm].zip` ainda está na pasta `resources` |
