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
	self.objectSelectionMode = false
	self.cameraMode = false
	self.lastCam = nil
	self.objectTargets = {}
	self.playerCamera = workspace.CurrentCamera
	self.cameraLock = nil
	self.tweenConnection = nil
	self.visuals = WorldVisuals.new()
	self.storeByCamera = {}
	self.connections = {}
	self.ui.onTrackSelected = function(cameraName)
		self:selectTrack(cameraName)
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
			self.ui.onTrackPropertiesRequested = function(cameraName)
			self:selectTrack(cameraName)
		end
		self.ui.onTrackPropertiesButtonRequested = function()
			if not self.lastCam then return end
			local cameraName = self.lastCam.name
			local track = self.ui.tracks[cameraName]
			local store = self:storeFor(cameraName)
			local position = track and track.rangeVisual and track.rangeVisual.AbsolutePosition or Vector2.new(12, 50)
			self.ui:openTrackProperties(cameraName, position, store.metadata)
		end

			self.ui.onTrackPropertiesSubmitted = function(cameraName, values)
			self:applyTrackProperties(cameraName, values)
		end
					self.ui.onTrackResizeStarted = function(cameraName)
			self.isDraggingPlayhead = false
			self:selectTrack(cameraName, true)

			self:pause()
		end
		self.ui.onTrackResized = function(cameraName, startTime, endTime)
			self:applyTrackRange(cameraName, startTime, endTime)
		end
		self.ui.onTrackResizeEnded = function(cameraName, startTime, endTime)
			self:applyTrackRange(cameraName, startTime, endTime)
		end

		self.handles.onChanged = function(target, cframe, size)
			self:updateSelectedKeyframe(target, cframe, size)
		end
	self.handles.onDragStateChanged = function(dragging)
		self:_setPlayerCameraLocked(dragging)
	end
	self.handles:show(false)
	self:setupButtons()
	self:setupTimelineInput()
	self:setupModeButtons()
	self:setupObjectSelection()
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
							local entry = self:activeTarget()
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

function module:targetFor(name)
	if not name then return nil end
	local entry = CameraResolver.get(name)
	if entry and entry.part then return entry end
	local part = self.objectTargets[name]
	if part and part.Parent then
		return {name = name, part = part, object = true}
	end
	return nil
end

function module:activeTarget()
	return self.lastCam and self:targetFor(self.lastCam.name) or nil
end

function module:isObjectTrack(name)
	return name and self.objectTargets[name] ~= nil
end

function module:getTargetCFrame(target)
	if not target then return nil end
	local part = target.part or target
	return part and part.CFrame or nil
end

function module:setTargetCFrame(target, cframe)
	if not target or not cframe then return end
	local part = target.part or target
	if not part or not part.Parent then return end
	if target.object or self:isObjectTrack(target.name) then
		part.CFrame = cframe
	else
		CameraResolver.setCFrame(target, cframe)
	end
end

function module:applyTargetState(target, cframe, size, color, transparency)
	if not target or not target.part or not target.part.Parent then return end
	self:setTargetCFrame(target, cframe)
	if target.object or self:isObjectTrack(target.name) then
		if size then target.part.Size = size end
		if color then target.part.Color = color end
		if transparency ~= nil then target.part.Transparency = math.clamp(transparency, 0, 1) end
	end
end

