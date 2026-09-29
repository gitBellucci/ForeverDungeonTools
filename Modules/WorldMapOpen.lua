-- Added for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Part of a modified MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
--
-- Option (default on, db.openFdtOnWorldMap): opening the world map inside a known dungeon opens the
-- FDT map of that dungeon instead, on the player's floor, with the player and group members drawn on it.
local _, MDT = ...

local UPDATE_INTERVAL = 0.1
local DOT_SIZE = 9
local ARROW_SIZE = 22

local issecretvalue = issecretvalue or function() return false end
local function readable(...)
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return end
  end
  return ...
end

local function getDB()
  return MDT.GetDB and MDT:GetDB()
end

local function currentDungeonIdx()
  local _, instanceType = IsInInstance()
  if instanceType ~= "party" and instanceType ~= "raid" then return end
  local name = readable((GetInstanceInfo()))
  local instanceId = readable((select(8, GetInstanceInfo())))
  local idx = MDT.instanceIdToDungeonIdx and instanceId and MDT.instanceIdToDungeonIdx[instanceId]
  local map = MDT.instanceNameToDungeonIdx
  if not idx and map and name then idx = map[name] or map[string.lower(name)] end
  if not idx and MDT.GetDungeonIdxForCurrentLocation then idx = MDT:GetDungeonIdxForCurrentLocation() end
  return idx
end

-- returns a function(worldX, worldY, worldZ, preferredSublevel) -> mapX, mapY, sublevel
local transformCache = {}
local function getTransform(dungeonIdx)
  local info = MDT.mapInfo[dungeonIdx]
  if info and info.worldToMap then
    return function(x, y, z, preferred)
      local best, bestScore
      for sublevel, t in pairs(info.worldToMap) do
        local mx, my = t.xY * y + t.x0, t.yX * x + t.y0
        if mx >= 0 and mx <= 840 and my <= 0 and my >= -555 then
          local score = (z >= t.zMin and z <= t.zMax) and 2 or 0
          if sublevel == preferred then score = score + 1 end
          if not bestScore or score > bestScore or (score == bestScore and sublevel < best.sublevel) then
            best, bestScore = { x = mx, y = my, sublevel = sublevel }, score
          end
        end
      end
      if best then return best.x, best.y, best.sublevel end
    end
  end
  local instanceId = select(8, GetInstanceInfo())
  local key = dungeonIdx..":"..tostring(instanceId)
  if transformCache[key] == nil then
    transformCache[key] = MDT.MobTracker_GetWorldTransform and MDT:MobTracker_GetWorldTransform(dungeonIdx) or false
  end
  local affine = transformCache[key]
  if affine then
    return function(x, y)
      local mx, my = affine({ x = x, y = y })
      return mx, my, 1
    end
  end
end

local function unitMapPosition(unit, transform, preferred)
  if not UnitExists(unit) then return end
  local posY, posX, posZ = readable(UnitPosition(unit))
  if not posY then return end
  return transform(posX, posY, posZ or 0, preferred)
end

local overlay, markers
local function createOverlay()
  local parent = MDT.main_frame and MDT.main_frame.mapPanelFrame
  if not parent then return end
  overlay = CreateFrame("Frame", nil, parent)
  overlay:SetAllPoints(parent)
  overlay:SetFrameLevel(parent:GetFrameLevel() + 60)
  markers = {}
  overlay.elapsed = 0
  overlay:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    self.elapsed = 0
    MDT:WorldMapOpen_UpdateMarkers()
  end)
  return overlay
end

local function getMarker(index)
  local marker = markers[index]
  if marker then return marker end
  marker = CreateFrame("Frame", nil, overlay)
  marker:SetFrameLevel(overlay:GetFrameLevel() + (index == 1 and 2 or 1))
  marker.texture = marker:CreateTexture(nil, "OVERLAY")
  marker.texture:SetAllPoints(marker)
  if index == 1 then
    marker:SetSize(ARROW_SIZE, ARROW_SIZE)
    marker.texture:SetTexture("Interface\\Minimap\\MinimapArrow")
  else
    marker:SetSize(DOT_SIZE, DOT_SIZE)
    marker.texture:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    marker.border = marker:CreateTexture(nil, "ARTWORK")
    marker.border:SetPoint("CENTER")
    marker.border:SetSize(DOT_SIZE + 3, DOT_SIZE + 3)
    marker.border:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    marker.border:SetVertexColor(0, 0, 0, 1)
    marker.name = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marker.name:SetPoint("BOTTOM", marker, "TOP", 0, 1)
  end
  markers[index] = marker
  return marker
end

