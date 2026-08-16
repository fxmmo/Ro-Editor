local Dev
do
	_G.__RoEditorDev = nil
	Dev = {}
	function Dev:Import(url)
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

local KeyframeStore = import(BASE .. "modules/KeyframeStore.lua", "KeyframeStore")
local HandleSystem = import(BASE .. "modules/HandleSystem.lua", "HandleSystem")
local Interface = import(BASE .. "modules/Interface.lua", "Interface")
local InterfaceTopbar = import(BASE .. "modules/InterfaceTopbar.lua", "InterfaceTopbar")
local InterfaceCamerasModal = import(BASE .. "modules/InterfaceCamerasModal.lua", "InterfaceCamerasModal")
local InterfaceEditModal = import(BASE .. "modules/InterfaceEditModal.lua", "InterfaceEditModal")
local InterfaceKeyframeProperties = import(BASE .. "modules/InterfaceKeyframeProperties.lua", "InterfaceKeyframeProperties")
local InterfaceTrackProperties = import(BASE .. "modules/InterfaceTrackProperties.lua", "InterfaceTrackProperties")
local InterfaceTimelinePanel = import(BASE .. "modules/InterfaceTimelinePanel.lua", "InterfaceTimelinePanel")
local InterfaceTracks = import(BASE .. "modules/InterfaceTracks.lua", "InterfaceTracks")
local InterfaceKeyframes = import(BASE .. "modules/InterfaceKeyframes.lua", "InterfaceKeyframes")
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
local TimelineController = import(BASE .. "modules/TimelineController.lua", "TimelineController")

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
