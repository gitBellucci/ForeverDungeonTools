# ForeverDungeonTools v0.4.3 - CHANGELOG

Date: 2026-09-26 (Europe/Paris)

## License
GPLv2 fork of MythicDungeonTools (Nnoggie). LICENSE kept verbatim.

## Classic Forever: strip M+ force / percentage UI
Classic Forever has no Mythic+ enemy-forces requirement. Visible M+ force/% UI is now hidden/removed from the pull panel and map:

- Side-panel Scenario ProgressBar (force percentage bar): created but always hidden; UpdateProgressbar is a no-op hide.
- Pull-button force % / force count text (percentageFontString): UpdateCountText only shows optional pull health.
- Pull hover no longer drives the ProgressBar.
- Pull tooltip: Forces / Total lines omitted.
- Map enemy tooltip: Forces and Efficiency Score lines omitted.
- Map blips: no force-count overlay on hover; Ctrl modifier no longer shows force counts.
- Settings: "Use forces count" and "Enemy forces in tooltips" options not shown.
- Enemy Info: "Enemy Forces" field not shown.

Backend CountForces / GetEnemyForces kept for API compatibility; dungeonTotalCount.normal remains 0.

## Version
- 0.4.3
