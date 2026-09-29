# ForeverDungeonTools v0.4.4 - CHANGELOG

Date: 2026-09-26 (Europe/Paris)

## License
GPLv2 fork of MythicDungeonTools (Nnoggie). LICENSE kept verbatim. Nnoggie attribution retained.

## 1. Monster spawn positions
Replaced diagonal demo/% stub placements with atlas-oriented layouts for:
RFC, Wailing Caverns, Deadmines (2 floors), Shadowfang Keep, Stockade, Blackfathom Deeps,
and all Forever dungeons. Coords use MDT map space (840 x -555 from tile1 TOPLEFT).
Sources: Classic Atlas / Wowhead dungeon map orientation; Hall of Thanes Santiago Reyes labeled rooms.

## 2. Blackfathom Deeps — 3 floors
Mobs/bosses spread across sublevels:
- 1 The Pool of Ask'ar: trash, Ghamoo-ra, Lady Sarevess, Gelihast
- 2 Moonshrine Sanctum: Twilight trash, Lorgus Jett, Twilight Lord Kelris
- 3 The Forgotten Pool: Aku'mai Snapjaws, Aku'mai

## 3. Hover / Enemy Info 3D models
Root cause: map tooltip used `SetCreature(npcId)` which fails for Forever fake ids (910xxx)
and often yields one shared default model on Classic when the creature is uncached.
Fix: prefer `SetDisplayInfo(displayId)` per NPC; portrait texture fallback; ModelWithControlsTemplate shim.
DisplayIds refreshed for uniqueness (classicdb / Wowhead Classic thematic ids).

## 4. Forever dungeon maps
Hall of Thanes keeps Santiago Reyes cartographer fullTexture.
Other Forever dungeons: replaced solid-box schematics with multi-room labeled parchment
cartographer-style fullTexture maps (rooms + corridors + labels). No Blizzard Forever
WorldMap tiles found extracted in client Interface\WorldMap.

## M+ UI
Kept 0.4.3 strip of Mythic+ force / percentage UI.

## Version
- 0.4.4
