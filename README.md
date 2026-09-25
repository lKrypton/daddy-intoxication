# Daddy Intoxication

![Daddy Intoxication](https://raw.githubusercontent.com/lKrypton/daddy-intoxication/main/.github/banner.jpg)

A free, server-authoritative intoxication system for FiveM. Players feel the alcohol through gameplay — visuals, movement, driving, voice, nausea and blackouts — with no UI. Other resources can read the state through state bags, exports and events.

## Features

- 0–100 alcohol points with five stages and hysteresis (no flickering near thresholds)
- Drink profiles (beer, wine, cocktail, shot, heavy) that change visuals, sway, nausea, blackout risk and how long the effects last
- Smooth fading between stages and profiles
- Drunk walking clipsets, stumbling and falling
- Drunk driving with four modes (subtle sway by default)
- Hiccups, groans, heartbeat, tinnitus
- Nausea with an optional ox_lib skill check, vomiting with animation and particles
- Blackouts at extreme intoxication
- Optional per-character tolerance
- BAC value for police and HUD resources
- Muffled voice for other players through pma-voice (radio and phone effects stay intact)
- Persistence across reconnects, with offline metabolism
- Qbox, QBCore, ESX and standalone; ox_inventory, qb-inventory and ESX usable items
- Nausea, vomiting, blackouts and death resets are decided by the server; the client cannot change alcohol

## Requirements

- OneSync
- [ox_lib](https://github.com/overextended/ox_lib)

Optional:
- Qbox, QBCore or ESX
- ox_inventory or qb-inventory
- pma-voice

## Installation

1. Put `daddy-intoxication` in your resources folder.
2. Start it **after** ox_lib, your framework, your inventory and pma-voice:
   ```
   ensure ox_lib
   ensure qbx_core        # or qb-core / es_extended
   ensure ox_inventory    # if used
   ensure pma-voice       # if used
   ensure daddy-intoxication
   ```
3. Make sure the drink and recovery items in `config.lua` exist in your inventory and are usable (see below).

## Framework configuration

```lua
Config.Framework = 'auto' -- 'qbox', 'qbcore', 'esx' or 'standalone'
```

`auto` checks `qbx_core`, `qb-core` and `es_extended` in that order. Standalone uses the player's license as identifier.

## Inventory configuration

```lua
Config.Inventory = 'auto' -- 'ox_inventory', 'framework' or 'none'
```

- **ox_inventory**: the resource listens to `ox_inventory:usedItem`. The item must be usable and consumed by ox_inventory, e.g.:
  ```lua
  ['whiskey'] = {
      label = 'Whiskey',
      weight = 500,
      consume = 1,
      client = { anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' }, prop = { model = `prop_whiskey_bottle`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, 0.0, -1.5) }, usetime = 2500 },
  },
  ```
- **framework** (qb-inventory, ESX): the items are registered as usable items `Config.UsableItemDelay` ms after start, and one item is removed on use. Items another resource already made usable are handled like this:
  - **QBCore** (e.g. `beer`, `vodka`, `whiskey` from qb-smallresources): the existing callback still runs (thirst, animation, item removal) and the alcohol is added after it. Start your consumables script before `daddy-intoxication`.
  - **ESX** (e.g. `beer`, `wine`, `vodka`, `tequila` from esx_optionalneeds, `water` from esx_basicneeds): ESX does not allow chaining, so the item is left to the other resource and listed in the server console. Call `ConsumeItem` (below) from that resource's use callback, or rename the items in `config.lua`.
- **none**: no item hooks. Use the server exports.

Integrating without the inventory bridge:

```lua
-- Full drink logic: profile, tolerance, notifications
exports['daddy-intoxication']:ConsumeItem(source, 'whiskey')

-- Raw alcohol points
exports['daddy-intoxication']:AddPlayerAlcohol(source, 15, 'shot')
```

## Voice configuration

```lua
Config.Voice.Enabled = true
Config.Voice.Resource = 'pma-voice'
```

Every client registers the drunk submixes when the resource or pma-voice starts. When a player reaches stage 2, the server sets that player's `submix` state bag and pma-voice applies the filter for everyone who hears them. The drunk player hears everyone else normally. Radio and phone calls keep their own effects, and a submix set by another resource is never replaced or cleared. If pma-voice is not running, voice effects are skipped.

## Adding drinks

```lua
Config.Drinks = {
    beer = { alcohol = 6, profile = 'beer' },
    my_custom_drink = { alcohol = 18, profile = 'cocktail' },
}
```

`alcohol` is the number of points gained (before tolerance and the profile multiplier). `profile` is a key of `Config.Profiles`.

## Adding recovery items

```lua
Config.RecoveryItems = {
    water  = { reduction = 8 },
    coffee = { reduction = 5, metabolism = { multiplier = 1.5, duration = 300 } },
    milk   = { reduction = 6, nausea = 120 },
}
```

- `reduction`: points removed immediately
- `metabolism`: temporarily faster metabolism (`duration` in seconds)
- `nausea`: seconds added before the next nausea wave

These are gameplay mechanics, not realistic sobering.

## Drink profiles

Each profile in `Config.Profiles` controls:

| Key | Effect |
|---|---|
| `alcoholMultiplier` | Scales alcohol gained from drinks with this profile |
| `metabolismMultiplier` | Below 1 lasts longer, above 1 wears off faster |
| `nausea` | Nausea tendency (how often waves come) |
| `blackout` | Blackout tendency (scales the blackout chance) |
| `timecycle`, `strength` | Screen filter and its strength per stage |
| `shake` | Camera sway per stage |
| `postfx` | Extra screen effects per stage |
| `clipset` | Walking style per stage |
| `burp`, `tinnitus` | Audio cues right after drinking |

Stage tables are indexed 1–4. A missing stage uses the closest lower value.

## Stages

| Stage | Default points | Effects |
|---|---|---|
| 0 | 0–19 | None |
| 1 | 20–39 | Light filter and sway, hiccups |
| 2 | 40–69 | Drunk walk, motion blur, muffled voice, driving sway |
| 3 | 70–89 | Heavy walk, falls, horn, nausea from 75, heartbeat from 80 |
| 4 | 90–100 | Blackout risk |

Change the thresholds in `Config.Stages.Thresholds`. A stage is kept until the points drop `Config.Stages.Hysteresis` below its threshold.

## Tolerance

```lua
Config.Tolerance.Enabled = true
```

- 0–100 per character, stored separately from alcohol (`Config.Tolerance.Persist`)
- Reduces alcohol gained from drinks by up to `MaxReduction` (default 30%) and speeds up metabolism slightly
- Grows only while the player is drunk, at most once per `GainCooldown`, and slower the higher it is
- Decreases after `DecayAfter` seconds without drinking

When disabled, tolerance exports return 0 and no tolerance state bag is set.

## BAC

BAC is a gameplay value for police and HUD resources, not a medical calculation. By default it is linear: 100 points = `Config.BAC.Max` (0.30). You can provide your own mapping:

```lua
Config.BAC.Convert = function(points) return points / 100 * 0.25 end
```

## Breathalyzer integration

```lua
local bac = exports['daddy-intoxication']:GetPlayerBAC(targetId)
if bac >= 0.08 then
    -- over the limit
end
```

A complete example command is in `examples/breathalyzer.lua` (not loaded by the resource).

## State bags

Set by the server on each player (`Player(src).state` / `LocalPlayer.state`):

| Key | Type | Description |
|---|---|---|
| `alcohol` | integer | Alcohol points 0–100 |
| `alcoholStage` | integer | Stage 0–4 |
| `alcoholType` | string or nil | Active drink profile |
| `intoxicated` | boolean | Stage ≥ `Config.Stages.IntoxicatedFrom` |
| `bac` | number | BAC value |
| `alcoholTolerance` | integer | Only when tolerance is enabled |
| `submix` | string or nil | Written for pma-voice while drunk (only if no other submix is set) |

## Client exports

Client exports are read-only. Alcohol can only be changed on the server.

| Export | Returns |
|---|---|
| `GetAlcohol()` | Alcohol points (integer) |
| `GetAlcoholStage()` | Stage 0–4 |
| `GetAlcoholProfile()` | Active drink profile or `nil` |
| `GetBAC()` | BAC value |
| `GetTolerance()` | Tolerance 0–100 (0 when disabled) |
| `IsIntoxicated()` | boolean |
| `GetIntoxication()` | `{ alcohol, stage, profile, bac, intoxicated, tolerance }` |
| `SetActionsBlocked(key, blocked)` | Blocks vomiting, blackouts, nausea and falls while your resource plays its own animation. Cleared automatically when your resource stops. |
| `PlayVomit()` | Plays the vomit sequence only (e.g. food poisoning). Does not change alcohol. |

```lua
local data = exports['daddy-intoxication']:GetIntoxication()
if data.stage >= 2 then
    -- player is drunk
end

exports['daddy-intoxication']:SetActionsBlocked('sitting', true)
```

## Server exports

| Export | Returns |
|---|---|
| `GetPlayerAlcohol(source)` | Alcohol points (integer) |
| `GetPlayerAlcoholStage(source)` | Stage 0–4 |
| `GetPlayerAlcoholProfile(source)` | Active drink profile or `nil` |
| `GetPlayerBAC(source)` | BAC value |
| `GetPlayerTolerance(source)` | Tolerance 0–100 (0 when disabled) |
| `IsPlayerIntoxicated(source)` | boolean |
| `GetPlayerIntoxication(source)` | `{ alcohol, stage, profile, bac, intoxicated, tolerance }` |
| `SetPlayerAlcohol(source, amount, profile?)` | New alcohol value |
| `AddPlayerAlcohol(source, amount, profile?)` | New alcohol value (raw points, no tolerance) |
| `ReducePlayerAlcohol(source, amount)` | New alcohol value |
| `ResetPlayerAlcohol(source)` | `true` |
| `SetPlayerTolerance(source, amount)` | New tolerance (only when tolerance is enabled) |
| `ConsumeItem(source, itemName)` | `true` if the item is a configured drink or recovery item. Runs the full logic: profile, tolerance, notifications. |

Setters return `false` for an invalid player or invalid arguments. `profile` must be a key of `Config.Profiles`; otherwise the current profile is kept.

```lua
local data = exports['daddy-intoxication']:GetPlayerIntoxication(source)
print(data.alcohol, data.stage, data.bac)
```

## Events

Client (local events):

```lua
AddEventHandler('daddy-intoxication:client:alcoholChanged', function(alcohol, stage, profile, bac) end)
AddEventHandler('daddy-intoxication:client:stageChanged', function(newStage, oldStage) end)
AddEventHandler('daddy-intoxication:client:movementRestored', function() end) -- reapply custom walk styles here
```

Server (local events):

```lua
AddEventHandler('daddy-intoxication:server:alcoholChanged', function(source, alcohol, stage, profile, reason) end)
AddEventHandler('daddy-intoxication:server:stageChanged', function(source, newStage, oldStage) end)
```

## Death and revive

With `Config.ResetOnDeath = true`, the client reports a death and the server checks it (ped health, `isDead` / `inLastStand` state bags, Qbox/QBCore metadata) before clearing the alcohol. Clients cannot reset themselves. Medical resources can also reset intoxication directly:

```lua
exports['daddy-intoxication']:ResetPlayerAlcohol(source)
```

## Persistence

```lua
Config.Persistence.Enabled = true
Config.Persistence.OfflineMetabolism = true
```

Alcohol and tolerance are stored per character in resource KVP (no database). On reconnect the time spent offline is metabolised. The saved entry is removed when alcohol and tolerance are both 0. Character switching is handled through the framework's unload events.

## Compatibility

- **Animations:** vomiting, nausea reactions, blackouts and falls are skipped or postponed while the player is dead, in last stand, cuffed, carried, carrying someone, swimming, falling, climbing, parachuting or in a scenario. Add your own state bag keys to `Config.BlockingStates`, use `Config.IsActionBlocked`, or the `SetActionsBlocked` export.
- **Walk styles:** when intoxication ends the movement clipset is reset and `movementRestored` fires. Use `Config.Movement.OnRestore` or the event to reapply a custom walk style, and `Config.Movement.CanApply` to skip drunk clipsets.
- **Timecycle:** GTA has one timecycle modifier slot. The resource only fades or clears a modifier it set itself, and never replaces one another resource is showing (for example the grey screen of a death screen). Its own filter comes back with the next update.
- **Driving:** `inverted` mode is available but not recommended for most servers.

## Localization

```lua
Config.Locale = 'en' -- or 'tr'
```

Add a language by copying `locales/en.lua`, changing `Locales.en` to your code and adding the file to `fxmanifest.lua`.

## Admin command and debug mode

```lua
Config.AdminCommand = true
Config.Debug = false
Config.DebugPermission = 'group.admin'
```

- `/setalcohol [id] [amount] [profile?]` is available to the ACE principal while `Config.AdminCommand` is on.
- `Config.Debug = true` adds debug output and the test commands `/testnausea [id?]`, `/testvomit [id?]` (animation only) and `/testblackout [id?]`.

With both off, no commands are registered and nothing is printed.

## Performance

- Sober players cost almost nothing: every client loop sleeps 2–5 seconds.
- Frame-level logic only runs while the player is intoxicated, driving and moving.
- Visual fades run a short thread only while a transition is in progress.
- The server loop only processes players with alcohol, a pending nausea wave or a blackout.

## License

Free to use and modify on your own servers. Reselling, redistributing or re-uploading this resource (modified or not) is not allowed. See `LICENSE` for the full terms.
