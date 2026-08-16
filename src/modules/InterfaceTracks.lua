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


return module