function module:storeFor(cameraName)
	if not self.storeByCamera[cameraName] then
		self.storeByCamera[cameraName] = setmetatable({
			keyframes = {},
			selected = nil,
							metadata = {
					speedMultiplier = 1,
					easing = "EaseInOut",
					startTime = 0,
					endTime = Config.MaxTime,
				},

		}, {__index = self.store})
	end
	local store = self.storeByCamera[cameraName]
			store.metadata = store.metadata or {
			speedMultiplier = 1,
			easing = "EaseInOut",
			startTime = 0,
			endTime = Config.MaxTime,
		}
		store.metadata.startTime = tonumber(store.metadata.startTime) or 0
		store.metadata.endTime = tonumber(store.metadata.endTime) or Config.MaxTime
		return store
	end

	function module:applyTrackRange(cameraName, startTime, endTime)
		local store = self:storeFor(cameraName)
		local maxTime = Config.MaxTime
		local start = math.clamp(tonumber(startTime) or store.metadata.startTime or 0, 0, maxTime)
		local finish = math.clamp(tonumber(endTime) or store.metadata.endTime or maxTime, 0, maxTime)
		if finish < start then
			start, finish = finish, start
		end
		if finish - start < 0.1 then
			finish = math.min(maxTime, start + 0.1)
			start = math.min(start, finish - 0.1)
		end
		store.metadata.startTime = start
		store.metadata.endTime = finish
		if self.lastCam and self.lastCam.name == cameraName and self.currentTime > finish then
			self.currentTime = finish
		end
	end

	function module:applyTrackProperties(cameraName, values)

	if not cameraName or not values then return end
	local target = self:targetFor(cameraName)
	if not target then return end
	local store = self:storeFor(cameraName)
	store.metadata.speedMultiplier = values.speedMultiplier
	store.metadata.easing = values.easing or store.metadata.easing or "EaseInOut"
	local newName = values.name
	if newName ~= cameraName then
		local renamed = self:isObjectTrack(cameraName) and self:renameObjectTrack(cameraName, newName) or self:renameCamera(cameraName, newName)
		if not renamed then return end
		cameraName = newName
	end
	self.ui:closeTrackProperties()
end

function module:renameObjectTrack(oldName, newName)
	if not oldName or not newName or newName == "" or oldName == newName then return self:targetFor(oldName) end
	if self.ui.tracks[newName] or CameraResolver.get(newName) or self.objectTargets[newName] then return nil end
	local part = self.objectTargets[oldName]
	if not part or not part.Parent then return nil end
	local store = self.storeByCamera[oldName]
	self.objectTargets[oldName] = nil
	self.objectTargets[newName] = part
	self.storeByCamera[oldName] = nil
	if store then
		self.storeByCamera[newName] = store
		for _, keyframe in ipairs(store.keyframes) do
			keyframe.cameraName = newName
		end
	end
	self.visuals:renameCamera(oldName, newName)
	self.ui:updateTrackName(oldName, newName)
	self.lastCam = {name = newName, part = part, object = true}
	return self.lastCam
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
		self.ui.onEditToolSelected = function(mode)
			self:setEditMode(mode)
		end
	self.ui.addCamButton.MouseButton1Click:Connect(function()
		self:addCamera()
		self.ui:closeCamerasModal()
	end)
		self.ui.deleteTrackButton.MouseButton1Click:Connect(function()
			if self:deleteTrack() then
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

function module:setupObjectSelection()
	self.connections.ObjectSelection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.objectSelectionMode then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local camera = workspace.CurrentCamera
		if not camera then return end
		local position = input.Position
		local ray = camera:ViewportPointToRay(position.X, position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclusions = {}
		local character = Players.LocalPlayer.Character
		if character then
			table.insert(exclusions, character)
		end
		local camsFolder = workspace:FindFirstChild("cams_folder")
		if camsFolder then
			table.insert(exclusions, camsFolder)
		end
		if self.visuals and self.visuals.folder then
			table.insert(exclusions, self.visuals.folder)
		end
		params.FilterDescendantsInstances = exclusions
		local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
		local part = result and result.Instance
		if part and part:IsA("BasePart") then
			self:selectMapPart(part)
		end
	end)
end

function module:selectMapPart(part)
	if not part or not part:IsA("BasePart") or not part.Parent then return nil end
	if self.visuals and self.visuals.folder and part:IsDescendantOf(self.visuals.folder) then return nil end
	local camsFolder = workspace:FindFirstChild("cams_folder")
	if camsFolder and part:IsDescendantOf(camsFolder) then return nil end
	local name = part.Name
	if name == "" then name = "Part" end
	local baseName = name
	local suffix = 1
	while self.ui.tracks[name] and self.objectTargets[name] ~= part do
		suffix = suffix + 1
		name = baseName .. "_" .. suffix
	end
	if not self.objectTargets[name] then
		self.objectTargets[name] = part
		self:storeFor(name)
		self.ui:ensureTrack(name)
		local store = self:storeFor(name)
		self.ui:setTrackRange(name, store.metadata.startTime, store.metadata.endTime)
	end
	self.lastCam = {name = name, part = part, object = true}
	self.ui:setActiveCamera(name)
	self.ui:clearKeyframeProperties()
	self.objectSelectionMode = false
	self:setEditMode("move")
	self:_refreshTimelineHeight()
	return self.lastCam
end

function module:addCamera()
	local name
	repeat
		name = "cam_" .. _nextCamId
		_nextCamId = _nextCamId + 1
	until not CameraResolver.get(name)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local flatForward = root and Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) or Vector3.new(0, 0, -1)
	if flatForward.Magnitude < EPSILON then
		flatForward = Vector3.new(0, 0, -1)
	else
		flatForward = flatForward.Unit
	end
	local spawnPosition = root and (root.Position - flatForward * 5 + Vector3.new(0, 1, 0)) or Vector3.new(0, 5, 10)
	local spawnCFrame = CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, -1))
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
		local store = self:storeFor(name)
		self.ui:setTrackRange(name, store.metadata.startTime, store.metadata.endTime)
		self.ui:setActiveCamera(name)

	self:_refreshTimelineHeight()
