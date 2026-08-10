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

	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.CFrame = part.CFrame
	camera.FieldOfView = props.FieldOfView or 70
	camera.Parent = part

	for key, value in pairs(props) do
		if key ~= "Name" and key ~= "CFrame" and key \~= "Parent" and key \~= "FieldOfView" then
			pcall(function()
				camera[key] = value
			end)
		end
	end

	_cameraCache[props.Name] = {
		part = part,
		camera = camera,
		name = props.Name
	}

	return _cameraCache[props.Name]
end

function module.get(name)
	return _cameraCache[name]
end

function module.getAll()
	return _cameraCache
end

function module.destroy(name)
	local entry = _cameraCache[name]
	if entry then
		if entry.part and entry.part.Parent then
			entry.part:Destroy()
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