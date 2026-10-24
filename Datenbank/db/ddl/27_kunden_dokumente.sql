-- =====================================================================
-- ThGERP-Datenmodell (Gruppe KUND)
-- 27 – Dokumente je Kunde und Mandant: KUND_DOKUMENTARTEN, KUND_KUNDEN_DOKUMENTE
--      Beliebige Dateien (PDF, Excel, Bilder …) beim Kunden, getrennt je Mandant und einer Dokumentart
--      zugeordnet. Pflege in App 20020 Seite 11, Registerkarte "Dokumente" (nur die Dokumente des
--      angemeldeten Mandanten), Bearbeiten in der Schublade Seite 16; Dokumentarten unter Administration >
--      Wertelisten (Seiten 190/191). Uebernommen aus dem Projekt Marchler (DDL 38).
-- Erzeugt: 2026-10-24
-- Wiederholbar (DDL_UTIL, Grunddaten nur fehlende Zeilen), Voraussetzung: 11_ddl_util.sql, 17_mandanten.sql
-- =====================================================================

set define off
set serveroutput on size unlimited

-- KUND_DOKUMENTARTEN (DART): Werteliste der Dokumentarten
begin
    DDL_UTIL.tabelle('KUND_DOKUMENTARTEN', q'~create table KUND_DOKUMENTARTEN (
  DART_ID number not null,
  DART_CODE varchar2(20 char) not null,
  DART_BEZEICHNUNG varchar2(100 char) not null,
  DART_SORTIERUNG number,
  DART_IST_AKTIV varchar2(1 char) default 'Y' not null,
  DART_CREATED_ON timestamp not null,
  DART_CREATED_BY varchar2(255 char) not null,
  DART_UPDATED_ON timestamp,
  DART_UPDATED_BY varchar2(255 char),
  DART_ROW_VERSION number not null,
  constraint DART_PK primary key (DART_ID)
)~');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_CODE', 'varchar2(20 char)', 'N');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_BEZEICHNUNG', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_SORTIERUNG', 'number', 'Y');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_DOKUMENTARTEN', 'DART_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_DOKUMENTARTEN', 'DART_PK', 'P', 'DART_ID');
    DDL_UTIL.constraint_('KUND_DOKUMENTARTEN', 'DART_CODE_UK', 'U', 'DART_CODE');
    DDL_UTIL.constraint_('KUND_DOKUMENTARTEN', 'DART_IST_AKTIV_CK', 'C', q'~DART_IST_AKTIV in ('Y', 'N')~');
    DDL_UTIL.trigger_pruefen('DART_BIU', 'KUND_DOKUMENTARTEN');
end;
/

create or replace trigger DART_BIU
  before insert or update on KUND_DOKUMENTARTEN
  for each row
