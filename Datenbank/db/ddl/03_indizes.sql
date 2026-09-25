-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 03 – Fachliche Unique-Indizes und Suchindizes
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

-- Hoechstens ein Hauptsitz je Kunde
create unique index KSTO_HAUPTSITZ_UI on KUND_STANDORTE (case when KSTO_IST_HAUPTSITZ = 'Y' then KSTO_KUND_ID end);

-- Hoechstens ein bevorzugter Eintrag je Mitarbeiter und Kommunikationsart
create unique index MKOM_BEVORZUGT_UI on ALLG_MITARBEITER_KOMMUNIKATION (case when MKOM_IST_BEVORZUGT = 'Y' then MKOM_MITA_ID end, case when MKOM_IST_BEVORZUGT = 'Y' then MKOM_KART_ID end);

-- Hoechstens ein bevorzugter Eintrag je Standort und Kommunikationsart
create unique index SKOM_BEVORZUGT_UI on KUND_STANDORT_KOMMUNIKATION (case when SKOM_IST_BEVORZUGT = 'Y' then SKOM_KSTO_ID end, case when SKOM_IST_BEVORZUGT = 'Y' then SKOM_KART_ID end);

-- Hoechstens ein bevorzugter Eintrag je Ansprechpartner und Kommunikationsart
create unique index AKOM_BEVORZUGT_UI on KUND_ANSPRECHPARTNER_KOMMUNIKATION (case when AKOM_IST_BEVORZUGT = 'Y' then AKOM_ANSP_ID end, case when AKOM_IST_BEVORZUGT = 'Y' then AKOM_KART_ID end);

-- Hoechstens ein aktueller Hauptverantwortlicher je Kunde und Rolle
create unique index KMIT_HAUPTVERANTW_UI on KUND_KUNDEN_MITARBEITER (case when KMIT_IST_HAUPTVERANTW = 'Y' and KMIT_GUELTIG_BIS is null then KMIT_KUND_ID end, case when KMIT_IST_HAUPTVERANTW = 'Y' and KMIT_GUELTIG_BIS is null then KMIT_BROL_ID end);

-- Jede Registeradresse (inkl. Zusatz) nur einmal
create unique index ADRE_REGISTER_UI on ALLG_ADRESSEN (case when ADRE_QUELLE = 'REGISTER' then ADRE_AREG_ADRCD end, case when ADRE_QUELLE = 'REGISTER' then nvl(ADRE_ZUSATZ, '#') end);

-- Suche im Adressregister (LOV)
create index AREG_SUCHE_I on ALLG_ADRESSREGISTER (AREG_PLZ, AREG_STRASSE, AREG_HAUSNUMMER);

-- Suche nach Firmenname
create index KUND_FIRMENNAME_I on KUND_KUNDEN (upper(KUND_FIRMENNAME));

-- Suche nach Nachname
create index KUND_NACHNAME_I on KUND_KUNDEN (upper(KUND_NACHNAME));
