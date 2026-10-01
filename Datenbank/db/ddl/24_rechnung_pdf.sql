-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 24 – Rechnung als PDF (Layout wie die bisherigen Ausgangsrechnungen, je Mandant)
--      FAKT_RECHNUNG_PDF.pdf(p_rech_id)       -> PDF als BLOB (AS_PDF, siehe 15_kundenstammblatt.sql)
--      FAKT_RECHNUNG_PDF.dateiname(p_rech_id) -> z.B. "Rechnung 2026 - 12.pdf"
--      Kopf: Mandantenlogo (Workspace-Datei MAND_LOGO_DATEI), Firmenname, Anschrift, E-Mail/Telefon
--      Absenderzeile, Empfaenger (Kopie in der Rechnung), Nummer/Datum/Bearbeiter, Vortext,
--      Positionen (Beschreibung als Rich Text -> Zeilen, Aufzaehlungen), Summen je Steuersatz,
--      Zahlungsbedingungen, Schlusstext; Fuss auf jeder Seite: Firmendaten, Banken, Firmenbuch, Seite x von y
-- Erzeugt: 2026-09-30
-- Wiederholbar (create or replace).
-- Voraussetzung: 15 (AS_PDF), 17/18 (Mandanten), 20/21 (Fakturierung)
-- =====================================================================

set define off

create or replace package FAKT_RECHNUNG_PDF
as
    -- Rechnung als PDF
    function pdf(p_rech_id in number) return blob;

    -- Dateiname fuer den Download, z.B. "Rechnung 2026 - 12.pdf" (Entwurf: "Rechnungsentwurf.pdf")
    function dateiname(p_rech_id in number) return varchar2;
end FAKT_RECHNUNG_PDF;
/

