local module = {}
local _cameraCache = {}

local function ensureFolder()
local folder = workspace:FindFirstChild("cams_folder")
if not folder then
folder = Instance.new("Folder")
folder.Name = "cams_folder"
folder.Parent = workspace
end
return folder
end

function module.createCam(props)
if not props or not props.Name then
return nil
end
if _cameraCache[props.Name] then
return _cameraCache[props.Name]
end
local folder = ensureFolder()
local parent = props.Parent or folder
local part = Instance.new("Part")
part.Name = props.Name
part.Anchored = true
part.CanCollide = false
part.Transparency = 1
part.Size = Vector3.new(0.5, 0.5, 0.5)
part.CFrame = props.CFrame or CFrame.new()
part.Parent = parent
_cameraCache[props.Name] = part
return part
end

function module.setCFrame(part, cframe)
if part and part.Parent and cframe then
part.CFrame = cframe
end
end

function module.sync(part)
if part and part.Parent then
part.CFrame = part.CFrame
end
end

function module.getCFrame(entry)
if entry and entry.Parent then
return entry.CFrame
end
return nil
end

function module.get(name)
return _cameraCache[name]
end

function module.getAll()
return _cameraCache
end

function module.destroy(name)
local part = _cameraCache[name]
if part then
if part.Parent then
part:Destroy()
end
_cameraCache[name] = nil
end
end

function module.clear()
for name in pairs(_cameraCache) do
module.destroy(name)
end
end

return module
