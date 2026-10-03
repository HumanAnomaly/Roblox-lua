--========================================================--
--  ha-ui v2  |  HumanAnomaly UI library
--  API:
--    Lib.Create{ Title, Sub, Discord, Folder, Position }
--    win:Tab(name) -> tab
--    tab:Section(text) / tab:Note(text) / tab:Label(fnOrText)
--    tab:Toggle(key, text, desc, default, cb)
--    tab:Slider(key, text, min, max, default, cb)
--    tab:Dropdown(key, text, values, default, cb)
--    tab:Button(text, cb, style)  -- style: "accent" | "danger"
--    win:SetToggle(key, v) / win:SetDropdown(key, values)
--    win:SetStatus(text, ok) / win:ResetAll()
--    win:Show() / win:Hide() / win:Destroy()
--========================================================--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local Lib = {
    Toggles = {},
    Dropdowns = {},
    Version = "2.0",
}

local C = {
    Accent   = Color3.fromRGB(122, 90, 248),
    Accent2  = Color3.fromRGB(86, 58, 196),
    Bg       = Color3.fromRGB(13, 13, 19),
    Top      = Color3.fromRGB(19, 19, 28),
    Side     = Color3.fromRGB(22, 19, 34),
    Card     = Color3.fromRGB(27, 27, 40),
    CardHi   = Color3.fromRGB(35, 35, 52),
    Line     = Color3.fromRGB(46, 46, 68),
    Input    = Color3.fromRGB(17, 17, 26),
    Text     = Color3.fromRGB(238, 238, 246),
    Dim      = Color3.fromRGB(148, 148, 172),
    Good     = Color3.fromRGB(88, 219, 132),
    Warn     = Color3.fromRGB(244, 186, 66),
    Danger   = Color3.fromRGB(126, 46, 58),
    DangerHi = Color3.fromRGB(160, 58, 72),
    TabIdle  = Color3.fromRGB(31, 28, 48),
    TabOn    = Color3.fromRGB(52, 41, 90),
    Track    = Color3.fromRGB(50, 50, 72),
}

local gui = Instance.new("ScreenGui")
gui.Name = "HA_UI_v2"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
local parented = pcall(function()
    gui.Parent = (gethui and gethui()) or CoreGui
end)
if not parented or not gui.Parent then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

local function New(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    inst.Parent = props.Parent
    return inst
end

local function Corner(p, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p })
end

local function Stroke(p, col, th)
    return New("UIStroke", { Color = col or C.Line, Thickness = th or 1, Parent = p })
end

local function Tween(o, goal, d)
    local tw = TweenService:Create(o, TweenInfo.new(d or 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

local function Hover(btn, onCol, offCol)
    btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = onCol }, 0.1) end)
    btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = offCol }, 0.1) end)
end

-- Skala otomatis: layar kecil (HP) diperkecil, desktop full size
local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
local uiScaleValue = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.52, 1)

local WIN_W, WIN_H = 660, 444
local main = New("Frame", {
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
    BackgroundColor3 = C.Bg,
    Active = true,
    Parent = gui,
})
Corner(main, 14)
Stroke(main, Color3.fromRGB(58, 48, 100), 1.6)
New("UIScale", { Scale = uiScaleValue, Parent = main })

-- Drag dari top bar
local dragging = false
local dragStart, startPos
local topBar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = C.Top,
    Parent = main,
})
Corner(topBar, 14)
New("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = C.Top,
    BorderSizePixel = 0,
    Parent = topBar,
})
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Logo + judul
local logo = New("Frame", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(0, 13, 0.5, -17),
    BackgroundColor3 = C.Accent,
    Parent = topBar,
})
Corner(logo, 10)
New("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 14,
    TextColor3 = Color3.new(1, 1, 1),
    Text = "HA",
    Parent = logo,
})

local titleLabel = New("TextLabel", {
    Size = UDim2.new(0, 260, 0, 22),
    Position = UDim2.new(0, 58, 0, 9),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.Text,
    Text = "",
    Parent = topBar,
})

local subLabel = New("TextLabel", {
    Size = UDim2.new(0, 260, 0, 14),
    Position = UDim2.new(0, 58, 0, 31),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.Dim,
    Text = "",
    Parent = topBar,
})

