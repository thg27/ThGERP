-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 26 – Rechnungspositionen als Haupt- und Unterpositionen (ersetzt das Textfeld Kapitel):
--      RPOS_HAUPT_RPOS_ID   Verweis der Unterposition auf ihre Hauptposition (leer = Hauptposition)
--      RPOS_SUMME_UNTERPOS  Hauptposition: Summe der nicht optionalen Unterpositionen (leer = keine Unterpositionen)
--      RPOS_PAUSCHALSUMME   Hauptposition: Pauschalsumme, gilt statt der berechneten Zwischensumme
--      RPOS_SUMME           Unterposition / Hauptposition ohne Unterpositionen: Menge x Einzelpreis abzgl. Rabatt
--                           Hauptposition mit Unterpositionen: Summe der Unterpositionen abzgl. Rabatt
--                           Hauptposition mit Pauschalsumme: die Pauschalsumme
--      RPOS_UK neu (RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_POSITION): Hauptpositionen 1, 2, 3 …,
--      Unterpositionen je Hauptposition 10, 20, 30 …
--      RPOS_KAPITEL und RPOS_UNTERKAPITEL entfallen.
--      Bestand (Testdaten): alle bisherigen Positionen werden Hauptpositionen ohne Unterpositionen und je
--      Rechnung in der bisherigen Reihenfolge (Kapitel, Position) neu mit 1, 2, 3 … nummeriert; Betraege bleiben.
-- Voraussetzung: 20; danach 21 (Package FAKT_RECHNUNG, View FAKT_RECHNUNG_MWST_V) und 24 (PDF) erneut ausfuehren
--                (beide create or replace).
-- Erzeugt: 2026-10-01
-- Wiederholbar.
-- =====================================================================

set define off
set serveroutput on size unlimited

declare
    c_tab constant varchar2(30) := 'FAKT_RECHNUNGSPOSITIONEN';
    c_uk  constant varchar2(100) := 'RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_POSITION';
    l_ist varchar2(4000);
    l_anz pls_integer;
begin
    DDL_UTIL.spalte(c_tab, 'RPOS_HAUPT_RPOS_ID', 'number', 'Y');
    DDL_UTIL.spalte(c_tab, 'RPOS_SUMME_UNTERPOS', 'number(12,2)', 'Y');
    DDL_UTIL.spalte(c_tab, 'RPOS_PAUSCHALSUMME', 'number(12,2)', 'Y');

    -- bisheriger Schluessel (Rechnung, Kapitel, Position) entfaellt; Bestand je Rechnung neu nummerieren
    select listagg(column_name, ', ') within group (order by position) into l_ist
      from user_cons_columns
     where constraint_name = 'RPOS_UK' and table_name = c_tab;
    if l_ist is not null and l_ist <> c_uk then
        execute immediate 'alter table ' || c_tab || ' drop constraint RPOS_UK drop index';
        dbms_output.put_line('RPOS_UK (' || l_ist || ') entfernt');
    end if;
    select count(*) into l_anz from user_tab_columns where table_name = c_tab and column_name = 'RPOS_KAPITEL';
    if l_anz > 0 then
        execute immediate q'~
            update FAKT_RECHNUNGSPOSITIONEN p
               set RPOS_POSITION = (select x.NR
                                      from (select RPOS_ID,
                                                   row_number() over (partition by RPOS_RECH_ID
                                                                      order by RPOS_KAPITEL nulls first, RPOS_POSITION) as NR
                                              from FAKT_RECHNUNGSPOSITIONEN) x
                                     where x.RPOS_ID = p.RPOS_ID)~';
        dbms_output.put_line(sql%rowcount || ' Positionen als Hauptpositionen neu nummeriert');
        execute immediate 'alter table ' || c_tab || ' drop (RPOS_KAPITEL, RPOS_UNTERKAPITEL)';
        dbms_output.put_line('RPOS_KAPITEL, RPOS_UNTERKAPITEL entfernt');
    end if;

    DDL_UTIL.constraint_(c_tab, 'RPOS_UK', 'U', c_uk);
    DDL_UTIL.constraint_(c_tab, 'RPOS_HAUPT_CK', 'C', q'~RPOS_HAUPT_RPOS_ID <> RPOS_ID~');
    DDL_UTIL.constraint_(c_tab, 'RPOS_PAUSCHAL_CK', 'C',
                         q'~RPOS_HAUPT_RPOS_ID is null or (RPOS_PAUSCHALSUMME is null and RPOS_SUMME_UNTERPOS is null)~');
    -- Hauptposition loeschen loescht ihre Unterpositionen
    DDL_UTIL.constraint_(c_tab, 'RPOS_HAUPT_RPOS_FK', 'R',
                         'RPOS_HAUPT_RPOS_ID references FAKT_RECHNUNGSPOSITIONEN (RPOS_ID) on delete cascade');
    DDL_UTIL.index_(c_tab, 'RPOS_HAUPT_RPOS_I', 'RPOS_HAUPT_RPOS_ID');
    DDL_UTIL.trigger_pruefen('RPOS_BIU', c_tab);
