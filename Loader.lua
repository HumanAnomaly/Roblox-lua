if not game:IsLoaded() then game.Loaded:Wait() end

local BASE = "https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/Games/"
local LIB = "https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/Lib/ha-ui.lua"

local GAMES = {
    [10035204815] = "ride-a-pet",
}

local function notify(title, text)
    pcall(game.GetService(game, "StarterGui").SetCore, game:GetService("StarterGui"), "SendNotification", {
        Title = title, Text = text, Duration = 8,
    })
end

local function get(url)
    local ok, body = pcall(game.HttpGet, game, url)
    if not ok or type(body) ~= "string" or #body < 50 then
        return nil, "download returned empty"
    end
    if body:sub(1, 1) == "<" then
        return nil, "404 not found: file not pushed to GitHub yet, or branch is not main, or repo is private"
    end
    return body, nil
end

local libSrc, libErr = get(LIB)
if not libSrc then
    notify("HumanAnomaly", "UI lib missing. " .. tostring(libErr) .. " | " .. LIB)
    return
end

local name = GAMES[game.GameId]
if not name then
    notify("HumanAnomaly", "Game not supported (GameId " .. tostring(game.GameId) .. "). Discord: https://discord.gg/NGBgETjmv3")
    local uni, uniErr = get(BASE .. "universal.lua")
    if uni then
        local fn = loadstring(uni)
        if fn then fn() end
    else
        notify("HumanAnomaly", "Fallback failed. " .. tostring(uniErr))
    end
    return
end

local url = BASE .. name .. ".lua"
local src, err = get(url)
if not src then
    notify("HumanAnomaly", tostring(err) .. " | " .. url)
    return
end

local fn, loadErr = loadstring(src)
if not fn then
    notify("HumanAnomaly", "Syntax error in " .. name .. ".lua: " .. tostring(loadErr))
    return
end

local ok, runErr = pcall(fn)
if not ok then
    notify("HumanAnomaly", "Runtime error: " .. tostring(runErr))
end
