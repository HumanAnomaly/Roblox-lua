local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HumanAnomaly"
gui.ResetOnSpawn = false
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 170)
main.Position = UDim2.new(0, 20, 0.5, -85)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "HUMANANOMALY v1.0.0"
title.Parent = main

local tcorner = Instance.new("UICorner")
tcorner.CornerRadius = UDim.new(0, 8)
tcorner.Parent = title

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -20, 1, -70)
body.Position = UDim2.new(0, 10, 0, 40)
body.BackgroundTransparency = 1
body.TextColor3 = Color3.fromRGB(180, 180, 190)
body.Font = Enum.Font.Gotham
body.TextSize = 12
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Text = "Game: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    .. "\nPlaceId: " .. tostring(game.PlaceId)
    .. "\nJobId: " .. string.sub(game.JobId, 1, 8) .. "..."
    .. "\nPlayers: " .. #Players:GetPlayers() .. "/" .. tostring(Players.MaxPlayers)
    .. "\nUser: " .. LP.Name
    .. "\nStatus: READY"
body.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 24, 0, 24)
close.Position = UDim2.new(1, -28, 0, 4)
close.BackgroundTransparency = 1
close.TextColor3 = Color3.fromRGB(255, 90, 90)
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.Text = "X"
close.Parent = title
close.MouseButton1Click:Connect(function() gui:Destroy() end)
