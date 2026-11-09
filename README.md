<p align="center"><img src="media/logo.png" width="200" alt="TotemWatch"></p>

<h1 align="center">TotemWatch</h1>

<p align="center"><b>Made for WoW Forever</b> – the totem helper for Shamans that works with Forever's combat restrictions.</p>

TotemWatch shows which totems are missing in combat, recommends the right ones for your boss, your group and the situation, and warns you before something goes wrong. Many older totem addons stop working on WoW Forever because the game hides combat data from addons – TotemWatch was built around these limits from day one.

## Features

- **Clickable totem bar** – left-click drops a totem, right-click opens a selection of all your totems
- **Smart recommendations** – boss rules (MC, Onyxia, BWL, ZG, AQ40, Naxx), boss detection via Blizzard encounters, **DBM** and **BigWigs**, fear warnings (Tremor Totem), group composition, AoE
- **Glow** on the button you should press right now
- **Warnings** – before a totem expires, when a totem is destroyed, when you are out of range of your totems, big messages in the middle of the screen, optional **spoken warnings** (text to speech)
- **Pull check** – a checklist on DBM/BigWigs pull timers and ready checks: totems, shield, weapon imbue, group range
- **Call of the Elements, Totemic Call, Totemic Recall** – with a mana comparison that tells you whether Totemic Call or re-dropping is cheaper
- **Four designs** – Classic, Minimal, Pillars, Bars – plus **Masque** support
- **Multiple shamans** – avoids duplicate totems in your group
- **Guided tour** on first start, minimap button, key bindings for every button
- **English and German**, more languages via CurseForge translations

## Commands

| Command | |
|---|---|
| `/tw` | Options |
| `/tw tutorial` | Guided tour |
| `/tw test` | Show the bar out of combat |
| `/tw check` | Pull check now |
| `/tw skin <classic\|minimal\|pillars\|bars>` | Change the design |
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
