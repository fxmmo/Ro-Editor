local load = loadstring(game:HttpGet("https://raw.githubusercontent.com/fxmmo/Ro-Editor/refs/heads/main/studio/src/utils/modules/require.lua"))()
local Create = load("./src/utils/modules/create.lua")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Timeline = {}
Timeline.__index = Timeline

function Timeline.new()
    local self = setmetatable({}, Timeline)

    self.Frames = {}
    self.CurrentFrame = 1
    self.IsPlaying = false
    self.Loop = false
    self.Speed = 1
    self.OnFrameChanged = nil

    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    self.Gui = Create"ScreenGui" {
        Name = "TimelineGUI",
        Parent = PlayerGui,

        Children = {
            Create"Frame" {
                Name = "MainFrame",
                Size = UDim2.new(0, 800, 0, 210),
                Position = UDim2.new(0.5, -400, 1, -220),
                BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                BorderSizePixel = 0,

                Children = {

                    -- Header
                    Create"Frame" {
                        Name = "Header",
                        Size = UDim2.new(1, 0, 0, 40),
                        BackgroundColor3 = Color3.fromRGB(45, 45, 45),

                        Children = {
                            Create"TextLabel" {
                                Name = "Title",
                                Text = "Timeline",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0, 100, 1, 0),
                                Position = UDim2.new(0, 10, 0, 0),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Font = Enum.Font.GothamBold,
                                TextSize = 18
                            },

                            Create"TextButton" {
                                Name = "PlayButton",
                                Text = "▶",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                                Size = UDim2.new(0, 40, 1, -10),
                                Position = UDim2.new(1, -180, 0, 5),
                                BorderSizePixel = 0,

                                Children = {
                                    Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                                },

                                MouseButton1Click = function()
                                    self:Play()
                                end
                            },

                            Create"TextButton" {
                                Name = "StopButton",
                                Text = "■",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                                Size = UDim2.new(0, 40, 1, -10),
                                Position = UDim2.new(1, -130, 0, 5),
                                BorderSizePixel = 0,

                                Children = {
                                    Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                                },

                                MouseButton1Click = function()
                                    self:Stop()
                                end
                            },

                            Create"TextBox" {
                                Name = "FrameInfo",
                                Text = "1/1",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                                Size = UDim2.new(0, 80, 1, -10),
                                Position = UDim2.new(1, -80, 0, 5),
                                TextXAlignment = Enum.TextXAlignment.Center,
                                Font = Enum.Font.Gotham,
                                TextSize = 14,

                                Children = {
                                    Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                                },

                                FocusLost = function(enterPressed)
                                    local box = self.Gui.MainFrame.Header.FrameInfo
                                    if enterPressed then
                                        local frame = tonumber(box.Text)
                                        if frame and frame >= 1 and frame <= #self.Frames then
                                            self:GoToFrame(frame)
                                        else
                                            box.Text = self.CurrentFrame .. "/" .. #self.Frames
                                        end
                                    else
                                        box.Text = self.CurrentFrame .. "/" .. #self.Frames
                                    end
                                end
                            }
                        }
                    },

                    -- Timeline Track
                    Create"Frame" {
                        Name = "TrackArea",
                        Size = UDim2.new(1, -20, 0, 60),
                        Position = UDim2.new(0, 10, 0, 50),
                        BackgroundColor3 = Color3.fromRGB(40, 40, 40),

                        Children = {
                            Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                        }
                    },

                    -- Keyframe container
                    Create"Frame" {
                        Name = "KeyframeContainer",
                        Size = UDim2.new(1, -20, 0, 40),
                        Position = UDim2.new(0, 10, 0, 120),
                        BackgroundTransparency = 1
                    },

                    -- Controls
                    Create"Frame" {
                        Name = "Controls",
                        Size = UDim2.new(1, -20, 0, 40),
                        Position = UDim2.new(0, 10, 0, 165),
                        BackgroundTransparency = 1,

                        Children = {
                            Create"TextButton" {
                                Name = "AddFrame",
                                Text = "+ Adicionar Frame",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundColor3 = Color3.fromRGB(76, 175, 80),
                                Size = UDim2.new(0, 130, 1, -10),
                                Position = UDim2.new(0, 0, 0, 5),
                                BorderSizePixel = 0,

                                Children = {
                                    Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                                },

                                MouseButton1Click = function()
                                    self:AddEmptyFrame()
                                end
                            },

                            Create"TextButton" {
                                Name = "RemoveFrame",
                                Text = "- Remover Frame",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundColor3 = Color3.fromRGB(244, 67, 54),
                                Size = UDim2.new(0, 130, 1, -10),
                                Position = UDim2.new(0, 135, 0, 5),
                                BorderSizePixel = 0,

                                Children = {
                                    Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                                },

                                MouseButton1Click = function()
                                    self:RemoveCurrentFrame()
                                end
                            },

                            Create"TextButton" {
                                Name = "LoopButton",
                                Text = "🔁 Loop: OFF",
                                TextColor3 = Color3.fromRGB(255, 255, 255),
                                BackgroundColor3 = Color3.fromRGB(66, 66, 66),
                                Size = UDim2.new(0, 110, 1, -10),
                                Position = UDim2.new(1, -110, 0, 5),
                                BorderSizePixel = 0,

                                Children = {
                                    Create"UICorner" { CornerRadius = UDim.new(0, 5) }
                                },

                                MouseButton1Click = function(button)
                                    self.Loop = not self.Loop
                                    button.Text = self.Loop and "🔁 Loop: ON" or "🔁 Loop: OFF"
                                    button.BackgroundColor3 = self.Loop
                                        and Color3.fromRGB(33, 150, 243)
                                        or Color3.fromRGB(66, 66, 66)
                                end
                            }
                        }
                    },

                    -- Cursor
                    Create"Frame" {
                        Name = "Cursor",
                        Size = UDim2.new(0, 2, 0, 60),
                        Position = UDim2.new(0, 10, 0, 50),
                        BackgroundColor3 = Color3.fromRGB(255, 82, 82),
                        ZIndex = 5,

                        Children = {
                            Create"Frame" {
                                Name = "CursorTop",
                                Size = UDim2.new(0, 10, 0, 10),
                                Position = UDim2.new(0.5, -5, 0, -10),
                                BackgroundColor3 = Color3.fromRGB(255, 82, 82),
                                ZIndex = 5
                            }
                        }
                    },

                    Create"UICorner" { CornerRadius = UDim.new(0, 8) }
                }
            }
        }
    }

    -- Cursor drag
    local trackArea = self.Gui.MainFrame.TrackArea
    local cursor = self.Gui.MainFrame.Cursor
    local isDragging = false

    cursor.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
        end
    end)

    cursor.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = input.Position.X
            local trackAbsX = trackArea.AbsolutePosition.X
            local trackW = trackArea.AbsoluteSize.X
            local newX = math.clamp(mouseX - trackAbsX, 0, trackW)
            local frameIndex = math.floor((newX / trackW) * (#self.Frames - 1)) + 1
            frameIndex = math.clamp(frameIndex, 1, math.max(#self.Frames, 1))
            self:GoToFrame(frameIndex)
        end
    end)

    return self
end

-- =====================
-- MÉTODOS
-- =====================

function Timeline:UpdateCursor()
    if #self.Frames == 0 then return end
    local trackArea = self.Gui.MainFrame.TrackArea
    local trackW = trackArea.AbsoluteSize.X
    local ratio = (self.CurrentFrame - 1) / math.max(#self.Frames - 1, 1)
    local xPos = ratio * trackW
    self.Gui.MainFrame.Cursor.Position = UDim2.new(0, 10 + xPos, 0, 50)
end

function Timeline:UpdateFrameInfo()
    self.Gui.MainFrame.Header.FrameInfo.Text = self.CurrentFrame .. "/" .. #self.Frames
end

function Timeline:UpdateKeyframesDisplay()
    local container = self.Gui.MainFrame.KeyframeContainer

    for _, child in pairs(container:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    if #self.Frames == 0 then return end

    local trackWidth = self.Gui.MainFrame.TrackArea.AbsoluteSize.X
    if trackWidth == 0 then
        task.wait()
        trackWidth = self.Gui.MainFrame.TrackArea.AbsoluteSize.X
    end

    for i = 1, #self.Frames do
        local xPos = ((i - 1) / math.max(#self.Frames - 1, 1)) * trackWidth
        local isActive = (i == self.CurrentFrame)

        local keyframe = Create"TextButton" {
            Text = tostring(i),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = isActive and Color3.fromRGB(33, 150, 243) or Color3.fromRGB(255, 152, 0),
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(0, xPos - 15, 0.5, -15),
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 12,

            Children = {
                Create"UICorner" { CornerRadius = UDim.new(1, 0) }
            },

            MouseButton1Click = function()
                self:GoToFrame(i)
            end
        }
        keyframe.Parent = container
    end
end

function Timeline:GoToFrame(frameNumber)
    if #self.Frames == 0 then return end
    frameNumber = math.clamp(frameNumber, 1, #self.Frames)

    self.CurrentFrame = frameNumber

    self:UpdateCursor()
    self:UpdateFrameInfo()

    -- Atualiza cor dos keyframes
    local container = self.Gui.MainFrame.KeyframeContainer
    local children = container:GetChildren()
    for i, btn in ipairs(children) do
        if btn:IsA("TextButton") then
            btn.BackgroundColor3 = (i == frameNumber)
                and Color3.fromRGB(33, 150, 243)
                or Color3.fromRGB(255, 152, 0)
        end
    end

    if self.OnFrameChanged then
        self.OnFrameChanged(frameNumber, self.Frames[frameNumber])
    end
end

function Timeline:AddEmptyFrame()
    table.insert(self.Frames, { Index = #self.Frames + 1, Data = {} })
    self:UpdateKeyframesDisplay()
    self:GoToFrame(#self.Frames)
end

function Timeline:RemoveCurrentFrame()
    if #self.Frames <= 1 then
        warn("[Timeline]: Não é possível remover o último frame.")
        return
    end

    table.remove(self.Frames, self.CurrentFrame)

    if self.CurrentFrame > #self.Frames then
        self.CurrentFrame = #self.Frames
    end

    self:UpdateKeyframesDisplay()
    self:GoToFrame(self.CurrentFrame)
end

function Timeline:Play()
    if self.IsPlaying or #self.Frames == 0 then return end

    self.IsPlaying = true

    task.spawn(function()
        while self.IsPlaying do
            local next = self.CurrentFrame + 1

            if next > #self.Frames then
                if self.Loop then
                    next = 1
                else
                    self:Stop()
                    break
                end
            end

            self:GoToFrame(next)
            task.wait(0.1 / self.Speed)
        end
    end)
end

function Timeline:Stop()
    self.IsPlaying = false
end

function Timeline:SetParent(parent)
    self.Gui.Parent = parent
    self:UpdateKeyframesDisplay()
end

function Timeline:SetData(frameIndex, key, value)
    if self.Frames[frameIndex] then
        self.Frames[frameIndex].Data[key] = value
    end
end

function Timeline:GetData(frameIndex, key)
    if self.Frames[frameIndex] then
        return self.Frames[frameIndex].Data[key]
    end
    return nil
end

return Timeline