--========================================================--
--  ha-ui v4.0 | HumanAnomaly UI library
--  Single window, two isolated scopes: UNIVERSAL and <GAME>.
--  Universal always loads on every map. Game scripts only add
--  their own scope — tabs are never mixed, the sidebar filters
--  by active scope.
--
--  Layout (tidy):
--    Header  : logo + title/subtitle | status pill + HIDE UI
--    Sidebar : SCOPE switch (UNIVERSAL / GAME) + tab list
--    Content : sections, cards, compact info rows
--    Footer  : version + toggle hint
--
--  API (unchanged, English-only):
--    Lib.Create{ Title, Sub, Discord, Folder }
--    win:Tab(name) -> tab
--    tab:Section(text) / tab:Note(text) / tab:Label(fnOrText)
--    tab:KV(label, fnOrText)
--    tab:Toggle(key, text, desc, default, cb)
--    tab:Slider(key, text, min, max, default, cb)
--    tab:Dropdown(key, text, values, default, cb)
--    tab:Button(text, cb, style)  -- "accent" | "danger" | "ghost"
--    win:SetToggle(key, v) / win:SetDropdown(key, values)
--    win:OnPanic(fn) / win:FirePanic()
--    win:RemoveTab(key) / win:SetStatus(text, ok)
--    win:ResetAll() / win:Show() / win:Hide() / win:Destroy()
--========================================================--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local Lib = {
    Toggles = {},
    Dropdowns = {},
    PanicHandlers = {},
    Version = "4.0",
}

--================ Theme ================--
local Theme = {
    Background       = Color3.fromRGB(14, 14, 16),
    Surface          = Color3.fromRGB(22, 23, 27),
    SurfaceSecond    = Color3.fromRGB(30, 32, 38),
    SurfaceHover     = Color3.fromRGB(38, 40, 48),
    Input            = Color3.fromRGB(18, 19, 23),
    Border           = Color3.fromRGB(44, 46, 54),
    BorderSoft       = Color3.fromRGB(34, 36, 43),
    Text             = Color3.fromRGB(242, 243, 245),
    TextSecond       = Color3.fromRGB(155, 160, 171),
    TextMuted        = Color3.fromRGB(110, 115, 128),
    Accent           = Color3.fromRGB(242, 243, 245),
    AccentText       = Color3.fromRGB(18, 18, 20),
    Success          = Color3.fromRGB(106, 190, 130),
    Warning          = Color3.fromRGB(226, 178, 88),
    Danger           = Color3.fromRGB(224, 100, 100),
}
local PAD = 12
local GAP = 8
local RADIUS = 8
local CARD_RADIUS = 6

--================ Responsive ================--
local cam = workspace.CurrentCamera
local viewport = cam and cam.ViewportSize or Vector2.new(1280, 720)
local isMobile = viewport.X < 750 or viewport.Y < 560

local function New(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            local ok = pcall(function() inst[k] = v end)
            if not ok then warn("[HA-UI] bad prop " .. tostring(k)) end
        end
    end
    inst.Parent = props.Parent
    return inst
end

local function Corner(p, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or RADIUS), Parent = p })
end

local function Stroke(p, col, th)
    return New("UIStroke", { Color = col or Theme.Border, Thickness = th or 1, Parent = p })
end

local function Tween(inst, goal, t)
    pcall(function()
        TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
    end)
end

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

--================ Root ================--
pcall(function()
    local holders = { (gethui and gethui()) or CoreGui, LP:FindFirstChild("PlayerGui") }
    for _, holder in ipairs(holders) do
        local old = holder and holder:FindFirstChild("HA_UI_v4")
        if old then old:Destroy() end
        local legacy = holder and holder:FindFirstChild("HA_UI_v3")
        if legacy then legacy:Destroy() end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "HA_UI_v4"
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
Corner(main, RADIUS)
Stroke(main, Theme.Border, 1)
if isMobile then
    main.Size = UDim2.new(1, -12, 1, -12)
    New("UISizeConstraint", { MaxSize = Vector2.new(680, 520), Parent = main })
else
    main.Size = UDim2.fromOffset(680, 460)
end

--================ Header ================--
local header = New("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundTransparency = 1,
    Active = true,
    Parent = main,
})