end;
/

-- Trigger wie in 20_fakturierung.sql (dort generiert)
create or replace trigger RPOS_BIU
  before insert or update on FAKT_RECHNUNGSPOSITIONEN
  for each row
begin
  if inserting then
    :new.RPOS_ID := coalesce(:new.RPOS_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.RPOS_CREATED_ON  := systimestamp;
    :new.RPOS_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RPOS_UPDATED_ON  := null;
    :new.RPOS_UPDATED_BY  := null;
    :new.RPOS_ROW_VERSION := 1;
  elsif updating then
    :new.RPOS_ID          := :old.RPOS_ID;  -- Primaerschluessel ist unveraenderlich
    :new.RPOS_CREATED_ON  := :old.RPOS_CREATED_ON;
    :new.RPOS_CREATED_BY  := :old.RPOS_CREATED_BY;
    :new.RPOS_UPDATED_ON  := systimestamp;
    :new.RPOS_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RPOS_ROW_VERSION := nvl(:old.RPOS_ROW_VERSION, 0) + 1;
  end if;
  -- Summe: Pauschalsumme, sonst Summe der Unterpositionen bzw. Menge x Einzelpreis, jeweils abzgl. Rabatt
  :new.RPOS_SUMME := coalesce(:new.RPOS_PAUSCHALSUMME,
                              round(coalesce(:new.RPOS_SUMME_UNTERPOS, :new.RPOS_MENGE * :new.RPOS_EINZELPREIS)
                                    * (1 - nvl(:new.RPOS_RABATT_PROZENT, 0) / 100), 2));
end RPOS_BIU;
/

comment on table FAKT_RECHNUNGSPOSITIONEN is 'Positionen der Ausgangsrechnungen (Haupt- und Unterpositionen) [Alias RPOS]';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_HAUPT_RPOS_ID is 'FK: Hauptposition (leer = diese Zeile ist selbst Hauptposition)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_POSITION is 'Positionsnummer: Hauptpositionen 1, 2, 3 …; Unterpositionen je Hauptposition 10, 20, 30 …';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_SUMME_UNTERPOS is 'Hauptposition: Summe der nicht optionalen Unterpositionen (leer = keine Unterpositionen; FAKT_RECHNUNG.summen_berechnen)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_PAUSCHALSUMME is 'Hauptposition: Pauschalsumme, gilt statt der berechneten Zwischensumme';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_SUMME is 'Summe (berechnet im Trigger): Menge x Einzelpreis bzw. Summe der Unterpositionen, abzgl. Rabatt; Hauptposition mit Pauschalsumme: die Pauschalsumme';

prompt Rechnungspositionen: Haupt- und Unterpositionen eingerichtet. Jetzt 21_finanz.sql und 24_rechnung_pdf.sql ausfuehren.
