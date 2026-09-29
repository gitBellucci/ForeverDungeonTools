-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
local _, MDT = ...
local L = MDT.L
local AceGUI = LibStub("AceGUI-3.0")

local ContentTypes = {
  LFR = "lfr",
  NORMAL = "normal",
  HEROIC = "heroic",
  MYTHIC = "mythic",
  MYTHIC_DUNGEON = "mythic_dungeon",
  MYTHIC_PLUS = "mythic_plus",
}

local combatLoggingFrame

local function getSettings()
  return MDT:GetDB().combatLogging
end

local function setDifficultyCheckboxesDisabled(checkboxes, disabled)
  for _, checkbox in ipairs(checkboxes) do
    checkbox:SetDisabled(disabled)
  end
end

local function addCheckbox(parent, label, value, relativeWidth, onChanged)
  local checkbox = AceGUI:Create("CheckBox")
  checkbox:SetLabel(label)
  checkbox:SetRelativeWidth(relativeWidth)
  checkbox:SetValue(value)
  checkbox:SetCallback("OnValueChanged", function(_, _, newValue)
    onChanged(newValue)
  end)
  parent:AddChild(checkbox)
  return checkbox
end

local function createCombatLoggingFrame()
  local mainFrame = MDT.main_frame
  local contentParent = mainFrame.sectionContentFrames.combatLogging

  local frame = AceGUI:Create("SimpleGroup")
  frame.frame:SetParent(contentParent)
  frame.frame:SetFrameStrata("HIGH")
  frame.frame:SetFrameLevel(3)
  frame:SetWidth(555)
  frame:SetHeight(480)
  frame:SetLayout("Flow")
  frame.frame:ClearAllPoints()
  frame.frame:SetPoint("TOP", contentParent, "TOP", 0, -20)
  MDT:RegisterMainFrameDragHandle(frame.frame, mainFrame)

  frame.frame:Hide()
  MDT.main_frame.CombatLoggingFrame = frame
  return frame
end

function MDT:CombatLogging_Open()
  if self:GetCurrentSection() ~= "combatLogging" then
    self:SetCurrentSection("combatLogging")
    return
  end

  combatLoggingFrame = combatLoggingFrame or createCombatLoggingFrame()
  local frame = combatLoggingFrame
  local settings = getSettings()

  MDT:HideAllDialogs()
  frame:ReleaseChildren()

  local difficultyCheckboxes = {}

  local heading = AceGUI:Create("Heading")
  heading:SetText(L["Combat Logging"])
  heading:SetFullWidth(true)
  frame:AddChild(heading)

  local overview = AceGUI:Create("Label")
  overview:SetText(L["combatLoggingOverview"])
  overview:SetFullWidth(true)
  overview:SetColor(0.82, 0.82, 0.82)
  frame:AddChild(overview)

  local enabledCheckbox = addCheckbox(frame, L["combatLoggingEnable"], settings.enabled, 1, function(value)
    self:CombatLogging_SetEnabled(value)
    setDifficultyCheckboxesDisabled(difficultyCheckboxes, not value)
  end)
  enabledCheckbox:SetFullWidth(true)

  local raidRow = AceGUI:Create("SimpleGroup")
  raidRow:SetLayout("Flow")
  raidRow:SetFullWidth(true)
  raidRow:SetHeight(28)
  frame:AddChild(raidRow)

  table.insert(difficultyCheckboxes, addCheckbox(raidRow, L["combatLoggingLFR"], settings.content.lfr, 0.25, function(value)
    self:CombatLogging_SetContentEnabled(ContentTypes.LFR, value)
  end))
  table.insert(difficultyCheckboxes, addCheckbox(raidRow, L["combatLoggingNormal"], settings.content.normal, 0.25, function(value)
    self:CombatLogging_SetContentEnabled(ContentTypes.NORMAL, value)
  end))
  table.insert(difficultyCheckboxes, addCheckbox(raidRow, L["combatLoggingHeroic"], settings.content.heroic, 0.25, function(value)
    self:CombatLogging_SetContentEnabled(ContentTypes.HEROIC, value)
  end))
  table.insert(difficultyCheckboxes, addCheckbox(raidRow, L["combatLoggingMythic"], settings.content.mythic, 0.25, function(value)
    self:CombatLogging_SetContentEnabled(ContentTypes.MYTHIC, value)
  end))

  local dungeonRow = AceGUI:Create("SimpleGroup")
  dungeonRow:SetLayout("Flow")
  dungeonRow:SetFullWidth(true)
  dungeonRow:SetHeight(28)
  frame:AddChild(dungeonRow)

  table.insert(difficultyCheckboxes, addCheckbox(dungeonRow, L["combatLoggingMythicDungeon"], settings.content.mythic_dungeon, 0.5, function(value)
    self:CombatLogging_SetContentEnabled(ContentTypes.MYTHIC_DUNGEON, value)
  end))
  table.insert(difficultyCheckboxes, addCheckbox(dungeonRow, L["combatLoggingMythicPlus"], settings.content.mythic_plus, 0.5, function(value)
    self:CombatLogging_SetContentEnabled(ContentTypes.MYTHIC_PLUS, value)
  end))

  local advancedNote = AceGUI:Create("Label")
  advancedNote:SetText(L["combatLoggingAdvancedNote"])
  advancedNote:SetFullWidth(true)
  advancedNote:SetColor(0.82, 0.82, 0.82)
  frame:AddChild(advancedNote)

  setDifficultyCheckboxesDisabled(difficultyCheckboxes, settings.enabled ~= true)

  local trackerHeading = AceGUI:Create("Heading")
  trackerHeading:SetText(L["fdtTrackerTitle"])
  trackerHeading:SetFullWidth(true)
  frame:AddChild(trackerHeading)

  local trackerOverview = AceGUI:Create("Label")
  trackerOverview:SetText(L["fdtTrackerOverview"])
  trackerOverview:SetFullWidth(true)
  trackerOverview:SetColor(0.82, 0.82, 0.82)
  frame:AddChild(trackerOverview)

  local trackerStatus = AceGUI:Create("Label")
  local function refreshTrackerStatus()
    local instances, npcs, pulls = self:MobTracker_GetSummary()
    trackerStatus:SetText(string.format(L["fdtTrackerStatus"],
      self:MobTracker_IsEnabled() and L["fdtTrackerOn"] or L["fdtTrackerOff"], instances, npcs, pulls))
  end

  local trackerCheckbox = addCheckbox(frame, L["fdtTrackerEnable"], self:MobTracker_IsEnabled(), 1, function(value)
    self:MobTracker_SetEnabled(value)
    refreshTrackerStatus()
  end)
  trackerCheckbox:SetFullWidth(true)

  trackerStatus:SetFullWidth(true)
  frame:AddChild(trackerStatus)
  refreshTrackerStatus()

  local applyButton = AceGUI:Create("Button")
  applyButton:SetText(L["fdtTrackerApply"])
  applyButton:SetWidth(200)
  applyButton:SetCallback("OnClick", function()
    self:MobTracker_Command("apply")
    refreshTrackerStatus()
  end)
  frame:AddChild(applyButton)

  frame.frame:Show()
  frame:DoLayout()
end

MDT:RegisterNavigationSection({
  key = "combatLogging",
  name = L["Combat Logging"],
  tooltip = L["Combat Logging"],
  texCoords = { 0.75, 1, 0, 0.25 },
  onShow = function()
    MDT:CombatLogging_Open()
  end,
})
