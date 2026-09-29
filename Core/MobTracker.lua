-- Added for ForeverDungeonTools (Classic Forever Beta) on 2026-09-29.
-- Part of a modified MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
--
-- Opt-in mob tracker: records the NPCs met in dungeons (npc id, name, level, health,
-- display id, spells, pulls and player-relative positions) into FDTTrackerDB so the
-- Forever dungeon data can be completed from real runs.
local _, MDT = ...
-- MDT.L is replaced by the UI bootstrap (loaded after this file), so look strings up lazily
local L = setmetatable({}, { __index = function(_, key) return MDT.L[key] end })

local SCAN_INTERVAL = 0.5
local NEAR_INTERACT_INDEX = 3 -- CheckInteractDistance "duel" range, about 10 yards
local MERGE_DISTANCE = 12 -- map units, merges the same spawn seen in different runs
local MAX_ENTRANCES = 10
local RUN_CONTINUE_SECONDS = 30 * 60

local tracker = {
  active = false,
  instanceId = nil,
  runId = nil,
  pull = nil,
  positionWarned = false,
}
local frame = CreateFrame("Frame")
local modelFrame
local displayIdTries = {}
local MAX_DISPLAY_TRIES = 6

local function settings()
  return MDT:GetDB().mobTracker
end

local function store()
  if type(FDTTrackerDB) ~= "table" then FDTTrackerDB = {} end
  FDTTrackerDB.version = 1
  FDTTrackerDB.instances = FDTTrackerDB.instances or {}
  FDTTrackerDB.spellDispel = FDTTrackerDB.spellDispel or {}
  return FDTTrackerDB
end

local function printMsg(msg)
  print("|cFFDDFF4FFDT|r "..msg)
end

-- The client returns unit data as secret values inside instances: they can't be read, compared or stored.
local issecretvalue = issecretvalue or function() return false end
local secretWarned = false
local function readable(...)
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then
      if not secretWarned then
        secretWarned = true
        printMsg(L["fdtTrackerSecretData"])
      end
      return
    end
  end
  return ...
end

-- Some APIs refuse the call outright when their data is secret (e.g. auras): stop that feature for
-- the current instance instead of erroring on every event; other errors are still reported.
local blockedFeatures = {}
local function guarded(feature, fn, ...)
  if blockedFeatures[feature] then return end
  local ok, err = pcall(fn, ...)
  if ok then return end
  if type(err) == "string" and err:lower():find("secret") then
    blockedFeatures[feature] = true
    if not secretWarned then
      secretWarned = true
      printMsg(L["fdtTrackerSecretData"])
    end
  else
    geterrorhandler()(err)
  end
end

local function parseCreatureGUID(guid)
  guid = readable(guid)
  if not guid then return end
  local unitType, _, _, _, _, npcId = strsplit("-", guid)
  if unitType ~= "Creature" and unitType ~= "Vehicle" then return end
  return tonumber(npcId)
end

-- npc id of a unit, and its GUID when readable; with a secret GUID the npc is matched by name against
-- the current dungeon's enemies (unknown names are keyed "name:<name>"), without per-spawn data
local function identifyUnit(unit)
  local guid = readable(UnitGUID(unit))
  local npcId = parseCreatureGUID(guid)
  if npcId then return npcId, guid end
  if guid then return end
  local name = readable(UnitName(unit))
  if not name or name == "" then return end
  local dungeonIdx = MDT.instanceIdToDungeonIdx and MDT.instanceIdToDungeonIdx[tracker.instanceId]
  for _, enemy in ipairs(dungeonIdx and MDT.dungeonEnemies[dungeonIdx] or {}) do
    if enemy.name == name then return enemy.id end
  end
  return "name:"..name
end

local function playerPosition()
  local posY, posX, posZ = readable(UnitPosition("player"))
  if not posY then return end
  return { x = posX, y = posY, z = posZ }
end

local function currentInstance()
  local instanceId = tracker.instanceId
  if not instanceId then return end
  local instances = store().instances
  local inst = instances[instanceId]
  if not inst then
    local name = GetInstanceInfo()
    inst = { name = name, npcs = {}, pulls = {}, entrances = {}, runs = 0 }
    instances[instanceId] = inst
  end
  return inst
end

local function getNpc(npcId, name)
  local inst = currentInstance()
  if not inst then return end
  local npc = inst.npcs[npcId]
  if not npc then
    npc = { name = name, spells = {}, units = {} }
    inst.npcs[npcId] = npc
  elseif name and not npc.name then
    npc.name = name
  end
  return npc
end

local function getUnitRecord(npc, guid)
  local unit = npc.units[guid]
  if not unit then
    unit = { run = tracker.runId }
    npc.units[guid] = unit
  end
  return unit
end

local function readDisplayId(unit)
  if not modelFrame then
    modelFrame = CreateFrame("PlayerModel", nil, UIParent)
    modelFrame:SetSize(1, 1)
    modelFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    modelFrame:SetAlpha(0)
  end
  if not modelFrame.GetDisplayInfo then return end
  local ok, displayId = pcall(function()
    modelFrame:ClearModel()
    modelFrame:SetUnit(unit)
    return modelFrame.GetDisplayInfo and modelFrame:GetDisplayInfo()
  end)
  displayId = ok and readable(displayId)
  if type(displayId) == "number" and displayId > 0 then return displayId end
end

local function isNear(unit)
  if InCombatLockdown() then return false end
  local ok, near = pcall(CheckInteractDistance, unit, NEAR_INTERACT_INDEX)
  return ok and readable(near) and true or false
end

local function recordSample(unitRecord, kind)
  if unitRecord[kind] then return end
  local pos = playerPosition()
  if pos then
    pos.t = time()
    unitRecord[kind] = pos
  end
end

local function observeUnit(unit)
  if not UnitExists(unit) then return end
  local isPlayer, isDead = UnitIsPlayer(unit), UnitIsDead(unit)
  if issecretvalue(isPlayer) or issecretvalue(isDead) or isPlayer or isDead then return end
  local npcId, guid = identifyUnit(unit)
  if not npcId or not readable(UnitCanAttack("player", unit)) then return end
  local npc = getNpc(npcId, readable(UnitName(unit)))
  if not npc then return end
  npc.level = readable(UnitLevel(unit)) or npc.level
  npc.classification = readable(UnitClassification(unit)) or npc.classification
  npc.creatureType = readable(UnitCreatureType(unit)) or npc.creatureType
  npc.family = readable(UnitCreatureFamily(unit)) or npc.family
  local maxHealth = readable(UnitHealthMax(unit))
  if maxHealth and maxHealth > (npc.health or 0) then npc.health = maxHealth end
  if not npc.displayId and (displayIdTries[npcId] or 0) < MAX_DISPLAY_TRIES then
    displayIdTries[npcId] = (displayIdTries[npcId] or 0) + 1
    npc.displayId = readDisplayId(unit)
  end
  if unit:find("^boss") then npc.isBoss = true end

  if not guid then return end
  local unitRecord = getUnitRecord(npc, guid)
  local inCombat = UnitAffectingCombat(unit)
  if not issecretvalue(inCombat) and not inCombat and not unitRecord.engaged then
    recordSample(unitRecord, "seen")
    if isNear(unit) then recordSample(unitRecord, "near") end
  end
