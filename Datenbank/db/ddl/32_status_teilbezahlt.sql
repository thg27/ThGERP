-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 32 – Rechnungsstatus TEILBEZAHLT (teilweise bezahlt; RECH_STATUS dafuer varchar2(15 char)): FAKT_RECHNUNG.zahlungsstatus setzt OFFEN (keine Zahlung),
--      TEILBEZAHLT (Zahlungen kleiner als der Gesamtbetrag) bzw. BEZAHLT; teilbezahlte Rechnungen zaehlen als offen
--      (FAKT_RECHNUNGEN_V: OFFEN, IST_UEBERFAELLIG). Package und View: Skript 21 erneut ausfuehren.
-- Erzeugt: 2026-10-24
-- Wiederholbar.
-- =====================================================================

declare
    l_text varchar2(4000);
    l_len  number;
begin
    select char_length into l_len from user_tab_columns where table_name = 'FAKT_RECHNUNGEN' and column_name = 'RECH_STATUS';
    if l_len < 15 then
        execute immediate 'alter table FAKT_RECHNUNGEN modify (RECH_STATUS varchar2(15 char))';
    end if;
    select search_condition_vc into l_text from user_constraints where constraint_name = 'RECH_STATUS_CK';
    if instr(l_text, 'TEILBEZAHLT') = 0 then
        execute immediate 'alter table FAKT_RECHNUNGEN drop constraint RECH_STATUS_CK';
        execute immediate q'~alter table FAKT_RECHNUNGEN add constraint RECH_STATUS_CK
                             check (RECH_STATUS in ('ENTWURF', 'OFFEN', 'TEILBEZAHLT', 'BEZAHLT', 'STORNIERT'))~';
    end if;
end;
/
comment on column FAKT_RECHNUNGEN.RECH_STATUS is 'ENTWURF, OFFEN, TEILBEZAHLT, BEZAHLT, STORNIERT';

@@21_finanz.sql

-- bestehende Rechnungen neu einstufen
begin
    for r in (select RECH_ID from FAKT_RECHNUNGEN where RECH_STATUS in ('OFFEN', 'TEILBEZAHLT', 'BEZAHLT')) loop
        FAKT_RECHNUNG.zahlungsstatus(r.RECH_ID);
    end loop;
    commit;
end;
/

-- die neu angelegte View invalidiert das Druckpaket
alter package FAKT_RECHNUNG_PDF compile;

prompt Status TEILBEZAHLT installiert.
