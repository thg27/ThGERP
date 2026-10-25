-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 40 – Erhaltene Gutschriften (Gutschriftverfahren, z.B. Hays; Tabelle FAKT_GUTSCHRIFTEN in Skript 39):
--      Package FAKT_GUTSCHRIFT: aus_pdf (PDF -> Text mit DBMS_VECTOR_CHAIN.UTL_TO_TEXT, Felder per Muster auslesen und
--      Gutschrift anlegen bzw. leere Felder ergaenzen).
-- Voraussetzung: 39
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

create or replace package FAKT_GUTSCHRIFT as
    -- PDF einer Gutschrift einlesen: Text auslesen (DBMS_VECTOR_CHAIN.UTL_TO_TEXT) und Aussteller/Kunde, Nummer
    -- (Belegnummer), Datum, faellig am ("voraussichtlich am"), Betrag (Bruttobetrag), Skonto %, Verwendungszweck
    -- (/GSV/<Belegnummer>/<Vertragsnummer>) per Muster ermitteln. p_guts_id leer: neue Gutschrift anlegen; sonst PDF ersetzen und
    -- nur leere Felder ergaenzen. Liefert die ID der Gutschrift.
    function aus_pdf(p_mand_id in number, p_dateiname in varchar2, p_mime_type in varchar2, p_datei in blob,
                     p_guts_id in number default null) return number;
    function status_text(p_status in varchar2) return varchar2 deterministic;
    -- Dateiname des PDF (PDF-Fenster Seite 43)
    function dateiname(p_guts_id in number) return varchar2;
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
        -- Skonto, das der Aussteller abzieht ("unter Abzug von 3% Skonto")
        l_skonto := to_number(replace(regexp_substr(regexp_substr(l_text, '[0-9]+([.,][0-9]+)? ?% ?Skonto', 1, 1, 'i'),
                                                    '[0-9]+([.,][0-9]+)?'), ',', '.'),
                              '990D99', 'NLS_NUMERIC_CHARACTERS=''.,''');
        -- Verwendungszweck: wie im PDF bzw. wie im Gutschriftverfahren am Kontoauszug (/GSV/<Belegnummer>/<Vertragsnummer>)
        l_vertrag := regexp_substr(regexp_substr(l_text, 'Vertragsnummer:? ?[A-Z0-9]{4,}', 1, 1, 'i'), '[A-Z0-9]{4,}$');
        l_zweck := substr(coalesce(regexp_substr(l_text, '/GSV/[^ ]+'),
                                   case when l_nummer is not null and l_vertrag is not null
                                        then '/GSV/' || l_nummer || '/' || l_vertrag end), 1, 140);

        if l_id is null then
            -- schon vorhanden? gleiche Datei (Inhalt) bzw. gleiche Gutschriftnummer desselben Ausstellers -> nur Hinweis
            for g in (select GUTS_NUMMER, GUTS_AUSSTELLER,
                             to_char(from_tz(GUTS_CREATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') as AM
                        from FAKT_GUTSCHRIFTEN
                       where GUTS_MAND_ID = p_mand_id
                         and ((l_nummer is not null and GUTS_NUMMER = substr(l_nummer, 1, 50)
                               and (GUTS_KUND_ID = l_kund or l_kund is null or GUTS_KUND_ID is null))
                              or (dbms_lob.getlength(GUTS_DATEI) = dbms_lob.getlength(p_datei)
                                  and dbms_lob.compare(GUTS_DATEI, p_datei) = 0))
                       fetch first 1 rows only) loop
                raise_application_error(-20271, 'Die Gutschrift ' || nvl(g.GUTS_NUMMER, '(ohne Nummer)')
                                                || nvl2(g.GUTS_AUSSTELLER, ' von ' || g.GUTS_AUSSTELLER, null)
                                                || ' ist bereits vorhanden (hochgeladen am ' || g.AM || ') – es wurde nichts angelegt.');
            end loop;
            insert into FAKT_GUTSCHRIFTEN (GUTS_MAND_ID, GUTS_KUND_ID, GUTS_AUSSTELLER, GUTS_NUMMER, GUTS_DATUM, GUTS_FAELLIG_AM,
                                           GUTS_BETRAG, GUTS_SKONTO_PROZENT, GUTS_VERWENDUNGSZWECK, GUTS_DATEINAME, GUTS_MIME_TYPE,
                                           GUTS_DATEI, GUTS_TEXT)
            values (p_mand_id, l_kund, substr(l_ausst, 1, 200), substr(l_nummer, 1, 50), l_datum, l_faellig, l_betrag, l_skonto,
                    l_zweck, p_dateiname, p_mime_type, p_datei, l_clob)
            returning GUTS_ID into l_id;
        else
            update FAKT_GUTSCHRIFTEN
               set GUTS_DATEINAME = p_dateiname, GUTS_MIME_TYPE = p_mime_type, GUTS_DATEI = p_datei, GUTS_TEXT = l_clob,
                   GUTS_KUND_ID = coalesce(GUTS_KUND_ID, l_kund),
                   GUTS_AUSSTELLER = coalesce(GUTS_AUSSTELLER, substr(l_ausst, 1, 200)),
                   GUTS_NUMMER = coalesce(GUTS_NUMMER, substr(l_nummer, 1, 50)),
                   GUTS_DATUM = coalesce(GUTS_DATUM, l_datum),
                   GUTS_FAELLIG_AM = coalesce(GUTS_FAELLIG_AM, l_faellig),
                   GUTS_BETRAG = coalesce(GUTS_BETRAG, l_betrag),
                   GUTS_SKONTO_PROZENT = coalesce(GUTS_SKONTO_PROZENT, l_skonto),
                   GUTS_VERWENDUNGSZWECK = coalesce(GUTS_VERWENDUNGSZWECK, l_zweck)
             where GUTS_ID = l_id and GUTS_MAND_ID = p_mand_id;
        end if;
        return l_id;
    end aus_pdf;

    function status_text(p_status in varchar2) return varchar2 deterministic is
    begin
        return case p_status when 'OFFEN' then 'Offen' when 'BEZAHLT' then 'Bezahlt' else initcap(p_status) end;
    end status_text;

    function dateiname(p_guts_id in number) return varchar2 is
        l_name FAKT_GUTSCHRIFTEN.GUTS_DATEINAME%type;
    begin
        select max(GUTS_DATEINAME) into l_name from FAKT_GUTSCHRIFTEN where GUTS_ID = p_guts_id;
        return l_name;
    end dateiname;

end FAKT_GUTSCHRIFT;
/

show errors package body FAKT_GUTSCHRIFT


prompt Gutschriften installiert.
