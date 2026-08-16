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
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Icons = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Icon_Config.lua") or error("[Ro-Editor] import failed")
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

local function fallbackTimelineAxis(areaWidth)
	local left = TRACK_PADDING + KF_LABEL_OFFSET
	local width = math.max(areaWidth - left - TIMELINE_AXIS_RIGHT, 1)
	return left, width
end

function module.new()
	local self = setmetatable({}, module)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local containers = {playerGui, CoreGui}
	for _, container in ipairs(containers) do
		pcall(function()
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("ScreenGui") and child.Name == "StudioTimelineSystem" then
					child:Destroy()
				end
			end
		end)
	end
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "StudioTimelineSystem"
	self.gui.ResetOnSpawn = false
	self.gui.IgnoreGuiInset = true
	local parentedToCoreGui = pcall(function()
		self.gui.Parent = CoreGui
	end)
	if not parentedToCoreGui or not self.gui.Parent then
		self.gui.Parent = playerGui
	end
	self.modalOpen = false
	self.editSectionOpen = false
	self.timelineMinimized = false
	self.timelineExpandedHeight = 160
	self.tracks = {}
	self.trackOrder = 0
	self.activeCameraName = nil
	self.trackResizeState = nil
	self.trackResizeConnection = nil
	return self
end

function module:getTimelineAxis()
	if not self.area then
		return TIMELINE_AXIS_LEFT, 1
	end
	local areaPosition = self.area.AbsolutePosition.X
	local areaWidth = self.area.AbsoluteSize.X
	local left, width = fallbackTimelineAxis(areaWidth)
	for _, track in pairs(self.tracks) do
		local container = track.keyframesContainer
		if container and container.Parent then
			left = container.AbsolutePosition.X - areaPosition
			width = container.AbsoluteSize.X
			break
		end
	end
	return left, math.max(width, 1)
end

function module:getRulerAxis()
	if not self.area then
		return TIMELINE_AXIS_LEFT, 1
	end
	local areaPosition = self.area.AbsolutePosition.X
	if self.tracksList and self.tracksList.Parent then
		return self.tracksList.AbsolutePosition.X - areaPosition, math.max(self.tracksList.AbsoluteSize.X, 1)
	end
	return fallbackTimelineAxis(self.area.AbsoluteSize.X)
end

function module:timeToX(t)
	local maxTime = getMaxTime()
	local left, width = self:getTimelineAxis()
	local clamped = math.clamp(t, 0, maxTime)
	return left + (clamped / maxTime) * width
end

function module:xToTime(absX)
	local maxTime = getMaxTime()
	local left, width = self:getTimelineAxis()
	local n = math.clamp((absX - self.area.AbsolutePosition.X - left) / width, 0, 1)
	return n * maxTime
end

