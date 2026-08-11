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
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
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
	self.modalOpen = false
	return self
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

	-- Single launcher button (was 3 buttons: View / Add / Edit Camera)
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

	return bar
end

-- Floating window containing View / Add / Edit Camera
function module:buildCamerasModal()
	-- Backdrop
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

	-- Modal panel
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(0, 240, 0, 170),
		Position = UDim2.new(0.5, -120, 0.5, -85),
		Color = Theme.Panel,
		Corner = 6,
		Name = "CamerasModal",
		ZIndex = 51,
	})
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.18)

	-- Header
	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Corner = 6,
		ZIndex = 52,
	})
	UIFactory.stroke(header, Theme.Border, 1)

	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 160, 1, 0),
		Text = "Cameras",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Color = Theme.Text,
		ZIndex = 53,
	})

	-- Close button (×)
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

	-- Helper that styles a row button
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
		-- hover/press
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

	self.camerasPanel = self
	self.camerasPanel.modalPanel   = panel
	self.camerasPanel.modalBackdrop = backdrop
	self.camerasPanel.viewButton   = rowBtn("ViewCamera",  "View Camera",  Theme.Panel,      44)
	self.camerasPanel.addCamButton = rowBtn("AddCamera",   "Add Camera",   Theme.Accent,     82)
	self.camerasPanel.editButton   = rowBtn("EditCamera",  "Edit Camera",  Theme.Panel,      120)

	-- Hidden until opened
	panel.Visible = false
	self.modalOpen = false

	-- Launcher opens the modal
	self.camerasButton.MouseButton1Click:Connect(function()
		self:openCamerasModal()
	end)

	-- Close interactions
	closeBtn.MouseButton1Click:Connect(function() self:closeCamerasModal() end)
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			self:closeCamerasModal()
		end
	end)
end

function module:openCamerasModal()
	if self.modalOpen then return end
	self.modalOpen = true
	self.modalBackdrop.Visible = true
	self.modalPanel.Visible = true
	self.modalBackdrop.BackgroundTransparency = 0.55
	TweenService:Create(self.modalPanel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -120, 0.5, -85)
	}):Play()
end

function module:closeCamerasModal()
	if not self.modalOpen then return end
	self.modalOpen = false
	TweenService:Create(self.modalBackdrop, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
	TweenService:Create(self.modalPanel, TweenInfo.new(0.15), {
		Position = UDim2.new(0.5, -110, 0.5, -75)
	}):Play()
	task.delay(0.16, function()
		if not self.modalOpen then
			self.modalPanel.Visible = false
			self.modalBackdrop.Visible = false
			self.modalPanel.Position = UDim2.new(0.5, -120, 0.5, -85)
		end
	end)
end

function module:buildTimelinePanel()
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 1, -160),
		Color = Theme.Background,
		Name = "TimelinePanel",
		ZIndex = 10,
	})
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

	self:buildRuler()
	self:buildTrack()
	self:buildPlayhead()

	return panel
end

function module:buildRuler()
	local ruler = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 4),
		Color = Theme.PanelDark,
		Name = "Ruler",
		ZIndex = 12,
	})
	ruler.BackgroundTransparency = 1

	local maxTime = Config.MaxTime or 10

	for i = 0, maxTime do
		local xPos = i / maxTime

		local marker = Instance.new("Frame")
		marker.Size = UDim2.new(0, 1, 0, 12)
		marker.Position = UDim2.new(xPos, 0, 0, 6)
		marker.BackgroundColor3 = Theme.TextMuted
		marker.BackgroundTransparency = 0.3
		marker.BorderSizePixel = 0
		marker.Parent = ruler
		marker.ZIndex = 13

		UIFactory.label({
			Parent = marker,
			Position = UDim2.new(0, -14, 1, 2),
			Size = UDim2.new(0, 28, 0, 12),
			Text = string.format("%ds", i),
			Font = Enum.Font.GothamMedium,
			TextSize = 9,
			Color = Theme.TextMuted,
			XAlign = Enum.TextXAlignment.Center,
			ZIndex = 13,
		})

		if i < maxTime then
			local sub = Instance.new("Frame")
			sub.Size = UDim2.new(0, 1, 0, 6)
			sub.Position = UDim2.new(xPos + (0.5 / maxTime), 0, 0, 9)
			sub.BackgroundColor3 = Theme.TextMuted
			sub.BackgroundTransparency = 0.7
			sub.BorderSizePixel = 0
			sub.Parent = ruler
			sub.ZIndex = 13
		end
	end
end

function module:buildTrack()
	self.track = UIFactory.frame({
		Parent = self.area,
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 0, 32),
		Color = Theme.Panel,
		Corner = 4,
		Name = "KeyframeTrack",
		ZIndex = 12,
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Theme.Panel),
			ColorSequenceKeypoint.new(1, Theme.Panel:Lerp(Theme.Background, 0.3))
		},
		GradientRotation = 90,
	})
	UIFactory.stroke(self.track, Theme.Border, 1, 0.5)

	UIFactory.label({
		Parent = self.track,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Text = "Camera",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		Color = Theme.TextDim,
		ZIndex = 13,
	})

	self.keyframeContainer = Instance.new("Frame")
	self.keyframeContainer.Name = "Keyframes"
	self.keyframeContainer.Size = UDim2.new(1, -110, 1, 0)
	self.keyframeContainer.Position = UDim2.new(0, 100, 0, 0)
	self.keyframeContainer.BackgroundTransparency = 1
	self.keyframeContainer.Parent = self.track
	self.keyframeContainer.ZIndex = 13

	self:renderKeyframes({0, 2.5, 5, 7.5, 10})
