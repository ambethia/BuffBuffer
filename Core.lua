local ADDON, NS = ...

local Buffer = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceConsole-3.0", "AceEvent-3.0")
local Toast = LibStub("LibToast-1.0")
local AceGUI = LibStub("AceGUI-3.0")

local ForEachAura = AuraUtil.ForEachAura
local CreateFrame = CreateFrame

local MAX_AURAS = 32

local DB_DEFAULTS = {
  profile = {
    ignoredAuras = {}
  }
}

function Buffer:OnInitialize() 
  self.db = LibStub("AceDB-3.0"):New(ADDON .. "DB", DB_DEFAULTS)
  
  self:EmbedBlizOptions()
  self:RegisterChatCommand("buffer", function ()
    self:ShowRecentAuras()
  end)

  local tooltip = CreateFrame("GameTooltip", ADDON .. "ScanningTooltip")
  tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  tooltip:AddFontStrings(
    tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
    tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
  )
  self.tooltip = tooltip
  
  self.auraEventFrame = CreateFrame("Frame")
  self.auraEventFrame:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
  self.auraEventFrame:SetScript("OnEvent", function(...) self:HandleAuras(select(3, ...)) end)
  
  self.oldAuras = {}
  self.newAuras = {}
  self.recentAuras = {}

  for _, spellID in ipairs(self.db.profile.ignoredAuras) do
    tinsert(self.recentAuras, spellID)
  end
end

function Buffer:OnEnable()
  Toast:Register(ADDON .. "Toast", function(toast, name, texture, description)
    toast:SetTitle(name)
    toast:SetText(description)
    toast:SetIconTexture(texture)
  end)
end 

function Buffer:HandleAuras(unit)
  wipe(self.newAuras)
  self:IterateAuras(unit, "HELPFUL")
  self:IterateAuras(unit, "HARMFUL")

  wipe(self.oldAuras)
  for i=1, #self.newAuras do
    self.oldAuras[i] = self.newAuras[i]
  end

  if self.recentAurasWindow then
    self:ShowRecentAuras()
  end
end

function Buffer:ShowRecentAuras()
  if self.recentAurasWindow then
    AceGUI:Release(self.recentAurasWindow)
    self.recentAurasWindow = nil
  end

  local window = AceGUI:Create("Window")
  window:SetTitle("Recent & Ignored Auras")
  window:SetWidth(240)
  window:SetHeight(480)
  window:SetLayout("Fill")
  window:SetCallback("OnClose", function(widget)
    AceGUI:Release(widget)
    self.recentAurasWindow = nil
  end)
  
  scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("List")
  window:AddChild(scroll)

  for _, spellID in ipairs(self.recentAuras) do
    local name, _, icon = GetSpellInfo(spellID)
    local row = AceGUI:Create("CheckBox")
    row:SetFullWidth(true)
    row:SetLabel(name)
    row:SetImage(icon)
    row:SetValue(tContains(self.db.profile.ignoredAuras, spellID))
    row:SetCallback("OnValueChanged", function(...)
      if select(3, ...) then
        tinsert(self.db.profile.ignoredAuras, spellID)
      else
        local index = 1;
        while self.db.profile.ignoredAuras[index] do
          if ( spellID == self.db.profile.ignoredAuras[index] ) then
            tremove(self.db.profile.ignoredAuras, index)
            break
          end
          index = index + 1;
        end
      end
    end)
    scroll:AddChild(row)
  end

  self.recentAurasWindow = window
end

function Buffer:IterateAuras(unit, filter)
  local index = 1
  ForEachAura(unit, filter, MAX_AURAS, function(...)
    local spellID = select(10, ...)

    tinsert(self.newAuras, spellID)

    if not tContains(self.oldAuras, spellID) and not tContains(self.db.profile.ignoredAuras, spellID) then
      self.tooltip:ClearLines()
      self.tooltip:SetUnitAura(unit, index, filter);
      local name, texture = ...;  
      local description = _G[ADDON .. "ScanningTooltipTextLeft2"]:GetText()

      if string.len(description) < 1 then
        description = "\n"
      end

      Toast:Spawn(ADDON .. "Toast", name, texture, description)
      tinsert(self.oldAuras, spellID)
    end

    if not tContains(self.recentAuras, spellID) then
      tinsert(self.recentAuras, 1, spellID)
    end

    index = index + 1;      
  end)
end

function Buffer:EmbedBlizOptions()
  local panel = CreateFrame( "Frame", ADDON .. "DummyPanel", UIParent )
  panel.name = ADDON

  local open = CreateFrame( "Button", ADDON .. "OptionsButton", panel, "UIPanelButtonTemplate" )
  open:SetPoint( "CENTER", panel, "CENTER", 0, 0 )
  open:SetWidth( 250 )
  open:SetHeight( 25 )
  open:SetText( "Recent & Ignored Auras" )

  open:SetScript("OnClick", function ()
    _G.InterfaceOptionsFrameOkay:Click()
    _G.GameMenuButtonContinue:Click()
    self:ShowRecentAuras()
  end)

  _G.InterfaceOptions_AddCategory(panel)
end