local logo = New("Frame", {
    Size = UDim2.fromOffset(32, 32),
    Position = UDim2.new(0, PAD, 0.5, -16),
    BackgroundColor3 = Theme.SurfaceSecond,
    Parent = header,
})
Corner(logo, 8)
Stroke(logo, Theme.Border, 1)
New("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextColor3 = Theme.Text,
    Text = "HA",
    Parent = logo,
})

local titleLabel = New("TextLabel", {
    Size = UDim2.new(0, 260, 0, 19),
    Position = UDim2.new(0, 52, 0, 10),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Text,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "HUMANANOMALY",
    Parent = header,
})
local subLabel = New("TextLabel", {
    Size = UDim2.new(0, 300, 0, 14),
    Position = UDim2.new(0, 52, 0, 30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.TextSecond,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "Universal",
    Parent = header,
})

-- Status pill + buttons (right aligned)
local pillRight = isMobile and -268 or -196
local statusPill = New("Frame", {
    Size = UDim2.fromOffset(92, 28),
    Position = UDim2.new(1, pillRight, 0.5, -14),
    BackgroundColor3 = Theme.Surface,
    Parent = header,
})
Corner(statusPill, 14)
Stroke(statusPill, Theme.BorderSoft, 1)
local statusDot = New("Frame", {
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.new(0, 10, 0.5, -3.5),
    BackgroundColor3 = Theme.Success,
    BorderSizePixel = 0,
    Parent = statusPill,
})
Corner(statusDot, UDim.new(1, 0))
local statusLabel = New("TextLabel", {
    Size = UDim2.new(1, -24, 1, 0),
    Position = UDim2.new(0, 22, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Text,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "READY",
    Parent = statusPill,
})

local menuBtn = New("TextButton", {
    Size = UDim2.fromOffset(56, 28),
    Position = UDim2.new(1, -164, 0.5, -14),
    BackgroundColor3 = Theme.SurfaceSecond,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.Text,
    Text = "MENU",
    AutoButtonColor = false,
    Visible = isMobile,
    Parent = header,
})
Corner(menuBtn, 7)

local hideBtn = New("TextButton", {
    Size = UDim2.fromOffset(76, 28),
    Position = UDim2.new(1, -88, 0.5, -14),
    BackgroundColor3 = Theme.SurfaceSecond,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.Text,
    Text = "HIDE",
    AutoButtonColor = false,
    Parent = header,
})
Corner(hideBtn, 7)
hideBtn.MouseEnter:Connect(function() hideBtn.BackgroundColor3 = Theme.SurfaceHover end)
hideBtn.MouseLeave:Connect(function() hideBtn.BackgroundColor3 = Theme.SurfaceSecond end)
menuBtn.MouseEnter:Connect(function() menuBtn.BackgroundColor3 = Theme.SurfaceHover end)
menuBtn.MouseLeave:Connect(function() menuBtn.BackgroundColor3 = Theme.SurfaceSecond end)

local headerDiv = New("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 0, 58),
    BackgroundColor3 = Theme.BorderSoft,
    BorderSizePixel = 0,
    Parent = main,
})

--================ Sidebar ================--
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
    Size = UDim2.new(0, 158, 1, -110),
    Position = UDim2.new(0, PAD, 0, 66),
    BackgroundColor3 = Theme.Surface,
    ZIndex = 10,
    Parent = main,
})
Corner(side, CARD_RADIUS)
Stroke(side, Theme.BorderSoft, 1)
if isMobile then side.Visible = false end

local sidePad = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 0,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 10,
    Parent = side,
})
New("UIPadding", {
    PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
    Parent = sidePad,
})
local sideLayout = New("UIListLayout", { Padding = UDim.new(0, 4), Parent = sidePad })
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function sideCaption(text)
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.TextMuted,
        Text = text,
        ZIndex = 10,
        Parent = sidePad,
    })
