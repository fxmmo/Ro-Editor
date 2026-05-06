local cache = {}
local isLoaded = {}
local load = customRequire

local function customRequire(url)
    if type(url) ~= "string" or url:gsub("%s", "") == "" then
        warn("Erro: URL inválida ou vazia fornecida.")
        return nil
    end

    if isLoaded[url] then
        return cache[url]
    end

    local successGet, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not successGet or type(source) ~= "string" then
        warn("Falha ao baixar o script da URL: " .. tostring(source))
        return nil
    end

    local fn, compileError = loadstring(source)
    if not fn then
        warn("Erro de sintaxe no código baixado: " .. tostring(compileError))
        return nil
    end

    local successRun, result = pcall(function()
        return fn()
    end)

    if not successRun then
        warn("Ocorreu um erro durante a execução do script: " .. tostring(result))
        return nil
    end

    isLoaded[url] = true
    cache[url] = result

    return cache[url]
end

return customRequire