-- Status pill
local statusPill = New("Frame", {
    Size = UDim2.fromOffset(112, 27),
    Position = UDim2.new(1, -282, 0.5, -13.5),
    BackgroundColor3 = Color3.fromRGB(24, 38, 28),
    Parent = topBar,
})
Corner(statusPill, 13)
local statusDot = New("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.new(0, 11, 0.5, -4),
    BackgroundColor3 = C.Good,
    Parent = statusPill,
})
Corner(statusDot, 4)
local statusText = New("TextLabel", {
    Size = UDim2.new(1, -28, 1, 0),
    Position = UDim2.new(0, 24, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.Good,
    Text = "LOADING",
    Parent = statusPill,
})

-- Tombol Discord
local discordBtn = New("TextButton", {
    Size = UDim2.fromOffset(80, 28),
    Position = UDim2.new(1, -160, 0.5, -14),
    BackgroundColor3 = C.Accent,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Color3.new(1, 1, 1),
    Text = "DISCORD",
    AutoButtonColor = false,
    Visible = false,
    Parent = topBar,
})
Corner(discordBtn, 8)
Hover(discordBtn, C.Accent2, C.Accent)

-- Tombol minimize / close
local minBtn = New("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -70, 0.5, -14),
    BackgroundColor3 = Color3.fromRGB(38, 38, 54),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = C.Dim,
    Text = "-",
    AutoButtonColor = false,
    Parent = topBar,
})
Corner(minBtn, 8)

local closeBtn = New("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -36, 0.5, -14),
    BackgroundColor3 = Color3.fromRGB(44, 30, 36),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 116, 116),
    Text = "X",
    AutoButtonColor = false,
    Parent = topBar,
})
Corner(closeBtn, 8)

-- Sidebar
local side = New("Frame", {
    Size = UDim2.new(0, 152, 1, -70),
    Position = UDim2.new(0, 9, 0, 62),
    BackgroundColor3 = C.Side,
    Parent = main,
})
Corner(side, 10)

local tabBar = New("ScrollingFrame", {
    Size = UDim2.new(1, -12, 1, -12),
    Position = UDim2.new(0, 6, 0, 6),
    BackgroundTransparency = 1,
    ScrollBarThickness = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = side,
})
New("UIListLayout", { Padding = UDim.new(0, 4), Parent = tabBar })

local pageHolder = New("Frame", {
    Size = UDim2.new(1, -172, 1, -72),
    Position = UDim2.new(0, 164, 0, 64),
    BackgroundTransparency = 1,
    Parent = main,
})

-- Tombol bulat mengambang (untuk buka/tutup menu, penting di mobile)
local bubble = New("TextButton", {
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 10, 0.42, 0),
    BackgroundColor3 = C.Accent,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextColor3 = Color3.new(1, 1, 1),
    Text = "HA",
    AutoButtonColor = false,
    Parent = gui,
})
Corner(bubble, 22)
Stroke(bubble, Color3.fromRGB(255, 255, 255), 1)

local W = { Tabs = {}, Discord = "", Folder = "" }

local function paintTabs()
    for _, t in pairs(W.Tabs) do
        t.Page.Visible = false
        t.Btn.BackgroundColor3 = C.TabIdle
        t.Btn.TextColor3 = C.Dim
        t.Bar.Visible = false
    end
end

local function selectTab(name)
    local t = W.Tabs[name]
    if not t then return end
    paintTabs()
    t.Page.Visible = true
    Tween(t.Btn, { BackgroundColor3 = C.TabOn }, 0.12)
    t.Btn.TextColor3 = C.Text
    t.Bar.Visible = true
end

