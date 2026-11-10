-- TotemWatch - Kernlogik, Empfehlungen, klickbare Totem-Leiste
local ADDON, ns = ...
local L = ns.L   -- Übersetzungen (Locales.lua)

local _, playerClass = UnitClass("player")
if playerClass ~= "SHAMAN" then return end

local GetTime, GetTotemInfo, UnitExists, InCombatLockdown = GetTime, GetTotemInfo, UnitExists, InCombatLockdown
local band = bit.band
local floor, ceil, format, lower, find = math.floor, math.ceil, string.format, string.lower, string.find

local DEFAULTS = {
  point = "CENTER", x = 0, y = -180, scale = 1.0,
  locked = false, sound = true, showOOC = false, auto = true,
  rangeWarn = true, destroyWarn = true, useOthers = true, useBoss = true,
  showWeapon = true, showShield = true, showAll = true, showHints = true,
  prePull = true,       -- Checkliste vor dem Pull / Bereitschaftscheck
  warnBefore = 5,       -- Sekunden Vorwarnung vor dem Ablaufen (0 = aus)
  enemyCasts = true,    -- Furcht über feindliche Zauber (Namensplaketten) erkennen
  distanceWarn = true,  -- Warnung, wenn du zu weit von deinen Totems weg bist
  showCall = true,      -- Knopf Call of the Elements (wenn gelernt)
  showRecall = true,    -- Knopf Totemic Recall (wenn gelernt)
  showMove = true,      -- Knopf Totemic Call (wenn gelernt)
  syncCall = true,      -- Totem-Leiste von Call of the Elements mit den Knöpfen abgleichen
  glow = true,          -- empfohlene Totems leuchten
  messages = true,      -- Meldungen in der Bildschirmmitte
  hintSize = 13,        -- Schriftgröße der Hinweise
  messageSize = 24,     -- Schriftgröße der Meldungen
  skin = "classic",     -- Design: classic, minimal, pillars, bars
  showMinimap = true,   -- Minimap-Knopf anzeigen
  minimapAngle = 200,   -- Position am Minimap-Rand (Grad)
  tutorialDone = false, -- Einführung schon gesehen?
  showInDungeon = true, -- in Dungeons immer anzeigen
  showInRaid = true,    -- in Raids immer anzeigen
  speak = false,        -- Warnungen vorlesen (Text-to-Speech)
  useMasque = true,     -- Knöpfe mit Masque gestalten, falls installiert
  tremorButton = true,  -- Notfall-Knopf "Emergency Tremor"
  tremorSize = 44,      -- Größe des Notfall-Knopfs
  tremorDim = 0.15,     -- Sichtbarkeit der Notfall-Knöpfe in Ruhe (0 = unsichtbar, 1 = voll)
  poisonButton = true,  -- Notfall-Knopf Poison Cleansing
  diseaseButton = true, -- Notfall-Knopf Disease Cleansing
  groundingButton = true, -- Notfall-Knopf Grounding
  cleanLook = true,     -- Clean Look: dünne Rahmen, Farbe nur bei Problemen, ruhige Symbole
  roundIcons = false,   -- runde Symbole (Beta)
  shortHints = true,    -- nur eine Hinweiszeile (nächster Schritt)
}

---------------------------------------------------------------------------
-- Zauber-Helfer (alte und neue API)
---------------------------------------------------------------------------
local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return (GetSpellInfo(id))
end

local function SpellIcon(idOrName)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(idOrName) end
  return GetSpellTexture(idOrName)
end

local function SpellCooldown(name)
  if C_Spell and C_Spell.GetSpellCooldown then
    local c = C_Spell.GetSpellCooldown(name)
    if c then
      local gcd = c.isOnGCD
      if issecretvalue and issecretvalue(gcd) then gcd = nil end
      return c.startTime, c.duration, gcd
    end
    return 0, 0
  end
  local s, d = GetSpellCooldown(name)
  return s or 0, d or 0
end

local function BaseName(n)
  if not n or n == "" then return nil end
  n = n:gsub("%s*%(.-%)%s*$", "")   -- "(Rang 3)"
  n = n:gsub("%s+[IVXL]+$", "")     -- "Totem des Windzorns III"
  return n
end

-- Fehler sichtbar machen (die Lua-Fehleranzeige ist im Spiel meist aus)
local shownErrors = {}
local function SafeCall(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then ns.lastErrors = ns.lastErrors or {}; ns.lastErrors[label] = tostring(err) end
  if not ok and not shownErrors[label] then
    shownErrors[label] = true
    print(L["|cffff4040TotemWatch error ("] .. label .. "):|r " .. tostring(err))
  end
  return ok
end
ns.SafeCall = SafeCall

-- Item-Infos (alte und neue API)
local function ItemEquipInfo(link)
  if not link then return nil, nil end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if f then
    local _, _, _, equipLoc, _, classID = f(link)
    return equipLoc, classID
  end
  if GetItemInfo then
    local r = { GetItemInfo(link) }
    return r[9], r[12]
  end
end

local knownNames, knownIds = {}, {}
ns.knownNames = knownNames
local function ScanSpellbook()
  wipe(knownNames); wipe(knownIds)
  -- neue API (C_SpellBook)
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
      if info then
        local offset, num = info.itemIndexOffset or 0, info.numSpellBookItems or 0
        for i = offset + 1, offset + num do
          local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
          if item and item.name then
            knownNames[item.name] = true
            if item.spellID then knownIds[item.spellID] = true end
          end
        end
      end
    end
    return
  end
  -- alte API
  if not GetNumSpellTabs or not GetSpellBookItemName or not GetSpellTabInfo then return end
  for t = 1, GetNumSpellTabs() do
    local _, _, offset, num = GetSpellTabInfo(t)
    for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
      local name = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
      if name then knownNames[name] = true end
    end
  end
end

local function IsKnownId(id)
  local name = SpellName(id)
  if not name then return false end
  if knownNames[name] or knownIds[id] then return true end
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  if IsSpellKnown and IsSpellKnown(id) then return true end
  return false
end

local function IsKnown(key)
  local d = ns.TOTEMS[key]
  return d and IsKnownId(d.id) or false
end

local function TotemName(key) return SpellName(ns.TOTEMS[key].id) or key end

-- Gesperrte ("geheime") Werte erkennen: neuere Clients sperren manche Daten im Kampf
local function IsSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Gelernten Zauber finden: erst über IDs, dann über Namen im Zauberbuch. Liefert den Namen.
local function FindKnownSpell(ids, names)
  for _, id in ipairs(ids) do
    if IsKnownId(id) then return SpellName(id) end
  end
  for _, n in ipairs(names) do
    if knownNames[n] then return n end
  end
end

-- Manakosten eines Zaubers (höchster Rang). Werden zwischengespeichert, falls der
-- Client sie im Kampf sperrt.
ns.costCache = {}
local function ManaCost(name)
  if not name then return nil end
  local ok, value = pcall(function()
    local costs
    if C_Spell and C_Spell.GetSpellPowerCost then costs = C_Spell.GetSpellPowerCost(name)
    elseif GetSpellPowerCost then costs = GetSpellPowerCost(name) end
    if type(costs) ~= "table" then return nil end
    for _, c in ipairs(costs) do
      local t, v, n = c.type, c.cost, c.name
      if not IsSecret(t) and not IsSecret(v) and not IsSecret(n)
         and (t == 0 or n == "MANA") and type(v) == "number" then
        return v
      end
    end
  end)
  if ok and value then ns.costCache[name] = value; return value end
  return ns.costCache[name]
end
ns.ManaCost = ManaCost

-- Zauber-ID des höchsten gelernten Rangs zu einem Namen (für die Totem-Leiste)
local function SpellIdFromName(name)
  if not name then return nil end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(name)
    return info and info.spellID
  end
  return (select(7, GetSpellInfo(name)))
end

-- Lokalisierter Name -> Totem-Schlüssel / Zauber-ID
local nameToKey, idByName = {}, {}
local function BuildNameLookup()
  wipe(nameToKey); wipe(idByName)
  for key, d in pairs(ns.TOTEMS) do
    local n = SpellName(d.id)
    if n then nameToKey[n] = key; idByName[n] = d.id end
  end
  for _, id in ipairs(ns.WEAPON_SPELLS) do local n = SpellName(id); if n then idByName[n] = id end end
  for _, id in ipairs(ns.SHIELD_SPELLS) do local n = SpellName(id); if n then idByName[n] = id end end
end
local function KeyFromName(n)
  n = BaseName(n)
  return n and nameToKey[n]
end

-- (IsSecret steht weiter oben, bei den Zauber-Helfern)

-- Eigene Position in Metern (nil, wenn der Client sie sperrt, z.B. in Instanzen)
local function PlayerPos()
  if not UnitPosition then return nil end
  local ok, y, x, _, inst = pcall(UnitPosition, "player")
  if not ok or y == nil or x == nil or IsSecret(y) or IsSecret(x) or IsSecret(inst) then return nil end
  return x, y, inst
end
ns.PlayerPos = PlayerPos

-- Eigene Aufzeichnung der gestellten Totems (Ersatz, wenn GetTotemInfo gesperrt ist)
local tracked = {}   -- [slot] = { key, start, duration }
ns.tracked = tracked

-- Liefert have, name, start, duration, icon, ausAufzeichnung, restzeitExakt
local function TotemData(slot)
  local now = GetTime()
  local ok, have, name, start, duration, icon = pcall(GetTotemInfo, slot)
  if ok and not IsSecret(have) and not IsSecret(name) and not IsSecret(start) and not IsSecret(duration) then
    -- Werte lesbar (z.B. außerhalb des Kampfes)
    local t = tracked[slot]
    if have and name and name ~= "" and duration and duration > 0 then
      local key = KeyFromName(name)
      -- echte Dauer des gewirkten Rangs lernen
      if t and t.spellID and not t.checked and key == t.key and math.abs(start - t.start) < 3 then
        t.checked = true
        if TotemWatchDB then
          TotemWatchDB.durations = TotemWatchDB.durations or {}
          TotemWatchDB.durations[t.spellID] = floor(duration + 0.5)
        end
      end
      -- Aufzeichnung mit den echten Werten abgleichen, damit sie im Kampf stimmt
      if key then
        local fresh = (now - start) < 4   -- gerade eben gestellt: steht dort, wo du jetzt bist
        if not t or t.key ~= key or math.abs(t.start - start) > 1 then
          local same = t and t.key == key
          local px, py, pinst
          if fresh then px, py, pinst = PlayerPos() end
          if not px and same then px, py, pinst = t.x, t.y, t.inst end
          tracked[slot] = { key = key, start = start, duration = duration,
                            spellID = same and t.spellID or nil, checked = true,
                            x = px, y = py, inst = pinst }
        else
          t.start, t.duration = start, duration
          -- Position fehlt noch (z.B. Ort war beim Wirken gesperrt): jetzt nachtragen
          if not t.x and fresh then t.x, t.y, t.inst = PlayerPos() end
        end
      end
    elseif t and now - t.start > 1 then
      tracked[slot] = nil   -- Slot leer (nicht direkt nach einem Wirken)
    end
    return have, name, start, duration, icon, false, true
  end

  -- Gesperrt: Restzeit über GetTotemTimeLeft (bei Forever im Kampf lesbar) = exakt
  local t = tracked[slot]
  local okL, left = false, nil
  if GetTotemTimeLeft then okL, left = pcall(GetTotemTimeLeft, slot) end
  if okL and type(left) == "number" and not IsSecret(left) then
    if left <= 0 then
      if t and now - t.start > 1 then tracked[slot] = nil end
      return false, "", 0, 0, nil, true, true
    end
    if t then
      -- Dauer anhand der exakten Restzeit korrigieren (z.B. anderer Rang)
      local endAt = now + left
      -- (Toleranz 1,5 s, da manche Clients ganze Sekunden liefern)
      if math.abs((t.start + t.duration) - endAt) > 1.5 then t.duration = endAt - t.start end
      local id = ns.TOTEMS[t.key].id
      return true, SpellName(id) or t.key, t.start, t.duration, SpellIcon(id), true, true
    end
    return true, "?", now, left, nil, true, true   -- Totem steht, aber unbekannt welches
  end

  -- Sonst: eigene Schätzung
  if t and t.start + t.duration > now then
    local id = ns.TOTEMS[t.key].id
    return true, SpellName(id) or t.key, t.start, t.duration, SpellIcon(id), true, false
  end
  return false, "", 0, 0, nil, true, false
end

-- Vom Spieler gewirkter Zauber -> falls Totem, aufzeichnen
local function TrackCast(spellID)
  if IsSecret(spellID) then return end
  local spellName = SpellName(spellID)
  -- Schild gewirkt -> für die Anzeige im Kampf merken (Dauer 10 Minuten)
  for _, id in ipairs(ns.SHIELD_SPELLS) do
    if SpellName(id) == spellName then
      ns.shieldLast = { name = spellName, count = nil, expires = GetTime() + 600 }
      -- gewirkte Zauber-ID merken (meist identisch mit der Aura-ID)
      if TotemWatchDB then
        TotemWatchDB.shieldAuraIds = TotemWatchDB.shieldAuraIds or {}
        TotemWatchDB.shieldAuraIds[spellID] = true
      end
      return
    end
  end
  -- Totemic Recall: alle Totems weg, gleich keine "zerstört"-Warnung
  if ns.recallName and spellName == ns.recallName then
    wipe(tracked)
    ns.recallUntil = GetTime() + 2
    return
  end
  -- Totemic Call: Totems kommen zu dir -> bleiben bestehen, nur neue Position merken
  if ns.moveName and spellName == ns.moveName then
    local px, py, pinst = PlayerPos()
    for _, t in pairs(tracked) do t.x, t.y, t.inst = px, py, pinst end
    return
  end
  -- Call of the Elements: die abgeglichenen Totems der Totem-Leiste stehen jetzt
  if ns.callName and spellName == ns.callName then
    local now, px, py, pinst = GetTime(), PlayerPos()
    for slot, key in pairs(ns.multicastKeys or {}) do
      tracked[slot] = { key = key, start = now, duration = ns.TOTEM_DURATION[key] or 120, checked = false,
                        x = px, y = py, inst = pinst }
    end
    return
  end
  local key = KeyFromName(spellName)
  if not key then return end
  local slot = ns.TOTEMS[key].slot
  -- Dauer: 1) selbst gelernt für genau diesen Rang, 2) Rang-Tabelle, 3) Standardwert
  local learned = TotemWatchDB and TotemWatchDB.durations and TotemWatchDB.durations[spellID]
  local duration = learned or ns.RANK_DURATION[spellID] or ns.TOTEM_DURATION[key] or 120
  local px, py, pinst = PlayerPos()   -- Totem steht dort, wo du es gewirkt hast
  tracked[slot] = { key = key, start = GetTime(), duration = duration, spellID = spellID, checked = false,
                    x = px, y = py, inst = pinst }
end

local function FormatTime(sec)
  if not sec or sec <= 0 then return "" end
  if sec >= 60 then return format("%dm", ceil(sec / 60)) end
  return format("%d", sec)
end

---------------------------------------------------------------------------
-- Zustand
---------------------------------------------------------------------------
local state = {
  boss = nil, bossName = nil,
  fearAt = nil, fearUntil = 0,
  poison = 0, disease = 0,
  melee = 0, caster = 0, groupSize = 1,
  enemies = 0,
  inCombat = false, test = false, pullUntil = 0,
  lastSound = 0,
  preWarned = {},        -- schon vorgewarnte Totems (Slot:Start)
  expireMsg = nil, expireUntil = 0,
  far = {},              -- [slot] = Abstand in Metern, wenn zu weit weg
  slotMsg = {},          -- [slot] = zuletzt gemeldetes Problem (keine Wiederholung)
  others = {},           -- [totemGUID] = { key, slot, caster, src, expires }
  partyShamans = {},     -- [GUID] = Name
  lastRec = {},          -- letzte Empfehlung je Slot (für automatische Belegung)
  setupDone = false, pendingSecure = false,
  range = {},            -- [slot] = { count, names } Spieler außer Reichweite
  prevTotem = {},        -- [slot] = { name, expires } für "Totem zerstört"
  destroyMsg = nil, destroyUntil = 0,
}
ns.state = state

local function OthersInSlot(slot)
  local now, res = GetTime(), {}
  if TotemWatchDB and not TotemWatchDB.useOthers then return res end
  for guid, t in pairs(state.others) do
    if t.expires <= now then
      state.others[guid] = nil
    elseif t.slot == slot and (state.partyShamans[t.src] or t.src == "TEST" or t.src == "BUFF") then
      res[t.key] = t.caster
    end
  end
  return res
end

local function AddOtherTotem(totemGUID, srcGUID, caster, key)
  local slot = ns.TOTEMS[key].slot
  for g, t in pairs(state.others) do
    if t.src == srcGUID and t.slot == slot then state.others[g] = nil end
  end
  state.others[totemGUID] = {
    key = key, slot = slot, caster = caster or "?", src = srcGUID,
    expires = GetTime() + (ns.TOTEM_DURATION[key] or 120),
  }
end

local function IsFearText(text)
  if not text then return false end
  text = lower(text)
  for _, kw in ipairs(ns.FEAR_KEYWORDS) do
    if find(text, kw, 1, true) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Gruppen- und Situationsanalyse
---------------------------------------------------------------------------
local GROUP_UNITS = { "player", "party1", "party2", "party3", "party4" }

local function ScanGroup()
  local melee, caster, size = 0, 0, 0
  wipe(state.partyShamans)
  for _, u in ipairs(GROUP_UNITS) do
    if u ~= "player" and UnitExists(u) and select(2, UnitClass(u)) == "SHAMAN" then
      local g = UnitGUID(u)
      if g then state.partyShamans[g] = UnitName(u) end
    end
    if UnitExists(u) and not UnitIsDeadOrGhost(u) then
      size = size + 1
      if u ~= "player" then
        local _, cls = UnitClass(u)
        local power = UnitPowerType(u)
        if cls == "WARRIOR" or cls == "ROGUE" or cls == "PALADIN" then
          melee = melee + 1
        elseif cls == "DRUID" and (power == 1 or power == 3) then
          melee = melee + 1
        elseif cls == "HUNTER" then
          melee = melee + 0.5
        else
          caster = caster + 1
        end
      end
    end
  end
  state.melee, state.caster, state.groupSize = melee, caster, size
end

-- Zentrale Aura-Abfrage. Sperrt der Client Auren im Kampf, wird bis Kampfende nicht mehr gefragt.
-- Rückgabe: name, count, expires, dispelType  -- oder nil (keine Aura mehr) / "BLOCKED"
local function GetAura(unit, i, helpful)
  if state.aurasBlocked then return "BLOCKED" end
  -- Einmal festgestellt, dass der Client Auren im Kampf sperrt: im Kampf gar nicht erst fragen
  if ns.aurasLockInCombat and InCombatLockdown() then state.aurasBlocked = true; return "BLOCKED" end
  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
    local f = helpful and C_UnitAuras.GetBuffDataByIndex or C_UnitAuras.GetDebuffDataByIndex
    local ok, a = pcall(f, unit, i)
    if not ok then state.aurasBlocked = true; ns.aurasLockInCombat = InCombatLockdown() or ns.aurasLockInCombat; return "BLOCKED" end
    if not a then return nil end
    if IsSecret(a.name) then state.aurasBlocked = true; return "BLOCKED" end
    return a.name, a.applications, a.expirationTime, a.dispelName, a.spellId
  end
  local f = helpful and UnitBuff or UnitDebuff
  if not f then return nil end
  local ok, n, _, c, t, _, e, _, _, _, sid = pcall(f, unit, i)
  if not ok then state.aurasBlocked = true; ns.aurasLockInCombat = InCombatLockdown() or ns.aurasLockInCombat; return "BLOCKED" end
  if not n then return nil end
  if IsSecret(n) then state.aurasBlocked = true; return "BLOCKED" end
  return n, c, e, t, sid
end

local function ScanDebuffs()
  local poison, disease = 0, 0
  for _, u in ipairs(GROUP_UNITS) do
    if UnitExists(u) then
      for i = 1, 40 do
        local n, _, _, dtype = GetAura(u, i, false)
        if not n or n == "BLOCKED" then break end
        if IsSecret(dtype) then dtype = nil end
        if dtype == "Poison" then poison = poison + 1
        elseif dtype == "Disease" then disease = disease + 1 end
      end
    end
  end
  state.poison, state.disease = poison, disease
end

local function ScanEnemies()
  local n = 0
  for i = 1, 40 do
    local u = "nameplate" .. i
    if UnitExists(u) and UnitCanAttack("player", u) and UnitAffectingCombat(u) and not UnitIsDead(u) then
      n = n + 1
    end
  end
  state.enemies = n
end

local function FindPlayerBuff(names)
  for i = 1, 40 do
    local name, count, expires, _, sid = GetAura("player", i, true)
    if name == "BLOCKED" then return "SECRET" end
    if not name then break end
    if names[name] then
      -- echte Aura-ID merken (Forever kann andere IDs als Classic haben)
      if sid and not IsSecret(sid) and TotemWatchDB then
        TotemWatchDB.shieldAuraIds = TotemWatchDB.shieldAuraIds or {}
        TotemWatchDB.shieldAuraIds[sid] = true
      end
      return name, count, expires
    end
  end
end

