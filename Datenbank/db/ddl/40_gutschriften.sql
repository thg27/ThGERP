-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 40 – Erhaltene Gutschriften (Gutschriftverfahren, z.B. Hays; Tabelle FAKT_GUTSCHRIFTEN in Skript 39):
--      Package FAKT_GUTSCHRIFT – Ablauf: Gutschrift anlegen (Kunde) -> Stundenzettel hochladen (dokument_ablegen: interne
--      Nummer "GS 2026 - 1" aus dem Nummernkreis GUTSCHRIFT und Gutschriftdatum) -> an den Aussteller senden (gesendet)
--      -> Gutschrift des Ausstellers hochladen (aus_pdf: Text mit DBMS_VECTOR_CHAIN.UTL_TO_TEXT, Nummer beim Aussteller,
--      Datum, faellig am, Netto/Betrag, Skonto, Verwendungszweck) -> Bankabgleich (Skript 39) -> bezahlt.
--      Doppelte Gutschrift (gleiche Datei bzw. gleiche Nummer beim Aussteller) -> nur Hinweis.
--      loeschen: nur ohne interne Nummer oder die zuletzt vergebene (Nummer wird wieder frei).
-- Voraussetzung: 39
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

create or replace package FAKT_GUTSCHRIFT as
    -- PDF einer Gutschrift einlesen: Text auslesen (DBMS_VECTOR_CHAIN.UTL_TO_TEXT) und Aussteller/Kunde, Nummer
    -- (Belegnummer), Datum, faellig am ("voraussichtlich am"), Betrag (Bruttobetrag), Skonto %, Verwendungszweck
    -- (/GSV/<Belegnummer>/<Vertragsnummer>) per Muster ermitteln. p_guts_id leer: neue Gutschrift anlegen (mit interner
    -- Nummer); sonst in die Gutschrift uebernehmen (nur einmal je Gutschrift). Liefert die ID der Gutschrift.
    function aus_pdf(p_mand_id in number, p_dateiname in varchar2, p_mime_type in varchar2, p_datei in blob,
                     p_guts_id in number default null) return number;
    -- Dokument (Stundenzettel u.a.) zur Gutschrift ablegen; vergibt beim ersten Dokument interne Nummer und Datum
    procedure dokument_ablegen(p_guts_id in number, p_art in varchar2, p_dateiname in varchar2, p_mime_type in varchar2,
                               p_datei in blob);
    -- Stundenzettel an den Aussteller gesendet (Entwurf -> Gesendet; spaeter per E-Mail aus der Anwendung)
    procedure gesendet(p_guts_id in number);
    -- Gutschrift loeschen: nur ohne interne Nummer oder die zuletzt vergebene; Bankbuchung wird wieder frei
    procedure loeschen(p_guts_id in number);
    function status_text(p_status in varchar2) return varchar2 deterministic;
    -- Dateiname fuer das PDF-Fenster (Seite 43): Dokument p_gdok_id bzw. Gutschrift des Ausstellers
    function dateiname(p_guts_id in number, p_gdok_id in number default null) return varchar2;
end FAKT_GUTSCHRIFT;
/

