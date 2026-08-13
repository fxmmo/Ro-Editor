local Dev = _G.__RoEditorDev
if not Dev then
	local _cache = {}
	Dev = {}
	function Dev:Import(url)
		if _cache[url] then
			return _cache[url]
		end
		local ok, result = pcall(function()
			return loadstring(game:HttpGet(url))()
		end)
		if ok and result then
			_cache[url] = result
			return result
		end
		return nil
	end
	_G.__RoEditorDev = Dev
end
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Icons = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Icon_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local CameraResolver = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/CameraResolver.lua") or error("[Ro-Editor] import failed")
local WorldVisuals = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/WorldVisuals.lua") or error("[Ro-Editor] import failed")
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local _nextCamId = 1
local EPSILON = 1e-4
local easingFunctions = {
	Linear = function(alpha) return alpha end,
	EaseIn = function(alpha) return alpha * alpha end,
	EaseOut = function(alpha) return 1 - (1 - alpha) * (1 - alpha) end,
	EaseInOut = function(alpha)
		if alpha < 0.5 then
			return 2 * alpha * alpha
		end
		return 1 - ((-2 * alpha + 2) ^ 2) / 2
	end,
}

local module = {}
module.__index = module

function module.new(interface, store, handles)
	local self = setmetatable({}, module)
	self.ui = interface
	self.store = store
	self.handles = handles
	self.isPlaying = false
	self.currentTime = 0
	self.isDraggingPlayhead = false
	self.isDraggingKeyframe = false
	self.editMode = false
	self.editTool = "move"
	self.cameraMode = false
	self.lastCam = nil
	self.playerCamera = workspace.CurrentCamera
	self.cameraLock = nil
	self.tweenConnection = nil
	self.visuals = WorldVisuals.new()
	self.storeByCamera = {}
	self.connections = {}
	self.ui.onTrackSelected = function(cameraName)
		self:selectCamera(cameraName)
	end
	self.ui.onKeyframeSelected = function(cameraName, data)
		self:selectKeyframe(cameraName, data)
	end
	self.ui.onKeyframePressStarted = function()
		self.isDraggingPlayhead = false
	end
	self.ui.onKeyframeDragStarted = function(cameraName, data)
		self:beginKeyframeDrag(cameraName, data)
	end
	self.ui.onKeyframeDragged = function(cameraName, data, targetTime)
		return self:moveKeyframe(cameraName, data, targetTime)
	end
	self.ui.onKeyframeDragEnded = function(cameraName, data)
		self:endKeyframeDrag(cameraName, data)
	end
	self.ui.onPropertiesSubmitted = function(values)
		self:applySelectedKeyframeProperties(values)
	end
	self.ui.onPrevKeyframe = function()
		self:prevKeyframe()
	end
	self.ui.onNextKeyframe = function()
		self:nextKeyframe()
	end
	self.ui.onTrackPropertiesRequested = function(cameraName, absolutePosition)
		self:selectCamera(cameraName)
		local store = self:storeFor(cameraName)
		self.ui:openTrackProperties(cameraName, absolutePosition, store.metadata)
	end
	self.ui.onTrackPropertiesSubmitted = function(cameraName, values)
		self:applyTrackProperties(cameraName, values)
	end
	self.handles.onChanged = function()
		self:updateSelectedKeyframe()
	end
	self.handles.onDragStateChanged = function(dragging)
		self:_setPlayerCameraLocked(dragging)
	end
	self.handles:show(false)
	self:setupButtons()
	self:setupTimelineInput()
	self:setupModeButtons()
	self.connections.CharacterAdded = Players.LocalPlayer.CharacterAdded:Connect(function(character)
		task.defer(function()
			Players.LocalPlayer:WaitForChild("PlayerGui", 5)
			if character and character.Parent then
				character:WaitForChild("Humanoid", 5)
			end
			self.cameraLock = nil
			if self.handles.isDragging then
				self.handles:stopDrag()
			end
			if not self.cameraMode then
				self:_restorePlayerCamera()
			end
			self.ui:setEditTool(self.editTool)
			local entry = self:activeCam()
			if self.editMode and entry then
				self.handles:setMode(self.editTool)
				self.handles:setTarget(entry.part)
				self.handles:show(true)
			else
				self.handles:show(false)
			end
		end)
	end)
	self:startLoop()
	return self
end

function module:activeCam()
	if not self.lastCam or not self.lastCam.name then return nil end
	return CameraResolver.get(self.lastCam.name)
end

