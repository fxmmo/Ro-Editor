local Dev = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxmmo/Nightfall-Storage/refs/heads/main/utils/modules/dev.lua"))()
local KeyframeStore = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/KeyframeStore.lua") or error("[Ro-Editor] import failed") or error("[Ro-Editor] Failed to import KeyframeStore (HTTP or loader error)")
local HandleSystem = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/HandleSystem.lua") or error("[Ro-Editor] import failed") or error("[Ro-Editor] Failed to import HandleSystem (HTTP or loader error)")
local Interface = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/Interface.lua") or error("[Ro-Editor] import failed") or error("[Ro-Editor] Failed to import Interface (HTTP or loader error)")
local TimelineController = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/modules/TimelineController.lua") or error("[Ro-Editor] import failed") or error("[Ro-Editor] Failed to import TimelineController (HTTP or loader error)")

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