function module:refreshTimelineAxis()
	if not self.area then return end
			local rulerLeft, rulerWidth = self:getRulerAxis()
		if self.ruler and self.ruler.Parent then
			self.ruler.Position = UDim2.new(0, rulerLeft, 0, 4)
			self.ruler.Size = UDim2.new(0, rulerWidth, 0, 22)
		end
		local left = self:getTimelineAxis()
		if self.playheadLine and self.playheadLine.Parent then

		self.playheadLine.Position = UDim2.new(0, left - 1, 0, 4)
	end
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

	self.topbarEditToolButtons = {}
	self.editToolsButton = UIFactory.button({
		Parent = bar,
		Name = "EditToolsButton",
		Position = UDim2.new(0, 246, 0.5, -13),
		Size = UDim2.new(0, 104, 0, 26),
		Text = "EDIT",
		Color = Theme.Panel,
		Corner = 4,
		TextSize = 10,
		ZIndex = 11,
	})
	UIFactory.setIcon(self.editToolsButton, Icons.Pencil, {Color = Theme.TextDim, TextOffset = 18})

	self.camerasButton = UIFactory.button({
		Parent = bar,
		Position = UDim2.new(1, -150, 0.5, -13),
		Size = UDim2.new(0, 130, 0, 26),
		Text = "Cameras",
		Color = Theme.Panel,
		Corner = 4,
		ZIndex = 11,
	})
	UIFactory.setIcon(self.camerasButton, Icons.Camera, {
		Color = Theme.Text,
		TextOffset = 20,
	})

	self:buildCamerasModal()
	self:buildEditModal()
	self:buildTimelinePanel()
	self:buildTrackPropertiesPanel()

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
		Size = UDim2.new(0, 320, 0, 580),
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
	closeBtn.Text = ""
	UIFactory.setIcon(closeBtn, Icons.X, {
		IconOnly = true,
		Color = Theme.TextDim,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 0.5, -7),
	})
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
	UIFactory.setIcon(switchRow, Icons.Eye, {
		IconOnly = true,
		Color = Theme.TextDim,
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(0, 10, 0.5, -8),
	})
	UIFactory.label({
		Parent = switchRow,
			Position = UDim2.new(0, 34, 0, 0),
			Size = UDim2.new(1, -84, 1, 0),
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
	local function rowBtn(name, text, color, yOffset, width, xOffset)
		local b = Instance.new("TextButton")
			b.Name = name
			b.Size = UDim2.new(0, width or 140, 0, 30)
			b.Position = UDim2.new(0, xOffset or 12, 0, yOffset)
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
	self.addCamButton = rowBtn("AddCamera", "Add Camera", Theme.Accent, 86, 140, 12)
	self.deleteTrackButton = rowBtn("DeleteTrack", "Delete Track", Theme.Danger, 122, 296, 12)
	UIFactory.setIcon(self.addCamButton, Icons.Plus, {Color = Theme.Text, TextOffset = 20})
	UIFactory.setIcon(self.deleteTrackButton, Icons.Trash, {Color = Theme.Text, TextOffset = 20})
	local editSection = Instance.new("Frame")
	editSection.Name = "EditCameraSection"
	editSection.Size = UDim2.new(1, -24, 0, 82)
	editSection.Position = UDim2.new(0, 12, 0, 166)
	editSection.BackgroundColor3 = Theme.Header
	editSection.BorderSizePixel = 0
	editSection.Parent = panel
	editSection.ZIndex = 52
	UIFactory.corner(editSection, 4)
	UIFactory.stroke(editSection, Theme.Border, 1)
	UIFactory.label({
		Parent = editSection,
		Position = UDim2.new(0, 10, 0, 3),
		Size = UDim2.new(1, -20, 0, 14),
		Text = "EDIT CAMERA",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		Color = Theme.TextDim,
		ZIndex = 53,
	})
	self.editToolButtons = {}
	local function editToolButton(name, text, y, mode)
		local button = UIFactory.button({
			Parent = editSection,
			Position = UDim2.new(0, 10, 0, y),
			Size = UDim2.new(1, -20, 0, 24),
			Text = text,
			Color = Theme.Panel,
			Corner = 4,
			TextSize = 10,
			ZIndex = 53,
		})
			button.Name = name
			UIFactory.setIcon(button, mode == "move" and Icons.Move3D or Icons.Rotate3D, {
				Color = Theme.TextDim,
				TextOffset = 20,
			})
			button.MouseButton1Click:Connect(function()
			self:setEditTool(mode)
			if self.onEditToolSelected then
				self.onEditToolSelected(mode)
			end
		end)
		self.editToolButtons[mode] = button
		return button
	end
	editToolButton("MoveCamera", "MOVE CAMERA", 20, "move")
	editToolButton("RotateCamera", "ROTATE CAMERA", 48, "rotate")
	self.editSection = editSection
	editSection.Visible = false
	local separator = Instance.new("Frame")
	separator.Size = UDim2.new(1, -24, 0, 1)
	separator.Position = UDim2.new(0, 12, 0, 158)
	separator.BackgroundColor3 = Theme.Border
	separator.BorderSizePixel = 0
	separator.Parent = panel
	separator.ZIndex = 52
	self.propertiesInfo = UIFactory.label({
		Parent = panel,
		Name = "KeyframePropertiesInfo",
		Position = UDim2.new(0, 12, 0, 169),
		Size = UDim2.new(1, -24, 0, 16),
		Text = "SELECT A KEYFRAME TO EDIT PROPERTIES",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		Color = Theme.TextMuted,
		ZIndex = 52,
	})
	local properties = Instance.new("Frame")
	properties.Name = "KeyframeProperties"
	properties.Size = UDim2.new(1, -24, 0, 370)
	properties.Position = UDim2.new(0, 12, 0, 193)
	properties.BackgroundTransparency = 1
	properties.BorderSizePixel = 0
	properties.Parent = panel
	properties.ZIndex = 52
	properties.Visible = false
	self.propertiesSection = properties
self.propertyFields = {}
		self.basePropertyFields = {}
		self.easingOptions = {"Linear", "EaseIn", "EaseOut", "EaseInOut"}
		self.easingValue = "EaseInOut"
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
	local function addField(key, label, x, y, color, target)

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
			(target or self.propertyFields)[key] = field
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
		sectionTitle("APPEARANCE", 180)
		addField("transparency", "T", 0, 198, Theme.Warning, self.basePropertyFields)
		addField("colorR", "R", 100, 198, Theme.AxisX, self.basePropertyFields)
		addField("colorG", "G", 200, 198, Theme.AxisY, self.basePropertyFields)
		addField("colorB", "B", 0, 226, Theme.AxisZ, self.basePropertyFields)
		sectionTitle("SIZE", 254)
		addField("sizeX", "X", 0, 272, Theme.AxisX, self.basePropertyFields)
		addField("sizeY", "Y", 100, 272, Theme.AxisY, self.basePropertyFields)
		addField("sizeZ", "Z", 200, 272, Theme.AxisZ, self.basePropertyFields)
		for _, field in pairs(self.basePropertyFields) do
			field.Visible = false
		end
		local apply = UIFactory.button({
		Parent = properties,
		Position = UDim2.new(0, 0, 0, 304),
		Size = UDim2.new(0, 142, 0, 28),
		Text = "APPLY",
		Color = Theme.Accent,
		Corner = 4,
		TextSize = 10,
		ZIndex = 53,
		})
		UIFactory.setIcon(apply, Icons.Check, {Color = Theme.Text, TextOffset = 20})
		apply.MouseButton1Click:Connect(function()
		if self.onPropertiesSubmitted then
			self.onPropertiesSubmitted(self:getPropertyValues())
		end
	end)
			self.easingButton = UIFactory.button({
			Parent = properties,
			Position = UDim2.new(0, 0, 0, 338),
			Size = UDim2.new(1, 0, 0, 26),
			Text = "EASING: EASEINOUT",
			Color = Theme.Panel,
			Corner = 4,
			TextSize = 10,
			ZIndex = 53,
		})
		self.easingButton.MouseButton1Click:Connect(function()
			local currentIndex = 1
			for index, option in ipairs(self.easingOptions) do
				if option == self.easingValue then
					currentIndex = index
					break
				end
			end
			currentIndex = currentIndex % #self.easingOptions + 1
			self.easingValue = self.easingOptions[currentIndex]
			self:setButtonLabel(self.easingButton, "EASING: " .. string.upper(self.easingValue))
			if self.onPropertiesSubmitted then
				self.onPropertiesSubmitted(self:getPropertyValues())
			end
		end)
		UIFactory.setIcon(self.easingButton, Icons.ChevronRight, {Color = Theme.TextDim, TextOffset = 20})
		local reset = UIFactory.button({

		Parent = properties,
		Position = UDim2.new(0, 154, 0, 304),
		Size = UDim2.new(0, 142, 0, 28),
		Text = "RESET",
		Color = Theme.PanelDark,
		Corner = 4,
		TextSize = 10,
		ZIndex = 53,
		})
		UIFactory.setIcon(reset, Icons.RotateCCW, {Color = Theme.Text, TextOffset = 20})
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

function module:buildEditModal()
	local backdrop = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Color3.new(0, 0, 0),
		Name = "EditModalBackdrop",
		ZIndex = 60,
	})
	backdrop.BackgroundTransparency = 1
	backdrop.Visible = false
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(0, 260, 0, 192),
		Color = Theme.Panel,
		Corner = 6,
		Name = "EditModal",
		ZIndex = 61,
	})
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.18)
	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Corner = 6,
		ZIndex = 62,
	})
	UIFactory.stroke(header, Theme.Border, 1)
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 2)
	accent.BackgroundColor3 = Theme.Accent
	accent.BorderSizePixel = 0
	accent.Parent = header
	accent.ZIndex = 63
	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 180, 1, 0),
		Text = "EDIT TOOLS",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Color = Theme.Text,
		ZIndex = 63,
	})
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 22, 0, 22)
	close.Position = UDim2.new(1, -28, 0.5, -11)
	close.BackgroundColor3 = Theme.Panel
	close.BorderSizePixel = 0
	close.Text = ""
	close.AutoButtonColor = false
	close.Parent = header
	close.ZIndex = 63
	UIFactory.setIcon(close, Icons.X, {
		IconOnly = true,
		Color = Theme.TextDim,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 0.5, -7),
	})
	UIFactory.corner(close, 3)
	UIFactory.stroke(close, Theme.Border, 1)
	self.editModalButtons = {}
	local function addTool(mode, text, y, icon)
		local button = UIFactory.button({
			Parent = panel,
			Name = string.upper(mode) .. "Tool",
			Position = UDim2.new(0, 12, 0, y),
			Size = UDim2.new(1, -24, 0, 28),
			Text = text,
			Color = Theme.PanelDark,
			Corner = 4,
			TextSize = 10,
			ZIndex = 62,
		})
		UIFactory.setIcon(button, icon, {Color = Theme.TextDim, TextOffset = 22})
		button.MouseButton1Click:Connect(function()
			self:setEditTool(mode)
			if self.onEditToolSelected then
				self.onEditToolSelected(mode)
			end
			self:closeEditModal()
		end)
		self.editModalButtons[mode] = button
	end
	addTool("select", "SELECT BASEPART", 44, Icons.Scan)
	addTool("move", "MOVE", 76, Icons.Move3D)
	addTool("rotate", "ROTATE", 108, Icons.Rotate3D)
	addTool("scale", "SCALE BASEPART", 140, Icons.Maximize)
	self.editModalBackdrop = backdrop
	self.editModalPanel = panel
	self.editModalOpen = false
	self.editToolsButton.MouseButton1Click:Connect(function()
		self:openEditModal()
	end)
	close.MouseButton1Click:Connect(function()
		self:closeEditModal()
	end)
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:closeEditModal()
		end
	end)
