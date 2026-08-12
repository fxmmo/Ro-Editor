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
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local module = {}
module.__index = module

local TRACK_PADDING = 8
local KF_LABEL_OFFSET = 100
local TIMELINE_AXIS_LEFT = TRACK_PADDING + KF_LABEL_OFFSET
local TIMELINE_AXIS_RIGHT = 26

local function getMaxTime()
	return Config.MaxTime or 10
end

local function getTimelineAxis(areaWidth)
	local width = math.max(areaWidth - TIMELINE_AXIS_LEFT - TIMELINE_AXIS_RIGHT, 1)
	return TIMELINE_AXIS_LEFT, width
end

local function xToTime(absX, areaAbsX, areaWidth)
	local maxTime = getMaxTime()
	local left, width = getTimelineAxis(areaWidth)
	local n = math.clamp((absX - areaAbsX - left) / width, 0, 1)
	return n * maxTime
end

local function timeToX(t, areaWidth)
	local maxTime = getMaxTime()
	local left, width = getTimelineAxis(areaWidth)
	local clamped = math.clamp(t, 0, maxTime)
	return left + (clamped / maxTime) * width
end

function module.new()
	local self = setmetatable({}, module)
	local player = Players.LocalPlayer
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "StudioTimelineSystem"
	self.gui.ResetOnSpawn = false
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = player:WaitForChild("PlayerGui")
	self.modalOpen = false
	self.tracks = {}
	self.activeCameraName = nil
	self.propertyFields = {}
	self.propertyKeyframe = nil
	return self
end

function module:timeToX(t)
	return timeToX(t, self.area.AbsoluteSize.X)
end

function module:xToTime(absX)
	return xToTime(absX, self.area.AbsolutePosition.X, self.area.AbsoluteSize.X)
end

function module:buildTopBar()
	local bar = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.StudioToolbar or Theme.Header,
		Name = "StudioTopBar",
		ZIndex = 10,
	})
	UIFactory.stroke(bar, Theme.Border, 1)
	UIFactory.shadow(bar, 0.1)
	local barGradient = Instance.new("UIGradient")
	barGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.Header),
		ColorSequenceKeypoint.new(1, Theme.StudioToolbar or Theme.Header),
	}
	barGradient.Rotation = 90
	barGradient.Parent = bar
	local mark = UIFactory.frame({
		Parent = bar,
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(0, 10, 0.5, -13),
		Color = Theme.Accent,
		Corner = 5,
		ZIndex = 11,
	})
	UIFactory.label({
		Parent = mark,
		Text = "C",
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		Color = Color3.new(1, 1, 1),
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 12,
	})
	UIFactory.label({
		Parent = bar,
		Position = UDim2.new(0, 46, 0, 5),
		Size = UDim2.new(0, 155, 0, 17),
		Text = "Camera Animator",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Color = Theme.Text,
		ZIndex = 11,
	})
	UIFactory.label({
		Parent = bar,
		Position = UDim2.new(0, 46, 0, 22),
		Size = UDim2.new(0, 155, 0, 12),
		Text = "ANIMATION EDITOR",
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 11,
	})
	local function menu(text, x, width)
		local button = Instance.new("TextButton")
		button.Name = text .. "Menu"
		button.Size = UDim2.new(0, width, 0, 26)
		button.Position = UDim2.new(0, x, 0.5, -13)
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 10
		button.TextColor3 = Theme.TextDim
		button.Text = text
		button.AutoButtonColor = false
		button.Parent = bar
		button.ZIndex = 11
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = Theme.Panel
			button.BackgroundTransparency = 0
			button.TextColor3 = Theme.Text
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
			button.TextColor3 = Theme.TextDim
		end)
		UIFactory.corner(button, 4)
		return button
	end
	menu("FILE", 214, 42)
	menu("EDIT", 258, 42)
	menu("VIEW", 302, 45)
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0, 1, 0, 22)
	divider.Position = UDim2.new(0, 361, 0.5, -11)
	divider.BackgroundColor3 = Theme.StudioSeparator or Theme.Border
	divider.BorderSizePixel = 0
	divider.Parent = bar
	divider.ZIndex = 11
	UIFactory.label({
		Parent = bar,
		Position = UDim2.new(0, 375, 0, 0),
		Size = UDim2.new(0, 160, 1, 0),
		Text = "CAMERA SEQUENCER",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		Color = Theme.TextDim,
		ZIndex = 11,
	})
	self.camerasButton = UIFactory.button({
		Parent = bar,
		Position = UDim2.new(1, -142, 0.5, -13),
		Size = UDim2.new(0, 128, 0, 26),
		Text = "CAMERAS  ▾",
		Color = Theme.Panel,
		Corner = 4,
		TextSize = 10,
		ZIndex = 11,
	})
	self:buildStudioRibbon()
	self:buildCamerasModal()
	self:buildTimelinePanel()
	self:buildPropertiesPanel()
	return bar