-- Schild-IDs für die Abfrage im Kampf: zuerst die selbst gelernten, dann die Classic-Liste
local function ShieldIdList()
  local list, seen = {}, {}
  if TotemWatchDB and TotemWatchDB.shieldAuraIds then
    for id in pairs(TotemWatchDB.shieldAuraIds) do list[#list + 1] = id; seen[id] = true end
  end
  for _, id in ipairs(ns.SHIELD_AURA_IDS) do
    if not seen[id] then list[#list + 1] = id end
  end
  return list
end
ns.ShieldIdList = ShieldIdList

-- Alle Buff-Namen einer Einheit sammeln
local function CollectBuffNames(unit, into)
  wipe(into)
  for i = 1, 40 do
    local name = GetAura(unit, i, true)
    if not name or name == "BLOCKED" then break end
    into[#into + 1] = name
  end
  return into
end

local function HasTotemBuff(buffs, buffName, totemName)
  for _, b in ipairs(buffs) do
    if b == buffName then return true end
    if totemName and #b >= 5 and b ~= totemName and find(totemName, b, 1, true) then return true end
  end
  return false
end

-- Reichweiten-Check: Wer in der Gruppe hat den Buff des eigenen Totems nicht?
local buffScratch = {}
local function ScanRange()
  for s = 1, 4 do state.range[s] = nil end
  if not TotemWatchDB.rangeWarn or state.aurasBlocked then return end
  local now = GetTime()
  for s = 1, 4 do
    local have, tname, start, duration = TotemData(s)
    local key = have and tname and tname ~= "" and KeyFromName(tname)
    local buffId = key and ns.TOTEM_BUFFS[key]
    if buffId and start and now - start > 3 and (start + (duration or 0) - now) > 1 then
      local buffName = SpellName(buffId)
      local baseTotem = TotemName(key)
      local missing, checked, selfOut = {}, 0, false
      for _, u in ipairs(GROUP_UNITS) do
        if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) then
          checked = checked + 1
          local visible = UnitIsVisible(u)
          if not visible or not HasTotemBuff(CollectBuffNames(u, buffScratch), buffName, baseTotem) then
            if u == "player" then selfOut = true end
            missing[#missing + 1] = (u == "player") and L["you"] or (UnitName(u) or "?")
          end
        end
      end
      -- Hat niemand den Buff, ist die Erkennung unzuverlässig -> nicht warnen
      if #missing > 0 and #missing < checked then
        state.range[s] = { count = #missing, names = table.concat(missing, ", "), self = selfOut,
                           name = baseTotem }
      end
    end
  end
  -- Du selbst bist raus (erkannt am fehlenden Buff): Meldung in der Mitte, einmal pro Mal,
  -- falls die Abstandsmessung (Position) das nicht schon gemeldet hat
  local selfOutNow = false
  for s = 1, 4 do if state.range[s] and state.range[s].self then selfOutNow = true end end
  if selfOutNow and not state.wasSelfOut and not state.wasFar and ns.ShowMessage then
    ns.ShowMessage(L["Out of totem range"], 1, 0.6, 0.2)
    if ns.Speak then ns.Speak(L["Out of totem range"]) end
  end
  state.wasSelfOut = selfOutNow
end

-- Ersatz ohne Kampflog: Totems anderer Schamanen über die Buffs auf dir erkennen.
-- (Hast du z.B. "Stärke der Erde", stellst aber selbst etwas anderes, kommt es von einem anderen Schamanen.)
local function ScanOtherBuffs()
  if state.aurasBlocked then
    -- Auren im Kampf gesperrt: letzten bekannten Stand beibehalten
    for _, t in pairs(state.others) do if t.src == "BUFF" then t.expires = GetTime() + 3 end end
    return
  end
  for g, t in pairs(state.others) do if t.src == "BUFF" then state.others[g] = nil end end
  if not TotemWatchDB.useOthers or next(state.partyShamans) == nil then return end
  local count, onlyName = 0, nil
  for _, n in pairs(state.partyShamans) do count = count + 1; onlyName = n end
  local who = (count == 1 and onlyName) or L["another shaman"]
  CollectBuffNames("player", buffScratch)
  for key, buffId in pairs(ns.TOTEM_BUFFS) do
    local slot = ns.TOTEMS[key].slot
    local have, tname = TotemData(slot)
    local mine = have and tname and tname ~= "" and KeyFromName(tname)
    if mine ~= key and HasTotemBuff(buffScratch, SpellName(buffId), TotemName(key)) then
      state.others["BUFF-" .. key] = { key = key, slot = slot, caster = who, src = "BUFF", expires = GetTime() + 3 }
    end
  end
end

-- Reichweite eines Totems in Yards: aus der Zauberbeschreibung im Spiel ("within 30 yards"),
-- sonst aus der Tabelle in Data.lua. false = nicht prüfen. Liefert range, quelle.
ns.rangeCache = {}
local RANGE_UNITS = { yard = true, yards = true, yd = true, meter = true, metern = true, metre = true, metres = true }
local function TotemRange(key)
  local fixed = ns.TOTEM_RANGE[key]
  if fixed == false then return false, "not checked" end
  if ns.rangeCache[key] then return ns.rangeCache[key], "spell" end
  local name = TotemName(key)
  local id = SpellIdFromName(name) or ns.TOTEMS[key].id
  local ok, desc = pcall(function()
    if C_Spell and C_Spell.GetSpellDescription then return C_Spell.GetSpellDescription(id) end
    if GetSpellDescription then return GetSpellDescription(id) end
  end)
  if ok and type(desc) == "string" and not IsSecret(desc) and desc ~= "" then
    for num, unit in desc:gmatch("(%d+)%s*%-?%s*(%a+)") do
      if RANGE_UNITS[lower(unit)] then
        local r = tonumber(num)
        if r and r >= 5 and r <= 100 then
          ns.rangeCache[key] = r       -- erst merken, wenn die Beschreibung geladen war
          return r, "spell"
        end
      end
    end
  end
  return fixed or ns.TOTEM_RANGE_DEFAULT, "table"
end
ns.TotemRange = TotemRange

-- Abstand zu den eigenen Totems (Position beim Wirken gemerkt)
-- Läuft über einen eigenen Takt (zweimal pro Sekunde), auch wenn die Leiste ausgeblendet ist.
ns.distInfo = {}   -- für /tw debug: [slot] = Text
local function ScanDistance()
  for s = 1, 4 do state.far[s] = nil; ns.distInfo[s] = nil end
  if not TotemWatchDB or not TotemWatchDB.distanceWarn then return end
  local px, py, pinst = PlayerPos()
  ns.posReadable = px ~= nil
  if not px then return end
  local maxDist = 0
  for s = 1, 4 do
    local t = tracked[s]
    local have = TotemData(s)
    if not have then
      ns.distInfo[s] = "no totem"
    elseif not t then
      ns.distInfo[s] = "not tracked (cast it again)"
    elseif not t.x then
      ns.distInfo[s] = "no position stored"
    elseif t.inst ~= pinst then
      ns.distInfo[s] = "other zone/instance"
    else
      local range, source = TotemRange(t.key)
      local tol = ns.TOTEM_RANGE_TOLERANCE or 0
      local dist = math.sqrt((px - t.x) ^ 2 + (py - t.y) ^ 2)
      ns.distInfo[s] = format("%.0f yd (range %s, from %s, +%d tolerance)", dist,
        range and tostring(range) or "-", source, tol)
      if range and dist > range + tol then
        state.far[s] = { dist = floor(dist + 0.5), range = range, name = TotemName(t.key) }
        maxDist = math.max(maxDist, dist)
      end
    end
  end
  ns.EvaluateTotemicCall()

  -- Meldung in der Bildschirmmitte, sobald du aus der Reichweite läufst (einmal pro Mal)
  local isFar = maxDist > 0
  if isFar and not state.wasFar and ns.ShowMessage then
    ns.ShowMessage(format(L["Out of range of your totems (%d yd)"], floor(maxDist + 0.5)), 1, 0.6, 0.2)
    if ns.Speak then ns.Speak(L["Out of totem range"]) end
  end
  state.wasFar = isFar
end
ns.ScanDistance = ScanDistance

-- Lohnt sich Totemic Call oder ist Neustellen besser?
-- Neustellen wirft die bezahlte Restzeit weg: Wert = Kosten des Totems * (Restzeit / Laufzeit).
-- Totemic Call lohnt sich, wenn er weniger kostet als dieser verlorene Wert.
function ns.EvaluateTotemicCall()
  state.moveAdvice = nil
  if not ns.moveName then return end
  local now = GetTime()
  local callCost = ManaCost(ns.moveName)
  local redrop, lost, fracSum, count, names = 0, 0, 0, 0, {}
  local costsKnown = callCost ~= nil
  for s = 1, 4 do
    local f, t = state.far[s], tracked[s]
    if f and t then
      local have, _, st, du = TotemData(s)
      if have and du and du > 0 then
        local frac = math.max(0, math.min(1, (st + du - now) / du))
        local c = ManaCost(TotemName(t.key))
        if c then
          redrop = redrop + c
          lost = lost + c * frac
        else
          costsKnown = false
        end
        fracSum, count = fracSum + frac, count + 1
        names[#names + 1] = TotemName(t.key)
      end
    end
  end
  if count == 0 then return end
  local useCall
  if costsKnown then
    useCall = callCost < lost
  else
    useCall = (fracSum / count) > 0.30   -- Ersatzregel ohne Manakosten
  end
  state.moveAdvice = {
    useCall = useCall, costsKnown = costsKnown, callCost = callCost,
    redrop = floor(redrop + 0.5), lost = floor(lost + 0.5),
    avgPct = floor(fracSum / count * 100 + 0.5), names = table.concat(names, ", "),
  }
end

-- Totem zerstört? (Slot wird leer, obwohl die Laufzeit noch nicht um ist)
local function CheckDestroyed(slot)
  local now = GetTime()
  local have, name, start, duration = TotemData(slot)
  if have and name and name ~= "" and duration and duration > 0 then
    state.prevTotem[slot] = { name = name, expires = start + duration }
    return
  end
  local prev = state.prevTotem[slot]
  state.prevTotem[slot] = nil
  if not prev or not TotemWatchDB.destroyWarn then return end
  if prev.expires - now < 1.5 or UnitIsDeadOrGhost("player") then return end
  if ns.recallUntil and now < ns.recallUntil then return end   -- selbst zurückgerufen
  -- kurz warten: beim Ersetzen ist der Slot kurz leer
  C_Timer.After(0.5, function()
    local h, n = TotemData(slot)
    if h and n and n ~= "" then return end
    if ns.recallUntil and GetTime() < ns.recallUntil then return end
    local key = KeyFromName(prev.name)
    if key == "GROUNDING" then
      state.destroyMsg = L["Grounding absorbed a spell – recast it!"]
    else
      state.destroyMsg = format(L["%s destroyed!"], BaseName(prev.name) or ns.SLOT_NAMES[slot])
    end
    state.destroyUntil = GetTime() + 4
  end)
end

---------------------------------------------------------------------------
-- Empfehlungs-Logik
---------------------------------------------------------------------------
-- Liefert key, grund, dringend, hinweisZuAnderen, andereTotems
local function Recommend(slot)
  local now = GetTime()
  local cands = {}
  local function add(key, reason, urgent) cands[#cands + 1] = { key, reason, urgent } end

  -- 1) Akute Situationen
  if slot == ns.EARTH then
    if state.fearUntil > now then
      add("TREMOR", L["Group is being feared!"], true)
    elseif state.fearAt then
      local dt = state.fearAt - now
      if dt > -3 and dt < 15 then
        add("TREMOR", format(L["Fear in %ds (boss mod)"], math.max(0, floor(dt))), dt < 6)
      end
    end
  elseif slot == ns.WATER then
    if state.poison >= 2 then add("POISON_CLEANSE", format(L["%d poison debuffs in group"], state.poison), true) end
    if state.disease >= 2 then add("DISEASE_CLEANSE", format(L["%d diseases in group"], state.disease), true) end
  end

  -- 2) Boss-spezifisch
  local boss = TotemWatchDB.useBoss and state.boss or nil
  if boss and boss[ns.SLOT_KEYS[slot]] then
    for _, e in ipairs(boss[ns.SLOT_KEYS[slot]]) do
      add(e[1], (state.bossName or boss.name or "Boss") .. ": " .. e[2])
    end
  end

  -- 3) Standard je nach Gruppe
  local melee, caster, solo = state.melee, state.caster, state.groupSize <= 1
  if slot == ns.FIRE then
    if state.enemies >= 3 then
      add("MAGMA", format(L["%d enemies – AoE"], state.enemies))
      add("FIRE_NOVA", format(L["%d enemies – AoE"], state.enemies))
    end
    if caster >= melee and not solo then add("TOTEM_OF_WRATH", L["Spell crit for casters"]) end
    if melee >= 2 then add("FLAMETONGUE", L["Weapon proc for melee"]) end
    add("SEARING", L["Extra damage"])
  elseif slot == ns.EARTH then
    if melee >= 1 or solo then add("STRENGTH", L["Strength for melee"]) end
    add("STONESKIN", L["Less melee damage taken"])
  elseif slot == ns.WATER then
    local okHp, lowHp = pcall(function() return UnitHealth("player") / math.max(1, UnitHealthMax("player")) < 0.6 end)
    if solo and okHp and lowHp then
      add("HEALING_STREAM", L["Low health"])
    end
    add("MANA_SPRING", L["Mana regeneration"])
    add("HEALING_STREAM", L["Healing"])
  elseif slot == ns.AIR then
    if melee >= 2 or solo then
      add("WINDFURY", L["Melee in group"])
      add("GRACE_OF_AIR", L["Agility for melee"])
    end
    if caster > melee then
      add("WRATH_OF_AIR", L["Spell power for casters"])
      add("TRANQUIL_AIR", L["Less threat for casters"])
    end
    add("GRACE_OF_AIR", L["Agility"])
    add("WINDFURY", L["Melee buff"])
  end

  local avoid = boss and boss.avoid
  local others = OthersInSlot(slot)

  local best
  for _, c in ipairs(cands) do
    if not (avoid and avoid[c[1]]) then best = c[1]; break end
  end

  local otherHint
  for k, who in pairs(others) do
    if avoid and avoid[k] then
      otherHint = format(L["%s has %s – %s"], who, TotemName(k), avoid[k])
    elseif best and k ~= best and not others[best] then
      otherHint = format(L["%s has %s – %s would be better"], who, TotemName(k), TotemName(best))
    end
  end

  local covered
  for _, c in ipairs(cands) do
    local k = c[1]
    if not (avoid and avoid[k]) then
      if others[k] then
        covered = covered or format(L["%s comes from %s"], TotemName(k), others[k])
      elseif IsKnown(k) then
        local reason = c[2]
        if covered then reason = reason .. " (" .. covered .. ")" end
        return k, reason, c[3], otherHint, others
      end
    end
  end
  return nil, covered, nil, otherHint, others
end

-- Status eines Slots: "OK", "MISSING", "WRONG", "DUPLICATE", "EXPIRING"
local function SlotStatus(slot, recKey, others)
  local have, name, start, duration, icon = TotemData(slot)
  local remaining = 0
  if have and name and name ~= "" and duration and duration > 0 then
    remaining = start + duration - GetTime()
  end
  if not have or not name or name == "" or remaining <= 0 then
    return "MISSING", nil, 0
  end
  if name == "?" then
    -- Totem steht, aber im Kampf nicht erkennbar welches (vor /reload gestellt): nicht falsch warnen
    return remaining < 10 and "EXPIRING" or "OK", nil, remaining
  end
  if recKey then
    local want = TotemName(recKey)
    local base = BaseName(name)
    if base ~= want and not find(name, want, 1, true) then
      local mine = KeyFromName(name)
      if mine and others and others[mine] then
        return "DUPLICATE", icon, remaining, name, others[mine]
      end
      return "WRONG", icon, remaining, name
    end
  end
  if remaining < 10 then return "EXPIRING", icon, remaining, name end
  return "OK", icon, remaining, name
end

---------------------------------------------------------------------------
-- Hauptfenster (geschützt, damit die Knöpfe im Kampf klickbar bleiben)
---------------------------------------------------------------------------
local BTN, GAP = 40, 46
local templates = "SecureHandlerStateTemplate" .. (BackdropTemplateMixin and ",BackdropTemplate" or "")
local frame = CreateFrame("Frame", "TotemWatchFrame", UIParent, templates)
frame:SetSize(9 + 7 * GAP + 6, 78)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
if frame.SetBackdrop then
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.6)
  frame:SetBackdropBorderColor(0.2, 0.5, 1, 0.8)
end
frame:SetScript("OnDragStart", function(self)
  if not TotemWatchDB.locked and not InCombatLockdown() then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
  if InCombatLockdown() then return end   -- geschütztes Fenster: im Kampf nicht anfassen
  self:StopMovingOrSizing()
  local p, _, _, x, y = self:GetPoint()
  TotemWatchDB.point, TotemWatchDB.x, TotemWatchDB.y = p, x, y
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", 8, -6)
title:SetText(L["|cff0070deTotemWatch|r  |cff888888(drag here)|r"])

local alert = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alert:SetPoint("BOTTOM", frame, "TOP", 0, 6)
alert:SetTextColor(1, 0.2, 0.2)

-- Goldenes, pulsierendes Leuchten um einen Knopf (zeigt: das hier ist empfohlen / jetzt drücken)
local function MakeGlow(parent, size)
  local g = parent:CreateTexture(nil, "OVERLAY", nil, 7)
  g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  g:SetBlendMode("ADD")
  g:SetVertexColor(1, 0.85, 0.2)
  g:SetSize(size * 1.85, size * 1.85)
  g:SetPoint("CENTER", parent, "CENTER", 0, 0)
  g:Hide()
  local ag = g:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.6)
  g.anim = ag
  return g
end

local function SetGlow(g, on)
  if not g then return end
  if on then
    if not g:IsShown() then g:Show(); g.anim:Play() end
  elseif g:IsShown() then
    g.anim:Stop(); g:Hide()
  end
end

-- Mausklicks passend zur Einstellung "Aktionen bei Tastendruck"
local function RegisterClicks(b)
  local keyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
  b:RegisterForClicks(keyDown and "AnyDown" or "AnyUp")
end

local function CreateCastButton(name, x)
  local b = CreateFrame("Button", name, frame, "SecureActionButtonTemplate")
  b:SetSize(BTN, BTN)
  b:SetPoint("TOPLEFT", x, -20)
  RegisterClicks(b)
  b:SetAttribute("type1", "spell")

  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetAllPoints()
  b.border:SetColorTexture(0.4, 0.4, 0.4, 1)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)

  local over = CreateFrame("Frame", nil, b)   -- Ebene über der Abklingzeit
  over:SetAllPoints()
  over:SetFrameLevel(b.cd:GetFrameLevel() + 2)
  b.over = over

  b.cur = over:CreateTexture(nil, "OVERLAY")    -- eigenes aktives Totem (wenn abweichend)
  b.cur:SetSize(16, 16); b.cur:SetPoint("BOTTOMRIGHT", 4, -4); b.cur:Hide()

  b.other = over:CreateTexture(nil, "OVERLAY")  -- Totem eines anderen Schamanen
  b.other:SetSize(16, 16); b.other:SetPoint("TOPLEFT", -4, 4); b.other:Hide()

  b.rec = over:CreateTexture(nil, "OVERLAY")    -- Empfehlung, wenn anders belegt
  b.rec:SetSize(18, 18); b.rec:SetPoint("TOPRIGHT", 5, 5); b.rec:Hide()

  b.label = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.label:SetPoint("BOTTOMLEFT", 2, 2)

  -- Große Entfernungsanzeige mitten auf dem Knopf (wenn du zu weit vom Totem weg bist)
  b.farText = over:CreateFontString(nil, "OVERLAY")
  b.farText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  b.farText:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.farText:SetTextColor(1, 0.55, 0.1)
  b.farText:Hide()

  b.glow = MakeGlow(over, BTN)
  b.recGlow = MakeGlow(over, 18)            -- Leuchten um das kleine Empfehlungs-Symbol
  b.recGlow:ClearAllPoints()
  b.recGlow:SetPoint("CENTER", b.rec, "CENTER", 0, 0)

  b.timer = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.timer:SetPoint("TOP", b, "BOTTOM", 0, -1)

  -- Bausteine für die Designs (Skins); welche sichtbar sind, entscheidet ApplySkin
  b.strip = over:CreateTexture(nil, "OVERLAY", nil, 2)   -- Status-Farbstreifen (Minimal)
  b.strip:SetHeight(3); b.strip:Hide()
  -- Clean Look: feine Statuslinie am unteren Rand (nur sichtbar, wenn etwas zu tun ist)
  b.cleanLine = over:CreateTexture(nil, "OVERLAY", nil, 3)
  b.cleanLine:SetHeight(2)
  b.cleanLine:SetPoint("BOTTOMLEFT", 1, 1); b.cleanLine:SetPoint("BOTTOMRIGHT", -1, 1)
  b.cleanLine:Hide()
  do
    local lg = b.cleanLine:CreateAnimationGroup()
    lg:SetLooping("BOUNCE")
    local la = lg:CreateAnimation("Alpha")
    la:SetFromAlpha(1); la:SetToAlpha(0.3); la:SetDuration(0.6)
    b.cleanPulse = lg
  end
  b.elemStrip = b:CreateTexture(nil, "OVERLAY")          -- Element-Farbleiste (Pillars)
  b.elemStrip:SetHeight(3); b.elemStrip:Hide()
  b.timeBar = CreateFrame("StatusBar", nil, frame)        -- Zeitbalken (Pillars / Bars)
  b.timeBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  b.timeBar:SetMinMaxValues(0, 1); b.timeBar:SetValue(0)
  b.timeBar.bg = b.timeBar:CreateTexture(nil, "BACKGROUND")
  b.timeBar.bg:SetAllPoints(); b.timeBar.bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
  b.barName = b.timeBar:CreateFontString(nil, "OVERLAY")
  b.barName:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
  b.barName:SetPoint("LEFT", 5, 0); b.barName:SetJustifyH("LEFT")
  b.barTime = b.timeBar:CreateFontString(nil, "OVERLAY")
  b.barTime:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
  b.barTime:SetPoint("RIGHT", -4, 0)
  b.timeBar:Hide()
  -- Hinweis: Keine Masken-Texturen (runde Icons) verwenden – sie haben bei WoW Forever
  -- einen Absturz des Spiels ausgelöst ("memory could not be written").

  local ag = b.border:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1); a:SetToAlpha(0.2); a:SetDuration(0.45)
  b.pulse = ag

  b:HookScript("OnAttributeChanged", function(self, attr, value)
    if attr == "spell1" and self.dbKey and TotemWatchDB and TotemWatchDB.choice then
      TotemWatchDB.choice[self.dbKey] = value
      -- Hast DU das Totem gewählt (nicht die Automatik)? Dann hat deine Wahl Vorrang.
      -- Wählst du wieder das empfohlene Totem, übernimmt die Automatik den Knopf wieder.
      if self.slot and not ns.autoAssigning and TotemWatchDB.manual then
        local k = value and KeyFromName(value)
        local rec = state.curRec and state.curRec[self.slot]
        TotemWatchDB.manual[self.slot] = (k and k ~= rec) and k or nil
      end
      -- Totem-Leiste von Call of the Elements nachziehen (nur außerhalb des Kampfes möglich)
      if self.slot and ns.SyncMultiCast and not InCombatLockdown() then ns.SyncMultiCast() end
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- Auswahlmenü (Rechtsklick). Ein Klick darin stellt das Totem UND belegt den Hauptknopf neu.
local FLYOUT_SNIPPET = [[
  local main = self:GetFrameRef("main")
  main:SetAttribute("spell1", self:GetAttribute("spell1"))
  self:GetParent():Hide()
  local all = main:GetFrameRef("all")
  if all then
    local s = ""
    for i = 1, 4 do
      local e = all:GetFrameRef("e" .. i)
      local sp = e and e:GetAttribute("spell1")
      if sp then
        if s ~= "" then s = s .. ", " end
        s = s .. sp
      end
    end
    all:SetAttribute("macrotext1", "/castsequence reset=combat/12 " .. s)
  end
]]

local TOGGLE_SNIPPET = [[
  if button == "RightButton" then
    local f = self:GetFrameRef("flyout")
    if f then
      if f:IsShown() then f:Hide() else f:Show() end
    end
    return false
  end
]]

local function BuildFlyout(main, ids)
  local fly = main.flyout
  if not fly then
    fly = CreateFrame("Frame", nil, main, "SecureHandlerBaseTemplate")
    fly:SetPoint("BOTTOM", main, "TOP", 0, 6)
    fly:SetFrameStrata("HIGH")
    fly:Hide()
    fly.buttons = {}
    main.flyout = fly
    SecureHandlerSetFrameRef(main, "flyout", fly)
    SecureHandlerWrapScript(main, "OnClick", frame, TOGGLE_SNIPPET)
  end
  local known = {}
  for _, id in ipairs(ids) do if IsKnownId(id) then known[#known + 1] = id end end
  for i, id in ipairs(known) do
    local fb = fly.buttons[i]
    if not fb then
      fb = CreateFrame("Button", nil, fly, "SecureActionButtonTemplate")
      fb:SetSize(32, 32)
      fb:SetPoint("BOTTOM", fly, "BOTTOM", 0, (i - 1) * 34)
      RegisterClicks(fb)
      fb:SetAttribute("type1", "spell")
      fb.icon = fb:CreateTexture(nil, "ARTWORK")
      fb.icon:SetAllPoints()
      fb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      fb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      fb.glow = MakeGlow(fb, 32)   -- leuchtet, wenn dieses Totem empfohlen ist
      SecureHandlerSetFrameRef(fb, "main", main)
      SecureHandlerWrapScript(fb, "OnClick", frame, FLYOUT_SNIPPET)
      fb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.spellId then GameTooltip:SetSpellByID(self.spellId) end
        GameTooltip:AddLine(L["Click: cast and set as default"], 0.6, 1, 0.6)
        if self.canMultispell then
          GameTooltip:AddLine(L["Right-click: put it on the Call of the Elements bar without casting (works in combat)"], 1, 0.82, 0, true)
        end
        GameTooltip:Show()
      end)
      fb:SetScript("OnLeave", function() GameTooltip:Hide() end)
      fly.buttons[i] = fb
    end
    fb.spellId = id
    fb:SetAttribute("spell1", SpellName(id))
    fb.icon:SetTexture(SpellIcon(id))
    fb:Show()
  end
  for i = #known + 1, #fly.buttons do
    fly.buttons[i]:SetAttribute("spell1", nil)
    fly.buttons[i]:Hide()
  end
  fly:SetSize(32, math.max(1, #known) * 34)
  return known
end

-- Knöpfe anlegen
local slots = {}
for s = 1, 4 do
  local b = CreateCastButton("TotemWatch" .. ({ "Fire", "Earth", "Water", "Air" })[s], 9 + (s - 1) * GAP)
  b.slot, b.dbKey = s, "slot" .. s
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local assigned = self:GetAttribute("spell1")
    GameTooltip:AddLine(ns.SLOT_NAMES[s] .. ": " .. (assigned or L["not set"]), 1, 1, 1)
    if self.recKey then
      GameTooltip:AddLine(L["Recommended: "] .. TotemName(self.recKey), 1, 0.82, 0)
      if self.reason then GameTooltip:AddLine(self.reason, 0.8, 0.8, 0.8, true) end
    elseif self.reason then
      GameTooltip:AddLine(self.reason, 0.8, 0.8, 0.8, true)
    end
    if self.curName then GameTooltip:AddLine(L["Active: "] .. self.curName, 0.6, 1, 0.6) end
    if self.others then
      for k, who in pairs(self.others) do
        GameTooltip:AddLine(format("%s: %s", who, TotemName(k)), 0.5, 0.8, 1)
      end
    end
    if self.otherHint then GameTooltip:AddLine(self.otherHint, 1, 0.6, 0.2, true) end
    if self.rangeInfo then GameTooltip:AddLine(self.rangeInfo, 1, 0.3, 0.3, true) end
    if TotemWatchDB.manual and TotemWatchDB.manual[s] then
      GameTooltip:AddLine(L["Chosen by you – automatic choice is paused for this button. Pick the recommended totem to resume it."], 0.6, 0.8, 1, true)
    end
    GameTooltip:AddLine(L["Left-click: cast  ·  Right-click: choose"], 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  slots[s] = b
end

-- "Alle stellen": /castsequence mit den 4 belegten Totems (mehrmals drücken)
local castAll = CreateFrame("Button", "TotemWatchCastAll", frame, "SecureActionButtonTemplate")
castAll:SetSize(BTN, BTN)
castAll:SetPoint("TOPLEFT", 9 + 4 * GAP + 6, -20)
RegisterClicks(castAll)
castAll:SetAttribute("type1", "macro")
do
  local bg = castAll:CreateTexture(nil, "BACKGROUND")
  castAll.bg = bg
  bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.25, 0.55, 1)
  local t = castAll:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("CENTER"); t:SetText(L["ALL"])
  castAll:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end
castAll:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(L["Cast all totems"], 1, 1, 1)
  GameTooltip:AddLine(L["Click / press repeatedly – casts in order:"], 0.8, 0.8, 0.8, true)
  for s = 1, 4 do
    local sp = slots[s]:GetAttribute("spell1")
    if sp then GameTooltip:AddLine("  " .. sp, 0.6, 1, 0.6) end
  end
  GameTooltip:Show()
end)
castAll:SetScript("OnLeave", function() GameTooltip:Hide() end)
for s = 1, 4 do
  SecureHandlerSetFrameRef(slots[s], "all", castAll)
  SecureHandlerSetFrameRef(castAll, "e" .. s, slots[s])
end

-- Waffenverzauberung und Schild
local weaponBtn = CreateCastButton("TotemWatchWeapon", 9 + 5 * GAP + 6)
weaponBtn.dbKey = "weapon"
local shieldBtn = CreateCastButton("TotemWatchShield", 9 + 6 * GAP + 6)
shieldBtn.dbKey = "shield"

-- Call of the Elements (alle 4 auf einmal), Totemic Call (Totems herholen), Totemic Recall (alle entfernen)
local callBtn = CreateCastButton("TotemWatchCall", 9 + 7 * GAP + 6)
local moveBtn = CreateCastButton("TotemWatchMove", 9 + 8 * GAP + 6)
local recallBtn = CreateCastButton("TotemWatchRecall", 9 + 9 * GAP + 6)
callBtn:Hide(); moveBtn:Hide(); recallBtn:Hide()

-- "..."-Knopf (Design Kompakt): klappt ALLE, Call, Totemic Call und Recall auf/zu.
-- Gesicherter Klick-Handler, damit das Aufklappen auch im Kampf funktioniert.
local moreBtn = CreateFrame("Button", "TotemWatchMore", frame, "SecureHandlerClickTemplate")
moreBtn:SetSize(18, 18)
moreBtn:RegisterForClicks("AnyUp")
moreBtn:Hide()
do
  local bg = moreBtn:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetColorTexture(0.15, 0.15, 0.15, 1)
  local t = moreBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("CENTER", 0, 2); t:SetText("...")
  moreBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end
for i, b in ipairs({ castAll, callBtn, moveBtn, recallBtn }) do moreBtn:SetFrameRef("x" .. i, b) end
moreBtn:SetAttribute("_onclick", [=[
  local open = not self:GetAttribute("open")
  self:SetAttribute("open", open)
  for i = 1, 4 do
    local f = self:GetFrameRef("x" .. i)
    if f then
      if open and f:GetAttribute("twEnabled") then f:Show() else f:Hide() end
    end
  end
]=])
moreBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(L["More buttons"], 1, 1, 1)
  GameTooltip:AddLine(L["Click: show/hide ALL, Call of the Elements, Totemic Call and Totemic Recall (also in combat)."], 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end)
moreBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
moveBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(self:GetAttribute("spell1") or "Totemic Call", 1, 1, 1)
  GameTooltip:AddLine(L["Moves your totems to your position. They keep their remaining time."], 0.8, 0.8, 0.8, true)
  local cost = ManaCost(self:GetAttribute("spell1"))
  if cost then GameTooltip:AddLine(format(L["Cost: %d mana"], cost), 0.6, 0.8, 1) end
  local adv = state.moveAdvice
  if adv then
    if adv.useCall then
      GameTooltip:AddLine(L["Worth it now – cheaper than re-dropping."], 0.4, 1, 0.4, true)
    else
      GameTooltip:AddLine(L["Not worth it now – re-drop the totems instead."], 1, 0.8, 0.2, true)
    end
  end
  GameTooltip:Show()
end)
moveBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
callBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(self:GetAttribute("spell1") or "Call of the Elements", 1, 1, 1)
  GameTooltip:AddLine(L["Drops all 4 totems at once."], 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine(L["Totems on its bar:"], 1, 0.82, 0)
  for s = 1, 4 do
    local key = ns.multicastKeys and ns.multicastKeys[s]
    local assigned = slots[s]:GetAttribute("spell1")
    local want = assigned and KeyFromName(assigned)
    if key then
      local ok = (key == want)
      GameTooltip:AddLine("  " .. TotemName(key) .. (ok and "" or ("  |cffff6060(" .. L["TotemWatch: "] .. (want and TotemName(want) or "-") .. ")|r")),
        ok and 0.6 or 1, ok and 1 or 0.6, ok and 0.6 or 0.4)
    end
  end
  GameTooltip:Show()
end)
callBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
recallBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(self:GetAttribute("spell1") or "Totemic Recall", 1, 1, 1)
  GameTooltip:AddLine(L["Removes all your totems and returns some mana."], 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end)
recallBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Notfall-Knöpfe: jeder zaubert IMMER dasselbe Totem (fester Zauber = erlaubt).
-- Gedimmt in Ruhe, leuchten bei Gefahr auf, grün wenn das Totem schon steht.
-- Im Kampf dürfen sie nicht ein-/ausgeblendet werden, nur heller/dunkler (SetAlpha).
---------------------------------------------------------------------------
-- Gefahren, die die Knöpfe auslösen: [Totem-Schlüssel] = { at = Zeitpunkt, untilT = aktiv bis }
state.danger = state.danger or {}

local EMERGENCY_DEFS = {
  { key = "TREMOR",          db = "tremor",    name = "TotemWatchTremor",    label = "Emergency Tremor",
    desc = "Always casts Tremor Totem. Lights up when a fear is coming." },
  { key = "POISON_CLEANSE",  db = "poison",    name = "TotemWatchPoison",    label = "Emergency Poison Cleansing",
    desc = "Always casts Poison Cleansing Totem. Lights up when enemies cast poison." },
  { key = "DISEASE_CLEANSE", db = "disease",   name = "TotemWatchDisease",   label = "Emergency Disease Cleansing",
    desc = "Always casts Disease Cleansing Totem. Lights up when enemies cast diseases." },
  { key = "GROUNDING",       db = "grounding", name = "TotemWatchGrounding", label = "Emergency Grounding",
    desc = "Always casts Grounding Totem. Lights up when an enemy casts a dangerous spell (Polymorph, Hex, Fear …)." },
}

-- Wie dringend ist ein Notfall-Totem gerade? 2 = jetzt (leuchten), 1 = erhöht (halb hell), nil = Ruhe
local SLOT_KEYS_LIST = { "fire", "earth", "water", "air" }
local function DangerFor(key, now)
  if key == "TREMOR" then
    if state.fearUntil > now then return 2, L["FEAR!"] end
    if state.fearAt then
      local dt = state.fearAt - now
      if dt > -3 and dt < 10 then return 2, (dt > 0) and format(L["Fear in %d"], ceil(dt)) or L["FEAR!"] end
    end
    return nil
  end
  local d = state.danger[key]
  if d then
    if d.untilT and d.untilT > now then return 2, L["NOW!"] end
    if d.at then
      local dt = d.at - now
      if dt > -3 and dt < 10 then return 2, (dt > 0) and format(L["in %d"], ceil(dt)) or L["NOW!"] end
    end
  end
  -- Debuffs in der Gruppe (nur lesbar, solange der Client es erlaubt)
  if (key == "POISON_CLEANSE" and state.poison >= 2) or (key == "DISEASE_CLEANSE" and state.disease >= 2) then
    return 2, L["NOW!"]
  end
  -- Boss ist für diese Gefahr bekannt (Boss-Regel empfiehlt das Totem): halb hell
  local boss = TotemWatchDB.useBoss and state.boss
  if boss then
    for _, sk in ipairs(SLOT_KEYS_LIST) do
      for _, e in ipairs(boss[sk] or {}) do
        if e[1] == key then return 1, "" end
      end
    end
  end
  return nil
end

-- Gefahr aus einem Zaubernamen oder Bossmod-Timer ableiten (Gift, Krankheit, Grounding)
function ns.MarkDanger(text, at)
  if not text or IsSecret(text) then return end
  local t = lower(text)
  for key, words in pairs(ns.EMERGENCY_KEYWORDS) do
    for _, w in ipairs(words) do
      if find(t, w, 1, true) then
        local d = state.danger[key] or {}
        d.at = at
        -- Gift/Krankheit wirken nach dem Treffer weiter: noch 8 s leuchten
        if key ~= "GROUNDING" then d.untilT = at + 8 end
        state.danger[key] = d
        break
      end
    end
  end
end

local function CreateEmergencyButton(def)
  local b = CreateFrame("Button", def.name, UIParent, "SecureActionButtonTemplate")
  b:SetSize(64, 64)
  b:SetFrameStrata("MEDIUM")
  b:SetClampedToScreen(true)
  b:SetMovable(true)
  RegisterClicks(b)
  b:SetAttribute("type1", "spell")
  b:Hide()
  b.def = def
  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetAllPoints()
  b.border:SetColorTexture(0.15, 0.15, 0.15, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
  b.text:SetPoint("BOTTOM", b, "TOP", 0, 3)   -- über dem Knopf (überdeckt keinen Nachbarknopf)
  b.text:SetJustifyH("CENTER"); b.text:SetWordWrap(false)
  b.glow = MakeGlow(b, 64)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L[def.label], 1, 1, 1)
    GameTooltip:AddLine(L[def.desc], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Anzeige: dunkel / halb hell / leuchtend mit Countdown / grün
  local acc = 0
  local slot = ns.TOTEMS[def.key].slot
  b:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    local now = GetTime()
    local have, name = TotemData(slot)
    local active = have and name and name ~= "" and KeyFromName(name) == def.key
    local level, text = DangerFor(def.key, now)
    local dim = (TotemWatchDB and TotemWatchDB.tremorDim) or 0.15
    if active then
      self:SetAlpha(1)
      self.border:SetColorTexture(0.1, 0.9, 0.1, 1); self.rr, self.rg, self.rb = 0.1, 0.9, 0.1
      SetGlow(self.glow, false)
      self.text:SetText(L["Active"])
      self.text:SetTextColor(0.4, 1, 0.4)
    elseif level == 2 then
      self:SetAlpha(1)
      self.border:SetColorTexture(1, 0.1, 0.1, 1); self.rr, self.rg, self.rb = 1, 0.1, 0.1
      SetGlow(self.glow, true)
      self.text:SetText(text or ""); self.text:SetTextColor(1, 0.3, 0.3)
    elseif level == 1 then
      self:SetAlpha(math.max(dim, 0.6))
      self.border:SetColorTexture(1, 0.55, 0.1, 1); self.rr, self.rg, self.rb = 1, 0.55, 0.1
      SetGlow(self.glow, false)
      self.text:SetText("")
    else
      self:SetAlpha(ns.emergencyMoving and 1 or dim)
      self.border:SetColorTexture(0.15, 0.15, 0.15, 1); self.rr, self.rg, self.rb = 0.08, 0.08, 0.08
      SetGlow(self.glow, false)
      self.text:SetText("")
    end
    if self.roundIcon and ns.RoundEmergency then ns.RoundEmergency(self) end
    -- Nur wegen einer Warnung außerhalb des Kampfes eingeblendet: danach wieder normale Sichtbarkeit
    if self.tempShown and not level and not InCombatLockdown() then
      self.tempShown = nil
      if ns.ApplyVisibilityDriver then ns.ApplyVisibilityDriver() end
    end
  end)

  -- Verschieben: blaue Fläche über dem Knopf (ziehen, Rechtsklick = fixieren)
  local mover = CreateFrame("Frame", nil, UIParent)
  mover:SetFrameStrata("DIALOG")
  mover:SetAllPoints(b)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  mover:Hide()
  mover.bg = mover:CreateTexture(nil, "BACKGROUND")
  mover.bg:SetAllPoints(); mover.bg:SetColorTexture(0.1, 0.4, 0.9, 0.45)
  mover:SetScript("OnDragStart", function() if not InCombatLockdown() then b:StartMoving() end end)
  mover:SetScript("OnDragStop", function()
    b:StopMovingOrSizing()
    local p, _, _, x, y = b:GetPoint()
    TotemWatchDB[def.db .. "Point"], TotemWatchDB[def.db .. "X"], TotemWatchDB[def.db .. "Y"] = p, x, y
  end)
  mover:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleEmergencyMove(false) end
  end)
  b.mover = mover
  return b
