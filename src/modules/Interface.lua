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
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Icons = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Icon_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local module = {}
module.__index = module
local BASE = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/"

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


local function importInterfaceModule(name)
	local partial = Dev:Import(BASE .. "modules/" .. name .. ".lua")
	if not partial then error("[Ro-Editor] Failed to import " .. name) end
	return partial
end
local function delegate(source, name)
	return function(self, ...)
		local method = source[name]
		if type(method) ~= "function" then error("[Ro-Editor] Missing method " .. name) end
		return method(self, ...)
	end
end
local InterfaceTopbar = importInterfaceModule("InterfaceTopbar")
local InterfaceCamerasModal = importInterfaceModule("InterfaceCamerasModal")
local InterfaceEditModal = importInterfaceModule("InterfaceEditModal")
local InterfaceKeyframeProperties = importInterfaceModule("InterfaceKeyframeProperties")
local InterfaceTrackProperties = importInterfaceModule("InterfaceTrackProperties")
local InterfaceTimelinePanel = importInterfaceModule("InterfaceTimelinePanel")
local InterfaceTracks = importInterfaceModule("InterfaceTracks")
local InterfaceKeyframes = importInterfaceModule("InterfaceKeyframes")
module.buildTopBar = delegate(InterfaceTopbar, "buildTopBar")
module.buildCamerasModal = delegate(InterfaceCamerasModal, "buildCamerasModal")
module.buildEditModal = delegate(InterfaceEditModal, "buildEditModal")
module.openEditModal = delegate(InterfaceEditModal, "openEditModal")
module.closeEditModal = delegate(InterfaceEditModal, "closeEditModal")
module.repositionEditModal = delegate(InterfaceEditModal, "repositionEditModal")
module.getPropertyValues = delegate(InterfaceEditModal, "getPropertyValues")
module.setKeyframeProperties = delegate(InterfaceKeyframeProperties, "setKeyframeProperties")
module.clearKeyframeProperties = delegate(InterfaceKeyframeProperties, "clearKeyframeProperties")
module.setEditTool = delegate(InterfaceKeyframeProperties, "setEditTool")
module.setEditSectionVisible = delegate(InterfaceKeyframeProperties, "setEditSectionVisible")
module.toggleEditSection = delegate(InterfaceKeyframeProperties, "toggleEditSection")
module.setViewToggle = delegate(InterfaceKeyframeProperties, "setViewToggle")
module.openCamerasModal = delegate(InterfaceKeyframeProperties, "openCamerasModal")
module.closeCamerasModal = delegate(InterfaceKeyframeProperties, "closeCamerasModal")
module.repositionModal = delegate(InterfaceKeyframeProperties, "repositionModal")
module.setTimelineMinimized = delegate(InterfaceKeyframeProperties, "setTimelineMinimized")
module.buildTrackPropertiesPanel = delegate(InterfaceTrackProperties, "buildTrackPropertiesPanel")
module.setButtonLabel = delegate(InterfaceTrackProperties, "setButtonLabel")
module.getTrackPropertiesValues = delegate(InterfaceTrackProperties, "getTrackPropertiesValues")
module.openTrackProperties = delegate(InterfaceTrackProperties, "openTrackProperties")
module.closeTrackProperties = delegate(InterfaceTrackProperties, "closeTrackProperties")
module.updateTrackName = delegate(InterfaceTrackProperties, "updateTrackName")
module.buildTimelinePanel = delegate(InterfaceTimelinePanel, "buildTimelinePanel")
module.buildRuler = delegate(InterfaceTimelinePanel, "buildRuler")
module.buildPlayhead = delegate(InterfaceTimelinePanel, "buildPlayhead")
module.setTrackRange = delegate(InterfaceTimelinePanel, "setTrackRange")
module.endTrackResize = delegate(InterfaceTimelinePanel, "endTrackResize")
module.beginTrackResize = delegate(InterfaceTimelinePanel, "beginTrackResize")
module.getTrackColor = delegate(InterfaceTimelinePanel, "getTrackColor")
module.ensureTrack = delegate(InterfaceTracks, "ensureTrack")
module.setActiveCamera = delegate(InterfaceTracks, "setActiveCamera")
module.removeTrack = delegate(InterfaceTracks, "removeTrack")
module.renderKeyframes = delegate(InterfaceKeyframes, "renderKeyframes")
module.createKeyframeVisual = delegate(InterfaceKeyframes, "createKeyframeVisual")
module.removeKeyframeVisual = delegate(InterfaceKeyframes, "removeKeyframeVisual")
module.updatePlayheadProximity = delegate(InterfaceKeyframes, "updatePlayheadProximity")
module.createControlButton = delegate(InterfaceKeyframes, "createControlButton")
module.createIconControl = delegate(InterfaceKeyframes, "createIconControl")
module.setPlayheadPosition = delegate(InterfaceKeyframes, "setPlayheadPosition")
return module
