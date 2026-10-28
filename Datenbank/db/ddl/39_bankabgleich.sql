-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 39 – Bankabgleich: Kontoauszug als CAMT-Datei (camt.052/.053/.054, z.B. ELBA-Export der Raiffeisenbank) hochladen,
--      Umsaetze speichern und Eingaenge automatisch den offenen Rechnungen des Mandanten zuordnen.
--      FAKT_BANKDATEIEN (BKDT): hochgeladene Datei (Original, Format, Nachrichten-ID, Zaehler)
--      FAKT_BANKUMSAETZE (BKUM): je Buchung Datum, Betrag, Richtung, Auftraggeber, Referenz, Verwendungszweck, Status
--        OFFEN (Eingang ohne Zuordnung), ZUGEORDNET (Zahlung zur Rechnung angelegt bzw. vorhandene verknuepft),
--        BEREITS_BEZAHLT (Rechnung erkannt, war schon bezahlt), AUSGANG (Abbuchung), IGNORIERT
--        Jede Buchung nur einmal je Mandant (BKUM_SCHLUESSEL: Bankreferenz bzw. Pruefsumme) – ueberlappende Dateien schaden nicht.
--      FAKT_GUTSCHRIFTEN (GUTS): erhaltene Gutschriften (Gutschriftverfahren, z.B. Hays) je Mandant: Aussteller (optional
--        Kunde), Nummer, Datum, faellig am, Betrag, Verwendungszweck wie auf dem Kontoauszug, PDF/Text, Status OFFEN/BEZAHLT
--        (Auslesen des PDF: Skript 40); Bankbuchung -> Gutschrift: BKUM_GUTS_ID
--      Package FAKT_BANK: einlesen (Datei pruefen, Konto muss zum Mandanten gehoeren), abgleichen
--        Zuordnung: 1. RF-Zahlungsreferenz, 2. Rechnungsnummer im Text, 3. offener Betrag + Auftraggeber passt zum Kunden.
--        Offene Rechnung: Zahlung anlegen (Trigger setzen Status/Historie) bzw. gleich hohe Zahlung +-7 Tage verknuepfen.
-- Voraussetzung: 17/18 (Mandanten, Bankverbindungen), 20/21, 36/38 (Zahlungsreferenz); FAKT_BANK braucht FAKT_DEBITOR (45)
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.tabelle('FAKT_BANKDATEIEN', q'~create table FAKT_BANKDATEIEN (
  BKDT_ID number not null,
  BKDT_MAND_ID number not null,
  BKDT_DATEINAME varchar2(400 char) not null,
  BKDT_FORMAT varchar2(30 char),
  BKDT_NACHRICHT_ID varchar2(100 char),
  BKDT_ERSTELLT_AM date,
  BKDT_IBAN varchar2(34 char),
  BKDT_ANZ_UMSAETZE number,
  BKDT_ANZ_NEU number,
  BKDT_ANZ_ZUGEORDNET number,
  BKDT_DATEI blob not null,
  BKDT_CREATED_ON timestamp not null,
  BKDT_CREATED_BY varchar2(255 char) not null,
  BKDT_UPDATED_ON timestamp,
  BKDT_UPDATED_BY varchar2(255 char),
  BKDT_ROW_VERSION number not null,
  constraint BKDT_PK primary key (BKDT_ID)
)~');
    DDL_UTIL.constraint_('FAKT_BANKDATEIEN', 'BKDT_MAND_FK', 'R', 'BKDT_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.index_('FAKT_BANKDATEIEN', 'BKDT_MAND_I', 'BKDT_MAND_ID');
    DDL_UTIL.trigger_pruefen('BKDT_BIU', 'FAKT_BANKDATEIEN');

    DDL_UTIL.tabelle('FAKT_BANKUMSAETZE', q'~create table FAKT_BANKUMSAETZE (
  BKUM_ID number not null,
  BKUM_MAND_ID number not null,
  BKUM_BKDT_ID number,
  BKUM_IBAN varchar2(34 char) not null,
  BKUM_BUCHUNGSDATUM date not null,
  BKUM_VALUTA date,
  BKUM_BETRAG number(14,2) not null,
  BKUM_WAEHRUNG varchar2(3 char) default 'EUR' not null,
  BKUM_RICHTUNG varchar2(4 char) not null,
  BKUM_GEGEN_NAME varchar2(200 char),
  BKUM_GEGEN_IBAN varchar2(34 char),
  BKUM_REFERENZ varchar2(140 char),
  BKUM_END_TO_END_ID varchar2(140 char),
  BKUM_VERWENDUNGSZWECK varchar2(1000 char),
  BKUM_BANK_REFERENZ varchar2(100 char),
  BKUM_SCHLUESSEL varchar2(130 char) not null,
  BKUM_STATUS varchar2(20 char) default 'OFFEN' not null,
  BKUM_RECH_ID number,
  BKUM_ZAHL_ID number,
  BKUM_ZUORDNUNG varchar2(200 char),
  BKUM_CREATED_ON timestamp not null,
  BKUM_CREATED_BY varchar2(255 char) not null,
  BKUM_UPDATED_ON timestamp,
  BKUM_UPDATED_BY varchar2(255 char),
  BKUM_ROW_VERSION number not null,
  constraint BKUM_PK primary key (BKUM_ID)
)~');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_UK', 'U', 'BKUM_MAND_ID, BKUM_SCHLUESSEL');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_RICHTUNG_CK', 'C', q'~BKUM_RICHTUNG in ('CRDT', 'DBIT')~');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_STATUS_CK', 'C',
                         q'~BKUM_STATUS in ('OFFEN', 'ZUGEORDNET', 'BEREITS_BEZAHLT', 'AUSGANG', 'IGNORIERT', 'DEBITOR')~');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_MAND_FK', 'R', 'BKUM_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_BKDT_FK', 'R', 'BKUM_BKDT_ID references FAKT_BANKDATEIEN (BKDT_ID) on delete set null');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_RECH_FK', 'R', 'BKUM_RECH_ID references FAKT_RECHNUNGEN (RECH_ID) on delete set null');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_ZAHL_FK', 'R', 'BKUM_ZAHL_ID references FAKT_ZAHLUNGEN (ZAHL_ID) on delete set null');
    DDL_UTIL.index_('FAKT_BANKUMSAETZE', 'BKUM_BKDT_I', 'BKUM_BKDT_ID');
    DDL_UTIL.index_('FAKT_BANKUMSAETZE', 'BKUM_RECH_I', 'BKUM_RECH_ID');
    DDL_UTIL.index_('FAKT_BANKUMSAETZE', 'BKUM_ZAHL_I', 'BKUM_ZAHL_ID');
    DDL_UTIL.index_('FAKT_BANKUMSAETZE', 'BKUM_STATUS_I', 'BKUM_MAND_ID, BKUM_STATUS');
    DDL_UTIL.trigger_pruefen('BKUM_BIU', 'FAKT_BANKUMSAETZE');
end;
/

create or replace trigger BKDT_BIU
  before insert or update on FAKT_BANKDATEIEN
  for each row
