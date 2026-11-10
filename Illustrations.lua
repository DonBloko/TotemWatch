-- TotemWatch - Bilder für Einführung und Hilfe
-- Die Bilder werden aus echten Spielsymbolen, den TotemWatch-Ringen und ein paar eigenen
-- Texturen (Maus, Pfeile) zusammengesetzt. Beschriftungen sind normaler Text und damit übersetzt.
-- Keine Masken-Texturen (Masken haben bei WoW Forever einen Absturz ausgelöst).
local ADDON, ns = ...
if not ns.frame then return end   -- kein Schamane
local L = ns.L

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local ROWS = 16

local ICON = {   -- Beispiel-Symbole (Zauber-IDs)
  fire = 3599, earth = 8075, water = 5675, air = 8512,
  tremor = 8143, poison = 8166, call = 66842, ancestors = 66843, weapon = 8017, shield = 324,
}
local STATUS = {
  missing = { 1, 0.1, 0.1 }, expiring = { 1, 0.85, 0 }, wrong = { 1, 0.5, 0 },
  ok = { 0.1, 0.9, 0.1 }, calm = { 0.08, 0.08, 0.08 }, far = { 1, 0.55, 0.1 },
}

local function Tex(id)
  local t = ns.SpellIcon and ns.SpellIcon(id)
  return t or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Text(parent, text, x, y, color, size, anchor)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(STANDARD_TEXT_FONT, size or 11, "")
  fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
  fs:SetPoint(anchor or "TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  return fs
end

-- Symbol, eckig oder rund (folgt der Einstellung "Symbolform"), mit Statusfarbe und Leuchten
local function Icon(parent, x, y, size, spell, status, glow, timer)
  local o = CreateFrame("Frame", nil, parent)
  o:SetSize(size, size)
  o:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local tex = Tex(spell)

  o.border = o:CreateTexture(nil, "BACKGROUND")
  o.border:SetAllPoints()
  o.square = o:CreateTexture(nil, "ARTWORK")
  o.square:SetPoint("TOPLEFT", 1, -1); o.square:SetPoint("BOTTOMRIGHT", -1, 1)
  o.square:SetTexture(tex); o.square:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  o.line = o:CreateTexture(nil, "OVERLAY", nil, 2)
  o.line:SetHeight(3); o.line:SetPoint("BOTTOMLEFT", 1, 1); o.line:SetPoint("BOTTOMRIGHT", -1, 1)

  o.strips = {}
  for i = 1, ROWS do
    local t = o:CreateTexture(nil, "ARTWORK")
    t:SetTexture(tex)
    local y0, y1 = (i - 1) / ROWS, i / ROWS
    local yc = (y0 + y1) / 2 - 0.5
    local hw = math.sqrt(math.max(0, 0.25 - yc * yc))
    local x0, x1 = 0.5 - hw, 0.5 + hw
    t:SetPoint("TOPLEFT", o, "TOPLEFT", x0 * size, -y0 * size)
    t:SetSize(math.max(0.1, (x1 - x0) * size), size / ROWS + 0.05)
    t:SetTexCoord(0.08 + x0 * 0.84, 0.08 + x1 * 0.84, 0.08 + y0 * 0.84, 0.08 + y1 * 0.84)
    o.strips[i] = t
  end
  o.ring = o:CreateTexture(nil, "OVERLAY", nil, 1)
  o.ring:SetTexture(MEDIA .. "round_ring")
  o.ring:SetPoint("TOPLEFT", -1, 1); o.ring:SetPoint("BOTTOMRIGHT", 1, -1)

  if glow then
    o.glow = o:CreateTexture(nil, "OVERLAY", nil, 3)
    o.glow:SetBlendMode("ADD")
    o.glow:SetPoint("CENTER")
  end
  if timer then
    o.timer = o:CreateFontString(nil, "OVERLAY")
    o.timer:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    o.timer:SetPoint("TOP", o, "BOTTOM", 0, -1)
    o.timer:SetText(timer)
  end

  function o.Refresh()
    local round = TotemWatchDB and TotemWatchDB.roundIcons
    local c = STATUS[status or "calm"]
    local calm = (status == nil or status == "calm" or status == "ok")
    o.square:SetShown(not round)
    o.border:SetShown(not round)
    o.border:SetColorTexture(0.06, 0.06, 0.06, 0.9)
    o.line:SetShown(not round and not calm)
    o.line:SetColorTexture(c[1], c[2], c[3], 1)
    for _, t in ipairs(o.strips) do t:SetShown(round) end
    o.ring:SetShown(round)
    if calm then o.ring:SetVertexColor(0.08, 0.08, 0.08, 0.95) else o.ring:SetVertexColor(c[1], c[2], c[3], 1) end
    if o.glow then
      if round then
        o.glow:SetTexture(MEDIA .. "round_glow"); o.glow:SetSize(size * 1.7, size * 1.7)
        o.glow:SetVertexColor(1, 0.85, 0.2, 0.5)
      else
        o.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); o.glow:SetSize(size * 1.85, size * 1.85)
        o.glow:SetVertexColor(1, 0.85, 0.2, 0.9)
      end
    end
  end
  o.Refresh()
  return o
