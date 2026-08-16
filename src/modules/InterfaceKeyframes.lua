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
