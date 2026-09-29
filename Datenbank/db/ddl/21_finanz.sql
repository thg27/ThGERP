-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 21 – Logik und Sichten der Fakturierung:
--      Package FAKT_RECHNUNG (Empfaenger uebernehmen, Summen, Abschliessen mit Nummernkreis, Zahlungsstatus,
--      Loeschen nur Entwurf bzw. letzte Rechnung)
--      Views FAKT_RECHNUNGEN_V (Liste mit offenem Betrag), FAKT_RECHNUNG_MWST_V (Summen je Steuersatz)
--      Grunddaten: Mitarbeiter Thomas Gesslbauer (Login ADMIN_THG), Textvorlagen aus Kingbill, Portal-Kachel
-- Voraussetzung: 17–20
-- Erzeugt: 2026-09-26
-- Wiederholbar (create or replace; Grunddaten nur fehlende Zeilen).
-- =====================================================================

set define off
set serveroutput on size unlimited

-- Summen je Steuersatz (Grundlage fuer Rechnungsfuss und FAKT_RECHNUNG.summen_berechnen)
create or replace view FAKT_RECHNUNG_MWST_V as
select r.RECH_ID,
       case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.RPOS_MWST_PROZENT end as MWST_PROZENT,
       round(sum(case r.RECH_IST_BRUTTO
                     when 'Y' then p.RPOS_SUMME / (1 + case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.RPOS_MWST_PROZENT end / 100)
                     else p.RPOS_SUMME end), 2) as NETTO,
       round(sum(case r.RECH_IST_BRUTTO
                     when 'Y' then p.RPOS_SUMME / (1 + case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.RPOS_MWST_PROZENT end / 100)
                     else p.RPOS_SUMME end)
             * case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.RPOS_MWST_PROZENT end / 100, 2) as MWST
  from FAKT_RECHNUNGEN r
  join FAKT_RECHNUNGSPOSITIONEN p on p.RPOS_RECH_ID = r.RECH_ID and p.RPOS_IST_OPTIONAL = 'N'
 group by r.RECH_ID, case r.RECH_IST_OHNE_MWST when 'Y' then 0 else p.RPOS_MWST_PROZENT end, r.RECH_IST_BRUTTO, r.RECH_IST_OHNE_MWST;

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
       case when r.RECH_STATUS in ('OFFEN', 'BEZAHLT') then r.RECH_SUMME_BRUTTO - nvl(z.BEZAHLT, 0) end as OFFEN,
       case when r.RECH_STATUS = 'OFFEN' and r.RECH_FAELLIG_AM < trunc(sysdate) then 'Y' else 'N' end as IST_UEBERFAELLIG,
       r.RECH_UPDATED_ON,
       r.RECH_UPDATED_BY
  from FAKT_RECHNUNGEN r
  join ADMIN_MANDANTEN m on m.MAND_ID = r.RECH_MAND_ID
  join KUND_KUNDEN k on k.KUND_ID = r.RECH_KUND_ID
  left join (select ZAHL_RECH_ID, sum(ZAHL_BETRAG + nvl(ZAHL_SKONTO, 0)) as BEZAHLT
               from FAKT_ZAHLUNGEN group by ZAHL_RECH_ID) z on z.ZAHL_RECH_ID = r.RECH_ID;

comment on table FAKT_RECHNUNG_MWST_V is 'Rechnungssummen je Steuersatz (netto, MwSt.), ohne optionale Positionen';
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
    -- Summen netto / MwSt. / brutto aus den Positionen (ohne optionale) neu berechnen
    procedure summen_berechnen(p_rech_id in number);
    -- naechste Belegnummer aus FAKT_NUMMERNKREISE (legt den Nummernkreis des Jahres bei Bedarf an)
    function naechste_nummer(p_mand_id in number, p_belegart in varchar2, p_jahr in number) return varchar2;
    -- Entwurf abschliessen: Nummer vergeben, Status OFFEN, Betreff/Faelligkeit vorbelegen
    procedure abschliessen(p_rech_id in number);
    -- Status OFFEN/BEZAHLT aus den Zahlungen ableiten
    procedure zahlungsstatus(p_rech_id in number);
    -- Y = Rechnung hat die zuletzt vergebene Nummer ihres Nummernkreises (darf geloescht werden)
    function ist_letzte(p_rech_id in number) return varchar2;
    -- Entwurf oder letzte Rechnung loeschen (inkl. Positionen, Zahlungen); letzte Nummer wird wieder frei
    procedure loeschen(p_rech_id in number);
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
                                when 'FIRMA' then r.KUND_FIRMENNAME || nvl2(r.KUND_NAMENSZUSATZ, chr(10) || r.KUND_NAMENSZUSATZ, null)
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
    begin
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

    function naechste_nummer(p_mand_id in number, p_belegart in varchar2, p_jahr in number) return varchar2 is
        l_nkrs FAKT_NUMMERNKREISE%rowtype;
    begin
        insert into FAKT_NUMMERNKREISE (NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR)
        select p_mand_id, p_belegart, p_jahr from dual
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
    begin
        select * into l_rech from FAKT_RECHNUNGEN where RECH_ID = p_rech_id for update;
        if l_rech.RECH_STATUS <> 'ENTWURF' then
            raise_application_error(-20200, 'Nur Entwürfe können abgeschlossen werden.');
        end if;
        select count(*) into l_anz from FAKT_RECHNUNGSPOSITIONEN
         where RPOS_RECH_ID = p_rech_id and RPOS_IST_OPTIONAL = 'N';
        if l_anz = 0 then
            raise_application_error(-20201, 'Die Rechnung hat keine Positionen.');
        end if;
        summen_berechnen(p_rech_id);
        l_nr := naechste_nummer(l_rech.RECH_MAND_ID, 'RECHNUNG', extract(year from l_rech.RECH_DATUM));
        g_intern := true;
        update FAKT_RECHNUNGEN r
           set RECH_NUMMER     = l_nr,
               RECH_STATUS     = 'OFFEN',
               RECH_BETREFF    = coalesce(RECH_BETREFF, 'Rechnung ' || l_nr),
               RECH_FAELLIG_AM = coalesce(RECH_FAELLIG_AM,
                                          RECH_DATUM + nvl((select ZBED_ZIEL_TAGE from ALLG_ZAHLUNGSBEDINGUNGEN
                                                             where ZBED_ID = r.RECH_ZBED_ID), 14))
         where RECH_ID = p_rech_id;
        g_intern := false;
    exception
        when others then
            g_intern := false;
            raise;
    end abschliessen;

    procedure zahlungsstatus(p_rech_id in number) is
    begin
        update FAKT_RECHNUNGEN r
           set RECH_STATUS = case when (select nvl(sum(ZAHL_BETRAG + nvl(ZAHL_SKONTO, 0)), 0)
                                          from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = r.RECH_ID) >= r.RECH_SUMME_BRUTTO
                                  then 'BEZAHLT' else 'OFFEN' end
         where RECH_ID = p_rech_id
           and RECH_STATUS in ('OFFEN', 'BEZAHLT');
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

prompt FAKT_RECHNUNG, FAKT_RECHNUNGEN_V, FAKT_RECHNUNG_MWST_V installiert.