function module:storeFor(cameraName)
	if not self.storeByCamera[cameraName] then
		self.storeByCamera[cameraName] = setmetatable({
			keyframes = {},
			selected = nil,
			metadata = {
				speedMultiplier = 1,
				easing = "EaseInOut",
			},
		}, {__index = self.store})
	end
	local store = self.storeByCamera[cameraName]
	store.metadata = store.metadata or {
		speedMultiplier = 1,
		easing = "EaseInOut",
	}
	return store
end

function module:applyTrackProperties(cameraName, values)
	if not cameraName or not values then return end
	local entry = CameraResolver.get(cameraName)
	if not entry then return end
	local store = self:storeFor(cameraName)
	store.metadata.speedMultiplier = values.speedMultiplier
	store.metadata.easing = values.easing or store.metadata.easing or "EaseInOut"
	local newName = values.name
	if newName ~= cameraName then
		local renamed = self:renameCamera(cameraName, newName)
		if not renamed then return end
		cameraName = newName
	end
	self.ui:closeTrackProperties()
end

function module:renameCamera(oldName, newName)
	if not oldName or not newName or newName == "" then return nil end
	if oldName == newName then return CameraResolver.get(oldName) end
	if CameraResolver.get(newName) then return nil end
	local entry = CameraResolver.get(oldName)
	if not entry or not entry.part then return nil end
	local cframe = entry.part.CFrame
	local fieldOfView = entry.camera and entry.camera.FieldOfView or 70
	local parent = entry.part.Parent
	local wasCameraMode = self.cameraMode
	if wasCameraMode then
		self.cameraMode = false
		self.ui:setViewToggle(false)
		self:_restorePlayerCamera()
	end
	self:_setPlayerCameraLocked(false)
	if self.tweenConnection then
		self.tweenConnection:Disconnect()
		self.tweenConnection = nil
	end
	CameraResolver.destroy(oldName)
	local renamed = CameraResolver.createCam({
		Name = newName,
		CFrame = cframe,
		FieldOfView = fieldOfView,
		Parent = parent,
	})
	if not renamed then return nil end
	local store = self.storeByCamera[oldName]
	self.storeByCamera[oldName] = nil
	if store then
		self.storeByCamera[newName] = store
		for _, keyframe in ipairs(store.keyframes) do
			keyframe.cameraName = newName
		end
	end
	self.visuals:renameCamera(oldName, newName, renamed)
	self.ui:updateTrackName(oldName, newName)
	if store and store:getSelected() then
		self.ui:setKeyframeProperties(store:getSelected())
	end
	self.lastCam = renamed
	if self.editMode then
		self.handles:setMode(self.editTool)
		self.handles:setTarget(renamed.part)
		self.handles:show(true)
	end
	if wasCameraMode then
		self.cameraMode = true
		self.ui:setViewToggle(true)
		self:_applyCameraMode()
	end
	return renamed
end

function module:setupModeButtons()
	self.ui.editButton.MouseButton1Click:Connect(function()
		local open = self.ui:toggleEditSection()
		if not open then
			self:setEditMode(nil)
		end
	end)
	self.ui.onEditToolSelected = function(mode)
		self:setEditMode(mode)
		self.ui:closeCamerasModal()
	end
	self.ui.addCamButton.MouseButton1Click:Connect(function()
		self:addCamera()
		self.ui:closeCamerasModal()
	end)
	self.ui.deleteCamButton.MouseButton1Click:Connect(function()
		if self:deleteCamera() then
			self.ui:closeCamerasModal()
		end
	end)
	self.ui:setViewToggle(false, function(on)
		self.cameraMode = on and true or false
		self:_applyCameraMode()
	end)
	local viewRow = self.ui.viewToggle.row
	viewRow.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self.ui:setViewToggle(not self.ui.viewToggle.on)
			if self.ui.viewToggle.callback then
				self.ui.viewToggle.callback(self.ui.viewToggle.on)
			end
		end
	end)
end

function module:addCamera()
	local name
	repeat
		name = "cam_" .. _nextCamId
		_nextCamId += 1
	until not CameraResolver.get(name)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local spawnCFrame = root and (root.CFrame * CFrame.new(0, 1, -5)) or CFrame.new(0, 5, 10)
	local camData = CameraResolver.createCam({
		Name = name,
		CFrame = spawnCFrame,
		FieldOfView = 70,
	})

	if not camData then
		return nil
	end
	self.lastCam = camData
	self.visuals:addCamera(camData)

	self.ui:ensureTrack(name)
	self.ui:setActiveCamera(name)
	self:_refreshTimelineHeight()
