-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 13 – Erweiterung Kundenstamm fuer die Altdatenuebernahme:
--      neu: KUND_KUNDENGRUPPEN, KUND_BRANCHEN, KUND_UNTERKATEGORIEN, KUND_KUNDEN_BRANCHEN,
--           KUND_KUNDEN_UNTERKATEGORIEN, KUND_ABTEILUNGEN, KUND_FUNKTIONEN
--      erweitert: KUND_KUNDEN (Kundengruppe, Kurzname, Namenszusatz, Sprache, Groesse, Bemerkung, Alt-IDs, …),
--                 KUND_ANSPRECHPARTNER (Abteilung, Funktion, Durchwahl, Bewertung, Geburtsdatum, Infomail, …)
-- GENERIERT (Definition siehe Kopf der Tabellenbloecke); nutzt Paket DDL_UTIL (11_ddl_util.sql)
-- Erzeugt: 2026-09-25
--
-- Wiederholbar: Tabellen/Spalten/Constraints/Indizes werden nur angelegt bzw. angeglichen,
-- Trigger nur ersetzt, wenn der Name zur richtigen Tabelle gehoert; Grunddaten nur fehlende Zeilen.
-- =====================================================================

set define off
set serveroutput on size unlimited

-- KUND_KUNDENGRUPPEN (KGRP): Kundengruppen (OEM, Wiederverkaeufer, Endkunde)
begin
    DDL_UTIL.tabelle('KUND_KUNDENGRUPPEN', q'~create table KUND_KUNDENGRUPPEN (
  KGRP_ID number not null,
  KGRP_CODE varchar2(20 char) not null,
  KGRP_BEZEICHNUNG varchar2(100 char) not null,
  KGRP_SORTIERUNG number(5),
  KGRP_IST_AKTIV varchar2(1 char) default 'Y' not null,
  KGRP_CREATED_ON timestamp not null,
  KGRP_CREATED_BY varchar2(255 char) not null,
  KGRP_UPDATED_ON timestamp,
  KGRP_UPDATED_BY varchar2(255 char),
  KGRP_ROW_VERSION number not null,
  constraint KGRP_PK primary key (KGRP_ID)
)~');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_CODE', 'varchar2(20 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_BEZEICHNUNG', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDENGRUPPEN', 'KGRP_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_KUNDENGRUPPEN', 'KGRP_PK', 'P', 'KGRP_ID');
    DDL_UTIL.constraint_('KUND_KUNDENGRUPPEN', 'KGRP_CODE_UK', 'U', q'~KGRP_CODE~');
    DDL_UTIL.constraint_('KUND_KUNDENGRUPPEN', 'KGRP_IST_AKTIV_CK', 'C', q'~KGRP_IST_AKTIV in ('Y', 'N')~');
end;
/

-- KUND_BRANCHEN (BRAN): Branchen der Kunden
begin
    DDL_UTIL.tabelle('KUND_BRANCHEN', q'~create table KUND_BRANCHEN (
  BRAN_ID number not null,
  BRAN_BEZEICHNUNG varchar2(200 char) not null,
  BRAN_BEWERTUNG number(1),
  BRAN_SORTIERUNG number(5),
  BRAN_IST_AKTIV varchar2(1 char) default 'Y' not null,
  BRAN_ALT_ID number,
  BRAN_CREATED_ON timestamp not null,
  BRAN_CREATED_BY varchar2(255 char) not null,
  BRAN_UPDATED_ON timestamp,
  BRAN_UPDATED_BY varchar2(255 char),
  BRAN_ROW_VERSION number not null,
  constraint BRAN_PK primary key (BRAN_ID)
)~');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_BEZEICHNUNG', 'varchar2(200 char)', 'N');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_BEWERTUNG', 'number(1)', 'Y');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_BRANCHEN', 'BRAN_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_BRANCHEN', 'BRAN_PK', 'P', 'BRAN_ID');
    DDL_UTIL.constraint_('KUND_BRANCHEN', 'BRAN_BEZEICHNUNG_UK', 'U', q'~BRAN_BEZEICHNUNG~');
    DDL_UTIL.constraint_('KUND_BRANCHEN', 'BRAN_ALT_ID_UK', 'U', q'~BRAN_ALT_ID~');
    DDL_UTIL.constraint_('KUND_BRANCHEN', 'BRAN_BEWERTUNG_CK', 'C', q'~BRAN_BEWERTUNG between 1 and 5~');
    DDL_UTIL.constraint_('KUND_BRANCHEN', 'BRAN_IST_AKTIV_CK', 'C', q'~BRAN_IST_AKTIV in ('Y', 'N')~');