end

-- Notfall-Reihe: alle Notfall-Knöpfe; angedockte stehen oben über der Leiste nebeneinander
ns.emergency = {}
for _, def in ipairs(EMERGENCY_DEFS) do
  ns.emergency[#ns.emergency + 1] = { btn = CreateEmergencyButton(def), def = def }
end
local tremorBtn = ns.emergency[1].btn
ns.tremorBtn = tremorBtn

function ns.LayoutEmergency()
  if InCombatLockdown() then state.pendingSecure = true; return end
  local db = TotemWatchDB
  local x, rowH = 0, 0
  for _, e in ipairs(ns.emergency) do
    local b, key = e.btn, e.def.db
    local point = db[key .. "Point"]
    b:ClearAllPoints()
    if point then
      -- frei platziert (vom Spieler verschoben)
      b:SetPoint(point, UIParent, point, db[key .. "X"] or 0, db[key .. "Y"] or 0)
    else
      -- angedockt: oben über der Leiste, nebeneinander (rechts daneben Platz für den Text)
      b:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, 6)
      if e.enabled then
        x = x + b:GetWidth() + 20
        rowH = math.max(rowH, b:GetHeight())
      end
    end
  end
  -- Große Warnmeldung über der Leiste über die Notfall-Reihe heben
  alert:ClearAllPoints()
  alert:SetPoint("BOTTOM", frame, "TOP", 0, 6 + (rowH > 0 and rowH + 28 or 0))   -- + Platz für den Text über den Knöpfen
end

-- Alle wieder an die Leiste andocken
function ns.AttachEmergency()
  if InCombatLockdown() then return false end
  for _, e in ipairs(ns.emergency) do
    local k = e.def.db
    TotemWatchDB[k .. "Point"], TotemWatchDB[k .. "X"], TotemWatchDB[k .. "Y"] = nil, nil, nil
  end
  ns.SetupEmergency()
  return true
end

-- Verschiebe-Modus für alle eingeschalteten Notfall-Knöpfe
function ns.ToggleEmergencyMove(on)
  if InCombatLockdown() then return ns.emergencyMoving end
  if on == nil then on = not ns.emergencyMoving end
  ns.emergencyMoving = on
  for _, e in ipairs(ns.emergency) do
    if on and e.enabled then
      e.btn:Show(); e.btn.mover:Show()
    else
      e.btn.mover:Hide()
    end
  end
  if not on and ns.ApplyVisibilityDriver then ns.ApplyVisibilityDriver() end
  return on
end

-- Einrichten (außerhalb des Kampfes): Zauber, Größe, Position, Sichtbarkeit
function ns.SetupEmergency()
  if InCombatLockdown() then state.pendingSecure = true; return end
  local db = TotemWatchDB
  local size = db.tremorSize or 64
  for _, e in ipairs(ns.emergency) do
    local b, def = e.btn, e.def
    local known = IsKnown(def.key)
    e.enabled = known and db[def.db .. "Button"] and true or false
    b:SetAttribute("spell1", known and TotemName(def.key) or nil)
    b:SetSize(size, size)
    b.glow:SetSize(size * 1.85, size * 1.85)
    b.text:SetFont(STANDARD_TEXT_FONT, math.max(12, floor(size / 4)), "OUTLINE")
    b.icon:SetTexture(SpellIcon(ns.TOTEMS[def.key].id))
  end
  ns.tremorActive = ns.emergency[1].enabled
  ns.LayoutEmergency()   -- Position: oben an der Leiste oder frei platziert
  if ns.ApplyVisibilityDriver then ns.ApplyVisibilityDriver() end
end

-- Außerhalb des Kampfes sind die Knöpfe sonst versteckt: bei einer Warnung kurz einblenden
-- (im Kampf zeigt sie der Sichtbarkeits-Treiber ohnehin)
function ns.RevealEmergency()
  if InCombatLockdown() then return end
  local now = GetTime()
  for _, e in ipairs(ns.emergency or {}) do
    if e.enabled and not e.btn:IsShown() and DangerFor(e.def.key, now) == 2 then
      e.btn.tempShown = true
      e.btn:Show()
    end
  end
