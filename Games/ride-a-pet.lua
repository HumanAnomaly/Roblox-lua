--========================================================--
--  HumanAnomaly | Ride A Pet
--  Game script for Ride A Pet (GameId 10035204815).
--  Game automation only: eggs, nests, pets, progress.
--  Player features (fly, speed, player ESP, server hop,
--  anti-AFK, troll) live in the Universal scope, never mixed.
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

if game.GameId ~= 10035204815 then
    LP:Kick("HumanAnomaly: this script is only for Ride A Pet")
    return
end

local BASE = "https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/"
-- Shared UI instance -> single window, isolated scopes (UNIVERSAL vs RIDE A PET)
local UI = getgenv().HA_UI
if not UI then
    if getgenv().HA_UI_SRC then
        UI = loadstring(getgenv().HA_UI_SRC)()
    else
        UI = loadstring(game:HttpGet(BASE .. "Lib/ha-ui.lua"))()
    end
    getgenv().HA_UI = UI
end

local HA = {
    Config = {
        Tag = "[HA RideAPet]",
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
        EspRange = 8000, EspRefresh = 0.5, EspLift = 4,
        RarityColors = {
            Common = Color3.fromRGB(200, 200, 200), Rare = Color3.fromRGB(90, 170, 255),
            Epic = Color3.fromRGB(190, 110, 255), Legendary = Color3.fromRGB(255, 200, 60),
            Mythic = Color3.fromRGB(255, 90, 90), Divine = Color3.fromRGB(120, 255, 220),
            Ethereal = Color3.fromRGB(255, 130, 230),
        },
    },
    State = {
        Alive = true, Connections = {}, Status = "Idle", Lock = nil,
        EggsCollected = 0, EggSkip = {}, NestSkip = {}, Snapshot = nil,
        StockFloor = 0, SnapshotAt = 0, DeliverFailUntil = 0, PetFailUntil = 0,
        LastHatch = 0, LastHatchAll = 0, LastClaim = 0, LastUpgrade = 0,
        LastNests = 0, LastRebirth = 0, RebirthBlockedUntil = 0, LastFeed = 0,
        NextRebirthCost = math.huge, EmptySince = nil, Hopping = false,
        EspBoards = {}, Plot = nil, HuntHops = 0,
    },
    Options = {},
}
local Config, State, Options = HA.Config, HA.State, HA.Options
local V3, CF = Vector3.new, CFrame.new
local Clock = os.clock

--================ Data game ================--
local function Need(parent, name)
    local c = parent and parent:WaitForChild(name, 30)
    if not c then error(Config.Tag .. " missing: " .. tostring(name)) end
    return c
end

local GameRemotes = Need(Need(ReplicatedStorage, "Remotes"), "Game")
local PlotRemotes = Need(GameRemotes, "Plot")
HA.Net = {
    EggPickup = Need(GameRemotes, "EggPickup"),
    EggArrivalClaim = Need(GameRemotes, "EggArrivalClaim"),
    EggPlaced = Need(GameRemotes, "EggPlaced"),
    Hatch = Need(GameRemotes, "Hatch"),
    PlacePet = Need(GameRemotes, "PlacePet"),
    PickupPet = Need(GameRemotes, "PickupPet"),
    PetCollect = Need(GameRemotes, "PetCollect"),
    FeedPet = Need(GameRemotes, "FeedPet"),
    Rebirth = Need(GameRemotes, "Rebirth"),
    Upgrades = Need(PlotRemotes, "Upgrades"),
    Nests = Need(PlotRemotes, "Nests"),
    ClaimIndexReward = Need(GameRemotes, "ClaimIndexReward"),
    OfflineEarnings = Need(GameRemotes, "OfflineEarnings"),
}

local GameData = Need(ReplicatedStorage, "GameData")
HA.Data = {
    Eggs = require(Need(GameData, "Eggs")),
    Pets = require(Need(GameData, "Pets")),
    Rebirths = require(Need(GameData, "Rebirths")),
    Mutations = require(Need(GameData, "Mutations")),
    Foods = require(Need(GameData, "Foods")),
    Nests = require(Need(GameData, "Nests")),
    EggBaskets = require(Need(GameData, "EggBaskets")),
}
local Data = HA.Data