end

function module:buildStudioRibbon()
	local ribbon = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 27),
		Position = UDim2.new(0, 0, 0, 42),
		Color = Theme.StudioRibbon or Theme.PanelDark,
		Name = "StudioRibbon",
		ZIndex = 9,
	})
	UIFactory.stroke(ribbon, Theme.Border, 1)
	local function ribbonLabel(text, x, width, accent)
		local frame = UIFactory.frame({
			Parent = ribbon,
			Size = UDim2.new(0, width, 0, 19),
			Position = UDim2.new(0, x, 0.5, -9),
			Color = accent and Theme.Panel or Theme.StudioRibbon or Theme.PanelDark,
			Corner = 3,
			ZIndex = 10,
		})
		if accent then
			UIFactory.stroke(frame, Theme.Accent, 1, 0.25)
		end
		UIFactory.label({
			Parent = frame,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 8,
			Color = accent and Theme.Text or Theme.TextMuted,
			XAlign = Enum.TextXAlignment.Center,
			ZIndex = 11,
		})
	end
	UIFactory.label({
		Parent = ribbon,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 68, 1, 0),
		Text = "TOOLS",
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 10,
	})
	ribbonLabel("SELECT", 66, 60, true)
	ribbonLabel("MOVE", 130, 52, false)
	ribbonLabel("KEYFRAME", 186, 72, false)
	local separator = Instance.new("Frame")
	separator.Size = UDim2.new(0, 1, 0, 15)
	separator.Position = UDim2.new(0, 270, 0.5, -7)
	separator.BackgroundColor3 = Theme.StudioSeparator or Theme.Border
	separator.BorderSizePixel = 0
	separator.Parent = ribbon
	separator.ZIndex = 10
	UIFactory.label({
		Parent = ribbon,
		Position = UDim2.new(0, 284, 0, 0),
		Size = UDim2.new(0, 180, 1, 0),
		Text = "WORKSPACE  /  CAMERA EDITOR",
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 10,
	})
end

function module:buildPropertiesPanel()
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(0, 244, 0, 246),
		Position = UDim2.new(1, -256, 1, -466),
		Color = Theme.PanelDark,
		Corner = 7,
		Name = "KeyframeProperties",
		ZIndex = 20,
	})
	UIFactory.stroke(panel, Theme.Border, 1, 0.15)
	UIFactory.shadow(panel, 0.16)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.Panel),
		ColorSequenceKeypoint.new(1, Theme.TimelineSurface or Theme.PanelDark),
	}
	gradient.Rotation = 90
	gradient.Parent = panel
	panel.Visible = false
	self.propertiesPanel = panel

	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Corner = 7,
		ZIndex = 21,
	})
	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 2)
	headerLine.BackgroundColor3 = Theme.Accent
	headerLine.BorderSizePixel = 0
	headerLine.Parent = header
	headerLine.ZIndex = 22
	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 13, 0, 7),
		Size = UDim2.new(1, -26, 0, 15),
		Text = "PROPERTIES",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Color = Theme.Text,
		ZIndex = 22,
	})
	self.propertiesInfo = UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 13, 0, 22),
		Size = UDim2.new(1, -26, 0, 12),
		Text = "SELECT A KEYFRAME",
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 22,
	})

	local function addSection(title, top)
		UIFactory.label({
			Parent = panel,
			Position = UDim2.new(0, 13, 0, top),
			Size = UDim2.new(1, -26, 0, 13),
			Text = title,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			Color = Theme.TextDim,
			ZIndex = 22,
		})
	end

	local function addField(key, labelText, top, accent)
		UIFactory.label({
			Parent = panel,
			Position = UDim2.new(0, 14, 0, top),
			Size = UDim2.new(0, 17, 0, 22),
			Text = labelText,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			Color = accent,
			ZIndex = 22,
		})
		local box = Instance.new("TextBox")
		box.Name = key
		box.Size = UDim2.new(0, 88, 0, 22)
		box.Position = UDim2.new(0, 32, 0, top)
		box.BackgroundColor3 = Theme.Background
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.PlaceholderText = "0.000"
		box.PlaceholderColor3 = Theme.TextMuted
		box.Text = ""
		box.Font = Enum.Font.Code
		box.TextSize = 10
		box.TextColor3 = Theme.Text
		box.TextXAlignment = Enum.TextXAlignment.Right
		box.Parent = panel
		box.ZIndex = 22
		UIFactory.corner(box, 4)
		UIFactory.stroke(box, Theme.Border, 1, 0.25)
		self.propertyFields[key] = box
		box.FocusLost:Connect(function()
			if self.onPropertiesSubmitted then
				self.onPropertiesSubmitted(self:getPropertyValues())
			end
		end)
	end

	addSection("POSITION", 50)
	addField("positionX", "X", 65, Theme.AxisX)
	addField("positionY", "Y", 91, Theme.AxisY)
	addField("positionZ", "Z", 117, Theme.AxisZ)
	addSection("ROTATION", 146)
	addField("rotationX", "X", 161, Theme.AxisX)
	addField("rotationY", "Y", 187, Theme.AxisY)
	addField("rotationZ", "Z", 213, Theme.AxisZ)

	local apply = UIFactory.button({
		Parent = panel,
		Position = UDim2.new(0, 132, 0, 187),
		Size = UDim2.new(0, 99, 0, 22),
		Text = "APPLY",
		Color = Theme.Accent,
		Corner = 4,
		TextSize = 9,
		ZIndex = 22,
	})
	apply.MouseButton1Click:Connect(function()
		if self.onPropertiesSubmitted then
			self.onPropertiesSubmitted(self:getPropertyValues())
		end
	end)
	local reset = UIFactory.button({
		Parent = panel,
		Position = UDim2.new(0, 132, 0, 213),
		Size = UDim2.new(0, 99, 0, 22),
		Text = "RESET",
		Color = Theme.Panel,
		Corner = 4,
		TextSize = 9,
		ZIndex = 22,
	})
	reset.MouseButton1Click:Connect(function()
		if self.propertyKeyframe then
			self:setKeyframeProperties(self.propertyKeyframe)
		end
	end)
