# ForeverDungeonTools v0.4.1 — CHANGELOG

Date: 2026-09-26 (Europe/Paris)

## License

ForeverDungeonTools is a **GPLv2** fork of [MythicDungeonTools](https://github.com/Nnoggie/MythicDungeonTools) by Nnoggie.
LICENSE (GNU GPL v2) kept verbatim. See NOTICE for attribution.

## Fix: pull route connectors (hull outlines)

MDT draws convex-hull outlines around each pull (circles + connecting lines + pull numbers) via `Modules/PullOutlines.lua`:
- `MDT:DrawAllHulls` → `DrawHull` → `DrawHullLine` / `DrawHullCircle` / `DrawHullFontString`
- Called from `MDT:ReloadPullButtons` and drag-preview in `DungeonEnemies.lua`

### What was broken
After the Forever rebrand, hull/draw textures still pointed at
`Interface\AddOns\MythicDungeonTools\Textures\...` while the installed folder is
`ForeverDungeonTools`. `Circle_White` / `Square_White` (and related UI textures) failed to load,
so pull outline circles and connector lines were invisible. Enemy creature portraits still worked
because they use game portrait paths, not those addon textures.

### What changed
- Remapped addon texture paths `MythicDungeonTools` → `ForeverDungeonTools` in hull/draw/UI files
  (PullOutlines, PresetObjects, Toolbar, DungeonEnemies.lua/xml, PullButton, ExternalLinks,
  FocusMarker, Settings, ErrorHandling, UI toc)
- `ClassicCompat.lua`: `DrawLine` polyfill if the client global is missing; `GameFontNormalMed3Outline` fallback
- `PullOutlines.lua`: safe font object when creating pull-number overlays
- `MapView.lua`: on Forever stub/fullTexture maps, keep `mapPanelTile1` shown at alpha 0 so hull
  `DrawLine` anchors keep valid geometry (blips already used this frame as origin)

## Version
- 0.4.1
