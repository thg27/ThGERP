-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 33 – Historie der Rechnung: wer hat wann was an einer Rechnung geaendert (Registerkarte "Historie" auf Seite 11).
--      FAKT_RECHNUNG_HISTORIE (RHIS): je Ereignis Zeitpunkt, Benutzer, Aktion und Details (alter -> neuer Wert).
--      Gefuellt von Triggern auf FAKT_RECHNUNGEN (angelegt, geaendert, abgeschlossen, Status), FAKT_RECHNUNGSPOSITIONEN
--      (Position angelegt/geaendert/geloescht) und FAKT_ZAHLUNGEN (Zahlung erfasst/geaendert/geloescht) sowie vom
--      PDF-Druck (Seite 12: Vorschau bzw. Rechnung gedruckt). Abgeleitete Werte (Summen, Positionsnummern beim
--      Verschieben, Audit-Spalten) werden nicht protokolliert, Texte (CLOB) nur als "geaendert".
--      Ohne Fremdschluessel (Protokoll beim Loeschen der Rechnung waere sonst nicht moeglich); FAKT_RECHNUNG.loeschen
--      loescht die Historie mit.
-- Erzeugt: 2026-10-24
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.tabelle('FAKT_RECHNUNG_HISTORIE', q'~create table FAKT_RECHNUNG_HISTORIE (
  RHIS_ID number not null,
  RHIS_RECH_ID number not null,
  RHIS_ZEITPUNKT timestamp default systimestamp not null,
  RHIS_BENUTZER varchar2(255 char) not null,
  RHIS_AKTION varchar2(100 char) not null,
  RHIS_DETAIL varchar2(4000 char),
  constraint RHIS_PK primary key (RHIS_ID)
)~');
    DDL_UTIL.index_('FAKT_RECHNUNG_HISTORIE', 'RHIS_RECH_I', 'RHIS_RECH_ID, RHIS_ZEITPUNKT');
    DDL_UTIL.trigger_pruefen('RHIS_BI', 'FAKT_RECHNUNG_HISTORIE');
    DDL_UTIL.trigger_pruefen('RECH_HIST_AIU', 'FAKT_RECHNUNGEN');
    DDL_UTIL.trigger_pruefen('RPOS_HIST_AIUD', 'FAKT_RECHNUNGSPOSITIONEN');
    DDL_UTIL.trigger_pruefen('ZAHL_HIST_AIUD', 'FAKT_ZAHLUNGEN');
end;
/

create or replace trigger RHIS_BI
  before insert on FAKT_RECHNUNG_HISTORIE
  for each row
