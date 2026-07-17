local cloneref = (cloneref or clonereference or function(instance)
  return instance
end)

local configs = {
  BackgroundColor = Color3.fromRGB(43,43,43),
  BackgroundSize = UDim2.new(0, 300,0, 353),
  BackgroundPosition = UDim2.new(1, -300, 0, 0),
  ButtonsColor = Color3.fromRGB(16,68,210),
  Placehoulders = Color3.fromRGB(46,98,239)
}

local function Window()
  local screen = Instance.new("ScreenGui")
  screen.IgnoreGuiInset = false
  screen.ResetOnSpawn = false
  screen.Name = "Dex"
  screen.Parent = cloneref(game:GetService("CoreGui"))
  
  local window = Instance.new("Frame")
  window.Parent = screen
  window.Name = "Window"
  window.Size = configs.BackgroundSize
  window.BackgroundColor3 = configs.BackgroundColor
  window.Position = configs.BackgroundPosition

  local content = Instance.new("Frame")
  content.Size = UDim2.new(1, 0, 1, -20)
  content.Position = UDim2.new(0, 0, 0, 20)
  content.BackgroundColor3 = Color3.fromRGB(40,40,40)
  content.Name = "Content"
  content.Parent = window

  local search_bar = Instance.new("Frame")
  search_bar.Name = "search_bar"
  search_bar.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
  search_bar.Size = UDim2.new(1, 0, 0, 22)
  search_bar.Parent = content
  
  return screen, window, content
end