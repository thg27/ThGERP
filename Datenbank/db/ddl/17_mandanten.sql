-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 17 – Mandanten:
--      neu: ADMIN_MANDANTEN (THG-EDV GmbH, Thomas Gesslbauer GmbH)
--      erweitert: ALLG_MITARBEITER (APEX-Benutzername, Standard-Mandant fuer den Login)
--      Kundendaten sind mandantenuebergreifend; mandantenabhaengige Daten (z.B. Rechnungen)
--      verweisen spaeter per <ALIAS>_MAND_ID auf ADMIN_MANDANTEN.
-- Erzeugt: 2026-09-26
-- Wiederholbar (nutzt DDL_UTIL aus 11_ddl_util.sql, Grunddaten nur fehlende Zeilen).
-- =====================================================================

set define off
set serveroutput on size unlimited

-- ADMIN_MANDANTEN (MAND): Firmen, fuer die im ERP gearbeitet wird
begin
    DDL_UTIL.tabelle('ADMIN_MANDANTEN', q'~create table ADMIN_MANDANTEN (
  MAND_ID number not null,
  MAND_CODE varchar2(10 char) not null,
  MAND_NAME varchar2(100 char) not null,
  MAND_KURZNAME varchar2(30 char) not null,
  MAND_LOGO_DATEI varchar2(255 char),
  MAND_SORTIERUNG number(5),
  MAND_IST_AKTIV varchar2(1 char) default 'Y' not null,
  MAND_CREATED_ON timestamp not null,
  MAND_CREATED_BY varchar2(255 char) not null,
  MAND_UPDATED_ON timestamp,
  MAND_UPDATED_BY varchar2(255 char),
  MAND_ROW_VERSION number not null,
  constraint MAND_PK primary key (MAND_ID)
)~');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_ID', 'number', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_CODE', 'varchar2(10 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_NAME', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_KURZNAME', 'varchar2(30 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_LOGO_DATEI', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ADMIN_MANDANTEN', 'MAND_PK', 'P', 'MAND_ID');
    DDL_UTIL.constraint_('ADMIN_MANDANTEN', 'MAND_CODE_UK', 'U', q'~MAND_CODE~');
    DDL_UTIL.constraint_('ADMIN_MANDANTEN', 'MAND_IST_AKTIV_CK', 'C', q'~MAND_IST_AKTIV in ('Y', 'N')~');
    DDL_UTIL.trigger_pruefen('MAND_BIU', 'ADMIN_MANDANTEN');
end;
/

create or replace trigger MAND_BIU
  before insert or update on ADMIN_MANDANTEN
  for each row
begin
  if inserting then
    :new.MAND_ID := coalesce(:new.MAND_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MAND_CREATED_ON  := systimestamp;
    :new.MAND_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MAND_UPDATED_ON  := null;
    :new.MAND_UPDATED_BY  := null;
    :new.MAND_ROW_VERSION := 1;
  elsif updating then
    :new.MAND_ID          := :old.MAND_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MAND_CREATED_ON  := :old.MAND_CREATED_ON;
    :new.MAND_CREATED_BY  := :old.MAND_CREATED_BY;
    :new.MAND_UPDATED_ON  := systimestamp;
    :new.MAND_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MAND_ROW_VERSION := nvl(:old.MAND_ROW_VERSION, 0) + 1;
  end if;
  :new.MAND_CODE := upper(:new.MAND_CODE);
end MAND_BIU;
/

-- ALLG_MITARBEITER: Login-Benutzer und Standard-Mandant
begin
    DDL_UTIL.spalte('ALLG_MITARBEITER', 'MITA_MAND_ID', 'number', 'Y');
    DDL_UTIL.spalte('ALLG_MITARBEITER', 'MITA_BENUTZERNAME', 'varchar2(255 char)', 'Y');
    DDL_UTIL.constraint_('ALLG_MITARBEITER', 'MITA_MAND_FK', 'R', 'MITA_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.index_('ALLG_MITARBEITER', 'MITA_MAND_I', 'MITA_MAND_ID');
    DDL_UTIL.constraint_('ALLG_MITARBEITER', 'MITA_BENUTZERNAME_UK', 'U', 'MITA_BENUTZERNAME');
    DDL_UTIL.trigger_pruefen('MITA_BIU', 'ALLG_MITARBEITER');
end;
/

-- MITA_BIU aus 04_trigger.sql, ergaenzt um die Normalisierung des Benutzernamens (APEX: APP_USER in Grossbuchstaben)
create or replace trigger MITA_BIU
  before insert or update on ALLG_MITARBEITER
  for each row
begin
  if inserting then
    :new.MITA_ID := coalesce(:new.MITA_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MITA_CREATED_ON  := systimestamp;
    :new.MITA_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MITA_UPDATED_ON  := null;
    :new.MITA_UPDATED_BY  := null;
    :new.MITA_ROW_VERSION := 1;
  elsif updating then
    :new.MITA_ID          := :old.MITA_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MITA_CREATED_ON  := :old.MITA_CREATED_ON;
    :new.MITA_CREATED_BY  := :old.MITA_CREATED_BY;
    :new.MITA_UPDATED_ON  := systimestamp;
    :new.MITA_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MITA_ROW_VERSION := nvl(:old.MITA_ROW_VERSION, 0) + 1;
  end if;
  :new.MITA_BENUTZERNAME := upper(trim(:new.MITA_BENUTZERNAME));
end MITA_BIU;
/

comment on table ADMIN_MANDANTEN is 'Mandanten (Firmen), fuer die im ERP gearbeitet wird; Kundendaten sind mandantenuebergreifend [Alias MAND]';
comment on column ADMIN_MANDANTEN.MAND_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ADMIN_MANDANTEN.MAND_CODE is 'Technischer Code, bestimmt Farben im Banner (thg.css: data-mandant), z.B. EDV, TG';
comment on column ADMIN_MANDANTEN.MAND_NAME is 'Firmenname, z.B. THG-EDV GmbH';
comment on column ADMIN_MANDANTEN.MAND_KURZNAME is 'Kurzname fuer Banner und Auswahl';
comment on column ADMIN_MANDANTEN.MAND_LOGO_DATEI is 'Logo als APEX-Workspace-Datei (#WORKSPACE_FILES#<Datei>), z.B. thg-logo-edv.png';
comment on column ADMIN_MANDANTEN.MAND_SORTIERUNG is 'Reihenfolge der Anzeige; der erste aktive Mandant ist Standard, wenn der Mitarbeiter keinen hat';
comment on column ADMIN_MANDANTEN.MAND_IST_AKTIV is 'Y = auswaehlbar';
comment on column ADMIN_MANDANTEN.MAND_CREATED_ON is 'Audit: angelegt am';
comment on column ADMIN_MANDANTEN.MAND_CREATED_BY is 'Audit: angelegt von';
comment on column ADMIN_MANDANTEN.MAND_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ADMIN_MANDANTEN.MAND_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ADMIN_MANDANTEN.MAND_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';
comment on column ALLG_MITARBEITER.MITA_MAND_ID is 'Standard-Mandant, wird beim Login gesetzt (FK ADMIN_MANDANTEN)';
comment on column ALLG_MITARBEITER.MITA_BENUTZERNAME is 'APEX-Benutzername (Login), Grossbuchstaben';

-- Grunddaten: nur fehlende Zeilen einfuegen
insert into ADMIN_MANDANTEN (MAND_CODE, MAND_NAME, MAND_KURZNAME, MAND_LOGO_DATEI, MAND_SORTIERUNG)
  select 'EDV', 'THG-EDV GmbH', 'THG-EDV', 'thg-logo-edv.png', 10
    from dual where not exists (select 1 from ADMIN_MANDANTEN where MAND_CODE = 'EDV');
insert into ADMIN_MANDANTEN (MAND_CODE, MAND_NAME, MAND_KURZNAME, MAND_LOGO_DATEI, MAND_SORTIERUNG)
  select 'TG', 'Thomas Geßlbauer GmbH', 'Thomas Geßlbauer', 'thg-logo-tg.png', 20
    from dual where not exists (select 1 from ADMIN_MANDANTEN where MAND_CODE = 'TG');
commit;

prompt ADMIN_MANDANTEN und ALLG_MITARBEITER (Mandant) installiert bzw. abgeglichen.
