-- changelog.lua  ->  raiz do repo xubi_bot (mesma pasta do manifest.json)
--
-- Aparece na caixa de atualizacao do bot, numa area com scroll.
-- Basta editar e dar push: o bot baixa sempre a versao mais nova, nao precisa
-- mexer no manifest nem no xubira.lua.
--
-- Este arquivo tambem pode ser so um texto puro (changelog.txt), ou uma lista
-- (return { "linha", "linha" }). O bot aceita os tres.

return [[
v1.4.3
 - Payhunt: o "correr na sala" voltou a funcionar em perfil novo. A distancia
   dos cantos e o alcance do deslize viraram valores fixos do script, entao
   nao dependem mais do que estava salvo no storage.
 - Perfil por personagem: cada char agora ganha um perfil sozinho no primeiro
   login (1, 2, 3, 4...). Com todos ocupados, abre uma janela pra escolher
   qual substituir.
 - Substituir um perfil zera ele: quem entra comeca limpo. O storage antigo
   fica guardado em profile_<n>.replaced.json, por seguranca.
 - Carimbos de perfil antigos (xubi_inuse_*) sao apagados sozinhos quando o
   dono muda.

v1.4.2
 - Face Target: a hotkey nasce vazia em vez de nil.
 - Exp HUD: nao quebra mais em storage salvo por versao antiga
   ("attempt to get length of field 'samples'").

v1.4.1
 - Primeira versao com auto-update.
]]
