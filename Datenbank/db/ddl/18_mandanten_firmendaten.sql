-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 18 – Firmendaten der Mandanten (fuer Briefkopf und Rechnungsfuss):
--      erweitert: ADMIN_MANDANTEN (Adresse, UID, Firmenbuch, Firmensitz)
--      neu: ADMIN_MANDANT_BANKVERBINDUNGEN (MBNK), ADMIN_MANDANT_KOMMUNIKATION (MAKO)
--      Daten aus den Ausgangsrechnungen 2026 (Vorlagen/Ausgangsrechnungen).
-- Erzeugt: 2026-09-26
-- Wiederholbar (nutzt DDL_UTIL aus 11_ddl_util.sql, Daten nur, wenn noch nicht vorhanden).
-- =====================================================================

set define off
set serveroutput on size unlimited

-- ADMIN_MANDANTEN: Firmendaten
begin
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_ADRE_ID', 'number', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_UID_NUMMER', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_FIRMENBUCHNR', 'varchar2(20 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_FIRMENBUCHGERICHT', 'varchar2(100 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANTEN', 'MAND_FIRMENSITZ', 'varchar2(100 char)', 'Y');
    DDL_UTIL.constraint_('ADMIN_MANDANTEN', 'MAND_ADRE_FK', 'R', 'MAND_ADRE_ID references ALLG_ADRESSEN (ADRE_ID)');
    DDL_UTIL.index_('ADMIN_MANDANTEN', 'MAND_ADRE_I', 'MAND_ADRE_ID');
end;
/

-- ADMIN_MANDANT_BANKVERBINDUNGEN (MBNK): Bankverbindungen je Mandant (Rechnungsfuss)
begin
    DDL_UTIL.tabelle('ADMIN_MANDANT_BANKVERBINDUNGEN', q'~create table ADMIN_MANDANT_BANKVERBINDUNGEN (
  MBNK_ID number not null,
  MBNK_MAND_ID number not null,
  MBNK_IBAN varchar2(34 char) not null,
  MBNK_BANK varchar2(100 char) not null,
  MBNK_BIC varchar2(11 char),
  MBNK_IST_BEVORZUGT varchar2(1 char) default 'N' not null,
  MBNK_IST_AKTIV varchar2(1 char) default 'Y' not null,
  MBNK_SORTIERUNG number(5),
  MBNK_CREATED_ON timestamp not null,
  MBNK_CREATED_BY varchar2(255 char) not null,
  MBNK_UPDATED_ON timestamp,
  MBNK_UPDATED_BY varchar2(255 char),
  MBNK_ROW_VERSION number not null,
  constraint MBNK_PK primary key (MBNK_ID)
)~');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_ID', 'number', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_MAND_ID', 'number', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_IBAN', 'varchar2(34 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_BANK', 'varchar2(100 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_BIC', 'varchar2(11 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_IST_BEVORZUGT', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_IST_AKTIV', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_SORTIERUNG', 'number(5)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_PK', 'P', 'MBNK_ID');
    DDL_UTIL.constraint_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_IBAN_UK', 'U', 'MBNK_IBAN');
    DDL_UTIL.constraint_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_IST_BEVORZUGT_CK', 'C', q'~MBNK_IST_BEVORZUGT in ('Y', 'N')~');
    DDL_UTIL.constraint_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_IST_AKTIV_CK', 'C', q'~MBNK_IST_AKTIV in ('Y', 'N')~');
    DDL_UTIL.constraint_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_MAND_FK', 'R', 'MBNK_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.index_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_MAND_I', 'MBNK_MAND_ID');
    -- Hoechstens eine bevorzugte Bankverbindung je Mandant
    DDL_UTIL.index_('ADMIN_MANDANT_BANKVERBINDUNGEN', 'MBNK_BEVORZUGT_UI',
                    q'~case when MBNK_IST_BEVORZUGT = 'Y' then MBNK_MAND_ID end~', true);
    DDL_UTIL.trigger_pruefen('MBNK_BIU', 'ADMIN_MANDANT_BANKVERBINDUNGEN');
end;
/

create or replace trigger MBNK_BIU
  before insert or update on ADMIN_MANDANT_BANKVERBINDUNGEN
  for each row
begin
  if inserting then
    :new.MBNK_ID := coalesce(:new.MBNK_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MBNK_CREATED_ON  := systimestamp;
    :new.MBNK_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MBNK_UPDATED_ON  := null;
    :new.MBNK_UPDATED_BY  := null;
    :new.MBNK_ROW_VERSION := 1;
  elsif updating then
    :new.MBNK_ID          := :old.MBNK_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MBNK_CREATED_ON  := :old.MBNK_CREATED_ON;
    :new.MBNK_CREATED_BY  := :old.MBNK_CREATED_BY;
    :new.MBNK_UPDATED_ON  := systimestamp;
    :new.MBNK_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MBNK_ROW_VERSION := nvl(:old.MBNK_ROW_VERSION, 0) + 1;
  end if;
  -- IBAN ohne Leerzeichen, in Grossbuchstaben speichern
  :new.MBNK_IBAN := upper(replace(:new.MBNK_IBAN, ' '));
  :new.MBNK_BIC  := upper(replace(:new.MBNK_BIC, ' '));
end MBNK_BIU;
/

-- ADMIN_MANDANT_KOMMUNIKATION (MAKO): Kommunikationsdaten je Mandant (Briefkopf)
begin
    DDL_UTIL.tabelle('ADMIN_MANDANT_KOMMUNIKATION', q'~create table ADMIN_MANDANT_KOMMUNIKATION (
  MAKO_ID number not null,
  MAKO_MAND_ID number not null,
  MAKO_KART_ID number not null,
  MAKO_WERT varchar2(255 char) not null,
  MAKO_BEZEICHNUNG varchar2(100 char),
  MAKO_IST_BEVORZUGT varchar2(1 char) default 'N' not null,
  MAKO_CREATED_ON timestamp not null,
  MAKO_CREATED_BY varchar2(255 char) not null,
  MAKO_UPDATED_ON timestamp,
  MAKO_UPDATED_BY varchar2(255 char),
  MAKO_ROW_VERSION number not null,
  constraint MAKO_PK primary key (MAKO_ID)
)~');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_ID', 'number', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_MAND_ID', 'number', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_KART_ID', 'number', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_WERT', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_BEZEICHNUNG', 'varchar2(100 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_IST_BEVORZUGT', 'varchar2(1 char)', 'N', q'~'N'~');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_CREATED_ON', 'timestamp', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_CREATED_BY', 'varchar2(255 char)', 'N');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_UPDATED_ON', 'timestamp', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_UPDATED_BY', 'varchar2(255 char)', 'Y');
    DDL_UTIL.spalte('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_ROW_VERSION', 'number', 'N');
    DDL_UTIL.constraint_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_PK', 'P', 'MAKO_ID');
    DDL_UTIL.constraint_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_IST_BEVORZUGT_CK', 'C', q'~MAKO_IST_BEVORZUGT in ('Y', 'N')~');
    DDL_UTIL.constraint_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_MAND_FK', 'R', 'MAKO_MAND_ID references ADMIN_MANDANTEN (MAND_ID)');
    DDL_UTIL.constraint_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_KART_FK', 'R', 'MAKO_KART_ID references ALLG_KOMMUNIKATIONSARTEN (KART_ID)');
    DDL_UTIL.index_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_MAND_I', 'MAKO_MAND_ID');
    DDL_UTIL.index_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_KART_I', 'MAKO_KART_ID');
    -- Hoechstens ein bevorzugter Eintrag je Mandant und Kommunikationsart
    DDL_UTIL.index_('ADMIN_MANDANT_KOMMUNIKATION', 'MAKO_BEVORZUGT_UI',
                    q'~case when MAKO_IST_BEVORZUGT = 'Y' then MAKO_MAND_ID end, case when MAKO_IST_BEVORZUGT = 'Y' then MAKO_KART_ID end~', true);
    DDL_UTIL.trigger_pruefen('MAKO_BIU', 'ADMIN_MANDANT_KOMMUNIKATION');
