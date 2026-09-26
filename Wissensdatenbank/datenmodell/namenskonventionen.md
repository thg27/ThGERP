# Namenskonventionen Tabellen/Spalten/Aliase

- Tabellen: `<GRUPPE>_<NAME>` – Gruppen: `KUND`, `ALLG`, `ADMIN` (bewusst 5-stellig), `ARTI`, `FAKT`
- Spalten: `<ALIAS>_<NAME>`, Alias 4-stellig, Registry in `Datenbank/db/aliase.md` (vor jeder neuen Tabelle prüfen und eintragen)
- Spaltenreihenfolge: PK, FK, Fachspalten, Audit-Spalten
- PK per Trigger aus `SYS_GUID`, Audit-Spalten per Trigger `<ALIAS>_BIU`
- Zieldatenbank Oracle AI Database 26ai → Objektnamen bis 128 Zeichen

Verbindlich ist der Skill `thg-oracle-db-standards`.


## Quelle / Stand

Aus der Projektarbeit ThGERP, Stand 2026-09-26.