end

local function getSpell(npc, spellId, spellName)
  local key = (spellId and spellId > 0) and spellId or ("name:"..tostring(spellName))
  local spell = npc.spells[key]
  if not spell then
    spell = { name = spellName, count = 0, events = {} }
    npc.spells[key] = spell
    if spellId and spellId > 0 then C_Spell.RequestLoadSpellData(spellId) end
  end
  return spell
end

local function addToPull(guid, npcId)
  local pull = tracker.pull
  if not pull or pull.npcs[guid] then return end
  pull.npcs[guid] = npcId
  local inst = currentInstance()
  local npc = inst and inst.npcs[npcId]
  if npc then
    local unitRecord = getUnitRecord(npc, guid)
    unitRecord.engaged = true
    unitRecord.pull = unitRecord.pull or pull.index
  end
end

local function onCastSucceeded(unit, spellId)
  spellId = readable(spellId)
  if not unit or not spellId or unit:find("^party") or unit == "player" or unit == "pet" then return end
  local npcId = identifyUnit(unit)
  if not npcId or not readable(UnitCanAttack("player", unit)) then return end
  local npc = getNpc(npcId, readable(UnitName(unit)))
  if not npc then return end
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = readable((info and info.name) or (GetSpellInfo and GetSpellInfo(spellId)))
  local spell = getSpell(npc, spellId, spellName)
  spell.count = spell.count + 1
  spell.events.cast = true
end

local function addUnitToPull(unit)
  if not tracker.pull or not UnitExists(unit) or not readable(UnitAffectingCombat(unit))
      or not readable(UnitCanAttack("player", unit)) then
    return
  end
  local npcId, guid = identifyUnit(unit)
  if npcId and guid then addToPull(guid, npcId) end
end

