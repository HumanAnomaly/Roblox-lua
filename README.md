# Roblox-lua

Roblox script collection by HumanAnomaly.

## Loader

Satu loadstring untuk semua game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/Loader.lua"))()
```

Yang terjadi saat dieksekusi:

1. UI library (`Lib/ha-ui.lua`) didownload sekali dan dibagikan lewat `getgenv().HA_UI_SRC`
2. **Universal** selalu jalan di semua game (movement, visual, ESP, server, troll)
3. Script khusus game jalan kalau `GameId` terdaftar, mis. Ride A Pet

## Structure

```
Loader.lua            <- entry: lib -> universal -> game
Games/
  universal.lua       <- SEMUA game, selalu dimuat
  ride-a-pet.lua      <- Ride A Pet (otomasi game)
Lib/
  ha-ui.lua           <- HumanAnomaly UI v2
test-local.lua        <- test tanpa GitHub (path lokal)
```

## Add Game

1. Create `Games/game-name.lua` (otomasi game saja; fitur pemain umum sudah ada di universal)
2. Register GameId in `Loader.lua`:

```lua
[10035204815] = "ride-a-pet",
```

3. Push. Loader picks it up automatically.

## Local Test

```lua
-- test-local.lua
getgenv().HA_UI_SRC = readfile("Lib/ha-ui.lua")
loadstring(readfile("Games/universal.lua"))()
loadstring(readfile("Games/ride-a-pet.lua"))()
```

## Unload

- `HAUnload()` - copot script game
- `HAUnloadUniversal()` - copot universal

## Discord

https://discord.gg/NGBgETjmv3
