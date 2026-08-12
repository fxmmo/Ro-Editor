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
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local CameraResolver = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/CameraResolver.lua") or error("[Ro-Editor] import failed")
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local _nextCamId = 1

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
	self.editMode = false
	self.editTool = "move"
	self.cameraMode = false
	self.lastCam = nil
	self.playerCamera = workspace.CurrentCamera
	self.cameraLock = nil
	self.tweenConnection = nil
	self.storeByCamera = {}
	self.connections = {}
	self.ui.onTrackSelected = function(cameraName)
		self:selectCamera(cameraName)
	end
	self.ui.onKeyframeSelected = function(cameraName, data)
		self:selectKeyframe(cameraName, data)
	end
	self.ui.onPropertiesSubmitted = function(values)
		self:applySelectedKeyframeProperties(values)
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
		self.storeByCamera[cameraName] = setmetatable({keyframes = {}, selected = nil}, {__index = self.store})
	end
	return self.storeByCamera[cameraName]
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
	local name = ("cam_" .. _nextCamId)
	_nextCamId += 1
	local camData = CameraResolver.createCam({
		Name = name,
		CFrame = CFrame.new(0, 5, 10),
		FieldOfView = 70,
	})

	if not camData then
		return nil
	end
	self.lastCam = camData

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
	if self.cameraMode then
		self.cameraMode = false
		self.ui:setViewToggle(false)
		self:_restorePlayerCamera()
	end
	self.storeByCamera[cameraName] = nil
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
		self:_restorePlayerCamera()
		return
	end
	local entry = self:activeCam()
	if not entry or not entry.camera then
		self.cameraMode = false
		self.ui:setViewToggle(false)
		self:_restorePlayerCamera()
		return
	end
	local current = workspace.CurrentCamera
	if current and current ~= entry.camera and not self:_isEditorCamera(current) then
		self.playerCamera = current
	end
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
	self.playBtn = self.ui:createControlButton(1, "▶", Theme.Panel, function()
		self:togglePlayback()
	end)
	self.stopBtn = self.ui:createControlButton(2, "⏹", Theme.Panel, function()
		self:stop()
	end)
	self.addBtn = self.ui:createControlButton(3, "＋", Theme.Panel, function()
		self:addKeyframe()
	end)
	self.deleteBtn = self.ui:createControlButton(4, "✕", Theme.Panel, function()
		self:deleteKeyframe()
	end)
end
function module:_updatePlaybackButton()
	if not self.playBtn then return end
	self.playBtn.Text = self.isPlaying and "⏸" or "▶"
	self.playBtn.BackgroundColor3 = self.isPlaying and Theme.Success or Theme.Panel
end
function module:togglePlayback()
	if self.isPlaying then
		self:pause()
	else
		self:play()
	end
end
function module:play()
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
	}
	store:add(data)
	store:setSelected(data)
	self.ui:setKeyframeProperties(data)

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
	self.ui:setKeyframeProperties(selected)
	if self.cameraMode then
		self:_applyCameraMode()
	end
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

	self.deleteBtn.BackgroundColor3 = Theme.Danger
	task.delay(0.2, function() self.deleteBtn.BackgroundColor3 = Theme.Panel end)
end

function module:setupTimelineInput()
	self.ui.area.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self.isDraggingPlayhead = true
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
			self.currentTime = self.currentTime + dt
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
end

return module