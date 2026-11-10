<p align="center"><img src="media/logo.png" width="200" alt="TotemWatch"></p>

<h1 align="center">TotemWatch</h1>

<p align="center"><b>Made for WoW Forever</b> – the totem helper for Shamans that works with Forever's combat restrictions.</p>

TotemWatch shows which totems are missing in combat, recommends the right ones for your boss, your group and the situation, and warns you before something goes wrong. Many older totem addons stop working on WoW Forever because the game hides combat data from addons – TotemWatch was built around these limits from day one.

## Features

- **Clickable totem bar** – left-click drops a totem, right-click opens a selection of all your learned totems; **ALL** casts your four totems one after another
- **The button you need glows** – missing, wrong or expiring totems are marked, one hint line tells you the next step
- **Eight designs** – Classic, Minimal, Pillars, Bars, Compact, Focus, Two rows, Column – with the **Clean look** or Blizzard style, **round or square icons**, plus **Masque** support
- **Named templates** for **Call of the Elements, Ancestors and Spirits** – TotemWatch sets up the game's totem bar for you; switch templates in combat by right-clicking the grip
- **Smart recommendations** – raid bosses (MC, Onyxia, BWL, ZG, AQ40, Naxx), about 30 classic dungeon bosses and the new Forever dungeons (Blizzard encounters, **DBM**, **BigWigs** or boss name), dangerous monsters, your group (melee, casters, healers by role, rogues, AoE) – every recommendation says why
- **Weapon enchant by role** – Windfury, Rockbiter or Flametongue depending on talents and weapon
- **Emergency buttons** – Tremor, Poison Cleansing, Disease Cleansing and Grounding light up when danger is coming
- **Warnings** – before a totem expires, when one is destroyed, when you are out of range – big messages and optional **spoken warnings**
- **Pull check** – a checklist on DBM/BigWigs pull timers and ready checks: totems, shield, weapon enchant, group range
- **Mana and cooldowns** – buttons turn blue-grey without enough mana; cooldowns are shown, also in combat
- **Totemic Call or re-drop?** – compares mana and saved casts and lights up the better button
- **Multiple shamans** – avoids duplicate totems in your group
- **Guided tour with pictures**, Help tab, "What's new" window and Changelog tab, minimap button, key bindings for every button
- **Light on your CPU** – check with `/tw cpu`
- **English and German**, more languages via CurseForge translations

## Commands

| Command | |
|---|---|
| `/tw` | Options |
| `/tw tour` | Guided tour |
| `/tw test` | Show the bar out of combat |
| `/tw check` | Pull check now |
| `/tw sos test` | Test the emergency buttons |
| `/tw skin <name>` | Change the design |
| `/tw cpu` | CPU use of TotemWatch |
| `/tw help` | All commands |

## Installation

Install via **CurseForge** or **Wago**, or copy the folder `TotemWatch` to `World of Warcraft\<Forever folder>\Interface\AddOns\`.

## Translations

All texts live in `Locales.lua` (key = English text). Translations can be contributed on the CurseForge project page (*Localization*) or via a pull request.

## For developers – releasing

1. Add an entry at the top of `CHANGELOG.md` and commit.
2. Tag and push:
   ```bash
   git tag v1.2.1
   git push origin main --tags
   ```
   GitHub Actions builds the package, creates a GitHub release and uploads it to CurseForge (and Wago, if configured – see `.github/workflows/release.yml`).

## License

MIT – see [LICENSE.txt](LICENSE.txt).