end

function module:getPropertyValues()
	if not self.propertyKeyframe then return nil end
	local values = {}
	for key, box in pairs(self.propertyFields) do
		local value = tonumber(box.Text)
		if not value then return nil end
		values[key] = value
	end
	return values
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
	if not position or not orientation then return end
	self.propertyKeyframe = data
	self.propertiesPanel.Visible = true
	self.propertiesInfo.Text = string.format("%s  •  %.2fs", string.upper(data.cameraName or "CAMERA"), data.time or 0)
	local values = {
		positionX = position.X,
		positionY = position.Y,
		positionZ = position.Z,
		rotationX = orientation.X,
		rotationY = orientation.Y,
		rotationZ = orientation.Z,
	}
	for key, value in pairs(values) do
		local box = self.propertyFields[key]
		if box and not box:IsFocused() then
			box.Text = string.format("%.3f", value)
		end
	end
end

function module:clearKeyframeProperties()
	self.propertyKeyframe = nil
	if self.propertiesPanel then
		self.propertiesPanel.Visible = false
	end
end

function module:buildCamerasModal()
	local backdrop = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Color3.new(0, 0, 0),
		Name = "CamerasModalBackdrop",
		ZIndex = 50,
	})
	backdrop.BackgroundTransparency = 1
	backdrop.Visible = false

	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(0, 240, 0, 200),
		Color = Theme.Panel,
		Corner = 6,
		Name = "CamerasModal",
		ZIndex = 51,
	})
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.18)

	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Corner = 6,
		ZIndex = 52,
	})
	UIFactory.stroke(header, Theme.Border, 1)
	local headerAccent = Instance.new("Frame")
	headerAccent.Size = UDim2.new(1, 0, 0, 2)
	headerAccent.BackgroundColor3 = Theme.Accent
	headerAccent.BorderSizePixel = 0
	headerAccent.Parent = header
	headerAccent.ZIndex = 13
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.Header),
		ColorSequenceKeypoint.new(1, Theme.Panel),
	}
	headerGradient.Rotation = 90
	headerGradient.Parent = header

	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 160, 1, 0),
		Text = "EXPLORER  •  CAMERAS",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Color = Theme.Text,
		ZIndex = 53,
	})

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(1, -28, 0.5, -11)
	closeBtn.BackgroundColor3 = Theme.Panel
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 13
	closeBtn.TextColor3 = Theme.TextDim
	closeBtn.Text = "×"
	closeBtn.AutoButtonColor = false
	closeBtn.Parent = header
	closeBtn.ZIndex = 53
	UIFactory.corner(closeBtn, 3)
	UIFactory.stroke(closeBtn, Theme.Border, 1)

	local switchRow = Instance.new("Frame")
	switchRow.Name = "ViewRow"
	switchRow.Size = UDim2.new(1, -24, 0, 30)
	switchRow.Position = UDim2.new(0, 12, 0, 44)
	switchRow.BackgroundColor3 = Theme.Header
	switchRow.BorderSizePixel = 0
	switchRow.Parent = panel
	switchRow.ZIndex = 52
	UIFactory.corner(switchRow, 4)
	UIFactory.stroke(switchRow, Theme.Border, 1)

	UIFactory.label({
		Parent = switchRow,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Text = "Camera Preview",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Color = Theme.Text,
		ZIndex = 53,
	})

	local switchTrack = Instance.new("Frame")
	switchTrack.Name = "Track"
	switchTrack.Size = UDim2.new(0, 36, 0, 18)
	switchTrack.Position = UDim2.new(1, -46, 0.5, -9)
	switchTrack.BackgroundColor3 = Theme.PanelDark
	switchTrack.BorderSizePixel = 0
	switchTrack.Parent = switchRow
	switchTrack.ZIndex = 53
	UIFactory.corner(switchTrack, 9)
	UIFactory.stroke(switchTrack, Theme.Border, 1)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 2, 0.5, -7)
	knob.BackgroundColor3 = Theme.TextDim
	knob.BorderSizePixel = 0
	knob.Parent = switchTrack
	knob.ZIndex = 54
	UIFactory.corner(knob, 7)

	self.viewToggle = {
		row = switchRow,
		track = switchTrack,
		knob = knob,
		on = false,
		callback = nil,
		button = switchRow,
	}

	local function rowBtn(name, text, color, yOffset)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(1, -24, 0, 30)
		b.Position = UDim2.new(0, 12, 0, yOffset)
		b.BackgroundColor3 = color or Theme.Header
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.TextColor3 = Theme.Text
		b.Text = text
		b.AutoButtonColor = false
		b.Parent = panel
		b.ZIndex = 52
		UIFactory.corner(b, 4)
		UIFactory.stroke(b, Theme.Border, 1)
		local def = b.BackgroundColor3
		local hov = def:Lerp(Color3.new(1,1,1), 0.12)
		local prs = def:Lerp(Color3.new(0,0,0), 0.08)
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = hov}):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = def}):Play()
		end)
		b.MouseButton1Down:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = prs}):Play()
		end)
		b.MouseButton1Up:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = hov}):Play()
		end)
		return b
	end

	self.modalPanel    = panel
	self.modalBackdrop = backdrop
	self.addCamButton  = rowBtn("AddCamera",  "+  Add Camera",  Theme.Accent, 90)
	self.editButton    = rowBtn("EditCamera", "Edit Selected", Theme.Panel,  132)

	panel.Visible = false
	self.modalOpen = false

	self.camerasButton.MouseButton1Click:Connect(function()
		self:openCamerasModal()
	end)
	closeBtn.MouseButton1Click:Connect(function() self:closeCamerasModal() end)
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:closeCamerasModal()
		end
	end)
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

	panel.Size = UDim2.new(0, 240, 0, 200)

	local desiredX = btnAbs.X + btnSize.X - 240
	local desiredY = btnAbs.Y + btnSize.Y + 6

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		or Vector2.new(panel.Parent.AbsoluteSize.X, panel.Parent.AbsoluteSize.Y)
	desiredX = math.clamp(desiredX, 8, math.max(8, viewport.X - 248))
	desiredY = math.clamp(desiredY, 8, math.max(8, viewport.Y - 208))

	self._modalTargetPos = UDim2.new(0, desiredX, 0, desiredY)
	panel.Position = self._modalTargetPos
