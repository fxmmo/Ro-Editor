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
		Size = UDim2.new(0, 32, 0, 26),
		Text = "",
		Color = Theme.Panel,
		Corner = 4,
		TextSize = 10,
		ZIndex = 11,
	})
	UIFactory.setIcon(self.editToolsButton, Icons.Pencil, {IconOnly = true, Color = Theme.TextDim, Size = UDim2.new(0, 16, 0, 16)})

	self.camerasButton = UIFactory.button({
		Parent = bar,
		Position = UDim2.new(1, -58, 0.5, -13),
		Size = UDim2.new(0, 32, 0, 26),
		Text = "",
		Color = Theme.Panel,
		Corner = 4,
		ZIndex = 11,
	})
	UIFactory.setIcon(self.camerasButton, Icons.Camera, {
		IconOnly = true,
		Color = Theme.Text,
		Size = UDim2.new(0, 16, 0, 16),
	})

	self:buildCamerasModal()
	self:buildEditModal()
	self:buildTimelinePanel()
	self:buildTrackPropertiesPanel()

	return bar
end


return module
