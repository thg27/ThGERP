-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 45 – Debitoren: Zahler ohne Rechnung/Gutschrift (z. B. Mieter), die regelmaessig einen festen Betrag ueberweisen.
--      FAKT_DEBITOREN (DEBI): Name, Bezeichnung, Betrag, Intervall (einmalig/monatlich/quartal/halbjaehrlich/jaehrlich),
--        faellig ab/bis, IBAN des Zahlers (Bankabgleich), optional Kunde; je Mandant
--      FAKT_DEBITOR_POSTEN (DPOS): faellige Betraege, aus dem Intervall erzeugt (bis Ende des naechsten Monats)
--      FAKT_DEBITOR_ZAHLUNGEN (DZAH): Zahlungen, aus der Bankdatei zugewiesen (BKUM_DEBI_ID, Status DEBITOR)
--      Zahlungen decken die Posten der Reihe nach (aelteste zuerst): View FAKT_DEBITOR_POSTEN_V (bezahlt, offen,
--        bezahlt am), FAKT_DEBITOREN_V (Rueckstand, naechste Faelligkeit, letzte Zahlung)
--      Package FAKT_DEBITOR: posten_erzeugen, planen (nach Aenderung), zuweisen/aufheben, abgleichen (IBAN bzw. Name),
--        von FAKT_BANK.abgleichen nach Rechnungen/Gutschriften aufgerufen.
-- Voraussetzung: 39 (Bankabgleich)
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.tabelle('FAKT_DEBITOREN', q'~create table FAKT_DEBITOREN (
  DEBI_ID number not null,
  DEBI_MAND_ID number not null,
  DEBI_NAME varchar2(200 char) not null,
  DEBI_BEZEICHNUNG varchar2(200 char),
  DEBI_KUND_ID number,
  DEBI_BETRAG number(14,2) not null,
  DEBI_INTERVALL varchar2(20 char) default 'MONATLICH' not null,
  DEBI_FAELLIG_AB date not null,
  DEBI_FAELLIG_BIS date,
  DEBI_IBAN varchar2(34 char),
  DEBI_IST_AKTIV varchar2(1 char) default 'Y' not null,
  DEBI_BEMERKUNG varchar2(1000 char),
  DEBI_CREATED_ON timestamp not null,
  DEBI_CREATED_BY varchar2(255 char) not null,
  DEBI_UPDATED_ON timestamp,
  DEBI_UPDATED_BY varchar2(255 char),
  DEBI_ROW_VERSION number not null,
  constraint DEBI_PK primary key (DEBI_ID)
)~');
    DDL_UTIL.constraint_('FAKT_DEBITOREN', 'DEBI_INTERVALL_CK', 'C',
                         q'~DEBI_INTERVALL in ('EINMALIG', 'MONATLICH', 'QUARTAL', 'HALBJAEHRLICH', 'JAEHRLICH')~');
    DDL_UTIL.constraint_('FAKT_DEBITOREN', 'DEBI_IST_AKTIV_CK', 'C', q'~DEBI_IST_AKTIV in ('Y', 'N')~');
    DDL_UTIL.constraint_('FAKT_DEBITOREN', 'DEBI_BETRAG_CK', 'C', 'DEBI_BETRAG > 0');
    DDL_UTIL.constraint_('FAKT_DEBITOREN', 'DEBI_BIS_CK', 'C', 'DEBI_FAELLIG_BIS is null or DEBI_FAELLIG_BIS >= DEBI_FAELLIG_AB');
    DDL_UTIL.constraint_('FAKT_DEBITOREN', 'DEBI_MAND_FK', 'R', 'DEBI_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('FAKT_DEBITOREN', 'DEBI_KUND_FK', 'R', 'DEBI_KUND_ID references KUND_KUNDEN (KUND_ID)');
    DDL_UTIL.index_('FAKT_DEBITOREN', 'DEBI_MAND_I', 'DEBI_MAND_ID');
    DDL_UTIL.index_('FAKT_DEBITOREN', 'DEBI_KUND_I', 'DEBI_KUND_ID');
    DDL_UTIL.trigger_pruefen('DEBI_BIU', 'FAKT_DEBITOREN');

    DDL_UTIL.tabelle('FAKT_DEBITOR_POSTEN', q'~create table FAKT_DEBITOR_POSTEN (
  DPOS_ID number not null,
  DPOS_DEBI_ID number not null,
  DPOS_FAELLIG_AM date not null,
  DPOS_BETRAG number(14,2) not null,
  DPOS_CREATED_ON timestamp not null,
  DPOS_CREATED_BY varchar2(255 char) not null,
  DPOS_UPDATED_ON timestamp,
  DPOS_UPDATED_BY varchar2(255 char),
  DPOS_ROW_VERSION number not null,
  constraint DPOS_PK primary key (DPOS_ID)
)~');
    DDL_UTIL.constraint_('FAKT_DEBITOR_POSTEN', 'DPOS_UK', 'U', 'DPOS_DEBI_ID, DPOS_FAELLIG_AM');
    DDL_UTIL.constraint_('FAKT_DEBITOR_POSTEN', 'DPOS_DEBI_FK', 'R', 'DPOS_DEBI_ID references FAKT_DEBITOREN (DEBI_ID) on delete cascade');
    DDL_UTIL.trigger_pruefen('DPOS_BIU', 'FAKT_DEBITOR_POSTEN');

    DDL_UTIL.tabelle('FAKT_DEBITOR_ZAHLUNGEN', q'~create table FAKT_DEBITOR_ZAHLUNGEN (
  DZAH_ID number not null,
  DZAH_DEBI_ID number not null,
  DZAH_DATUM date not null,
  DZAH_BETRAG number(14,2) not null,
  DZAH_BKUM_ID number,
  DZAH_BEMERKUNG varchar2(500 char),
  DZAH_CREATED_ON timestamp not null,
  DZAH_CREATED_BY varchar2(255 char) not null,
  DZAH_UPDATED_ON timestamp,
  DZAH_UPDATED_BY varchar2(255 char),
  DZAH_ROW_VERSION number not null,
  constraint DZAH_PK primary key (DZAH_ID)
)~');
    DDL_UTIL.constraint_('FAKT_DEBITOR_ZAHLUNGEN', 'DZAH_BKUM_UK', 'U', 'DZAH_BKUM_ID');
    DDL_UTIL.constraint_('FAKT_DEBITOR_ZAHLUNGEN', 'DZAH_DEBI_FK', 'R', 'DZAH_DEBI_ID references FAKT_DEBITOREN (DEBI_ID) on delete cascade');
    DDL_UTIL.constraint_('FAKT_DEBITOR_ZAHLUNGEN', 'DZAH_BKUM_FK', 'R', 'DZAH_BKUM_ID references FAKT_BANKUMSAETZE (BKUM_ID) on delete set null');
    DDL_UTIL.index_('FAKT_DEBITOR_ZAHLUNGEN', 'DZAH_DEBI_I', 'DZAH_DEBI_ID');
    DDL_UTIL.trigger_pruefen('DZAH_BIU', 'FAKT_DEBITOR_ZAHLUNGEN');

    -- Bankbuchung -> Debitor, neuer Status DEBITOR ("Zugewiesen zu Debitor")
    DDL_UTIL.spalte('FAKT_BANKUMSAETZE', 'BKUM_DEBI_ID', 'number', 'Y');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_DEBI_FK', 'R', 'BKUM_DEBI_ID references FAKT_DEBITOREN (DEBI_ID) on delete set null');
    DDL_UTIL.index_('FAKT_BANKUMSAETZE', 'BKUM_DEBI_I', 'BKUM_DEBI_ID');
    DDL_UTIL.constraint_('FAKT_BANKUMSAETZE', 'BKUM_STATUS_CK', 'C',
                         q'~BKUM_STATUS in ('OFFEN', 'ZUGEORDNET', 'BEREITS_BEZAHLT', 'AUSGANG', 'IGNORIERT', 'DEBITOR')~');
end;
/

create or replace trigger DEBI_BIU
  before insert or update on FAKT_DEBITOREN
  for each row
begin
  if inserting then
    :new.DEBI_ID := coalesce(:new.DEBI_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.DEBI_CREATED_ON  := systimestamp;
    :new.DEBI_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DEBI_UPDATED_ON  := null;
    :new.DEBI_UPDATED_BY  := null;
    :new.DEBI_ROW_VERSION := 1;
  elsif updating then
    :new.DEBI_ID          := :old.DEBI_ID;  -- Primaerschluessel ist unveraenderlich
    :new.DEBI_CREATED_ON  := :old.DEBI_CREATED_ON;
    :new.DEBI_CREATED_BY  := :old.DEBI_CREATED_BY;
    :new.DEBI_UPDATED_ON  := systimestamp;
    :new.DEBI_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DEBI_ROW_VERSION := nvl(:old.DEBI_ROW_VERSION, 0) + 1;
  end if;
  -- IBAN ohne Leerzeichen, gross
  :new.DEBI_IBAN := replace(upper(:new.DEBI_IBAN), ' ');
end DEBI_BIU;
/

create or replace trigger DPOS_BIU
  before insert or update on FAKT_DEBITOR_POSTEN
  for each row
begin
  if inserting then
    :new.DPOS_ID := coalesce(:new.DPOS_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.DPOS_CREATED_ON  := systimestamp;
    :new.DPOS_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DPOS_UPDATED_ON  := null;
    :new.DPOS_UPDATED_BY  := null;
    :new.DPOS_ROW_VERSION := 1;
  elsif updating then
    :new.DPOS_ID          := :old.DPOS_ID;  -- Primaerschluessel ist unveraenderlich
    :new.DPOS_CREATED_ON  := :old.DPOS_CREATED_ON;
    :new.DPOS_CREATED_BY  := :old.DPOS_CREATED_BY;
    :new.DPOS_UPDATED_ON  := systimestamp;
    :new.DPOS_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DPOS_ROW_VERSION := nvl(:old.DPOS_ROW_VERSION, 0) + 1;
  end if;
end DPOS_BIU;
/

create or replace trigger DZAH_BIU
  before insert or update on FAKT_DEBITOR_ZAHLUNGEN
  for each row
begin
  if inserting then
    :new.DZAH_ID := coalesce(:new.DZAH_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.DZAH_CREATED_ON  := systimestamp;
    :new.DZAH_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DZAH_UPDATED_ON  := null;
    :new.DZAH_UPDATED_BY  := null;
    :new.DZAH_ROW_VERSION := 1;
  elsif updating then
    :new.DZAH_ID          := :old.DZAH_ID;  -- Primaerschluessel ist unveraenderlich
    :new.DZAH_CREATED_ON  := :old.DZAH_CREATED_ON;
    :new.DZAH_CREATED_BY  := :old.DZAH_CREATED_BY;
    :new.DZAH_UPDATED_ON  := systimestamp;
    :new.DZAH_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.DZAH_ROW_VERSION := nvl(:old.DZAH_ROW_VERSION, 0) + 1;
  end if;
end DZAH_BIU;
/

comment on table FAKT_DEBITOREN is 'Debitoren ohne Rechnung/Gutschrift (z. B. Mieter) mit regelmaessigem Betrag je Mandant [Alias DEBI]';
comment on column FAKT_DEBITOREN.DEBI_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_DEBITOREN.DEBI_MAND_ID is 'FK: Mandant (Zahlungsempfaenger)';
comment on column FAKT_DEBITOREN.DEBI_NAME is 'Name des Debitors (Zahler)';
comment on column FAKT_DEBITOREN.DEBI_BEZEICHNUNG is 'Wofuer gezahlt wird, z. B. Miete Wohnung Top 3';
comment on column FAKT_DEBITOREN.DEBI_KUND_ID is 'FK: Kunde, optional';
comment on column FAKT_DEBITOREN.DEBI_BETRAG is 'Zu ueberweisender Betrag je Faelligkeit';
comment on column FAKT_DEBITOREN.DEBI_INTERVALL is 'EINMALIG, MONATLICH, QUARTAL, HALBJAEHRLICH, JAEHRLICH';
comment on column FAKT_DEBITOREN.DEBI_FAELLIG_AB is 'Erste Faelligkeit (weitere im Intervall am selben Tag)';
comment on column FAKT_DEBITOREN.DEBI_FAELLIG_BIS is 'Letzte Faelligkeit (leer = unbefristet)';
comment on column FAKT_DEBITOREN.DEBI_IBAN is 'IBAN des Zahlers (Bankabgleich); wird bei der ersten Zuweisung uebernommen';
comment on column FAKT_DEBITOREN.DEBI_IST_AKTIV is 'Y = aktiv (neue Posten werden erzeugt, Bankabgleich)';
comment on column FAKT_DEBITOREN.DEBI_BEMERKUNG is 'Bemerkung';
comment on column FAKT_DEBITOREN.DEBI_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_DEBITOREN.DEBI_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_DEBITOREN.DEBI_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_DEBITOREN.DEBI_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_DEBITOREN.DEBI_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table FAKT_DEBITOR_POSTEN is 'Faellige Betraege eines Debitors (aus dem Intervall erzeugt) [Alias DPOS]';
comment on column FAKT_DEBITOR_POSTEN.DPOS_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_DEBITOR_POSTEN.DPOS_DEBI_ID is 'FK: Debitor';
comment on column FAKT_DEBITOR_POSTEN.DPOS_FAELLIG_AM is 'Faellig am';
comment on column FAKT_DEBITOR_POSTEN.DPOS_BETRAG is 'Faelliger Betrag (Betrag des Debitors bei der Erzeugung)';
comment on column FAKT_DEBITOR_POSTEN.DPOS_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_DEBITOR_POSTEN.DPOS_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_DEBITOR_POSTEN.DPOS_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_DEBITOR_POSTEN.DPOS_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_DEBITOR_POSTEN.DPOS_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table FAKT_DEBITOR_ZAHLUNGEN is 'Zahlungen eines Debitors (aus der Bankdatei zugewiesen) [Alias DZAH]';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_DEBI_ID is 'FK: Debitor';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_DATUM is 'Zahlungsdatum (Buchungsdatum)';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_BETRAG is 'Betrag';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_BKUM_ID is 'FK: Bankbuchung (je Buchung nur eine Zahlung)';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_BEMERKUNG is 'Bemerkung (Auftraggeber, Verwendungszweck)';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_CREATED_ON is 'Audit: angelegt am';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_CREATED_BY is 'Audit: angelegt von';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column FAKT_DEBITOR_ZAHLUNGEN.DZAH_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';
comment on column FAKT_BANKUMSAETZE.BKUM_DEBI_ID is 'FK: zugewiesener Debitor (Status DEBITOR)';
comment on column FAKT_BANKUMSAETZE.BKUM_STATUS is 'OFFEN, ZUGEORDNET, BEREITS_BEZAHLT, AUSGANG, IGNORIERT, DEBITOR (zugewiesen zu Debitor)';

-- Posten mit Zahlungsstand: Zahlungen decken die Posten der Reihe nach (aelteste Faelligkeit zuerst)
create or replace view FAKT_DEBITOR_POSTEN_V as
with z as (
    select DZAH_DEBI_ID as DEBI_ID, DZAH_DATUM as DATUM,
           sum(DZAH_BETRAG) over (partition by DZAH_DEBI_ID order by DZAH_DATUM, DZAH_ID) as KUM
      from FAKT_DEBITOR_ZAHLUNGEN
), p as (
    select d.DPOS_ID, d.DPOS_DEBI_ID, d.DPOS_FAELLIG_AM, d.DPOS_BETRAG,
           sum(d.DPOS_BETRAG) over (partition by d.DPOS_DEBI_ID order by d.DPOS_FAELLIG_AM, d.DPOS_ID) as KUM_SOLL,
           nvl((select sum(DZAH_BETRAG) from FAKT_DEBITOR_ZAHLUNGEN where DZAH_DEBI_ID = d.DPOS_DEBI_ID), 0) as GEZAHLT
      from FAKT_DEBITOR_POSTEN d
)
select p.DPOS_ID,
       p.DPOS_DEBI_ID as DEBI_ID,
       b.DEBI_MAND_ID as MAND_ID,
       p.DPOS_FAELLIG_AM as FAELLIG_AM,
       p.DPOS_BETRAG as BETRAG,
       greatest(0, least(p.DPOS_BETRAG, p.GEZAHLT - (p.KUM_SOLL - p.DPOS_BETRAG))) as BEZAHLT,
       p.DPOS_BETRAG - greatest(0, least(p.DPOS_BETRAG, p.GEZAHLT - (p.KUM_SOLL - p.DPOS_BETRAG))) as OFFEN,
       case when p.GEZAHLT >= p.KUM_SOLL then 'BEZAHLT'
            when p.GEZAHLT > p.KUM_SOLL - p.DPOS_BETRAG then 'TEILBEZAHLT'
            else 'OFFEN' end as STATUS,
       case when p.GEZAHLT < p.KUM_SOLL and p.DPOS_FAELLIG_AM < trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))
            then 'Y' else 'N' end as IST_UEBERFAELLIG,
       -- bezahlt am: Datum der Zahlung, mit der die Summe der Zahlungen diesen Posten erreicht
       (select min(z.DATUM) from z where z.DEBI_ID = p.DPOS_DEBI_ID and z.KUM >= p.KUM_SOLL) as BEZAHLT_AM
  from p
  join FAKT_DEBITOREN b on b.DEBI_ID = p.DPOS_DEBI_ID;

comment on table FAKT_DEBITOR_POSTEN_V is 'Posten der Debitoren mit Zahlungsstand (Zahlungen decken die aeltesten Posten zuerst)';

-- Debitoren mit Rueckstand, naechster Faelligkeit und letzter Zahlung
create or replace view FAKT_DEBITOREN_V as
select d.*,
       nvl((select sum(v.OFFEN) from FAKT_DEBITOR_POSTEN_V v
             where v.DEBI_ID = d.DEBI_ID and v.IST_UEBERFAELLIG = 'Y'), 0) as RUECKSTAND,
       (select min(v.FAELLIG_AM) from FAKT_DEBITOR_POSTEN_V v
         where v.DEBI_ID = d.DEBI_ID and v.OFFEN > 0
           and v.FAELLIG_AM >= trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))) as NAECHSTE_FAELLIGKEIT,
       (select max(z.DZAH_DATUM) from FAKT_DEBITOR_ZAHLUNGEN z where z.DZAH_DEBI_ID = d.DEBI_ID) as LETZTE_ZAHLUNG,
       nvl((select sum(z.DZAH_BETRAG) from FAKT_DEBITOR_ZAHLUNGEN z where z.DZAH_DEBI_ID = d.DEBI_ID), 0) as SUMME_GEZAHLT,
       -- Guthaben: mehr gezahlt als bisher faellig
       greatest(0, nvl((select sum(z.DZAH_BETRAG) from FAKT_DEBITOR_ZAHLUNGEN z where z.DZAH_DEBI_ID = d.DEBI_ID), 0)
                   - nvl((select sum(p.DPOS_BETRAG) from FAKT_DEBITOR_POSTEN p where p.DPOS_DEBI_ID = d.DEBI_ID), 0)) as GUTHABEN
  from FAKT_DEBITOREN d;

