-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
-- No map art or spawn data is public for this dungeon yet: no map and no enemies are shown.
-- Record it with the mob tracker (/fdt track on) to collect positions.

local _, MDT = ...
local L = MDT.L
local dungeonIndex = 12
MDT.dungeonList[dungeonIndex] = L["Krol'dok Stronghold"]
MDT.mapInfo[dungeonIndex] = {
  shortName = L["Krol"],
  englishName = "Krol'dok Stronghold",
  iconId = "Interface\\Icons\\Ability_Warrior_BattleShout",
  noMap = true,
}
MDT.dungeonMaps[dungeonIndex] = {
  [0] = "",
  [1] = { noMap = true, stubColor = { 0.07, 0.07, 0.08, 1 } },
}
MDT.dungeonSubLevels[dungeonIndex] = {
  [1] = "Krol'dok Stronghold",
}
MDT.dungeonTotalCount[dungeonIndex] = { normal = 0 }
MDT.mapPOIs[dungeonIndex] = { [1] = {} }
MDT.dungeonEnemies[dungeonIndex] = {}
MDT:RegisterDungeonLocation(12, { zoneIds = { } })
