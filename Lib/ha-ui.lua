local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local Lib = {}
Lib.Toggles = {}

local ACCENT = Color3.fromRGB(139, 92, 246)
local ACCENT_D = Color3.fromRGB(109, 64, 205)
local BG = Color3.fromRGB(16, 16, 24)
local TOPBAR = Color3.fromRGB(22, 22, 32)
local SIDE = Color3.fromRGB(24, 20, 36)
local PANEL = Color3.fromRGB(24, 24, 36)
local CARD = Color3.fromRGB(30, 30, 44)
local INPUT = Color3.fromRGB(18, 18, 27)
local TEXT = Color3.fromRGB(240, 240, 248)
local DIM = Color3.fromRGB(155, 155, 175)
local GOOD = Color3.fromRGB(74, 200, 120)
local WARN = Color3.fromRGB(240, 180, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "HumanAnomalyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = gethui and gethui() or CoreGui end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end
local function stroke(p, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(48, 48, 70)
    s.Thickness = t or 1
    s.Parent = p
    return s
end
local function tween(inst, goal, dur)
    local tw = TweenService:Create(inst, TweenInfo.new(dur or 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 640, 0, 420)
main.Position = UDim2.new(0.5, -320, 0.5, -210)
main.BackgroundColor3 = BG
main.Active = true
main.Draggable = true
main.Parent = gui
corner(main, 12)
stroke(main, Color3.fromRGB(60, 50, 100), 2)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 56)
top.BackgroundColor3 = TOPBAR
top.Parent = main
corner(top, 12)

local fix = Instance.new("Frame")
fix.Size = UDim2.new(1, 0, 0, 12)
fix.Position = UDim2.new(0, 0, 1, -12)
fix.BackgroundColor3 = TOPBAR
fix.BorderSizePixel = 0
fix.Parent = top

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 32, 0, 32)
dot.Position = UDim2.new(0, 12, 0.5, -16)
dot.BackgroundColor3 = ACCENT
dot.Parent = top
corner(dot, 16)
local dotT = Instance.new("TextLabel")
dotT.Size = UDim2.new(1, 0, 1, 0)
dotT.BackgroundTransparency = 1
dotT.Font = Enum.Font.GothamBlack
dotT.TextSize = 16
dotT.TextColor3 = Color3.new(1, 1, 1)
dotT.Text = "HA"
dotT.Parent = dot

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 220, 0, 22)
title.Position = UDim2.new(0, 52, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = TEXT
title.Parent = top

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(0, 220, 0, 14)
sub.Position = UDim2.new(0, 52, 0, 30)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = DIM
sub.Parent = top

local statusPill = Instance.new("Frame")
statusPill.Size = UDim2.new(0, 110, 0, 26)
statusPill.Position = UDim2.new(1, -250, 0.5, -13)
statusPill.BackgroundColor3 = Color3.fromRGB(28, 40, 30)
statusPill.Parent = top
corner(statusPill, 13)
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 10, 0.5, -4)
statusDot.BackgroundColor3 = GOOD
statusDot.Parent = statusPill
corner(statusDot, 4)
local statusTxt = Instance.new("TextLabel")
statusTxt.Size = UDim2.new(1, -26, 1, 0)
statusTxt.Position = UDim2.new(0, 22, 0, 0)
statusTxt.BackgroundTransparency = 1
statusTxt.Font = Enum.Font.GothamBold
statusTxt.TextSize = 11
statusTxt.TextXAlignment = Enum.TextXAlignment.Left
statusTxt.TextColor3 = GOOD
statusTxt.Text = "READY"
statusTxt.Parent = statusPill

local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0, 76, 0, 28)
discordBtn.Position = UDim2.new(1, -132, 0.5, -14)
discordBtn.BackgroundColor3 = ACCENT
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = 11
discordBtn.TextColor3 = Color3.new(1, 1, 1)
discordBtn.Text = "DISCORD"
discordBtn.AutoButtonColor = false
discordBtn.Parent = top
corner(discordBtn, 7)
discordBtn.MouseEnter:Connect(function() tween(discordBtn, { BackgroundColor3 = ACCENT_D }, 0.12) end)
discordBtn.MouseLeave:Connect(function() tween(discordBtn, { BackgroundColor3 = ACCENT }, 0.12) end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 28, 32)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
closeBtn.Text = "X"
closeBtn.Parent = top
corner(closeBtn, 7)

local side = Instance.new("Frame")
side.Size = UDim2.new(0, 148, 1, -64)
side.Position = UDim2.new(0, 8, 0, 60)
side.BackgroundColor3 = SIDE
side.Parent = main
corner(side, 10)

