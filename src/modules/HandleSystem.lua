local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ThemeConfig = require(script.Parent.Parent.configs.Theme_Config)
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local module = {}
module.__index = module

local HANDLE_SIZE = Config.HandleSize or 0.5
local HANDLE_DISTANCE = Config.HandleDistance or 2
local MOUSE_SENSITIVITY = Config.MouseSensitivity or 1

function module.new()
	local self = setmetatable({}, module)
	self.model = Instance.new("Model")
	self.model.Name = "CameraHandles"
	self.selectedTarget = nil
	self.activeAxis = nil
	self.isDragging = false
	self.lastMouse = Vector2.new()
	self.handles = {}
	self.connections = {}
	self:build()
	
	self:setupGlobalEvents()
	
	return self
end

function module:setupGlobalEvents()
	self.connections.InputChanged = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.isDragging then
			self:dragUpdate()
		end
	end)
	
	self.connections.InputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:stopDrag()
		end
	end)
end

function module:createHandle(axis, color, direction)
	local handle = Instance.new("Part")
	handle.Name = "Handle_" .. axis
	handle.Anchored = true
	handle.CanCollide = false
	handle.CanQuery = true
	handle.CanTouch = false
	handle.Size = Vector3.new(HANDLE_SIZE, HANDLE_SIZE, HANDLE_SIZE)
	handle.Color = color
	handle.Material = Enum.Material.Neon
	handle.Transparency = 0.1
	handle.Parent = self.model

	local selection = Instance.new("SelectionBox")
	selection.Adornee = handle
	selection.Color3 = color
	selection.Transparency = 0.5
	selection.Visible = false
	selection.Parent = handle

	local beam = Instance.new("Part")
	beam.Name = "Beam_" .. axis
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Size = Vector3.new(0.1, 0.1, HANDLE_DISTANCE)
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.3
	beam.Parent = self.model

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 50
	clickDetector.Parent = handle

	self.handles[axis] = {
		part = handle,
		beam = beam,
		direction = direction,
		clickDetector = clickDetector,
		selection = selection,
		color = color,
	}

	self:bindHandleEvents(axis)
	return self.handles[axis]
end

function module:bindHandleEvents(axis)
	local data = self.handles[axis]

	local function highlight(on)
		local targetSize = on and Vector3.new(HANDLE_SIZE * 1.3, HANDLE_SIZE * 1.3, HANDLE_SIZE * 1.3) 
			or Vector3.new(HANDLE_SIZE, HANDLE_SIZE, HANDLE_SIZE)
		
		local tween = TweenService:Create(data.part, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Size = targetSize,
			Transparency = on and 0.05 or 0.1
		})
		tween:Play()
		
		if data.selection then
			data.selection.Visible = on
		end
	end

	data.clickDetector.MouseHoverEnter:Connect(function()
		if not self.isDragging then
			highlight(true)
		end
	end)

	data.clickDetector.MouseHoverLeave:Connect(function()
		if not self.isDragging then
			highlight(false)
		end
	end)

	data.clickDetector.MouseClick:Connect(function(player)
		if player ~= game.Players.LocalPlayer then return end
		
		self.activeAxis = axis
		self.isDragging = true
		self.lastMouse = UserInputService:GetMouseLocation()
		highlight(true)
		
		data.part.Transparency = 0.2
	end)
end

function module:build()
	local axisXColor = (Theme and Theme.AxisX) or Color3.new(1, 0, 0)
	local axisYColor = (Theme and Theme.AxisY) or Color3.new(0, 1, 0)
	local axisZColor = (Theme and Theme.AxisZ) or Color3.new(0, 0.5, 1)
	
	self:createHandle("X", axisXColor, Vector3.new(1, 0, 0))
	self:createHandle("Y", axisYColor, Vector3.new(0, 1, 0))
	self:createHandle("Z", axisZColor, Vector3.new(0, 0, 1))
end

function module:setTarget(target)
	self.selectedTarget = target
	if target then
		self:update()
	end
end

function module:show(visible)
	self.model.Parent = visible and workspace or nil
	if visible then
		self:update()
	end
end

function module:update()
	if not self.selectedTarget or not self.selectedTarget.Parent then return end
	
	local pos = self.selectedTarget.Position
	
	if self.handles.X then
		self.handles.X.part.CFrame = CFrame.new(pos + Vector3.new(HANDLE_DISTANCE, 0, 0))
		self.handles.X.beam.CFrame = CFrame.new(pos + Vector3.new(HANDLE_DISTANCE/2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0)
	end
	
	if self.handles.Y then
		self.handles.Y.part.CFrame = CFrame.new(pos + Vector3.new(0, HANDLE_DISTANCE, 0))
		self.handles.Y.beam.CFrame = CFrame.new(pos + Vector3.new(0, HANDLE_DISTANCE/2, 0)) * CFrame.Angles(math.rad(90), 0, 0)
	end
	
	if self.handles.Z then
		self.handles.Z.part.CFrame = CFrame.new(pos + Vector3.new(0, 0, HANDLE_DISTANCE))
		self.handles.Z.beam.CFrame = CFrame.new(pos + Vector3.new(0, 0, HANDLE_DISTANCE/2))
	end
end

function module:dragUpdate()
	if not self.isDragging or not self.activeAxis or not self.selectedTarget then 
		self:stopDrag()
		return 
	end
	
	local mouse = UserInputService:GetMouseLocation()
	local delta = mouse - self.lastMouse
	self.lastMouse = mouse

	local axisData = self.handles[self.activeAxis]
	if not axisData then return end
	
	local moveAmount = (delta.X + delta.Y) * 0.03 * MOUSE_SENSITIVITY
	
	self.selectedTarget.Position += axisData.direction * moveAmount
	
	self:update()
end

function module:stopDrag()
	if self.isDragging and self.activeAxis then
		local axisData = self.handles[self.activeAxis]
		if axisData then
			axisData.part.Transparency = 0.1
			axisData.part.Size = Vector3.new(HANDLE_SIZE, HANDLE_SIZE, HANDLE_SIZE)
			if axisData.selection then
				axisData.selection.Visible = false
			end
		end
	end
	
	self.isDragging = false
	self.activeAxis = nil
end

function module:destroy()
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.connections = {}
	
	if self.model then
		self.model:Destroy()
	end
end

return module