end

-- Test: alle Notfall-Knöpfe in 5 s aufleuchten lassen
function ns.TestEmergency()
  local at = GetTime() + 5
  state.fearAt = at
  for _, k in ipairs({ "POISON_CLEANSE", "DISEASE_CLEANSE", "GROUNDING" }) do
    state.danger[k] = { at = at, untilT = (k ~= "GROUNDING") and (at + 8) or nil }
  end
  ns.RevealEmergency()
end

-- alte Namen weiter erlauben (Optionen, Befehle)
ns.SetupTremor = function() return ns.SetupEmergency() end
ns.AttachTremor = function() return ns.AttachEmergency() end
ns.ToggleTremorMove = function(on) return ns.ToggleEmergencyMove(on) end

-- Masque: Knöpfe im Look des gewählten Masque-Skins (nur wenn Masque installiert ist)
function ns.SetupMasque()
  if ns.masqueGroup or not (TotemWatchDB and TotemWatchDB.useMasque) then return end
  local Masque = LibStub and LibStub("Masque", true)
  if not Masque then return end
  local ok, group = pcall(Masque.Group, Masque, "TotemWatch", L["Totem bar"])
  if not ok or not group then return end
  for _, b in ipairs({ slots[1], slots[2], slots[3], slots[4], weaponBtn, shieldBtn, callBtn, moveBtn, recallBtn }) do
    pcall(group.AddButton, group, b, { Icon = b.icon, Cooldown = b.cd, Highlight = b:GetHighlightTexture() })
  end
  for _, e in ipairs(ns.emergency or {}) do
    pcall(group.AddButton, group, e.btn, { Icon = e.btn.icon, Highlight = e.btn:GetHighlightTexture() })
  end
  ns.masqueGroup = group
end

local function SimpleTooltip(b, titleText, extra)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(titleText .. ": " .. (self:GetAttribute("spell1") or L["not set"]), 1, 1, 1)
    if self.info then GameTooltip:AddLine(self.info, 0.8, 0.8, 0.8, true) end
    if extra then GameTooltip:AddLine(extra, 0.6, 0.6, 0.6, true) end
    GameTooltip:AddLine(L["Left-click: use  ·  Right-click: choose"], 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
end
SimpleTooltip(weaponBtn, L["Weapon"], L["Note: oils/stones also count as an enchant."])
SimpleTooltip(shieldBtn, L["Shield"])

-- Meldungen in der Bildschirmmitte (groß, mit Umrandung, blenden aus)
local msgFrame = CreateFrame("MessageFrame", "TotemWatchMessages", UIParent)
msgFrame:SetSize(800, 120)
msgFrame:SetPoint("TOP", UIParent, "TOP", 0, -170)
msgFrame:SetFrameStrata("HIGH")
pcall(msgFrame.SetInsertMode, msgFrame, "TOP")
msgFrame:SetFading(true)
msgFrame:SetFadeDuration(1.5)
msgFrame:SetTimeVisible(3)
msgFrame:SetJustifyH("CENTER")
function ns.ApplyMessageFont()
  local size = (TotemWatchDB and TotemWatchDB.messageSize) or 24
  msgFrame:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
  msgFrame:SetShadowOffset(2, -2)
  msgFrame:SetShadowColor(0, 0, 0, 1)
end
ns.ApplyMessageFont()

-- Meldungsbereich verschiebbar (nicht geschützt -> geht auch im Kampf)
msgFrame:SetMovable(true)
msgFrame:SetClampedToScreen(true)
msgFrame:EnableMouse(false)
msgFrame.anchorBg = msgFrame:CreateTexture(nil, "BACKGROUND")
msgFrame.anchorBg:SetAllPoints()
msgFrame.anchorBg:SetColorTexture(0.1, 0.4, 0.9, 0.35)
msgFrame.anchorBg:Hide()
msgFrame.anchorText = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
msgFrame.anchorText:SetPoint("BOTTOM", msgFrame, "BOTTOM", 0, 6)
msgFrame.anchorText:SetText(L["TotemWatch messages – drag to move, right-click to lock"])
msgFrame.anchorText:Hide()

function ns.ApplyMessagePosition()
  local db = TotemWatchDB or {}
  msgFrame:ClearAllPoints()
  msgFrame:SetPoint(db.msgPoint or "TOP", UIParent, db.msgPoint or "TOP", db.msgX or 0, db.msgY or -170)
end

function ns.ToggleMessageMove(on)
  if on == nil then on = not ns.msgMoving end
  ns.msgMoving = on
  msgFrame:EnableMouse(on)
  if on then
    msgFrame.anchorBg:Show(); msgFrame.anchorText:Show()
    msgFrame:AddMessage(L["Example: Earth: Tremor Totem – missing"], 1, 0.1, 0.1)
  else
    msgFrame.anchorBg:Hide(); msgFrame.anchorText:Hide()
  end
  return on
end

msgFrame:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
    self:StartMoving()
  elseif button == "RightButton" then
    ns.ToggleMessageMove(false)
    print("|cff0070deTotemWatch|r: " .. L["Message position saved."])
  end
end)
msgFrame:SetScript("OnMouseUp", function(self)
  self:StopMovingOrSizing()
  local p, _, _, x, y = self:GetPoint()
  if TotemWatchDB then TotemWatchDB.msgPoint, TotemWatchDB.msgX, TotemWatchDB.msgY = p, x, y end
end)

-- Sprachausgabe (Text-to-Speech) für wichtige Warnungen; höchstens alle 8 s derselbe Text
local lastSpoken = {}
function ns.Speak(text, force)
  if not text or text == "" or not TotemWatchDB or (not TotemWatchDB.speak and not force) then return end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local now = GetTime()
  if not force and lastSpoken[text] and now - lastSpoken[text] < 8 then return end
  lastSpoken[text] = now
  local ok = false
  -- Weg 1: Blizzards TTS-Oberfläche (neuere Clients)
  if TextToSpeech_Speak and TextToSpeech_GetSelectedVoice and Enum and Enum.TtsVoiceType then
    ok = pcall(function() TextToSpeech_Speak(text, TextToSpeech_GetSelectedVoice(Enum.TtsVoiceType.Standard)) end)
  end
  -- Weg 2: direkt über C_VoiceChat
  if not ok and C_VoiceChat and C_VoiceChat.SpeakText and C_VoiceChat.GetTtsVoices then
    ok = pcall(function()
      local voices = C_VoiceChat.GetTtsVoices()
      local voice = voices and voices[1] and voices[1].voiceID or 0
      local dest = (Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback) or 1
      C_VoiceChat.SpeakText(voice, text, dest, 0, 100)
    end)
  end
  ns.ttsWorks = ok
  return ok
end

-- Test: Warnton, Meldung und Sprachausgabe auf einmal (unabhängig von den Optionen)
function ns.TestWarnings()
  PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
  msgFrame:AddMessage(L["Test: Tremor Totem now!"], 1, 0.2, 0.2)
  local spoke = ns.Speak(L["Tremor Totem now!"], true)
  print("|cff0070deTotemWatch|r: " .. (spoke and L["Test warning played: sound, message and speech."]
    or L["Test warning played: sound and message. Text to speech is not available on this client."]))
end

local lastMessage = {}
-- Zeigt eine Meldung, aber dieselbe höchstens alle 8 Sekunden
function ns.ShowMessage(text, r, g, b)
  if not text or text == "" or not TotemWatchDB or not TotemWatchDB.messages then return end
  local now = GetTime()
  if lastMessage[text] and now - lastMessage[text] < 8 then return end
  lastMessage[text] = now
  msgFrame:AddMessage(text, r or 1, g or 0.82, b or 0)
end

-- Hinweise unter der Leiste: dunkler Hintergrund + Schrift mit Umrandung (im Kampf gut lesbar)
local MAX_HINTS = 8
local HINT_WIDTH = 460
local hintBg = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
hintBg:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
hintBg:SetSize(HINT_WIDTH + 12, 20)
if hintBg.SetBackdrop then
  hintBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  hintBg:SetBackdropColor(0, 0, 0, 0.8)
  hintBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
end
hintBg:SetAlpha(0)

local hints = {}
for i = 1, MAX_HINTS do
  local fs = hintBg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  fs:SetWidth(HINT_WIDTH)
  hints[i] = fs
end

local hintLineHeight = 16
function ns.ApplyHintFont()
  local size = (TotemWatchDB and TotemWatchDB.hintSize) or 13
  hintLineHeight = size + 4
  for i, fs in ipairs(hints) do
    fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetWordWrap(true)
    fs:ClearAllPoints()
    -- fortlaufend: jeder Hinweis direkt unter dem vorherigen (auch wenn dieser umbricht)
    if i == 1 then
      fs:SetPoint("TOPLEFT", hintBg, "TOPLEFT", 6, -5)
    else
      fs:SetPoint("TOPLEFT", hints[i - 1], "BOTTOMLEFT", 0, -2)
    end
  end
end
ns.ApplyHintFont()

local STATUS_COLOR = {
  OK        = { 0.1, 0.9, 0.1 },
  EXPIRING  = { 1.0, 0.85, 0.0 },
  WRONG     = { 1.0, 0.5, 0.0 },
  DUPLICATE = { 1.0, 0.5, 0.0 },
  MISSING   = { 1.0, 0.1, 0.1 },
  COVERED   = { 0.2, 0.6, 1.0 },
  FAR       = { 1.0, 0.55, 0.1 },
  NONE      = { 0.4, 0.4, 0.4 },
}

local function CurrentSkin()
  return ns.SKINS[(TotemWatchDB and TotemWatchDB.skin) or "classic"] or ns.SKINS.classic
end
ns.CurrentSkin = CurrentSkin

local CALM = { OK = true, NONE = true, COVERED = true }
local function SetBorder(b, status, pulse)
  local c = STATUS_COLOR[status] or STATUS_COLOR.NONE
  b.statusColor = c
  b.statusKey = status
  if TotemWatchDB and TotemWatchDB.cleanLook and b.cleanLine then
    -- Clean Look: immer ein feiner dunkler Rahmen; Farbe nur als Linie, wenn etwas zu tun ist
    if b.pulse:IsPlaying() then b.pulse:Stop() end
    b.border:SetAlpha(1)
    b.border:SetColorTexture(0.06, 0.06, 0.06, 0.9)
    if b.strip then b.strip:Hide() end
    if CALM[status] then
      b.cleanLine:Hide()
      if b.cleanPulse:IsPlaying() then b.cleanPulse:Stop() end
    else
      b.cleanLine:SetColorTexture(c[1], c[2], c[3], 1)
      b.cleanLine:Show()
      if pulse then
        if not b.cleanPulse:IsPlaying() then b.cleanPulse:Play() end
      elseif b.cleanPulse:IsPlaying() then
        b.cleanPulse:Stop(); b.cleanLine:SetAlpha(1)
      end
    end
    return
  end
  if b.cleanLine then b.cleanLine:Hide() end
  local skin = CurrentSkin()
  if skin.strip and b.slot then
    -- Minimal: schwarzer Rahmen, Status als Farbstreifen
    b.border:SetColorTexture(0, 0, 0, 1)
    b.strip:SetColorTexture(c[1], c[2], c[3], 1)
  else
    b.border:SetColorTexture(c[1], c[2], c[3], 1)
  end
  local target = (skin.strip and b.slot) and b.strip or b.border
  if pulse then
    if not b.pulse:IsPlaying() then b.pulse:Play() end
  else
    if b.pulse:IsPlaying() then b.pulse:Stop() end
    b.border:SetAlpha(1)
  end
  target:SetAlpha(1)
end

-- Hex-Farbe "ff7f3f" -> r, g, b
local function HexColor(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end


-- Design anwenden: Rahmen, Knopfgrößen, Anordnung, Restzeit, Balken, Hinweise.
-- Nur außerhalb des Kampfes (die Knöpfe sind geschützt).
function ns.ApplySkin()
  if InCombatLockdown() then state.pendingSecure = true; return end
  local S = CurrentSkin()
  local size, gap, inset = S.btn, S.gap, S.inset
  local pad = 6
  local clean = TotemWatchDB.cleanLook          -- Clean Look (ruhigere Darstellung)
  local gf = clean and 1.7 or 1.85               -- Leuchten: etwas enger und schwächer im Clean Look

  -- Leiste
  if frame.SetBackdrop then
    local edgeSize = S.edgeSize or 12
    local ins = (edgeSize >= 8) and 3 or edgeSize
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = S.edgeFile, tile = false,
      edgeSize = edgeSize, insets = { left = ins, right = ins, top = ins, bottom = ins } })
    frame:SetBackdropColor(unpack(S.bg))
    frame:SetBackdropBorderColor(unpack(S.edge))
    if clean then
      -- kein Kasten: Hintergrund und Rand unsichtbar, nur die Knöpfe stehen frei
      local a = 0
      frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
      frame:SetBackdropColor(0.04, 0.04, 0.05, a)
      frame:SetBackdropBorderColor(0, 0, 0, a > 0 and 0.9 or 0)
    end
  end
  if S.title and not clean then
    title:Show()
    if not pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 13, "") then title:SetFontObject("GameFontNormal") end
    title:SetText("TotemWatch")
    title:SetTextColor(0.91, 0.77, 0.42)
  else
    title:Hide()
  end
  local top = (S.title and not clean) and 22 or 8                 -- oben: Titel bzw. schmaler Streifen zum Ziehen
  if S.elemStrip then top = top + 6 end

  -- Totem-Knöpfe (Elemente ohne gelerntes Totem werden übersprungen, die anderen rücken auf)
  local vis, nVis = {}, 0
  for s = 1, 4 do
    if slots[s].twKnown ~= false then nVis = nVis + 1; vis[s] = nVis end
  end
  for s = 1, 4 do
    local b = slots[s]
    b:SetSize(size, size)
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", inset, -inset); b.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    b.glow:SetSize(size * gf, size * gf)
    -- Restzeit
    b.timer:ClearAllPoints()
    if S.timer == "inside" then
      b.timer:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 4); b.timer:Show()
    elseif S.timer == "below" then
      b.timer:SetPoint("TOP", b, "BOTTOM", 0, S.bar == "below" and -8 or -1); b.timer:Show()
    elseif S.timer == "right" then
      b.timer:SetPoint("LEFT", b, "RIGHT", 4, 0); b.timer:Show()
    else
      b.timer:Hide()
    end
    -- Status-Farbstreifen (Minimal)
    b.strip:ClearAllPoints()
    if S.strip then
      b.strip:SetPoint("BOTTOMLEFT", inset, inset); b.strip:SetPoint("BOTTOMRIGHT", -inset, inset); b.strip:Show()
    else
      b.strip:Hide()
    end
    -- Element-Farbleiste (Pillars)
    b.elemStrip:ClearAllPoints()
    if S.elemStrip then
      b.elemStrip:SetColorTexture(HexColor(ns.SLOT_COLORS[s]))
      b.elemStrip:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -3, 4); b.elemStrip:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 3, 4)
      b.elemStrip:Show()
    else
      b.elemStrip:Hide()
    end
    -- Zeitbalken
    b.timeBar:ClearAllPoints()
    if S.bar == "below" then
      b.timeBar:SetSize(size + 6, 4)
      b.timeBar:SetPoint("TOP", b, "BOTTOM", 0, -2)
      b.barName:Hide(); b.barTime:Hide(); b.timeBar:Show()
    elseif S.bar == "right" then
      b.timeBar:SetSize(S.barWidth or 200, size)
      b.timeBar:SetPoint("LEFT", b, "RIGHT", 3, 0)
      b.barName:Show(); b.barTime:Show(); b.timeBar:Show()
    else
      b.timeBar:Hide()
    end
    -- Position
    b:ClearAllPoints()
    b:SetAlpha(1)   -- Fokus-Design dimmt im Betrieb; beim Wechsel zurücksetzen
    if S.bar == "right" or S.vertical then
      b:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -top - ((vis[s] or 1) - 1) * (size + gap))
    else
      b:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + ((vis[s] or 1) - 1) * (size + gap), -top)
    end
    SetBorder(b, "NONE", false)
    if not vis[s] then b.timeBar:Hide() end   -- Element ohne gelerntes Totem: ganz ausblenden
  end

  -- Zusatzknöpfe (ALLE, Call, Totemic Call, Recall, Waffe, Schild)
  local extras = { castAll, callBtn, moveBtn, recallBtn, weaponBtn, shieldBtn }
  for _, b in ipairs(extras) do b:SetAlpha(1) end
  -- ALLE / Call / Totemic Call / Recall: gewünscht laut Optionen? (Kompakt: hinter "...")
  local wanted = {
    [castAll] = TotemWatchDB.showAll,
    [callBtn] = ns.callName and TotemWatchDB.showCall,
    [moveBtn] = ns.moveName and TotemWatchDB.showMove,
    [recallBtn] = ns.recallName and TotemWatchDB.showRecall,
  }
  for b, want in pairs(wanted) do
    b:SetAttribute("twEnabled", want and true or false)
    if want and not S.more then b:Show() else b:Hide() end
  end
  moreBtn:SetAttribute("open", false)
  if S.more then moreBtn:Show() else moreBtn:Hide() end

  local width, height
  local esize = S.extraBtn or size
  local function PlaceExtra(b, x, y, sz)
    b:SetSize(sz, sz)
    if b.glow then b.glow:SetSize(sz * gf, sz * gf) end
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  end
  if S.more then
    -- Kompakt: Waffe/Schild klein rechts daneben, dann "...";
    -- die übrigen Zusatzknöpfe klappen über dem "..." auf
    local x = pad + nVis * (size + gap) + 4
    local y = -top - (size - esize) / 2
    for _, b in ipairs({ weaponBtn, shieldBtn }) do
      if b:IsShown() then PlaceExtra(b, x, y, esize); x = x + esize + 3 end
    end
    moreBtn:SetSize(esize, esize)
    moreBtn:ClearAllPoints(); moreBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    x = x + esize
    local i = 0
    for _, b in ipairs({ castAll, callBtn, moveBtn, recallBtn }) do
      if wanted[b] then
        b:SetSize(esize + 6, esize + 6)
        if b.glow then b.glow:SetSize((esize + 6) * gf, (esize + 6) * gf) end
        b:ClearAllPoints()
        b:SetPoint("BOTTOMRIGHT", moreBtn, "TOPRIGHT", -i * (esize + 9), 4)
        i = i + 1
      end
    end
    width = x + pad
    height = top + size + ((S.timer == "below") and 16 or 4)
  elseif S.extrasBelow or S.vertical then
    -- Zwei Ebenen / Senkrecht: alle Zusatzknöpfe als kleine Reihe darunter
    local y = S.vertical and (-top - nVis * (size + gap) - 2) or (-top - size - 4)
    local x = pad
    for _, b in ipairs(extras) do
      if b:IsShown() then PlaceExtra(b, x, y, esize); x = x + esize + 3 end
    end
    if S.vertical then
      width = math.max(pad + size + 44, x + pad)
      height = top + nVis * (size + gap) + ((x > pad) and (esize + 16) or 0) + 2
    else
      width = math.max(pad + nVis * (size + gap) - gap + pad, x + pad)
      height = top + size + 4 + ((x > pad) and (esize + 16) or 0) + 2
    end
  elseif S.bar == "right" then
    -- Bars: Zusatzknöpfe in einer Reihe unter den Balken
    local y = -top - nVis * (size + gap) - 3
    local x = pad
    local esize = S.extraBtn or size          -- Zusatzknöpfe dürfen größer sein als die Zeilen-Icons
    for _, b in ipairs(extras) do
      b:SetSize(esize, esize)
      if b.glow then b.glow:SetSize(esize * gf, esize * gf) end
      if b:IsShown() then
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        x = x + esize + 4
      end
    end
    width = math.max(pad + size + 3 + (S.barWidth or 200) + pad, x + pad)
    -- Platz für die Restzeit unter Waffe/Schild einplanen
    height = top + nVis * (size + gap) + ((x > pad) and (esize + 18) or 0) + 4
  else
    local x = pad + nVis * (size + gap) + 6
    for _, b in ipairs(extras) do
      b:SetSize(size, size)
      if b.glow then b.glow:SetSize(size * gf, size * gf) end
      if b:IsShown() then
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -top)
        x = x + size + gap
      end
    end
    width = x - gap + pad
    local below = (S.timer == "below" and 16 or 4) + (S.bar == "below" and 8 or 0)
    height = top + size + below + 2
  end
  frame:SetSize(math.max(width, 120), height)
  -- Masque-Skin an die neuen Knopfgrößen anpassen
  if ns.masqueGroup then pcall(ns.masqueGroup.ReSkin, ns.masqueGroup) end

  -- Hinweise im passenden Stil
  if hintBg.SetBackdrop then
    local edgeSize = (S.edgeSize and S.edgeSize >= 8) and 10 or 1
    hintBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = S.edgeFile, tile = false,
      edgeSize = edgeSize, insets = { left = (edgeSize > 1) and 2 or 1, right = (edgeSize > 1) and 2 or 1,
      top = (edgeSize > 1) and 2 or 1, bottom = (edgeSize > 1) and 2 or 1 } })
    hintBg:SetBackdropColor(unpack(S.hintBg))
    hintBg:SetBackdropBorderColor(unpack(S.hintEdge))
    if clean then
      hintBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", tile = false, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      hintBg:SetBackdropColor(0, 0, 0, 0.35)   -- nur ein Hauch Hintergrund, damit der Text auf hellem Boden lesbar bleibt
    end
  end
  -- Schrift: im Clean Look eine schlichte Schrift mit Schatten statt dicker Umrandung
  for _, b in ipairs({ slots[1], slots[2], slots[3], slots[4], weaponBtn, shieldBtn, callBtn, moveBtn, recallBtn }) do
    for _, fs in ipairs({ b.timer, b.label }) do
      if clean then
        fs:SetFont(STANDARD_TEXT_FONT, 10, "")
        fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
        fs:SetTextColor(0.85, 0.85, 0.85)
      else
        fs:SetFontObject("NumberFontNormal"); fs:SetTextColor(1, 1, 1)
      end
    end
    b.farText:SetFont(STANDARD_TEXT_FONT, clean and 11 or 14, "OUTLINE")
    -- Zahl (Aufladungen / Spieler außer Reichweite): im Clean Look als kleines Abzeichen unten rechts,
    -- damit sie nicht mit "far" oder der Restzeit kollidiert
    b.label:ClearAllPoints()
    if clean then
      b.label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
      b.label:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    else
      b.label:SetPoint("BOTTOMLEFT", 2, 2)
    end
    if clean then b.farText:ClearAllPoints(); b.farText:SetPoint("CENTER", b, "CENTER", 0, 1) end
    b.farText:SetShadowOffset(1, -1); b.farText:SetShadowColor(0, 0, 0, 1)
    if not clean then b.icon:SetVertexColor(1, 1, 1); b.icon:SetAlpha(1) end
    if b.glow then b.glow:SetVertexColor(1, 0.85, 0.2, clean and 0.5 or 1) end
  end
  hintBg:SetWidth(math.max(frame:GetWidth(), 380))
  for _, fs in ipairs(hints) do fs:SetWidth(hintBg:GetWidth() - 12) end
  if ns.ApplyRound then ns.ApplyRound() end   -- runde Symbole an/aus
