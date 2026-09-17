--------------------------------------------------------------------
-- XUBI BOT - AUTO UPDATE (modulo standalone, so pra TESTE por enquanto)
--------------------------------------------------------------------
-- Ideia: ao ligar, o bot busca um "manifest.json" no Github (raw) com a
-- versao mais recente + lista de arquivos daquela versao. Se a versao
-- local estiver desatualizada, baixa TODOS os arquivos do manifest, e so
-- entra no bot quando a versao local == versao do manifest. Se alguma
-- etapa falhar (rede, arquivo corrompido, etc.) ele refaz o processo
-- inteiro (nao fica com update pela metade).
--
-- Formato esperado do manifest.json (hospedado no seu repo Github):
-- {
--   "version": "1.0.1",
--   "files": [
--     { "path": "/xubira.lua",        "url": "https://raw.githubusercontent.com/USUARIO/REPO/main/xubira.lua" },
--     { "path": "/payhunt_andar.lua", "url": "https://raw.githubusercontent.com/USUARIO/REPO/main/payhunt_andar.lua" }
--   ]
-- }
--
-- "path" = onde o arquivo vai ser gravado dentro da pasta de dados do
--          client (g_resources), sempre comecando com "/".
-- "url"  = link RAW do Github pra baixar o conteudo daquele arquivo
--          (espaco no nome do arquivo tem que virar %20 na url).
--
-- Esse arquivo nao muda nada no "xubira - bk.lua" ainda -- e so pra
-- validar a logica sozinha. Cole ele no console/editor do client pra
-- testar (depois de trocar MANIFEST_URL por um manifest.json de teste
-- no seu Github).
--------------------------------------------------------------------

local XubiUpdate = {}

--------------------------------------------------
-- CONFIG
--------------------------------------------------
XubiUpdate.VERSION       = "1.0.0"  -- versao "instalada" deste bot (bump isso a cada release)
XubiUpdate.MANIFEST_URL  = "https://raw.githubusercontent.com/thiagorulexz/xubi_bot/refs/heads/main/manifest.json"
XubiUpdate.MAX_RETRIES   = 3        -- tentativas por arquivo/manifest antes de desistir do ciclo
XubiUpdate.RETRY_DELAY_MS = 4000    -- espera entre tentativas
XubiUpdate.MAX_CYCLES    = 5        -- quantas vezes repete "checa -> atualiza -> confere de novo"
XubiUpdate.FAIL_OPEN     = true     -- se true: nao conseguindo falar com o Github, entra com a versao local mesmo assim

--------------------------------------------------
-- HELPERS
--------------------------------------------------
local loadFn = loadstring or load

local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil, a
end

local function log(msg)
    print("[XUBI UPDATE] " .. tostring(msg))
end

-- "1.4.2" -> {1,4,2}
local function parseVersion(v)
    local parts = {}
    for n in tostring(v or ""):gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    return parts
end

