# ORA-03049: RETURNING bei INSERT … SELECT

## Kontext
Beim Anlegen eines Datensatzes wird die neue ID gebraucht, die Werte kommen aber teils aus einer Abfrage
(z. B. Adressquelle aus `ALLG_LAENDER`):

```sql
insert into ALLG_ADRESSEN (ADRE_LAND_CODE, ADRE_QUELLE, ADRE_PLZ, ADRE_ORT)
select LAND_CODE, 'MANUELL', :PLZ, :ORT from ALLG_LAENDER where LAND_CODE = :LAND
returning ADRE_ID into l_id;
-- PL/SQL: ORA-03049: SQL-Schlüsselwort "RETURNING" … ergibt keine gültige Syntax
```

## Lösung
`RETURNING … INTO` gibt es nur bei `INSERT … VALUES` (sowie UPDATE/DELETE). Werte vorher in Variablen lesen:

```sql
select case LAND_HAT_REGISTER when 'Y' then 'MIGRATION' else 'MANUELL' end
  into l_quelle
  from ALLG_LAENDER where LAND_CODE = :LAND;
insert into ALLG_ADRESSEN (ADRE_LAND_CODE, ADRE_QUELLE, ADRE_PLZ, ADRE_ORT)
values (:LAND, l_quelle, :PLZ, :ORT)
returning ADRE_ID into l_id;
```

## Stolpersteine
- Syntax ohne Schreibzugriff prüfen: Anweisung in `if 1 = 0 then … end if;` packen – der Block wird übersetzt, aber nicht ausgeführt.

## Quelle / Stand
Geprüft auf Oracle AI Database 23.26.1 (pdbthg), 2026-09-26 (App 20030, Seite 21 Mandant).
