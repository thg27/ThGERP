-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 21 – Logik und Sichten der Fakturierung:
--      Package FAKT_RECHNUNG (Empfaenger uebernehmen, Summen der Haupt-/Unterpositionen, Positionsnummer, Abschliessen mit
--      Nummernkreis, Zahlungsstatus, Loeschen nur Entwurf bzw. letzte Rechnung, Rechnung kopieren)
--      Views FAKT_RECHNUNGEN_V (Liste mit offenem Betrag), FAKT_RECHNUNG_MWST_V (Summen je Steuersatz)
--      Grunddaten: Mitarbeiter Thomas Gesslbauer (Login ADMIN_THG), Textvorlagen aus Kingbill, Portal-Kachel
-- Voraussetzung: 17–20
-- Erzeugt: 2026-09-26
-- Wiederholbar (create or replace; Grunddaten nur fehlende Zeilen).
-- =====================================================================

set define off
set serveroutput on size unlimited

-- Summen je Steuersatz (Grundlage fuer Rechnungsfuss und FAKT_RECHNUNG.summen_berechnen)
-- In die Rechnungssumme zaehlen die nicht optionalen Hauptpositionen mit ihrer Summe (RPOS_SUMME):
--   * Hauptposition ohne Unterpositionen: ihre Summe mit ihrem Steuersatz
--   * Hauptposition mit Unterpositionen: Rabatt bzw. Pauschalsumme der Hauptposition werden anteilig auf die
--     Steuersaetze der nicht optionalen Unterpositionen verteilt (Faktor = Summe Hauptposition / Summe Unterpositionen);
--     ergeben die Unterpositionen 0, zaehlt die Summe (Pauschale) mit dem Steuersatz der Hauptposition
create or replace view FAKT_RECHNUNG_MWST_V as
select r.RECH_ID,
       case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.MWST_PROZENT end as MWST_PROZENT,
       round(sum(case r.RECH_IST_BRUTTO
                     when 'Y' then p.BETRAG / (1 + case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.MWST_PROZENT end / 100)
                     else p.BETRAG end), 2) as NETTO,
       round(sum(case r.RECH_IST_BRUTTO
                     when 'Y' then p.BETRAG / (1 + case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.MWST_PROZENT end / 100)
                     else p.BETRAG end)
             * case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.MWST_PROZENT end / 100, 2) as MWST
  from FAKT_RECHNUNGEN r
  join (select h.RPOS_RECH_ID, h.RPOS_MWST_PROZENT as MWST_PROZENT, h.RPOS_SUMME as BETRAG
          from FAKT_RECHNUNGSPOSITIONEN h
         where h.RPOS_HAUPT_RPOS_ID is null
           and h.RPOS_IST_OPTIONAL = 'N'
           and nvl(h.RPOS_SUMME_UNTERPOS, 0) = 0
        union all
        select u.RPOS_RECH_ID, u.RPOS_MWST_PROZENT, u.RPOS_SUMME * h.RPOS_SUMME / h.RPOS_SUMME_UNTERPOS
          from FAKT_RECHNUNGSPOSITIONEN u
          join FAKT_RECHNUNGSPOSITIONEN h on h.RPOS_ID = u.RPOS_HAUPT_RPOS_ID
         where u.RPOS_IST_OPTIONAL = 'N'
           and h.RPOS_IST_OPTIONAL = 'N'
           and h.RPOS_SUMME_UNTERPOS <> 0) p on p.RPOS_RECH_ID = r.RECH_ID
 group by r.RECH_ID, case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.MWST_PROZENT end, r.RECH_IST_BRUTTO, r.RECH_IST_OHNE_MWST;

-- Rechnungsliste mit Kunde, Mandant, bezahltem und offenem Betrag
create or replace view FAKT_RECHNUNGEN_V as
select r.RECH_ID,
       r.RECH_MAND_ID,
       m.MAND_CODE,
       m.MAND_KURZNAME,
       r.RECH_NUMMER,
       r.RECH_STATUS,
       r.RECH_DATUM,
       r.RECH_FAELLIG_AM,
       r.RECH_BETREFF,
       r.RECH_LEISTUNGSZEITRAUM,
       r.RECH_KUND_ID,
       k.KUND_NUMMER,
       coalesce(k.KUND_FIRMENNAME, trim(k.KUND_NACHNAME || ' ' || k.KUND_VORNAME)) as KUNDE,
       r.RECH_SUMME_NETTO,
       r.RECH_SUMME_MWST,
       r.RECH_SUMME_BRUTTO,
       nvl(z.BEZAHLT, 0) as BEZAHLT,
       case when r.RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT') then r.RECH_SUMME_BRUTTO - nvl(z.BEZAHLT, 0) end as OFFEN,
       case when r.RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT') and r.RECH_FAELLIG_AM < trunc(cast(systimestamp at time zone 'Europe/Vienna' as date)) then 'Y' else 'N' end as IST_UEBERFAELLIG,
       r.RECH_UPDATED_ON,
       r.RECH_UPDATED_BY
  from FAKT_RECHNUNGEN r
  join ADMIN_MANDANTEN m on m.MAND_ID = r.RECH_MAND_ID
  join KUND_KUNDEN k on k.KUND_ID = r.RECH_KUND_ID
  left join (select ZAHL_RECH_ID, sum(ZAHL_BETRAG) as BEZAHLT
               from FAKT_ZAHLUNGEN group by ZAHL_RECH_ID) z on z.ZAHL_RECH_ID = r.RECH_ID;