end

-- Clean Look, nach jeder Aktualisierung: Mini-Symbole aus (stehen im Tooltip),
-- ruhige Symbole leicht abgedunkelt, nur Knöpfe mit Handlungsbedarf in voller Farbe,
-- leere Plätze als dunkles Feld statt Fragezeichen.
function ns.CleanPost()
  if not (TotemWatchDB and TotemWatchDB.cleanLook) then return end
  for _, b in ipairs({ slots[1], slots[2], slots[3], slots[4], weaponBtn, shieldBtn }) do
    b.rec:Hide(); b.other:Hide(); b.cur:Hide()
    SetGlow(b.recGlow, false)
    local tex = b.icon:GetTexture()
    local empty = tex == nil or tex == 134400 or (type(tex) == "string" and tex:find("QuestionMark") ~= nil)
    b.icon:SetAlpha(empty and 0 or 1)
    local v = CALM[b.statusKey or "NONE"] and 0.72 or 1
    b.icon:SetVertexColor(v, v, v)
  end
end

-- Runde Symbole: das Symbol wird aus schmalen waagerechten Streifen zusammengesetzt,
-- deren Breite einem Kreis folgt; ein feiner Ring deckt die Stufen am Rand ab.
-- Nur normale Texturen – keine Masken (Masken haben bei WoW Forever einen Absturz ausgelöst).
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local ROUND_ROWS = 20

local function LayoutRound(r)
  local w, h = r:GetWidth(), r:GetHeight()
  if not w or w <= 0 or not h or h <= 0 then return end
  for i, t in ipairs(r.strips) do
    local y0, y1 = (i - 1) / ROUND_ROWS, i / ROUND_ROWS
    local yc = (y0 + y1) / 2 - 0.5
    local hw = math.sqrt(math.max(0, 0.25 - yc * yc))
    local x0, x1 = 0.5 - hw, 0.5 + hw
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", r, "TOPLEFT", x0 * w, -y0 * h)
    t:SetSize(math.max(0.1, (x1 - x0) * w), h / ROUND_ROWS + 0.05)   -- minimal überlappen: keine Lücken
    t:SetTexCoord(0.08 + x0 * 0.84, 0.08 + x1 * 0.84, 0.08 + y0 * 0.84, 0.08 + y1 * 0.84)
  end
end

local function EnsureRound(b)
  if b.roundIcon then return b.roundIcon end
  local r = CreateFrame("Frame", nil, b)
  r:SetPoint("TOPLEFT", b.icon, "TOPLEFT")
  r:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT")
  r.strips = {}
  for i = 1, ROUND_ROWS do r.strips[i] = r:CreateTexture(nil, "ARTWORK") end
  r:SetScript("OnSizeChanged", LayoutRound)
  r.ring = (b.over or b):CreateTexture(nil, "OVERLAY", nil, 1)
  r.ring:SetTexture(MEDIA .. "round_ring")
  r.ring:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -1, 1)
  r.ring:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, -1)
  r:Hide(); r.ring:Hide()
  b.roundIcon = r
  return r
end

local function SetRound(b, on)
  if not on and not b.roundIcon then return end
  local r = EnsureRound(b)
  local hl = b:GetHighlightTexture()
  if on then
    r.src = nil
    r:Show(); r.ring:Show(); b.icon:Hide()
    LayoutRound(r)
    if b.cd then pcall(b.cd.SetSwipeTexture, b.cd, MEDIA .. "round_disc") end
    if b.glow then b.glow:SetTexture(MEDIA .. "round_glow") end      -- weicher runder Leucht-Kreis
    b:SetHighlightTexture(MEDIA .. "round_disc", "ADD")
    hl = b:GetHighlightTexture()
    if hl then hl:ClearAllPoints(); hl:SetAllPoints(r); hl:SetVertexColor(1, 1, 1, 0.3) end
  else
    r:Hide(); r.ring:Hide(); b.icon:Show()
    b.border:SetAlpha(1)
    if b.cd then pcall(b.cd.SetSwipeTexture, b.cd, "Interface\\Buttons\\WHITE8X8") end
    if b.glow then b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border") end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    hl = b:GetHighlightTexture()
    if hl then hl:ClearAllPoints(); hl:SetAllPoints(b); hl:SetVertexColor(1, 1, 1, 1) end
  end
end

local ROUND_BUTTONS
local function RoundButtons()
  ROUND_BUTTONS = ROUND_BUTTONS or { slots[1], slots[2], slots[3], slots[4], weaponBtn, shieldBtn,
                                     callBtn, moveBtn, recallBtn }
  return ROUND_BUTTONS
end

-- Ein/aus laut Einstellung (aus ApplySkin, außerhalb des Kampfes)
function ns.ApplyRound()
  local on = TotemWatchDB and TotemWatchDB.roundIcons and not ns.masqueGroup and true or false
  for _, b in ipairs(RoundButtons()) do SetRound(b, on) end

  -- Notfall-Knöpfe ebenfalls rund
  for _, e in ipairs(ns.emergency or {}) do
    SetRound(e.btn, on)
    if on and e.btn.roundIcon then e.btn.roundIcon.src = nil; ns.RoundEmergency(e.btn) end
  end

  -- ALLE-Knopf: runde blaue Fläche statt Quadrat
  local hl
  if on then
    castAll.bg:SetTexture(MEDIA .. "round_disc")
    castAll.bg:SetVertexColor(0.05, 0.25, 0.55, 1)
    castAll:SetHighlightTexture(MEDIA .. "round_disc", "ADD")
    hl = castAll:GetHighlightTexture()
    if hl then hl:SetVertexColor(1, 1, 1, 0.3) end
  else
    castAll.bg:SetVertexColor(1, 1, 1, 1)
    castAll.bg:SetColorTexture(0.05, 0.25, 0.55, 1)
    castAll:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    hl = castAll:GetHighlightTexture()
    if hl then hl:SetVertexColor(1, 1, 1, 1) end
  end

  -- Zeitbalken unter runden Symbolen (Pillars): schmaler und feiner
  if on and CurrentSkin().bar == "below" then
    for s = 1, 4 do
      local w = slots[s]:GetWidth() or 30
      slots[s].timeBar:SetSize(w * 0.7, 2)
    end
  end

  -- Element-Farbe (Pillars): kleiner farbiger Punkt über dem Kreis statt eines Balkens
  for s = 1, 4 do
    local st = slots[s].elemStrip
    if st:IsShown() then
      if on then
        local r, g, b = HexColor(ns.SLOT_COLORS[s])
        st:SetTexture(MEDIA .. "round_disc")
        st:SetVertexColor(r, g, b, 1)
        st:ClearAllPoints()
        st:SetSize(7, 7)
        st:SetPoint("BOTTOM", slots[s], "TOP", 0, 3)
      else
        st:SetVertexColor(1, 1, 1, 1)   -- ApplySkin hat die Farbleiste schon wieder gesetzt
      end
    end
  end
end

-- Notfall-Knopf rund: Symbol übernehmen, eckigen Rahmen ausblenden, Ring in der Zustandsfarbe
function ns.RoundEmergency(b)
  local r = b.roundIcon
  if not (r and r:IsShown()) then return end
  local tex = b.icon:GetTexture()
  if tex ~= r.src then
    r.src = tex
    for _, t in ipairs(r.strips) do t:SetTexture(tex) end
  end
  b.border:SetAlpha(0)
  r.ring:SetVertexColor(b.rr or 0.08, b.rg or 0.08, b.rb or 0.08, 1)
end

-- Nach jeder Aktualisierung: Streifen an das echte Symbol angleichen (Bild, Farbe, Helligkeit),
-- eckigen Rahmen ausblenden, Status als Farbe des Rings zeigen.
function ns.RoundPost()
  for _, b in ipairs(RoundButtons()) do
    local r = b.roundIcon
    if r and r:IsShown() then
      local icon = b.icon
      local tex = icon:GetTexture()
      if tex ~= r.src then
        r.src = tex
        for _, t in ipairs(r.strips) do t:SetTexture(tex) end
      end
      local vr, vg, vb = icon:GetVertexColor()
      local a = icon:GetAlpha()
      local desat = icon.IsDesaturated and icon:IsDesaturated() or false
      for _, t in ipairs(r.strips) do
        t:SetVertexColor(vr, vg, vb); t:SetAlpha(a); t:SetDesaturated(desat)
      end
      if b.pulse and b.pulse:IsPlaying() then b.pulse:Stop() end
      b.border:SetAlpha(0)
      if b.cleanLine then b.cleanLine:Hide() end
      local c = b.statusColor
      if c and b.statusKey and not CALM[b.statusKey] then
        r.ring:SetVertexColor(c[1], c[2], c[3], 1)
      elseif TotemWatchDB.cleanLook then
        r.ring:SetVertexColor(0.08, 0.08, 0.08, 0.95)
      elseif c then
        r.ring:SetVertexColor(c[1], c[2], c[3], 1)
      else
        r.ring:SetVertexColor(0.3, 0.3, 0.3, 1)
      end
    end
  end
end

local function UpdateCooldown(b, spellName)
  if not spellName then b.cd:Hide(); return end
  local start, duration, onGCD = SpellCooldown(spellName)
  if IsSecret(start) or IsSecret(duration) then
    -- Gesperrte Werte: nicht damit rechnen, sondern direkt an das Cooldown-Element geben
    -- (Blizzard-Elemente dürfen gesperrte Werte anzeigen). Globale Abklingzeit ausblenden, wenn bekannt.
    if onGCD == true then b.cd:Hide(); return end
    if pcall(b.cd.SetCooldown, b.cd, start, duration) then b.cd:Show() else b.cd:Hide() end
    return
  end
  if start and duration and duration > 1.6 then
    b.cd:SetCooldown(start, duration); b.cd:Show()
  else
    b.cd:Hide()
  end
end

---------------------------------------------------------------------------
-- Belegung der Knöpfe (nur außerhalb des Kampfes erlaubt)
---------------------------------------------------------------------------
local function FirstKnown(ids)
  for _, id in ipairs(ids) do if IsKnownId(id) then return id end end
end

local function KnownChoice(saved, ids)
  if not saved then return nil end
  for _, id in ipairs(ids) do
    if SpellName(id) == saved and IsKnownId(id) then return saved end
  end
end

local function DefaultWeaponSpell()
  local equipLoc = ItemEquipInfo(GetInventoryItemLink("player", 16))
  local twoHand = (equipLoc == "INVTYPE_2HWEAPON")
  if twoHand and IsKnownId(8232) then return 8232 end
  return FirstKnown({ 8024, 8017, 8232, 8033 })
end