create or replace package body FAKT_GUTSCHRIFT as

    c_datum  constant varchar2(60) := '([0-3]?[0-9])\.([01]?[0-9])\.((20)?[0-9]{2})';
    c_betrag constant varchar2(60) := '-?[0-9]{1,3}(\.?[0-9]{3})*,[0-9]{2}';

    -- "1.234,56" -> 1234.56
    function betrag(p_text in varchar2) return number is
    begin
        return to_number(replace(replace(p_text, '.'), ',', '.'), '9999999999990D99', 'NLS_NUMERIC_CHARACTERS=''.,''');
    exception
        when others then
            return null;
    end betrag;

    -- "5.10.26" / "05.10.2026" -> Datum
    function datum(p_text in varchar2) return date is
        l_j varchar2(4) := regexp_replace(p_text, c_datum, '\3');
    begin
        return to_date(lpad(regexp_replace(p_text, c_datum, '\1'), 2, '0') || lpad(regexp_replace(p_text, c_datum, '\2'), 2, '0')
                       || case when length(l_j) = 2 then '20' || l_j else l_j end, 'DDMMYYYY');
    exception
        when others then
            return null;
    end datum;

    -- erster Treffer von p_wert innerhalb von 60 Zeichen nach einer der Beschriftungen (in Reihenfolge)
    function nach_label(p_text in varchar2, p_labels in varchar2, p_wert in varchar2) return varchar2 is
        l_t varchar2(32767);
    begin
        l_t := regexp_substr(p_text, '(' || p_labels || ')[^0-9-]{0,60}' || p_wert, 1, 1, 'i');
        return case when l_t is not null then regexp_substr(l_t, p_wert, 1, 1, 'i') end;
    end nach_label;

    -- interne Nummer und Gutschriftdatum vergeben, falls noch leer
    procedure nummer_vergeben(p_guts_id in number) is
        l_mand  FAKT_GUTSCHRIFTEN.GUTS_MAND_ID%type;
        l_nr    FAKT_GUTSCHRIFTEN.GUTS_INTERN_NUMMER%type;
        l_heute constant date := trunc(cast(systimestamp at time zone 'Europe/Vienna' as date));
    begin
        select GUTS_MAND_ID, GUTS_INTERN_NUMMER into l_mand, l_nr from FAKT_GUTSCHRIFTEN where GUTS_ID = p_guts_id for update;
        if l_nr is null then
            l_nr := FAKT_RECHNUNG.naechste_nummer(l_mand, 'GUTSCHRIFT', extract(year from l_heute));
            update FAKT_GUTSCHRIFTEN set GUTS_INTERN_NUMMER = l_nr, GUTS_DATUM = coalesce(GUTS_DATUM, l_heute)
             where GUTS_ID = p_guts_id;
        end if;
    end nummer_vergeben;

    function aus_pdf(p_mand_id in number, p_dateiname in varchar2, p_mime_type in varchar2, p_datei in blob,
                     p_guts_id in number default null) return number is
        l_clob    clob;
        l_text    varchar2(32767);
        l_eigen   ADMIN_MANDANTEN.MAND_NAME%type;
        l_kund    FAKT_GUTSCHRIFTEN.GUTS_KUND_ID%type;
        l_ausst   FAKT_GUTSCHRIFTEN.GUTS_AUSSTELLER%type;
        l_nummer  FAKT_GUTSCHRIFTEN.GUTS_NUMMER%type;
        l_datum   date;
        l_faellig date;
        l_betrag  number;
        l_netto   number;
        l_zweck   FAKT_GUTSCHRIFTEN.GUTS_VERWENDUNGSZWECK%type;
        l_skonto  number;
        l_vertrag varchar2(50);
        l_tage    pls_integer;
        l_id      FAKT_GUTSCHRIFTEN.GUTS_ID%type := p_guts_id;
        l_anz     pls_integer;
    begin
        begin
            l_clob := dbms_vector_chain.utl_to_text(p_datei);
        exception
            when others then
                l_clob := null;   -- kein lesbarer Text (z.B. eingescanntes Bild): Felder von Hand
        end;
        l_text := regexp_replace(dbms_lob.substr(l_clob, 30000, 1), '[[:space:]]+', ' ');
        select max(MAND_NAME) into l_eigen from ADMIN_MANDANTEN where MAND_ID = p_mand_id;

        -- Aussteller: Kunde, dessen Firmenname im Text vorkommt (eindeutig); sonst erste Firmenbezeichnung, die nicht der
        -- eigene Mandant ist
        select count(*), max(KUND_ID), max(KUND_FIRMENNAME) into l_anz, l_kund, l_ausst
          from KUND_KUNDEN
         where KUND_FIRMENNAME is not null and length(KUND_FIRMENNAME) >= 4
           and instr(upper(l_text), upper(KUND_FIRMENNAME)) > 0;
        if l_anz <> 1 then
            l_kund := null;
            l_ausst := null;
            for i in 1 .. 10 loop
                l_ausst := regexp_substr(l_text, '[A-ZÄÖÜ][[:alnum:]&.-]*( [[:alnum:]&.-]+){0,4} (AG|GmbH|SE|KG|OG|GesmbH|Ltd\.?|Inc\.?)',
                                         1, i);
                exit when l_ausst is null
                          or (upper(l_ausst) not like '%' || upper(l_eigen) || '%' and upper(l_eigen) not like '%' || upper(l_ausst) || '%');
            end loop;
        end if;

        l_nummer := regexp_substr(
                        regexp_substr(l_text, '(Gutschrifts?(nummer|-?nr\.?| nr\.?)|Beleg(nummer|-?nr\.?)|Dokument(nummer|-?nr\.?))[: ]*[A-Z0-9][A-Z0-9/-]{2,}',
                                      1, 1, 'i'),
                        '[A-Z0-9][A-Z0-9/-]{2,}$', 1, 1, 'i');
        -- Datum der Gutschrift beim Aussteller (das interne Gutschriftdatum kommt mit der internen Nummer)
        l_datum := datum(coalesce(nach_label(l_text, 'Gutschriftsdatum|Gutschrift vom|Belegdatum|Datum', c_datum),
                                  regexp_substr(l_text, c_datum)));
        l_faellig := datum(nach_label(l_text, 'voraussichtlich am|fällig am|fällig bis|fällig|zahlbar bis|zahlbar am|Valuta|Auszahlung am|Zahlungsziel', c_datum));
        if l_faellig is null and l_datum is not null then
            l_tage := to_number(regexp_substr(regexp_substr(l_text, 'innerhalb (von )?[0-9]{1,3} Tag', 1, 1, 'i'), '[0-9]+'));
            l_faellig := case when l_tage is not null then l_datum + l_tage end;
        end if;
        l_betrag := betrag(nach_label(l_text, 'Auszahlungsbetrag|Zahlbetrag|Gutschriftsbetrag|Gutschriftbetrag|Endbetrag|'
                                              || 'Gesamtbetrag|Rechnungsbetrag|Summe brutto|Bruttobetrag|Gesamtsumme', c_betrag));
        if l_betrag is null then   -- sonst groesster Betrag im Text
            for i in 1 .. 200 loop
                exit when regexp_substr(l_text, c_betrag, 1, i) is null;
                l_betrag := greatest(nvl(l_betrag, 0), nvl(betrag(regexp_substr(l_text, c_betrag, 1, i)), 0));
            end loop;
        end if;
        l_netto := betrag(nach_label(l_text, 'Nettobetrag|Summe netto|Netto', c_betrag));
        -- Skonto, das der Aussteller abzieht ("unter Abzug von 3% Skonto")
        l_skonto := to_number(replace(regexp_substr(regexp_substr(l_text, '[0-9]+([.,][0-9]+)? ?% ?Skonto', 1, 1, 'i'),
                                                    '[0-9]+([.,][0-9]+)?'), ',', '.'),
                              '990D99', 'NLS_NUMERIC_CHARACTERS=''.,''');
        -- Verwendungszweck: wie im PDF bzw. wie im Gutschriftverfahren am Kontoauszug (/GSV/<Belegnummer>/<Vertragsnummer>)
        l_vertrag := regexp_substr(regexp_substr(l_text, 'Vertragsnummer:? ?[A-Z0-9]{4,}', 1, 1, 'i'), '[A-Z0-9]{4,}$');
        l_zweck := substr(coalesce(regexp_substr(l_text, '/GSV/[^ ]+'),
                                   case when l_nummer is not null and l_vertrag is not null
                                        then '/GSV/' || l_nummer || '/' || l_vertrag end), 1, 140);

        -- schon vorhanden? gleiche Datei (Inhalt) bzw. gleiche Nummer beim selben Aussteller -> nur Hinweis
        for g in (select coalesce(GUTS_INTERN_NUMMER, GUTS_NUMMER) as NR, GUTS_NUMMER, GUTS_AUSSTELLER,
                         to_char(from_tz(GUTS_CREATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') as AM
                    from FAKT_GUTSCHRIFTEN
                   where GUTS_MAND_ID = p_mand_id
                     and GUTS_ID <> nvl(l_id, -1)
                     and ((l_nummer is not null and GUTS_NUMMER = substr(l_nummer, 1, 50)
                           and (GUTS_KUND_ID = l_kund or l_kund is null or GUTS_KUND_ID is null))
                          or (dbms_lob.getlength(GUTS_DATEI) = dbms_lob.getlength(p_datei)
                              and dbms_lob.compare(GUTS_DATEI, p_datei) = 0))
                   fetch first 1 rows only) loop
            raise_application_error(-20271, 'Die Gutschrift ' || nvl(g.GUTS_NUMMER, '(ohne Nummer)')
                                            || nvl2(g.GUTS_AUSSTELLER, ' von ' || g.GUTS_AUSSTELLER, null)
                                            || ' ist bereits vorhanden (' || g.NR || ', hochgeladen am ' || g.AM
                                            || ') – es wurde nichts übernommen.');
        end loop;

        if l_id is null then
            insert into FAKT_GUTSCHRIFTEN (GUTS_MAND_ID, GUTS_KUND_ID, GUTS_AUSSTELLER, GUTS_NUMMER, GUTS_AUSSTELLER_DATUM,
                                           GUTS_FAELLIG_AM, GUTS_NETTO, GUTS_BETRAG, GUTS_SKONTO_PROZENT, GUTS_VERWENDUNGSZWECK,
                                           GUTS_DATEINAME, GUTS_MIME_TYPE, GUTS_DATEI, GUTS_TEXT)
            values (p_mand_id, l_kund, substr(l_ausst, 1, 200), substr(l_nummer, 1, 50), l_datum, l_faellig, l_netto, l_betrag,
                    l_skonto, l_zweck, p_dateiname, p_mime_type, p_datei, l_clob)
            returning GUTS_ID into l_id;
        else
            select count(*) into l_anz from FAKT_GUTSCHRIFTEN
             where GUTS_ID = l_id and GUTS_MAND_ID = p_mand_id and GUTS_DATEI is null;
            if l_anz = 0 then
                raise_application_error(-20272, 'Die Gutschrift des Ausstellers ist bei dieser Gutschrift bereits hochgeladen.');
            end if;
            -- Angaben des Ausstellers uebernehmen (von Hand Erfasstes bleibt)
            update FAKT_GUTSCHRIFTEN
               set GUTS_DATEINAME = p_dateiname, GUTS_MIME_TYPE = p_mime_type, GUTS_DATEI = p_datei, GUTS_TEXT = l_clob,
                   GUTS_KUND_ID = coalesce(GUTS_KUND_ID, l_kund),
                   GUTS_AUSSTELLER = coalesce(GUTS_AUSSTELLER, substr(l_ausst, 1, 200)),
                   GUTS_NUMMER = coalesce(GUTS_NUMMER, substr(l_nummer, 1, 50)),
                   GUTS_AUSSTELLER_DATUM = coalesce(GUTS_AUSSTELLER_DATUM, l_datum),
                   GUTS_FAELLIG_AM = coalesce(GUTS_FAELLIG_AM, l_faellig),
                   GUTS_NETTO = coalesce(GUTS_NETTO, l_netto),
                   GUTS_BETRAG = coalesce(GUTS_BETRAG, l_betrag),
                   GUTS_SKONTO_PROZENT = coalesce(GUTS_SKONTO_PROZENT, l_skonto),
                   GUTS_VERWENDUNGSZWECK = coalesce(GUTS_VERWENDUNGSZWECK, l_zweck)
             where GUTS_ID = l_id;
        end if;
        nummer_vergeben(l_id);
        return l_id;
    end aus_pdf;

    procedure dokument_ablegen(p_guts_id in number, p_art in varchar2, p_dateiname in varchar2, p_mime_type in varchar2,
                               p_datei in blob) is
        l_anz pls_integer;
    begin
        if p_datei is null or dbms_lob.getlength(p_datei) = 0 then
            raise_application_error(-20274, 'Bitte eine Datei auswählen.');
        end if;
        select count(*) into l_anz from FAKT_GUTSCHRIFT_DOKUMENTE
         where GDOK_GUTS_ID = p_guts_id and GDOK_GROESSE = dbms_lob.getlength(p_datei)
           and dbms_lob.compare(GDOK_DATEI, p_datei) = 0;
        if l_anz > 0 then
            raise_application_error(-20275, 'Diese Datei ist bei der Gutschrift bereits abgelegt – es wurde nichts übernommen.');
        end if;
        insert into FAKT_GUTSCHRIFT_DOKUMENTE (GDOK_GUTS_ID, GDOK_ART, GDOK_DATEINAME, GDOK_MIME_TYPE, GDOK_DATEI)
        values (p_guts_id, nvl(p_art, 'STUNDENZETTEL'), p_dateiname, p_mime_type, p_datei);
        nummer_vergeben(p_guts_id);
    end dokument_ablegen;

    procedure gesendet(p_guts_id in number) is
        g FAKT_GUTSCHRIFTEN%rowtype;
    begin
        select * into g from FAKT_GUTSCHRIFTEN where GUTS_ID = p_guts_id for update;
        if g.GUTS_STATUS <> 'ENTWURF' then
            raise_application_error(-20276, 'Nur ein Entwurf kann als gesendet markiert werden.');
        end if;
        if g.GUTS_INTERN_NUMMER is null then
            raise_application_error(-20277, 'Bitte zuerst den Stundenzettel hochladen.');
        end if;
        update FAKT_GUTSCHRIFTEN set GUTS_STATUS = 'GESENDET' where GUTS_ID = p_guts_id;
    end gesendet;

    procedure loeschen(p_guts_id in number) is
        g        FAKT_GUTSCHRIFTEN%rowtype;
        l_nkrs   FAKT_NUMMERNKREISE%rowtype;
        l_letzte varchar2(30);
    begin
        select * into g from FAKT_GUTSCHRIFTEN where GUTS_ID = p_guts_id for update;
        if g.GUTS_INTERN_NUMMER is not null then
            select * into l_nkrs from FAKT_NUMMERNKREISE
             where NKRS_MAND_ID = g.GUTS_MAND_ID and NKRS_BELEGART = 'GUTSCHRIFT'
               and NKRS_JAHR = to_number(regexp_substr(g.GUTS_INTERN_NUMMER, '[0-9]{4}'))
               for update;
            l_letzte := replace(replace(l_nkrs.NKRS_FORMAT, '{JAHR}', to_char(l_nkrs.NKRS_JAHR)), '{NR}', to_char(l_nkrs.NKRS_LETZTE_NUMMER));
            if l_letzte <> g.GUTS_INTERN_NUMMER then
                raise_application_error(-20273, 'Gelöscht werden kann nur ein Entwurf ohne Nummer oder die zuletzt vergebene Gutschrift ('
                                                || l_letzte || ').');
            end if;
            FAKT_RECHNUNG.g_intern := true;
            update FAKT_NUMMERNKREISE set NKRS_LETZTE_NUMMER = NKRS_LETZTE_NUMMER - 1 where NKRS_ID = l_nkrs.NKRS_ID;
            FAKT_RECHNUNG.g_intern := false;
        end if;
        update FAKT_BANKUMSAETZE set BKUM_STATUS = 'OFFEN', BKUM_GUTS_ID = null, BKUM_ZUORDNUNG = null
         where BKUM_GUTS_ID = p_guts_id;
        delete from FAKT_GUTSCHRIFT_DOKUMENTE where GDOK_GUTS_ID = p_guts_id;   -- vor der Historie (Trigger protokolliert)
        execute immediate 'delete from FAKT_GUTSCHRIFT_HISTORIE where GHIS_GUTS_ID = :1' using p_guts_id;   -- Skript 42
        delete from FAKT_GUTSCHRIFTEN where GUTS_ID = p_guts_id;
    exception
        when others then
            FAKT_RECHNUNG.g_intern := false;
            raise;
    end loeschen;

    function status_text(p_status in varchar2) return varchar2 deterministic is
    begin
        return case p_status when 'ENTWURF' then 'Entwurf' when 'GESENDET' then 'Gesendet'
                             when 'OFFEN' then 'Offen' when 'BEZAHLT' then 'Bezahlt' else initcap(p_status) end;
    end status_text;

    function dateiname(p_guts_id in number, p_gdok_id in number default null) return varchar2 is
        l_name varchar2(400);
    begin
        if p_gdok_id is not null then
            select max(GDOK_DATEINAME) into l_name from FAKT_GUTSCHRIFT_DOKUMENTE
             where GDOK_ID = p_gdok_id and GDOK_GUTS_ID = p_guts_id;
        else
            select max(GUTS_DATEINAME) into l_name from FAKT_GUTSCHRIFTEN where GUTS_ID = p_guts_id;
        end if;
        return l_name;
    end dateiname;

end FAKT_GUTSCHRIFT;
/

show errors package body FAKT_GUTSCHRIFT


prompt Gutschriften installiert.
