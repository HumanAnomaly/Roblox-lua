-- Local test without GitHub (same order as Loader):
-- universal first, then the game script. MUST run inside Ride A Pet.
local ROOT = "C:/HumanAnomaly/WorkscpaceTEMP/asasa/"

if not readfile then
    error("This executor does not support readfile - push to GitHub or copy the files to the executor workspace.")
end

local function readLocal(rel)
    local ok, body = pcall(readfile, ROOT .. rel)
    if ok and type(body) == "string" then return body end
    return readfile(rel) -- fallback: files copied to the executor workspace
end

getgenv().HA_UI_SRC = readLocal("Lib/ha-ui.lua")
loadstring(readLocal("Games/universal.lua"))()
loadstring(readLocal("Games/ride-a-pet.lua"))()