local tabBar = Instance.new("ScrollingFrame")
tabBar.Size = UDim2.new(1, -12, 1, -12)
tabBar.Position = UDim2.new(0, 6, 0, 6)
tabBar.BackgroundTransparency = 1
tabBar.ScrollBarThickness = 0
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.Parent = side
local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local pageHolder = Instance.new("Frame")
pageHolder.Size = UDim2.new(1, -168, 1, -64)
pageHolder.Position = UDim2.new(0, 160, 0, 60)
pageHolder.BackgroundTransparency = 1
pageHolder.Parent = main

local W = { Tabs = {}, Discord = "" }

function W:Tab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(32, 28, 48)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = DIM
    btn.Text = "  " .. name:upper()
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = tabBar
    corner(btn, 7)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 20)
    bar.Position = UDim2.new(0, 6, 0.5, -10)
    bar.BackgroundColor3 = ACCENT
    bar.Visible = false
    bar.Parent = btn
    corner(bar, 2)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.Visible = false
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = pageHolder
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page

    local function select()
        for _, t in pairs(W.Tabs) do
            t.Page.Visible = false
            t.Btn.BackgroundColor3 = Color3.fromRGB(32, 28, 48)
            t.Btn.TextColor3 = DIM
            t.Bar.Visible = false
        end
        page.Visible = true
        tween(btn, { BackgroundColor3 = Color3.fromRGB(52, 40, 88) }, 0.12)
        btn.TextColor3 = Color3.new(1, 1, 1)
        bar.Visible = true
    end
    btn.MouseButton1Click:Connect(select)

    local T = {}

    function T:Section(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -6, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBlack
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = ACCENT
        l.Text = text:upper()
        l.Parent = page
    end

    local function card()
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -6, 0, 40)
        f.BackgroundColor3 = CARD
        f.AutomaticSize = Enum.AutomaticSize.Y
        f.Parent = page
        corner(f, 9)
        stroke(f)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)
        pad.PaddingTop = UDim.new(0, 9)
        pad.PaddingBottom = UDim.new(0, 9)
        pad.Parent = f
        return f
    end

    function T:Label(fn)
        local f = card()
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = TEXT
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.Parent = f
        if type(fn) == "function" then
            task.spawn(function()
                while f.Parent do
                    local ok, v = pcall(fn)
                    if ok then l.Text = tostring(v) end
                    task.wait(1)
                end
            end)
        else
            l.Text = tostring(fn)
        end
    end

    function T:Toggle(key, text, desc, default, cb)
        local f = card()
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -60, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = TEXT
        l.Text = text
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Parent = f
        if desc then
            local d = Instance.new("TextLabel")
            d.Size = UDim2.new(1, -60, 0, 14)
            d.Position = UDim2.new(0, 0, 0, 19)
            d.BackgroundTransparency = 1
            d.Font = Enum.Font.Gotham
            d.TextSize = 10
            d.TextXAlignment = Enum.TextXAlignment.Left
            d.TextColor3 = DIM
            d.Text = desc
            d.TextTruncate = Enum.TextTruncate.AtEnd
            d.Parent = f
        end
        local track = Instance.new("TextButton")
        track.Size = UDim2.new(0, 44, 0, 24)
        track.Position = UDim2.new(1, -44, 0, 2)
        track.BackgroundColor3 = default and ACCENT or Color3.fromRGB(50, 50, 68)
        track.Text = ""
        track.AutoButtonColor = false
        track.Parent = f
        corner(track, 12)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.Parent = track
        corner(knob, 9)
        local state = default or false
        local function paint()
            tween(track, { BackgroundColor3 = state and ACCENT or Color3.fromRGB(50, 50, 68) }, 0.12)
            tween(knob, { Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }, 0.12)
        end
        Lib.Toggles[key] = { Value = state, Set = function(_, v) state = v paint() end }
        track.MouseButton1Click:Connect(function()
            state = not state
            Lib.Toggles[key].Value = state
            paint()
            pcall(cb, state)
        end)
    end

    function T:Button(text, cb, style)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 34)
        b.BackgroundColor3 = style == "danger" and Color3.fromRGB(120, 45, 55) or style == "accent" and ACCENT or Color3.fromRGB(38, 38, 56)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = text
        b.AutoButtonColor = false
        b.Parent = page
        corner(b, 8)
        stroke(b)
        b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = style == "danger" and Color3.fromRGB(150, 55, 65) or ACCENT }, 0.12) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = style == "danger" and Color3.fromRGB(120, 45, 55) or style == "accent" and ACCENT or Color3.fromRGB(38, 38, 56) }, 0.12) end)
        b.MouseButton1Click:Connect(function() task.spawn(function() pcall(cb) end) end)
    end

    function T:Slider(key, text, min, max, default, cb)
        local f = card()
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = TEXT
        l.Parent = f
        local track = Instance.new("TextButton")
        track.Size = UDim2.new(1, 0, 0, 8)
        track.Position = UDim2.new(0, 0, 0, 28)
        track.BackgroundColor3 = Color3.fromRGB(48, 48, 66)
        track.Text = ""
        track.AutoButtonColor = false
        track.Parent = f
        corner(track, 4)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = ACCENT
        fill.BorderSizePixel = 0
        fill.Parent = track
        corner(fill, 4)
        local val = default
        local function paint()
            local p = (val - min) / math.max(1, max - min)
            fill.Size = UDim2.new(p, 0, 1, 0)
            l.Text = text .. ": " .. tostring(val)
        end
        local dragging = false
        local function setFromX(x)
            local abs = track.AbsolutePosition.X
            local w = math.max(1, track.AbsoluteSize.X)
            local p = math.clamp((x - abs) / w, 0, 1)
            val = math.floor(min + p * (max - min) + 0.5)
            paint()
            pcall(cb, val)
        end
        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setFromX(i.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                setFromX(i.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        paint()
        pcall(cb, val)
    end

    function T:Dropdown(key, text, values, default, cb)
        local f = card()
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = TEXT
        l.Text = text .. (default and (": " .. tostring(default)) or "")
        l.Parent = f
        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, 0, 0, 78)
        list.Position = UDim2.new(0, 0, 0, 24)
        list.BackgroundColor3 = INPUT
        list.ScrollBarThickness = 3
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.Parent = f
        corner(list, 6)
        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 2)
        lay.Parent = list
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 4)
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 4)
        pad.Parent = list
        local current = default
        for _, name in ipairs(values) do
            local opt = Instance.new("TextButton")
            opt.Size = UDim2.new(1, 0, 0, 24)
            opt.BackgroundColor3 = name == current and ACCENT or Color3.fromRGB(28, 28, 40)
            opt.Font = Enum.Font.Gotham
            opt.TextSize = 11
            opt.TextColor3 = name == current and Color3.new(1, 1, 1) or DIM
            opt.Text = name
            opt.TextXAlignment = Enum.TextXAlignment.Left
            opt.AutoButtonColor = false
            opt.Parent = list
            corner(opt, 5)
            local inner = Instance.new("UIPadding")
            inner.PaddingLeft = UDim.new(0, 8)
            inner.Parent = opt
            opt.MouseButton1Click:Connect(function()
                current = name
                l.Text = text .. ": " .. name
                for _, o in ipairs(list:GetChildren()) do
                    if o:IsA("TextButton") then
                        o.BackgroundColor3 = o == opt and ACCENT or Color3.fromRGB(28, 28, 40)
                        o.TextColor3 = o == opt and Color3.new(1, 1, 1) or DIM
                    end
                end
                pcall(cb, name)
            end)
        end
        pcall(cb, current)
    end

    W.Tabs[name] = { Btn = btn, Page = page, Bar = bar }
    local count = 0
    for _ in pairs(W.Tabs) do count += 1 end
    if count == 1 then select() end
    return T
