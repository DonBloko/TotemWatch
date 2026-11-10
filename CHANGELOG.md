# TotemWatch – Changelog

## 1.4.0

### New
- **Named templates for all three calls** (options → Calls): save as many templates as you like with a name (e.g. "Dungeon AoE", "Raid melee"), each with 4 totems, and choose which template **Call of the Elements**, **Call of the Ancestors** and **Call of the Spirits** use. TotemWatch puts the totems on the game's totem bar for you (out of combat) – no need to set up the bar yourself. "Take from buttons" saves your current TotemWatch buttons, "Put on buttons" loads a template onto them. Call of the Elements can also simply follow your TotemWatch buttons.
- **Call button with selection**: right-click the Call button to choose which call it casts (Elements, Ancestors or Spirits) – the name of each call's template is shown next to it, and a short message names the chosen template. The tooltip shows the template and its totems.
- **Switch templates at the bar**: right-click the dotted grip left of the bar to open your templates; one click puts the 4 totems of a template on your TotemWatch buttons – also in combat (options → Bar).
- TotemWatch now recognizes all three calls when you cast them, so the totem timers are right in combat, too.
- Template editor shows totem icons and only lists totems you have learned.
- `/tw bar` shows all three pages of the totem bar.
- **Pictures that explain the bar**: the guided tour shows small pictures for moving the bar, clicking and the status colors, and the **Help** tab is now a reference page with an annotated overview of the bar and pictures for every feature (casting and choosing, colors, templates, calls, emergency buttons). The pictures follow your icon shape (round or square).
- The guided tour shows the TotemWatch logo.
- **"What's new" window**: after an update TotemWatch shows once what is new (not on a fresh install – the tour explains everything then). Open it again any time with `/tw news`.
- **Visible grip to move the bar**: a small dotted handle on the left of the bar (hidden when the bar is locked).
- Fix: the bar now really stays visible for a few seconds after combat.

## 1.3.0

### New
- **Four new designs** (options → Look, or `/tw skin <name>`):
  - **Compact** – only the totems are big; weapon and shield small; ALL, Call of the Elements, Totemic Call and Totemic Recall behind a "..." button (opens in combat, too).
  - **Focus** – no background; buttons that need nothing are almost invisible, only the ones you have to press light up.
  - **Two rows** – totems on top, all extra buttons as a small row below.
  - **Column** – a narrow column, e.g. next to your character, with the remaining time beside each totem.
- **Clean look** (on by default, `/tw clean`): no box around the bar, thin dark frames, status color only where you have to act, calmer icons, plain font. Works with every design; switch back to the Blizzard style any time.
- **Round icons** (default for new installs, `/tw round`): totems, weapon, shield, the Call buttons, ALL and the emergency buttons as circles with a ring in the status color and a soft round glow. Built without mask textures, so no crash risk.
- **Short hints**: one line with the next step below the bar, e.g. "Next: Searing Totem (Fire) – Extra damage (+2)". Full list or off in the options.
- **The bar stays visible for a few seconds after combat** (default 8 s, options → Bar), e.g. for Totemic Recall.
- **Elements without a learned totem are hidden** (e.g. Air before level 30); the other buttons move together and the missing one appears when you learn it.

### Improved
- **Clearer options menu** (`/tw`): five tabs – Look, Bar, Warnings, Emergency, Help. The Look tab uses drop-downs for design, style, icon shape and hints. While the menu is open, the bar is shown on top of it so you see every change right away.
- Guided tour: choose square or round icons in the design step.
- Emergency buttons are smaller by default (44 instead of 64, adjustable).
- **Range in dungeons**: the game hides your position in instances, so no yards can be shown there – if you yourself are out of range, the button now says *far*, the hint says "you are out of range of …" and the center message appears.
- Pillars: the element color is a small dot above round icons; no empty time bar under an empty slot.
- Bars: no extra hint line (the bars already say what is missing).
- Counts (shield charges, players out of range) and the "ALL" text fit small buttons and no longer overlap other text.
- New `/tw look` shows the display state – handy for bug reports.

### Fixed
- The distance to a totem was sometimes missing when the game reported the totem before the cast.
- The yards display on a button could disappear when a locked value caused a problem.
- Clean look with square icons: the status line and glow were too faint on bright ground.

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
