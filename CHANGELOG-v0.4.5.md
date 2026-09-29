# ForeverDungeonTools v0.4.5 - CHANGELOG

Date: 2026-09-26 (Europe/Paris)

## License
GPLv2 fork of MythicDungeonTools (Nnoggie). LICENSE kept verbatim. Nnoggie attribution retained.

## Enemy Info spell lists (Classic dungeons)
Enemy Info UI already rendered data.spells via MDTSpellButton (icons + names beside the model),
but Classic dungeon enemy tables had no spells keys - right-click Set Enemy Info showed an empty list.

Populated spells on Classic dungeon NPCs from classicdb / Wowhead Classic abilities tabs:
- Ragefire Chasm, Wailing Caverns, Deadmines, Shadowfang Keep, Stockade, Blackfathom Deeps
- 67 / 72 NPC types with at least one ability; 5 melee-only (no abilities on classicdb) left without a spells block
- Flags set where clear from spell name: interruptible, curse, poison, disease, magic, bleed, enrage
- Passive noise skipped (Dual Wield, Battle/Defensive Stance, Improved Blocking)

Files touched:
- Classic/Ragefire.lua, WailingCaverns.lua, Deadmines.lua, Shadowfang.lua, Stockade.lua, Blackfathom.lua
- ForeverDungeonTools.toc (0.4.5)

No EnemyInfo.lua / SpellButton code changes required - data was the missing piece.

## Version
- 0.4.5