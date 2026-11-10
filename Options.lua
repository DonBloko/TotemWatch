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

local scaleSlider, warnSlider, hintSlider, msgSlider, tremorSlider, dimSlider, afterSlider
local skinButtons = {}

-- Gewähltes Design im Menü hervorheben
local function RefreshSkinButtons()
  for key, btn in pairs(skinButtons) do
    if TotemWatchDB.skin == key then btn:LockHighlight() else btn:UnlockHighlight() end
  end
end

local dropdowns = {}

local function RefreshPanel()
  for _, c in ipairs(checks) do c.cb:SetChecked(TotemWatchDB[c.key] and true or false) end
  for _, s in ipairs({ scaleSlider, warnSlider, hintSlider, msgSlider, tremorSlider, dimSlider, afterSlider }) do
    if s then s.Refresh() end
  end
  for _, d in ipairs(dropdowns) do d.Refresh() end
  RefreshSkinButtons()
end

-- Eigene Auswahlliste (Blizzards UIDropDownMenu kann im Optionsmenü Taint-Fehler auslösen).
-- items = { { value = ..., text = "..." }, ... }
local openList
local function AddDropdown(parent, x, y, label, width, items, getter, setter, tooltip, needsOOC)
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  title:SetPoint("TOPLEFT", x, y)
  title:SetText(label)

  local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetSize(width, 24)
  b:SetPoint("TOPLEFT", x, y - 18)
  if b.SetBackdrop then
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    b:SetBackdropBorderColor(0.35, 0.35, 0.38, 1)
  end
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", 8, 0); b.text:SetPoint("RIGHT", -22, 0); b.text:SetJustifyH("LEFT")
  b.arrow = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.arrow:SetPoint("RIGHT", -8, 0); b.arrow:SetText("v")
  b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
  b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)

  -- Liste
  local list = CreateFrame("Frame", nil, b, BackdropTemplateMixin and "BackdropTemplate" or nil)
  list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
  list:SetSize(width, #items * 22 + 6)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetFrameLevel(b:GetFrameLevel() + 20)
  if list.SetBackdrop then
    list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    list:SetBackdropColor(0.04, 0.04, 0.05, 0.98)
    list:SetBackdropBorderColor(0.35, 0.35, 0.38, 1)
  end
  list:Hide()
  list:EnableMouse(true)

  local function Refresh()
    local cur = getter()
    for _, it in ipairs(items) do
      if it.value == cur then b.text:SetText(it.text) end
    end
  end
  b.Refresh = Refresh

  for i, it in ipairs(items) do
    local row = CreateFrame("Button", nil, list)
    row:SetSize(width - 6, 22)
    row:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 22)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetText(it.text)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    row:GetHighlightTexture():SetVertexColor(0.2, 0.5, 1, 0.35)
    row:SetScript("OnClick", function()
      list:Hide(); openList = nil
      local apply = function() setter(it.value) end
      if needsOOC then OutOfCombat(apply) else apply() end
      Refresh()
    end)
  end

  b:SetScript("OnClick", function()
    if list:IsShown() then
      list:Hide(); openList = nil
    else
      if openList then openList:Hide() end
      list:Show(); openList = list
    end
  end)
  if tooltip then
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(label, 1, 1, 1)
      GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  b:SetScript("OnHide", function() list:Hide(); if openList == list then openList = nil end end)
  dropdowns[#dropdowns + 1] = b
  return b
end


-- Kleine graue Beschreibung unter einer Überschrift
local function AddNote(parent, x, y, text, width)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetWidth(width or 270)
  fs:SetJustifyH("LEFT")
  fs:SetTextColor(0.7, 0.7, 0.7)
  fs:SetText(text)
  return fs
end

local function ApplyLook()
  if ns.ApplySkin then ns.ApplySkin() end
  if ns.Refresh then ns.SafeCall("Display", ns.Refresh) end
end

function ns.CreateOptions()
  if panel then return end
  panel = CreateFrame("Frame")
  panel.name = "TotemWatch"
  panel:Hide()

  -- Kopf: Titel, Untertitel, Einführung
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L["|cff0070deTotemWatch|r – Options"])
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText(L["Totem recommendations, warnings and the totem bar. Some changes only work out of combat."])
  local tourBtn = AddButton(panel, 0, 0, L["Start tour"], 140, function()
    if ns.StartTutorial then ns.StartTutorial() end
  end)
  tourBtn:ClearAllPoints()
  tourBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)

  -- Inhalt: scrollbar (falls das Fenster klein ist), darin eine Seite je Reiter
  local scroll
  local okTemplate = pcall(function()
    scroll = CreateFrame("ScrollFrame", "TotemWatchOptionsScroll", panel, "UIPanelScrollFrameTemplate")
  end)
  if not okTemplate or not scroll then
    scroll = CreateFrame("ScrollFrame", "TotemWatchOptionsScroll", panel)
  end
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -96)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 4)
  local P = CreateFrame("Frame", nil, scroll)
  P:SetSize(640, 400)
  scroll:SetScrollChild(P)
  scroll:SetScript("OnSizeChanged", function(self, w)
    if w and w > 0 then P:SetWidth(w) end
  end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
  end)

  local LX, RX = 16, 320   -- Spalten-Positionen (nicht L = Übersetzung!)

  -- Reiter
  local TABS = {
    { key = "look",      label = L["Look"],      height = 330 },
    { key = "bar",       label = L["Bar"],       height = 300 },
    { key = "alerts",    label = L["Warnings"],  height = 300 },
    { key = "emergency", label = L["Emergency"], height = 260 },
    { key = "help",      label = L["Help"],      height = 140 },
  }
  local pages, tabButtons = {}, {}
  local function ShowTab(key)
    for _, t in ipairs(TABS) do
      if t.key == key then
        pages[t.key]:Show(); tabButtons[t.key]:LockHighlight()
        P:SetHeight(t.height)
      else
        pages[t.key]:Hide(); tabButtons[t.key]:UnlockHighlight()
      end
    end
    scroll:SetVerticalScroll(0)
    -- Scrollleiste nur zeigen, wenn der Inhalt nicht ins Fenster passt
    local sb = scroll.ScrollBar or _G["TotemWatchOptionsScrollScrollBar"]
    if sb and C_Timer then
      C_Timer.After(0, function() sb:SetShown((scroll:GetVerticalScrollRange() or 0) > 1) end)
    end
    if TotemWatchDB then TotemWatchDB.optTab = key end
  end
  for i, t in ipairs(TABS) do
    local page = CreateFrame("Frame", nil, P)
    page:SetAllPoints(P)
    page:Hide()
    pages[t.key] = page
    local b = AddButton(panel, 16 + (i - 1) * 116, -60, t.label, 112, function() ShowTab(t.key) end)
    tabButtons[t.key] = b
  end
  -- Trennlinie unter den Reitern
  local line = panel:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.15)
  line:SetPoint("TOPLEFT", 16, -90); line:SetPoint("TOPRIGHT", -16, -90); line:SetHeight(1)

  -----------------------------------------------------------------------
  -- Aussehen
  -----------------------------------------------------------------------
  local p = pages.look
  AddHeader(p, LX, -8, L["Appearance"])

  local designItems = {}
  for _, key in ipairs(ns.SKIN_ORDER) do
    designItems[#designItems + 1] = { value = key, text = L[ns.SKINS[key].name] }
  end
  AddDropdown(p, LX, -30, L["Design"], 230, designItems,
    function() return TotemWatchDB.skin or "classic" end,
    function(v) TotemWatchDB.skin = v; ApplyLook() end,
    L["Layout of the bar. You can also use /tw skin <name>."], true)

  AddDropdown(p, LX, -84, L["Style"], 230, {
      { value = true,  text = L["Clean"] },
      { value = false, text = L["Blizzard (frames and title)"] },
    },
    function() return TotemWatchDB.cleanLook and true or false end,
    function(v) TotemWatchDB.cleanLook = v; ApplyLook() end,
    L["Thin dark frames, color only where you have to act, calmer icons, smaller glow and no mini icons (they are in the tooltip). Works with every design."], true)

  AddDropdown(p, LX, -138, L["Icon shape"], 230, {
      { value = false, text = L["Square"] },
      { value = true,  text = L["Round"] },
    },
    function() return TotemWatchDB.roundIcons and true or false end,
    function(v) TotemWatchDB.roundIcons = v; ApplyLook() end,
    L["Shows the totem, weapon and shield icons as circles with a thin ring. The ring shows the status color."], true)

  AddDropdown(p, LX, -192, L["Hints below the bar"], 230, {
      { value = "short", text = L["One line (next step)"] },
      { value = "full",  text = L["Full list"] },
      { value = "off",   text = L["Off"] },
    },
    function()
      if not TotemWatchDB.showHints then return "off" end
      return TotemWatchDB.shortHints and "short" or "full"
    end,
    function(v)
      TotemWatchDB.showHints = (v ~= "off")
      TotemWatchDB.shortHints = (v == "short")
      if ns.Refresh then ns.SafeCall("Display", ns.Refresh) end
    end,
    L["Explanations below the bar: what is missing and why."])

  AddCheck(p, LX, -248, "glow", L["Glow recommended totems"],
    L["The button (or the totem in the selection) that you should press glows."])

  AddHeader(p, RX, -8, L["Sizes"])
  scaleSlider = AddSlider(p, RX, -30, L["Size"], 0.5, 2.0, 0.05,
    function() return TotemWatchDB.scale or 1 end,
    function(v)
      if InCombatLockdown() then return end
      TotemWatchDB.scale = v
      ns.ApplyPosition()
    end)
  hintSlider = AddSlider(p, RX, -84, L["Hint text size"], 9, 20, 1,
    function() return TotemWatchDB.hintSize or 13 end,
    function(v) TotemWatchDB.hintSize = v; if ns.ApplyHintFont then ns.ApplyHintFont() end end)
  msgSlider = AddSlider(p, RX, -138, L["Message size"], 14, 40, 1,
    function() return TotemWatchDB.messageSize or 24 end,
    function(v)
      TotemWatchDB.messageSize = v
      if ns.ApplyMessageFont then ns.ApplyMessageFont() end
      if ns.ShowMessage then ns.ShowMessage(L["TotemWatch test message"] .. " " .. v, 1, 0.82, 0) end
    end)

  -----------------------------------------------------------------------
  -- Leiste
  -----------------------------------------------------------------------
  p = pages.bar
  AddHeader(p, LX, -8, L["Buttons"])
  AddCheck(p, LX, -28, "showAll", L["Cast-all button"], nil, function() ns.SetupSecure() end, true)
  AddCheck(p, LX, -54, "showWeapon", L["Weapon enchant button"], nil, function() ns.SetupSecure() end, true)
  AddCheck(p, LX, -80, "showShield", L["Shield button"], nil, function() ns.SetupSecure() end, true)
  AddCheck(p, LX, -106, "showCall", L["Call of the Elements button"],
    L["Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(p, LX, -132, "syncCall", L["Sync Call of the Elements"],
    L["Puts the totems from your TotemWatch buttons on the Call of the Elements bar (out of combat)."],
    function() ns.SetupSecure() end, true)
  AddCheck(p, LX, -158, "showMove", L["Totemic Call button"],
    L["Moves your totems to you. Only shown if you know the spell."], function() ns.SetupSecure() end, true)
  AddCheck(p, LX, -184, "showRecall", L["Totemic Recall button"],
    L["Removes your totems. Only shown if you know the spell."], function() ns.SetupSecure() end, true)

  local function applyVis() ns.ApplyVisibilityDriver(); ns.UpdateVisibility() end
  AddHeader(p, RX, -8, L["Visibility"])
  AddCheck(p, RX, -28, "showOOC", L["Also show out of combat"], nil, applyVis, true)
  AddCheck(p, RX, -54, "showInDungeon", L["Always show in dungeons"],
    L["The bar stays visible in dungeons, also between fights."], applyVis, true)
  AddCheck(p, RX, -80, "showInRaid", L["Always show in raids"],
    L["The bar stays visible in raids, also between fights."], applyVis, true)
  AddCheck(p, RX, -106, "locked", L["Lock window"],
    L["Prevents accidental moving via the title bar."])
  AddCheck(p, RX, -132, "showMinimap", L["Minimap button"],
    L["Left-click: options · Right-click: show/hide the bar · Shift-click: tour"],
    function() if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end end)
  AddCheck(p, RX, -158, "useMasque", L["Use Masque (if installed)"],
    L["Styles the buttons with your Masque skin. Changes need a /reload."])
  afterSlider = AddSlider(p, RX, -192, L["Keep visible after combat (sec.)"], 0, 30, 1,
    function() return TotemWatchDB.afterCombat or 0 end,
    function(v) TotemWatchDB.afterCombat = v end)
  AddButton(p, LX + 4, -248, L["Test display (on/off)"], 180, function()
    OutOfCombat(function()
      ns.ToggleTest()
      Note(L["Test mode "] .. (ns.state.test and L["on"] or L["off"]))
    end)
  end)
  AddButton(p, LX + 194, -248, L["Reset position"], 180, function()
    OutOfCombat(function() ns.ResetPosition(); RefreshPanel() end)
  end)

  -----------------------------------------------------------------------
  -- Warnungen (inkl. Empfehlungen und Meldungen)
  -----------------------------------------------------------------------
  p = pages.alerts
  AddHeader(p, LX, -8, L["Recommendations"])
  AddCheck(p, LX, -28, "auto", L["Auto-assign buttons"],
    L["Out of combat, the totem buttons are set to the recommended totem."],
    function()
      wipe(ns.state.lastRec)
      if TotemWatchDB.manual then wipe(TotemWatchDB.manual) end   -- eigene Festlegungen aufheben
    end)
  AddCheck(p, LX, -54, "useBoss", L["Use boss rules"],
    L["Recommendations per boss (detected via Blizzard, DBM or BigWigs)."])
  AddCheck(p, LX, -80, "useOthers", L["Consider other shamans"],
    L["Detect totems of other shamans in your group and avoid duplicates."])

  AddHeader(p, LX, -122, L["Messages"])
  AddCheck(p, LX, -142, "messages", L["Messages in the middle of the screen"],
    L["Large messages for missing totems, fear and destroyed totems. Each message is shown only once."])
  AddCheck(p, LX, -168, "sound", L["Warning sound"],
    L["Sound on urgent warnings (fear, destroyed totem)."])
  AddCheck(p, LX, -194, "speak", L["Speak warnings (text to speech)"],
    L["Important warnings are read out loud, e.g. “Tremor Totem now!”."],
    function(on) if on and ns.Speak then ns.Speak(L["TotemWatch voice warnings on"], true) end end)
  AddButton(p, LX + 4, -230, L["Test warnings"], 140, function()
    if ns.TestWarnings then ns.TestWarnings() end
  end)
  local moveMsg
  moveMsg = AddButton(p, LX + 150, -230, L["Move messages"], 140, function()
    local on = ns.ToggleMessageMove and ns.ToggleMessageMove()
    moveMsg:SetText(on and L["Lock messages"] or L["Move messages"])
  end)

  AddHeader(p, RX, -8, L["Warnings"])
  AddCheck(p, RX, -28, "rangeWarn", L["Range warning"],
    L["Shows who does not have your totem's buff (out of range). Works for totems with a buff, e.g. Strength of Earth, Mana Spring, Grace of Air, resistances."])
  AddCheck(p, RX, -54, "distanceWarn", L["Distance to your totems"],
    L["Warns when you are farther from your totems than their range."])
  AddCheck(p, RX, -80, "destroyWarn", L["Warn when a totem is destroyed"],
    L["Warns when a totem disappears early (killed, Grounding absorbed a spell)."])
  AddCheck(p, RX, -106, "enemyCasts", L["Fear from enemy casts"],
    L["Detects via nameplates when an enemy casts fear and recommends Tremor Totem."])
  AddCheck(p, RX, -132, "prePull", L["Pull check"],
    L["Shows a checklist on pull timer (DBM/BigWigs) and ready check: totems, shield, weapon, range."])
  warnSlider = AddSlider(p, RX, -170, L["Warning before expiry (sec., 0 = off)"], 0, 15, 1,
    function() return TotemWatchDB.warnBefore or 0 end,
    function(v) TotemWatchDB.warnBefore = v end)

  -----------------------------------------------------------------------
  -- Notfall-Knöpfe
  -----------------------------------------------------------------------
  p = pages.emergency
  AddHeader(p, LX, -8, L["Emergency buttons"])
  AddNote(p, LX, -26, L["Each button always casts the same totem. It is almost invisible at rest and lights up when danger is coming."], 560)
  AddCheck(p, LX, -64, "tremorButton", L["Emergency Tremor button"],
    L["A big button that always casts Tremor Totem. It is dimmed and lights up when a fear is coming."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)
  AddCheck(p, LX, -90, "poisonButton", L["Emergency Poison Cleansing button"],
    L["Always casts Poison Cleansing Totem. Lights up when enemies cast poison."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)
  AddCheck(p, LX, -116, "diseaseButton", L["Emergency Disease Cleansing button"],
    L["Always casts Disease Cleansing Totem. Lights up when enemies cast diseases."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)
  AddCheck(p, LX, -142, "groundingButton", L["Emergency Grounding button"],
    L["Always casts Grounding Totem. Lights up when an enemy casts a dangerous spell (Polymorph, Hex, Fear …)."],
    function() if ns.SetupEmergency then ns.SetupEmergency() end end, true)

  tremorSlider = AddSlider(p, RX, -64, L["Emergency button size"], 32, 120, 4,
    function() return TotemWatchDB.tremorSize or 44 end,
    function(v)
      if InCombatLockdown() then return end
      TotemWatchDB.tremorSize = v
      if ns.SetupEmergency then ns.SetupEmergency() end
    end)
  dimSlider = AddSlider(p, RX, -109, L["Emergency buttons visibility at rest (%)"], 0, 100, 5,
    function() return math.floor(((TotemWatchDB.tremorDim or 0.15) * 100) + 0.5) end,
    function(v) TotemWatchDB.tremorDim = v / 100 end)

  local moveTremor
  moveTremor = AddButton(p, LX + 4, -190, L["Move emergency buttons"], 190, function()
    OutOfCombat(function()
      local on = ns.ToggleEmergencyMove and ns.ToggleEmergencyMove()
      moveTremor:SetText(on and L["Lock emergency buttons"] or L["Move emergency buttons"])
    end)
  end)
  AddButton(p, LX + 200, -190, L["Attach emergency buttons to the bar"], 240, function()
    OutOfCombat(function()
      if ns.emergencyMoving and ns.ToggleEmergencyMove then
        ns.ToggleEmergencyMove(false)
        moveTremor:SetText(L["Move emergency buttons"])
      end
      if ns.AttachEmergency then ns.AttachEmergency() end
      Note(L["Emergency buttons attached to the bar."])
    end)
  end)
  AddButton(p, LX + 4, -220, L["Test emergency alerts"], 190, function()
    if ns.TestEmergency then ns.TestEmergency() end
    Note(L["Simulating emergencies in 5 seconds."])
  end)

  -----------------------------------------------------------------------
  -- Hilfe
  -----------------------------------------------------------------------
  p = pages.help
  AddHeader(p, LX, -8, L["Help"])
  local help = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  help:SetPoint("TOPLEFT", LX, -30)
  help:SetWidth(580)
  help:SetJustifyH("LEFT")
  help:SetSpacing(4)
  help:SetText(L["Usage: left-click casts the totem, right-click opens the selection.\n"] ..
    L["Key bindings: Esc > Key Bindings > AddOns > TotemWatch.\n"] ..
    L["Commands: /tw help · /tw check · /tw probe · /tw boss <ID> · /tw other <totem>"] .. "\n" ..
    L["Designs: /tw skin <name> · Clean look: /tw clean · Round icons: /tw round · Emergency: /tw sos test"])

  -- Solange das Menü offen ist: Leiste im Testmodus zeigen und über das Optionsfenster legen,
  -- damit jede Änderung sofort sichtbar ist. Beim Schließen wieder wie vorher.
  -- Ausgeschaltet wird erst, wenn das GANZE Optionsfenster schließt (Forevers Optionsfenster
  -- blendet die Seite beim Öffnen kurz aus und wieder ein – das darf die Vorschau nicht beenden).
  local host = SettingsPanel or InterfaceOptionsFrame
  if host and host.HookScript then
    host:HookScript("OnHide", function() if ns.OptionsPreviewOff then ns.OptionsPreviewOff() end end)
  else
    panel:SetScript("OnHide", function() if ns.OptionsPreviewOff then ns.OptionsPreviewOff() end end)
  end
  panel:SetScript("OnShow", function()
    if ns.OptionsPreviewOn then ns.OptionsPreviewOn() end
    RefreshPanel()
    local want = TotemWatchDB and TotemWatchDB.optTab
    local found = false
    for _, t in ipairs(TABS) do if t.key == want then found = true end end
    ShowTab(found and want or "look")
  end)
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

-- Vorschau: solange das Menü offen ist, Leiste im Testmodus über dem Optionsfenster zeigen
local previewTest, previewStrata
function ns.OptionsPreviewOn()
  if InCombatLockdown() then return end
  if not ns.state.test then ns.ToggleTest(); previewTest = true end
  if not previewStrata then
    previewStrata = ns.frame:GetFrameStrata()
    ns.frame:SetFrameStrata("FULLSCREEN_DIALOG")
  end
end
function ns.OptionsPreviewOff()
  if InCombatLockdown() then return end
  if previewTest and ns.state.test then ns.ToggleTest() end
  previewTest = nil
  if previewStrata then ns.frame:SetFrameStrata(previewStrata); previewStrata = nil end
end

function ns.OpenOptions()
  if not panel then ns.CreateOptions() end
  ns.OptionsPreviewOn()
  if Settings and Settings.OpenToCategory and category then
    Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)   -- bekannter Blizzard-Bug: zweimal nötig
  else
    Note(L["Options menu not available – use /tw help"])
  end
end
