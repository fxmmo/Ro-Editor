local _cache = {}
local Dev
do
	_G.__RoEditorDev = nil
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
