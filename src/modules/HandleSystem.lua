local Dev = _G.__RoEditorDev
if not Dev then
	Dev = {}
	function Dev:Import(url)
		local source = game:HttpGet(url, true)
		local chunk, compileError = loadstring(source)
		if not chunk then
			error(compileError or "compile failed")
		end
		local result = chunk()
		if not result then
			error("module returned nil: " .. url)
		end
		return result
	end
	_G.__RoEditorDev = Dev
end
local Players = game:GetService("Players")
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

local ROTATION_AXES = Axes.new(Enum.Axis.X, Enum.Axis.Y, Enum.Axis.Z)

local FACE_DIRECTIONS = {
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
}

local AXIS_VECTORS = {
	[Enum.Axis.X] = Vector3.new(1, 0, 0),
	[Enum.Axis.Y] = Vector3.new(0, 1, 0),
	[Enum.Axis.Z] = Vector3.new(0, 0, 1),
}

function module.new()
	local self = setmetatable({}, module)
	self.handles = {}
		self.arcHandles = nil
		self.scaleHandles = nil
		self.connections = {}
		self.selectedTarget = nil
		self.dragStartCFrame = nil
		self.dragStartSize = nil
		self.dragFace = nil
		self.dragAxis = nil
		self.isDragging = false
		self.visible = false
		self.mode = "move"
	self.onChanged = nil
	self.onDragStateChanged = nil
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
			if not self.visible or self.mode ~= "move" or not self.selectedTarget or not self.selectedTarget.Parent then return end
			self.dragFace = face
			self.dragStartCFrame = self.selectedTarget.CFrame
			self:_setDragging(true)
		end)
		self.connections[#self.connections + 1] = handle.MouseDrag:Connect(function(face, distance)
			if not self.isDragging or self.mode ~= "move" or face ~= self.dragFace then return end
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

	local arcHandles = Instance.new("ArcHandles")
	arcHandles.Name = "CameraArcHandles"
	arcHandles.Axes = ROTATION_AXES
	arcHandles.Color3 = Theme.Accent or Color3.fromRGB(0, 170, 255)
	arcHandles.Transparency = 0
	self.connections[#self.connections + 1] = arcHandles.MouseButton1Down:Connect(function(axis)
		if not self.visible or self.mode ~= "rotate" or not self.selectedTarget or not self.selectedTarget.Parent then return end
		self.dragAxis = axis
		self.dragStartCFrame = self.selectedTarget.CFrame
		self:_setDragging(true)
	end)
	self.connections[#self.connections + 1] = arcHandles.MouseDrag:Connect(function(axis, relativeAngle)
		if not self.isDragging or self.mode ~= "rotate" or axis ~= self.dragAxis then return end
		if not self.selectedTarget or not self.selectedTarget.Parent or not self.dragStartCFrame then
			self:stopDrag()
			return
		end
		local axisVector = AXIS_VECTORS[axis]
		if not axisVector then return end
		local cframe = self.dragStartCFrame * CFrame.fromAxisAngle(axisVector, relativeAngle)
		self.selectedTarget.CFrame = cframe
		local childCamera = self.selectedTarget:FindFirstChildOfClass("Camera")
		if childCamera then
			childCamera.CFrame = cframe
		end
		if self.onChanged then
			self.onChanged(self.selectedTarget, cframe)
		end
	end)
	self.connections[#self.connections + 1] = arcHandles.MouseButton1Up:Connect(function()
		self:stopDrag()
	end)
	self.arcHandles = arcHandles
	local scaleHandles = Instance.new("Handles")
	scaleHandles.Name = "BasePartScaleHandles"
	scaleHandles.Style = Enum.HandlesStyle.Resize
	scaleHandles.Color3 = Theme.Warning or Color3.fromRGB(255, 188, 66)
	scaleHandles.Transparency = 0
	scaleHandles.Faces = Faces.new(Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Bottom, Enum.NormalId.Top, Enum.NormalId.Back, Enum.NormalId.Front)
	self.connections[#self.connections + 1] = scaleHandles.MouseButton1Down:Connect(function(face)
		if not self.visible or self.mode ~= "scale" or not self.selectedTarget or not self.selectedTarget.Parent then return end
		self.dragFace = face
		self.dragStartSize = self.selectedTarget.Size
		self:_setDragging(true)
	end)
	self.connections[#self.connections + 1] = scaleHandles.MouseDrag:Connect(function(face, distance)
		if not self.isDragging or self.mode ~= "scale" or face ~= self.dragFace then return end
		if not self.selectedTarget or not self.selectedTarget.Parent or not self.dragStartSize then
			self:stopDrag()
			return
		end
		local axis = FACE_DIRECTIONS[face]
		if not axis then return end
		local size = self.dragStartSize
		local delta = distance * 2
		if axis.X ~= 0 then
			size = Vector3.new(math.max(0.1, self.dragStartSize.X + delta), size.Y, size.Z)
		elseif axis.Y ~= 0 then
			size = Vector3.new(size.X, math.max(0.1, self.dragStartSize.Y + delta), size.Z)
		elseif axis.Z ~= 0 then
			size = Vector3.new(size.X, size.Y, math.max(0.1, self.dragStartSize.Z + delta))
		end
		self.selectedTarget.Size = size
		if self.onChanged then
			self.onChanged(self.selectedTarget, self.selectedTarget.CFrame, size)
		end
	end)
	self.connections[#self.connections + 1] = scaleHandles.MouseButton1Up:Connect(function()
		self:stopDrag()
	end)
	self.scaleHandles = scaleHandles
end

function module:setMode(mode)
	if mode == "rotate" then
		self.mode = "rotate"
	elseif mode == "scale" then
		self.mode = "scale"
	else
		self.mode = "move"
	end
	if self.isDragging then
		self:stopDrag()
	end
	self:_updateParents()
end

function module:setTarget(target)
	self.selectedTarget = target
	for _, handle in ipairs(self.handles) do
		handle.Adornee = target
	end
		if self.arcHandles then
			self.arcHandles.Adornee = target
		end
		if self.scaleHandles then
			self.scaleHandles.Adornee = target
		end
	if not target then
		self:show(false)
	else
		self:_updateParents()
	end
end

function module:_updateParents()
	local parent = self.visible and self:getPlayerGui() or nil
	for _, handle in ipairs(self.handles) do
		handle.Parent = self.mode == "move" and parent or nil
	end
		if self.arcHandles then
			self.arcHandles.Parent = self.mode == "rotate" and parent or nil
		end
		if self.scaleHandles then
			self.scaleHandles.Parent = self.mode == "scale" and parent or nil
		end
end

function module:show(visible)
	self.visible = visible and self.selectedTarget ~= nil
	if not self.visible then
		self:stopDrag()
	end
	self:_updateParents()
end

function module:update()
	if not self.selectedTarget or not self.selectedTarget.Parent then
		self:setTarget(nil)
	end
end

function module:dragUpdate()
end

function module:_setDragging(dragging)
	dragging = dragging and true or false
	if self.isDragging == dragging then return end
	self.isDragging = dragging
	if self.onDragStateChanged then
		self.onDragStateChanged(dragging)
	end
end

function module:stopDrag()
	self.dragFace = nil
		self.dragAxis = nil
		self.dragStartCFrame = nil
		self.dragStartSize = nil
		self:_setDragging(false)
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
		if self.arcHandles then
			self.arcHandles:Destroy()
			self.arcHandles = nil
		end
		if self.scaleHandles then
			self.scaleHandles:Destroy()
			self.scaleHandles = nil
		end
end

return module