create or replace package body FAKT_RECHNUNG_PDF
as
    c_links     constant number := 57;              -- linker Rand (pt), A4 = 595 x 842 pt
    c_rechts    constant number := 538;             -- rechter Rand
    c_unten     constant number := 125;             -- darunter Seitenumbruch (Platz fuer den Fuss)
    c_oben_f2   constant number := 780;             -- erste Zeile ab Seite 2
    c_grau      constant varchar2(6) := '808080';
    c_kopf_bg   constant varchar2(6) := 'dddddd';   -- Hintergrund Tabellenkopf

    -- Spalten der Positionstabelle
    c_x_pos     constant number := c_links;
    c_x_text    constant number := c_links + 40;
    c_b_text    constant number := 250;              -- Breite der Beschreibung
    c_x_preis   constant number := 395;              -- rechtsbuendig
    c_x_menge   constant number := 425;              -- rechtsbuendig (Zahl), Einheit dahinter
    c_x_summe   constant number := c_rechts;         -- rechtsbuendig

    g_normal    pls_integer;
    g_fett      pls_integer;
    g_y         number;

    type t_zeile is record (txt varchar2(4000), fett boolean, punkt boolean);
    type t_zeilen is table of t_zeile index by pls_integer;

    -- ---------------------------------------------------------------- Hilfen
    function betrag(p_wert number) return varchar2
    is
    begin
        return to_char(p_wert, 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''');
    end betrag;

    function menge(p_wert number) return varchar2
    is
    begin
        return rtrim(rtrim(to_char(p_wert, 'FM999G999G990D999', 'NLS_NUMERIC_CHARACTERS='',.'''), '0'), ',');
    end menge;

    function iban(p_iban varchar2) return varchar2
    is
        l_roh varchar2(50) := replace(upper(p_iban), ' ');
        l_erg varchar2(80);
    begin
        for i in 0 .. ceil(length(l_roh) / 4) - 1 loop
            l_erg := l_erg || case when i > 0 then ' ' end || substr(l_roh, i * 4 + 1, 4);
        end loop;
        return l_erg;
    end iban;

    procedure txt(p_x number, p_txt varchar2, p_font pls_integer default null, p_size number default 9,
                  p_color varchar2 default null)
    is
    begin
        if p_txt is not null then
            as_pdf.put_txt(p_x, g_y, p_txt, p_font_index => coalesce(p_font, g_normal), p_fontsize => p_size,
                           p_color => p_color);
        end if;
    end txt;

    -- rechtsbuendig bis p_x
    procedure txt_r(p_x number, p_txt varchar2, p_font pls_integer default null, p_size number default 9)
    is
    begin
        if p_txt is not null then
            txt(p_x - as_pdf.str_len(p_txt, coalesce(p_font, g_normal), p_size), p_txt, p_font, p_size);
        end if;
    end txt_r;

    -- Text mit Wortumbruch auf p_breite; g_y steht danach unter dem Text
    procedure block(p_x number, p_breite number, p_txt varchar2, p_font pls_integer default null,
                    p_size number default 9)
    is
        l_font  pls_integer := coalesce(p_font, g_normal);
        l_rest  varchar2(32767) := p_txt;
        l_zeile varchar2(32767);
        l_wort  varchar2(32767);
        l_pos   pls_integer;
    begin
        while l_rest is not null loop
            l_pos := instr(l_rest, ' ');
            l_wort := case when l_pos = 0 then l_rest else substr(l_rest, 1, l_pos - 1) end;
            l_rest := case when l_pos = 0 then null else substr(l_rest, l_pos + 1) end;
            if l_zeile is not null and as_pdf.str_len(l_zeile || ' ' || l_wort, l_font, p_size) > p_breite then
                txt(p_x, l_zeile, l_font, p_size);
                g_y := g_y - p_size * 1.25;
                l_zeile := l_wort;
            else
                l_zeile := case when l_zeile is null then l_wort else l_zeile || ' ' || l_wort end;
            end if;
        end loop;
        txt(p_x, l_zeile, l_font, p_size);
        g_y := g_y - p_size * 1.25;
    end block;

    -- Rich Text (HTML des Editors) bzw. einfacher Text -> Zeilen; <strong>/<b> ganzer Zeilen fett, <li> als Aufzaehlung
    function zeilen(p_text clob) return t_zeilen
    is
        l_s     varchar2(32767);
        l_erg   t_zeilen;
        l_z     varchar2(32767);
        l_i     pls_integer := 0;
        l_teil  pls_integer := 1;
    begin
        if p_text is null then
            return l_erg;
        end if;
        l_s := dbms_lob.substr(p_text, 32000, 1);
        l_s := replace(l_s, chr(13));
        if instr(l_s, '<') > 0 then
            l_s := replace(l_s, chr(10), ' ');
            l_s := regexp_replace(l_s, '<br[^>]*>', chr(10), 1, 0, 'i');
            l_s := regexp_replace(l_s, '</(p|div|h[1-6]|li|ul|ol)>', chr(10), 1, 0, 'i');
            l_s := regexp_replace(l_s, '<li[^>]*>', chr(10) || chr(3), 1, 0, 'i');            -- Aufzaehlung
            l_s := regexp_replace(l_s, '<(strong|b)( [^>]*)?>', chr(1), 1, 0, 'i');             -- fett an
            l_s := regexp_replace(l_s, '</(strong|b)>', chr(2), 1, 0, 'i');                     -- fett aus
            l_s := regexp_replace(l_s, '<[^>]+>', '');
            l_s := utl_i18n.unescape_reference(l_s);
            l_s := replace(l_s, chr(160), ' ');
        end if;
        loop
            l_z := regexp_substr(l_s, '[^' || chr(10) || ']*', 1, l_teil);
            exit when l_teil > regexp_count(l_s, chr(10)) + 1;
            l_teil := l_teil + 1;
            l_z := trim(l_z);
            if replace(replace(replace(l_z, chr(1)), chr(2)), chr(3)) is not null then
                l_i := l_i + 1;
                l_erg(l_i).punkt := instr(l_z, chr(3)) > 0;
                l_erg(l_i).fett  := substr(replace(l_z, chr(3)), 1, 1) = chr(1);
                l_erg(l_i).txt   := trim(replace(replace(replace(l_z, chr(1)), chr(2)), chr(3)));
            end if;
        end loop;
        return l_erg;
    end zeilen;

    procedure neue_seite
    is
    begin
        as_pdf.new_page;
        -- Linie ueber dem Fuss hier statt per p_page_proc (as_pdf 4.0.3 vertauscht dort Linienbreite und -farbe)
        as_pdf.horizontal_line(c_links, 95, c_rechts - c_links, 0.6, '000000');
        g_y := c_oben_f2;
    end neue_seite;

    procedure tabellenkopf
    is
    begin
        as_pdf.rect(c_links, g_y - 4, c_rechts - c_links, 14, p_line_color => c_kopf_bg, p_fill_color => c_kopf_bg);
        txt(c_x_pos + 2, 'Pos', g_fett, 9.5);
        txt(c_x_text, 'Beschreibung', g_fett, 9.5);
        txt_r(c_x_preis, 'Einzelpreis', g_fett, 9.5);
        txt(c_x_menge - 10, 'Menge', g_fett, 9.5);
        txt_r(c_x_summe - 2, 'Summe', g_fett, 9.5);
        g_y := g_y - 22;
    end tabellenkopf;

    -- Seitenumbruch, wenn weniger als p_hoehe Platz bleibt (in der Tabelle mit Kopf)
    procedure platz(p_hoehe number, p_mit_kopf boolean default false)
    is
    begin
        if g_y - p_hoehe < c_unten then
            neue_seite;
            if p_mit_kopf then
                tabellenkopf;
            end if;
        end if;
    end platz;

    -- Mehrzeiliger Text (Vortext, Zahlungsbedingungen, Schlusstext)
    procedure absatz(p_text clob)
    is
        l_z t_zeilen := zeilen(p_text);
    begin
        for i in 1 .. l_z.count loop
            platz(12);
            block(c_links, c_rechts - c_links, l_z(i).txt, case when l_z(i).fett then g_fett end, 9);
        end loop;
        if l_z.count > 0 then
            g_y := g_y - 6;
        end if;
    end absatz;

    function dateiname(p_rech_id in number) return varchar2
    is
        l_nr FAKT_RECHNUNGEN.RECH_NUMMER%type;
    begin
        select RECH_NUMMER into l_nr from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        return coalesce('Rechnung ' || l_nr, 'Rechnungsentwurf') || '.pdf';
    end dateiname;

    -- ---------------------------------------------------------------- Teile der Rechnung
    procedure kopf(p_r FAKT_RECHNUNGEN%rowtype)
    is
        l_logo   blob;
        l_img    pls_integer;
        l_y      number;
        cursor c_mand is
            select m.MAND_NAME, m.MAND_LOGO_DATEI,
                   trim(a.ADRE_STRASSE || ' ' || a.ADRE_HAUSNUMMER) as strasse, a.ADRE_PLZ as plz, a.ADRE_ORT as ort,
                   (select max(c.MAKO_WERT) keep (dense_rank first order by case c.MAKO_IST_BEVORZUGT when 'Y' then 0 else 1 end)
                      from ADMIN_MANDANT_KOMMUNIKATION c join ALLG_KOMMUNIKATIONSARTEN k on k.KART_ID = c.MAKO_KART_ID
                     where c.MAKO_MAND_ID = m.MAND_ID and k.KART_CODE = 'EMAIL') as email,
                   (select max(c.MAKO_WERT) keep (dense_rank first order by case k.KART_CODE when 'TEL' then 0 else 1 end,
                                                                         case c.MAKO_IST_BEVORZUGT when 'Y' then 0 else 1 end)
                      from ADMIN_MANDANT_KOMMUNIKATION c join ALLG_KOMMUNIKATIONSARTEN k on k.KART_ID = c.MAKO_KART_ID
                     where c.MAKO_MAND_ID = m.MAND_ID and k.KART_CODE in ('TEL', 'MOBIL')) as tel
              from ADMIN_MANDANTEN m
              left join ALLG_ADRESSEN a on a.ADRE_ID = m.MAND_ADRE_ID
             where m.MAND_ID = p_r.RECH_MAND_ID;
        m c_mand%rowtype;
    begin
        open c_mand;
        fetch c_mand into m;
        close c_mand;
        -- Logo (Workspace-Datei) links oben
        begin
            select file_content into l_logo
              from apex_workspace_static_files
             where workspace = 'THGERP' and file_name = m.MAND_LOGO_DATEI;
            l_img := as_pdf.load_image(l_logo);
            as_pdf.put_image(l_img, c_links, 745, p_height => 75);
        exception
            when no_data_found then
                null;   -- ohne Logo
        end;
        -- Firma rechts oben
        g_y := 805;
        txt_r(c_rechts, m.MAND_NAME, g_fett, 15);
        g_y := g_y - 14;
        txt_r(c_rechts, m.strasse, g_normal, 10);
        g_y := g_y - 12;
        txt_r(c_rechts, trim(m.plz || ' ' || m.ort), g_normal, 10);
        g_y := g_y - 20;
        if m.email is not null then
            txt_r(c_rechts, 'email  ' || m.email, g_normal, 10);
            g_y := g_y - 12;
        end if;
        if m.tel is not null then
            txt_r(c_rechts, 'Tel  ' || m.tel, g_normal, 10);
        end if;
        as_pdf.horizontal_line(c_links, 735, c_rechts - c_links, 0.6, '000000');

        -- Absenderzeile (unterstrichen) und Empfaenger
        g_y := 712;
        as_pdf.underline('Abs.:' || m.MAND_NAME || ' ' || chr(14844066) || ' ' || m.strasse || ' ' || chr(14844066) || ' '
                         || trim(m.plz || ' ' || m.ort), c_links, g_y, p_font_index => g_normal, p_fontsize => 6.5,
                         p_line_width => 0.3);
        g_y := g_y - 13;
        l_y := g_y;
        txt(c_links, p_r.RECH_EMPF_ANREDE, g_normal, 10.5);
        if p_r.RECH_EMPF_ANREDE is not null then
            g_y := g_y - 12.5;
        end if;
        for z in (select trim(regexp_substr(n, '[^' || chr(10) || ']+', 1, level)) as zeile
                    from (select replace(p_r.RECH_EMPF_NAME, chr(13)) as n from dual)
                 connect by level <= regexp_count(n, '[^' || chr(10) || ']+'))
        loop
            txt(c_links, z.zeile, g_normal, 10.5);
            g_y := g_y - 12.5;
        end loop;
        if p_r.RECH_EMPF_KONTAKTPERSON is not null then
            txt(c_links, 'z.H. ' || p_r.RECH_EMPF_KONTAKTPERSON, g_normal, 10.5);
            g_y := g_y - 12.5;
        end if;
        txt(c_links, p_r.RECH_EMPF_STRASSE, g_normal, 10.5);
        g_y := g_y - 12.5;
        txt(c_links, trim(p_r.RECH_EMPF_PLZ || ' ' || p_r.RECH_EMPF_ORT), g_normal, 10.5);
        g_y := g_y - 12.5;
        for l in (select regexp_replace(LAND_BEZEICHNUNG, ' \([A-Z]{2}\)$') as land
                    from ALLG_LAENDER where LAND_CODE = p_r.RECH_EMPF_LAND_CODE)
        loop
            txt(c_links, l.land, g_normal, 10.5);
            g_y := g_y - 12.5;
        end loop;
        if p_r.RECH_EMPF_UID_NUMMER is not null then
            txt(c_links, 'UID-Nr.: ' || p_r.RECH_EMPF_UID_NUMMER, g_normal, 10.5);
        end if;

        -- Rechnungsnummer, Datum, Bearbeiter
        g_y := 590;
        txt(c_links, case when p_r.RECH_NUMMER is null then 'Rechnungsentwurf' else 'Rechnung ' || p_r.RECH_NUMMER end,
            g_fett, 14);
        g_y := 594;
        txt_r(c_rechts, 'Datum: ' || coalesce(to_char(p_r.RECH_DATUM, 'DD.MM.YYYY'), '-'), g_normal, 10);
        g_y := g_y - 12;
        for b in (select MITA_NAME from ALLG_MITARBEITER where MITA_ID = p_r.RECH_MITA_ID) loop
            txt_r(c_rechts, 'Bearbeiter: ' || b.MITA_NAME, g_normal, 9);
            g_y := g_y - 11;
        end loop;
        if p_r.RECH_IST_FAELLIGKEIT_ANZEIGEN = 'Y' and p_r.RECH_FAELLIG_AM is not null then
            txt_r(c_rechts, 'Fällig am: ' || to_char(p_r.RECH_FAELLIG_AM, 'DD.MM.YYYY'), g_normal, 9);
            g_y := g_y - 11;
        end if;
        g_y := least(g_y, 576) - 4;
        if p_r.RECH_LEISTUNGSZEITRAUM is not null then
            txt(c_links, 'Leistungszeitraum: ' || p_r.RECH_LEISTUNGSZEITRAUM, g_normal, 9);
            g_y := g_y - 11;
        end if;
        if p_r.RECH_REFERENZ is not null then
            txt(c_links, 'Referenz: ' || p_r.RECH_REFERENZ, g_normal, 9);
            g_y := g_y - 11;
        end if;
        if p_r.RECH_PROJEKT is not null then
            txt(c_links, 'Projekt: ' || p_r.RECH_PROJEKT, g_normal, 9);
            g_y := g_y - 11;
        end if;
        g_y := g_y - 6;
    end kopf;

    procedure positionen(p_r FAKT_RECHNUNGEN%rowtype)
    is
        l_z      t_zeilen;
        l_kapitel FAKT_RECHNUNGSPOSITIONEN.RPOS_KAPITEL%type;
        l_y_zeile number;
    begin
        platz(40);
        tabellenkopf;
        for p in (select * from FAKT_RECHNUNGSPOSITIONEN where RPOS_RECH_ID = p_r.RECH_ID
                   order by RPOS_KAPITEL nulls first, RPOS_POSITION)   -- ohne Kapitel zuerst, je Kapitel 10, 20, 30 …
        loop
            -- Kapitel als Zwischenueberschrift, wenn es wechselt
            if p.RPOS_KAPITEL is not null and (l_kapitel is null or p.RPOS_KAPITEL <> l_kapitel) then
                platz(30, true);
                txt(c_x_text, p.RPOS_KAPITEL || case when p.RPOS_UNTERKAPITEL is not null then ' – ' || p.RPOS_UNTERKAPITEL end,
                    g_fett, 10);
                g_y := g_y - 16;
            end if;
            l_kapitel := p.RPOS_KAPITEL;
            l_z := zeilen(p.RPOS_BESCHREIBUNG);
            platz(26 + least(l_z.count, 3) * 10, true);
            l_y_zeile := g_y;
            txt(c_x_pos + 2, to_char(p.RPOS_POSITION), g_normal, 9);
            txt_r(c_x_preis, betrag(p.RPOS_EINZELPREIS), g_normal, 9);
            txt_r(c_x_menge, menge(p.RPOS_MENGE), g_normal, 9);
            txt(c_x_menge + 5, p.RPOS_EINHEIT, g_normal, 8.5);
            txt_r(c_x_summe, case when p.RPOS_IST_OPTIONAL = 'Y' then '(' || betrag(p.RPOS_SUMME) || ' €)'
                                  else betrag(p.RPOS_SUMME) || ' €' end, g_normal, 9);
            block(c_x_text, c_b_text, p.RPOS_NAME || case when p.RPOS_IST_OPTIONAL = 'Y' then ' (optional)' end, g_fett, 9);
            if p.RPOS_RABATT_PROZENT is not null and p.RPOS_RABATT_PROZENT <> 0 then
                txt(c_x_text, 'abzüglich ' || menge(p.RPOS_RABATT_PROZENT) || ' % Rabatt', g_normal, 8.5);
                g_y := g_y - 10.5;
            end if;
            for i in 1 .. l_z.count loop
                platz(12, true);
                if l_z(i).punkt then
                    txt(c_x_text + 14, chr(14844066), g_normal, 8.5);
                    block(c_x_text + 24, c_b_text - 24, l_z(i).txt, case when l_z(i).fett then g_fett end, 8.5);
                else
                    block(c_x_text, c_b_text, l_z(i).txt, case when l_z(i).fett then g_fett end, 8.5);
                end if;
            end loop;
            g_y := g_y - 12;
        end loop;
    end positionen;

    procedure summen(p_r FAKT_RECHNUNGEN%rowtype)
    is
        c_x_label constant number := 390;
        l_netto   number := 0;
        l_mwst    number := 0;
    begin
        platz(80);
        as_pdf.horizontal_line(c_links, g_y + 4, c_rechts - c_links, 0.6, '000000');
        g_y := g_y - 12;
        for s in (select MWST_PROZENT, NETTO, MWST from FAKT_RECHNUNG_MWST_V where RECH_ID = p_r.RECH_ID) loop
            l_netto := l_netto + s.NETTO;
            l_mwst  := l_mwst + s.MWST;
        end loop;
        txt(c_x_label, 'Netto', g_normal, 10);
        txt_r(c_rechts, betrag(l_netto), g_normal, 10);
        g_y := g_y - 13;
        for s in (select MWST_PROZENT, MWST from FAKT_RECHNUNG_MWST_V where RECH_ID = p_r.RECH_ID order by MWST_PROZENT desc) loop
            txt(c_x_label, menge(s.MWST_PROZENT) || '% MwSt', g_normal, 10);
            txt_r(c_rechts, betrag(s.MWST), g_normal, 10);
            g_y := g_y - 13;
        end loop;
        txt(c_x_label, 'Gesamtbetrag', g_fett, 10);
        txt_r(c_rechts, betrag(l_netto + l_mwst) || ' €', g_fett, 10);
        as_pdf.horizontal_line(c_x_label, g_y - 3, c_rechts - c_x_label, 0.6, '000000');
        as_pdf.horizontal_line(c_x_label, g_y - 5, c_rechts - c_x_label, 0.6, '000000');
        g_y := g_y - 26;
        if p_r.RECH_IST_OHNE_MWST = 'Y' then
            platz(24);
            block(c_links, c_rechts - c_links,
                  'Steuerschuldnerschaft des Leistungsempfängers (Reverse Charge)', g_normal, 9);
            g_y := g_y - 6;
        end if;
    end summen;

    -- Fuss auf allen Seiten: Firmendaten, Banken, Firmenbuch, Seite x von y
    procedure fuss(p_mand_id number)
    is
        l_y    number := 83;

        procedure mittig(p_txt varchar2, p_size number default 8)
        is
        begin
            as_pdf.put_txt((595 - as_pdf.str_len(p_txt, g_normal, p_size)) / 2, l_y, p_txt, p_font_index => g_normal,
                           p_fontsize => p_size, p_page_proc => 1);
            l_y := l_y - p_size * 1.2;
        end mittig;
    begin
        for m in (select m.MAND_NAME || ' - ' || trim(a.ADRE_STRASSE || ' ' || a.ADRE_HAUSNUMMER) || ' - '
                         || trim(a.ADRE_PLZ || ' ' || a.ADRE_ORT)
                         || case when m.MAND_UID_NUMMER is not null then ' UID: ' || m.MAND_UID_NUMMER end as zeile1,
                         'Firmenbuchgericht: ' || m.MAND_FIRMENBUCHGERICHT || ' ' || m.MAND_FIRMENBUCHNR
                         || ' - Firmensitz: ' || m.MAND_FIRMENSITZ as zeile3
                    from ADMIN_MANDANTEN m
                    left join ALLG_ADRESSEN a on a.ADRE_ID = m.MAND_ADRE_ID
                   where m.MAND_ID = p_mand_id)
        loop
            mittig(m.zeile1);
            for b in (select MBNK_BANK, MBNK_IBAN, MBNK_BIC from ADMIN_MANDANT_BANKVERBINDUNGEN
                       where MBNK_MAND_ID = p_mand_id and MBNK_IST_AKTIV = 'Y'
                       order by case MBNK_IST_BEVORZUGT when 'Y' then 0 else 1 end, MBNK_SORTIERUNG)
            loop
                mittig(b.MBNK_BANK || ', IBAN: ' || iban(b.MBNK_IBAN)
                       || case when b.MBNK_BIC is not null then ', BIC: ' || b.MBNK_BIC end);
            end loop;
            mittig(m.zeile3);
        end loop;
        l_y := l_y - 8;
        -- Breite mit Beispielwerten messen (die Platzhalter sind laenger als die eingesetzten Zahlen)
        as_pdf.put_txt((595 - as_pdf.str_len('Seite 1 von 1', g_normal, 7.5)) / 2, l_y, 'Seite #PAGE_NR# von #PAGE_COUNT#',
                       p_font_index => g_normal, p_fontsize => 7.5, p_page_proc => 1);
    end fuss;

    -- ---------------------------------------------------------------- PDF
    function pdf(p_rech_id in number) return blob
    is
        l_r FAKT_RECHNUNGEN%rowtype;
    begin
        select * into l_r from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        as_pdf.init;
        as_pdf.set_page_format('A4');
        as_pdf.set_margins(p_top => 30, p_left => c_links, p_bottom => 30, p_right => 595 - c_rechts, p_unit => 'pt');
        as_pdf.set_info(p_title => dateiname(p_rech_id), p_author => 'ThGERP');
        g_normal := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'N');
        g_fett   := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'B');
        neue_seite;
        kopf(l_r);
        absatz(l_r.RECH_VORTEXT);
        positionen(l_r);
        summen(l_r);
        absatz(l_r.RECH_ZAHLUNGSBED_TEXT);
        absatz(l_r.RECH_SCHLUSSTEXT);
        fuss(l_r.RECH_MAND_ID);
        return as_pdf.get_pdf;
    end pdf;
end FAKT_RECHNUNG_PDF;
/

show errors package body FAKT_RECHNUNG_PDF

prompt FAKT_RECHNUNG_PDF installiert.
