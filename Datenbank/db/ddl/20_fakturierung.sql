-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 20 – Fakturierung: Ausgangsrechnungen, abgeleitet aus der Kingbill-Rechnungseingabe
--      neu: FAKT_NUMMERNKREISE, FAKT_RECHNUNGEN, FAKT_RECHNUNGSPOSITIONEN, FAKT_ZAHLUNGEN
--      Grunddaten: Nummernkreise 2026 (EDV zuletzt 13, TG zuletzt 199)
-- Voraussetzung: 17/18 (Mandanten), 19 (Artikelstamm)
-- GENERIERT mit generator/gen_19_20_artikel_fakturierung.py – nicht von Hand bearbeiten
-- Erzeugt: 2026-09-26
-- Wiederholbar (DDL_UTIL; Grunddaten nur fehlende Zeilen).
-- =====================================================================

set define off
set serveroutput on size unlimited

-- FAKT_NUMMERNKREISE (NKRS): Nummernkreise je Mandant, Belegart und Jahr
begin
    DDL_UTIL.tabelle('FAKT_NUMMERNKREISE', q'~create table FAKT_NUMMERNKREISE (
  NKRS_ID number not null,
  NKRS_MAND_ID number not null,
  NKRS_BELEGART varchar2(20 char) not null,
  NKRS_JAHR number(4) not null,
  NKRS_FORMAT varchar2(50 char) default '{JAHR} - {NR}' not null,
  NKRS_LETZTE_NUMMER number default 0 not null,
  NKRS_CREATED_ON timestamp not null,
  NKRS_CREATED_BY varchar2(255 char) not null,
  NKRS_UPDATED_ON timestamp,
  NKRS_UPDATED_BY varchar2(255 char),
  NKRS_ROW_VERSION number not null,
  constraint NKRS_PK primary key (NKRS_ID)
)~');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_MAND_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_BELEGART', 'varchar2(20 char)', 'N');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_JAHR', 'number(4)', 'N');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_FORMAT', 'varchar2(50 char)', 'N', q'~'{JAHR} - {NR}'~');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_LETZTE_NUMMER', 'number', 'N', q'~0~');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('FAKT_NUMMERNKREISE', 'NKRS_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('FAKT_NUMMERNKREISE', 'NKRS_PK', 'P', 'NKRS_ID');
    DDL_UTIL.constraint_('FAKT_NUMMERNKREISE', 'NKRS_UK', 'U', q'~NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR~');
    DDL_UTIL.constraint_('FAKT_NUMMERNKREISE', 'NKRS_BELEGART_CK', 'C', q'~NKRS_BELEGART in ('RECHNUNG', 'GUTSCHRIFT')~');
    DDL_UTIL.constraint_('FAKT_NUMMERNKREISE', 'NKRS_LETZTE_NUMMER_CK', 'C', q'~NKRS_LETZTE_NUMMER >= 0~');
end;
/