end

function module:openEditModal()
	if self.editModalOpen then return end
	self.editModalOpen = true
	self:repositionEditModal()
	self.editModalBackdrop.Visible = true
	self.editModalPanel.Visible = true
	self.editModalBackdrop.BackgroundTransparency = 0.55
	self.editModalPanel.Position = self.editModalPanel.Position + UDim2.new(0, 0, 0, -6)
	TweenService:Create(self.editModalPanel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = self._editModalTargetPos,
	}):Play()
end

function module:closeEditModal()
	if not self.editModalOpen then return end
	self.editModalOpen = false
	TweenService:Create(self.editModalBackdrop, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
	local current = self.editModalPanel.Position
	TweenService:Create(self.editModalPanel, TweenInfo.new(0.15), {
		Position = current + UDim2.new(0, 0, 0, -6),
	}):Play()
	task.delay(0.16, function()
		if not self.editModalOpen then
			self.editModalPanel.Visible = false
			self.editModalBackdrop.Visible = false
		end
	end)
end

function module:repositionEditModal()
	local button = self.editToolsButton
	local position = button.AbsolutePosition
	local size = button.AbsoluteSize
	local panel = self.editModalPanel
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(panel.Parent.AbsoluteSize.X, panel.Parent.AbsoluteSize.Y)
	local desiredX = math.clamp(position.X, 8, math.max(8, viewport.X - 268))
	local desiredY = math.clamp(position.Y + size.Y + 6, 8, math.max(8, viewport.Y - 200))
	self._editModalTargetPos = UDim2.new(0, desiredX, 0, desiredY)
	panel.Position = self._editModalTargetPos
end

function module:getPropertyValues()
	if not self.propertyKeyframe or not self.propertyFields then return nil end
	local values = {}
			for key, field in pairs(self.propertyFields) do
				local value = tonumber(field.Text)
				if not value then return nil end
				values[key] = value
			end
			for key, field in pairs(self.basePropertyFields or {}) do
				if field.Text ~= "" then
					local value = tonumber(field.Text)
					if not value then return nil end
					values[key] = value
				end
			end
			values.easing = self.easingValue or "EaseInOut"
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

function module:buildTrackPropertiesPanel()
	local panel = UIFactory.frame({
		Parent = self.gui,
		Name = "TrackPropertiesPanel",
		Size = UDim2.new(0, 268, 0, 188),
		Position = UDim2.new(0, 12, 0, 50),
		Color = Theme.Panel,
		Corner = 6,
		ZIndex = 60,
	})
	panel.Active = true
	panel.Draggable = true
	panel.Visible = false
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.18)
	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 30),
		Color = Theme.Header,
		Corner = 6,
		ZIndex = 61,
	})
	UIFactory.stroke(header, Theme.Border, 1)
	self.trackPropertiesTitle = UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -42, 1, 0),
		Text = "TRACK PROPERTIES",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		Color = Theme.Text,
		ZIndex = 62,
	})
	local closeButton = UIFactory.button({
		Parent = header,
		Position = UDim2.new(1, -26, 0.5, -10),
		Size = UDim2.new(0, 20, 0, 20),
		Text = "",
		Color = Theme.Panel,
		Corner = 3,
		TextSize = 10,
		ZIndex = 62,
	})
	UIFactory.setIcon(closeButton, Icons.X, {
		IconOnly = true,
		Color = Theme.TextDim,
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0.5, -6, 0.5, -6),
	})
	local function fieldLabel(text, y)
		UIFactory.label({
			Parent = panel,
			Position = UDim2.new(0, 12, 0, y),
			Size = UDim2.new(1, -24, 0, 14),
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			Color = Theme.TextDim,
			ZIndex = 61,
		})
	end
	local function textField(name, y, placeholder)
		local field = Instance.new("TextBox")
		field.Name = name
		field.Size = UDim2.new(1, -24, 0, 24)
		field.Position = UDim2.new(0, 12, 0, y)
		field.BackgroundColor3 = Theme.Background
		field.BorderSizePixel = 0
		field.ClearTextOnFocus = false
		field.PlaceholderText = placeholder
		field.PlaceholderColor3 = Theme.TextMuted
		field.Font = Enum.Font.Code
		field.TextSize = 10
		field.TextColor3 = Theme.Text
		field.TextXAlignment = Enum.TextXAlignment.Left
		field.Parent = panel
		field.ZIndex = 61
		UIFactory.corner(field, 4)
		UIFactory.stroke(field, Theme.Border, 1, 0.25)
		return field
	end
	fieldLabel("TRACK NAME", 40)
	self.trackRenameField = textField("TrackName", 54, "Camera name")
	fieldLabel("SEGMENT SPEED MULTIPLIER", 84)
	self.trackSpeedField = textField("SpeedMultiplier", 98, "1.00")
	self.trackEasingOptions = {"Linear", "EaseIn", "EaseOut", "EaseInOut"}
	self.trackPropertyEasing = "EaseInOut"
	self.trackEasingButton = UIFactory.button({
		Parent = panel,
		Position = UDim2.new(0, 12, 0, 128),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "EASING: EASEINOUT",
		Color = Theme.Header,
		Corner = 4,
		TextSize = 10,
		ZIndex = 61,
	})
	UIFactory.setIcon(self.trackEasingButton, Icons.ChevronRight, {Color = Theme.TextDim, TextOffset = 20})
	local apply = UIFactory.button({
		Parent = panel,
		Position = UDim2.new(0, 12, 0, 158),
		Size = UDim2.new(1, -24, 0, 22),
		Text = "APPLY TRACK PROPERTIES",
		Color = Theme.Accent,
		Corner = 4,
		TextSize = 9,
		ZIndex = 61,
	})
	UIFactory.setIcon(apply, Icons.Check, {Color = Theme.Text, TextOffset = 18})
	self.trackPropertiesPanel = panel
	closeButton.MouseButton1Click:Connect(function()
		self:closeTrackProperties()
	end)
	self.trackEasingButton.MouseButton1Click:Connect(function()
		local currentIndex = 1
		for index, option in ipairs(self.trackEasingOptions) do
			if option == self.trackPropertyEasing then
				currentIndex = index
				break
			end
		end
		currentIndex = currentIndex % #self.trackEasingOptions + 1
		self.trackPropertyEasing = self.trackEasingOptions[currentIndex]
		self:setButtonLabel(self.trackEasingButton, "EASING: " .. string.upper(self.trackPropertyEasing))
	end)
	apply.MouseButton1Click:Connect(function()
		local values = self:getTrackPropertiesValues()
		if values and self.onTrackPropertiesSubmitted and self.trackPropertiesCameraName then
			self.onTrackPropertiesSubmitted(self.trackPropertiesCameraName, values)
		end
	end)
