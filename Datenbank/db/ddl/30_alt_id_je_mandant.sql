-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 30 – Kingbill-IDs je Mandant: jeder Mandant hatte eine eigene Kingbill-Datenbank (ThG-edv GmbH, Thomas
--      Gesslbauer GmbH), deren IDs sich ueberschneiden. RECH_ALT_ID ist daher nur je Mandant eindeutig
--      (Unique-Index RECH_ALT_ID_UI nur ueber Zeilen mit RECH_ALT_ID); ZAHL_ALT_ID nur noch indiziert.
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
    -- nicht als Constraint auf (RECH_MAND_ID, RECH_ALT_ID): Oracle vergleicht zusammengesetzte Schluessel auch, wenn nur
    -- RECH_ALT_ID leer ist - je Mandant waere nur eine neue Rechnung (ohne Altsystem-ID) moeglich (ORA-00001).
    -- Stattdessen funktionsbasierter Unique-Index nur ueber Zeilen mit Altsystem-ID.
    if l_spalten is not null then
        execute immediate 'alter table FAKT_RECHNUNGEN drop constraint RECH_ALT_ID_UK drop index';
        dbms_output.put_line('RECH_ALT_ID_UK entfernt');
    end if;
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_ALT_ID_UI',
                    q'~case when RECH_ALT_ID is not null then RECH_MAND_ID end, RECH_ALT_ID~', true);
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