-- FAKT_RECHNUNGEN (RECH): Ausgangsrechnungen (Kopf)
begin
    DDL_UTIL.tabelle('FAKT_RECHNUNGEN', q'~create table FAKT_RECHNUNGEN (
  RECH_ID number not null,
  RECH_MAND_ID number not null,
  RECH_KUND_ID number not null,
  RECH_KSTO_ID number,
  RECH_ANSP_ID number,
  RECH_MITA_ID number,
  RECH_ZBED_ID number,
  RECH_EMPF_LAND_CODE varchar2(2 char),
  RECH_NUMMER varchar2(30 char),
  RECH_STATUS varchar2(10 char) default 'ENTWURF' not null,
  RECH_BETREFF varchar2(200 char),
  RECH_DATUM date default trunc(sysdate) not null,
  RECH_FAELLIG_AM date,
  RECH_LEISTUNGSZEITRAUM varchar2(100 char),
  RECH_LEISTUNG_VON date,
  RECH_LEISTUNG_BIS date,
  RECH_REFERENZ varchar2(200 char),
  RECH_PROJEKT varchar2(200 char),
  RECH_IST_BRUTTO varchar2(1 char) default 'N' not null,
  RECH_IST_OHNE_MWST varchar2(1 char) default 'N' not null,
  RECH_IST_FAELLIGKEIT_ANZEIGEN varchar2(1 char) default 'N' not null,
  RECH_EMPF_ANREDE varchar2(30 char),
  RECH_EMPF_NAME varchar2(400 char),
  RECH_EMPF_KONTAKTPERSON varchar2(200 char),
  RECH_EMPF_STRASSE varchar2(250 char),
  RECH_EMPF_PLZ varchar2(10 char),
  RECH_EMPF_ORT varchar2(100 char),
  RECH_EMPF_UID_NUMMER varchar2(20 char),
  RECH_LIEFERADRESSE varchar2(1000 char),
  RECH_ZAHLUNGSBED_TEXT clob,
  RECH_VORTEXT clob,
  RECH_SCHLUSSTEXT clob,
  RECH_WAEHRUNG varchar2(3 char) default 'EUR' not null,
  RECH_SUMME_NETTO number(12,2) default 0 not null,
  RECH_SUMME_MWST number(12,2) default 0 not null,
  RECH_SUMME_BRUTTO number(12,2) default 0 not null,
  RECH_ALT_ID number,
  RECH_CREATED_ON timestamp not null,
  RECH_CREATED_BY varchar2(255 char) not null,
  RECH_UPDATED_ON timestamp,
  RECH_UPDATED_BY varchar2(255 char),
  RECH_ROW_VERSION number not null,
  constraint RECH_PK primary key (RECH_ID)
)~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_MAND_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_KUND_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_KSTO_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ANSP_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_MITA_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ZBED_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_LAND_CODE', 'varchar2(2 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_NUMMER', 'varchar2(30 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_STATUS', 'varchar2(10 char)', 'N', q'~'ENTWURF'~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_BETREFF', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_DATUM', 'date', 'N', q'~trunc(sysdate)~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_FAELLIG_AM', 'date', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_LEISTUNGSZEITRAUM', 'varchar2(100 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_LEISTUNG_VON', 'date', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_LEISTUNG_BIS', 'date', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_REFERENZ', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_PROJEKT', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_IST_BRUTTO', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_IST_OHNE_MWST', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_IST_FAELLIGKEIT_ANZEIGEN', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_ANREDE', 'varchar2(30 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_NAME', 'varchar2(400 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_KONTAKTPERSON', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_STRASSE', 'varchar2(250 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_PLZ', 'varchar2(10 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_ORT', 'varchar2(100 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_EMPF_UID_NUMMER', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_LIEFERADRESSE', 'varchar2(1000 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ZAHLUNGSBED_TEXT', 'clob', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_VORTEXT', 'clob', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_SCHLUSSTEXT', 'clob', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_WAEHRUNG', 'varchar2(3 char)', 'N', q'~'EUR'~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_SUMME_NETTO', 'number(12,2)', 'N', q'~0~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_SUMME_MWST', 'number(12,2)', 'N', q'~0~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_SUMME_BRUTTO', 'number(12,2)', 'N', q'~0~');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_PK', 'P', 'RECH_ID');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_ALT_ID_UK', 'U', q'~RECH_ALT_ID~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_STATUS_CK', 'C', q'~RECH_STATUS in ('ENTWURF', 'OFFEN', 'BEZAHLT', 'STORNIERT')~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_NUMMER_CK', 'C', q'~RECH_STATUS = 'ENTWURF' or RECH_NUMMER is not null~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_LEISTUNG_CK', 'C', q'~RECH_LEISTUNG_BIS is null or RECH_LEISTUNG_VON is null or RECH_LEISTUNG_BIS >= RECH_LEISTUNG_VON~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_IST_BRUTTO_CK', 'C', q'~RECH_IST_BRUTTO in ('Y', 'N')~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_IST_OHNE_MWST_CK', 'C', q'~RECH_IST_OHNE_MWST in ('Y', 'N')~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_IST_FAELLIGKEIT_ANZEIGEN_CK', 'C', q'~RECH_IST_FAELLIGKEIT_ANZEIGEN in ('Y', 'N')~');
end;
/

-- FAKT_RECHNUNGSPOSITIONEN (RPOS): Positionen der Ausgangsrechnungen
begin
    DDL_UTIL.tabelle('FAKT_RECHNUNGSPOSITIONEN', q'~create table FAKT_RECHNUNGSPOSITIONEN (
  RPOS_ID number not null,
  RPOS_RECH_ID number not null,
  RPOS_ARTI_ID number,
  RPOS_POSITION number(5) not null,
  RPOS_KAPITEL varchar2(200 char),
  RPOS_UNTERKAPITEL varchar2(200 char),
  RPOS_ARTIKELNUMMER varchar2(30 char),
  RPOS_NAME varchar2(200 char) not null,
  RPOS_BESCHREIBUNG clob,
  RPOS_MENGE number(12,3) default 1 not null,
  RPOS_EINHEIT varchar2(10 char),
  RPOS_EINZELPREIS number(12,2) default 0 not null,
  RPOS_RABATT_PROZENT number(5,2),
  RPOS_MWST_PROZENT number(5,2) not null,
  RPOS_SUMME number(12,2) default 0 not null,
  RPOS_IST_OPTIONAL varchar2(1 char) default 'N' not null,
  RPOS_ERLOESKONTO varchar2(20 char),
  RPOS_CREATED_ON timestamp not null,
  RPOS_CREATED_BY varchar2(255 char) not null,
  RPOS_UPDATED_ON timestamp,
  RPOS_UPDATED_BY varchar2(255 char),
  RPOS_ROW_VERSION number not null,
  constraint RPOS_PK primary key (RPOS_ID)
)~');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_RECH_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ARTI_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_POSITION', 'number(5)', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_KAPITEL', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_UNTERKAPITEL', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ARTIKELNUMMER', 'varchar2(30 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_NAME', 'varchar2(200 char)', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_BESCHREIBUNG', 'clob', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_MENGE', 'number(12,3)', 'N', q'~1~');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_EINHEIT', 'varchar2(10 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_EINZELPREIS', 'number(12,2)', 'N', q'~0~');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_RABATT_PROZENT', 'number(5,2)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_MWST_PROZENT', 'number(5,2)', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_SUMME', 'number(12,2)', 'N', q'~0~');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_IST_OPTIONAL', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ERLOESKONTO', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_PK', 'P', 'RPOS_ID');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_UK', 'U', q'~RPOS_RECH_ID, RPOS_POSITION~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_RABATT_CK', 'C', q'~RPOS_RABATT_PROZENT between 0 and 100~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_MWST_CK', 'C', q'~RPOS_MWST_PROZENT between 0 and 100~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_IST_OPTIONAL_CK', 'C', q'~RPOS_IST_OPTIONAL in ('Y', 'N')~');
end;
/

-- FAKT_ZAHLUNGEN (ZAHL): Zahlungseingaenge zu Ausgangsrechnungen
begin
    DDL_UTIL.tabelle('FAKT_ZAHLUNGEN', q'~create table FAKT_ZAHLUNGEN (
  ZAHL_ID number not null,
  ZAHL_RECH_ID number not null,
  ZAHL_DATUM date not null,
  ZAHL_BETRAG number(12,2) not null,
  ZAHL_SKONTO number(12,2),
  ZAHL_MAHNSPESEN number(12,2),
  ZAHL_BEMERKUNG varchar2(500 char),
  ZAHL_ALT_ID number,
  ZAHL_CREATED_ON timestamp not null,
  ZAHL_CREATED_BY varchar2(255 char) not null,
  ZAHL_UPDATED_ON timestamp,
  ZAHL_UPDATED_BY varchar2(255 char),
  ZAHL_ROW_VERSION number not null,
  constraint ZAHL_PK primary key (ZAHL_ID)
)~');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_RECH_ID', 'number', 'N');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_DATUM', 'date', 'N');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_BETRAG', 'number(12,2)', 'N');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_SKONTO', 'number(12,2)', 'Y');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_MAHNSPESEN', 'number(12,2)', 'Y');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_BEMERKUNG', 'varchar2(500 char)', 'Y');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('FAKT_ZAHLUNGEN', 'ZAHL_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('FAKT_ZAHLUNGEN', 'ZAHL_PK', 'P', 'ZAHL_ID');
    DDL_UTIL.constraint_('FAKT_ZAHLUNGEN', 'ZAHL_ALT_ID_UK', 'U', q'~ZAHL_ALT_ID~');