begin
  if inserting then
    :new.DART_ID := coalesce(:new.DART_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.DART_CREATED_ON  := systimestamp;
    :new.DART_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DART_UPDATED_ON  := null;
    :new.DART_UPDATED_BY  := null;
    :new.DART_ROW_VERSION := 1;
  elsif updating then
    :new.DART_ID          := :old.DART_ID;  -- Primaerschluessel ist unveraenderlich
    :new.DART_CREATED_ON  := :old.DART_CREATED_ON;
    :new.DART_CREATED_BY  := :old.DART_CREATED_BY;
    :new.DART_UPDATED_ON  := systimestamp;
    :new.DART_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DART_ROW_VERSION := nvl(:old.DART_ROW_VERSION, 0) + 1;
  end if;
  :new.DART_CODE := upper(trim(:new.DART_CODE));
end DART_BIU;
/

-- KUND_KUNDEN_DOKUMENTE (KDOK): Dokument (Datei) je Kunde und Mandant
begin
    DDL_UTIL.tabelle('KUND_KUNDEN_DOKUMENTE', q'~create table KUND_KUNDEN_DOKUMENTE (
  KDOK_ID number not null,
  KDOK_KUND_ID number not null,
  KDOK_MAND_ID number not null,
  KDOK_DART_ID number not null,
  KDOK_BEZEICHNUNG varchar2(200 char) not null,
  KDOK_BESCHREIBUNG varchar2(4000 char),
  KDOK_DATEINAME varchar2(400 char) not null,
  KDOK_MIME_TYPE varchar2(255 char),
  KDOK_GROESSE number,
  KDOK_DATEI blob not null,
  KDOK_CREATED_ON timestamp not null,
  KDOK_CREATED_BY varchar2(255 char) not null,
  KDOK_UPDATED_ON timestamp,
  KDOK_UPDATED_BY varchar2(255 char),
  KDOK_ROW_VERSION number not null,
  constraint KDOK_PK primary key (KDOK_ID)
)~');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_KUND_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_MAND_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_DART_ID', 'number', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_BEZEICHNUNG', 'varchar2(200 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_BESCHREIBUNG', 'varchar2(4000 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_DATEINAME', 'varchar2(400 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_MIME_TYPE', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_GROESSE', 'number', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_DATEI', 'blob', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('KUND_KUNDEN_DOKUMENTE', 'KDOK_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('KUND_KUNDEN_DOKUMENTE', 'KDOK_PK', 'P', 'KDOK_ID');
    DDL_UTIL.constraint_('KUND_KUNDEN_DOKUMENTE', 'KDOK_KUND_FK', 'R', 'KDOK_KUND_ID references KUND_KUNDEN (KUND_ID) on delete cascade');
    DDL_UTIL.constraint_('KUND_KUNDEN_DOKUMENTE', 'KDOK_MAND_FK', 'R', 'KDOK_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('KUND_KUNDEN_DOKUMENTE', 'KDOK_DART_FK', 'R', 'KDOK_DART_ID references KUND_DOKUMENTARTEN (DART_ID)');
    DDL_UTIL.index_('KUND_KUNDEN_DOKUMENTE', 'KDOK_KUND_I', 'KDOK_KUND_ID, KDOK_MAND_ID');
    DDL_UTIL.index_('KUND_KUNDEN_DOKUMENTE', 'KDOK_MAND_I', 'KDOK_MAND_ID');
    DDL_UTIL.index_('KUND_KUNDEN_DOKUMENTE', 'KDOK_DART_I', 'KDOK_DART_ID');
    DDL_UTIL.trigger_pruefen('KDOK_BIU', 'KUND_KUNDEN_DOKUMENTE');
end;
/

create or replace trigger KDOK_BIU
  before insert or update on KUND_KUNDEN_DOKUMENTE
  for each row
begin
  if inserting then
    :new.KDOK_ID := coalesce(:new.KDOK_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KDOK_CREATED_ON  := systimestamp;
    :new.KDOK_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KDOK_UPDATED_ON  := null;
    :new.KDOK_UPDATED_BY  := null;
    :new.KDOK_ROW_VERSION := 1;
  elsif updating then
    :new.KDOK_ID          := :old.KDOK_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KDOK_CREATED_ON  := :old.KDOK_CREATED_ON;
    :new.KDOK_CREATED_BY  := :old.KDOK_CREATED_BY;
    :new.KDOK_UPDATED_ON  := systimestamp;
    :new.KDOK_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KDOK_ROW_VERSION := nvl(:old.KDOK_ROW_VERSION, 0) + 1;
  end if;
  -- Groesse immer aus der Datei
  :new.KDOK_GROESSE := dbms_lob.getlength(:new.KDOK_DATEI);
end KDOK_BIU;
/

comment on table KUND_DOKUMENTARTEN is 'Dokumentarten der Kundendokumente (Vertrag, Zeichnung …) [Alias DART]';
comment on column KUND_DOKUMENTARTEN.DART_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_DOKUMENTARTEN.DART_CODE is 'Technischer Code (eindeutig, Grossbuchstaben)';
comment on column KUND_DOKUMENTARTEN.DART_BEZEICHNUNG is 'Bezeichnung (Anzeige)';
comment on column KUND_DOKUMENTARTEN.DART_SORTIERUNG is 'Sortierung in Auswahllisten';
comment on column KUND_DOKUMENTARTEN.DART_IST_AKTIV is 'Y = fuer neue Dokumente waehlbar';
comment on column KUND_DOKUMENTARTEN.DART_CREATED_ON is 'Audit: angelegt am';
comment on column KUND_DOKUMENTARTEN.DART_CREATED_BY is 'Audit: angelegt von';
comment on column KUND_DOKUMENTARTEN.DART_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_DOKUMENTARTEN.DART_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_DOKUMENTARTEN.DART_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table KUND_KUNDEN_DOKUMENTE is 'Dokumente (Dateien) je Kunde und Mandant [Alias KDOK]';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_ID is 'Primaerschluessel (SYS_GUID)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_KUND_ID is 'FK: Kunde';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_MAND_ID is 'FK: Mandant, fuer den das Dokument gilt';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_DART_ID is 'FK: Dokumentart';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_BEZEICHNUNG is 'Bezeichnung des Dokuments (Vorgabe: Dateiname)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_BESCHREIBUNG is 'Beschreibung (optional)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_DATEINAME is 'Dateiname beim Hochladen';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_MIME_TYPE is 'MIME-Typ der Datei';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_GROESSE is 'Groesse in Bytes (Trigger)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_DATEI is 'Datei (Inhalt)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_CREATED_ON is 'Audit: angelegt am (hochgeladen am)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_CREATED_BY is 'Audit: angelegt von (hochgeladen von)';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column KUND_KUNDEN_DOKUMENTE.KDOK_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

-- Grunddaten: nur fehlende Dokumentarten
insert into KUND_DOKUMENTARTEN (DART_CODE, DART_BEZEICHNUNG, DART_SORTIERUNG)
  select 'VERTRAG', 'Vertrag', 10 from dual where not exists (select 1 from KUND_DOKUMENTARTEN where DART_CODE = 'VERTRAG');
insert into KUND_DOKUMENTARTEN (DART_CODE, DART_BEZEICHNUNG, DART_SORTIERUNG)
  select 'ANGEBOT', 'Angebot', 20 from dual where not exists (select 1 from KUND_DOKUMENTARTEN where DART_CODE = 'ANGEBOT');
insert into KUND_DOKUMENTARTEN (DART_CODE, DART_BEZEICHNUNG, DART_SORTIERUNG)
  select 'LIZENZ', 'Lizenz', 30 from dual where not exists (select 1 from KUND_DOKUMENTARTEN where DART_CODE = 'LIZENZ');
insert into KUND_DOKUMENTARTEN (DART_CODE, DART_BEZEICHNUNG, DART_SORTIERUNG)
  select 'DOKUMENTATION', 'Dokumentation', 40 from dual where not exists (select 1 from KUND_DOKUMENTARTEN where DART_CODE = 'DOKUMENTATION');
insert into KUND_DOKUMENTARTEN (DART_CODE, DART_BEZEICHNUNG, DART_SORTIERUNG)
  select 'KORRESPONDENZ', 'Korrespondenz', 50 from dual where not exists (select 1 from KUND_DOKUMENTARTEN where DART_CODE = 'KORRESPONDENZ');
insert into KUND_DOKUMENTARTEN (DART_CODE, DART_BEZEICHNUNG, DART_SORTIERUNG)
  select 'SONSTIGES', 'Sonstiges', 90 from dual where not exists (select 1 from KUND_DOKUMENTARTEN where DART_CODE = 'SONSTIGES');
commit;

prompt KUND_DOKUMENTARTEN, KUND_KUNDEN_DOKUMENTE installiert bzw. abgeglichen.
