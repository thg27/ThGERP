-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 42 – Historie der Gutschrift (Registerkarte "Historie" auf Seite 41, Timeline wie bei der Rechnung):
--      FAKT_GUTSCHRIFT_HISTORIE (GHIS): je Ereignis Zeitpunkt, Benutzer, Aktion, Details (alter -> neuer Wert).
--      Trigger GUTS_HIST_AIU: Hochgeladen bzw. Angelegt, Geaendert (Felder), Bezahlt / Zahlung zurueckgenommen, PDF ersetzt.
--      Ohne Fremdschluessel (wie FAKT_RECHNUNG_HISTORIE); beim Loeschen der Gutschrift wird die Historie mitgeloescht (Seite 41).
-- Voraussetzung: 33 (FAKT_HISTORIE), 39/40
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.tabelle('FAKT_GUTSCHRIFT_HISTORIE', q'~create table FAKT_GUTSCHRIFT_HISTORIE (
  GHIS_ID number not null,
  GHIS_GUTS_ID number not null,
  GHIS_ZEITPUNKT timestamp default systimestamp not null,
  GHIS_BENUTZER varchar2(255 char) not null,
  GHIS_AKTION varchar2(100 char) not null,
  GHIS_DETAIL varchar2(4000 char),
  constraint GHIS_PK primary key (GHIS_ID)
)~');
    DDL_UTIL.index_('FAKT_GUTSCHRIFT_HISTORIE', 'GHIS_GUTS_I', 'GHIS_GUTS_ID, GHIS_ZEITPUNKT');
    DDL_UTIL.trigger_pruefen('GHIS_BI', 'FAKT_GUTSCHRIFT_HISTORIE');
    DDL_UTIL.trigger_pruefen('GUTS_HIST_AIU', 'FAKT_GUTSCHRIFTEN');
    DDL_UTIL.trigger_pruefen('GDOK_HIST_AID', 'FAKT_GUTSCHRIFT_DOKUMENTE');
end;
/

create or replace trigger GHIS_BI
  before insert on FAKT_GUTSCHRIFT_HISTORIE
  for each row
