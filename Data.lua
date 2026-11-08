-- TotemWatch - Daten
-- Hier kannst du Boss-Empfehlungen, Fear-Zauber und Standard-Totems anpassen.
local ADDON, ns = ...
local L = ns.L

-- Totem-Slots wie GetTotemInfo() sie liefert
ns.FIRE, ns.EARTH, ns.WATER, ns.AIR = 1, 2, 3, 4
ns.SLOT_KEYS  = { [1] = "fire", [2] = "earth", [3] = "water", [4] = "air" }
ns.SLOT_NAMES = { [1] = L["Fire"], [2] = L["Earth"], [3] = L["Water"], [4] = L["Air"] }
ns.SLOT_COLORS = {
  [1] = "ff7f3f", [2] = "c8a050", [3] = "40a0ff", [4] = "b0e0ff",
}

-- Rang-1-Zauber-IDs (Name und Icon werden aus dem Spiel gelesen -> automatisch lokalisiert)
ns.TOTEMS = {
  -- Feuer
  SEARING        = { id = 3599,  slot = 1 },
  FIRE_NOVA      = { id = 1535,  slot = 1 },
  MAGMA          = { id = 8190,  slot = 1 },
  FLAMETONGUE    = { id = 8227,  slot = 1 },
  FROST_RES      = { id = 8181,  slot = 1 },
  TOTEM_OF_WRATH = { id = 30706, slot = 1 }, -- TBC
  -- Erde
  STRENGTH       = { id = 8075,  slot = 2 },
  STONESKIN      = { id = 8071,  slot = 2 },
  TREMOR         = { id = 8143,  slot = 2 },
  EARTHBIND      = { id = 2484,  slot = 2 },
  STONECLAW      = { id = 5730,  slot = 2 },
  -- Wasser
  HEALING_STREAM = { id = 5394,  slot = 3 },
  MANA_SPRING    = { id = 5675,  slot = 3 },
  POISON_CLEANSE = { id = 8166,  slot = 3 },
  DISEASE_CLEANSE= { id = 8170,  slot = 3 },
  FIRE_RES       = { id = 8184,  slot = 3 },
  MANA_TIDE      = { id = 16190, slot = 3 },
  -- Luft
  WINDFURY       = { id = 8512,  slot = 4 },
  GRACE_OF_AIR   = { id = 8835,  slot = 4 },
  GROUNDING      = { id = 8177,  slot = 4 },
  NATURE_RES     = { id = 10595, slot = 4 },
  WINDWALL       = { id = 15107, slot = 4 },
  TRANQUIL_AIR   = { id = 25908, slot = 4 },
  WRATH_OF_AIR   = { id = 3738,  slot = 4 }, -- TBC
}

-- Reihenfolge im Auswahlmenü (Rechtsklick) je Element
ns.FLYOUT = {
  [1] = { "SEARING", "MAGMA", "FIRE_NOVA", "FLAMETONGUE", "FROST_RES", "TOTEM_OF_WRATH" },
  [2] = { "STRENGTH", "STONESKIN", "TREMOR", "EARTHBIND", "STONECLAW" },
  [3] = { "MANA_SPRING", "HEALING_STREAM", "POISON_CLEANSE", "DISEASE_CLEANSE", "FIRE_RES", "MANA_TIDE" },
  [4] = { "WINDFURY", "GRACE_OF_AIR", "WRATH_OF_AIR", "TRANQUIL_AIR", "GROUNDING", "NATURE_RES", "WINDWALL" },
}

-- Waffenverzauberungen und Schilde (Rang-1-IDs)
ns.WEAPON_SPELLS = {
  8232,  -- Waffe des Windzorns
  8024,  -- Waffe der Flammenzunge
  8033,  -- Waffe des Frostbrands
  8017,  -- Waffe des Felsbeißers
}
ns.SHIELD_SPELLS = {
  24398, -- Wasserschild (TBC)
  324,   -- Blitzschlagschild
}
-- Drei verschiedene Zauber (WoW Forever):
--   Totemic Recall:      entfernt alle Totems, gibt Mana zurück
--   Totemic Call:        holt deine Totems zu dir (sie bleiben bestehen)
--   Call of the Elements: stellt alle Totems der Totem-Leiste auf einmal
-- Recall und Call werden NUR über den Namen erkannt, da die Zauber-ID 36936 je nach
-- Spielversion mal "Totemic Call", mal "Totemic Recall" heißt. Bei Bedarf Namen ergänzen.
ns.RECALL_NAMES = { "Totemic Recall", "Totemischer Rückruf" }
ns.MOVE_NAMES   = { "Totemic Call", "Totemruf" }
ns.CALL_IDS     = { 66842 }
ns.CALL_NAMES   = { "Call of the Elements", "Ruf der Elemente" }
-- Aktions-IDs der Totem-Leiste für "Call of the Elements" (Seite 1): 133-136
ns.MULTICAST_BASE = 132

