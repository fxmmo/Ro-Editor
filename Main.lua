local HttpService = game:GetService("HttpService")
local url = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/Explorer.lua"

local success, result = pcall(function()
    return HttpService:GetAsync(url)
end)

if success then
    if result then
        local loadstringResult = loadstring(result)
        if loadstringResult then
            loadstringResult()
            print("Explorer.lua carregado e executado com sucesso!")
        else
            warn("Erro ao carregar o código do Explorer.lua com loadstring.")
        end
    else
        warn("Nenhum conteúdo retornado da URL.")
    end
else
    warn("Erro ao obter o código do Explorer.lua: ", result)
end
