-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 14 – Vorbereitung Altdatenuebernahme (TBL_*):
--      * Alt-ID-Spalten fuer wiederholbare Uebernahme: KSTO_ALT_ID (TBL_ADRESSE), SKOM_ALT_ID
--        (TBL_KUNDEN_KOMMUNIKATION), AKOM_ALT_ID (TBL_ANSPRECHPERSON_KOMM), KBRA_ALT_ID
--        (TBL_KUNDE_BRANCHE), KUKA_ALT_ID (TBL_KUNDE_UNTERKATEGORIE)
--      * Land XX = unbekannt (Altadressen ohne bzw. mit unbekanntem Land)
--      * Standorttypen Rechnungsadresse, Lieferadresse
-- Erzeugt: 2026-09-25
-- Wiederholbar (nutzt DDL_UTIL, Grunddaten nur fehlende Zeilen).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.spalte('KUND_STANDORTE', 'KSTO_ALT_ID', 'number');
    DDL_UTIL.constraint_('KUND_STANDORTE', 'KSTO_ALT_ID_UK', 'U', 'KSTO_ALT_ID');
    DDL_UTIL.spalte('KUND_STANDORT_KOMMUNIKATION', 'SKOM_ALT_ID', 'number');
    DDL_UTIL.constraint_('KUND_STANDORT_KOMMUNIKATION', 'SKOM_ALT_ID_UK', 'U', 'SKOM_ALT_ID');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER_KOMMUNIKATION', 'AKOM_ALT_ID', 'number');
    DDL_UTIL.constraint_('KUND_ANSPRECHPARTNER_KOMMUNIKATION', 'AKOM_ALT_ID_UK', 'U', 'AKOM_ALT_ID');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_ALT_ID', 'number');
    DDL_UTIL.constraint_('KUND_KUNDEN_BRANCHEN', 'KBRA_ALT_ID_UK', 'U', 'KBRA_ALT_ID');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_ALT_ID', 'number');
    DDL_UTIL.constraint_('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_ALT_ID_UK', 'U', 'KUKA_ALT_ID');
end;
/

comment on column KUND_STANDORTE.KSTO_ALT_ID is 'ID im Altsystem (TBL_ADRESSE.ADRE_ID), fuer die Datenuebernahme';
comment on column KUND_STANDORT_KOMMUNIKATION.SKOM_ALT_ID is 'ID im Altsystem (TBL_KUNDEN_KOMMUNIKATION.KUKO_ID), fuer die Datenuebernahme';
comment on column KUND_ANSPRECHPARTNER_KOMMUNIKATION.AKOM_ALT_ID is 'ID im Altsystem (TBL_ANSPRECHPERSON_KOMM.APKO_ID), fuer die Datenuebernahme';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_ALT_ID is 'ID im Altsystem (TBL_KUNDE_BRANCHE.KUBR_ID), fuer die Datenuebernahme';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_ALT_ID is 'ID im Altsystem (TBL_KUNDE_UNTERKATEGORIE.KUUK_ID), fuer die Datenuebernahme';

insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER)
  select 'XX', 'unbekannt', 'N', 'N' from dual where not exists (select 1 from ALLG_LAENDER where LAND_CODE = 'XX');
insert into KUND_STANDORT_TYPEN (STYP_BEZEICHNUNG)
  select 'Rechnungsadresse' from dual where not exists (select 1 from KUND_STANDORT_TYPEN where STYP_BEZEICHNUNG = 'Rechnungsadresse');
insert into KUND_STANDORT_TYPEN (STYP_BEZEICHNUNG)
  select 'Lieferadresse' from dual where not exists (select 1 from KUND_STANDORT_TYPEN where STYP_BEZEICHNUNG = 'Lieferadresse');
commit;

prompt Vorbereitung Altdatenuebernahme abgeschlossen.
