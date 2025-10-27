-- Editor de Câmera para Roblox com Painel Lateral + Edição Avançada + Suporte Mobile
-- Coloque este script em StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Criar a primeira câmera
local cameraPart = Instance.new("Part")
cameraPart.Name = "CameraPart"
cameraPart.Size = Vector3.new(2, 2, 2)
cameraPart.Anchored = true
cameraPart.CanCollide = false
cameraPart.Material = Enum.Material.Neon
cameraPart.BrickColor = BrickColor.new("Bright blue")
cameraPart.Position = Vector3.new(0, 10, 0)
cameraPart.Parent = workspace

-- Configurações
local moveSpeed = 0.5
local rotateSpeed = 2
local sensitivity = 0.3

-- Variáveis de controle
local isDragging = false
local lastMousePosition = Vector2.new()
local mode = "move" -- "move" ou "rotate"
local cameraMode = false
local editMode = false
local selectedCamera = cameraPart
local originalCameraType = camera.CameraType

-- Detectar se é mobile
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Interface
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CameraEditor"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Painel Lateral
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 250, 1, 0)
panel.Position = UDim2.new(1, -250, 0, 0)
panel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
panel.BorderSizePixel = 0
panel.Parent = screenGui

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
header.Parent = panel

local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -20, 1, 0)
headerLabel.Position = UDim2.new(0, 10, 0, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "📷 Camera Editor"
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextSize = 18
headerLabel.TextColor3 = Color3.new(1, 1, 1)
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Parent = header

-- Container de botões
local buttonContainer = Instance.new("ScrollingFrame")
buttonContainer.Size = UDim2.new(1, -20, 1, -60)
buttonContainer.Position = UDim2.new(0, 10, 0, 50)
buttonContainer.BackgroundTransparency = 1
buttonContainer.BorderSizePixel = 0
buttonContainer.ScrollBarThickness = 6
buttonContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
buttonContainer.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = buttonContainer

-- Função botão
local function createPanelButton(name, icon, text, order, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 45)
	button.LayoutOrder = order
	button.Text = icon .. " " .. text
	button.Font = Enum.Font.Gotham
	button.TextSize = 15
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	button.BorderSizePixel = 0
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Parent = buttonContainer
	Instance.new("UICorner", button)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 15)
	pad.Parent = button
	button.MouseButton1Click:Connect(callback)
	return button
end

-- Seção título
local function createSectionLabel(text, order)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.LayoutOrder = order
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(150, 150, 170)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = buttonContainer
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.Parent = label
	return label
end

-- Seções
createSectionLabel("MODO DE CÂMERA", 1)

-- Botão modo câmera
local cameraModeButton = createPanelButton("CameraModeButton", "📹", "Entrar no Modo Câmera", 2, function()
	cameraMode = not cameraMode
	editMode = false
	if cameraMode then
		camera.CameraType = Enum.CameraType.Scriptable
		cameraModeButton.Text = "📹 Sair do Modo Câmera"
		cameraModeButton.BackgroundColor3 = Color3.fromRGB(226, 88, 88)
	else
		camera.CameraType = originalCameraType
		cameraModeButton.Text = "📹 Entrar no Modo Câmera"
		cameraModeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	end
end)

-- Botão Adicionar Câmera
local addCameraButton = createPanelButton("AddCameraButton", "➕", "Adicionar Câmera", 2.5, function()
	local newPart = Instance.new("Part")
	newPart.Name = "CameraPart_" .. math.random(1000,9999)
	newPart.Size = Vector3.new(2, 2, 2)
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.Material = Enum.Material.Neon
	newPart.BrickColor = BrickColor.new("Bright blue")
	newPart.Position = selectedCamera.Position + Vector3.new(5, 0, 0)
	newPart.Parent = workspace
	selectedCamera = newPart
	print("Nova câmera adicionada:", newPart.Name)
end)

