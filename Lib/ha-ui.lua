--========================================================--
--  ha-ui v3  |  HumanAnomaly UI library
--  Satu window tunggal. Universal + script game menumpuk
--  tab di window yang sama (game script = isi Content).
--
--  API:
--    Lib.Create{ Title, Sub, Discord, Folder }
--    win:Tab(name) -> tab (tab.Key unik, untuk RemoveTab)
--    tab:Section(text) / tab:Note(text) / tab:Label(fnOrText)
--    tab:KV(label, fnOrText)          <- info compact, tanpa card
--    tab:Toggle(key, text, desc, default, cb)
--    tab:Slider(key, text, min, max, default, cb)
--    tab:Dropdown(key, text, values, default, cb)
--    tab:Button(text, cb, style)      <- "accent" | "danger" | "ghost"
--    win:SetToggle(key, v) / win:SetDropdown(key, values)
--    win:OnPanic(fn) / win:FirePanic()
--    win:RemoveTab(key) / win:SetStatus(text, ok)
--    win:ResetAll() / win:Show() / win:Hide() / win:Destroy()
--========================================================--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local Lib = {
    Toggles = {},
    Dropdowns = {},
    PanicHandlers = {},
    Version = "3.0",
}

--================ Theme + design constants ================--
local Theme = {
    Background      = Color3.fromRGB(15, 15, 21),
    Surface         = Color3.fromRGB(22, 22, 31),
    SurfaceSecondary= Color3.fromRGB(30, 30, 43),
    SurfaceHover    = Color3.fromRGB(40, 40, 57),
    Input           = Color3.fromRGB(18, 18, 26),
    Border          = Color3.fromRGB(50, 50, 70),
    Text            = Color3.fromRGB(235, 235, 243),
    TextSecondary   = Color3.fromRGB(148, 148, 170),
    Accent          = Color3.fromRGB(122, 92, 248),
    AccentDark      = Color3.fromRGB(88, 62, 198),
    Success         = Color3.fromRGB(88, 219, 132),
    Warning         = Color3.fromRGB(244, 186, 66),
    Danger          = Color3.fromRGB(242, 95, 95),
}
local Spacing = { XS = 4, SM = 8, MD = 12, LG = 18 }
local Radius = { Small = 6, Medium = 10 }

--================ Responsive dasar ================--
local cam = workspace.CurrentCamera
local viewport = cam and cam.ViewportSize or Vector2.new(1280, 720)
local isMobile = viewport.X < 750 or viewport.Y < 560

local function New(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    inst.Parent = props.Parent
    return inst
end

local function Corner(p, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or Radius.Small), Parent = p })
end

local function Stroke(p, col, th)
    return New("UIStroke", { Color = col or Theme.Border, Thickness = th or 1, Parent = p })
end

local function Tween(o, goal, d)
    local tw = TweenService:Create(o, TweenInfo.new(d or 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

-- Drag handle generik, dengan clamp ke layar
local function MakeDraggable(handle, target, clampToScreen)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        local nx, ny = startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y
        if clampToScreen then
            local vs = workspace.CurrentCamera.ViewportSize
            local half = target.AbsoluteSize / 2
            local minX = -(vs.X / 2) + half.X
            local minY = -(vs.Y / 2) + half.Y
            if minX < 0 then nx = math.clamp(nx, minX + 4, -minX - 4) end
            if minY < 0 then ny = math.clamp(ny, minY + 4, -minY - 4) end
        end
        target.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--================ Root window ================--
local gui = Instance.new("ScreenGui")
gui.Name = "HA_UI_v3"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
local parented = pcall(function()
    gui.Parent = (gethui and gethui()) or CoreGui
end)
if not parented or not gui.Parent then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

local main = New("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = Theme.Background,
    Active = true,
    Parent = gui,
})
Corner(main, Radius.Medium)
if isMobile then
    main.Size = UDim2.new(1, -12, 1, -12)
    New("UISizeConstraint", { MaxSize = Vector2.new(660, 520), Parent = main })
else
    main.Size = UDim2.fromOffset(660, 444)
end

--================ Header ================--
local header = New("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Theme.Surface,
    Parent = main,
})
Corner(header, Radius.Medium)
New("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Parent = header,
})