end

function module:setButtonLabel(button, text)
	local label = UIFactory.getLabel(button)
	if label then
		label.Text = text
	elseif button then
		button.Text = text
	end
end

function module:getTrackPropertiesValues()
	if not self.trackRenameField or not self.trackSpeedField then return nil end
	local name = string.gsub(self.trackRenameField.Text or "", "^%s*(.-)%s*$", "%1")
	local speedMultiplier = tonumber(self.trackSpeedField.Text)
	if name == "" or not speedMultiplier or speedMultiplier <= 0 then return nil end
	return {
		name = name,
		speedMultiplier = speedMultiplier,
		easing = self.trackPropertyEasing or "EaseInOut",
	}
end

function module:openTrackProperties(cameraName, absolutePosition, metadata)
	if not self.trackPropertiesPanel then return end
	metadata = metadata or {}
	self.trackPropertiesCameraName = cameraName
	self.trackPropertiesTitle.Text = "TRACK: " .. string.upper(cameraName)
	self.trackRenameField.Text = cameraName
	self.trackSpeedField.Text = string.format("%.2f", metadata.speedMultiplier or 1)
	self.trackPropertyEasing = metadata.easing or "EaseInOut"
	self:setButtonLabel(self.trackEasingButton, "EASING: " .. string.upper(self.trackPropertyEasing))
	local guiSize = self.gui.AbsoluteSize
	local x = math.clamp((absolutePosition and absolutePosition.X or 12) + 12, 8, math.max(8, guiSize.X - 276))
	local y = math.clamp((absolutePosition and absolutePosition.Y or 50) - 164, 46, math.max(46, guiSize.Y - 196))
	self.trackPropertiesPanel.Position = UDim2.new(0, x, 0, y)
	self.trackPropertiesPanel.Visible = true
