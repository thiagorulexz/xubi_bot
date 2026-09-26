-- changelog.lua  ->  raiz do repo xubi_bot (mesma pasta do manifest.json)
--
-- Aparece na caixa de atualizacao do bot, numa area com scroll.
-- Basta editar e dar push: o bot baixa sempre a versao mais nova, nao precisa
-- mexer no manifest nem no xubira.lua.
--
-- Este arquivo tambem pode ser so um texto puro (changelog.txt), ou uma lista
-- (return { "linha", "linha" }). O bot aceita os tres.

return [[
V0.0.7 -- 26/09/2026
Refeita a key de todos os usuarios
Corrigido Spells na Payhunt
Adicionado Outfith Manager
Corrigido falhas internas
Corrigido o Face target no PVP
Corrigido a UI do Event Viewer
Corrigido AutoCombo v_Bot
Corrigido TargetBot Profiles

v0.0.6 -- 25/09/2026
Refeito Icones dos ataques
Corrigido alguns icones reportados 
Adicionado Ant Push
Adicionado Arround Flowers
Adicionado Full Chase
Arrumado Sistema Club Kina

v0.0.5 -- 24/09/2026
Remodelado o sistema de ícones
Ícones faltantes adicionados
Remodelado o sistema de Hotkeys
Hotkeys faltantes adicionadas
Corrigido as Box do [Xubi]: Follow, Status, Atk Leader
Removida box de monstros
Adicionado Atk Leader System
Filtro aba Payhunt

v0.0.4 -- 22/09/26
Removido os erros ERROR: [BOT] Invalid hotkey keys da Mw e Grav
Removido o erro que ao alterar a hotkey de Mw e Grav era necessário reiniciar o bot para ter efeito
Removido o Auto Bless do vBot deixando somente o do XubiBot
Corrigido problema no Force Exura Sio do Druid
Corrigido o Tempo do Exura Gran Ico e Utito Tempo para Knight
Adicionado o Exura gran ico na aba de Cooldowns de Knight
Corrigido bug do Force cast no trainer 
Retirado o Bless system do vBot deixando somente o do XubiBot
Corrigido o problema da bless por dinheiro
Corrigido bug que o exura sio do druid não estava validando de acordo com os valores de Friend Healer
Adicionado Level no Battle List
Corrigido o bug do Look warning error
Corrigido a Backpack Padrão do código 
Corrigido o Hold Target
Criado Enemy Guild Low Level
Corrigido o TargetBroken de Enemy Guild Low Level
Criado um script para usar o Task Scroll sempre que estiver atacando monstro e ela acabar
Corrigido um bug no Friend Healer agora usa UH + Pot 
Foi feito Otimizações no código e arrumados Bugs
Corrigido os erros WARNING: widget '' was not explicitly destroyed

v0.0.3 -- 19/09/26
 - Payhunt: o "correr na sala" voltou a funcionar em perfil novo. A distancia
   dos cantos e o alcance do deslize viraram valores fixos do script, entao
   nao dependem mais do que estava salvo no storage.
 - Perfil por personagem: cada char agora ganha um perfil sozinho no primeiro
   login (1, 2, 3, 4...). Com todos ocupados, abre uma janela pra escolher
   qual substituir.
 - Substituir um perfil zera ele de vez: o storage e as configs do vBot
   daquele perfil sao apagados e quem entra comeca limpo.
 - Carimbos de perfil antigos (xubi_inuse_*) sao apagados sozinhos quando o
   dono muda.
 - Face Target: a hotkey nasce vazia em vez de nil.
 - Exp HUD: nao quebra mais em storage salvo por versao antiga
   ("attempt to get length of field 'samples'").
 - Atualizacao: o bot nao recebe mais arquivo velho do cache do Github (a CDN
   segura por ate 5 minutos). Changelog e versao nova chegam na hora, e sumiu
   o risco de gravar um arquivo desatualizado achando que era o novo.
 - Primeira versao com auto-update.
]]