local titleLabel = New("TextLabel", {
    Size = UDim2.new(0, 300, 0, 20),
    Position = UDim2.new(0, Spacing.MD, 0, Spacing.SM),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Text,
    Text = "",
    Parent = header,
})
local subLabel = New("TextLabel", {
    Size = UDim2.new(0, 340, 0, 14),
    Position = UDim2.new(0, Spacing.MD, 0, 28),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.TextSecondary,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "",
    Parent = header,
})

local statusLabel = New("TextLabel", {
    Size = UDim2.new(0, 74, 0, 28),
    Position = UDim2.new(1, -238, 0.5, -14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextColor3 = Theme.Success,
    Text = "READY",
    Parent = header,
})

local menuBtn = New("TextButton", {
    Size = UDim2.fromOffset(58, 28),
    Position = UDim2.new(1, -172, 0.5, -14),
    BackgroundColor3 = Theme.SurfaceSecondary,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.Text,
    Text = "MENU",
    AutoButtonColor = false,
    Visible = isMobile,
    Parent = header,
})
Corner(menuBtn)

local hideBtn = New("TextButton", {
    Size = UDim2.fromOffset(76, 28),
    Position = UDim2.new(1, -88, 0.5, -14),
    BackgroundColor3 = Theme.SurfaceSecondary,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.Text,
    Text = "HIDE UI",
    AutoButtonColor = false,
    Parent = header,
})
Corner(hideBtn)

--================ Sidebar / drawer ================--
local cover = New("TextButton", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 9,
    Parent = main,
})

local side = New("Frame", {
    Size = UDim2.new(0, 140, 1, -64),
    Position = UDim2.new(0, Spacing.SM, 0, 56),
    BackgroundColor3 = Theme.Surface,
    ZIndex = 10,
    Parent = main,
})
Corner(side, Radius.Medium)
if isMobile then
    side.Visible = false -- drawer: buka lewat tombol MENU
end

local tabBar = New("ScrollingFrame", {
    Size = UDim2.new(1, -12, 1, -12),
    Position = UDim2.new(0, 6, 0, 6),
    BackgroundTransparency = 1,
    ScrollBarThickness = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 10,
    Parent = side,
})
New("UIListLayout", { Padding = UDim.new(0, 3), Parent = tabBar })

local pageHolder = New("Frame", {
    Size = isMobile and UDim2.new(1, -16, 1, -68) or UDim2.new(1, -152, 1, -68),
    Position = isMobile and UDim2.new(0, Spacing.SM, 0, 60) or UDim2.new(0, 148, 0, 60),
    BackgroundTransparency = 1,
    Parent = main,
})

local function closeDrawer()
    if isMobile then
        side.Visible = false
        cover.Visible = false
    end
end

menuBtn.MouseButton1Click:Connect(function()
    local show = not side.Visible
    side.Visible = show
    cover.Visible = show
end)
cover.MouseButton1Click:Connect(closeDrawer)

--================ Tombol SHOW UI (saat window disembunyikan) ================--
local showBtn = New("TextButton", {
    Size = UDim2.fromOffset(92, 34),
    Position = UDim2.new(0, Spacing.MD, 0.42, 0),
    BackgroundColor3 = Theme.Background,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Theme.Text,
    Text = "SHOW UI",
    AutoButtonColor = false,
    Visible = false,
    Parent = gui,
})
Corner(showBtn, Radius.Small)
Stroke(showBtn, Theme.Accent, 1.4)
MakeDraggable(showBtn, showBtn, true)

--================ Tab registry ================--
local W = { Tabs = {}, Discord = "", Folder = "" }

