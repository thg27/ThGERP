-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 24 – Rechnung als PDF (Layout wie die bisherigen Ausgangsrechnungen, je Mandant)
--      FAKT_RECHNUNG_PDF.pdf(p_rech_id)       -> PDF als BLOB (AS_PDF, siehe 15_kundenstammblatt.sql)
--      FAKT_RECHNUNG_PDF.dateiname(p_rech_id) -> z.B. "Rechnung 2026 - 12.pdf"
--      Kopf: Mandantenlogo (Workspace-Datei MAND_LOGO_DATEI), Firmenname, Anschrift, E-Mail/Telefon
--      Absenderzeile, Empfaenger (Kopie in der Rechnung), Nummer/Datum/Bearbeiter, Vortext,
--      Haupt-/Unterpositionen (Zwischensumme, Rabatt, Pauschale; Beschreibung als Rich Text -> Zeilen,
--      Aufzaehlungen), Summen je Steuersatz,
--      Zahlungsbedingungen, Zahlungsreferenz (fett) mit EPC-QR-Code "Zahlen mit Code" rechts darunter (APEX_BARCODE),
--      Schlusstext; Fuss auf jeder Seite: Firmendaten, Banken, Firmenbuch, Seite x von y
-- Erzeugt: 2026-09-30, Layout an die Kingbill-Rechnungen angeglichen 2026-10-24
-- Wiederholbar (create or replace).
-- Voraussetzung: 15 (AS_PDF), 17/18 (Mandanten), 20/21 (Fakturierung)
-- =====================================================================

set define off

create or replace package FAKT_RECHNUNG_PDF
as
    -- Rechnung als PDF
    function pdf(p_rech_id in number) return blob;

    -- Dateiname fuer den Download, z.B. "Rechnung 2026 - 12.pdf" (Entwurf: "Rechnungsvorschau.pdf")
    function dateiname(p_rech_id in number) return varchar2;
end FAKT_RECHNUNG_PDF;
/