end;
/

create or replace trigger MAKO_BIU
  before insert or update on ADMIN_MANDANT_KOMMUNIKATION
  for each row
begin
  if inserting then
    :new.MAKO_ID := coalesce(:new.MAKO_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MAKO_CREATED_ON  := systimestamp;
    :new.MAKO_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MAKO_UPDATED_ON  := null;
    :new.MAKO_UPDATED_BY  := null;
    :new.MAKO_ROW_VERSION := 1;
  elsif updating then
    :new.MAKO_ID          := :old.MAKO_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MAKO_CREATED_ON  := :old.MAKO_CREATED_ON;
    :new.MAKO_CREATED_BY  := :old.MAKO_CREATED_BY;
    :new.MAKO_UPDATED_ON  := systimestamp;
    :new.MAKO_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MAKO_ROW_VERSION := nvl(:old.MAKO_ROW_VERSION, 0) + 1;
  end if;
end MAKO_BIU;
/

comment on column ADMIN_MANDANTEN.MAND_ADRE_ID is 'Firmenadresse (Absender im Briefkopf), FK ALLG_ADRESSEN';
comment on column ADMIN_MANDANTEN.MAND_UID_NUMMER is 'Umsatzsteuer-Identifikationsnummer, z.B. ATU82689645';
comment on column ADMIN_MANDANTEN.MAND_FIRMENBUCHNR is 'Firmenbuchnummer, z.B. FN 665019 w';
comment on column ADMIN_MANDANTEN.MAND_FIRMENBUCHGERICHT is 'Firmenbuchgericht, z.B. LG Leoben';
comment on column ADMIN_MANDANTEN.MAND_FIRMENSITZ is 'Firmensitz laut Firmenbuch';

comment on table ADMIN_MANDANT_BANKVERBINDUNGEN is 'Bankverbindungen der Mandanten (Rechnungsfuss) [Alias MBNK]';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_MAND_ID is 'Mandant (FK ADMIN_MANDANTEN)';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_IBAN is 'IBAN ohne Leerzeichen, eindeutig';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_BANK is 'Name der Bank';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_BIC is 'BIC (optional)';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_IST_BEVORZUGT is 'Y = Hauptbankverbindung (hoechstens eine je Mandant)';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_IST_AKTIV is 'Y = wird auf Rechnungen angedruckt';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_SORTIERUNG is 'Reihenfolge im Rechnungsfuss';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_CREATED_ON is 'Audit: angelegt am';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_CREATED_BY is 'Audit: angelegt von';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ADMIN_MANDANT_BANKVERBINDUNGEN.MBNK_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

comment on table ADMIN_MANDANT_KOMMUNIKATION is 'Kommunikationsdaten der Mandanten (Briefkopf) [Alias MAKO]';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_MAND_ID is 'Mandant (FK ADMIN_MANDANTEN)';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_KART_ID is 'Kommunikationsart (FK ALLG_KOMMUNIKATIONSARTEN)';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_WERT is 'Telefonnummer, E-Mail-Adresse, Website';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_BEZEICHNUNG is 'Zusatz, z.B. Buchhaltung';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_IST_BEVORZUGT is 'Y = wird im Briefkopf verwendet (hoechstens einer je Art)';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_CREATED_ON is 'Audit: angelegt am';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_CREATED_BY is 'Audit: angelegt von';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ADMIN_MANDANT_KOMMUNIKATION.MAKO_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

-- Firmendaten aus den Ausgangsrechnungen 2026: nur setzen bzw. einfuegen, wenn noch nicht vorhanden
declare
    procedure firma(p_code varchar2, p_strasse varchar2, p_hausnr varchar2, p_plz varchar2, p_ort varchar2,
                    p_uid varchar2, p_fn varchar2, p_gericht varchar2, p_sitz varchar2) is
        l_mand ADMIN_MANDANTEN%rowtype;
        l_adre ALLG_ADRESSEN.ADRE_ID%type;
    begin
        select * into l_mand from ADMIN_MANDANTEN where MAND_CODE = p_code;
        if l_mand.MAND_ADRE_ID is null then
            -- Adressregister (AT) noch nicht importiert: Quelle MIGRATION (aus Altsystem/Rechnungen)
            insert into ALLG_ADRESSEN (ADRE_LAND_CODE, ADRE_QUELLE, ADRE_STRASSE, ADRE_HAUSNUMMER, ADRE_PLZ, ADRE_ORT)
            values ('AT', 'MIGRATION', p_strasse, p_hausnr, p_plz, p_ort)
            returning ADRE_ID into l_adre;
        end if;
        update ADMIN_MANDANTEN
           set MAND_ADRE_ID           = coalesce(MAND_ADRE_ID, l_adre),
               MAND_UID_NUMMER        = coalesce(MAND_UID_NUMMER, p_uid),
               MAND_FIRMENBUCHNR      = coalesce(MAND_FIRMENBUCHNR, p_fn),
               MAND_FIRMENBUCHGERICHT = coalesce(MAND_FIRMENBUCHGERICHT, p_gericht),
               MAND_FIRMENSITZ        = coalesce(MAND_FIRMENSITZ, p_sitz)
         where MAND_ID = l_mand.MAND_ID;
    end;

    procedure bank(p_code varchar2, p_bank varchar2, p_iban varchar2, p_bevorzugt varchar2, p_sort number) is
    begin
        insert into ADMIN_MANDANT_BANKVERBINDUNGEN (MBNK_MAND_ID, MBNK_BANK, MBNK_IBAN, MBNK_IST_BEVORZUGT, MBNK_SORTIERUNG)
        select MAND_ID, p_bank, p_iban, p_bevorzugt, p_sort
          from ADMIN_MANDANTEN
         where MAND_CODE = p_code
           and not exists (select 1 from ADMIN_MANDANT_BANKVERBINDUNGEN where MBNK_IBAN = upper(replace(p_iban, ' ')));
    end;

    procedure komm(p_code varchar2, p_kart varchar2, p_wert varchar2) is
    begin
        insert into ADMIN_MANDANT_KOMMUNIKATION (MAKO_MAND_ID, MAKO_KART_ID, MAKO_WERT, MAKO_IST_BEVORZUGT)
        select m.MAND_ID, k.KART_ID, p_wert, 'Y'
          from ADMIN_MANDANTEN m, ALLG_KOMMUNIKATIONSARTEN k
         where m.MAND_CODE = p_code and k.KART_CODE = p_kart
           and not exists (select 1 from ADMIN_MANDANT_KOMMUNIKATION x
                            where x.MAKO_MAND_ID = m.MAND_ID and x.MAKO_KART_ID = k.KART_ID and x.MAKO_WERT = p_wert);
    end;
begin
    firma('EDV', 'Rosengasse', '5', '8650', 'Kindberg',
          'ATU82689645', 'FN 665019 w', 'LG Leoben', 'Kindberg');
    bank('EDV', 'Raiffeisenbank Mürztal eGen', 'AT50 3818 6000 0040 9797', 'Y', 10);
    komm('EDV', 'EMAIL', 'office@thg-edv.com');

    firma('TG', 'Maierleitn', '1', '8661', 'St. Barbara im Mürztal',
          'ATU65026349', 'FN 329125 h', 'LG Leoben', 'St. Barbara im Mürztal');
    bank('TG', 'Raiffeisenbank Mürztal eGen', 'AT39 3818 6000 0803 6329', 'Y', 10);  -- Standard
    bank('TG', 'Steiermärkische Sparkasse', 'AT61 2081 5000 4246 1467', 'N', 20);
    komm('TG', 'EMAIL', 'office@thg-edv.com');
    komm('TG', 'TEL', '+43 (0) 660 466 80 88');
end;
/
commit;

prompt Firmendaten der Mandanten installiert bzw. abgeglichen.