comment on table FAKT_RECHNUNG_MWST_V is 'Rechnungssummen je Steuersatz (netto, MwSt.) aus den Hauptpositionen, Rabatt/Pauschale anteilig je Steuersatz, ohne optionale Positionen';
comment on table FAKT_RECHNUNGEN_V is 'Rechnungen mit Kunde, Mandant, bezahltem und offenem Betrag, ueberfaellig';

create or replace package FAKT_RECHNUNG as
    -- Empfaengerdaten eines Kunden: Rechnungsadresse = Standort mit Kennzeichen Rechnungsadresse, sonst Hauptsitz;
    -- Kontaktperson = Hauptkontakt des Standorts, sonst erster Ansprechpartner
    type t_empfaenger is record (
        ksto_id       KUND_STANDORTE.KSTO_ID%type,
        ansp_id       KUND_ANSPRECHPARTNER.ANSP_ID%type,
        anrede        FAKT_RECHNUNGEN.RECH_EMPF_ANREDE%type,
        name          FAKT_RECHNUNGEN.RECH_EMPF_NAME%type,
        kontaktperson FAKT_RECHNUNGEN.RECH_EMPF_KONTAKTPERSON%type,
        uid_nummer    FAKT_RECHNUNGEN.RECH_EMPF_UID_NUMMER%type,
        strasse       FAKT_RECHNUNGEN.RECH_EMPF_STRASSE%type,
        plz           FAKT_RECHNUNGEN.RECH_EMPF_PLZ%type,
        ort           FAKT_RECHNUNGEN.RECH_EMPF_ORT%type,
        land_code     FAKT_RECHNUNGEN.RECH_EMPF_LAND_CODE%type,
        zbed_id       FAKT_RECHNUNGEN.RECH_ZBED_ID%type);
    -- Empfaengerdaten des Kunden ermitteln (Rechnungsmaske: sofort bei Auswahl des Kunden anzeigen)
    function empfaenger(p_kund_id in number) return t_empfaenger;
    -- Empfaengerdaten vom Kunden in die Rechnung kopieren (Zahlungsbedingung nur, wenn leer);
    -- p_nur_verweise: nur Standort und Ansprechpartner setzen (Texte wurden in der Maske schon uebernommen/geaendert)
    procedure empfaenger_uebernehmen(p_rech_id in number, p_nur_verweise in boolean default false);
    -- Summen neu berechnen: je Hauptposition die Summe ihrer nicht optionalen Unterpositionen (daraus im Trigger
    -- RPOS_BIU die Zwischensumme abzgl. Rabatt bzw. die Pauschalsumme), dann netto / MwSt. / brutto der Rechnung
    -- (ohne optionale Positionen). Nach jeder Aenderung an Positionen aufrufen.
    procedure summen_berechnen(p_rech_id in number);
    -- naechste Positionsnummer: Hauptpositionen (p_haupt_rpos_id leer) 1, 2, 3 …; Unterpositionen einer
    -- Hauptposition 10, 20, 30 …; p_rpos_id: diese Position nicht mitzaehlen (bestehende Position wird verschoben)
    function naechste_position(p_rech_id in number, p_haupt_rpos_id in number default null,
                               p_rpos_id in number default null) return number;
    -- naechste Belegnummer aus FAKT_NUMMERNKREISE (legt den Nummernkreis des Jahres bei Bedarf an)
    function naechste_nummer(p_mand_id in number, p_belegart in varchar2, p_jahr in number) return varchar2;
    -- Entwurf abschliessen: Rechnungsdatum = heute, Nummer vergeben (Jahr des Rechnungsdatums), Status GEDRUCKT,
    -- Betreff/Faelligkeit vorbelegen
    procedure abschliessen(p_rech_id in number);
    -- Status aus den Zahlungen ableiten: keine Zahlung GEDRUCKT bzw. GESENDET (bleibt), teilweise TEILBEZAHLT,
    -- vollstaendig BEZAHLT
    procedure zahlungsstatus(p_rech_id in number);
    -- Y = Rechnung hat die zuletzt vergebene Nummer ihres Nummernkreises (darf geloescht werden)
    function ist_letzte(p_rech_id in number) return varchar2;
    -- Entwurf oder letzte Rechnung loeschen (inkl. Positionen, Zahlungen); letzte Nummer wird wieder frei
    procedure loeschen(p_rech_id in number);
    -- Rechnung 1:1 als neuen Entwurf kopieren (gleicher Mandant, Kunde, Empfaenger, Texte, Kennzeichen, alle Haupt- und
    -- Unterpositionen); nicht uebernommen: Nummer, Datum, Faelligkeit, Betreff, Zahlungen, Altsystem-ID.
    -- Liefert die ID der neuen Rechnung.
    function kopieren(p_rech_id in number) return number;
    -- Position kopieren (Button "Kopieren" in der Rechnungsuebersicht): Hauptposition mit allen Unterpositionen bzw.
    -- eine Unterposition; die Kopie steht direkt hinter dem Original, die Ebene wird neu nummeriert. Liefert die neue ID.
    function position_kopieren(p_rpos_id in number) return number;
    -- Rechnung stornieren: nur abgeschlossene, offene Rechnungen ohne Zahlung; Grund ist Pflicht. Die Rechnung behaelt
    -- Nummer und Datum, zaehlt nicht mehr zum Umsatz und ist gesperrt; der Grund steht in der Historie.
    procedure stornieren(p_rech_id in number, p_grund in varchar2);
    -- Anzeigetext des Status (ENTWURF -> Entwurf, GEDRUCKT -> Offen – gedruckt, GESENDET -> Offen – gesendet, ...)
    function status_text(p_status in varchar2) return varchar2 deterministic;
    -- Vor-/Schlusstext fuer den Rich-Text-Editor: HTML unveraendert, Klartext (Altdaten, Textvorlagen) maskiert mit
    -- Zeilenumbruechen als <br> – nur fuer die Anzeige; gespeichert wird erst beim naechsten Speichern der Rechnung
    function text_html(p_text in clob) return clob;
    -- Zahlungsreferenz der Rechnung als RF-Referenz (ISO 11649): RF + 2 Pruefziffern + Firma (1 = EDV, 2 = HOLDING) +
    -- Kundennummer + Jahr + laufende Rechnungsnummer (5-stellig), z.B. RF752100221202600203; null ohne Rechnungsnummer
    function zahlungsreferenz(p_rech_id in number) return varchar2;
    -- Anzeige/Druck in Vierergruppen: RF75 2100 2212 0260 0203
    function referenz_anzeige(p_referenz in varchar2) return varchar2 deterministic;
    -- TRUE nur waehrend das Package Nummern vergibt/zuruecksetzt (Trigger sperren manuelle Aenderungen)
    g_intern boolean := false;
