local Create = {}

local function applyProperties(obj, props)
    local deferredParent = props.Parent
    
    for prop, value in pairs(props) do
        if prop == "Children" then
            for _, child in ipairs(value) do
                child.Parent = obj
            end
        elseif prop ~= "Parent" then
            local success, err = pcall(function()
                obj[prop] = value
            end)
            if not success then
                warn(string.format("[Create]: Erro ao definir %s em %s: %s", prop, obj.ClassName, err))
            end
        end
    end
    
    if deferredParent then
        obj.Parent = deferredParent
    end
end

setmetatable(Create, {
    __index = function(_, className)
        return function(props)
            local obj = Instance.new(className)
            if props then
                applyProperties(obj, props)
            end
            return obj
        end
    end
})

return Create