end

function W:SetToggle(key, v)
    local t = Lib.Toggles[key]
    if t and t.Set then t.Value = v t:Set(v) end
end

function W:ResetAll()
    for _, t in pairs(Lib.Toggles) do
        if t.Set then t.Value = false t:Set(false) end
    end
end

function W:SetStatus(text, ok)
    statusTxt.Text = text
    local col = ok == false and WARN or GOOD
    statusTxt.TextColor3 = col
    statusDot.BackgroundColor3 = col
end

function Lib.Create(opt)
    gui.Enabled = true
    title.Text = opt.Title or "HUMANANOMALY"
    sub.Text = opt.Sub or ""
    W.Discord = opt.Discord or ""
    main.Visible = true
    discordBtn.MouseButton1Click:Connect(function()
        local cp = setclipboard or toclipboard
        if cp then pcall(cp, W.Discord) end
        Lib.Notify("Discord", "Invite copied to clipboard")
    end)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
    UserInputService.InputBegan:Connect(function(i, g)
        if g then return end
        if i.KeyCode == Enum.KeyCode.LeftControl then gui.Enabled = not gui.Enabled end
    end)
    local win = setmetatable({}, { __index = W })
    return win
end

function Lib.Show()
    gui.Enabled = true
    main.Visible = true
end

function Lib.Hide()
    gui.Enabled = false
end

function Lib.Notify(t, msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(t), Text = tostring(msg), Duration = 5,
        })
    end)
end

function Lib.Destroy()
    gui:Destroy()
end

Lib.Window = W
return Lib
