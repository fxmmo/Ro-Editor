local Dev = _G.__RoEditorDev
if not Dev then
	local _cache = {}
	Dev = {}
	function Dev:Import(url)
		if _cache[url] then
			return _cache[url]
		end
		local ok, result = pcall(function()
			local source = game:HttpGet(url, true)
			local chunk, compileError = loadstring(source)
			if not chunk then
				error(compileError or "compile failed")
			end
			return chunk()
		end)
		if not ok then
			error(result)
		end
		if not result then
			error("module returned nil: " .. url)
		end
		_cache[url] = result
		return result
	end
	_G.__RoEditorDev = Dev
end
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local BASE = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/"
local UIFactory = Dev:Import(BASE .. "modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import(BASE .. "configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Icons = Dev:Import(BASE .. "configs/Icon_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local module = {}
module.__index = module
local TRACK_PADDING = 8
local KF_LABEL_OFFSET = 180
local TIMELINE_AXIS_LEFT = TRACK_PADDING + KF_LABEL_OFFSET
local TIMELINE_AXIS_RIGHT = 26
local KEYFRAME_HOLD_DURATION = 0.45
local TRACK_RESIZE_MIN_TIME = 0.1
local TRACK_RESIZE_HANDLE_WIDTH = 10
local function getMaxTime()
	return Config.MaxTime or 10
end
function module:setKeyframeProperties(data)
	if not data then
		self:clearKeyframeProperties()
		return
	end
	local position = data.position or (data.cframe and data.cframe.Position)
	local orientation = data.orientation
	if not orientation and data.cframe then
		local rx, ry, rz = data.cframe:ToOrientation()
		orientation = Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
	end
	if not position or not orientation or not self.propertyFields then return end
	self.propertyKeyframe = data
	self.propertiesInfo.Text = string.format("%s  •  %.2fs", string.upper(data.cameraName or "CAMERA"), data.time or 0)
	self.propertiesInfo.TextColor3 = Theme.TextDim
	self.propertiesSection.Visible = true
		local values = {
			positionX = position.X,
			positionY = position.Y,
			positionZ = position.Z,
			rotationX = orientation.X,
			rotationY = orientation.Y,
			rotationZ = orientation.Z,
		}
		local isObject = data.object == true or data.size ~= nil or data.color ~= nil or data.transparency ~= nil
		for _, field in pairs(self.basePropertyFields or {}) do
			field.Visible = isObject
		end
		if isObject then
			if data.transparency ~= nil then values.transparency = data.transparency end
			if data.color then
				values.colorR = data.color.R * 255
				values.colorG = data.color.G * 255
				values.colorB = data.color.B * 255
			end
			if data.size then
				values.sizeX = data.size.X
				values.sizeY = data.size.Y
				values.sizeZ = data.size.Z
			end
		end
			for key, value in pairs(values) do
				local field = (self.propertyFields and self.propertyFields[key]) or (self.basePropertyFields and self.basePropertyFields[key])
				if field and not field:IsFocused() then
					field.Text = string.format("%.3f", value)
				end
			end
		self.easingValue = data.easing or "EaseInOut"
		if self.easingButton then
			self:setButtonLabel(self.easingButton, "EASING: " .. string.upper(self.easingValue))
		end

end

function module:clearKeyframeProperties()
	self.propertyKeyframe = nil
	if self.propertiesInfo then
		self.propertiesInfo.Text = "SELECT A KEYFRAME TO EDIT PROPERTIES"
		self.propertiesInfo.TextColor3 = Theme.TextMuted
	end
	if self.propertiesSection then
			self.propertiesSection.Visible = false
		end
			for _, field in pairs(self.basePropertyFields or {}) do
			field.Visible = false
			field.Text = ""
		end
	end

function module:setEditTool(mode)
	local function updateButtons(buttons)
		if not buttons then return end
		for buttonMode, button in pairs(buttons) do
			local active = buttonMode == mode
			button.BackgroundColor3 = active and Theme.Accent or Theme.Panel
			button.TextColor3 = active and Theme.Text or Theme.TextDim
			local label = UIFactory.getLabel(button)
			if label then
				label.TextColor3 = active and Theme.Text or Theme.TextDim
			end
			local icon = UIFactory.getIcon(button)
			if icon then
				icon.ImageColor3 = active and Theme.Text or Theme.TextDim
			end
		end
	end
		updateButtons(self.editToolButtons)
		updateButtons(self.topbarEditToolButtons)
		updateButtons(self.editModalButtons)
	self.activeEditTool = mode
end

function module:setEditSectionVisible(visible)
	if not self.editSection or not self.modalPanel then return false end
	self.editSectionOpen = visible and true or false
	self.editSection.Visible = self.editSectionOpen
	local offset = self.editSectionOpen and 89 or 0
	self.propertiesInfo.Position = UDim2.new(0, 12, 0, 169 + offset)
	self.propertiesSection.Position = UDim2.new(0, 12, 0, 193 + offset)
	self.modalPanel.Size = UDim2.new(0, 320, 0, 580 + offset)
	if self.modalOpen then
		self:repositionModal()
	end
	return self.editSectionOpen
end

function module:toggleEditSection()
	return self:setEditSectionVisible(not self.editSectionOpen)
end

function module:setViewToggle(on, callback)
	local t = self.viewToggle
	if not t then return end
	t.on = on and true or false
	if callback ~= nil then t.callback = callback end

	TweenService:Create(t.knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = t.on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
		BackgroundColor3 = t.on and Theme.Accent or Theme.TextDim,
	}):Play()
	TweenService:Create(t.track, TweenInfo.new(0.18), {
		BackgroundColor3 = t.on and Theme.Accent:Lerp(Theme.Background, 0.6) or Theme.PanelDark,
	}):Play()
end

function module:openCamerasModal()
	if self.modalOpen then return end
	self.modalOpen = true
	self:repositionModal()
	self.modalBackdrop.Visible = true
	self.modalPanel.Visible = true
	self.modalBackdrop.BackgroundTransparency = 0.55
	self.modalPanel.Position = self.modalPanel.Position + UDim2.new(0, 0, 0, -6)
	TweenService:Create(self.modalPanel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = self._modalTargetPos
	}):Play()
