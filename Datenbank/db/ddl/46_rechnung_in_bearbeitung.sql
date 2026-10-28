-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 46 – Rechnungsstatus IN_BEARBEITUNG („In Bearbeitung“): „Rechnung bearbeiten“ setzt eine offene Rechnung ohne Zahlung
--      (GEDRUCKT/GESENDET) dauerhaft in Bearbeitung (bisher nur fuer die Sitzung); Nummer und Datum bleiben.
--      „Rechnung drucken“ schliesst die Bearbeitung ab (wieder GEDRUCKT, neue Dokumentversion).
--      In Bearbeitung zaehlt als offen (FAKT_RECHNUNGEN_V: OFFEN, IST_UEBERFAELLIG), Zahlungen sind gesperrt
--      (Trigger ZAHL_STATUS_AIUD, FAKT_BANK.zuordnen); mit Zahlung ist kein Bearbeiten mehr moeglich.
--      Package/View: Skript 21, Zahlungs-Trigger: 31, Historie (Aktionen Zur Bearbeitung geoeffnet /
--      Bearbeitung abgeschlossen): 33, Bankabgleich: 39 – jeweils erneut.
-- Erzeugt: 2026-10-28
-- Wiederholbar.
-- =====================================================================

declare
    l_text varchar2(4000);
begin
    select max(search_condition_vc) into l_text from user_constraints where constraint_name = 'RECH_STATUS_CK';
    if l_text is not null and instr(l_text, 'IN_BEARBEITUNG') = 0 then
        execute immediate 'alter table FAKT_RECHNUNGEN drop constraint RECH_STATUS_CK';
        l_text := null;
    end if;
    if l_text is null then
        execute immediate q'~alter table FAKT_RECHNUNGEN add constraint RECH_STATUS_CK
                             check (RECH_STATUS in ('ENTWURF', 'GEDRUCKT', 'GESENDET', 'IN_BEARBEITUNG', 'TEILBEZAHLT', 'BEZAHLT', 'STORNIERT'))~';
    end if;
end;
/
comment on column FAKT_RECHNUNGEN.RECH_STATUS is 'ENTWURF, GEDRUCKT, GESENDET, IN_BEARBEITUNG, TEILBEZAHLT, BEZAHLT, STORNIERT';

@@21_finanz.sql
@@31_zahlungsstatus_trigger.sql
@@33_rechnung_historie.sql
@@39_bankabgleich.sql

-- geaenderte Spezifikation/View invalidiert abhaengige Pakete und Views
begin
    for o in (select object_name, object_type from user_objects
               where status <> 'VALID' and object_type in ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'TRIGGER')
               order by case object_type when 'VIEW' then 1 when 'PACKAGE' then 2 when 'PACKAGE BODY' then 3 else 4 end) loop
        begin
            execute immediate 'alter ' || case o.object_type when 'PACKAGE BODY' then 'package' else lower(o.object_type) end
                              || ' "' || o.object_name || '" compile' || case o.object_type when 'PACKAGE BODY' then ' body' end;
        exception
            when others then
                dbms_output.put_line(o.object_type || ' ' || o.object_name || ': ' || sqlerrm);
        end;
    end loop;
end;
/

prompt Status IN_BEARBEITUNG installiert.
