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
local CACHE_BUST = Dev.__RoEditorVersion and "?v=" .. tostring(Dev.__RoEditorVersion) or ""
local UIFactory = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/UIFactory.lua" .. CACHE_BUST) or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua" .. CACHE_BUST) or error("[Ro-Editor] import failed")
local Icons = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Icon_Config.lua" .. CACHE_BUST) or error("[Ro-Editor] import failed")
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


local function merge(source)
	for key, value in pairs(source) do module[key] = value end
end
local function importInterfaceModule(name)
	local partial = Dev:Import(BASE .. "modules/" .. name .. ".lua" .. CACHE_BUST)
	if not partial then error("[Ro-Editor] Failed to import " .. name) end
	merge(partial)
end
importInterfaceModule("InterfaceTopbar")
importInterfaceModule("InterfaceCamerasModal")
importInterfaceModule("InterfaceEditModal")
importInterfaceModule("InterfaceKeyframeProperties")
importInterfaceModule("InterfaceTrackProperties")
importInterfaceModule("InterfaceTimelinePanel")
importInterfaceModule("InterfaceTracks")
importInterfaceModule("InterfaceKeyframes")
if type(module.buildTopBar) ~= "function" then error("[Ro-Editor] InterfaceTopbar did not export buildTopBar") end
return module