HA.Info, HA.EggNames, HA.Rarities, HA.RarityRank, HA.FoodNames = {}, {}, {}, {}, {}
function HA.BuildLists()
    table.clear(HA.Info) table.clear(HA.EggNames) table.clear(HA.Rarities)
    table.clear(HA.RarityRank) table.clear(HA.FoodNames)
    local lowestLuck = {}
    for name, info in pairs(Data.Eggs) do
        local rarity = info.Rarity or "Common"
        local luck = tonumber(info.Luck) or math.huge
        HA.Info[name] = { Rarity = rarity, Luck = luck, Growth = tonumber(info.GrowthTime) or 0 }
        HA.EggNames[#HA.EggNames + 1] = name
        lowestLuck[rarity] = math.min(lowestLuck[rarity] or math.huge, luck)
    end
    table.sort(HA.EggNames, function(a, b) return HA.Info[a].Luck > HA.Info[b].Luck end)
    for r in pairs(lowestLuck) do HA.Rarities[#HA.Rarities + 1] = r end
    table.sort(HA.Rarities, function(a, b) return lowestLuck[a] < lowestLuck[b] end)
    for i, r in ipairs(HA.Rarities) do HA.RarityRank[r] = i end
    for name in pairs(Data.Foods) do HA.FoodNames[#HA.FoodNames + 1] = name end
    table.sort(HA.FoodNames, function(a, b) return (Data.Foods[a].XP or 0) > (Data.Foods[b].XP or 0) end)
end
HA.BuildLists()

--================ Helper inti ================--
function HA:Connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(State.Connections, c)
    return c
end

function HA:SetStatus(text) State.Status = text end

-- Automation pauses while Universal troll (Fling/Stick) is active
function HA:IsBusy()
    local u = getgenv().HA_Universal
    local o = u and u.Options
    return (o and (o.Fling or o.Stick)) or false
end

function HA:Acquire(owner, patience)
    local deadline = Clock() + (patience or 0)
    while State.Lock and State.Lock ~= owner do
        if Clock() > deadline or not State.Alive then return false end
        task.wait(0.05)
    end
    State.Lock = owner
    return true
end

function HA:Release(owner)
    if State.Lock == owner then State.Lock = nil end
end

function HA:WithLock(owner, patience, fn, ...)
    if not self:Acquire(owner, patience) then return false end
    local ok, err = pcall(fn, ...)
    self:Release(owner)
    if not ok then warn(Config.Tag, owner, err) end
    return ok
end

function HA:Saved()
    return LP:FindFirstChild("SavedData")
end

function HA:Cash()
    local s = self:Saved()
    return s and s.Cash.Value or 0
end

function HA:RebirthCount()
    local s = self:Saved()
    return s and s.Rebirths.Value or 0
end

function HA:GetPlot()
    if State.Plot and State.Plot.Parent then return State.Plot end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, p in ipairs(plots:GetChildren()) do
        local d = p:FindFirstChild("Data")
        local o = d and d:FindFirstChild("Owner")
        if o and o.Value == LP then
            State.Plot = p
            return p
        end
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

function HA:BasketCount()
    local b = LP:FindFirstChild("Basket")
    return b and #b:GetChildren() or 0
end

function HA:BasketCapacity()
    local s = self:Saved()
    local info = Data.EggBaskets[s and s.EquippedEggBasket.Value or "Wooden"]
    return math.min(type(info) == "table" and tonumber(info.Capacity) or 1, Config.ClaimBatch)
end

function HA.FormatNumber(n)
    if n == math.huge then return "-" end
    local suf = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }
    local i = 1
    while math.abs(n) >= 1000 and i < #suf do
        n /= 1000
        i += 1
    end
    return i == 1 and tostring(math.floor(n)) or string.format("%.2f%s", n, suf[i])
end

HA.Player = { Parts = {} }
function HA.Player:Bind(ch)
    self.Character = ch
    self.Humanoid = ch:WaitForChild("Humanoid", 30)
    self.Root = ch:WaitForChild("HumanoidRootPart", 30)
    table.clear(self.Parts)
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then self.Parts[#self.Parts + 1] = p end
    end
    HA:Connect(ch.DescendantAdded, function(p)
        if p:IsA("BasePart") then self.Parts[#self.Parts + 1] = p end
    end)
end

function HA.Player:IsAlive()
    return self.Humanoid ~= nil and self.Humanoid.Health > 0
        and self.Root ~= nil and self.Root.Parent ~= nil
end

--================ Eggs (Farm) ================--
HA.Eggs = {}

function HA.Eggs.Wanted(name)
    local info = HA.Info[name]
    if not info then return false end
    local o = Options
    if o.EggHunter then
        local floorRank = HA.RarityRank[o.HuntMinRarity or "Mythic"] or 1
        if (HA.RarityRank[info.Rarity] or 1) < floorRank then return false end
    end
    if o.EggRarities and next(o.EggRarities) and not o.EggRarities[info.Rarity] then return false end
    if o.EggNames and next(o.EggNames) and not o.EggNames[name] then return false end
    if o.SwapSmarter and info.Luck <= State.StockFloor then return false end
    return info.Luck >= (o.MinLuck or 0)
end

-- When the bag is full: only pick eggs better than the bag contents
function HA.Eggs.StockFloor()
    local tools = HA.Hatch.BackpackEggs()
    if #tools < Config.EggStock then return 0 end
    local lucks = table.create(#tools)
    for i, t in ipairs(tools) do
        local info = HA.Hatch.ToolInfo(t)
        lucks[i] = info and info.Luck or 0
    end
    table.sort(lucks, function(a, b) return a > b end)
    return lucks[Config.EggStock]
end

function HA.Eggs.OnMap()
    local now = Clock()
    if State.Snapshot and now - State.SnapshotAt < Config.SnapshotTtl then return State.Snapshot end
    State.StockFloor = Options.SwapSmarter and HA.Eggs.StockFloor() or 0
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
            list[#list + 1] = { egg, HA.Info[name].Luck * (egg:GetAttribute("Weight") or 1) }
        end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i, p in ipairs(list) do list[i] = p[1] end
    end
    State.Snapshot, State.SnapshotAt = list, now
    return list
end

function HA.Eggs.Grab(egg)
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
    for _, egg in ipairs(HA.Eggs.OnMap()) do
        if not State.Alive or not HA.Player:IsAlive() or HA:IsBusy() then break end
        if not egg.Parent then continue end
        HA:SetStatus("Collecting " .. egg:GetAttribute("Egg"))
        if HA.Eggs.Grab(egg) then got += 1 end
        if HA:BasketCount() >= cap and not HA.Eggs.Deliver() then
            State.DeliverFailUntil = Clock() + Config.DeliverBackoff
            HA:SetStatus("Delivery rejected, retrying later")
            break
        end
    end
    if HA:BasketCount() > 0 and not HA.Eggs.Deliver() then
        State.DeliverFailUntil = Clock() + Config.DeliverBackoff
    end
    State.Snapshot = nil
    State.EggsCollected += got
    if Options.ReturnAfter and got > 0 then HA:MoveTo(origin) end
    if Clock() > State.DeliverFailUntil then
        HA:SetStatus(got > 0 and ("Collected " .. got .. " eggs") or "Waiting for eggs")
    end
    return got
end

function HA.Eggs.Step()
    if not Options.AutoEggs and not Options.EggHunter then return end
    if HA:IsBusy() or Clock() < State.DeliverFailUntil then return end
    if #HA.Eggs.OnMap() > 0 then
        State.EmptySince = nil
        HA:WithLock("eggs", 0, HA.Eggs.Run)
        return
    end
    State.EmptySince = State.EmptySince or Clock()
    if not Options.EggHunter then
        HA:SetStatus("Waiting for eggs")
        return
    end
    local left = Config.HuntHopAfter - (Clock() - State.EmptySince)
    HA:SetStatus(("Egg Radar: empty, hopping in %ds"):format(math.max(0, math.ceil(left))))
    if left <= 0 and not State.Hopping then HA.Server.RadarHop() end
end

--================ Nests (Hatchery) ================--
HA.Hatch = {}

function HA.Hatch.BackpackEggs()
    local tools = {}
    for _, holder in ipairs({ LP:FindFirstChild("Backpack"), HA.Player.Character }) do
        if not holder then continue end
        for _, t in ipairs(holder:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("EggInventoryId") then tools[#tools + 1] = t end
        end
    end
    return tools
end

function HA.Hatch.ToolInfo(tool)
    return HA.Info[tool.Name:match("^(.-Egg)") or ""]
end

function HA.Hatch.MyEggs()
    local plot = HA:GetPlot()
    local folder = plot and plot:FindFirstChild("Eggs")
    local eggs = {}
    if not folder then return eggs end
    for _, e in ipairs(folder:GetChildren()) do
        if e:GetAttribute("EggKey") and e:GetAttribute("OwnerUserId") == LP.UserId then
            eggs[#eggs + 1] = e
        end
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
    local tools = HA.Hatch.BackpackEggs()
    local nests = HA.Hatch.FreeNests()
    if #tools == 0 or #nests == 0 then return end
    local fastest = Options.FastestFirst
    table.sort(tools, function(a, b)
        local ia, ib = HA.Hatch.ToolInfo(a), HA.Hatch.ToolInfo(b)
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
        if not nest:GetAttribute("Occupied") then
            State.NestSkip[nest] = Clock() + Config.NestSkipFor
        end
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
    local now = Clock()
    if Options.AutoPlaceEggs and not HA:IsBusy()
        and #HA.Hatch.FreeNests() > 0 and #HA.Hatch.BackpackEggs() > 0 then
        HA:WithLock("place", 0, HA.Hatch.Place)
    end
    if Options.AutoHatch and now - State.LastHatch > Config.HatchGap then
        State.LastHatch = now
        local sweep = now - State.LastHatchAll > Config.HatchRetry
        if sweep then State.LastHatchAll = now end
        HA.Hatch.HatchNow(sweep)
    end
end

--================ Pet (Ranch) ================--
HA.Ranch = {}

function HA.Ranch.Score(inst)
    local info = Data.Pets[inst:GetAttribute("PetName") or ""]
    local income = type(info) == "table" and tonumber(info.Income) or 0
    local mult = 1
    for _, attr in ipairs({ "Mutation", "SpawnMutation" }) do
        local m = Data.Mutations[inst:GetAttribute(attr) or ""]
        if type(m) == "table" then mult *= 1 + (tonumber(m.StatMultiplier) or 0) / 100 end
    end
    return income * (inst:GetAttribute("Weight") or 1) * mult
end

function HA.Ranch.Ranked(list, asc)
    local ranked = table.create(#list)
    for i, inst in ipairs(list) do ranked[i] = { inst, HA.Ranch.Score(inst) } end
    table.sort(ranked, function(a, b) return asc and a[2] < b[2] or a[2] > b[2] end)
    return ranked
end

function HA.Ranch.Placed()
    local plot = HA:GetPlot()
    local folder = plot and plot:FindFirstChild("Pets")
    local list = {}
    if not folder then return list end
    for _, p in ipairs(folder:GetChildren()) do
        if p:GetAttribute("OwnerUserId") == LP.UserId and p:GetAttribute("PetKey") then list[#list + 1] = p end
    end
    return list
end

function HA.Ranch.Owned()
    local list = {}
    for _, holder in ipairs({ LP:FindFirstChild("Backpack"), HA.Player.Character }) do
        if not holder then continue end
        for _, t in ipairs(holder:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("PetKey") then list[#list + 1] = t end
        end
    end
    return list
end

function HA.Ranch.MaxSlots()
    local s = HA:Saved()
    return tonumber(s and s.MaxPets.Value) or Data.Rebirths.BasePetCapacity or 5
end

function HA.Ranch.RandomSpot()
    local plot = HA:GetPlot()
    local b = plot and plot:FindFirstChild("Baseplate")
    if not b then return nil end
    local half = b.Size * Config.PetSpread
    local off = V3((math.random() * 2 - 1) * half.X, b.Size.Y / 2 + Config.PetLift, (math.random() * 2 - 1) * half.Z)
    return (b.CFrame * CF(off)).Position
end

function HA.Ranch.PlaceBest()
    if Clock() < State.PetFailUntil then return false end
    local placed = HA.Ranch.Ranked(HA.Ranch.Placed(), true)
    local owned = HA.Ranch.Ranked(HA.Ranch.Owned(), false)
    local free = HA.Ranch.MaxSlots() - #placed
    local before = #placed
    local acted = false
    for _, pair in ipairs(owned) do
        local tool, score = pair[1], pair[2]
        local spot = HA.Ranch.RandomSpot()
        if not spot then return false end
        if free > 0 then
            HA.Net.PlacePet:FireServer(tool:GetAttribute("PetKey"), spot)
            free -= 1
            acted = true
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
    if acted and #HA.Ranch.Placed() < math.min(before + 1, HA.Ranch.MaxSlots()) and before < HA.Ranch.MaxSlots() then
        State.PetFailUntil = Clock() + Config.PetFailBackoff
    end
    return acted
end

function HA.Ranch.CollectNow()
    for _, p in ipairs(HA.Ranch.Placed()) do
        HA.Net.PetCollect:FireServer(p:GetAttribute("PetKey"))
    end
end

function HA.Ranch.FoodTool()
    local allowed = Options.FoodTypes
    local bp = LP:FindFirstChild("Backpack")
    for _, name in ipairs(HA.FoodNames) do
        if allowed and next(allowed) and not allowed[name] then continue end
        local t = (bp and bp:FindFirstChild(name)) or (HA.Player.Character and HA.Player.Character:FindFirstChild(name))
        if t then return t end
    end
end

function HA.Ranch.Feed()
    for _, pair in ipairs(HA.Ranch.Ranked(HA.Ranch.Placed(), false)) do
        local food = HA.Ranch.FoodTool()
        if not food or not HA.Player:IsAlive() then break end
        HA.Player.Humanoid:EquipTool(food)
        task.wait(Config.EquipSettle)
        HA.Net.FeedPet:FireServer(pair[1]:GetAttribute("PetKey"), food.Name, true)
        task.wait(Config.FeedGap)
    end
    if HA.Player.Humanoid then HA.Player.Humanoid:UnequipTools() end
end

function HA.Ranch.Step()
    local now = Clock()
    if Options.AutoEquipBest then HA:WithLock("ranch", 0, HA.Ranch.PlaceBest) end
    if Options.AutoCollectCash then HA.Ranch.CollectNow() end
    if Options.AutoFeed and now - State.LastFeed > Config.FeedGap * Config.FeedEvery then
        State.LastFeed = now
        HA:WithLock("feed", 0, HA.Ranch.Feed)
    end
end

--================ Progress ================--
HA.Progress = {}

function HA.Progress.RebirthCost()
    local lib = Data.Rebirths
    local nextRebirth = HA:RebirthCount() + 1
    if nextRebirth > (lib.Cap or math.huge) then return math.huge end
    if lib.RiggedCost and lib.RiggedCost[nextRebirth] then return lib.RiggedCost[nextRebirth] end
    local ok, cost = pcall(lib.GetCost, HA:RebirthCount())
    return ok and tonumber(cost) or math.huge
end

function HA.Progress.RebirthNow()
    if HA:RebirthCount() >= (Data.Rebirths.Cap or math.huge) then return end
    local before = HA:RebirthCount()
    HA.Net.Rebirth:FireServer()
    task.delay(3, function()
        if HA:RebirthCount() == before then
            State.RebirthBlockedUntil = Clock() + Config.RebirthBackoff
            HA:SetStatus("Rebirth rejected (need more pets?)")
        end
    end)
end

function HA.Progress.Step()
    local now = Clock()
    State.NextRebirthCost = HA.Progress.RebirthCost()
    if Options.AutoRebirth and now - State.LastRebirth > Config.RebirthGap
        and now > State.RebirthBlockedUntil and HA:Cash() >= State.NextRebirthCost then
        State.LastRebirth = now
        HA.Progress.RebirthNow()
    end
    if Options.AutoNests and now - State.LastNests > Config.NestsGap then
        State.LastNests = now
        local plot = HA:GetPlot()
        local nests = plot and plot:FindFirstChild("Nests")
        if nests then
            local prices = Data.Nests.Prices or {}
            for _, n in ipairs(nests:GetChildren()) do
                local idx = tonumber(n.Name)
                if n:GetAttribute("Unlocked") or not idx then continue end
                if HA:Cash() < (prices[idx] or math.huge) then continue end
                HA.Net.Nests:FireServer(idx)
                task.wait(Config.PlaceGap)
            end
        end
    end
    if Options.AutoUpgrade and now - State.LastUpgrade > Config.UpgradeGap then
        -- Save For Rebirth: hold upgrades while cash is reserved for rebirth
        local saving = Options.SaveForRebirth and State.NextRebirthCost < math.huge
            and HA:Cash() < State.NextRebirthCost * Config.RebirthReserve
        if not saving then
            State.LastUpgrade = now
            HA.Net.Upgrades:FireServer("Max")
        end
    end
    if Options.AutoClaim and now - State.LastClaim > Config.ClaimGap then
        State.LastClaim = now
        HA.Net.ClaimIndexReward:FireServer()
        HA.Net.OfflineEarnings:FireServer()
    end
end

--================ Egg Radar (server hop) ================--
HA.Server = {}

function HA.Server.Hop()
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
    local open = {}
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(body) end)
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

function HA.Server.RadarHop()
    State.Hopping = true
    local hops = State.HuntHops + 1
    if hops > Config.HuntMaxHops then
        State.HuntHops = 0
        Options.EggHunter = false
        if HA.UIRef then HA.UIRef:SetToggle("EggHunter", false) end
        UI.Notify("Egg Radar", ("No match after %d servers, radar turned off"):format(Config.HuntMaxHops))
        return
    end
    local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if queue and Options.EggHunter then
        queue(string.format("getgenv().HAHunt = { Hops = %d, Rarity = %q } ", hops, Options.HuntMinRarity or "Mythic")
            .. 'loadstring(game:HttpGet("' .. BASE .. 'Loader.lua"))()')
    end
    task.delay(Config.HopReset, function()
        State.Hopping = false
        State.EmptySince = Clock()
    end)
    pcall(HA.Server.Hop)
end

--================ Places ================--
HA.Places = {}

function HA.Places.List()
    local places = { ["Home (Plot)"] = function() return HA:HomeCFrame() end }
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

function HA.Places.Names()
    local n = {}
    for name in pairs(HA.Places.List()) do n[#n + 1] = name end
    table.sort(n)
    return n
end

--================ Egg ESP ================--
HA.Esp = {}

function HA.Esp.Clear()
    for k, e in pairs(State.EspBoards) do
        e.Board:Destroy()
        State.EspBoards[k] = nil
    end
end

function HA.Esp.Refresh()
    if not Options.EggEsp then
        if next(State.EspBoards) then HA.Esp.Clear() end
        return
    end
    local rendered = Workspace:FindFirstChild("RenderedEggs")
    if not rendered then return end
    local root = HA.Player.Root
    local minRank = HA.RarityRank[Options.EspMinRarity or ""] or 1
    local seen = {}
    for _, model in ipairs(rendered:GetChildren()) do
        local info = HA.Info[model.Name]
        if not info or (HA.RarityRank[info.Rarity] or 1) < minRank then continue end
        local entry = State.EspBoards[model]
        if not entry or not entry.Board.Parent then
            local part = model:IsA("BasePart") and model or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if not part then continue end
            local board = Instance.new("BillboardGui")
            board.Name = "HA_EggEsp"
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
        entry.Label.Text = ("%s [%s]\n1 in %s | %dm"):format(model.Name, info.Rarity, HA.FormatNumber(info.Luck), dist)
    end
    for k, e in pairs(State.EspBoards) do
        if not seen[k] then e.Board:Destroy() State.EspBoards[k] = nil end
    end
end

--================ UI (RIDE A PET scope only) ================--
function HA.BuildUI()
    local W = UI.Create({
        Title = "HUMANANOMALY",
        Sub = "Ride A Pet",
        Discord = Config.Discord,
        Folder = "HumanAnomaly/RideAPet",
    })
    HA.UIRef = W

    local home = W:Tab("Auto")
    home:Section("Automation")
    home:Toggle("Autopilot", "Autopilot", "Enable all automation at once", false, function(on)
        for _, k in ipairs({ "AutoEggs", "SwapSmarter", "AutoPlaceEggs", "AutoHatch", "AutoEquipBest", "AutoCollectCash", "AutoFeed", "AutoUpgrade", "SaveForRebirth", "AutoRebirth", "AutoNests", "AutoClaim" }) do
            Options[k] = on
            W:SetToggle(k, on)
        end
    end)
    home:Toggle("SaveForRebirth", "Save For Rebirth", "Hold upgrades while saving for rebirth", false, function(v) Options.SaveForRebirth = v end)
    home:Button("PANIC - Turn Everything Off", function() W:FirePanic() end, "danger")
    W:OnPanic(function()
        for k in pairs(Options) do Options[k] = false end
    end)
    home:Section("Status")
    home:KV("STATUS", function()
        local saving = (Options.SaveForRebirth and State.NextRebirthCost < math.huge) and " (saving)" or ""
        return State.Status .. saving
    end)
    home:KV("CASH", function() return HA.FormatNumber(HA:Cash()) end)
    home:KV("REBIRTH", function() return tostring(HA:RebirthCount()) end)
    home:KV("EGGS", function() return State.EggsCollected .. " collected | " .. #HA.Eggs.OnMap() .. " on map" end)
    home:Note("Player features (fly, speed, ESP, anti-AFK, troll, server hop) are under MOVEMENT / VISUAL / SERVER / PLAYERS in the Universal scope.")

    local eggs = W:Tab("Eggs")
    eggs:Section("Collect")
    eggs:Toggle("AutoEggs", "Auto Collect", "Pick filtered eggs, deliver to home", false, function(v) Options.AutoEggs = v end)
    eggs:Toggle("SwapSmarter", "Swap Smarter", "When full: only pick better eggs", false, function(v) Options.SwapSmarter = v end)
    eggs:Toggle("ReturnAfter", "Return To Spot", "Teleport back when finished", false, function(v) Options.ReturnAfter = v end)
    eggs:Slider("MinLuck", "Min luck (1 in X)", 0, 1000000, 0, function(v) Options.MinLuck = v end)
    eggs:Button("Grab Best Egg", function()
        local e = HA.Eggs.OnMap()[1]
        if e then HA:MoveTo(CF(e:GetAttribute("Position") + V3(0, Config.EggHover, 0))) end
    end)
    eggs:Section("Egg Radar")
    eggs:Toggle("EggHunter", "Egg Radar", "Focus high rarity, auto-hop servers", false, function(v) Options.EggHunter = v end)
    eggs:Dropdown("HuntMinRarity", "Min rarity", HA.Rarities, "Mythic", function(v) Options.HuntMinRarity = v end)
    eggs:Label(function() return ("Radar: server %d/%d"):format(State.HuntHops, Config.HuntMaxHops) end)

    local nest = W:Tab("Nests")
    nest:Section("Hatching")
    nest:Toggle("AutoPlaceEggs", "Auto Place", "Place best eggs into empty nests", false, function(v) Options.AutoPlaceEggs = v end)
    nest:Toggle("FastestFirst", "Fastest First", "Off = highest luck first", false, function(v) Options.FastestFirst = v end)
    nest:Toggle("AutoHatch", "Auto Hatch", "Hatch from anywhere when ready", false, function(v) Options.AutoHatch = v end)
    nest:Button("Place Eggs Now", function() HA:WithLock("place", Config.LockWait, HA.Hatch.Place) end)
    nest:Button("Hatch Now", function() HA.Hatch.HatchNow(true) end)
    nest:Section("Nests")
    nest:Toggle("AutoNests", "Auto Buy Nests", "Unlock new nests when affordable", false, function(v) Options.AutoNests = v end)

    local ranch = W:Tab("Ranch")
    ranch:Section("Ranch")
    ranch:Toggle("AutoEquipBest", "Auto Ranch", "Keep ranch filled with best earners", false, function(v) Options.AutoEquipBest = v end)
    ranch:Toggle("AutoCollectCash", "Auto Cash", "Collect pet cash from anywhere", false, function(v) Options.AutoCollectCash = v end)
    ranch:Button("Place Best Now", function() HA:WithLock("ranch", Config.LockWait, HA.Ranch.PlaceBest) end)
    ranch:Button("Collect Cash Now", function() HA.Ranch.CollectNow() end)
    ranch:Section("Feeding")
    ranch:Toggle("AutoFeed", "Auto Feed", "Feed best pets first", false, function(v) Options.AutoFeed = v end)

    local prog = W:Tab("Progress")
    prog:Section("Progress")
    prog:Toggle("AutoUpgrade", "Auto Upgrade", "Buy every affordable luck upgrade", false, function(v) Options.AutoUpgrade = v end)
    prog:Toggle("AutoRebirth", "Auto Rebirth", "Rebirth when cash and pets allow", false, function(v) Options.AutoRebirth = v end)
    prog:Toggle("AutoClaim", "Auto Claim", "Index and offline rewards", false, function(v) Options.AutoClaim = v end)
    prog:Button("Upgrade Max", function() HA.Net.Upgrades:FireServer("Max") end)
    prog:Button("Rebirth Now", function() HA.Progress.RebirthNow() end)
    prog:Button("Claim Now", function() HA.Net.ClaimIndexReward:FireServer() HA.Net.OfflineEarnings:FireServer() end)

    local places = W:Tab("Places")
    places:Section("Teleport")
    places:Dropdown("TPPlace", "Destination", HA.Places.Names(), HA.Places.Names()[1], function(v) Options.TPPlace = v end)
    places:Button("Teleport", function()
        local target = HA.Places.List()[Options.TPPlace or ""]
        if target then HA:MoveTo(target()) end
    end, "accent")
end

--================ Boot ================--
function HA:Boot()
    if LP.Character then self.Player:Bind(LP.Character) end
    self:Connect(LP.CharacterAdded, function(ch) self.Player:Bind(ch) end)

    task.spawn(function()
        while State.Alive do
            pcall(HA.Eggs.Step)
            task.wait(Config.EggTick)
        end
    end)
    task.spawn(function()
        while State.Alive do
            pcall(HA.Hatch.Step)
            pcall(HA.Ranch.Step)
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
        for _, c in ipairs(State.Connections) do c:Disconnect() end
        table.clear(State.Connections)
        if HA.UIRef then
            -- Remove game tabs only; keep the window for Universal
            for _, key in ipairs({ "Auto", "Eggs", "Nests", "Ranch", "Progress", "Places" }) do
                HA.UIRef:RemoveTab(key)
            end
            if not next(HA.UIRef.Tabs) then
                HA.UIRef:Destroy()
                getgenv().HA_UI = nil
            end
        end
    end

    HA.BuildUI()
    UI.Show()
    HA.UIRef:SetStatus("READY", true)
    UI.Notify("HumanAnomaly", "Ride A Pet ready. LeftCtrl / HA button.")

    -- Resume Egg Radar after server hop
    local hunt = getgenv().HAHunt
    getgenv().HAHunt = nil
    if type(hunt) == "table" then
        State.HuntHops = tonumber(hunt.Hops) or 0
        Options.HuntMinRarity = hunt.Rarity
        Options.EggHunter = true
        Options.AutoPlaceEggs = true
        Options.AutoHatch = true
        HA.UIRef:SetToggle("EggHunter", true)
        UI.Notify("Egg Radar", ("Target %s+ (server %d/%d)"):format(tostring(hunt.Rarity), State.HuntHops, Config.HuntMaxHops))
    end
end

HA:Boot()
return HA