create or replace package body FAKT_RECHNUNG_PDF
as
    c_links     constant number := 53;              -- linker Rand (pt), A4 = 595 x 842 pt (wie die Kingbill-Rechnungen)
    c_rechts    constant number := 563;             -- rechter Rand
    c_unten     constant number := 125;             -- darunter Seitenumbruch (Platz fuer den Fuss)
    c_oben_f2   constant number := 780;             -- erste Zeile ab Seite 2
    c_grau      constant varchar2(6) := '808080';
    c_kopf_bg   constant varchar2(6) := 'dddddd';   -- Hintergrund Tabellenkopf

    -- Spalten der Positionstabelle
    c_x_pos     constant number := c_links;
    c_x_text    constant number := c_links + 46;
    c_b_text    constant number := 250;              -- Breite der Beschreibung
    c_x_preis   constant number := 400;              -- rechtsbuendig
    c_x_menge   constant number := 444;              -- rechtsbuendig (Zahl), Einheit dahinter
    c_x_summe   constant number := c_rechts;         -- rechtsbuendig

    g_normal    pls_integer;
    g_fett      pls_integer;
    g_kursiv    pls_integer;
    g_fett_kursiv pls_integer;
    g_y         number;
    g_wasserzeichen varchar2(20);                    -- VORSCHAU (Entwurf) bzw. STORNIERT

    type t_zeile is record (txt varchar2(4000), fett boolean, punkt boolean);
    type t_zeilen is table of t_zeile index by pls_integer;

    -- ---------------------------------------------------------------- Hilfen
    function betrag(p_wert number) return varchar2
    is
    begin
        return to_char(p_wert, 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''');
    end betrag;

    -- Summenblock wie in den bisherigen Rechnungen: Tausendertrennung mit Leerzeichen (14 155,00)
    function betrag_summe(p_wert number) return varchar2
    is
    begin
        return to_char(p_wert, 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='', ''');
    end betrag_summe;

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

    -- Text mit Wortumbruch und Fett/Kursiv innerhalb der Zeile (Marken aus zeilen(): chr(1)/chr(2) fett an/aus,
    -- chr(4)/chr(5) kursiv an/aus); jedes Wort wird in Teile gleicher Schrift zerlegt und nebeneinander gesetzt
    procedure block_rich(p_x number, p_breite number, p_txt varchar2, p_size number default 9)
    is
        type t_teil is record (txt varchar2(4000), font pls_integer);
        type t_teile is table of t_teil index by pls_integer;
        l_zeile   t_teile;                 -- Teile der aktuellen Zeile
        l_wort    t_teile;                 -- Teile des aktuellen Worts
        l_breite  number := 0;             -- Breite der aktuellen Zeile
        l_wbreite number;
        l_leer    number := as_pdf.str_len(' ', g_normal, p_size);
        l_fett    boolean := false;
        l_kursiv  boolean := false;
        l_rest    varchar2(32767) := p_txt;
        l_w       varchar2(32767);
        l_akt     varchar2(4000);
        l_c       varchar2(4 char);
        l_pos     pls_integer;

        function schrift return pls_integer is
        begin
            return case when l_fett and l_kursiv then g_fett_kursiv when l_fett then g_fett
                        when l_kursiv then g_kursiv else g_normal end;
        end schrift;

        procedure teil_dazu is
        begin
            if l_akt is not null then
                l_wort(l_wort.count + 1).txt := l_akt;
                l_wort(l_wort.count).font := schrift;
                l_wbreite := l_wbreite + as_pdf.str_len(l_akt, schrift, p_size);
                l_akt := null;
            end if;
        end teil_dazu;

        procedure zeile_ausgeben is
            l_px number := p_x;
        begin
            for i in 1 .. l_zeile.count loop
                txt(l_px, l_zeile(i).txt, l_zeile(i).font, p_size);
                l_px := l_px + as_pdf.str_len(l_zeile(i).txt, l_zeile(i).font, p_size);
            end loop;
            g_y := g_y - p_size * 1.25;
            l_zeile.delete;
            l_breite := 0;
        end zeile_ausgeben;
    begin
        while l_rest is not null loop
            l_pos  := instr(l_rest, ' ');
            l_w    := case when l_pos = 0 then l_rest else substr(l_rest, 1, l_pos - 1) end;
            l_rest := case when l_pos = 0 then null else substr(l_rest, l_pos + 1) end;
            l_wort.delete;
            l_wbreite := 0;
            for i in 1 .. nvl(length(l_w), 0) loop
                l_c := substr(l_w, i, 1);
                if l_c in (chr(1), chr(2), chr(4), chr(5)) then
                    teil_dazu;
                    if l_c = chr(1) then l_fett := true;
                    elsif l_c = chr(2) then l_fett := false;
                    elsif l_c = chr(4) then l_kursiv := true;
                    else l_kursiv := false;
                    end if;
                else
                    l_akt := l_akt || l_c;
                end if;
            end loop;
            teil_dazu;
            if l_wort.count > 0 then
                if l_zeile.count > 0 and l_breite + l_leer + l_wbreite > p_breite then
                    zeile_ausgeben;
                end if;
                if l_zeile.count > 0 then
                    l_zeile(l_zeile.count + 1).txt := ' ';
                    l_zeile(l_zeile.count).font := g_normal;
                    l_breite := l_breite + l_leer;
                end if;
                for i in 1 .. l_wort.count loop
                    l_zeile(l_zeile.count + 1) := l_wort(i);
                end loop;
                l_breite := l_breite + l_wbreite;
            end if;
        end loop;
        if l_zeile.count > 0 then
            zeile_ausgeben;
        end if;
    end block_rich;

    -- Rich Text (HTML des Editors) bzw. einfacher Text -> Zeilen; <li> als Aufzaehlung. Fett/kursiv bleiben als Marken im
    -- Text (chr(1)/chr(2) fett an/aus, chr(4)/chr(5) kursiv an/aus) und werden von block_rich wortweise ausgegeben
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
            l_s := regexp_replace(l_s, '<h[1-6]( [^>]*)?>', chr(10) || chr(1), 1, 0, 'i');     -- Ueberschrift fett
            l_s := regexp_replace(l_s, '</h[1-6]>', chr(2) || chr(10), 1, 0, 'i');
            l_s := regexp_replace(l_s, '</(p|div|h[1-6]|li|ul|ol)>', chr(10), 1, 0, 'i');
            l_s := regexp_replace(l_s, '<li[^>]*>', chr(10) || chr(3), 1, 0, 'i');            -- Aufzaehlung
            l_s := regexp_replace(l_s, '<(strong|b)( [^>]*)?>', chr(1), 1, 0, 'i');             -- fett an
            l_s := regexp_replace(l_s, '</(strong|b)>', chr(2), 1, 0, 'i');                     -- fett aus
            l_s := regexp_replace(l_s, '<(em|i)( [^>]*)?>', chr(4), 1, 0, 'i');                 -- kursiv an
            l_s := regexp_replace(l_s, '</(em|i)>', chr(5), 1, 0, 'i');                         -- kursiv aus
            l_s := regexp_replace(l_s, '<[^>]+>', '');
            l_s := utl_i18n.unescape_reference(l_s);
            l_s := replace(l_s, chr(160), ' ');
        end if;
        l_s := l_s || chr(10);
        loop
            exit when l_teil > length(l_s);
            l_z := trim(substr(l_s, l_teil, instr(l_s, chr(10), l_teil) - l_teil));
            l_teil := instr(l_s, chr(10), l_teil) + 1;
            if trim(translate(l_z, 'x' || chr(1) || chr(2) || chr(3) || chr(4) || chr(5), 'x')) is not null then
                l_i := l_i + 1;
                l_erg(l_i).punkt := instr(l_z, chr(3)) > 0;
                l_erg(l_i).fett  := false;
                l_erg(l_i).txt   := trim(replace(l_z, chr(3)));
            end if;
        end loop;
        return l_erg;
    end zeilen;

    procedure neue_seite
    is
    begin
        as_pdf.new_page;
        -- Linie ueber dem Fuss hier statt per p_page_proc (as_pdf 4.0.3 vertauscht dort Linienbreite und -farbe)
        as_pdf.horizontal_line(c_links, 86, c_rechts - c_links, 0.6, '000000');
        if g_wasserzeichen is not null then
            -- Wasserzeichen quer ueber die Seite: Vorschau bzw. stornierte Rechnung nicht als gueltige Rechnung verwenden
            as_pdf.put_txt(case g_wasserzeichen when 'VORSCHAU' then 110 else 95 end, 230, g_wasserzeichen,
                           p_degrees_rotation => 45, p_font_index => g_fett, p_fontsize => 110,
                           p_color => case g_wasserzeichen when 'VORSCHAU' then 'c8c8c8' else 'e08080' end, p_alpha => 0.45);
        end if;
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
            block_rich(c_links, c_rechts - c_links, l_z(i).txt, 9);
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
        return case when l_nr is null then 'Rechnungsvorschau' else 'Rechnung ' || l_nr end || '.pdf';
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
            as_pdf.put_image(l_img, c_links + 7, 716, p_height => 90);
        exception
            when no_data_found then
                null;   -- ohne Logo
        end;
        -- Firma rechts oben
        g_y := 795;
        txt_r(c_rechts, m.MAND_NAME, g_fett, 14);
        g_y := g_y - 13;
        txt_r(c_rechts, m.strasse, g_normal, 10);
        g_y := g_y - 12;
        txt_r(c_rechts, trim(m.plz || ' ' || m.ort), g_normal, 10);
        g_y := g_y - 24;
        if m.email is not null then
            txt_r(c_rechts, 'email  ' || m.email, g_normal, 10);
            g_y := g_y - 11.5;
        end if;
        if m.tel is not null then
            txt_r(c_rechts, 'Tel  ' || m.tel, g_normal, 10);
        end if;
        as_pdf.horizontal_line(c_links, 711, c_rechts - c_links, 0.6, '000000');

        -- Absenderzeile (unterstrichen) und Empfaenger
        g_y := 689;
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
            txt(c_links, p_r.RECH_EMPF_KONTAKTPERSON, g_normal, 10.5);
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
            txt(c_links, p_r.RECH_EMPF_UID_NUMMER, g_normal, 10);
        end if;

        -- Rechnungsnummer, Datum, Bearbeiter
        -- rechts: Datum, Leistungszeitraum, Bearbeiter untereinander (Faelligkeit steht unter den Summen)
        g_y := 569;
        txt(c_links, case when p_r.RECH_NUMMER is null then 'Rechnungsvorschau' else 'Rechnung ' || p_r.RECH_NUMMER end,
            g_fett, 13);
        g_y := 571;
        txt_r(c_rechts, 'Datum: ' || coalesce(to_char(p_r.RECH_DATUM, 'DD.MM.YYYY'), '-'), g_normal, 10);
        g_y := g_y - 11;
        if p_r.RECH_LEISTUNGSZEITRAUM is not null then
            txt_r(c_rechts, 'Leistungszeitraum: ' || p_r.RECH_LEISTUNGSZEITRAUM, g_normal, 9);
            g_y := g_y - 10.5;
        end if;
        for b in (select MITA_NAME from ALLG_MITARBEITER where MITA_ID = p_r.RECH_MITA_ID) loop
            txt_r(c_rechts, 'Bearbeiter: ' || b.MITA_NAME, g_normal, 9);
            g_y := g_y - 10.5;
        end loop;
        g_y := least(g_y + 10.5, 548) - 12;
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

    -- Positionen: Hauptpositionen 1, 2, 3 …; Unterpositionen darunter als 1.10, 1.20 …
    --   * Hauptposition ohne Unterpositionen: wie in den bisherigen Rechnungen Einzelpreis, Menge/Einheit und Summe
    --     (mit Pauschalsumme nur Name und Summe)
    --   * unter dem Namen fett "Art.-Nr.: …", wenn eine Artikelnummer erfasst ist
    --   * Hauptposition mit Unterpositionen: Ueberschrift, Unterpositionen immer mit Einzelpreis, Menge, Rabatt und
    --     Summe; danach "Summe Position n", mit Rabatt der Hauptposition zusaetzlich Rabatt und Zwischensumme, mit
    --     Pauschalsumme zusaetzlich "Pauschalsumme Position n" – fett ist der Betrag, der in die Rechnung eingeht
    procedure positionen(p_r FAKT_RECHNUNGEN%rowtype)
    is
        c_x_zw   constant number := c_x_menge + 30;   -- Beschriftung der Zwischensummen, rechtsbuendig
        l_unter  pls_integer;
        l_rabatt boolean;
        l_netto  number;

        function summe_txt(p_wert number, p_optional varchar2) return varchar2
        is
        begin
            return case when p_optional = 'Y' then '(' || betrag(p_wert) || ' €)' else betrag(p_wert) || ' €' end;
        end summe_txt;

        procedure beschreibung(p_text clob)
        is
            l_z t_zeilen := zeilen(p_text);
        begin
            for i in 1 .. l_z.count loop
                platz(12, true);
                if l_z(i).punkt then
                    txt(c_x_text + 14, chr(14844066), g_normal, 8.5);
                    block_rich(c_x_text + 24, c_b_text - 24, l_z(i).txt, 8.5);
                else
                    block_rich(c_x_text, c_b_text, l_z(i).txt, 8.5);
                end if;
            end loop;
        end beschreibung;

        -- eine Positionszeile: Nummer, Name, Menge, optional Einzelpreis und Summe, Rabatt, Beschreibung;
        -- p_nur_summe: Hauptposition ohne Unterpositionen – nur Name und Summe (kein Einzelpreis, keine Menge/Einheit)
        procedure zeile(p FAKT_RECHNUNGSPOSITIONEN%rowtype, p_nr varchar2, p_mit_preis boolean, p_nur_summe boolean default false)
        is
        begin
            platz(26 + least(regexp_count(dbms_lob.substr(p.RPOS_BESCHREIBUNG, 2000, 1), '<(p|li|br)') + 1, 3) * 10, true);
            txt(c_x_pos + 2, p_nr, g_normal, 9);
            if not p_nur_summe then
                txt_r(c_x_menge, menge(p.RPOS_MENGE), g_normal, 9);
                txt(c_x_menge + 5, p.RPOS_EINHEIT, g_normal, 8.5);
            end if;
            if p_mit_preis then
                if not p_nur_summe then
                    txt_r(c_x_preis, betrag(p.RPOS_EINZELPREIS), g_normal, 9);
                end if;
                txt_r(c_x_summe, summe_txt(p.RPOS_SUMME, p.RPOS_IST_OPTIONAL), g_normal, 9);
            end if;
            block(c_x_text, c_b_text, p.RPOS_NAME || case when p.RPOS_IST_OPTIONAL = 'Y' then ' (optional)' end, g_fett, 9);
            if p.RPOS_ARTIKELNUMMER is not null then
                g_y := g_y + 1.5;
                txt(c_x_text, 'Art.-Nr.: ' || p.RPOS_ARTIKELNUMMER, g_fett, 8.5);
                g_y := g_y - 12;
            end if;
            g_y := g_y - 1.5;
            if p_mit_preis and not p_nur_summe and p.RPOS_RABATT_PROZENT is not null and p.RPOS_RABATT_PROZENT <> 0 then
                txt(c_x_text, 'abzüglich ' || menge(p.RPOS_RABATT_PROZENT) || ' % Rabatt', g_normal, 8.5);
                g_y := g_y - 10.5;
            end if;
            beschreibung(p.RPOS_BESCHREIBUNG);
            g_y := g_y - 12;
        end zeile;

        procedure zwischenzeile(p_label varchar2, p_wert varchar2, p_font pls_integer)
        is
        begin
            platz(14, true);
            txt_r(c_x_zw, p_label, p_font, 9);
            txt_r(c_x_summe, p_wert, p_font, 9);
            g_y := g_y - 12;
        end zwischenzeile;
    begin
        platz(40);
        tabellenkopf;
        for h in (select * from FAKT_RECHNUNGSPOSITIONEN
                   where RPOS_RECH_ID = p_r.RECH_ID and RPOS_HAUPT_RPOS_ID is null
                   order by RPOS_POSITION)
        loop
            select count(*) into l_unter from FAKT_RECHNUNGSPOSITIONEN where RPOS_HAUPT_RPOS_ID = h.RPOS_ID;
            if l_unter = 0 then
                zeile(h, to_char(h.RPOS_POSITION), true, h.RPOS_PAUSCHALSUMME is not null);
                continue;
            end if;
            -- Hauptposition als Ueberschrift
            platz(44, true);
            txt(c_x_pos + 2, to_char(h.RPOS_POSITION), g_fett, 10);
            block(c_x_text, c_rechts - c_x_text, h.RPOS_NAME || case when h.RPOS_IST_OPTIONAL = 'Y' then ' (optional)' end,
                  g_fett, 10);
            beschreibung(h.RPOS_BESCHREIBUNG);
            g_y := g_y - 6;
            for u in (select * from FAKT_RECHNUNGSPOSITIONEN where RPOS_HAUPT_RPOS_ID = h.RPOS_ID order by RPOS_POSITION) loop
                zeile(u, h.RPOS_POSITION || '.' || u.RPOS_POSITION, true);
            end loop;
            -- nach den Unterpositionen: ihre Summe, ggf. Rabatt der Hauptposition, ggf. Pauschalsumme; fett ist der
            -- Betrag, der in die Rechnungssumme eingeht (RPOS_SUMME)
            g_y := g_y + 4;
            as_pdf.horizontal_line(c_x_preis - 60, g_y + 9, c_rechts - c_x_preis + 60, 0.4, c_grau);
            l_rabatt := nvl(h.RPOS_RABATT_PROZENT, 0) <> 0;
            zwischenzeile('Summe Position ' || h.RPOS_POSITION,
                          case when l_rabatt or h.RPOS_PAUSCHALSUMME is not null then betrag(h.RPOS_SUMME_UNTERPOS) || ' €'
                               else summe_txt(h.RPOS_SUMME, h.RPOS_IST_OPTIONAL) end,
                          case when l_rabatt or h.RPOS_PAUSCHALSUMME is not null then g_normal else g_fett end);
            if l_rabatt then
                l_netto := round(h.RPOS_SUMME_UNTERPOS * (1 - h.RPOS_RABATT_PROZENT / 100), 2);
                zwischenzeile('abzüglich ' || menge(h.RPOS_RABATT_PROZENT) || ' % Rabatt',
                              '-' || betrag(h.RPOS_SUMME_UNTERPOS - l_netto) || ' €', g_normal);
                zwischenzeile('Zwischensumme Position ' || h.RPOS_POSITION,
                              case when h.RPOS_PAUSCHALSUMME is not null then betrag(l_netto) || ' €'
                                   else summe_txt(h.RPOS_SUMME, h.RPOS_IST_OPTIONAL) end,
                              case when h.RPOS_PAUSCHALSUMME is not null then g_normal else g_fett end);
            end if;
            if h.RPOS_PAUSCHALSUMME is not null then
                zwischenzeile('Pauschalsumme Position ' || h.RPOS_POSITION, summe_txt(h.RPOS_SUMME, h.RPOS_IST_OPTIONAL), g_fett);
            end if;
            g_y := g_y - 8;
        end loop;
    end positionen;

    procedure summen(p_r FAKT_RECHNUNGEN%rowtype)
    is
        c_x_label constant number := 393;
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
        txt_r(c_rechts, betrag_summe(l_netto), g_normal, 10);
        g_y := g_y - 13;
        for s in (select MWST_PROZENT, MWST from FAKT_RECHNUNG_MWST_V where RECH_ID = p_r.RECH_ID order by MWST_PROZENT desc) loop
            txt(c_x_label, menge(s.MWST_PROZENT) || '% MwSt', g_normal, 10);
            txt_r(c_rechts, betrag_summe(s.MWST), g_normal, 10);
            g_y := g_y - 13;
        end loop;
        txt(c_x_label, 'Gesamtbetrag', g_fett, 10);
        txt_r(c_rechts, betrag_summe(l_netto + l_mwst), g_fett, 10);
        as_pdf.horizontal_line(c_x_label - 3, g_y - 4, c_rechts - c_x_label + 3, 1.2, '000000');
        g_y := g_y - 26;
        if p_r.RECH_IST_OHNE_MWST = 'Y' then
            platz(24);
            txt_r(c_rechts - 2, 'Steuerschuldnerschaft des Leistungsempfängers (Reverse Charge)', g_normal, 9);
            g_y := g_y - 13;
        end if;
        if p_r.RECH_IST_FAELLIGKEIT_ANZEIGEN = 'Y' and p_r.RECH_FAELLIG_AM is not null then
            platz(16);
            txt(c_links + 2, 'Fällig am: ' || to_char(p_r.RECH_FAELLIG_AM, 'DD.MM.YYYY'), g_normal, 9);
            g_y := g_y - 16;
        end if;
    end summen;

    -- Fuss auf allen Seiten: Firmendaten, Banken, Firmenbuch, Seite x von y
    procedure fuss(p_mand_id number)
    is
        l_y    number := 74;

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
        as_pdf.put_txt((595 - as_pdf.str_len('Seite 1 von 1', g_normal, 7.5)) / 2, 24, 'Seite #PAGE_NR# von #PAGE_COUNT#',
                       p_font_index => g_normal, p_fontsize => 7.5, p_page_proc => 1);
    end fuss;

    -- ---------------------------------------------------------------- PDF
    -- EPC-QR-Code ("Zahlen mit Code", EPC069-12 Version 002) rechts unter dem Text zur Zahlungsreferenz: Empfaenger
    -- (Firmenname des Mandanten), IBAN/BIC der bevorzugten Bankverbindung, offener Betrag, Zahlungsreferenz (RF).
    -- Nicht bei Entwurf/Storno, ohne Referenz, ohne Bankverbindung, wenn nichts mehr offen ist oder beim Kunden abgeschaltet.
    procedure qr_code(p_r FAKT_RECHNUNGEN%rowtype)
    is
        c_groesse constant number := 85;            -- Kantenlaenge in pt (ca. 3 cm)
        l_offen   number;
        l_daten   varchar2(1000);
        l_img     pls_integer;
        l_lf      constant varchar2(1) := chr(10);
    begin
        if p_r.RECH_ZAHLUNGSREFERENZ is null or p_r.RECH_STATUS in ('ENTWURF', 'STORNIERT') then
            return;
        end if;
        select p_r.RECH_SUMME_BRUTTO - nvl(sum(ZAHL_BETRAG), 0) into l_offen
          from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = p_r.RECH_ID;
        if l_offen < 0.01 or l_offen > 999999999.99 then
            return;
        end if;
        for b in (select m.MAND_NAME, k.MBNK_IBAN, k.MBNK_BIC
                    from ADMIN_MANDANTEN m
                    join ADMIN_MANDANT_BANKVERBINDUNGEN k on k.MBNK_MAND_ID = m.MAND_ID and k.MBNK_IST_AKTIV = 'Y'
                   where m.MAND_ID = p_r.RECH_MAND_ID
                     -- je Kunde abschaltbar (Kundenstamm: "QR-Code auf der Rechnung")
                     and exists (select 1 from KUND_KUNDEN where KUND_ID = p_r.RECH_KUND_ID and KUND_IST_QR_CODE = 'Y')
                   order by case k.MBNK_IST_BEVORZUGT when 'Y' then 0 else 1 end, k.MBNK_SORTIERUNG
                   fetch first 1 rows only)
        loop
            -- Zeilen: Kennung, Version, Zeichensatz (1 = UTF-8), SEPA-Ueberweisung, BIC, Empfaenger (max. 70), IBAN,
            -- Betrag, Zweck (leer), strukturierte Referenz (RF)
            l_daten := 'BCD' || l_lf || '002' || l_lf || '1' || l_lf || 'SCT' || l_lf
                       || replace(b.MBNK_BIC, ' ') || l_lf
                       || substr(b.MAND_NAME, 1, 70) || l_lf
                       || replace(upper(b.MBNK_IBAN), ' ') || l_lf
                       || 'EUR' || to_char(round(l_offen, 2), 'FM999999990.00', 'NLS_NUMERIC_CHARACTERS=''.,''') || l_lf
                       || l_lf
                       || p_r.RECH_ZAHLUNGSREFERENZ || l_lf;
            l_img := as_pdf.load_image(apex_barcode.get_qrcode_png(p_value => l_daten, p_scale => 6, p_quiet => 1,
                                                                   p_eclevel => 'M'));
            platz(c_groesse + 16);
            as_pdf.put_image(l_img, c_rechts - c_groesse, g_y - c_groesse, p_width => c_groesse, p_height => c_groesse);
            g_y := g_y - c_groesse - 9;
            txt_r(c_rechts - (c_groesse - as_pdf.str_len('Zahlen mit Code', g_normal, 7)) / 2, 'Zahlen mit Code', g_normal, 7);
            g_y := g_y - 12;
        end loop;
    end qr_code;

    function pdf(p_rech_id in number) return blob
    is
        l_r FAKT_RECHNUNGEN%rowtype;
    begin
        select * into l_r from FAKT_RECHNUNGEN where RECH_ID = p_rech_id;
        g_wasserzeichen := case l_r.RECH_STATUS when 'ENTWURF' then 'VORSCHAU' when 'STORNIERT' then 'STORNIERT' end;
        as_pdf.init;
        as_pdf.set_page_format('A4');
        as_pdf.set_margins(p_top => 30, p_left => c_links, p_bottom => 30, p_right => 595 - c_rechts, p_unit => 'pt');
        as_pdf.set_info(p_title => dateiname(p_rech_id), p_author => 'ThGERP');
        g_normal := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'N');
        g_fett   := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'B');
        g_kursiv := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'I');
        g_fett_kursiv := as_pdf.get_font_index(p_family => 'helvetica', p_style => 'BI');
        neue_seite;
        kopf(l_r);
        absatz(l_r.RECH_VORTEXT);
        positionen(l_r);
        summen(l_r);
        absatz(l_r.RECH_ZAHLUNGSBED_TEXT);
        -- Zahlungsreferenz (RF-Referenz, beim Abschliessen erzeugt), fett in Vierergruppen
        if l_r.RECH_ZAHLUNGSREFERENZ is not null then
            platz(12);
            block_rich(c_links, c_rechts - c_links,
                       'Bitte bei Online-Überweisungen die Zahlungsreferenz ' || chr(1)
                       || FAKT_RECHNUNG.referenz_anzeige(l_r.RECH_ZAHLUNGSREFERENZ) || chr(2) || ' angeben.', 9);
            qr_code(l_r);
            g_y := g_y - 6;
        end if;
        absatz(l_r.RECH_SCHLUSSTEXT);
        fuss(l_r.RECH_MAND_ID);
        return as_pdf.get_pdf;
    end pdf;
end FAKT_RECHNUNG_PDF;
/

show errors package body FAKT_RECHNUNG_PDF

-- abhaengige Pakete (Skript 35) neu uebersetzen
begin
    for o in (select object_name from user_objects
               where status <> 'VALID' and object_type = 'PACKAGE BODY' and object_name in ('FAKT_RECHNUNG_DOKUMENT')) loop
        execute immediate 'alter package ' || o.object_name || ' compile body';
    end loop;
end;
/

prompt FAKT_RECHNUNG_PDF installiert.