end FAKT_RECHNUNG;
/

create or replace package body FAKT_RECHNUNG as

    function empfaenger(p_kund_id in number) return t_empfaenger is
        e t_empfaenger;
    begin
        for r in (select k.KUND_TYP, k.KUND_FIRMENNAME, k.KUND_NAMENSZUSATZ, k.KUND_ANREDE,
                         k.KUND_VORNAME, k.KUND_NACHNAME, k.KUND_UID_NUMMER, k.KUND_ZBED_ID,
                         s.KSTO_ID, a.ADRE_STRASSE, a.ADRE_HAUSNUMMER, a.ADRE_PLZ, a.ADRE_ORT, a.ADRE_LAND_CODE
                    from KUND_KUNDEN k
                    left join lateral (select s.*
                                         from KUND_STANDORTE s
                                        where s.KSTO_KUND_ID = k.KUND_ID
                                        order by case s.KSTO_IST_RECHNUNGSADR when 'Y' then 0 else 1 end,
                                                 case s.KSTO_IST_HAUPTSITZ when 'Y' then 0 else 1 end
                                        fetch first 1 row only) s on 1 = 1
                    left join ALLG_ADRESSEN a on a.ADRE_ID = s.KSTO_ADRE_ID
                   where k.KUND_ID = p_kund_id)
        loop
            e.ksto_id    := r.KSTO_ID;
            e.anrede     := case r.KUND_TYP when 'PRIVAT' then r.KUND_ANREDE end;
            e.name       := case r.KUND_TYP
                                when 'FIRMA' then r.KUND_FIRMENNAME || nvl2(r.KUND_NAMENSZUSATZ, ', ' || r.KUND_NAMENSZUSATZ, null)  -- einzeilig
                                else trim(r.KUND_VORNAME || ' ' || r.KUND_NACHNAME) end;
            e.strasse    := trim(r.ADRE_STRASSE || ' ' || r.ADRE_HAUSNUMMER);
            e.plz        := r.ADRE_PLZ;
            e.ort        := r.ADRE_ORT;
            e.land_code  := r.ADRE_LAND_CODE;
            e.uid_nummer := r.KUND_UID_NUMMER;
            e.zbed_id    := r.KUND_ZBED_ID;
            select max(ANSP_ID) keep (dense_rank first order by case ANSP_IST_HAUPTKONTAKT when 'Y' then 0 else 1 end, ANSP_NACHNAME),
                   max(trim(regexp_replace(ANSP_ANREDE || ' ' || ANSP_TITEL || ' ' || ANSP_VORNAME || ' ' || ANSP_NACHNAME, ' +', ' ')))
                       keep (dense_rank first order by case ANSP_IST_HAUPTKONTAKT when 'Y' then 0 else 1 end, ANSP_NACHNAME)
              into e.ansp_id, e.kontaktperson
              from KUND_ANSPRECHPARTNER
             where ANSP_KSTO_ID = r.KSTO_ID;
        end loop;
        return e;
    end empfaenger;

    procedure empfaenger_uebernehmen(p_rech_id in number, p_nur_verweise in boolean default false) is
        l_kund_id FAKT_RECHNUNGEN.RECH_KUND_ID%type;
        e         t_empfaenger;
    begin
        select RECH_KUND_ID into l_kund_id from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        e := empfaenger(l_kund_id);
        if p_nur_verweise then
            update FAKT_RECHNUNGEN
               set RECH_KSTO_ID = e.ksto_id,
                   RECH_ANSP_ID = e.ansp_id
             where RECH_ID = p_rech_id;
        else
            update FAKT_RECHNUNGEN
               set RECH_KSTO_ID            = e.ksto_id,
                   RECH_ANSP_ID            = e.ansp_id,
                   RECH_EMPF_ANREDE        = e.anrede,
                   RECH_EMPF_NAME          = e.name,
                   RECH_EMPF_KONTAKTPERSON = e.kontaktperson,
                   RECH_EMPF_STRASSE       = e.strasse,
                   RECH_EMPF_PLZ           = e.plz,
                   RECH_EMPF_ORT           = e.ort,
                   RECH_EMPF_LAND_CODE     = e.land_code,
                   RECH_EMPF_UID_NUMMER    = e.uid_nummer,
                   RECH_ZBED_ID            = coalesce(RECH_ZBED_ID, e.zbed_id)
             where RECH_ID = p_rech_id;
        end if;
    end empfaenger_uebernehmen;

    procedure summen_berechnen(p_rech_id in number) is
        l_anz pls_integer;
    begin
        -- nur zwei Ebenen: Unterpositionen haengen an einer Hauptposition derselben Rechnung
        select count(*) into l_anz
          from FAKT_RECHNUNGSPOSITIONEN u
          join FAKT_RECHNUNGSPOSITIONEN h on h.RPOS_ID = u.RPOS_HAUPT_RPOS_ID
         where u.RPOS_RECH_ID = p_rech_id
           and (h.RPOS_RECH_ID <> u.RPOS_RECH_ID or h.RPOS_HAUPT_RPOS_ID is not null);
        if l_anz > 0 then
            raise_application_error(-20213, 'Unterpositionen können nur einer Hauptposition derselben Rechnung zugeordnet werden.');
        end if;
        -- Summe der Unterpositionen je Hauptposition (leer = keine Unterpositionen); nur geaenderte Zeilen,
        -- der Trigger RPOS_BIU rechnet daraus RPOS_SUMME der Hauptposition
        update FAKT_RECHNUNGSPOSITIONEN h
           set RPOS_SUMME_UNTERPOS = (select case when count(*) > 0
                                                  then nvl(sum(case u.RPOS_IST_OPTIONAL when 'N' then u.RPOS_SUMME end), 0) end
                                        from FAKT_RECHNUNGSPOSITIONEN u
                                       where u.RPOS_HAUPT_RPOS_ID = h.RPOS_ID)
         where h.RPOS_RECH_ID = p_rech_id
           and h.RPOS_HAUPT_RPOS_ID is null
           and decode(h.RPOS_SUMME_UNTERPOS,
                      (select case when count(*) > 0
                                   then nvl(sum(case u.RPOS_IST_OPTIONAL when 'N' then u.RPOS_SUMME end), 0) end
                         from FAKT_RECHNUNGSPOSITIONEN u
                        where u.RPOS_HAUPT_RPOS_ID = h.RPOS_ID), 1, 0) = 0;
        update FAKT_RECHNUNGEN rech
           set (RECH_SUMME_NETTO, RECH_SUMME_MWST) =
               (select nvl(sum(m.NETTO), 0), nvl(sum(m.MWST), 0)
                  from FAKT_RECHNUNG_MWST_V m
                 where m.RECH_ID = rech.RECH_ID)
         where RECH_ID = p_rech_id;
        update FAKT_RECHNUNGEN
           set RECH_SUMME_BRUTTO = RECH_SUMME_NETTO + RECH_SUMME_MWST
         where RECH_ID = p_rech_id;
    end summen_berechnen;

    function naechste_position(p_rech_id in number, p_haupt_rpos_id in number default null,
                               p_rpos_id in number default null) return number is
        l_max FAKT_RECHNUNGSPOSITIONEN.RPOS_POSITION%type;
    begin
        select nvl(max(RPOS_POSITION), 0) into l_max
          from FAKT_RECHNUNGSPOSITIONEN
         where RPOS_RECH_ID = p_rech_id
           and (RPOS_HAUPT_RPOS_ID = p_haupt_rpos_id or (RPOS_HAUPT_RPOS_ID is null and p_haupt_rpos_id is null))
           and (p_rpos_id is null or RPOS_ID <> p_rpos_id);
        return case when p_haupt_rpos_id is null then l_max + 1 else trunc(l_max / 10) * 10 + 10 end;
    end naechste_position;

    function naechste_nummer(p_mand_id in number, p_belegart in varchar2, p_jahr in number) return varchar2 is
        l_nkrs FAKT_NUMMERNKREISE%rowtype;
    begin
        -- neuer Nummernkreis: Rechnungen "2026 - 1", Gutschriften "GS 2026 - 1"
        insert into FAKT_NUMMERNKREISE (NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR, NKRS_FORMAT)
        select p_mand_id, p_belegart, p_jahr,
               case p_belegart when 'GUTSCHRIFT' then 'GS {JAHR} - {NR}' else '{JAHR} - {NR}' end from dual
         where not exists (select 1 from FAKT_NUMMERNKREISE
                            where NKRS_MAND_ID = p_mand_id and NKRS_BELEGART = p_belegart and NKRS_JAHR = p_jahr);
        select * into l_nkrs
          from FAKT_NUMMERNKREISE
         where NKRS_MAND_ID = p_mand_id and NKRS_BELEGART = p_belegart and NKRS_JAHR = p_jahr
           for update;
        g_intern := true;
        update FAKT_NUMMERNKREISE
           set NKRS_LETZTE_NUMMER = NKRS_LETZTE_NUMMER + 1
         where NKRS_ID = l_nkrs.NKRS_ID;
        g_intern := false;
        return replace(replace(l_nkrs.NKRS_FORMAT, '{JAHR}', to_char(p_jahr)), '{NR}', to_char(l_nkrs.NKRS_LETZTE_NUMMER + 1));
    end naechste_nummer;

    procedure abschliessen(p_rech_id in number) is
        l_rech FAKT_RECHNUNGEN%rowtype;
        l_anz  pls_integer;
        l_nr   FAKT_RECHNUNGEN.RECH_NUMMER%type;
        -- Rechnungsdatum = Tag des Abschliessens in Oesterreich (Datenbankserver laeuft in UTC)
        l_datum constant date := trunc(cast(systimestamp at time zone 'Europe/Vienna' as date));
        l_ref   FAKT_RECHNUNGEN.RECH_ZAHLUNGSREFERENZ%type;
    begin
        select * into l_rech from FAKT_RECHNUNGEN where RECH_ID = p_rech_id for update;
        if l_rech.RECH_STATUS <> 'ENTWURF' then
            raise_application_error(-20200, 'Nur Entwürfe können abgeschlossen werden.');
        end if;
        select count(*) into l_anz from FAKT_RECHNUNGSPOSITIONEN
         where RPOS_RECH_ID = p_rech_id and RPOS_HAUPT_RPOS_ID is null and RPOS_IST_OPTIONAL = 'N';
        if l_anz = 0 then
            raise_application_error(-20201, 'Die Rechnung hat keine Positionen.');
        end if;
        summen_berechnen(p_rech_id);
        l_nr := naechste_nummer(l_rech.RECH_MAND_ID, 'RECHNUNG', extract(year from l_datum));
        g_intern := true;
        update FAKT_RECHNUNGEN r
           set RECH_NUMMER     = l_nr,
               RECH_DATUM      = l_datum,
               RECH_STATUS     = 'GEDRUCKT',
               RECH_BETREFF    = coalesce(RECH_BETREFF, 'Rechnung ' || l_nr),
               RECH_FAELLIG_AM = coalesce(RECH_FAELLIG_AM,
                                          l_datum + nvl((select ZBED_ZIEL_TAGE from ALLG_ZAHLUNGSBEDINGUNGEN
                                                             where ZBED_ID = r.RECH_ZBED_ID), 14))
         where RECH_ID = p_rech_id;
        -- Zahlungsreferenz aus Firma, Kunde und der eben vergebenen Nummer (erst berechnen, dann setzen – eine Funktion,
        -- die FAKT_RECHNUNGEN liest, ist im UPDATE derselben Tabelle wegen der Trigger nicht erlaubt: ORA-04091)
        l_ref := zahlungsreferenz(p_rech_id);
        update FAKT_RECHNUNGEN set RECH_ZAHLUNGSREFERENZ = l_ref where RECH_ID = p_rech_id;
        g_intern := false;
    exception
        when others then
            g_intern := false;
            raise;
    end abschliessen;

    procedure zahlungsstatus(p_rech_id in number) is
    begin
        update FAKT_RECHNUNGEN r
           set RECH_STATUS = (select case when nvl(sum(ZAHL_BETRAG), 0) >= r.RECH_SUMME_BRUTTO then 'BEZAHLT'
                                          when nvl(sum(ZAHL_BETRAG), 0) > 0 then 'TEILBEZAHLT'
                                          when r.RECH_STATUS = 'GESENDET' then 'GESENDET'
                                          else 'GEDRUCKT' end
                                from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = r.RECH_ID)
         where RECH_ID = p_rech_id
           and RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT');
    end zahlungsstatus;

    function ist_letzte(p_rech_id in number) return varchar2 is
        l_anz pls_integer;
    begin
        select count(*) into l_anz
          from FAKT_RECHNUNGEN r
          join FAKT_NUMMERNKREISE n on n.NKRS_MAND_ID = r.RECH_MAND_ID
                                   and n.NKRS_BELEGART = 'RECHNUNG'
                                   and n.NKRS_JAHR = extract(year from r.RECH_DATUM)
         where r.RECH_ID = p_rech_id
           and r.RECH_NUMMER = replace(replace(n.NKRS_FORMAT, '{JAHR}', to_char(n.NKRS_JAHR)),
                                       '{NR}', to_char(n.NKRS_LETZTE_NUMMER));
        return case when l_anz > 0 then 'Y' else 'N' end;
    end ist_letzte;

    procedure loeschen(p_rech_id in number) is
        l_rech FAKT_RECHNUNGEN%rowtype;
    begin
        select * into l_rech from FAKT_RECHNUNGEN where RECH_ID = p_rech_id for update;
        if l_rech.RECH_STATUS <> 'ENTWURF' and ist_letzte(p_rech_id) = 'N' then
            raise_application_error(-20220, 'Es kann nur die zuletzt vergebene Rechnung ('
                || 'Nummernkreis ' || extract(year from l_rech.RECH_DATUM) || ') gelöscht werden.');
        end if;
        g_intern := true;
        delete from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = p_rech_id;
        delete from FAKT_RECHNUNGSPOSITIONEN where RPOS_RECH_ID = p_rech_id;
        delete from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        -- Historie (Skript 33) mitloeschen; dynamisch, da die Tabelle erst nach diesem Skript angelegt wird
        execute immediate 'delete from FAKT_RECHNUNG_HISTORIE where RHIS_RECH_ID = :1' using p_rech_id;
        if l_rech.RECH_STATUS <> 'ENTWURF' then
            update FAKT_NUMMERNKREISE
               set NKRS_LETZTE_NUMMER = NKRS_LETZTE_NUMMER - 1
             where NKRS_MAND_ID = l_rech.RECH_MAND_ID
               and NKRS_BELEGART = 'RECHNUNG'
               and NKRS_JAHR = extract(year from l_rech.RECH_DATUM);
        end if;
        g_intern := false;
    exception
        when others then
            g_intern := false;
            raise;
    end loeschen;

    procedure stornieren(p_rech_id in number, p_grund in varchar2) is
        l_rech  FAKT_RECHNUNGEN%rowtype;
        l_anz   pls_integer;
    begin
        select * into l_rech from FAKT_RECHNUNGEN where RECH_ID = p_rech_id for update;
        if trim(p_grund) is null then
            raise_application_error(-20240, 'Bitte den Grund für das Storno angeben.');
        end if;
        if l_rech.RECH_STATUS not in ('GEDRUCKT', 'GESENDET') then
            raise_application_error(-20241, 'Nur abgeschlossene, offene Rechnungen können storniert werden (Status '
                                            || l_rech.RECH_STATUS || ').');
        end if;
        select count(*) into l_anz from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = p_rech_id;
        if l_anz > 0 then
            raise_application_error(-20242, 'Zu dieser Rechnung sind Zahlungen erfasst – bitte zuerst die Zahlungen entfernen.');
        end if;
        update FAKT_RECHNUNGEN set RECH_STATUS = 'STORNIERT' where RECH_ID = p_rech_id;
        -- Grund in die Historie (Skript 33; dynamisch, siehe loeschen)
        execute immediate 'begin FAKT_HISTORIE.protokoll(:1, :2, :3); end;' using p_rech_id, 'Stornogrund', trim(p_grund);
    end stornieren;

    function position_kopieren(p_rpos_id in number) return number is
        o     FAKT_RECHNUNGSPOSITIONEN%rowtype;
        l_neu FAKT_RECHNUNGSPOSITIONEN.RPOS_ID%type;
    begin
        select * into o from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = p_rpos_id;
        -- vorlaeufig Nummer -1 (RPOS_UK), danach die Ebene neu nummerieren
        insert into FAKT_RECHNUNGSPOSITIONEN (RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_ARTI_ID, RPOS_POSITION, RPOS_ARTIKELNUMMER,
                                              RPOS_NAME, RPOS_BESCHREIBUNG, RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS,
                                              RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT, RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO,
                                              RPOS_PAUSCHALSUMME)
        values (o.RPOS_RECH_ID, o.RPOS_HAUPT_RPOS_ID, o.RPOS_ARTI_ID, -1, o.RPOS_ARTIKELNUMMER, o.RPOS_NAME,
                o.RPOS_BESCHREIBUNG, o.RPOS_MENGE, o.RPOS_EINHEIT, o.RPOS_EINZELPREIS, o.RPOS_RABATT_PROZENT,
                o.RPOS_MWST_PROZENT, o.RPOS_IST_OPTIONAL, o.RPOS_ERLOESKONTO, o.RPOS_PAUSCHALSUMME)
        returning RPOS_ID into l_neu;
        -- Hauptposition: ihre Unterpositionen mitkopieren (gleiche Nummern 10, 20, 30 … unter der neuen Hauptposition)
        if o.RPOS_HAUPT_RPOS_ID is null then
            insert into FAKT_RECHNUNGSPOSITIONEN (RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_ARTI_ID, RPOS_POSITION,
                                                  RPOS_ARTIKELNUMMER, RPOS_NAME, RPOS_BESCHREIBUNG, RPOS_MENGE,
                                                  RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT,
                                                  RPOS_MWST_PROZENT, RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO,
                                                  RPOS_PAUSCHALSUMME)
            select RPOS_RECH_ID, l_neu, RPOS_ARTI_ID, RPOS_POSITION, RPOS_ARTIKELNUMMER, RPOS_NAME, RPOS_BESCHREIBUNG,
                   RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT,
                   RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO, RPOS_PAUSCHALSUMME
              from FAKT_RECHNUNGSPOSITIONEN
             where RPOS_HAUPT_RPOS_ID = p_rpos_id
             order by RPOS_POSITION;
        end if;
        -- Ebene neu nummerieren: Kopie direkt hinter das Original (Schluessel 2 x Position + 1), Hauptpositionen 1, 2, 3 …,
        -- Unterpositionen 10, 20, 30 …
        update FAKT_RECHNUNGSPOSITIONEN p
           set RPOS_POSITION = (select x.NR
                                  from (select RPOS_ID,
                                               row_number() over (order by case when RPOS_ID = l_neu then o.RPOS_POSITION * 2 + 1
                                                                                else RPOS_POSITION * 2 end, RPOS_ID)
                                               * case when o.RPOS_HAUPT_RPOS_ID is null then 1 else 10 end as NR
                                          from FAKT_RECHNUNGSPOSITIONEN
                                         where RPOS_RECH_ID = o.RPOS_RECH_ID
                                           and (RPOS_HAUPT_RPOS_ID = o.RPOS_HAUPT_RPOS_ID
                                                or (RPOS_HAUPT_RPOS_ID is null and o.RPOS_HAUPT_RPOS_ID is null))) x
                                 where x.RPOS_ID = p.RPOS_ID)
         where p.RPOS_RECH_ID = o.RPOS_RECH_ID
           and (p.RPOS_HAUPT_RPOS_ID = o.RPOS_HAUPT_RPOS_ID or (p.RPOS_HAUPT_RPOS_ID is null and o.RPOS_HAUPT_RPOS_ID is null));
        summen_berechnen(o.RPOS_RECH_ID);
        return l_neu;
    end position_kopieren;

    function kopieren(p_rech_id in number) return number is
        -- ID vorab vergeben (RECH_BIU uebernimmt sie): bei insert … select gibt es kein returning (ORA-03049)
        l_neu   FAKT_RECHNUNGEN.RECH_ID%type := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
        l_haupt FAKT_RECHNUNGSPOSITIONEN.RPOS_ID%type;
        l_herkunft varchar2(100);
    begin
        insert into FAKT_RECHNUNGEN (RECH_ID, RECH_MAND_ID, RECH_KUND_ID, RECH_KSTO_ID, RECH_ANSP_ID, RECH_MITA_ID, RECH_ZBED_ID,
                                     RECH_EMPF_LAND_CODE, RECH_STATUS, RECH_LEISTUNGSZEITRAUM, RECH_LEISTUNG_VON,
                                     RECH_LEISTUNG_BIS, RECH_REFERENZ, RECH_PROJEKT, RECH_IST_BRUTTO, RECH_IST_OHNE_MWST,
                                     RECH_IST_FAELLIGKEIT_ANZEIGEN, RECH_EMPF_ANREDE, RECH_EMPF_NAME,
                                     RECH_EMPF_KONTAKTPERSON, RECH_EMPF_STRASSE, RECH_EMPF_PLZ, RECH_EMPF_ORT,
                                     RECH_EMPF_UID_NUMMER, RECH_LIEFERADRESSE, RECH_ZAHLUNGSBED_TEXT, RECH_VORTEXT,
                                     RECH_SCHLUSSTEXT, RECH_WAEHRUNG)
        select l_neu, RECH_MAND_ID, RECH_KUND_ID, RECH_KSTO_ID, RECH_ANSP_ID, RECH_MITA_ID, RECH_ZBED_ID,
               RECH_EMPF_LAND_CODE, 'ENTWURF', RECH_LEISTUNGSZEITRAUM, RECH_LEISTUNG_VON,
               RECH_LEISTUNG_BIS, RECH_REFERENZ, RECH_PROJEKT, RECH_IST_BRUTTO, RECH_IST_OHNE_MWST,
               RECH_IST_FAELLIGKEIT_ANZEIGEN, RECH_EMPF_ANREDE, RECH_EMPF_NAME,
               RECH_EMPF_KONTAKTPERSON, RECH_EMPF_STRASSE, RECH_EMPF_PLZ, RECH_EMPF_ORT,
               RECH_EMPF_UID_NUMMER, RECH_LIEFERADRESSE, RECH_ZAHLUNGSBED_TEXT, RECH_VORTEXT,
               RECH_SCHLUSSTEXT, RECH_WAEHRUNG
          from FAKT_RECHNUNGEN
         where RECH_ID = p_rech_id;
        if sql%rowcount = 0 then
            raise_application_error(-20210, 'Die Rechnung wurde nicht gefunden.');
        end if;
        -- Hauptpositionen, dann je Hauptposition ihre Unterpositionen (neue Hauptposition als Bezug)
        for h in (select * from FAKT_RECHNUNGSPOSITIONEN
                   where RPOS_RECH_ID = p_rech_id and RPOS_HAUPT_RPOS_ID is null order by RPOS_POSITION) loop
            insert into FAKT_RECHNUNGSPOSITIONEN (RPOS_RECH_ID, RPOS_ARTI_ID, RPOS_POSITION, RPOS_ARTIKELNUMMER, RPOS_NAME,
                                                  RPOS_BESCHREIBUNG, RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS,
                                                  RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT, RPOS_IST_OPTIONAL,
                                                  RPOS_ERLOESKONTO, RPOS_PAUSCHALSUMME)
            values (l_neu, h.RPOS_ARTI_ID, h.RPOS_POSITION, h.RPOS_ARTIKELNUMMER, h.RPOS_NAME, h.RPOS_BESCHREIBUNG,
                    h.RPOS_MENGE, h.RPOS_EINHEIT, h.RPOS_EINZELPREIS, h.RPOS_RABATT_PROZENT, h.RPOS_MWST_PROZENT,
                    h.RPOS_IST_OPTIONAL, h.RPOS_ERLOESKONTO, h.RPOS_PAUSCHALSUMME)
            returning RPOS_ID into l_haupt;
            insert into FAKT_RECHNUNGSPOSITIONEN (RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_ARTI_ID, RPOS_POSITION,
                                                  RPOS_ARTIKELNUMMER, RPOS_NAME, RPOS_BESCHREIBUNG, RPOS_MENGE,
                                                  RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT,
                                                  RPOS_MWST_PROZENT, RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO,
                                                  RPOS_PAUSCHALSUMME)
            select l_neu, l_haupt, RPOS_ARTI_ID, RPOS_POSITION, RPOS_ARTIKELNUMMER, RPOS_NAME, RPOS_BESCHREIBUNG,
                   RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT,
                   RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO, RPOS_PAUSCHALSUMME
              from FAKT_RECHNUNGSPOSITIONEN
             where RPOS_HAUPT_RPOS_ID = h.RPOS_ID;
        end loop;
        summen_berechnen(l_neu);
        -- Herkunft in der Historie der Kopie (Skript 33; dynamisch, siehe loeschen)
        select 'aus Rechnung ' || nvl(RECH_NUMMER, 'Entwurf') into l_herkunft from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        execute immediate 'begin FAKT_HISTORIE.protokoll(:1, :2, :3); end;' using l_neu, 'Kopiert', l_herkunft;
        return l_neu;
    end kopieren;

    function zahlungsreferenz(p_rech_id in number) return varchar2 is
        l_basis varchar2(100);
        l_ziffern varchar2(200);
        l_rest  pls_integer := 0;
    begin
        select case m.MAND_CODE when 'EDV' then '1' when 'HOLDING' then '2' else '9' end
               || regexp_replace(upper(k.KUND_NUMMER), '[^0-9A-Z]')
               || regexp_substr(r.RECH_NUMMER, '^[0-9]{4}')
               || lpad(regexp_substr(r.RECH_NUMMER, '[0-9]+$'), 5, '0')
          into l_basis
          from FAKT_RECHNUNGEN r
          join ADMIN_MANDANTEN m on m.MAND_ID = r.RECH_MAND_ID
          join KUND_KUNDEN k on k.KUND_ID = r.RECH_KUND_ID
         where r.RECH_ID = p_rech_id
           and r.RECH_NUMMER is not null;
        l_basis := substr(l_basis, 1, 21);   -- RF-Referenz: hoechstens 25 Zeichen
        -- Pruefziffern: Basis + "RF00", Buchstaben A=10 … Z=35, Rest modulo 97 (stueckweise), Pruefziffer = 98 - Rest
        for i in 1 .. length(l_basis || 'RF00') loop
            l_ziffern := l_ziffern || case when substr(l_basis || 'RF00', i, 1) between '0' and '9'
                                           then substr(l_basis || 'RF00', i, 1)
                                           else to_char(ascii(substr(l_basis || 'RF00', i, 1)) - 55) end;
        end loop;
        for i in 1 .. length(l_ziffern) loop
            l_rest := mod(l_rest * 10 + to_number(substr(l_ziffern, i, 1)), 97);
        end loop;
        return 'RF' || lpad(98 - l_rest, 2, '0') || l_basis;
    exception
        when no_data_found then
            return null;
    end zahlungsreferenz;

    function referenz_anzeige(p_referenz in varchar2) return varchar2 deterministic is
    begin
        return trim(regexp_replace(replace(p_referenz, ' '), '(.{4})', '\1 '));
    end referenz_anzeige;

    function text_html(p_text in clob) return clob is
    begin
        if p_text is null or regexp_like(dbms_lob.substr(p_text, 50, 1), '^\s*<[a-zA-Z]') then
            return p_text;
        end if;
        return '<p>' || replace(replace(replace(replace(replace(replace(p_text, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'),
                                                chr(13) || chr(10), chr(10)), chr(13), chr(10)), chr(10), '<br>')
               || '</p>';
    end text_html;

    function status_text(p_status in varchar2) return varchar2 deterministic is
    begin
        return case p_status when 'ENTWURF'     then 'Entwurf'
                             when 'GEDRUCKT'    then 'Offen – gedruckt'
                             when 'GESENDET'    then 'Offen – gesendet'
                             when 'TEILBEZAHLT' then 'Teilweise bezahlt'
                             when 'BEZAHLT'     then 'Bezahlt'
                             when 'STORNIERT'   then 'Storniert'
                             else initcap(p_status) end;
    end status_text;

end FAKT_RECHNUNG;
/

-- Grunddaten: nur fehlende Zeilen
insert into ALLG_MITARBEITER (MITA_KUERZEL, MITA_NAME, MITA_BENUTZERNAME, MITA_MAND_ID)
  select 'TG', 'Thomas Geßlbauer', 'ADMIN_THG', (select MAND_ID from ADMIN_MANDANTEN where MAND_CODE = 'EDV')
    from dual where not exists (select 1 from ALLG_MITARBEITER where MITA_KUERZEL = 'TG');

insert into ALLG_TEXTVORLAGEN (TXVL_ART, TXVL_BEZEICHNUNG, TXVL_TEXT, TXVL_IST_STANDARD, TXVL_SORTIERUNG)
  select 'VORTEXT', 'Rechnung', 'Herzlichen Dank für Ihr Vertrauen in unsere Produkte und Dienstleistungen. Wir erlauben uns folgende Beträge in Rechnung zu stellen.', 'Y', 10
    from dual where not exists (select 1 from ALLG_TEXTVORLAGEN where TXVL_ART = 'VORTEXT' and TXVL_BEZEICHNUNG = 'Rechnung');
insert into ALLG_TEXTVORLAGEN (TXVL_ART, TXVL_BEZEICHNUNG, TXVL_TEXT, TXVL_IST_STANDARD, TXVL_SORTIERUNG)
  select 'ZAHLUNGSBED', 'Banküberweisung', null, 'Y', 10
    from dual where not exists (select 1 from ALLG_TEXTVORLAGEN where TXVL_ART = 'ZAHLUNGSBED' and TXVL_BEZEICHNUNG = 'Banküberweisung');
insert into ALLG_TEXTVORLAGEN (TXVL_ART, TXVL_BEZEICHNUNG, TXVL_TEXT, TXVL_IST_STANDARD, TXVL_SORTIERUNG)
  select 'ZAHLUNGSBED', 'Bankeinzug', 'Bitte nicht einzahlen, der Betrag wird in den nächsten Tagen von Ihrem Konto abgebucht.', 'N', 20
    from dual where not exists (select 1 from ALLG_TEXTVORLAGEN where TXVL_ART = 'ZAHLUNGSBED' and TXVL_BEZEICHNUNG = 'Bankeinzug');
insert into ALLG_TEXTVORLAGEN (TXVL_ART, TXVL_BEZEICHNUNG, TXVL_TEXT, TXVL_IST_STANDARD, TXVL_SORTIERUNG)
  select 'ZAHLUNGSBED', 'PayPal', 'Zahlung mit PayPal.', 'N', 30
    from dual where not exists (select 1 from ALLG_TEXTVORLAGEN where TXVL_ART = 'ZAHLUNGSBED' and TXVL_BEZEICHNUNG = 'PayPal');

insert into ADMIN_APPLIKATIONEN (APPL_APEX_APP_ID, APPL_APEX_ALIAS, APPL_BEZEICHNUNG, APPL_BESCHREIBUNG, APPL_ZIELSEITE, APPL_ICON, APPL_SORTIERUNG)
  select 20050, 'THG-FINANZ', 'Finanz', 'Ausgangsrechnungen, Zahlungseingänge, Nummernkreise', 'HOME', 'fa-eur', 40
    from dual where not exists (select 1 from ADMIN_APPLIKATIONEN where APPL_APEX_APP_ID = 20050);
commit;

-- abhaengige Objekte nach dem Neukompilieren des Packages wieder gueltig machen
begin
    for o in (select object_name, object_type from user_objects
               where status <> 'VALID' and object_name in ('RECH_NUMMER_BUD', 'NKRS_NUMMER_BU', 'ZAHL_STATUS_AIUD', 'FAKT_RECHNUNG_PDF', 'RECH_HIST_AIU', 'FAKT_RECHNUNG_DOKUMENT')) loop
        execute immediate 'alter ' || case o.object_type when 'PACKAGE BODY' then 'package' else lower(o.object_type) end
                          || ' ' || o.object_name || ' compile';
    end loop;
end;
/

prompt FAKT_RECHNUNG, FAKT_RECHNUNGEN_V, FAKT_RECHNUNG_MWST_V installiert.
