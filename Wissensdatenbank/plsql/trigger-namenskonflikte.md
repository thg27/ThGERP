# Namenskonflikte bei Triggern/Constraints vor Installation prüfen

## Kontext
`create or replace trigger` ersetzt einen gleichnamigen Trigger ohne Warnung – auch wenn er zu einer anderen Tabelle oder einem anderen Projekt gehört. Constraint- und Indexnamen führen dagegen zu einem Fehler.

## Vorgehen
Vor jeder Installation in ein bestehendes Schema prüfen:
```sql
select object_type, object_name
from   user_objects
where  object_name in ( /* Namen aus dem Skript */ );

select constraint_name, table_name
from   user_constraints
where  constraint_name in ( ... );
```

## Stolpersteine
- Besonders heikel im Schema `WKSP_THGERP`, weil dieselbe APEX-Instanz auch den Workspace SIPA (Kundenprojekt) enthält.


## Quelle / Stand

Aus der Projektarbeit ThGERP, Stand 2026-09-26.
