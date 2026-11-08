-- TotemWatch - Daten
-- Hier kannst du Boss-Empfehlungen, Fear-Zauber und Standard-Totems anpassen.
local ADDON, ns = ...

-- Totem-Slots wie GetTotemInfo() sie liefert
ns.FIRE, ns.EARTH, ns.WATER, ns.AIR = 1, 2, 3, 4
ns.SLOT_KEYS  = { [1] = "fire", [2] = "earth", [3] = "water", [4] = "air" }
ns.SLOT_NAMES = { [1] = "Feuer", [2] = "Erde", [3] = "Wasser", [4] = "Luft" }
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

-- Boss-Empfehlungen, Schlüssel = encounterID (ENCOUNTER_START / DBM / BigWigs).
-- Jede Element-Liste wird der Reihe nach probiert; das erste bekannte Totem gewinnt.
-- avoid = Totems, die man bei diesem Boss NICHT stellen soll.
local function T(key, reason) return { key, reason } end

ns.BOSSES = {
  ---------------------------------------------------------------- Molten Core
  [663] = { name = "Lucifron",   earth = { T("TREMOR", "Gedankenkontrolle (Charm)") } },
  [664] = { name = "Magmadar",   earth = { T("TREMOR", "Panik (Fear)") },
                                 water = { T("FIRE_RES", "Lavabomben / Feuerschaden") } },
  [668] = { name = "Baron Geddon", water = { T("FIRE_RES", "Inferno / Feuerschaden") } },
  [670] = { name = "Golemagg",   water = { T("FIRE_RES", "Feuerschaden") } },
  [672] = { name = "Ragnaros",   water = { T("FIRE_RES", "Massiver Feuerschaden") } },
  ---------------------------------------------------------------- Onyxia
  [1084] = { name = "Onyxia",    earth = { T("TREMOR", "Dröhnendes Gebrüll in Phase 3") },
                                 water = { T("FIRE_RES", "Flammenatem / Tiefer Atem") } },
  ---------------------------------------------------------------- Blackwing Lair
  [611] = { name = "Vaelastrasz", water = { T("FIRE_RES", "Flammenatem") } },
  [613] = { name = "Feuerschwinge", water = { T("FIRE_RES", "Flammenpuffer") } },
  [614] = { name = "Schattenschwinge", water = { T("FIRE_RES", "Schattenflamme") } },
  [615] = { name = "Flammenmaul", water = { T("FIRE_RES", "Schattenflamme / Feuernova") } },
  [616] = { name = "Chromaggus", water = { T("POISON_CLEANSE", "Brutgebrechen: Grün (Gift)"),
                                           T("FIRE_RES", "Atemangriffe") },
                                 note = "Atem-Typ beachten: ggf. Frost-/Naturwiderstand stellen" },
  [617] = { name = "Nefarian",   earth = { T("TREMOR", "Dröhnendes Gebrüll (Fear)") },
                                 water = { T("FIRE_RES", "Schattenflamme") } },
  ---------------------------------------------------------------- Zul'Gurub
  [784] = { name = "Venoxis",    water = { T("POISON_CLEANSE", "Giftwolken / Gift") },
                                 air   = { T("NATURE_RES", "Naturschaden") } },
  [785] = { name = "Jeklik",     earth = { T("TREMOR", "Schrei (Fear)") } },
  [786] = { name = "Mar'li",     water = { T("POISON_CLEANSE", "Giftblitzsalve") },
                                 air   = { T("NATURE_RES", "Naturschaden") } },
  [793] = { name = "Hakkar",     earth = { T("TREMOR", "Wahnsinn verursachen (Charm)") },
                                 avoid = { POISON_CLEANSE = "Gift wird gegen Bluttrinken gebraucht!" } },
  ---------------------------------------------------------------- AQ40
  [710] = { name = "Käfer-Trio", earth = { T("TREMOR", "Prinzessin Yauj: Fear") } },
  [713] = { name = "Viscidus",   water = { T("POISON_CLEANSE", "Giftblitzsalve") },
                                 air   = { T("NATURE_RES", "Naturschaden") } },
  [714] = { name = "Huhuran",    water = { T("POISON_CLEANSE", "Wyvernstich / Gift") },
                                 air   = { T("NATURE_RES", "Giftiger Stachel – Naturschaden") } },
  ---------------------------------------------------------------- Naxxramas
  [1108] = { name = "Gluth",     earth = { T("TREMOR", "Furchterregendes Gebrüll") } },
  [1110] = { name = "Faerlina",  water = { T("FIRE_RES", "Feuerregen") } },
  [1112] = { name = "Heigan",    water = { T("DISEASE_CLEANSE", "Zerfallsfieber (Krankheit)") } },
  [1116] = { name = "Maexxna",   water = { T("POISON_CLEANSE", "Giftschuss-Salve") },
                                 air   = { T("NATURE_RES", "Naturschaden") } },
  [1119] = { name = "Saphiron",  fire  = { T("FROST_RES", "Frostaura / Frostatem") } },
  [1114] = { name = "Kel'Thuzad", fire = { T("FROST_RES", "Frostblitze / Frostschlag") } },
  [1120] = { name = "Thaddius",  air   = { T("NATURE_RES", "Kettenblitz / Polarität") } },
}
