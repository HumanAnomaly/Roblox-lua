local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

if game.GameId ~= 10035204815 then
    LP:Kick("HumanAnomaly: Ride A Pet only")
    return
end

local BASE = "https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/"
local UI
if getgenv and getgenv().HA_UI_SRC then
    UI = loadstring(getgenv().HA_UI_SRC)()
else
    UI = loadstring(game:HttpGet(BASE .. "Lib/ha-ui.lua"))()
end

local HA = {}
HA.Config = {
    Tag = "[HumanAnomaly]",
    SaveFolder = "HumanAnomaly/RideAPet",
    Discord = "https://discord.gg/NGBgETjmv3",
    EggHover = 4, HomeHover = 3, NestHover = 5,
    TeleportSettle = 0.25, EquipSettle = 0.15,
    PickupWait = 0.6, DeliverWait = 0.6,
    ClaimBatch = 64, EggSkipFor = 30, EggStock = 40,
    DeliverBackoff = 3, SnapshotTtl = 0.2, LockWait = 6,
    EggTick = 0.1, StepTick = 0.5, HatchGap = 1.5, HatchRetry = 30,
    PlaceGap = 0.4, NestSkipFor = 30, PetSpread = 0.35, PetLift = 0.5,
    PetFailBackoff = 20, FeedGap = 1, FeedEvery = 5, ClaimGap = 30,
    UpgradeGap = 2, NestsGap = 5, RebirthGap = 5, RebirthBackoff = 60, RebirthReserve = 2,
    HuntHopAfter = 45, HuntMaxHops = 15, HopPick = 15, HopReset = 15,
    FlySpeed = 120, WalkSpeed = 60, JumpPower = 80,
    FlingSpin = 2000, FlingForce = 9e4, StickOffset = 2,
    EspRange = 8000, EspRefresh = 0.5, EspLift = 4,
    RarityColors = {
        Common = Color3.fromRGB(200, 200, 200), Rare = Color3.fromRGB(90, 170, 255),
        Epic = Color3.fromRGB(190, 110, 255), Legendary = Color3.fromRGB(255, 200, 60),
        Mythic = Color3.fromRGB(255, 90, 90), Divine = Color3.fromRGB(120, 255, 220),
        Ethereal = Color3.fromRGB(255, 130, 230),
    },
}
HA.State = {
    Alive = true, Connections = {}, Status = "Idle", Lock = nil,
    EggsCollected = 0, EggSkip = {}, NestSkip = {}, Snapshot = nil,
    StockFloor = 0, SnapshotAt = 0, DeliverFailUntil = 0, PetFailUntil = 0,
    LastHatch = 0, LastHatchAll = 0, LastClaim = 0, LastUpgrade = 0,
    LastNests = 0, LastRebirth = 0, RebirthBlockedUntil = 0, LastFeed = 0,
    NextRebirthCost = math.huge, EmptySince = nil, Hopping = false,
    EspBoards = {}, CollidePatch = {}, FlingHome = nil,
}
HA.Options = {}
local Config, State = HA.Config, HA.State
local V3, CF = Vector3.new, CFrame.new
local Clock = os.clock

local function Need(parent, name)
    local c = parent and parent:WaitForChild(name, 30)
    if not c then error(Config.Tag .. " missing " .. name) end
    return c
end

local GR = Need(Need(ReplicatedStorage, "Remotes"), "Game")
local PR = Need(GR, "Plot")
HA.Net = {
    EggPickup = Need(GR, "EggPickup"), EggArrivalClaim = Need(GR, "EggArrivalClaim"),
    EggPlaced = Need(GR, "EggPlaced"), Hatch = Need(GR, "Hatch"),
    PlacePet = Need(GR, "PlacePet"), PickupPet = Need(GR, "PickupPet"),
    PetCollect = Need(GR, "PetCollect"), FeedPet = Need(GR, "FeedPet"),
    Rebirth = Need(GR, "Rebirth"), Upgrades = Need(PR, "Upgrades"),
    Nests = Need(PR, "Nests"), ClaimIndexReward = Need(GR, "ClaimIndexReward"),
    OfflineEarnings = Need(GR, "OfflineEarnings"),
}
local GD = Need(ReplicatedStorage, "GameData")
HA.Lib = {
    Eggs = require(Need(GD, "Eggs")), Pets = require(Need(GD, "Pets")),
    Rebirths = require(Need(GD, "Rebirths")), Mutations = require(Need(GD, "Mutations")),
    Foods = require(Need(GD, "Foods")), Nests = require(Need(GD, "Nests")),
    EggBaskets = require(Need(GD, "EggBaskets")),
}
local GameLib = HA.Lib

