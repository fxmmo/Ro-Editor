local module = {}
module.__index = module

function module.new()
	local self = setmetatable({}, module)
	self.keyframes = {}
	self.selected = nil
	return self
end

function module:add(data)
	table.insert(self.keyframes, data)
	return data
end

function module:remove(target)
	for i, kf in ipairs(self.keyframes) do
		if kf == target then
			if kf.frame and kf.frame.Parent then
				kf.frame:Destroy()
			end
			table.remove(self.keyframes, i)
			if self.selected == target then
				self.selected = nil
			end
			return true
		end
	end
	return false
end

function module:sorted()
	local list = {}
	for _, kf in ipairs(self.keyframes) do
		table.insert(list, kf)
	end
	table.sort(list, function(a, b) return a.time < b.time end)
	return list
end

function module:findNeighbors(time)
	local sorted = self:sorted()
	local prevKf, nextKf = nil, nil
	for _, kf in ipairs(sorted) do
		if kf.time <= time then
			prevKf = kf
		end
		if kf.time > time and not nextKf then
			nextKf = kf
			break
		end
	end
	return prevKf, nextKf
end

function module:count()
	return #self.keyframes
end

function module:setSelected(kf)
	self.selected = kf
end

function module:getSelected()
	return self.selected
end

return module