end

function module:selectTrack(name, preserveProperties)
	local target = self:targetFor(name)
	if not target then return end
	self.lastCam = target
	self.objectSelectionMode = false
	self.ui:setActiveCamera(name)
	if not preserveProperties then
		self.ui:clearKeyframeProperties()
	end
	if self.editMode then
		self.handles:setMode(self.editTool)
		self.handles:setTarget(target.part)
		self.handles:show(true)
	end
	if self.cameraMode and not target.object then
		self:_applyCameraMode()
	end
end

function module:selectCamera(cameraName, preserveProperties)
	if CameraResolver.get(cameraName) then
		self:selectTrack(cameraName, preserveProperties)
	end
end

function module:deleteTrack()
		local cameraName = self.lastCam and self.lastCam.name
		if not cameraName or not self:targetFor(cameraName) then
			return false
		end
		local objectTrack = self:isObjectTrack(cameraName)
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
		if objectTrack then
			self.objectTargets[cameraName] = nil
			self.visuals:removePath(cameraName)
		else
			self.visuals:removeCamera(cameraName)
			CameraResolver.destroy(cameraName)
		end
		self.ui:removeTrack(cameraName)
	self.lastCam = nil
	self.currentTime = 0
	self.isPlaying = false
	self:_updatePlaybackButton()
	self.ui:clearKeyframeProperties()
		self.ui:closeEditModal()
		self:updatePlayhead()
	self:updateTimeLabel()
	self:_refreshTimelineHeight()
	return true
end

