#!/usr/bin/env python3
"""Mandant in allen Sub-Apps: globale Items MANDANT_*, Vorbelegung und Mandantenlogo im Banner.

Der Mandant wird im Portal (20000) gewaehlt (Navigationsleiste, App-Prozess "Mandant setzen").
Alle ThG-Apps teilen die Sitzung (Session Sharing: Workspace) und damit die globalen Items MANDANT_*.
Die Sub-Apps belegen den Mandanten nur vor, wenn noch keiner gesetzt ist (Einstieg direkt in einer App),
aendern ihn aber nie – gewechselt wird nur im Portal.
Aufruf (wiederholbar):  python3 Apex/generator/mandant_in_apps.py
"""
import re
from pathlib import Path

APEX = Path(__file__).resolve().parent.parent
SUB_APPS = {"thg-allgemein": "Allgemein", "thg-kunden": "Kundenstammdaten", "thg-admin": "Administration",
            "thg-artikel": "Artikelstamm", "thg-finanz": "Finanz"}

PROZESS = """appProcess mandant-vorbelegen (
    name: Mandant vorbelegen
    type: executeCode
    source {
        plsqlCode:
            ```plsql
            -- Mandant der Sitzung kommt aus dem Portal (globale Items MANDANT_*, Session Sharing).
            -- Nur wenn noch keiner gesetzt ist (direkter Einstieg in diese App): Standard-Mandant des
            -- Mitarbeiters, ersatzweise der erste aktive Mandant. Gewechselt wird nur im Portal.
            declare
                l_mand_id ADMIN_MANDANTEN.MAND_ID%type;
            begin
                if :MANDANT_ID is null or :MANDANT_BENUTZER is null or :MANDANT_BENUTZER <> :APP_USER then
                    select max(MITA_MAND_ID) into l_mand_id
                      from ALLG_MITARBEITER
                      join ADMIN_MANDANTEN on MAND_ID = MITA_MAND_ID and MAND_IST_AKTIV = 'Y'
                     where MITA_BENUTZERNAME = upper(:APP_USER);
                    if l_mand_id is null then
                        select min(MAND_ID) keep (dense_rank first order by MAND_SORTIERUNG, MAND_NAME) into l_mand_id
                          from ADMIN_MANDANTEN
                         where MAND_IST_AKTIV = 'Y';
                    end if;
                    select MAND_ID, MAND_CODE, MAND_KURZNAME, MAND_LOGO_DATEI
                      into :MANDANT_ID, :MANDANT_CODE, :MANDANT_NAME, :MANDANT_LOGO
                      from ADMIN_MANDANTEN
                     where MAND_ID = l_mand_id;
                    :MANDANT_BENUTZER := :APP_USER;
                end if;
            end;
            ```
    }
    execution {
        sequence: 5
        point: beforeHeader
    }
)
"""

LOGO = """    logo {{
        type: custom
        customHtml:
            ```
            <span class="thg-mandant-logo" data-mandant="&MANDANT_CODE."><img src="#WORKSPACE_FILES#&MANDANT_LOGO." alt="&MANDANT_NAME."></span><span class="apex-logo-text">{text}</span>
            ```
    }}
"""

items = (APEX / "thg-portal" / "shared-components" / "app-items.apx").read_text(encoding="utf-8")
for app, text in SUB_APPS.items():
    sc = APEX / app / "shared-components"
    (sc / "app-items.apx").write_text(items, encoding="utf-8")
    p = sc / "app-processes.apx"
    s = p.read_text(encoding="utf-8") if p.exists() else ""
    s = re.sub(r"appProcess mandant-vorbelegen \(.*?\n\)\n\n?", "", s, flags=re.S)
    p.write_text(PROZESS + ("\n" + s if s.strip() else ""), encoding="utf-8")
    p = APEX / app / "application.apx"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"    logo \{\n.*?\n    \}\n", lambda _: LOGO.format(text=text), s, count=1, flags=re.S)
    p.write_text(s, encoding="utf-8")
print(f"Mandant (Items, Vorbelegung, Logo) in {len(SUB_APPS)} Sub-Apps")
