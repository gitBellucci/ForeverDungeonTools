# ForeverDungeonTools v0.4.2 - CHANGELOG

Date: 2026-09-26 (Europe/Paris)

## License
GPLv2 fork of MythicDungeonTools (Nnoggie). LICENSE kept verbatim.

## Enemy / mob database
- Root cause: v0.4.x stubs used displayId = 10015 (boar) and fake sequential ids for every pin.
- Classic dungeons (RFC, WC, VC, SFK, Stocks, BFD): real Classic NPC ids + displayIds (classicdb/rising-gods ModelViewer), bosses flagged, clones grouped with g, positions from prior FDT percent layouts mapped to MDT coords.
- Forever dungeons: thematic Classic displayIds (no boar placeholder), bosses present, pull groups set.
- dungeonTotalCount.normal = 0 (Classic/Forever force counts not invented).

## Forever maps
- Hall of Thanes: refreshed Santiago Reyes cartographer map (Wowhead screenshot 1303242) as fullTexture.
- Added schematic fullTexture maps under Media/ for: Ruins of Lordaeron, Excavation Site, City of Dalaran, Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace (replacing gray stubColor).

## Feature: Open FDT on minimap in dungeon
- Settings > General checkbox "Open FDT on minimap in dungeon" (db.openFdtOnMinimap, default off).
- When enabled, left-clicking the minimap (or zone text / ToggleMinimap show) while inside a party/raid instance resolves the dungeon via GetInstanceInfo() name map (or zone id) and opens FDT on that map. No-op if unmapped.

## Version
- 0.4.2
