local cache = {}
local isLoaded = {}

local BASE_URL = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/studio/"

local function resolvePath(path)
    if path:match("^https?://") then
        return path
    end

    if path:sub(1, 2) == "./" then
        path = path:sub(3)
    end

    return BASE_URL .. path
end

local function customRequire(path)
    if type(path) ~= "string" or path:match("^%s*$") then
        warn("Erro: caminho inválido.")
        return nil
    end

    local url = resolvePath(path)

    -- loop protection
    if isLoaded[url] == "loading" then
        error("Loop de require detectado: " .. url)
    end

    if isLoaded[url] then
        return cache[url]
    end

    isLoaded[url] = "loading"
    cache[url] = {}

    local successGet, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not successGet or type(source) ~= "string" then
        warn("Falha ao baixar:", url)
        return nil
    end

    local fn, compileError = loadstring(source)
    if not fn then
        warn("Erro de sintaxe:", compileError)
        return nil
    end

    local successRun, result = pcall(fn)

    if not successRun then
        warn("Erro ao executar:", result)
        return nil
    end

    cache[url] = result
    isLoaded[url] = true

    return result
end

return customRequire