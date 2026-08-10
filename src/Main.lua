local Dev = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxmmo/Nightfall-Storage/refs/heads/main/utils/modules/dev.lua"))()
local KeyframeStore = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/KeyframeStore.lua")
local HandleSystem = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/HandleSystem.lua")
local Interface = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/Interface.lua")
local TimelineController = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/TimelineController.lua")

local System = {}
System.__index = System

function System.new()
	local self = setmetatable({}, System)
	self.store = KeyframeStore.new()
	self.handles = HandleSystem.new()
	self.interface = Interface.new()
	self.interface:buildTopBar()
	self.interface:buildTimelinePanel()
	self.controller = TimelineController.new(self.interface, self.store, self.handles)
	return self
end

return System.new()
