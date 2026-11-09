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

local scaleSlider, warnSlider, hintSlider, msgSlider, tremorSlider, dimSlider
local skinButtons = {}

-- Gewähltes Design im Menü hervorheben
local function RefreshSkinButtons()
  for key, btn in pairs(skinButtons) do
    if TotemWatchDB.skin == key then btn:LockHighlight() else btn:UnlockHighlight() end
  end
end

local function RefreshPanel()
  for _, c in ipairs(checks) do c.cb:SetChecked(TotemWatchDB[c.key] and true or false) end
  for _, s in ipairs({ scaleSlider, warnSlider, hintSlider, msgSlider, tremorSlider, dimSlider }) do
    if s then s.Refresh() end
  end
  RefreshSkinButtons()
end

function ns.CreateOptions()
  if panel then return end
  panel = CreateFrame("Frame")
  panel.name = "TotemWatch"
  panel:Hide()

  -- Scrollbarer Inhalt: alle Bedienelemente hängen an P statt direkt am Fenster,
  -- damit nichts unten aus dem Optionsfenster herausragt.
  local scroll
  local okTemplate = pcall(function()
    scroll = CreateFrame("ScrollFrame", "TotemWatchOptionsScroll", panel, "UIPanelScrollFrameTemplate")
  end)
  if not okTemplate or not scroll then
    scroll = CreateFrame("ScrollFrame", "TotemWatchOptionsScroll", panel)
  end
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)
  local P = CreateFrame("Frame", nil, scroll)
  P:SetSize(660, 960)
  scroll:SetScrollChild(P)
  -- Inhalt so breit wie der sichtbare Bereich (nicht unter die Scrollleiste)
  scroll:SetScript("OnSizeChanged", function(self, w)
    if w and w > 0 then P:SetWidth(w) end
  end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
  end)

  local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["|cff0070deTotemWatch|r – Options"])

  local sub = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText(L["Totem recommendations, warnings and the totem bar. Some changes only work out of combat."])

  local LX, RX = 16, 300   -- Spalten-Positionen (nicht L = Übersetzung!)

  -- Einführung jederzeit erneut starten (oben rechts)
  local tourBtn = AddButton(P, 0, 0, L["Start tour"], 140, function()
    if ns.StartTutorial then ns.StartTutorial() end
  end)
  tourBtn:ClearAllPoints()
  tourBtn:SetPoint("TOPRIGHT", P, "TOPRIGHT", -30, -16)   -- Abstand zur Scrollleiste

  -- Design-Auswahl (oben, gut sichtbar)
  AddHeader(P, LX, -62, L["Design"])
  for i, key in ipairs(ns.SKIN_ORDER) do
    local b = AddButton(P, LX + 60 + (i - 1) * 128, -58, L[ns.SKINS[key].name], 124, function()
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

  AddHeader(P, LX, y, L["Recommendations"])
  AddCheck(P, LX, y - 20, "auto", L["Auto-assign buttons"],
    L["Out of combat, the totem buttons are set to the recommended totem."],
    function()
      wipe(ns.state.lastRec)
      if TotemWatchDB.manual then wipe(TotemWatchDB.manual) end   -- eigene Festlegungen aufheben
    end)
  AddCheck(P, LX, y - 46, "useBoss", L["Use boss rules"],
    L["Recommendations per boss (detected via Blizzard, DBM or BigWigs)."])
  AddCheck(P, LX, y - 72, "useOthers", L["Consider other shamans"],
    L["Detect totems of other shamans in your group and avoid duplicates."])
  AddCheck(P, LX, y - 98, "showHints", L["Show hint texts"],
    L["Explanations below the bar: what is missing and why."])
  AddCheck(P, LX, y - 124, "glow", L["Glow recommended totems"],
    L["The button (or the totem in the selection) that you should press glows."])
  AddCheck(P, LX, y - 150, "messages", L["Messages in the middle of the screen"],
    L["Large messages for missing totems, fear and destroyed totems. Each message is shown only once."])
  -- Warnton, Meldung und Sprachausgabe sofort ausprobieren
  AddButton(P, LX + 4, y - 184, L["Test warnings"], 180, function()
    if ns.TestWarnings then ns.TestWarnings() end
  end)

  AddHeader(P, RX, y, L["Warnings"])
  AddCheck(P, RX, y - 20, "sound", L["Warning sound"],
    L["Sound on urgent warnings (fear, destroyed totem)."])
  AddCheck(P, RX, y - 46, "rangeWarn", L["Range warning"],
    L["Shows who does not have your totem's buff (out of range). Works for totems with a buff, e.g. Strength of Earth, Mana Spring, Grace of Air, resistances."])
  AddCheck(P, RX, y - 72, "destroyWarn", L["Warn when a totem is destroyed"],
    L["Warns when a totem disappears early (killed, Grounding absorbed a spell)."])
  AddCheck(P, RX, y - 98, "prePull", L["Pull check"],
    L["Shows a checklist on pull timer (DBM/BigWigs) and ready check: totems, shield, weapon, range."])
  AddCheck(P, RX, y - 124, "enemyCasts", L["Fear from enemy casts"],
    L["Detects via nameplates when an enemy casts fear and recommends Tremor Totem."])
  AddCheck(P, RX, y - 150, "distanceWarn", L["Distance to your totems"],
    L["Warns when you are farther from your totems than their range."])
  -- In Instanzen die Leiste dauerhaft zeigen (nicht nur im Kampf)
  local function applyVis() ns.ApplyVisibilityDriver(); ns.UpdateVisibility() end
  AddCheck(P, RX, y - 176, "showInDungeon", L["Always show in dungeons"],
    L["The bar stays visible in dungeons, also between fights."], applyVis, true)
  AddCheck(P, RX, y - 202, "showInRaid", L["Always show in raids"],
    L["The bar stays visible in raids, also between fights."], applyVis, true)
  AddCheck(P, RX, y - 228, "speak", L["Speak warnings (text to speech)"],
    L["Important warnings are read out loud, e.g. “Tremor Totem now!”."],
    function(on) if on and ns.Speak then ns.Speak(L["TotemWatch voice warnings on"], true) end end)

  y = -350
  AddHeader(P, LX, y, L["Bar"])
  AddCheck(P, LX, y - 20, "showAll", L["Cast-all button"], nil,
    function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 46, "showWeapon", L["Weapon enchant button"], nil,
    function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 72, "showShield", L["Shield button"], nil,
    function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 98, "showOOC", L["Also show out of combat"], nil,
    function() ns.ApplyVisibilityDriver(); ns.UpdateVisibility() end, true)
  AddCheck(P, LX, y - 124, "locked", L["Lock window"],
    L["Prevents accidental moving via the title bar."])
  AddCheck(P, LX, y - 150, "showCall", L["Call of the Elements button"],
    L["Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 176, "syncCall", L["Sync Call of the Elements"],
    L["Puts the totems from your TotemWatch buttons on the Call of the Elements bar (out of combat)."],
    function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 202, "showMove", L["Totemic Call button"],
    L["Moves your totems to you. Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 228, "showRecall", L["Totemic Recall button"],
    L["Removes your totems. Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(P, LX, y - 254, "showMinimap", L["Minimap button"],
    L["Left-click: options · Right-click: show/hide the bar · Shift-click: tour"],
    function() if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end end)
  AddCheck(P, LX, y - 280, "useMasque", L["Use Masque (if installed)"],
    L["Styles the buttons with your Masque skin. Changes need a /reload."])
  AddCheck(P, LX, y - 306, "tremorButton", L["Emergency Tremor button"],
    L["A big button that always casts Tremor Totem. It is dimmed and lights up when a fear is coming."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)
  AddCheck(P, LX, y - 332, "poisonButton", L["Emergency Poison Cleansing button"],
    L["Always casts Poison Cleansing Totem. Lights up when enemies cast poison."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)
  AddCheck(P, LX, y - 358, "diseaseButton", L["Emergency Disease Cleansing button"],
    L["Always casts Disease Cleansing Totem. Lights up when enemies cast diseases."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)
  AddCheck(P, LX, y - 384, "groundingButton", L["Emergency Grounding button"],
    L["Always casts Grounding Totem. Lights up when an enemy casts a dangerous spell (Polymorph, Hex, Fear …)."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)

  scaleSlider = AddSlider(P, RX, y - 20, L["Size"], 0.5, 2.0, 0.05,
    function() return TotemWatchDB.scale or 1 end,
    function(v)
      if InCombatLockdown() then return end
      TotemWatchDB.scale = v
      ns.ApplyPosition()
    end)

  AddButton(P, RX, y - 70, L["Test display (on/off)"], 180, function()
    OutOfCombat(function()
      ns.ToggleTest()
      Note(L["Test mode "] .. (ns.state.test and L["on"] or L["off"]))
    end)
  end)
  AddButton(P, RX, y - 100, L["Reset position"], 180, function()
    OutOfCombat(function() ns.ResetPosition(); RefreshPanel() end)
  end)

  warnSlider = AddSlider(P, RX, y - 135, L["Warning before expiry (sec., 0 = off)"], 0, 15, 1,
    function() return TotemWatchDB.warnBefore or 0 end,
    function(v) TotemWatchDB.warnBefore = v end)

  hintSlider = AddSlider(P, RX, y - 180, L["Hint text size"], 9, 20, 1,
    function() return TotemWatchDB.hintSize or 13 end,
    function(v) TotemWatchDB.hintSize = v; if ns.ApplyHintFont then ns.ApplyHintFont() end end)

  msgSlider = AddSlider(P, RX, y - 225, L["Message size"], 14, 40, 1,
    function() return TotemWatchDB.messageSize or 24 end,
    function(v)
      TotemWatchDB.messageSize = v
      if ns.ApplyMessageFont then ns.ApplyMessageFont() end
      if ns.ShowMessage then ns.ShowMessage(L["TotemWatch test message"] .. " " .. v, 1, 0.82, 0) end
    end)

  -- Meldungen in der Bildschirmmitte verschieben (blau hinterlegt, ziehen, Rechtsklick = fixieren)
  local moveMsg
  moveMsg = AddButton(P, RX, y - 268, L["Move messages"], 180, function()
    local on = ns.ToggleMessageMove and ns.ToggleMessageMove()
    moveMsg:SetText(on and L["Lock messages"] or L["Move messages"])
  end)

  -- Notfall-Knöpfe: verschieben, testen, Größe
  local moveTremor
  moveTremor = AddButton(P, RX, y - 298, L["Move emergency buttons"], 180, function()
    OutOfCombat(function()
      local on = ns.ToggleEmergencyMove and ns.ToggleEmergencyMove()
      moveTremor:SetText(on and L["Lock emergency buttons"] or L["Move emergency buttons"])
    end)
  end)
  -- Notfall-Knöpfe wieder oben an die Leiste hängen
  AddButton(P, LX + 4, y - 418, L["Attach emergency buttons to the bar"], 240, function()
    OutOfCombat(function()
      if ns.emergencyMoving and ns.ToggleEmergencyMove then
        ns.ToggleEmergencyMove(false)
        moveTremor:SetText(L["Move emergency buttons"])
      end
      if ns.AttachEmergency then ns.AttachEmergency() end
      Note(L["Emergency buttons attached to the bar."])
    end)
  end)
  AddButton(P, RX, y - 328, L["Test emergency alerts"], 180, function()
    if ns.TestEmergency then ns.TestEmergency() end
    Note(L["Simulating emergencies in 5 seconds."])
  end)
  tremorSlider = AddSlider(P, RX, y - 362, L["Emergency button size"], 40, 120, 4,
    function() return TotemWatchDB.tremorSize or 64 end,
    function(v)
      if InCombatLockdown() then return end
      TotemWatchDB.tremorSize = v
      if ns.SetupEmergency then ns.SetupEmergency() end
    end)
  -- Sichtbarkeit im Ruhezustand (in Prozent): 0 = unsichtbar, 100 = voll sichtbar
  dimSlider = AddSlider(P, RX, y - 404, L["Emergency buttons visibility at rest (%)"], 0, 100, 5,
    function() return math.floor(((TotemWatchDB.tremorDim or 0.15) * 100) + 0.5) end,
    function(v) TotemWatchDB.tremorDim = v / 100 end)

  local help = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", LX, y - 466)
  help:SetWidth(560)
  help:SetJustifyH("LEFT")
  help:SetText(L["Usage: left-click casts the totem, right-click opens the selection.\n"] ..
    L["Key bindings: Esc > Key Bindings > AddOns > TotemWatch.\n"] ..
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
