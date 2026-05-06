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
                Size = UDim2.new(0, 800, 0, 200),
                Position = UDim2.new(0.5, -400, 1, -220),
                BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                BorderSizePixel = 0,

                Children = {

                    -- HEADER
                    Create"Frame" {
                        Name = "Header",
                        Size = UDim2.new(1, 0, 0, 40),
                        BackgroundColor3 = Color3.fromRGB(45, 45, 45),

                        Children = {
                            Create"TextLabel" {
                                Name = "Title",
                                Text = "Timeline",
                                TextColor3 = Color3.fromRGB(255,255,255),
                                BackgroundTransparency = 1,
                                Size = UDim2.new(0,100,1,0),
                                Position = UDim2.new(0,10,0,0),
                                Font = Enum.Font.GothamBold,
                                TextSize = 18,
                                TextXAlignment = Enum.TextXAlignment.Left
                            },

                            Create"TextButton" {
                                Name = "PlayButton",
                                Text = "▶",
                                Size = UDim2.new(0,40,1,-10),
                                Position = UDim2.new(1,-180,0,5),
                                BackgroundColor3 = Color3.fromRGB(60,60,60),
                                TextColor3 = Color3.fromRGB(255,255,255),

                                Children = {
                                    Create"UICorner" {}
                                },

                                MouseButton1Click = function()
                                    self:Play()
                                end
                            },

                            Create"TextButton" {
                                Name = "StopButton",
                                Text = "■",
                                Size = UDim2.new(0,40,1,-10),
                                Position = UDim2.new(1,-130,0,5),
                                BackgroundColor3 = Color3.fromRGB(60,60,60),
                                TextColor3 = Color3.fromRGB(255,255,255),

                                Children = {
                                    Create"UICorner" {}
                                },

                                MouseButton1Click = function()
                                    self:Stop()
                                end
                            },

                            Create"TextBox" {
                                Name = "FrameInfo",
                                Text = "1/1",
                                Size = UDim2.new(0,80,1,-10),
                                Position = UDim2.new(1,-80,0,5),
                                BackgroundColor3 = Color3.fromRGB(60,60,60),
                                TextColor3 = Color3.fromRGB(255,255,255),

                                Children = {
                                    Create"UICorner" {}
                                },

                                FocusLost = function(textBox, enter)
                                    if enter then
                                        local n = tonumber(textBox.Text)
                                        if n and n >= 1 and n <= #self.Frames then
                                            self:GoToFrame(n)
                                        end
                                    end
                                end
                            }
                        }
                    },

                    -- TRACK
                    Create"Frame" {
                        Name = "TrackArea",
                        Size = UDim2.new(1,-20,0,60),
                        Position = UDim2.new(0,10,0,50),
                        BackgroundColor3 = Color3.fromRGB(40,40,40),

                        Children = {
                            Create"UICorner" {}
                        }
                    },

                    -- KEYFRAMES
                    Create"Frame" {
                        Name = "KeyframeContainer",
                        Size = UDim2.new(1,-20,0,40),
                        Position = UDim2.new(0,10,0,120),
                        BackgroundTransparency = 1
                    },

                    -- CURSOR
                    Create"Frame" {
                        Name = "Cursor",
                        Size = UDim2.new(0,2,0,60),
                        BackgroundColor3 = Color3.fromRGB(255,82,82),

                        Children = {
                            Create"Frame" {
                                Size = UDim2.new(0,10,0,10),
                                Position = UDim2.new(0.5,-5,0,-10),
                                BackgroundColor3 = Color3.fromRGB(255,82,82)
                            }
                        }
                    }
                }
            }
        }
    }

    -- DRAG
    local track = self.Gui.MainFrame.TrackArea
    local cursor = self.Gui.MainFrame.Cursor
    local dragging = false

    cursor.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)

    cursor.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp(
                i.Position.X - track.AbsolutePosition.X,
                0,
                track.AbsoluteSize.X
            )

            local index = math.floor((x / track.AbsoluteSize.X) * (#self.Frames - 1)) + 1
            index = math.clamp(index, 1, #self.Frames)

            self:GoToFrame(index)
        end
    end)

    return self
end

function Timeline:GoToFrame(n)
    if not self.Frames[n] then return end
    self.CurrentFrame = n
end

function Timeline:Play()
    self.IsPlaying = true
end

function Timeline:Stop()
    self.IsPlaying = false
end

return Timeline