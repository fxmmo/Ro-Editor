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
local KF_LABEL_OFFSET = 180
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
	local playerGui = player:WaitForChild("PlayerGui")
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == "StudioTimelineSystem" then
			child:Destroy()
		end
	end
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "StudioTimelineSystem"
	self.gui.ResetOnSpawn = false
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = playerGui
	self.modalOpen = false
	self.tracks = {}
	self.activeCameraName = nil
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
		Size = UDim2.new(1, 0, 0, 38),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Name = "TopBar",
		ZIndex = 10,
	})
	UIFactory.stroke(bar, Theme.Border, 1)
	UIFactory.shadow(bar, 0.06)

	local accent = UIFactory.frame({
		Parent = bar,
		Size = UDim2.new(0, 3, 0, 16),
		Position = UDim2.new(0, 14, 0.5, -8),
		Color = Theme.Accent or Theme.Playhead,
		Corner = 2,
		ZIndex = 11,
	})

	UIFactory.label({
		Parent = bar,
		Position = UDim2.new(0, 26, 0, 0),
		Size = UDim2.new(0, 200, 1, 0),
		Text = "Camera Animator",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Color = Theme.Text,
		ZIndex = 11,
	})

	UIFactory.frame({
		Parent = bar,
		Size = UDim2.new(0, 1, 0, 20),
		Position = UDim2.new(0, 230, 0.5, -10),
		Color = Theme.Border,
		ZIndex = 11,
	})

	self.camerasButton = UIFactory.button({
		Parent = bar,
		Position = UDim2.new(1, -150, 0.5, -13),
		Size = UDim2.new(0, 130, 0, 26),
		Text = "Cameras",
		Color = Theme.Panel,
		Corner = 4,
		ZIndex = 11,
	})

	self:buildCamerasModal()
	self:buildTimelinePanel()

	return bar
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
		Size = UDim2.new(0, 320, 0, 400),
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
	headerAccent.ZIndex = 53
	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 180, 1, 0),
		Text = "Cameras",
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
	local switchRow = Instance.new("TextButton")
	switchRow.Name = "ViewRow"
	switchRow.Size = UDim2.new(1, -24, 0, 30)
	switchRow.Position = UDim2.new(0, 12, 0, 44)
	switchRow.BackgroundColor3 = Theme.Header
	switchRow.BorderSizePixel = 0
	switchRow.Text = ""
	switchRow.AutoButtonColor = false
	switchRow.Parent = panel
	switchRow.ZIndex = 52
	UIFactory.corner(switchRow, 4)
	UIFactory.stroke(switchRow, Theme.Border, 1)
	UIFactory.label({
		Parent = switchRow,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Text = "View Camera",
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
		b.Size = UDim2.new(0, 140, 0, 30)
		b.Position = UDim2.new(0, 12 + (name == "EditCamera" and 152 or 0), 0, yOffset)
		b.BackgroundColor3 = color or Theme.Header
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextColor3 = Theme.Text
		b.Text = text
		b.AutoButtonColor = false
		b.Parent = panel
		b.ZIndex = 52
		UIFactory.corner(b, 4)
		UIFactory.stroke(b, Theme.Border, 1)
		local def = b.BackgroundColor3
		local hov = def:Lerp(Color3.new(1, 1, 1), 0.12)
		local prs = def:Lerp(Color3.new(0, 0, 0), 0.08)
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
	self.addCamButton = rowBtn("AddCamera", "Add Camera", Theme.Accent, 86)
	self.editButton = rowBtn("EditCamera", "Edit Camera", Theme.Panel, 86)
	local separator = Instance.new("Frame")
	separator.Size = UDim2.new(1, -24, 0, 1)
	separator.Position = UDim2.new(0, 12, 0, 130)
	separator.BackgroundColor3 = Theme.Border
	separator.BorderSizePixel = 0
	separator.Parent = panel
	separator.ZIndex = 52
	self.propertiesInfo = UIFactory.label({
		Parent = panel,
		Position = UDim2.new(0, 12, 0, 141),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "SELECT A KEYFRAME TO EDIT PROPERTIES",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		Color = Theme.TextMuted,
		ZIndex = 52,
	})
	local properties = Instance.new("Frame")
	properties.Name = "KeyframeProperties"
	properties.Size = UDim2.new(1, -24, 0, 220)
	properties.Position = UDim2.new(0, 12, 0, 165)
	properties.BackgroundTransparency = 1
	properties.BorderSizePixel = 0
	properties.Parent = panel
	properties.ZIndex = 52
	properties.Visible = false
	self.propertiesSection = properties
	self.propertyFields = {}
	local function sectionTitle(text, y)
		UIFactory.label({
			Parent = properties,
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(0, 100, 0, 14),
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			Color = Theme.TextDim,
			ZIndex = 53,
		})
	end
	local function addField(key, label, x, y, color)
		UIFactory.label({
			Parent = properties,
			Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, 14, 0, 22),
			Text = label,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			Color = color,
			ZIndex = 53,
		})
		local field = Instance.new("TextBox")
		field.Name = key
		field.Size = UDim2.new(0, 76, 0, 22)
		field.Position = UDim2.new(0, x + 16, 0, y)
		field.BackgroundColor3 = Theme.Background
		field.BorderSizePixel = 0
		field.ClearTextOnFocus = false
		field.PlaceholderText = "0.000"
		field.PlaceholderColor3 = Theme.TextMuted
		field.Font = Enum.Font.Code
		field.TextSize = 10
		field.TextColor3 = Theme.Text
		field.TextXAlignment = Enum.TextXAlignment.Right
		field.Parent = properties
		field.ZIndex = 53
		UIFactory.corner(field, 4)
		UIFactory.stroke(field, Theme.Border, 1, 0.25)
		self.propertyFields[key] = field
		field.FocusLost:Connect(function()
			if self.onPropertiesSubmitted then
				self.onPropertiesSubmitted(self:getPropertyValues())
			end
		end)
	end
	sectionTitle("POSITION", 0)
	addField("positionX", "X", 0, 18, Theme.AxisX)
	addField("positionY", "Y", 100, 18, Theme.AxisY)
	addField("positionZ", "Z", 200, 18, Theme.AxisZ)
	sectionTitle("ROTATION", 52)
	addField("rotationX", "X", 0, 70, Theme.AxisX)
	addField("rotationY", "Y", 100, 70, Theme.AxisY)
	addField("rotationZ", "Z", 200, 70, Theme.AxisZ)
	local apply = UIFactory.button({
		Parent = properties,
		Position = UDim2.new(0, 0, 0, 112),
		Size = UDim2.new(0, 142, 0, 28),
		Text = "APPLY",
		Color = Theme.Accent,
		Corner = 4,
		TextSize = 10,
		ZIndex = 53,
	})
	apply.MouseButton1Click:Connect(function()
		if self.onPropertiesSubmitted then
			self.onPropertiesSubmitted(self:getPropertyValues())
		end
	end)
	local reset = UIFactory.button({
		Parent = properties,
		Position = UDim2.new(0, 154, 0, 112),
		Size = UDim2.new(0, 142, 0, 28),
		Text = "RESET",
		Color = Theme.PanelDark,
		Corner = 4,
		TextSize = 10,
		ZIndex = 53,
	})
	reset.MouseButton1Click:Connect(function()
		if self.propertyKeyframe then
			self:setKeyframeProperties(self.propertyKeyframe)
		end
	end)
	self.modalPanel = panel
	self.modalBackdrop = backdrop
	panel.Visible = false
	self.modalOpen = false
	self.camerasButton.MouseButton1Click:Connect(function()
		self:openCamerasModal()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:closeCamerasModal()
	end)
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:closeCamerasModal()
		end
	end)