end;
/

-- Fremdschluessel, FK-Indizes und fachliche Indizes
begin
    DDL_UTIL.constraint_('FAKT_NUMMERNKREISE', 'NKRS_MAND_FK', 'R', 'NKRS_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_MAND_FK', 'R', 'RECH_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_KUND_FK', 'R', 'RECH_KUND_ID references KUND_KUNDEN (KUND_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_KSTO_FK', 'R', 'RECH_KSTO_ID references KUND_STANDORTE (KSTO_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_ANSP_FK', 'R', 'RECH_ANSP_ID references KUND_ANSPRECHPARTNER (ANSP_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_MITA_FK', 'R', 'RECH_MITA_ID references ALLG_MITARBEITER (MITA_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_ZBED_FK', 'R', 'RECH_ZBED_ID references ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGEN', 'RECH_EMPF_LAND_FK', 'R', 'RECH_EMPF_LAND_CODE references ALLG_LAENDER (LAND_CODE)');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_NUMMER_UI', q'~case when RECH_NUMMER is not null then RECH_MAND_ID end, RECH_NUMMER~', true);
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_MAND_I', q'~RECH_MAND_ID~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_KUND_I', q'~RECH_KUND_ID~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_KSTO_I', q'~RECH_KSTO_ID~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_ANSP_I', q'~RECH_ANSP_ID~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_MITA_I', q'~RECH_MITA_ID~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_ZBED_I', q'~RECH_ZBED_ID~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_EMPF_LAND_I', q'~RECH_EMPF_LAND_CODE~');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_DATUM_I', q'~RECH_DATUM~');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_RECH_FK', 'R', 'RPOS_RECH_ID references FAKT_RECHNUNGEN (RECH_ID)');
    DDL_UTIL.constraint_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ARTI_FK', 'R', 'RPOS_ARTI_ID references ARTI_ARTIKEL (ARTI_ID)');
    DDL_UTIL.index_('FAKT_RECHNUNGSPOSITIONEN', 'RPOS_ARTI_I', q'~RPOS_ARTI_ID~');
    DDL_UTIL.constraint_('FAKT_ZAHLUNGEN', 'ZAHL_RECH_FK', 'R', 'ZAHL_RECH_ID references FAKT_RECHNUNGEN (RECH_ID)');
    DDL_UTIL.index_('FAKT_ZAHLUNGEN', 'ZAHL_RECH_I', q'~ZAHL_RECH_ID~');
