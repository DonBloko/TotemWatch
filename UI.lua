-- TotemWatch - Minimap-Knopf und Einführung (Tutorial)
local ADDON, ns = ...
if not ns.frame then return end   -- kein Schamane
local L = ns.L

local function Note(text) print("|cff0070deTotemWatch|r: " .. text) end

local function TotemIcon()
  local id = 8143   -- Totem des Erdstoßes
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  return (GetSpellTexture and GetSpellTexture(id)) or "Interface\\Icons\\Spell_Nature_TremorTotem"
end

---------------------------------------------------------------------------
-- Minimap-Knopf
---------------------------------------------------------------------------
local mm = CreateFrame("Button", "TotemWatchMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("AnyUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mmBg = mm:CreateTexture(nil, "BACKGROUND")
mmBg:SetSize(20, 20)
mmBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mmBg:SetPoint("TOPLEFT", 7, -5)
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetSize(18, 18)
mmIcon:SetPoint("TOPLEFT", 7, -6)
mmIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetPoint("TOPLEFT")

local function UpdateMinimapPosition()
  local angle = math.rad((TotemWatchDB and TotemWatchDB.minimapAngle) or 200)
  local r = (Minimap:GetWidth() / 2) + 10
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

-- Ziehen: Knopf wandert am Rand der Minimap entlang
mm:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    TotemWatchDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdateMinimapPosition()
  end)
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

mm:SetScript("OnClick", function(_, button)
  if button == "RightButton" then
    if InCombatLockdown() then Note(L["Not possible in combat."]) return end
    ns.ToggleTest()
    Note(L["Test mode "] .. (ns.state.test and L["on"] or L["off"]))
  elseif IsShiftKeyDown() then
    ns.StartTutorial()
  else
    ns.OpenOptions()
  end
end)

