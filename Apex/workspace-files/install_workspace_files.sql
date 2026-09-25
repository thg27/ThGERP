-- =====================================================================
-- Workspace-Dateien der ThG-Apps (Workspace THGERP) anlegen bzw. aktualisieren
-- GENERIERT mit build_install.py aus: thg.css, thg-logo.svg - nicht von Hand bearbeiten!
--
-- Einbindung in den Apps:
--   Theme > CSS > File URLs:        #WORKSPACE_FILES#thg.css
--   Anwendung > Logo (Bild + Text): #WORKSPACE_FILES#thg-logo.svg
-- (APEX kennt keine Subscription fuer Dateien, daher Workspace-Dateien statt App-Dateien.)
--
-- Wiederholbar: unveraenderte Dateien bleiben, geaenderte werden ersetzt.
-- Nutzt die APEX-Import-API (wie ein Workspace-Export), da es keine oeffentliche API gibt.
-- Ausfuehren mit SQLcl als Workspace-Schema (THGERP), nur DEV/TEST nach Freigabe.
-- =====================================================================

set define off
set serveroutput on

declare
    l_inhalt clob;

    procedure workspace_datei (
        p_file_name in varchar2,
        p_mime_type in varchar2,
        p_inhalt    in clob)
    is
    l_workspace_id number;
    l_file_id      number;
    l_alt          blob;
    l_neu          blob := apex_util.clob_to_blob(p_clob => p_inhalt, p_charset => 'AL32UTF8');
begin
    select workspace_id into l_workspace_id from apex_workspaces where workspace = 'THGERP';
    begin
        select workspace_file_id, file_content into l_file_id, l_alt
          from apex_workspace_static_files
         where workspace_id = l_workspace_id and file_name = p_file_name;
    exception
        when no_data_found then l_file_id := null;
    end;

    if l_file_id is not null and dbms_lob.compare(l_alt, l_neu) = 0 then
        dbms_output.put_line(p_file_name || ': unveraendert');
        return;
    end if;

    wwv_flow_imp.import_begin(p_version_yyyy_mm_dd   => '2026.03.30',
                              p_default_workspace_id => l_workspace_id);
    wwv_flow_imp_shared.create_workspace_static_file(
        p_id           => l_file_id,
        p_file_name    => p_file_name,
        p_mime_type    => p_mime_type,
        p_file_charset => 'utf-8',
        p_file_content => l_neu);
    wwv_flow_imp.import_end;
    commit;
    dbms_output.put_line(p_file_name || ': ' || case when l_file_id is null then 'angelegt' else 'aktualisiert' end);
    end workspace_datei;
begin
    -- thg.css (text/css)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('/* ThG: gemeinsame Anpassungen Universal Theme (alle ThG-Apps) */

/* Farbigen Streifen oben im Header (t-Header::before) ausblenden - wie im Strategic Planner.
   Betrifft die Stile Iris/Vita; Redwood hat keinen Streifen. */
:root {
  --ut-header-strip-size: 0;
}

/* Redwood: Header (Banner ganz oben) in dezentem Braun mit weisser Schrift */
body.apex-theme-redwood-light .t-Header {
  --ut-header-background-color: #6b5444;
  --ut-header-border-color: #6b5444;
  --ut-header-text-color: #fff;
  --ut-logo-text-color: #fff;
  color: #fff;
}

/* Logo (ThG-Logo, Workspace-Datei thg-logo.svg) vor dem App-Namen */
.t-Header-logo img {
  height: 1.5rem;
  width: auto;
  margin-inline-end: .5rem;
}

/* Pflichtfelder: Text "Required" unter dem Feld ausblenden - die rote Markierung im Feld genuegt.
   Hoehere Spezifitaet, weil der Theme-Stil (z.B. Redwood.css) nach dieser Datei geladen wird. */
.t-Form-fieldContainer .t-Form-itemAssistance .t-Form-itemRequired {
  display: none;
}

/* Radio-/Chec'));
    dbms_lob.append(l_inhalt, to_clob('kbox-Gruppen nebeneinander statt untereinander:
   am Feld Appearance > CSS Classes "thg-horizontal" setzen */
.thg-horizontal.apex-item-group--rc,
.thg-horizontal .apex-item-group--rc {
  display: flex;
  flex-wrap: wrap;
  column-gap: 1.5rem;
}

/* Aktives Eingabefeld hervorheben (Hintergrund), damit sofort sichtbar ist, wo der Cursor steht;
   Radio-/Checkbox-Gruppen ausgenommen (dort wäre die ganze Gruppe eingefärbt) */
.t-Form-fieldContainer:focus-within {
  --thg-fokus: #f6ecd9;
}
.t-Form-fieldContainer:focus-within .t-Form-inputContainer :is(input:not([type=radio]):not([type=checkbox]), textarea, select),
.t-Form-fieldContainer--floatingLabel:not(:has(.apex-item-group--rc)):focus-within .t-Form-fieldContainer-inner,
.t-Form-fieldContainer--floatingLabel:not(:has(.apex-item-group--rc)):focus-within .t-Form-itemWrapper {
  background-color: var(--thg-fokus) !important;
}

/* Kompakte Formular-Regionen: Region > Appearance > CSS Classes "thg-kompakt"
   (zusammen mit Template-Optio'));
    dbms_lob.append(l_inhalt, to_clob('n "Slim Padding"): weniger Leerraum zwischen und in den Abschnitten */
.t-Region.thg-kompakt {
  margin-block-end: .75rem;
}
.thg-kompakt > .t-Region-header {
  padding-block: .375rem;
  min-block-size: 0;
}
.thg-kompakt > .t-Region-header .t-Region-headerItems {
  padding-block: 0;
  min-block-size: 0;
}
.thg-kompakt > .t-Region-header .t-Region-title {
  font-size: .9375rem;
}
.thg-kompakt > .t-Region-bodyWrap > .t-Region-body {
  padding: .375rem .5rem .5rem;
}

/* Dialog ohne Redwood-Musterstreifen über der Titelleiste: Klasse "thg-dialog-schlicht" am .ui-dialog
   (setzt z.B. das Kundenstammblatt, Seite 13 in 20020, per JavaScript) */
.ui-dialog.thg-dialog-schlicht .ui-dialog-titlebar::before {
  display: none !important;
}
'));
    workspace_datei(p_file_name => 'thg.css', p_mime_type => 'text/css', p_inhalt => l_inhalt);
    dbms_lob.freetemporary(l_inhalt);

    -- thg-logo.svg (image/svg+xml)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="39" viewBox="0 0 64 39" fill="none"><title>ThG</title><text x="0" y="31" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="32" font-weight="700" letter-spacing="-0.5" fill="#ffffff">ThG</text></svg>
'));
    workspace_datei(p_file_name => 'thg-logo.svg', p_mime_type => 'image/svg+xml', p_inhalt => l_inhalt);
    dbms_lob.freetemporary(l_inhalt);
end;
/
