local workspace = game:GetService("Workspace")
local UserInput = game:GetService("UserInputService")

local Drag = {}

function Drag:Init(obj)
  local dragging = false
  local dragInput, dragStart, startPos

  local function update(input)
    local delta = input.Position - dragStart
    local nX = startPos.X.Offset + delta.X
    local nY = startPos.Y.Offset + delta.Y

    local Screen_Size = workspace.CurrentCamera.ViewportSize
    nX = math.clamp(nX, 0, Screen_Size.X - obj.AbsoluteSize.X)
    nY = math.clamp(nY, 0, Screen_Size.Y - obj.AbsoluteSize.Y)

    obj.Position = UDim2.new(startPos.X.Scale, nX, startPos.Y.Scale, nY)
  end

  obj.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      dragStart = input.Position
      startPos = obj.Position

      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          dragging = false
        end
      end)
    end
  end)

  obj.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch then
      dragInput = input
    end
  end)

  UserInput.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
      update(input)
    end
  end)
end

return Drag