end

function module:closeTrackProperties()
	if self.trackPropertiesPanel then
		self.trackPropertiesPanel.Visible = false
	end
	self.trackPropertiesCameraName = nil
end

function module:updateTrackName(oldName, newName)
	if oldName == newName then return self.tracks[oldName] end
	local track = self.tracks[oldName]
	if not track or self.tracks[newName] then return nil end
	self.tracks[oldName] = nil
	self.tracks[newName] = track
	track.cameraName = newName
	track.row.Name = "Track_" .. newName
	track.label.Text = newName
	if self.activeCameraName == oldName then
		self.activeCameraName = newName
	end
	return track
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
	panel.Active = true
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

			self.trackPropertiesButton = UIFactory.button({
			Parent = header,
			Name = "TrackProperties",
			Position = UDim2.new(0, 438, 0.5, -12),
			Size = UDim2.new(0, 28, 0, 24),
			Text = "",
			Color = Theme.Panel,
			Corner = 4,
			TextSize = 16,
			ZIndex = 13,
		})
		UIFactory.setIcon(self.trackPropertiesButton, Icons.Settings, {
			IconOnly = true,
			Color = Theme.TextDim,
			Size = UDim2.new(0, 14, 0, 14),
			Position = UDim2.new(0.5, -7, 0.5, -7),
		})
		self.trackPropertiesButton.MouseButton1Click:Connect(function()
			if self.onTrackPropertiesButtonRequested then
				self.onTrackPropertiesButtonRequested()
			end
		end)

		self.timelineMinimizeButton = UIFactory.button({

		Parent = header,
		Name = "MinimizeTimeline",
		Position = UDim2.new(1, -154, 0.5, -12),
		Size = UDim2.new(0, 28, 0, 24),
		Text = "",
		Color = Theme.Panel,
		Corner = 4,
		TextSize = 16,
		ZIndex = 13,
	})
	UIFactory.setIcon(self.timelineMinimizeButton, Icons.Minus, {
		IconOnly = true,
		Color = Theme.TextDim,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 0.5, -7),
	})
	self.timelineMinimizeButton.MouseButton1Click:Connect(function()
		self:setTimelineMinimized(not self.timelineMinimized)
	end)

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
			self.tracksList.Size = UDim2.new(1, 0, 1, -28)
		self.tracksList.Position = UDim2.new(0, 0, 0, 26)

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
			local left, width = self:getRulerAxis()
		local ruler = UIFactory.frame({

		Parent = self.area,
		Size = UDim2.new(0, width, 0, 22),
		Position = UDim2.new(0, left, 0, 4),
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
	local left = self:getTimelineAxis()
	self.playheadLine.Position = UDim2.new(0, left - 1, 0, 4)
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

function module:setTrackRange(cameraName, startTime, endTime)
	local track = self.tracks[cameraName]
	if not track then return nil end
	local maxTime = getMaxTime()
	local start = math.clamp(tonumber(startTime) or track.startTime or 0, 0, maxTime)
	local finish = math.clamp(tonumber(endTime) or track.endTime or maxTime, 0, maxTime)
	if finish < start then
		start, finish = finish, start
	end
	if finish - start < TRACK_RESIZE_MIN_TIME then
		if self.trackResizeState and self.trackResizeState.side == "left" then
			start = math.max(0, finish - TRACK_RESIZE_MIN_TIME)
			finish = math.max(finish, start + TRACK_RESIZE_MIN_TIME)
		else
			finish = math.min(maxTime, start + TRACK_RESIZE_MIN_TIME)
			start = math.min(start, finish - TRACK_RESIZE_MIN_TIME)
		end
	end
	track.startTime = start
	track.endTime = finish
	if track.rangeVisual and track.rangeVisual.Parent then
		track.rangeVisual.Position = UDim2.new(start / maxTime, 0, 0, 0)
		track.rangeVisual.Size = UDim2.new((finish - start) / maxTime, 0, 1, 0)
	end
	if track.leftResizeHandle and track.leftResizeHandle.Parent then
		track.leftResizeHandle.Position = UDim2.new(0, 0, 0, -2)
	end
	if track.rightResizeHandle and track.rightResizeHandle.Parent then
		track.rightResizeHandle.Position = UDim2.new(1, -TRACK_RESIZE_HANDLE_WIDTH, 0, -2)
	end
	return start, finish
end

function module:endTrackResize()
	local state = self.trackResizeState
	self.trackResizeState = nil
	if self.trackResizeConnection then
		self.trackResizeConnection:Disconnect()
		self.trackResizeConnection = nil
	end
	if state and self.onTrackResizeEnded then
		self.onTrackResizeEnded(state.cameraName, state.startTime, state.endTime)
	end
end

function module:beginTrackResize(cameraName, side, input)
	local track = self.tracks[cameraName]
	if not track then return end
	self:endTrackResize()
	self.trackResizeState = {
		cameraName = cameraName,
		side = side,
		startTime = track.startTime or 0,
		endTime = track.endTime or getMaxTime(),
	}
	if self.onTrackSelected then
		self.onTrackSelected(cameraName)
	end
	if self.onTrackResizeStarted then
		self.onTrackResizeStarted(cameraName, self.trackResizeState.startTime, self.trackResizeState.endTime)
	end
	self.trackResizeConnection = UserInputService.InputChanged:Connect(function(changedInput)
		local state = self.trackResizeState
		if not state then return end
		if changedInput.UserInputType ~= Enum.UserInputType.MouseMovement and changedInput.UserInputType ~= Enum.UserInputType.Touch then return end
		local targetTime = self:xToTime(changedInput.Position.X)
		local startTime = state.startTime
		local endTime = state.endTime
		if state.side == "left" then
			startTime = math.clamp(targetTime, 0, endTime - TRACK_RESIZE_MIN_TIME)
		else
			endTime = math.clamp(targetTime, startTime + TRACK_RESIZE_MIN_TIME, getMaxTime())
		end
		local nextStart, nextEnd = self:setTrackRange(cameraName, startTime, endTime)
		state.startTime = nextStart or startTime
		state.endTime = nextEnd or endTime
		if self.onTrackResized then
			self.onTrackResized(cameraName, state.startTime, state.endTime)
		end
	end)
	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			self:endTrackResize()
		end
	end)
end

function module:getTrackColor(index)
	local palette = Theme.TrackPalette
	if not palette or #palette == 0 then return Theme.Accent end
	return palette[(index - 1) % #palette + 1]
end

function module:ensureTrack(cameraName)
	if self.tracks[cameraName] then return self.tracks[cameraName] end

	local row = Instance.new("Frame")
	row.Name = "Track_" .. cameraName
			row.Size = UDim2.new(1, 0, 0, 36)

	row.BackgroundColor3 = Theme.Panel
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
			row.Active = true
		self.trackOrder = self.trackOrder + 1
		row.LayoutOrder = self.trackOrder

	local trackColor = self:getTrackColor(self.trackOrder)

	row.Parent = self.tracksList
	row.ZIndex = 12
		UIFactory.corner(row, 6)
		local rowStroke = UIFactory.stroke(row, Theme.Border, 1, 0.5)
		rowStroke.Enabled = false
		local selectionStroke = UIFactory.stroke(row, trackColor, 2, 1)
		selectionStroke.Enabled = false

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, trackColor:Lerp(Theme.Panel, 0.45)),
		ColorSequenceKeypoint.new(1, trackColor:Lerp(Theme.Background, 0.8)),
	}
	grad.Rotation = 90
	grad.Parent = row

	local labelSurface = UIFactory.frame({
		Parent = row,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(0, KF_LABEL_OFFSET - 8, 1, -4),
		Color = Theme.Panel,
		Name = "TrackLabelArea",
		ZIndex = 12,
	})
	UIFactory.corner(labelSurface, 4)

	local label = UIFactory.label({
		Parent = row,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Text = cameraName,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Color = Theme.Text,
		ZIndex = 13,
	})

	local kfContainer = Instance.new("Frame")
	kfContainer.Name = "Keyframes"
			kfContainer.Size = UDim2.new(1, 0, 1, 0)
		kfContainer.Position = UDim2.new(0, 0, 0, 0)

	kfContainer.BackgroundTransparency = 1
	kfContainer.ClipsDescendants = false
	kfContainer.Parent = row
	kfContainer.ZIndex = 13

			local rangeVisual = UIFactory.frame({
				Parent = kfContainer,
				Size = UDim2.new(1, 0, 1, -4),
			Position = UDim2.new(0, 0, 0, 0),
			Color = trackColor,
			Name = "TrackRange",
			ZIndex = 13,
		})
			rangeVisual.Active = true
			rangeVisual.ClipsDescendants = false
				rangeVisual.BackgroundTransparency = 0.82

		UIFactory.corner(rangeVisual, 6)
		local rangeStroke = UIFactory.stroke(rangeVisual, trackColor, 1, 0.55)
		grad.Parent = rangeVisual

		local colorBar = UIFactory.frame({
			Parent = rangeVisual,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 3, 1, 0),
			Color = trackColor,
			Name = "TrackColorBar",
			ZIndex = 15,
		})
		colorBar.BackgroundTransparency = 0.15
		UIFactory.corner(colorBar, 2)

		labelSurface.Parent = rangeVisual
		labelSurface.Position = UDim2.new(0, 8, 0, 3)
		labelSurface.Size = UDim2.new(1, -16, 1, -6)
		labelSurface.BackgroundColor3 = trackColor:Lerp(Theme.PanelDark, 0.72)
		labelSurface.BackgroundTransparency = 0.35
		labelSurface.ZIndex = 14
		label.Parent = labelSurface
		label.Position = UDim2.new(0, 8, 0, 0)
		label.Size = UDim2.new(1, -16, 1, 0)
		label.ZIndex = 15

		local function createResizeHandle(side)
				local handle = Instance.new("Frame")
				handle.Name = side == "left" and "LeftResizeHandle" or "RightResizeHandle"
				handle.Size = UDim2.new(0, TRACK_RESIZE_HANDLE_WIDTH, 1, 4)
				handle.Position = side == "left" and UDim2.new(0, 0, 0, -2) or UDim2.new(1, -TRACK_RESIZE_HANDLE_WIDTH, 0, -2)
			handle.BackgroundColor3 = trackColor
			handle.BackgroundTransparency = 0.08
			handle.BorderSizePixel = 0
			handle.Active = true
			handle.ZIndex = 16
				handle.Parent = rangeVisual
			UIFactory.corner(handle, 3)
			handle.Visible = false
			handle.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					self:beginTrackResize(cameraName, side, input)
				end
			end)
			return handle
		end

		local leftResizeHandle = createResizeHandle("left")
		local rightResizeHandle = createResizeHandle("right")

	local track = {
		row = row,
		labelSurface = labelSurface,
		label = label,
		keyframesContainer = kfContainer,
		keyframes = {},
		activeKeyframe = nil,
			cameraName = cameraName,
			selectionStroke = selectionStroke,
			rangeVisual = rangeVisual,
			rangeStroke = rangeStroke,
			colorBar = colorBar,
			color = trackColor,
			leftResizeHandle = leftResizeHandle,
			rightResizeHandle = rightResizeHandle,
			startTime = 0,
			endTime = getMaxTime(),

	}

			local function containsPoint(guiObject, point)
			local origin = guiObject.AbsolutePosition
			local size = guiObject.AbsoluteSize
			return point.X >= origin.X and point.X <= origin.X + size.X and point.Y >= origin.Y and point.Y <= origin.Y + size.Y
		end
		rangeVisual.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local position = input.Position
			if not containsPoint(rangeVisual, position) then return end
			if containsPoint(leftResizeHandle, position) or containsPoint(rightResizeHandle, position) then return end
			for _, keyframe in ipairs(track.keyframes) do
				if keyframe.frame and keyframe.frame.Parent and containsPoint(keyframe.frame, position) then
					return
				end
			end
			if self.onTrackSelected then
				self.onTrackSelected(track.cameraName)
			end
		end)

	self.tracks[cameraName] = track
	self:setTrackRange(cameraName, 0, getMaxTime())
		self:refreshTimelineAxis()

	task.defer(function()
		if self.tracks[cameraName] == track then
			self:refreshTimelineAxis()
		end
	end)
	return track