-- 1 se a>b, -1 se a<b, 0 se igual
local function compareVersions(a, b)
    local pa, pb = parseVersion(a), parseVersion(b)
    local len = math.max(#pa, #pb)
    for i = 1, len do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return (x > y) and 1 or -1 end
    end
    return 0
end

-- confere se o conteudo baixado e utilizavel antes de gravar no disco.
-- arquivo .lua: precisa compilar (pega download truncado/corrompido).
-- outros arquivos: so exige que nao venha vazio.
local function looksValid(path, content)
    if type(content) ~= "string" or content == "" then return false end
    if not tostring(path):lower():match("%.lua$") then return true end
    if type(loadFn) ~= "function" then return true end -- sem como validar, deixa passar
    local chunk, err = loadFn(content, "=xubi-update:" .. tostring(path))
    if not chunk then
        log("arquivo invalido (nao compilou): " .. tostring(path) .. " -> " .. tostring(err))
        return false
    end
    return true
end

local function envReady()
    if type(HTTP) ~= "table" or type(HTTP.get) ~= "function" then
        log("HTTP.get indisponivel neste ambiente.")
        return false
    end
    if type(g_resources) ~= "table" or type(g_resources.writeFileContents) ~= "function" then
        log("g_resources indisponivel neste ambiente.")
        return false
    end
    if type(json) ~= "table" or type(json.decode) ~= "function" then
        log("json.decode indisponivel neste ambiente.")
        return false
    end
    return true
end

local function delay(ms, fn)
    if type(scheduleEvent) == "function" then
        scheduleEvent(fn, ms)
    else
        fn() -- sem timer disponivel: roda na hora (so pra nao travar o teste)
    end
end

--------------------------------------------------
-- DOWNLOAD DE 1 ARQUIVO, COM RETRY
--------------------------------------------------
local function downloadFile(fileEntry, attemptsLeft, onDone)
    HTTP.get(fileEntry.url, function(data, err)
        local ok = not err and looksValid(fileEntry.path, data)
        if ok then
            onDone(true, data)
            return
        end

        attemptsLeft = attemptsLeft - 1
        if attemptsLeft <= 0 then
            log("desisti de " .. tostring(fileEntry.path) .. " (" .. tostring(err) .. ")")
            onDone(false, nil)
            return
        end

        log("falha em " .. tostring(fileEntry.path) .. ", tentando de novo (" .. attemptsLeft .. " restante(s))")
        delay(XubiUpdate.RETRY_DELAY_MS, function()
            downloadFile(fileEntry, attemptsLeft, onDone)
        end)
    end)
end

-- baixa a lista inteira, um arquivo por vez. So chama onDone(true, ...)
-- se TODOS baixarem certo -- nunca grava update pela metade.
local function downloadAll(files, onDone)
    local downloaded = {}
    local i = 0

    local function advance()
        i = i + 1
        local entry = files[i]
        if not entry then
            onDone(true, downloaded)
            return
        end
        if type(entry.path) ~= "string" or type(entry.url) ~= "string" then
            log("entrada invalida no manifest (indice " .. i .. "), pulando update.")
            onDone(false, nil)
            return
        end
        downloadFile(entry, XubiUpdate.MAX_RETRIES, function(ok, data)
            if not ok then
                onDone(false, nil)
                return
            end
            downloaded[#downloaded + 1] = { path = entry.path, data = data }
            advance()
        end)
    end

    advance()
end

local function writeAll(files)
    for _, f in ipairs(files) do
        local dir = f.path:match("^(.*)/[^/]+$")
        if dir and dir ~= "" and not g_resources.directoryExists(dir) then
            safe(function() g_resources.makeDir(dir) end)
        end
        local wroteOk = safe(function()
            g_resources.writeFileContents(f.path, f.data)
            return true
        end)
        log((wroteOk and "atualizado: " or "FALHOU AO GRAVAR: ") .. f.path)
    end
end

--------------------------------------------------
-- 1 CICLO: busca manifest -> compara versao -> baixa se precisar
--------------------------------------------------
-- onUpToDate()               : versao local ja bate com a do manifest
-- onUpdated(novaVersao)      : baixou e gravou tudo, mas precisa reconferir
-- onFailed(motivo)           : nao deu pra concluir este ciclo
function XubiUpdate.checkOnce(onUpToDate, onUpdated, onFailed)
    local function tryManifest(attemptsLeft)
        HTTP.get(XubiUpdate.MANIFEST_URL, function(data, err)
            if err or not data or data == "" then
                attemptsLeft = attemptsLeft - 1
                if attemptsLeft > 0 then
                    delay(XubiUpdate.RETRY_DELAY_MS, function() tryManifest(attemptsLeft) end)
                    return
                end
                if XubiUpdate.FAIL_OPEN then
                    log("nao consegui falar com o Github; seguindo com a versao local (" .. XubiUpdate.VERSION .. ").")
                    onUpToDate()
                else
                    onFailed("sem resposta do manifest")
                end
                return
            end

            local ok, manifest = pcall(json.decode, data)
            if not ok or type(manifest) ~= "table" or type(manifest.version) ~= "string" or type(manifest.files) ~= "table" then
                onFailed("manifest.json invalido")
                return
            end

            if compareVersions(manifest.version, XubiUpdate.VERSION) <= 0 then
                onUpToDate()
                return
            end

            log("versao nova disponivel: " .. manifest.version .. " (local: " .. XubiUpdate.VERSION .. ")")
            downloadAll(manifest.files, function(ok2, downloaded)
                if not ok2 then
                    onFailed("falha ao baixar os arquivos do update")
                    return
                end
                writeAll(downloaded)
                XubiUpdate.VERSION = manifest.version -- so pra essa sessao nao ficar re-baixando em loop
                onUpdated(manifest.version)
            end)
        end)
    end

    tryManifest(XubiUpdate.MAX_RETRIES)
end

-- depois de gravar os arquivos novos no disco, forca o client a recarregar
-- o script (reload() ja existe no xubira - bk.lua e e usado nesse mesmo
-- sentido -- ex.: apos trocar de vocacao). A proxima execucao le os
-- arquivos JA atualizados do disco e cai direto no onUpToDate().
local function forceReload(novaVersao)
    log("atualizado para " .. tostring(novaVersao) .. " -- forcando reload()...")
    if type(reload) == "function" then
        local ok, err = safe(reload)
        if not ok then
            log("reload() falhou (" .. tostring(err) .. "); o update ja esta gravado no disco, mas precisa reabrir o bot manualmente.")
        end
        -- se reload() funcionar, o script inteiro reinicia aqui -- nada
        -- depois disso deve rodar nesta execucao.
        return true
    end
    log("reload() indisponivel neste ambiente; grava no disco mas nao consegue reiniciar sozinho.")
    return false
end

--------------------------------------------------
-- ORQUESTRADOR
--------------------------------------------------
-- onReady()          : versao ja bate, pode entrar no bot normalmente
-- onBlocked(motivo)  : nao foi possivel garantir a versao certa; NAO entra no bot
function XubiUpdate.run(onReady, onBlocked)
    if not envReady() then
        onBlocked("ambiente sem HTTP/g_resources/json")
        return
    end

    local cycle = 0
    local function step()
        cycle = cycle + 1
        if cycle > XubiUpdate.MAX_CYCLES then
            log("update nao convergiu depois de " .. XubiUpdate.MAX_CYCLES .. " ciclos.")
            if XubiUpdate.FAIL_OPEN then
                onReady()
            else
                onBlocked("update nao convergiu")
            end
            return
        end

        XubiUpdate.checkOnce(
            onReady,
            function(novaVersao)
                -- update gravado com sucesso: a forma "normal" de continuar
                -- e reiniciar o script (reload), nao seguir rodando o
                -- codigo antigo que ja estava carregado nesta sessao.
                if not forceReload(novaVersao) then
                    -- sem reload() disponivel: cai pro fallback de reconferir
                    -- na mesma sessao (menos ideal, mas nao trava o login).
                    step()
                end
            end,
            function(motivo)
                log("ciclo de update falhou (" .. motivo .. "), refazendo em " .. XubiUpdate.RETRY_DELAY_MS .. "ms...")
                delay(XubiUpdate.RETRY_DELAY_MS, step)
            end
        )
    end

    step()
end

--------------------------------------------------
-- TESTE MANUAL: cole este arquivo no editor/console do client depois
-- de trocar MANIFEST_URL por um manifest.json real no seu Github.
--------------------------------------------------
XubiUpdate.run(
    function()
        log("versao OK (" .. XubiUpdate.VERSION .. ") -> entraria no bot agora.")
    end,
    function(motivo)
        log("BLOQUEADO: " .. tostring(motivo))
    end
)

return XubiUpdate
