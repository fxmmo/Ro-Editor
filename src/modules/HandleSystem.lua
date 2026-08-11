local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
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
	self.activeAxis = nil
	self.isDragging = false
	self.hoveredAxis = nil
	self.lastMouse = Vector2.new()
	self.selectedTarget = nil
	self.connections = {}
	self:build()
	self:setupGlobalEvents()
	return self
end

function module:setupGlobalEvents()
	self.connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.hoveredAxis or not self.selectedTarget then return end
		self:startDrag(self.hoveredAxis)
	end)

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

	RunService.RenderStepped:Connect(function()
		if not self.isDragging then
			self:checkHover()
		end
	end)
end

function module:build()
	local basePart = Instance.new("Part")
	basePart.Name = "HandleBase"
	basePart.Anchored = true
	basePart.CanCollide = false
	basePart.CanQuery = false
	basePart.CanTouch = false
	basePart.Transparency = 1
	basePart.Size = Vector3.new(0.1, 0.1, 0.1)
	basePart.Parent = workspace

	for axis, color in pairs(AXIS_COLORS) do
		local handle = Instance.new("Handle")
		handle.Name = "Handle_" .. axis
		handle.Style = Enum.HandleStyle.Movement
		handle.Massless = true
		handle.Color = color
		handle.Transparency = 0.3
		handle.Size = Vector3.new(HANDLE_SIZE, HANDLE_SIZE, HANDLE_SIZE)
		handle.Adornee = basePart
		handle.Face = AXIS_FACES[axis]
		handle.Parent = basePart

		self.handles[axis] = {
			handle = handle,
			base = basePart,
			color = color,
			direction = AXIS_DIRECTIONS[axis]
		}
	end
end

function module:checkHover()
	if not self.selectedTarget or not self.selectedTarget.Parent then
		self.hoveredAxis = nil
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local camera = workspace.CurrentCamera
	local closest, minDist = nil, math.huge
	for axis, data in pairs(self.handles) do
		local worldPos = self.selectedTarget.Position + (data.direction * HANDLE_DISTANCE)
		local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
		if onScreen then
			local dist = (Vector2.new(screenPos.X, screenPos.Y) - mouse).Magnitude
			if dist < minDist and dist < 30 then
				minDist = dist
				closest = axis
			end
		end
	end
	self.hoveredAxis = closest
end

function module:startDrag(axis)
	local data = self.handles[axis]
	if not data then return end
	self.activeAxis = axis
	self.isDragging = true
	self.lastMouse = UserInputService:GetMouseLocation()
	TweenService:Create(data.handle, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
		Transparency = 0.05
	}):Play()
end

function module:setTarget(target)
	self.selectedTarget = target
	if target then
		self:update()
	end
end

function module:show(visible)
	for _, data in pairs(self.handles) do
		data.base.Parent = visible and workspace or nil
	end
	if visible then
		self:update()
	end
end

function module:update()
	if not self.selectedTarget or not self.selectedTarget.Parent then return end
	for _, data in pairs(self.handles) do
		data.base.Position = self.selectedTarget.Position + (data.direction * HANDLE_DISTANCE)
	end
end

function module:dragUpdate()
	if not self.isDragging then return end
	if not self.activeAxis or not self.selectedTarget or not self.selectedTarget.Parent then
		self:stopDrag()
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local delta = mouse - self.lastMouse
	self.lastMouse = mouse

	local axisData = self.handles[self.activeAxis]
	if not axisData then return end

	local moveAmount = (delta.X + delta.Y) * 0.03 * MOUSE_SENSITIVITY
	self.selectedTarget.CFrame = self.selectedTarget.CFrame + (axisData.direction * moveAmount)

	local childCamera = self.selectedTarget:FindFirstChildOfClass("Camera")
	if childCamera then
		childCamera.CFrame = self.selectedTarget.CFrame
	end

	self:update()
end

function module:stopDrag()
	if self.isDragging and self.activeAxis then
		local axisData = self.handles[self.activeAxis]
		if axisData then
			TweenService:Create(axisData.handle, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				Transparency = 0.3
			}):Play()
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
	for _, data in pairs(self.handles) do
		if data.base then
			data.base:Destroy()
		end
	end
	self.handles = {}
end

return module
