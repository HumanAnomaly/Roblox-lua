-- Test lokal tanpa GitHub. WAJIB dieksekusi dari dalam game Ride A Pet.
local ROOT = "C:/HumanAnomaly/WorkscpaceTEMP/asasa/"

if not readfile then
    error("Executor ini tidak support readfile - push ke GitHub atau copy file ke workspace executor.")
end

local function readLocal(rel)
    local ok, body = pcall(readfile, ROOT .. rel)
    if ok and type(body) == "string" then return body end
    return readfile(rel) -- fallback: kalau file dicopy ke workspace executor
end

getgenv().HA_UI_SRC = readLocal("Lib/ha-ui.lua")
loadstring(readLocal("Games/ride-a-pet.lua"))()
