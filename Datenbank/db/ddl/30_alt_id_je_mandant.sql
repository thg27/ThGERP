-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 30 – Kingbill-IDs je Mandant: jeder Mandant hatte eine eigene Kingbill-Datenbank (ThG-edv GmbH, Thomas
--      Gesslbauer GmbH), deren IDs sich ueberschneiden. RECH_ALT_ID ist daher nur je Mandant eindeutig
--      (RECH_ALT_ID_UK auf RECH_MAND_ID, RECH_ALT_ID); ZAHL_ALT_ID nur noch indiziert (Zahlung gehoert zur Rechnung).
--      Neuinstallationen legen die Constraints so an (Skript 20).
-- Erzeugt: 2026-10-24
-- Wiederholbar.
-- =====================================================================

set serveroutput on size unlimited

declare
    l_spalten varchar2(200);
    l_n       pls_integer;
begin
    select listagg(column_name, ',') within group (order by position) into l_spalten
      from user_cons_columns where constraint_name = 'RECH_ALT_ID_UK';
    if l_spalten = 'RECH_ALT_ID' then
        execute immediate 'alter table FAKT_RECHNUNGEN drop constraint RECH_ALT_ID_UK drop index';
        execute immediate 'alter table FAKT_RECHNUNGEN add constraint RECH_ALT_ID_UK unique (RECH_MAND_ID, RECH_ALT_ID)';
        dbms_output.put_line('RECH_ALT_ID_UK je Mandant');
    end if;
    select count(*) into l_n from user_constraints where constraint_name = 'ZAHL_ALT_ID_UK';
    if l_n > 0 then
        execute immediate 'alter table FAKT_ZAHLUNGEN drop constraint ZAHL_ALT_ID_UK drop index';
        dbms_output.put_line('ZAHL_ALT_ID_UK entfernt');
    end if;
    select count(*) into l_n from user_indexes where index_name = 'ZAHL_ALT_ID_I';
    if l_n = 0 then
        execute immediate 'create index ZAHL_ALT_ID_I on FAKT_ZAHLUNGEN (ZAHL_ALT_ID)';
        dbms_output.put_line('ZAHL_ALT_ID_I angelegt');
    end if;
end;
/

prompt Kingbill-IDs je Mandant.
