-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 15 – Kundenstammblatt als PDF
--      * AS_PDF (Anton Scheffer, MIT-Lizenz, v4.0.3) aus Datenbank/db/lib/as_pdf
--      * KUND_STAMMBLATT.pdf(p_kund_id) liefert das Kundenstammblatt als BLOB
--        (Kopf, Adressen, Bemerkung, Kommunikation, Ansprechpersonen)
--        Mehrzeilige Firmennamen (Umbruch aus dem Altsystem) werden zeilenweise ausgegeben.
-- Erzeugt: 2026-09-25
-- Wiederholbar (nur create or replace package).
-- Voraussetzung: 13_kundenstamm_erweiterung.sql
-- =====================================================================

set define off

@@../lib/as_pdf/as_pdf.sql

create or replace package KUND_STAMMBLATT
as
    -- Kundenstammblatt eines Kunden als PDF
    function pdf(p_kund_id in number) return blob;

    -- Dateiname fuer den Download, z.B. Kundenstammblatt_100090.pdf
    function dateiname(p_kund_id in number) return varchar2;
end KUND_STAMMBLATT;
/

create or replace package body KUND_STAMMBLATT
as
    c_links     constant number := 45;             -- linker Rand (pt)
    c_rechts    constant number := 555;            -- rechter Rand (pt), A4 = 595 pt breit
    c_oben      constant number := 800;            -- erste Zeile (pt von unten)
    c_unten     constant number := 50;             -- darunter Seitenumbruch
    c_wert_x    constant number := 135;            -- Spalte der Werte hinter den Labels
    c_linie     constant varchar2(6) := '000000';
    c_grau      constant varchar2(6) := '808080';

    g_f_normal  pls_integer;
    g_f_fett    pls_integer;
    g_f_kursiv  pls_integer;
    g_y         number;

    -- ---------------------------------------------------------------
    procedure txt(p_x number, p_txt varchar2, p_font pls_integer default null,
                  p_size number default 8.5, p_color varchar2 default null)
    is
    begin
        if p_txt is not null then
            as_pdf.put_txt(p_x, g_y, p_txt, p_font_index => coalesce(p_font, g_f_normal),
                           p_fontsize => p_size, p_color => p_color);
        end if;
    end txt;

    -- Label wie im Altsystem: kursiv, unterstrichen
    procedure label(p_x number, p_txt varchar2)
    is
    begin
        as_pdf.underline(p_txt, p_x, g_y, p_font_index => g_f_kursiv, p_fontsize => 8, p_line_width => 0.4);
    end label;

    procedure platz(p_hoehe number);

    -- Text mit Wortumbruch auf p_breite; g_y steht danach unter dem Text
    procedure block(p_x number, p_breite number, p_txt varchar2, p_size number default 8.5)
    is
        l_rest  varchar2(32767) := p_txt;
        l_zeile varchar2(32767);
        l_wort  varchar2(32767);
        l_pos   pls_integer;
    begin
        while l_rest is not null loop
            l_pos := instr(l_rest, ' ');
            l_wort := case when l_pos = 0 then l_rest else substr(l_rest, 1, l_pos - 1) end;
            l_rest := case when l_pos = 0 then null else substr(l_rest, l_pos + 1) end;
            if l_zeile is not null
               and as_pdf.str_len(l_zeile || ' ' || l_wort, g_f_normal, p_size) > p_breite then
                platz(12);
                txt(p_x, l_zeile, g_f_normal, p_size);
                g_y := g_y - p_size * 1.2;
                l_zeile := l_wort;
            else
                l_zeile := case when l_zeile is null then l_wort else l_zeile || ' ' || l_wort end;
            end if;
        end loop;
        platz(12);
        txt(p_x, l_zeile, g_f_normal, p_size);
        g_y := g_y - p_size * 1.2;
    end block;

    procedure neue_seite
    is
    begin
        as_pdf.new_page;
        -- Fusslinie hier statt per p_page_proc (as_pdf 4.0.3 vertauscht dort Linienbreite und -farbe)
        as_pdf.horizontal_line(c_links, 38, c_rechts - c_links, 0.4, c_grau);
        g_y := c_oben;
    end neue_seite;

    -- Seitenumbruch, wenn weniger als p_hoehe Platz bleibt
    procedure platz(p_hoehe number)
    is
    begin
        if g_y - p_hoehe < c_unten then
            neue_seite;
        end if;
    end platz;

    -- ---------------------------------------------------------------
    function groesse_text(p_code varchar2) return varchar2
    is
    begin
        return case p_code
                   when 'KU' then 'Kleinstunternehmen'
                   when 'K'  then 'Kleinunternehmen'
                   when 'M'  then 'Mittleres Unternehmen'
                   when 'G'  then 'Großunternehmen'
               end;
    end groesse_text;

    function dateiname(p_kund_id in number) return varchar2
    is
        l_nr KUND_KUNDEN.KUND_NUMMER%type;
    begin
        select KUND_NUMMER into l_nr from KUND_KUNDEN where KUND_ID = p_kund_id;
        return 'Kundenstammblatt_' || l_nr || '.pdf';
    end dateiname;

    -- ---------------------------------------------------------------
    procedure kopf(p_kunde KUND_KUNDEN%rowtype)
    is
    begin
        g_y := c_oben;
        as_pdf.underline('Kundenstammblatt:', c_links, g_y, p_font_index => g_f_fett, p_fontsize => 14, p_line_width => 0.8);
        txt(c_rechts - 95, 'Kd.-Nr. ' || p_kunde.KUND_NUMMER, g_f_normal, 8.5, c_grau);
        g_y := g_y - 18;
        label(c_links, 'Kurzbezeichnung:');
        txt(c_wert_x, p_kunde.KUND_KURZNAME, g_f_fett, 10);
        label(360, 'UID:');
        txt(385, p_kunde.KUND_UID_NUMMER);
        g_y := g_y - 13;
        label(c_links, 'Firmenwortlaut:');
        -- Firmennamen aus dem Altsystem enthalten teils Zeilenumbrueche -> je Zeile ausgeben
        for r in (select trim(regexp_substr(n, '[^' || chr(10) || ']+', 1, level)) as zeile
                    from (select replace(p_kunde.KUND_FIRMENNAME, chr(13)) as n from dual)
                 connect by level <= regexp_count(n, '[^' || chr(10) || ']+'))
        loop
            if r.zeile is not null then
                txt(c_wert_x, r.zeile);
                g_y := g_y - 11;
            end if;
        end loop;
        g_y := g_y + 11;
        if p_kunde.KUND_NAMENSZUSATZ is not null then
            g_y := g_y - 11;
            txt(c_wert_x, replace(replace(p_kunde.KUND_NAMENSZUSATZ, chr(13)), chr(10), ' '));
        end if;
        g_y := g_y - 16;
    end kopf;

    procedure adressen(p_kund_id number)
    is
        c_x_art    constant number := c_wert_x;
        c_x_str    constant number := c_wert_x + 75;
        c_x_plz    constant number := 390;
        c_x_ort    constant number := 425;
        c_x_land   constant number := c_rechts - 22;
    begin
        label(c_links, 'Adresse:');
        txt(c_x_art, 'Adressart', g_f_kursiv, 8);
        txt(c_x_str, 'Straße', g_f_kursiv, 8);
        txt(c_x_plz, 'PLZ', g_f_kursiv, 8);
        txt(c_x_ort, 'Ort', g_f_kursiv, 8);
        txt(c_x_land, 'Land', g_f_kursiv, 8);
        as_pdf.horizontal_line(c_x_art, g_y - 3, c_rechts - c_x_art, 0.5, c_linie);
        g_y := g_y - 12;
        for r in (select coalesce(s.KSTO_BEZEICHNUNG, t.STYP_BEZEICHNUNG) as art,
                         trim(a.ADRE_STRASSE || ' ' || a.ADRE_HAUSNUMMER) as strasse,
                         a.ADRE_ZUSATZ as zusatz, a.ADRE_PLZ as plz, a.ADRE_ORT as ort,
                         a.ADRE_LAND_CODE as land
                    from KUND_STANDORTE s
                    left join KUND_STANDORT_TYPEN t on t.STYP_ID = s.KSTO_STYP_ID
                    left join ALLG_ADRESSEN a on a.ADRE_ID = s.KSTO_ADRE_ID
                   where s.KSTO_KUND_ID = p_kund_id
                   order by case s.KSTO_IST_HAUPTSITZ when 'Y' then 0 else 1 end, s.KSTO_ID)
        loop
            platz(12);
            txt(c_x_art, substr(r.art, 1, 25));
            txt(c_x_str, r.strasse);
            txt(c_x_plz, r.plz);
            txt(c_x_ort, substr(r.ort, 1, 32));
            txt(c_x_land, r.land);
            if r.zusatz is not null then
                g_y := g_y - 10;
                txt(c_x_str, r.zusatz, g_f_normal, 7.5);
            end if;
            g_y := g_y - 11;
        end loop;
        g_y := g_y - 6;
    end adressen;

    procedure bemerkung(p_bemerkung clob)
    is
        l_rest  clob := replace(p_bemerkung, chr(13));
        l_pos   pls_integer;
        l_zeile varchar2(4000);
    begin
        platz(24);
        label(c_links, 'Bemerkung:');
        if l_rest is null then
            g_y := g_y - 16;
            return;
        end if;
        -- zeilenweise ausgeben, damit lange Bemerkungen sauber umbrechen
        loop
            l_pos := dbms_lob.instr(l_rest, chr(10));
            if l_pos = 0 then
                l_zeile := dbms_lob.substr(l_rest, 4000, 1);
            else
                l_zeile := dbms_lob.substr(l_rest, least(l_pos - 1, 4000), 1);
            end if;
            platz(12);
            if l_zeile is null then
                g_y := g_y - 10;
            else
                block(c_wert_x, c_rechts - c_wert_x, l_zeile);
            end if;
            exit when l_pos = 0;
            l_rest := dbms_lob.substr(l_rest, 32767, l_pos + 1);
            exit when l_rest is null;
        end loop;
        g_y := g_y - 8;
    end bemerkung;

    procedure kommunikation(p_kunde KUND_KUNDEN%rowtype)
    is
        c_x_wert constant number := c_wert_x + 105;
        c_x_rl   constant number := 410;
        c_x_rw   constant number := 470;
        l_gruppe KUND_KUNDENGRUPPEN.KGRP_BEZEICHNUNG%type;
        l_y0     number;
        l_y_min  number;
    begin
        platz(40);
        if p_kunde.KUND_KGRP_ID is not null then
            select KGRP_BEZEICHNUNG into l_gruppe from KUND_KUNDENGRUPPEN where KGRP_ID = p_kunde.KUND_KGRP_ID;
        end if;
        l_y0 := g_y;
        label(c_links, 'Kommunikation:');
        -- rechte Spalte
        label(c_x_rl, 'Hauptgruppe:');
        txt(c_x_rw, l_gruppe);
        g_y := l_y0 - 11;
        label(c_x_rl, 'Fi.Größe:');
        txt(c_x_rw, groesse_text(p_kunde.KUND_UNTERNEHMENSGROESSE));
        g_y := l_y0 - 22;
        label(c_x_rl, 'MA:');
        txt(c_x_rw, p_kunde.KUND_MITARBEITER_ANZAHL);
        l_y_min := g_y;
        -- linke Spalte
        g_y := l_y0;
        for r in (select a.KART_BEZEICHNUNG || ' ' || coalesce(c.SKOM_BEZEICHNUNG, 'Standard') as art,
                         c.SKOM_WERT as wert
                    from KUND_STANDORTE s
                    join KUND_STANDORT_KOMMUNIKATION c on c.SKOM_KSTO_ID = s.KSTO_ID
                    join ALLG_KOMMUNIKATIONSARTEN a on a.KART_ID = c.SKOM_KART_ID
                   where s.KSTO_KUND_ID = p_kunde.KUND_ID
                   order by case s.KSTO_IST_HAUPTSITZ when 'Y' then 0 else 1 end, s.KSTO_ID,
                            a.KART_SORTIERUNG, c.SKOM_ID)
        loop
            platz(12);
            txt(c_wert_x, r.art, g_f_kursiv);
            txt(c_x_wert, substr(replace(replace(r.wert, chr(13)), chr(10), ' '), 1, 45), g_f_kursiv);
            g_y := g_y - 11;
        end loop;
        g_y := least(g_y, l_y_min - 11) - 10;
    end kommunikation;

    -- Ansprechpersonen als Tabelle; Kopfzeile wird nach jedem Seitenumbruch wiederholt
    procedure ansprechpersonen(p_kund_id number)
    is
        l_breiten as_pdf.tp_numbers := as_pdf.tp_numbers(30, 26, 72, 58, 28, 18, 40, 40, 78, 125);
        l_opt     constant varchar2(100) := '{"yOffset":true}';
        l_zeilen  pls_integer;

        procedure tabellenkopf
        is
        begin
            as_pdf.table_row(as_pdf.tp_varchar2s('Anrede', 'Titel', 'Zuname', 'Vorname', 'DW', 'BW',
                                                 'Funktion', 'Abteilung', 'Kommunikation', ''),
                             c_links, g_y, l_breiten, p_padding => 1.5, p_font_index => g_f_kursiv,
                             p_fontsize => 7, p_line_width => 0, p_options => l_opt);
            g_y := as_pdf.get(as_pdf.c_get_y);
            as_pdf.horizontal_line(c_links, g_y, c_rechts - c_links, 0.8, c_linie);
        end tabellenkopf;
    begin
        platz(50);
        label(c_links, 'Ansprechperson:');
        g_y := g_y - 4;
        tabellenkopf;
        for r in (select p.ANSP_ANREDE as anrede, p.ANSP_TITEL as titel, p.ANSP_NACHNAME as nachname,
                         p.ANSP_VORNAME as vorname, p.ANSP_DURCHWAHL as dw, p.ANSP_BEWERTUNG as bw,
                         coalesce(f.FUNK_CODE, p.ANSP_FUNKTION) as funktion, ab.ABTE_CODE as abteilung,
                         (select listagg(a.KART_BEZEICHNUNG || ' ' || coalesce(c.AKOM_BEZEICHNUNG, 'Standard'), chr(10))
                                 within group (order by a.KART_SORTIERUNG, c.AKOM_ID)
                            from KUND_ANSPRECHPARTNER_KOMMUNIKATION c
                            join ALLG_KOMMUNIKATIONSARTEN a on a.KART_ID = c.AKOM_KART_ID
                           where c.AKOM_ANSP_ID = p.ANSP_ID) as komm_art,
                         (select listagg(trim(replace(replace(c.AKOM_WERT, chr(13)), chr(10), ' ')), chr(10)) within group (order by a.KART_SORTIERUNG, c.AKOM_ID)
                            from KUND_ANSPRECHPARTNER_KOMMUNIKATION c
                            join ALLG_KOMMUNIKATIONSARTEN a on a.KART_ID = c.AKOM_KART_ID
                           where c.AKOM_ANSP_ID = p.ANSP_ID) as komm_wert,
                         (select count(*) from KUND_ANSPRECHPARTNER_KOMMUNIKATION c
                           where c.AKOM_ANSP_ID = p.ANSP_ID) as komm_anzahl
                    from KUND_ANSPRECHPARTNER p
                    join KUND_STANDORTE s on s.KSTO_ID = p.ANSP_KSTO_ID
                    left join KUND_FUNKTIONEN f on f.FUNK_ID = p.ANSP_FUNK_ID
                    left join KUND_ABTEILUNGEN ab on ab.ABTE_ID = p.ANSP_ABTE_ID
                   where s.KSTO_KUND_ID = p_kund_id
                   order by coalesce(p.ANSP_BEWERTUNG, 'Z'), p.ANSP_NACHNAME, p.ANSP_VORNAME)
        loop
            l_zeilen := greatest(r.komm_anzahl, 1);
            if g_y - (l_zeilen * 8.4 + 6) < c_unten then
                neue_seite;
                tabellenkopf;
            end if;
            as_pdf.table_row(as_pdf.tp_varchar2s(r.anrede, r.titel, r.nachname, r.vorname, r.dw, r.bw,
                                                 r.funktion, r.abteilung, r.komm_art, r.komm_wert),
                             c_links, g_y - 1.5, l_breiten, p_padding => 1.5, p_font_index => g_f_normal,
                             p_fontsize => 7, p_line_width => 0, p_options => l_opt);
            g_y := as_pdf.get(as_pdf.c_get_y);
            as_pdf.horizontal_line(c_links, g_y, c_rechts - c_links, 0.4, c_linie);
        end loop;
    end ansprechpersonen;

    -- Fusszeile auf allen Seiten
    procedure fusszeile(p_kunde KUND_KUNDEN%rowtype)
    is
    begin
        as_pdf.put_txt(c_links, 28, p_kunde.KUND_NUMMER || ' – ' || coalesce(p_kunde.KUND_KURZNAME, p_kunde.KUND_FIRMENNAME)
                                    || '   ·   erstellt ' || to_char(systimestamp at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI'),
                       p_font_index => g_f_normal, p_fontsize => 7, p_color => c_grau, p_page_proc => 1);
        as_pdf.put_txt(c_rechts - 55, 28, 'Seite #PAGE_NR# / #PAGE_COUNT#',
                       p_font_index => g_f_normal, p_fontsize => 7, p_color => c_grau, p_page_proc => 1);
    end fusszeile;

    function pdf(p_kund_id in number) return blob
    is
        l_kunde KUND_KUNDEN%rowtype;
    begin
        select * into l_kunde from KUND_KUNDEN where KUND_ID = p_kund_id;
        as_pdf.init;
        as_pdf.set_page_format('A4');
        as_pdf.set_margins(p_top => 30, p_left => c_links, p_bottom => 30, p_right => 595 - c_rechts, p_unit => 'pt');
        g_f_normal := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'N');
        g_f_fett   := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'B');
        g_f_kursiv := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'I');
        neue_seite;
        kopf(l_kunde);
        adressen(p_kund_id);
        bemerkung(l_kunde.KUND_BEMERKUNG);
        kommunikation(l_kunde);
        ansprechpersonen(p_kund_id);
        fusszeile(l_kunde);
        return as_pdf.get_pdf;
    end pdf;
end KUND_STAMMBLATT;
/
