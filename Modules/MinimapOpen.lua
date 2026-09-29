-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
local _, MDT = ...
local L = MDT.L

-- Option: open FDT when the player clicks the minimap while inside a mapped dungeon.
-- Default: off (db.openFdtOnMinimap).

local function resolveDungeonIdx()
  local map = MDT.instanceNameToDungeonIdx
  if map then
    local name = GetInstanceInfo and select(1, GetInstanceInfo()) or nil
    if name and name ~= "" then
      local idx = map[name] or map[string.lower(name)]
      if idx then return idx end
    end
  end
  if MDT.GetDungeonIdxForCurrentLocation then
    local idx = MDT:GetDungeonIdxForCurrentLocation()
    if idx then return idx end
  end
  return nil
end

local function tryOpenFromMinimap()
  local db = MDT.GetDB and MDT:GetDB()
  if not db or not db.openFdtOnMinimap then return end
  if not IsInInstance or not IsInInstance() then return end
  local instanceType = select(2, IsInInstance())
  if instanceType ~= "party" and instanceType ~= "raid" then return end
  local idx = resolveDungeonIdx()
  if not idx then return end
  if MDT.ShowInterface then MDT:ShowInterface(true) end
  MDT:RunAfterFramesInitialized(function()
    if not MDT.main_frame then return end
    MDT:UpdateToDungeon(idx)
    MDT:SetDungeonList(nil, idx)
  end)
end

MDT.TryOpenFromMinimap = tryOpenFromMinimap

local function hookMinimap()
  if Minimap and Minimap.HookScript then
    Minimap:HookScript("OnMouseUp", function(_, button)
      if button == "LeftButton" then tryOpenFromMinimap() end
    end)
  end
  if MinimapZoneTextButton and MinimapZoneTextButton.HookScript then
    MinimapZoneTextButton:HookScript("OnClick", function()
      tryOpenFromMinimap()
    end)
  end
  if type(ToggleMinimap) == "function" then
    hooksecurefunc("ToggleMinimap", function()
      if Minimap and Minimap.IsShown and Minimap:IsShown() then
        tryOpenFromMinimap()
      end
    end)
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  hookMinimap()
end)
