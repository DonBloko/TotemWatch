-- TotemWatch - Optionsmenü (Esc -> Optionen -> AddOns -> TotemWatch)
local ADDON, ns = ...
if not ns.frame then return end   -- kein Schamane

local panel, category

local function Note(text)
  print("|cff0070deTotemWatch|r: " .. text)
end

-- Einstellungen, die geschützte Fenster ändern, nur außerhalb des Kampfes
local function OutOfCombat(fn)
  if InCombatLockdown() then Note("Im Kampf nicht möglich – bitte nach dem Kampf ändern.") return false end
  fn()
  return true
end

local checks = {}

local function AddCheck(parent, x, y, key, label, tooltip, onChange, needsOOC)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  fs:SetText(label)
  cb:SetScript("OnClick", function(self)
    local value = self:GetChecked() and true or false
    local apply = function()
      TotemWatchDB[key] = value
      if onChange then onChange(value) end
    end
    if needsOOC then
      if not OutOfCombat(apply) then self:SetChecked(TotemWatchDB[key]) end
    else
      apply()
    end
  end)
  if tooltip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(label, 1, 1, 1)
      GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  checks[#checks + 1] = { cb = cb, key = key }
  return cb
end

local function AddButton(parent, x, y, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 150, 24)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function AddHeader(parent, x, y, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

-- Eigener Schieberegler (Vorlagen unterscheiden sich je nach Client)
local function AddSlider(parent, x, y, label, minV, maxV, step, getter, setter)
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  title:SetPoint("TOPLEFT", x, y)
  local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(200, 16)
  s:SetPoint("TOPLEFT", x, y - 18)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  if s.SetBackdrop then
    s:SetBackdrop({
      bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
      edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
  end
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local fmt = (step >= 1) and "%s: %d" or "%s: %.2f"
  local function update(v) title:SetText(string.format(fmt, label, v)) end
  s:SetScript("OnValueChanged", function(self, v, byUser)
    v = math.floor(v / step + 0.5) * step
    update(v)
    if self.ready then setter(v) end
  end)
  s.Refresh = function()
    s.ready = false
    s:SetValue(getter()); update(getter())
    s.ready = true
  end
  return s
end

local scaleSlider, warnSlider

local function RefreshPanel()
  for _, c in ipairs(checks) do c.cb:SetChecked(TotemWatchDB[c.key] and true or false) end
  if scaleSlider then scaleSlider.Refresh() end
  if warnSlider then warnSlider.Refresh() end
end

function ns.CreateOptions()
  if panel then return end
  panel = CreateFrame("Frame")
  panel.name = "TotemWatch"
  panel:Hide()

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("|cff0070deTotemWatch|r – Optionen")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Totem-Empfehlungen, Warnungen und Totem-Leiste. Manche Änderungen gehen nur außerhalb des Kampfes.")

  local L, R = 16, 300
  local y = -70

  AddHeader(panel, L, y, "Empfehlungen")
  AddCheck(panel, L, y - 20, "auto", "Knöpfe automatisch belegen",
    "Außerhalb des Kampfes werden die Totem-Knöpfe mit dem empfohlenen Totem belegt.",
    function() wipe(ns.state.lastRec) end)
  AddCheck(panel, L, y - 46, "useBoss", "Boss-Regeln verwenden",
    "Empfehlungen je Boss (erkannt über Blizzard, DBM oder BigWigs).")
  AddCheck(panel, L, y - 72, "useOthers", "Andere Schamanen berücksichtigen",
    "Totems anderer Schamanen in deiner Gruppe erkennen und Doppelungen vermeiden.")
  AddCheck(panel, L, y - 98, "showHints", "Hinweistexte anzeigen",
    "Erklärungen unter der Leiste: was fehlt und warum.")

  AddHeader(panel, R, y, "Warnungen")
  AddCheck(panel, R, y - 20, "sound", "Warnton",
    "Ton bei dringenden Warnungen (Fear, zerstörtes Totem).")
  AddCheck(panel, R, y - 46, "rangeWarn", "Reichweiten-Warnung",
    "Zeigt, wer den Buff deines Totems nicht hat (außer Reichweite). Gilt für Totems mit Buff, z.B. Stärke der Erde, Manaquelle, Luftgnade, Widerstände.")
  AddCheck(panel, R, y - 72, "destroyWarn", "Warnung bei zerstörtem Totem",
    "Warnt, wenn ein Totem vor Ablauf verschwindet (getötet, Erdung hat einen Zauber abgefangen).")
  AddCheck(panel, R, y - 98, "prePull", "Pull-Check",
    "Zeigt bei Pull-Timer (DBM/BigWigs) und Bereitschaftscheck eine Checkliste: Totems, Schild, Waffe, Reichweite.")
  AddCheck(panel, R, y - 124, "enemyCasts", "Furcht über feindliche Zauber",
    "Erkennt über die Namensplaketten, wenn ein Gegner Furcht zaubert, und empfiehlt Erdstoß.")
  AddCheck(panel, R, y - 150, "distanceWarn", "Abstand zu eigenen Totems",
    "Warnt, wenn du weiter als die Totem-Reichweite von deinen Totems weg bist.")

  y = -260
  AddHeader(panel, L, y, "Leiste")
  AddCheck(panel, L, y - 20, "showAll", "Knopf „ALLE stellen“", nil,
    function() ns.SetupSecure() end, true)
  AddCheck(panel, L, y - 46, "showWeapon", "Knopf Waffenverzauberung", nil,
    function() ns.SetupSecure() end, true)
  AddCheck(panel, L, y - 72, "showShield", "Knopf Schild", nil,
    function() ns.SetupSecure() end, true)
  AddCheck(panel, L, y - 98, "showOOC", "Auch außerhalb des Kampfes zeigen", nil,
    function() ns.ApplyVisibilityDriver(); ns.UpdateVisibility() end, true)
  AddCheck(panel, L, y - 124, "locked", "Fenster fixieren",
    "Verhindert versehentliches Verschieben über die Titelzeile.")

  scaleSlider = AddSlider(panel, R, y - 20, "Größe", 0.5, 2.0, 0.05,
    function() return TotemWatchDB.scale or 1 end,
    function(v)
      if InCombatLockdown() then return end
      TotemWatchDB.scale = v
      ns.ApplyPosition()
    end)

  AddButton(panel, R, y - 70, "Anzeige testen (an/aus)", 180, function()
    OutOfCombat(function()
      ns.ToggleTest()
      Note("Testmodus " .. (ns.state.test and "an" or "aus"))
    end)
  end)
  AddButton(panel, R, y - 100, "Position zurücksetzen", 180, function()
    OutOfCombat(function() ns.ResetPosition(); RefreshPanel() end)
  end)

  warnSlider = AddSlider(panel, R, y - 135, "Vorwarnung vor Ablauf (Sek., 0 = aus)", 0, 15, 1,
    function() return TotemWatchDB.warnBefore or 0 end,
    function(v) TotemWatchDB.warnBefore = v end)

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", L, y - 190)
  help:SetWidth(560)
  help:SetJustifyH("LEFT")
  help:SetText("Bedienung: Linksklick stellt das Totem, Rechtsklick öffnet die Auswahl.\n" ..
    "Tasten belegen: Esc → Tastaturbelegung → AddOns → TotemWatch.\n" ..
    "Befehle: /tw help · /tw check · /tw probe · /tw boss <ID> · /tw fremd <totem>")

  panel:SetScript("OnShow", RefreshPanel)
  -- ältere Clients
  panel.refresh = RefreshPanel
  panel.okay = function() end
  panel.cancel = function() end

  if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, "TotemWatch")
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ns.OpenOptions()
  if not panel then ns.CreateOptions() end
  if Settings and Settings.OpenToCategory and category then
    Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)   -- bekannter Blizzard-Bug: zweimal nötig
  else
    Note("Optionsmenü nicht verfügbar – nutze /tw help")
  end
end
