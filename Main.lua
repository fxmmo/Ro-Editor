-- main.lua (versão simplificada)
print("Carregando Explorer.lua...")

local url = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/Explorer.lua"

if game and game:GetService("HttpService") then
    local http = game:GetService("HttpService")
    
    local sucesso, codigo = pcall(function()
        return http:GetAsync(url)
    end)
    
    if sucesso then
        local carregado, erro = loadstring(codigo)
        
        if carregado then
            print("✓ Explorer.lua carregado!")
            local explorer = carregado()
            print("Pronto para usar!")
        else
            warn("❌ Falha ao carregar o código: " .. tostring(erro))
        end
    else
        warn("❌ Falha ao baixar o arquivo: " .. tostring(codigo))
    end
else
    warn("❌ Ambiente Roblox não detectado")
end
