-- =====================================================================
-- ThGERP (Gruppen ARTI, ALLG)
-- 19 – Artikelstamm (in der App THG-FINANZ), abgeleitet aus der Kingbill-Artikelmaske:
--      neu: ALLG_EINHEITEN, ALLG_MWST_SAETZE, ALLG_TEXTVORLAGEN, ARTI_ARTIKELGRUPPEN, ARTI_ARTIKEL
--      Grunddaten: MwSt.-Saetze 0/10/20 % (Standard 20), Einheiten
--      (Zusatzfelder, Artikeldateien und Artikelbild 2026-10-24 entfernt – bestehende Schemas: Skript 29)
-- GENERIERT mit generator/gen_19_20_artikel_fakturierung.py – nicht von Hand bearbeiten
-- Erzeugt: 2026-09-26
-- Wiederholbar (DDL_UTIL; Grunddaten nur fehlende Zeilen).
-- =====================================================================

set define off
set serveroutput on size unlimited

-- ALLG_EINHEITEN (EINH): Mengeneinheiten (Stk., Std., Pauschale …) fuer Artikel und Belegpositionen
begin
    DDL_UTIL.tabelle('ALLG_EINHEITEN', q'~create table ALLG_EINHEITEN (
  EINH_ID number not null,
  EINH_CODE varchar2(10 char) not null,
  EINH_BEZEICHNUNG varchar2(50 char) not null,
  EINH_SORTIERUNG number(5),
  EINH_IST_AKTIV varchar2(1 char) default 'Y' not null,
  EINH_CREATED_ON timestamp not null,
  EINH_CREATED_BY varchar2(255 char) not null,
  EINH_UPDATED_ON timestamp,
  EINH_UPDATED_BY varchar2(255 char),
  EINH_ROW_VERSION number not null,
  constraint EINH_PK primary key (EINH_ID)
)~');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_ID', 'number', 'N');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_CODE', 'varchar2(10 char)', 'N');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_BEZEICHNUNG', 'varchar2(50 char)', 'N');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ALLG_EINHEITEN', 'EINH_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ALLG_EINHEITEN', 'EINH_PK', 'P', 'EINH_ID');
    DDL_UTIL.constraint_('ALLG_EINHEITEN', 'EINH_CODE_UK', 'U', q'~EINH_CODE~');
    DDL_UTIL.constraint_('ALLG_EINHEITEN', 'EINH_IST_AKTIV_CK', 'C', q'~EINH_IST_AKTIV in ('Y', 'N')~');
end;
/

-- ALLG_MWST_SAETZE (MWST): Umsatzsteuersaetze
begin
    DDL_UTIL.tabelle('ALLG_MWST_SAETZE', q'~create table ALLG_MWST_SAETZE (
  MWST_ID number not null,
  MWST_PROZENT number(5,2) not null,
  MWST_BEZEICHNUNG varchar2(50 char) not null,
  MWST_IST_STANDARD varchar2(1 char) default 'N' not null,
  MWST_IST_AKTIV varchar2(1 char) default 'Y' not null,
  MWST_SORTIERUNG number(5),
  MWST_CREATED_ON timestamp not null,
  MWST_CREATED_BY varchar2(255 char) not null,
  MWST_UPDATED_ON timestamp,
  MWST_UPDATED_BY varchar2(255 char),
  MWST_ROW_VERSION number not null,
  constraint MWST_PK primary key (MWST_ID)
)~');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_ID', 'number', 'N');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_PROZENT', 'number(5,2)', 'N');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_BEZEICHNUNG', 'varchar2(50 char)', 'N');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_IST_STANDARD', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ALLG_MWST_SAETZE', 'MWST_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ALLG_MWST_SAETZE', 'MWST_PK', 'P', 'MWST_ID');
    DDL_UTIL.constraint_('ALLG_MWST_SAETZE', 'MWST_PROZENT_UK', 'U', q'~MWST_PROZENT~');
    DDL_UTIL.constraint_('ALLG_MWST_SAETZE', 'MWST_PROZENT_CK', 'C', q'~MWST_PROZENT between 0 and 100~');
    DDL_UTIL.constraint_('ALLG_MWST_SAETZE', 'MWST_IST_STANDARD_CK', 'C', q'~MWST_IST_STANDARD in ('Y', 'N')~');
    DDL_UTIL.constraint_('ALLG_MWST_SAETZE', 'MWST_IST_AKTIV_CK', 'C', q'~MWST_IST_AKTIV in ('Y', 'N')~');