HA.EggInfo, HA.EggNames, HA.Rarities, HA.RarityRank, HA.FoodNames = {}, {}, {}, {}, {}
function HA.BuildLists()
    table.clear(HA.EggInfo) table.clear(HA.EggNames) table.clear(HA.Rarities)
    table.clear(HA.RarityRank) table.clear(HA.FoodNames)
    local floor = {}
    for name, info in pairs(GameLib.Eggs) do
        local r = info.Rarity or "Common"
        local luck = tonumber(info.Luck) or math.huge
        HA.EggInfo[name] = { Rarity = r, Luck = luck, Growth = tonumber(info.GrowthTime) or 0 }
        HA.EggNames[#HA.EggNames + 1] = name
        floor[r] = math.min(floor[r] or math.huge, luck)
    end
    table.sort(HA.EggNames, function(a, b) return HA.EggInfo[a].Luck > HA.EggInfo[b].Luck end)
    for r in pairs(floor) do HA.Rarities[#HA.Rarities + 1] = r end
    table.sort(HA.Rarities, function(a, b) return floor[a] < floor[b] end)
    for i, r in ipairs(HA.Rarities) do HA.RarityRank[r] = i end
    for name in pairs(GameLib.Foods) do HA.FoodNames[#HA.FoodNames + 1] = name end
    table.sort(HA.FoodNames, function(a, b) return (GameLib.Foods[a].XP or 0) > (GameLib.Foods[b].XP or 0) end)
end
HA.BuildLists()

function HA:Connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(State.Connections, c)
    return c
end
function HA:SetStatus(t) State.Status = t end
function HA:Acquire(owner, patience)
    local deadline = Clock() + (patience or 0)
    while State.Lock and State.Lock ~= owner do
        if Clock() > deadline or not State.Alive then return false end
        task.wait(0.05)
    end
    State.Lock = owner
    return true
end
function HA:Release(owner) if State.Lock == owner then State.Lock = nil end end
function HA:WithLock(owner, patience, fn, ...)
    if not self:Acquire(owner, patience) then return false end
    local ok, err = pcall(fn, ...)
    self:Release(owner)
    if not ok then warn(Config.Tag, owner, err) end
    return ok
end
function HA:TrollActive() return self.Options.Fling or self.Options.Stick end
function HA:Saved() return LP:FindFirstChild("SavedData") end
function HA:Cash() local s = self:Saved() return s and s.Cash.Value or 0 end
function HA:Rebirths() local s = self:Saved() return s and s.Rebirths.Value or 0 end
function HA:GetPlot()
    if State.Plot and State.Plot.Parent then return State.Plot end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        local d = p:FindFirstChild("Data")
        local o = d and d:FindFirstChild("Owner")
        if o and o.Value == LP then State.Plot = p return p end
    end
end
function HA:HomeCFrame()
    local p = self:GetPlot()
    local b = p and p:FindFirstChild("Baseplate")
    if not b then return nil end
    return b.CFrame + V3(0, b.Size.Y / 2 + Config.HomeHover, 0)
end
function HA:MoveTo(cf)
    if not cf or not self.Player:IsAlive() then return false end
    self.Player.Root.AssemblyLinearVelocity = Vector3.zero
    self.Player.Root.CFrame = cf
    return true
end
function HA:BasketCount() local b = LP:FindFirstChild("Basket") return b and #b:GetChildren() or 0 end
function HA:BasketCapacity()
    local s = self:Saved()
    local info = GameLib.EggBaskets[s and s.EquippedEggBasket.Value or "Wooden"]
    return math.min(type(info) == "table" and tonumber(info.Capacity) or 1, Config.ClaimBatch)
end
function HA.FormatNumber(n)
    if n == math.huge then return "-" end
    local suf = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }
    local i = 1
    while math.abs(n) >= 1000 and i < #suf do n /= 1000 i += 1 end
    return i == 1 and tostring(math.floor(n)) or string.format("%.2f%s", n, suf[i])
end

HA.Player = { Client = LP, Parts = {} }
function HA.Player:Bind(ch)
    self.Character = ch
    self.Humanoid = ch:WaitForChild("Humanoid", 30)
    self.Root = ch:WaitForChild("HumanoidRootPart", 30)
    table.clear(self.Parts) table.clear(State.CollidePatch)
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then self.Parts[#self.Parts + 1] = p end
    end
    HA:Connect(ch.DescendantAdded, function(p)
        if p:IsA("BasePart") then self.Parts[#self.Parts + 1] = p end
    end)
    if self.Humanoid then
        HA.Move.Saved.WalkSpeed = HA.Move.Saved.WalkSpeed or self.Humanoid.WalkSpeed
        HA.Move.Saved.JumpPower = HA.Move.Saved.JumpPower or self.Humanoid.JumpPower
    end
end
function HA.Player:IsAlive()
    return self.Humanoid ~= nil and self.Humanoid.Health > 0 and self.Root ~= nil and self.Root.Parent ~= nil
end

HA.Eggs = {}
function HA.Eggs.Wanted(name)
    local info = HA.EggInfo[name]
    if not info then return false end
    local o = HA.Options
    if o.EggHunter then
        local f = HA.RarityRank[o.HuntMinRarity or "Mythic"] or 1
        if (HA.RarityRank[info.Rarity] or 1) < f then return false end
    end
    if o.EggRarities and next(o.EggRarities) and not o.EggRarities[info.Rarity] then return false end
    if o.EggNames and next(o.EggNames) and not o.EggNames[name] then return false end
    if o.SmartEggs and info.Luck <= State.StockFloor then return false end
    return info.Luck >= (o.MinLuck or 0)
end
function HA.Eggs.StockFloor()
    local tools = HA.Hatch.EggTools()
    if #tools < Config.EggStock then return 0 end
    local lucks = table.create(#tools)
    for i, t in ipairs(tools) do
        local info = HA.Hatch.ToolEgg(t)
        lucks[i] = info and info.Luck or 0
    end
    table.sort(lucks, function(a, b) return a > b end)
    return lucks[Config.EggStock]
end
function HA.Eggs.Available()
    local now = Clock()
    if State.Snapshot and now - State.SnapshotAt < Config.SnapshotTtl then return State.Snapshot end
    State.StockFloor = HA.Options.SmartEggs and HA.Eggs.StockFloor() or 0
    local folder = ReplicatedStorage:FindFirstChild("ServerData")
    folder = folder and folder:FindFirstChild("ActiveEggs")
    local list = {}
    if folder then
        local serverNow = Workspace:GetServerTimeNow()
        for _, egg in ipairs(folder:GetChildren()) do
            local name = egg:GetAttribute("Egg")
            local priv = egg:GetAttribute("PrivateTo")
            if not name or not egg:GetAttribute("Position") then continue end
            if priv and priv ~= LP.UserId then continue end
            if (tonumber(egg:GetAttribute("DropEndsAt")) or 0) > serverNow then continue end
            if (State.EggSkip[egg.Name] or 0) > now then continue end
            if not HA.Eggs.Wanted(name) then continue end
            list[#list + 1] = { egg, HA.EggInfo[name].Luck * (egg:GetAttribute("Weight") or 1) }
        end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i, p in ipairs(list) do list[i] = p[1] end
    end
    State.Snapshot, State.SnapshotAt = list, now
    return list
end
function HA.Eggs.Pickup(egg)
    local before = HA:BasketCount()
    HA:MoveTo(CF(egg:GetAttribute("Position") + V3(0, Config.EggHover, 0)))
    task.wait(Config.TeleportSettle)
    HA.Net.EggPickup:FireServer(egg.Name)
    local deadline = Clock() + Config.PickupWait
    repeat task.wait() until HA:BasketCount() > before or Clock() > deadline
    local got = HA:BasketCount() > before
    if not got then State.EggSkip[egg.Name] = Clock() + Config.EggSkipFor end
    return got
end
function HA.Eggs.Deliver()
    if HA:BasketCount() == 0 then return true end
    if not HA:MoveTo(HA:HomeCFrame()) then return false end
    task.wait(Config.TeleportSettle)
    local names = {}
    for _, e in ipairs(LP.Basket:GetChildren()) do
        names[#names + 1] = e.Name
        if #names >= Config.ClaimBatch then break end
    end
    HA.Net.EggArrivalClaim:FireServer(Workspace:GetServerTimeNow(), HA.Player.Root.Position, names)
    local deadline = Clock() + Config.DeliverWait
    repeat task.wait() until HA:BasketCount() == 0 or Clock() > deadline
    return HA:BasketCount() == 0
end
function HA.Eggs.Run()
    local origin = HA.Player.Root.CFrame
    local cap = HA:BasketCapacity()
    local got = 0
    for _, egg in ipairs(HA.Eggs.Available()) do
        if not State.Alive or not HA.Player:IsAlive() or HA:TrollActive() then break end
        if not egg.Parent then continue end
        HA:SetStatus("Grabbing " .. egg:GetAttribute("Egg"))
        if HA.Eggs.Pickup(egg) then got += 1 end
        if HA:BasketCount() >= cap and not HA.Eggs.Deliver() then
            State.DeliverFailUntil = Clock() + Config.DeliverBackoff
            HA:SetStatus("Delivery refused, retrying soon")
            break
        end
    end
    if HA:BasketCount() > 0 and not HA.Eggs.Deliver() then
        State.DeliverFailUntil = Clock() + Config.DeliverBackoff
    end
    State.Snapshot = nil
    State.EggsCollected += got
    if HA.Options.ReturnAfter and got > 0 then HA:MoveTo(origin) end
    if Clock() > State.DeliverFailUntil then
        HA:SetStatus(got > 0 and ("Collected " .. got .. " eggs") or "Waiting for eggs")
    end
    return got
end
function HA.Eggs.Step()
    local o = HA.Options
    if not o.AutoEggs and not o.EggHunter then return end
    if HA:TrollActive() or Clock() < State.DeliverFailUntil then return end
    if #HA.Eggs.Available() > 0 then
        State.EmptySince = nil
        HA:WithLock("eggs", 0, HA.Eggs.Run)
        return
    end
    State.EmptySince = State.EmptySince or Clock()
    if not o.EggHunter then HA:SetStatus("Waiting for eggs") return end
    local left = Config.HuntHopAfter - (Clock() - State.EmptySince)
    HA:SetStatus(string.format("No rare eggs, hopping in %ds", math.max(0, math.ceil(left))))
    if left <= 0 and not State.Hopping then HA.Server.HuntHop() end
end

HA.Hatch = {}
function HA.Hatch.EggTools()
    local tools = {}
    for _, h in ipairs({ LP:FindFirstChild("Backpack"), HA.Player.Character }) do
        if not h then continue end
        for _, t in ipairs(h:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("EggInventoryId") then tools[#tools + 1] = t end
        end
    end
    return tools
end
function HA.Hatch.ToolEgg(tool) return HA.EggInfo[tool.Name:match("^(.-Egg)") or ""] end
function HA.Hatch.MyEggs()
    local plot = HA:GetPlot()
    local folder = plot and plot:FindFirstChild("Eggs")
    local eggs = {}
    if not folder then return eggs end
    for _, e in ipairs(folder:GetChildren()) do
        if e:GetAttribute("EggKey") and e:GetAttribute("OwnerUserId") == LP.UserId then eggs[#eggs + 1] = e end
    end
    return eggs
end
function HA.Hatch.IsReady(egg)
    for _, l in ipairs(egg:GetDescendants()) do
        if l.Name == "Timer" and l:IsA("TextLabel") then
            local t = l.Text
            return t == "" or not t:find("%d+:%d%d") or t:match("^0?0?:?0:00$") ~= nil
        end
    end
    return true
end
function HA.Hatch.FreeNests()
    local plot = HA:GetPlot()
    local nests = plot and plot:FindFirstChild("Nests")
    local free = {}
    if not nests then return free end
    for _, n in ipairs(nests:GetChildren()) do
        if n:GetAttribute("Unlocked") and not n:GetAttribute("Occupied") and (State.NestSkip[n] or 0) < Clock() then
            free[#free + 1] = n
        end
    end
    return free
end
function HA.Hatch.Place()
    local tools = HA.Hatch.EggTools()
    local nests = HA.Hatch.FreeNests()
    if #tools == 0 or #nests == 0 then return end
    local fastest = HA.Options.FastestFirst
    table.sort(tools, function(a, b)
        local ia, ib = HA.Hatch.ToolEgg(a), HA.Hatch.ToolEgg(b)
        local ra = ia and (fastest and -ia.Growth or ia.Luck) or -math.huge
        local rb = ib and (fastest and -ib.Growth or ib.Luck) or -math.huge
        return ra > rb
    end)
    local origin = HA.Player.Root.CFrame
    for _, nest in ipairs(nests) do
        local tool = table.remove(tools, 1)
        if not tool or not HA.Player:IsAlive() then break end
        HA:SetStatus("Placing " .. tool.Name)
        HA:MoveTo(nest:GetPivot() + V3(0, Config.NestHover, 0))
        task.wait(Config.TeleportSettle)
        HA.Player.Humanoid:EquipTool(tool)
        task.wait(Config.EquipSettle)
        HA.Net.EggPlaced:FireServer({ NestId = nest.Name })
        task.wait(Config.PlaceGap)
        if not nest:GetAttribute("Occupied") then State.NestSkip[nest] = Clock() + Config.NestSkipFor end
    end
    HA.Player.Humanoid:UnequipTools()
    HA:MoveTo(origin)
end
function HA.Hatch.HatchNow(force)
    for _, e in ipairs(HA.Hatch.MyEggs()) do
        if force or HA.Hatch.IsReady(e) then
            HA.Net.Hatch:FireServer({ EggKey = e:GetAttribute("EggKey") })
        end
    end
end
function HA.Hatch.Step()
    local o, now = HA.Options, Clock()
    if o.AutoPlaceEggs and not HA:TrollActive() and #HA.Hatch.FreeNests() > 0 and #HA.Hatch.EggTools() > 0 then
        HA:WithLock("place", 0, HA.Hatch.Place)
    end
    if o.AutoHatch and now - State.LastHatch > Config.HatchGap then
        State.LastHatch = now
        local sweep = now - State.LastHatchAll > Config.HatchRetry
        if sweep then State.LastHatchAll = now end
        HA.Hatch.HatchNow(sweep)
    end
end

HA.Pets = {}
function HA.Pets.Score(inst)
    local info = GameLib.Pets[inst:GetAttribute("PetName") or ""]
    local income = type(info) == "table" and tonumber(info.Income) or 0
    local f = 1
    for _, a in ipairs({ "Mutation", "SpawnMutation" }) do
        local m = GameLib.Mutations[inst:GetAttribute(a) or ""]
        if type(m) == "table" then f *= 1 + (tonumber(m.StatMultiplier) or 0) / 100 end
    end
    return income * (inst:GetAttribute("Weight") or 1) * f
end
function HA.Pets.Ranked(list, asc)
    local r = table.create(#list)
    for i, inst in ipairs(list) do r[i] = { inst, HA.Pets.Score(inst) } end
    table.sort(r, function(a, b) return asc and a[2] < b[2] or a[2] > b[2] end)
    return r
end
function HA.Pets.Placed()
    local plot = HA:GetPlot()
    local folder = plot and plot:FindFirstChild("Pets")
    local list = {}
    if not folder then return list end
    for _, p in ipairs(folder:GetChildren()) do
        if p:GetAttribute("OwnerUserId") == LP.UserId and p:GetAttribute("PetKey") then list[#list + 1] = p end
    end
    return list
end
function HA.Pets.Owned()
    local list = {}
    for _, h in ipairs({ LP:FindFirstChild("Backpack"), HA.Player.Character }) do
        if not h then continue end
        for _, t in ipairs(h:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("PetKey") then list[#list + 1] = t end
        end
    end
    return list
end
function HA.Pets.MaxSlots()
    local s = HA:Saved()
    return tonumber(s and s.MaxPets.Value) or GameLib.Rebirths.BasePetCapacity or 5
end
function HA.Pets.RandomSpot()
    local plot = HA:GetPlot()
    local b = plot and plot:FindFirstChild("Baseplate")
    if not b then return nil end
    local half = b.Size * Config.PetSpread
    local off = V3((math.random() * 2 - 1) * half.X, b.Size.Y / 2 + Config.PetLift, (math.random() * 2 - 1) * half.Z)
    return (b.CFrame * CF(off)).Position
end
function HA.Pets.EquipBest()
    if Clock() < State.PetFailUntil then return false end
    local placed = HA.Pets.Ranked(HA.Pets.Placed(), true)
    local owned = HA.Pets.Ranked(HA.Pets.Owned(), false)
    local free = HA.Pets.MaxSlots() - #placed
    local before = #placed
    local acted = false
    for _, pair in ipairs(owned) do
        local tool, score = pair[1], pair[2]
        local spot = HA.Pets.RandomSpot()
        if not spot then return false end
        if free > 0 then
            HA.Net.PlacePet:FireServer(tool:GetAttribute("PetKey"), spot)
            free -= 1 acted = true
            task.wait(Config.PlaceGap)
            continue
        end
        local worst = placed[1]
        if not worst or score <= worst[2] then break end
        table.remove(placed, 1)
        HA.Net.PickupPet:FireServer(worst[1]:GetAttribute("PetKey"))
        task.wait(Config.PlaceGap)
        HA.Net.PlacePet:FireServer(tool:GetAttribute("PetKey"), spot)
        acted = true
        task.wait(Config.PlaceGap)
    end
    if acted and #HA.Pets.Placed() < math.min(before + 1, HA.Pets.MaxSlots()) and before < HA.Pets.MaxSlots() then
        State.PetFailUntil = Clock() + Config.PetFailBackoff
    end
    return acted
end
function HA.Pets.CollectNow()
    for _, p in ipairs(HA.Pets.Placed()) do
        HA.Net.PetCollect:FireServer(p:GetAttribute("PetKey"))
    end
end
function HA.Pets.FoodTool()
    local allowed = HA.Options.FoodTypes
    local bp = LP:FindFirstChild("Backpack")
    for _, name in ipairs(HA.FoodNames) do
        if allowed and next(allowed) and not allowed[name] then continue end
        local t = (bp and bp:FindFirstChild(name)) or (HA.Player.Character and HA.Player.Character:FindFirstChild(name))
        if t then return t end
    end
end
function HA.Pets.Feed()
    for _, pair in ipairs(HA.Pets.Ranked(HA.Pets.Placed(), false)) do
        local food = HA.Pets.FoodTool()
        if not food or not HA.Player:IsAlive() then break end
        HA.Player.Humanoid:EquipTool(food)
        task.wait(Config.EquipSettle)
        HA.Net.FeedPet:FireServer(pair[1]:GetAttribute("PetKey"), food.Name, true)
        task.wait(Config.FeedGap)
    end
    if HA.Player.Humanoid then HA.Player.Humanoid:UnequipTools() end
end
function HA.Pets.Step()
    local o, now = HA.Options, Clock()
    if o.AutoEquipBest then HA:WithLock("pets", 0, HA.Pets.EquipBest) end
    if o.AutoCollectCash then HA.Pets.CollectNow() end
    if o.AutoFeed and now - State.LastFeed > Config.FeedGap * Config.FeedEvery then
        State.LastFeed = now
        HA:WithLock("feed", 0, HA.Pets.Feed)
    end
end

HA.Progress = {}
function HA.Progress.RebirthCost()
    local lib = GameLib.Rebirths
    local nextR = HA:Rebirths() + 1
    if nextR > (lib.Cap or math.huge) then return math.huge end
    if lib.RiggedCost and lib.RiggedCost[nextR] then return lib.RiggedCost[nextR] end
    local ok, cost = pcall(lib.GetCost, HA:Rebirths())
    return ok and tonumber(cost) or math.huge
end
function HA.Progress.CanRebirthSoon()
    return HA.Options.AutoRebirth and State.NextRebirthCost < math.huge and Clock() > State.RebirthBlockedUntil
end
function HA.Progress.RebirthNow()
    if HA:Rebirths() >= (GameLib.Rebirths.Cap or math.huge) then return end
    local before = HA:Rebirths()
    HA.Net.Rebirth:FireServer()
    task.delay(3, function()
        if HA:Rebirths() == before then
            State.RebirthBlockedUntil = Clock() + Config.RebirthBackoff
            HA:SetStatus("Rebirth refused (missing required pet?)")
        end
    end)
end
function HA.Progress.Step()
    local o, now = HA.Options, Clock()
    State.NextRebirthCost = HA.Progress.RebirthCost()
    if o.AutoRebirth and now - State.LastRebirth > Config.RebirthGap and now > State.RebirthBlockedUntil and HA:Cash() >= State.NextRebirthCost then
        State.LastRebirth = now
        HA.Progress.RebirthNow()
    end
    if o.AutoNests and now - State.LastNests > Config.NestsGap then
        State.LastNests = now
        local plot = HA:GetPlot()
        local nests = plot and plot:FindFirstChild("Nests")
        if nests then
            local prices = GameLib.Nests.Prices or {}
            for _, n in ipairs(nests:GetChildren()) do
                local idx = tonumber(n.Name)
                if n:GetAttribute("Unlocked") or not idx then continue end
                if HA:Cash() < (prices[idx] or math.huge) then continue end
                HA.Net.Nests:FireServer(idx)
                task.wait(Config.PlaceGap)
            end
        end
    end
    if o.AutoUpgrade and now - State.LastUpgrade > Config.UpgradeGap then
        local saving = HA.Options.SmartSpend and HA.Progress.CanRebirthSoon() and HA:Cash() < State.NextRebirthCost * Config.RebirthReserve
        if not saving then
            State.LastUpgrade = now
            HA.Net.Upgrades:FireServer("Max")
        end
    end
    if o.AutoClaim and now - State.LastClaim > Config.ClaimGap then
        State.LastClaim = now
        HA.Net.ClaimIndexReward:FireServer()
        HA.Net.OfflineEarnings:FireServer()
    end
end

HA.Move = { Saved = {} }
function HA.Move.SetNoClip(on)
    if on then
        for _, p in ipairs(HA.Player.Parts) do
            if p.Parent and p.CanCollide then State.CollidePatch[p] = true p.CanCollide = false end
        end
        return
    end
    for p in pairs(State.CollidePatch) do
        if p.Parent then p.CanCollide = true end
    end
    table.clear(State.CollidePatch)
end
function HA.Move.Frame(dt)
    local o = HA.Options
    local hum = HA.Player.Humanoid
    if o.NoClip or o.Fly or o.Fling then HA.Move.SetNoClip(true) end
    if o.Fly and HA.Player.Root then
        local cam = Workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
        HA.Player.Root.AssemblyLinearVelocity = Vector3.zero
        if dir.Magnitude > 0 then HA.Player.Root.CFrame += dir.Unit * (o.FlySpeed or Config.FlySpeed) * dt end
    end
    if hum and o.SpeedOn then hum.WalkSpeed = o.WalkSpeed or Config.WalkSpeed end
    if hum and o.JumpOn then hum.JumpPower = o.JumpPower or Config.JumpPower end
end
function HA.Move.Restore(idx)
    local o, hum = HA.Options, HA.Player.Humanoid
    if hum and (idx == "SpeedOn" or idx == nil) then hum.WalkSpeed = HA.Move.Saved.WalkSpeed or 16 end
    if hum and (idx == "JumpOn" or idx == nil) then hum.JumpPower = HA.Move.Saved.JumpPower or 50 end
    if idx == nil or not (o.NoClip or o.Fly or o.Fling) then HA.Move.SetNoClip(false) end
    if idx == "Fly" and HA.Player.Root then HA.Player.Root.AssemblyLinearVelocity = Vector3.zero end
end

HA.Esp = {}
function HA.Esp.Clear()
    for k, e in pairs(State.EspBoards) do e.Board:Destroy() State.EspBoards[k] = nil end
end
function HA.Esp.Refresh()
    if not HA.Options.EggEsp then
        if next(State.EspBoards) then HA.Esp.Clear() end
        return
    end
    local rendered = Workspace:FindFirstChild("RenderedEggs")
    if not rendered then return end
    local root = HA.Player.Root
    local minRank = HA.RarityRank[HA.Options.EspMinRarity or ""] or 1
    local seen = {}
    for _, model in ipairs(rendered:GetChildren()) do
        local info = HA.EggInfo[model.Name]
        if not info or (HA.RarityRank[info.Rarity] or 1) < minRank then continue end
        local entry = State.EspBoards[model]
        if not entry or not entry.Board.Parent then
            local part = model:IsA("BasePart") and model or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if not part then continue end
            local board = Instance.new("BillboardGui")
            board.Name = "HA_Esp"
            board.AlwaysOnTop = true
            board.Size = UDim2.fromOffset(200, 40)
            board.StudsOffset = V3(0, Config.EspLift, 0)
            board.MaxDistance = Config.EspRange
            board.Adornee = part
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Size = UDim2.fromScale(1, 1)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 14
            label.TextStrokeTransparency = 0.3
            label.TextColor3 = Config.RarityColors[info.Rarity] or Color3.new(1, 1, 1)
            label.Parent = board
            board.Parent = (gethui and gethui()) or CoreGui
            entry = { Board = board, Label = label, Part = part }
            State.EspBoards[model] = entry
        end
        seen[model] = true
        local dist = root and math.floor((entry.Part.Position - root.Position).Magnitude) or 0
        entry.Label.Text = string.format("%s [%s]\n1 in %s | %dm", model.Name, info.Rarity, HA.FormatNumber(info.Luck), dist)
    end
    for k, e in pairs(State.EspBoards) do
        if not seen[k] then e.Board:Destroy() State.EspBoards[k] = nil end
    end
end

HA.Teleport = {}
function HA.Teleport.Places()
    local places = { ["My Plot"] = function() return HA:HomeCFrame() end }
    local stalls = Workspace:FindFirstChild("Stalls")
    for _, s in ipairs(stalls and stalls:GetChildren() or {}) do
        places["Shop: " .. s.Name] = function() return s:GetPivot() + V3(0, Config.HomeHover, 0) end
    end
    local volcano = Workspace:FindFirstChild("Volcano")
    for _, spot in ipairs({ "VolcanoEntrance", "VolcanoTop" }) do
        local part = volcano and volcano:FindFirstChild(spot)
        if part then places["Volcano: " .. spot:sub(8)] = function() return part.CFrame + V3(0, Config.NestHover, 0) end end
    end
    return places
end
function HA.Teleport.Names()
    local n = {}
    for name in pairs(HA.Teleport.Places()) do n[#n + 1] = name end
    table.sort(n)
    return n
end

HA.Troll = {}
function HA.Troll.TargetRoot()
    local t = Players:FindFirstChild(HA.Options.TrollTarget or "")
    return t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
end
function HA.Troll.Frame()
    local o = HA.Options
    if not o.Fling and not o.Stick then return end
    local troot, root = HA.Troll.TargetRoot(), HA.Player.Root
    if not troot or not root then return end
    if o.Fling then
        State.FlingHome = State.FlingHome or root.CFrame
        root.CFrame = troot.CFrame * CFrame.Angles(0, math.rad(Clock() * Config.FlingSpin % 360), 0)
        root.AssemblyLinearVelocity = V3(0, Config.FlingForce, 0)
        root.AssemblyAngularVelocity = V3(0, Config.FlingForce, 0)
        return
    end
    root.CFrame = troot.CFrame * CF(0, 0, Config.StickOffset)
end
function HA.Troll.StopFling()
    local root = HA.Player.Root
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if State.FlingHome then root.CFrame = State.FlingHome end
    end
    State.FlingHome = nil
    HA.Move.Restore("Fling")
end

HA.Server = {}
function HA.Server.Hop()
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
    local ok, body = pcall(game.HttpGet, game, url)
    local open = {}
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
function HA.Server.HuntHop()
    State.Hopping = true
    local hops = (State.HuntHops or 0) + 1
    if hops > Config.HuntMaxHops then
        State.HuntHops = 0
        HA.Options.EggHunter = false
        if UI.Window then UI.Window:SetToggle("EggHunter", false) end
        UI.Notify("Rare Egg Hunter", "No rare eggs after " .. Config.HuntMaxHops .. " servers, stopped")
        return
    end
    local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if queue and HA.Options.EggHunter then
        queue(string.format("getgenv().HAHunt = { Hops = %d, Rarity = %q } ", hops, HA.Options.HuntMinRarity or "Mythic") .. 'loadstring(game:HttpGet("' .. BASE .. 'Loader.lua"))()')
    end
    task.delay(Config.HopReset, function() State.Hopping = false State.EmptySince = Clock() end)
    pcall(HA.Server.Hop)
end

function HA.PlayerNames()
    local n = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then n[#n + 1] = p.Name end
    end
    table.sort(n)
    if #n == 0 then n = { "No players" } end
    return n
end

function HA.BuildUI()
    local W = UI.Create({
        Title = "HUMANANOMALY",
        Sub = "Ride A Pet",
        Discord = Config.Discord,
        Folder = Config.SaveFolder,
    })
    HA.UIRef = W

    local home = W:Tab("Home")
    home:Section("Automation")
    home:Toggle("Kaitun", "Kaitun", "Full auto from eggs to rebirth", false, function(on)
        for _, k in ipairs({ "AutoEggs", "SmartEggs", "AutoPlaceEggs", "AutoHatch", "AutoEquipBest", "AutoCollectCash", "AutoFeed", "AutoUpgrade", "SmartSpend", "AutoRebirth", "AutoNests", "AutoClaim", "AntiAfk" }) do
            HA.Options[k] = on
            W:SetToggle(k, on)
        end
    end)
    home:Toggle("SmartSpend", "Save For Rebirth", "Hold luck upgrades until rebirth is affordable", false, function(v) HA.Options.SmartSpend = v end)
    home:Button("Panic - All Off", function()
        for k in pairs(HA.Options) do HA.Options[k] = false end
        W:ResetAll()
        HA.Move.Restore(nil)
        W:SetStatus("IDLE", true)
    end, "danger")
    home:Section("Live Status")
    home:Label(function()
        local saving = (HA.Options.SmartSpend and State.NextRebirthCost < math.huge) and " (saving)" or ""
        return "Status: " .. State.Status .. saving
    end)
    home:Label(function() return "Cash: " .. HA.FormatNumber(HA:Cash()) .. " | Rebirths: " .. HA:Rebirths() end)
    home:Label(function() return "Eggs collected: " .. State.EggsCollected .. " | Wanted on map: " .. #HA.Eggs.Available() end)

    local eggs = W:Tab("Eggs")
    eggs:Section("Collect")
    eggs:Toggle("AutoEggs", "Auto Collect", "Grab wanted eggs and deliver home", false, function(v) HA.Options.AutoEggs = v end)
    eggs:Toggle("SmartEggs", "Better Only", "When bag is full take better eggs only", false, function(v) HA.Options.SmartEggs = v end)
    eggs:Toggle("ReturnAfter", "Return To Spot", "Teleport back after collecting", false, function(v) HA.Options.ReturnAfter = v end)
    eggs:Slider("MinLuck", "Min luck (1 in X)", 0, 1000000, 0, function(v) HA.Options.MinLuck = v end)
    eggs:Button("Teleport To Best Egg", function()
        local e = HA.Eggs.Available()[1]
        if e then HA:MoveTo(CF(e:GetAttribute("Position") + V3(0, Config.EggHover, 0))) end
    end)
    eggs:Section("Rare Hunter")
    eggs:Toggle("EggHunter", "Rare Hunter", "Top rarity only, hops server when empty", false, function(v) HA.Options.EggHunter = v end)
    eggs:Dropdown("HuntMinRarity", "Min rarity", HA.Rarities, "Mythic", function(v) HA.Options.HuntMinRarity = v end)
    eggs:Button("Hop Server", function() HA.Server.Hop() end)

    local hatch = W:Tab("Hatch")
    hatch:Section("Hatching")
    hatch:Toggle("AutoPlaceEggs", "Auto Place", "Put best eggs into free nests", false, function(v) HA.Options.AutoPlaceEggs = v end)
    hatch:Toggle("FastestFirst", "Fastest First", "Off means best luck first", false, function(v) HA.Options.FastestFirst = v end)
    hatch:Toggle("AutoHatch", "Auto Hatch", "Hatch from anywhere when ready", false, function(v) HA.Options.AutoHatch = v end)
    hatch:Button("Place Eggs Now", function() HA:WithLock("place", Config.LockWait, HA.Hatch.Place) end)
    hatch:Button("Hatch Now", function() HA.Hatch.HatchNow(true) end)
    hatch:Section("Nests")
    hatch:Toggle("AutoNests", "Auto Buy Nests", "Unlock nests when affordable", false, function(v) HA.Options.AutoNests = v end)

    local pets = W:Tab("Pets")
    pets:Section("Ranch")
    pets:Toggle("AutoEquipBest", "Place Best", "Keep ranch filled with top earners", false, function(v) HA.Options.AutoEquipBest = v end)
    pets:Toggle("AutoCollectCash", "Auto Cash", "Collect pet cash from anywhere", false, function(v) HA.Options.AutoCollectCash = v end)
    pets:Button("Place Best Now", function() HA:WithLock("pets", Config.LockWait, HA.Pets.EquipBest) end)
    pets:Button("Collect Cash Now", function() HA.Pets.CollectNow() end)
    pets:Section("Feeding")
    pets:Toggle("AutoFeed", "Auto Feed", "Feed best pets with owned food", false, function(v) HA.Options.AutoFeed = v end)

    local up = W:Tab("Upgrades")
    up:Section("Progress")
    up:Toggle("AutoUpgrade", "Auto Upgrade", "Buy every luck upgrade affordable", false, function(v) HA.Options.AutoUpgrade = v end)
    up:Toggle("AutoRebirth", "Auto Rebirth", "Rebirth when cash and pet ready", false, function(v) HA.Options.AutoRebirth = v end)
    up:Toggle("AutoClaim", "Auto Claim", "Index and offline rewards", false, function(v) HA.Options.AutoClaim = v end)
    up:Button("Upgrade Max Now", function() HA.Net.Upgrades:FireServer("Max") end)
    up:Button("Rebirth Now", function() HA.Progress.RebirthNow() end)
    up:Button("Claim Now", function() HA.Net.ClaimIndexReward:FireServer() HA.Net.OfflineEarnings:FireServer() end)

    local tp = W:Tab("Teleport")
    tp:Section("Places")
    tp:Dropdown("TPPlace", "Place", HA.Teleport.Names(), HA.Teleport.Names()[1], function(v) HA.Options.TPPlace = v end)
    tp:Button("Teleport", function()
        local g = HA.Teleport.Places()[HA.Options.TPPlace or ""]
        if g then HA:MoveTo(g()) end
    end, "accent")
    tp:Section("Players")
    tp:Dropdown("TPPlayer", "Player", HA.PlayerNames(), nil, function(v) HA.Options.TPPlayer = v end)
    tp:Button("Teleport To Player", function()
        local t = Players:FindFirstChild(HA.Options.TPPlayer or "")
        local r = t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
        if r then HA:MoveTo(r.CFrame + V3(0, Config.HomeHover, 0)) end
    end)
    tp:Section("Troll")
    tp:Dropdown("TrollTarget", "Target", HA.PlayerNames(), nil, function(v) HA.Options.TrollTarget = v end)
    tp:Toggle("Fling", "Fling", "Pause farming while on", false, function(v) HA.Options.Fling = v if not v then HA.Troll.StopFling() end end)
    tp:Toggle("Stick", "Stick", "Glue to target", false, function(v) HA.Options.Stick = v end)

    local pl = W:Tab("Player")
    pl:Section("Movement")
    pl:Toggle("SpeedOn", "Speed", "Custom walkspeed", false, function(v) HA.Options.SpeedOn = v if not v then HA.Move.Restore("SpeedOn") end end)
    pl:Slider("WalkSpeed", "Walk speed", 16, 300, Config.WalkSpeed, function(v) HA.Options.WalkSpeed = v end)
    pl:Toggle("JumpOn", "Jump Power", "Custom jump", false, function(v) HA.Options.JumpOn = v if not v then HA.Move.Restore("JumpOn") end end)
    pl:Slider("JumpPower", "Power", 50, 300, Config.JumpPower, function(v) HA.Options.JumpPower = v end)
    pl:Toggle("Fly", "Fly", "WASD + Space / Shift", false, function(v) HA.Options.Fly = v if not v then HA.Move.Restore("Fly") end end)
    pl:Slider("FlySpeed", "Fly speed", 20, 500, Config.FlySpeed, function(v) HA.Options.FlySpeed = v end)
    pl:Toggle("NoClip", "Noclip", "Walk through walls", false, function(v) HA.Options.NoClip = v if not v then HA.Move.Restore("NoClip") end end)
    pl:Toggle("InfJump", "Infinite Jump", nil, false, function(v) HA.Options.InfJump = v end)
    pl:Section("Vision")
    pl:Toggle("EggEsp", "Egg ESP", "Rarity and distance through walls", false, function(v) HA.Options.EggEsp = v end)
    pl:Dropdown("EspMinRarity", "ESP min rarity", HA.Rarities, HA.Rarities[1], function(v) HA.Options.EspMinRarity = v end)
    pl:Section("Server")
    pl:Toggle("AntiAfk", "Anti AFK", nil, false, function(v) HA.Options.AntiAfk = v end)
    pl:Button("Rejoin", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    pl:Button("Server Hop", function() HA.Server.Hop() end)
end

function HA:Boot()
    if LP.Character then self.Player:Bind(LP.Character) end
    self:Connect(LP.CharacterAdded, function(ch) self.Player:Bind(ch) end)
    self:Connect(RunService.Heartbeat, function(dt) HA.Move.Frame(dt) HA.Troll.Frame() end)
    self:Connect(LP.Idled, function()
        if not HA.Options.AntiAfk then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    self:Connect(UserInputService.JumpRequest, function()
        if HA.Options.InfJump and HA.Player.Humanoid then
            HA.Player.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    task.spawn(function()
        while State.Alive do
            pcall(HA.Eggs.Step)
            task.wait(Config.EggTick)
        end
    end)
    task.spawn(function()
        while State.Alive do
            pcall(HA.Hatch.Step)
            pcall(HA.Pets.Step)
            pcall(HA.Progress.Step)
            task.wait(Config.StepTick)
        end
    end)
    task.spawn(function()
        while State.Alive do
            pcall(HA.Esp.Refresh)
            task.wait(Config.EspRefresh)
        end
    end)
    getgenv().HAUnload = function()
        State.Alive = false
        HA.Esp.Clear()
        HA.Move.Restore(nil)
        for _, c in ipairs(State.Connections) do c:Disconnect() end
        table.clear(State.Connections)
        UI.Destroy()
    end
    HA.BuildUI()
    UI.Show()
    HA.UIRef:SetStatus("READY", true)
    UI.Notify("HumanAnomaly", "Menu: LeftCtrl to hide/show. Discord: " .. Config.Discord)
    local hunt = getgenv().HAHunt
    getgenv().HAHunt = nil
    if type(hunt) == "table" then
        State.HuntHops = tonumber(hunt.Hops) or 0
        HA.Options.HuntMinRarity = hunt.Rarity
        HA.Options.EggHunter = true
        HA.Options.AutoPlaceEggs = true
        HA.Options.AutoHatch = true
        HA.Options.AntiAfk = true
        HA.UIRef:SetToggle("EggHunter", true)
        UI.Notify("Hunter", "Hunting " .. tostring(hunt.Rarity) .. "+ (server " .. State.HuntHops .. "/" .. Config.HuntMaxHops .. ")")
    end
end

HA:Boot()
return HA