end

function module:renderKeyframes(keyframeTimes)
	for _, child in ipairs(self.keyframeContainer:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local maxTime = Config.MaxTime or 10

	for _, time in ipairs(keyframeTimes) do
		local xPos = time / maxTime

		local guide = Instance.new("Frame")
		guide.Size = UDim2.new(0, 1, 1, 8)
		guide.Position = UDim2.new(xPos, 0, 0, -4)
		guide.BackgroundColor3 = Theme.Accent or Theme.Playhead
		guide.BackgroundTransparency = 0.85
		guide.BorderSizePixel = 0
		guide.Parent = self.keyframeContainer
		guide.ZIndex = 13

		local diamond = Instance.new("Frame")
		diamond.Name = "Keyframe_" .. tostring(time)
		diamond.Size = UDim2.new(0, 10, 0, 10)
		diamond.Position = UDim2.new(xPos, -5, 0.5, -5)
		diamond.BackgroundColor3 = Theme.Accent or Theme.Playhead
		diamond.BorderSizePixel = 0
		diamond.Rotation = 45
		diamond.Parent = self.keyframeContainer
		diamond.ZIndex = 14

		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Panel
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = diamond

		local defaultSize = diamond.Size
		local hoverSize = UDim2.new(0, 14, 0, 14)

		diamond.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				game:GetService("TweenService"):Create(diamond, TweenInfo.new(0.15), {
					Size = hoverSize,
					Position = UDim2.new(xPos, -7, 0.5, -7)
				}):Play()
			end
		end)
		diamond.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				game:GetService("TweenService"):Create(diamond, TweenInfo.new(0.15), {
					Size = defaultSize,
					Position = UDim2.new(xPos, -5, 0.5, -5)
				}):Play()
			end
		end)
	end
end

function module:buildPlayhead()
	self.playheadLine = Instance.new("Frame")
	self.playheadLine.Name = "PlayheadLine"
	self.playheadLine.Size = UDim2.new(0, 2, 1, -8)
	self.playheadLine.Position = UDim2.new(0, 8, 0, 4)
	self.playheadLine.BackgroundColor3 = Theme.Playhead
	self.playheadLine.BorderSizePixel = 0
	self.playheadLine.Parent = self.area
	self.playheadLine.ZIndex = 20

	local dashPattern = Instance.new("Frame")
	dashPattern.Size = UDim2.new(1, 0, 1, 0)
	dashPattern.BackgroundTransparency = 1
	dashPattern.Parent = self.playheadLine

	self.playhead = UIFactory.frame({
		Parent = self.playheadLine,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 0, -7),
		Color = Theme.Playhead,
		Corner = 3,
		ZIndex = 21,
	})

	UIFactory.frame({
		Parent = self.playhead,
		Size = UDim2.new(1, 4, 1, 4),
		Position = UDim2.new(0, -2, 0, -2),
		Color = Color3.new(0, 0, 0),
		Corner = 4,
		ZIndex = 20,
	}).BackgroundTransparency = 0.85

	local triangle = Instance.new("Frame")
	triangle.Size = UDim2.new(0, 8, 0, 8)
	triangle.Position = UDim2.new(0.5, -4, 0.5, -4)
	triangle.BackgroundColor3 = Color3.new(1, 1, 1)
	triangle.BorderSizePixel = 0
	triangle.Rotation = 45
	triangle.Parent = self.playhead
	triangle.ZIndex = 22

	local bottomHandle = UIFactory.frame({
		Parent = self.playheadLine,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 1, -7),
		Color = Theme.Playhead,
		Corner = 3,
		ZIndex = 21,
	})
	bottomHandle.Rotation = 180

	local bottomTriangle = Instance.new("Frame")
	bottomTriangle.Size = UDim2.new(0, 8, 0, 8)
	bottomTriangle.Position = UDim2.new(0.5, -4, 0.5, -4)
	bottomTriangle.BackgroundColor3 = Color3.new(1, 1, 1)
	bottomTriangle.BorderSizePixel = 0
	bottomTriangle.Rotation = 45
	bottomTriangle.Parent = bottomHandle
	bottomTriangle.ZIndex = 22
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
	local maxTime = Config.MaxTime or 10
	local clampedTime = math.clamp(time, 0, maxTime)
	local xPos = clampedTime / maxTime

	local areaWidth = self.area.AbsoluteSize.X - 16
	local pixelPos = 8 + (xPos * areaWidth)

	self.playheadLine.Position = UDim2.new(0, pixelPos, 0, 4)

	local mins = math.floor(clampedTime / 60)
	local secs = math.floor(clampedTime % 60)
	local totalMins = math.floor(maxTime / 60)
	local totalSecs = math.floor(maxTime % 60)
	self.timeLabel.Text = string.format("%02d:%02d / %02d:%02d", mins, secs, totalMins, totalSecs)
end

return module