local Players = game:GetService("Players")
local Dev = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxmmo/Nightfall-Storage/refs/heads/main/utils/modules/dev.lua"))()
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
	self.connections = {}
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

function module:setupModeButtons()
	self.ui.editButton.MouseButton1Click:Connect(function()
		self:toggleEditMode()
	end)
	self.ui.viewButton.MouseButton1Click:Connect(function()
		self:toggleCameraMode()
	end)
	self.ui.addCamButton.MouseButton1Click:Connect(function()
		self:addCamera()
	end)
end

function module:addCamera()
	local name = ("cam_" .. _nextCamId)
	_nextCamId += 1
	local camData = CameraResolver.createCam({
		Name = name,
		CFrame = CFrame.new(0, 5, 10),
		FieldOfView = 70
	})

	if not camData then
		return nil
	end
	self.lastCam = camData
end

function module:toggleEditMode()
	local entry = self:activeCam()
	if not entry then
		self.editMode = false
		self.handles:show(false)
		self.ui.editButton.BackgroundColor3 = Theme.Panel
		return
	end

	self.editMode = not self.editMode
	self.handles:setTarget(entry.part)
	self.handles:show(self.editMode)
	self.ui.editButton.BackgroundColor3 = self.editMode and Theme.Accent or Theme.Panel
end

function module:toggleCameraMode()
	self.cameraMode = not self.cameraMode
	if self.cameraMode then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		if self.lastCam then
			local camData = CameraResolver.get(self.lastCam.Name)
			if camData and camData.camera then
				workspace.CurrentCamera = camData.camera
			end
		end
		self.ui.viewButton.BackgroundColor3 = Theme.Accent
	else
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		if Players.LocalPlayer.Character then
			workspace.CurrentCamera.CameraSubject = Players.LocalPlayer.Character
		end
		self.ui.viewButton.BackgroundColor3 = Theme.Panel
	end
end

function module:setupButtons()
	self.playBtn = self.ui:createControlButton(1, "▶", Theme.Panel, function() self:play() end)
	self.pauseBtn = self.ui:createControlButton(2, "⏸", Theme.Panel, function() self:pause() end)
	self.stopBtn = self.ui:createControlButton(3, "⏹", Theme.Panel, function() self:stop() end)
	self.addBtn = self.ui:createControlButton(4, "＋", Theme.Panel, function() self:addKeyframe() end)
	self.deleteBtn = self.ui:createControlButton(5, "✕", Theme.Panel, function() self:deleteSelected() end)
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

	local data = {
		time = self.currentTime,
		position = entry.part.Position,
		orientation = entry.part.Orientation,
		cframe = entry.part.CFrame,
	}
	self:createKeyframeVisual(data)
	self.store:add(data)

	self.addBtn.BackgroundColor3 = Theme.Success
	task.delay(0.2, function()
		self.addBtn.BackgroundColor3 = Theme.Panel
	end)
end

function module:createKeyframeVisual(data)
	local kf = Instance.new("TextButton")
	kf.Name = "Keyframe"
	kf.Size = UDim2.new(0, 12, 0, 20)
	kf.Position = UDim2.new(data.time / Config.MaxTime, -6, 0.5, -10)
	kf.BackgroundColor3 = Theme.Keyframe
	kf.BorderSizePixel = 0
	kf.Text = ""
	kf.ZIndex = 5
	kf.Parent = self.ui.track
	UIFactory.corner(kf, 2)
	UIFactory.stroke(kf, Theme.Border, 1)

	data.frame = kf

	kf.MouseButton1Click:Connect(function()
		self:selectKeyframe(data)
	end)
end

function module:selectKeyframe(data)
	self.store:setSelected(data)
	self.currentTime = data.time

	for _, kf in ipairs(self.store.keyframes) do
		if kf.frame then
			kf.frame.BackgroundColor3 = Theme.Keyframe
		end
	end
	if data.frame then
		data.frame.BackgroundColor3 = Theme.KeyframeSelected
	end

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

function module:deleteSelected()
	local selected = self.store:getSelected()
	if not selected then return end
	self.store:remove(selected)
	self.deleteBtn.BackgroundColor3 = Theme.Danger
	task.delay(0.2, function()
		self.deleteBtn.BackgroundColor3 = Theme.Panel
	end)
end

function module:setupTimelineInput()
	self.ui.area.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.isDraggingPlayhead = true
		end
	end)

	self.connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.isDraggingPlayhead = false
			self.handles:stopDrag()
		end
	end)
end

function module:updateCameraByTime()
	local entry = self:activeCam()
	if not entry or self.store:count() == 0 then return end

	local prevKf, nextKf = self.store:findNeighbors(self.currentTime)
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
			local relX = mousePos.X - self.ui.area.AbsolutePosition.X
			local normalized = math.clamp(relX / self.ui.area.AbsoluteSize.X, 0, 1)
			self.currentTime = normalized * Config.MaxTime
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
			local camCFrame = CameraResolver.getCFrame(entry)
			if camCFrame then
				workspace.CurrentCamera.CFrame = camCFrame
			end
		end

		self:updatePlayhead()
		self:updateTimeLabel()
	end)
end

function module:destroy()
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.connections = {}
	if self.handles then
		self.handles:destroy()
	end
end

return module