end;
/

-- ALLG_TEXTVORLAGEN (TXVL): Textvorlagen fuer Belege (Zahlungsbedingungen, Vortext, Schlusstext)
begin
    DDL_UTIL.tabelle('ALLG_TEXTVORLAGEN', q'~create table ALLG_TEXTVORLAGEN (
  TXVL_ID number not null,
  TXVL_ART varchar2(20 char) not null,
  TXVL_BEZEICHNUNG varchar2(100 char) not null,
  TXVL_TEXT clob,
  TXVL_IST_STANDARD varchar2(1 char) default 'N' not null,
  TXVL_SORTIERUNG number(5),
  TXVL_CREATED_ON timestamp not null,
  TXVL_CREATED_BY varchar2(255 char) not null,
  TXVL_UPDATED_ON timestamp,
  TXVL_UPDATED_BY varchar2(255 char),
  TXVL_ROW_VERSION number not null,
  constraint TXVL_PK primary key (TXVL_ID)
)~');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_ID', 'number', 'N');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_ART', 'varchar2(20 char)', 'N');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_BEZEICHNUNG', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_TEXT', 'clob', 'Y');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_IST_STANDARD', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ALLG_TEXTVORLAGEN', 'TXVL_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ALLG_TEXTVORLAGEN', 'TXVL_PK', 'P', 'TXVL_ID');
    DDL_UTIL.constraint_('ALLG_TEXTVORLAGEN', 'TXVL_UK', 'U', q'~TXVL_ART, TXVL_BEZEICHNUNG~');
    DDL_UTIL.constraint_('ALLG_TEXTVORLAGEN', 'TXVL_ART_CK', 'C', q'~TXVL_ART in ('ZAHLUNGSBED', 'VORTEXT', 'SCHLUSSTEXT')~');
    DDL_UTIL.constraint_('ALLG_TEXTVORLAGEN', 'TXVL_IST_STANDARD_CK', 'C', q'~TXVL_IST_STANDARD in ('Y', 'N')~');
end;
/

-- ARTI_ARTIKELGRUPPEN (AGRP): Artikelgruppen (Kingbill: Gruppe)
begin
    DDL_UTIL.tabelle('ARTI_ARTIKELGRUPPEN', q'~create table ARTI_ARTIKELGRUPPEN (
  AGRP_ID number not null,
  AGRP_CODE varchar2(20 char) not null,
  AGRP_BEZEICHNUNG varchar2(100 char) not null,
  AGRP_SORTIERUNG number(5),
  AGRP_IST_AKTIV varchar2(1 char) default 'Y' not null,
  AGRP_CREATED_ON timestamp not null,
  AGRP_CREATED_BY varchar2(255 char) not null,
  AGRP_UPDATED_ON timestamp,
  AGRP_UPDATED_BY varchar2(255 char),
  AGRP_ROW_VERSION number not null,
  constraint AGRP_PK primary key (AGRP_ID)
)~');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_ID', 'number', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_CODE', 'varchar2(20 char)', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_BEZEICHNUNG', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKELGRUPPEN', 'AGRP_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ARTI_ARTIKELGRUPPEN', 'AGRP_PK', 'P', 'AGRP_ID');
    DDL_UTIL.constraint_('ARTI_ARTIKELGRUPPEN', 'AGRP_CODE_UK', 'U', q'~AGRP_CODE~');
    DDL_UTIL.constraint_('ARTI_ARTIKELGRUPPEN', 'AGRP_IST_AKTIV_CK', 'C', q'~AGRP_IST_AKTIV in ('Y', 'N')~');