end

local function Mouse(parent, x, y, side, size)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetTexture(MEDIA .. (side == "right" and "mouse_right" or "mouse_left"))
  t:SetSize(size or 26, size or 26)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  return t
end

local function Arrow(parent, x, y, dir, len, color)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetTexture(MEDIA .. ((dir == "up") and "arrow_up" or "arrow_right"))
  if dir == "left" then t:SetTexCoord(1, 0, 0, 1) end
  if dir == "up" then t:SetSize(16, len or 22) else t:SetSize(len or 22, 16) end
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local c = color or { 1, 0.82, 0 }
  t:SetVertexColor(c[1], c[2], c[3], 0.9)
  return t
end

local function Badge(parent, x, y, n)
  local t = parent:CreateTexture(nil, "OVERLAY", nil, 5)
  t:SetTexture(MEDIA .. "round_disc"); t:SetVertexColor(1, 0.82, 0, 1)
  t:SetSize(16, 16); t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(STANDARD_TEXT_FONT, 10, "")
  fs:SetTextColor(0.2, 0.13, 0); fs:SetPoint("CENTER", t, "CENTER", 0, 0)
  fs:SetText(n)
  fs:SetDrawLayer("OVERLAY", 6)
  return t
end

local function Grip(parent, x, y, h)
  local g = parent:CreateTexture(nil, "ARTWORK")
  g:SetColorTexture(0, 0, 0, 0.6)
  g:SetSize(10, h); g:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  for r = 1, 3 do
    for c = 1, 2 do
      local d = parent:CreateTexture(nil, "OVERLAY")
      d:SetColorTexture(0.85, 0.85, 0.85, 1); d:SetSize(2, 2)
      d:SetPoint("CENTER", g, "CENTER", (c - 1.5) * 4, (2 - r) * 4)
    end
  end
  return g
end

local function Panel(parent, w, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, h)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.08, 0.85)
  f.edge = f:CreateTexture(nil, "BORDER")
  f.edge:SetPoint("TOPLEFT", -1, 1); f.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  f.edge:SetColorTexture(0.3, 0.3, 0.34, 0.8)
  f.edge:SetDrawLayer("BACKGROUND", -1)
  f.icons = {}
  function f.Refresh() for _, o in ipairs(f.icons) do o.Refresh() end end
  return f
end

local SCENES = {}

