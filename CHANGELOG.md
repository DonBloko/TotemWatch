# TotemWatch – Changelog

## 1.3.0 (beta)

- **Clean look** (options menu → Design, or `/tw clean`, on by default in this beta): no box around the bar (transparent background), thin dark frames, status color only as a fine line where you have to act, calmer icons, softer glow, plain font with shadow, no mini icons (they are in the tooltip), empty slots as dark fields. Works with every design.
- **Round icons (beta)** (options menu → Design, or `/tw round`): icons built from thin circular strips with a ring that shows the status color and a soft round glow – also for Call, Totemic Call, Recall, the ALL button (round blue disc) and the emergency buttons; in Pillars the element color becomes a small dot above the circle – no mask textures, so no crash risk.
- Emergency buttons are smaller by default (44 instead of 64; adjustable in the options).
- **The bar stays visible for a few seconds after combat** (default 8 s, options → Bar), e.g. for Totemic Recall.
- Bars design: no extra hint line below (the bars already say what is missing).
- **Elements without a learned totem are hidden** (e.g. Air before level 30); the other buttons move together. They appear automatically when you learn the first totem.
- **Short hints** (on by default, options → Recommendations): one line with the next step, e.g. "Next: Searing Totem (Fire) – Extra damage (+2)". Turn it off for the full list.
- Pillars: no empty gray time bar under a slot without a totem; with round icons the time bar is thinner.
- Clean look: counts (shield charges, players out of range) are a small badge at the bottom right and no longer overlap "far" or the remaining time.
- Clean look with square icons: the status line and glow are clearly visible now (they were too faint on bright ground); in Blizzard style the ready Call/Recall buttons get a neutral ring with round icons. New `/tw look` prints the display state for bug reports. Fixed the glow sometimes being drawn behind the totem buttons.
- **Clearer options menu** (`/tw`): five tabs – Look, Bar, Warnings, Emergency, Help – instead of one long page; related settings grouped in two columns. The Look tab uses drop-downs for design, style (Clean/Blizzard), icon shape (square/round) and hints (one line/full list/off). The menu remembers the last tab.
- Guided tour: the design step now also asks whether icons should be square or round.
- While the options menu is open, the bar is shown (test mode) on top of the window, so every change is visible right away; closing the menu restores it.
- **Four new designs to try** (options menu → Design, or `/tw skin <name>`):
  - **Compact** (`compact`) – small bar: only the 4 totems are big, weapon and shield small, ALL/Call/Totemic Call/Recall behind a "..." button (opens in combat, too). One hint line with the next step.
  - **Focus** (`focus`) – no background; buttons that need nothing are almost invisible, only the ones you have to press light up.
  - **Two rows** (`stacked`) – totems on top, all extra buttons as a small row below; hints only in the tooltip.
  - **Column** (`column`) – a narrow column (e.g. next to your character) with the remaining time beside each totem.

## 1.2.2

- **Fix:** the totem range/distance was sometimes missing when the game reported a new totem before the cast event (no or an old position was stored). The position is now taken when the totem appears.
- **Range in dungeons:** the game hides your position in instances, so no yards can be shown there. If you yourself are missing a totem buff, the button now says *far* with an orange frame, the hint says "you are out of range of …", and the center message appears (instead of only a red "1").
- The yards display on the button no longer disappears when a locked value causes a problem earlier in the update.

## 1.2.1

- **Emergency Tremor button** – a big button that always casts Tremor Totem. It stays dimmed and lights up with a countdown when a fear is coming (boss mod timer or enemy cast); green when Tremor is already up. By default it sits on top of the totem bar (emergency row) and moves with it; drag it anywhere you like, and attach it again with one click. Own key binding, size adjustable (`/tw tremor`, `/tw tremor move | attach | test`).
- **More emergency buttons: Poison Cleansing, Disease Cleansing and Grounding** – they work like the Tremor button: always the same totem, dimmed at rest, lighting up when enemies cast poison, diseases or dangerous spells (Polymorph, Hex, Fear …) or a boss mod announces them. Each can be switched off in the options; all of them dock in the emergency row above the bar and move together. Test them with *Test emergency alerts* or `/tw sos test`.
- **Fix:** boss mod timers from newer DBM versions (`DBM_TimerBegin`) are recognized again, so fear/poison/Grounding warnings from DBM work. Emergency buttons now also appear out of combat while a warning is active. New: `/tw timers` prints every boss mod timer to chat (diagnostics).
- Emergency button texts (countdown, *Active*) now sit above the buttons and no longer overlap the neighbouring button.
- **Spoken warnings** (text to speech) – optional, in the options under Warnings. Try them with the *Test warnings* button or `/tw soundtest`.
- **Masque support** – the buttons use your Masque skin if Masque is installed.
- Uploads to **Wago Addons** as well (once configured).
- **New:** *Always show in dungeons* and *Always show in raids* – the bar stays visible in instances, also between fights (on by default).
- **Fix: game crash** ("memory could not be written") caused by the round icon masks of the *Pillars* design. Masks are no longer used; Pillars now has square icons.
- **Fix:** your own totem choice is no longer overwritten by the automatic assignment (e.g. Magma Totem being reset to Searing Totem after combat). A button you set yourself keeps your totem until you pick the recommended one again; the tooltip shows when a button is set by you. `/tw auto` or the option *Auto-assign buttons* clears your choices.