end;
/

-- KUND_UNTERKATEGORIEN (UKAT): Unterkategorien je Branche
begin
    DDL_UTIL.tabelle('KUND_UNTERKATEGORIEN', q'~create table KUND_UNTERKATEGORIEN (
  UKAT_ID number not null,
  UKAT_BRAN_ID number not null,
  UKAT_BEZEICHNUNG varchar2(200 char) not null,
  UKAT_BEWERTUNG number(1),
  UKAT_SORTIERUNG number(5),
  UKAT_IST_AKTIV varchar2(1 char) default 'Y' not null,
  UKAT_ALT_ID number,
  UKAT_CREATED_ON timestamp not null,
  UKAT_CREATED_BY varchar2(255 char) not null,
  UKAT_UPDATED_ON timestamp,
  UKAT_UPDATED_BY varchar2(255 char),
  UKAT_ROW_VERSION number not null,
  constraint UKAT_PK primary key (UKAT_ID)
)~');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_BRAN_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_BEZEICHNUNG', 'varchar2(200 char)', 'N');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_BEWERTUNG', 'number(1)', 'Y');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_UNTERKATEGORIEN', 'UKAT_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_UNTERKATEGORIEN', 'UKAT_PK', 'P', 'UKAT_ID');
    DDL_UTIL.constraint_('KUND_UNTERKATEGORIEN', 'UKAT_UK', 'U', q'~UKAT_BRAN_ID, UKAT_BEZEICHNUNG~');
    DDL_UTIL.constraint_('KUND_UNTERKATEGORIEN', 'UKAT_ALT_ID_UK', 'U', q'~UKAT_ALT_ID~');
    DDL_UTIL.constraint_('KUND_UNTERKATEGORIEN', 'UKAT_BEWERTUNG_CK', 'C', q'~UKAT_BEWERTUNG between 1 and 5~');
    DDL_UTIL.constraint_('KUND_UNTERKATEGORIEN', 'UKAT_IST_AKTIV_CK', 'C', q'~UKAT_IST_AKTIV in ('Y', 'N')~');
end;
/

-- KUND_KUNDEN_BRANCHEN (KBRA): Zuordnung Kunde - Branche (n:m)
begin
    DDL_UTIL.tabelle('KUND_KUNDEN_BRANCHEN', q'~create table KUND_KUNDEN_BRANCHEN (
  KBRA_ID number not null,
  KBRA_KUND_ID number not null,
  KBRA_BRAN_ID number not null,
  KBRA_CREATED_ON timestamp not null,
  KBRA_CREATED_BY varchar2(255 char) not null,
  KBRA_UPDATED_ON timestamp,
  KBRA_UPDATED_BY varchar2(255 char),
  KBRA_ROW_VERSION number not null,
  constraint KBRA_PK primary key (KBRA_ID)
)~');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_KUND_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_BRAN_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_BRANCHEN', 'KBRA_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_KUNDEN_BRANCHEN', 'KBRA_PK', 'P', 'KBRA_ID');
    DDL_UTIL.constraint_('KUND_KUNDEN_BRANCHEN', 'KBRA_UK', 'U', q'~KBRA_KUND_ID, KBRA_BRAN_ID~');
end;
/

-- KUND_KUNDEN_UNTERKATEGORIEN (KUKA): Zuordnung Kunden-Branche - Unterkategorie (n:m)
begin
    DDL_UTIL.tabelle('KUND_KUNDEN_UNTERKATEGORIEN', q'~create table KUND_KUNDEN_UNTERKATEGORIEN (
  KUKA_ID number not null,
  KUKA_KBRA_ID number not null,
  KUKA_UKAT_ID number not null,
  KUKA_CREATED_ON timestamp not null,
  KUKA_CREATED_BY varchar2(255 char) not null,
  KUKA_UPDATED_ON timestamp,
  KUKA_UPDATED_BY varchar2(255 char),
  KUKA_ROW_VERSION number not null,
  constraint KUKA_PK primary key (KUKA_ID)
)~');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_KBRA_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_UKAT_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_PK', 'P', 'KUKA_ID');
    DDL_UTIL.constraint_('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_UK', 'U', q'~KUKA_KBRA_ID, KUKA_UKAT_ID~');
end;
/

