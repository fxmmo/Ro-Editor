local Dev = _G.__RoEditorDev
if not Dev then
	local _cache = {}
	Dev = {}
	function Dev:Import(url)
		if _cache[url] then return _cache[url] end
		local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
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


return module