## 1.2.0

- **Four designs to choose from** (options menu → Design, or `/tw skin <name>`):
  - **Classic** – Blizzard look with a gold frame and title
  - **Minimal** – flat and compact; status as a colored strip, time inside the icon
  - **Pillars** – round icons, element color strip on top, time bar below
  - **Bars** – one row per element with totem name, status and a time bar (like boss mod bars)
- Hint texts match the chosen design and no longer overlap when a hint wraps.
- The messages in the middle of the screen can be moved (options menu → Move messages, or `/tw msg`).
- **Minimap button:** left-click opens the options, right-click shows/hides the bar, Shift-click starts the tour; drag it around the minimap (can be hidden).
- **Guided tour** on first login (and any time via the minimap button, the options or `/tw tutorial`): design, placement, usage, key bindings and warnings in 7 short steps.

## 1.1.0

- **English interface.** The language follows your game client: English by default, German on German clients.
- Boss names and recommendation reasons are translated, too.
- New English command names: `/tw other <totem>`, `/tw combatlog`, `/tw options` (the German ones still work).
- **New buttons** (only shown if you know the spell):
  - **Call of the Elements** – drops all 4 totems at once; its totem bar is synced with your TotemWatch buttons out of combat.
  - **Totemic Call** – moves your totems to you; TotemWatch keeps their timers and updates their position. When you are out of range, TotemWatch compares mana: Totemic Call is only recommended if it costs less than the remaining time you would waste by re-dropping (totem cost × remaining share of its duration). Otherwise it tells you to re-drop.
  - **Totemic Recall** – removes your totems; no false "totem destroyed" warnings afterwards.
- Key bindings for the new buttons; `/tw probe` shows which of these spells your client knows.
- Call of the Elements bar: synced to the slots the game actually uses (read from its totem bar buttons). In combat the game does not allow automatic changes – right-click a totem in the selection menu to put it on the bar (works in combat). TotemWatch checks whether its sync worked. If the game does not allow it, TotemWatch shows which totems on the bar differ from your buttons so you can change them yourself. New diagnostics: `/tw bar`.
- **Readability:** hint texts below the bar now have a dark background and an outlined, larger font (size adjustable).
- **Messages in the middle of the screen** for missing totems, fear and destroyed totems – each only once (size adjustable, can be turned off).
- **Glow:** the button you should press glows; in the selection menu the recommended totem glows.
- **Totemic Call vs. Totemic Recall:** when you are out of range, the better choice glows and the other one is greyed out (mana comparison in the tooltip).
- **Distance warning** uses the range from the spell's own tooltip ("within 30 yards"), shown in yards, with 2 yards tolerance; it runs independently of the bar (twice per second) and shows a message in the middle of the screen when you leave the range of your totems. `/tw debug` shows the distance per totem.

*Deutsch:* Englische Oberfläche – die Sprache richtet sich nach dem Spiel-Client (deutscher Client = Deutsch).

## 1.0.0 (erste Veröffentlichung)

- Totem-Leiste mit 4 Element-Knöpfen: Linksklick stellt, Rechtsklick öffnet die Auswahl
- Automatische Empfehlungen nach Boss (Blizzard/DBM/BigWigs), Gruppe, Furcht, Gift/Krankheit und AoE
- Boss-Regeln für Molten Core, Onyxia, Blackwing Lair, Zul'Gurub, AQ40 und Naxxramas
- Knopf „ALLE“ (stellt nacheinander alle 4 Totems), Knöpfe für Waffenverzauberung und Schild
- Exakte Totem-Restzeit im Kampf; Laufzeit je Rang wird automatisch gelernt
- Warnungen: Vorwarnung vor Ablauf, Totem zerstört, Abstand zu den Totems, Reichweite der Gruppe
- Pull-Check bei Pull-Timer und Bereitschaftscheck
- Erkennung von Totems anderer Schamanen
- Optionsmenü (`/tw`), Tastenbelegung, Diagnosebefehle `/tw debug` und `/tw probe`
- Angepasst an die Kampf-Einschränkungen von WoW Forever (kein Kampflog, gesperrte Auren im Kampf)
