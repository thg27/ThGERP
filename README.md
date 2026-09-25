# ThGERP

ERP-System für die **THG-EDV GmbH** und die **Thomas Geßlbauer GmbH** – Oracle-Datenbank und APEX-Anwendungen.

## Struktur

| Ordner | Inhalt |
|---|---|
| `Apex/thg-portal` | Portal-App (Master für Shared Components / LOVs) |
| `Apex/thg-allgemein` | Allgemeine Stammdaten (ALLG) |
| `Apex/thg-kunden` | Kundenstamm (KUND) |
| `Apex/thg-admin` | Administration (ADMIN): Applikationen/Portal-Kacheln, Aktivitätsprotokoll |
| `Apex/strategic-planner` | Vorlage/Basis (Projekte, Initiativen, KI-Zusammenfassungen) – nur lokal, nicht in Git |
| `Apex/workspace-files` | Gemeinsames CSS (`thg.css`), Logo (`thg-logo.svg`) + Installationsskript |
| `Apex/generator` | Generator für Wertelisten-Seiten |
| `EmployeePortal` | APEX-App Employee Portal |
| `Datenbank/db/ddl` | Installationsskripte Datenmodell (`00_install.sql`) |
| `Datenbank/db/er-modell` | ER-Modell (Mermaid-Quelle `.mmd` + PDF/SVG/PNG/HTML) |
| `Datenbank/db/lib` | Bibliotheken (as_pdf) |
| `Datenbank/db/test` | Testdaten-Skripte |

## Konventionen

- Tabellen: `<GRUPPE>_<NAME>`, Spalten: `<ALIAS>_<NAME>` (4-stelliger Alias, Registry `Datenbank/db/aliase.md`)
- Spaltenreihenfolge: PK, FK, Fachspalten, Audit-Spalten
- PK per Trigger aus `SYS_GUID`, Audit-Spalten per Trigger `<ALIAS>_BIU`

Skripte nur auf DEV-Verbindungen ausführen.
