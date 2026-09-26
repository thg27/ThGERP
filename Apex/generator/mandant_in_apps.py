#!/usr/bin/env python3
"""Mandant in allen Sub-Apps: globale Items MANDANT_*, Vorbelegung und Mandantenlogo im Banner.

Der Mandant wird im Portal (20000) gewaehlt (Navigationsleiste, App-Prozess "Mandant setzen").
Alle ThG-Apps teilen die Sitzung (Session Sharing: Workspace) und damit die globalen Items MANDANT_*.
Die Sub-Apps belegen den Mandanten nur vor, wenn noch keiner gesetzt ist (Einstieg direkt in einer App),
aendern ihn aber nie – gewechselt wird nur im Portal.
Theme-Stil: Prozess "Theme-Stil" (Portal und Sub-Apps) setzt den beim Mitarbeiter gespeicherten Stil einmal je
Sitzung fuer alle Apps; im Portal speichert die Stilauswahl (Request THEME_STYLE_<id>) den Stil beim Mitarbeiter.
Navigationsleiste: Eintrag mit dem aktuellen Mandanten (nur Anzeige; Klick fuehrt ins Portal zum Wechseln).
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

THEME_PROZESS = """appProcess theme-stil (
    name: Theme-Stil
    type: executeCode
    source {
        plsqlCode:
            ```plsql
            -- Theme-Stil je Mitarbeiter (ALLG_MITARBEITER.MITA_THEME_STIL), gilt in der Sitzung fuer alle ThG-Apps:
            --   * Portal: Auswahl in der Navigationsleiste (Request THEME_STYLE_<id>) -> beim Mitarbeiter speichern
            --   * sonst einmal je Anmeldung: gespeicherten Stil setzen (ohne Eintrag gilt der Standard der App)
            declare
                l_stil ALLG_MITARBEITER.MITA_THEME_STIL%type;

                procedure anwenden(p_name in varchar2) is
                begin
                    for a in (select distinct s.application_id, s.theme_number
                                from apex_application_theme_styles s
                               where s.name = p_name
                                 and s.is_public = 'Yes'
                                 and s.application_id in (select APPL_APEX_APP_ID from ADMIN_APPLIKATIONEN))
                    loop
                        apex_theme.set_session_style(p_application_id => a.application_id,
                                                     p_theme_number   => a.theme_number,
                                                     p_name           => p_name);
                    end loop;
                end;
            begin
                if :REQUEST like 'THEME\\_STYLE\\_%' escape '\\' then
                    select max(name) into l_stil
                      from apex_application_theme_styles
                     where application_id = :APP_ID
                       and theme_style_id = to_number(substr(:REQUEST, length('THEME_STYLE_') + 1));
                    update ALLG_MITARBEITER
                       set MITA_THEME_STIL = l_stil
                     where MITA_BENUTZERNAME = upper(:APP_USER);
                    anwenden(l_stil);
                    :THEME_STIL := l_stil;
                    :THEME_STIL_BENUTZER := :APP_USER;
                elsif :THEME_STIL_BENUTZER is null or :THEME_STIL_BENUTZER <> :APP_USER then
                    select max(MITA_THEME_STIL) into l_stil
                      from ALLG_MITARBEITER
                     where MITA_BENUTZERNAME = upper(:APP_USER);
                    if l_stil is not null then
                        anwenden(l_stil);
                    end if;
                    :THEME_STIL := l_stil;
                    :THEME_STIL_BENUTZER := :APP_USER;
                end if;
            end;
            ```
    }
    execution {
        sequence: 10
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

NAV_EINTRAG = """    entry mandant (
        label: &MANDANT_NAME.
        icon {
            imageIconCssClasses: fa-building-o
        }
        layout {
            sequence: 5
        }
        link {
            target: {
                type: url
                url: f?p=THG-PORTAL:HOME:&SESSION.::&DEBUG.
            }
            linkAttributes: title="Mandant wechseln im Portal"
        }
    )

"""

items = (APEX / "thg-portal" / "shared-components" / "app-items.apx").read_text(encoding="utf-8")
for app, text in SUB_APPS.items():
    sc = APEX / app / "shared-components"
    (sc / "app-items.apx").write_text(items, encoding="utf-8")
    p = sc / "app-processes.apx"
    s = p.read_text(encoding="utf-8") if p.exists() else ""
    s = re.sub(r"appProcess (mandant-vorbelegen|theme-stil) \(.*?\n\)\n\n?", "", s, flags=re.S)
    p.write_text(PROZESS + "\n" + THEME_PROZESS + ("\n" + s if s.strip() else ""), encoding="utf-8")
    p = sc / "lists.apx"
    s = p.read_text(encoding="utf-8")
    if "    entry mandant (" not in s:
        s = s.replace("list navigation-bar (\n    name: Navigation Bar\n\n",
                      "list navigation-bar (\n    name: Navigation Bar\n\n" + NAV_EINTRAG, 1)
        assert "    entry mandant (" in s, app
        p.write_text(s, encoding="utf-8")
    p = APEX / app / "application.apx"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"    logo \{\n.*?\n    \}\n", lambda _: LOGO.format(text=text), s, count=1, flags=re.S)
    p.write_text(s, encoding="utf-8")
# Portal: bisherigen Prozess "Theme-Stil setzen" (setzte den Stil global fuer alle Benutzer) ersetzen
p = APEX / "thg-portal" / "shared-components" / "app-processes.apx"
s = p.read_text(encoding="utf-8")
s = re.sub(r"appProcess (theme-stil-setzen|theme-stil) \(.*?\n\)\n?", "", s, flags=re.S).rstrip("\n")
p.write_text(s + "\n\n" + THEME_PROZESS, encoding="utf-8")
print(f"Mandant (Items, Vorbelegung, Logo) in {len(SUB_APPS)} Sub-Apps")