-- Botão Editar Câmera
local editCameraButton = createPanelButton("EditCameraButton", "🛠️", "Editar Câmera", 2.8, function()
	editMode = not editMode
	cameraMode = false
	if editMode then
		camera.CameraType = Enum.CameraType.Scriptable
		editCameraButton.Text = "🛠️ Sair do Editar Câmera"
		editCameraButton.BackgroundColor3 = Color3.fromRGB(88, 180, 90)
	else
		camera.CameraType = originalCameraType
		editCameraButton.Text = "🛠️ Editar Câmera"
		editCameraButton.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	end
end)

-- CONTROLES
createSectionLabel("CONTROLES", 3)
local moveButton, rotateButton
moveButton = createPanelButton("MoveButton", "🚀", "Modo Mover", 4, function()
	mode = "move"
	moveButton.BackgroundColor3 = Color3.fromRGB(74, 144, 226)
	rotateButton.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
end)
rotateButton = createPanelButton("RotateButton", "🔄", "Modo Rotacionar", 5, function()
	mode = "rotate"
	rotateButton.BackgroundColor3 = Color3.fromRGB(74, 144, 226)
	moveButton.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
end)

-- AÇÕES
createSectionLabel("AÇÕES", 6)
createPanelButton("ResetButton", "↺", "Resetar Posição", 7, function()
	selectedCamera.Position = Vector3.new(0, 10, 0)
	selectedCamera.Orientation = Vector3.new(0, 0, 0)
end)

-- INFORMAÇÕES
createSectionLabel("INFORMAÇÕES", 8)
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 120)
infoLabel.LayoutOrder = 9
infoLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
infoLabel.Font = Enum.Font.Code
infoLabel.TextSize = 12
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = buttonContainer
Instance.new("UICorner", infoLabel)
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingTop = UDim.new(0, 10)
pad.Parent = infoLabel

-- Atualizar infos
local function updateInfo()
	local pos = selectedCamera.Position
	local rot = selectedCamera.Orientation
	infoLabel.Text = string.format(
		"Câmera Selecionada: %s\n\nPosição:\nX: %.2f\nY: %.2f\nZ: %.2f\n\nRotação:\nX: %.1f°\nY: %.1f°\nZ: %.1f°",
		selectedCamera.Name, pos.X, pos.Y, pos.Z, rot.X, rot.Y, rot.Z
	)
end

-- Setas 3D interativas com suporte mobile
local arrows = Instance.new("Model")
arrows.Name = "CameraArrows"
arrows.Parent = workspace

-- Variáveis para setas
local activeArrow = nil
local arrowConnections = {}