end

function module:selectCamera(cameraName, preserveProperties)
	local entry = CameraResolver.get(cameraName)
	if not entry then return end
	self.lastCam = entry
	self.ui:setActiveCamera(cameraName)
	if not preserveProperties then
		self.ui:clearKeyframeProperties()
	end
	if self.editMode then
		self.handles:setMode(self.editTool)
		self.handles:setTarget(entry.part)
		self.handles:show(true)
	end
	if self.cameraMode then
		self:_applyCameraMode()
	end
end

function module:deleteCamera()
	local cameraName = self.lastCam and self.lastCam.name
	if not cameraName or not CameraResolver.get(cameraName) then
		return false
	end
	self:_setPlayerCameraLocked(false)
	self.editMode = false
	self.editTool = "move"
	self.handles:show(false)
	self.visuals:setVisible(true)
	if self.cameraMode then
		self.cameraMode = false
		self.ui:setViewToggle(false)
		self:_restorePlayerCamera()
	end
	self.storeByCamera[cameraName] = nil
	self.visuals:removeCamera(cameraName)
	self.ui:removeTrack(cameraName)
	CameraResolver.destroy(cameraName)
	self.lastCam = nil
	self.currentTime = 0
	self.isPlaying = false
	self:_updatePlaybackButton()
	self.ui:clearKeyframeProperties()
	self.ui:setEditSectionVisible(false)
	self:updatePlayhead()
	self:updateTimeLabel()
	self:_refreshTimelineHeight()
	return true
end

function module:setEditMode(mode)
	local entry = self:activeCam()
	local enabled = mode == "move" or mode == "rotate"
	if enabled and not entry then
		self.editMode = false
		self.handles:show(false)
		return
	end
	if enabled and self.cameraMode then
		self.cameraMode = false
		self.ui:setViewToggle(false)
		self:_applyCameraMode()
	end
	self.editMode = enabled
	self.editTool = enabled and mode or "move"
	if not enabled then
		self.handles:show(false)
		return
	end
	self.ui:setEditTool(self.editTool)
	self.handles:setMode(self.editTool)
	self.handles:setTarget(entry.part)
	self.handles:show(true)
end

function module:toggleEditMode()
	self:setEditMode(self.editMode and nil or "move")
end

function module:_isEditorCamera(camera)
	if not camera then return false end
	for _, entry in pairs(CameraResolver.getAll()) do
		if entry.camera == camera then
			return true
		end
	end
	return false
end
function module:_rememberPlayerCamera()
	local current = workspace.CurrentCamera
	if current and not self:_isEditorCamera(current) then
		self.playerCamera = current
	end
end
function module:_restorePlayerCamera()
	self:_rememberPlayerCamera()
	local camera = self.playerCamera
	if not camera or not camera.Parent or self:_isEditorCamera(camera) then
		camera = Instance.new("Camera")
		camera.Name = "PlayerCamera"
		camera.Parent = workspace
		self.playerCamera = camera
	end
	workspace.CurrentCamera = camera
	camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	camera.CameraSubject = humanoid or root or character
	self.previewCamera = nil
end
function module:_setPlayerCameraLocked(locked)
	if locked then
		if self.cameraLock or self.cameraMode or not self.editMode then return end
		local camera = workspace.CurrentCamera
		if not camera or self:_isEditorCamera(camera) or not camera.Parent then return end
		self.cameraLock = {
			camera = camera,
			cframe = camera.CFrame,
			cameraType = camera.CameraType,
			cameraSubject = camera.CameraSubject,
		}
		self.playerCamera = camera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = self.cameraLock.cframe
		return
	end
	local lock = self.cameraLock
	self.cameraLock = nil
	if not lock or not lock.camera or not lock.camera.Parent or self.cameraMode then return end
	workspace.CurrentCamera = lock.camera
	lock.camera.CFrame = lock.cframe
	lock.camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	lock.camera.CameraSubject = humanoid or root or character or lock.cameraSubject
end

function module:_applyCameraMode()
	if not self.cameraMode then
		self.visuals:setVisible(true)
		self:_restorePlayerCamera()
		return
	end
	local entry = self:activeCam()
	if not entry or not entry.camera then
		self.cameraMode = false
		self.ui:setViewToggle(false)
		self.visuals:setVisible(true)
		self:_restorePlayerCamera()
		return
	end
	local current = workspace.CurrentCamera
	if current and current ~= entry.camera and not self:_isEditorCamera(current) then
		self.playerCamera = current
	end
	self.visuals:setVisible(false)
	entry.camera.CameraType = Enum.CameraType.Scriptable
	workspace.CurrentCamera = entry.camera
	self.previewCamera = entry.camera
