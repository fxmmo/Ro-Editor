local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Dev = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxmmo/Nightfall-Storage/refs/heads/main/utils/modules/dev.lua"))()
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local CameraResolver = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/CameraResolver.lua")

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
	self:setupButtons()
	self:setupTimelineInput()
	self:setupModeButtons()
	self:startLoop()
	return self
end

function module:setupModeButtons()
	self.ui.editButton.MouseButton1Click:Connect(function()
		self:toggleEditMode()
	end)
	self.ui.viewButton.MouseButton1Click:Connect(function()
		self:toggleCameraMode()
	end)
end

function module:toggleEditMode()
	self.editMode = not self.editMode
	local target = CameraResolver.get()
	self.handles:setTarget(target)
	self.handles:show(self.editMode)
	self.ui.editButton.BackgroundColor3 = self.editMode and Theme.Accent or Theme.Panel
end

function module:toggleCameraMode()
	self.cameraMode = not self.cameraMode
	if self.cameraMode then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		self.ui.viewButton.BackgroundColor3 = Theme.Accent
	else
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
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
	local cam = CameraResolver.get()
	if not cam then return end

	local data = {
		time = self.currentTime,
		position = cam.Position,
		orientation = cam.Orientation,
		cframe = cam.CFrame,
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
	local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua")
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
	local cam = CameraResolver.get()
	if not cam then return end

	local startCFrame = cam.CFrame
	local startTime = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.min(elapsed / Config.InterpolationDuration, 1)
		alpha = 1 - (1 - alpha) ^ 2
		cam.CFrame = startCFrame:Lerp(targetCFrame, alpha)
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

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.isDraggingPlayhead = false
			self.handles:stopDrag()
		end
	end)
end

function module:updateCameraByTime()
	local cam = CameraResolver.get()
	if not cam or self.store:count() == 0 then return end

	local prev, next = self.store:findNeighbors(self.currentTime)
	if prev and next then
		local alpha = (self.currentTime - prev.time) / (next.time - prev.time)
		alpha = math.clamp(alpha, 0, 1)
		cam.CFrame = prev.cframe:Lerp(next.cframe, alpha)
	elseif prev then
		cam.CFrame = prev.cframe
	elseif next then
		cam.CFrame = next.cframe
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
	local trackWidth = self.ui.area.AbsoluteSize.X - 10
	local x = 5 + (self.currentTime / Config.MaxTime) * trackWidth
	self.ui.playhead.Position = UDim2.new(0, x, 0, 2)
end

function module:startLoop()
	RunService.RenderStepped:Connect(function(dt)
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
			self.handles:dragUpdate()
		end

		if self.cameraMode then
			local cam = CameraResolver.get()
			if cam then
				workspace.CurrentCamera.CFrame = cam.CFrame
			end
		end

		self:updatePlayhead()
		self:updateTimeLabel()
	end)
end

return module
