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

local AXES = {
	{
		name = "X",
		color = (Theme and Theme.AxisX) or Color3.fromRGB(255, 82, 82),
		faces = Faces.new(Enum.NormalId.Left, Enum.NormalId.Right),
	},
	{
		name = "Y",
		color = (Theme and Theme.AxisY) or Color3.fromRGB(105, 235, 110),
		faces = Faces.new(Enum.NormalId.Bottom, Enum.NormalId.Top),
	},
	{
		name = "Z",
		color = (Theme and Theme.AxisZ) or Color3.fromRGB(82, 145, 255),
		faces = Faces.new(Enum.NormalId.Back, Enum.NormalId.Front),
	},
}

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
	self.handles = {}
	self.connections = {}
	self.selectedTarget = nil
	self.dragStartCFrame = nil
	self.dragFace = nil
	self.isDragging = false
	self.visible = false
	self.onChanged = nil
	self:build()
	self:show(false)
	return self
end

function module:getPlayerGui()
	local player = Players.LocalPlayer
	if not player then return nil end
	return player:FindFirstChildOfClass("PlayerGui")
end

function module:build()
	for _, axis in ipairs(AXES) do
		local handle = Instance.new("Handles")
		handle.Name = "CameraHandle_" .. axis.name
		handle.Style = Enum.HandlesStyle.Movement
		handle.Color3 = axis.color
		handle.Transparency = 0
		handle.Faces = axis.faces
		self.connections[#self.connections + 1] = handle.MouseButton1Down:Connect(function(face)
			if not self.visible or not self.selectedTarget or not self.selectedTarget.Parent then return end
			self.dragFace = face
			self.dragStartCFrame = self.selectedTarget.CFrame
			self.isDragging = true
		end)
		self.connections[#self.connections + 1] = handle.MouseDrag:Connect(function(face, distance)
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
		self.connections[#self.connections + 1] = handle.MouseButton1Up:Connect(function()
			self:stopDrag()
		end)
		self.handles[#self.handles + 1] = handle
	end
end

function module:setTarget(target)
	self.selectedTarget = target
	for _, handle in ipairs(self.handles) do
		handle.Adornee = target
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
	local parent = self.visible and self:getPlayerGui() or nil
	for _, handle in ipairs(self.handles) do
		handle.Parent = parent
	end
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
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	for _, handle in ipairs(self.handles) do
		handle:Destroy()
	end
	self.handles = {}
end

return module