function W:Tab(name)
    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = C.TabIdle,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = C.Dim,
        Text = "  " .. name:upper(),
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = tabBar,
    })
    Corner(btn, 8)
    Hover(btn, C.CardHi, C.TabIdle)

    local bar = New("Frame", {
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 6, 0.5, -10),
        BackgroundColor3 = C.Accent,
        Visible = false,
        Parent = btn,
    })
    Corner(bar, 2)

    local page = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.Accent,
        Visible = false,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = pageHolder,
    })
    New("UIListLayout", { Padding = UDim.new(0, 8), Parent = page })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8),
        Parent = page,
    })

    btn.MouseButton1Click:Connect(function() selectTab(name) end)

    local T = {}

    local function card()
        local f = New("Frame", {
            Size = UDim2.new(1, -6, 0, 40),
            BackgroundColor3 = C.Card,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        Corner(f, 10)
        Stroke(f)
        New("UIPadding", {
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
            PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            Parent = f,
        })
        return f
    end

    function T:Section(text)
        New("TextLabel", {
            Size = UDim2.new(1, -6, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBlack,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.Accent,
            Text = text:upper(),
            Parent = page,
        })
    end

    function T:Note(text)
        local f = card()
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextColor3 = C.Dim,
            Text = text,
            Parent = f,
        })
    end

    function T:Label(fn)
        local f = card()
        local l = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextColor3 = C.Text,
            Text = "",
            Parent = f,
        })
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
        local l = New("TextLabel", {
            Size = UDim2.new(1, -60, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.Text,
            Text = text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = f,
        })
        if desc then
            New("TextLabel", {
                Size = UDim2.new(1, -60, 0, 14),
                Position = UDim2.new(0, 0, 0, 19),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = C.Dim,
                Text = desc,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = f,
            })
        end
        local track = New("TextButton", {
            Size = UDim2.fromOffset(44, 24),
            Position = UDim2.new(1, -44, 0, 2),
            BackgroundColor3 = default and C.Accent or C.Track,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        Corner(track, 12)
        local knob = New("Frame", {
            Size = UDim2.fromOffset(18, 18),
            Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Parent = track,
        })
        Corner(knob, 9)

        local state = default or false
        local function paint()
            Tween(track, { BackgroundColor3 = state and C.Accent or C.Track }, 0.12)
            Tween(knob, { Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }, 0.12)
        end
        local entry = { Value = state }
        function entry:Set(v)
            state = v
            paint()
        end
        Lib.Toggles[key] = entry
        track.MouseButton1Click:Connect(function()
            state = not state
            Lib.Toggles[key].Value = state
            paint()
            if cb then task.spawn(cb, state) end
        end)
    end

    function T:Slider(key, text, min, max, default, cb)
        local f = card()
        local l = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.Text,
            Text = text,
            Parent = f,
        })
        local valText = New("TextLabel", {
            Size = UDim2.fromOffset(80, 18),
            Position = UDim2.new(1, -80, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = C.Accent,
            Text = tostring(default),
            Parent = f,
        })
        local track = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 8),
            Position = UDim2.new(0, 0, 0, 28),
            BackgroundColor3 = C.Track,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        Corner(track, 4)
        local fill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = C.Accent,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(fill, 4)

        local val = default
        local function paint()
            local p = (val - min) / math.max(1, max - min)
            fill.Size = UDim2.new(p, 0, 1, 0)
            valText.Text = tostring(val)
        end
        local draggingSlider = false
        local function setFromX(x)
            local abs = track.AbsolutePosition.X
            local w = math.max(1, track.AbsoluteSize.X)
            local p = math.clamp((x - abs) / w, 0, 1)
            val = math.floor(min + p * (max - min) + 0.5)
            paint()
            if cb then task.spawn(cb, val) end
        end
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                setFromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                setFromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = false
            end
        end)
        paint()
        if cb then task.spawn(cb, val) end
    end

    function T:Dropdown(key, text, values, default, cb)
        local f = card()
        local head = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        local l = New("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.Text,
            Text = text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = head,
        })
        local chev = New("TextLabel", {
            Size = UDim2.fromOffset(16, 22),
            Position = UDim2.new(1, -16, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = C.Dim,
            Text = "v",
            Parent = head,
        })
        local curText = New("TextLabel", {
            Size = UDim2.new(0.5, -24, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = C.Dim,
            Text = default and tostring(default) or "-",
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = head,
        })
        local list = New("ScrollingFrame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = C.Input,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            BorderSizePixel = 0,
            Parent = f,
        })
        Corner(list, 7)
        New("UIListLayout", { Padding = UDim.new(0, 3), Parent = list })
        New("UIPadding", {
            PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
            PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
            Parent = list,
        })

        local open = false
        local current = default
        local options = {}

        local function collapse()
            open = false
            list.Visible = false
            chev.Text = "v"
        end

        local function paintOptions()
            for _, o in ipairs(options) do
                local on = o.Name == current
                o.Btn.BackgroundColor3 = on and C.Accent or Color3.fromRGB(24, 24, 36)
                o.Btn.TextColor3 = on and Color3.new(1, 1, 1) or C.Dim
            end
        end

        local function rebuild(values)
            for _, o in ipairs(options) do o.Btn:Destroy() end
            table.clear(options)
            for _, name in ipairs(values) do
                local optBtn = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundColor3 = Color3.fromRGB(24, 24, 36),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = C.Dim,
                    Text = "  " .. name,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    Parent = list,
                })
                Corner(optBtn, 6)
                local entry = { Name = name, Btn = optBtn }
                options[#options + 1] = entry
                optBtn.MouseButton1Click:Connect(function()
                    current = name
                    curText.Text = name
                    paintOptions()
                    collapse()
                    if cb then task.spawn(cb, name) end
                end)
            end
            list.Size = UDim2.new(1, 0, 0, math.min(#values, 5) * 25 + 8)
            paintOptions()
        end

        head.MouseButton1Click:Connect(function()
            open = not open
            list.Visible = open
            chev.Text = open and "^" or "v"
        end)

        rebuild(values)
        Lib.Dropdowns[key] = { SetValues = function(_, vals) rebuild(vals) end }
        if cb then task.spawn(cb, current) end
    end

    function T:Button(text, cb, style)
        local offCol = style == "danger" and C.Danger or style == "accent" and C.Accent or C.CardHi
        local onCol = style == "danger" and C.DangerHi or C.Accent2
        local b = New("TextButton", {
            Size = UDim2.new(1, -6, 0, 34),
            BackgroundColor3 = offCol,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Color3.new(1, 1, 1),
            Text = text,
            AutoButtonColor = false,
            Parent = page,
        })
        Corner(b, 9)
        Stroke(b)
        Hover(b, onCol, offCol)
        b.MouseButton1Click:Connect(function()
            if cb then task.spawn(function() pcall(cb) end) end
        end)
    end

    W.Tabs[name] = { Btn = btn, Page = page, Bar = bar }
    local count = 0
    for _ in pairs(W.Tabs) do count += 1 end
    if count == 1 then selectTab(name) end
    return T
end

function W:SetToggle(key, v)
    local t = Lib.Toggles[key]
    if t then
        t.Value = v
        t:Set(v)
    end
end

function W:SetDropdown(key, values)
    local d = Lib.Dropdowns[key]
    if d then d:SetValues(values) end
end

function W:ResetAll()
    for _, t in pairs(Lib.Toggles) do
        t.Value = false
        t:Set(false)
    end
end

function W:SetStatus(text, ok)
    statusText.Text = text
    local col = (ok == false) and C.Warn or C.Good
    statusText.TextColor3 = col
    statusDot.BackgroundColor3 = col
    statusPill.BackgroundColor3 = (ok == false) and Color3.fromRGB(46, 38, 20) or Color3.fromRGB(24, 38, 28)
end

function W:Show()
    main.Visible = true
end

function W:Hide()
    main.Visible = false
end

function W:Destroy()
    gui:Destroy()
end

function Lib.Create(opt)
    opt = opt or {}
    titleLabel.Text = opt.Title or "HUMANANOMALY"
    subLabel.Text = opt.Sub or ""
    W.Discord = opt.Discord or ""
    W.Folder = opt.Folder or ""
    if opt.Position then main.Position = opt.Position end
    discordBtn.Visible = W.Discord ~= ""

    discordBtn.MouseButton1Click:Connect(function()
        local cp = setclipboard or toclipboard
        if cp then pcall(cp, W.Discord) end
        Lib.Notify("Discord", "Invite dicopy ke clipboard")
    end)

    local function hideMenu()
        main.Visible = false
    end
    minBtn.MouseButton1Click:Connect(hideMenu)
    closeBtn.MouseButton1Click:Connect(hideMenu)

    bubble.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.LeftControl then
            main.Visible = not main.Visible
        end
    end)

    statusText.Text = "READY"
    return setmetatable({}, { __index = W })
end

function Lib.Show()
    main.Visible = true
end

function Lib.Hide()
    main.Visible = false
end

function Lib.Notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(message),
            Duration = 5,
        })
    end)
end

function Lib.Destroy()
    gui:Destroy()
end

Lib.Window = W
return Lib