end

function module:setActiveCamera(cameraName)
	self.activeCameraName = cameraName
	for name, tr in pairs(self.tracks) do
		local highlight = (name == cameraName)
		local color = tr.color or Theme.Accent
		tr.row.BackgroundColor3 = Theme.Panel
		if tr.labelSurface then
			tr.labelSurface.BackgroundColor3 = color:Lerp(Theme.PanelDark, highlight and 0.45 or 0.78)
			tr.labelSurface.BackgroundTransparency = highlight and 0.1 or 0.4
		end
		if tr.selectionStroke then
			tr.selectionStroke.Enabled = false
		end
		if tr.label then
			tr.label.TextColor3 = highlight and Theme.Text or Theme.TextDim
		end
		if tr.colorBar then
			tr.colorBar.Size = UDim2.new(0, highlight and 4 or 3, 1, 0)
			tr.colorBar.BackgroundTransparency = highlight and 0 or 0.35
		end
		if tr.selectionStroke then
			tr.selectionStroke.Color = color
			tr.selectionStroke.Thickness = 2
			tr.selectionStroke.Transparency = highlight and 0.15 or 1
		end
		if tr.rangeStroke then
			tr.rangeStroke.Color = color
			tr.rangeStroke.Thickness = highlight and 2 or 1
			tr.rangeStroke.Transparency = highlight and 0 or 0.6
		end
		if tr.rangeVisual then
			tr.rangeVisual.BackgroundColor3 = color
			tr.rangeVisual.BackgroundTransparency = highlight and 0.7 or 0.86
		end
		if tr.leftResizeHandle then
			tr.leftResizeHandle.Visible = highlight
		end
		if tr.rightResizeHandle then
			tr.rightResizeHandle.Visible = highlight
		end
	end