end

function module:_refreshTimelineHeight()
	if self.ui.timelineMinimized then return end
	local count = 0
	for _ in pairs(self.ui.tracks) do count += 1 end
	local rowH = 36
	local pad = 4
	local desired = math.clamp(count * (rowH + pad) + 28, 160, 280)
	self.ui.timelineExpandedHeight = desired
	local panel = self.ui.gui:FindFirstChild("TimelinePanel")
	if panel then
		panel.Size = UDim2.new(1, 0, 0, desired)
		panel.Position = UDim2.new(0, 0, 1, -desired)
	end
end

function module:setupButtons()
	self.playBtn = self.ui:createControlButton(1, "", Theme.Panel, function()
		self:togglePlayback()
	end, Icons.Play)
	self.stopBtn = self.ui:createControlButton(2, "", Theme.Panel, function()
		self:stop()
	end, Icons.Square)
	self.addBtn = self.ui:createControlButton(3, "", Theme.Panel, function()
		self:addKeyframe()
	end, Icons.Plus)
	self.deleteBtn = self.ui:createControlButton(4, "", Theme.Panel, function()
		self:deleteKeyframe()
	end, Icons.Trash)
	self.prevBtn = self.ui:createControlButton(5, "", Theme.Panel, function()
		self:prevKeyframe()
	end, Icons.ChevronLeft)
	self.nextBtn = self.ui:createControlButton(6, "", Theme.Panel, function()
		self:nextKeyframe()
	end, Icons.ChevronRight)
end
function module:_updatePlaybackButton()
	if not self.playBtn then return end
	self.playBtn.Text = ""
	self.playBtn.BackgroundColor3 = self.isPlaying and Theme.Success or Theme.Panel
	local icon = self.playBtn:FindFirstChild("Icon")
	if icon then
		icon.Image = self.isPlaying and Icons.Pause or Icons.Play
		icon.ImageColor3 = self.isPlaying and Theme.Text or Theme.TextDim
	end
end
function module:togglePlayback()
	if self.isPlaying then
		self:pause()
	else
		self:play()
	end
end
function module:play()
	if self.currentTime >= Config.MaxTime then
		self.currentTime = 0
		self:updateCameraByTime()
		self:updatePlayhead()
		self:updateTimeLabel()
	end
	self.isPlaying = true
	self:_updatePlaybackButton()
end
function module:pause()
	self.isPlaying = false
	self:_updatePlaybackButton()
end
function module:stop()
	self.isPlaying = false
	self.currentTime = 0
	self:updateCameraByTime()
	self:updatePlayhead()
	self:updateTimeLabel()
	self:_updatePlaybackButton()
end

function module:addKeyframe()
	local entry = self:activeCam()
	if not entry or not entry.part then return end

	local time = self.currentTime
	local camName = self.lastCam.name
	local store = self:storeFor(camName)

	for _, kf in ipairs(store.keyframes) do
		if math.abs(kf.time - time) < 1e-4 then
			self.addBtn.BackgroundColor3 = Theme.Warning
			task.delay(0.2, function() self.addBtn.BackgroundColor3 = Theme.Panel end)
			return
		end
	end

	local data = {
		time = time,
		position = entry.part.Position,
		orientation = entry.part.Orientation,
		cframe = entry.part.CFrame,
		cameraName = camName,
		easing = (store.metadata and store.metadata.easing) or "EaseInOut",
	}
	store:add(data)
	store:setSelected(data)
	self.ui:setKeyframeProperties(data)
	self.visuals:setKeyframes(camName, store:sorted())

	local record = self.ui:createKeyframeVisual(camName, time, data)
	data.frame = record.diamond

	self.addBtn.BackgroundColor3 = Theme.Success
	task.delay(0.2, function() self.addBtn.BackgroundColor3 = Theme.Panel end)
end

function module:updateSelectedKeyframe()
	local entry = self:activeCam()
	if not entry or not entry.part or not self.lastCam then return end
	local store = self:storeFor(self.lastCam.name)
	local selected = store:getSelected()
	if not selected then return end
	selected.cframe = entry.part.CFrame
	selected.position = entry.part.Position
	selected.orientation = entry.part.Orientation
	self.visuals:updateKeyframe(self.lastCam.name, selected)
	self.ui:setKeyframeProperties(selected)