-- KUND_ABTEILUNGEN (ABTE): Abteilungen der Ansprechpartner beim Kunden
begin
    DDL_UTIL.tabelle('KUND_ABTEILUNGEN', q'~create table KUND_ABTEILUNGEN (
  ABTE_ID number not null,
  ABTE_CODE varchar2(25 char) not null,
  ABTE_BEZEICHNUNG varchar2(100 char) not null,
  ABTE_SORTIERUNG number(5),
  ABTE_IST_AKTIV varchar2(1 char) default 'Y' not null,
  ABTE_ALT_ID number,
  ABTE_CREATED_ON timestamp not null,
  ABTE_CREATED_BY varchar2(255 char) not null,
  ABTE_UPDATED_ON timestamp,
  ABTE_UPDATED_BY varchar2(255 char),
  ABTE_ROW_VERSION number not null,
  constraint ABTE_PK primary key (ABTE_ID)
)~');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_CODE', 'varchar2(25 char)', 'N');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_BEZEICHNUNG', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_ABTEILUNGEN', 'ABTE_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_ABTEILUNGEN', 'ABTE_PK', 'P', 'ABTE_ID');
    DDL_UTIL.constraint_('KUND_ABTEILUNGEN', 'ABTE_CODE_UK', 'U', q'~ABTE_CODE~');
    DDL_UTIL.constraint_('KUND_ABTEILUNGEN', 'ABTE_ALT_ID_UK', 'U', q'~ABTE_ALT_ID~');
    DDL_UTIL.constraint_('KUND_ABTEILUNGEN', 'ABTE_IST_AKTIV_CK', 'C', q'~ABTE_IST_AKTIV in ('Y', 'N')~');
end;
/

-- KUND_FUNKTIONEN (FUNK): Funktionen der Ansprechpartner beim Kunden
begin
    DDL_UTIL.tabelle('KUND_FUNKTIONEN', q'~create table KUND_FUNKTIONEN (
  FUNK_ID number not null,
  FUNK_CODE varchar2(20 char) not null,
  FUNK_BEZEICHNUNG varchar2(100 char) not null,
  FUNK_SORTIERUNG number(5),
  FUNK_IST_AKTIV varchar2(1 char) default 'Y' not null,
  FUNK_ALT_ID number,
  FUNK_CREATED_ON timestamp not null,
  FUNK_CREATED_BY varchar2(255 char) not null,
  FUNK_UPDATED_ON timestamp,
  FUNK_UPDATED_BY varchar2(255 char),
  FUNK_ROW_VERSION number not null,
  constraint FUNK_PK primary key (FUNK_ID)
)~');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_CODE', 'varchar2(20 char)', 'N');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_BEZEICHNUNG', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_FUNKTIONEN', 'FUNK_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_FUNKTIONEN', 'FUNK_PK', 'P', 'FUNK_ID');
    DDL_UTIL.constraint_('KUND_FUNKTIONEN', 'FUNK_CODE_UK', 'U', q'~FUNK_CODE~');
    DDL_UTIL.constraint_('KUND_FUNKTIONEN', 'FUNK_ALT_ID_UK', 'U', q'~FUNK_ALT_ID~');
    DDL_UTIL.constraint_('KUND_FUNKTIONEN', 'FUNK_IST_AKTIV_CK', 'C', q'~FUNK_IST_AKTIV in ('Y', 'N')~');
end;
/

