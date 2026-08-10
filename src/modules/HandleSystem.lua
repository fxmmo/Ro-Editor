local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ThemeConfig = require(script.Parent.Theme_Config)
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config

local module = {}
module.__index = module

function module.new()
	local self = setmetatable({}, module)
	self.selectedTarget = nil
	self.isDragging = false
	self.activeFace = nil
	self.connections = {}

	self.handles = Instance.new("Handles")
	self.handles.Name = "CameraHandles"
	self.handles.Style = Enum.HandlesStyle.Movement
	self.handles.Color3 = Theme.AxisX -- base color; per-axis color isn't natively supported, see note below
	self.handles.Adornee = nil
	self.handles.Parent = workspace

	self:bindEvents()
	return self
end

function module:bindEvents()
	table.insert(self.connections, self.handles.MouseButton1Down:Connect(function(face)
		self.activeFace = face
		self.isDragging = true
	end))

	table.insert(self.connections, self.handles.MouseButton1Up:Connect(function()
		self.isDragging = false
		self.activeFace = nil
	end))

	table.insert(self.connections, self.handles.MouseDrag:Connect(function(face, distance)
		if not self.selectedTarget then return end
		local direction = self:faceToVector(face)
		self.selectedTarget.CFrame = self.selectedTarget.CFrame + direction * distance
	end))

	table.insert(self.connections, self.handles.MouseEnter:Connect(function(face)
		self.handles.Color3 = Theme.AxisX -- swap to a "hover" color if you want per-face feedback
	end))

	table.insert(self.connections, self.handles.MouseLeave:Connect(function(face)
		self.handles.Color3 = Theme.AxisX
	end))
end

function module:faceToVector(face)
	local map = {
		[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
		[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
		[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
		[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
		[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
		[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	}
	return map[face] or Vector3.new()
end

function module:setTarget(target)
	self.selectedTarget = target
	self.handles.Adornee = target
end

function module:show(visible)
	self.handles.Parent = visible and workspace or nil
end

function module:destroy()
	for _, conn in ipairs(self.connections) do
		conn:Disconnect()
	end
	self.connections = {}
	self.handles:Destroy()
end

return module