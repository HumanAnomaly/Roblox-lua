--========================================================--
--  HumanAnomaly Loader
--  1. UI library didownload sekali, dibagikan ke semua script
--  2. UNIVERSAL selalu jalan di semua game
--  3. Script khusus game jalan kalau GameId terdaftar
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
        return nil, "download kosong/gagal"
    end
    if body:sub(1, 1) == "<" then
        return nil, "404: file belum di-push / branch bukan main / repo private"
    end
    return body, nil
end

local function run(src, label)
    local fn, loadErr = loadstring(src)
    if not fn then
        notify("HumanAnomaly", "Syntax error di " .. label .. ": " .. tostring(loadErr))
        return false
    end
    local ok, runErr = pcall(fn)
    if not ok then
        notify("HumanAnomaly", "Runtime error " .. label .. ": " .. tostring(runErr))
        return false
    end
    return true
end

print("[HumanAnomaly] loader v2 | GameId:", game.GameId, "| PlaceId:", game.PlaceId)

-- 1. UI library: download sekali, share lewat getgenv
if not getgenv().HA_UI_SRC then
    local libSrc, libErr = get(LIB)
    if not libSrc then
        notify("HumanAnomaly", "UI lib gagal. " .. tostring(libErr) .. " | " .. LIB)
        return
    end
    getgenv().HA_UI_SRC = libSrc
end

-- 2. Universal: selalu jalan, di semua game
local uniSrc, uniErr = get(BASE .. "Games/universal.lua")
if uniSrc then
    run(uniSrc, "universal.lua")
else
    notify("HumanAnomaly", "Universal gagal: " .. tostring(uniErr))
end

-- 3. Script khusus game kalau didukung
local name = GAMES[game.GameId]
if not name then
    notify("HumanAnomaly", "Game ini belum didukung - Universal tetap aktif. (GameId " .. tostring(game.GameId) .. ")")
    return
end

local src, err = get(BASE .. "Games/" .. name .. ".lua")
if not src then
    notify("HumanAnomaly", tostring(err) .. " | " .. name .. ".lua")
    return
end
run(src, name .. ".lua")