end

function module:buildTimelinePanel()
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 214),
		Position = UDim2.new(0, 0, 1, -214),
		Color = Theme.Background,
		Name = "TimelinePanel",
		ZIndex = 10,
	})
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.15)
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.PanelDark),
		ColorSequenceKeypoint.new(1, Theme.Background),
	}
	panelGradient.Rotation = 90
	panelGradient.Parent = panel
	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.StudioToolbar or Theme.Header,
		Name = "Header",
		ZIndex = 11,
	})
	UIFactory.stroke(header, Theme.Border, 1)
	local headerAccent = Instance.new("Frame")
	headerAccent.Size = UDim2.new(0, 3, 0, 24)
	headerAccent.Position = UDim2.new(0, 10, 0.5, -12)
	headerAccent.BackgroundColor3 = Theme.Accent
	headerAccent.BorderSizePixel = 0
	headerAccent.Parent = header
	headerAccent.ZIndex = 12
	UIFactory.corner(headerAccent, 2)
	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 22, 0, 6),
		Size = UDim2.new(0, 120, 0, 14),
		Text = "ANIMATION EDITOR",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Color = Theme.Text,
		ZIndex = 12,
	})
	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 22, 0, 21),
		Size = UDim2.new(0, 120, 0, 11),
		Text = "CAMERA SEQUENCER",
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 12,
	})
	self.controls = UIFactory.frame({
		Parent = header,
		Position = UDim2.new(0, 152, 0.5, -15),
		Size = UDim2.new(0, 286, 0, 30),
		Color = Theme.StudioInput or Theme.PanelDark,
		Corner = 4,
		Name = "Controls",
		ZIndex = 12,
	})
	UIFactory.stroke(self.controls, Theme.StudioSeparator or Theme.Border, 1, 0.25)
	self.timeLabel = UIFactory.label({
		Parent = header,
		Position = UDim2.new(1, -138, 0, 0),
		Size = UDim2.new(0, 124, 1, 0),
		Text = "00:00 / 00:10",
		Font = Enum.Font.Code,
		TextSize = 12,
		Color = Theme.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		ZIndex = 12,
	})
	self.area = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, -16, 1, -54),
		Position = UDim2.new(0, 8, 0, 48),
		Color = Theme.TimelineSurface or Theme.PanelDark,
		Corner = 4,
		Name = "TimelineArea",
		ZIndex = 11,
	})
	UIFactory.stroke(self.area, Theme.StudioSeparator or Theme.Border, 1, 0.35)
	local areaGradient = Instance.new("UIGradient")
	areaGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.TimelineSurface or Theme.PanelDark),
		ColorSequenceKeypoint.new(1, Theme.Background),
	}
	areaGradient.Rotation = 90
	areaGradient.Parent = self.area
	local leftHeader = UIFactory.label({
		Parent = self.area,
		Position = UDim2.new(0, 12, 0, 3),
		Size = UDim2.new(0, 72, 0, 18),
		Text = "TRACKS",
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 29,
	})
	local timelineHeader = UIFactory.label({
		Parent = self.area,
		Position = UDim2.new(0, TIMELINE_AXIS_LEFT, 0, 3),
		Size = UDim2.new(0, 90, 0, 18),
		Text = "TIMELINE",
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		Color = Theme.TextMuted,
		ZIndex = 29,
	})
	local rulerLine = Instance.new("Frame")
	rulerLine.Size = UDim2.new(1, -16, 0, 1)
	rulerLine.Position = UDim2.new(0, 8, 0, 25)
	rulerLine.BackgroundColor3 = Theme.StudioSeparator or Theme.Border
	rulerLine.BorderSizePixel = 0
	rulerLine.Parent = self.area
	rulerLine.ZIndex = 28
	self.tracksList = Instance.new("ScrollingFrame")
	self.tracksList.Name = "TracksList"
	self.tracksList.Size = UDim2.new(1, -12, 1, -33)
	self.tracksList.Position = UDim2.new(0, 6, 0, 29)
	self.tracksList.BackgroundTransparency = 1
	self.tracksList.BorderSizePixel = 0
	self.tracksList.ScrollBarThickness = 4
	self.tracksList.ScrollBarImageColor3 = Theme.Accent
	self.tracksList.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.tracksList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.tracksList.Parent = self.area
	self.tracksList.ZIndex = 12
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = self.tracksList
	layout.FillDirection = Enum.FillDirection.Vertical
	self:buildRuler()
	self:buildPlayhead()
