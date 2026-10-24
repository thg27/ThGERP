-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 35 – Dokumente der Rechnung: jeder Rechnungsdruck wird als PDF abgelegt (Registerkarte "Dokumente" auf Seite 11).
--      FAKT_RECHNUNG_DOKUMENTE (RDOK): je Druck Version 1, 2, 3 …, Status beim Druck, Datei.
--      Package FAKT_RECHNUNG_DOKUMENT: ablegen (vom PDF-Druck Seite 12) – neue Version nur beim ersten Druck und wenn die
--      Rechnung seit dem letzten abgelegten Druck zur Bearbeitung geoeffnet oder storniert wurde; aeltere Drucke bleiben
--      erhalten. Vorschauen (Entwurf) werden nicht abgelegt.
-- Voraussetzung: 20, 21, 24, 33
-- Erzeugt: 2026-10-24
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.tabelle('FAKT_RECHNUNG_DOKUMENTE', q'~create table FAKT_RECHNUNG_DOKUMENTE (
  RDOK_ID number not null,
  RDOK_RECH_ID number not null,
  RDOK_VERSION number not null,
  RDOK_RECH_STATUS varchar2(15 char) not null,
  RDOK_BEZEICHNUNG varchar2(200 char) not null,
  RDOK_DATEINAME varchar2(400 char) not null,
  RDOK_MIME_TYPE varchar2(255 char),
  RDOK_GROESSE number,
  RDOK_DATEI blob not null,
  RDOK_CREATED_ON timestamp not null,
  RDOK_CREATED_BY varchar2(255 char) not null,
  RDOK_UPDATED_ON timestamp,
  RDOK_UPDATED_BY varchar2(255 char),
  RDOK_ROW_VERSION number not null,
  constraint RDOK_PK primary key (RDOK_ID)
)~');
    DDL_UTIL.constraint_('FAKT_RECHNUNG_DOKUMENTE', 'RDOK_PK', 'P', 'RDOK_ID');
    DDL_UTIL.constraint_('FAKT_RECHNUNG_DOKUMENTE', 'RDOK_UK', 'U', 'RDOK_RECH_ID, RDOK_VERSION');
    DDL_UTIL.constraint_('FAKT_RECHNUNG_DOKUMENTE', 'RDOK_RECH_FK', 'R', 'RDOK_RECH_ID references FAKT_RECHNUNGEN (RECH_ID) on delete cascade');
    DDL_UTIL.trigger_pruefen('RDOK_BIU', 'FAKT_RECHNUNG_DOKUMENTE');
end;
/

create or replace trigger RDOK_BIU
  before insert or update on FAKT_RECHNUNG_DOKUMENTE
  for each row
