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
	self.cameraMode = false
	self.lastCam = nil
	self.storeByCamera = {}
	self.connections = {}
	self.ui.onTrackSelected = function(cameraName)
		self:selectCamera(cameraName)
	end
	self.ui.onKeyframeSelected = function(cameraName, data)
		self:selectKeyframe(cameraName, data)
	end
	self.handles:show(false)
	self:setupButtons()
	self:setupTimelineInput()
	self:setupModeButtons()
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
		self:toggleEditMode()
		self.ui:closeCamerasModal()
	end)
	self.ui.addCamButton.MouseButton1Click:Connect(function()
		self:addCamera()
		self.ui:closeCamerasModal()
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

function module:selectCamera(cameraName)
	local entry = CameraResolver.get(cameraName)
	if not entry then return end
	self.lastCam = entry
	self.ui:setActiveCamera(cameraName)
	if self.editMode then
		self.handles:setTarget(entry.part)
		self.handles:show(true)
	end
	if self.cameraMode then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera = entry.camera
	end
end

function module:toggleEditMode()
	local entry = self:activeCam()
	if not entry then
		self.editMode = false
		self.handles:show(false)
		return
	end

	self.editMode = not self.editMode
	self.handles:setTarget(entry.part)
	self.handles:show(self.editMode)
end

function module:_applyCameraMode()
	if self.cameraMode then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		if self.lastCam then
			local camData = CameraResolver.get(self.lastCam.name)
			if camData and camData.camera then
				workspace.CurrentCamera = camData.camera
			end
		end
	else
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		if Players.LocalPlayer.Character then
			workspace.CurrentCamera.CameraSubject = Players.LocalPlayer.Character
		end
	end
end

function module:_refreshTimelineHeight()
	local count = 0
	for _ in pairs(self.ui.tracks) do count += 1 end
	local rowH = 36
	local pad = 4
	local desired = math.clamp(count * (rowH + pad) + 28, 160, 280)
	local panel = self.ui.gui:FindFirstChild("TimelinePanel")
	if panel then
		panel.Size = UDim2.new(1, 0, 0, desired)
		panel.Position = UDim2.new(0, 0, 1, -desired)
	end
end

function module:setupButtons()
	self.playBtn   = self.ui:createControlButton(1, "▶", Theme.Panel,   function() self:play()  end)
	self.pauseBtn  = self.ui:createControlButton(2, "⏸", Theme.Panel,   function() self:pause() end)
	self.stopBtn   = self.ui:createControlButton(3, "⏹", Theme.Panel,   function() self:stop()  end)
	self.addBtn    = self.ui:createControlButton(4, "＋", Theme.Panel,  function() self:addKeyframe() end)
	self.deleteBtn = self.ui:createControlButton(5, "✕", Theme.Panel,   function() self:deleteKeyframe() end)
end

function module:play()
	self.isPlaying = true
	self.playBtn.BackgroundColor3 = Theme.Success
	self.pauseBtn.BackgroundColor3 = Theme.Panel
end

function module:pause()
	self.isPlaying = false
	self.pauseBtn.BackgroundColor3 = Theme.Warning
	self.playBtn.BackgroundColor3 = Theme.Panel
end

function module:stop()
	self.isPlaying = false
	self.currentTime = 0
	self.playBtn.BackgroundColor3 = Theme.Panel
	self.pauseBtn.BackgroundColor3 = Theme.Panel
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

	local record = self.ui:createKeyframeVisual(camName, time)
	data.frame = record.diamond
	record.data = data

	self.addBtn.BackgroundColor3 = Theme.Success
	task.delay(0.2, function() self.addBtn.BackgroundColor3 = Theme.Panel end)
end

function module:selectKeyframe(camName, data)
	self:selectCamera(camName)
	local store = self:storeFor(camName)
	store:setSelected(data)
	self.currentTime = data.time
	self.isPlaying = false
	self:updatePlayhead()
	self:tweenCameraTo(data.cframe)
end

function module:tweenCameraTo(targetCFrame)
	local entry = self:activeCam()
	if not entry or not targetCFrame then return end

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
		end
	end)
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
				self.isPlaying = false
				self.playBtn.BackgroundColor3 = Theme.Panel
			end
			self:updateCameraByTime()
		end

		if self.isDraggingPlayhead then
			local mousePos = UserInputService:GetMouseLocation()
			self.currentTime = self.ui:xToTime(mousePos.X)
			self.isPlaying = false
			self:updateCameraByTime()
		end

		if self.editMode then
			self.handles:update()
			if self.handles.isDragging then
				self.handles:dragUpdate()
			end
		end

		if self.cameraMode then
			local entry = self:activeCam()
			if entry then
				local camCFrame = CameraResolver.getCFrame(entry)
				if camCFrame then
					workspace.CurrentCamera.CFrame = camCFrame
				end
			end
		end

		self:updatePlayhead()
		self:updateTimeLabel()
	end)
end

function module:destroy()
	for _, connection in pairs(self.connections) do
		if connection then connection:Disconnect() end
	end
	self.connections = {}
	if self.handles then self.handles:destroy() end
end

return module