end;
/

-- ARTI_ARTIKEL (ARTI): Artikelstamm (Waren und Dienstleistungen)
begin
    DDL_UTIL.tabelle('ARTI_ARTIKEL', q'~create table ARTI_ARTIKEL (
  ARTI_ID number not null,
  ARTI_AGRP_ID number,
  ARTI_EINH_ID number,
  ARTI_MWST_ID number not null,
  ARTI_NUMMER varchar2(30 char) not null,
  ARTI_NAME varchar2(200 char) not null,
  ARTI_BESCHREIBUNG clob,
  ARTI_VK_PREIS number(12,2) default 0 not null,
  ARTI_IST_BRUTTO varchar2(1 char) default 'N' not null,
  ARTI_EK_PREIS number(12,2),
  ARTI_EAN varchar2(20 char),
  ARTI_ERLOESKONTO varchar2(20 char),
  ARTI_AUFGENOMMEN_AM date default trunc(cast(systimestamp at time zone 'Europe/Vienna' as date)) not null,
  ARTI_KOMMENTAR clob,
  ARTI_IST_AKTIV varchar2(1 char) default 'Y' not null,
  ARTI_ALT_ID number,
  ARTI_CREATED_ON timestamp not null,
  ARTI_CREATED_BY varchar2(255 char) not null,
  ARTI_UPDATED_ON timestamp,
  ARTI_UPDATED_BY varchar2(255 char),
  ARTI_ROW_VERSION number not null,
  constraint ARTI_PK primary key (ARTI_ID)
)~');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_ID', 'number', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_AGRP_ID', 'number', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_EINH_ID', 'number', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_MWST_ID', 'number', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_NUMMER', 'varchar2(30 char)', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_NAME', 'varchar2(200 char)', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_BESCHREIBUNG', 'clob', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_VK_PREIS', 'number(12,2)', 'N', q'~0~');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_IST_BRUTTO', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_EK_PREIS', 'number(12,2)', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_EAN', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_ERLOESKONTO', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_AUFGENOMMEN_AM', 'date', 'N', q'~trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))~');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_KOMMENTAR', 'clob', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_ALT_ID', 'number', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ARTI_ARTIKEL', 'ARTI_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_PK', 'P', 'ARTI_ID');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_NUMMER_UK', 'U', q'~ARTI_NUMMER~');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_ALT_ID_UK', 'U', q'~ARTI_ALT_ID~');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_VK_PREIS_CK', 'C', q'~ARTI_VK_PREIS >= 0~');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_IST_BRUTTO_CK', 'C', q'~ARTI_IST_BRUTTO in ('Y', 'N')~');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_IST_AKTIV_CK', 'C', q'~ARTI_IST_AKTIV in ('Y', 'N')~');
end;
/

-- Fremdschluessel, FK-Indizes und fachliche Indizes
begin
    DDL_UTIL.index_('ALLG_MWST_SAETZE', 'MWST_STANDARD_UI', q'~case when MWST_IST_STANDARD = 'Y' then 'Y' end~', true);
    DDL_UTIL.index_('ALLG_TEXTVORLAGEN', 'TXVL_STANDARD_UI', q'~case when TXVL_IST_STANDARD = 'Y' then TXVL_ART end~', true);
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_AGRP_FK', 'R', 'ARTI_AGRP_ID references ARTI_ARTIKELGRUPPEN (AGRP_ID)');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_EINH_FK', 'R', 'ARTI_EINH_ID references ALLG_EINHEITEN (EINH_ID)');
    DDL_UTIL.constraint_('ARTI_ARTIKEL', 'ARTI_MWST_FK', 'R', 'ARTI_MWST_ID references ALLG_MWST_SAETZE (MWST_ID)');
    DDL_UTIL.index_('ARTI_ARTIKEL', 'ARTI_AGRP_I', q'~ARTI_AGRP_ID~');
    DDL_UTIL.index_('ARTI_ARTIKEL', 'ARTI_EINH_I', q'~ARTI_EINH_ID~');
    DDL_UTIL.index_('ARTI_ARTIKEL', 'ARTI_MWST_I', q'~ARTI_MWST_ID~');
    DDL_UTIL.index_('ARTI_ARTIKEL', 'ARTI_NAME_I', q'~upper(ARTI_NAME)~');
