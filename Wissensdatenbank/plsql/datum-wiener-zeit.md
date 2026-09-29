# Tagesdatum in Wiener Zeit statt sysdate

## Problem
Der Datenbankserver (dbthgprod) läuft in **UTC**. `sysdate`/`systimestamp` liefern Serverzeit – zwischen Mitternacht
und 1:00 (Winterzeit) bzw. 2:00 (Sommerzeit) in Österreich noch den **Vortag**. Beobachtet 2026-09-30 01:05 Wien:
`sysdate` = 29.09.2026 23:05.

`current_date` hängt von der Sitzungs-Zeitzone ab (SQLcl: Europe/Vienna, APEX-Sitzung: je nach Einstellung) –
nicht verlässlich für Standardwerte und Packages.

## Lösung
Tagesdatum immer so ermitteln:

```sql
trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))
```

Verwendet in: Spalten-Standardwerten (`RECH_DATUM`, `ARTI_AUFGENOMMEN_AM`), `FAKT_RECHNUNG.abschliessen`
(Rechnungsdatum = Tag des Abschließens), `FAKT_RECHNUNGEN_V.IST_UEBERFAELLIG`, APEX-Vorbelegungen.

## Stolpersteine
- Nach dem Ändern eines Spalten-Standardwerts wird das Package, das die Tabelle nutzt, ungültig →
  `alter package … compile body` und `user_objects` auf ungültige Objekte prüfen.
- Audit-Spalten (`*_CREATED_ON` = `systimestamp`) bleiben in UTC – für Zeitstempel unkritisch, bei Anzeige ggf.
  umrechnen.

## Quelle / Stand
Rechnungsdatum Finanz-App, 2026-09-30.