function module:setEditMode(mode)
	if mode == "select" then
		self.objectSelectionMode = true
		self.editMode = false
		self:_setPlayerCameraLocked(false)
		self.handles:show(false)
		self.ui:setEditTool("select")
		return
	end
	self.objectSelectionMode = false
	local target = self:activeTarget()
		local enabled = mode == "move" or mode == "rotate" or mode == "scale"
		if mode == "scale" and (not target or not target.object) then
			self.editMode = false
			self.handles:show(false)
			return
		end
		if enabled and not target then
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
		self.ui:setEditTool("move")
		return
	end
	self.ui:setEditTool(self.editTool)
	self.handles:setMode(self.editTool)
	self.handles:setTarget(target.part)
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
	for _ in pairs(self.ui.tracks) do count = count + 1 end
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
		local activeTrack = self.lastCam and self.ui.tracks[self.lastCam.name]
		local activeEnd = activeTrack and (activeTrack.endTime or Config.MaxTime) or Config.MaxTime
		if self.currentTime >= Config.MaxTime - EPSILON then
			self.currentTime = activeTrack and (activeTrack.startTime or 0) or 0
		elseif self.currentTime >= activeEnd - EPSILON then
			local nextCamera = self:findNextPlaybackCamera()
						if nextCamera then
				local nextTrack = self.ui.tracks[nextCamera]
									self:selectTrack(nextCamera, true)

				local nextStart = nextTrack and (nextTrack.startTime or 0) or 0
				local nextEnd = nextTrack and (nextTrack.endTime or Config.MaxTime) or Config.MaxTime
				self.currentTime = math.clamp(self.currentTime, nextStart, nextEnd)
			else

				self.currentTime = activeTrack and (activeTrack.startTime or 0) or 0
			end
		end
		self:updateCameraByTime()
		self:updatePlayhead()
		self:updateTimeLabel()
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
	local entry = self:activeTarget()
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

	local isObject = entry.object == true
		local data = {
			time = time,
			position = entry.part.Position,
			orientation = entry.part.Orientation,
			cframe = entry.part.CFrame,
			cameraName = camName,
			object = isObject,
			size = isObject and entry.part.Size or nil,
			color = isObject and entry.part.Color or nil,
			transparency = isObject and entry.part.Transparency or nil,
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

function module:updateSelectedKeyframe(target, cframe, size)
		local entry = self:activeTarget()
		if not entry or not entry.part or not self.lastCam then return end
		local store = self:storeFor(self.lastCam.name)
		local selected = store:getSelected()
		if not selected then return end
		selected.cframe = cframe or entry.part.CFrame
		selected.position = entry.part.Position
		selected.orientation = entry.part.Orientation
		if entry.object then
			selected.object = true
			selected.size = size or entry.part.Size
			selected.color = entry.part.Color
			selected.transparency = entry.part.Transparency
		end
		self.visuals:updateKeyframe(self.lastCam.name, selected)
		self.ui:setKeyframeProperties(selected)
	end

function module:applySelectedKeyframeProperties(values)
	if not values then return end
	local entry = self:activeTarget()
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
	local size = selected.size
	local color = selected.color
	local transparency = selected.transparency
	if entry.object then
		if values.sizeX and values.sizeY and values.sizeZ then
			size = Vector3.new(math.max(0.05, values.sizeX), math.max(0.05, values.sizeY), math.max(0.05, values.sizeZ))
		end
		if values.colorR and values.colorG and values.colorB then
			color = Color3.fromRGB(math.clamp(values.colorR, 0, 255), math.clamp(values.colorG, 0, 255), math.clamp(values.colorB, 0, 255))
		end
		if values.transparency ~= nil then
			transparency = math.clamp(values.transparency, 0, 1)
		end
	end
	self:applyTargetState(entry, cframe, size, color, transparency)
	selected.position = position
	selected.orientation = orientation
	selected.cframe = cframe
	if entry.object then
		selected.size = size
		selected.color = color
		selected.transparency = transparency
	end
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
	self:selectTrack(cameraName, true)
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
	self:selectTrack(camName, true)
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
	local entry = self:activeTarget()
	if not entry or not targetCFrame then return end
	if self.tweenConnection then
		self.tweenConnection:Disconnect()
		self.tweenConnection = nil
	end
	local startCFrame = self:getTargetCFrame(entry)
	if not startCFrame then return end
	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.min(elapsed / Config.InterpolationDuration, 1)
		alpha = 1 - (1 - alpha) ^ 2
					self:setTargetCFrame(entry, startCFrame:Lerp(targetCFrame, alpha))

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

function module:findTopPlaybackCamera()
	if not self.ui or not self.ui.tracks then return nil end
	local candidateName = nil
	local candidateOrder = math.huge
	for name, track in pairs(self.ui.tracks) do
		local store = self:storeFor(name)
		if track.row and track.row.LayoutOrder < candidateOrder and store:count() > 0 then
			candidateName = name
			candidateOrder = track.row.LayoutOrder
		end
	end
	return candidateName
end

function module:resetToTopPlaybackCamera()
	local topCamera = self:findTopPlaybackCamera()
	if topCamera then
					self:selectTrack(topCamera, true)

		local track = self.ui.tracks[topCamera]
		local topStart = track and (track.startTime or 0) or 0
		local topEnd = track and (track.endTime or Config.MaxTime) or Config.MaxTime
		self.currentTime = math.clamp(topStart, 0, topEnd)
		self:updateCameraByTime()
	else
		self.currentTime = 0
	end
	self:updatePlayhead()
	self:updateTimeLabel()
end

function module:findPlaybackCameraAtTime(time)
	if not self.ui or not self.ui.tracks then return nil end
	local candidateName = nil
	local candidateOrder = math.huge
	for name, track in pairs(self.ui.tracks) do
		local store = self:storeFor(name)
		local startTime = track.startTime or 0
		local endTime = track.endTime or Config.MaxTime
		if track.row and store:count() > 0 and time >= startTime - EPSILON and time <= endTime + EPSILON then
			if track.row.LayoutOrder < candidateOrder then
				candidateName = name
				candidateOrder = track.row.LayoutOrder
			end
		end
	end
	return candidateName
end

function module:findNextPlaybackCamera()
	if not self.lastCam or not self.ui or not self.ui.tracks then return nil end
	local currentTrack = self.ui.tracks[self.lastCam.name]
	if not currentTrack or not currentTrack.row then return nil end
	local currentOrder = currentTrack.row.LayoutOrder
	local currentEnd = currentTrack.endTime or Config.MaxTime
	local candidateName = nil
	local candidateOrder = math.huge
	for name, track in pairs(self.ui.tracks) do
		local store = self:storeFor(name)
		local trackEnd = track.endTime or Config.MaxTime
		if name ~= self.lastCam.name and track.row and track.row.LayoutOrder > currentOrder and track.row.LayoutOrder < candidateOrder and trackEnd > currentEnd + EPSILON and store:count() > 0 then
			candidateName = name
			candidateOrder = track.row.LayoutOrder
		end
	end
	return candidateName
end

function module:updateCameraByTime()
	if not self.lastCam then return end
	local store = self:storeFor(self.lastCam.name)
	if store:count() == 0 then return end

		local entry = self:activeTarget()
	if not entry then return end

				local prevKf, nextKf = store:findNeighbors(self.currentTime)

			if prevKf and nextKf then
				local span = nextKf.time - prevKf.time
				local alpha = span > 0 and (self.currentTime - prevKf.time) / span or 0
				alpha = math.clamp(alpha, 0, 1)
				local easing = easingFunctions[prevKf.easing or (store.metadata and store.metadata.easing) or "EaseInOut"] or easingFunctions.EaseInOut
				alpha = easing(alpha)
				local cframe = prevKf.cframe:Lerp(nextKf.cframe, alpha)
				local size = prevKf.size and nextKf.size and prevKf.size:Lerp(nextKf.size, alpha) or nil
				local color = prevKf.color and nextKf.color and prevKf.color:Lerp(nextKf.color, alpha) or nil
				local transparency = nil
				if prevKf.transparency ~= nil and nextKf.transparency ~= nil then
					transparency = prevKf.transparency + (nextKf.transparency - prevKf.transparency) * alpha
				end
				self:applyTargetState(entry, cframe, size, color, transparency)
			elseif prevKf then
				self:applyTargetState(entry, prevKf.cframe, prevKf.size, prevKf.color, prevKf.transparency)
			elseif nextKf then
				self:applyTargetState(entry, nextKf.cframe, nextKf.size, nextKf.color, nextKf.transparency)
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
					local activeName = self.lastCam and self.lastCam.name
					local store = activeName and self:storeFor(activeName)
					local speedMultiplier = store and store.metadata and store.metadata.speedMultiplier or 1
					self.currentTime = self.currentTime + dt * speedMultiplier
					local playbackCamera = self:findPlaybackCameraAtTime(self.currentTime)
					if playbackCamera then
						if not self.lastCam or self.lastCam.name ~= playbackCamera then
															self:selectTrack(playbackCamera, true)

						end
						self:updateCameraByTime()
					elseif self.currentTime >= Config.MaxTime - EPSILON then
						self:resetToTopPlaybackCamera()
						self:pause()
					end
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