-- Bedienung: Linksklick stellt, Rechtsklick öffnet die Auswahl
SCENES.click = function(parent, w)
  local f = Panel(parent, w, 118)
  local ic = f.icons
  ic[#ic + 1] = Icon(f, 18, -64, 32, ICON.fire, "missing", true)
  ic[#ic + 1] = Icon(f, 56, -64, 32, ICON.earth, "ok", false, "4m")
  ic[#ic + 1] = Icon(f, 94, -64, 32, ICON.water, "ok", false, "2m")
  Mouse(f, 22, -14, "left")
  Arrow(f, 26, -40, "up", 22)
  Text(f, L["Left-click: cast"], 52, -20, { 0.62, 0.88, 0.8 })
  -- Auswahl über Erde (drei kleine Symbole übereinander)
  local x0 = 220
  ic[#ic + 1] = Icon(f, x0, -64, 32, ICON.earth, "ok", false)
  ic[#ic + 1] = Icon(f, x0 + 4, -38, 24, ICON.tremor)
  ic[#ic + 1] = Icon(f, x0 + 4, -12, 24, 8071)
  Mouse(f, x0 + 40, -66, "right")
  Text(f, L["Right-click: choose another totem"], x0 + 70, -72, { 0.52, 0.72, 0.92 })
  Text(f, L["Glowing = cast now"], 14, -102, { 1, 0.82, 0 }, 10)
  return f
end

-- Statusfarben
SCENES.status = function(parent, w)
  local f = Panel(parent, w, 92)
  local items = {
    { ICON.fire, "missing", true, nil, L["missing"], STATUS.missing },
    { ICON.earth, "expiring", false, "7", L["expiring"], STATUS.expiring },
    { ICON.water, "wrong", false, "1m", L["better totem"], STATUS.wrong },
    { ICON.air, "far", false, nil, L["out of range"], STATUS.far },
    { ICON.weapon, "ok", false, "28m", L["all good"], { 0.6, 0.9, 0.6 } },
  }
  local step = math.floor((w - 20) / #items)
  for i, it in ipairs(items) do
    local x = 14 + (i - 1) * step + math.floor((step - 32) / 2)
    f.icons[#f.icons + 1] = Icon(f, x, -14, 32, it[1], it[2], it[3], it[4])
    if it[2] == "far" then
      local fs = Text(f, L["far"], x + 16, -24, STATUS.far, 10, "TOP")
      fs:ClearAllPoints(); fs:SetPoint("CENTER", f.icons[#f.icons], "CENTER", 0, 0)
    end
    local lab = Text(f, it[5], 0, 0, it[6], 10)
    lab:ClearAllPoints(); lab:SetPoint("TOP", f.icons[#f.icons], "BOTTOM", 0, -16)
  end
  return f
end

-- Griff: ziehen = verschieben, Rechtsklick = Vorlagen
SCENES.grip = function(parent, w)
  local f = Panel(parent, w, 112)
  local gx = 40
  Grip(f, gx, -54, 32)
  for i, sp in ipairs({ ICON.fire, ICON.earth, ICON.water }) do
    f.icons[#f.icons + 1] = Icon(f, gx + 14 + (i - 1) * 36, -54, 32, sp, "ok")
  end
  Mouse(f, gx - 30, -58, "left")
  Arrow(f, gx - 32, -88, "left", 22)
  Arrow(f, gx - 8, -88, "right", 22)
  Text(f, L["Drag: move the bar"], 10, -14, { 0.62, 0.88, 0.8 })
  -- Vorlagen-Liste
  local lx = 210
  Mouse(f, lx - 34, -56, "right")
  local list = f:CreateTexture(nil, "ARTWORK")
  list:SetColorTexture(0.02, 0.02, 0.03, 0.95)
  list:SetSize(w - lx - 14, 66); list:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -36)
  local names = { L["Solo"], L["Dungeon AoE"], L["Raid melee"] }
  for r = 1, 3 do
    for s, sp in ipairs({ ICON.fire, ICON.earth, ICON.water, ICON.air }) do
      local t = f:CreateTexture(nil, "OVERLAY")
      t:SetTexture(Tex(sp)); t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      t:SetSize(14, 14); t:SetPoint("TOPLEFT", f, "TOPLEFT", lx + 4 + (s - 1) * 16, -40 - (r - 1) * 21)
    end
    Text(f, names[r], lx + 72, -41 - (r - 1) * 21, r == 2 and { 0.52, 0.72, 0.92 } or nil, 10)
  end
  Text(f, L["Right-click: your templates"], lx, -14, { 0.52, 0.72, 0.92 })
  return f
end

-- Ruf-Knopf: Rechtsklick wählt den Ruf, daneben steht die Vorlage
SCENES.calls = function(parent, w)
  local f = Panel(parent, w, 112)
  f.icons[#f.icons + 1] = Icon(f, 24, -66, 30, ICON.call)
  Mouse(f, 60, -68, "right")
  local rows = { { ICON.call, L["Call of the Elements"], L["Solo"] },
                 { ICON.ancestors, L["Call of the Ancestors"], L["Dungeon AoE"] } }
  for i, r in ipairs(rows) do
    local y = -12 - (i - 1) * 26
    f.icons[#f.icons + 1] = Icon(f, 104, y, 22, r[1])
    Text(f, r[2], 132, y - 4, { 1, 1, 1 }, 11)
    Text(f, r[3], 290, y - 4, { 0.52, 0.72, 0.92 }, 11)
  end
  Text(f, L["Left-click casts the chosen call – its totems come from the template."], 104, -76, { 0.8, 0.8, 0.8 }, 10)
  return f
end

-- Notfall-Knöpfe
SCENES.emergency = function(parent, w)
  local f = Panel(parent, w, 104)
  f.icons[#f.icons + 1] = Icon(f, 20, -14, 36, ICON.tremor, "missing", true)
  Text(f, L["Fear in 3"], 62, -24, STATUS.missing, 12)
  f.icons[#f.icons + 1] = Icon(f, 150, -14, 36, ICON.poison, "calm")
  for i, sp in ipairs({ ICON.fire, ICON.earth, ICON.water }) do
    f.icons[#f.icons + 1] = Icon(f, 20 + (i - 1) * 32, -62, 28, sp, "ok")
  end
  Text(f, L["Lights up when a boss mod or an enemy announces fear, poison, disease or a dangerous spell – one click casts the right totem."], 150, -62, { 0.85, 0.85, 0.85 }, 10)
  return f
end

-- Überblick für die Hilfe: Leiste mit Nummern
SCENES.overview = function(parent, w)
  local f = Panel(parent, w, 96)
  Grip(f, 16, -40, 32)
  Badge(f, 12, -18, "1")
  for i, sp in ipairs({ ICON.fire, ICON.earth, ICON.water, ICON.air }) do
    f.icons[#f.icons + 1] = Icon(f, 30 + (i - 1) * 36, -40, 32, sp, (i == 1) and "missing" or "ok", i == 1, (i > 1) and "3m" or nil)
  end
  Badge(f, 42, -18, "2")
  local all = f:CreateTexture(nil, "ARTWORK")
  all:SetTexture(MEDIA .. "round_disc"); all:SetVertexColor(0.05, 0.25, 0.55, 1)
  all:SetSize(24, 24); all:SetPoint("TOPLEFT", f, "TOPLEFT", 182, -44)
  local allT = f:CreateFontString(nil, "OVERLAY"); allT:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
  allT:SetPoint("CENTER", all, "CENTER"); allT:SetText(L["ALL"]); allT:SetTextColor(1, 0.82, 0)
  Badge(f, 186, -18, "3")
  f.icons[#f.icons + 1] = Icon(f, 212, -44, 24, ICON.call)
  Badge(f, 216, -18, "4")
  f.icons[#f.icons + 1] = Icon(f, 244, -44, 24, ICON.weapon, "ok", false, "28m")
  f.icons[#f.icons + 1] = Icon(f, 272, -44, 24, ICON.shield, "missing")
  Badge(f, 260, -18, "5")
  local hint = Text(f, L["|cffffd100Next:|r Searing Totem (Fire)"], 30, -80, nil, 10)
  Badge(f, 8, -78, "6")
  return f
end

-- Bild erzeugen: ns.Illustration(parent, "click", Breite) -> Frame mit :Refresh()
function ns.Illustration(parent, kind, w)
  local fn = SCENES[kind]
  if not fn then return nil end
  return fn(parent, w or 412)
end