end
function module:addTrackGrid(container)
	local maxTime = getMaxTime()
	for i = 0, maxTime do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 1, 1, 0)
		line.Position = UDim2.new(i / maxTime, 0, 0, 0)
		line.BackgroundColor3 = Theme.TimelineGrid or Theme.Border
		line.BackgroundTransparency = i == 0 and 0.42 or 0.72
		line.BorderSizePixel = 0
		line.Parent = container
		line.ZIndex = 13
		if i < maxTime then
			local subline = Instance.new("Frame")
			subline.Size = UDim2.new(0, 1, 1, 0)
			subline.Position = UDim2.new((i + 0.5) / maxTime, 0, 0, 0)
			subline.BackgroundColor3 = Theme.TimelineMinorGrid or Theme.Border
			subline.BackgroundTransparency = 0.86
			subline.BorderSizePixel = 0
			subline.Parent = container
			subline.ZIndex = 13
		end
	end
end

function module:buildRuler()
	local ruler = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(1, -TIMELINE_AXIS_LEFT - TIMELINE_AXIS_RIGHT, 0, 22),
		Position = UDim2.new(0, TIMELINE_AXIS_LEFT, 0, 4),
		Color = Theme.PanelDark,
		Name = "Ruler",
		ZIndex = 30,
	})
	ruler.BackgroundTransparency = 1

	local maxTime = getMaxTime()
	for i = 0, maxTime do
		local xPos = i / maxTime
		local marker = Instance.new("Frame")
		marker.Size = UDim2.new(0, 1, 0, 12)
		marker.Position = UDim2.new(xPos, 0, 0, 6)
		marker.BackgroundColor3 = Theme.TextMuted
		marker.BackgroundTransparency = 0.3
		marker.BorderSizePixel = 0
		marker.Parent = ruler
		marker.ZIndex = 31

		UIFactory.label({
			Parent = marker,
			Position = UDim2.new(0, -14, 1, 2),
			Size = UDim2.new(0, 28, 0, 12),
			Text = string.format("%ds", i),
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			Color = Theme.TextMuted,
			XAlign = Enum.TextXAlignment.Center,
			ZIndex = 31,
		})
		if i < maxTime then
			local sub = Instance.new("Frame")
			sub.Size = UDim2.new(0, 1, 0, 6)
			sub.Position = UDim2.new(xPos + (0.5 / maxTime), 0, 0, 9)
			sub.BackgroundColor3 = Theme.TextMuted
			sub.BackgroundTransparency = 0.7
			sub.BorderSizePixel = 0
			sub.Parent = ruler
			sub.ZIndex = 31
		end
	end