begin
  if inserting then
    :new.BKDT_ID := coalesce(:new.BKDT_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.BKDT_CREATED_ON  := systimestamp;
    :new.BKDT_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BKDT_UPDATED_ON  := null;
    :new.BKDT_UPDATED_BY  := null;
    :new.BKDT_ROW_VERSION := 1;
  elsif updating then
    :new.BKDT_ID          := :old.BKDT_ID;  -- Primaerschluessel ist unveraenderlich
    :new.BKDT_CREATED_ON  := :old.BKDT_CREATED_ON;
    :new.BKDT_CREATED_BY  := :old.BKDT_CREATED_BY;
    :new.BKDT_UPDATED_ON  := systimestamp;
    :new.BKDT_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BKDT_ROW_VERSION := nvl(:old.BKDT_ROW_VERSION, 0) + 1;
  end if;
end BKDT_BIU;
/

create or replace trigger BKUM_BIU
  before insert or update on FAKT_BANKUMSAETZE
  for each row
begin
  if inserting then
    :new.BKUM_ID := coalesce(:new.BKUM_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.BKUM_CREATED_ON  := systimestamp;
    :new.BKUM_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BKUM_UPDATED_ON  := null;
    :new.BKUM_UPDATED_BY  := null;
    :new.BKUM_ROW_VERSION := 1;
  elsif updating then
    :new.BKUM_ID          := :old.BKUM_ID;  -- Primaerschluessel ist unveraenderlich
    :new.BKUM_CREATED_ON  := :old.BKUM_CREATED_ON;
    :new.BKUM_CREATED_BY  := :old.BKUM_CREATED_BY;
    :new.BKUM_UPDATED_ON  := systimestamp;
    :new.BKUM_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BKUM_ROW_VERSION := nvl(:old.BKUM_ROW_VERSION, 0) + 1;
  end if;
end BKUM_BIU;
/

comment on table FAKT_BANKDATEIEN is 'Hochgeladene Bankdateien (CAMT-Kontoauszuege) je Mandant [Alias BKDT]';
comment on column FAKT_BANKDATEIEN.BKDT_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_BANKDATEIEN.BKDT_MAND_ID is 'FK: Mandant (Kontoinhaber)';
comment on column FAKT_BANKDATEIEN.BKDT_DATEINAME is 'Dateiname beim Hochladen';
comment on column FAKT_BANKDATEIEN.BKDT_FORMAT is 'CAMT-Format, z.B. camt.052.001.02';
comment on column FAKT_BANKDATEIEN.BKDT_NACHRICHT_ID is 'Nachrichten-ID der Bank (GrpHdr/MsgId) – je Mandant nur einmal';
comment on column FAKT_BANKDATEIEN.BKDT_ERSTELLT_AM is 'Erstellt von der Bank am (GrpHdr/CreDtTm)';
comment on column FAKT_BANKDATEIEN.BKDT_IBAN is 'Konto (IBAN) der Datei';
comment on column FAKT_BANKDATEIEN.BKDT_ANZ_UMSAETZE is 'Anzahl Buchungen in der Datei';
comment on column FAKT_BANKDATEIEN.BKDT_ANZ_NEU is 'Anzahl neu gespeicherter Buchungen (ohne bereits vorhandene)';
comment on column FAKT_BANKDATEIEN.BKDT_ANZ_ZUGEORDNET is 'Anzahl beim Hochladen zugeordneter Eingaenge';
comment on column FAKT_BANKDATEIEN.BKDT_DATEI is 'Datei (Original)';
comment on column FAKT_BANKDATEIEN.BKDT_CREATED_ON is 'Audit: angelegt am (hochgeladen am)';
comment on column FAKT_BANKDATEIEN.BKDT_CREATED_BY is 'Audit: angelegt von (hochgeladen von)';
comment on column FAKT_BANKDATEIEN.BKDT_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_BANKDATEIEN.BKDT_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_BANKDATEIEN.BKDT_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table FAKT_BANKUMSAETZE is 'Buchungen der Bankkonten (aus CAMT-Dateien) mit Zuordnung zu Rechnungen [Alias BKUM]';
comment on column FAKT_BANKUMSAETZE.BKUM_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_BANKUMSAETZE.BKUM_MAND_ID is 'FK: Mandant (Kontoinhaber)';
comment on column FAKT_BANKUMSAETZE.BKUM_BKDT_ID is 'FK: Bankdatei, aus der die Buchung zuerst eingelesen wurde';
comment on column FAKT_BANKUMSAETZE.BKUM_IBAN is 'Eigenes Konto (IBAN)';
comment on column FAKT_BANKUMSAETZE.BKUM_BUCHUNGSDATUM is 'Buchungsdatum';
comment on column FAKT_BANKUMSAETZE.BKUM_VALUTA is 'Valutadatum';
comment on column FAKT_BANKUMSAETZE.BKUM_BETRAG is 'Betrag (immer positiv, Richtung in BKUM_RICHTUNG)';
comment on column FAKT_BANKUMSAETZE.BKUM_WAEHRUNG is 'Waehrung';
comment on column FAKT_BANKUMSAETZE.BKUM_RICHTUNG is 'CRDT = Eingang, DBIT = Ausgang';
comment on column FAKT_BANKUMSAETZE.BKUM_GEGEN_NAME is 'Auftraggeber (Zahler) bzw. Empfaenger';
comment on column FAKT_BANKUMSAETZE.BKUM_GEGEN_IBAN is 'IBAN des Auftraggebers';
comment on column FAKT_BANKUMSAETZE.BKUM_REFERENZ is 'Strukturierte Zahlungsreferenz (z.B. RF…)';
comment on column FAKT_BANKUMSAETZE.BKUM_END_TO_END_ID is 'End-to-End-Referenz';
comment on column FAKT_BANKUMSAETZE.BKUM_VERWENDUNGSZWECK is 'Verwendungszweck (unstrukturiert)';
comment on column FAKT_BANKUMSAETZE.BKUM_BANK_REFERENZ is 'Referenz der Bank (AcctSvcrRef)';
comment on column FAKT_BANKUMSAETZE.BKUM_SCHLUESSEL is 'Eindeutiger Schluessel je Mandant (Bankreferenz bzw. Pruefsumme) gegen doppeltes Einlesen';
comment on column FAKT_BANKUMSAETZE.BKUM_STATUS is 'OFFEN, ZUGEORDNET, BEREITS_BEZAHLT, AUSGANG, IGNORIERT';
comment on column FAKT_BANKUMSAETZE.BKUM_RECH_ID is 'FK: zugeordnete bzw. erkannte Rechnung';
comment on column FAKT_BANKUMSAETZE.BKUM_ZAHL_ID is 'FK: angelegte bzw. verknuepfte Zahlung';
comment on column FAKT_BANKUMSAETZE.BKUM_ZUORDNUNG is 'Wie zugeordnet (Zahlungsreferenz, Rechnungsnummer, Betrag und Kunde) bzw. Hinweis';
comment on column FAKT_BANKUMSAETZE.BKUM_CREATED_ON is 'Audit: angelegt am (eingelesen am)';
comment on column FAKT_BANKUMSAETZE.BKUM_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_BANKUMSAETZE.BKUM_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_BANKUMSAETZE.BKUM_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_BANKUMSAETZE.BKUM_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

-- Erhaltene Gutschriften (Gutschriftverfahren, z.B. Hays) – vor FAKT_BANK, das sie im Abgleich verwendet
begin
    DDL_UTIL.tabelle('FAKT_GUTSCHRIFTEN', q'~create table FAKT_GUTSCHRIFTEN (
  GUTS_ID number not null,
  GUTS_MAND_ID number not null,
  GUTS_KUND_ID number,
  GUTS_AUSSTELLER varchar2(200 char),
  GUTS_INTERN_NUMMER varchar2(30 char),
  GUTS_NUMMER varchar2(50 char),
  GUTS_DATUM date,
  GUTS_AUSSTELLER_DATUM date,
  GUTS_FAELLIG_AM date,
  GUTS_NETTO number(14,2),
  GUTS_BETRAG number(14,2),
  GUTS_SKONTO_PROZENT number(5,2),
  GUTS_ZAHLBETRAG number(14,2),
  GUTS_VERWENDUNGSZWECK varchar2(140 char),
  GUTS_BEMERKUNG varchar2(1000 char),
  GUTS_STATUS varchar2(20 char) default 'ENTWURF' not null,
  GUTS_BEZAHLT_AM date,
  GUTS_DATEINAME varchar2(400 char),
  GUTS_MIME_TYPE varchar2(255 char),
  GUTS_DATEI blob,
  GUTS_TEXT clob,
  GUTS_CREATED_ON timestamp not null,
  GUTS_CREATED_BY varchar2(255 char) not null,
  GUTS_UPDATED_ON timestamp,
  GUTS_UPDATED_BY varchar2(255 char),
  GUTS_ROW_VERSION number not null,
  constraint GUTS_PK primary key (GUTS_ID)
)~');
    -- Status erweitert (2026-10-25: ENTWURF, GESENDET): alte Pruefung ersetzen
    for c in (select constraint_name from user_constraints
               where constraint_name = 'GUTS_STATUS_CK' and search_condition_vc not like '%ENTWURF%') loop
        execute immediate 'alter table FAKT_GUTSCHRIFTEN drop constraint GUTS_STATUS_CK';
        execute immediate q'~alter table FAKT_GUTSCHRIFTEN modify (GUTS_STATUS default 'ENTWURF')~';
    end loop;
    DDL_UTIL.constraint_('FAKT_GUTSCHRIFTEN', 'GUTS_STATUS_CK', 'C', q'~GUTS_STATUS in ('ENTWURF', 'GESENDET', 'OFFEN', 'BEZAHLT')~');
    DDL_UTIL.constraint_('FAKT_GUTSCHRIFTEN', 'GUTS_MAND_FK', 'R', 'GUTS_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('FAKT_GUTSCHRIFTEN', 'GUTS_KUND_FK', 'R', 'GUTS_KUND_ID references KUND_KUNDEN (KUND_ID)');
    DDL_UTIL.index_('FAKT_GUTSCHRIFTEN', 'GUTS_MAND_I', 'GUTS_MAND_ID, GUTS_STATUS');
    DDL_UTIL.index_('FAKT_GUTSCHRIFTEN', 'GUTS_KUND_I', 'GUTS_KUND_ID');
    DDL_UTIL.spalte('FAKT_GUTSCHRIFTEN', 'GUTS_SKONTO_PROZENT', 'number(5,2)', 'Y');
    DDL_UTIL.spalte('FAKT_GUTSCHRIFTEN', 'GUTS_INTERN_NUMMER', 'varchar2(30 char)', 'Y');
    DDL_UTIL.spalte('FAKT_GUTSCHRIFTEN', 'GUTS_AUSSTELLER_DATUM', 'date', 'Y');
    DDL_UTIL.spalte('FAKT_GUTSCHRIFTEN', 'GUTS_NETTO', 'number(14,2)', 'Y');
    DDL_UTIL.spalte('FAKT_GUTSCHRIFTEN', 'GUTS_ZAHLBETRAG', 'number(14,2)', 'Y');
    DDL_UTIL.trigger_pruefen('GUTS_BIU', 'FAKT_GUTSCHRIFTEN');
    -- Bankbuchung -> Gutschrift
    DDL_UTIL.spalte('FAKT_BANKUMSAETZE', 'BKUM_GUTS_ID', 'number', 'Y');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_GUTS_FK', 'R', 'BKUM_GUTS_ID references FAKT_GUTSCHRIFTEN (GUTS_ID) on delete set null');
    DDL_UTIL.index_('FAKT_BANKUMSAETZE', 'BKUM_GUTS_I', 'BKUM_GUTS_ID');
    -- Dokumente der Gutschrift (Stundenzettel u.a.; das PDF der Gutschrift des Ausstellers steht in GUTS_DATEI)
    DDL_UTIL.tabelle('FAKT_GUTSCHRIFT_DOKUMENTE', q'~create table FAKT_GUTSCHRIFT_DOKUMENTE (
  GDOK_ID number not null,
  GDOK_GUTS_ID number not null,
  GDOK_ART varchar2(20 char) default 'STUNDENZETTEL' not null,
  GDOK_DATEINAME varchar2(400 char) not null,
  GDOK_MIME_TYPE varchar2(255 char),
  GDOK_GROESSE number,
  GDOK_DATEI blob not null,
  GDOK_CREATED_ON timestamp not null,
  GDOK_CREATED_BY varchar2(255 char) not null,
  GDOK_UPDATED_ON timestamp,
  GDOK_UPDATED_BY varchar2(255 char),
  GDOK_ROW_VERSION number not null,
  constraint GDOK_PK primary key (GDOK_ID)
)~');
    DDL_UTIL.constraint_('FAKT_GUTSCHRIFT_DOKUMENTE', 'GDOK_ART_CK', 'C', q'~GDOK_ART in ('STUNDENZETTEL', 'SONSTIGES')~');
    DDL_UTIL.constraint_('FAKT_GUTSCHRIFT_DOKUMENTE', 'GDOK_GUTS_FK', 'R', 'GDOK_GUTS_ID references FAKT_GUTSCHRIFTEN (GUTS_ID) on delete cascade');
    DDL_UTIL.index_('FAKT_GUTSCHRIFT_DOKUMENTE', 'GDOK_GUTS_I', 'GDOK_GUTS_ID');
    DDL_UTIL.trigger_pruefen('GDOK_BIU', 'FAKT_GUTSCHRIFT_DOKUMENTE');
end;
/

create or replace trigger GDOK_BIU
  before insert or update on FAKT_GUTSCHRIFT_DOKUMENTE
  for each row
begin
  if inserting then
    :new.GDOK_ID := coalesce(:new.GDOK_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.GDOK_CREATED_ON  := systimestamp;
    :new.GDOK_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.GDOK_UPDATED_ON  := null;
    :new.GDOK_UPDATED_BY  := null;
    :new.GDOK_ROW_VERSION := 1;
  elsif updating then
    :new.GDOK_ID          := :old.GDOK_ID;  -- Primaerschluessel ist unveraenderlich
    :new.GDOK_CREATED_ON  := :old.GDOK_CREATED_ON;
    :new.GDOK_CREATED_BY  := :old.GDOK_CREATED_BY;
    :new.GDOK_UPDATED_ON  := systimestamp;
    :new.GDOK_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.GDOK_ROW_VERSION := nvl(:old.GDOK_ROW_VERSION, 0) + 1;
  end if;
  :new.GDOK_GROESSE := dbms_lob.getlength(:new.GDOK_DATEI);
end GDOK_BIU;
/

comment on table FAKT_GUTSCHRIFT_DOKUMENTE is 'Dokumente der Gutschrift (Stundenzettel u.a.) [Alias GDOK]';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_GUTS_ID is 'FK: Gutschrift';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_ART is 'STUNDENZETTEL, SONSTIGES';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_DATEINAME is 'Dateiname';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_MIME_TYPE is 'MIME-Typ';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_GROESSE is 'Groesse in Bytes (Trigger)';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_DATEI is 'Datei';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_CREATED_ON is 'Audit: angelegt am (hochgeladen am)';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_GUTSCHRIFT_DOKUMENTE.GDOK_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

create or replace trigger GUTS_BIU
  before insert or update on FAKT_GUTSCHRIFTEN
  for each row
begin
  if inserting then
    :new.GUTS_ID := coalesce(:new.GUTS_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.GUTS_CREATED_ON  := systimestamp;
    :new.GUTS_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.GUTS_UPDATED_ON  := null;
    :new.GUTS_UPDATED_BY  := null;
    :new.GUTS_ROW_VERSION := 1;
  elsif updating then
    :new.GUTS_ID          := :old.GUTS_ID;  -- Primaerschluessel ist unveraenderlich
    :new.GUTS_CREATED_ON  := :old.GUTS_CREATED_ON;
    :new.GUTS_CREATED_BY  := :old.GUTS_CREATED_BY;
    :new.GUTS_UPDATED_ON  := systimestamp;
    :new.GUTS_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.GUTS_ROW_VERSION := nvl(:old.GUTS_ROW_VERSION, 0) + 1;
  end if;
  -- Status: Bezahlt (Zahlungsdatum aus Bankabgleich oder von Hand) > Offen (Gutschrift des Ausstellers liegt vor)
  -- > Gesendet (Stundenzettel an den Aussteller) > Entwurf
  :new.GUTS_STATUS := case when :new.GUTS_BEZAHLT_AM is not null then 'BEZAHLT'
                           when :new.GUTS_DATEI is not null then 'OFFEN'
                           when :new.GUTS_STATUS = 'GESENDET' then 'GESENDET'
                           else 'ENTWURF' end;
  -- Netto ohne Angabe = Betrag (Gutschriftverfahren meist Reverse Charge, 0 % USt)
  :new.GUTS_NETTO := coalesce(:new.GUTS_NETTO, :new.GUTS_BETRAG);
  -- erwartete Zahlung: Betrag abzueglich Skonto (z.B. Hays: 3 % bei Zahlung innerhalb von 7 Tagen)
  :new.GUTS_ZAHLBETRAG := round(:new.GUTS_BETRAG * (1 - nvl(:new.GUTS_SKONTO_PROZENT, 0) / 100), 2);
  -- Aussteller vom Kunden, wenn leer
  if :new.GUTS_AUSSTELLER is null and :new.GUTS_KUND_ID is not null then
    select max(coalesce(KUND_FIRMENNAME, KUND_KURZNAME)) into :new.GUTS_AUSSTELLER from KUND_KUNDEN where KUND_ID = :new.GUTS_KUND_ID;
  end if;
end GUTS_BIU;
/

comment on table FAKT_GUTSCHRIFTEN is 'Erhaltene Gutschriften (Gutschriftverfahren) je Mandant [Alias GUTS]';
comment on column FAKT_GUTSCHRIFTEN.GUTS_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_MAND_ID is 'FK: Mandant (Empfaenger der Gutschrift)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_KUND_ID is 'FK: Kunde (Aussteller), optional';
comment on column FAKT_GUTSCHRIFTEN.GUTS_AUSSTELLER is 'Aussteller der Gutschrift (Name, aus dem PDF bzw. vom Kunden)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_INTERN_NUMMER is 'Interne Gutschriftnummer (Nummernkreis GUTSCHRIFT, z.B. GS 2026 - 1), vergeben beim ersten Stundenzettel bzw. PDF';
comment on column FAKT_GUTSCHRIFTEN.GUTS_NUMMER is 'Nummer beim Aussteller (z.B. Hays-Belegnummer)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_AUSSTELLER_DATUM is 'Datum der Gutschrift beim Aussteller (Belegdatum)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_NETTO is 'Nettobetrag (Umsatz im Dashboard)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_DATUM is 'Internes Gutschriftdatum (mit der internen Nummer vergeben)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_FAELLIG_AM is 'Faellig am (Auszahlung erwartet)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_BETRAG is 'Betrag der Gutschrift (Auszahlungsbetrag brutto)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_SKONTO_PROZENT is 'Skonto in Prozent, das der Aussteller bei der Zahlung abzieht';
comment on column FAKT_GUTSCHRIFTEN.GUTS_ZAHLBETRAG is 'Erwartete Zahlung = Betrag abzueglich Skonto (Trigger)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_VERWENDUNGSZWECK is 'Verwendungszweck wie auf dem Kontoauszug (Bankabgleich)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_BEMERKUNG is 'Bemerkung';
comment on column FAKT_GUTSCHRIFTEN.GUTS_STATUS is 'ENTWURF, GESENDET (Stundenzettel an Aussteller), OFFEN (Gutschrift erhalten), BEZAHLT (Trigger)';
comment on column FAKT_GUTSCHRIFTEN.GUTS_BEZAHLT_AM is 'Zahlungseingang am';
comment on column FAKT_GUTSCHRIFTEN.GUTS_DATEINAME is 'Dateiname des PDF';
comment on column FAKT_GUTSCHRIFTEN.GUTS_MIME_TYPE is 'MIME-Typ des PDF';
comment on column FAKT_GUTSCHRIFTEN.GUTS_DATEI is 'PDF der Gutschrift';
comment on column FAKT_GUTSCHRIFTEN.GUTS_TEXT is 'Aus dem PDF ausgelesener Text';
comment on column FAKT_GUTSCHRIFTEN.GUTS_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_GUTSCHRIFTEN.GUTS_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_GUTSCHRIFTEN.GUTS_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_GUTSCHRIFTEN.GUTS_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_GUTSCHRIFTEN.GUTS_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';
comment on column FAKT_BANKUMSAETZE.BKUM_GUTS_ID is 'FK: zugeordnete Gutschrift';

create or replace package FAKT_BANK as
    -- CAMT-Datei (camt.052/.053/.054) einlesen: Konto muss zum Mandanten gehoeren, Datei (Nachrichten-ID) nur einmal;
    -- neue Buchungen speichern (bereits vorhandene werden uebersprungen), danach abgleichen. Liefert die ID der Bankdatei.
    function einlesen(p_mand_id in number, p_dateiname in varchar2, p_datei in blob) return number;
    -- offene Eingaenge des Mandanten den Rechnungen zuordnen; liefert die Anzahl neu zugeordneter Eingaenge
    function abgleichen(p_mand_id in number) return pls_integer;
    -- Status als Text (Liste der Bankumsaetze)
    function status_text(p_status in varchar2) return varchar2 deterministic;
    -- Meldung des letzten Aufrufs von einlesen (z. B. "bereits hochgeladen – erneut abgeglichen")
    function meldung return varchar2;
    -- Zahlungseingang von Hand einer Rechnung, Gutschrift bzw. einem Debitor zuordnen (p_belegart RECHNUNG/GUTSCHRIFT/DEBITOR, Seite 31):
    -- vorhandene gleich hohe Zahlung verknuepfen, sonst bei offener Rechnung Zahlung anlegen; bereits bezahlte Rechnung
    -- ohne passende Zahlung nur verknuepfen (keine Zahlung). Eine bestehende Zuordnung wird vorher aufgehoben.
    procedure zuordnen(p_bkum_id in number, p_belegart in varchar2, p_beleg_id in number);
    -- Zuordnung aufheben: Buchung wieder offen; vom Bankabgleich angelegte Zahlung loeschen, Debitor-Zahlung entfernen,
    -- per Bank gesetztes "Bezahlt am" der Gutschrift zuruecknehmen
    procedure aufheben(p_bkum_id in number);
end FAKT_BANK;
/

create or replace package body FAKT_BANK as

    g_meldung varchar2(1000);

    function meldung return varchar2 is
    begin
        return g_meldung;
    end meldung;

    function einlesen(p_mand_id in number, p_dateiname in varchar2, p_datei in blob) return number is
        l_xml     xmltype;
        l_format  FAKT_BANKDATEIEN.BKDT_FORMAT%type;
        l_msg_id  FAKT_BANKDATEIEN.BKDT_NACHRICHT_ID%type;
        l_erst    varchar2(40);
        l_iban    FAKT_BANKDATEIEN.BKDT_IBAN%type;
        l_anz     pls_integer;
        l_neu     pls_integer;
        l_bkdt    FAKT_BANKDATEIEN.BKDT_ID%type;
        l_wann    varchar2(40);
        l_zug     pls_integer;
    begin
        begin
            l_xml := xmltype(p_datei, nls_charset_id('AL32UTF8'));
        exception
            when others then
                raise_application_error(-20260, 'Die Datei ist keine gültige XML-Datei.');
        end;
        l_format := regexp_substr(l_xml.getnamespace(), 'camt\.[0-9]{3}\.[0-9]{3}\.[0-9]{2}');
        if l_format is null then
            raise_application_error(-20260, 'Die Datei ist keine CAMT-Datei (camt.052, camt.053 oder camt.054).');
        end if;
        select msg_id, erstellt into l_msg_id, l_erst
          from xmltable('/*:Document/*/*:GrpHdr' passing l_xml
                        columns msg_id varchar2(100) path '*:MsgId', erstellt varchar2(40) path '*:CreDtTm');
        -- Konten der Datei: jedes muss eine Bankverbindung des Mandanten sein
        for k in (select distinct replace(upper(iban), ' ') as iban
                    from xmltable('/*:Document/*/*[*:Acct]' passing l_xml columns iban varchar2(40) path '*:Acct/*:Id/*:IBAN')) loop
            select count(*) into l_anz
              from ADMIN_MANDANT_BANKVERBINDUNGEN
             where MBNK_MAND_ID = p_mand_id and replace(upper(MBNK_IBAN), ' ') = k.iban;
            if l_anz = 0 then
                raise_application_error(-20261, 'Das Konto ' || FAKT_RECHNUNG.referenz_anzeige(k.iban) || ' gehört nicht zum gewählten Mandanten. '
                                                || 'Bitte im Portal den richtigen Mandanten wählen.');
            end if;
            l_iban := k.iban;
        end loop;
        if l_iban is null then
            raise_application_error(-20260, 'Die Datei enthält kein Konto.');
        end if;
        -- dieselbe Datei (Nachrichten-ID) nicht zweimal
        select max(to_char(from_tz(BKDT_CREATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI')) into l_wann
          from FAKT_BANKDATEIEN where BKDT_MAND_ID = p_mand_id and BKDT_NACHRICHT_ID = l_msg_id;
        if l_wann is not null then
            -- schon hochgeladen: keine neuen Buchungen, aber die Zuordnung erneut pruefen (z. B. nachdem Rechnungen,
            -- Gutschriften oder Debitoren erfasst wurden)
            l_zug := abgleichen(p_mand_id);
            g_meldung := p_dateiname || ': bereits am ' || l_wann || ' hochgeladen – keine neuen Buchungen; Zuordnung erneut geprüft, '
                         || l_zug || ' Zahlungseingänge zugeordnet.';
            select max(BKDT_ID) into l_bkdt from FAKT_BANKDATEIEN where BKDT_MAND_ID = p_mand_id and BKDT_NACHRICHT_ID = l_msg_id;
            return l_bkdt;
        end if;

        insert into FAKT_BANKDATEIEN (BKDT_MAND_ID, BKDT_DATEINAME, BKDT_FORMAT, BKDT_NACHRICHT_ID, BKDT_ERSTELLT_AM,
                                      BKDT_IBAN, BKDT_DATEI)
        values (p_mand_id, p_dateiname, l_format, l_msg_id, to_date(substr(l_erst, 1, 10), 'YYYY-MM-DD'), l_iban, p_datei)
        returning BKDT_ID into l_bkdt;

        -- Buchungen: je Bericht/Auszug (Rpt, Stmt, Ntfctn) das Konto, je Ntry der erste Umsatz (TxDtls)
        insert into FAKT_BANKUMSAETZE (BKUM_MAND_ID, BKUM_BKDT_ID, BKUM_IBAN, BKUM_BUCHUNGSDATUM, BKUM_VALUTA, BKUM_BETRAG,
                                       BKUM_WAEHRUNG, BKUM_RICHTUNG, BKUM_GEGEN_NAME, BKUM_GEGEN_IBAN, BKUM_REFERENZ,
                                       BKUM_END_TO_END_ID, BKUM_VERWENDUNGSZWECK, BKUM_BANK_REFERENZ, BKUM_SCHLUESSEL,
                                       BKUM_STATUS)
        select p_mand_id, l_bkdt, x.IBAN, x.BUCHUNG, x.VALUTA, x.BETRAG, x.WAEHRUNG, x.RICHTUNG, x.NAME, x.GEGEN_IBAN,
               x.REFERENZ, x.E2E, x.ZWECK, x.BANKREF, x.SCHLUESSEL,
               case x.RICHTUNG when 'DBIT' then 'AUSGANG' else 'OFFEN' end
          from (select y.*,
                       -- Schluessel: Referenz der Bank; fehlt sie oder ist sie in der Datei mehrfach (z. B. Abschluss mit
                       -- Zinsen und Spesen unter einer Referenz), Pruefsumme der Buchungsdaten (gleiche Buchungen am selben
                       -- Tag werden mitgezaehlt)
                       case when y.BANKREF is not null and upper(y.BANKREF) <> 'NOTPROVIDED'
                             and count(*) over (partition by y.IBAN, y.BANKREF) = 1
                            then y.IBAN || ':' || y.BANKREF
                            else y.IBAN || ':' || rawtohex(standard_hash(to_char(y.BUCHUNG, 'YYYYMMDD') || '|' || y.RICHTUNG || '|'
                                                    || to_char(y.BETRAG, 'FM999999999990.00') || '|' || y.NAME || '|' || y.ZWECK
                                                    || '|' || y.E2E || '|' || y.REFERENZ || '|'
                                                    || row_number() over (partition by y.IBAN, y.BUCHUNG, y.RICHTUNG, y.BETRAG,
                                                                                       y.NAME, y.ZWECK, y.E2E, y.REFERENZ
                                                                          order by y.NR), 'SHA256'))
                       end as SCHLUESSEL
                  from (select replace(upper(a.IBAN), ' ') as IBAN,
                               to_date(substr(coalesce(n.BUCHUNG_DT, n.BUCHUNG_DTTM), 1, 10), 'YYYY-MM-DD') as BUCHUNG,
                               to_date(substr(coalesce(n.VALUTA_DT, n.VALUTA_DTTM), 1, 10), 'YYYY-MM-DD') as VALUTA,
                               abs(to_number(n.BETRAG, '999999999999990D99999', 'NLS_NUMERIC_CHARACTERS=''.,''')) as BETRAG,
                               nvl(n.WAEHRUNG, 'EUR') as WAEHRUNG,
                               n.RICHTUNG,
                               substr(coalesce(n.NAME1, n.NAME2, n.NAME3, n.NAME4), 1, 200) as NAME,
                               coalesce(n.GEGEN_IBAN1, n.GEGEN_IBAN2) as GEGEN_IBAN,
                               n.REFERENZ,
                               case when upper(n.E2E) <> 'NOTPROVIDED' then n.E2E end as E2E,
                               substr(trim(n.ZWECK1 || ' ' || n.ZWECK2 || ' ' || n.ZWECK3 || ' ' || n.ZWECK4), 1, 1000) as ZWECK,
                               n.BANKREF,
                               a.RNR * 10000 + n.NR as NR
                          from xmltable('/*:Document/*/*[*:Acct]' passing l_xml
                                        columns RNR for ordinality,
                                                IBAN varchar2(40) path '*:Acct/*:Id/*:IBAN',
                                                NTRYS xmltype path '.') a,
                               xmltable('/*/*:Ntry' passing a.NTRYS
                                        columns NR for ordinality,
                                                BETRAG varchar2(30) path '*:Amt',
                                                WAEHRUNG varchar2(3) path '*:Amt/@Ccy',
                                                RICHTUNG varchar2(4) path '*:CdtDbtInd',
                                                BUCHUNG_DT varchar2(30) path '*:BookgDt/*:Dt',
                                                BUCHUNG_DTTM varchar2(40) path '*:BookgDt/*:DtTm',
                                                VALUTA_DT varchar2(30) path '*:ValDt/*:Dt',
                                                VALUTA_DTTM varchar2(40) path '*:ValDt/*:DtTm',
                                                BANKREF varchar2(100) path '*:AcctSvcrRef',
                                                NAME1 varchar2(200) path '*:NtryDtls/*:TxDtls[1]/*:RltdPties/*:Dbtr/*:Nm',
                                                NAME2 varchar2(200) path '*:NtryDtls/*:TxDtls[1]/*:RltdPties/*:Dbtr/*:Pty/*:Nm',
                                                NAME3 varchar2(200) path '*:NtryDtls/*:TxDtls[1]/*:RltdPties/*:Cdtr/*:Nm',
                                                NAME4 varchar2(200) path '*:NtryDtls/*:TxDtls[1]/*:RltdPties/*:Cdtr/*:Pty/*:Nm',
                                                GEGEN_IBAN1 varchar2(34) path '*:NtryDtls/*:TxDtls[1]/*:RltdPties/*:DbtrAcct/*:Id/*:IBAN',
                                                GEGEN_IBAN2 varchar2(34) path '*:NtryDtls/*:TxDtls[1]/*:RltdPties/*:CdtrAcct/*:Id/*:IBAN',
                                                REFERENZ varchar2(140) path '*:NtryDtls/*:TxDtls[1]/*:RmtInf/*:Strd[1]/*:CdtrRefInf/*:Ref',
                                                E2E varchar2(140) path '*:NtryDtls/*:TxDtls[1]/*:Refs/*:EndToEndId',
                                                ZWECK1 varchar2(140) path '*:NtryDtls/*:TxDtls[1]/*:RmtInf/*:Ustrd[1]',
                                                ZWECK2 varchar2(140) path '*:NtryDtls/*:TxDtls[1]/*:RmtInf/*:Ustrd[2]',
                                                ZWECK3 varchar2(140) path '*:NtryDtls/*:TxDtls[1]/*:RmtInf/*:Ustrd[3]',
                                                ZWECK4 varchar2(140) path '*:NtryDtls/*:TxDtls[1]/*:RmtInf/*:Ustrd[4]') n) y) x
         where not exists (select 1 from FAKT_BANKUMSAETZE u
                            where u.BKUM_MAND_ID = p_mand_id and u.BKUM_SCHLUESSEL = x.SCHLUESSEL);
        l_neu := sql%rowcount;
        select count(*) into l_anz
          from xmltable('/*:Document/*/*/*:Ntry' passing l_xml columns x varchar2(1) path 'x');
        -- abgleichen aendert Daten: nicht im UPDATE aufrufen (ORA-14551), erst in eine Variable
        l_zug := abgleichen(p_mand_id);
        update FAKT_BANKDATEIEN set BKDT_ANZ_UMSAETZE = l_anz, BKDT_ANZ_NEU = l_neu, BKDT_ANZ_ZUGEORDNET = l_zug
         where BKDT_ID = l_bkdt;
        g_meldung := p_dateiname || ': ' || l_anz || ' Buchungen, davon ' || l_neu || ' neu; ' || l_zug || ' Zahlungseingänge zugeordnet.';
        return l_bkdt;
    end einlesen;

    function abgleichen(p_mand_id in number) return pls_integer is
        l_text    varchar2(2000);
        l_kompakt varchar2(2000);
        l_rech    FAKT_RECHNUNGEN.RECH_ID%type;
        l_art     varchar2(100);
        l_anz     pls_integer;
        l_treffer varchar2(50);
        l_nr      FAKT_RECHNUNGEN.RECH_NUMMER%type;
        l_status  FAKT_RECHNUNGEN.RECH_STATUS%type;
        l_zahl    FAKT_ZAHLUNGEN.ZAHL_ID%type;
        l_zugeordnet pls_integer := 0;
        l_guts    FAKT_GUTSCHRIFTEN.GUTS_ID%type;
        l_gstatus FAKT_GUTSCHRIFTEN.GUTS_STATUS%type;
        l_zdatum  date;
        c_muster  constant varchar2(100) := '(20[0-9]{2})[[:space:]]*[-/][[:space:]]*0*([0-9]{1,5})([^-/0-9]|$)';
    begin
        for u in (select * from FAKT_BANKUMSAETZE
                   -- auch "Rechnung bereits bezahlt": vorhandene Zahlung (anderes Datum) nachtraeglich verknuepfen
                   where BKUM_MAND_ID = p_mand_id and BKUM_STATUS in ('OFFEN', 'BEREITS_BEZAHLT') and BKUM_RICHTUNG = 'CRDT'
                     -- von Hand aufgehobene Zuordnung nicht automatisch wiederherstellen
                     and nvl(BKUM_ZUORDNUNG, '-') not in ('Zuordnung von Hand aufgehoben', 'Zuweisung zum Debitor aufgehoben')
                   order by BKUM_BUCHUNGSDATUM, BKUM_ID) loop
            l_rech := null;
            l_art  := null;
            l_text := upper(u.BKUM_REFERENZ || ' ' || u.BKUM_VERWENDUNGSZWECK || ' ' || u.BKUM_END_TO_END_ID);
            l_kompakt := regexp_replace(l_text, '[^0-9A-Z]');
            -- 0. erhaltene Gutschrift (Gutschriftverfahren): gleicher Betrag und Verwendungszweck bzw. Gutschriftnummer
            --    im Text (Betrag egal – Skonto); sonst Zahlbetrag und Aussteller passt zum Auftraggeber (jeweils eindeutig).
            --    Auch schon von Hand als bezahlt erfasste Gutschriften, solange ihnen noch keine Bankbuchung gehoert.
            select count(*), max(GUTS_ID) into l_anz, l_guts
              from FAKT_GUTSCHRIFTEN g
             where g.GUTS_MAND_ID = p_mand_id and g.GUTS_STATUS in ('OFFEN', 'BEZAHLT')
               and not exists (select 1 from FAKT_BANKUMSAETZE b where b.BKUM_GUTS_ID = g.GUTS_ID)
               and ((g.GUTS_VERWENDUNGSZWECK is not null
                     and instr(l_kompakt, regexp_replace(upper(g.GUTS_VERWENDUNGSZWECK), '[^0-9A-Z]')) > 0)
                    or (length(regexp_replace(upper(g.GUTS_NUMMER), '[^0-9A-Z]')) >= 4
                        and instr(l_kompakt, regexp_replace(upper(g.GUTS_NUMMER), '[^0-9A-Z]')) > 0));
            l_art := 'Gutschrift (Gutschriftnummer/Verwendungszweck)';
            if l_anz <> 1 and u.BKUM_GEGEN_NAME is not null then
                select count(*), max(GUTS_ID) into l_anz, l_guts
                  from FAKT_GUTSCHRIFTEN g
                 where g.GUTS_MAND_ID = p_mand_id and g.GUTS_STATUS in ('OFFEN', 'BEZAHLT')
                   and not exists (select 1 from FAKT_BANKUMSAETZE b where b.BKUM_GUTS_ID = g.GUTS_ID)
                   and coalesce(g.GUTS_ZAHLBETRAG, g.GUTS_BETRAG) = u.BKUM_BETRAG
                   and (utl_match.jaro_winkler_similarity(upper(g.GUTS_AUSSTELLER), upper(u.BKUM_GEGEN_NAME)) >= 85
                        or instr(upper(u.BKUM_GEGEN_NAME), upper(regexp_substr(g.GUTS_AUSSTELLER, '[^ ,.-]{4,}'))) > 0);
                l_art := 'Gutschrift (Betrag und Aussteller)';
            end if;
            if l_anz = 1 then
                select GUTS_STATUS into l_gstatus from FAKT_GUTSCHRIFTEN where GUTS_ID = l_guts;
                if l_gstatus = 'BEZAHLT' then
                    l_art := l_art || ', war bereits als bezahlt erfasst';
                end if;
                -- Zahlungsdatum laut Bank (auch wenn "Bezahlt am" von Hand erfasst war)
                update FAKT_GUTSCHRIFTEN set GUTS_STATUS = 'BEZAHLT', GUTS_BEZAHLT_AM = u.BKUM_BUCHUNGSDATUM
                 where GUTS_ID = l_guts and (GUTS_STATUS <> 'BEZAHLT' or decode(GUTS_BEZAHLT_AM, u.BKUM_BUCHUNGSDATUM, 1, 0) = 0);
                update FAKT_BANKUMSAETZE
                   set BKUM_STATUS = 'ZUGEORDNET', BKUM_GUTS_ID = l_guts, BKUM_RECH_ID = null, BKUM_ZUORDNUNG = l_art
                 where BKUM_ID = u.BKUM_ID;
                l_zugeordnet := l_zugeordnet + 1;
                continue;
            end if;
            l_art := null;
            -- 1. RF-Zahlungsreferenz der Rechnung (Leerzeichen/Trennzeichen egal)
            select count(*), max(RECH_ID) into l_anz, l_rech
              from FAKT_RECHNUNGEN
             where RECH_MAND_ID = p_mand_id and RECH_ZAHLUNGSREFERENZ is not null
               and instr(l_kompakt, RECH_ZAHLUNGSREFERENZ) > 0;
            if l_anz = 1 then
                l_art := 'Zahlungsreferenz';
            else
                l_rech := null;
            end if;
            -- 2. Rechnungsnummer im Text ("2026 -13", "NR. 2026 - 202", "2026/13"; Datumsangaben 2026-10-16 nicht)
            if l_rech is null then
                for i in 1 .. 5 loop
                    l_treffer := regexp_substr(l_text, c_muster, 1, i);
                    exit when l_treffer is null;
                    l_nr := regexp_replace(l_treffer, c_muster, '\1 - \2');
                    select count(*), max(RECH_ID) into l_anz, l_rech
                      from FAKT_RECHNUNGEN where RECH_MAND_ID = p_mand_id and RECH_NUMMER = l_nr;
                    if l_anz = 1 then
                        l_art := 'Rechnungsnummer ' || l_nr;
                        exit;
                    end if;
                    l_rech := null;
                end loop;
            end if;
            -- 2b. Rechnungsnummer ohne Trennzeichen ("2026201/22.9." = 2026 - 201) – nur wenn der Auftraggeber der Kunde
            --     der Rechnung ist (FAKT_DEBITOR.ist_kunde, Skript 45)
            if l_rech is null and u.BKUM_GEGEN_NAME is not null then
                for i in 1 .. 5 loop
                    l_treffer := regexp_substr(l_text, '(^|[^0-9])(20[0-9]{2})([0-9]{1,5})([^0-9]|$)', 1, i, null, 2);
                    exit when l_treffer is null;
                    l_nr := l_treffer || ' - ' || to_number(regexp_substr(l_text, '(^|[^0-9])(20[0-9]{2})([0-9]{1,5})([^0-9]|$)', 1, i, null, 3));
                    select count(*), max(RECH_ID) into l_anz, l_rech
                      from FAKT_RECHNUNGEN
                     where RECH_MAND_ID = p_mand_id and RECH_NUMMER = l_nr
                       and FAKT_DEBITOR.ist_kunde(RECH_EMPF_NAME, u.BKUM_GEGEN_NAME) = 'Y';
                    if l_anz = 1 then
                        l_art := 'Rechnungsnummer ' || l_nr || ' (ohne Trennzeichen) und Kunde';
                        exit;
                    end if;
                    l_rech := null;
                end loop;
            end if;
            -- 3. offener Betrag und Auftraggeber passt zum Kunden (nur eindeutig)
            if l_rech is null and u.BKUM_GEGEN_NAME is not null then
                select count(*), max(v.RECH_ID) into l_anz, l_rech
                  from FAKT_RECHNUNGEN_V v
                  join FAKT_RECHNUNGEN r on r.RECH_ID = v.RECH_ID
                 where r.RECH_MAND_ID = p_mand_id
                   and r.RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT')
                   and v.OFFEN = u.BKUM_BETRAG
                   and (utl_match.jaro_winkler_similarity(upper(r.RECH_EMPF_NAME), upper(u.BKUM_GEGEN_NAME)) >= 85
                        or instr(upper(u.BKUM_GEGEN_NAME), upper(regexp_substr(r.RECH_EMPF_NAME, '[^ ,.-]{4,}'))) > 0);
                if l_anz = 1 then
                    l_art := 'Betrag und Kunde';
                else
                    l_rech := null;
                end if;
            end if;
            if l_rech is null then
                continue;
            end if;

            select RECH_STATUS into l_status from FAKT_RECHNUNGEN where RECH_ID = l_rech;
            -- gleich hohe Zahlung +-7 Tage, die noch keiner Buchung gehoert (z.B. von Hand erfasst): verknuepfen
            select min(z.ZAHL_ID) into l_zahl
              from FAKT_ZAHLUNGEN z
             where z.ZAHL_RECH_ID = l_rech and z.ZAHL_BETRAG = u.BKUM_BETRAG
               and abs(z.ZAHL_DATUM - u.BKUM_BUCHUNGSDATUM) <= 7
               and not exists (select 1 from FAKT_BANKUMSAETZE b where b.BKUM_ZAHL_ID = z.ZAHL_ID);
            -- Rechnung schon bezahlt: gleich hohe Zahlung mit anderem Datum (z. B. aus dem Altsystem) verknuepfen
            if l_zahl is null and l_status = 'BEZAHLT' then
                select min(z.ZAHL_ID) keep (dense_rank first order by abs(z.ZAHL_DATUM - u.BKUM_BUCHUNGSDATUM)),
                       min(z.ZAHL_DATUM) keep (dense_rank first order by abs(z.ZAHL_DATUM - u.BKUM_BUCHUNGSDATUM))
                  into l_zahl, l_zdatum
                  from FAKT_ZAHLUNGEN z
                 where z.ZAHL_RECH_ID = l_rech and z.ZAHL_BETRAG = u.BKUM_BETRAG
                   and not exists (select 1 from FAKT_BANKUMSAETZE b where b.BKUM_ZAHL_ID = z.ZAHL_ID);
                if l_zahl is not null then
                    l_art := l_art || ', vorhandene Zahlung vom ' || to_char(l_zdatum, 'DD.MM.YYYY');
                end if;
            elsif l_zahl is not null then
                l_art := l_art || ', vorhandene Zahlung';
            end if;
            if l_zahl is not null then
                update FAKT_BANKUMSAETZE
                   set BKUM_STATUS = 'ZUGEORDNET', BKUM_RECH_ID = l_rech, BKUM_ZAHL_ID = l_zahl,
                       BKUM_ZUORDNUNG = l_art
                 where BKUM_ID = u.BKUM_ID;
                l_zugeordnet := l_zugeordnet + 1;
            elsif l_status in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT') then
                -- Zahlung anlegen (Trigger: Zahlungsstatus der Rechnung, Historie)
                insert into FAKT_ZAHLUNGEN (ZAHL_RECH_ID, ZAHL_DATUM, ZAHL_BETRAG, ZAHL_REFERENZ, ZAHL_BEMERKUNG)
                values (l_rech, u.BKUM_BUCHUNGSDATUM, u.BKUM_BETRAG,
                        substr(coalesce(u.BKUM_REFERENZ, u.BKUM_VERWENDUNGSZWECK, u.BKUM_END_TO_END_ID), 1, 140),
                        substr('Bankabgleich: ' || u.BKUM_GEGEN_NAME, 1, 500))
                returning ZAHL_ID into l_zahl;
                update FAKT_BANKUMSAETZE
                   set BKUM_STATUS = 'ZUGEORDNET', BKUM_RECH_ID = l_rech, BKUM_ZAHL_ID = l_zahl, BKUM_ZUORDNUNG = l_art
                 where BKUM_ID = u.BKUM_ID;
                l_zugeordnet := l_zugeordnet + 1;
            elsif l_status = 'BEZAHLT' then
                update FAKT_BANKUMSAETZE
                   set BKUM_STATUS = 'BEREITS_BEZAHLT', BKUM_RECH_ID = l_rech,
                       BKUM_ZUORDNUNG = l_art || ' – Rechnung war bereits bezahlt'
                 where BKUM_ID = u.BKUM_ID;
            else
                update FAKT_BANKUMSAETZE
                   set BKUM_RECH_ID = l_rech,
                       BKUM_ZUORDNUNG = l_art || ' – Rechnung ist ' || FAKT_RECHNUNG.status_text(l_status) || ', nicht zugeordnet'
                 where BKUM_ID = u.BKUM_ID;
            end if;
        end loop;
        -- danach Debitoren ohne Rechnung (z. B. Mieter): IBAN bzw. Name des Zahlers (Skript 45)
        return l_zugeordnet + FAKT_DEBITOR.abgleichen(p_mand_id);
    end abgleichen;

    procedure aufheben(p_bkum_id in number) is
    begin
        for u in (select * from FAKT_BANKUMSAETZE where BKUM_ID = p_bkum_id) loop
            if u.BKUM_DEBI_ID is not null then
                for z in (select DZAH_ID from FAKT_DEBITOR_ZAHLUNGEN where DZAH_BKUM_ID = u.BKUM_ID) loop
                    FAKT_DEBITOR.aufheben(z.DZAH_ID);
                end loop;
            end if;
            if u.BKUM_GUTS_ID is not null and instr(u.BKUM_ZUORDNUNG, 'bereits als bezahlt') = 0 then
                -- vom Abgleich bezahlt gesetzt: wieder offen (Trigger: Status aus Datei/Datum)
                update FAKT_GUTSCHRIFTEN set GUTS_BEZAHLT_AM = null, GUTS_STATUS = 'OFFEN'
                 where GUTS_ID = u.BKUM_GUTS_ID and GUTS_BEZAHLT_AM = u.BKUM_BUCHUNGSDATUM;
            end if;
            update FAKT_BANKUMSAETZE
               set BKUM_STATUS = 'OFFEN', BKUM_RECH_ID = null, BKUM_ZAHL_ID = null, BKUM_GUTS_ID = null, BKUM_DEBI_ID = null,
                   BKUM_ZUORDNUNG = 'Zuordnung von Hand aufgehoben'
             where BKUM_ID = u.BKUM_ID;
            -- vom Bankabgleich angelegte Zahlung entfernen (Trigger: Zahlungsstatus der Rechnung, Historie)
            if u.BKUM_ZAHL_ID is not null then
                delete from FAKT_ZAHLUNGEN where ZAHL_ID = u.BKUM_ZAHL_ID and ZAHL_BEMERKUNG like 'Bankabgleich%';
            end if;
        end loop;
    end aufheben;

    procedure zuordnen(p_bkum_id in number, p_belegart in varchar2, p_beleg_id in number) is
        l_u      FAKT_BANKUMSAETZE%rowtype;
        l_mand   number;
        l_status varchar2(20);
        l_nr     varchar2(50);
        l_zahl   number;
        l_zdatum date;
        l_art    varchar2(200);
    begin
        select * into l_u from FAKT_BANKUMSAETZE where BKUM_ID = p_bkum_id;
        if l_u.BKUM_RICHTUNG <> 'CRDT' then
            raise_application_error(-20264, 'Nur Zahlungseingänge können zugeordnet werden.');
        end if;
        if p_belegart = 'DEBITOR' then
            select DEBI_MAND_ID, 'AKTIV', DEBI_NAME into l_mand, l_status, l_nr
              from FAKT_DEBITOREN where DEBI_ID = p_beleg_id;
        elsif p_belegart = 'GUTSCHRIFT' then
            select GUTS_MAND_ID, GUTS_STATUS, coalesce(GUTS_INTERN_NUMMER, GUTS_NUMMER) into l_mand, l_status, l_nr
              from FAKT_GUTSCHRIFTEN where GUTS_ID = p_beleg_id;
        else
            select RECH_MAND_ID, RECH_STATUS, RECH_NUMMER into l_mand, l_status, l_nr
              from FAKT_RECHNUNGEN where RECH_ID = p_beleg_id;
        end if;
        if l_mand <> l_u.BKUM_MAND_ID then
            raise_application_error(-20265, 'Der Beleg gehört zu einem anderen Mandanten.');
        end if;
        if l_status in ('ENTWURF', 'IN_BEARBEITUNG', 'STORNIERT') then
            raise_application_error(-20266, 'Entwürfe, Rechnungen in Bearbeitung und stornierte Belege können nicht zugeordnet werden.');
        end if;
        -- bestehende Zuordnung zuerst aufheben
        if l_u.BKUM_STATUS not in ('OFFEN', 'AUSGANG', 'IGNORIERT') then
            aufheben(p_bkum_id);
        end if;

        if p_belegart = 'DEBITOR' then
            -- Zahlung beim Debitor anlegen, Status DEBITOR, IBAN merken (FAKT_DEBITOR, Skript 45)
            FAKT_DEBITOR.zuweisen(p_bkum_id, p_beleg_id);
            return;
        end if;
        if p_belegart = 'GUTSCHRIFT' then
            l_art := 'Von Hand zugeordnet: Gutschrift ' || l_nr || case when l_status = 'BEZAHLT' then ', war bereits als bezahlt erfasst' end;
            update FAKT_GUTSCHRIFTEN set GUTS_STATUS = 'BEZAHLT', GUTS_BEZAHLT_AM = l_u.BKUM_BUCHUNGSDATUM where GUTS_ID = p_beleg_id;
            update FAKT_BANKUMSAETZE set BKUM_STATUS = 'ZUGEORDNET', BKUM_GUTS_ID = p_beleg_id, BKUM_ZUORDNUNG = l_art
             where BKUM_ID = p_bkum_id;
            return;
        end if;

        -- Rechnung: gleich hohe, noch keiner Buchung gehoerende Zahlung (naechstes Datum) verknuepfen
        select min(z.ZAHL_ID) keep (dense_rank first order by abs(z.ZAHL_DATUM - l_u.BKUM_BUCHUNGSDATUM)),
               min(z.ZAHL_DATUM) keep (dense_rank first order by abs(z.ZAHL_DATUM - l_u.BKUM_BUCHUNGSDATUM))
          into l_zahl, l_zdatum
          from FAKT_ZAHLUNGEN z
         where z.ZAHL_RECH_ID = p_beleg_id and z.ZAHL_BETRAG = l_u.BKUM_BETRAG
           and not exists (select 1 from FAKT_BANKUMSAETZE b where b.BKUM_ZAHL_ID = z.ZAHL_ID);
        if l_zahl is not null then
            l_art := 'Von Hand zugeordnet: Rechnung ' || l_nr || ', vorhandene Zahlung vom ' || to_char(l_zdatum, 'DD.MM.YYYY');
        elsif l_status in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT') then
            insert into FAKT_ZAHLUNGEN (ZAHL_RECH_ID, ZAHL_DATUM, ZAHL_BETRAG, ZAHL_REFERENZ, ZAHL_BEMERKUNG)
            values (p_beleg_id, l_u.BKUM_BUCHUNGSDATUM, l_u.BKUM_BETRAG,
                    substr(coalesce(l_u.BKUM_REFERENZ, l_u.BKUM_VERWENDUNGSZWECK, l_u.BKUM_END_TO_END_ID), 1, 140),
                    substr('Bankabgleich (von Hand): ' || l_u.BKUM_GEGEN_NAME, 1, 500))
            returning ZAHL_ID into l_zahl;
            l_art := 'Von Hand zugeordnet: Rechnung ' || l_nr || ', Zahlung angelegt';
        else
            l_art := 'Von Hand zugeordnet: Rechnung ' || l_nr || ' (war bereits bezahlt, keine Zahlung angelegt)';
        end if;
        update FAKT_BANKUMSAETZE
           set BKUM_STATUS = 'ZUGEORDNET', BKUM_RECH_ID = p_beleg_id, BKUM_ZAHL_ID = l_zahl, BKUM_ZUORDNUNG = substr(l_art, 1, 200)
         where BKUM_ID = p_bkum_id;
    end zuordnen;

    function status_text(p_status in varchar2) return varchar2 deterministic is
    begin
        return case p_status when 'OFFEN'           then 'Nicht zugeordnet'
                             when 'ZUGEORDNET'      then 'Zugeordnet'
                             when 'BEREITS_BEZAHLT' then 'Rechnung bereits bezahlt'
                             when 'AUSGANG'         then 'Ausgang'
                             when 'IGNORIERT'       then 'Ignoriert'
                             when 'DEBITOR'         then 'Zugeordnet'   -- Debitor: gleicher Text, damit sich alle zugeordneten ausblenden lassen
                             else initcap(p_status) end;
    end status_text;

end FAKT_BANK;
/

show errors package body FAKT_BANK

prompt Bankabgleich installiert.
