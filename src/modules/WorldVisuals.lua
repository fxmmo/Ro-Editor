local Dev = _G.__RoEditorDev
if not Dev then
	local _cache = {}
	Dev = {}
	function Dev:Import(url)
		if _cache[url] then
			return _cache[url]
		end
		local ok, result = pcall(function()
			local source = game:HttpGet(url, true)
			local chunk, compileError = loadstring(source)
			if not chunk then
				error(compileError or "compile failed")
			end
			return chunk()
		end)
		if not ok then
			error(result)
		end
		if not result then
			error("module returned nil: " .. url)
		end
		_cache[url] = result
		return result
	end
	_G.__RoEditorDev = Dev
end
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local module = {}
module.__index = module

local DIRECTION_LENGTH = 2.4

local function keyFor(time)
	return string.format("%.6f", tonumber(time) or 0)
end

local function destroyChildren(parent)
	if not parent then return end
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

function module.new()
	local self = setmetatable({}, module)
	self.folder = Instance.new("Folder")
	self.folder.Name = "RoEditorWorldVisuals"
	self.folder.Parent = workspace
	self.cameraMarkers = {}
	self.paths = {}
	self.visible = true
	return self
end

function module:_createMarker(entry)
	if not entry or not entry.name or not entry.part then return nil end
	self:removeCamera(entry.name)
	local marker = Instance.new("Part")
	marker.Name = entry.name .. "_Marker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Shape = Enum.PartType.Block
	marker.Material = Enum.Material.Neon
	marker.Color = Theme.Accent
	marker.Size = Vector3.new(0.9, 0.9, 0.9)
	marker.CFrame = entry.part.CFrame
	marker.Transparency = self.visible and 0.08 or 1
	marker.Parent = self.folder

	local directionFrame = Instance.new("Part")
	directionFrame.Name = entry.name .. "_DirectionFrame"
	directionFrame.Anchored = true
	directionFrame.CanCollide = false
	directionFrame.CanTouch = false
	directionFrame.CanQuery = false
	directionFrame.CastShadow = false
	directionFrame.Shape = Enum.PartType.Block
	directionFrame.Material = Enum.Material.Neon
	directionFrame.Color = Theme.Success or Theme.Accent
	directionFrame.Size = Vector3.new(2.7, 2.2, 0.07)
	directionFrame.CFrame = entry.part.CFrame * CFrame.new(0, 0, -DIRECTION_LENGTH)
	directionFrame.Transparency = self.visible and 0.3 or 1
	directionFrame.Parent = self.folder

	local startOffsets = {
		Vector3.new(-0.45, -0.45, -0.45),
		Vector3.new(0.45, -0.45, -0.45),
		Vector3.new(0.45, 0.45, -0.45),
		Vector3.new(-0.45, 0.45, -0.45),
	}
	local endOffsets = {
		Vector3.new(-1.35, -1.1, 0),
		Vector3.new(1.35, -1.1, 0),
		Vector3.new(1.35, 1.1, 0),
		Vector3.new(-1.35, 1.1, 0),
	}
	local directionBeams = {}
	for index = 1, #startOffsets do
		local directionStart = Instance.new("Attachment")
		directionStart.Name = "DirectionStart_" .. index
		directionStart.Position = startOffsets[index]
		directionStart.Parent = marker
		local directionEnd = Instance.new("Attachment")
		directionEnd.Name = "DirectionEnd_" .. index
		directionEnd.Position = endOffsets[index]
		directionEnd.Parent = directionFrame
		local directionBeam = Instance.new("Beam")
		directionBeam.Name = "CameraDirection_" .. index
		directionBeam.Attachment0 = directionStart
		directionBeam.Attachment1 = directionEnd
		directionBeam.Color = ColorSequence.new(Theme.Success or Theme.Accent)
		directionBeam.Transparency = NumberSequence.new(0.12)
		directionBeam.Width0 = 0.055
		directionBeam.Width1 = 0.035
		directionBeam.FaceCamera = true
		directionBeam.LightEmission = 0.8
		directionBeam.Enabled = self.visible
		directionBeam.Parent = marker
		table.insert(directionBeams, directionBeam)
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "CameraHighlight"
	highlight.Adornee = marker
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Theme.Accent
	highlight.FillTransparency = self.visible and 0.45 or 1
	highlight.OutlineColor = Theme.Text
	highlight.OutlineTransparency = self.visible and 0 or 1
	highlight.Enabled = self.visible
	highlight.Parent = marker

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CameraLabel"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Size = UDim2.new(0, 120, 0, 24)
	billboard.StudsOffset = Vector3.new(0, 1.1, 0)
	billboard.Enabled = self.visible
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.Text = entry.name
	label.TextColor3 = Theme.Text
	label.TextSize = 12
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	self.cameraMarkers[entry.name] = {
		entry = entry,
		marker = marker,
		directionFrame = directionFrame,
		directionBeams = directionBeams,
		highlight = highlight,
		billboard = billboard,
	}
	return self.cameraMarkers[entry.name]
end

function module:addCamera(entry)
	return self:_createMarker(entry)
end

function module:renameCamera(oldName, newName, entry)
	if oldName == newName then return end
	local markerRecord = self.cameraMarkers[oldName]
	if markerRecord then
		self.cameraMarkers[oldName] = nil
		self.cameraMarkers[newName] = markerRecord
		markerRecord.entry = entry or markerRecord.entry
					if markerRecord.marker then
				markerRecord.marker.Name = newName .. "_Marker"
			end
			if markerRecord.directionFrame then
				markerRecord.directionFrame.Name = newName .. "_DirectionFrame"
			end

		if markerRecord.billboard then
			local label = markerRecord.billboard:FindFirstChild("Text")
			if label then
				label.Text = newName
			end
		end
	end
	local path = self.paths[oldName]
	if path then
		self.paths[oldName] = nil
		self.paths[newName] = path
		if path.folder then
			path.folder.Name = newName .. "_Path"
		end
	end
