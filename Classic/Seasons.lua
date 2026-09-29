-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-26.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
local _, MDT = ...
local L = MDT.L

wipe(MDT.seasonList)
wipe(MDT.dungeonSelectionToIndex)

tinsert(MDT.seasonList, L["Forever Classic"])
tinsert(MDT.dungeonSelectionToIndex, { 7, 8, 9, 10, 11, 12, 13, 14, 15, 1, 2, 3, 4, 5, 6 })

tinsert(MDT.seasonList, L["Classic Dungeons"])
tinsert(MDT.dungeonSelectionToIndex, { 1, 2, 3, 4, 5, 6 })

-- Instance-name -> dungeon index for Classic Forever (GetInstanceInfo name).
MDT.instanceNameToDungeonIdx = MDT.instanceNameToDungeonIdx or {}
local nameMap = {
  ["Ragefire Chasm"] = 1,
  ["Wailing Caverns"] = 2,
  ["The Deadmines"] = 3,
  ["Deadmines"] = 3,
  ["Shadowfang Keep"] = 4,
  ["The Stockade"] = 5,
  ["Stormwind Stockade"] = 5,
  ["Blackfathom Deeps"] = 6,
  ["Hall of Thanes"] = 7,
  ["The Hall of Thanes"] = 7,
  ["Ruins of Lordaeron"] = 8,
  ["Excavation Site"] = 9,
  ["City of Dalaran"] = 10,
  ["The Drowned City"] = 11,
  ["Drowned City"] = 11,
  ["Krol'dok Stronghold"] = 12,
  ["Krol'Dok Stronghold"] = 12,
  ["Alcaz Island Prison"] = 13,
  ["Alcaz Prison"] = 13,
  ["Blackmaw Hold"] = 14,
  ["Shaper's Terrace"] = 15,
}
for k, v in pairs(nameMap) do
  MDT.instanceNameToDungeonIdx[k] = v
  MDT.instanceNameToDungeonIdx[string.lower(k)] = v
end
