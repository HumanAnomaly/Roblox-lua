--========================================================--
--  HumanAnomaly | Universal
--  Jalan di SEMUA game. Selalu dimuat otomatis oleh Loader,
--  jendela game-specific (mis. Ride A Pet) muncul terpisah.
--========================================================--

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

local BASE = "https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/"
-- Satu instance UI dibagikan ke semua script -> satu window
local UI = getgenv().HA_UI
if not UI then
    if getgenv().HA_UI_SRC then
        UI = loadstring(getgenv().HA_UI_SRC)()
    else
        UI = loadstring(game:HttpGet(BASE .. "Lib/ha-ui.lua"))()
    end
    getgenv().HA_UI = UI
end

local U = {
    Config = {
        Tag = "[HA Universal]",
        FlySpeed = 90, WalkSpeed = 60, JumpPower = 80,
        EspRefresh = 0.3, EspRange = 5000, HopPick = 15,
        FlingSpin = 2000, FlingForce = 9e4, StickOffset = 2,
    },
    State = { Alive = true, Connections = {}, Parts = {}, CollidePatch = {},
        Boards = {}, Lighting = nil, FovBackup = nil, FlingHome = nil, FPS = 0 },
    Options = {},
}
local Config, State, Options = U.Config, U.State, U.Options
local V3, CF = Vector3.new, CFrame.new

getgenv().HA_Universal = U -- dipakai script game untuk cek status troll

function U:Connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(State.Connections, c)
    return c
end

function U:Saved()
    return LP:FindFirstChild("Character") ~= nil or LP.Character ~= nil
end

