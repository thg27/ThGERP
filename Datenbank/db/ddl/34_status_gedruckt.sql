-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 34 – Rechnungsstatus OFFEN aufgeteilt nach dem Versand: GEDRUCKT („Offen – gedruckt“, nach „Rechnung drucken“)
--      und GESENDET („Offen – gesendet“, nach dem E-Mail-Versand aus der Applikation – folgt). Beide zaehlen als offen
--      (FAKT_RECHNUNGEN_V: OFFEN, IST_UEBERFAELLIG; Storno; Zahlungsstatus behaelt GEDRUCKT/GESENDET ohne Zahlung).
--      Bisherige OFFEN-Rechnungen werden GEDRUCKT (ohne Eintrag in der Historie).
--      Package/View: Skript 21 erneut, Historien-Trigger: Skript 33 erneut.
-- Erzeugt: 2026-10-24
-- Wiederholbar.
-- =====================================================================

declare
    l_text varchar2(4000);
begin
    select search_condition_vc into l_text from user_constraints where constraint_name = 'RECH_STATUS_CK';
    if instr(l_text, 'GEDRUCKT') = 0 then
        execute immediate 'alter table FAKT_RECHNUNGEN drop constraint RECH_STATUS_CK';
    end if;
end;
/

-- Umstellung ohne Historie (kein "Geaendert" je Rechnung)
declare
    l_trg number;
begin
    select count(*) into l_trg from user_triggers where trigger_name = 'RECH_HIST_AIU';
    if l_trg > 0 then
        execute immediate 'alter trigger RECH_HIST_AIU disable';
    end if;
    update FAKT_RECHNUNGEN set RECH_STATUS = 'GEDRUCKT' where RECH_STATUS = 'OFFEN';
    dbms_output.put_line(sql%rowcount || ' Rechnungen OFFEN -> GEDRUCKT');
    commit;
    if l_trg > 0 then
        execute immediate 'alter trigger RECH_HIST_AIU enable';
    end if;
exception
    when others then
        if l_trg > 0 then
            execute immediate 'alter trigger RECH_HIST_AIU enable';
        end if;
        raise;
end;
/

declare
    l_anz number;
begin
    select count(*) into l_anz from user_constraints where constraint_name = 'RECH_STATUS_CK';
    if l_anz = 0 then
        execute immediate q'~alter table FAKT_RECHNUNGEN add constraint RECH_STATUS_CK
                             check (RECH_STATUS in ('ENTWURF', 'GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT', 'STORNIERT'))~';
    end if;
end;
/
comment on column FAKT_RECHNUNGEN.RECH_STATUS is 'ENTWURF, GEDRUCKT, GESENDET, TEILBEZAHLT, BEZAHLT, STORNIERT';

@@21_finanz.sql
@@33_rechnung_historie.sql

-- die neu angelegte View invalidiert das Druckpaket
alter package FAKT_RECHNUNG_PDF compile;

prompt Status GEDRUCKT/GESENDET installiert.