local function selectTab(key)
    local target = W.Tabs[key]
    if not target then return end
    for _, t in pairs(W.Tabs) do
        t.Page.Visible = false
        t.Btn.BackgroundColor3 = Theme.Background
        t.Btn.TextColor3 = Theme.TextSecondary
    end
    target.Page.Visible = true
    target.Btn.BackgroundColor3 = Theme.SurfaceSecondary
    target.Btn.TextColor3 = Theme.Text
    closeDrawer()
end

function W:Tab(name)
    local key = name
    local n = 1
    while W.Tabs[key] do
        n += 1
        key = name .. " " .. n
    end

    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.Background,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.TextSecondary,
        Text = "  " .. name:upper(),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        ZIndex = 10,
        Parent = tabBar,
    })
    Corner(btn)
    btn.MouseEnter:Connect(function()
        Tween(btn, { BackgroundColor3 = Theme.SurfaceHover }, 0.1)
    end)
    btn.MouseLeave:Connect(function()
        local on = page.Visible
        Tween(btn, { BackgroundColor3 = on and Theme.SurfaceSecondary or Theme.Background }, 0.1)
    end)

    local page = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Border,
        Visible = false,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = pageHolder,
    })
    New("UIListLayout", { Padding = UDim.new(0, 6), Parent = page })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, Spacing.SM),
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, Spacing.SM),
        Parent = page,
    })

    btn.MouseButton1Click:Connect(function() selectTab(key) end)

    local T = { Key = key }

    -- Row interaktif: satu-satunya bentuk "surface", tanpa border bertumpuk
    local function row(height)
        local f = New("Frame", {
            Size = UDim2.new(1, -6, 0, height),
            BackgroundColor3 = Theme.Surface,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        Corner(f)
        New("UIPadding", {
            PaddingLeft = UDim.new(0, Spacing.MD), PaddingRight = UDim.new(0, Spacing.MD),
            PaddingTop = UDim.new(0, Spacing.SM), PaddingBottom = UDim.new(0, Spacing.SM),
            Parent = f,
        })
        return f
    end

    function T:Section(text)
        New("TextLabel", {
            Size = UDim2.new(1, -6, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.TextSecondary,
            Text = text:upper(),
            Parent = page,
        })
    end

    function T:Note(text)
        New("TextLabel", {
            Size = UDim2.new(1, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextColor3 = Theme.TextSecondary,
            Text = text,
            Parent = page,
        })
    end

    function T:Label(fn)
        local l = New("TextLabel", {
            Size = UDim2.new(1, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextColor3 = Theme.Text,
            Text = "",
            Parent = page,
        })
        if type(fn) == "function" then
            task.spawn(function()
                while l.Parent do
                    local ok, v = pcall(fn)
                    if ok then l.Text = tostring(v) end
                    task.wait(1)
                end
            end)
        else
            l.Text = tostring(fn)
        end
    end

    -- Info compact: label kecil kiri, nilai kanan, tanpa card
    function T:KV(label, fn)
        local container = New("Frame", {
            Size = UDim2.new(1, -6, 0, 30),
            BackgroundTransparency = 1,
            Parent = page,
        })
        New("TextLabel", {
            Size = UDim2.new(0.4, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.TextSecondary,
            Text = label:upper(),
            Parent = container,
        })
        local value = New("TextLabel", {
            Size = UDim2.new(0.6, 0, 1, 0),
            Position = UDim2.new(0.4, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Theme.Text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "",
            Parent = container,
        })
        if type(fn) == "function" then
            task.spawn(function()
                while container.Parent do
                    local ok, v = pcall(fn)
                    if ok then value.Text = tostring(v) end
                    task.wait(1)
                end
            end)
        else
            value.Text = tostring(fn)
        end
    end

    function T:Toggle(key, text, desc, default, cb)
        local f = row(desc and 44 or 34)
        local l = New("TextLabel", {
            Size = UDim2.new(1, -66, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = f,
        })
        if desc then
            New("TextLabel", {
                Size = UDim2.new(1, -66, 0, 14),
                Position = UDim2.new(0, 0, 0, 19),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.TextSecondary,
                Text = desc,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = f,
            })
        end
        local track = New("TextButton", {
            Size = UDim2.fromOffset(54, 26),
            Position = UDim2.new(1, -54, 0.5, -13),
            BackgroundColor3 = default and Theme.Accent or Theme.SurfaceHover,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = default and Color3.new(1, 1, 1) or Theme.TextSecondary,
            Text = default and "ON" or "OFF",
            AutoButtonColor = false,
            Parent = f,
        })
        Corner(track)

        local state = default or false
        local entry = { Value = state }
        function entry:Set(v)
            state = v
            track.BackgroundColor3 = v and Theme.Accent or Theme.SurfaceHover
            track.TextColor3 = v and Color3.new(1, 1, 1) or Theme.TextSecondary
            track.Text = v and "ON" or "OFF"
        end
        Lib.Toggles[key] = entry
        track.MouseButton1Click:Connect(function()
            state = not state
            Lib.Toggles[key].Value = state
            entry:Set(state)
            if cb then task.spawn(cb, state) end
        end)
    end

    function T:Slider(key, text, min, max, default, cb)
        local f = row(52)
        local l = New("TextLabel", {
            Size = UDim2.new(1, -70, 0, 16),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = text,
            Parent = f,
        })
        local valText = New("TextLabel", {
            Size = UDim2.fromOffset(70, 16),
            Position = UDim2.new(1, -70, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Theme.Accent,
            Text = tostring(default),
            Parent = f,
        })
        local track = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.new(0, 0, 0, 30),
            BackgroundColor3 = Theme.Input,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        Corner(track, 3)
        local fill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(fill, 3)

        local val = default
        local function paint()
            fill.Size = UDim2.new((val - min) / math.max(1, max - min), 0, 1, 0)
            valText.Text = tostring(val)
        end
        local sliding = false
        local function setFromX(x)
            local abs = track.AbsolutePosition.X
            local w = math.max(1, track.AbsoluteSize.X)
            val = math.floor(min + math.clamp((x - abs) / w, 0, 1) * (max - min) + 0.5)
            paint()
            if cb then task.spawn(cb, val) end
        end
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                setFromX(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                setFromX(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false
            end
        end)
        paint()
        if cb then task.spawn(cb, val) end
    end

    function T:Dropdown(key, text, values, default, cb)
        local f = row(34)
        local head = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        New("TextLabel", {
            Size = UDim2.new(0.45, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = head,
        })
        local chev = New("TextLabel", {
            Size = UDim2.fromOffset(14, 18),
            Position = UDim2.new(1, -14, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Theme.TextSecondary,
            Text = "v",
            Parent = head,
        })
        local curText = New("TextLabel", {
            Size = UDim2.new(0.55, -18, 1, 0),
            Position = UDim2.new(0.45, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Theme.TextSecondary,
            Text = default and tostring(default) or "-",
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = head,
        })
        local list = New("ScrollingFrame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.Input,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Border,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            BorderSizePixel = 0,
            Parent = f,
        })
        Corner(list)
        New("UIListLayout", { Padding = UDim.new(0, 3), Parent = list })
        New("UIPadding", {
            PaddingLeft = UDim.new(0, Spacing.XS), PaddingRight = UDim.new(0, Spacing.XS),
            PaddingTop = UDim.new(0, Spacing.XS), PaddingBottom = UDim.new(0, Spacing.XS),
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
                o.Btn.BackgroundColor3 = on and Theme.Accent or Theme.SurfaceSecondary
                o.Btn.TextColor3 = on and Color3.new(1, 1, 1) or Theme.TextSecondary
            end
        end

        local function rebuild(values)
            for _, o in ipairs(options) do o.Btn:Destroy() end
            table.clear(options)
            for _, name in ipairs(values) do
                local optBtn = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundColor3 = Theme.SurfaceSecondary,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = Theme.TextSecondary,
                    Text = "  " .. name,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    Parent = list,
                })
                Corner(optBtn)
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
            list.Size = UDim2.new(1, 0, 0, math.min(#values, 5) * 27 + 8)
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
        local b = New("TextButton", {
            Size = UDim2.new(1, -6, 0, 32),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            Text = text,
            AutoButtonColor = false,
            Parent = page,
        })
        Corner(b)
        if style == "danger" then
            b.BackgroundColor3 = Theme.Background
            b.TextColor3 = Theme.Danger
            Stroke(b, Theme.Danger, 1)
            b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = Color3.fromRGB(52, 28, 32) }, 0.1) end)
            b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = Theme.Background }, 0.1) end)
        elseif style == "accent" then
            b.BackgroundColor3 = Theme.Accent
            b.TextColor3 = Color3.new(1, 1, 1)
            b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = Theme.AccentDark }, 0.1) end)
            b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = Theme.Accent }, 0.1) end)
        elseif style == "ghost" then
            b.BackgroundColor3 = Theme.Background
            b.TextColor3 = Theme.TextSecondary
            Stroke(b, Theme.Border, 1)
            b.MouseEnter:Connect(function() b.TextColor3 = Theme.Text Tween(b, { BackgroundColor3 = Theme.Surface }, 0.1) end)
            b.MouseLeave:Connect(function() b.TextColor3 = Theme.TextSecondary Tween(b, { BackgroundColor3 = Theme.Background }, 0.1) end)
        else
            b.BackgroundColor3 = Theme.SurfaceSecondary
            b.TextColor3 = Theme.Text
            b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = Theme.SurfaceHover }, 0.1) end)
            b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = Theme.SurfaceSecondary }, 0.1) end)
        end
        b.MouseButton1Click:Connect(function()
            if cb then task.spawn(function() pcall(cb) end) end
        end)
    end

    W.Tabs[key] = { Btn = btn, Page = page, Key = key }
    local count = 0
    for _ in pairs(W.Tabs) do count += 1 end
    if count == 1 then selectTab(key) end
    return T
