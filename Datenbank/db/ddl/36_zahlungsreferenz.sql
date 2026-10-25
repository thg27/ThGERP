-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 36 – Zahlungsreferenz je Zahlungseingang (FAKT_ZAHLUNGEN.ZAHL_REFERENZ, 140 Zeichen wie der SEPA-Verwendungszweck):
--      Eingabe im Dialog "Zahlungseingang" (THG-FINANZ Seite 16); dient spaeter der automatischen Zuordnung von
--      Bankumsaetzen (Index ZAHL_REFERENZ_I). Historien-Trigger: Skript 33 erneut (Referenz in der Historie).
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL).
-- =====================================================================

begin
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_REFERENZ', 'varchar2(140 char)', 'Y');
    DDL_UTIL.index_('FAKT_ZAHLUNGEN', 'ZAHL_REFERENZ_I', 'ZAHL_REFERENZ');
end;
/
comment on column FAKT_ZAHLUNGEN.ZAHL_REFERENZ is 'Zahlungsreferenz (Verwendungszweck/Referenz der Bank) fuer die automatische Zuordnung';

@@33_rechnung_historie.sql

prompt Zahlungsreferenz installiert.
