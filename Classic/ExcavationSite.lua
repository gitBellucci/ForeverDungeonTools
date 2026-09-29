-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
-- No map art or spawn data is public for this dungeon yet: no map and no enemies are shown.
-- Record it with the mob tracker (/fdt track on) to collect positions.

local _, MDT = ...
local L = MDT.L
local dungeonIndex = 9
MDT.dungeonList[dungeonIndex] = L["Excavation Site"]
MDT.mapInfo[dungeonIndex] = {
  shortName = L["Excav"],
  englishName = "Excavation Site",
  iconId = "Interface\\Icons\\INV_Pick_02",
  noMap = true,
}
MDT.dungeonMaps[dungeonIndex] = {
  [0] = "",
  [1] = { noMap = true, stubColor = { 0.07, 0.07, 0.08, 1 } },
}
MDT.dungeonSubLevels[dungeonIndex] = {
  [1] = "Excavation Site",
}
MDT.dungeonTotalCount[dungeonIndex] = { normal = 0 }
MDT.mapPOIs[dungeonIndex] = { [1] = {} }
MDT.dungeonEnemies[dungeonIndex] = {}
MDT:RegisterDungeonLocation(9, { zoneIds = { }, instanceIds = { 2998 } })
