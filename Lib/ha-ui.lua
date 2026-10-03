--========================================================--
--  ha-ui v3.2  |  HumanAnomaly UI library
--  Satu window tunggal. Sidebar ada switch scope UNIVERSAL
--  vs <GAME>: grup tab ditentukan dari Sub di Lib.Create.
--  Universal selalu ada (jalan di semua game), tab script
--  game masuk grup sendiri dan muncul saat script-nya load.
--
--  Prinsip: fungsi dulu. Palet netral polos (abu-abu tanpa
--  tint warna), satu aksen (putih) yang HANYA dipakai untuk
--  menandai state: toggle ON, isi slider, tab aktif, tombol
--  utama. Success/Warning/Danger cuma untuk teks status.
--  Tanpa gradien, glow, atau animasi dekoratif.
--
--  API:
--    Lib.Create{ Title, Sub, Discord, Folder }  <- Sub = nama scope
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
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

local Lib = {
    Toggles = {},
    Dropdowns = {},
    PanicHandlers = {},
    Version = "3.2",
}

--================ Theme + design constants ================--
local Theme = {
    Background      = Color3.fromRGB(16, 16, 16),
    Surface         = Color3.fromRGB(26, 26, 26),
    SurfaceSecondary= Color3.fromRGB(34, 34, 34),
    SurfaceHover    = Color3.fromRGB(44, 44, 44),
    Input           = Color3.fromRGB(21, 21, 21),
    Border          = Color3.fromRGB(48, 48, 48),
    Text            = Color3.fromRGB(230, 230, 230),
    TextSecondary   = Color3.fromRGB(150, 150, 150),
    Accent          = Color3.fromRGB(230, 230, 230), -- state ON / aktif / tombol utama
    AccentText      = Color3.fromRGB(20, 20, 20),    -- teks di atas permukaan Accent
    Success         = Color3.fromRGB(106, 190, 130),
    Warning         = Color3.fromRGB(226, 178, 88),
    Danger          = Color3.fromRGB(224, 100, 100),
}
local Spacing = { XS = 4, SM = 8, MD = 12 }
local RADIUS = 6 -- satu radius buat semuanya

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
    return New("UICorner", { CornerRadius = UDim.new(0, r or RADIUS), Parent = p })
end

local function Stroke(p, col, th)
    return New("UIStroke", { Color = col or Theme.Border, Thickness = th or 1, Parent = p })
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
-- Bersihkan window sisa eksekusi sebelumnya (re-execute tanpa rejoin)
pcall(function()
    local holders = { (gethui and gethui()) or CoreGui, LP:FindFirstChild("PlayerGui") }
    for _, holder in ipairs(holders) do
        local old = holder and holder:FindFirstChild("HA_UI_v3")
        if old then old:Destroy() end
    end
end)

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
Corner(main)
Stroke(main, Theme.Border, 1)
if isMobile then
    main.Size = UDim2.new(1, -12, 1, -12)
    New("UISizeConstraint", { MaxSize = Vector2.new(660, 520), Parent = main })
else
    main.Size = UDim2.fromOffset(660, 444)
end

--================ Header (polos, tanpa surface) ================--
local header = New("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1,
    Active = true,
    Parent = main,
})

