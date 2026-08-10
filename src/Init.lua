local Players = game:GetService("Players")

local modules = {
	{ name = "KeyframeStore", path = script.modules.KeyframeStore },
	{ name = "CameraResolver", path = script.modules.CameraResolver },
	{ name = "UIFactory", path = script.modules.UIFactory },
	{ name = "HandleSystem", path = script.modules.HandleSystem },
	{ name = "Interface", path = script.modules.Interface },
	{ name = "TimelineController", path = script.modules.TimelineController },
}

local ThemeConfig = require(script.configs.Theme_Config)
if ThemeConfig.Theme and ThemeConfig.Config then
	print("[Ro-Editor] ThemeConfig loaded OK")
else
	warn("[Ro-Editor] ThemeConfig loaded but missing expected tables")
end

for _, entry in ipairs(modules) do
	local ok, result = pcall(function()
		return require(entry.path)
	end)
	if ok and result then
		print("[Ro-Editor] Module '" .. entry.name .. "' loaded OK")
	else
		warn("[Ro-Editor] Module '" .. entry.name .. "' FAILED: " .. tostring(result))
	end
end

local ok, system = pcall(function()
	return require(script.Main)
end)
if ok then
	print("[Ro-Editor] System initialized OK")
else
	warn("[Ro-Editor] System initialization FAILED: " .. tostring(system))
end

if Players.LocalPlayer then
	Players.LocalPlayer.CharacterAdded:Connect(function()
		local success, err = pcall(function()
			require(script.Main)
		end)
		if not success then
			warn("[Ro-Editor] System re-init FAILED after respawn: " .. tostring(err))
		else
			print("[Ro-Editor] System re-initialized OK after respawn")
		end
	end)
end