-- Alle Ränge der Schilde (für die Abfrage nach Zauber-ID im Kampf)
ns.SHIELD_AURA_IDS = {
  324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, -- Blitzschlagschild
  24398, 33736,                                          -- Wasserschild
}

-- Buffs, die Totems auf Gruppenmitgliedern hinterlassen (für den Reichweiten-Check).
-- Zusätzlich erkennt das Addon Buffs, deren Name im Totemnamen vorkommt
-- (z.B. "Stärke der Erde" in "Totem der Stärke der Erde").
-- Totems ohne Buff (Windzorn, Erdstoß, Reinigung, Feuertotems) werden nicht geprüft.
ns.TOTEM_BUFFS = {
  STRENGTH = 8076, STONESKIN = 8072, GRACE_OF_AIR = 8836, MANA_SPRING = 5677,
  HEALING_STREAM = 5672, FIRE_RES = 8185, FROST_RES = 8182, NATURE_RES = 10596,
  TRANQUIL_AIR = 25909, WINDWALL = 15108,
}

-- Wirkungsradius der Totems in Metern (für die Abstands-Warnung). Feuertotems ohne Eintrag
-- werden nicht geprüft (sie greifen Gegner an, dein Abstand ist egal). Bei Bedarf anpassen.
ns.TOTEM_RANGE_DEFAULT = 20
ns.TOTEM_RANGE = {
  TREMOR = 30, SEARING = false, MAGMA = false, FIRE_NOVA = false, STONECLAW = false, EARTHBIND = false,
}

-- Laufzeit je Rang (Zauber-ID), wo sie sich je Rang unterscheidet.
-- Das Addon lernt außerdem die echte Dauer außerhalb des Kampfes und speichert sie (hat Vorrang).
ns.RANK_DURATION = {
  -- Totem der Verbrennung Rang 1-6
  [3599] = 30, [6363] = 35, [6364] = 40, [6365] = 45, [10437] = 50, [10438] = 55,
}

-- Laufzeit in Sekunden (Ersatzwert, für Totems anderer Schamanen); nicht aufgeführte = 120
ns.TOTEM_DURATION = {
  FIRE_NOVA = 5, MANA_TIDE = 12, STONECLAW = 15, MAGMA = 20, EARTHBIND = 45,
  GROUNDING = 45, SEARING = 55, HEALING_STREAM = 60, MANA_SPRING = 60,
}

-- Zauber, gegen die Totem des Erdstoßes (Tremor) hilft: Furcht, Bezauberung, Schlaf.
ns.FEAR_SPELLS = {
  [5782] = true, [6213] = true, [6215] = true,          -- Furcht (Hexer)
  [5484] = true, [17928] = true,                        -- Schreckensgeheul
  [8122] = true, [8124] = true, [10888] = true, [10890] = true, -- Psychischer Schrei
  [5246] = true,                                        -- Drohruf
  [6358] = true,                                        -- Verführung (Sukkubus)
  [18431] = true,                                       -- Onyxia: Dröhnendes Gebrüll
  [22686] = true,                                       -- Nefarian: Dröhnendes Gebrüll
  [19408] = true,                                       -- Magmadar: Panik
  [29685] = true,                                       -- Gluth: Furchterregendes Gebrüll
  [26580] = true,                                       -- Prinzessin Yauj: Furcht
  [23918] = true,                                       -- Jeklik: Schrei
  [7399]  = true,                                       -- Schrecken (Mobs)
}

-- Stichworte in DBM-/BigWigs-Timern oder Zaubernamen, die auf Furcht hindeuten (klein geschrieben)
ns.FEAR_KEYWORDS = {
  "fear", "furcht", "roar", "gebrüll", "scream", "schrei", "panic", "panik",
  "terrify", "schreck", "howl", "geheul", "bellowing", "dröhnend",
}

