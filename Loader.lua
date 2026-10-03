--========================================================--
--  HumanAnomaly Loader v3
--  1. UI library is downloaded once and shared via getgenv
--  2. UNIVERSAL always runs on every map (movement, visual,
--     ESP, server, troll) — isolated UNIVERSAL scope
--  3. Game scripts run only on their GameId — isolated game
--     scope (e.g. RIDE A PET). Scopes are never mixed.
--========================================================--

if not game:IsLoaded() then game.Loaded:Wait() end

local BASE = "https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/"
local LIB = BASE .. "Lib/ha-ui.lua"

local GAMES = {
    [10035204815] = "ride-a-pet",
}

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = 8,
        })
    end)
end

local function get(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" or #body < 50 then
        return nil, "empty/failed download"
    end
    if body:sub(1, 1) == "<" then
        return nil, "404: file not pushed yet / wrong branch / private repo"
    end
    return body, nil
end

local function run(src, label)
    local fn, loadErr = loadstring(src)
    if not fn then
        notify("HumanAnomaly", "Syntax error in " .. label .. ": " .. tostring(loadErr))
        return false
    end
    local ok, runErr = pcall(fn)
    if not ok then
        notify("HumanAnomaly", "Runtime error " .. label .. ": " .. tostring(runErr))
        return false
    end
    return true
end

print("[HumanAnomaly] loader v3 | GameId:", game.GameId, "| PlaceId:", game.PlaceId)

-- 1. UI library: download once, share via getgenv (single window)
if not getgenv().HA_UI_SRC then
    local libSrc, libErr = get(LIB)
    if not libSrc then
        notify("HumanAnomaly", "UI library failed. " .. tostring(libErr) .. " | " .. LIB)
        return
    end
    getgenv().HA_UI_SRC = libSrc
end

-- 2. Universal: always runs, on every map (UNIVERSAL scope)
local uniSrc, uniErr = get(BASE .. "Games/universal.lua")
if uniSrc then
    run(uniSrc, "universal.lua")
else
    notify("HumanAnomaly", "Universal failed: " .. tostring(uniErr))
end

-- 3. Game script only when supported (separate scope, never mixed)
local name = GAMES[game.GameId]
if not name then
    notify("HumanAnomaly", "This map is not supported yet — Universal stays active. (GameId " .. tostring(game.GameId) .. ")")
    return
end

local src, err = get(BASE .. "Games/" .. name .. ".lua")
if not src then
    notify("HumanAnomaly", tostring(err) .. " | " .. name .. ".lua")
    return
end
run(src, name .. ".lua")