end

function module:buildPlayhead()
	if self.playheadLine and self.playheadLine.Parent then
		self.playheadLine.Parent = nil
	end
	self.playheadLine = Instance.new("Frame")
	self.playheadLine.Name = "PlayheadLine"
	self.playheadLine.Size = UDim2.new(0, 2, 1, -8)
	self.playheadLine.Position = UDim2.new(0, TIMELINE_AXIS_LEFT - 1, 0, 4)
	self.playheadLine.BackgroundColor3 = Theme.Playhead
	self.playheadLine.BorderSizePixel = 0
	self.playheadLine.Parent = self.area
	self.playheadLine.ZIndex = 40

	self.playhead = UIFactory.frame({
		Parent = self.playheadLine,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 0, -7),
		Color = Theme.Playhead,
		Corner = 3,
		ZIndex = 41,
	})

	local triangle = Instance.new("Frame")
	triangle.Size = UDim2.new(0, 8, 0, 8)
	triangle.Position = UDim2.new(0.5, -4, 0.5, -4)
	triangle.BackgroundColor3 = Color3.new(1, 1, 1)
	triangle.BorderSizePixel = 0
	triangle.Rotation = 45
	triangle.Parent = self.playhead
	triangle.ZIndex = 42

	local bottomHandle = UIFactory.frame({
		Parent = self.playheadLine,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 1, -7),
		Color = Theme.Playhead,
		Corner = 3,
		ZIndex = 41,
	})
	bottomHandle.Rotation = 180

	local bottomTriangle = Instance.new("Frame")
	bottomTriangle.Size = UDim2.new(0, 8, 0, 8)
	bottomTriangle.Position = UDim2.new(0.5, -4, 0.5, -4)
	bottomTriangle.BackgroundColor3 = Color3.new(1, 1, 1)
	bottomTriangle.BorderSizePixel = 0
	bottomTriangle.Rotation = 45
	bottomTriangle.Parent = bottomHandle
	bottomTriangle.ZIndex = 42
end

