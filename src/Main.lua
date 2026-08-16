local DEV_VERSION = "2026-08-16-explicit-interface-composition"
local _cache = {}
local Dev
do
	_G.__RoEditorDev = nil
	Dev = {}
	function Dev:Import(url)
		if _cache[url] then
			return _cache[url]
		end
		local lastErr
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				local source = game:HttpGet(url, true)
				local chunk, compileError = loadstring(source)
				if not chunk then
					error(compileError or "compile failed")
				end
				return chunk()
			end)
			if ok and result then
				_cache[url] = result
				return result
			elseif not ok then
				lastErr = tostring(result)
			else
				lastErr = "module returned nil: " .. url
			end
			task.wait(0.5 * attempt)
		end
		if lastErr then
			warn("[Ro-Editor] import error: " .. lastErr)
		end
		return nil
	end
	Dev.__RoEditorVersion = DEV_VERSION
	_G.__RoEditorDev = Dev
end

local function import(url, name)
	local mod = Dev:Import(url)
	if not mod then
		error("[Ro-Editor] Failed to import " .. name .. " (check Output above for the exact HttpGet error)")
	end
	return mod
end

local BASE = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/"
local CACHE_BUST = "?v=2026-08-16-explicit-interface-composition"

local KeyframeStore = import(BASE .. "modules/KeyframeStore.lua" .. CACHE_BUST, "KeyframeStore")
local HandleSystem = import(BASE .. "modules/HandleSystem.lua" .. CACHE_BUST, "HandleSystem")
local Interface = import(BASE .. "modules/Interface.lua" .. CACHE_BUST, "Interface")
local InterfaceTopbar = import(BASE .. "modules/InterfaceTopbar.lua" .. CACHE_BUST, "InterfaceTopbar")
local InterfaceCamerasModal = import(BASE .. "modules/InterfaceCamerasModal.lua" .. CACHE_BUST, "InterfaceCamerasModal")
local InterfaceEditModal = import(BASE .. "modules/InterfaceEditModal.lua" .. CACHE_BUST, "InterfaceEditModal")
local InterfaceKeyframeProperties = import(BASE .. "modules/InterfaceKeyframeProperties.lua" .. CACHE_BUST, "InterfaceKeyframeProperties")
local InterfaceTrackProperties = import(BASE .. "modules/InterfaceTrackProperties.lua" .. CACHE_BUST, "InterfaceTrackProperties")
local InterfaceTimelinePanel = import(BASE .. "modules/InterfaceTimelinePanel.lua" .. CACHE_BUST, "InterfaceTimelinePanel")
local InterfaceTracks = import(BASE .. "modules/InterfaceTracks.lua" .. CACHE_BUST, "InterfaceTracks")
local InterfaceKeyframes = import(BASE .. "modules/InterfaceKeyframes.lua" .. CACHE_BUST, "InterfaceKeyframes")
local function attachInterfaceMethods(target, source, names, sourceName)
	for _, name in ipairs(names) do
		local method = source[name]
		if type(method) ~= "function" then
			error("[Ro-Editor] " .. sourceName .. " missing method " .. name)
		end
		target[name] = method
	end
end
attachInterfaceMethods(Interface, InterfaceTopbar, {"buildTopBar"}, "InterfaceTopbar")
attachInterfaceMethods(Interface, InterfaceCamerasModal, {"buildCamerasModal"}, "InterfaceCamerasModal")
attachInterfaceMethods(Interface, InterfaceEditModal, {"buildEditModal", "openEditModal", "closeEditModal", "repositionEditModal", "getPropertyValues"}, "InterfaceEditModal")
attachInterfaceMethods(Interface, InterfaceKeyframeProperties, {"setKeyframeProperties", "clearKeyframeProperties", "setEditTool", "setEditSectionVisible", "toggleEditSection", "setViewToggle", "openCamerasModal", "closeCamerasModal", "repositionModal", "setTimelineMinimized"}, "InterfaceKeyframeProperties")
attachInterfaceMethods(Interface, InterfaceTrackProperties, {"buildTrackPropertiesPanel", "setButtonLabel", "getTrackPropertiesValues", "openTrackProperties", "closeTrackProperties", "updateTrackName"}, "InterfaceTrackProperties")
attachInterfaceMethods(Interface, InterfaceTimelinePanel, {"buildTimelinePanel", "buildRuler", "buildPlayhead", "setTrackRange", "endTrackResize", "beginTrackResize", "getTrackColor"}, "InterfaceTimelinePanel")
attachInterfaceMethods(Interface, InterfaceTracks, {"ensureTrack", "setActiveCamera", "removeTrack"}, "InterfaceTracks")
attachInterfaceMethods(Interface, InterfaceKeyframes, {"renderKeyframes", "createKeyframeVisual", "removeKeyframeVisual", "updatePlayheadProximity", "createControlButton", "createIconControl", "setPlayheadPosition"}, "InterfaceKeyframes")
local TimelineController = import(BASE .. "modules/TimelineController.lua" .. CACHE_BUST, "TimelineController")

local System = {}
System.__index = System

function System.new()
	local self = setmetatable({}, System)
	self.store = KeyframeStore.new()
	self.handles = HandleSystem.new()
	self.interface = Interface.new()
	self.interface:buildTopBar()
	self.controller = TimelineController.new(self.interface, self.store, self.handles)
	return self
end

return System.new()
