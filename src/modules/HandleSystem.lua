local Players = game:GetService("Players")
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

local module = {}
module.__index = module

local FACE_DIRECTIONS = {
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
}

function module.new()
	local self = setmetatable({}, module)
	self.handle = Instance.new("Handles")
	self.handle.Name = "CameraMovementHandles"
	self.handle.Style = Enum.HandlesStyle.Movement
	self.handle.Color3 = (Theme and Theme.Accent) or Color3.fromRGB(0, 170, 255)
	self.handle.Transparency = 0
	self.handle.Faces = Faces.new(
		Enum.NormalId.Left,
		Enum.NormalId.Right,
		Enum.NormalId.Bottom,
		Enum.NormalId.Top,
		Enum.NormalId.Back,
		Enum.NormalId.Front
	)
	self.selectedTarget = nil
	self.dragStartCFrame = nil
	self.dragFace = nil
	self.isDragging = false
	self.visible = false
	self.onChanged = nil
	self.connections = {}
	self:bindEvents()
	self:show(false)
	return self
end

function module:getPlayerGui()
	local player = Players.LocalPlayer
	if not player then return nil end
	return player:FindFirstChildOfClass("PlayerGui")
end

function module:bindEvents()
	self.connections.down = self.handle.MouseButton1Down:Connect(function(face)
		if not self.visible or not self.selectedTarget or not self.selectedTarget.Parent then return end
		self.dragFace = face
		self.dragStartCFrame = self.selectedTarget.CFrame
		self.isDragging = true
	end)
	self.connections.drag = self.handle.MouseDrag:Connect(function(face, distance)
		if not self.isDragging or face ~= self.dragFace then return end
		if not self.selectedTarget or not self.selectedTarget.Parent or not self.dragStartCFrame then
			self:stopDrag()
			return
		end
		local direction = FACE_DIRECTIONS[face]
		if not direction then return end
		local cframe = self.dragStartCFrame + direction * distance
		self.selectedTarget.CFrame = cframe
		local childCamera = self.selectedTarget:FindFirstChildOfClass("Camera")
		if childCamera then
			childCamera.CFrame = cframe
		end
		if self.onChanged then
			self.onChanged(self.selectedTarget, cframe)
		end
	end)
	self.connections.up = self.handle.MouseButton1Up:Connect(function()
		self:stopDrag()
	end)
end

function module:setTarget(target)
	self.selectedTarget = target
	self.handle.Adornee = target
	if not target then
		self:show(false)
	end
end

function module:show(visible)
	self.visible = visible and self.selectedTarget ~= nil
	if not self.visible then
		self:stopDrag()
	end
	self.handle.Parent = self.visible and self:getPlayerGui() or nil
end

function module:update()
	if not self.selectedTarget or not self.selectedTarget.Parent then
		self:setTarget(nil)
	end
end

function module:dragUpdate()
end

function module:stopDrag()
	self.isDragging = false
	self.dragFace = nil
	self.dragStartCFrame = nil
end

function module:destroy()
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end
	self.connections = {}
	self.handle:Destroy()
end

return module