function module:ensureTrack(cameraName)
	if self.tracks[cameraName] then return self.tracks[cameraName] end

	local row = Instance.new("Frame")
	row.Name = "Track_" .. cameraName
	row.Size = UDim2.new(1, -8, 0, 36)
	row.BackgroundColor3 = Theme.Track or Theme.Panel
	row.BackgroundTransparency = 0.04
	row.BorderSizePixel = 0
	row.Active = true
	row.LayoutOrder = #self.tracks + 1
	row.Parent = self.tracksList
	row.ZIndex = 12
	UIFactory.corner(row, 4)
	UIFactory.stroke(row, Theme.Border, 1, 0.5)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Theme.Panel),
		ColorSequenceKeypoint.new(1, Theme.Panel:Lerp(Theme.Background, 0.3)),
	}
	grad.Rotation = 90
	grad.Parent = row

	local selectionRail = Instance.new("Frame")
	selectionRail.Size = UDim2.new(0, 3, 1, 0)
	selectionRail.Position = UDim2.new(0, 0, 0, 0)
	selectionRail.BackgroundColor3 = Theme.Accent
	selectionRail.BackgroundTransparency = 1
	selectionRail.BorderSizePixel = 0
	selectionRail.Parent = row
	selectionRail.ZIndex = 14

	local cameraDot = Instance.new("Frame")
	cameraDot.Size = UDim2.new(0, 7, 0, 7)
	cameraDot.Position = UDim2.new(0, 11, 0.5, -4)
	cameraDot.BackgroundColor3 = Theme.Accent
	cameraDot.BorderSizePixel = 0
	cameraDot.Parent = row
	cameraDot.ZIndex = 14
	UIFactory.corner(cameraDot, 4)

	local label = UIFactory.label({
		Parent = row,
		Position = UDim2.new(0, 24, 0, 4),
		Size = UDim2.new(0, 68, 0, 15),
		Text = string.upper(cameraName),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		Color = Theme.TextDim,
		ZIndex = 14,
	})
	UIFactory.label({
		Parent = row,
		Position = UDim2.new(0, 24, 0, 19),
		Size = UDim2.new(0, 68, 0, 11),
		Text = "CAMERA",
		Font = Enum.Font.GothamMedium,
		TextSize = 7,
		Color = Theme.TextMuted,
		ZIndex = 14,
	})
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0, 1, 1, -10)
	divider.Position = UDim2.new(0, KF_LABEL_OFFSET - 8, 0, 5)
	divider.BackgroundColor3 = Theme.Border
	divider.BackgroundTransparency = 0.45
	divider.BorderSizePixel = 0
	divider.Parent = row
	divider.ZIndex = 13

	local kfContainer = Instance.new("Frame")
	kfContainer.Name = "Keyframes"
	kfContainer.Size = UDim2.new(1, -110, 1, 0)
	kfContainer.Position = UDim2.new(0, KF_LABEL_OFFSET, 0, 0)
	kfContainer.BackgroundTransparency = 1
	kfContainer.ClipsDescendants = true
	kfContainer.Parent = row
	kfContainer.ZIndex = 13
	self:addTrackGrid(kfContainer)

	local track = {
		row = row,
		label = label,
		selectionRail = selectionRail,
		cameraDot = cameraDot,
		keyframesContainer = kfContainer,
		keyframes = {},
		activeKeyframe = nil,
		cameraName = cameraName,
	}
	row.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if self.onTrackSelected then
				self.onTrackSelected(cameraName)
			end
		end
	end)
	self.tracks[cameraName] = track
	return track
end

function module:setActiveCamera(cameraName)
	self.activeCameraName = cameraName
	for name, tr in pairs(self.tracks) do
		local highlight = (name == cameraName)
		tr.row.BackgroundColor3 = highlight
			and (Theme.TrackActive or Theme.Accent:Lerp(Theme.Panel, 0.25))
			or (Theme.Track or Theme.Panel)
		tr.selectionRail.BackgroundTransparency = highlight and 0 or 1
		tr.cameraDot.BackgroundColor3 = highlight and Theme.Keyframe or Theme.Accent
		tr.label.TextColor3 = highlight and Theme.Text or Theme.TextDim
	end
end

function module:renderKeyframes(keyframeTimes)
	for _, tr in pairs(self.tracks) do
		for _, kf in ipairs(tr.keyframes) do
			if kf.diamond and kf.diamond.Parent then kf.diamond:Destroy() end
			if kf.guide and kf.guide.Parent then kf.guide:Destroy() end
			if kf.tooltip and kf.tooltip.Parent then kf.tooltip:Destroy() end
		end
		tr.keyframes = {}
	end

	for name, _ in pairs(self.tracks) do
		for _, t in ipairs(keyframeTimes) do
			self:createKeyframeVisual(name, t)
		end
	end
end