begin
  :new.GHIS_ID        := coalesce(:new.GHIS_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
  :new.GHIS_ZEITPUNKT := coalesce(:new.GHIS_ZEITPUNKT, systimestamp);
  :new.GHIS_BENUTZER  := coalesce(:new.GHIS_BENUTZER, sys_context('APEX$SESSION', 'APP_USER'), user);
end GHIS_BI;
/

comment on table FAKT_GUTSCHRIFT_HISTORIE is 'Historie der Gutschrift: Hochladen, Aenderungen, Zahlung [Alias GHIS]';
comment on column FAKT_GUTSCHRIFT_HISTORIE.GHIS_ID is 'Primaerschluessel (SYS_GUID)';
comment on column FAKT_GUTSCHRIFT_HISTORIE.GHIS_GUTS_ID is 'Gutschrift (ohne FK)';
comment on column FAKT_GUTSCHRIFT_HISTORIE.GHIS_ZEITPUNKT is 'Zeitpunkt (Serverzeit UTC)';
comment on column FAKT_GUTSCHRIFT_HISTORIE.GHIS_BENUTZER is 'Benutzer (APEX-Anmeldung bzw. Datenbankbenutzer)';
comment on column FAKT_GUTSCHRIFT_HISTORIE.GHIS_AKTION is 'Ereignis: Angelegt, Stundenzettel hochgeladen, Nummer vergeben, An Aussteller gesendet, Hochgeladen, Gutschrift erhalten, Geaendert, Bezahlt …';
comment on column FAKT_GUTSCHRIFT_HISTORIE.GHIS_DETAIL is 'Details: geaenderte Felder mit altem und neuem Wert';

create or replace trigger GUTS_HIST_AIU
  after insert or update on FAKT_GUTSCHRIFTEN
  for each row
declare
  l_det varchar2(32767);
  procedure protokoll(p_aktion varchar2, p_detail varchar2) is
  begin
    insert into FAKT_GUTSCHRIFT_HISTORIE (GHIS_GUTS_ID, GHIS_AKTION, GHIS_DETAIL)
    values (:new.GUTS_ID, p_aktion, substr(rtrim(p_detail, '; '), 1, 4000));
  end;
begin
  if inserting then
    protokoll(case when :new.GUTS_DATEINAME is not null then 'Hochgeladen' else 'Angelegt' end,
              nvl2(:new.GUTS_DATEINAME, 'Datei: ' || :new.GUTS_DATEINAME || '; ', null)
              || 'Nummer: ' || nvl(:new.GUTS_NUMMER, '–') || '; Aussteller: ' || nvl(:new.GUTS_AUSSTELLER, '–')
              || '; Betrag: ' || nvl(FAKT_HISTORIE.betrag(:new.GUTS_BETRAG), '–'));
    return;
  end if;
  if :old.GUTS_DATEINAME is null and :new.GUTS_DATEINAME is not null then
    protokoll('Hochgeladen', 'Gutschrift des Ausstellers: ' || :new.GUTS_DATEINAME);
  elsif nvl(:old.GUTS_DATEINAME, '-') <> nvl(:new.GUTS_DATEINAME, '-') then
    protokoll('PDF ersetzt', 'Datei: ' || nvl(:old.GUTS_DATEINAME, '–') || ' → ' || :new.GUTS_DATEINAME);
  end if;
  if :old.GUTS_INTERN_NUMMER is null and :new.GUTS_INTERN_NUMMER is not null then
    protokoll('Nummer vergeben', :new.GUTS_INTERN_NUMMER || nvl2(:new.GUTS_DATUM, ' vom ' || to_char(:new.GUTS_DATUM, 'DD.MM.YYYY'), null));
  end if;
  if :old.GUTS_STATUS <> :new.GUTS_STATUS then
    protokoll(case when :new.GUTS_STATUS = 'BEZAHLT' then 'Bezahlt'
                   when :old.GUTS_STATUS = 'BEZAHLT' then 'Zahlung zurückgenommen'
                   when :new.GUTS_STATUS = 'GESENDET' then 'An Aussteller gesendet'
                   when :new.GUTS_STATUS = 'OFFEN' then 'Gutschrift erhalten'
                   else 'Status ' || FAKT_GUTSCHRIFT.status_text(:new.GUTS_STATUS) end,
              case when :new.GUTS_STATUS = 'BEZAHLT' then 'am ' || to_char(:new.GUTS_BEZAHLT_AM, 'DD.MM.YYYY')
                   when :new.GUTS_STATUS = 'OFFEN' and :old.GUTS_STATUS <> 'BEZAHLT' then
                       'Nummer beim Aussteller: ' || nvl(:new.GUTS_NUMMER, '–') || '; Betrag: '
                       || nvl(FAKT_HISTORIE.betrag(:new.GUTS_BETRAG), '–') || '; fällig am '
                       || nvl(to_char(:new.GUTS_FAELLIG_AM, 'DD.MM.YYYY'), '–') end);
  end if;
  l_det := FAKT_HISTORIE.d('Kunde', FAKT_HISTORIE.kunde(:old.GUTS_KUND_ID), FAKT_HISTORIE.kunde(:new.GUTS_KUND_ID))
        || FAKT_HISTORIE.d('Aussteller', :old.GUTS_AUSSTELLER, :new.GUTS_AUSSTELLER)
        || FAKT_HISTORIE.d('Nummer beim Aussteller', :old.GUTS_NUMMER, :new.GUTS_NUMMER)
        || case when :old.GUTS_INTERN_NUMMER is not null then FAKT_HISTORIE.d('Gutschriftdatum', :old.GUTS_DATUM, :new.GUTS_DATUM) end
        || FAKT_HISTORIE.d('Datum beim Aussteller', :old.GUTS_AUSSTELLER_DATUM, :new.GUTS_AUSSTELLER_DATUM)
        || FAKT_HISTORIE.d('Netto', FAKT_HISTORIE.betrag(:old.GUTS_NETTO), FAKT_HISTORIE.betrag(:new.GUTS_NETTO))
        || FAKT_HISTORIE.d('Fällig am', :old.GUTS_FAELLIG_AM, :new.GUTS_FAELLIG_AM)
        || FAKT_HISTORIE.d('Betrag', FAKT_HISTORIE.betrag(:old.GUTS_BETRAG), FAKT_HISTORIE.betrag(:new.GUTS_BETRAG))
        || FAKT_HISTORIE.d('Skonto %', :old.GUTS_SKONTO_PROZENT, :new.GUTS_SKONTO_PROZENT)
        || FAKT_HISTORIE.d('Verwendungszweck', :old.GUTS_VERWENDUNGSZWECK, :new.GUTS_VERWENDUNGSZWECK)
        || FAKT_HISTORIE.d('Bemerkung', :old.GUTS_BEMERKUNG, :new.GUTS_BEMERKUNG)
        || case when :old.GUTS_STATUS = :new.GUTS_STATUS
                then FAKT_HISTORIE.d('Bezahlt am', :old.GUTS_BEZAHLT_AM, :new.GUTS_BEZAHLT_AM) end;
  if l_det is not null then
    protokoll('Geändert', l_det);
  end if;
end GUTS_HIST_AIU;
/

-- Dokumente (Stundenzettel u.a.)
create or replace trigger GDOK_HIST_AID
  after insert or delete on FAKT_GUTSCHRIFT_DOKUMENTE
  for each row
begin
  if inserting then
    insert into FAKT_GUTSCHRIFT_HISTORIE (GHIS_GUTS_ID, GHIS_AKTION, GHIS_DETAIL)
    values (:new.GDOK_GUTS_ID, case :new.GDOK_ART when 'STUNDENZETTEL' then 'Stundenzettel hochgeladen' else 'Dokument hochgeladen' end,
            :new.GDOK_DATEINAME);
  else
    insert into FAKT_GUTSCHRIFT_HISTORIE (GHIS_GUTS_ID, GHIS_AKTION, GHIS_DETAIL)
    values (:old.GDOK_GUTS_ID, 'Dokument gelöscht', :old.GDOK_DATEINAME);
  end if;
end GDOK_HIST_AID;
/

-- vorhandene Gutschriften: Hochladen nachtragen (einmalig, Zeitpunkt/Benutzer der Anlage)
insert into FAKT_GUTSCHRIFT_HISTORIE (GHIS_GUTS_ID, GHIS_ZEITPUNKT, GHIS_BENUTZER, GHIS_AKTION, GHIS_DETAIL)
select g.GUTS_ID, g.GUTS_CREATED_ON, g.GUTS_CREATED_BY,
       case when g.GUTS_DATEINAME is not null then 'Hochgeladen' else 'Angelegt' end,
       nvl2(g.GUTS_DATEINAME, 'Datei: ' || g.GUTS_DATEINAME || '; ', null) || 'Nummer: ' || nvl(g.GUTS_NUMMER, '–')
       || '; Aussteller: ' || nvl(g.GUTS_AUSSTELLER, '–') || '; Betrag: ' || nvl(FAKT_HISTORIE.betrag(g.GUTS_BETRAG), '–')
  from FAKT_GUTSCHRIFTEN g
 where not exists (select 1 from FAKT_GUTSCHRIFT_HISTORIE h where h.GHIS_GUTS_ID = g.GUTS_ID);
insert into FAKT_GUTSCHRIFT_HISTORIE (GHIS_GUTS_ID, GHIS_ZEITPUNKT, GHIS_BENUTZER, GHIS_AKTION, GHIS_DETAIL)
select g.GUTS_ID, g.GUTS_UPDATED_ON, g.GUTS_UPDATED_BY, 'Bezahlt', 'am ' || to_char(g.GUTS_BEZAHLT_AM, 'DD.MM.YYYY') || ' (Bankabgleich)'
  from FAKT_GUTSCHRIFTEN g
 where g.GUTS_STATUS = 'BEZAHLT' and g.GUTS_UPDATED_ON is not null
   and not exists (select 1 from FAKT_GUTSCHRIFT_HISTORIE h where h.GHIS_GUTS_ID = g.GUTS_ID and h.GHIS_AKTION = 'Bezahlt');
commit;

prompt Historie der Gutschrift installiert.