end

function W:RemoveTab(key)
    local t = W.Tabs[key]
    if not t then return end
    t.Btn:Destroy()
    t.Page:Destroy()
    W.Tabs[key] = nil
    for k in pairs(W.Tabs) do
        selectTab(k)
        break
    end
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

function W:OnPanic(fn)
    table.insert(Lib.PanicHandlers, fn)
end

function W:FirePanic()
    for _, fn in ipairs(Lib.PanicHandlers) do
        pcall(fn)
    end
    W:ResetAll()
    W:SetStatus("IDLE", true)
end

function W:SetStatus(text, ok)
    statusLabel.Text = text
    statusLabel.TextColor3 = (ok == false) and Theme.Warning or Theme.Success
end

function W:Show()
    main.Visible = true
    showBtn.Visible = false
end

function W:Hide()
    main.Visible = false
    showBtn.Visible = true
end

function W:Destroy()
    gui:Destroy()
end

--================ Window behavior (sekali saja) ================--
MakeDraggable(header, main, true)
hideBtn.MouseButton1Click:Connect(function() W:Hide() end)
showBtn.MouseButton1Click:Connect(function() W:Show() end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftControl then
        if main.Visible then W:Hide() else W:Show() end
    end
end)

local created = false

function Lib.Create(opt)
    opt = opt or {}
    if created then
        -- Window sudah ada (universal duluan): game script hanya menambah sub
        if opt.Sub and opt.Sub ~= "" and subLabel.Text ~= "" then
            subLabel.Text = subLabel.Text .. " · " .. opt.Sub
        elseif opt.Sub then
            subLabel.Text = opt.Sub
        end
        return setmetatable({}, { __index = W })
    end
    created = true
    if titleLabel then titleLabel.Text = opt.Title or "HUMANANOMALY" end
    subLabel.Text = opt.Sub or "Universal"
    W.Discord = opt.Discord or ""
    W.Folder = opt.Folder or ""
    return setmetatable({}, { __index = W })
end

function Lib.Show() W:Show() end
function Lib.Hide() W:Hide() end

function Lib.Notify(title, message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(message),
            Duration = 5,
        })
    end)
end

function Lib.Destroy() W:Destroy() end

Lib.Window = W
return Lib