end


function module:removeTrack(cameraName)
	if self.trackPropertiesCameraName == cameraName then
		self:closeTrackProperties()
	end
	local track = self.tracks[cameraName]
	if not track then return end
	if track.row and track.row.Parent then
		track.row:Destroy()
	end
	self.tracks[cameraName] = nil
	if self.activeCameraName == cameraName then
		self.activeCameraName = nil
	end
	self:refreshTimelineAxis()
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
		for _, item in ipairs(keyframeTimes) do
			local time = typeof(item) == "table" and item.time or item
			local data = typeof(item) == "table" and item or nil
			self:createKeyframeVisual(name, time, data)
		end
	end
end

function module:createKeyframeVisual(cameraName, time, data)
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
		data = data,
		dragging = false,
		suppressClick = false,
	}
	track.keyframes[#track.keyframes + 1] = record
	diamond.MouseButton1Click:Connect(function()
		if record.suppressClick then
			record.suppressClick = false
			return
		end
		if self.onKeyframeSelected then
			self.onKeyframeSelected((record.data and record.data.cameraName) or track.cameraName, record.data or {
				time = record.time,
				cameraName = track.cameraName,
			})
		end
	end)

	local defaultSize = diamond.Size
	local hoverSize = UDim2.new(0, 16, 0, 16)
	local function updateVisual(targetTime)
		local normalized = math.clamp(targetTime or record.time or 0, 0, maxTime)
		local currentX = normalized / maxTime
		record.time = normalized
		if record.data then
			record.data.time = normalized
		end
		diamond.Name = "Keyframe_" .. tostring(normalized)
		guide.Position = UDim2.new(currentX, 0, 0, -4)
		diamond.Position = UDim2.new(
			currentX,
			record.expanded and -9 or -6,
			0.5,
			record.expanded and -9 or -6
		)
	end

	local function endPress()
		self.keyframePressActive = false
		if self.keyframePressedRecord ~= record then return end
		self.keyframePressedRecord = nil
		if record.dragging then
			record.dragging = false
			record.suppressClick = true
			if self.keyframeDragConnection then
				self.keyframeDragConnection:Disconnect()
				self.keyframeDragConnection = nil
			end
			if self.onKeyframeDragEnded then
				self.onKeyframeDragEnded((record.data and record.data.cameraName) or track.cameraName, record.data)
			end
			task.delay(0.1, function()
				record.suppressClick = false
			end)
		end
	end

	diamond.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(diamond, TweenInfo.new(0.15), {
				Size = hoverSize,
				Position = UDim2.new(record.time / maxTime, -8, 0.5, -8),
			}):Play()
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		self.keyframePressActive = true
		self.keyframePressedRecord = record
		self.keyframePressId = (self.keyframePressId or 0) + 1
		local pressId = self.keyframePressId
		if self.onKeyframePressStarted then
			self.onKeyframePressStarted()
		end
		task.delay(KEYFRAME_HOLD_DURATION, function()
			if not self.keyframePressActive or self.keyframePressId ~= pressId or self.keyframePressedRecord ~= record then return end
			record.dragging = true
			record.suppressClick = true
			if self.onKeyframeDragStarted then
				self.onKeyframeDragStarted((record.data and record.data.cameraName) or track.cameraName, record.data)
			end
			if self.keyframeDragConnection then
				self.keyframeDragConnection:Disconnect()
			end
			self.keyframeDragConnection = UserInputService.InputChanged:Connect(function(changedInput)
				if not record.dragging then return end
				if changedInput.UserInputType ~= Enum.UserInputType.MouseMovement and changedInput.UserInputType ~= Enum.UserInputType.Touch then return end
				local targetTime = self:xToTime(changedInput.Position.X)
				if self.onKeyframeDragged then
					targetTime = self.onKeyframeDragged((record.data and record.data.cameraName) or track.cameraName, record.data, targetTime) or targetTime
				end
				updateVisual(targetTime)
			end)
		end)
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				endPress()
			end
		end)
	end)
	diamond.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(diamond, TweenInfo.new(0.15), {
				Size = record.expanded and UDim2.new(0, 18, 0, 18) or defaultSize,
				Position = UDim2.new(
					record.time / maxTime,
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
			local kfX = self:timeToX(kf.time)
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

function module:createControlButton(index, text, color, callback, icon)
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
	if icon then
		UIFactory.setIcon(btn, icon, {
			IconOnly = true,
			Color = Theme.TextDim,
			Size = UDim2.new(0, 15, 0, 15),
			Position = UDim2.new(0.5, -7, 0.5, -7),
		})
	end
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
	local pixelPos = self:timeToX(clampedTime)

	self.playheadLine.Position = UDim2.new(0, pixelPos - 1, 0, 4)

	local mins = math.floor(clampedTime / 60)
	local secs = math.floor(clampedTime % 60)
	local totalMins = math.floor(maxTime / 60)
	local totalSecs = math.floor(maxTime % 60)
	self.timeLabel.Text = string.format("%02d:%02d / %02d:%02d", mins, secs, totalMins, totalSecs)

	self:updatePlayheadProximity(clampedTime, pixelPos)
end

return module