end

function module:getPropertyValues()
	if not self.propertyKeyframe or not self.propertyFields then return nil end
	local values = {}
	for key, field in pairs(self.propertyFields) do
		local value = tonumber(field.Text)
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
	for key, value in pairs(values) do
		local field = self.propertyFields[key]
		if field and not field:IsFocused() then
			field.Text = string.format("%.3f", value)
		end
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

	panel.Size = UDim2.new(0, 320, 0, 400)

	local desiredX = btnAbs.X + btnSize.X - 320
	local desiredY = btnAbs.Y + btnSize.Y + 6

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		or Vector2.new(panel.Parent.AbsoluteSize.X, panel.Parent.AbsoluteSize.Y)
	desiredX = math.clamp(desiredX, 8, math.max(8, viewport.X - 328))
	desiredY = math.clamp(desiredY, 8, math.max(8, viewport.Y - 408))

	self._modalTargetPos = UDim2.new(0, desiredX, 0, desiredY)
	panel.Position = self._modalTargetPos
end

function module:buildTimelinePanel()
	if self.timelinePanel and self.timelinePanel.Parent then
		self.timelinePanel:Destroy()
	end
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 1, -160),
		Color = Theme.Background,
		Name = "TimelinePanel",
		ZIndex = 10,
	})
	self.timelinePanel = panel
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.1)

	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Name = "Header",
		ZIndex = 11,
	})
	UIFactory.stroke(header, Theme.Border, 1)

	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(0, 120, 1, 0),
		Text = "Animation Editor",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Color = Theme.Text,
		ZIndex = 12,
	})

	self.controls = UIFactory.frame({
		Parent = header,
		Position = UDim2.new(0, 150, 0, 4),
		Size = UDim2.new(0, 280, 1, -8),
		Color = Theme.Panel,
		Corner = 4,
		Name = "Controls",
		ZIndex = 12,
	})
	UIFactory.stroke(self.controls, Theme.Border, 1, 0.5)

	self.timeLabel = UIFactory.label({
		Parent = header,
		Name = "TimeLabel",
		Position = UDim2.new(1, -120, 0, 0),
		Size = UDim2.new(0, 110, 1, 0),
		Text = "00:00 / 00:10",
		Font = Enum.Font.Code,
		TextSize = 13,
		Color = Theme.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		ZIndex = 12,
	})

	self.area = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, -20, 1, -44),
		Position = UDim2.new(0, 10, 0, 38),
		Color = Theme.PanelDark,
		Corner = 6,
		Name = "TimelineArea",
		ZIndex = 11,
	})
	UIFactory.stroke(self.area, Theme.Border, 1, 0.6)

	self.tracksList = Instance.new("ScrollingFrame")
	self.tracksList.Name = "TracksList"
	self.tracksList.Size = UDim2.new(1, -16, 1, -28)
	self.tracksList.Position = UDim2.new(0, 8, 0, 26)
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

