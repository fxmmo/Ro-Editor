local KeyframeStore = require(script.modules.KeyframeStore)
local HandleSystem = require(script.modules.HandleSystem)
local Interface = require(script.modules.Interface)
local TimelineController = require(script.modules.TimelineController)

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
