local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Dev = loadstring(game:HttpGet(""))()
local ThemeConfig = require(script.Parent.ThemeConfig)
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config

local module = {}
module.__index = module

function module.new()
	local self = setmetatable({}, module)
	self.model = Instance.new("Model")
	self.model.Name = "CameraHandles"
	self.selectedTarget = nil
	self.activeAxis = nil
	self.isDragging = false
	self.lastMouse = Vector2.new()
	self.handles = {}
	self:build()
	return self
end

function module:createHandle(axis, color, direction)
	local template = workspace:FindFirstChild("handle")
	local handle
	if template then
		handle = template:Clone()
	else
		handle = Instance.new("Part")
		handle.Shape = Enum.PartType.Ball
		handle.Material = Enum.Material.Neon
	end
	handle.Name = "Handle_" .. axis
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanQuery = true
	handle.CanTouch = false
	handle.Size = Vector3.new(Config.HandleSize, Config.HandleSize, Config.HandleSize)
	handle.Color = color
	handle.Transparency = 0.1
	handle.Parent = self.model

	local beam = Instance.new("Part")
	beam.Name = "Beam_" .. axis
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Size = Vector3.new(0.1, 0.1, Config.HandleDistance)
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.3
	beam.Parent = self.model

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 100
	clickDetector.Parent = handle

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = handle

	local touchButton = Instance.new("TextButton")
	touchButton.Size = UDim2.new(1, 0, 1, 0)
	touchButton.BackgroundTransparency = 1
	touchButton.Text = ""
	touchButton.Parent = billboard

	self.handles[axis] = {
		part = handle,
		beam = beam,
		direction = direction,
		clickDetector = clickDetector,
		touchButton = touchButton,
		color = color,
	}

	self:bindHandleEvents(axis)
	return self.handles[axis]
end

function module:build()
	self:createHandle("X", Theme.AxisX, Vector3.new(1, 0, 0))
	self:createHandle("Y", Theme.AxisY, Vector3.new(0, 1, 0))
	self:createHandle("Z", Theme.AxisZ, Vector3.new(0, 0, 1))
end

function module:bindHandleEvents(axis)
	local data = self.handles[axis]

	local function highlight(on)
		local target = on and Vector3.new(Config.HandleSize * 1.4, Config.HandleSize * 1.4, Config.HandleSize * 1.4)
			or Vector3.new(Config.HandleSize, Config.HandleSize, Config.HandleSize)
		TweenService:Create(data.part, TweenInfo.new(0.15), {Size = target}):Play()
	end

	data.clickDetector.MouseHoverEnter:Connect(function() highlight(true) end)
	data.clickDetector.MouseHoverLeave:Connect(function()
		if self.activeAxis ~= axis then highlight(false) end
	end)

	data.touchButton.MouseButton1Down:Connect(function()
		self.activeAxis = axis
		self.isDragging = true
		self.lastMouse = UserInputService:GetMouseLocation()
		highlight(true)
	end)

	data.touchButton.MouseButton1Up:Connect(function()
		if self.activeAxis == axis then
			self.activeAxis = nil
			highlight(false)
		end
	end)
end

function module:setTarget(target)
	self.selectedTarget = target
end

function module:show(visible)
	self.model.Parent = visible and workspace or nil
end

function module:update()
	if not self.selectedTarget or not self.selectedTarget.Parent then return end
	local pos = self.selectedTarget.Position

	self.handles.X.part.CFrame = CFrame.new(pos + Vector3.new(Config.HandleDistance, 0, 0))
	self.handles.Y.part.CFrame = CFrame.new(pos + Vector3.new(0, Config.HandleDistance, 0))
	self.handles.Z.part.CFrame = CFrame.new(pos + Vector3.new(0, 0, Config.HandleDistance))

	self.handles.X.beam.CFrame = CFrame.new(pos + Vector3.new(Config.HandleDistance / 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0)
	self.handles.Y.beam.CFrame = CFrame.new(pos + Vector3.new(0, Config.HandleDistance / 2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
	self.handles.Z.beam.CFrame = CFrame.new(pos + Vector3.new(0, 0, Config.HandleDistance / 2))
end

function module:dragUpdate()
	if not self.isDragging or not self.activeAxis or not self.selectedTarget then return end
	local mouse = UserInputService:GetMouseLocation()
	local delta = mouse - self.lastMouse
	self.lastMouse = mouse

	local axisData = self.handles[self.activeAxis]
	local moveAmount = (delta.X - delta.Y) * 0.05 * Config.MouseSensitivity
	self.selectedTarget.Position += axisData.direction * moveAmount
end

function module:stopDrag()
	self.isDragging = false
	self.activeAxis = nil
end

return module
