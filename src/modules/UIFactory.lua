local TweenService = game:GetService("TweenService")
local ThemeConfig = require(script.Parent.ThemeConfig)
local Theme = ThemeConfig.Theme

local module = {}
module.__index = module

function module.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 4)
	c.Parent = parent
	return c
end

function module.stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function module.padding(parent, all)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
	return p
end

function module.frame(props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.Color or Theme.Panel
	f.BorderSizePixel = 0
	f.Size = props.Size or UDim2.new(1, 0, 1, 0)
	f.Position = props.Position or UDim2.new(0, 0, 0, 0)
	f.Name = props.Name or "Frame"
	f.Parent = props.Parent
	if props.Corner then module.corner(f, props.Corner) end
	if props.Stroke then module.stroke(f, props.StrokeColor, props.StrokeThickness) end
	return f
end

function module.label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = props.Size or UDim2.new(1, 0, 1, 0)
	l.Position = props.Position or UDim2.new(0, 0, 0, 0)
	l.Text = props.Text or ""
	l.Font = props.Font or Enum.Font.Gotham
	l.TextSize = props.TextSize or 12
	l.TextColor3 = props.Color or Theme.Text
	l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	l.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	l.Name = props.Name or "Label"
	l.Parent = props.Parent
	return l
end

function module.button(props)
	local b = Instance.new("TextButton")
	b.Size = props.Size or UDim2.new(0, 32, 0, 24)
	b.Position = props.Position or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = props.Color or Theme.Header
	b.BorderSizePixel = 0
	b.Text = props.Text or ""
	b.Font = props.Font or Enum.Font.GothamBold
	b.TextSize = props.TextSize or 13
	b.TextColor3 = props.TextColor or Theme.Text
	b.AutoButtonColor = false
	b.Name = props.Name or "Button"
	b.Parent = props.Parent
	module.corner(b, 3)
	module.stroke(b, Theme.Border, 1)
	local defaultColor = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = defaultColor:Lerp(Color3.new(1,1,1), 0.15)}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3 = defaultColor}):Play()
	end)
	return b
end

return module
