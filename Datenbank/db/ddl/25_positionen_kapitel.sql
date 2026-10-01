-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 25 – Rechnungspositionen je Kapitel nummerieren:
--      Das Kapitel gruppiert die Positionen; innerhalb eines Kapitels laufen die Positionsnummern in
--      Zehnerschritten ab 10. Positionen ohne Kapitel stehen am Anfang der Rechnung.
--      RPOS_UK: bisher (RPOS_RECH_ID, RPOS_POSITION), neu (RPOS_RECH_ID, RPOS_KAPITEL, RPOS_POSITION).
--      Oracle behandelt (Rechnung, NULL, 10) und (Rechnung, NULL, 10) als gleich – auch ohne Kapitel
--      bleibt die Position eindeutig.
-- Voraussetzung: 20; danach 21 (FAKT_RECHNUNG.naechste_position) und 24 (PDF sortiert nach Kapitel, Position)
--                erneut ausfuehren (beide create or replace).
-- Erzeugt: 2026-10-01
-- Wiederholbar. Bestehende Positionsnummern bleiben unveraendert (rechnungsweit eindeutig ist auch je Kapitel eindeutig).
-- =====================================================================

set define off
set serveroutput on size unlimited

declare
    l_ist varchar2(4000);
begin
    select listagg(column_name, ', ') within group (order by position) into l_ist
      from user_cons_columns
     where constraint_name = 'RPOS_UK' and table_name = 'FAKT_RECHNUNGSPOSITIONEN';
    if l_ist is not null and l_ist <> 'RPOS_RECH_ID, RPOS_KAPITEL, RPOS_POSITION' then
        execute immediate 'alter table FAKT_RECHNUNGSPOSITIONEN drop constraint RPOS_UK drop index';
        dbms_output.put_line('RPOS_UK (' || l_ist || ') entfernt');
    end if;
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_UK', 'U', 'RPOS_RECH_ID, RPOS_KAPITEL, RPOS_POSITION');
end;
/

comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_POSITION is 'Positionsnummer innerhalb des Kapitels (10er-Schritte)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_KAPITEL is 'Kapitel (Gruppierung auf der Rechnung; leer = am Anfang der Rechnung)';

prompt RPOS_UK: Position eindeutig je Rechnung und Kapitel.