local function TotemIds(slot)
  local ids = {}
  for _, key in ipairs(ns.FLYOUT[slot]) do ids[#ids + 1] = ns.TOTEMS[key].id end
  return ids
end

local function RebuildCastAll()
  local parts = {}
  for s = 1, 4 do
    local sp = slots[s]:GetAttribute("spell1")
    if sp then parts[#parts + 1] = sp end
  end
  local text = "/castsequence reset=combat/12 " .. table.concat(parts, ", ")
  if castAll:GetAttribute("macrotext1") ~= text then castAll:SetAttribute("macrotext1", text) end
  if ns.SyncMultiCast then ns.SyncMultiCast() end
end

-- Totem-Leiste von "Call of the Elements" mit den TotemWatch-Knöpfen abgleichen (nur außerhalb des Kampfes)
-- Welches Totem liegt auf einer Aktion der Leiste? (nil = leer/unbekannt)
local function ActionTotemKey(action)
  if not GetActionInfo then return nil end
  local ok, kind, id = pcall(GetActionInfo, action)
  if not ok or kind ~= "spell" or not id or IsSecret(id) then return nil end
  local nm = SpellName(id)
  return nm and KeyFromName(nm)
end
ns.ActionTotemKey = ActionTotemKey

-- Welche Aktions-Plätze nutzt die Totem-Leiste des Spiels wirklich?
-- Die Blizzard-Knöpfe der Leiste (MultiCastActionButton1-4) kennen ihren Platz selbst.
-- Nur wenn es diese Knöpfe nicht gibt, gilt die WotLK-Annahme 133-136.
function ns.MultiCastActions()
  local list = {}
  for i = 1, 4 do
    local btn = _G["MultiCastActionButton" .. i]
    local a = btn and btn.action
    if (not a) and btn and btn.GetAttribute then a = btn:GetAttribute("action") end
    if type(a) == "number" and not IsSecret(a) then list[i] = a end
  end
  if list[1] and list[2] and list[3] and list[4] then
    ns.multicastSource = "MultiCastActionButton1-4"
    return list
  end
  ns.multicastSource = format("default %d-%d", ns.MULTICAST_BASE + 1, ns.MULTICAST_BASE + 4)
  return { ns.MULTICAST_BASE + 1, ns.MULTICAST_BASE + 2, ns.MULTICAST_BASE + 3, ns.MULTICAST_BASE + 4 }
end

-- Rechtsklick auf ein Totem im Auswahlmenü legt es auf die Leiste von Call of the Elements.
-- Das nutzt Blizzards sicheren Knopf-Typ "multispell" und funktioniert deshalb auch im Kampf.
-- Einrichten (Attribute setzen) geht nur außerhalb des Kampfes.
function ns.UpdateFlyoutMultispell()
  if InCombatLockdown() then return end
  local active = callBtn:IsShown() and ns.multicastActionForSlot
  for s = 1, 4 do
    local fly = slots[s].flyout
    local action = active and ns.multicastActionForSlot[s]
    if fly and fly.buttons then
      for _, fb in ipairs(fly.buttons) do
        local id = action and fb.spellId and fb:IsShown() and SpellIdFromName(SpellName(fb.spellId))
        if id then
          -- Blizzard: type "multispell" ruft SetMultiCastSpell(action, spell) auf
          fb:SetAttribute("type2", "multispell")
          fb:SetAttribute("action2", action)
          fb:SetAttribute("spell2", id)
          fb:SetAttribute("multispell2", id)
          fb.canMultispell = true
        else
          fb:SetAttribute("type2", nil)
          fb:SetAttribute("action2", nil)
          fb:SetAttribute("spell2", nil)
          fb:SetAttribute("multispell2", nil)
          fb.canMultispell = false
        end
      end
    end
  end
end

function ns.SyncMultiCast()
  ns.multicastKeys = ns.multicastKeys or {}
  ns.multicastMismatch = nil
  if InCombatLockdown() or not callBtn:IsShown() then return end
  local actions = ns.MultiCastActions()

  -- Welche Aktion gehört zu welchem Element? Zuerst aus dem, was schon auf der Leiste liegt,
  -- für leere Plätze die Standard-Reihenfolge (Erde, Feuer, Wasser, Luft).
  local slotOf, used = {}, {}
  for i = 1, 4 do
    local k = ActionTotemKey(actions[i])
    if k then slotOf[i] = ns.TOTEMS[k].slot; used[slotOf[i]] = true end
  end
  local order = TOTEM_PRIORITIES or { 2, 1, 3, 4 }
  for i = 1, 4 do
    if not slotOf[i] then
      for _, s in ipairs(order) do
        if not used[s] then slotOf[i] = s; used[s] = true; break end
      end
    end
  end

  local failed, mismatch = 0, {}
  for i = 1, 4 do
    local action, slot = actions[i], slotOf[i]
    if slot then
      ns.multicastActionForSlot = ns.multicastActionForSlot or {}
      ns.multicastActionForSlot[slot] = action
    end
    local assigned = slot and slots[slot]:GetAttribute("spell1")
    local want = assigned and KeyFromName(assigned)
    -- 1) setzen (wenn gewünscht und möglich)
    if want and TotemWatchDB.syncCall and SetMultiCastSpell and ActionTotemKey(action) ~= want then
      local id = SpellIdFromName(assigned)
      if id then pcall(SetMultiCastSpell, action, id) end
    end
    -- 2) Kontrolle: was liegt jetzt wirklich auf der Leiste?
    local have = ActionTotemKey(action)
    if slot then ns.multicastKeys[slot] = have end
    if want and have ~= want then
      failed = failed + 1
      mismatch[#mismatch + 1] = { slot = slot, have = have, want = want }
    end
  end
  ns.multicastMismatch = (#mismatch > 0) and mismatch or nil
  ns.UpdateFlyoutMultispell()
  ns.syncResult = (failed == 0) and "ok" or (SetMultiCastSpell and "set, but not applied" or "SetMultiCastSpell missing")

  if failed > 0 and TotemWatchDB.syncCall and not ns.syncWarned then
    ns.syncWarned = true
    print("|cff0070deTotemWatch|r: " .. L["Could not update the Call of the Elements bar automatically. Please set the totems on the bar yourself – TotemWatch shows which ones differ. (/tw bar for details)"])
  end
end

local function SetupSecure()
  if InCombatLockdown() then state.pendingSecure = true; return end
  state.pendingSecure = false
  local choice = TotemWatchDB.choice

  for s = 1, 4 do
    local ids = TotemIds(s)
    BuildFlyout(slots[s], ids)
    -- Noch kein Totem dieses Elements gelernt: Knopf ganz ausblenden, bis eins gelernt ist
    local knowsAny = FirstKnown(ids) ~= nil
    slots[s].twKnown = knowsAny
    if knowsAny then slots[s]:Show() else slots[s]:Hide() end
    local cur = KnownChoice(slots[s]:GetAttribute("spell1"), ids) or KnownChoice(choice["slot" .. s], ids)
    if not cur then
      local id = FirstKnown(ids)
      cur = id and SpellName(id)
    end
    ns.autoAssigning = true             -- Wiederherstellen beim Laden ist keine neue eigene Wahl
    slots[s]:SetAttribute("spell1", cur)
    ns.autoAssigning = false
  end

  local wKnown = BuildFlyout(weaponBtn, ns.WEAPON_SPELLS)
  local wCur = KnownChoice(choice.weapon, ns.WEAPON_SPELLS)
  if not wCur then local id = DefaultWeaponSpell(); wCur = id and SpellName(id) end
  weaponBtn:SetAttribute("spell1", wCur)
  if #wKnown > 0 and TotemWatchDB.showWeapon then weaponBtn:Show() else weaponBtn:Hide() end

  local sKnown = BuildFlyout(shieldBtn, ns.SHIELD_SPELLS)
  local sCur = KnownChoice(choice.shield, ns.SHIELD_SPELLS)
  if not sCur then local id = FirstKnown(ns.SHIELD_SPELLS); sCur = id and SpellName(id) end
  shieldBtn:SetAttribute("spell1", sCur)
  if #sKnown > 0 and TotemWatchDB.showShield then shieldBtn:Show() else shieldBtn:Hide() end
  if TotemWatchDB.showAll then castAll:Show() else castAll:Hide() end

  -- Call of the Elements / Totemic Recall: nur wenn gelernt (gibt es evtl. nicht in jeder Spielversion)
  ns.callName = FindKnownSpell(ns.CALL_IDS, ns.CALL_NAMES)
  ns.moveName = FindKnownSpell({}, ns.MOVE_NAMES)
  ns.recallName = FindKnownSpell({}, ns.RECALL_NAMES)
  -- Manakosten jetzt einlesen (außerhalb des Kampfes lesbar), für den Vergleich im Kampf
  for key in pairs(ns.TOTEMS) do
    if IsKnown(key) then ManaCost(TotemName(key)) end
  end
  ManaCost(ns.moveName)
  for _, pair in ipairs({ { callBtn, ns.callName, TotemWatchDB.showCall },
                          { moveBtn, ns.moveName, TotemWatchDB.showMove },
                          { recallBtn, ns.recallName, TotemWatchDB.showRecall } }) do
    local b, spell, wanted = pair[1], pair[2], pair[3]
    b:SetAttribute("spell1", spell)
    if spell and wanted then
      b.icon:SetTexture(SpellIcon(spell) or "Interface\\Icons\\INV_Misc_QuestionMark")
      SetBorder(b, "COVERED", false)
      b:Show()
    else
      b:Hide()
    end
  end

  -- Design anwenden: ordnet alle sichtbaren Knöpfe an und setzt Rahmen/Größen
  ns.ApplySkin()
  -- Notfall-Knopf Tremor einrichten
  ns.SetupTremor()

  RebuildCastAll()
  state.setupDone = true
end
ns.SetupSecure = SetupSecure

-- Außerhalb des Kampfes: Knopf automatisch auf die Empfehlung setzen, wenn diese sich ändert
local function AutoAssign(s, key)
  state.curRec = state.curRec or {}
  state.curRec[s] = key                 -- aktuelle Empfehlung (für die Erkennung "eigene Wahl")
  if InCombatLockdown() or not state.setupDone then return end
  if key == state.lastRec[s] then return end
  state.lastRec[s] = key
  -- Von dir gewählte Knöpfe nicht überschreiben
  local manual = TotemWatchDB.manual and TotemWatchDB.manual[s]
  if manual then
    if manual == key then TotemWatchDB.manual[s] = nil end   -- Empfehlung = deine Wahl: Automatik wieder an
    return
  end
  if TotemWatchDB.auto and key then
    ns.autoAssigning = true
    slots[s]:SetAttribute("spell1", TotemName(key))
    ns.autoAssigning = false
    RebuildCastAll()
  end
end

---------------------------------------------------------------------------
-- Aktualisierung
---------------------------------------------------------------------------
local function PlayAlert()
  if not TotemWatchDB.sound then return end
  local now = GetTime()
  if now - state.lastSound < 6 then return end
  state.lastSound = now
  PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
end

local shieldNames = {}

local function Refresh()
  local now = GetTime()
  local hintLine, alertText = 1, nil
  -- Anzahl Hinweiszeilen je Design (Kompakt/Fokus: 1, Zwei Ebenen/Senkrecht: 0 = nur Tooltip)
  local hintMax = math.min(CurrentSkin().hints or MAX_HINTS, MAX_HINTS)
  local short = TotemWatchDB.shortHints            -- nur eine Zeile: der nächste Schritt (+ Anzahl weiterer)
  if short then hintMax = math.min(hintMax, 1) end
  local hintWanted = 0
  local function hint(text)
    hintWanted = hintWanted + 1
    if hintLine <= hintMax then hints[hintLine]:SetText(text); hintLine = hintLine + 1 end
  end

  -- Totems (jeder Slot einzeln abgesichert; Restzeit zuerst, damit sie immer läuft)
  local function doSlot(s)
    local b = slots[s]
    -- Restzeit zuerst (läuft auch, wenn danach etwas ausfällt)
    local tHave, tName, tStart, tDur = TotemData(s)
    local tLeft = (tHave and tDur and tDur > 0) and (tStart + tDur - now) or 0
    b.timer:SetText(FormatTime(tLeft))
    -- Abstand ebenfalls gleich am Anfang zeigen: fällt später etwas aus (im Kampf gesperrte
    -- Werte), soll die Yards-Anzeige trotzdem erscheinen
    local farEarly = state.far[s]
    local rngEarly = state.range[s]
    if farEarly then
      b.farText:SetText(farEarly.dist .. L["yd"]); b.farText:Show()
    elseif rngEarly and rngEarly.self then
      -- Position gesperrt (z.B. in Dungeons): keine Yards, aber du selbst hast den Buff nicht
      b.farText:SetText(L["far"]); b.farText:Show()
    else
      b.farText:Hide()
    end

    -- Vorwarnung kurz vor dem Ablaufen (nur für längere Totems, einmal pro gestelltem Totem)
    local wb = TotemWatchDB.warnBefore or 0
    if wb > 0 and tLeft > 0 and tLeft <= wb and tDur > 20 then
      local id = s .. ":" .. floor(tStart)
      if not state.preWarned[id] then
        state.preWarned[id] = true
        local shown = (tName and tName ~= "" and tName ~= "?") and (BaseName(tName) or tName) or (ns.SLOT_NAMES[s] .. "totem")
        state.expireMsg = format(L["%s expires in %d s!"], shown, ceil(tLeft))
        state.expireUntil = now + 3
      end
    end
    local key, reason, urgent, otherHint, others = Recommend(s)
    AutoAssign(s, key)

    local assigned = b:GetAttribute("spell1")
    local assignedKey = assigned and KeyFromName(assigned)
    local status, curIcon, remaining, curName, dupWho = SlotStatus(s, key, others)
    b.recKey, b.reason, b.curName, b.others, b.otherHint = key, reason, curName, others, otherHint

    if assigned then
      b.icon:SetTexture(SpellIcon(idByName[assigned] or assigned))
    elseif key then
      b.icon:SetTexture(SpellIcon(ns.TOTEMS[key].id))
    else
      b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    b.icon:SetDesaturated(not assigned)

    local otherKey = next(others)
    if otherKey then b.other:SetTexture(SpellIcon(ns.TOTEMS[otherKey].id)); b.other:Show() else b.other:Hide() end

    if key and key ~= assignedKey then b.rec:SetTexture(SpellIcon(ns.TOTEMS[key].id)); b.rec:Show() else b.rec:Hide() end

    if status ~= "MISSING" and status ~= "OK" and curIcon then b.cur:SetTexture(curIcon); b.cur:Show() else b.cur:Hide() end

    if status == "DUPLICATE" then
      reason = format(L["%s already has %s – %s"], dupWho or "?", curName or "?", reason or "")
    end

    if key then
      SetBorder(b, status, status == "MISSING" or (urgent and status == "WRONG"))
    elseif otherKey then
      SetBorder(b, "COVERED", false)
    else
      SetBorder(b, status == "MISSING" and "NONE" or "OK", false)
    end

    -- Leuchten: Empfohlenes Totem muss gestellt werden
    local needAction = key and (status == "MISSING" or status == "WRONG" or status == "DUPLICATE")
    local glowOn = TotemWatchDB.glow
    -- Knopf selbst leuchtet, wenn ein Klick genau das empfohlene Totem stellt
    SetGlow(b.glow, glowOn and needAction and key == assignedKey)
    -- Meldung in der Bildschirmmitte, sobald im Kampf ein neues Problem an diesem Slot auftaucht
    if needAction and state.inCombat then
      local msgKey = status .. ":" .. key
      if state.slotMsg[s] ~= msgKey then
        state.slotMsg[s] = msgKey
        local what = (status == "MISSING") and L["missing"] or (status == "DUPLICATE") and L["duplicate, better"] or L["better"]
        local c = STATUS_COLOR[status]
        ns.ShowMessage(format("%s: %s – %s", ns.SLOT_NAMES[s], TotemName(key), what), c[1], c[2], c[3])
      end
    elseif not needAction then
      state.slotMsg[s] = nil
    end
    -- Sonst leuchtet das kleine Empfehlungs-Symbol (Rechtsklick -> auswählen)
    SetGlow(b.recGlow, glowOn and key and key ~= assignedKey)
    -- Im Auswahlmenü leuchtet das empfohlene Totem
    if b.flyout and b.flyout.buttons then
      local recId = key and ns.TOTEMS[key].id
      for _, fb in ipairs(b.flyout.buttons) do
        SetGlow(fb.glow, glowOn and recId ~= nil and fb.spellId == recId and fb:IsShown())
      end
    end

    UpdateCooldown(b, assigned)

    local col = ns.SLOT_COLORS[s]
    -- Abstand zum eigenen Totem
    local far = state.far[s]
    local rng = state.range[s]
    if far then
      hint(format(L["|cff%s%s|r |cffffa040Distance:|r you are %d yd from %s (range %d yd)"],
        col, ns.SLOT_NAMES[s], far.dist, far.name, far.range))
    elseif rng and rng.self then
      -- ohne Position (Dungeon): wenigstens klar sagen, dass DU zu weit weg bist
      hint(format(L["|cff%s%s|r |cffffa040Distance:|r you are out of range of %s"], col, ns.SLOT_NAMES[s], rng.name or "?"))
    end
    if rng then
      b.label:SetText("|cffff3030" .. rng.count .. "|r")
      b.rangeInfo = format(L["Out of range: %s"], rng.names)
      hint(format(L["|cff%s%s|r |cffff6060Range:|r %d out of range (%s)"], col, ns.SLOT_NAMES[s], rng.count, rng.names))
    else
      b.label:SetText("")
      b.rangeInfo = far and format(L["You are %d yd away (range %d yd)"], far.dist, far.range) or nil
    end

    -- Zu weit weg: deutlich am Knopf zeigen (oranger, pulsierender Rahmen + große Meterzahl)
    if far then
      b.farText:SetText(far.dist .. L["yd"])
      b.farText:Show()
      SetBorder(b, "FAR", true)
      -- Leuchten, wenn Neustellen die Lösung ist (Totemic Call lohnt sich nicht oder fehlt)
      -- und ein Klick genau dieses Totem neu stellt
      local adv = state.moveAdvice
      local t = tracked[s]
      local redropBetter = not (adv and adv.useCall)
      SetGlow(b.glow, TotemWatchDB.glow and redropBetter and t and t.key == assignedKey)
    elseif rng and rng.self then
      b.farText:SetText(L["far"]); b.farText:Show()
      SetBorder(b, "FAR", true)
    else
      b.farText:Hide()
    end
    if key and status ~= "OK" then
      local what = (status == "MISSING" and L["missing"] or status == "WRONG" and L["better"]
                    or status == "DUPLICATE" and L["duplicate, better"] or L["expiring"])
      local pick = (key ~= assignedKey) and L[" |cffffff00[right-click: choose]|r"] or ""
      if short then
        hint(format(L["|cffffd100Next:|r %s |cff888888(%s)|r – %s"], TotemName(key), ns.SLOT_NAMES[s], reason or ""))
      else
        hint(format("|cff%s%s|r %s: |cffffffff%s|r – %s%s", col, ns.SLOT_NAMES[s], what, TotemName(key), reason or "", pick))
      end
    end
    if otherHint then
      hint(format(L["|cff%s%s|r |cff80c0ff(group)|r %s"], col, ns.SLOT_NAMES[s], otherHint))
    end

    -- Zeitbalken je Design (Pillars: unter dem Knopf, Bars: mit Name und Restzeit)
    local S = CurrentSkin()
    if S.bar then
      local tb = b.timeBar
      tb:SetMinMaxValues(0, (tDur and tDur > 0) and tDur or 1)
      tb:SetValue((tLeft and tLeft > 0) and tLeft or 0)
      local missing = key and status == "MISSING"
      if S.bar == "right" then
        local r, g, bl = HexColor(ns.SLOT_COLORS[s])
        tb:SetStatusBarColor(r * 0.65, g * 0.65, bl * 0.65)
        tb.bg:SetColorTexture(missing and 0.30 or 0.12, missing and 0.08 or 0.12, missing and 0.08 or 0.12, 0.9)
        local text
        if missing then
          text = "|cffff8080" .. TotemName(key) .. " – " .. L["missing"] .. "|r"
        elseif key and (status == "WRONG" or status == "DUPLICATE") then
          text = (BaseName(curName) or "?") .. " > |cffffd100" .. TotemName(key) .. "|r"
        elseif tHave and tName and tName ~= "" and tName ~= "?" then
          text = BaseName(tName) or tName
        else
          text = key and TotemName(key) or "-"
        end
        if far then text = text .. " |cffffa040(" .. far.dist .. L["yd"] .. ")|r" end
        b.barName:SetText(text)
        b.barTime:SetText(FormatTime(tLeft))
      else
        local c = b.statusColor or STATUS_COLOR.NONE
        tb:SetStatusBarColor(c[1], c[2], c[3])
        -- leerer Platz (kein Totem): keinen leeren grauen Balken zeigen
        tb:SetShown(b:IsShown() and (tLeft or 0) > 0)
      end
    end

    if urgent and status ~= "OK" and status ~= "EXPIRING" then
      alertText = TotemName(key) .. L[" now!"]
    end
  end
  for s = 1, 4 do SafeCall("Totem", doSlot, s) end
  -- Fokus-Design: nur Knöpfe mit Handlungsbedarf hell, alles andere fast unsichtbar
  -- (SetAlpha ist auch im Kampf erlaubt; die Knöpfe bleiben klickbar)
  if CurrentSkin().focus then
    local calm = { [STATUS_COLOR.OK] = true, [STATUS_COLOR.NONE] = true, [STATUS_COLOR.COVERED] = true }
    for _, b in ipairs({ slots[1], slots[2], slots[3], slots[4], castAll, callBtn, moveBtn, recallBtn, weaponBtn, shieldBtn }) do
      local need = b.statusColor and not calm[b.statusColor]
      if b.glow and b.glow:IsShown() then need = true end
      b:SetAlpha(need and 1 or 0.18)
    end
  end

  -- Waffenverzauberung
  SafeCall(L["Weapon"], function() if weaponBtn:IsShown() then
    local assigned = weaponBtn:GetAttribute("spell1")
    weaponBtn.icon:SetTexture(assigned and SpellIcon(idByName[assigned] or assigned) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local hasMH, mhExp, _, _, hasOH, ohExp
    if GetWeaponEnchantInfo then hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo() end
    if IsSecret(hasMH) or IsSecret(mhExp) or IsSecret(hasOH) or IsSecret(ohExp) then
      -- im Kampf gesperrt: Zustand unbekannt, nichts falsch anzeigen
      weaponBtn.info = L["Locked by the game in combat – status after combat"]
      SetBorder(weaponBtn, "NONE", false)
      weaponBtn.timer:SetText("")
      UpdateCooldown(weaponBtn, assigned)
      return
    end
    local _, ohClass = ItemEquipInfo(GetInventoryItemLink("player", 17))
    local needOH = (ohClass == 2)
    local left = hasMH and (mhExp or 0) / 1000 or 0
    if needOH then left = math.min(left, hasOH and (ohExp or 0) / 1000 or 0) end
    local missing = (not hasMH) or (needOH and not hasOH)
    weaponBtn.info = missing and L["No enchant active"] or (L["Time left: "] .. FormatTime(left))
    SetBorder(weaponBtn, missing and "MISSING" or (left < 60 and "EXPIRING" or "OK"), missing and state.inCombat)
    weaponBtn.timer:SetText(FormatTime(left))
    weaponBtn.label:SetText("")
    UpdateCooldown(weaponBtn, assigned)
    if missing and assigned then hint(L["|cffffd100Weapon|r missing: |cffffffff"] .. assigned .. "|r") end
  end end)

  -- Schild
  SafeCall(L["Shield"], function() if shieldBtn:IsShown() then
    local assigned = shieldBtn:GetAttribute("spell1")
    shieldBtn.icon:SetTexture(assigned and SpellIcon(idByName[assigned] or assigned) or "Interface\\Icons\\INV_Misc_QuestionMark")
    wipe(shieldNames)
    for _, id in ipairs(ns.SHIELD_SPELLS) do local n = SpellName(id); if n then shieldNames[n] = true end end
    local name, count, expires = FindPlayerBuff(shieldNames)
    local estimated = false
    if name == "SECRET" or IsSecret(count) or IsSecret(expires) then
      -- Auren im Kampf gesperrt
      name, count, expires = nil, nil, nil

      -- 1) Abfrage nach Zauber-ID versuchen (gab bei Forever im Kampf keinen Fehler)
      local found, idUsable = nil, false
      if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for _, id in ipairs(ShieldIdList()) do
          local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
          if ok then
            if a == nil then
              idUsable = true
            elseif not IsSecret(a.name) and not IsSecret(a.expirationTime) then
              idUsable, found = true, a
              break
            end
          end
        end
      end

      if found then
        -- Funktioniert: ab jetzt wissen wir, dass "nichts gefunden" auch "kein Schild" heißt
        ns.shieldIdConfirmed = true
        local apps = found.applications
        name, count, expires = found.name, (not IsSecret(apps)) and apps or nil, found.expirationTime
        ns.shieldLast = { name = name, count = count, expires = expires }
      elseif idUsable and ns.shieldIdConfirmed then
        name = nil   -- verlässliche Abfrage, kein Treffer: Schild ist weg
        ns.shieldLast = nil
      else
        -- 2) Letzten bekannten Stand bzw. eigenes Wirken verwenden
        local last = ns.shieldLast
        if last and last.expires > now then
          name, count, expires, estimated = last.name, nil, last.expires, true
        else
          shieldBtn.info = L["Locked by the game in combat – status after combat"]
          SetBorder(shieldBtn, "NONE", false)
          shieldBtn.label:SetText("")
          shieldBtn.timer:SetText("")
          UpdateCooldown(shieldBtn, assigned)
          return
        end
      end
    else
      ns.shieldLast = name and { name = name, count = count, expires = expires } or nil
    end
    local left = (expires and expires > 0) and (expires - now) or 0
    if estimated then
      shieldBtn.info = format(L["%s: approx. %s (estimated in combat, charges unknown)"], name, FormatTime(left))
      SetBorder(shieldBtn, left < 60 and "EXPIRING" or "OK", false)
      shieldBtn.label:SetText("")
      shieldBtn.timer:SetText(FormatTime(left))
      UpdateCooldown(shieldBtn, assigned)
      return
    end
    if name then
      if count == 1 then
        shieldBtn.info = format(L["%s: 1 charge, %s"], name, FormatTime(left))
      else
        shieldBtn.info = format(L["%s: %d charges, %s"], name, count or 0, FormatTime(left))
      end
      SetBorder(shieldBtn, left > 0 and left < 60 and "EXPIRING" or "OK", false)
      shieldBtn.label:SetText((count and count > 0) and count or "")
    else
      shieldBtn.info = L["No shield active"]
      SetBorder(shieldBtn, "MISSING", state.inCombat)
      shieldBtn.label:SetText("")
      if assigned then hint(L["|cffffd100Shield|r missing: |cffffffff"] .. assigned .. "|r") end
    end
    shieldBtn.timer:SetText(FormatTime(left))
    UpdateCooldown(shieldBtn, assigned)
  end end)

  -- Call of the Elements / Totemic Call / Totemic Recall: Abklingzeit anzeigen
  for _, b in ipairs({ callBtn, moveBtn, recallBtn }) do
    if b:IsShown() then SafeCall("Totem spells", UpdateCooldown, b, b:GetAttribute("spell1")) end
  end
  -- Zu weit weg: Totemic Call oder neu stellen? (Mana-Vergleich, siehe EvaluateTotemicCall)
  -- Keine Textzeile: der schlechtere Knopf wird ausgegraut, der bessere leuchtet.
  local adv = state.moveAdvice
  -- Leiste von Call of the Elements weicht von den TotemWatch-Knöpfen ab (außerhalb des Kampfes)
  if ns.multicastMismatch and callBtn:IsShown() and not InCombatLockdown() then
    for _, m in ipairs(ns.multicastMismatch) do
      hint(format(L["|cffffd100Call of the Elements bar:|r %s instead of %s – change it on the totem bar"],
        m.have and TotemName(m.have) or L["empty"], TotemName(m.want)))
    end
  end
  if callBtn:IsShown() then
    SetBorder(callBtn, ns.multicastMismatch and "WRONG" or "COVERED", false)
  end

  -- Totemic Call / Totemic Recall: lohnt sich Call -> Call leuchtet, Recall grau;
  -- lohnt sich Neustellen -> Call grau, Recall normal. Ohne Abstand: beide normal.
  local callWorth = adv and adv.useCall
  local callGrey  = adv and not adv.useCall
  local recallGrey = adv and adv.useCall
  local function Dim(b, grey)
    b.icon:SetDesaturated(grey and true or false)
    b.icon:SetAlpha(grey and 0.45 or 1)
  end
  if moveBtn:IsShown() then
    Dim(moveBtn, callGrey)
    SetBorder(moveBtn, callWorth and "OK" or (callGrey and "NONE" or "COVERED"), false)
    SetGlow(moveBtn.glow, TotemWatchDB.glow and callWorth)
  end
  if recallBtn:IsShown() then
    Dim(recallBtn, recallGrey)
    SetBorder(recallBtn, recallGrey and "NONE" or "COVERED", false)
  end

  if TotemWatchDB.useBoss and state.boss and state.boss.note then hint(L["|cffaaaaaaNote: "] .. state.boss.note .. "|r") end
  -- Kurze Hinweise: anzeigen, wie viele weitere es gibt (Rest steht im Tooltip der Knöpfe)
  if short and hintLine > 1 and hintWanted > hintLine - 1 then
    local last = hints[hintLine - 1]
    last:SetText((last:GetText() or "") .. " |cff888888(+" .. (hintWanted - (hintLine - 1)) .. ")|r")
  end
  if not TotemWatchDB.showHints then hintLine = 1 end
  for i = hintLine, MAX_HINTS do hints[i]:SetText("") end
  -- Hintergrund an die Zeilenzahl anpassen (unsichtbar ohne Hinweise)
  local shownLines = hintLine - 1
  -- Höhe aus der echten Texthöhe (umgebrochene Hinweise brauchen mehr Platz)
  local h = 10
  for i = 1, shownLines do h = h + math.max(hints[i]:GetStringHeight() or 0, hintLineHeight - 4) + 2 end
  hintBg:SetHeight(math.max(h, hintLineHeight + 8))
  hintBg:SetAlpha(shownLines > 0 and 1 or 0)

  if not alertText and state.destroyMsg and now < state.destroyUntil then
    alertText = state.destroyMsg
    alert:SetTextColor(1, 0.55, 0.1)
  elseif not alertText and state.expireMsg and now < state.expireUntil then
    alertText = state.expireMsg
    alert:SetTextColor(1, 0.85, 0.1)
  else
    alert:SetTextColor(1, 0.2, 0.2)
  end
  if alertText then
    if alert:GetText() ~= alertText then
      PlayAlert()
      local r, g, b = alert:GetTextColor()
      ns.ShowMessage(alertText, r, g, b)   -- zusätzlich groß in der Bildschirmmitte
      ns.Speak(alertText)                  -- und auf Wunsch vorgelesen
    end
    alert:SetText(alertText)
  else
    alert:SetText("")
  end

  if state.fearAt and now - state.fearAt > 5 then state.fearAt = nil end
  if ns.CleanPost then ns.CleanPost() end   -- Clean Look: ruhigere Darstellung nachziehen
  if ns.RoundPost then ns.RoundPost() end     -- runde Symbole: Streifen angleichen, Ring einfärben
end

---------------------------------------------------------------------------
-- Sichtbarkeit (im Kampf über sicheren Statustreiber)
---------------------------------------------------------------------------
-- Bist du gerade in einem Dungeon/Raid, in dem die Leiste immer sichtbar sein soll?
local function AlwaysShowHere()
  if not IsInInstance then return false end
  local inInstance, kind = IsInInstance()
  if not inInstance then return false end
  return (kind == "party" and TotemWatchDB.showInDungeon) or (kind == "raid" and TotemWatchDB.showInRaid) or false
end
ns.AlwaysShowHere = AlwaysShowHere

local function ApplyVisibilityDriver()
  if InCombatLockdown() then state.pendingSecure = true; return end
  local always = state.test or TotemWatchDB.showOOC or AlwaysShowHere()
  RegisterStateDriver(frame, "visibility", always and "show" or "[combat] show; hide")
  -- Notfall-Knöpfe: gleiche Sichtbarkeit wie die Leiste (beim Verschieben immer sichtbar)
  for _, e in ipairs(ns.emergency or {}) do
    if e.enabled then
      RegisterStateDriver(e.btn, "visibility", (always or ns.emergencyMoving) and "show" or "[combat] show; hide")
    else
      RegisterStateDriver(e.btn, "visibility", "hide")
    end
  end
end

local function UpdateVisibility()
  if InCombatLockdown() or state.test or TotemWatchDB.showOOC or AlwaysShowHere() then return end
  if GetTime() < state.pullUntil then
    if not frame:IsShown() then frame:Show() end
  elseif frame:IsShown() then
    frame:Hide()
  end
end

local function ShowForPull(seconds)
  state.pullUntil = GetTime() + (tonumber(seconds) or 10) + 2
  if not InCombatLockdown() then frame:Show() end
  if ns.RunPrePullCheck then SafeCall(L["Pull check"], ns.RunPrePullCheck, L["pull timer"], seconds) end
end

---------------------------------------------------------------------------
-- Check vor dem Pull: außerhalb des Kampfes ist alles lesbar -> hier gründlich prüfen
---------------------------------------------------------------------------
local check = CreateFrame("Frame", "TotemWatchCheck", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
check:SetSize(340, 40)
check:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
check:SetClampedToScreen(true)
check:SetFrameStrata("MEDIUM")
check:Hide()
if check.SetBackdrop then
  check:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  check:SetBackdropColor(0, 0, 0, 0.75)
  check:SetBackdropBorderColor(1, 0.82, 0, 0.9)
end
check.title = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
check.title:SetPoint("TOPLEFT", 8, -7)
check.lines = {}
for i = 1, 14 do
  local fs = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 8, -24 - (i - 1) * 14)
  fs:SetWidth(324); fs:SetJustifyH("LEFT")
  check.lines[i] = fs
end

local ICON_OK  = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local ICON_BAD = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t "

local function GuessBossFromTarget()
  if state.boss or not UnitExists("target") then return end
  local tn = UnitName("target")
  if not tn or IsSecret(tn) then return end
  tn = lower(tn)
  for _, b in pairs(ns.BOSSES) do
    if b.name and lower(b.name) == tn then
      state.boss, state.bossName = b, b.name
      return
    end
  end
end

local function BuildCheck()
  local now = GetTime()
  SafeCall(L["group"], ScanGroup); pcall(ScanRange)
  GuessBossFromTarget()
  local lines, problems = {}, 0
  local function add(ok, text)
    lines[#lines + 1] = (ok and ICON_OK or ICON_BAD) .. text
    if not ok then problems = problems + 1 end
  end
  if state.boss then lines[#lines + 1] = "|cffffd100Boss: " .. (state.bossName or state.boss.name or "?") .. "|r" end

  -- Totems
  for s = 1, 4 do
    local key, _, _, _, others = Recommend(s)
    local status, _, remaining, curName = SlotStatus(s, key, others)
    if key then
      local nm = format("|cff%s%s|r: %s", ns.SLOT_COLORS[s], ns.SLOT_NAMES[s], TotemName(key))
      if status == "MISSING" then
        add(false, nm .. L[" – drop it"])
      elseif status == "WRONG" or status == "DUPLICATE" then
        add(false, nm .. L[" instead of "] .. (BaseName(curName) or "?"))
      elseif remaining < 60 then
        add(false, format(L["%s expires in %s – recast shortly before the pull"], nm, FormatTime(remaining)))
      else
        add(true, format("%s (%s)", nm, FormatTime(remaining)))
      end
    end
    local rng = state.range[s]
    if rng then add(false, format(L["%s: %d out of range (%s)"], ns.SLOT_NAMES[s], rng.count, rng.names)) end
  end

  -- Schild
  if FirstKnown(ns.SHIELD_SPELLS) then
    local names = {}
    for _, id in ipairs(ns.SHIELD_SPELLS) do local n = SpellName(id); if n then names[n] = true end end
    local n, c, e = FindPlayerBuff(names)
    if not n or n == "SECRET" then
      add(false, L["Shield missing – cast it"])
    else
      local left = (e and e > 0) and (e - now) or 0
      if left > 0 and left < 180 then
        add(false, format(L["%s expires in %s – refresh it"], n, FormatTime(left)))
      elseif c and c > 0 and c < 3 then
        add(false, (c == 1) and format(L["%s: only 1 charge – refresh it"], n) or format(L["%s: only %d charges – refresh it"], n, c))
      else
        add(true, format(L["%s: %s charges%s"], n, c or "?", left > 0 and (", " .. FormatTime(left)) or ""))
      end
    end
  end

  -- Waffe
  if FirstKnown(ns.WEAPON_SPELLS) and GetWeaponEnchantInfo then
    local hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo()
    if not IsSecret(hasMH) and not IsSecret(mhExp) then
      local _, ohClass = ItemEquipInfo(GetInventoryItemLink("player", 17))
      if not hasMH or (ohClass == 2 and not hasOH) then
        add(false, L["Weapon enchant missing"])
      else
        local left = (mhExp or 0) / 1000
        if ohClass == 2 then left = math.min(left, (ohExp or 0) / 1000) end
        if left < 180 then
          add(false, format(L["Weapon enchant expires in %s"], FormatTime(left)))
        else
          add(true, L["Weapon enchant ("] .. FormatTime(left) .. ")")
        end
      end
    end
  end

  if #lines == 0 then add(true, L["All set"]) end
  for i, fs in ipairs(check.lines) do fs:SetText(lines[i] or "") end
  check:SetHeight(30 + math.min(#lines, #check.lines) * 14)
  return problems
end

function ns.RunPrePullCheck(reason, seconds)
  if InCombatLockdown() or not TotemWatchDB.prePull then return end
  local problems = BuildCheck()
  check.title:SetText(format(L["Pull check |cffaaaaaa(%s)|r"], reason or L["manual"]))
  check.untilT = GetTime() + (tonumber(seconds) or 15) + 2
  check:Show()
  if problems > 0 then PlayAlert() end
end

local checkAcc = 0
check:SetScript("OnUpdate", function(self, elapsed)
  checkAcc = checkAcc + elapsed
  if checkAcc < 1 then return end
  checkAcc = 0
  if InCombatLockdown() or GetTime() > (self.untilT or 0) then self:Hide(); return end
  SafeCall(L["Pull check"], BuildCheck)   -- jede Sekunde neu, damit Behobenes sofort grün wird
end)

local elapsedAcc, slowAcc = 0, 0
frame:SetScript("OnUpdate", function(_, elapsed)
  elapsedAcc = elapsedAcc + elapsed
  slowAcc = slowAcc + elapsed
  if slowAcc > 1 then
    slowAcc = 0
    pcall(ScanEnemies)
    ScanGroup()
    pcall(ScanRange)   -- pcall: falls der Client Aura-Daten im Kampf sperrt
    if not ns.combatLogAllowed then pcall(ScanOtherBuffs) end
    -- Leiste von Call of the Elements regelmäßig prüfen (du kannst sie auch selbst umstellen)
    if not InCombatLockdown() and ns.SyncMultiCast then pcall(ns.SyncMultiCast) end
    UpdateVisibility()
  end
  if elapsedAcc > 0.2 then
    elapsedAcc = 0
    SafeCall(L["Display"], Refresh)
  end
end)

---------------------------------------------------------------------------
-- Boss-Erkennung (Blizzard / DBM / BigWigs)
---------------------------------------------------------------------------
local function SetBoss(encounterID, name)
  local data = encounterID and ns.BOSSES[tonumber(encounterID)]
  state.boss = data
  state.bossName = (data and data.name) or name
  if data then
    print(format(L["|cff0070deTotemWatch|r: boss detected – %s"], state.bossName or "?"))
  end
end

local function ClearBoss()
  state.boss, state.bossName, state.fearAt = nil, nil, nil
end

local function OnTimer(text, duration, spellId)
  duration = tonumber(duration)
  if not duration then return end
  local isFear = (spellId and ns.FEAR_SPELLS[tonumber(spellId) or 0]) or IsFearText(text)
  if isFear and duration > 0 and duration < 120 then
    state.fearAt = GetTime() + duration
  end
  -- Gift / Krankheit / gefährliche Zauber für die Notfall-Knöpfe
  if type(text) == "string" and duration > 0 and duration < 120 and ns.MarkDanger then
    ns.MarkDanger(text, GetTime() + duration)
  end
  if ns.RevealEmergency then ns.RevealEmergency() end
  if type(text) == "string" and lower(text):find("pull", 1, true) then
    ShowForPull(duration)
  end
end

local dbmHooked, bwHooked = false, false
local function HookBossMods()
  if not dbmHooked and DBM and DBM.RegisterCallback then
    dbmHooked = true
    DBM:RegisterCallback("DBM_Pull", function(_, mod)
      if not mod then return end
      local eid = mod.encounterId or (mod.multiEncounterPullDetection and mod.multiEncounterPullDetection[1])
      local name = mod.localization and mod.localization.general and mod.localization.general.name
      SetBoss(eid, name or mod.id)
    end)
    DBM:RegisterCallback("DBM_Kill", ClearBoss)
    DBM:RegisterCallback("DBM_Wipe", ClearBoss)
    -- Neuere DBM-Versionen melden Timer als "DBM_TimerBegin", ältere als "DBM_TimerStart".
    -- Beide anmelden; feuern beide, wird derselbe Timer nur einmal ausgewertet.
    local lastId, lastAt = nil, 0
    local function OnDBMTimer(_, id, msg, timer, icon, timerType, spellId)
      local now = GetTime()
      if id ~= nil and id == lastId and now - lastAt < 0.5 then return end
      lastId, lastAt = id, now
      if ns.debugTimers then
        print("|cff0070deTotemWatch|r DBM timer:", tostring(msg), tostring(timer), tostring(timerType), tostring(spellId))
      end
      if timerType == "pull" or (type(id) == "string" and id:lower():find("pull", 1, true)) then
        ShowForPull(timer)
        return
      end
      OnTimer(msg, timer, spellId)
    end
    pcall(DBM.RegisterCallback, DBM, "DBM_TimerStart", OnDBMTimer)
    pcall(DBM.RegisterCallback, DBM, "DBM_TimerBegin", OnDBMTimer)
  end
  if not bwHooked and BigWigsLoader and BigWigsLoader.RegisterMessage then
    bwHooked = true
    local owner = {}
    BigWigsLoader.RegisterMessage(owner, "BigWigs_OnBossEngage", function(_, module)
      if not module then return end
      SetBoss(module.engageId, module.displayName or module.moduleName)
    end)
    BigWigsLoader.RegisterMessage(owner, "BigWigs_OnBossWin", ClearBoss)
    BigWigsLoader.RegisterMessage(owner, "BigWigs_OnBossWipe", ClearBoss)
    BigWigsLoader.RegisterMessage(owner, "BigWigs_StartBar", function(_, module, key, text, time)
      if ns.debugTimers then
        print("|cff0070deTotemWatch|r BigWigs bar:", tostring(text), tostring(time), tostring(key))
      end
      OnTimer(text, time, type(key) == "number" and key or nil)
    end)
    BigWigsLoader.RegisterMessage(owner, "BigWigs_StartPull", function(_, _, seconds)
      ShowForPull(seconds)
    end)
  end
end

---------------------------------------------------------------------------
-- Ereignisse
---------------------------------------------------------------------------
local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
local AFFILIATION_MINE = bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE or 0x1, COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x2)

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_TOTEM_UPDATE")
if ev.RegisterUnitEvent then
  ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
  ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("UNIT_SPELLCAST_START")
ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
ev:RegisterEvent("READY_CHECK")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")   -- Instanz betreten/verlassen -> Sichtbarkeit neu setzen
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")

-- Feindliche Zauber (Namensplaketten, Ziel, Boss): Furcht erkennen, ohne Kampflog
local ENEMY_UNIT = { target = true, focus = true }
function ns.OnEnemyCast(unit, spellID, channel)
  if not TotemWatchDB.enemyCasts then return end
  if not (ENEMY_UNIT[unit] or unit:find("^nameplate") or unit:find("^boss")) then return end
  if not UnitCanAttack("player", unit) then return end
  local name, endMS
  if spellID and not IsSecret(spellID) then name = SpellName(spellID) end
  local ok, cName, _, _, _, cEnd = pcall(channel and UnitChannelInfo or UnitCastingInfo, unit)
  if ok then
    if not name and cName and not IsSecret(cName) then name = cName end
    if cEnd and not IsSecret(cEnd) then endMS = cEnd end
  end
  ns.enemyCastSeen = true
  ns.enemyCastReadable = (name ~= nil)
  if not name then return end
  ns.lastEnemyCast = name
  if (spellID and not IsSecret(spellID) and ns.FEAR_SPELLS[spellID]) or IsFearText(name) then
    local at = endMS and (endMS / 1000) or (GetTime() + 2)
    if not state.fearAt or at < state.fearAt or state.fearAt < GetTime() then state.fearAt = at end
  end
  -- Gift / Krankheit / gefährliche Einzelzauber -> Notfall-Knöpfe
  if ns.MarkDanger then ns.MarkDanger(name, endMS and (endMS / 1000) or (GetTime() + 2)) end
end
-- Auf Clients mit Kampf-Einschränkungen (wie Midnight) ist das Kampflog für Addons gesperrt;
-- schon die Anmeldung löst "nur für Blizzard-UI verfügbar" aus. Dann ohne Kampflog arbeiten.
local tocVersion = select(4, GetBuildInfo()) or 0
ns.combatLogAllowed = (issecretvalue == nil) and (C_Secrets == nil) and tocVersion < 120000 and tocVersion ~= 16001
-- (Anmeldung erst in ADDON_LOADED, damit /tw kampflog wirken kann)
pcall(ev.RegisterEvent, ev, "ENCOUNTER_START")
pcall(ev.RegisterEvent, ev, "ENCOUNTER_END")

local isGroupUnit = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }

local function ApplyPosition()
  if InCombatLockdown() then state.pendingSecure = true; return end
  frame:ClearAllPoints()
  frame:SetPoint(TotemWatchDB.point, UIParent, TotemWatchDB.point, TotemWatchDB.x, TotemWatchDB.y)
  frame:SetScale(TotemWatchDB.scale)
end

-- für Options.lua
ns.frame = frame
ns.ApplyPosition = ApplyPosition
ns.ApplyVisibilityDriver = ApplyVisibilityDriver
ns.UpdateVisibility = UpdateVisibility
ns.Refresh = Refresh
ns.ToggleTest = function()
  if InCombatLockdown() then return end
  state.test = not state.test
  ApplyVisibilityDriver(); ScanGroup(); Refresh()
end
ns.ResetPosition = function()
  TotemWatchDB.point, TotemWatchDB.x, TotemWatchDB.y, TotemWatchDB.scale = "CENTER", 0, -180, 1
  ApplyPosition()
  -- Meldungen zurück in die Bildschirmmitte
  TotemWatchDB.msgPoint, TotemWatchDB.msgX, TotemWatchDB.msgY = nil, nil, nil
  if ns.ApplyMessagePosition then ns.ApplyMessagePosition() end
  -- Notfall-Knopf wieder an die Leiste andocken
  if ns.AttachTremor then ns.AttachTremor() end
end

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == ADDON then
      TotemWatchDB = TotemWatchDB or {}
      for k, v in pairs(DEFAULTS) do if TotemWatchDB[k] == nil then TotemWatchDB[k] = v end end
      TotemWatchDB.choice = TotemWatchDB.choice or {}
      TotemWatchDB.manual = TotemWatchDB.manual or {}   -- [slot] = von dir festgelegtes Totem
      -- Einmalig: alter Standard 0.35 auf den neuen, durchsichtigeren Standard setzen
      if TotemWatchDB.tremorDim == 0.35 and not TotemWatchDB.tremorDimSet then TotemWatchDB.tremorDim = 0.15 end
      TotemWatchDB.tremorDimSet = true
      -- Einmalig: Notfall-Knöpfe kleiner (etwa Totem-Größe) statt des alten Standards 64
      if TotemWatchDB.tremorSize == 64 and not TotemWatchDB.tremorSizeSet then TotemWatchDB.tremorSize = 44 end
      TotemWatchDB.tremorSizeSet = true
      -- Einmalig: "in Dungeons/Raids immer anzeigen" einschalten (Testversion hatte "aus" gespeichert)
      if not TotemWatchDB.instanceDefaultsSet then
        TotemWatchDB.showInDungeon, TotemWatchDB.showInRaid = true, true
        TotemWatchDB.instanceDefaultsSet = true
      end
      if TotemWatchDB.forceCombatLog then ns.combatLogAllowed = true end
      if ns.combatLogAllowed then ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
    end
    HookBossMods()
  elseif event == "PLAYER_LOGIN" then
    -- jeder Schritt einzeln abgesichert: ein Fehler darf den Rest nicht verhindern
    SafeCall(L["Spellbook"], ScanSpellbook)
    SafeCall(L["Names"], BuildNameLookup)
    SafeCall(L["group"], ScanGroup)
    SafeCall("Bossmods", HookBossMods)
    SafeCall("Position", ApplyPosition)
    -- Abstand zu den Totems: eigener Takt, unabhängig davon, ob die Leiste sichtbar ist
    if not ns.distanceTicker and C_Timer and C_Timer.NewTicker then
      ns.distanceTicker = C_Timer.NewTicker(0.5, function() SafeCall("Distance", ScanDistance) end)
    end
    SafeCall("Fonts", ns.ApplyHintFont)       -- gespeicherte Schriftgrößen anwenden
    SafeCall("Fonts", ns.ApplyMessageFont)
    SafeCall("Messages", ns.ApplyMessagePosition)   -- gespeicherte Position der Meldungen
    if ns.UpdateMinimapButton then SafeCall("Minimap", ns.UpdateMinimapButton) end
    -- Beim allerersten Mal die Einführung zeigen (kurz nach dem Einloggen)
    if not TotemWatchDB.tutorialDone and ns.StartTutorial and C_Timer then
      C_Timer.After(4, function()
        if not InCombatLockdown() then SafeCall("Tutorial", ns.StartTutorial) end
      end)
    end
    SafeCall(L["Visibility"], ApplyVisibilityDriver)
    SafeCall(L["Buttons"], SetupSecure)
    SafeCall("Masque", ns.SetupMasque)
    for s = 1, 4 do SafeCall("Totems", CheckDestroyed, s) end
    if ns.CreateOptions then SafeCall(L["Options"], ns.CreateOptions) end
    print(L["|cff0070deTotemWatch|r loaded – /tw for options, /tw debug if something is wrong."])
  elseif event == "SPELLS_CHANGED" then
    ScanSpellbook(); BuildNameLookup()
    if state.setupDone then SetupSecure() end
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    if state.setupDone and not InCombatLockdown() and not TotemWatchDB.choice.weapon then SetupSecure() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    state.inCombat = true
    -- Dieses Ereignis kommt kurz VOR der Kampfsperre: Anzeigen ist hier noch erlaubt.
    if not InCombatLockdown() and not frame:IsShown() then frame:Show() end
    SafeCall(L["group"], ScanGroup); pcall(ScanDebuffs); SafeCall(L["Display"], Refresh)
  elseif event == "PLAYER_REGEN_ENABLED" then
    state.inCombat = false
    state.aurasBlocked = false   -- nach dem Kampf dürfen Auren wieder gelesen werden
    state.fearUntil, state.poison, state.disease = 0, 0, 0
    if not IsEncounterInProgress or not IsEncounterInProgress() then ClearBoss() end
    wipe(state.lastRec)   -- Empfehlungen neu auf die Knöpfe legen
    wipe(state.slotMsg)   -- im nächsten Kampf wieder melden
    if state.pendingSecure then ApplyPosition(); SetupSecure(); ApplyVisibilityDriver() end
    UpdateVisibility()
  elseif event == "GROUP_ROSTER_UPDATE" then
    ScanGroup()
  elseif event == "UNIT_AURA" then
    local unit = ...
    if isGroupUnit[unit] and state.inCombat then pcall(ScanDebuffs) end
  elseif event == "PLAYER_TOTEM_UPDATE" then
    local slot = ...
    if slot and not IsSecret(slot) and slot >= 1 and slot <= 4 then
      -- Wenn GetTotemInfo gesperrt ist: ein Update ohne frisch gewirktes Totem heißt "Totem weg"
      local _, _, _, _, _, fromTracked, exact = TotemData(slot)
      local t = tracked[slot]
      -- nur ohne exakte Restzeit raten: Update ohne frisch gewirktes Totem = Totem weg
      if fromTracked and not exact and t and GetTime() - t.start > 1 then tracked[slot] = nil end
      SafeCall("Totems", CheckDestroyed, slot)
    end
    if frame:IsShown() then SafeCall(L["Display"], Refresh) end
  elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
    local unit, _, spellID = ...
    if type(unit) == "string" and unit ~= "player" then
      pcall(ns.OnEnemyCast, unit, spellID, event == "UNIT_SPELLCAST_CHANNEL_START")
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- in Dungeons/Raids ggf. immer anzeigen (im Kampf wird es nach dem Kampf nachgeholt)
    if TotemWatchDB then
      SafeCall(L["Visibility"], ApplyVisibilityDriver)
      SafeCall(L["Visibility"], UpdateVisibility)
    end
  elseif event == "READY_CHECK" then
    if ns.RunPrePullCheck then SafeCall(L["Pull check"], ns.RunPrePullCheck, L["ready check"], 20) end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" then
      ns.lastCastSecret = IsSecret(spellID)
      ns.lastCastSeen = true
      pcall(TrackCast, spellID)
    end
  elseif event == "ENCOUNTER_START" then
    local encounterID, encounterName = ...
    SetBoss(encounterID, encounterName)
  elseif event == "ENCOUNTER_END" then
    ClearBoss()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- pcall: neuere Clients können Kampflog-Werte in Bosskämpfen sperren
    pcall(ns.HandleCombatLog)
  end
end)

function ns.HandleCombatLog()
  do
    local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, dstFlags, _, spellId, spellName = CombatLogGetCurrentEventInfo()

    if sub == "SPELL_SUMMON" then
      if srcGUID and state.partyShamans[srcGUID] then
        local key = KeyFromName(spellName) or KeyFromName(dstName)
        if key and dstGUID then AddOtherTotem(dstGUID, srcGUID, state.partyShamans[srcGUID] or srcName, key) end
      end
      return
    elseif (sub == "UNIT_DIED" or sub == "UNIT_DESTROYED") and dstGUID and state.others[dstGUID] then
      state.others[dstGUID] = nil
      return
    end

    if not state.inCombat then return end
    if sub == "SPELL_CAST_START" and band(srcFlags or 0, HOSTILE) > 0 then
      if ns.FEAR_SPELLS[spellId] or IsFearText(spellName) then
        state.fearAt = GetTime() + 2
      end
    elseif sub == "SPELL_AURA_APPLIED" and band(srcFlags or 0, HOSTILE) > 0
           and band(dstFlags or 0, AFFILIATION_MINE) > 0 then
      if ns.FEAR_SPELLS[spellId] or IsFearText(spellName) then
        state.fearUntil = GetTime() + 12
      end
    end
  end
end

---------------------------------------------------------------------------
-- Tastenbelegung (Bindings.xml)
---------------------------------------------------------------------------
BINDING_HEADER_TOTEMWATCH = "TotemWatch"
_G["BINDING_NAME_CLICK TotemWatchCastAll:LeftButton"] = L["Cast all totems (press repeatedly)"]
_G["BINDING_NAME_CLICK TotemWatchFire:LeftButton"]    = L["Cast fire totem"]
_G["BINDING_NAME_CLICK TotemWatchEarth:LeftButton"]   = L["Cast earth totem"]
_G["BINDING_NAME_CLICK TotemWatchWater:LeftButton"]   = L["Cast water totem"]
_G["BINDING_NAME_CLICK TotemWatchAir:LeftButton"]     = L["Cast air totem"]
_G["BINDING_NAME_CLICK TotemWatchWeapon:LeftButton"]  = L["Cast weapon enchant"]
_G["BINDING_NAME_CLICK TotemWatchShield:LeftButton"]  = L["Cast shield"]
_G["BINDING_NAME_CLICK TotemWatchCall:LeftButton"]    = L["Call of the Elements (all totems)"]
_G["BINDING_NAME_CLICK TotemWatchMove:LeftButton"]    = L["Totemic Call (move totems to you)"]
_G["BINDING_NAME_CLICK TotemWatchRecall:LeftButton"]  = L["Totemic Recall (remove totems)"]
_G["BINDING_NAME_CLICK TotemWatchTremor:LeftButton"]  = L["Emergency Tremor (Tremor Totem)"]
_G["BINDING_NAME_CLICK TotemWatchPoison:LeftButton"]    = L["Emergency Poison Cleansing"]
_G["BINDING_NAME_CLICK TotemWatchDisease:LeftButton"]   = L["Emergency Disease Cleansing"]
_G["BINDING_NAME_CLICK TotemWatchGrounding:LeftButton"] = L["Emergency Grounding"]

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_TOTEMWATCH1, SLASH_TOTEMWATCH2 = "/tw", "/totemwatch"
SlashCmdList.TOTEMWATCH = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  local p = function(t) print("|cff0070deTotemWatch|r: " .. t) end
  local needsOOC = { test = true, ooc = true, scale = true, reset = true }
  if needsOOC[cmd] and InCombatLockdown() then p(L["Not possible in combat."]) return end

  if cmd == "test" then
    ns.ToggleTest()
    p(L["Test mode "] .. (state.test and L["on"] or L["off"]))
  elseif cmd == "lock" then
    TotemWatchDB.locked = true; p(L["Locked"])
  elseif cmd == "unlock" then
    TotemWatchDB.locked = false; p(L["Unlocked (drag the title bar)"])
  elseif cmd == "scale" and tonumber(arg) then
    TotemWatchDB.scale = math.max(0.5, math.min(2.5, tonumber(arg)))
    frame:SetScale(TotemWatchDB.scale); p(L["Scale "] .. TotemWatchDB.scale)
  elseif cmd == "sound" then
    TotemWatchDB.sound = not TotemWatchDB.sound; p("Sound " .. (TotemWatchDB.sound and L["on"] or L["off"]))
  elseif cmd == "auto" then
    TotemWatchDB.auto = not TotemWatchDB.auto; wipe(state.lastRec)
    wipe(TotemWatchDB.manual)   -- eigene Festlegungen aufheben
    p(L["Auto-assign recommended totems to buttons: "] .. (TotemWatchDB.auto and L["on"] or L["off"]))
  elseif cmd == "ooc" then
    TotemWatchDB.showOOC = not TotemWatchDB.showOOC; ApplyVisibilityDriver(); UpdateVisibility()
    p(L["Show out of combat: "] .. (TotemWatchDB.showOOC and L["on"] or L["off"]))
  elseif cmd == "reset" then
    TotemWatchDB.point, TotemWatchDB.x, TotemWatchDB.y, TotemWatchDB.scale = "CENTER", 0, -180, 1
    ApplyPosition(); p(L["Position reset"])
  elseif cmd == "other" or cmd == "fremd" then
    local key = arg ~= "" and arg:upper() or nil
    if key and ns.TOTEMS[key] then
      AddOtherTotem("TEST-" .. key, "TEST", L["Test shaman"], key)
      p(L["Simulated: test shaman has "] .. TotemName(key))
    else
      for g, t in pairs(state.others) do if t.src == "TEST" then state.others[g] = nil end end
      local list = {}
      for k in pairs(ns.TOTEMS) do list[#list + 1] = k:lower() end
      table.sort(list)
      p(L["Simulated totems removed. Possible values: "] .. table.concat(list, ", "))
    end
  elseif cmd == "boss" then
    local id = tonumber(arg)
    if id then SetBoss(id) else ClearBoss() end
    p("Boss: " .. (state.bossName or L["none"]))
  elseif cmd == "debug" then
    local known = {}
    for key in pairs(ns.TOTEMS) do if IsKnown(key) then known[#known + 1] = TotemName(key) end end
    p(L["Diagnostics:"])
    print("  Client-Interface: " .. tostring(select(4, GetBuildInfo())))
    print(L["  Combat log active: "] .. (ns.combatLogAllowed and L["yes"] or L["no"]))
    print(L["  Buttons set up: "] .. (state.setupDone and L["yes"] or L["NO"]))
    print(L["  Window visible: "] .. (frame:IsShown() and L["yes"] or L["no"]) ..
          L[", in combat: "] .. (InCombatLockdown() and L["yes"] or L["no"]))
    print(format(L["  Known totems (%d): %s"], #known, table.concat(known, ", ")))
    print("  DBM: " .. (DBM and L["yes"] or L["no"]) .. ", BigWigs: " .. (BigWigsLoader and L["yes"] or L["no"]))
    for s = 1, 4 do
      local have, n, st, du, _, fromTracked = TotemData(s)
      local left = (du and du > 0) and floor(st + du - GetTime()) or 0
      print(format(L["  Slot %d (%s): active=%s, left=%ds, source=%s, assigned=%s"], s, ns.SLOT_NAMES[s],
        (have and n and n ~= "") and n or "-", left, fromTracked and L["own tracking"] or L["game"],
        tostring(slots[s]:GetAttribute("spell1"))))
    end
    -- Abstand zu den Totems
    print(L["  Distance check: "] .. (not TotemWatchDB.distanceWarn and L["off"]
      or (ns.distanceTicker and (ns.posReadable and L["running, position readable"] or L["running, position NOT readable here"]))
      or L["not started"]))
    for s = 1, 4 do
      if ns.distInfo[s] then print(format("    %s: %s", ns.SLOT_NAMES[s], ns.distInfo[s])) end
    end
    if ns.lastErrors then
      for label, err in pairs(ns.lastErrors) do print(L["  |cffff4040Error "] .. label .. ":|r " .. err) end
    else
      print(L["  No errors so far."])
    end
  elseif cmd == "tutorial" or cmd == "tour" or cmd == "einführung" then
    if ns.StartTutorial then ns.StartTutorial() end
  elseif cmd == "minimap" then
    TotemWatchDB.showMinimap = not TotemWatchDB.showMinimap
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    p(L["Minimap button: "] .. (TotemWatchDB.showMinimap and L["on"] or L["off"]))
  elseif cmd == "tremor" or cmd == "sos" or cmd == "emergency" then
    if InCombatLockdown() then p(L["Not possible in combat."]) return end
    if arg == "attach" then
      ns.AttachEmergency()
      p(L["Emergency buttons attached to the bar."])
    elseif arg == "move" then
      local on = ns.ToggleEmergencyMove()
      p(on and L["Emergency buttons unlocked – drag them, right-click to lock."] or L["Emergency buttons locked."])
    elseif arg == "test" then
      -- Fear/Gift/Krankheit/Grounding simulieren, damit man das Aufleuchten sieht
      ns.TestEmergency()
      p(L["Simulating emergencies in 5 seconds."])
    else
      TotemWatchDB.tremorButton = not TotemWatchDB.tremorButton
      ns.SetupTremor()
      p(L["Emergency Tremor button: "] .. (TotemWatchDB.tremorButton and L["on"] or L["off"]))
    end
  elseif cmd == "soundtest" or cmd == "testsound" then
    ns.TestWarnings()
  elseif cmd == "round" or cmd == "roundtest" then
    if InCombatLockdown() then p(L["Not possible in combat."]) return end
    if arg == "off" then TotemWatchDB.roundIcons = false
    elseif arg == "on" then TotemWatchDB.roundIcons = true
    else TotemWatchDB.roundIcons = not TotemWatchDB.roundIcons end
    ns.ApplySkin(); SafeCall("Display", Refresh)
    p(L["Round icons: "] .. (TotemWatchDB.roundIcons and L["on"] or L["off"]))
  elseif cmd == "clean" then
    if InCombatLockdown() then p(L["Not possible in combat."]) return end
    TotemWatchDB.cleanLook = not TotemWatchDB.cleanLook
    ns.ApplySkin(); SafeCall("Display", Refresh)
    p(L["Clean look: "] .. (TotemWatchDB.cleanLook and L["on"] or L["off"]))
  elseif cmd == "timers" then
    -- Diagnose: jeden Bossmod-Timer im Chat ausgeben
    ns.debugTimers = not ns.debugTimers
    p(L["Boss mod timer output: "] .. (ns.debugTimers and L["on"] or L["off"]))
  elseif cmd == "msg" or cmd == "messages" then
    local on = ns.ToggleMessageMove()
    p(on and L["Messages unlocked – drag them, right-click or /tw msg to lock."] or L["Message position saved."])
  elseif cmd == "skin" or cmd == "design" then
    if arg ~= "" and ns.SKINS[arg] then
      if InCombatLockdown() then p(L["Not possible in combat."]) return end
      TotemWatchDB.skin = arg
      ns.ApplySkin(); SafeCall("Display", Refresh)
      p(L["Design: "] .. ns.SKINS[arg].name)
    else
      p(L["Designs: "] .. table.concat(ns.SKIN_ORDER, ", ") .. "  (" .. L["current: "] .. tostring(TotemWatchDB.skin) .. ")")
    end
  elseif cmd == "bar" then
    -- Diagnose der Totem-Leiste von Call of the Elements
    p("Call of the Elements – " .. L["totem bar diagnostics"])
    print("  Call of the Elements: " .. tostring(ns.callName or "-"))
    print("  SetMultiCastSpell: " .. (SetMultiCastSpell and L["yes"] or L["no"]) ..
          ", GetMultiCastTotemSpells: " .. (GetMultiCastTotemSpells and L["yes"] or L["no"]) ..
          ", TOTEM_PRIORITIES: " .. (TOTEM_PRIORITIES and table.concat(TOTEM_PRIORITIES, ",") or "-"))
    print("  " .. L["Last sync: "] .. tostring(ns.syncResult or "-"))
    -- Welche Plätze nutzt TotemWatch, und woher kommen sie?
    local acts = ns.MultiCastActions()
    print(format("  Slots used: %d, %d, %d, %d  (source: %s)", acts[1], acts[2], acts[3], acts[4], tostring(ns.multicastSource)))
    -- Blizzard-Knöpfe der Totem-Leiste
    for i = 1, 4 do
      local btn = _G["MultiCastActionButton" .. i]
      if btn then
        local a = btn.action or (btn.GetAttribute and btn:GetAttribute("action"))
        local k = type(a) == "number" and ActionTotemKey(a)
        print(format("  MultiCastActionButton%d: action=%s %s", i, tostring(a), k and TotemName(k) or ""))
      end
    end
    -- Funktionen und Fenster im Client, die mit der Totem-Leiste zu tun haben
    local apis, frames = {}, {}
    for name, v in pairs(_G) do
      if type(name) == "string" and (name:find("MultiCast") or name:find("TotemBar") or name:find("Totem.*Bar")) then
        if type(v) == "function" then apis[#apis + 1] = name
        elseif type(v) == "table" and v.GetObjectType then frames[#frames + 1] = name end
      end
    end
    table.sort(apis); table.sort(frames)
    print("  " .. L["Functions: "] .. (#apis > 0 and table.concat(apis, ", ") or "-"))
    print("  " .. L["Frames: "] .. (#frames > 0 and table.concat(frames, ", ", 1, math.min(#frames, 15)) or "-"))
    -- Alle Aktions-Plätze mit Totem-Zaubern auflisten (zeigt, wo die Leiste wirklich liegt)
    local found = 0
    for a = 1, 200 do
      local ok, kind, id = pcall(GetActionInfo, a)
      if ok and kind == "spell" and id and not IsSecret(id) then
        local nm = SpellName(id)
        local k = nm and KeyFromName(nm)
        if k then
          found = found + 1
          print(format("  " .. L["action %d: %s (spell ID %d)"], a, nm, id))
        end
      end
    end
    if found == 0 then print("  " .. L["No totems found on any action slot."]) end
    if GetMultiCastTotemSpells then
      for s = 1, 4 do
        local ok, list = pcall(function() return { GetMultiCastTotemSpells(s) } end)
        if ok and list then
          local names = {}
          for _, id in ipairs(list) do names[#names + 1] = tostring(SpellName(id) or id) end
          print(format("  GetMultiCastTotemSpells(%d): %s", s, table.concat(names, ", ")))
        end
      end
    end
  elseif cmd == "check" then
    if InCombatLockdown() then p(L["The pull check only works out of combat."]) return end
    local old = TotemWatchDB.prePull
    TotemWatchDB.prePull = true
    ns.RunPrePullCheck(L["manual"], 20)
    TotemWatchDB.prePull = old
  elseif cmd == "probe" then
    -- Welche Daten liefert der Client gerade (im Kampf testen!)?
    local function pack(...) return { n = select("#", ...), ... } end
    local function probe(label, fn)
      local r = pack(pcall(fn))
      if not r[1] then
        print(format(L["  %s: |cffff4040blocked (error)|r %s"], label, tostring(r[2])))
        return
      end
      if r.n < 2 or (r.n == 2 and r[2] == nil) then
        print(format(L["  %s: |cffaaaaaano data|r"], label))
        return
      end
      local secret = false
      for i = 2, r.n do
        local v = r[i]
        if IsSecret(v) then secret = true end
        if type(v) == "table" then
          for _, fv in pairs(v) do if IsSecret(fv) then secret = true end end
        end
      end
      print(format("  %s: %s", label, secret and L["|cffff8000blocked (secret value)|r"] or L["|cff40ff40readable|r"]))
    end
    local earthSpell = slots[2]:GetAttribute("spell1") or SpellName(8075)
    p(format(L["Data test – in combat: %s, client %s"], InCombatLockdown() and L["|cff40ff40yes|r"] or
      L["|cffff4040NO (please repeat in combat)|r"], tostring(select(4, GetBuildInfo()))))
    print(L["  Secret values in client: "] .. (issecretvalue and L["yes"] or L["no"]))
    for s = 1, 4 do probe("Totem " .. ns.SLOT_NAMES[s] .. " (GetTotemInfo)", function() return GetTotemInfo(s) end) end
    if GetTotemTimeLeft then probe(L["Totem time left (GetTotemTimeLeft)"], function() return GetTotemTimeLeft(1) end) end
    probe(L["Spell cooldown"], function()
      if C_Spell and C_Spell.GetSpellCooldown then return C_Spell.GetSpellCooldown(earthSpell) end
      return GetSpellCooldown(earthSpell)
    end)
    probe(L["Own buffs"], function()
      if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then return C_UnitAuras.GetBuffDataByIndex("player", 1) end
      return UnitBuff("player", 1)
    end)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
      local learned = {}
      if TotemWatchDB.shieldAuraIds then for id in pairs(TotemWatchDB.shieldAuraIds) do learned[#learned + 1] = id end end
      print(L["  Learned shield IDs: "] .. (#learned > 0 and table.concat(learned, ", ") or
        L["|cffff8000none – cast your shield out of combat, then test again|r"]))
      probe(L["Own shield (by spell ID, shield must be active)"], function()
        for _, id in ipairs(ShieldIdList()) do
          local a = C_UnitAuras.GetPlayerAuraBySpellID(id)
          if a then return a end
        end
      end)
    end
    probe(L["Own debuffs"], function()
      if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then return C_UnitAuras.GetDebuffDataByIndex("player", 1) end
      return UnitDebuff("player", 1)
    end)
    if UnitExists("party1") then
      probe(L["Party member buffs"], function()
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then return C_UnitAuras.GetBuffDataByIndex("party1", 1) end
        return UnitBuff("party1", 1)
      end)
      probe(L["Party member range (UnitInRange)"], function() return UnitInRange("party1") end)
    end
    probe(L["Own health"], function() return UnitHealth("player") end)
    probe(L["Own mana"], function() return UnitPower("player") end)
    probe(L["Weapon enchant"], function() return GetWeaponEnchantInfo() end)
    if UnitExists("nameplate1") then
      probe(L["Enemy nameplate"], function() return UnitAffectingCombat("nameplate1") end)
    end
    if UnitExists("target") then probe(L["Target health"], function() return UnitHealth("target") end) end
    print(L["  Spell event (cast): "] .. (not ns.lastCastSeen and L["|cffaaaaaanothing cast yet|r"]
      or ns.lastCastSecret and L["|cffff8000blocked|r"] or L["|cff40ff40readable|r"]))
    -- für Abstands-Warnung und Furcht-Erkennung
    probe(L["Own position (UnitPosition)"], function() return UnitPosition("player") end)
    if UnitExists("target") then
      probe(L["Target casting (UnitCastingInfo)"], function() return UnitCastingInfo("target") end)
    end
    print(L["  Enemy spell events: "] .. (not ns.enemyCastSeen and L["|cffaaaaaanone seen yet (let enemies cast)|r"]
      or ns.enemyCastReadable and (L["|cff40ff40readable|r (last: "] .. tostring(ns.lastEnemyCast) .. ")")
      or L["|cffff8000blocked|r"]))
    print(L["  Combat log: "] .. (ns.combatLogAllowed and L["registered"] or L["not registered (blocked on Forever)"]))
    -- Totem-Zauber: welche kennt der Client?
    local nf = "|cffaaaaaa" .. L["not learned / not in this game version"] .. "|r"
    print("  Call of the Elements: " .. (ns.callName and ("|cff40ff40" .. ns.callName .. "|r") or nf))
    print("  Totemic Call: " .. (ns.moveName and ("|cff40ff40" .. ns.moveName .. "|r") or nf))
    print("  Totemic Recall: " .. (ns.recallName and ("|cff40ff40" .. ns.recallName .. "|r") or nf))
    if ns.callName then
      local keys = {}
      for s = 1, 4 do
        local k = ns.multicastKeys and ns.multicastKeys[s]
        keys[#keys + 1] = k and TotemName(k) or "-"
      end
      print(L["  Call of the Elements bar: "] .. table.concat(keys, ", "))
    end
    print(L["  Countdown numbers (game setting): "] .. tostring(GetCVar and GetCVar("countdownForCooldowns")))
  elseif cmd == "combatlog" or cmd == "kampflog" then
    TotemWatchDB.forceCombatLog = not TotemWatchDB.forceCombatLog
    p(L["Force combat log: "] .. (TotemWatchDB.forceCombatLog and L["on"] or L["off"]) ..
      L[" – takes effect after /reload. If the Blizzard message returns, turn it off again."])
  elseif (cmd == "" or cmd == "config" or cmd == "options" or cmd == "optionen") and ns.OpenOptions then
    ns.OpenOptions()
  else
    p(L["Commands:"])
    print(L["  /tw – open options"])
    print(L["  /tw test – show the bar for testing (on/off)"])
    print(L["  /tw lock | unlock – lock / move the window"])
    print(L["  /tw scale 1.2 – change size"])
    print(L["  /tw sound – warning sound on/off"])
    print(L["  /tw auto – auto-assign recommended totems to buttons (on/off)"])
    print(L["  /tw ooc – also show out of combat"])
    print(L["  /tw boss <encounterID> – simulate a boss (e.g. 672 = Ragnaros)"])
    print(L["  /tw other <totem> – simulate another shaman's totem (no value: remove)"])
    print(L["  /tw reset – reset position"])
    print(L["  /tw check – show the pull check now (otherwise automatic on pull timer / ready check)"])
    print(L["  /tw probe – test in combat which data the game allows"])
    print(L["  /tw bar – Call of the Elements bar diagnostics"])
    print(L["  /tw skin <classic|minimal|pillars|bars> – change the design"])
    print(L["  /tw msg – move the messages in the middle of the screen"])
    print(L["  /tw soundtest – play a test warning (sound, message, speech)"])
    print(L["  /tw tremor – Emergency Tremor button on/off  ·  /tw sos move | attach | test"])
    print(L["  /tw tutorial – start the tour  ·  /tw minimap – show/hide the minimap button"])
    print(L["  /tw combatlog – force the combat log (testing only; default on Forever: off)"])
    print(L["  Combat log active: "] .. (ns.combatLogAllowed and L["yes"] or L["no (buff-based fallback)"]))
    print(L["  Keys: Esc > Key Bindings > AddOns > TotemWatch"])
  end
end
