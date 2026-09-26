# Fortlaufende Belegnummern je Mandant (lückenlos, nur letzte löschbar)

## Kontext
Rechnungsnummern müssen je Mandant und Jahr fortlaufend sein und dürfen nicht manuell geändert werden;
die jeweils letzte Rechnung darf (mit Sicherheitsabfrage) gelöscht werden – ihre Nummer wird wieder frei.

## Lösung
- Nummernkreis-Tabelle `FAKT_NUMMERNKREISE` (Mandant, Belegart, Jahr, Format `{JAHR} - {NR}`, letzte Nummer);
  Vergabe mit `select … for update` (keine Sequence → lückenlos, transaktionssicher).
- Nummer erst beim **Abschließen** vergeben (`FAKT_RECHNUNG.abschliessen`), Entwürfe haben keine Nummer.
- Package-Variable `FAKT_RECHNUNG.g_intern`: nur während das Package Nummern vergibt/zurücksetzt `TRUE`.
  Trigger `RECH_NUMMER_BUD` und `NKRS_NUMMER_BU` lehnen jede Änderung ab, wenn `g_intern` nicht gesetzt ist.
- `FAKT_RECHNUNG.ist_letzte(id)` vergleicht die Rechnungsnummer mit der formatierten letzten Nummer des
  Nummernkreises; `loeschen(id)` löscht Entwurf oder letzte Rechnung und zählt den Nummernkreis zurück.

## Stolpersteine
- `g_intern` in jedem Ausnahmezweig wieder auf `FALSE` setzen (`exception when others then g_intern := false; raise;`).
- Beim Löschen `g_intern` **vor** den `delete`-Anweisungen setzen – der Trigger prüft auch `deleting`.
- Skalare Unterabfragen sind in PL/SQL-Ausdrücken nicht erlaubt (`l_x number := (select …)` → PLS-00103);
  `select … into` verwenden.
- Tests mit echten Daten in einer Transaktion und am Ende `rollback` – der Nummernkreis bleibt unverändert.

## Quelle / Stand
21_finanz.sql, 22_finanz_nummernschutz.sql, 2026-09-26.