end

function module:applySelectedKeyframeProperties(values)
	if not values then return end
	local entry = self:activeCam()
	if not entry or not entry.part or not self.lastCam then return end
	local store = self:storeFor(self.lastCam.name)
	local selected = store:getSelected()
	if not selected then return end
	local position = Vector3.new(values.positionX, values.positionY, values.positionZ)
	local orientation = Vector3.new(values.rotationX, values.rotationY, values.rotationZ)
	local cframe = CFrame.new(position) * CFrame.fromOrientation(
		math.rad(orientation.X),
		math.rad(orientation.Y),
		math.rad(orientation.Z)
	)
	CameraResolver.setCFrame(entry, cframe)
	selected.position = position
	selected.orientation = orientation
	selected.cframe = cframe
	if values.easing then
		selected.easing = values.easing
	end
	self.visuals:updateKeyframe(self.lastCam.name, selected)
	self.ui:setKeyframeProperties(selected)
	if self.cameraMode then
		self:_applyCameraMode()
	end
end

function module:prevKeyframe()
	if not self.lastCam then return end
	local store = self:storeFor(self.lastCam.name)
	local previous = nil
	for _, keyframe in ipairs(store:sorted()) do
		if keyframe.time < self.currentTime - EPSILON then
			previous = keyframe
		else
			break
		end
	end
	if previous then
		self:selectKeyframe(self.lastCam.name, previous)
	end
end

function module:nextKeyframe()
	if not self.lastCam then return end
	local store = self:storeFor(self.lastCam.name)
	for _, keyframe in ipairs(store:sorted()) do
		if keyframe.time > self.currentTime + EPSILON then
			self:selectKeyframe(self.lastCam.name, keyframe)
			return
		end
	end
end

function module:beginKeyframeDrag(cameraName, data)
	if not cameraName or not data then return end
	self:selectCamera(cameraName, true)
	local store = self:storeFor(cameraName)
	store:setSelected(data)
	self.isDraggingKeyframe = true
	self.isDraggingPlayhead = false
	self:pause()
	if self.tweenConnection then
		self.tweenConnection:Disconnect()
		self.tweenConnection = nil
	end
	self.ui:setKeyframeProperties(data)
end

function module:moveKeyframe(cameraName, data, targetTime)
	if not self.isDraggingKeyframe or not cameraName or not data then return data and data.time or targetTime end
	local store = self:storeFor(cameraName)
	local target = math.clamp(targetTime or data.time or 0, 0, Config.MaxTime)
	for _, candidate in ipairs(store.keyframes) do
		if candidate ~= data and math.abs(candidate.time - target) < 0.02 then
			return data.time
		end
	end
	data.time = target
	self.currentTime = target
	store:setSelected(data)
	self.visuals:setKeyframes(cameraName, store:sorted())
	self.ui:setKeyframeProperties(data)
	self:updatePlayhead()
	self:updateTimeLabel()
	return target
end

function module:endKeyframeDrag(cameraName, data)
	if not data then return end
	self.isDraggingKeyframe = false
	self.isDraggingPlayhead = false
	self.currentTime = data.time or self.currentTime
	self.ui:setKeyframeProperties(data)
	self:updatePlayhead()
	self:updateTimeLabel()
end

function module:selectKeyframe(camName, data)
	self:selectCamera(camName, true)
	local store = self:storeFor(camName)
	local selected = data
	if not selected or not selected.cframe then
		for _, candidate in ipairs(store.keyframes) do
			if candidate.time and data and math.abs(candidate.time - data.time) < 1e-4 then
				selected = candidate
				break
			end
		end
	end
	if not selected then return end
	store:setSelected(selected)
	self.ui:setKeyframeProperties(selected)
	self.currentTime = selected.time or 0
	self.isPlaying = false
	self:_updatePlaybackButton()
	self:updatePlayhead()
	self:tweenCameraTo(selected.cframe)
end

function module:tweenCameraTo(targetCFrame)
	local entry = self:activeCam()
	if not entry or not targetCFrame then return end
	if self.tweenConnection then
		self.tweenConnection:Disconnect()
		self.tweenConnection = nil
	end
	local startCFrame = CameraResolver.getCFrame(entry)
	if not startCFrame then return end
	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.min(elapsed / Config.InterpolationDuration, 1)
		alpha = 1 - (1 - alpha) ^ 2
		CameraResolver.setCFrame(entry, startCFrame:Lerp(targetCFrame, alpha))
		if alpha >= 1 then
			connection:Disconnect()
			if self.tweenConnection == connection then
				self.tweenConnection = nil
			end
		end
	end)
	self.tweenConnection = connection
