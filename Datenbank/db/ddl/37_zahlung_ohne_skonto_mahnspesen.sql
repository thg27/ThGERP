-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 37 – Zahlungseingang ohne Skonto und Mahnspesen: Spalten ZAHL_SKONTO und ZAHL_MAHNSPESEN entfernt (werden nicht
--      gebraucht, waren in keiner Zahlung befuellt). Bezahlt/Offen/Status rechnen nur noch mit ZAHL_BETRAG.
--      Package/View: Skript 21 erneut, Historien-Trigger: Skript 33 erneut.
-- Erzeugt: 2026-10-25
-- Wiederholbar.
-- =====================================================================

declare
    l_anz number;
begin
    for c in (select column_name from user_tab_columns
               where table_name = 'FAKT_ZAHLUNGEN' and column_name in ('ZAHL_SKONTO', 'ZAHL_MAHNSPESEN')) loop
        execute immediate 'select count(*) from FAKT_ZAHLUNGEN where nvl(' || c.column_name || ', 0) <> 0' into l_anz;
        if l_anz > 0 then
            raise_application_error(-20001, c.column_name || ' ist in ' || l_anz || ' Zahlungen befuellt – nicht entfernt.');
        end if;
        execute immediate 'alter table FAKT_ZAHLUNGEN drop column ' || c.column_name;
        dbms_output.put_line(c.column_name || ' entfernt');
    end loop;
end;
/

@@21_finanz.sql
@@33_rechnung_historie.sql

-- die neu angelegte View invalidiert das Druckpaket
alter package FAKT_RECHNUNG_PDF compile;

prompt Zahlung ohne Skonto/Mahnspesen installiert.
