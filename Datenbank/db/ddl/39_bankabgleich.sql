-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 39 – Bankabgleich: Kontoauszug als CAMT-Datei (camt.052/.053/.054, z.B. ELBA-Export der Raiffeisenbank) hochladen,
--      Umsaetze speichern und Eingaenge automatisch den offenen Rechnungen des Mandanten zuordnen.
--      FAKT_BANKDATEIEN (BKDT): hochgeladene Datei (Original, Format, Nachrichten-ID, Zaehler)
--      FAKT_BANKUMSAETZE (BKUM): je Buchung Datum, Betrag, Richtung, Auftraggeber, Referenz, Verwendungszweck, Status
--        OFFEN (Eingang ohne Zuordnung), ZUGEORDNET (Zahlung zur Rechnung angelegt bzw. vorhandene verknuepft),
--        BEREITS_BEZAHLT (Rechnung erkannt, war schon bezahlt), AUSGANG (Abbuchung), IGNORIERT
--        Jede Buchung nur einmal je Mandant (BKUM_SCHLUESSEL: Bankreferenz bzw. Pruefsumme) – ueberlappende Dateien schaden nicht.
--      Package FAKT_BANK: einlesen (Datei pruefen, Konto muss zum Mandanten gehoeren), abgleichen
--        Zuordnung: 1. RF-Zahlungsreferenz, 2. Rechnungsnummer im Text, 3. offener Betrag + Auftraggeber passt zum Kunden.
--        Offene Rechnung: Zahlung anlegen (Trigger setzen Status/Historie) bzw. gleich hohe Zahlung +-7 Tage verknuepfen.
-- Voraussetzung: 17/18 (Mandanten, Bankverbindungen), 20/21, 36/38 (Zahlungsreferenz)
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
                         q'~BKUM_STATUS in ('OFFEN', 'ZUGEORDNET', 'BEREITS_BEZAHLT', 'AUSGANG', 'IGNORIERT')~');
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

create or replace package FAKT_BANK as
    -- CAMT-Datei (camt.052/.053/.054) einlesen: Konto muss zum Mandanten gehoeren, Datei (Nachrichten-ID) nur einmal;
    -- neue Buchungen speichern (bereits vorhandene werden uebersprungen), danach abgleichen. Liefert die ID der Bankdatei.
    function einlesen(p_mand_id in number, p_dateiname in varchar2, p_datei in blob) return number;
    -- offene Eingaenge des Mandanten den Rechnungen zuordnen; liefert die Anzahl neu zugeordneter Eingaenge
    function abgleichen(p_mand_id in number) return pls_integer;
    -- Status als Text (Liste der Bankumsaetze)
    function status_text(p_status in varchar2) return varchar2 deterministic;
end FAKT_BANK;
/

create or replace package body FAKT_BANK as

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
            raise_application_error(-20262, 'Diese Bankdatei wurde bereits am ' || l_wann || ' hochgeladen.');
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
                       -- Schluessel: Referenz der Bank; fehlt sie, Pruefsumme der Buchungsdaten (gleiche Buchungen am selben
                       -- Tag werden mitgezaehlt)
                       case when y.BANKREF is not null and upper(y.BANKREF) <> 'NOTPROVIDED'
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
        c_muster  constant varchar2(100) := '(20[0-9]{2})[[:space:]]*[-/][[:space:]]*0*([0-9]{1,5})([^-/0-9]|$)';
    begin
        for u in (select * from FAKT_BANKUMSAETZE
                   where BKUM_MAND_ID = p_mand_id and BKUM_STATUS = 'OFFEN' and BKUM_RICHTUNG = 'CRDT'
                   order by BKUM_BUCHUNGSDATUM, BKUM_ID) loop
            l_rech := null;
            l_art  := null;
            l_text := upper(u.BKUM_REFERENZ || ' ' || u.BKUM_VERWENDUNGSZWECK || ' ' || u.BKUM_END_TO_END_ID);
            l_kompakt := regexp_replace(l_text, '[^0-9A-Z]');
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
            if l_zahl is not null then
                update FAKT_BANKUMSAETZE
                   set BKUM_STATUS = 'ZUGEORDNET', BKUM_RECH_ID = l_rech, BKUM_ZAHL_ID = l_zahl,
                       BKUM_ZUORDNUNG = l_art || ', vorhandene Zahlung'
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
        return l_zugeordnet;
    end abgleichen;

    function status_text(p_status in varchar2) return varchar2 deterministic is
    begin
        return case p_status when 'OFFEN'           then 'Nicht zugeordnet'
                             when 'ZUGEORDNET'      then 'Zugeordnet'
                             when 'BEREITS_BEZAHLT' then 'Rechnung bereits bezahlt'
                             when 'AUSGANG'         then 'Ausgang'
                             when 'IGNORIERT'       then 'Ignoriert'
                             else initcap(p_status) end;
    end status_text;

end FAKT_BANK;
/

show errors package body FAKT_BANK

prompt Bankabgleich installiert.