end;
/

begin
    DDL_UTIL.trigger_pruefen('NKRS_BIU', 'FAKT_NUMMERNKREISE');
end;
/

create or replace trigger NKRS_BIU
  before insert or update on FAKT_NUMMERNKREISE
  for each row
begin
  if inserting then
    :new.NKRS_ID := coalesce(:new.NKRS_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.NKRS_CREATED_ON  := systimestamp;
    :new.NKRS_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.NKRS_UPDATED_ON  := null;
    :new.NKRS_UPDATED_BY  := null;
    :new.NKRS_ROW_VERSION := 1;
  elsif updating then
    :new.NKRS_ID          := :old.NKRS_ID;  -- Primaerschluessel ist unveraenderlich
    :new.NKRS_CREATED_ON  := :old.NKRS_CREATED_ON;
    :new.NKRS_CREATED_BY  := :old.NKRS_CREATED_BY;
    :new.NKRS_UPDATED_ON  := systimestamp;
    :new.NKRS_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.NKRS_ROW_VERSION := nvl(:old.NKRS_ROW_VERSION, 0) + 1;
  end if;
end NKRS_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('RECH_BIU', 'FAKT_RECHNUNGEN');
end;
/

create or replace trigger RECH_BIU
  before insert or update on FAKT_RECHNUNGEN
  for each row
begin
  if inserting then
    :new.RECH_ID := coalesce(:new.RECH_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.RECH_CREATED_ON  := systimestamp;
    :new.RECH_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RECH_UPDATED_ON  := null;
    :new.RECH_UPDATED_BY  := null;
    :new.RECH_ROW_VERSION := 1;
  elsif updating then
    :new.RECH_ID          := :old.RECH_ID;  -- Primaerschluessel ist unveraenderlich
    :new.RECH_CREATED_ON  := :old.RECH_CREATED_ON;
    :new.RECH_CREATED_BY  := :old.RECH_CREATED_BY;
    :new.RECH_UPDATED_ON  := systimestamp;
    :new.RECH_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RECH_ROW_VERSION := nvl(:old.RECH_ROW_VERSION, 0) + 1;
  end if;
end RECH_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('RPOS_BIU', 'FAKT_RECHNUNGSPOSITIONEN');
end;
/

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
  :new.RPOS_SUMME := round(:new.RPOS_MENGE * :new.RPOS_EINZELPREIS * (1 - nvl(:new.RPOS_RABATT_PROZENT, 0) / 100), 2);
end RPOS_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('ZAHL_BIU', 'FAKT_ZAHLUNGEN');
end;
/

create or replace trigger ZAHL_BIU
  before insert or update on FAKT_ZAHLUNGEN
  for each row
begin
  if inserting then
    :new.ZAHL_ID := coalesce(:new.ZAHL_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.ZAHL_CREATED_ON  := systimestamp;
    :new.ZAHL_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ZAHL_UPDATED_ON  := null;
    :new.ZAHL_UPDATED_BY  := null;
    :new.ZAHL_ROW_VERSION := 1;
  elsif updating then
    :new.ZAHL_ID          := :old.ZAHL_ID;  -- Primaerschluessel ist unveraenderlich
    :new.ZAHL_CREATED_ON  := :old.ZAHL_CREATED_ON;
    :new.ZAHL_CREATED_BY  := :old.ZAHL_CREATED_BY;
    :new.ZAHL_UPDATED_ON  := systimestamp;
    :new.ZAHL_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ZAHL_ROW_VERSION := nvl(:old.ZAHL_ROW_VERSION, 0) + 1;
  end if;
end ZAHL_BIU;
/

comment on table FAKT_NUMMERNKREISE is 'Nummernkreise je Mandant, Belegart und Jahr [Alias NKRS]';
comment on column FAKT_NUMMERNKREISE.NKRS_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_NUMMERNKREISE.NKRS_MAND_ID is 'FK: Mandant';
comment on column FAKT_NUMMERNKREISE.NKRS_BELEGART is 'RECHNUNG oder GUTSCHRIFT';
comment on column FAKT_NUMMERNKREISE.NKRS_JAHR is 'Geschaeftsjahr';
comment on column FAKT_NUMMERNKREISE.NKRS_FORMAT is 'Format der Belegnummer mit {JAHR} und {NR}, z.B. 2026 - 13';
comment on column FAKT_NUMMERNKREISE.NKRS_LETZTE_NUMMER is 'Zuletzt vergebene laufende Nummer';
comment on column FAKT_NUMMERNKREISE.NKRS_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_NUMMERNKREISE.NKRS_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_NUMMERNKREISE.NKRS_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_NUMMERNKREISE.NKRS_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_NUMMERNKREISE.NKRS_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table FAKT_RECHNUNGEN is 'Ausgangsrechnungen (Kopf) [Alias RECH]';
comment on column FAKT_RECHNUNGEN.RECH_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_RECHNUNGEN.RECH_MAND_ID is 'FK: Mandant (ausstellende Firma)';
comment on column FAKT_RECHNUNGEN.RECH_KUND_ID is 'FK: Kunde (Rechnungsempfaenger)';
comment on column FAKT_RECHNUNGEN.RECH_KSTO_ID is 'FK: Standort (Rechnungsadresse)';
comment on column FAKT_RECHNUNGEN.RECH_ANSP_ID is 'FK: Ansprechpartner (Kontaktperson)';
comment on column FAKT_RECHNUNGEN.RECH_MITA_ID is 'FK: Mitarbeiter (Bearbeiter)';
comment on column FAKT_RECHNUNGEN.RECH_ZBED_ID is 'FK: Zahlungsbedingung';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_LAND_CODE is 'Empfaenger (Kopie beim Anlegen): Land, FK ALLG_LAENDER';
comment on column FAKT_RECHNUNGEN.RECH_NUMMER is 'Rechnungsnummer (eindeutig je Mandant), vergeben beim Abschliessen';
comment on column FAKT_RECHNUNGEN.RECH_STATUS is 'ENTWURF, OFFEN, BEZAHLT, STORNIERT';
comment on column FAKT_RECHNUNGEN.RECH_BETREFF is 'Betreff, z.B. Rechnung 2026 - 13';
comment on column FAKT_RECHNUNGEN.RECH_DATUM is 'Rechnungsdatum';
comment on column FAKT_RECHNUNGEN.RECH_FAELLIG_AM is 'Faelligkeitsdatum';
comment on column FAKT_RECHNUNGEN.RECH_LEISTUNGSZEITRAUM is 'Leistungszeitraum als Text, z.B. Juli 2026';
comment on column FAKT_RECHNUNGEN.RECH_LEISTUNG_VON is 'Leistungszeitraum von (optional, fuer Auswertungen)';
comment on column FAKT_RECHNUNGEN.RECH_LEISTUNG_BIS is 'Leistungszeitraum bis';
comment on column FAKT_RECHNUNGEN.RECH_REFERENZ is 'Referenz, z.B. Bestellnummer des Kunden';
comment on column FAKT_RECHNUNGEN.RECH_PROJEKT is 'Projekt';
comment on column FAKT_RECHNUNGEN.RECH_IST_BRUTTO is 'Y = Preise der Positionen sind brutto';
comment on column FAKT_RECHNUNGEN.RECH_IST_OHNE_MWST is 'Y = ohne Umsatzsteuer (Reverse Charge, Ausland)';
comment on column FAKT_RECHNUNGEN.RECH_IST_FAELLIGKEIT_ANZEIGEN is 'Y = Faelligkeit auf der Rechnung andrucken';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_ANREDE is 'Empfaenger (Kopie beim Anlegen): Anrede';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_NAME is 'Empfaenger (Kopie beim Anlegen): Name (Firma bzw. Person, mehrzeilig)';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_KONTAKTPERSON is 'Empfaenger (Kopie beim Anlegen): Kontaktperson';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_STRASSE is 'Empfaenger (Kopie beim Anlegen): Strasse und Hausnummer';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_PLZ is 'Empfaenger (Kopie beim Anlegen): PLZ';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_ORT is 'Empfaenger (Kopie beim Anlegen): Ort';
comment on column FAKT_RECHNUNGEN.RECH_EMPF_UID_NUMMER is 'Empfaenger (Kopie beim Anlegen): UID-Nummer';
comment on column FAKT_RECHNUNGEN.RECH_LIEFERADRESSE is 'Lieferadresse (Freitext)';
comment on column FAKT_RECHNUNGEN.RECH_ZAHLUNGSBED_TEXT is 'Zahlungsbedingungen (Text auf der Rechnung)';
comment on column FAKT_RECHNUNGEN.RECH_VORTEXT is 'Text vor den Positionen';
comment on column FAKT_RECHNUNGEN.RECH_SCHLUSSTEXT is 'Text nach den Positionen';
comment on column FAKT_RECHNUNGEN.RECH_WAEHRUNG is 'Waehrung (ISO 4217)';
comment on column FAKT_RECHNUNGEN.RECH_SUMME_NETTO is 'Summe netto (aus den Positionen, ohne optionale)';
comment on column FAKT_RECHNUNGEN.RECH_SUMME_MWST is 'Summe Umsatzsteuer';
comment on column FAKT_RECHNUNGEN.RECH_SUMME_BRUTTO is 'Gesamtbetrag';
comment on column FAKT_RECHNUNGEN.RECH_ALT_ID is 'ID im Altsystem (Kingbill DokumentRechnung.ID), fuer die Datenuebernahme';
comment on column FAKT_RECHNUNGEN.RECH_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_RECHNUNGEN.RECH_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_RECHNUNGEN.RECH_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_RECHNUNGEN.RECH_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_RECHNUNGEN.RECH_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table FAKT_RECHNUNGSPOSITIONEN is 'Positionen der Ausgangsrechnungen [Alias RPOS]';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_RECH_ID is 'FK: Rechnung';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_ARTI_ID is 'FK: Artikel (optional; Texte werden kopiert)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_POSITION is 'Positionsnummer';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_KAPITEL is 'Kapitel (Gruppierung auf der Rechnung)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_UNTERKAPITEL is 'Unterkapitel';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_ARTIKELNUMMER is 'Artikelnummer (Kopie)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_NAME is 'Positionstext (Kopie des Artikelnamens)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_BESCHREIBUNG is 'Beschreibung (Kopie, HTML)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_MENGE is 'Menge';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_EINHEIT is 'Einheit (Kopie), z.B. Pauschale';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_EINZELPREIS is 'Einzelpreis (netto bzw. brutto lt. RECH_IST_BRUTTO)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_RABATT_PROZENT is 'Rabatt in Prozent';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_MWST_PROZENT is 'Umsatzsteuersatz (Kopie)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_SUMME is 'Positionssumme = Menge x Einzelpreis abzgl. Rabatt (berechnet im Trigger)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_IST_OPTIONAL is 'Y = Alternativposition, nicht in der Rechnungssumme';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_ERLOESKONTO is 'Erloeskonto (Kopie)';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_RECHNUNGSPOSITIONEN.RPOS_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table FAKT_ZAHLUNGEN is 'Zahlungseingaenge zu Ausgangsrechnungen [Alias ZAHL]';
comment on column FAKT_ZAHLUNGEN.ZAHL_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_ZAHLUNGEN.ZAHL_RECH_ID is 'FK: Rechnung';
comment on column FAKT_ZAHLUNGEN.ZAHL_DATUM is 'Zahlungsdatum';
comment on column FAKT_ZAHLUNGEN.ZAHL_BETRAG is 'Gezahlter Betrag';
comment on column FAKT_ZAHLUNGEN.ZAHL_SKONTO is 'Abgezogenes Skonto';
comment on column FAKT_ZAHLUNGEN.ZAHL_MAHNSPESEN is 'Mahnspesen und Verzugszinsen';
comment on column FAKT_ZAHLUNGEN.ZAHL_BEMERKUNG is 'Bemerkung';
comment on column FAKT_ZAHLUNGEN.ZAHL_ALT_ID is 'ID im Altsystem (Kingbill Payment.ID), fuer die Datenuebernahme';
comment on column FAKT_ZAHLUNGEN.ZAHL_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_ZAHLUNGEN.ZAHL_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_ZAHLUNGEN.ZAHL_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_ZAHLUNGEN.ZAHL_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_ZAHLUNGEN.ZAHL_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

-- Grunddaten: nur fehlende Zeilen
insert into FAKT_NUMMERNKREISE (NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR, NKRS_LETZTE_NUMMER)
  select MAND_ID, 'RECHNUNG', 2026, 13 from ADMIN_MANDANTEN m
   where MAND_CODE = 'EDV'
     and not exists (select 1 from FAKT_NUMMERNKREISE where NKRS_MAND_ID = m.MAND_ID and NKRS_BELEGART = 'RECHNUNG' and NKRS_JAHR = 2026);
insert into FAKT_NUMMERNKREISE (NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR, NKRS_LETZTE_NUMMER)
  select MAND_ID, 'RECHNUNG', 2026, 199 from ADMIN_MANDANTEN m
   where MAND_CODE = 'TG'
     and not exists (select 1 from FAKT_NUMMERNKREISE where NKRS_MAND_ID = m.MAND_ID and NKRS_BELEGART = 'RECHNUNG' and NKRS_JAHR = 2026);
commit;

prompt FAKT_NUMMERNKREISE, FAKT_RECHNUNGEN, FAKT_RECHNUNGSPOSITIONEN, FAKT_ZAHLUNGEN installiert bzw. abgeglichen.