U.Player = { Humanoid = nil, Root = nil }
function U.Player:Bind(ch)
    if not ch then return end
    self.Humanoid = ch:WaitForChild("Humanoid", 30)
    self.Root = ch:WaitForChild("HumanoidRootPart", 30)
    table.clear(State.Parts)
    table.clear(State.CollidePatch)
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then State.Parts[#State.Parts + 1] = p end
    end
    U:Connect(ch.DescendantAdded, function(p)
        if p:IsA("BasePart") then State.Parts[#State.Parts + 1] = p end
    end)
end

function U:IsAlive()
    return self.Player.Humanoid ~= nil and self.Player.Humanoid.Health > 0
        and self.Player.Root ~= nil and self.Player.Root.Parent ~= nil
end

function U:MoveTo(cf)
    if not cf or not self:IsAlive() then return false end
    self.Player.Root.AssemblyLinearVelocity = Vector3.zero
    self.Player.Root.CFrame = cf
    return true
end

function U:PlayerNames()
    local n = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then n[#n + 1] = p.Name end
    end
    table.sort(n)
    if #n == 0 then n = { "Tidak ada pemain lain" } end
    return n
end

function U:TargetRoot(name)
    local t = Players:FindFirstChild(name or "")
    return t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
end

--================ Movement ================--
function U.SetNoClip(on)
    if on then
        for _, p in ipairs(State.Parts) do
            if p.Parent and p.CanCollide then
                State.CollidePatch[p] = true
                p.CanCollide = false
            end
        end
        return
    end
    for p in pairs(State.CollidePatch) do
        if p.Parent then p.CanCollide = true end
    end
    table.clear(State.CollidePatch)
end

function U.Frame(dt)
    local hum = U.Player.Humanoid
    if (Options.NoClip or Options.Fly or Options.Fling) and U:IsAlive() then
        U.SetNoClip(true)
    end
    if Options.Fly and U:IsAlive() then
        local camDir = Workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += camDir.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= camDir.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += camDir.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= camDir.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
        U.Player.Root.AssemblyLinearVelocity = Vector3.zero
        if dir.Magnitude > 0 then
            U.Player.Root.CFrame += dir.Unit * (Options.FlySpeed or Config.FlySpeed) * dt
        end
    end
    if hum and Options.SpeedOn then hum.WalkSpeed = Options.WalkSpeed or Config.WalkSpeed end
    if hum and Options.JumpOn then hum.JumpPower = Options.JumpPower or Config.JumpPower end
end

function U.RestoreMovement(key)
    local hum = U.Player.Humanoid
    if hum and (key == "SpeedOn" or key == nil) then hum.WalkSpeed = 16 end
    if hum and (key == "JumpOn" or key == nil) then hum.JumpPower = 50 end
    if key == nil or not (Options.NoClip or Options.Fly or Options.Fling) then U.SetNoClip(false) end
    if key == "Fly" and U.Player.Root then U.Player.Root.AssemblyLinearVelocity = Vector3.zero end
end

--================ Visual ================--
function U.EspClear()
    for _, e in pairs(State.Boards) do e.Board:Destroy() end
    table.clear(State.Boards)
end

function U.EspRefresh()
    if not Options.PlayerEsp then
        if next(State.Boards) then U.EspClear() end
        return
    end
    local myRoot = U.Player.Root
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local head = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
            if head then
                local entry = State.Boards[plr]
                if not entry or not entry.Board.Parent then
                    local board = Instance.new("BillboardGui")
                    board.Name = "HA_UniEsp"
                    board.AlwaysOnTop = true
                    board.Size = UDim2.fromOffset(160, 36)
                    board.StudsOffset = V3(0, 2.5, 0)
                    board.MaxDistance = Config.EspRange
                    board.Adornee = head
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.fromScale(1, 1)
                    label.BackgroundTransparency = 1
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = 12
                    label.TextStrokeTransparency = 0.35
                    label.TextColor3 = Color3.new(1, 1, 1)
                    label.Parent = board
                    board.Parent = (gethui and gethui()) or CoreGui
                    entry = { Board = board, Label = label }
                    State.Boards[plr] = entry
                end
                seen[plr] = true
                local dist = myRoot and math.floor((head.Position - myRoot.Position).Magnitude) or 0
                entry.Label.Text = plr.DisplayName .. "\n" .. dist .. "m"
            end
        end
    end
    for plr, e in pairs(State.Boards) do
        if not seen[plr] then e.Board:Destroy() State.Boards[plr] = nil end
    end
end

function U.SetFullbright(on)
    if on then
        State.Lighting = {
            Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient, FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
        }
        Lighting.Brightness = 1.5
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false
    elseif State.Lighting then
        Lighting.Brightness = State.Lighting.Brightness
        Lighting.Ambient = State.Lighting.Ambient
        Lighting.OutdoorAmbient = State.Lighting.OutdoorAmbient
        Lighting.FogEnd = State.Lighting.FogEnd
        Lighting.GlobalShadows = State.Lighting.GlobalShadows
        State.Lighting = nil
    end
end

--================ Troll ================--
function U.TrollFrame()
    if not Options.Fling and not Options.Stick then return end
    local troot, root = U:TargetRoot(Options.TrollTarget), U.Player.Root
    if not troot or not root or not U:IsAlive() then return end
    if Options.Fling then
        State.FlingHome = State.FlingHome or root.CFrame
        root.CFrame = troot.CFrame * CFrame.Angles(0, math.rad(os.clock() * Config.FlingSpin % 360), 0)
        root.AssemblyLinearVelocity = V3(0, Config.FlingForce, 0)
        root.AssemblyAngularVelocity = V3(0, Config.FlingForce, 0)
        return
    end
    root.CFrame = troot.CFrame * CF(0, 0, Config.StickOffset)
end

function U.StopFling()
    local root = U.Player.Root
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if State.FlingHome then root.CFrame = State.FlingHome end
    end
    State.FlingHome = nil
    U.RestoreMovement("Fly")
end

--================ Server ================--
function U.Rejoin()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end

function U.Hop()
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
    local open = {}
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then
        local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, body)
        for _, s in ipairs(ok2 and decoded and decoded.data or {}) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then open[#open + 1] = s.id end
        end
    end
    if #open > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, open[math.random(1, math.min(#open, Config.HopPick))], LP)
        return
    end
    TeleportService:Teleport(game.PlaceId, LP)
end

--================ UI ================--
function U.BuildUI()
    local W = UI.Create({
        Title = "HUMANANOMALY",
        Sub = "Universal",
        Discord = "https://discord.gg/NGBgETjmv3",
        Folder = "HumanAnomaly/Universal",
    })
    U.UIRef = W

    local home = W:Tab("Home")
    home:Section("Info")
    home:Note("Universal aktif di semua game dan selalu dimuat otomatis oleh Loader. Script khusus game menambah tab sendiri di window ini.")
    home:KV("GAME", function()
        local name = "?"
        pcall(function() name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
        return name
    end)
    home:KV("PLACE", function() return tostring(game.PlaceId) end)
    home:KV("JOB", function() return game.JobId:sub(1, 8) .. "..." end)
    home:KV("EXECUTOR", function()
        local exec = "?"
        pcall(function() exec = identifyexecutor() end)
        return exec
    end)
    home:KV("PLAYERS", function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers end)
    home:KV("FPS", function() return tostring(State.FPS) end)
    home:Section("Kontrol")
    home:Button("Join Discord", function()
        local cp = setclipboard or toclipboard
        if cp then pcall(cp, "https://discord.gg/NGBgETjmv3") end
        UI.Notify("Discord", "Invite dicopy ke clipboard")
    end, "ghost")
    home:Button("PANIC - Semua Off", function() W:FirePanic() end, "danger")
    W:OnPanic(function()
        for k in pairs(Options) do Options[k] = false end
        U.RestoreMovement(nil)
        U.SetFullbright(false)
        if U.Player.Humanoid then Workspace.CurrentCamera.CameraSubject = U.Player.Humanoid end
        if State.FovBackup then Workspace.CurrentCamera.FieldOfView = State.FovBackup end
    end)

    local pl = W:Tab("Character")
    pl:Section("Movement")
    pl:Toggle("SpeedOn", "Speed", "Walkspeed custom", false, function(v) Options.SpeedOn = v if not v then U.RestoreMovement("SpeedOn") end end)
    pl:Slider("WalkSpeed", "Walk speed", 16, 300, Config.WalkSpeed, function(v) Options.WalkSpeed = v end)
    pl:Toggle("JumpOn", "Jump Power", "Jump custom", false, function(v) Options.JumpOn = v if not v then U.RestoreMovement("JumpOn") end end)
    pl:Slider("JumpPower", "Power", 50, 300, Config.JumpPower, function(v) Options.JumpPower = v end)
    pl:Toggle("InfJump", "Infinite Jump", nil, false, function(v) Options.InfJump = v end)
    pl:Toggle("Fly", "Fly", "WASD + Space / Shift", false, function(v) Options.Fly = v if not v then U.RestoreMovement("Fly") end end)
    pl:Slider("FlySpeed", "Fly speed", 20, 500, Config.FlySpeed, function(v) Options.FlySpeed = v end)
    pl:Toggle("NoClip", "Noclip", "Tembus tembok", false, function(v) Options.NoClip = v if not v then U.RestoreMovement("NoClip") end end)
    pl:Toggle("ClickTp", "Click TP", "Klik kiri ke titik untuk teleport", false, function(v) Options.ClickTp = v end)

    local vis = W:Tab("Visual")
    vis:Section("Dunia")
    vis:Toggle("Fullbright", "Fullbright", "Terang merata, tanpa bayangan", false, function(v) U.SetFullbright(v) end)
    vis:Slider("Fov", "Field of View", 40, 120, 70, function(v)
        local cam2 = Workspace.CurrentCamera
        if not cam2 then return end
        if not State.FovBackup then State.FovBackup = cam2.FieldOfView end
        cam2.FieldOfView = v
    end)
    vis:Section("ESP")
    vis:Toggle("PlayerEsp", "Player ESP", "Nama + jarak tembus tembok", false, function(v) Options.PlayerEsp = v end)

    local srv = W:Tab("Server")
    srv:Section("Server")
    srv:Toggle("AntiAfk", "Anti AFK", "Anti kick 20 menit idle", false, function(v) Options.AntiAfk = v end)
    srv:Button("Unlock FPS (240)", function()
        if setfpscap then pcall(setfpscap, 240) UI.Notify("Universal", "FPS cap 240") else UI.Notify("Universal", "Executor tidak support setfpscap") end
    end, "accent")
    srv:Button("Rejoin", function() U.Rejoin() end)
    srv:Button("Server Hop", function() U.Hop() end)

    local ppl = W:Tab("Players")
    ppl:Section("Pemain")
    ppl:Dropdown("Player", "Target", U:PlayerNames(), nil, function(v) Options.Player = v end)
    ppl:Button("Refresh Players", function() W:SetDropdown("Player", U:PlayerNames()) end)
    ppl:Button("Teleport Ke Player", function()
        local r = U:TargetRoot(Options.Player)
        if r then U:MoveTo(r.CFrame + V3(0, 2.5, 0)) end
    end, "accent")
    ppl:Section("Troll")
    ppl:Dropdown("TrollTarget", "Target", U:PlayerNames(), nil, function(v) Options.TrollTarget = v end)
    ppl:Toggle("Spectate", "Spectate", "Lihat dari kamera target", false, function(v)
        Options.Spectate = v
        local cam2 = Workspace.CurrentCamera
        if v then
            local t = Players:FindFirstChild(Options.TrollTarget or "")
            local hum = t and t.Character and t.Character:FindFirstChildOfClass("Humanoid")
            if cam2 and hum then cam2.CameraSubject = hum end
        elseif cam2 and U.Player.Humanoid then
            cam2.CameraSubject = U.Player.Humanoid
        end
    end)
    ppl:Toggle("Fling", "Fling", "Matikan automasi saat aktif", false, function(v) Options.Fling = v if not v then U.StopFling() end end)
    ppl:Toggle("Stick", "Stick", "Tempel ke target", false, function(v) Options.Stick = v end)
end

--================ Boot ================--
function U:Boot()
    if LP.Character then self.Player:Bind(LP.Character) end
    self:Connect(LP.CharacterAdded, function(ch) self.Player:Bind(ch) end)

    self:Connect(RunService.Heartbeat, function(dt)
        U.Frame(dt)
        U.TrollFrame()
    end)

    self:Connect(UserInputService.JumpRequest, function()
        if Options.InfJump and self.Player.Humanoid then
            self.Player.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    self:Connect(LP.Idled, function()
        if not Options.AntiAfk then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    self:Connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed or not Options.ClickTp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 and self:IsAlive() then
            local hit = LP:GetMouse().Hit
            if hit then self:MoveTo(hit.CFrame + V3(0, 3, 0)) end
        end
    end)

    local frames = 0
    self:Connect(RunService.RenderStepped, function() frames += 1 end)
    task.spawn(function()
        while State.Alive do
            State.FPS = frames
            frames = 0
            task.wait(1)
        end
    end)

    task.spawn(function()
        while State.Alive do
            pcall(U.EspRefresh)
            task.wait(Config.EspRefresh)
        end
    end)

    getgenv().HAUnloadUniversal = function()
        State.Alive = false
        U.EspClear()
        U.SetFullbright(false)
        U.RestoreMovement(nil)
        if U.Player.Humanoid then Workspace.CurrentCamera.CameraSubject = U.Player.Humanoid end
        for _, c in ipairs(State.Connections) do c:Disconnect() end
        table.clear(State.Connections)
        if U.UIRef then
            -- Lepas tab universal saja; window tetap untuk script game lain
            for _, key in ipairs({ "Home", "Character", "Visual", "Server", "Players" }) do
                U.UIRef:RemoveTab(key)
            end
            if not next(U.UIRef.Tabs) then
                U.UIRef:Destroy()
                getgenv().HA_UI = nil
            end
        end
        getgenv().HA_Universal = nil
    end

    U.BuildUI()
    UI.Show()
    UI.Notify("HA Universal", "Aktif di semua game. LeftCtrl / tombol HA.")
end

U:Boot()
return U