comment on table FAKT_DEBITOREN_V is 'Debitoren mit Rueckstand (ueberfaellig offen), naechster Faelligkeit, letzter Zahlung und Guthaben';

create or replace package FAKT_DEBITOR as
    -- fehlende Posten aktiver Debitoren erzeugen (Faelligkeiten bis Ende des naechsten Monats); ohne p_debi_id alle des Mandanten
    procedure posten_erzeugen(p_mand_id in number, p_debi_id in number default null);
    -- nach einer Aenderung des Debitors: kuenftige und nicht mehr passende Posten neu erzeugen (bisherige Betraege bleiben)
    procedure planen(p_debi_id in number);
    -- Bankbuchung dem Debitor zuweisen (Zahlung anlegen, Status DEBITOR, IBAN des Zahlers uebernehmen, wenn leer)
    procedure zuweisen(p_bkum_id in number, p_debi_id in number, p_art in varchar2 default 'Von Hand zugewiesen');
    -- Zuweisung aufheben: Zahlung loeschen, Bankbuchung wieder offen
    procedure aufheben(p_dzah_id in number);
    -- neuen Debitor aus einer offenen Bankbuchung anlegen (Name/IBAN des Zahlers, Betrag, monatlich ab Buchungsdatum,
    -- Verwendungszweck als Bezeichnung) und die Buchung gleich zuweisen; liefert die ID des Debitors
    function aus_buchung(p_bkum_id in number) return number;
    -- offene Eingaenge ohne Rechnung den aktiven Debitoren zuweisen (IBAN, sonst Name eindeutig); liefert die Anzahl
    function abgleichen(p_mand_id in number) return pls_integer;
    -- Name des Debitors passt zum Auftraggeber der Buchung ('Y'/'N'): alle Namensteile enthalten (Reihenfolge egal) bzw. aehnlich
    function name_passt(p_name in varchar2, p_auftraggeber in varchar2) return varchar2 deterministic;
    -- Anzeigetexte
    function intervall_text(p_intervall in varchar2) return varchar2 deterministic;
    function status_text(p_status in varchar2) return varchar2 deterministic;
