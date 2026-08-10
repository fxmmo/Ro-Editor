local KeyframeStore = require(script.KeyframeStore)
local HandleSystem = require(script.HandleSystem)
local Interface = require(script.Interface)
local TimelineController = require(script.TimelineController)

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