local function createArrow(direction, color, offset)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(0.8, 0.8, 0.8)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.BrickColor = BrickColor.new(color)
	part.Name = direction
	part.Parent = arrows
	
	-- Adicionar ClickDetector para PC
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 50
	clickDetector.Parent = part
	
	-- Adicionar BillboardGui para touch em mobile
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(3, 0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	
	local touchButton = Instance.new("TextButton")
	touchButton.Size = UDim2.new(1, 0, 1, 0)
	touchButton.BackgroundTransparency = 1
	touchButton.Text = ""
	touchButton.Parent = billboard
	
	return part, clickDetector, touchButton
end

local arrowX, clickX, touchX = createArrow("X", "Bright red", Vector3.new(3, 0, 0))
local arrowY, clickY, touchY = createArrow("Y", "Bright green", Vector3.new(0, 3, 0))
local arrowZ, clickZ, touchZ = createArrow("Z", "Bright blue", Vector3.new(0, 0, 3))

-- Sistema de drag para setas (PC e Mobile)
local function setupArrowDrag(arrow, clickDetector, touchButton, axis)
	-- Para PC (ClickDetector)
	local mouseDown = false
	
	clickDetector.MouseClick:Connect(function()
		if not editMode then return end
		activeArrow = axis
	end)
	
	-- Para Mobile (TouchButton)
	touchButton.MouseButton1Down:Connect(function()
		if not editMode then return end
		activeArrow = axis
		mouseDown = true
	end)
	
	touchButton.MouseButton1Up:Connect(function()
		activeArrow = nil
		mouseDown = false
	end)
	
	-- Touch events específicos para mobile
	touchButton.TouchTap:Connect(function()
		if not editMode then return end
		activeArrow = axis
		task.wait(0.1)
		activeArrow = nil
	end)
	
	touchButton.TouchLongPress:Connect(function()
		if not editMode then return end
		activeArrow = axis
	end)
end

setupArrowDrag(arrowX, clickX, touchX, "X")
setupArrowDrag(arrowY, clickY, touchY, "Y")
setupArrowDrag(arrowZ, clickZ, touchZ, "Z")

-- Atualização em tempo real
RunService.RenderStepped:Connect(function(dt)
	if UserInputService:GetFocusedTextBox() then return end
	
	if editMode then
		arrows.Parent = workspace
		local pos = selectedCamera.Position
		
		-- Posicionar setas
		arrowX.CFrame = CFrame.new(pos + Vector3.new(3, 0, 0)) * CFrame.Angles(0, 0, math.rad(90))
		arrowY.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		arrowZ.CFrame = CFrame.new(pos + Vector3.new(0, 0, 3)) * CFrame.Angles(math.rad(90), 0, 0)
		
		-- Processar movimento das setas
		if activeArrow and isDragging then
			local mousePos = UserInputService:GetMouseLocation()
			local delta = mousePos - lastMousePosition
			lastMousePosition = mousePos
			
			local moveAmount = 0.15
			if activeArrow == "X" then
				selectedCamera.Position += Vector3.new(delta.X * moveAmount, 0, 0)
			elseif activeArrow == "Y" then
				selectedCamera.Position += Vector3.new(0, -delta.Y * moveAmount, 0)
			elseif activeArrow == "Z" then
				selectedCamera.Position += Vector3.new(0, 0, -delta.Y * moveAmount)
			end
		end
	else
		arrows.Parent = nil
	end
	
	if cameraMode then
		camera.CFrame = selectedCamera.CFrame
	end
	
	updateInfo()
end)

-- Input mover/rotacionar (mouse/teclado)
UserInputService.InputChanged:Connect(function(input, processed)
	if processed or cameraMode or not editMode then return end
	
	if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
		if not activeArrow then
			local delta = input.Delta
			if mode == "move" then
				selectedCamera.CFrame *= CFrame.new(-delta.X * sensitivity * 0.05, delta.Y * sensitivity * 0.05, 0)
			elseif mode == "rotate" then
				selectedCamera.CFrame *= CFrame.Angles(math.rad(-delta.Y * 0.5), math.rad(-delta.X * 0.5), 0)
			end
		end
	end
	
	-- Touch Movement para mobile
	if input.UserInputType == Enum.UserInputType.Touch then
		if isDragging and not activeArrow then
			local touchPos = input.Position
			local delta = touchPos - lastMousePosition
			lastMousePosition = touchPos
			
			if mode == "move" then
				selectedCamera.CFrame *= CFrame.new(-delta.X * sensitivity * 0.02, delta.Y * sensitivity * 0.02, 0)
			elseif mode == "rotate" then
				selectedCamera.CFrame *= CFrame.Angles(math.rad(-delta.Y * 0.3), math.rad(-delta.X * 0.3), 0)
			end
		end
	end
end)

-- Input Began (Mouse e Touch)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
		lastMousePosition = input.Position
	elseif input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		lastMousePosition = input.Position
	end
end)

-- Input Ended (Mouse e Touch)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = false
		activeArrow = nil
	elseif input.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
		activeArrow = nil
	end
end)

-- Inicializar
moveButton.BackgroundColor3 = Color3.fromRGB(74, 144, 226)
arrows.Parent = nil
print("📷 Editor de Câmera Avançado carregado com suporte Mobile!")
if isMobile then
	print("🔵 Modo Mobile detectado - Use toque nas setas para mover")
else
	print("🖱️ Modo PC detectado - Clique e arraste as setas")
end

local url

url = "https://raw.githubusercontent.com/rubzinbr/jogorobloxhub/main/menu_principal.lua"