begin
  if inserting then
    :new.RDOK_ID := coalesce(:new.RDOK_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.RDOK_CREATED_ON  := systimestamp;
    :new.RDOK_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RDOK_UPDATED_ON  := null;
    :new.RDOK_UPDATED_BY  := null;
    :new.RDOK_ROW_VERSION := 1;
  elsif updating then
    :new.RDOK_ID          := :old.RDOK_ID;  -- Primaerschluessel ist unveraenderlich
    :new.RDOK_CREATED_ON  := :old.RDOK_CREATED_ON;
    :new.RDOK_CREATED_BY  := :old.RDOK_CREATED_BY;
    :new.RDOK_UPDATED_ON  := systimestamp;
    :new.RDOK_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RDOK_ROW_VERSION := nvl(:old.RDOK_ROW_VERSION, 0) + 1;
  end if;
  -- Groesse immer aus der Datei
  :new.RDOK_GROESSE := dbms_lob.getlength(:new.RDOK_DATEI);
end RDOK_BIU;
/

comment on table FAKT_RECHNUNG_DOKUMENTE is 'Abgelegte Rechnungsdrucke (PDF) je Rechnung, jede Version bleibt erhalten [Alias RDOK]';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_RECH_ID is 'FK: Rechnung';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_VERSION is 'Version je Rechnung (1, 2, 3 …)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_RECH_STATUS is 'Status der Rechnung beim Druck';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_BEZEICHNUNG is 'Bezeichnung (Rechnung <Nummer>, ab Version 2 mit Version)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_DATEINAME is 'Dateiname';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_MIME_TYPE is 'MIME-Typ der Datei';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_GROESSE is 'Groesse in Bytes (Trigger)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_DATEI is 'Datei (PDF)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_CREATED_ON is 'Audit: angelegt am (gedruckt am)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_CREATED_BY is 'Audit: angelegt von (gedruckt von)';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_RECHNUNG_DOKUMENTE.RDOK_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

create or replace package FAKT_RECHNUNG_DOKUMENT as
    -- Rechnungsdruck ablegen (Seite 12, nach dem Erzeugen des PDF): nur abgeschlossene Rechnungen; neue Version beim
    -- ersten Druck und wenn die Rechnung seit dem letzten abgelegten Druck zur Bearbeitung geoeffnet oder storniert
    -- wurde (Historie) – ein erneuter Druck ohne Aenderung legt nichts ab. Aeltere Versionen bleiben erhalten.
    procedure ablegen(p_rech_id in number, p_pdf in blob);
    -- Dateiname fuer die Anzeige: abgelegter Druck (p_rdok_id) bzw. aktueller Druck der Rechnung
    function dateiname(p_rech_id in number, p_rdok_id in number default null) return varchar2;
end FAKT_RECHNUNG_DOKUMENT;
/

create or replace package body FAKT_RECHNUNG_DOKUMENT as

    procedure ablegen(p_rech_id in number, p_pdf in blob) is
        l_rech    FAKT_RECHNUNGEN%rowtype;
        l_letzter timestamp;
        l_version number;
        l_neu     number;
    begin
        select * into l_rech from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        if l_rech.RECH_STATUS = 'ENTWURF' or p_pdf is null then
            return;
        end if;
        select max(RDOK_CREATED_ON), nvl(max(RDOK_VERSION), 0) into l_letzter, l_version
          from FAKT_RECHNUNG_DOKUMENTE where RDOK_RECH_ID = p_rech_id;
        if l_letzter is not null then
            select count(*) into l_neu
              from FAKT_RECHNUNG_HISTORIE
             where RHIS_RECH_ID = p_rech_id
               and RHIS_AKTION in ('Zur Bearbeitung geöffnet', 'Storniert')
               and RHIS_ZEITPUNKT > l_letzter;
            if l_neu = 0 then
                return;
            end if;
        end if;
        l_version := l_version + 1;
        insert into FAKT_RECHNUNG_DOKUMENTE (RDOK_RECH_ID, RDOK_VERSION, RDOK_RECH_STATUS, RDOK_BEZEICHNUNG, RDOK_DATEINAME,
                                            RDOK_MIME_TYPE, RDOK_DATEI)
        values (p_rech_id, l_version, l_rech.RECH_STATUS,
                'Rechnung ' || l_rech.RECH_NUMMER || case when l_version > 1 then ' (Version ' || l_version || ')' end,
                'Rechnung ' || l_rech.RECH_NUMMER || case when l_version > 1 then ' V' || l_version end || '.pdf',
                'application/pdf', p_pdf);
        FAKT_HISTORIE.protokoll(p_rech_id, 'Dokument abgelegt',
                                'Rechnung ' || l_rech.RECH_NUMMER || ', Version ' || l_version);
    end ablegen;

    function dateiname(p_rech_id in number, p_rdok_id in number default null) return varchar2 is
        l_name FAKT_RECHNUNG_DOKUMENTE.RDOK_DATEINAME%type;
    begin
        if p_rdok_id is null then
            return FAKT_RECHNUNG_PDF.dateiname(p_rech_id);
        end if;
        select RDOK_DATEINAME into l_name
          from FAKT_RECHNUNG_DOKUMENTE where RDOK_ID = p_rdok_id and RDOK_RECH_ID = p_rech_id;
        return l_name;
    end dateiname;

end FAKT_RECHNUNG_DOKUMENT;
/

show errors package body FAKT_RECHNUNG_DOKUMENT

prompt Rechnungsdokumente installiert.