begin
  :new.RHIS_ID        := coalesce(:new.RHIS_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
  :new.RHIS_ZEITPUNKT := coalesce(:new.RHIS_ZEITPUNKT, systimestamp);
  :new.RHIS_BENUTZER  := coalesce(:new.RHIS_BENUTZER, sys_context('APEX$SESSION', 'APP_USER'), user);
end RHIS_BI;
/

comment on table FAKT_RECHNUNG_HISTORIE is 'Historie der Rechnung: Aenderungen an Kopf, Positionen, Zahlungen und Drucke [Alias RHIS]';
comment on column FAKT_RECHNUNG_HISTORIE.RHIS_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_RECHNUNG_HISTORIE.RHIS_RECH_ID is 'Rechnung (ohne FK, siehe Skriptkopf)';
comment on column FAKT_RECHNUNG_HISTORIE.RHIS_ZEITPUNKT is 'Zeitpunkt (Serverzeit UTC)';
comment on column FAKT_RECHNUNG_HISTORIE.RHIS_BENUTZER is 'Benutzer (APEX-Anmeldung bzw. Datenbankbenutzer)';
comment on column FAKT_RECHNUNG_HISTORIE.RHIS_AKTION is 'Ereignis, z.B. Angelegt, Geaendert, Abgeschlossen, Position geaendert, Zahlung erfasst';
comment on column FAKT_RECHNUNG_HISTORIE.RHIS_DETAIL is 'Details: geaenderte Felder mit altem und neuem Wert';

create or replace package FAKT_HISTORIE as
    -- Eintrag in die Historie einer Rechnung (Benutzer/Zeitpunkt automatisch)
    procedure protokoll(p_rech_id in number, p_aktion in varchar2, p_detail in varchar2 default null);
    -- Vergleich fuer die Trigger: "Feld: alt → neu; " wenn sich der Wert geaendert hat, sonst null
    function d(p_feld in varchar2, p_alt in varchar2, p_neu in varchar2) return varchar2;
    function d(p_feld in varchar2, p_alt in number, p_neu in number) return varchar2;
    function d(p_feld in varchar2, p_alt in date, p_neu in date) return varchar2;
    -- Texte (CLOB): nur "Feld geaendert; "
    function d_text(p_feld in varchar2, p_alt in clob, p_neu in clob) return varchar2;
    -- Anzeigenamen fuer Fremdschluessel
    function kunde(p_kund_id in number) return varchar2;
    function mitarbeiter(p_mita_id in number) return varchar2;
    function zahlungsbedingung(p_zbed_id in number) return varchar2;
    function betrag(p_wert in number) return varchar2;
end FAKT_HISTORIE;
/

create or replace package body FAKT_HISTORIE as

    procedure protokoll(p_rech_id in number, p_aktion in varchar2, p_detail in varchar2 default null) is
    begin
        insert into FAKT_RECHNUNG_HISTORIE (RHIS_RECH_ID, RHIS_AKTION, RHIS_DETAIL)
        values (p_rech_id, p_aktion, substr(rtrim(p_detail, '; '), 1, 4000));
    end protokoll;

    function d(p_feld in varchar2, p_alt in varchar2, p_neu in varchar2) return varchar2 is
    begin
        if p_alt = p_neu or (p_alt is null and p_neu is null) then   -- decode ist in PL/SQL nicht erlaubt (PLS-00204)
            return null;
        end if;
        return p_feld || ': ' || nvl(substr(replace(p_alt, chr(10), ' '), 1, 200), '–') || ' → '
               || nvl(substr(replace(p_neu, chr(10), ' '), 1, 200), '–') || '; ';
    end d;

    function d(p_feld in varchar2, p_alt in number, p_neu in number) return varchar2 is
    begin
        -- ohne ueberfluessige Nachkommastellen: 3 statt 3,00; 1.080,5 statt 1.080,50
        return d(p_feld, rtrim(rtrim(to_char(p_alt, 'FM999G999G990D999', 'NLS_NUMERIC_CHARACTERS='',.'''), '0'), ','),
                         rtrim(rtrim(to_char(p_neu, 'FM999G999G990D999', 'NLS_NUMERIC_CHARACTERS='',.'''), '0'), ','));
    end d;

    function d(p_feld in varchar2, p_alt in date, p_neu in date) return varchar2 is
    begin
        return d(p_feld, to_char(p_alt, 'DD.MM.YYYY'), to_char(p_neu, 'DD.MM.YYYY'));
    end d;

    function d_text(p_feld in varchar2, p_alt in clob, p_neu in clob) return varchar2 is
    begin
        if (p_alt is null and p_neu is null)
           or (p_alt is not null and p_neu is not null and dbms_lob.compare(p_alt, p_neu) = 0) then
            return null;
        end if;
        return p_feld || ' geändert; ';
    end d_text;

    function kunde(p_kund_id in number) return varchar2 is
        l_name varchar2(400);
    begin
        select KUND_NUMMER || ' ' || coalesce(KUND_FIRMENNAME, KUND_NACHNAME) into l_name from KUND_KUNDEN where KUND_ID = p_kund_id;
        return l_name;
    exception when no_data_found then return null;
    end kunde;

    function mitarbeiter(p_mita_id in number) return varchar2 is
        l_name varchar2(200);
    begin
        select MITA_NAME into l_name from ALLG_MITARBEITER where MITA_ID = p_mita_id;
        return l_name;
    exception when no_data_found then return null;
    end mitarbeiter;

    function zahlungsbedingung(p_zbed_id in number) return varchar2 is
        l_name varchar2(200);
    begin
        select ZBED_BEZEICHNUNG into l_name from ALLG_ZAHLUNGSBEDINGUNGEN where ZBED_ID = p_zbed_id;
        return l_name;
    exception when no_data_found then return null;
    end zahlungsbedingung;

    function betrag(p_wert in number) return varchar2 is
    begin
        return to_char(p_wert, 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €';
    end betrag;
end FAKT_HISTORIE;
/

-- Rechnungskopf: angelegt, geaendert, abgeschlossen, Status
create or replace trigger RECH_HIST_AIU
  after insert or update on FAKT_RECHNUNGEN
  for each row
declare
  l_det   varchar2(32767);
  l_aktion varchar2(100);
begin
  if inserting then
    FAKT_HISTORIE.protokoll(:new.RECH_ID, 'Angelegt',
        'Status: ' || :new.RECH_STATUS || nvl2(:new.RECH_NUMMER, '; Nummer: ' || :new.RECH_NUMMER, null)
        || '; Kunde: ' || FAKT_HISTORIE.kunde(:new.RECH_KUND_ID));
    return;
  end if;
  l_det := FAKT_HISTORIE.d('Nummer', :old.RECH_NUMMER, :new.RECH_NUMMER)
        || FAKT_HISTORIE.d('Status', :old.RECH_STATUS, :new.RECH_STATUS)
        || FAKT_HISTORIE.d('Rechnungsdatum', :old.RECH_DATUM, :new.RECH_DATUM)
        || FAKT_HISTORIE.d('Fällig am', :old.RECH_FAELLIG_AM, :new.RECH_FAELLIG_AM)
        || FAKT_HISTORIE.d('Kunde', FAKT_HISTORIE.kunde(:old.RECH_KUND_ID), FAKT_HISTORIE.kunde(:new.RECH_KUND_ID))
        || FAKT_HISTORIE.d('Empfänger', :old.RECH_EMPF_NAME, :new.RECH_EMPF_NAME)
        || FAKT_HISTORIE.d('Kontaktperson', :old.RECH_EMPF_KONTAKTPERSON, :new.RECH_EMPF_KONTAKTPERSON)
        || FAKT_HISTORIE.d('Straße', :old.RECH_EMPF_STRASSE, :new.RECH_EMPF_STRASSE)
        || FAKT_HISTORIE.d('PLZ', :old.RECH_EMPF_PLZ, :new.RECH_EMPF_PLZ)
        || FAKT_HISTORIE.d('Ort', :old.RECH_EMPF_ORT, :new.RECH_EMPF_ORT)
        || FAKT_HISTORIE.d('Land', :old.RECH_EMPF_LAND_CODE, :new.RECH_EMPF_LAND_CODE)
        || FAKT_HISTORIE.d('UID-Nr.', :old.RECH_EMPF_UID_NUMMER, :new.RECH_EMPF_UID_NUMMER)
        || FAKT_HISTORIE.d('Lieferadresse', :old.RECH_LIEFERADRESSE, :new.RECH_LIEFERADRESSE)
        || FAKT_HISTORIE.d('Betreff', :old.RECH_BETREFF, :new.RECH_BETREFF)
        || FAKT_HISTORIE.d('Leistungszeitraum', :old.RECH_LEISTUNGSZEITRAUM, :new.RECH_LEISTUNGSZEITRAUM)
        || FAKT_HISTORIE.d('Leistung von', :old.RECH_LEISTUNG_VON, :new.RECH_LEISTUNG_VON)
        || FAKT_HISTORIE.d('Leistung bis', :old.RECH_LEISTUNG_BIS, :new.RECH_LEISTUNG_BIS)
        || FAKT_HISTORIE.d('Referenz', :old.RECH_REFERENZ, :new.RECH_REFERENZ)
        || FAKT_HISTORIE.d('Projekt', :old.RECH_PROJEKT, :new.RECH_PROJEKT)
        || FAKT_HISTORIE.d('Bearbeiter', FAKT_HISTORIE.mitarbeiter(:old.RECH_MITA_ID), FAKT_HISTORIE.mitarbeiter(:new.RECH_MITA_ID))
        || FAKT_HISTORIE.d('Zahlungsbedingung', FAKT_HISTORIE.zahlungsbedingung(:old.RECH_ZBED_ID), FAKT_HISTORIE.zahlungsbedingung(:new.RECH_ZBED_ID))
        || FAKT_HISTORIE.d('Preise brutto', :old.RECH_IST_BRUTTO, :new.RECH_IST_BRUTTO)
        || FAKT_HISTORIE.d('Ohne MwSt.', :old.RECH_IST_OHNE_MWST, :new.RECH_IST_OHNE_MWST)
        || FAKT_HISTORIE.d('Fälligkeit anzeigen', :old.RECH_IST_FAELLIGKEIT_ANZEIGEN, :new.RECH_IST_FAELLIGKEIT_ANZEIGEN)
        || FAKT_HISTORIE.d_text('Vortext', :old.RECH_VORTEXT, :new.RECH_VORTEXT)
        || FAKT_HISTORIE.d_text('Schlusstext', :old.RECH_SCHLUSSTEXT, :new.RECH_SCHLUSSTEXT)
        || FAKT_HISTORIE.d_text('Zahlungsbedingungen (Text)', :old.RECH_ZAHLUNGSBED_TEXT, :new.RECH_ZAHLUNGSBED_TEXT)
        || FAKT_HISTORIE.d('Gesamtbetrag', :old.RECH_SUMME_BRUTTO, :new.RECH_SUMME_BRUTTO);
  if l_det is null then
    return;
  end if;
  l_aktion := case
                when :old.RECH_STATUS = 'ENTWURF' and :new.RECH_STATUS = 'OFFEN' then 'Abgeschlossen'
                when :new.RECH_STATUS = 'STORNIERT' and :old.RECH_STATUS <> 'STORNIERT' then 'Storniert'
                when :old.RECH_STATUS <> :new.RECH_STATUS and :new.RECH_STATUS in ('OFFEN', 'TEILBEZAHLT', 'BEZAHLT')
                     and :old.RECH_STATUS in ('OFFEN', 'TEILBEZAHLT', 'BEZAHLT') then 'Zahlungsstatus'
                else 'Geändert'
              end;
  FAKT_HISTORIE.protokoll(:new.RECH_ID, l_aktion, l_det);
end RECH_HIST_AIU;
/

-- Positionen (Nummernaenderungen beim Verschieben und berechnete Summen werden nicht protokolliert)
create or replace trigger RPOS_HIST_AIUD
  after insert or update or delete on FAKT_RECHNUNGSPOSITIONEN
  for each row
declare
  l_det varchar2(32767);
  function text(p_name varchar2, p_menge number, p_einheit varchar2, p_preis number) return varchar2 is
  begin
    return p_name || ', ' || rtrim(rtrim(to_char(p_menge, 'FM999G999G990D999', 'NLS_NUMERIC_CHARACTERS='',.'''), '0'), ',')
           || nvl2(p_einheit, ' ' || p_einheit, null) || ' à ' || FAKT_HISTORIE.betrag(p_preis);
  end;
begin
  if inserting then
    FAKT_HISTORIE.protokoll(:new.RPOS_RECH_ID,
        case when :new.RPOS_HAUPT_RPOS_ID is null then 'Position angelegt' else 'Unterposition angelegt' end,
        text(:new.RPOS_NAME, :new.RPOS_MENGE, :new.RPOS_EINHEIT, :new.RPOS_EINZELPREIS));
  elsif deleting then
    FAKT_HISTORIE.protokoll(:old.RPOS_RECH_ID,
        case when :old.RPOS_HAUPT_RPOS_ID is null then 'Position gelöscht' else 'Unterposition gelöscht' end,
        text(:old.RPOS_NAME, :old.RPOS_MENGE, :old.RPOS_EINHEIT, :old.RPOS_EINZELPREIS));
  else
    l_det := FAKT_HISTORIE.d('Artikelnummer', :old.RPOS_ARTIKELNUMMER, :new.RPOS_ARTIKELNUMMER)
          || FAKT_HISTORIE.d('Name', :old.RPOS_NAME, :new.RPOS_NAME)
          || FAKT_HISTORIE.d('Menge', :old.RPOS_MENGE, :new.RPOS_MENGE)
          || FAKT_HISTORIE.d('Einheit', :old.RPOS_EINHEIT, :new.RPOS_EINHEIT)
          || FAKT_HISTORIE.d('Einzelpreis', :old.RPOS_EINZELPREIS, :new.RPOS_EINZELPREIS)
          || FAKT_HISTORIE.d('Rabatt %', :old.RPOS_RABATT_PROZENT, :new.RPOS_RABATT_PROZENT)
          || FAKT_HISTORIE.d('MwSt. %', :old.RPOS_MWST_PROZENT, :new.RPOS_MWST_PROZENT)
          || FAKT_HISTORIE.d('Optional', :old.RPOS_IST_OPTIONAL, :new.RPOS_IST_OPTIONAL)
          || FAKT_HISTORIE.d('Pauschalsumme', :old.RPOS_PAUSCHALSUMME, :new.RPOS_PAUSCHALSUMME)
          || FAKT_HISTORIE.d_text('Beschreibung', :old.RPOS_BESCHREIBUNG, :new.RPOS_BESCHREIBUNG)
          || case when not (:old.RPOS_HAUPT_RPOS_ID = :new.RPOS_HAUPT_RPOS_ID
                             or (:old.RPOS_HAUPT_RPOS_ID is null and :new.RPOS_HAUPT_RPOS_ID is null))
                  then 'Position verschoben; ' end;
    if l_det is not null then
      FAKT_HISTORIE.protokoll(:new.RPOS_RECH_ID,
          case when :new.RPOS_HAUPT_RPOS_ID is null then 'Position geändert' else 'Unterposition geändert' end,
          :new.RPOS_NAME || ': ' || l_det);
    end if;
  end if;
end RPOS_HIST_AIUD;
/

-- Zahlungen
create or replace trigger ZAHL_HIST_AIUD
  after insert or update or delete on FAKT_ZAHLUNGEN
  for each row
declare
  l_det varchar2(32767);
begin
  if inserting then
    FAKT_HISTORIE.protokoll(:new.ZAHL_RECH_ID, 'Zahlung erfasst',
        to_char(:new.ZAHL_DATUM, 'DD.MM.YYYY') || ': ' || FAKT_HISTORIE.betrag(:new.ZAHL_BETRAG)
        || case when nvl(:new.ZAHL_SKONTO, 0) <> 0 then ', Skonto ' || FAKT_HISTORIE.betrag(:new.ZAHL_SKONTO) end
        || nvl2(:new.ZAHL_BEMERKUNG, ' (' || :new.ZAHL_BEMERKUNG || ')', null));
  elsif deleting then
    FAKT_HISTORIE.protokoll(:old.ZAHL_RECH_ID, 'Zahlung gelöscht',
        to_char(:old.ZAHL_DATUM, 'DD.MM.YYYY') || ': ' || FAKT_HISTORIE.betrag(:old.ZAHL_BETRAG));
  else
    l_det := FAKT_HISTORIE.d('Datum', :old.ZAHL_DATUM, :new.ZAHL_DATUM)
          || FAKT_HISTORIE.d('Betrag', :old.ZAHL_BETRAG, :new.ZAHL_BETRAG)
          || FAKT_HISTORIE.d('Skonto', :old.ZAHL_SKONTO, :new.ZAHL_SKONTO)
          || FAKT_HISTORIE.d('Mahnspesen', :old.ZAHL_MAHNSPESEN, :new.ZAHL_MAHNSPESEN)
          || FAKT_HISTORIE.d('Bemerkung', :old.ZAHL_BEMERKUNG, :new.ZAHL_BEMERKUNG);
    if l_det is not null then
      FAKT_HISTORIE.protokoll(:new.ZAHL_RECH_ID, 'Zahlung geändert', l_det);
    end if;
  end if;
end ZAHL_HIST_AIUD;
/

-- durch das Neuanlegen der Trigger ungueltig gewordene Objekte neu kompilieren
begin
    for o in (select object_name, object_type from user_objects
               where status <> 'VALID' and object_type in ('VIEW', 'TRIGGER', 'PACKAGE', 'PACKAGE BODY')
                 and object_name not like 'BIN$%') loop
        begin
            execute immediate 'alter ' || case o.object_type when 'PACKAGE BODY' then 'package' else lower(o.object_type) end
                              || ' ' || o.object_name || ' compile' || case o.object_type when 'PACKAGE BODY' then ' body' end;
        exception when others then null;   -- Fehler zeigt die Kontrolle user_objects
        end;
    end loop;
end;
/

prompt Historie der Rechnung installiert.
