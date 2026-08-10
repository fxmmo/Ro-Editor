local Players = game:GetService("Players")
local ThemeConfig = require(script.Parent.ThemeConfig)
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local UIFactory = require(script.Parent.UIFactory)

local module = {}
module.__index = module

function module.new()
	local self = setmetatable({}, module)
	local player = Players.LocalPlayer
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "StudioTimelineSystem"
	self.gui.ResetOnSpawn = false
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = player:WaitForChild("PlayerGui")
	return self
end

function module:buildTopBar()
	local bar = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Name = "TopBar",
	})
	UIFactory.stroke(bar, Theme.Border, 1)

	UIFactory.label({
		Parent = bar,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 200, 1, 0),
		Text = "Camera Animator",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Color = Theme.Text,
	})

	self.editButton = UIFactory.button({
		Parent = bar,
		Position = UDim2.new(1, -240, 0.5, -12),
		Size = UDim2.new(0, 100, 0, 24),
		Text = "Edit Camera",
		Color = Theme.Panel,
	})

	self.viewButton = UIFactory.button({
		Parent = bar,
		Position = UDim2.new(1, -130, 0.5, -12),
		Size = UDim2.new(0, 100, 0, 24),
		Text = "View Camera",
		Color = Theme.Panel,
	})

	return bar
end

function module:buildTimelinePanel()
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 140),
		Position = UDim2.new(0, 0, 1, -140),
		Color = Theme.Background,
		Name = "TimelinePanel",
	})
	UIFactory.stroke(panel, Theme.Border, 1)

	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Name = "Header",
	})

	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0, 120, 1, 0),
		Text = "Animation Editor",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Color = Theme.Text,
	})

	self.controls = UIFactory.frame({
		Parent = header,
		Position = UDim2.new(0, 140, 0, 2),
		Size = UDim2.new(0, 260, 1, -4),
		Color = Theme.Header,
		Name = "Controls",
	})
	self.controls.BackgroundTransparency = 1

	self.timeLabel = UIFactory.label({
		Parent = header,
		Position = UDim2.new(1, -110, 0, 0),
		Size = UDim2.new(0, 100, 1, 0),
		Text = "00:00 / 00:10",
		Font = Enum.Font.Code,
		TextSize = 12,
		Color = Theme.TextDim,
		XAlign = Enum.TextXAlignment.Right,
	})

	self.area = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, -16, 1, -36),
		Position = UDim2.new(0, 8, 0, 32),
		Color = Theme.PanelDark,
		Corner = 4,
		Name = "TimelineArea",
	})
	UIFactory.stroke(self.area, Theme.Border, 1)

	self:buildRuler()
	self:buildTrack()
	self:buildPlayhead()

	return panel
end

function module:buildRuler()
	local ruler = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(1, -10, 0, 18),
		Position = UDim2.new(0, 5, 0, 2),
		Color = Theme.PanelDark,
		Name = "Ruler",
	})
	ruler.BackgroundTransparency = 1

	for i = 0, Config.MaxTime do
		local marker = Instance.new("Frame")
		marker.Size = UDim2.new(0, 1, 0, 10)
		marker.Position = UDim2.new(i / Config.MaxTime, 0, 0, 4)
		marker.BackgroundColor3 = Theme.TextMuted
		marker.BorderSizePixel = 0
		marker.Parent = ruler

		UIFactory.label({
			Parent = marker,
			Position = UDim2.new(0, -12, 1, 0),
			Size = UDim2.new(0, 24, 0, 10),
			Text = tostring(i) .. "s",
			Font = Enum.Font.Code,
			TextSize = 9,
			Color = Theme.TextMuted,
			XAlign = Enum.TextXAlignment.Center,
		})
	end
end

function module:buildTrack()
	self.track = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(1, -10, 0, 32),
		Position = UDim2.new(0, 5, 0, 28),
		Color = Theme.Panel,
		Corner = 3,
		Name = "KeyframeTrack",
	})
	UIFactory.stroke(self.track, Theme.Border, 1)

	UIFactory.label({
		Parent = self.track,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Text = "Camera",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		Color = Theme.TextDim,
	})
end

function module:buildPlayhead()
	self.playhead = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(0, 2, 1, -4),
		Position = UDim2.new(0, 5, 0, 2),
		Color = Theme.Playhead,
		Name = "Playhead",
	})
	self.playhead.ZIndex = 10

	local top = UIFactory.frame({
		Parent = self.playhead,
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(0.5, -6, 0, -6),
		Color = Theme.Playhead,
		Corner = 6,
	})
	top.ZIndex = 11
end

function module:createControlButton(index, text, color, callback)
	local btn = UIFactory.button({
		Parent = self.controls,
		Position = UDim2.new(0, (index - 1) * 42, 0.5, -12),
		Size = UDim2.new(0, 38, 0, 24),
		Text = text,
		Color = color or Theme.Panel,
	})
	btn.MouseButton1Click:Connect(callback)
	return btn
end

return module
