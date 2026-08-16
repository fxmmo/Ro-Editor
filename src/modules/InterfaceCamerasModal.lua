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
		local fields = target or self.propertyFields
		fields[key] = field
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


return module
