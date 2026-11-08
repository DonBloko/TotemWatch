<p align="center"><img src="media/logo.png" width="200" alt="TotemWatch"></p>

# TotemWatch

Totem-Helfer für Schamanen in **WoW Forever**: zeigt im Kampf fehlende Totems und empfiehlt automatisch die passenden – nach Boss (Blizzard/DBM/BigWigs), Gruppe und Situation.

*Totem helper for Shamans in WoW Forever: shows missing totems in combat and recommends the right ones based on boss (DBM/BigWigs), group and situation. UI language: German.*

## Funktionen

- Totem-Leiste: Linksklick stellt, Rechtsklick öffnet die Auswahl; Farben für passt / läuft ab / besser / fehlt
- Exakte Restzeit im Kampf, Laufzeit je Rang wird automatisch gelernt
- Boss-Regeln (MC, Onyxia, BWL, ZG, AQ40, Naxx), Furcht-Warnungen, Gruppenzusammensetzung, AoE
- Warnungen: Vorwarnung vor Ablauf, Totem zerstört, Abstand zu den Totems, Reichweite der Gruppe
- Pull-Check bei Pull-Timer oder Bereitschaftscheck
- Knopf „ALLE“, Waffenverzauberung, Schild, Abklingzeiten, Tastenbelegung
- Erkennt Totems anderer Schamanen

## Befehle

`/tw` Optionen · `/tw test` Leiste anzeigen · `/tw check` Pull-Check · `/tw help` alle Befehle · `/tw debug`, `/tw probe` Diagnose

## Installation

Über CurseForge oder manuell: Ordner `TotemWatch` nach `World of Warcraft\<Forever-Ordner>\Interface\AddOns\` kopieren.

## Release erstellen (für Entwickler)

1. `## Version` wird automatisch aus dem Git-Tag gesetzt.
2. Eintrag in `CHANGELOG.md` ergänzen und committen.
3. Tag setzen und pushen:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
   GitHub Actions baut das ZIP, erstellt ein GitHub-Release und lädt es zu CurseForge hoch.

## Lizenz

MIT – siehe [LICENSE.txt](LICENSE.txt).