-- Boss recommendations, key = encounterID (ENCOUNTER_START / DBM / BigWigs).
-- Each element list is tried in order; the first known totem wins.
-- avoid = totems you should NOT drop on this boss.
-- Names and reasons are translated via Locales.lua.
local function T(key, reason) return { key, L[reason] } end

ns.BOSSES = {
  ---------------------------------------------------------------- Molten Core
  [663] = { name = L["Lucifron"],   earth = { T("TREMOR", "Mind control (charm)") } },
  [664] = { name = L["Magmadar"],   earth = { T("TREMOR", "Panic (fear)") },
                                    water = { T("FIRE_RES", "Lava bombs / fire damage") } },
  [668] = { name = L["Baron Geddon"], water = { T("FIRE_RES", "Inferno / fire damage") } },
  [670] = { name = L["Golemagg"],   water = { T("FIRE_RES", "Fire damage") } },
  [672] = { name = L["Ragnaros"],   water = { T("FIRE_RES", "Massive fire damage") } },
  ---------------------------------------------------------------- Onyxia
  [1084] = { name = L["Onyxia"],    earth = { T("TREMOR", "Bellowing Roar in phase 3") },
                                    water = { T("FIRE_RES", "Flame Breath / Deep Breath") } },
  ---------------------------------------------------------------- Blackwing Lair
  [611] = { name = L["Vaelastrasz"], water = { T("FIRE_RES", "Flame Breath") } },
  [613] = { name = L["Firemaw"],    water = { T("FIRE_RES", "Flame Buffet") } },
  [614] = { name = L["Ebonroc"],    water = { T("FIRE_RES", "Shadow Flame") } },
  [615] = { name = L["Flamegor"],   water = { T("FIRE_RES", "Shadow Flame / Fire Nova") } },
  [616] = { name = L["Chromaggus"], water = { T("POISON_CLEANSE", "Brood Affliction: Green (poison)"),
                                              T("FIRE_RES", "Breath attacks") },
                                    note = L["Watch the breath type: drop Frost/Nature Resistance if needed"] },
  [617] = { name = L["Nefarian"],   earth = { T("TREMOR", "Bellowing Roar (fear)") },
                                    water = { T("FIRE_RES", "Shadow Flame") } },
  ---------------------------------------------------------------- Zul'Gurub
  [784] = { name = L["Venoxis"],    water = { T("POISON_CLEANSE", "Poison clouds / poison") },
                                    air   = { T("NATURE_RES", "Nature damage") } },
  [785] = { name = L["Jeklik"],     earth = { T("TREMOR", "Screech (fear)") } },
  [786] = { name = L["Mar'li"],     water = { T("POISON_CLEANSE", "Poison Bolt Volley") },
                                    air   = { T("NATURE_RES", "Nature damage") } },
  [793] = { name = L["Hakkar"],     earth = { T("TREMOR", "Cause Insanity (charm)") },
                                    avoid = { POISON_CLEANSE = L["Poison is needed against Blood Siphon!"] } },
  ---------------------------------------------------------------- AQ40
  [710] = { name = L["Bug Trio"],   earth = { T("TREMOR", "Princess Yauj: fear") } },
  [713] = { name = L["Viscidus"],   water = { T("POISON_CLEANSE", "Poison Bolt Volley") },
                                    air   = { T("NATURE_RES", "Nature damage") } },
  [714] = { name = L["Princess Huhuran"], water = { T("POISON_CLEANSE", "Wyvern Sting / poison") },
                                    air   = { T("NATURE_RES", "Noxious Poison – nature damage") } },
  ---------------------------------------------------------------- Naxxramas
  [1108] = { name = L["Gluth"],     earth = { T("TREMOR", "Terrifying Roar") } },
  [1110] = { name = L["Grand Widow Faerlina"], water = { T("FIRE_RES", "Rain of Fire") } },
  [1112] = { name = L["Heigan the Unclean"], water = { T("DISEASE_CLEANSE", "Decrepit Fever (disease)") } },
  [1116] = { name = L["Maexxna"],   water = { T("POISON_CLEANSE", "Poison Shock volley") },
                                    air   = { T("NATURE_RES", "Nature damage") } },
  [1119] = { name = L["Sapphiron"], fire  = { T("FROST_RES", "Frost Aura / Frost Breath") } },
  [1114] = { name = L["Kel'Thuzad"], fire = { T("FROST_RES", "Frostbolts / Frost Blast") } },
  [1120] = { name = L["Thaddius"],  air   = { T("NATURE_RES", "Chain Lightning / Polarity") } },
}
