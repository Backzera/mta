PACOTE PRONTO — 7 SKINS PERSONALIZADAS PARA MTA:SA
====================================================

ESTE ZIP É UMA VERSÃO ENXUTA: contém somente os 14 arquivos DFF/TXD usados, o meta.xml, o carregador client.lua e a configuração atualizada das caixas.

INSTALAÇÃO NA HOST
1. Pare o servidor MTA antes de substituir arquivos.
2. Extraia o ZIP. Abra a pasta extraída e copie a pasta "mods" para a raiz da instalação do servidor (a pasta que já contém "mods"). Mescle as pastas e substitua o arquivo quando solicitado.
3. Inicie o servidor e, no console, execute:
   refresh
   start dm_skins
   restart dm_core
   restart dm_crates
   Se dm_skins já estiver rodando, use "restart dm_skins".
4. Entre no jogo com uma conta de administrador e use um comando para conceder/equipar a skin:
   /darskin skin_miku
   /darskin skin_sakura_miku
   /darskin skin_zoro
   /darskin skin_luffy
   /darskin skin_usada_pekora
   /darskin skin_tanjiro
   /darskin skin_naruto_bijuu
   Para trocar entre skins já concedidas, pressione F7 e abra "MEU INVENTÁRIO".

SKINS E IDS DE MODELO
298 — Hatsune Miku
299 — Sakura Miku
300 — Roronoa Zoro
301 — Monkey D. Luffy
302 — Usada Pekora
303 — Tanjiro Kamado
304 — Naruto Bijuu

NOTAS IMPORTANTES
- O pacote reserva os IDs 298–304 para essas skins dentro do sistema de caixas. Modelos originais do GTA com esses IDs ficam visualmente substituídos enquanto dm_skins estiver ativo.
- As variantes DFF_Normal de Miku e Sakura foram usadas para evitar carregar os IFPs globais do Modloader, que avisam poder causar problemas em outros personagens.
- Os 14 arquivos DFF/TXD somam aproximadamente 157 MB sem compressão. Os jogadores precisarão baixá-los na primeira conexão. Dependendo da host, upload/download ou limite por arquivo pode demorar.
- O arquivo "skins_generated.lua" é gerado pelo tools/build_skins.py no repositório. A lista de sete personagens também já foi adicionada ao gerador no branch principal para que uma futura regeneração não remova os itens.
