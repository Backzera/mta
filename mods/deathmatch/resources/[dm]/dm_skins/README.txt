PACOTE DM SKINS — MTA:SA

Conteúdo: 5 personagens personalizados carregados pelo recurso dm_skins e itens registrados no inventário de caixas.

INSTALAÇÃO
1. Faça backup de:
   mods/deathmatch/resources/[dm]/dm_skins/
   mods/deathmatch/resources/[dm]/dm_core/shared/skins_generated.lua
2. Extraia este ZIP na raiz da pasta do servidor MTA (a pasta que contém "mods").
   Quando o Windows perguntar se deseja mesclar/substituir, mantenha a estrutura de pastas.
3. No console do servidor, execute:
   refresh
   start dm_skins
   restart dm_core
   restart dm_crates
   Se dm_skins já estiver iniciado, use "restart dm_skins" em vez de "start dm_skins".
4. Para testar como administrador, use um destes comandos no chat:
   /darskin skin_miku
   /darskin skin_sakura_miku
   /darskin skin_zoro
   /darskin skin_luffy
   /darskin skin_tanjiro
   O comando concede o item e equipa a skin. Para mudar depois, abra o inventário com F7.

MAPA DOS IDS
298 — Hatsune Miku
299 — Sakura Miku
300 — Roronoa Zoro
301 — Monkey D. Luffy
303 — Tanjiro Kamado

OBSERVAÇÕES
- IDs 298, 299, 300, 301 e 303 foram reservados para estes itens dentro da configuração do projeto. Modelos base do GTA com esses mesmos IDs são substituídos visualmente enquanto dm_skins estiver carregado.
- Miku e Sakura usam as versões DFF_Normal; os IFP extras do Modloader não são carregados, para evitar substituir animações gerais do personagem.
- As sete texturas são grandes. Os clientes poderão baixar aproximadamente 157 MB de arquivos na primeira conexão.
- Este pacote altera o arquivo gerado skins_generated.lua para registrar os novos itens e pesos das caixas.
