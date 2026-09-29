# ForeverDungeonTools v0.4.0 — CHANGELOG

Date: 2026-09-25 (Europe/Paris)

## License

ForeverDungeonTools is a **GPLv2** fork of [MythicDungeonTools](https://github.com/Nnoggie/MythicDungeonTools) by Nnoggie.
LICENSE (GNU GPL v2) is kept verbatim. See NOTICE for attribution. Not relicensed as MIT.

## Upstream

- Repo: https://github.com/Nnoggie/MythicDungeonTools
- Base: shallow clone depth 1 (Release 6.2.20 / commit 7fd7672)

## Changes in 0.4.0

### Rebrand
- Addon name / TOC: ForeverDungeonTools (Title, Author note based on MythicDungeonTools by Nnoggie)
- Version 0.4.0; Interface 16001, 11509
- Slash `/fdt` primary; `/mdt` and `/mplus` aliases retained
- SavedVariables: FDTDB (does not wipe retail MythicDungeonToolsDB)
- Bundled UI into a single AddOn folder (no separate LoD UI addon required)

### Dungeons
- Disabled retail Midnight M+ season lists (would break Classic load)
- Added Forever Classic list + Classic Dungeons list
- Classic (Blizzard WorldMap tiles): Ragefire, Wailing Caverns, Deadmines, Shadowfang, Stockade, Blackfathom
- Forever stubs (boss pins from prior FDT data): Hall of Thanes, Ruins of Lordaeron, Excavation Site, City of Dalaran, The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace
- Hall of Thanes: custom Media texture ported from prior FDT

### API / Classic Forever safety
- IsCompatibleVersion always true for this fork
- ClassicCompat: SafeCreateFrame fallbacks for LoadingSpinnerTemplate, MaximizeMinimizeButtonFrameTemplate, ScenarioProgressBarTemplate, TooltipBorderedFrameTemplate, BackdropTemplate
- CreateColor / WrapTextInColor / issecretvalue / C_AddOns / C_Map / C_ChallengeMode shims where missing
- Transmission: AceSerializer+LibDeflate fallback when C_EncodingUtil unavailable
- MenuUtil / TooltipDataProcessor guarded
- MapView: fullTexture + stubColor for single-image / schematic Forever maps
- BackdropTemplateMixin retained for AceGUI frames (already present upstream)

### Kept intact
- MDT map engine, tile loading, pull/route UI, presets, drawing tools
