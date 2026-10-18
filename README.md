# CandyBuckets for WoW 3.3.5a

A **backport of [CandyBuckets](https://github.com/Vladinator/wow-addon-candybuckets) by Vladinator** to
the original Wrath of the Lich King client (**3.3.5a, build 12340, Interface 30300**).

It places the holiday objectives on the world map — both the zone view **and** the continent
overview — and as dots on the **minimap**:

- 🎃 **Hallow's End** — candy buckets
- 🏮 **Lunar Festival** — elders
- 🔥 **Midsummer Fire Festival** — bonfires

The upstream addon is built on the modern (Legion/BfA+) map-pin API and cannot load on a 3.3.5a
client, so this is a rewrite of the display layer against the old world map
(`WorldMapDetailFrame`, `GetMapZones`, `GetCurrentMapZone`) with the coordinate database
regenerated from 3.3.5 data.

---

## Install

**Easiest:** download `CandyBuckets.zip` from the [latest release](../../releases/latest) and extract it
into `World of Warcraft\Interface\AddOns\` — the folder inside is already named `CandyBuckets`.

**From source:** copy the `CandyBuckets` folder in this repository into
`World of Warcraft\Interface\AddOns\`.

## Usage

Open the world map (**M**) — icons appear in both the zone view and the continent overview.
The minimap shows dots for objectives in the zone you're standing in. Icons are coloured by the
faction that can complete them; hover for the name, coordinates, side and quest ID.

- **Click an icon** → sets a **TomTom** waypoint (if TomTom is loaded), otherwise prints the coordinates to chat.
- Completed objectives are hidden by default (so the map only shows what's left for the achievement).

### Slash commands

| Command | Effect |
| --- | --- |
| `/cb` | show current status |
| `/cb all` / `/cb none` | load / unload every event |
| `/cb hallow` / `/cb lunar` / `/cb midsummer` | toggle a single event |
| `/cb completed` | show/hide already-completed objectives |
| `/cb minimap` | toggle the minimap dots |
| `/cb enemy` | show/hide objectives that sit inside the other faction's camp |

On first run it auto-selects whichever event is running by today's date (and shows all of
them if none are). Your choice is saved.

## Requirements

- World of Warcraft **3.3.5a** (build 12340)
- Optional: **[TomTom](https://www.curseforge.com/wow/addons/tomtom)** (r240 / 3.3.5 build) for waypoint arrows

## How the data was built

The upstream `db\*.lua` files are keyed by modern `uiMapID`s with modern coordinates, which are
wrong on 3.3.5 — Cataclysm reworked the old-world maps (e.g. the Crossroads is `52, 29.9` in
3.3.5 but `~49.5, 58` on modern maps).

Instead, the coordinate database here was regenerated from **[wotlkdb.com](https://wotlkdb.com)**
(a 3.3.5-only database), which returns the 3.3.5 zone and coordinates for each quest:

- 627 upstream quest IDs checked → **335 are real 3.3.5 content** (the rest are post-WotLK and dropped).
- 108 candy buckets · 75 elders · 152 bonfires, across 81 zones.
- The **faction** (`Alliance` / `Horde` / neutral) is also taken from the 3.3.5 quest itself, so the
  filtering matches vanilla WotLK — e.g. the Northrend and Outland objectives are neutral there,
  while the Eastern Kingdoms / Kalimdor inns are faction-locked.

## Enemy camps

A few 3.3.5 objectives carry no faction flag but sit *inside* an enemy base — for example the
Silver Enclave in Dalaran, or Amberpine Lodge in Grizzly Hills. You get ported out and there's no
quest marker for you, but the achievement data can't express that.

`areas.lua` lists these spots (derived from the 3.3.5 NPC factions around each one) and they're
hidden for the opposite faction by default. Toggle with **`/cb enemy`**. If you find one that's
tagged wrong, it's a one-line edit in `areas.lua` (`[questID] = 1` Alliance / `2` Horde).

## Map & minimap placement

World-map icons are plotted on whichever map is open — zone view **and** continent overview — using
**Astrolabe** (bundled with TomTom, or the standalone `!Astrolabe` library) to translate coordinates
between maps. Minimap dots use Astrolabe too. Without Astrolabe the addon falls back to showing
objectives only for the zone you're viewing.

## Limitations

- TomTom hides waypoints while you're inside an instance, so the Lunar Festival elders that
  live in dungeons only report coordinates instead of setting an arrow.
- Zone-name matching handles the known `Sunken Temple` ↔ `The Temple of Atal'Hakkar` difference.

## Credits

- **[Vladinator](https://github.com/Vladinator/wow-addon-candybuckets)** — original CandyBuckets
  ([CurseForge](https://www.curseforge.com/wow/addons/candy-buckets) ·
  [WoWInterface](https://www.wowinterface.com/downloads/info20450-CandyBuckets.html)).
  This port reuses the addon's concept, event coverage and iconography.
- Coordinate data: [wotlkdb.com](https://wotlkdb.com) (WotLK 3.3.5a database).
- **[TomTom](https://github.com/Cladhaire/TomTom)** by Cladhaire — optional waypoint support.

## License / notice

This is an **unofficial fan backport** and is not affiliated with or endorsed by the original
author. The upstream CandyBuckets is published as *"All rights reserved."*; this port is provided
for personal use and keeps the original author credited. If you are the author and would like it
changed or removed, please open an issue.
