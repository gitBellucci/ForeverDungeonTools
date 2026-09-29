-- Modified for ForeverDungeonTools (Classic Forever Beta) on 2026-09-26.
-- Based on MythicDungeonTools by Nnoggie. Licensed under GNU GPL v2.0.
-- Classic Forever API safety shims (templates / encoding / tooltips).
local addonName, MDT = ...
MDT.uiBundled = true
MDT.AddonName = addonName

local _CreateFrame = CreateFrame
local missingTemplates = {}

function MDT.SafeCreateFrame(frameType, name, parent, template, ...)
  if not template or template == "" then
    return _CreateFrame(frameType, name, parent, nil, ...)
  end
  local ok, frame = pcall(_CreateFrame, frameType, name, parent, template, ...)
  if ok and frame then return frame end
  missingTemplates[template] = true
  local f = _CreateFrame(frameType, name, parent, nil, ...)
  if template == "LoadingSpinnerTemplate" then
    f.BackgroundFrame = CreateFrame("Frame", nil, f)
    f.BackgroundFrame.Background = f:CreateTexture(nil, "BACKGROUND")
    f.BackgroundFrame.Background:SetAllPoints()
    f.AnimFrame = CreateFrame("Frame", nil, f)
    f.AnimFrame.Circle = f:CreateTexture(nil, "ARTWORK")
    f.AnimFrame.Circle:SetAllPoints()
    f.Anim = { Play = function() end, Stop = function() end }
  elseif template == "MaximizeMinimizeButtonFrameTemplate" then
    function f:Minimize() end
    function f:Maximize() end
    function f:SetOnMaximizedCallback(cb) self._onMax = cb end
    function f:SetOnMinimizedCallback(cb) self._onMin = cb end
    f:SetSize(24, 24)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up")
    f:EnableMouse(true)
    f:SetScript("OnClick", function(self)
      local db = MDT.GetDB and MDT:GetDB()
      if db and db.maximized then
        if self._onMin then self._onMin(MDT) end
      else
        if self._onMax then self._onMax(MDT) end
      end
    end)
  elseif template == "ScenarioProgressBarTemplate" then
    f.Bar = CreateFrame("StatusBar", nil, f)
    f.Bar:SetAllPoints()
    f.Bar:SetMinMaxValues(0, 1)
    f.Bar:SetValue(0)
    f.Bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    f.Bar.Label = f.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.Bar.Label:SetPoint("CENTER")
    f.Bar.Icon = f.Bar:CreateTexture(nil, "OVERLAY")
  
  elseif template == "ModelWithControlsTemplate" then
    -- Classic may lack ModelWithControlsTemplate; frameType is already PlayerModel.

  elseif template == "TooltipBorderedFrameTemplate" or template == "BackdropTemplate" then
    if BackdropTemplateMixin and not f.SetBackdrop then
      Mixin(f, BackdropTemplateMixin)
    end
    if f.SetBackdrop then
      f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
      })
    end
  end
  return f
end

MDT.MissingTemplates = missingTemplates

if not CreateColor then
  function CreateColor(r, g, b, a)
    local c = { r = r or 1, g = g or 1, b = b or 1, a = a or 1 }
    function c:GetRGB() return self.r, self.g, self.b end
    function c:GetRGBA() return self.r, self.g, self.b, self.a end
    function c:GenerateHexColorMarkup()
      return ("|cff%02x%02x%02x"):format(self.r * 255, self.g * 255, self.b * 255)
    end
    return c
  end
end
if not WrapTextInColor then
  function WrapTextInColor(text, color)
    if type(color) == "table" and color.GenerateHexColorMarkup then
      return color:GenerateHexColorMarkup() .. tostring(text) .. "|r"
    end
    return text
  end
end
if not issecretvalue then
  function issecretvalue(_) return false end
end

if not C_AddOns then
  C_AddOns = {
    GetAddOnMetadata = GetAddOnMetadata,
    IsAddOnLoaded = function(n)
      local loaded = IsAddOnLoaded(n)
      return loaded, loaded
    end,
    LoadAddOn = LoadAddOn,
    EnableAddOn = EnableAddOn,
  }
end

if not C_Map then C_Map = {} end
if not C_Map.GetBestMapForUnit then function C_Map.GetBestMapForUnit() return nil end end
if not C_Map.GetAreaInfo then function C_Map.GetAreaInfo() return nil end end
if not C_ChallengeMode then
  C_ChallengeMode = { IsChallengeModeActive = function() return false end }
end

MDT.UseLegacyEncoding = not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR and Enum and Enum.CompressionMethod)

if not C_ChatInfo then
  C_ChatInfo = {
    SendChatMessage = function(msg, chatType, language, target)
      return SendChatMessage(msg, chatType, language, target)
    end,
    RegisterAddonMessagePrefix = function(prefix)
      if RegisterAddonMessagePrefix then return RegisterAddonMessagePrefix(prefix) end
      return true
    end,
  }
end
if not C_EncodingUtil then C_EncodingUtil = nil end

-- DrawLine: Blizzard SharedXML helper used by pull hulls / patrols / drawing tools.
-- Provide a compatible implementation when the client does not expose the global.
if not DrawLine then
  local LINEFACTOR = 256 / 254
  local LINEFACTOR_2 = LINEFACTOR / 2
  function DrawLine(T, C, sx, sy, ex, ey, w, s, f)
    if not T or not C then return end
    local relPoint = f or "TOPLEFT"
    s = s or 1
    local dx, dy = ex - sx, ey - sy
    local cx, cy = (sx + ex) / 2, (sy + ey) / 2
    if dx < 0 then
      dx, dy = -dx, -dy
    end
    local l = math.sqrt((dx * dx) + (dy * dy))
    T:ClearAllPoints()
    if l == 0 then
      T:SetTexCoord(0, 0, 0, 0, 0, 0, 0, 0)
      T:SetPoint("BOTTOMLEFT", C, relPoint, cx, cy)
      T:SetPoint("TOPRIGHT", C, relPoint, cx, cy)
      return
    end
    w = w * s / l
    local sn, cn = -dy / l, dx / l
    local sc = sn * cn
    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
    if dy >= 0 then
      Bwid = ((l * cn) - (w * sn)) * LINEFACTOR_2
      Bhgt = ((w * cn) - (l * sn)) * LINEFACTOR_2
      BLx, BLy, BRy = (w / l) * sc, sn * sn, (l / w) * sc
      BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
      TRy = BRx
    else
      Bwid = ((l * cn) + (w * sn)) * LINEFACTOR_2
      Bhgt = ((w * cn) + (l * sn)) * LINEFACTOR_2
      BLx, BLy, BRx = sn * sn, -(l / w) * sc, 1 + (w / l) * sc
      BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
      TRx = TLy
    end
    T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
    T:SetPoint("BOTTOMLEFT", C, relPoint, cx - Bwid, cy - Bhgt)
    T:SetPoint("TOPRIGHT", C, relPoint, cx + Bwid, cy + Bhgt)
  end
end

-- Font used by pull-number overlays on hulls
if not GameFontNormalMed3Outline and GameFontNormal then
  GameFontNormalMed3Outline = GameFontNormal
end