end
sideCaption("SCOPE")

local scopeBar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    ZIndex = 10,
    Parent = sidePad,
})
New("UIListLayout", { Padding = UDim.new(0, 4), Parent = scopeBar })
local scopeSegs = {}

sideCaption("TABS")
local tabBar = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    ZIndex = 10,
    Parent = sidePad,
})
New("UIListLayout", { Padding = UDim.new(0, 3), Parent = tabBar })

--================ Content ================--
local pageHolder = New("Frame", {
    Size = isMobile and UDim2.new(1, -24, 1, -110) or UDim2.new(1, -182, 1, -110),
    Position = isMobile and UDim2.new(0, PAD, 0, 66) or UDim2.new(0, 170, 0, 66),
    BackgroundTransparency = 1,
    Parent = main,
})

--================ Footer ================--
local footerDiv = New("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 1, -33),
    BackgroundColor3 = Theme.BorderSoft,
    BorderSizePixel = 0,
    Parent = main,
})
New("TextLabel", {
    Size = UDim2.new(0, 200, 0, 16),
    Position = UDim2.new(0, 12, 1, -24),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.TextMuted,
    Text = "HA v4.0  •  English",
    Parent = main,
})
New("TextLabel", {
    Size = UDim2.new(0, 260, 0, 16),
    Position = UDim2.new(1, -272, 1, -24),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextColor3 = Theme.TextMuted,
    Text = "Press LeftCtrl to show / hide",
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

--================ SHOW button ================--
local showBtn = New("TextButton", {
    Size = UDim2.fromOffset(96, 34),
    Position = UDim2.new(0, PAD, 0.42, 0),
    BackgroundColor3 = Theme.Background,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Theme.Text,
    Text = "SHOW UI",
    AutoButtonColor = false,
    Visible = false,
    Parent = gui,
})
Corner(showBtn, 8)
Stroke(showBtn, Theme.Border, 1)
MakeDraggable(showBtn, showBtn, true)

--================ Registry (strict scope isolation) ================--
-- UNIVERSAL scope: always present, works on every map.
-- Game scope (e.g. RIDE A PET): only appears when that game
-- script loads. Tabs are filtered by active scope — never mixed.
local W = { Tabs = {}, Scopes = {}, ScopeSet = {}, LastTab = {}, Discord = "", Folder = "" }

local function selectTab(key)
    local target = W.Tabs[key]
    if not target then return end
    for _, t in pairs(W.Tabs) do
        t.Page.Visible = false
        t.Btn.BackgroundTransparency = 1
        t.Btn.TextColor3 = Theme.TextSecond
        if t.Indicator then t.Indicator.BackgroundTransparency = 1 end
    end
    target.Page.Visible = true
    target.Btn.BackgroundColor3 = Theme.SurfaceSecond
    target.Btn.BackgroundTransparency = 0
    target.Btn.TextColor3 = Theme.Text
    if target.Indicator then
        target.Indicator.BackgroundTransparency = 0
        target.Indicator.BackgroundColor3 = Theme.Accent
    end
    W.ActiveTab = key
    W.LastTab[target.Scope] = key
    closeDrawer()
end

local function paintScopeSegs()
    local n = #W.Scopes
    for _, name in ipairs(W.Scopes) do
        local seg = scopeSegs[name]
        if seg then
            local on = name == W.ActiveScope
            seg.Box.BackgroundColor3 = on and Theme.SurfaceSecond or Theme.Background
            seg.Btn.TextColor3 = on and Theme.Text or Theme.TextSecond
            seg.Dot.BackgroundColor3 = on and Theme.Success or Theme.TextMuted
        end
    end
end

local function selectScope(scope)
    if not W.ScopeSet[scope] then return end
    W.ActiveScope = scope
    paintScopeSegs()
    for _, t in pairs(W.Tabs) do
        local show = t.Scope == scope
        t.Btn.Visible = show
    end
    local key = W.LastTab[scope]
    if not (key and W.Tabs[key]) then
        for _, t in pairs(W.Tabs) do
            if t.Scope == scope then key = t.Key break end
        end
    end
    if key then selectTab(key) end
end

local function scopeBadgeText(scope)
    local c = 0
    for _, t in pairs(W.Tabs) do
        if t.Scope == scope then c += 1 end
    end
    return tostring(c)
end

local function refreshScopeBadges()
    for name, seg in pairs(scopeSegs) do
        seg.Badge.Text = scopeBadgeText(name)
    end
end

local function addScope(name)
    if W.ScopeSet[name] then return end
    W.ScopeSet[name] = true
    W.Scopes[#W.Scopes + 1] = name
    table.sort(W.Scopes, function(a, b)
        if a == "UNIVERSAL" then return true end
        if b == "UNIVERSAL" then return false end
        return a < b
    end)
    -- rebuild scope buttons in order
    for _, s in ipairs(W.Scopes) do
        if not scopeSegs[s] then
            local box = New("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Theme.Background,
                ZIndex = 10,
                Parent = scopeBar,
            })
            Corner(box, 6)
            Stroke(box, Theme.BorderSoft, 1)
            local dot = New("Frame", {
                Size = UDim2.fromOffset(6, 6),
                Position = UDim2.new(0, 9, 0.5, -3),
                BackgroundColor3 = Theme.TextMuted,
                BorderSizePixel = 0,
                ZIndex = 10,
                Parent = box,
            })
            Corner(dot, UDim.new(1, 0))
            local btn = New("TextButton", {
                Size = UDim2.new(1, -42, 1, 0),
                Position = UDim2.new(0, 20, 0, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = Theme.TextSecond,
                Text = s,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false,
                ZIndex = 10,
                Parent = box,
            })
            local badge = New("TextLabel", {
                Size = UDim2.fromOffset(20, 16),
                Position = UDim2.new(1, -24, 0.5, -8),
                BackgroundColor3 = Theme.Input,
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                TextColor3 = Theme.TextSecond,
                Text = "0",
                ZIndex = 10,
                Parent = box,
            })
            Corner(badge, 8)
            local seg = { Box = box, Btn = btn, Dot = dot, Badge = badge }
            scopeSegs[s] = seg
            btn.MouseButton1Click:Connect(function() selectScope(s) end)
            box.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    selectScope(s)
                end
            end)
        end
    end
    -- reorder LayoutOrder to match sorted scopes
    for i, s in ipairs(W.Scopes) do
        if scopeSegs[s] then scopeSegs[s].Box.LayoutOrder = i end
    end
    paintScopeSegs()
    refreshScopeBadges()
end

local function removeScope(name)
    local seg = scopeSegs[name]
    if seg then seg.Box:Destroy() scopeSegs[name] = nil end
    W.ScopeSet[name] = nil
    W.LastTab[name] = nil
    for i, s in ipairs(W.Scopes) do
        if s == name then table.remove(W.Scopes, i) break end
    end
    paintScopeSegs()
end

function W:Tab(name)
    local key = name
    local n = 1
    while W.Tabs[key] do
        n += 1
        key = name .. " " .. n
    end

    local scope = "UNIVERSAL"
    if type(self) == "table" and type(self.__scope) == "string" and self.__scope ~= "" then
        scope = self.__scope:upper()
    end
    local isNewScope = not W.ScopeSet[scope]
    if isNewScope then addScope(scope) end

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
    New("UIListLayout", { Padding = UDim.new(0, GAP), Parent = page })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, PAD),
        Parent = page,
    })

    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.SurfaceSecond,
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.TextSecond,
        Text = "     " .. name:upper(),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        ZIndex = 10,
        Parent = tabBar,
    })
    Corner(btn, 6)
    local indicator = New("Frame", {
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 7, 0.5, -8),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = btn,
    })
    Corner(indicator, UDim.new(1, 0))
    btn.MouseEnter:Connect(function()
        if not page.Visible then btn.TextColor3 = Theme.Text end
    end)
    btn.MouseLeave:Connect(function()
        if not page.Visible then btn.TextColor3 = Theme.TextSecond end
    end)
    btn.MouseButton1Click:Connect(function() selectTab(key) end)
    btn.Visible = W.ActiveScope == nil or W.ActiveScope == scope

    local T = { Key = key }

    local function row(height)
        local f = New("Frame", {
            Size = UDim2.new(1, -6, 0, height),
            BackgroundColor3 = Theme.Surface,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = page,
        })
        Corner(f, CARD_RADIUS)
        Stroke(f, Theme.BorderSoft, 1)
        New("UIPadding", {
            PaddingLeft = UDim.new(0, PAD), PaddingRight = UDim.new(0, PAD),
            PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            Parent = f,
        })
        return f
    end

    function T:Section(text)
        local wrap = New("Frame", {
            Size = UDim2.new(1, -6, 0, 20),
            BackgroundTransparency = 1,
            Parent = page,
        })
        New("TextLabel", {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.TextMuted,
            Text = text:upper(),
            Parent = wrap,
        })
        New("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -4),
            BackgroundColor3 = Theme.BorderSoft,
            BorderSizePixel = 0,
            Parent = wrap,
        })
    end

    function T:Note(text)
        local f = New("Frame", {
            Size = UDim2.new(1, -6, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Surface,
            Parent = page,
        })
        Corner(f, CARD_RADIUS)
        Stroke(f, Theme.BorderSoft, 1)
        New("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = Theme.Border,
            BorderSizePixel = 0,
            Parent = f,
        })
        Corner(New("Frame", { Visible = false, Parent = f }), 0)
        local l = New("TextLabel", {
            Size = UDim2.new(1, -24, 0, 0),
            Position = UDim2.new(0, 14, 0, 8),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextColor3 = Theme.TextSecond,
            Text = text,
            Parent = f,
        })
        New("UIPadding", { PaddingBottom = UDim.new(0, 8), Parent = f })
        -- grow container to fit text
        l:GetPropertyChangedSignal("TextBounds"):Connect(function()
            f.Size = UDim2.new(1, -6, 0, l.TextBounds.Y + 16)
        end)
        task.defer(function()
            if l.Parent then f.Size = UDim2.new(1, -6, 0, l.TextBounds.Y + 16) end
        end)
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

    function T:KV(label, fn)
        local container = New("Frame", {
            Size = UDim2.new(1, -6, 0, 28),
            BackgroundTransparency = 1,
            Parent = page,
        })
        New("TextLabel", {
            Size = UDim2.new(0.42, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.TextMuted,
            Text = label:upper(),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = container,
        })
        local value = New("TextLabel", {
            Size = UDim2.new(0.58, 0, 1, 0),
            Position = UDim2.new(0.42, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Theme.Text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "",
            Parent = container,
        })
        New("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -1),
            BackgroundColor3 = Theme.BorderSoft,
            BorderSizePixel = 0,
            BackgroundTransparency = 0.4,
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
        local f = row(desc and 46 or 36)
        New("TextLabel", {
            Size = UDim2.new(1, -62, 0, 18),
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
                Size = UDim2.new(1, -62, 0, 14),
                Position = UDim2.new(0, 0, 0, 20),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Theme.TextSecond,
                Text = desc,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = f,
            })
        end
        local track = New("Frame", {
            Size = UDim2.fromOffset(44, 22),
            Position = UDim2.new(1, -44, 0.5, -11),
            BackgroundColor3 = Theme.SurfaceHover,
            BorderSizePixel = 0,
            Parent = f,
        })
        Corner(track, UDim.new(1, 0))
        Stroke(track, Theme.Border, 1)
        local knob = New("Frame", {
            Size = UDim2.fromOffset(14, 14),
            Position = UDim2.new(0, 4, 0.5, -7),
            BackgroundColor3 = Theme.TextSecond,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(knob, UDim.new(1, 0))

        local state = default or false
        local entry = { Value = state }
        local function paint(v, animate)
            local goal = v and UDim2.new(1, -18, 0.5, -7) or UDim2.new(0, 4, 0.5, -7)
            if animate then Tween(knob, { Position = goal }, 0.12) else knob.Position = goal end
            track.BackgroundColor3 = v and Theme.Accent or Theme.SurfaceHover
            knob.BackgroundColor3 = v and Theme.AccentText or Theme.TextSecond
        end
        function entry:Set(v) state = v paint(v, true) end
        paint(state, false)
        Lib.Toggles[key] = entry

        local function flip()
            state = not state
            Lib.Toggles[key].Value = state
            entry:Set(state)
            if cb then task.spawn(cb, state) end
        end
        New("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        }).MouseButton1Click:Connect(flip)
    end

    function T:Slider(key, text, min, max, default, cb)
        local f = row(56)
        New("TextLabel", {
            Size = UDim2.new(1, -72, 0, 16),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = f,
        })
        local valText = New("TextLabel", {
            Size = UDim2.fromOffset(66, 18),
            Position = UDim2.new(1, -66, 0, 0),
            BackgroundColor3 = Theme.Input,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Theme.Text,
            Text = tostring(default),
            Parent = f,
        })
        Corner(valText, 5)
        local hit = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            Position = UDim2.new(0, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        local track = New("Frame", {
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.new(0, 0, 0.5, -3),
            BackgroundColor3 = Theme.Input,
            BorderSizePixel = 0,
            Parent = hit,
        })
        Corner(track, UDim.new(1, 0))
        local fill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(fill, UDim.new(1, 0))
        local knob = New("Frame", {
            Size = UDim2.fromOffset(12, 12),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Theme.Text,
            BorderSizePixel = 0,
            Parent = track,
        })
        Corner(knob, UDim.new(1, 0))
        Stroke(knob, Theme.Border, 1)

        local val = default
        local function paint()
            local t = (val - min) / math.max(1, max - min)
            fill.Size = UDim2.new(t, 0, 1, 0)
            knob.Position = UDim2.new(t, 0, 0.5, 0)
            valText.Text = tostring(val)
        end
        local sliding = false
        local function setFromX(x)
            local abs = hit.AbsolutePosition.X
            local w = math.max(1, hit.AbsoluteSize.X)
            val = math.floor(min + math.clamp((x - abs) / w, 0, 1) * (max - min) + 0.5)
            paint()
            if cb then task.spawn(cb, val) end
        end
        hit.InputBegan:Connect(function(input)
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
        local f = row(36)
        local head = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        })
        New("TextLabel", {
            Size = UDim2.new(0.42, 0, 1, 0),
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
            TextColor3 = Theme.TextSecond,
            Text = "v",
            Parent = head,
        })
        local curText = New("TextLabel", {
            Size = UDim2.new(0.58, -18, 1, 0),
            Position = UDim2.new(0.42, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Theme.TextSecond,
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
        Corner(list, 6)
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
                o.Btn.BackgroundColor3 = on and Theme.Accent or Theme.SurfaceSecond
                o.Btn.TextColor3 = on and Theme.AccentText or Theme.TextSecond
            end
        end

        local function rebuild(vals)
            for _, o in ipairs(options) do o.Btn:Destroy() end
            table.clear(options)
            for _, name in ipairs(vals) do
                local optBtn = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Theme.SurfaceSecond,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = Theme.TextSecond,
                    Text = "  " .. tostring(name),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    AutoButtonColor = false,
                    Parent = list,
                })
                Corner(optBtn, 5)
                local entry = { Name = name, Btn = optBtn }
                options[#options + 1] = entry
                optBtn.MouseButton1Click:Connect(function()
                    current = name
                    curText.Text = tostring(name)
                    paintOptions()
                    collapse()
                    if cb then task.spawn(cb, name) end
                end)
            end
            list.Size = UDim2.new(1, 0, 0, math.min(#vals, 5) * 29 + 8)
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
            Size = UDim2.new(1, -6, 0, 34),
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            Text = text,
            AutoButtonColor = false,
            Parent = page,
        })
        Corner(b, 7)
        if style == "danger" then
            b.BackgroundColor3 = Theme.Background
            b.TextColor3 = Theme.Danger
            Stroke(b, Theme.Danger, 1)
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(40, 25, 25) end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.Background end)
        elseif style == "accent" then
            b.BackgroundColor3 = Theme.Accent
            b.TextColor3 = Theme.AccentText
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.Accent end)
        elseif style == "ghost" then
            b.BackgroundColor3 = Theme.Background
            b.TextColor3 = Theme.TextSecond
            Stroke(b, Theme.Border, 1)
            b.MouseEnter:Connect(function()
                b.TextColor3 = Theme.Text
                b.BackgroundColor3 = Theme.Surface
            end)
            b.MouseLeave:Connect(function()
                b.TextColor3 = Theme.TextSecond
                b.BackgroundColor3 = Theme.Background
            end)
        else
            b.BackgroundColor3 = Theme.SurfaceSecond
            b.TextColor3 = Theme.Text
            Stroke(b, Theme.BorderSoft, 1)
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.SurfaceHover end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.SurfaceSecond end)
        end
        b.MouseButton1Click:Connect(function()
            if cb then task.spawn(function() pcall(cb) end) end
        end)
    end

    W.Tabs[key] = { Btn = btn, Page = page, Key = key, Scope = scope, Indicator = indicator }
    refreshScopeBadges()
    local count = 0
    for _ in pairs(W.Tabs) do count += 1 end
    if count == 1 then
        W.ActiveScope = scope
        paintScopeSegs()
        selectTab(key)
    elseif isNewScope and scope ~= "UNIVERSAL" then
        selectScope(scope)
    else
        -- keep current scope visible; hide new tab if not active
        btn.Visible = (W.ActiveScope == scope)
    end
    return T
end

function W:RemoveTab(key)
    local t = W.Tabs[key]
    if not t then return end
    t.Btn:Destroy()
    t.Page:Destroy()
    W.Tabs[key] = nil
    if W.LastTab[t.Scope] == key then W.LastTab[t.Scope] = nil end
    refreshScopeBadges()

    local stillHas = false
    for _, tt in pairs(W.Tabs) do
        if tt.Scope == t.Scope then stillHas = true break end
    end
    if not stillHas then removeScope(t.Scope) end

    if W.ActiveTab == key then
        local scope = W.ActiveScope
        local nextKey = W.LastTab[scope]
        if nextKey and W.Tabs[nextKey] then
            selectTab(nextKey)
        elseif scope and W.ScopeSet[scope] then
            selectScope(scope)
        else
            W.ActiveScope = nil
            if W.Scopes[1] then selectScope(W.Scopes[1]) end
        end
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
    statusLabel.Text = tostring(text):upper()
    local col = (ok == false) and Theme.Warning or Theme.Success
    statusDot.BackgroundColor3 = col
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

--================ Window behavior ================--
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

local function scopeFor(opt)
    local s = opt and opt.Sub
    if type(s) == "string" and s ~= "" then return s:upper() end
    return "UNIVERSAL"
end

function Lib.Create(opt)
    opt = opt or {}
    if created then
        if opt.Sub and opt.Sub ~= "" and subLabel.Text ~= "" then
            -- keep subtitle tidy: "Universal • Ride A Pet"
            local cur = subLabel.Text
            if not cur:find(opt.Sub, 1, true) then
                subLabel.Text = cur .. "  •  " .. opt.Sub
            end
        elseif opt.Sub then
            subLabel.Text = opt.Sub
        end
        return setmetatable({ __scope = scopeFor(opt) }, { __index = W })
    end
    created = true
    if titleLabel then titleLabel.Text = (opt.Title or "HUMANANOMALY"):upper() end
    subLabel.Text = opt.Sub or "Universal"
    W.Discord = opt.Discord or ""
    W.Folder = opt.Folder or ""
    return setmetatable({ __scope = scopeFor(opt) }, { __index = W })
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