local titleLabel = New("TextLabel", {
    Size = UDim2.new(0, 300, 0, 20),
    Position = UDim2.new(0, Spacing.MD, 0, Spacing.SM),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Text,
    TextTruncate = Enum.TextTruncate.AtEnd,
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

-- Posisi status: nempel di kiri tombol paling kiri (MENU di mobile)
local statusRight = isMobile and -276 or -192
local statusLabel = New("TextLabel", {
    Size = UDim2.new(0, 96, 0, 28),
    Position = UDim2.new(1, statusRight, 0.5, -14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextColor3 = Theme.Success,
    TextTruncate = Enum.TextTruncate.AtEnd,
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
menuBtn.MouseEnter:Connect(function() menuBtn.BackgroundColor3 = Theme.SurfaceHover end)
menuBtn.MouseLeave:Connect(function() menuBtn.BackgroundColor3 = Theme.SurfaceSecondary end)

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
hideBtn.MouseEnter:Connect(function() hideBtn.BackgroundColor3 = Theme.SurfaceHover end)
hideBtn.MouseLeave:Connect(function() hideBtn.BackgroundColor3 = Theme.SurfaceSecondary end)

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
Corner(side)
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

-- Switch scope di atas daftar tab: UNIVERSAL / <GAME>.
-- Baru muncul kalau grupnya >1 (universal doang = nggak ada yg di-switch)
local scopeSegs = {}
local scopeBar = New("Frame", {
    Size = UDim2.new(1, -12, 0, 0),
    Position = UDim2.new(0, 6, 0, 6),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 10,
    Parent = side,
})
New("UIListLayout", { Padding = UDim.new(0, 3), Parent = scopeBar })

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
Corner(showBtn)
Stroke(showBtn, Theme.TextSecondary, 1)
MakeDraggable(showBtn, showBtn, true)

--================ Tab registry ================--
local W = { Tabs = {}, Scopes = {}, ScopeSet = {}, LastTab = {}, Discord = "", Folder = "" }

local function selectTab(key)
    local target = W.Tabs[key]
    if not target then return end
    for _, t in pairs(W.Tabs) do
        t.Page.Visible = false
        t.Btn.BackgroundTransparency = 1
        t.Btn.TextColor3 = Theme.TextSecondary
    end
    target.Page.Visible = true
    target.Btn.BackgroundColor3 = Theme.SurfaceSecondary
    target.Btn.BackgroundTransparency = 0
    target.Btn.TextColor3 = Theme.Text
    W.ActiveTab = key
    W.LastTab[target.Scope] = key
    closeDrawer()
end

--================ Scope switch (UNIVERSAL / <GAME>) ================--
local function layoutSide()
    local h = scopeBar.Visible and scopeBar.Size.Height.Offset or 0
    tabBar.Position = UDim2.new(0, 6, 0, scopeBar.Visible and (12 + h) or 6)
    tabBar.Size = UDim2.new(1, -12, 1, scopeBar.Visible and -(18 + h) or -12)
end

local function paintScopeSegs()
    local n = #W.Scopes
    for _, name in ipairs(W.Scopes) do
        local seg = scopeSegs[name]
        if seg then
            local on = name == W.ActiveScope
            seg.BackgroundColor3 = Theme.SurfaceSecondary
            seg.BackgroundTransparency = on and 0 or 1
            seg.TextColor3 = on and Theme.Text or Theme.TextSecondary
        end
    end
    scopeBar.Visible = n > 1
    scopeBar.Size = UDim2.new(1, -12, 0, n > 1 and (n * 24 + (n - 1) * 3) or 0)
    layoutSide()
end

local function selectScope(scope)
    if not W.ScopeSet[scope] then return end
    W.ActiveScope = scope
    paintScopeSegs()
    for _, t in pairs(W.Tabs) do
        t.Btn.Visible = t.Scope == scope
    end
    local key = W.LastTab[scope]
    if not (key and W.Tabs[key]) then
        for _, t in pairs(W.Tabs) do
            if t.Scope == scope then key = t.Key break end
        end
    end
    if key then selectTab(key) end
end

local function addScope(name)
    W.ScopeSet[name] = true
    W.Scopes[#W.Scopes + 1] = name
    local seg = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.SurfaceSecondary,
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = Theme.TextSecondary,
        Text = "  " .. name,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        ZIndex = 10,
        Parent = scopeBar,
    })
    Corner(seg)
    scopeSegs[name] = seg
    seg.MouseButton1Click:Connect(function() selectScope(name) end)
    paintScopeSegs()
end

local function removeScope(name)
    local seg = scopeSegs[name]
    if seg then
        seg:Destroy()
        scopeSegs[name] = nil
    end
    W.ScopeSet[name] = nil
    W.LastTab[name] = nil
    for i, s in ipairs(W.Scopes) do
        if s == name then
            table.remove(W.Scopes, i)
            break
        end
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

    -- Scope = pemanggil Create terakhir (proxy bawa __scope dari Lib.Create)
    local scope = "UNIVERSAL"
    if type(self) == "table" and type(self.__scope) == "string" and self.__scope ~= "" then
        scope = self.__scope:upper()
    end
    local isNewScope = not W.ScopeSet[scope]
    if isNewScope then addScope(scope) end

    -- Page dibuat duluan supaya hover tab bisa baca state-nya
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

    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.SurfaceSecondary,
        BackgroundTransparency = 1,
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
        if not page.Visible then btn.TextColor3 = Theme.Text end
    end)
    btn.MouseLeave:Connect(function()
        if not page.Visible then btn.TextColor3 = Theme.TextSecondary end
    end)
    btn.MouseButton1Click:Connect(function() selectTab(key) end)
    btn.Visible = W.ActiveScope == nil or W.ActiveScope == scope

    local T = { Key = key }

    -- Row interaktif: satu-satunya bentuk "surface"
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
        New("TextLabel", {
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
        local track = New("Frame", {
            Size = UDim2.fromOffset(50, 24),
            Position = UDim2.new(1, -50, 0.5, -12),
            BackgroundColor3 = Theme.SurfaceHover,
            Parent = f,
        })
        Corner(track)

        local state = default or false
        local entry = { Value = state }
        local function paint(v)
            track.BackgroundColor3 = v and Theme.Accent or Theme.SurfaceHover
        end
        function entry:Set(v)
            state = v
            paint(v)
        end
        paint(state)
        Lib.Toggles[key] = entry

        local function flip()
            state = not state
            Lib.Toggles[key].Value = state
            entry:Set(state)
            if cb then task.spawn(cb, state) end
        end
        -- Satu hit area seluas baris: enak dipakai di HP
        New("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = f,
        }).MouseButton1Click:Connect(flip)
    end

    function T:Slider(key, text, min, max, default, cb)
        local f = row(52)
        New("TextLabel", {
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
            TextColor3 = Theme.Text,
            Text = tostring(default),
            Parent = f,
        })
        -- Hit area 22px berisi bar visual 6px: akurat di mouse, bisa di HP
        local hit = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 22),
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
                o.Btn.TextColor3 = on and Theme.AccentText or Theme.TextSecondary
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
                    TextTruncate = Enum.TextTruncate.AtEnd,
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
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(40, 25, 25) end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.Background end)
        elseif style == "accent" then
            b.BackgroundColor3 = Theme.Accent
            b.TextColor3 = Theme.AccentText
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.Accent end)
        elseif style == "ghost" then
            b.BackgroundColor3 = Theme.Background
            b.TextColor3 = Theme.TextSecondary
            Stroke(b, Theme.Border, 1)
            b.MouseEnter:Connect(function()
                b.TextColor3 = Theme.Text
                b.BackgroundColor3 = Theme.Surface
            end)
            b.MouseLeave:Connect(function()
                b.TextColor3 = Theme.TextSecondary
                b.BackgroundColor3 = Theme.Background
            end)
        else
            b.BackgroundColor3 = Theme.SurfaceSecondary
            b.TextColor3 = Theme.Text
            b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.SurfaceHover end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.SurfaceSecondary end)
        end
        b.MouseButton1Click:Connect(function()
            if cb then task.spawn(function() pcall(cb) end) end
        end)
    end

    W.Tabs[key] = { Btn = btn, Page = page, Key = key, Scope = scope }
    local count = 0
    for _ in pairs(W.Tabs) do count += 1 end
    if count == 1 then
        W.ActiveScope = scope
        paintScopeSegs()
        selectTab(key)
    elseif isNewScope and scope ~= "UNIVERSAL" then
        -- Script game baru load: langsung tampilkan grup tab-nya
        selectScope(scope)
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
            selectScope(scope) -- tab pertama yang tersisa di scope ini
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

-- Scope = grup tab di sidebar. Ambil dari Sub di Create:
-- universal pakai Sub "Universal" -> UNIVERSAL, game script
-- pakai Sub sendiri (mis. "Ride A Pet" -> RIDE A PET).
local function scopeFor(opt)
    local s = opt and opt.Sub
    if type(s) == "string" and s ~= "" then return s:upper() end
    return "UNIVERSAL"
end

function Lib.Create(opt)
    opt = opt or {}
    if created then
        -- Window sudah ada (universal duluan): game script hanya menambah sub
        if opt.Sub and opt.Sub ~= "" and subLabel.Text ~= "" then
            subLabel.Text = subLabel.Text .. " · " .. opt.Sub
        elseif opt.Sub then
            subLabel.Text = opt.Sub
        end
        return setmetatable({ __scope = scopeFor(opt) }, { __index = W })
    end
    created = true
    if titleLabel then titleLabel.Text = opt.Title or "HUMANANOMALY" end
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
