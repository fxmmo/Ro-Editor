local Dev = _G.__RoEditorDev
if not Dev then
	local _cache = {}
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
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local BASE = "https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/"
local UIFactory = Dev:Import(BASE .. "modules/UIFactory.lua") or error("[Ro-Editor] import failed")
local ThemeConfig = Dev:Import(BASE .. "configs/Theme_Config.lua") or error("[Ro-Editor] import failed")
local Icons = Dev:Import(BASE .. "configs/Icon_Config.lua") or error("[Ro-Editor] import failed")
local Theme = ThemeConfig.Theme
local Config = ThemeConfig.Config
local module = {}
module.__index = module
local TRACK_PADDING = 8
local KF_LABEL_OFFSET = 180
local TIMELINE_AXIS_LEFT = TRACK_PADDING + KF_LABEL_OFFSET
local TIMELINE_AXIS_RIGHT = 26
local KEYFRAME_HOLD_DURATION = 0.45
local TRACK_RESIZE_MIN_TIME = 0.1
local TRACK_RESIZE_HANDLE_WIDTH = 10
local function getMaxTime()
	return Config.MaxTime or 10
end
function module:buildEditModal()
	local backdrop = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Color3.new(0, 0, 0),
		Name = "EditModalBackdrop",
		ZIndex = 60,
	})
	backdrop.BackgroundTransparency = 1
	backdrop.Visible = false
	local panel = UIFactory.frame({
		Parent = self.gui,
		Size = UDim2.new(0, 260, 0, 192),
		Color = Theme.Panel,
		Corner = 6,
		Name = "EditModal",
		ZIndex = 61,
	})
	UIFactory.stroke(panel, Theme.Border, 1)
	UIFactory.shadow(panel, 0.18)
	local header = UIFactory.frame({
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0, 0),
		Color = Theme.Header,
		Corner = 6,
		ZIndex = 62,
	})
	UIFactory.stroke(header, Theme.Border, 1)
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 2)
	accent.BackgroundColor3 = Theme.Accent
	accent.BorderSizePixel = 0
	accent.Parent = header
	accent.ZIndex = 63
	UIFactory.label({
		Parent = header,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0, 180, 1, 0),
		Text = "EDIT TOOLS",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Color = Theme.Text,
		ZIndex = 63,
	})
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 22, 0, 22)
	close.Position = UDim2.new(1, -28, 0.5, -11)
	close.BackgroundColor3 = Theme.Panel
	close.BorderSizePixel = 0
	close.Text = ""
	close.AutoButtonColor = false
	close.Parent = header
	close.ZIndex = 63
	UIFactory.setIcon(close, Icons.X, {
		IconOnly = true,
		Color = Theme.TextDim,
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0.5, -7, 0.5, -7),
	})
	UIFactory.corner(close, 3)
	UIFactory.stroke(close, Theme.Border, 1)
	self.editModalButtons = {}
	local function addTool(mode, text, y, icon)
		local button = UIFactory.button({
			Parent = panel,
			Name = string.upper(mode) .. "Tool",
			Position = UDim2.new(0, 12, 0, y),
			Size = UDim2.new(1, -24, 0, 28),
			Text = text,
			Color = Theme.PanelDark,
			Corner = 4,
			TextSize = 10,
			ZIndex = 62,
		})
		UIFactory.setIcon(button, icon, {Color = Theme.TextDim, TextOffset = 22})
		button.MouseButton1Click:Connect(function()
			self:setEditTool(mode)
			if self.onEditToolSelected then
				self.onEditToolSelected(mode)
			end
			self:closeEditModal()
		end)
		self.editModalButtons[mode] = button
	end
	addTool("select", "SELECT BASEPART", 44, Icons.Scan)
	addTool("move", "MOVE", 76, Icons.Move3D)
	addTool("rotate", "ROTATE", 108, Icons.Rotate3D)
	addTool("scale", "SCALE BASEPART", 140, Icons.Maximize)
	self.editModalBackdrop = backdrop
	self.editModalPanel = panel
	backdrop.Visible = false
	panel.Visible = false
	self.editModalOpen = false
	self.editToolsButton.MouseButton1Click:Connect(function()
		self:openEditModal()
	end)
	close.MouseButton1Click:Connect(function()
		self:closeEditModal()
	end)
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:closeEditModal()
		end
	end)
end

function module:openEditModal()
	if self.editModalOpen then return end
	self.editModalOpen = true
	self:repositionEditModal()
	self.editModalBackdrop.Visible = true
	self.editModalPanel.Visible = true
	self.editModalBackdrop.BackgroundTransparency = 0.55
	self.editModalPanel.Position = self.editModalPanel.Position + UDim2.new(0, 0, 0, -6)
	TweenService:Create(self.editModalPanel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = self._editModalTargetPos,
	}):Play()
end

function module:closeEditModal()
	if not self.editModalOpen then return end
	self.editModalOpen = false
	TweenService:Create(self.editModalBackdrop, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
	local current = self.editModalPanel.Position
	TweenService:Create(self.editModalPanel, TweenInfo.new(0.15), {
		Position = current + UDim2.new(0, 0, 0, -6),
	}):Play()
	task.delay(0.16, function()
		if not self.editModalOpen then
			self.editModalPanel.Visible = false
			self.editModalBackdrop.Visible = false
		end
	end)
end

function module:repositionEditModal()
	local button = self.editToolsButton
	local position = button.AbsolutePosition
	local size = button.AbsoluteSize
	local panel = self.editModalPanel
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(panel.Parent.AbsoluteSize.X, panel.Parent.AbsoluteSize.Y)
	local desiredX = math.clamp(position.X, 8, math.max(8, viewport.X - 268))
	local desiredY = math.clamp(position.Y + size.Y + 6, 8, math.max(8, viewport.Y - 200))
	self._editModalTargetPos = UDim2.new(0, desiredX, 0, desiredY)
	panel.Position = self._editModalTargetPos
end

function module:getPropertyValues()
	if not self.propertyKeyframe or not self.propertyFields then return nil end
	local values = {}
			for key, field in pairs(self.propertyFields) do
				local value = tonumber(field.Text)
				if not value then return nil end
				values[key] = value
			end
			for key, field in pairs(self.basePropertyFields or {}) do
				if field.Text ~= "" then
					local value = tonumber(field.Text)
					if not value then return nil end
					values[key] = value
				end
			end
			values.easing = self.easingValue or "EaseInOut"
		return values

end


return module