function module:createKeyframeVisual(cameraName, time)
	local track = self:ensureTrack(cameraName)
	local maxTime = getMaxTime()
	local xPos = (time or 0) / maxTime

	local guide = Instance.new("Frame")
	guide.Size = UDim2.new(0, 1, 1, 8)
	guide.Position = UDim2.new(xPos, 0, 0, -4)
	guide.BackgroundColor3 = Theme.Keyframe
	guide.BackgroundTransparency = 0.68
	guide.BorderSizePixel = 0
	guide.Parent = track.keyframesContainer
	guide.ZIndex = 13

	local diamond = Instance.new("TextButton")
	diamond.Name = "Keyframe_" .. tostring(time)
	diamond.Text = ""
	diamond.AutoButtonColor = false
	diamond.Active = true
	diamond.Size = UDim2.new(0, 12, 0, 12)
	diamond.Position = UDim2.new(xPos, -6, 0.5, -6)
	diamond.BackgroundColor3 = Theme.Keyframe or Theme.Accent or Theme.Playhead
	diamond.BorderSizePixel = 0
	diamond.Rotation = 45
	diamond.Parent = track.keyframesContainer
	diamond.ZIndex = 14

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Keyframe:Lerp(Theme.Text, 0.42)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = diamond

	local tooltip = UIFactory.label({
		Parent = track.keyframesContainer,
		Position = UDim2.new(xPos, -24, 0, -17),
		Size = UDim2.new(0, 48, 0, 12),
		Text = string.format("%.2fs", time or 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 8,
		Color = Theme.Text,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 16,
	})
	tooltip.BackgroundColor3 = Theme.Header
	tooltip.BackgroundTransparency = 0.08
	tooltip.Visible = false
	UIFactory.corner(tooltip, 3)

	local record = {
		time = time,
		diamond = diamond,
		guide = guide,
		tooltip = tooltip,
		expanded = false,
	}
	track.keyframes[#track.keyframes + 1] = record
	diamond.MouseButton1Click:Connect(function()
		if self.onKeyframeSelected and record.data then
			self.onKeyframeSelected(cameraName, record.data)
		end
	end)

	local defaultSize = diamond.Size
	local hoverSize = UDim2.new(0, 16, 0, 16)
	diamond.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			tooltip.Visible = true
			TweenService:Create(diamond, TweenInfo.new(0.15), {
				Size = hoverSize,
				Position = UDim2.new(xPos, -8, 0.5, -8),
			}):Play()
		end
	end)
	diamond.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			tooltip.Visible = false
			TweenService:Create(diamond, TweenInfo.new(0.15), {
				Size = record.expanded and UDim2.new(0, 18, 0, 18) or defaultSize,
				Position = UDim2.new(
					xPos,
					record.expanded and -9 or -6,
					0.5,
					record.expanded and -9 or -6
				),
			}):Play()
		end
	end)

	return record
end

function module:removeKeyframeVisual(cameraName, time)
	local track = self.tracks[cameraName]
	if not track then return end
	for i, kf in ipairs(track.keyframes) do
		if math.abs(kf.time - time) < 1e-4 then
			if kf.diamond and kf.diamond.Parent then kf.diamond:Destroy() end
			if kf.guide and kf.guide.Parent then kf.guide:Destroy() end
			if kf.tooltip and kf.tooltip.Parent then kf.tooltip:Destroy() end
			table.remove(track.keyframes, i)
			return true
		end
	end
	return false
end

function module:updatePlayheadProximity(time, pixelPos)
	local maxTime = getMaxTime()
	local threshold = 6
	for _, track in pairs(self.tracks) do
		for _, kf in ipairs(track.keyframes) do
			local kfX = timeToX(kf.time, self.area.AbsoluteSize.X)
			local dist = math.abs(pixelPos - kfX)
			local shouldExpand = dist < threshold
			if shouldExpand ~= kf.expanded then
				kf.expanded = shouldExpand
				if shouldExpand then
					TweenService:Create(kf.diamond, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.new(0, 18, 0, 18),
						Position = UDim2.new(kf.time / maxTime, -9, 0.5, -9),
					}):Play()
				else
					TweenService:Create(kf.diamond, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(0, 12, 0, 12),
						Position = UDim2.new(kf.time / maxTime, -6, 0.5, -6),
					}):Play()
				end
			end
		end
	end
end

function module:createControlButton(index, text, color, callback)
	local btn = UIFactory.button({
		Parent = self.controls,
		Position = UDim2.new(0, 5 + (index - 1) * 46, 0.5, -12),
		Size = UDim2.new(0, 40, 0, 24),
		Text = text,
		Color = color or Theme.Panel,
		Corner = 3,
		TextSize = 12,
		ZIndex = 13,
	})
	btn.MouseButton1Click:Connect(callback)
	return btn
end

function module:createIconControl(index, icon, callback, tooltip)
	local container, btn = UIFactory.iconButton({
		Parent = self.controls,
		Position = UDim2.new(0, 6 + (index - 1) * 34, 0.5, -12),
		Size = UDim2.new(0, 26, 0, 26),
		Icon = icon,
		Color = Theme.Panel,
		Corner = 4,
		TextSize = 14,
		TextColor = Theme.TextDim,
		Callback = callback,
		ZIndex = 13,
	})
	return container
end

function module:setPlayheadPosition(time)
	local maxTime = getMaxTime()
	local clampedTime = math.clamp(time, 0, maxTime)
	local areaWidth = self.area.AbsoluteSize.X
	local pixelPos = timeToX(clampedTime, areaWidth)

	self.playheadLine.Position = UDim2.new(0, pixelPos - 1, 0, 4)

	local mins = math.floor(clampedTime / 60)
	local secs = math.floor(clampedTime % 60)
	local totalMins = math.floor(maxTime / 60)
	local totalSecs = math.floor(maxTime % 60)
	self.timeLabel.Text = string.format("%02d:%02d / %02d:%02d", mins, secs, totalMins, totalSecs)

	self:updatePlayheadProximity(clampedTime, pixelPos)
end

return module