end

function module:removeCamera(cameraName)
	local record = self.cameraMarkers[cameraName]
	if record and record.directionFrame then
		record.directionFrame:Destroy()
	end
	if record and record.marker then
		record.marker:Destroy()
	end
	self.cameraMarkers[cameraName] = nil
	self:removePath(cameraName)
end

function module:_getPath(cameraName)
	local path = self.paths[cameraName]
	if path and path.folder and path.folder.Parent then
		return path
	end
	local folder = Instance.new("Folder")
	folder.Name = cameraName .. "_Path"
	folder.Parent = self.folder
	path = {folder = folder, nodes = {}, beams = {}}
	self.paths[cameraName] = path
	return path
end

function module:_createNode(path, data)
	local node = Instance.new("Part")
	node.Name = "Keyframe_" .. keyFor(data.time)
	node.Anchored = true
	node.CanCollide = false
	node.CanTouch = false
	node.CanQuery = false
	node.CastShadow = false
	node.Shape = Enum.PartType.Ball
	node.Material = Enum.Material.Neon
	node.Color = Theme.Keyframe
	node.Size = Vector3.new(0.32, 0.32, 0.32)
	node.CFrame = data.cframe or CFrame.new(data.position or Vector3.zero)
	node.Transparency = self.visible and 0.1 or 1
	node.Parent = path.folder
	local attachment = Instance.new("Attachment")
	attachment.Name = "PathAttachment"
	attachment.Parent = node
	return {data = data, node = node, attachment = attachment}
end

function module:_rebuildBeams(path)
	for _, beam in ipairs(path.beams) do
		if beam and beam.Parent then
			beam:Destroy()
		end
	end
	path.beams = {}
	local nodes = {}
	for _, record in pairs(path.nodes) do
		table.insert(nodes, record)
	end
	table.sort(nodes, function(a, b)
		return (a.data.time or 0) < (b.data.time or 0)
	end)
	for index = 1, #nodes - 1 do
		local beam = Instance.new("Beam")
		beam.Name = "Segment_" .. index
		beam.Attachment0 = nodes[index].attachment
		beam.Attachment1 = nodes[index + 1].attachment
		beam.Color = ColorSequence.new(Theme.Keyframe)
		beam.FaceCamera = true
		beam.LightEmission = 0.7
		beam.Segments = 8
		beam.Width0 = 0.12
		beam.Width1 = 0.12
		beam.Enabled = self.visible
		beam.Parent = path.folder
		table.insert(path.beams, beam)
	end
end

function module:setKeyframes(cameraName, keyframes)
	local path = self:_getPath(cameraName)
	destroyChildren(path.folder)
	path.nodes = {}
	path.beams = {}
	for _, data in ipairs(keyframes or {}) do
		path.nodes[keyFor(data.time)] = self:_createNode(path, data)
	end
	self:_rebuildBeams(path)
end

function module:updateKeyframe(cameraName, data)
	if not data then return end
	local path = self:_getPath(cameraName)
	local record = path.nodes[keyFor(data.time)]
	if record and record.node then
		record.data = data
		record.node.CFrame = data.cframe or CFrame.new(data.position or Vector3.zero)
	else
		path.nodes[keyFor(data.time)] = self:_createNode(path, data)
		self:_rebuildBeams(path)
	end
end

function module:removeKeyframe(cameraName, time)
	local path = self.paths[cameraName]
	if not path then return end
	local record = path.nodes[keyFor(time)]
	if record and record.node then
		record.node:Destroy()
	end
	path.nodes[keyFor(time)] = nil
	self:_rebuildBeams(path)
end

function module:removePath(cameraName)
	local path = self.paths[cameraName]
	if path and path.folder then
		path.folder:Destroy()
	end
	self.paths[cameraName] = nil
end

function module:setVisible(visible)
	self.visible = visible and true or false
	for _, record in pairs(self.cameraMarkers) do
		if record.marker then record.marker.Transparency = self.visible and 0.08 or 1 end
		if record.directionFrame then record.directionFrame.Transparency = self.visible and 0.3 or 1 end
		for _, beam in ipairs(record.directionBeams or {}) do
			if beam then beam.Enabled = self.visible end
		end
		if record.highlight then
			record.highlight.Enabled = self.visible
			record.highlight.FillTransparency = self.visible and 0.45 or 1
			record.highlight.OutlineTransparency = self.visible and 0 or 1
		end
		if record.billboard then record.billboard.Enabled = self.visible end
	end
	for _, path in pairs(self.paths) do
		for _, record in pairs(path.nodes) do
			if record.node then record.node.Transparency = self.visible and 0.1 or 1 end
		end
		for _, beam in ipairs(path.beams) do
			if beam then beam.Enabled = self.visible end
		end
	end
end

function module:sync()
	for _, record in pairs(self.cameraMarkers) do
		if record.entry and record.entry.part and record.marker and record.marker.Parent then
			record.marker.CFrame = record.entry.part.CFrame
			if record.directionFrame and record.directionFrame.Parent then
				record.directionFrame.CFrame = record.entry.part.CFrame * CFrame.new(0, 0, -DIRECTION_LENGTH)
			end
		end
	end
end

function module:destroy()
	if self.folder then
		self.folder:Destroy()
	end
	self.cameraMarkers = {}
	self.paths = {}
end

return module
