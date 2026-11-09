-- TotemWatch - Optionsmenü (Esc -> Optionen -> AddOns -> TotemWatch)
local ADDON, ns = ...
if not ns.frame then return end   -- kein Schamane
local L = ns.L

local panel, category

local function Note(text)
  print("|cff0070deTotemWatch|r: " .. text)
end

-- Einstellungen, die geschützte Fenster ändern, nur außerhalb des Kampfes
local function OutOfCombat(fn)
  if InCombatLockdown() then Note(L["Not possible in combat – please change it after combat."]) return false end
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

local scaleSlider, warnSlider, hintSlider, msgSlider
local skinButtons = {}

-- Gewähltes Design im Menü hervorheben
local function RefreshSkinButtons()
  for key, btn in pairs(skinButtons) do
    if TotemWatchDB.skin == key then btn:LockHighlight() else btn:UnlockHighlight() end
  end
end

local function RefreshPanel()
  for _, c in ipairs(checks) do c.cb:SetChecked(TotemWatchDB[c.key] and true or false) end
  for _, s in ipairs({ scaleSlider, warnSlider, hintSlider, msgSlider }) do
    if s then s.Refresh() end
  end
  RefreshSkinButtons()
end

function ns.CreateOptions()
  if panel then return end
  panel = CreateFrame("Frame")
  panel.name = "TotemWatch"
  panel:Hide()

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["|cff0070deTotemWatch|r – Options"])

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText(L["Totem recommendations, warnings and the totem bar. Some changes only work out of combat."])

  local LX, RX = 16, 300   -- Spalten-Positionen (nicht L = Übersetzung!)

  -- Einführung jederzeit erneut starten (oben rechts)
  local tourBtn = AddButton(panel, 0, 0, L["Start tour"], 140, function()
    if ns.StartTutorial then ns.StartTutorial() end
  end)
  tourBtn:ClearAllPoints()
  tourBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)

  -- Design-Auswahl (oben, gut sichtbar)
  AddHeader(panel, LX, -62, L["Design"])
  for i, key in ipairs(ns.SKIN_ORDER) do
    local b = AddButton(panel, LX + 60 + (i - 1) * 128, -58, L[ns.SKINS[key].name], 124, function()
      OutOfCombat(function()
        TotemWatchDB.skin = key
        if ns.ApplySkin then ns.ApplySkin() end
        if ns.Refresh then ns.SafeCall("Display", ns.Refresh) end
        RefreshSkinButtons()
      end)
    end)
    skinButtons[key] = b
  end

  local y = -100

  AddHeader(panel, LX, y, L["Recommendations"])
  AddCheck(panel, LX, y - 20, "auto", L["Auto-assign buttons"],
    L["Out of combat, the totem buttons are set to the recommended totem."],
    function()
      wipe(ns.state.lastRec)
      if TotemWatchDB.manual then wipe(TotemWatchDB.manual) end   -- eigene Festlegungen aufheben
    end)
  AddCheck(panel, LX, y - 46, "useBoss", L["Use boss rules"],
    L["Recommendations per boss (detected via Blizzard, DBM or BigWigs)."])
  AddCheck(panel, LX, y - 72, "useOthers", L["Consider other shamans"],
    L["Detect totems of other shamans in your group and avoid duplicates."])
  AddCheck(panel, LX, y - 98, "showHints", L["Show hint texts"],
    L["Explanations below the bar: what is missing and why."])
  AddCheck(panel, LX, y - 124, "glow", L["Glow recommended totems"],
    L["The button (or the totem in the selection) that you should press glows."])
  AddCheck(panel, LX, y - 150, "messages", L["Messages in the middle of the screen"],
    L["Large messages for missing totems, fear and destroyed totems. Each message is shown only once."])

  AddHeader(panel, RX, y, L["Warnings"])
  AddCheck(panel, RX, y - 20, "sound", L["Warning sound"],
    L["Sound on urgent warnings (fear, destroyed totem)."])
  AddCheck(panel, RX, y - 46, "rangeWarn", L["Range warning"],
    L["Shows who does not have your totem's buff (out of range). Works for totems with a buff, e.g. Strength of Earth, Mana Spring, Grace of Air, resistances."])
  AddCheck(panel, RX, y - 72, "destroyWarn", L["Warn when a totem is destroyed"],
    L["Warns when a totem disappears early (killed, Grounding absorbed a spell)."])
  AddCheck(panel, RX, y - 98, "prePull", L["Pull check"],
    L["Shows a checklist on pull timer (DBM/BigWigs) and ready check: totems, shield, weapon, range."])
  AddCheck(panel, RX, y - 124, "enemyCasts", L["Fear from enemy casts"],
    L["Detects via nameplates when an enemy casts fear and recommends Tremor Totem."])
  AddCheck(panel, RX, y - 150, "distanceWarn", L["Distance to your totems"],
    L["Warns when you are farther from your totems than their range."])

  y = -290
  AddHeader(panel, LX, y, L["Bar"])
  AddCheck(panel, LX, y - 20, "showAll", L["Cast-all button"], nil,
    function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 46, "showWeapon", L["Weapon enchant button"], nil,
    function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 72, "showShield", L["Shield button"], nil,
    function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 98, "showOOC", L["Also show out of combat"], nil,
    function() ns.ApplyVisibilityDriver(); ns.UpdateVisibility() end, true)
  AddCheck(panel, LX, y - 124, "locked", L["Lock window"],
    L["Prevents accidental moving via the title bar."])
  AddCheck(panel, LX, y - 150, "showCall", L["Call of the Elements button"],
    L["Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 176, "syncCall", L["Sync Call of the Elements"],
    L["Puts the totems from your TotemWatch buttons on the Call of the Elements bar (out of combat)."],
    function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 202, "showMove", L["Totemic Call button"],
    L["Moves your totems to you. Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 228, "showRecall", L["Totemic Recall button"],
    L["Removes your totems. Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(panel, LX, y - 254, "showMinimap", L["Minimap button"],
    L["Left-click: options · Right-click: show/hide the bar · Shift-click: tour"],
    function() if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end end)

  scaleSlider = AddSlider(panel, RX, y - 20, L["Size"], 0.5, 2.0, 0.05,
    function() return TotemWatchDB.scale or 1 end,
    function(v)
      if InCombatLockdown() then return end
      TotemWatchDB.scale = v
      ns.ApplyPosition()
    end)

  AddButton(panel, RX, y - 70, L["Test display (on/off)"], 180, function()
    OutOfCombat(function()
      ns.ToggleTest()
      Note(L["Test mode "] .. (ns.state.test and L["on"] or L["off"]))
    end)
  end)
  AddButton(panel, RX, y - 100, L["Reset position"], 180, function()
    OutOfCombat(function() ns.ResetPosition(); RefreshPanel() end)
  end)

  warnSlider = AddSlider(panel, RX, y - 135, L["Warning before expiry (sec., 0 = off)"], 0, 15, 1,
    function() return TotemWatchDB.warnBefore or 0 end,
    function(v) TotemWatchDB.warnBefore = v end)

  hintSlider = AddSlider(panel, RX, y - 180, L["Hint text size"], 9, 20, 1,
    function() return TotemWatchDB.hintSize or 13 end,
    function(v) TotemWatchDB.hintSize = v; if ns.ApplyHintFont then ns.ApplyHintFont() end end)

  msgSlider = AddSlider(panel, RX, y - 225, L["Message size"], 14, 40, 1,
    function() return TotemWatchDB.messageSize or 24 end,
    function(v)
      TotemWatchDB.messageSize = v
      if ns.ApplyMessageFont then ns.ApplyMessageFont() end
      if ns.ShowMessage then ns.ShowMessage(L["TotemWatch test message"] .. " " .. v, 1, 0.82, 0) end
    end)

  -- Meldungen in der Bildschirmmitte verschieben (blau hinterlegt, ziehen, Rechtsklick = fixieren)
  local moveMsg
  moveMsg = AddButton(panel, RX, y - 268, L["Move messages"], 180, function()
    local on = ns.ToggleMessageMove and ns.ToggleMessageMove()
    moveMsg:SetText(on and L["Lock messages"] or L["Move messages"])
  end)

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", LX, y - 305)
  help:SetWidth(560)
  help:SetJustifyH("LEFT")
  help:SetText(L["Usage: left-click casts the totem, right-click opens the selection.\n"] ..
    L["Key bindings: Esc → Key Bindings → AddOns → TotemWatch.\n"] ..
    L["Commands: /tw help · /tw check · /tw probe · /tw boss <ID> · /tw other <totem>"])

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
    Note(L["Options menu not available – use /tw help"])
  end
end
