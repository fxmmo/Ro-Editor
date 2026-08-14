local module = {}

module.Theme = {
	Background = Color3.fromRGB(43, 43, 43),
	Panel = Color3.fromRGB(45, 45, 45),
	PanelDark = Color3.fromRGB(37, 37, 37),
	Header = Color3.fromRGB(60, 60, 60),
	Border = Color3.fromRGB(30, 30, 30),
	Accent = Color3.fromRGB(0, 162, 255),
	AccentHover = Color3.fromRGB(40, 180, 255),
	Success = Color3.fromRGB(88, 180, 90),
	Warning = Color3.fromRGB(226, 180, 88),
	Danger = Color3.fromRGB(226, 88, 88),
	Text = Color3.fromRGB(220, 220, 220),
	TextDim = Color3.fromRGB(160, 160, 160),
	TextMuted = Color3.fromRGB(120, 120, 120),
	Keyframe = Color3.fromRGB(255, 200, 50),
	KeyframeSelected = Color3.fromRGB(0, 162, 255),
	Playhead = Color3.fromRGB(0, 162, 255),
	AxisX = Color3.fromRGB(255, 82, 82),
	AxisY = Color3.fromRGB(105, 235, 110),
	AxisZ = Color3.fromRGB(82, 145, 255),
	TrackPalette = {
		Color3.fromRGB(0, 162, 255),
		Color3.fromRGB(120, 200, 90),
		Color3.fromRGB(255, 160, 60),
		Color3.fromRGB(200, 110, 235),
		Color3.fromRGB(240, 95, 120),
		Color3.fromRGB(60, 210, 200),
		Color3.fromRGB(235, 205, 70),
		Color3.fromRGB(130, 140, 250),
	},
}


module.Config = {
	MaxTime = 10,
	InterpolationDuration = 0.5,
	MoveStrength = 0.25,
	MouseSensitivity = 1,
	HandleSize = 1,
	HandleDistance = 4,
}

return module