end

function module:deleteKeyframe()
	if not self.lastCam then return end
	local camName = self.lastCam.name
	local store = self:storeFor(camName)
	local selected = store:getSelected()

	if not selected then
		local best, bestDist = nil, math.huge
		for _, kf in ipairs(store.keyframes) do
			local d = math.abs(kf.time - self.currentTime)
			if d < bestDist then best, bestDist = kf, d end
		end
		selected = best
	end

	if not selected then
		self.deleteBtn.BackgroundColor3 = Theme.Danger
		task.delay(0.2, function() self.deleteBtn.BackgroundColor3 = Theme.Panel end)
		return
	end

	self.ui:removeKeyframeVisual(camName, selected.time)
	store:remove(selected)
	self.visuals:setKeyframes(camName, store:sorted())

	self.deleteBtn.BackgroundColor3 = Theme.Danger
	task.delay(0.2, function() self.deleteBtn.BackgroundColor3 = Theme.Panel end)
end

function module:setupTimelineInput()
	self.ui.area.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if not self.isDraggingKeyframe and not self.ui.keyframePressActive then
				self.isDraggingPlayhead = true
			end
		end
	end)

	self.connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self.isDraggingPlayhead = false
			self.handles:stopDrag()
		end
	end)
end

function module:updateCameraByTime()
	if not self.lastCam then return end
	local store = self:storeFor(self.lastCam.name)
	if store:count() == 0 then return end

	local entry = self:activeCam()
	if not entry then return end

			local prevKf, nextKf = store:findNeighbors(self.currentTime)
		if prevKf and nextKf then
			local span = nextKf.time - prevKf.time
			local alpha = span > 0 and (self.currentTime - prevKf.time) / span or 0
			alpha = math.clamp(alpha, 0, 1)
			local easing = easingFunctions[prevKf.easing or (store.metadata and store.metadata.easing) or "EaseInOut"] or easingFunctions.EaseInOut
			alpha = easing(alpha)
			CameraResolver.setCFrame(entry, prevKf.cframe:Lerp(nextKf.cframe, alpha))

	elseif prevKf then
		CameraResolver.setCFrame(entry, prevKf.cframe)
	elseif nextKf then
		CameraResolver.setCFrame(entry, nextKf.cframe)
	end
end

function module:updateTimeLabel()
	local m = math.floor(self.currentTime / 60)
	local s = math.floor(self.currentTime % 60)
	local mm = math.floor(Config.MaxTime / 60)
	local ms = math.floor(Config.MaxTime % 60)
	self.ui.timeLabel.Text = string.format("%02d:%02d / %02d:%02d", m, s, mm, ms)
end

function module:updatePlayhead()
	self.ui:setPlayheadPosition(self.currentTime)
end

function module:startLoop()
	self.connections.RenderStepped = RunService.RenderStepped:Connect(function(dt)
		if self.isPlaying then
			local store = self.lastCam and self:storeFor(self.lastCam.name)
			local speedMultiplier = store and store.metadata and store.metadata.speedMultiplier or 1
			self.currentTime = self.currentTime + dt * speedMultiplier
			if self.currentTime >= Config.MaxTime then
				self.currentTime = Config.MaxTime
				self:pause()
			end
			self:updateCameraByTime()
		end

		if self.isDraggingPlayhead then
			local mousePos = UserInputService:GetMouseLocation()
			self.currentTime = self.ui:xToTime(mousePos.X)
			self:pause()
			self:updateCameraByTime()
		end

		if self.editMode then
			self.handles:update()
			if self.handles.isDragging then
				self.handles:dragUpdate()
			end
		end

		self.visuals:sync()
		self:updatePlayhead()
		self:updateTimeLabel()
	end)
end

function module:destroy()
	self:_setPlayerCameraLocked(false)
	if self.cameraMode then
		self.cameraMode = false
		self:_restorePlayerCamera()
	end
	if self.tweenConnection then
		self.tweenConnection:Disconnect()
		self.tweenConnection = nil
	end
	for _, connection in pairs(self.connections) do
		if connection then connection:Disconnect() end
	end
	self.connections = {}
	if self.handles then self.handles:destroy() end
	if self.visuals then self.visuals:destroy() end
end

return module