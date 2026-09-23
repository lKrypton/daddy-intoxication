# Changelog

## 1.0.0

Initial release.

- Server-authoritative alcohol points (0–100) with five stages and hysteresis
- Drink profiles: beer, wine, cocktail, shot, heavy
- Smooth fading visuals, drunk walking, stumbling and falling
- Drunk driving modes: `off`, `sway` (default), `reduced_control`, `inverted`
- Hiccups, groans, heartbeat, tinnitus
- Server-scheduled nausea with optional ox_lib skill check, vomiting and blackouts
- Optional per-character tolerance
- BAC value for police and HUD resources
- Muffled voice for other players through pma-voice without touching radio or phone effects
- Persistence with offline metabolism (resource KVP)
- Qbox, QBCore, ESX and standalone; ox_inventory, qb-inventory and ESX usable items
- State bags, client/server exports and events for integrations
- English and Turkish locales
- Debug commands behind `Config.Debug` and an ACE permission
