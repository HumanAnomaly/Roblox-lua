# Roblox-lua

Roblox script collection by HumanAnomaly.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/Loader.lua"))()
```

## Structure

```
Loader.lua            <- entry, routes per GameId
Games/
  ride-a-pet.lua      <- Ride A Pet
  universal.lua       <- fallback
Lib/
  ha-ui.lua           <- HumanAnomaly UI
test-local.lua        <- local test (no GitHub needed)
```

## Add Game

1. Create `Games/game-name.lua`
2. Register GameId in `Loader.lua`:

```lua
[10035204815] = "ride-a-pet",
```

3. Push. Loader picks it up automatically.

## Local Test

```lua
getgenv().HA_UI_SRC = readfile("Lib/ha-ui.lua")
loadstring(readfile("Games/ride-a-pet.lua"))()
```

## Discord

https://discord.gg/NGBgETjmv3