end FAKT_DEBITOR;
/

create or replace package body FAKT_DEBITOR as

    function monate(p_intervall in varchar2) return pls_integer is
    begin
        return case p_intervall when 'MONATLICH' then 1 when 'QUARTAL' then 3 when 'HALBJAEHRLICH' then 6
                                when 'JAEHRLICH' then 12 else 0 end;
    end monate;

    function heute return date is
    begin
        return trunc(cast(systimestamp at time zone 'Europe/Vienna' as date));
    end heute;

    procedure posten_erzeugen(p_mand_id in number, p_debi_id in number default null) is
        l_bis   date := last_day(add_months(heute, 1));
        l_dat   date;
        l_i     pls_integer;
    begin
        for d in (select * from FAKT_DEBITOREN
                   where DEBI_MAND_ID = p_mand_id and DEBI_IST_AKTIV = 'Y'
                     and (p_debi_id is null or DEBI_ID = p_debi_id)) loop
            l_i := 0;
            loop
                l_dat := add_months(d.DEBI_FAELLIG_AB, l_i * monate(d.DEBI_INTERVALL));
                exit when l_dat > l_bis or l_dat > nvl(d.DEBI_FAELLIG_BIS, l_dat);
                insert into FAKT_DEBITOR_POSTEN (DPOS_DEBI_ID, DPOS_FAELLIG_AM, DPOS_BETRAG)
                select d.DEBI_ID, l_dat, d.DEBI_BETRAG from dual
                 where not exists (select 1 from FAKT_DEBITOR_POSTEN where DPOS_DEBI_ID = d.DEBI_ID and DPOS_FAELLIG_AM = l_dat);
                exit when monate(d.DEBI_INTERVALL) = 0;
                l_i := l_i + 1;
            end loop;
        end loop;
    end posten_erzeugen;

    procedure planen(p_debi_id in number) is
        l_mand number;
        l_m    pls_integer;
        l_heute date := heute;
    begin
        for d in (select * from FAKT_DEBITOREN where DEBI_ID = p_debi_id) loop
            l_mand := d.DEBI_MAND_ID;
            l_m    := monate(d.DEBI_INTERVALL);   -- private Funktion nicht in SQL (PLS-00231)
            -- kuenftige Posten (neuer Betrag) und Posten ausserhalb des Zeitraums bzw. nicht im Intervall entfernen
            delete from FAKT_DEBITOR_POSTEN p
             where p.DPOS_DEBI_ID = d.DEBI_ID
               and (p.DPOS_FAELLIG_AM > l_heute
                    or p.DPOS_FAELLIG_AM < d.DEBI_FAELLIG_AB
                    or p.DPOS_FAELLIG_AM > nvl(d.DEBI_FAELLIG_BIS, p.DPOS_FAELLIG_AM)
                    or (l_m = 0 and p.DPOS_FAELLIG_AM <> d.DEBI_FAELLIG_AB)
                    or (l_m > 0 and mod(months_between(p.DPOS_FAELLIG_AM, d.DEBI_FAELLIG_AB), l_m) <> 0));
        end loop;
        if l_mand is not null then
            posten_erzeugen(l_mand, p_debi_id);
        end if;
    end planen;

    procedure zuweisen(p_bkum_id in number, p_debi_id in number, p_art in varchar2 default 'Von Hand zugewiesen') is
        l_debi FAKT_DEBITOREN%rowtype;
    begin
        select * into l_debi from FAKT_DEBITOREN where DEBI_ID = p_debi_id;
        for u in (select * from FAKT_BANKUMSAETZE
                   where BKUM_ID = p_bkum_id and BKUM_MAND_ID = l_debi.DEBI_MAND_ID
                     and BKUM_RICHTUNG = 'CRDT' and BKUM_STATUS = 'OFFEN') loop
            insert into FAKT_DEBITOR_ZAHLUNGEN (DZAH_DEBI_ID, DZAH_DATUM, DZAH_BETRAG, DZAH_BKUM_ID, DZAH_BEMERKUNG)
            values (p_debi_id, u.BKUM_BUCHUNGSDATUM, u.BKUM_BETRAG, u.BKUM_ID,
                    substr(trim(u.BKUM_GEGEN_NAME || ' ' || u.BKUM_VERWENDUNGSZWECK), 1, 500));
            update FAKT_BANKUMSAETZE
               set BKUM_STATUS = 'DEBITOR', BKUM_DEBI_ID = p_debi_id, BKUM_RECH_ID = null,
                   BKUM_ZUORDNUNG = substr(p_art || ': ' || l_debi.DEBI_NAME, 1, 200)
             where BKUM_ID = u.BKUM_ID;
            -- IBAN des Zahlers merken (naechste Zahlung wird automatisch zugewiesen)
            if l_debi.DEBI_IBAN is null and u.BKUM_GEGEN_IBAN is not null then
                update FAKT_DEBITOREN set DEBI_IBAN = u.BKUM_GEGEN_IBAN where DEBI_ID = p_debi_id;
            end if;
            return;
        end loop;
        raise_application_error(-20280, 'Die Buchung ist kein offener Zahlungseingang dieses Mandanten.');
    end zuweisen;

    procedure aufheben(p_dzah_id in number) is
    begin
        for z in (select * from FAKT_DEBITOR_ZAHLUNGEN where DZAH_ID = p_dzah_id) loop
            update FAKT_BANKUMSAETZE
               set BKUM_STATUS = 'OFFEN', BKUM_DEBI_ID = null, BKUM_ZUORDNUNG = 'Zuweisung zum Debitor aufgehoben'
             where BKUM_ID = z.DZAH_BKUM_ID;
            delete from FAKT_DEBITOR_ZAHLUNGEN where DZAH_ID = z.DZAH_ID;
        end loop;
    end aufheben;

    function aus_buchung(p_bkum_id in number) return number is
        l_debi number;
    begin
        for u in (select * from FAKT_BANKUMSAETZE
                   where BKUM_ID = p_bkum_id and BKUM_RICHTUNG = 'CRDT' and BKUM_STATUS = 'OFFEN') loop
            insert into FAKT_DEBITOREN (DEBI_MAND_ID, DEBI_NAME, DEBI_BEZEICHNUNG, DEBI_BETRAG, DEBI_INTERVALL,
                                        DEBI_FAELLIG_AB, DEBI_IBAN)
            values (u.BKUM_MAND_ID,
                    nvl(substr(trim(regexp_replace(u.BKUM_GEGEN_NAME, ' {2,}', ' ')), 1, 200), 'Unbekannter Zahler'),
                    substr(trim(regexp_replace(u.BKUM_VERWENDUNGSZWECK, ' {2,}', ' ')), 1, 200),
                    u.BKUM_BETRAG, 'MONATLICH', u.BKUM_BUCHUNGSDATUM, u.BKUM_GEGEN_IBAN)
            returning DEBI_ID into l_debi;
            posten_erzeugen(u.BKUM_MAND_ID, l_debi);
            zuweisen(u.BKUM_ID, l_debi, 'Debitor aus der Buchung angelegt');
            return l_debi;
        end loop;
        raise_application_error(-20280, 'Die Buchung ist kein offener Zahlungseingang.');
    end aus_buchung;

    function name_passt(p_name in varchar2, p_auftraggeber in varchar2) return varchar2 deterministic is
        l_name varchar2(400) := ' ' || trim(regexp_replace(upper(p_name), '[^[:alnum:]]+', ' ')) || ' ';
        l_auft varchar2(400) := ' ' || trim(regexp_replace(upper(p_auftraggeber), '[^[:alnum:]]+', ' ')) || ' ';
        l_teil varchar2(200);
        l_anz  pls_integer := 0;
    begin
        if p_name is null or p_auftraggeber is null then
            return 'N';
        end if;
        if utl_match.jaro_winkler_similarity(trim(l_name), trim(l_auft)) >= 92 then
            return 'Y';
        end if;
        -- jeder Namensteil ab 3 Zeichen muss im Auftraggeber vorkommen ("Christa Rossegger" = "Rossegger  Christa")
        for i in 1 .. 10 loop
            l_teil := regexp_substr(trim(l_name), '[^ ]+', 1, i);
            exit when l_teil is null;
            if length(l_teil) >= 3 then
                if instr(l_auft, ' ' || l_teil || ' ') = 0 then
                    return 'N';
                end if;
                l_anz := l_anz + 1;
            end if;
        end loop;
        return case when l_anz > 0 then 'Y' else 'N' end;
    end name_passt;

    function abgleichen(p_mand_id in number) return pls_integer is
        l_anz  pls_integer;
        l_debi number;
        l_art  varchar2(100);
        l_zug  pls_integer := 0;
    begin
        posten_erzeugen(p_mand_id);
        for u in (select * from FAKT_BANKUMSAETZE
                   where BKUM_MAND_ID = p_mand_id and BKUM_STATUS = 'OFFEN' and BKUM_RICHTUNG = 'CRDT'
                     and BKUM_RECH_ID is null and BKUM_GUTS_ID is null
                   order by BKUM_BUCHUNGSDATUM, BKUM_ID) loop
            -- 1. IBAN des Zahlers
            select count(*), max(DEBI_ID) into l_anz, l_debi
              from FAKT_DEBITOREN
             where DEBI_MAND_ID = p_mand_id and DEBI_IST_AKTIV = 'Y'
               and DEBI_IBAN = replace(upper(u.BKUM_GEGEN_IBAN), ' ');
            l_art := 'IBAN des Zahlers';
            -- 2. Name des Debitors passt zum Auftraggeber (eindeutig)
            if l_anz <> 1 then
                select count(*), max(DEBI_ID) into l_anz, l_debi
                  from FAKT_DEBITOREN
                 where DEBI_MAND_ID = p_mand_id and DEBI_IST_AKTIV = 'Y'
                   and name_passt(DEBI_NAME, u.BKUM_GEGEN_NAME) = 'Y';
                l_art := 'Name des Zahlers';
            end if;
            if l_anz = 1 then
                zuweisen(u.BKUM_ID, l_debi, l_art);
                l_zug := l_zug + 1;
            end if;
        end loop;
        return l_zug;
    end abgleichen;

    function intervall_text(p_intervall in varchar2) return varchar2 deterministic is
    begin
        return case p_intervall when 'EINMALIG' then 'Einmalig' when 'MONATLICH' then 'Monatlich'
                                when 'QUARTAL' then 'Vierteljährlich' when 'HALBJAEHRLICH' then 'Halbjährlich'
                                when 'JAEHRLICH' then 'Jährlich' else p_intervall end;
    end intervall_text;

    function status_text(p_status in varchar2) return varchar2 deterministic is
    begin
        return case p_status when 'BEZAHLT' then 'Bezahlt' when 'TEILBEZAHLT' then 'Teilweise bezahlt'
                             when 'OFFEN' then 'Offen' else initcap(p_status) end;
    end status_text;

end FAKT_DEBITOR;
/

show errors package body FAKT_DEBITOR

-- FAKT_BANK.abgleichen ruft FAKT_DEBITOR.abgleichen auf (Skript 39) – bei einer Neuinstallation hier neu uebersetzen
alter package FAKT_BANK compile body;

prompt Debitoren installiert.
