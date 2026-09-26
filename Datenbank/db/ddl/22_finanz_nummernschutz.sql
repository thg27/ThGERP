-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 22 – Schutz der Rechnungsnummern (fortlaufend je Mandant, nicht manuell aenderbar):
--      FAKT_RECHNUNGEN: Nummer und Mandant einer abgeschlossenen Rechnung unveraenderlich,
--                       Nummer nur ueber FAKT_RECHNUNG.abschliessen; Loeschen nur ueber FAKT_RECHNUNG.loeschen
--      FAKT_NUMMERNKREISE: zuletzt vergebene Nummer nur ueber das Package FAKT_RECHNUNG
-- Voraussetzung: 20, 21 (Package FAKT_RECHNUNG mit g_intern)
-- Erzeugt: 2026-09-26
-- Wiederholbar (Trigger-Namen werden vorher geprueft).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.trigger_pruefen('RECH_NUMMER_BUD', 'FAKT_RECHNUNGEN');
    DDL_UTIL.trigger_pruefen('NKRS_NUMMER_BU', 'FAKT_NUMMERNKREISE');
end;
/

create or replace trigger RECH_NUMMER_BUD
  before update or delete on FAKT_RECHNUNGEN
  for each row
begin
  if FAKT_RECHNUNG.g_intern then
    return;
  end if;
  if updating then
    if :old.RECH_NUMMER is not null
       and (:new.RECH_NUMMER is null or :new.RECH_NUMMER <> :old.RECH_NUMMER or :new.RECH_MAND_ID <> :old.RECH_MAND_ID) then
      raise_application_error(-20230, 'Rechnungsnummer und Mandant einer abgeschlossenen Rechnung können nicht geändert werden.');
    end if;
    if :old.RECH_NUMMER is null and :new.RECH_NUMMER is not null then
      raise_application_error(-20231, 'Die Rechnungsnummer wird beim Abschließen fortlaufend vergeben und kann nicht manuell gesetzt werden.');
    end if;
  elsif deleting and :old.RECH_STATUS <> 'ENTWURF' then
    raise_application_error(-20232, 'Abgeschlossene Rechnungen nur über „Rechnung löschen“ (nur die letzte Rechnung).');
  end if;
end RECH_NUMMER_BUD;
/

create or replace trigger NKRS_NUMMER_BU
  before update on FAKT_NUMMERNKREISE
  for each row
begin
  if not FAKT_RECHNUNG.g_intern and :new.NKRS_LETZTE_NUMMER <> :old.NKRS_LETZTE_NUMMER then
    raise_application_error(-20233, 'Die zuletzt vergebene Nummer wird nur beim Abschließen bzw. Löschen der letzten Rechnung geändert.');
  end if;
end NKRS_NUMMER_BU;
/

prompt Schutz der Rechnungsnummern installiert.