-- KUND_KUNDEN: zusaetzliche Spalten
begin
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_KGRP_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_KURZNAME', 'varchar2(50 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_NAMENSZUSATZ', 'varchar2(200 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_SPRACHE', 'varchar2(2 char)', 'N', q'~'de'~');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_UNTERNEHMENSGROESSE', 'varchar2(2 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_MITARBEITER_ANZAHL', 'varchar2(15 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_BUCHHALTUNGSNR', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_ZAHLUNGSBED_TEXT', 'varchar2(2000 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_LIEFERBEDINGUNG', 'varchar2(2000 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_RABATT_TEXT', 'varchar2(4000 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_BEMERKUNG', 'clob', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_ALT_SI_ID', 'number', 'Y');
    DDL_UTIL.constraint_('KUND_KUNDEN', 'KUND_KURZNAME_UK', 'U', q'~KUND_KURZNAME~');
    DDL_UTIL.constraint_('KUND_KUNDEN', 'KUND_ALT_ID_UK', 'U', q'~KUND_ALT_ID~');
    DDL_UTIL.constraint_('KUND_KUNDEN', 'KUND_SPRACHE_CK', 'C', q'~KUND_SPRACHE in ('de', 'en')~');
    DDL_UTIL.constraint_('KUND_KUNDEN', 'KUND_UNTERNEHMENSGROESSE_CK', 'C', q'~KUND_UNTERNEHMENSGROESSE in ('KU', 'K', 'M', 'G')~');
end;
/

-- KUND_ANSPRECHPARTNER: zusaetzliche Spalten
begin
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_ABTE_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_FUNK_ID', 'number', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_DURCHWAHL', 'varchar2(100 char)', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_BEWERTUNG', 'varchar2(1 char)', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_GEBURTSDATUM', 'date', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_IST_INFOMAIL', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_INFOMAIL_AM', 'date', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_BEMERKUNG', 'varchar2(4000 char)', 'Y');
    DDL_UTIL.spalte('KUND_ANSPRECHPARTNER', 'ANSP_ALT_ID', 'number', 'Y');
    DDL_UTIL.constraint_('KUND_ANSPRECHPARTNER', 'ANSP_ALT_ID_UK', 'U', q'~ANSP_ALT_ID~');
    DDL_UTIL.constraint_('KUND_ANSPRECHPARTNER', 'ANSP_BEWERTUNG_CK', 'C', q'~ANSP_BEWERTUNG in ('A', 'B', 'C', 'U', 'X')~');
    DDL_UTIL.constraint_('KUND_ANSPRECHPARTNER', 'ANSP_IST_INFOMAIL_CK', 'C', q'~ANSP_IST_INFOMAIL in ('Y', 'N')~');
end;
/

-- Fremdschluessel und FK-Indizes
begin
    DDL_UTIL.constraint_('KUND_UNTERKATEGORIEN', 'UKAT_BRAN_FK', 'R', 'UKAT_BRAN_ID references KUND_BRANCHEN (BRAN_ID)');
    DDL_UTIL.index_('KUND_UNTERKATEGORIEN', 'UKAT_BRAN_I', 'UKAT_BRAN_ID');
    DDL_UTIL.constraint_('KUND_KUNDEN_BRANCHEN', 'KBRA_KUND_FK', 'R', 'KBRA_KUND_ID references KUND_KUNDEN (KUND_ID)');
    DDL_UTIL.constraint_('KUND_KUNDEN_BRANCHEN', 'KBRA_BRAN_FK', 'R', 'KBRA_BRAN_ID references KUND_BRANCHEN (BRAN_ID)');
    DDL_UTIL.index_('KUND_KUNDEN_BRANCHEN', 'KBRA_BRAN_I', 'KBRA_BRAN_ID');
    DDL_UTIL.constraint_('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_KBRA_FK', 'R', 'KUKA_KBRA_ID references KUND_KUNDEN_BRANCHEN (KBRA_ID)');
    DDL_UTIL.constraint_('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_UKAT_FK', 'R', 'KUKA_UKAT_ID references KUND_UNTERKATEGORIEN (UKAT_ID)');
    DDL_UTIL.index_('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA_UKAT_I', 'KUKA_UKAT_ID');
    DDL_UTIL.constraint_('KUND_KUNDEN', 'KUND_KGRP_FK', 'R', 'KUND_KGRP_ID references KUND_KUNDENGRUPPEN (KGRP_ID)');
    DDL_UTIL.index_('KUND_KUNDEN', 'KUND_KGRP_I', 'KUND_KGRP_ID');
    DDL_UTIL.constraint_('KUND_ANSPRECHPARTNER', 'ANSP_ABTE_FK', 'R', 'ANSP_ABTE_ID references KUND_ABTEILUNGEN (ABTE_ID)');
    DDL_UTIL.constraint_('KUND_ANSPRECHPARTNER', 'ANSP_FUNK_FK', 'R', 'ANSP_FUNK_ID references KUND_FUNKTIONEN (FUNK_ID)');
    DDL_UTIL.index_('KUND_ANSPRECHPARTNER', 'ANSP_ABTE_I', 'ANSP_ABTE_ID');
    DDL_UTIL.index_('KUND_ANSPRECHPARTNER', 'ANSP_FUNK_I', 'ANSP_FUNK_ID');
end;
/

begin
    DDL_UTIL.trigger_pruefen('KGRP_BIU', 'KUND_KUNDENGRUPPEN');
end;
/

create or replace trigger KGRP_BIU
  before insert or update on KUND_KUNDENGRUPPEN
  for each row
begin
  if inserting then
    :new.KGRP_ID := coalesce(:new.KGRP_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KGRP_CREATED_ON  := systimestamp;
    :new.KGRP_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KGRP_UPDATED_ON  := null;
    :new.KGRP_UPDATED_BY  := null;
    :new.KGRP_ROW_VERSION := 1;
  elsif updating then
    :new.KGRP_ID          := :old.KGRP_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KGRP_CREATED_ON  := :old.KGRP_CREATED_ON;
    :new.KGRP_CREATED_BY  := :old.KGRP_CREATED_BY;
    :new.KGRP_UPDATED_ON  := systimestamp;
    :new.KGRP_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KGRP_ROW_VERSION := nvl(:old.KGRP_ROW_VERSION, 0) + 1;
  end if;
end KGRP_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('BRAN_BIU', 'KUND_BRANCHEN');
end;
/

create or replace trigger BRAN_BIU
  before insert or update on KUND_BRANCHEN
  for each row
begin
  if inserting then
    :new.BRAN_ID := coalesce(:new.BRAN_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.BRAN_CREATED_ON  := systimestamp;
    :new.BRAN_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BRAN_UPDATED_ON  := null;
    :new.BRAN_UPDATED_BY  := null;
    :new.BRAN_ROW_VERSION := 1;
  elsif updating then
    :new.BRAN_ID          := :old.BRAN_ID;  -- Primaerschluessel ist unveraenderlich
    :new.BRAN_CREATED_ON  := :old.BRAN_CREATED_ON;
    :new.BRAN_CREATED_BY  := :old.BRAN_CREATED_BY;
    :new.BRAN_UPDATED_ON  := systimestamp;
    :new.BRAN_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BRAN_ROW_VERSION := nvl(:old.BRAN_ROW_VERSION, 0) + 1;
  end if;
end BRAN_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('UKAT_BIU', 'KUND_UNTERKATEGORIEN');
end;
/

create or replace trigger UKAT_BIU
  before insert or update on KUND_UNTERKATEGORIEN
  for each row
begin
  if inserting then
    :new.UKAT_ID := coalesce(:new.UKAT_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.UKAT_CREATED_ON  := systimestamp;
    :new.UKAT_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.UKAT_UPDATED_ON  := null;
    :new.UKAT_UPDATED_BY  := null;
    :new.UKAT_ROW_VERSION := 1;
  elsif updating then
    :new.UKAT_ID          := :old.UKAT_ID;  -- Primaerschluessel ist unveraenderlich
    :new.UKAT_CREATED_ON  := :old.UKAT_CREATED_ON;
    :new.UKAT_CREATED_BY  := :old.UKAT_CREATED_BY;
    :new.UKAT_UPDATED_ON  := systimestamp;
    :new.UKAT_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.UKAT_ROW_VERSION := nvl(:old.UKAT_ROW_VERSION, 0) + 1;
  end if;
end UKAT_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('KBRA_BIU', 'KUND_KUNDEN_BRANCHEN');
end;
/

create or replace trigger KBRA_BIU
  before insert or update on KUND_KUNDEN_BRANCHEN
  for each row
begin
  if inserting then
    :new.KBRA_ID := coalesce(:new.KBRA_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KBRA_CREATED_ON  := systimestamp;
    :new.KBRA_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KBRA_UPDATED_ON  := null;
    :new.KBRA_UPDATED_BY  := null;
    :new.KBRA_ROW_VERSION := 1;
  elsif updating then
    :new.KBRA_ID          := :old.KBRA_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KBRA_CREATED_ON  := :old.KBRA_CREATED_ON;
    :new.KBRA_CREATED_BY  := :old.KBRA_CREATED_BY;
    :new.KBRA_UPDATED_ON  := systimestamp;
    :new.KBRA_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KBRA_ROW_VERSION := nvl(:old.KBRA_ROW_VERSION, 0) + 1;
  end if;
end KBRA_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('KUKA_BIU', 'KUND_KUNDEN_UNTERKATEGORIEN');
end;
/

create or replace trigger KUKA_BIU
  before insert or update on KUND_KUNDEN_UNTERKATEGORIEN
  for each row
begin
  if inserting then
    :new.KUKA_ID := coalesce(:new.KUKA_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KUKA_CREATED_ON  := systimestamp;
    :new.KUKA_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KUKA_UPDATED_ON  := null;
    :new.KUKA_UPDATED_BY  := null;
    :new.KUKA_ROW_VERSION := 1;
  elsif updating then
    :new.KUKA_ID          := :old.KUKA_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KUKA_CREATED_ON  := :old.KUKA_CREATED_ON;
    :new.KUKA_CREATED_BY  := :old.KUKA_CREATED_BY;
    :new.KUKA_UPDATED_ON  := systimestamp;
    :new.KUKA_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KUKA_ROW_VERSION := nvl(:old.KUKA_ROW_VERSION, 0) + 1;
  end if;
  -- Unterkategorie muss zur Branche der Kunden-Branche-Zuordnung gehoeren
  declare
    l_ok pls_integer;
  begin
    select count(*) into l_ok
      from KUND_KUNDEN_BRANCHEN b
      join KUND_UNTERKATEGORIEN u on u.UKAT_BRAN_ID = b.KBRA_BRAN_ID
     where b.KBRA_ID = :new.KUKA_KBRA_ID and u.UKAT_ID = :new.KUKA_UKAT_ID;
    if l_ok = 0 then
      raise_application_error(-20110, 'Unterkategorie gehoert nicht zur Branche der Zuordnung.');
    end if;
  end;
end KUKA_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('ABTE_BIU', 'KUND_ABTEILUNGEN');
end;
/

create or replace trigger ABTE_BIU
  before insert or update on KUND_ABTEILUNGEN
  for each row
begin
  if inserting then
    :new.ABTE_ID := coalesce(:new.ABTE_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.ABTE_CREATED_ON  := systimestamp;
    :new.ABTE_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ABTE_UPDATED_ON  := null;
    :new.ABTE_UPDATED_BY  := null;
    :new.ABTE_ROW_VERSION := 1;
  elsif updating then
    :new.ABTE_ID          := :old.ABTE_ID;  -- Primaerschluessel ist unveraenderlich
    :new.ABTE_CREATED_ON  := :old.ABTE_CREATED_ON;
    :new.ABTE_CREATED_BY  := :old.ABTE_CREATED_BY;
    :new.ABTE_UPDATED_ON  := systimestamp;
    :new.ABTE_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ABTE_ROW_VERSION := nvl(:old.ABTE_ROW_VERSION, 0) + 1;
  end if;
end ABTE_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('FUNK_BIU', 'KUND_FUNKTIONEN');
end;
/

create or replace trigger FUNK_BIU
  before insert or update on KUND_FUNKTIONEN
  for each row
begin
  if inserting then
    :new.FUNK_ID := coalesce(:new.FUNK_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.FUNK_CREATED_ON  := systimestamp;
    :new.FUNK_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.FUNK_UPDATED_ON  := null;
    :new.FUNK_UPDATED_BY  := null;
    :new.FUNK_ROW_VERSION := 1;
  elsif updating then
    :new.FUNK_ID          := :old.FUNK_ID;  -- Primaerschluessel ist unveraenderlich
    :new.FUNK_CREATED_ON  := :old.FUNK_CREATED_ON;
    :new.FUNK_CREATED_BY  := :old.FUNK_CREATED_BY;
    :new.FUNK_UPDATED_ON  := systimestamp;
    :new.FUNK_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.FUNK_ROW_VERSION := nvl(:old.FUNK_ROW_VERSION, 0) + 1;
  end if;
end FUNK_BIU;
/

comment on table KUND_KUNDENGRUPPEN is 'Kundengruppen (OEM, Wiederverkaeufer, Endkunde) [Alias KGRP]';
comment on column KUND_KUNDENGRUPPEN.KGRP_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_KUNDENGRUPPEN.KGRP_CODE is 'Kuerzel, z.B. OEM, WV, EK';
comment on column KUND_KUNDENGRUPPEN.KGRP_BEZEICHNUNG is 'Bezeichnung';
comment on column KUND_KUNDENGRUPPEN.KGRP_SORTIERUNG is 'Reihenfolge';
comment on column KUND_KUNDENGRUPPEN.KGRP_IST_AKTIV is 'Y = auswaehlbar';
comment on column KUND_KUNDENGRUPPEN.KGRP_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_KUNDENGRUPPEN.KGRP_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_KUNDENGRUPPEN.KGRP_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_KUNDENGRUPPEN.KGRP_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_KUNDENGRUPPEN.KGRP_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_BRANCHEN is 'Branchen der Kunden [Alias BRAN]';
comment on column KUND_BRANCHEN.BRAN_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_BRANCHEN.BRAN_BEZEICHNUNG is 'Bezeichnung der Branche';
comment on column KUND_BRANCHEN.BRAN_BEWERTUNG is 'Bewertung 1 (niedrig) bis 5 (hoch)';
comment on column KUND_BRANCHEN.BRAN_SORTIERUNG is 'Reihenfolge';
comment on column KUND_BRANCHEN.BRAN_IST_AKTIV is 'Y = auswaehlbar';
comment on column KUND_BRANCHEN.BRAN_ALT_ID is 'ID im Altsystem (TBL_BRANCHE.BRAN_ID), fuer die Datenuebernahme';
comment on column KUND_BRANCHEN.BRAN_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_BRANCHEN.BRAN_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_BRANCHEN.BRAN_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_BRANCHEN.BRAN_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_BRANCHEN.BRAN_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_UNTERKATEGORIEN is 'Unterkategorien je Branche [Alias UKAT]';
comment on column KUND_UNTERKATEGORIEN.UKAT_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_UNTERKATEGORIEN.UKAT_BRAN_ID is 'FK: Branche';
comment on column KUND_UNTERKATEGORIEN.UKAT_BEZEICHNUNG is 'Bezeichnung der Unterkategorie';
comment on column KUND_UNTERKATEGORIEN.UKAT_BEWERTUNG is 'Bewertung 1 (niedrig) bis 5 (hoch)';
comment on column KUND_UNTERKATEGORIEN.UKAT_SORTIERUNG is 'Reihenfolge';
comment on column KUND_UNTERKATEGORIEN.UKAT_IST_AKTIV is 'Y = auswaehlbar';
comment on column KUND_UNTERKATEGORIEN.UKAT_ALT_ID is 'ID im Altsystem (TBL_UNTERKATEGORIE.UNKA_ID), fuer die Datenuebernahme';
comment on column KUND_UNTERKATEGORIEN.UKAT_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_UNTERKATEGORIEN.UKAT_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_UNTERKATEGORIEN.UKAT_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_UNTERKATEGORIEN.UKAT_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_UNTERKATEGORIEN.UKAT_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_KUNDEN_BRANCHEN is 'Zuordnung Kunde - Branche (n:m) [Alias KBRA]';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_KUND_ID is 'FK: Kunde';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_BRAN_ID is 'FK: Branche';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_KUNDEN_BRANCHEN.KBRA_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_KUNDEN_UNTERKATEGORIEN is 'Zuordnung Kunden-Branche - Unterkategorie (n:m) [Alias KUKA]';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_KBRA_ID is 'FK: Kunde-Branche-Zuordnung';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_UKAT_ID is 'FK: Unterkategorie (muss zur Branche der Zuordnung gehoeren)';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_KUNDEN_UNTERKATEGORIEN.KUKA_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_ABTEILUNGEN is 'Abteilungen der Ansprechpartner beim Kunden [Alias ABTE]';
comment on column KUND_ABTEILUNGEN.ABTE_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_ABTEILUNGEN.ABTE_CODE is 'Kuerzel, z.B. EK, VK, GF';
comment on column KUND_ABTEILUNGEN.ABTE_BEZEICHNUNG is 'Bezeichnung';
comment on column KUND_ABTEILUNGEN.ABTE_SORTIERUNG is 'Reihenfolge';
comment on column KUND_ABTEILUNGEN.ABTE_IST_AKTIV is 'Y = auswaehlbar';
comment on column KUND_ABTEILUNGEN.ABTE_ALT_ID is 'ID im Altsystem (TBL_ABTEILUNG.ABTE_ID), fuer die Datenuebernahme';
comment on column KUND_ABTEILUNGEN.ABTE_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_ABTEILUNGEN.ABTE_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_ABTEILUNGEN.ABTE_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_ABTEILUNGEN.ABTE_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_ABTEILUNGEN.ABTE_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_FUNKTIONEN is 'Funktionen der Ansprechpartner beim Kunden [Alias FUNK]';
comment on column KUND_FUNKTIONEN.FUNK_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_FUNKTIONEN.FUNK_CODE is 'Kuerzel, z.B. GF, ABL, SB';
comment on column KUND_FUNKTIONEN.FUNK_BEZEICHNUNG is 'Bezeichnung';
comment on column KUND_FUNKTIONEN.FUNK_SORTIERUNG is 'Reihenfolge';
comment on column KUND_FUNKTIONEN.FUNK_IST_AKTIV is 'Y = auswaehlbar';
comment on column KUND_FUNKTIONEN.FUNK_ALT_ID is 'ID im Altsystem (TBL_FUNKTION.FUNK_ID), fuer die Datenuebernahme';
comment on column KUND_FUNKTIONEN.FUNK_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_FUNKTIONEN.FUNK_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_FUNKTIONEN.FUNK_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_FUNKTIONEN.FUNK_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_FUNKTIONEN.FUNK_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on column KUND_KUNDEN.KUND_KGRP_ID is 'FK: Kundengruppe (OEM, Wiederverkaeufer, Endkunde)';
comment on column KUND_KUNDEN.KUND_KURZNAME is 'Kurzname / Suchbegriff (eindeutig)';
comment on column KUND_KUNDEN.KUND_NAMENSZUSATZ is 'Namenszusatz (2. Namenszeile)';
comment on column KUND_KUNDEN.KUND_SPRACHE is 'Korrespondenzsprache (ISO 639-1): de, en';
comment on column KUND_KUNDEN.KUND_UNTERNEHMENSGROESSE is 'Unternehmensgroesse: KU = Kleinstunternehmen, K = klein, M = mittel, G = gross';
comment on column KUND_KUNDEN.KUND_MITARBEITER_ANZAHL is 'Mitarbeiteranzahl (Groessenklasse als Text)';
comment on column KUND_KUNDEN.KUND_BUCHHALTUNGSNR is 'Nummer in der Buchhaltung (Altsystem BUCH_NR)';
comment on column KUND_KUNDEN.KUND_ZAHLUNGSBED_TEXT is 'Individuelle Zahlungsbedingung (Freitext, ergaenzend zu KUND_ZBED_ID)';
comment on column KUND_KUNDEN.KUND_LIEFERBEDINGUNG is 'Lieferbedingung (Freitext)';
comment on column KUND_KUNDEN.KUND_RABATT_TEXT is 'Rabattvereinbarung (Freitext)';
comment on column KUND_KUNDEN.KUND_BEMERKUNG is 'Bemerkung zum Kunden';
comment on column KUND_KUNDEN.KUND_ALT_ID is 'ID im Altsystem (TBL_KUNDE.KUND_ID), fuer die Datenuebernahme';
comment on column KUND_KUNDEN.KUND_ALT_SI_ID is 'Kontakt-ID im aelteren Altsystem (TBL_KUNDE.KUND_ID_SI = TBL_KONTAKT.ID_KONTAKT)';

comment on column KUND_ANSPRECHPARTNER.ANSP_ABTE_ID is 'FK: Abteilung';
comment on column KUND_ANSPRECHPARTNER.ANSP_FUNK_ID is 'FK: Funktion (ANSP_FUNKTION bleibt als Freitext)';
comment on column KUND_ANSPRECHPARTNER.ANSP_DURCHWAHL is 'Telefon-Durchwahl';
comment on column KUND_ANSPRECHPARTNER.ANSP_BEWERTUNG is 'Bewertung A, B, C, U, X (aus Altsystem)';
comment on column KUND_ANSPRECHPARTNER.ANSP_GEBURTSDATUM is 'Geburtsdatum';
comment on column KUND_ANSPRECHPARTNER.ANSP_IST_INFOMAIL is 'Y = Einwilligung Infomail/Newsletter';
comment on column KUND_ANSPRECHPARTNER.ANSP_INFOMAIL_AM is 'Datum der Infomail-Einwilligung';
comment on column KUND_ANSPRECHPARTNER.ANSP_BEMERKUNG is 'Bemerkung zum Ansprechpartner';
comment on column KUND_ANSPRECHPARTNER.ANSP_ALT_ID is 'ID im Altsystem (TBL_ANSPRECHPERSON.APER_ID), fuer die Datenuebernahme';

-- Grunddaten Kundengruppen (aus TBL_HAUPTGRUPPE); nur fehlende Zeilen
insert into KUND_KUNDENGRUPPEN (KGRP_CODE, KGRP_BEZEICHNUNG, KGRP_SORTIERUNG)
  select 'OEM', 'Anlagenbau (OEM)', 10 from dual where not exists (select 1 from KUND_KUNDENGRUPPEN where KGRP_CODE = 'OEM');
insert into KUND_KUNDENGRUPPEN (KGRP_CODE, KGRP_BEZEICHNUNG, KGRP_SORTIERUNG)
  select 'WV', 'Wiederverkäufer', 20 from dual where not exists (select 1 from KUND_KUNDENGRUPPEN where KGRP_CODE = 'WV');
insert into KUND_KUNDENGRUPPEN (KGRP_CODE, KGRP_BEZEICHNUNG, KGRP_SORTIERUNG)
  select 'EK', 'Endkunde', 30 from dual where not exists (select 1 from KUND_KUNDENGRUPPEN where KGRP_CODE = 'EK');
commit;

prompt Kundenstamm-Erweiterung installiert bzw. abgeglichen.
