-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
-- NPC ids: Wowhead Forever. Display ids, levels and boss positions: foreverchanges.pro
-- (map by Santiago Reyes). Trash positions, health and spell ids come from the in-game
-- mob tracker (/fdt track).

local _, MDT = ...
local L = MDT.L
local dungeonIndex = 8
MDT.dungeonList[dungeonIndex] = L["Ruins of Lordaeron"]
MDT.mapInfo[dungeonIndex] = {
  shortName = L["RoL"],
  englishName = "Ruins of Lordaeron",
  instanceId = 2999,
  iconDisplayId = 139455,
  iconId = "Interface\\Icons\\Spell_Shadow_RaiseDead",
  -- map points of the subzones (GetSubZoneText), used to place tracker kills: the client hides
  -- unit identity and positions in this instance
  fdtSubzoneAnchors = {
    ["Market Street"] = { x = 307.7, y = -249.0 },
    ["King's Alley"] = { x = 589.7, y = -244.0 },
    ["Lordamere Overlook"] = { x = 456.4, y = -386.3 },
    ["Lordaeron Graveyard"] = { x = 353.8, y = -426.9 },
  },
}
MDT.dungeonMaps[dungeonIndex] = {
  [0] = "",
  [1] = { fullTexture = "Interface\\AddOns\\ForeverDungeonTools\\Media\\RuinsOfLordaeron" },
}
MDT.dungeonSubLevels[dungeonIndex] = {
  [1] = "Ruins of Lordaeron",
}
MDT.dungeonTotalCount[dungeonIndex] = { normal = 0 }
MDT.mapPOIs[dungeonIndex] = {
  [1] = {
    [1] = { ["type"] = "dungeonEntrance", ["x"] = 512.4, ["y"] = -119.9, ["sizeMult"] = 1.5 },
  },
}
MDT.dungeonEnemies[dungeonIndex] = {
  [1] = {
    ["name"] = "Witherfang",
    ["id"] = 250483,
    ["count"] = 0,
    ["health"] = 5200,
    ["scale"] = 1.6,
    ["displayId"] = 144189,
    ["creatureType"] = "Beast",
    ["level"] = 17,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Courtyard spiders", icon = "inv_misc_monsterspidercarapace_01", flags = { "important" },
        text = "Patrols the spider courtyard in front of the entrance with adds. Clear the other spiders first or they join the fight." },
      { name = "Poison", icon = "ability_creature_poison_05", flags = { "poison" },
        text = "Poisons its target." },
    },
    ["clones"] = {
      [1] = { ["x"] = 561.1, ["y"] = -217.6, ["g"] = 1, ["sublevel"] = 1 },
    },
  },
  [2] = {
    ["name"] = "The Baron",
    ["id"] = 250660,
    ["count"] = 0,
    ["health"] = 5200,
    ["scale"] = 1.6,
    ["displayId"] = 144188,
    ["creatureType"] = "Undead",
    ["level"] = 17,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Hurl", icon = "ability_smash", flags = { "tank" },
        text = "Throws the tank into the air and stuns them for about 5 seconds. Damage dealers must watch their threat." },
      { name = "Patrol", icon = "ability_eyeoftheowl", flags = { "important" },
        text = "A patrol crosses his room: clear it before the pull. His head is needed for Abominable Creatures and Unending Torment." },
    },
    ["clones"] = {
      [1] = { ["x"] = 493.9, ["y"] = -387.4, ["g"] = 2, ["sublevel"] = 1 },
    },
  },
  [3] = {
    ["name"] = "The Abandoned",
    ["id"] = 250631,
    ["count"] = 0,
    ["health"] = 5600,
    ["scale"] = 1.6,
    ["displayId"] = 138667,
    ["creatureType"] = "Undead",
    ["level"] = 18,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Statue event", icon = "inv_misc_statue_02", flags = { "important" },
        text = "Kill the Skeletal Mage in the south hallway, then click the glowing statue in the tower: three waves spawn before the boss." },
      { name = "Frost Nova", icon = "spell_frost_frostnova", flags = { "healer" },
        text = "Frost damage and root on the whole group." },
      { name = "Drain Life", icon = "spell_shadow_lifedrain02", flags = { "interrupt" },
        text = "Channelled life drain: interrupt or stun it." },
    },
    ["clones"] = {
      [1] = { ["x"] = 344.4, ["y"] = -295.8, ["g"] = 3, ["sublevel"] = 1 },
    },
  },
  [4] = {
    ["name"] = "Bjork",
    ["id"] = 256097,
    ["count"] = 0,
    ["health"] = 6000,
    ["scale"] = 1.6,
    ["displayId"] = 144170,
    ["creatureType"] = "Undead",
    ["level"] = 19,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Knockback", icon = "ability_warstomp", flags = { "tank", "important" },
        text = "Knocks the group back: clear the packs around him first so nobody lands in another pull." },
      { name = "Anti-Magic Shield", icon = "spell_shadow_antimagicshell", flags = { "magic" },
        text = "Shields himself against spells for a while. Purge it or switch to physical damage." },
      { name = "Heavy blows", icon = "ability_warrior_decisivestrike", flags = { "tank", "healer" },
        text = "Hits the tank hard." },
    },
    ["clones"] = {
      [1] = { ["x"] = 329.3, ["y"] = -235.9, ["g"] = 4, ["sublevel"] = 1 },
    },
  },
  [5] = {
    ["name"] = "Rath'mael",
    ["id"] = 250657,
    ["count"] = 0,
    ["health"] = 7000,
    ["scale"] = 1.6,
    ["displayId"] = 144175,
    ["creatureType"] = "Undead",
    ["level"] = 20,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Flamestrike", icon = "spell_fire_selfdestruct", flags = { "deadly", "interrupt" },
        text = "His main spell. Interrupt or stun every cast; melee takes the area damage." },
      { name = "Large health pool", icon = "spell_holy_sealofmight", flags = { "damage" },
        text = "Longest fight of the dungeon: keep the interrupt rotation going." },
    },
    ["clones"] = {
      [1] = { ["x"] = 384.7, ["y"] = -348.0, ["g"] = 5, ["sublevel"] = 1 },
    },
  },
  [6] = {
    ["name"] = "Viktor the Vile",
    ["id"] = 256035,
    ["count"] = 0,
    ["health"] = 6000,
    ["scale"] = 1.6,
    ["displayId"] = 139455,
    ["creatureType"] = "Beast",
    ["level"] = 19,
    ["isBoss"] = true,
    ["abilities"] = {
      { name = "Grim Campfire", icon = "spell_fire_fire", flags = { "important" },
        text = "Optional boss. Light the fireplace of the ruined house in the south-west: four waves of undead spawn before Viktor." },
      { name = "Poison", icon = "ability_creature_poison_05", flags = { "poison", "healer" },
        text = "Poisons his target." },
      { name = "Heavy blows", icon = "ability_warrior_decisivestrike", flags = { "tank" },
        text = "Tank and spank; the healer is usually low on mana after the waves." },
    },
    ["clones"] = {
      [1] = { ["x"] = 316.7, ["y"] = -359.6, ["g"] = 6, ["sublevel"] = 1 },
    },
  },
}
MDT:RegisterDungeonLocation(8, { zoneIds = { }, instanceIds = { 2999 } })