local function onCastStart(unit, spellId, isChannel)
  local npcId = identifyUnit(unit)
  if not npcId or not readable(UnitCanAttack("player", unit)) then return end
  local npc = getNpc(npcId, readable(UnitName(unit)))
  if not npc then return end
  local info = { readable((isChannel and UnitChannelInfo or UnitCastingInfo)(unit)) }
  local spellName = info[1]
  spellId = readable(spellId) or info[#info]
  if not spellName then return end
  local spell = getSpell(npc, spellId, spellName)
  spell.events[isChannel and "channel" or "castStart"] = true
  if info[4] and info[5] then spell.castTime = info[5] - info[4] end
  -- retail-style signature: name, text, texture, start, end, tradeskill, castID|nil, notInterruptible, spellId
  local notInterruptible = isChannel and info[7] or info[8]
  if type(notInterruptible) == "boolean" then
    if notInterruptible then spell.notInterruptible = true else spell.interruptibleCast = true end
  end
end

local function scanAuras(unit)
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
  local dispel = store().spellDispel
  for i = 1, 40 do
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
    if not aura then break end
    local spellId, dispelName, auraName, sourceUnit = readable(aura.spellId, aura.dispelName, aura.name, aura.sourceUnit)
    if spellId and dispelName and dispelName ~= "" then
      dispel[spellId] = dispelName
      local sourceNpc = sourceUnit and identifyUnit(sourceUnit)
      if sourceNpc then
        local npc = getNpc(sourceNpc, readable(UnitName(sourceUnit)))
        if npc then getSpell(npc, spellId, auraName).dispel = dispelName end
      end
    end
  end
end

local function onLootOpened()
  if not GetLootSourceInfo then return end
  local inst = currentInstance()
  if not inst then return end
  for slot = 1, GetNumLootItems() do
    local sources = { GetLootSourceInfo(slot) }
    for i = 1, #sources, 2 do
      local guid = sources[i]
      local npcId = parseCreatureGUID(guid)
      local npc = npcId and inst.npcs[npcId]
      if npc then recordSample(getUnitRecord(npc, guid), "death") end
    end
  end
end

---------------------------------------------------------------------------
-- Kill log for instances that hide unit identity and positions: mob names come from the
-- kill chat messages (experience gain, "X dies.", quest progress), the level from the unit
-- that just died, the place from the subzone name, the pull from the combat session.
---------------------------------------------------------------------------
local function formatToPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return end
  local pattern = fmt:gsub("%%%d?%$?", "%%"):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  pattern = pattern:gsub("%%s", "(.+)"):gsub("%%d", "%%d+")
  return "^"..pattern.."$"
end

local killPatterns = {}
local function buildKillPatterns()
  wipe(killPatterns)
  local sources = {
    { "xp", COMBATLOG_XPGAIN_FIRSTPERSON }, { "xp", COMBATLOG_XPGAIN_EXHAUSTION1 },
    { "xp", COMBATLOG_XPGAIN_EXHAUSTION2 }, { "xp", COMBATLOG_XPGAIN_EXHAUSTION4 },
    { "xp", COMBATLOG_XPGAIN_EXHAUSTION5 }, { "xp", COMBATLOG_XPGAIN_FIRSTPERSON_RAID },
    { "xp", COMBATLOG_XPGAIN_FIRSTPERSON_GROUP },
    { "death", UNITDIESOTHER },
    { "quest", ERR_QUEST_ADD_KILL_SII }, { "quest", QUEST_MONSTERS_KILLED },
  }
  for _, source in ipairs(sources) do
    local pattern = formatToPattern(source[2])
    if pattern then killPatterns[#killPatterns + 1] = { kind = source[1], pattern = pattern } end
  end
  -- the xp line may carry a trailing bonus text: also accept it as a prefix match
  for _, source in ipairs(sources) do
    if source[1] == "xp" and type(source[2]) == "string" then
      local prefix = source[2]:match("^(.-%%s[^,]*,)")
      local pattern = prefix and formatToPattern(prefix)
      if pattern then killPatterns[#killPatterns + 1] = { kind = "xp", pattern = pattern:sub(1, -2) } end
    end
  end
end

local function parseKillMessage(msg)
  msg = readable(msg)
  if type(msg) ~= "string" then return end
  if #killPatterns == 0 then buildKillPatterns() end
  for _, entry in ipairs(killPatterns) do
    local name = msg:match(entry.pattern)
    if name and name ~= "" then return name, entry.kind end
  end
end

local function currentSubzone()
  local subzone = readable(GetSubZoneText and GetSubZoneText())
  if not subzone or subzone == "" then subzone = readable(GetMinimapZoneText and GetMinimapZoneText()) end
  local zone = readable(GetZoneText and GetZoneText())
  if not subzone or subzone == "" or subzone == zone then return "" end
  return subzone
end

-- each source counts the same deaths: the kill count is the highest of them
local function killCountRaw(kill)
  return math.max(kill.xp or 0, kill.death or 0, kill.quest or 0, kill.dead or 0)
end

local function debugEvent(line)
  local log = store()
  log.debugLog = log.debugLog or {}
  tinsert(log.debugLog, date("%H:%M:%S ")..line)
  while #log.debugLog > 600 do table.remove(log.debugLog, 1) end
end

local function getZonePull()
  local inst = currentInstance()
  if not inst then return end
  inst.zonePulls = inst.zonePulls or {}
  if not tracker.zonePull then
    tracker.zonePull = { run = tracker.runId, t = time(), subzone = currentSubzone(), kills = {} }
    tinsert(inst.zonePulls, tracker.zonePull)
  end
  if not tracker.pull then
    -- kill outside of a combat session (e.g. xp message after leaving combat): close it shortly
    local zonePull = tracker.zonePull
    C_Timer.After(3, function() if tracker.zonePull == zonePull and not tracker.pull then tracker.zonePull = nil end end)
  end
  return tracker.zonePull
end

local function addKill(name, kind, info)
  local pull = getZonePull()
  if not pull then return end
  local inst = currentInstance()
  if inst then inst.lastActivity = time() end
  local subzone = currentSubzone()
  local key = name.."\t"..subzone
  local kill = pull.kills[key]
  if not kill then
    kill = { name = name, subzone = subzone }
    pull.kills[key] = kill
  end
  kill[kind] = (kill[kind] or 0) + 1
  if info then
    kill.level = info.level or kill.level
    kill.classification = info.classification or kill.classification
    if info.isBoss then kill.isBoss = true end
    if info.placeholder then kill.placeholder = true end
  end
  return kill, pull, key
end

-- name of the enemy targeted by the player's last spell (UNIT_SPELLCAST_SENT carries it as text)
local castTarget
local function isGroupMemberName(name)
  if name == readable(UnitName("player")) then return true end
  for i = 1, 4 do
    if name == readable(UnitName("party"..i)) then return true end
  end
  for i = 1, 40 do
    if name == readable(UnitName("raid"..i)) then return true end
  end
end

local function onSpellcastSent(unit, target)
  if unit ~= "player" then return end
  target = readable(target)
  if type(target) ~= "string" or target == "" or isGroupMemberName(target) then return end
  castTarget = { name = target, t = GetTime() }
end

-- deaths seen on the target / nameplates: counted even when no kill message names the mob
local deadTokens = {}
local lastDeath
local function noteUnitDeath(unit)
  if deadTokens[unit] then return end
  local isDead = UnitIsDead(unit)
  if issecretvalue(isDead) or not isDead then return end
  local isPlayer = UnitIsPlayer(unit)
  if issecretvalue(isPlayer) or isPlayer then return end
  if not readable(UnitCanAttack("player", unit)) then return end
  deadTokens[unit] = true
  local now = GetTime()
  local info = {
    level = readable(UnitLevel(unit)),
    classification = readable(UnitClassification(unit)),
    isBoss = readable(UnitIsBossMob and UnitIsBossMob(unit)),
  }
  -- the same death seen through the target frame and the nameplate
  if lastDeath and now - lastDeath.t < 0.5 and lastDeath.unit ~= unit and lastDeath.level == info.level then return end
  local name = castTarget and now - castTarget.t < 30 and castTarget.name
  local inst = currentInstance()
  local hint = inst and inst.nameHints and inst.nameHints[string.format("%s:%s:%s", tostring(info.level),
    tostring(info.classification), currentSubzone())]
  name = name or hint
  if not name then
    name = string.format(L["fdtTrackerUnknownMob"], info.level or 0)
    info.placeholder = true
  end
  local kill, pull, key = addKill(name, "dead", info)
  lastDeath = { t = now, unit = unit, level = info.level, info = info, kill = kill, pull = pull, key = key }
  debugEvent(string.format("death %s level=%s class=%s named=%s subzone=%s", unit, tostring(info.level),
    tostring(info.classification), tostring(name), currentSubzone()))
end

local function onUnitTokenReset(unit)
  if not unit then return end
  local isDead = UnitIsDead(unit)
  deadTokens[unit] = (not issecretvalue(isDead) and isDead) and true or nil
end

local function onKillMessage(msg)
  local name, kind = parseKillMessage(msg)
  if not name then return end
  local recent = lastDeath and GetTime() - lastDeath.t < 2 and lastDeath
  if recent and recent.kill and recent.kill.name ~= name and (recent.kill.dead or 0) > 0 then
    -- the kill message names the mob that just died: move that death to the right name
    recent.kill.dead = recent.kill.dead - 1
    if recent.kill.dead == 0 and killCountRaw(recent.kill) == 0 then recent.pull.kills[recent.key] = nil end
    local info = { level = recent.info.level, classification = recent.info.classification, isBoss = recent.info.isBoss }
    local kill, pull, key = addKill(name, "dead", info)
    recent.kill, recent.pull, recent.key = kill, pull, key
  end
  addKill(name, kind, recent and recent.info and {
    level = recent.info.level, classification = recent.info.classification, isBoss = recent.info.isBoss,
  })
end

local function startPull()
  local inst = currentInstance()
  if not inst then return end
  local pos = playerPosition()
  tracker.pull = { index = #inst.pulls + 1, run = tracker.runId, t = time(), npcs = {}, pos = pos }
  tracker.zonePull = nil
end

local function endPull()
  local pull = tracker.pull
  tracker.pull = nil
  -- kill messages can arrive just after combat ends
  local zonePull = tracker.zonePull
  C_Timer.After(2, function() if tracker.zonePull == zonePull and not tracker.pull then tracker.zonePull = nil end end)
  local inst = currentInstance()
  if not pull or not inst or not next(pull.npcs) then return end
  inst.pulls[pull.index] = pull
end

local function scanUnits()
  if not tracker.active then return end
  observeUnit("target")
  observeUnit("mouseover")
  observeUnit("focus")
  for i = 1, 5 do observeUnit("boss"..i) end
  for i = 1, 40 do observeUnit("nameplate"..i) end
  if tracker.pull then
    addUnitToPull("target")
    addUnitToPull("focus")
    for i = 1, 5 do addUnitToPull("boss"..i) end
    for i = 1, 40 do addUnitToPull("nameplate"..i) end
  end
end

local function fillSpellDescriptions()
  local getDescription = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
  if not getDescription then return end
  for _, inst in pairs(store().instances) do
    for _, npc in pairs(inst.npcs) do
      for key, spell in pairs(npc.spells) do
        if type(key) == "number" and not spell.desc then
          local ok, desc = pcall(getDescription, key)
          desc = ok and readable(desc)
          if desc and desc ~= "" then spell.desc = desc end
        end
      end
    end
  end
end

local function shouldTrack()
  if not settings().enabled then return end
  local _, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo()
  if instanceType ~= "party" and not (settings().allInstances and instanceType ~= "none") then return end
  return instanceId
end

local ticker
local function evaluate()
  local instanceId = shouldTrack()
  if instanceId == tracker.instanceId and tracker.active == (instanceId ~= nil) then return end
  tracker.instanceId = instanceId
  tracker.active = instanceId ~= nil
  tracker.pull = nil
  if ticker then ticker:Cancel(); ticker = nil end
  if not tracker.active then return end

  wipe(blockedFeatures)
  local inst = currentInstance()
  -- a /reload or reconnect inside the dungeon continues the same run
  if inst.lastRunId and inst.lastActivity and time() - inst.lastActivity < RUN_CONTINUE_SECONDS then
    tracker.runId = inst.lastRunId
  else
    tracker.runId = time()
    inst.runs = (inst.runs or 0) + 1
  end
  inst.lastRunId, inst.lastActivity = tracker.runId, time()
  inst.dungeonIdx = MDT.instanceIdToDungeonIdx and MDT.instanceIdToDungeonIdx[instanceId]
  local pos = playerPosition()
  inst.positionAvailable = pos ~= nil
  if pos and #inst.entrances < MAX_ENTRANCES then tinsert(inst.entrances, pos) end
  printMsg(string.format(L["fdtTrackerRecording"], inst.name or tostring(instanceId)))
  if not pos and not tracker.positionWarned then
    tracker.positionWarned = true
    printMsg(L["fdtTrackerNoPosition"])
  end
  ticker = C_Timer.NewTicker(SCAN_INTERVAL, function()
    guarded("units", scanUnits)
    guarded("deaths", function()
      noteUnitDeath("target")
      for i = 1, 40 do
        if UnitExists("nameplate"..i) then noteUnitDeath("nameplate"..i) end
      end
    end)
  end)
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(1, evaluate)
    return
  elseif event == "PLAYER_LOGIN" then
    if settings().autoApply then MDT:MobTracker_Apply(true) end
    return
  elseif event == "PLAYER_LOGOUT" then
    fillSpellDescriptions()
    return
  end
  if not tracker.active then return end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellId = ...
    guarded("casts", onCastSucceeded, unit, spellId)
  elseif event == "UNIT_SPELLCAST_START" then
    local unit, _, spellId = ...
    guarded("casts", onCastStart, unit, spellId, false)
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    local unit, _, spellId = ...
    guarded("casts", onCastStart, unit, spellId, true)
  elseif event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" or (unit and unit:find("^party%d$")) then guarded("auras", scanAuras, unit) end
  elseif event == "PLAYER_REGEN_DISABLED" then
    startPull()
  elseif event == "PLAYER_REGEN_ENABLED" then
    endPull()
  elseif event == "LOOT_OPENED" then
    guarded("loot", onLootOpened)
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "UPDATE_MOUSEOVER_UNIT" then
    if event == "NAME_PLATE_UNIT_ADDED" then onUnitTokenReset((...)) end
    guarded("units", observeUnit, event == "NAME_PLATE_UNIT_ADDED" and (...) or "mouseover")
  elseif event == "PLAYER_TARGET_CHANGED" then
    -- a corpse selected to loot it is not a new death
    local isDead = UnitIsDead("target")
    deadTokens.target = (not issecretvalue(isDead) and isDead) and true or nil
    guarded("units", observeUnit, "target")
  elseif event == "UNIT_SPELLCAST_SENT" then
    guarded("names", onSpellcastSent, ...)
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" or event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
    guarded("kills", onKillMessage, (...))
  elseif event == "UI_INFO_MESSAGE" then
    guarded("kills", onKillMessage, select(2, ...))
  elseif event == "UNIT_HEALTH" or event == "NAME_PLATE_UNIT_REMOVED" then
    local unit = ...
    if unit == "target" or unit == "focus" or (unit and unit:find("^nameplate")) then guarded("deaths", noteUnitDeath, unit) end
  end
end)

-- COMBAT_LOG_EVENT_UNFILTERED is protected on the Classic Forever client (ADDON_ACTION_FORBIDDEN):
-- casts, auras and pulls come from unit events and nameplates instead.
local trackedEvents = {
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "LOOT_OPENED",
  "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
  "UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
  "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_HOSTILE_DEATH", "UI_INFO_MESSAGE",
  "UNIT_HEALTH", "NAME_PLATE_UNIT_REMOVED", "UNIT_SPELLCAST_SENT",
}
local eventsRegistered = false
local function registerTrackingEvents(enabled)
  if enabled == eventsRegistered then return end
  eventsRegistered = enabled
  local method = enabled and "RegisterEvent" or "UnregisterEvent"
  for _, event in ipairs(trackedEvents) do pcall(frame[method], frame, event) end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

function MDT:MobTracker_IsEnabled()
  return settings().enabled == true
end

function MDT:MobTracker_SetEnabled(enabled)
  settings().enabled = enabled and true or false
  registerTrackingEvents(settings().enabled)
  evaluate()
  printMsg(enabled and L["fdtTrackerEnabled"] or L["fdtTrackerDisabled"])
end

function MDT:MobTracker_GetSummary()
  local instances, npcs, pulls = 0, 0, 0
  for _, inst in pairs(store().instances) do
    instances = instances + 1
    local names = {}
    for id, npc in pairs(inst.npcs) do names[npc.name or id] = true end
    for _, pull in ipairs(inst.zonePulls or {}) do
      for _, kill in pairs(pull.kills) do names[kill.name] = true end
    end
    for _ in pairs(names) do npcs = npcs + 1 end
    pulls = pulls + #inst.pulls + #(inst.zonePulls or {})
  end
  return instances, npcs, pulls
end

function MDT:MobTracker_Reset()
  FDTTrackerDB = nil
  store()
  printMsg(L["fdtTrackerReset"])
end

---------------------------------------------------------------------------
-- Applying logged data to the dungeon tables
---------------------------------------------------------------------------

local function median(values)
  if #values == 0 then return end
  table.sort(values)
  return values[math.ceil(#values / 2)]
end

local function medianPosition(samples)
  local xs, ys = {}, {}
  for _, s in ipairs(samples) do
    xs[#xs + 1] = s.x
    ys[#ys + 1] = s.y
  end
  if #xs == 0 then return end
  return { x = median(xs), y = median(ys) }
end

local function unitPosition(unitRecord)
  return unitRecord.near or unitRecord.death or unitRecord.seen
end

-- least squares affine fit world (x, y) -> map (mx, my); needs 3+ non collinear anchors
local function solveAffine(pairsList)
  if #pairsList < 3 then return end
  local sxx, sxy, syy, sx, sy, n = 0, 0, 0, 0, 0, #pairsList
  local bx, by = { 0, 0, 0 }, { 0, 0, 0 }
  for _, p in ipairs(pairsList) do
    local x, y = p.world.x, p.world.y
    sxx, sxy, syy, sx, sy = sxx + x * x, sxy + x * y, syy + y * y, sx + x, sy + y
    bx[1], bx[2], bx[3] = bx[1] + x * p.map.x, bx[2] + y * p.map.x, bx[3] + p.map.x
    by[1], by[2], by[3] = by[1] + x * p.map.y, by[2] + y * p.map.y, by[3] + p.map.y
  end
  local m = { { sxx, sxy, sx }, { sxy, syy, sy }, { sx, sy, n } }
  local function det3(a)
    return a[1][1] * (a[2][2] * a[3][3] - a[2][3] * a[3][2])
        - a[1][2] * (a[2][1] * a[3][3] - a[2][3] * a[3][1])
        + a[1][3] * (a[2][1] * a[3][2] - a[2][2] * a[3][1])
  end
  local d = det3(m)
  if math.abs(d) < 1e-6 then return end
  local function solve(b)
    local out = {}
    for col = 1, 3 do
      local mc = { { m[1][1], m[1][2], m[1][3] }, { m[2][1], m[2][2], m[2][3] }, { m[3][1], m[3][2], m[3][3] } }
      for row = 1, 3 do mc[row][col] = b[row] end
      out[col] = det3(mc) / d
    end
    return out
  end
  local cx, cy = solve(bx), solve(by)
  return function(pos)
    return cx[1] * pos.x + cx[2] * pos.y + cx[3], cy[1] * pos.x + cy[2] * pos.y + cy[3]
  end
end

local function buildTransform(dungeonIdx, inst)
  local anchors = {}
  for _, enemy in ipairs(MDT.dungeonEnemies[dungeonIdx]) do
    local npc = enemy.isBoss and not enemy.fdtTracked and inst.npcs[enemy.id]
    local clone = npc and enemy.clones and enemy.clones[1]
    if clone then
      local samples = {}
      for _, unitRecord in pairs(npc.units) do
        local pos = unitRecord.death or unitRecord.near
        if pos then samples[#samples + 1] = pos end
      end
      local world = medianPosition(samples)
      if world then anchors[#anchors + 1] = { world = world, map = { x = clone.x, y = clone.y } } end
    end
  end
  local pois = MDT.mapPOIs[dungeonIdx] and MDT.mapPOIs[dungeonIdx][1]
  for _, poi in ipairs(pois or {}) do
    if poi.type == "dungeonEntrance" then
      local world = medianPosition(inst.entrances or {})
      if world then anchors[#anchors + 1] = { world = world, map = { x = poi.x, y = poi.y } } end
      break
    end
  end
  return solveAffine(anchors), #anchors
end

-- world -> map transform calibrated from recorded runs (boss kills + entrance), for dungeons with no built-in one
function MDT:MobTracker_GetWorldTransform(dungeonIdx)
  local instanceId = select(8, GetInstanceInfo())
  local inst = instanceId and FDTTrackerDB and store().instances[instanceId]
  if not inst or not MDT.dungeonEnemies[dungeonIdx] then return end
  return (buildTransform(dungeonIdx, inst))
end

local function mergeSpells(enemy, npc)
  local dispel = store().spellDispel
  for key, spell in pairs(npc.spells) do
    if type(key) == "number" and C_Spell.GetSpellInfo(key) then
      enemy.spells = enemy.spells or {}
      local target = enemy.spells[key] or {}
      if spell.interrupted or spell.interruptibleCast then target.interruptible = true end
      local dispelName = spell.dispel or dispel[key]
      if dispelName == "Magic" then target.magic = true
      elseif dispelName == "Curse" then target.curse = true
      elseif dispelName == "Poison" then target.poison = true
      elseif dispelName == "Disease" then target.disease = true
      end
      enemy.spells[key] = target
    end
  end
end

local function updateEnemy(enemy, npc)
  if npc.displayId then enemy.displayId = npc.displayId end
  if npc.health and npc.health > 0 then enemy.health = npc.health end
  if npc.level and npc.level > 0 then enemy.level = npc.level end
  if npc.creatureType then enemy.creatureType = npc.creatureType end
  mergeSpells(enemy, npc)
end

local function nextGroupId(enemies)
  local maxG = 0
  for _, enemy in ipairs(enemies) do
    for _, clone in pairs(not enemy.fdtZoneTracked and enemy.clones or {}) do
      if clone.g and clone.g > maxG then maxG = clone.g end
    end
  end
  return maxG
end

local function buildClones(npc, transform, groupBase)
  local clones = {}
  local runsByClone = {}
  for _, unitRecord in pairs(npc.units) do
    local pos = unitPosition(unitRecord)
    if pos then
      local mx, my = transform(pos)
      local match
      for idx, clone in ipairs(clones) do
        local dx, dy = clone.x - mx, clone.y - my
        if not runsByClone[idx][unitRecord.run or 0] and dx * dx + dy * dy <= MERGE_DISTANCE * MERGE_DISTANCE then
          match = idx
          break
        end
      end
      if match then
        local clone = clones[match]
        clone.samples = clone.samples + 1
        clone.x = clone.x + (mx - clone.x) / clone.samples
        clone.y = clone.y + (my - clone.y) / clone.samples
        runsByClone[match][unitRecord.run or 0] = true
      else
        clones[#clones + 1] = {
          x = mx, y = my, sublevel = 1, samples = 1,
          g = unitRecord.pull and (groupBase + unitRecord.pull) or nil,
        }
        runsByClone[#clones] = { [unitRecord.run or 0] = true }
      end
    end
  end
  for _, clone in ipairs(clones) do clone.samples = nil end
  return clones
end

local ICON_BY_KEYWORD = {
  { "spider", "Ability_Hunter_Pet_Spider" }, { "widow", "Ability_Hunter_Pet_Spider" },
  { "lurker", "Ability_Hunter_Pet_Spider" }, { "crawler", "Ability_Hunter_Pet_Spider" },
  { "wolf", "Ability_Hunter_Pet_Wolf" }, { "worg", "Ability_Hunter_Pet_Wolf" },
  { "bat", "Ability_Hunter_Pet_Bat" }, { "rat", "INV_Misc_Food_Rat_01" },
  { "skeleton", "Spell_Shadow_RaiseDead" }, { "bone", "Spell_Shadow_RaiseDead" },
  { "ghoul", "Spell_Shadow_AnimateDead" }, { "zombie", "Spell_Shadow_AnimateDead" },
  { "abomination", "Spell_Shadow_AnimateDead" }, { "flesh", "Spell_Shadow_AnimateDead" },
  { "ghost", "Spell_Shadow_Haunting" }, { "spirit", "Spell_Shadow_Haunting" },
  { "wraith", "Spell_Shadow_Haunting" }, { "banshee", "Spell_Shadow_Haunting" },
  { "necromancer", "Spell_Shadow_ShadowBolt" }, { "cultist", "Spell_Shadow_ShadowBolt" },
  { "acolyte", "Spell_Shadow_ShadowBolt" }, { "mage", "Spell_Frost_FrostBolt02" },
  { "priest", "Spell_Holy_HolyBolt" }, { "soldier", "INV_Sword_04" }, { "guard", "INV_Shield_06" },
  { "footman", "INV_Shield_06" }, { "captain", "INV_Sword_27" }, { "knight", "INV_Sword_27" },
  { "archer", "INV_Weapon_Bow_07" }, { "gargoyle", "Spell_Shadow_Gargoyle" },
}
local function iconForName(name)
  local lower = name:lower()
  for _, entry in ipairs(ICON_BY_KEYWORD) do
    if lower:find(entry[1], 1, true) then return "Interface\\Icons\\"..entry[2] end
  end
  return "Interface\\Icons\\Spell_Shadow_RaiseDead"
end

-- stable pseudo npc id (>= 9000000, never a real creature id) for mobs only known by name
local function pseudoNpcId(name)
  local hash = 5381
  for i = 1, #name do hash = (hash * 33 + name:byte(i)) % 999983 end
  return 9000000 + hash
end

local killCount = killCountRaw

-- places the logged kills of the most complete run around the map point of each subzone
local function applyZoneKills(dungeonIdx, inst, enemies, groupBase)
  if not inst.zonePulls or #inst.zonePulls == 0 then return 0 end
  local mapInfo = MDT.mapInfo[dungeonIdx] or {}
  local anchors = mapInfo.fdtSubzoneAnchors or {}
  local fallback
  for _, poi in ipairs(MDT.mapPOIs[dungeonIdx] and MDT.mapPOIs[dungeonIdx][1] or {}) do
    if poi.type == "dungeonEntrance" then fallback = { x = poi.x, y = poi.y - 40 } end
  end
  fallback = fallback or { x = 420, y = -277 }

  -- runs recorded less than RUN_CONTINUE_SECONDS apart (/reload inside the dungeon) are one run
  local sessionOf, lastT, session = {}, nil, 0
  local ordered = {}
  for _, pull in ipairs(inst.zonePulls) do ordered[#ordered + 1] = pull end
  table.sort(ordered, function(a, b) return (a.t or 0) < (b.t or 0) end)
  for _, pull in ipairs(ordered) do
    if not lastT or (pull.t or 0) - lastT > RUN_CONTINUE_SECONDS then session = session + 1 end
    sessionOf[pull] = session
    lastT = pull.t or 0
  end
  local killsByRun = {}
  for _, pull in ipairs(inst.zonePulls) do
    for _, kill in pairs(pull.kills) do
      killsByRun[sessionOf[pull]] = (killsByRun[sessionOf[pull]] or 0) + killCount(kill)
    end
  end
  local bestRun, bestCount = nil, 0
  for run, count in pairs(killsByRun) do
    if count > bestCount then bestRun, bestCount = run, count end
  end
  if not bestRun then return 0 end

  local byName, levels = {}, {}
  for _, enemy in ipairs(enemies) do byName[enemy.name] = enemy end
  for _, pull in ipairs(inst.zonePulls) do
    for _, kill in pairs(pull.kills) do
      local l = levels[kill.name] or {}
      if kill.level and kill.level > 0 then l[#l + 1] = kill.level end
      if kill.isBoss then l.isBoss = true end
      if kill.classification then l.classification = kill.classification end
      levels[kill.name] = l
    end
  end
  for _, enemy in ipairs(enemies) do
    if enemy.fdtZoneTracked then enemy.clones = {} end
  end

  local pullsInSubzone, unknownSubzones, placed = {}, {}, {}
  local groupIndex = 0
  for _, pull in ipairs(ordered) do
    if sessionOf[pull] == bestRun and next(pull.kills) then
      groupIndex = groupIndex + 1
      local members = {}
      for _, kill in pairs(pull.kills) do
        for _ = 1, killCount(kill) do members[#members + 1] = kill end
      end
      table.sort(members, function(a, b) return a.name < b.name end)
      local subzone = members[1].subzone or ""
      local anchor = anchors[subzone]
      if not anchor then
        anchor = fallback
        if subzone ~= "" then unknownSubzones[subzone] = true end
      end
      local slot = (pullsInSubzone[subzone] or 0) + 1
      pullsInSubzone[subzone] = slot
      -- golden-angle spiral: successive pulls of a subzone spread around its point
      local angle, radius = slot * 2.39996, 14 * math.sqrt(slot - 1)
      local cx, cy = anchor.x + radius * math.cos(angle), anchor.y + radius * math.sin(angle)
      for i, kill in ipairs(members) do
        local enemy = byName[kill.name]
        if enemy and not enemy.fdtZoneTracked then
          -- already on the map (built-in data): only complete its level
          local l = levels[kill.name]
          if (not enemy.level or enemy.level <= 1) and l and l[1] then enemy.level = median(l) end
        else
          if not enemy then
            local l = levels[kill.name] or {}
            local isBoss = l.isBoss or l.classification == "worldboss"
            enemy = {
              name = kill.name, id = pseudoNpcId(kill.name), count = 0, health = 0, scale = isBoss and 1.6 or 1,
              iconTexture = iconForName(kill.name), creatureType = "Humanoid",
              level = (l[1] and median({ unpack(l) })) or 1, isBoss = isBoss or nil,
              clones = {}, fdtZoneTracked = true,
            }
            tinsert(enemies, enemy)
            byName[kill.name] = enemy
          end
          local a = (i - 1) * (2 * math.pi / math.max(#members, 1))
          local r = #members > 1 and 5 or 0
          tinsert(enemy.clones, { x = cx + r * math.cos(a), y = cy + r * math.sin(a), sublevel = 1, g = groupBase + groupIndex })
          placed[kill.name] = true
        end
      end
    end
  end
  for subzone in pairs(unknownSubzones) do
    printMsg(string.format(L["fdtTrackerUnknownSubzone"], subzone))
  end
  local count = 0
  for _ in pairs(placed) do count = count + 1 end
  return count
end

function MDT:MobTracker_Apply(silent)
  local appliedNpcs, placedNpcs = 0, 0
  for instanceId, inst in pairs(store().instances) do
    local dungeonIdx = MDT.instanceIdToDungeonIdx and MDT.instanceIdToDungeonIdx[instanceId]
    local enemies = dungeonIdx and MDT.dungeonEnemies[dungeonIdx]
    if enemies then
      local byId = {}
      for _, enemy in ipairs(enemies) do byId[enemy.id] = enemy end
      local transform, anchorCount = buildTransform(dungeonIdx, inst)
      local groupBase = nextGroupId(enemies)
      for npcId, npc in pairs(inst.npcs) do
        local enemy = byId[npcId]
        if enemy then
          updateEnemy(enemy, npc)
          appliedNpcs = appliedNpcs + 1
        elseif transform and not npc.summonedBy and npc.name then
          local clones = buildClones(npc, transform, groupBase)
          if #clones > 0 then
            local isBoss = npc.isBoss or npc.classification == "worldboss"
            enemy = {
              name = npc.name, id = npcId, count = 0, health = npc.health or 1, scale = isBoss and 1.6 or 1,
              displayId = npc.displayId, creatureType = npc.creatureType or "Humanoid", level = npc.level or 1,
              isBoss = isBoss, clones = clones, fdtTracked = true,
            }
            mergeSpells(enemy, npc)
            tinsert(enemies, enemy)
            byId[npcId] = enemy
            placedNpcs = placedNpcs + 1
          end
        end
      end
      if not transform then
        local zonePlaced = applyZoneKills(dungeonIdx, inst, enemies, groupBase)
        placedNpcs = placedNpcs + zonePlaced
        if not silent and zonePlaced == 0 and not (inst.zonePulls and #inst.zonePulls > 0) then
          printMsg(string.format(L["fdtTrackerNoCalibration"], inst.name or tostring(instanceId), anchorCount))
        end
      end
    end
  end
  if not silent then printMsg(string.format(L["fdtTrackerApplied"], appliedNpcs, placedNpcs)) end
  if MDT.main_frame and MDT.UpdateMap then MDT:UpdateMap() end
end

function MDT:MobTracker_PrintStatus()
  local instances, npcs, pulls = MDT:MobTracker_GetSummary()
  printMsg(string.format(L["fdtTrackerStatus"],
    settings().enabled and L["fdtTrackerOn"] or L["fdtTrackerOff"], instances, npcs, pulls))
  if tracker.active then
    local inst = currentInstance()
    printMsg(string.format(L["fdtTrackerRecording"], inst and inst.name or "?"))
  end
end

-- /fdt track debug: which unit and position data the client lets the addon read here (target + player)
function MDT:MobTracker_Debug()
  local function describe(fn, ...)
    local function pack(...) return { n = select("#", ...), ... } end
    local results = pack(pcall(fn, ...))
    if not results[1] then return "|cFFFF4040blocked|r" end
    local parts = {}
    for i = 2, math.max(2, results.n) do
      local v = results[i]
      if v ~= nil and issecretvalue(v) then parts[#parts + 1] = "|cFFFF8040secret|r"
      else parts[#parts + 1] = tostring(v) end
    end
    return table.concat(parts, ", ")
  end
  local log = store()
  log.debugLog = log.debugLog or {}
  local function out(line)
    printMsg(line)
    tinsert(log.debugLog, date("%H:%M:%S ")..line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    while #log.debugLog > 600 do table.remove(log.debugLog, 1) end
  end
  local function check(label, fn, ...)
    if type(fn) == "function" then out(label.." = "..describe(fn, ...)) else out(label.." = (no api)") end
  end

  local _, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo()
  out(string.format("debug - instance %s (%s), tracker %s, combat lockdown %s", tostring(instanceId),
    tostring(instanceType), tracker.active and "active" or "inactive", tostring(InCombatLockdown())))
  check("UnitAffectingCombat(player)", UnitAffectingCombat, "player")
  check("UnitAffectingCombat(target)", UnitAffectingCombat, "target")

  -- identity
  check("UnitGUID(target)", UnitGUID, "target")
  check("UnitName(target)", UnitName, "target")
  check("UnitNameUnmodified(target)", UnitNameUnmodified, "target")
  check("UnitLevel(target)", UnitLevel, "target")
  check("UnitEffectiveLevel(target)", UnitEffectiveLevel, "target")
  check("UnitClassification(target)", UnitClassification, "target")
  check("UnitCreatureType(target)", UnitCreatureType, "target")
  check("UnitCreatureFamily(target)", UnitCreatureFamily, "target")
  check("UnitSex(target)", UnitSex, "target")
  check("UnitRace(target)", UnitRace, "target")
  check("UnitClass(target)", UnitClass, "target")
  check("UnitPowerType(target)", UnitPowerType, "target")
  check("UnitPowerMax(target)", UnitPowerMax, "target")
  check("UnitHealth(target)", UnitHealth, "target")
  check("UnitHealthMax(target)", UnitHealthMax, "target")
  check("UnitHealthPercent(target)", UnitHealthPercent, "target")
  check("UnitReaction(player,target)", UnitReaction, "player", "target")
  check("UnitIsBossMob(target)", UnitIsBossMob, "target")
  check("UnitCanAttack(target)", UnitCanAttack, "player", "target")
  check("UnitTokenFromGUID(guid)", function() return UnitTokenFromGUID and UnitTokenFromGUID(UnitGUID("target")) end)
  check("model GetDisplayInfo(target)", function()
    if not modelFrame then readDisplayId("target") end
    modelFrame:ClearModel()
    modelFrame:SetUnit("target")
    return modelFrame.GetDisplayInfo and modelFrame:GetDisplayInfo()
  end)
  check("model GetModelFileID(target)", function()
    if not modelFrame then readDisplayId("target") end
    modelFrame:SetUnit("target")
    return modelFrame.GetModelFileID and modelFrame:GetModelFileID()
  end)
  check("C_TooltipInfo.GetUnit(target)", function()
    local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit("target")
    if not data or not data.lines then return nil end
    local first, second = data.lines[1], data.lines[2]
    return data.id, first and first.leftText, second and second.leftText, data.guid
  end)
  check("scan tooltip line 1/2", function()
    local tip = _G.FDTScanTooltip or CreateFrame("GameTooltip", "FDTScanTooltip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetUnit("target")
    local l1, l2 = _G.FDTScanTooltipTextLeft1, _G.FDTScanTooltipTextLeft2
    return l1 and l1:GetText(), l2 and l2:GetText()
  end)
  check("nameplate(target) name text", function()
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    local uf = plate and plate.UnitFrame
    return uf and uf.name and uf.name:GetText(), plate and plate.namePlateUnitToken
  end)
  -- a secret name can be displayed: check whether the rendered text still exposes measurable aspects
  local probe = _G.FDTNameProbe
  if not probe then
    probe = CreateFrame("Frame", "FDTNameProbe", UIParent)
    probe:SetSize(1, 1)
    probe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
    probe.text = probe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    probe.edit = CreateFrame("EditBox", nil, probe)
    probe.edit:SetAutoFocus(false)
    probe.edit:SetFontObject("GameFontNormal")
    probe.edit:SetSize(400, 20)
  end
  check("probe text width (secret name)", function()
    probe.text:SetText(UnitName("target"))
    return probe.text:GetStringWidth(), probe.text.GetUnboundedStringWidth and probe.text:GetUnboundedStringWidth(),
      probe.text:GetStringHeight(), probe.text.IsTruncated and probe.text:IsTruncated()
  end)
  check("probe text width (\"Deep Widow\")", function()
    probe.text:SetText("Deep Widow")
    return probe.text:GetStringWidth(), probe.text.GetUnboundedStringWidth and probe.text:GetUnboundedStringWidth()
  end)
  check("probe text HasSecretValues", function()
    probe.text:SetText(UnitName("target"))
    return probe.text.HasSecretValues and probe.text:HasSecretValues(), probe.text.HasSecretAspect and probe.text:HasSecretAspect()
  end)
  check("probe editbox letters (secret name)", function()
    probe.edit:SetText(UnitName("target"))
    return probe.edit:GetNumLetters(), probe.edit:GetText()
  end)
  check("probe text width (secret level/class line)", function()
    probe.text:SetText(UnitCreatureType("target"))
    return probe.text:GetStringWidth()
  end)

  for _, ns in ipairs({ "C_Secrets", "C_RestrictedActions" }) do
    local api = _G[ns]
    if type(api) == "table" then
      local names = {}
      for name, fn in pairs(api) do
        local query = name:find("^Get") or name:find("^Is") or name:find("^Should") or name:find("^Has") or name:find("^Can")
        if type(fn) == "function" and query then names[#names + 1] = name end
      end
      table.sort(names)
      for _, name in ipairs(names) do check(ns.."."..name.."(target)", api[name], "target") end
    else
      out(ns.." = (no api)")
    end
  end
  if Enum and Enum.AddOnRestrictionType and C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState then
    for key, value in pairs(Enum.AddOnRestrictionType) do
      check("restriction "..key, C_RestrictedActions.GetAddOnRestrictionState, value)
    end
  end

  -- position sources
  check("UnitPosition(player)", UnitPosition, "player")
  check("UnitPosition(target)", UnitPosition, "target")
  check("C_Map.GetBestMapForUnit(player)", C_Map and C_Map.GetBestMapForUnit, "player")
  check("GetPlayerFacing()", GetPlayerFacing)
  check("GetUnitSpeed(player)", GetUnitSpeed, "player")
  check("IsPlayerMoving()", IsPlayerMoving)
  check("IsFalling()", IsFalling)
  check("GetZoneText()", GetZoneText)
  check("GetSubZoneText()", GetSubZoneText)
  check("GetMinimapZoneText()", GetMinimapZoneText)
  check("C_Map.GetMapInfo(instance)", function()
    local id = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    return info and info.name, info and info.mapType
  end)
  check("CheckInteractDistance(target,1..4)", function()
    return CheckInteractDistance("target", 1), CheckInteractDistance("target", 2),
      CheckInteractDistance("target", 3), CheckInteractDistance("target", 4)
  end)
  check("nameplate(target) screen center", function()
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate then return nil end
    return plate:GetCenter()
  end)
  check("UnitDistanceSquared(party1)", UnitDistanceSquared, "party1")
  check("UnitPosition(party1)", UnitPosition, "party1")

  local seen = tracker.debugSeen or {}
  for key, value in pairs(seen) do out("last "..key.." = "..value) end
  out("identified as = "..describe(identifyUnit, "target"))
end

-- records whether event payloads arrive secret, for /fdt track debug
local debugFrame = CreateFrame("Frame")
for _, event in ipairs({ "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
  "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "LOOT_OPENED", "CHAT_MSG_COMBAT_XP_GAIN",
  "CHAT_MSG_COMBAT_HOSTILE_DEATH", "UI_INFO_MESSAGE", "UNIT_SPELLCAST_SENT", "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED", "CHAT_MSG_LOOT", "QUEST_WATCH_UPDATE", "UNIT_DIED" }) do
  pcall(debugFrame.RegisterEvent, debugFrame, event)
end
debugFrame:SetScript("OnEvent", function(_, event, ...)
  if not tracker.active then return end
  local parts = {}
  for i = 1, math.min(select("#", ...), 5) do
    local v = select(i, ...)
    if v ~= nil and issecretvalue(v) then parts[#parts + 1] = "secret" else parts[#parts + 1] = tostring(v) end
  end
  if event == "LOOT_OPENED" and GetLootSourceInfo and GetNumLootItems() > 0 then
    local guid = GetLootSourceInfo(1)
    parts[#parts + 1] = "source="..((guid ~= nil and issecretvalue(guid)) and "secret" or tostring(guid))
  end
  local line = table.concat(parts, ", ")
  tracker.debugSeen = tracker.debugSeen or {}
  tracker.debugSeen[event] = line
  debugEvent("event "..event..": "..line.." | subzone="..currentSubzone())
end)

-- /fdt track name [level] <name>: names the unknown mobs of the last pull (optionally only one level),
-- then remembers it for mobs of the same level, rank and subzone in this dungeon
function MDT:MobTracker_NameLastPull(text)
  local level, name = (text or ""):match("^(%d+)%s+(.+)$")
  name = name or text
  name = name and name:match("^%s*(.-)%s*$")
  local instanceId = tracker.instanceId or select(8, GetInstanceInfo())
  local inst = instanceId and store().instances[instanceId]
  if not name or name == "" or not inst or not inst.zonePulls or #inst.zonePulls == 0 then
    printMsg(L["fdtTrackerNameUsage"])
    return
  end
  level = tonumber(level)
  local lastPull
  for _, pull in ipairs(inst.zonePulls) do
    for _, kill in pairs(pull.kills) do
      if kill.placeholder and (not lastPull or (pull.t or 0) >= (lastPull.t or 0)) then lastPull = pull end
    end
  end
  if not lastPull then
    printMsg(L["fdtTrackerNameUsage"])
    return
  end
  inst.nameHints = inst.nameHints or {}
  local renamed = 0
  local function rename(pull, key, kill)
    pull.kills[key] = nil
    local newKey = name.."\t"..(kill.subzone or "")
    local target = pull.kills[newKey]
    if target then
      for _, kind in ipairs({ "xp", "death", "quest", "dead" }) do
        if kill[kind] then target[kind] = (target[kind] or 0) + kill[kind] end
      end
    else
      kill.name, kill.placeholder = name, nil
      pull.kills[newKey] = kill
    end
    renamed = renamed + killCountRaw(kill)
  end
  local fingerprints = {}
  for key, kill in pairs(lastPull.kills) do
    if kill.placeholder and (not level or kill.level == level) then
      local fp = string.format("%s:%s:%s", tostring(kill.level), tostring(kill.classification), kill.subzone or "")
      fingerprints[fp] = true
      inst.nameHints[fp] = name
    end
  end
  -- same profile elsewhere in the recorded runs
  for _, pull in ipairs(inst.zonePulls) do
    local keys = {}
    for key, kill in pairs(pull.kills) do
      local fp = string.format("%s:%s:%s", tostring(kill.level), tostring(kill.classification), kill.subzone or "")
      if kill.placeholder and fingerprints[fp] then keys[#keys + 1] = key end
    end
    for _, key in ipairs(keys) do rename(pull, key, pull.kills[key]) end
  end
  printMsg(string.format(L["fdtTrackerNamed"], renamed, name))
end

function MDT:MobTracker_Command(argument)
  if argument == "on" then
    MDT:MobTracker_SetEnabled(true)
  elseif argument == "off" then
    MDT:MobTracker_SetEnabled(false)
  elseif argument == "apply" then
    settings().autoApply = true
    MDT:MobTracker_Apply(false)
  elseif argument == "reset" then
    MDT:MobTracker_Reset()
  elseif argument == "status" then
    MDT:MobTracker_PrintStatus()
  elseif argument == "debug" then
    MDT:MobTracker_Debug()
  elseif argument and argument:find("^name") then
    MDT:MobTracker_NameLastPull(argument:match("^name%s*(.*)$"))
  else
    MDT:MobTracker_SetEnabled(not settings().enabled)
  end
end

registerTrackingEvents(settings().enabled)
