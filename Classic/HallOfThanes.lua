-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
-- NPC ids: Wowhead Forever. Display ids and boss positions: foreverchanges.pro
-- (map by Santiago Reyes). Trash positions, health and spell ids come from the in-game
-- mob tracker (/fdt track).

local _, MDT = ...
local L = MDT.L
local dungeonIndex = 7
MDT.dungeonList[dungeonIndex] = L["Hall of Thanes"]
MDT.mapInfo[dungeonIndex] = {
  shortName = L["HoT"],
  englishName = "Hall of Thanes",
  instanceId = 3065,
  iconDisplayId = 142837,
  iconId = "Interface\\Icons\\INV_Hammer_09",
}
MDT.dungeonMaps[dungeonIndex] = {
  [0] = "",
  [1] = { fullTexture = "Interface\\AddOns\\ForeverDungeonTools\\Media\\HallOfThanes" },
}
MDT.dungeonSubLevels[dungeonIndex] = {
  [1] = "Hall of Thanes",
}
MDT.dungeonTotalCount[dungeonIndex] = { normal = 0 }
MDT.mapPOIs[dungeonIndex] = {
  [1] = {
    [1] = { ["type"] = "dungeonEntrance", ["x"] = 427.6, ["y"] = -518.4, ["sizeMult"] = 1.5 },
  },
}
MDT.dungeonEnemies[dungeonIndex] = {
  [1] = {
    ["name"] = "Faldrim Anvilmar",
    ["id"] = 261306,
    ["count"] = 0,
    ["health"] = 4500,
    ["scale"] = 1.6,
    ["displayId"] = 142826,
    ["creatureType"] = "Undead",
    ["level"] = 16,
    ["isBoss"] = true,
    ["spells"] = {
      [1292602] = { ["curse"] = true },
    },
    ["abilities"] = {
      { name = "Mind Blast", icon = "spell_shadow_unholyfrenzy", flags = { "interrupt" },
        text = "Shadow damage on a random target. Interruptible." },
      { name = "Patrol", icon = "ability_eyeoftheowl", flags = { "important" },
        text = "Patrols the centre of Anvilmar's Rest among Enraged Apparitions: clear one side of the room and pull him when he comes to you." },
    },
    ["clones"] = {
      [1] = { ["x"] = 427.6, ["y"] = -346.9, ["g"] = 1, ["sublevel"] = 1 },
    },
  },
  [2] = {
    ["name"] = "Magmatus",
    ["id"] = 261316,
    ["count"] = 0,
    ["health"] = 5000,
    ["scale"] = 1.6,
    ["displayId"] = 1070,
    ["creatureType"] = "Elemental",
    ["level"] = 17,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Dark Iron Summoner", icon = "spell_shadow_summonimp", flags = { "important", "damage" },
        text = "A Dark Iron Summoner keeps bringing Fiery Assistants: kill him first, then the elemental." },
      { name = "Fire all around", icon = "spell_fire_fire", flags = { "healer" },
        text = "Area fire damage around him, worse with many melee. Tank him away from the group." },
    },
    ["clones"] = {
      [1] = { ["x"] = 525.0, ["y"] = -272.0, ["g"] = 2, ["sublevel"] = 1 },
    },
  },
  [3] = {
    ["name"] = "Plunder",
    ["id"] = 261311,
    ["count"] = 0,
    ["health"] = 5000,
    ["scale"] = 1.6,
    ["displayId"] = 142840,
    ["creatureType"] = "Elemental",
    ["level"] = 17,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Charge and knockback", icon = "ability_warstomp", flags = { "tank", "important" },
        text = "Charges and stuns, then knocks everyone around him far away. Clear the nearby packs and tank him near the tunnel." },
    },
    ["clones"] = {
      [1] = { ["x"] = 428.4, ["y"] = -274.7, ["g"] = 3, ["sublevel"] = 1 },
    },
  },
  [4] = {
    ["name"] = "Durgen Dirgehammer",
    ["id"] = 261319,
    ["count"] = 0,
    ["health"] = 6000,
    ["scale"] = 1.6,
    ["displayId"] = 142837,
    ["creatureType"] = "Humanoid",
    ["level"] = 18,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Fear at low health", icon = "spell_shadow_psychicscream", flags = { "important" },
        text = "Fears the whole group when his health gets low: clear the trash along the room edges first." },
      { name = "Stone Golems", icon = "inv_misc_stonetablet_05", flags = { "tank" },
        text = "Two golems join the fight: off-tank or burn them. Killed golems do not respawn after a wipe." },
      { name = "Locked vaults", icon = "inv_misc_key_03", flags = {},
        text = "After the fight, open the vaults: Dwarven Heirlooms for Important Heirlooms and the tablet for The Treaty of Understanding." },
    },
    ["clones"] = {
      [1] = { ["x"] = 428.4, ["y"] = -122.1, ["g"] = 4, ["sublevel"] = 1 },
    },
  },
}
MDT:RegisterDungeonLocation(7, { zoneIds = { }, instanceIds = { 3065 } })
