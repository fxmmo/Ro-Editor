local module = {}

function module.get()
	return workspace:FindFirstChild("CameraPart") or workspace:FindFirstChildWhichIsA("Part")
end

return module
