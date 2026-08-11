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
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config

local module = {}
module.__index = module

local HANDLE_SIZE = Config.HandleSize or 0.5
local HANDLE_DISTANCE = Config.HandleDistance or 2
local MOUSE_SENSITIVITY = Config.MouseSensitivity or 1

local AXIS_COLORS = {
	X = (Theme and Theme.AxisX) or Color3.new(1, 0, 0),
	Y = (Theme and Theme.AxisY) or Color3.new(0, 1, 0),
	Z = (Theme and Theme.AxisZ) or Color3.new(0, 0.5, 1)
}

local AXIS_FACES = {
	X = Enum.NormalId.Right,
	Y = Enum.NormalId.Top,
	Z = Enum.NormalId.Front
}

local AXIS_DIRECTIONS = {
	X = Vector3.new(1, 0, 0),
	Y = Vector3.new(0, 1, 0),
	Z = Vector3.new(0, 0, 1)
}

function module.new()
	local self = setmetatable({}, module)
	self.handles = {}
	self.selectedTarget = nil
	self.visible = false
	self.activeAxis = nil
	self.dragStartCFrame = nil
	self.isDragging = false
	self.connections = {}
	self:build()
	self:show(false)
	return self
end

function module:getPlayerGui()
	local player = game:GetService("Players").LocalPlayer
	return player and player:FindFirstChildOfClass("PlayerGui")
end

function module:build()
	local faces = {
		X = Faces.new(Enum.NormalId.Left, Enum.NormalId.Right),
		Y = Faces.new(Enum.NormalId.Bottom, Enum.NormalId.Top),
		Z = Faces.new(Enum.NormalId.Back, Enum.NormalId.Front),
	}
	local directions = {
		[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
		[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
		[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
		[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
		[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
		[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	}
	for axis, color in pairs(AXIS_COLORS) do
		local gizmo = Instance.new("Handles")
		gizmo.Name = "CameraHandle_" .. axis
		gizmo.Style = Enum.HandlesStyle.Movement
		gizmo.Color3 = color
		gizmo.Transparency = 0.15
		gizmo.Faces = faces[axis]
		self.connections[axis .. "Down"] = gizmo.MouseButton1Down:Connect(function()
			if not self.visible or not self.selectedTarget or not self.selectedTarget.Parent then return end
			self.activeAxis = axis
			self.dragStartCFrame = self.selectedTarget.CFrame
			self.isDragging = true
		end)
		self.connections[axis .. "Drag"] = gizmo.MouseDrag:Connect(function(face, distance)
			if not self.isDragging or self.activeAxis ~= axis or not self.selectedTarget or not self.dragStartCFrame then return end
			local direction = directions[face]
			if not direction then return end
			self.selectedTarget.CFrame = self.dragStartCFrame + direction * distance
			local childCamera = self.selectedTarget:FindFirstChildOfClass("Camera")
			if childCamera then
				childCamera.CFrame = self.selectedTarget.CFrame
			end
		end)
		self.connections[axis .. "Up"] = gizmo.MouseButton1Up:Connect(function()
			if self.activeAxis == axis then
				self:stopDrag()
			end
		end)
		self.handles[axis] = gizmo
	end
end

function module:setTarget(target)
	self.selectedTarget = target
	for _, gizmo in pairs(self.handles) do
		gizmo.Adornee = target
	end
	if not target then
		self:show(false)
	end
end

function module:show(visible)
	self.visible = visible and self.selectedTarget ~= nil
	if not self.visible then
		self:stopDrag()
	end
	local playerGui = self:getPlayerGui()
	for _, gizmo in pairs(self.handles) do
		gizmo.Parent = self.visible and playerGui or nil
	end
end

function module:update()
	if not self.selectedTarget or not self.selectedTarget.Parent then
		self:show(false)
	end
end

function module:dragUpdate()
end

function module:stopDrag()
	self.isDragging = false
	self.activeAxis = nil
	self.dragStartCFrame = nil
end

function module:destroy()
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.connections = {}
	for _, gizmo in pairs(self.handles) do
		gizmo:Destroy()
	end
	self.handles = {}
end

return module