local groupUnits = {}
local function collectGroupUnits()
  wipe(groupUnits)
  groupUnits[1] = "player"
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid"..i
      if not UnitIsUnit(unit, "player") then groupUnits[#groupUnits + 1] = unit end
    end
  else
    for i = 1, GetNumSubgroupMembers() do groupUnits[#groupUnits + 1] = "party"..i end
  end
  return groupUnits
end

function MDT:WorldMapOpen_UpdateMarkers()
  if not overlay or not markers then return end
  local db = getDB()
  local dungeonIdx = currentDungeonIdx()
  local transform = dungeonIdx and db and db.currentDungeonIdx == dungeonIdx and getTransform(dungeonIdx)
  local sublevel = transform and MDT.GetCurrentSubLevel and MDT:GetCurrentSubLevel()
  local scale = MDT:GetScale()
  local shown = 0
  if transform and sublevel then
    for index, unit in ipairs(collectGroupUnits()) do
      local mx, my, unitSublevel = unitMapPosition(unit, transform, sublevel)
      local marker = getMarker(index)
      if mx and unitSublevel == sublevel then
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", MDT.main_frame.mapPanelTile1, "TOPLEFT", mx * scale, my * scale)
        if index == 1 then
          local facing = GetPlayerFacing and readable(GetPlayerFacing())
          if facing then marker.texture:SetRotation(facing) end
        else
          local class = readable(select(2, UnitClass(unit)))
          local color = class and RAID_CLASS_COLORS[class]
          marker.texture:SetVertexColor(color and color.r or 1, color and color.g or 1, color and color.b or 1, 1)
          marker.name:SetText(readable(UnitName(unit)) or "")
          if color then marker.name:SetTextColor(color.r, color.g, color.b) end
        end
        marker:Show()
        shown = index
      else
        marker:Hide()
      end
    end
  end
  for index = 1, #markers do
    if index > #groupUnits or not transform then markers[index]:Hide() end
  end
  MDT:WorldMapOpen_UpdateZoneMarker(dungeonIdx, db, shown >= 1)
  return shown
end

-- instances that hide positions: highlight the player's subzone (GetSubZoneText stays readable)
local ZONE_DOT_SIZE = 10
local zoneMarker
function MDT:WorldMapOpen_UpdateZoneMarker(dungeonIdx, db, hasExactPosition)
  local info = dungeonIdx and MDT.mapInfo[dungeonIdx]
  local anchors = info and info.fdtSubzoneAnchors
  local subzone = readable(GetSubZoneText and GetSubZoneText())
  local anchor = anchors and subzone and anchors[subzone]
  local visible = anchor and not hasExactPosition and db and db.currentDungeonIdx == dungeonIdx
    and (not MDT.GetCurrentSubLevel or MDT:GetCurrentSubLevel() == (anchor.sublevel or 1))
  if not visible then
    if zoneMarker then zoneMarker:Hide() end
    return
  end
  if not zoneMarker then
    zoneMarker = CreateFrame("Frame", nil, overlay)
    zoneMarker:SetFrameLevel(overlay:GetFrameLevel() + 3)
    zoneMarker:SetSize(ZONE_DOT_SIZE, ZONE_DOT_SIZE)
    zoneMarker.border = zoneMarker:CreateTexture(nil, "ARTWORK")
    zoneMarker.border:SetPoint("CENTER")
    zoneMarker.border:SetSize(ZONE_DOT_SIZE + 4, ZONE_DOT_SIZE + 4)
    zoneMarker.border:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    zoneMarker.border:SetVertexColor(0, 0, 0, 1)
    zoneMarker.dot = zoneMarker:CreateTexture(nil, "OVERLAY")
    zoneMarker.dot:SetAllPoints(zoneMarker)
    zoneMarker.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    zoneMarker.dot:SetVertexColor(0.95, 0.1, 0.1, 1)
    zoneMarker.label = zoneMarker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneMarker.label:SetPoint("BOTTOM", zoneMarker, "TOP", 0, 2)
  end
  local scale = MDT:GetScale()
  zoneMarker:ClearAllPoints()
  zoneMarker:SetPoint("CENTER", MDT.main_frame.mapPanelTile1, "TOPLEFT", anchor.x * scale, anchor.y * scale)
  zoneMarker.label:SetText(subzone)
  zoneMarker:Show()
end

function MDT:WorldMapOpen_Diagnose()
  local db = getDB()
  local dungeonIdx = currentDungeonIdx()
  local info = dungeonIdx and MDT.mapInfo[dungeonIdx]
  local anchors = info and info.fdtSubzoneAnchors
  local rawSubzone = GetSubZoneText and GetSubZoneText()
  local subzone = readable(rawSubzone)
  local posY = readable(UnitPosition("player"))
  local ok, err = true, nil
  if overlay then ok, err = pcall(MDT.WorldMapOpen_UpdateMarkers, MDT) end
  local lines = {
    "instance="..tostring(readable((GetInstanceInfo())))..", id="..tostring(readable((select(8, GetInstanceInfo()))))
      ..", dungeonIdx="..tostring(dungeonIdx)..", selected="..tostring(db and db.currentDungeonIdx),
    "subzone="..(issecretvalue(rawSubzone) and "<secret>" or ("\""..tostring(subzone).."\""))
      ..", anchor="..tostring(anchors and subzone and anchors[subzone] ~= nil)
      ..", sublevel="..tostring(MDT.GetCurrentSubLevel and MDT:GetCurrentSubLevel()),
    "position="..tostring(posY ~= nil)..", overlay="..tostring(overlay ~= nil)
      ..(overlay and (", overlayVisible="..tostring(overlay:IsVisible())) or "")
      ..", marker="..tostring(zoneMarker ~= nil and zoneMarker:IsShown()),
  }
  local function probe(label, fn)
    local results = { pcall(fn) }
    if not results[1] then return label.."=blocked" end
    local parts = {}
    for i = 2, #results do parts[#parts + 1] = issecretvalue(results[i]) and "<secret>" or tostring(results[i]) end
    return label.."="..(#parts > 0 and table.concat(parts, "/") or "nil")
  end
  local minimapProbes = {
    probe("ping", function() return Minimap:GetPingPosition() end),
    probe("zoom", function() return Minimap:GetZoom() end),
    probe("mapPos", function()
      local mapId = C_Map.GetBestMapForUnit("player")
      local pos = mapId and C_Map.GetPlayerMapPosition(mapId, "player")
      if pos then return pos:GetXY() end
      return mapId
    end),
  }
  if C_Minimap then
    local names = {}
    for key in pairs(C_Minimap) do names[#names + 1] = key end
    table.sort(names)
    minimapProbes[#minimapProbes + 1] = "C_Minimap: "..table.concat(names, ",")
  end
  lines[#lines + 1] = "minimap: "..table.concat(minimapProbes, ", ")
  if not ok then lines[#lines + 1] = "error: "..tostring(err) end
  for _, line in ipairs(lines) do print("|cFFFFD100FDT where:|r "..line) end
end

local function selectPlayerSublevel(dungeonIdx)
  local transform = getTransform(dungeonIdx)
  if not transform or not MDT.GetCurrentSubLevel then return end
  local current = MDT:GetCurrentSubLevel()
  local _, _, sublevel = unitMapPosition("player", transform, current)
  if sublevel and sublevel ~= current then
    MDT:SetCurrentSubLevel(sublevel)
    MDT:UpdateMap()
  end
end

local function openDungeonMap(dungeonIdx)
  -- the main frame is built asynchronously on first show: switch dungeon only once it exists
  if MDT.ShowInterface then MDT:ShowInterface(true) end
  local function afterShown()
    if not MDT.main_frame then return end
    MDT:UpdateToDungeon(dungeonIdx)
    MDT:SetDungeonList(nil, dungeonIdx)
    if not overlay and not createOverlay() then return end
    selectPlayerSublevel(dungeonIdx)
    MDT:WorldMapOpen_UpdateMarkers()
  end
  C_Timer.After(0.2, function()
    if MDT.RunAfterFramesInitialized then MDT:RunAfterFramesInitialized(afterShown) else afterShown() end
  end)
end

local function onWorldMapShown()
  local db = getDB()
  if not db or not db.openFdtOnWorldMap then return end
  local dungeonIdx = currentDungeonIdx()
  if not dungeonIdx then return end
  if not InCombatLockdown() then HideUIPanel(WorldMapFrame) end
  -- the map keybind toggles: pressing it while FDT is open closes FDT
  if MDT.main_frame and MDT.main_frame:IsShown() then
    MDT:HideInterface()
    return
  end
  openDungeonMap(dungeonIdx)
end

local hooked = false
local function hookWorldMap()
  if hooked or not WorldMapFrame then return end
  hooked = true
  WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, onWorldMapShown) end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
  if event == "PLAYER_LOGIN" and MDT.RunAfterFramesInitialized then
    MDT:RunAfterFramesInitialized(function() if not overlay then createOverlay() end end)
  end
  if event == "PLAYER_LOGIN" or addonName == "Blizzard_WorldMap" then hookWorldMap() end
  if hooked then self:UnregisterAllEvents() end
end)