end;
/

begin
    DDL_UTIL.trigger_pruefen('EINH_BIU', 'ALLG_EINHEITEN');
end;
/

create or replace trigger EINH_BIU
  before insert or update on ALLG_EINHEITEN
  for each row
begin
  if inserting then
    :new.EINH_ID := coalesce(:new.EINH_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.EINH_CREATED_ON  := systimestamp;
    :new.EINH_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.EINH_UPDATED_ON  := null;
    :new.EINH_UPDATED_BY  := null;
    :new.EINH_ROW_VERSION := 1;
  elsif updating then
    :new.EINH_ID          := :old.EINH_ID;  -- Primaerschluessel ist unveraenderlich
    :new.EINH_CREATED_ON  := :old.EINH_CREATED_ON;
    :new.EINH_CREATED_BY  := :old.EINH_CREATED_BY;
    :new.EINH_UPDATED_ON  := systimestamp;
    :new.EINH_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.EINH_ROW_VERSION := nvl(:old.EINH_ROW_VERSION, 0) + 1;
  end if;
end EINH_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('MWST_BIU', 'ALLG_MWST_SAETZE');
end;
/

create or replace trigger MWST_BIU
  before insert or update on ALLG_MWST_SAETZE
  for each row
begin
  if inserting then
    :new.MWST_ID := coalesce(:new.MWST_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MWST_CREATED_ON  := systimestamp;
    :new.MWST_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MWST_UPDATED_ON  := null;
    :new.MWST_UPDATED_BY  := null;
    :new.MWST_ROW_VERSION := 1;
  elsif updating then
    :new.MWST_ID          := :old.MWST_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MWST_CREATED_ON  := :old.MWST_CREATED_ON;
    :new.MWST_CREATED_BY  := :old.MWST_CREATED_BY;
    :new.MWST_UPDATED_ON  := systimestamp;
    :new.MWST_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MWST_ROW_VERSION := nvl(:old.MWST_ROW_VERSION, 0) + 1;
  end if;
end MWST_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('TXVL_BIU', 'ALLG_TEXTVORLAGEN');
end;
/

create or replace trigger TXVL_BIU
  before insert or update on ALLG_TEXTVORLAGEN
  for each row
begin
  if inserting then
    :new.TXVL_ID := coalesce(:new.TXVL_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.TXVL_CREATED_ON  := systimestamp;
    :new.TXVL_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.TXVL_UPDATED_ON  := null;
    :new.TXVL_UPDATED_BY  := null;
    :new.TXVL_ROW_VERSION := 1;
  elsif updating then
    :new.TXVL_ID          := :old.TXVL_ID;  -- Primaerschluessel ist unveraenderlich
    :new.TXVL_CREATED_ON  := :old.TXVL_CREATED_ON;
    :new.TXVL_CREATED_BY  := :old.TXVL_CREATED_BY;
    :new.TXVL_UPDATED_ON  := systimestamp;
    :new.TXVL_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.TXVL_ROW_VERSION := nvl(:old.TXVL_ROW_VERSION, 0) + 1;
  end if;
end TXVL_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('AGRP_BIU', 'ARTI_ARTIKELGRUPPEN');
end;
/

create or replace trigger AGRP_BIU
  before insert or update on ARTI_ARTIKELGRUPPEN
  for each row
begin
  if inserting then
    :new.AGRP_ID := coalesce(:new.AGRP_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.AGRP_CREATED_ON  := systimestamp;
    :new.AGRP_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.AGRP_UPDATED_ON  := null;
    :new.AGRP_UPDATED_BY  := null;
    :new.AGRP_ROW_VERSION := 1;
  elsif updating then
    :new.AGRP_ID          := :old.AGRP_ID;  -- Primaerschluessel ist unveraenderlich
    :new.AGRP_CREATED_ON  := :old.AGRP_CREATED_ON;
    :new.AGRP_CREATED_BY  := :old.AGRP_CREATED_BY;
    :new.AGRP_UPDATED_ON  := systimestamp;
    :new.AGRP_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.AGRP_ROW_VERSION := nvl(:old.AGRP_ROW_VERSION, 0) + 1;
  end if;
end AGRP_BIU;
/

begin
    DDL_UTIL.trigger_pruefen('ARTI_BIU', 'ARTI_ARTIKEL');
end;
/

create or replace trigger ARTI_BIU
  before insert or update on ARTI_ARTIKEL
  for each row
begin
  if inserting then
    :new.ARTI_ID := coalesce(:new.ARTI_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.ARTI_CREATED_ON  := systimestamp;
    :new.ARTI_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ARTI_UPDATED_ON  := null;
    :new.ARTI_UPDATED_BY  := null;
    :new.ARTI_ROW_VERSION := 1;
  elsif updating then
    :new.ARTI_ID          := :old.ARTI_ID;  -- Primaerschluessel ist unveraenderlich
    :new.ARTI_CREATED_ON  := :old.ARTI_CREATED_ON;
    :new.ARTI_CREATED_BY  := :old.ARTI_CREATED_BY;
    :new.ARTI_UPDATED_ON  := systimestamp;
    :new.ARTI_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ARTI_ROW_VERSION := nvl(:old.ARTI_ROW_VERSION, 0) + 1;
  end if;
end ARTI_BIU;
/

comment on table ALLG_EINHEITEN is 'Mengeneinheiten (Stk., Std., Pauschale …) fuer Artikel und Belegpositionen [Alias EINH]';
comment on column ALLG_EINHEITEN.EINH_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ALLG_EINHEITEN.EINH_CODE is 'Kuerzel, wie auf dem Beleg angedruckt, z.B. Stk., Std.';
comment on column ALLG_EINHEITEN.EINH_BEZEICHNUNG is 'Bezeichnung, z.B. Stueck, Stunde';
comment on column ALLG_EINHEITEN.EINH_SORTIERUNG is 'Reihenfolge';
comment on column ALLG_EINHEITEN.EINH_IST_AKTIV is 'Y = auswaehlbar';
comment on column ALLG_EINHEITEN.EINH_CREATED_ON is 'Audit: angelegt am';
comment on column ALLG_EINHEITEN.EINH_CREATED_BY is 'Audit: angelegt von';
comment on column ALLG_EINHEITEN.EINH_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ALLG_EINHEITEN.EINH_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ALLG_EINHEITEN.EINH_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table ALLG_MWST_SAETZE is 'Umsatzsteuersaetze [Alias MWST]';
comment on column ALLG_MWST_SAETZE.MWST_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ALLG_MWST_SAETZE.MWST_PROZENT is 'Steuersatz in Prozent, z.B. 20';
comment on column ALLG_MWST_SAETZE.MWST_BEZEICHNUNG is 'Bezeichnung, z.B. 20 % Normalsteuersatz';
comment on column ALLG_MWST_SAETZE.MWST_IST_STANDARD is 'Y = Vorschlag fuer neue Artikel/Positionen (hoechstens einer)';
comment on column ALLG_MWST_SAETZE.MWST_IST_AKTIV is 'Y = auswaehlbar';
comment on column ALLG_MWST_SAETZE.MWST_SORTIERUNG is 'Reihenfolge';
comment on column ALLG_MWST_SAETZE.MWST_CREATED_ON is 'Audit: angelegt am';
comment on column ALLG_MWST_SAETZE.MWST_CREATED_BY is 'Audit: angelegt von';
comment on column ALLG_MWST_SAETZE.MWST_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ALLG_MWST_SAETZE.MWST_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ALLG_MWST_SAETZE.MWST_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table ALLG_TEXTVORLAGEN is 'Textvorlagen fuer Belege (Zahlungsbedingungen, Vortext, Schlusstext) [Alias TXVL]';
comment on column ALLG_TEXTVORLAGEN.TXVL_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ALLG_TEXTVORLAGEN.TXVL_ART is 'ZAHLUNGSBED, VORTEXT oder SCHLUSSTEXT';
comment on column ALLG_TEXTVORLAGEN.TXVL_BEZEICHNUNG is 'Name der Vorlage, z.B. Banküberweisung';
comment on column ALLG_TEXTVORLAGEN.TXVL_TEXT is 'Text der Vorlage';
comment on column ALLG_TEXTVORLAGEN.TXVL_IST_STANDARD is 'Y = Vorschlag fuer neue Belege (hoechstens einer je Art)';
comment on column ALLG_TEXTVORLAGEN.TXVL_SORTIERUNG is 'Reihenfolge';
comment on column ALLG_TEXTVORLAGEN.TXVL_CREATED_ON is 'Audit: angelegt am';
comment on column ALLG_TEXTVORLAGEN.TXVL_CREATED_BY is 'Audit: angelegt von';
comment on column ALLG_TEXTVORLAGEN.TXVL_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ALLG_TEXTVORLAGEN.TXVL_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ALLG_TEXTVORLAGEN.TXVL_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table ARTI_ARTIKELGRUPPEN is 'Artikelgruppen (Kingbill: Gruppe) [Alias AGRP]';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_CODE is 'Kuerzel';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_BEZEICHNUNG is 'Bezeichnung';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_SORTIERUNG is 'Reihenfolge';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_IST_AKTIV is 'Y = auswaehlbar';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_CREATED_ON is 'Audit: angelegt am';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_CREATED_BY is 'Audit: angelegt von';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ARTI_ARTIKELGRUPPEN.AGRP_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table ARTI_ARTIKEL is 'Artikelstamm (Waren und Dienstleistungen) [Alias ARTI]';
comment on column ARTI_ARTIKEL.ARTI_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ARTI_ARTIKEL.ARTI_AGRP_ID is 'FK: Artikelgruppe';
comment on column ARTI_ARTIKEL.ARTI_EINH_ID is 'FK: Mengeneinheit';
comment on column ARTI_ARTIKEL.ARTI_MWST_ID is 'FK: Umsatzsteuersatz';
comment on column ARTI_ARTIKEL.ARTI_NUMMER is 'Artikelnummer (eindeutig)';
comment on column ARTI_ARTIKEL.ARTI_NAME is 'Artikelname (Positionstext)';
comment on column ARTI_ARTIKEL.ARTI_BESCHREIBUNG is 'Beschreibung (formatiert, HTML), wird in die Belegposition uebernommen';
comment on column ARTI_ARTIKEL.ARTI_VK_PREIS is 'Verkaufspreis (netto bzw. brutto lt. ARTI_IST_BRUTTO)';
comment on column ARTI_ARTIKEL.ARTI_IST_BRUTTO is 'Y = Verkaufspreis ist brutto';
comment on column ARTI_ARTIKEL.ARTI_EK_PREIS is 'Einkaufspreis netto';
comment on column ARTI_ARTIKEL.ARTI_EAN is 'Barcode EAN/GTIN';
comment on column ARTI_ARTIKEL.ARTI_ERLOESKONTO is 'Erloeskonto fuer die Buchhaltung';
comment on column ARTI_ARTIKEL.ARTI_AUFGENOMMEN_AM is 'Datum der Aufnahme in den Artikelstamm';
comment on column ARTI_ARTIKEL.ARTI_KOMMENTAR is 'Interner Kommentar (nicht auf Belegen)';
comment on column ARTI_ARTIKEL.ARTI_IST_AKTIV is 'Y = in Belegen auswaehlbar (Artikel nie loeschen)';
comment on column ARTI_ARTIKEL.ARTI_ALT_ID is 'ID im Altsystem (Kingbill Product.ID), fuer die Datenuebernahme';
comment on column ARTI_ARTIKEL.ARTI_CREATED_ON is 'Audit: angelegt am';
comment on column ARTI_ARTIKEL.ARTI_CREATED_BY is 'Audit: angelegt von';
comment on column ARTI_ARTIKEL.ARTI_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ARTI_ARTIKEL.ARTI_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ARTI_ARTIKEL.ARTI_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

-- Grunddaten: nur fehlende Zeilen
insert into ALLG_MWST_SAETZE (MWST_PROZENT, MWST_BEZEICHNUNG, MWST_IST_STANDARD, MWST_SORTIERUNG)
  select 0, '0 % steuerfrei', 'N', 30 from dual
   where not exists (select 1 from ALLG_MWST_SAETZE where MWST_PROZENT = 0);
insert into ALLG_MWST_SAETZE (MWST_PROZENT, MWST_BEZEICHNUNG, MWST_IST_STANDARD, MWST_SORTIERUNG)
  select 10, '10 % ermaessigt', 'N', 20 from dual
   where not exists (select 1 from ALLG_MWST_SAETZE where MWST_PROZENT = 10);
insert into ALLG_MWST_SAETZE (MWST_PROZENT, MWST_BEZEICHNUNG, MWST_IST_STANDARD, MWST_SORTIERUNG)
  select 20, '20 % Normalsteuersatz', 'Y', 10 from dual
   where not exists (select 1 from ALLG_MWST_SAETZE where MWST_PROZENT = 20);
insert into ALLG_EINHEITEN (EINH_CODE, EINH_BEZEICHNUNG, EINH_SORTIERUNG)
  select 'Stk.', 'Stück', 10 from dual
   where not exists (select 1 from ALLG_EINHEITEN where EINH_CODE = 'Stk.');
insert into ALLG_EINHEITEN (EINH_CODE, EINH_BEZEICHNUNG, EINH_SORTIERUNG)
  select 'Std.', 'Stunde', 20 from dual
   where not exists (select 1 from ALLG_EINHEITEN where EINH_CODE = 'Std.');
insert into ALLG_EINHEITEN (EINH_CODE, EINH_BEZEICHNUNG, EINH_SORTIERUNG)
  select 'Pauschale', 'Pauschale', 30 from dual
   where not exists (select 1 from ALLG_EINHEITEN where EINH_CODE = 'Pauschale');
insert into ALLG_EINHEITEN (EINH_CODE, EINH_BEZEICHNUNG, EINH_SORTIERUNG)
  select 'Tag', 'Tag', 40 from dual
   where not exists (select 1 from ALLG_EINHEITEN where EINH_CODE = 'Tag');
insert into ALLG_EINHEITEN (EINH_CODE, EINH_BEZEICHNUNG, EINH_SORTIERUNG)
  select 'm²', 'Quadratmeter', 50 from dual
   where not exists (select 1 from ALLG_EINHEITEN where EINH_CODE = 'm²');
insert into ALLG_EINHEITEN (EINH_CODE, EINH_BEZEICHNUNG, EINH_SORTIERUNG)
  select 'lfm', 'Laufmeter', 60 from dual
   where not exists (select 1 from ALLG_EINHEITEN where EINH_CODE = 'lfm');
commit;

prompt ALLG_EINHEITEN, ALLG_MWST_SAETZE, ALLG_TEXTVORLAGEN, ARTI_ARTIKELGRUPPEN, ARTI_ARTIKEL installiert bzw. abgeglichen.
