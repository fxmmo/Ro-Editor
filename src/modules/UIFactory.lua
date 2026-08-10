local TweenService = game:GetService("TweenService")
local Dev = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxmmo/Nightfall-Storage/refs/heads/main/utils/modules/dev.lua"))()
local ThemeConfig = Dev:Import("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/src/configs/Theme_Config.lua")
local Theme = ThemeConfig.Theme

local module = {}
module.__index = module

function module.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 4)
	c.Parent = parent
	return c
end

function module.stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Border
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function module.padding(parent, config)
	config = config or {}
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, config.Top or config.All or 0)
	p.PaddingBottom = UDim.new(0, config.Bottom or config.All or 0)
	p.PaddingLeft = UDim.new(0, config.Left or config.All or 0)
	p.PaddingRight = UDim.new(0, config.Right or config.All or 0)
	p.Parent = parent
	return p
end

function module.shadow(parent, intensity)
	intensity = intensity or 0.08
	local s = Instance.new("Frame")
	s.Name = "Shadow"
	s.BackgroundColor3 = Color3.new(0, 0, 0)
	s.BackgroundTransparency = 1 - intensity
	s.Size = UDim2.new(1, 8, 1, 8)
	s.Position = UDim2.new(0, -4, 0, -4)
	s.ZIndex = parent.ZIndex - 1
	s.Parent = parent
	module.corner(s, 6)
	
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 1)
	}
	gradient.Rotation = 90
	gradient.Parent = s
	return s
end

function module.frame(props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.Color or Theme.Panel
	f.BorderSizePixel = 0
	f.Size = props.Size or UDim2.new(1, 0, 1, 0)
	f.Position = props.Position or UDim2.new(0, 0, 0, 0)
	f.Name = props.Name or "Frame"
	f.Parent = props.Parent
	f.ZIndex = props.ZIndex or f.ZIndex
	if props.Corner then module.corner(f, props.Corner) end
	if props.Stroke then module.stroke(f, props.StrokeColor, props.StrokeThickness, props.StrokeTransparency) end
	if props.Shadow then module.shadow(f, props.ShadowIntensity) end
	if props.Gradient then
		local g = Instance.new("UIGradient")
		g.Color = props.Gradient
		g.Rotation = props.GradientRotation or 0
		g.Parent = f
	end
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
	l.ZIndex = props.ZIndex or l.ZIndex
	l.TextTransparency = props.TextTransparency or 0
	if props.Shadow then
		l.TextStrokeTransparency = 0.9
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
	end
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
	b.ZIndex = props.ZIndex or b.ZIndex
	module.corner(b, props.Corner or 4)
	module.stroke(b, props.StrokeColor or Theme.Border, 1, props.StrokeTransparency)
	
	local defaultColor = b.BackgroundColor3
	local hoverColor = defaultColor:Lerp(Color3.new(1,1,1), 0.12)
	local pressColor = defaultColor:Lerp(Color3.new(0,0,0), 0.08)
	
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = hoverColor}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = defaultColor}):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = pressColor}):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = hoverColor}):Play()
	end)
	
	return b
end

function module.iconButton(props)
	local container = module.frame({
		Parent = props.Parent,
		Size = props.Size or UDim2.new(0, 28, 0, 28),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		Color = props.Color or Theme.Panel,
		Corner = props.Corner or 4,
		Stroke = true,
		StrokeColor = props.StrokeColor or Theme.Border,
		ZIndex = props.ZIndex,
	})
	
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = props.Icon or "●"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = props.TextSize or 14
	btn.TextColor3 = props.TextColor or Theme.Text
	btn.Parent = container
	btn.ZIndex = container.ZIndex + 1
	btn.AutoButtonColor = false
	btn.Name = props.Name or "IconButton"
	
	local defaultColor = container.BackgroundColor3
	local hoverColor = defaultColor:Lerp(Color3.new(1,1,1), 0.12)
	local pressColor = defaultColor:Lerp(Color3.new(0,0,0), 0.08)
	local defaultText = btn.TextColor3
	local hoverText = defaultText:Lerp(Color3.new(1,1,1), 0.2)
	
	local function tween(obj, props, dur)
		TweenService:Create(obj, TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end
	
	btn.MouseEnter:Connect(function()
		tween(container, {BackgroundColor3 = hoverColor})
		tween(btn, {TextColor3 = hoverText})
	end)
	btn.MouseLeave:Connect(function()
		tween(container, {BackgroundColor3 = defaultColor})
		tween(btn, {TextColor3 = defaultText})
	end)
	btn.MouseButton1Down:Connect(function()
		tween(container, {BackgroundColor3 = pressColor}, 0.08)
	end)
	btn.MouseButton1Up:Connect(function()
		tween(container, {BackgroundColor3 = hoverColor}, 0.12)
	end)
	
	btn.MouseButton1Click:Connect(props.Callback or function() end)
	
	return container, btn
end

return module