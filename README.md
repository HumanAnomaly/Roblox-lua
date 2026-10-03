# Roblox-lua

Roblox script collection by HumanAnomaly.

## Loader

One loadstring for every game:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HumanAnomaly/Roblox-lua/main/Loader.lua"))()
```

What happens on execute:

1. UI library (`Lib/ha-ui.lua`) is downloaded once and shared via `getgenv().HA_UI_SRC` (single window)
2. **Universal always runs on every map** (movement, visual, ESP, server, troll) — isolated `UNIVERSAL` scope
3. Game scripts run only when the `GameId` is registered, e.g. Ride A Pet — isolated game scope, never mixed with Universal

## UI (v4.0, English-only)

- Header: logo + title/subtitle, status pill, HIDE
- Sidebar: SCOPE switch (`UNIVERSAL` / game name) + tab list with active indicator
- Content: tidy sections, cards, compact info rows
- Footer: version + `LeftCtrl` hint
- Works on desktop and mobile (drawer menu)

## Structure

```
Loader.lua            <- entry: lib -> universal -> game
Games/
  universal.lua       <- EVERY map, always loaded (UNIVERSAL scope only)
  ride-a-pet.lua      <- Ride A Pet (game automation only)
Lib/
  ha-ui.lua           <- HumanAnomaly UI v4.0 (tidy, English-only, isolated scopes)
test-local.lua        <- local test without GitHub
```

## Add Game

1. Create `Games/game-name.lua` (game automation only; player features already exist in Universal)
2. Register the GameId in `Loader.lua`:

```lua
[10035204815] = "ride-a-pet",
```

3. In your script use your own scope, never `Universal`:

```lua
local W = UI.Create({ Title = "HUMANANOMALY", Sub = "Your Game Name" })
```

4. Push. The Loader picks it up automatically.

## Scope Rules (do not mix)

- `universal.lua`: `Sub = "Universal"` only. No game remotes, no game automation.
- `Games/<game>.lua`: `Sub = "<Game Name>"` only. Guard with `if game.GameId ~= ... then return end`.
- Toggle/Dropdown keys must be unique across scopes.
- Unload removes only its own tabs (`HAUnloadUniversal` / `HAUnload`).

## Local Test

```lua
-- test-local.lua
getgenv().HA_UI_SRC = readfile("Lib/ha-ui.lua")
loadstring(readfile("Games/universal.lua"))()
loadstring(readfile("Games/ride-a-pet.lua"))()
```

## Unload

- `HAUnload()` - remove the game script tabs
- `HAUnloadUniversal()` - remove the Universal tabs

## Discord

https://discord.gg/NGBgETjmv3
