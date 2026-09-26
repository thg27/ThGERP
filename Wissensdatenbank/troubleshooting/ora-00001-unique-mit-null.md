# ORA-00001 bei zweispaltigem Unique-Constraint mit NULL

## Kontext
`FAKT_RECHNUNGEN` hatte `RECH_NUMMER_UK unique (RECH_MAND_ID, RECH_NUMMER)`. Entwürfe haben noch keine Nummer.
Beim zweiten Entwurf desselben Mandanten: `ORA-00001: Unique Constraint (RECH_NUMMER_UK) verletzt`.

## Ursache
Oracle ignoriert eine Zeile im Unique-Index nur, wenn **alle** Spalten NULL sind. (Mandant, NULL) und
(Mandant, NULL) gelten als gleich.

## Lösung
Funktionsbasierter Unique-Index, der nur Zeilen mit Nummer erfasst:

```sql
create unique index RECH_NUMMER_UI on FAKT_RECHNUNGEN
  (case when RECH_NUMMER is not null then RECH_MAND_ID end, RECH_NUMMER);
```
Den alten Constraint mit `alter table … drop constraint RECH_NUMMER_UK drop index` entfernen und im
Generator/Installationsskript ersetzen, sonst legt ein erneuter Lauf ihn wieder an.

## Quelle / Stand
22_finanz_nummernschutz.sql, 2026-09-26.