mm:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cff0070deTotemWatch|r")
  GameTooltip:AddLine(L["Left-click: options"], 1, 1, 1)
  GameTooltip:AddLine(L["Right-click: show/hide the bar"], 1, 1, 1)
  GameTooltip:AddLine(L["Shift-click: start the tour"], 1, 1, 1)
  GameTooltip:AddLine(L["Drag: move this button"], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.UpdateMinimapButton()
  mmIcon:SetTexture(TotemIcon())
  UpdateMinimapPosition()
  if TotemWatchDB.showMinimap then mm:Show() else mm:Hide() end
end

---------------------------------------------------------------------------
-- Einführung (Tutorial)
---------------------------------------------------------------------------
local tut = CreateFrame("Frame", "TotemWatchTutorial", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
tut:SetSize(460, 300)
tut:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
tut:SetFrameStrata("DIALOG")
tut:SetClampedToScreen(true)
tut:SetMovable(true)
tut:EnableMouse(true)
tut:RegisterForDrag("LeftButton")
tut:SetScript("OnDragStart", tut.StartMoving)
tut:SetScript("OnDragStop", tut.StopMovingOrSizing)
tut:Hide()
if tut.SetBackdrop then
  tut:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end

local tIcon = tut:CreateTexture(nil, "ARTWORK")
tIcon:SetSize(36, 36)
tIcon:SetPoint("TOPLEFT", 22, -22)
tIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local tTitle = tut:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
tTitle:SetPoint("TOPLEFT", tIcon, "TOPRIGHT", 10, -2)
tTitle:SetJustifyH("LEFT")

local tStep = tut:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
tStep:SetPoint("TOPLEFT", tTitle, "BOTTOMLEFT", 0, -3)

local tText = tut:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
tText:SetPoint("TOPLEFT", 24, -72)
tText:SetWidth(412)
tText:SetJustifyH("LEFT")
tText:SetSpacing(3)

-- Bereich für die Bedienelemente des jeweiligen Schritts
local content = CreateFrame("Frame", nil, tut)
content:SetPoint("TOPLEFT", tText, "BOTTOMLEFT", 0, -12)
content:SetSize(412, 110)

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 120, 24)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function MakeCheck(parent, key, label)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  fs:SetText(label)
  cb:SetScript("OnClick", function(self) TotemWatchDB[key] = self:GetChecked() and true or false end)
  cb.key = key
  return cb
end

local navBack = MakeButton(tut, L["Back"], 90, function() ns.TutorialGo(-1) end)
navBack:SetPoint("BOTTOMLEFT", 20, 18)
local navNext = MakeButton(tut, L["Next"], 110, function() ns.TutorialGo(1) end)
navNext:SetPoint("BOTTOMRIGHT", -20, 18)
local navSkip = MakeButton(tut, L["Skip tour"], 110, function() ns.FinishTutorial() end)
navSkip:SetPoint("RIGHT", navNext, "LEFT", -8, 0)

-- Schritte: Titel, Text, Bedienelemente (werden beim ersten Anzeigen gebaut)
local steps
local current = 1

local function OutOfCombat(fn)
  if InCombatLockdown() then Note(L["Not possible in combat – please change it after combat."]) return end
  fn()
end

local function EnsureTestMode()
  if not InCombatLockdown() and not ns.state.test then
    ns.ToggleTest()
    tut.turnedOnTest = true
  end
end

local function BuildSteps()
  steps = {
    { -- 1 Willkommen
      title = L["Welcome to TotemWatch"],
      text = L["TotemWatch shows which totems are missing in combat and recommends the right ones for your boss, your group and the situation.\n\nThis short tour helps you set it up. It takes about a minute. The bar is shown now so you can see every change right away."],
      onShow = EnsureTestMode,
    },
    { -- 2 Design
      title = L["Choose a design"],
      text = L["Pick the look you like best. The bar changes immediately."],
      build = function(f)
        f.skinButtons = {}
        for i, key in ipairs(ns.SKIN_ORDER) do
          local b = MakeButton(f, L[ns.SKINS[key].name], 98, function()
            OutOfCombat(function()
              TotemWatchDB.skin = key
              ns.ApplySkin(); ns.SafeCall("Display", ns.Refresh)
              for k, btn in pairs(f.skinButtons) do
                if k == key then btn:LockHighlight() else btn:UnlockHighlight() end
              end
            end)
          end)
          b:SetPoint("TOPLEFT", (i - 1) * 103, 0)
          f.skinButtons[key] = b
        end
      end,
      onShow = function(f)
        EnsureTestMode()
        for k, btn in pairs(f.skinButtons) do
          if k == TotemWatchDB.skin then btn:LockHighlight() else btn:UnlockHighlight() end
        end
      end,
    },
    { -- 3 Platzieren
      title = L["Place the bar"],
      text = L["Drag the bar by its top edge to where you want it.\nYou can also move the big warning messages: click the button, drag the blue area, then right-click it."],
      build = function(f)
        local move = MakeButton(f, L["Move messages"], 160, function(self)
          local on = ns.ToggleMessageMove()
          self:SetText(on and L["Lock messages"] or L["Move messages"])
        end)
        move:SetPoint("TOPLEFT", 0, 0)
        f.move = move
        local reset = MakeButton(f, L["Reset position"], 160, function()
          OutOfCombat(function() ns.ResetPosition() end)
        end)
        reset:SetPoint("LEFT", move, "RIGHT", 10, 0)
      end,
      onShow = function()
        EnsureTestMode()
        if TotemWatchDB.locked then TotemWatchDB.locked = false end   -- Verschieben erlauben
      end,
      onHide = function(f)
        if ns.msgMoving then ns.ToggleMessageMove(false); f.move:SetText(L["Move messages"]) end
      end,
    },
    { -- 4 Bedienung
      title = L["How to use the bar"],
      text = L["|cffffd100Left-click|r a totem button to drop that totem.\n|cffffd100Right-click|r it to choose another totem.\nA |cffffd100glowing|r button is what you should press now.\n|cffffd100Red|r = missing, |cffffd100yellow|r = expiring, |cffffd100orange|r = a better totem exists.\nIn the selection menu, |cffffd100right-click|r a totem to put it on your Call of the Elements bar – this also works in combat."],
      onShow = EnsureTestMode,
    },
    { -- 5 Tasten
      title = L["Key bindings"],
      text = L["Bind TotemWatch to your keys: every totem button, “Cast all”, Call of the Elements, Totemic Call and Totemic Recall can be put on a key. Look for the TotemWatch section."],
      build = function(f)
        local b = MakeButton(f, L["Open key bindings"], 180, function()
          local ok = false
          if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
            ok = pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
          end
          if not ok then
            if KeyBindingFrame_LoadUI then pcall(KeyBindingFrame_LoadUI) end
            if KeyBindingFrame then ok = pcall(ShowUIPanel, KeyBindingFrame) end
          end
          if not ok then Note(L["Open it via Esc > Key Bindings > AddOns > TotemWatch."]) end
        end)
        b:SetPoint("TOPLEFT", 0, 0)
      end,
    },
    { -- 6 Warnungen
      title = L["Warnings"],
      text = L["Choose how TotemWatch warns you. You can change all of this later in the options."],
      controlsHeight = 5 * 24 + 4,   -- 5 Häkchen untereinander
      build = function(f)
        f.checks = {
          MakeCheck(f, "messages", L["Messages in the middle of the screen"]),
          MakeCheck(f, "sound", L["Warning sound"]),
          MakeCheck(f, "glow", L["Glow recommended totems"]),
          MakeCheck(f, "distanceWarn", L["Distance to your totems"]),
          MakeCheck(f, "prePull", L["Pull check"]),
        }
        for i, cb in ipairs(f.checks) do
          -- untereinander (lange Texte würden in eine zweite Spalte hineinlaufen)
          cb:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
        end
      end,
      onShow = function(f)
        for _, cb in ipairs(f.checks) do cb:SetChecked(TotemWatchDB[cb.key] and true or false) end
      end,
    },
    { -- 7 Fertig
      title = L["All set!"],
      text = L["The bar appears automatically in combat. Before a pull (DBM/BigWigs pull timer or ready check) you get a checklist of what is missing.\n\nOpen the options any time with |cffffd100/tw|r or the minimap button. Shift-click the minimap button to see this tour again."],
    },
  }
  for _, s in ipairs(steps) do
    s.frame = CreateFrame("Frame", nil, content)
    s.frame:SetAllPoints()
    s.frame:Hide()
    if s.build then s.build(s.frame) end
  end
end

local function ShowStep(i)
  if steps[current] and steps[current].frame then
    steps[current].frame:Hide()
    if steps[current].onHide then steps[current].onHide(steps[current].frame) end
  end
  current = i
  local s = steps[i]
  tTitle:SetText(s.title)
  tStep:SetText(string.format(L["Step %d of %d"], i, #steps))
  tText:SetText(s.text)
  s.frame:Show()
  if s.onShow then s.onShow(s.frame) end
  navBack:SetEnabled(i > 1)
  navNext:SetText(i == #steps and L["Finish"] or L["Next"])
  navSkip:SetShown(i < #steps)
  -- Fensterhöhe an den Text anpassen
  local textH = tText:GetStringHeight() or 60
  local controls = s.controlsHeight or ((s.build and 70) or 0)
  tut:SetHeight(math.max(220, 72 + textH + 12 + controls + 60))
end

function ns.TutorialGo(dir)
  local nxt = current + dir
  if nxt > #steps then ns.FinishTutorial() return end
  if nxt < 1 then nxt = 1 end
  ShowStep(nxt)
end

function ns.StartTutorial()
  if not steps then BuildSteps() end
  tIcon:SetTexture(TotemIcon())
  tut:Show()
  ShowStep(1)
end

function ns.FinishTutorial()
  if steps and steps[current] and steps[current].onHide then steps[current].onHide(steps[current].frame) end
  tut:Hide()
  TotemWatchDB.tutorialDone = true
  -- Test-Ansicht wieder aus, wenn die Einführung sie eingeschaltet hat
  if tut.turnedOnTest and ns.state.test and not InCombatLockdown() then ns.ToggleTest() end
  tut.turnedOnTest = nil
  Note(L["Tour finished. Open it again with /tw tutorial or Shift-click on the minimap button."])
end
