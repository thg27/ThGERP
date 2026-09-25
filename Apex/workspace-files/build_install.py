#!/usr/bin/env python3
"""Erzeugt install_workspace_files.sql aus den Quelldateien in diesem Ordner.

Workspace-Dateien (#WORKSPACE_FILES#<name>) werden von allen ThG-Apps genutzt.
Ablauf bei Änderungen: Quelldatei bearbeiten -> `python3 build_install.py` ->
install_workspace_files.sql mit SQLcl (Schema WKSP_THGERP) ausführen -> beides committen.
"""
import base64
from pathlib import Path

# Dateiname -> MIME-Typ (Reihenfolge = Reihenfolge im Skript)
FILES = {
    "thg.css": "text/css",
    "thg-logo.svg": "image/svg+xml",
    "thg-app-icon.svg": "image/svg+xml",  # App-Icon (Login-Seite), Farben aus beiden Firmenlogos
    "thg-logo-edv.png": "image/png",   # Mandant EDV (THG-EDV GmbH), aus Vorlagen/Logo ThG edv.tif
    "thg-logo-tg.png": "image/png",    # Mandant TG (Thomas Gesslbauer GmbH), aus Vorlagen/Logo Thomas Gesslbauer GmbH.jpg
}
WORKSPACE = "THGERP"
CHUNK = 1000

here = Path(__file__).resolve().parent


def plsql_clob(text: str) -> str:
    """Inhalt als Folge von dbms_lob.append-Aufrufen (Hochkommas verdoppelt)."""
    parts = [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)] or [""]
    lines = []
    for p in parts:
        lit = p.replace("'", "''")
        lines.append(f"    dbms_lob.append(l_inhalt, to_clob('{lit}'));")
    return "\n".join(lines)


blocks = []
for name, mime in FILES.items():
    binaer = not mime.startswith("text/") and not mime.endswith("+xml")
    if binaer:
        # Binaerdateien (Bilder) als Base64, in der DB mit apex_web_service.clobbase642blob dekodiert
        content = base64.b64encode((here / name).read_bytes()).decode("ascii")
    else:
        content = (here / name).read_text(encoding="utf-8")
    # Zeilenumbrueche als chr(10) erhalten: Literal darf Umbrueche enthalten,
    # SQLcl ueberliest aber Zeilen, die nur "/" enthalten -> kommt in CSS/SVG nicht vor.
    blocks.append(f"""
    -- {name} ({mime})
    dbms_lob.createtemporary(l_inhalt, true);
{plsql_clob(content)}
    workspace_datei(p_file_name => '{name}', p_mime_type => '{mime}', p_inhalt => l_inhalt, p_base64 => {'true' if binaer else 'false'});
    dbms_lob.freetemporary(l_inhalt);
""")

sql = f"""-- =====================================================================
-- Workspace-Dateien der ThG-Apps (Workspace {WORKSPACE}) anlegen bzw. aktualisieren
-- GENERIERT mit build_install.py aus: {', '.join(FILES)} - nicht von Hand bearbeiten!
--
-- Einbindung in den Apps:
--   Theme > CSS > File URLs:        #WORKSPACE_FILES#thg.css
--   Anwendung > Logo (Custom):      #WORKSPACE_FILES#thg-logo-<mandant>.png (ADMIN_MANDANTEN.MAND_LOGO_DATEI)
-- (APEX kennt keine Subscription fuer Dateien, daher Workspace-Dateien statt App-Dateien.)
--
-- Wiederholbar: unveraenderte Dateien bleiben, geaenderte werden ersetzt.
-- Nutzt die APEX-Import-API (wie ein Workspace-Export), da es keine oeffentliche API gibt.
-- Ausfuehren mit SQLcl als Workspace-Schema ({WORKSPACE}), nur DEV/TEST nach Freigabe.
-- =====================================================================

set define off
set serveroutput on

declare
    l_inhalt clob;

    procedure workspace_datei (
        p_file_name in varchar2,
        p_mime_type in varchar2,
        p_inhalt    in clob,
        p_base64    in boolean default false)
    is
    l_workspace_id number;
    l_file_id      number;
    l_alt          blob;
    l_neu          blob;
begin
    l_neu := case when p_base64 then apex_web_service.clobbase642blob(p_inhalt)
                  else apex_util.clob_to_blob(p_clob => p_inhalt, p_charset => 'AL32UTF8') end;
    select workspace_id into l_workspace_id from apex_workspaces where workspace = '{WORKSPACE}';
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
        p_file_charset => case when p_base64 then null else 'utf-8' end,
        p_file_content => l_neu);
    wwv_flow_imp.import_end;
    commit;
    dbms_output.put_line(p_file_name || ': ' || case when l_file_id is null then 'angelegt' else 'aktualisiert' end);
    end workspace_datei;
begin{''.join(blocks)}end;
/
"""
(here / "install_workspace_files.sql").write_text(sql, encoding="utf-8")
print("install_workspace_files.sql erzeugt:", ", ".join(FILES))