function module:buildRuler()
	if self.ruler and self.ruler.Parent then
		self.ruler:Destroy()
	end
	local ruler = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(1, -TIMELINE_AXIS_LEFT - TIMELINE_AXIS_RIGHT, 0, 22),
		Position = UDim2.new(0, TIMELINE_AXIS_LEFT, 0, 4),
		Color = Theme.PanelDark,
		Name = "Ruler",
		ZIndex = 30,
	})
	self.ruler = ruler
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
	row.BackgroundColor3 = Theme.Panel
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

	local label = UIFactory.label({
		Parent = row,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Text = cameraName,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Color = Theme.TextDim,
		ZIndex = 13,
	})

	local kfContainer = Instance.new("Frame")
	kfContainer.Name = "Keyframes"
	kfContainer.Size = UDim2.new(1, -KF_LABEL_OFFSET - 10, 1, 0)
	kfContainer.Position = UDim2.new(0, KF_LABEL_OFFSET, 0, 0)
	kfContainer.BackgroundTransparency = 1
	kfContainer.ClipsDescendants = true
	kfContainer.Parent = row
	kfContainer.ZIndex = 13

	local track = {
		row = row,
		label = label,
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
			and Theme.Accent:Lerp(Theme.Panel, 0.25)
			or Theme.Panel
	end
end

function module:renderKeyframes(keyframeTimes)
	for _, tr in pairs(self.tracks) do
		for _, kf in ipairs(tr.keyframes) do
			if kf.diamond and kf.diamond.Parent then kf.diamond:Destroy() end
			if kf.guide and kf.guide.Parent then kf.guide:Destroy() end
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
	guide.BackgroundColor3 = Theme.Accent or Theme.Playhead
	guide.BackgroundTransparency = 0.85
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
	stroke.Color = Theme.Panel
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = diamond

	local record = {
		time = time,
		diamond = diamond,
		guide = guide,
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
			TweenService:Create(diamond, TweenInfo.new(0.15), {
				Size = hoverSize,
				Position = UDim2.new(xPos, -8, 0.5, -8),
			}):Play()
		end
	end)
	diamond.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
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
		Position = UDim2.new(0, 6 + (index - 1) * 46, 0.5, -12),
		Size = UDim2.new(0, 40, 0, 24),
		Text = text,
		Color = color or Theme.Panel,
		Corner = 4,
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