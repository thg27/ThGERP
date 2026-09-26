# Wissensdatenbank ThGERP

Gesammeltes Praxiswissen aus der Entwicklung des ERP-Systems: Lösungen, Muster, Stolpersteine und Abläufe.
Projektregeln (verbindlich) stehen in `CLAUDE.md`; hier steht das *Wie* und *Warum* dahinter.

## Bereiche

| Ordner | Inhalt |
|---|---|
| `oracle-sql/` | SQL-Muster, Abfragen, Data-Dictionary-Views, 26ai-Besonderheiten |
| `plsql/` | Packages, Trigger, Fehlerbehandlung, Code-Muster |
| `apex/` | APEX-Entwicklung: Shared Components, Subscriptions, APEXlang, Theme, Workspace-Dateien |
| `sqlcl/` | SQLcl-Befehle, Verbindungen, `apex validate` / `apex import`, Liquibase |
| `ords/` | ORDS, REST-Services, Deployment |
| `git-github/` | Git-Workflow, Repository ThGERP, .gitignore, Commits |
| `datenmodell/` | Modellierungsentscheidungen, Namenskonventionen, ER-Modell-Erzeugung |
| `troubleshooting/` | Fehlermeldungen (ORA-, APEX-, SQLcl-) mit Ursache und Lösung |

## Konventionen für Einträge

- Eine Datei pro Thema, Dateiname klein mit Bindestrichen: `lov-subscriptions.md`
- Aufbau: **Kontext** → **Lösung/Vorgehen** (mit Code) → **Stolpersteine** → **Quelle/Stand** (Datum, Version)
- Jeder Bereich hat eine `README.md` mit Index – neue Einträge dort eintragen
- Fehlermeldungen unter `troubleshooting/` mit exaktem Fehlercode im Titel, damit sie per Suche auffindbar sind
- Keine Passwörter, Wallets oder Kundendaten
