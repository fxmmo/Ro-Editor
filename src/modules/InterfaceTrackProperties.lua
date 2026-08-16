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


return module