end

function module:closeCamerasModal()
	if not self.modalOpen then return end
	self.modalOpen = false
	TweenService:Create(self.modalBackdrop, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
	local current = self.modalPanel.Position
	TweenService:Create(self.modalPanel, TweenInfo.new(0.15), {
		Position = current + UDim2.new(0, 0, 0, -6)
	}):Play()
	task.delay(0.16, function()
		if not self.modalOpen then
			self.modalPanel.Visible = false
			self.modalBackdrop.Visible = false
		end
	end)
end

function module:repositionModal()
	local btn = self.camerasButton
	local btnAbs = btn.AbsolutePosition
	local btnSize = btn.AbsoluteSize
	local panel = self.modalPanel

	local panelHeight = self.editSectionOpen and 517 or 428
	panel.Size = UDim2.new(0, 320, 0, panelHeight)

	local desiredX = btnAbs.X + btnSize.X - 320
	local desiredY = btnAbs.Y + btnSize.Y + 6

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		or Vector2.new(panel.Parent.AbsoluteSize.X, panel.Parent.AbsoluteSize.Y)
	desiredX = math.clamp(desiredX, 8, math.max(8, viewport.X - 328))
	desiredY = math.clamp(desiredY, 8, math.max(8, viewport.Y - panelHeight - 8))

	self._modalTargetPos = UDim2.new(0, desiredX, 0, desiredY)
	panel.Position = self._modalTargetPos
end

function module:setTimelineMinimized(minimized)
	self.timelineMinimized = minimized and true or false
	if not self.timelineMinimized and self.timelinePanel and self.timelinePanel.Size.Y.Offset > 34 then
		self.timelineExpandedHeight = self.timelinePanel.Size.Y.Offset
	end
	local panelHeight = self.timelineMinimized and 34 or (self.timelineExpandedHeight or 160)
	if self.timelinePanel then
		self.timelinePanel.Size = UDim2.new(1, 0, 0, panelHeight)
		self.timelinePanel.Position = UDim2.new(0, 0, 1, -panelHeight)
	end
	if self.area then
		self.area.Visible = not self.timelineMinimized
	end
	if self.timelineMinimizeButton then
		self.timelineMinimizeButton.Text = ""
		local icon = self.timelineMinimizeButton:FindFirstChild("Icon")
		if icon then
			icon.Image = self.timelineMinimized and Icons.Maximize or Icons.Minus
		end
	end
	if not self.timelineMinimized then
		self:refreshTimelineAxis()
	end
	return self.timelineMinimized
end


return module
