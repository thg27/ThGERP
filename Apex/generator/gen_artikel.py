#!/usr/bin/env python3.13
"""Artikelstamm: Seiten fuer THG-FINANZ (20050) und die ALLG-Wertelisten in THG-ALLGEMEIN (20010).

Die eigene App THG-ARTIKEL (20040) ist seit 2026-10-24 aufgeloest – nur Rechnungen verwenden Artikel. Die Seiten
werden hier mit den urspruenglichen Nummern erzeugt und von gen_finanz.py per in_finanz() umnummeriert:
  Artikel (Liste) 10 -> 20, Artikel (Maske: Registerkarten Stammdaten und Kommentar) 11 -> 21;
  Werteliste Artikelgruppen 120/121 (WL_ARTIKEL, Uebersicht Seite 100 der Finanz-App).
  Zusatzfelder, Dokumente, Dateien und Artikelbild entfallen seit 2026-10-24 (DDL 29).
THG-ALLGEMEIN: 140/141 Einheiten, 150/151 MwSt.-Saetze, 160/161 Textvorlagen (Look Up Values)
LOVs liegen im Portal (20000) und werden abonniert (siehe CLAUDE.md).
Aufruf:  python3.13 Apex/generator/gen_artikel.py   (nur THG-ALLGEMEIN; Artikelseiten ueber gen_finanz.py)
"""
import re
import secrets
from pathlib import Path

import gen_wertelisten_kunden as wl

APEX = Path(__file__).resolve().parent.parent
ALLG = APEX / "thg-allgemein"

# Seitennummern der Artikelseiten in THG-FINANZ (erzeugt werden sie mit 10/11/12)
SEITEN_FINANZ = {10: 20, 11: 21}


def in_finanz(text):
    """Artikelseite fuer THG-FINANZ umnummerieren: Seitenkopf, Ziele, Cache, Elementnamen (P10_ -> P20_ …)."""
    for alt, neu in SEITEN_FINANZ.items():
        text = re.sub(rf"^page {alt} \(", f"page {neu} (", text, flags=re.M)
        text = re.sub(rf"\b(page|clearCache): {alt}\b", rf"\1: {neu}", text)
        text = re.sub(rf"\bP{alt}_", f"P{neu}_", text)
    return text


# --------------------------------------------------------------------------- Wertelisten
WL_ARTIKEL = [
    dict(seite=120, alias="ARTIKELGRUPPEN", titel="Artikelgruppen", einzahl="Artikelgruppe",
         tabelle="ARTI_ARTIKELGRUPPEN", pfx="AGRP", icon="fa-tags",
         beschreibung="Gruppen der Artikel (Dienstleistung, Office 365 …)",
         felder=[("CODE", "Code", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("SORTIERUNG", "Sortierung", "number", False), ("IST_AKTIV", "Aktiv", "switch", True)],
         order="AGRP_SORTIERUNG nulls last, AGRP_BEZEICHNUNG"),
]
WL_ALLG = [
    dict(seite=140, alias="EINHEITEN", titel="Einheiten", einzahl="Einheit",
         tabelle="ALLG_EINHEITEN", pfx="EINH", icon="fa-balance-scale",
         beschreibung="Mengeneinheiten (Stk., Std., Pauschale …)",
         felder=[("CODE", "Kürzel (Beleg)", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("SORTIERUNG", "Sortierung", "number", False), ("IST_AKTIV", "Aktiv", "switch", True)],
         order="EINH_SORTIERUNG nulls last, EINH_CODE"),
    dict(seite=150, alias="MWST-SAETZE", titel="MwSt.-Sätze", einzahl="MwSt.-Satz",
         tabelle="ALLG_MWST_SAETZE", pfx="MWST", icon="fa-percent",
         beschreibung="Umsatzsteuersätze; der Standardsatz wird für neue Artikel vorgeschlagen",
         felder=[("PROZENT", "Prozent", "number", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("IST_STANDARD", "Standard", "switchN", True), ("SORTIERUNG", "Sortierung", "number", False),
                 ("IST_AKTIV", "Aktiv", "switch", True)],
         order="MWST_SORTIERUNG nulls last, MWST_PROZENT desc"),
    dict(seite=160, alias="TEXTVORLAGEN", titel="Textvorlagen", einzahl="Textvorlage",
         tabelle="ALLG_TEXTVORLAGEN", pfx="TXVL", icon="fa-file-text-o",
         beschreibung="Vorlagen für Zahlungsbedingungen, Vortext und Schlusstext auf Belegen",
         felder=[("ART", "Art", "selectText", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("TEXT", "Text", "textarea", False), ("IST_STANDARD", "Standard je Art", "switchN", True),
                 ("SORTIERUNG", "Sortierung", "number", False)],
         lov="lov-textvorlage-arten",
         order="TXVL_ART, TXVL_SORTIERUNG nulls last, TXVL_BEZEICHNUNG"),
]


def wl_seiten(ziel, wertelisten):
    for w in wertelisten:
        name = w["alias"].lower()
        # "selectText": Auswahlliste mit Textwert (statische LOV), sonst wie select
        felder = [(c, l, "select" if k == "selectText" else k, p) for c, l, k, p in w["felder"]]
        w2 = {**w, "felder": felder}
        ber = wl.bericht({**w, "felder": [(c, l, "text" if k == "selectText" else k, p) for c, l, k, p in w["felder"]]})
        bea = wl.bearbeiten(w2)
        if any(k == "selectText" for _, _, k, _ in w["felder"]):
            bea = bea.replace("dataType: number\n        }\n        lov {", "dataType: varchar2\n        }\n        lov {")
        (ziel / "pages" / f"p{w['seite']:05d}-{name}.apx").write_text(ber, encoding="utf-8")
        (ziel / "pages" / f"p{w['seite'] + 1:05d}-{name}-bearbeiten.apx").write_text(bea, encoding="utf-8")


# --------------------------------------------------------------------------- Bausteine
def item(name, typ, label, seq, region, form="artikel", col=None, dtype="varchar2", req=False, maxlen=None,
         extra="", neue_zeile=True, spalten=None, tmpl=None):
    layout = f"            sequence: {seq}\n            region: @{region}\n            slot: regionBody\n"
    if not neue_zeile:
        layout += "            startNewRow: false\n"
    if spalten:
        layout += f"            columnSpan: {spalten}\n"
    tmpl = tmpl or ("@/required-floating" if req else "@/optional-floating")
    s = f"""    pageItem {name} (
        type: {typ}
        label {{
            label: {label}
            alignment: left
        }}
        layout {{
{layout}            alignment: left
        }}
        appearance {{
            template: {tmpl}
            templateOptions: #DEFAULT#
        }}
"""
    if col:
        s += f"""        source {{
            formRegion: @{form}
            column: {col}
            dataType: {dtype}
        }}
"""
    v = ("            valueRequired: true\n" if req else "") + (f"            maxLength: {maxlen}\n" if maxlen else "")
    if v:
        s += "        validation {\n" + v + "        }\n"
    return s + extra + "    )\n\n"


def lov(static_id, null=None):
    n = f"            displayNullValue: true\n            nullDisplayValue: {null}\n" if null else \
        "            displayNullValue: false\n"
    return f"""        lov {{
            type: sharedComponent
            lov: @{static_id}
{n}            displayExtraValues: false
        }}
"""


SWITCH = lambda d: f"""        settings {{
            useDefaults: false
            onValue: Y
            onLabel: Ja
            offValue: N
            offLabel: Nein
        }}
        default {{
            type: static
            staticValue: {d}
        }}
"""


def region(sid, name, seq, template="@/standard", slot="body", parent=None, typ="staticContent", extra="",
           options="#DEFAULT#", bedingung=None):
    lay = f"            sequence: {seq}\n"
    unter = "tabs" if parent == "details" else "subRegions"  # Unterregionen des Tabs-Containers: Slot tabs
    lay += f"            parentRegion: @{parent}\n            slot: {unter}\n" if parent else f"            slot: {slot}\n"
    s = f"""    region {sid} (
        name: {name}
        type: {typ}
{extra}        layout {{
{lay}        }}
        appearance {{
            template: {template}
            templateOptions: {options}
        }}
"""
    if bedingung:
        s += f"""        serverSideCondition {{
            type: itemIsNotNull
            item: {bedingung}
        }}
"""
    return s + "    )\n\n"


def ir_spalten(spalten):
    out = ""
    for i, sp in enumerate(spalten, 1):
        name, heading, typ, dtype = sp[:4]
        extra = sp[4] if len(sp) > 4 else ""
        ausr = "end" if dtype == "NUMBER" and typ != "hidden" else None
        out += f"""
        column {name} (
            type: {typ}
            heading {{
                heading: {heading}
""" + (f"                alignment: {ausr}\n" if ausr else "") + f"""            }}
            layout {{
                sequence: {i * 10}
""" + (f"                columnAlignment: {ausr}\n" if ausr else "") + f"""            }}
            source {{
                dataType: {dtype}
            }}
{extra}        )
"""
    return out


def button(sid, name, label, seq, region, slot, tmpl="@/text", hot=False, verhalten="", bedingung="", icon=None,
           options="#DEFAULT#"):
    return f"""    button {sid} (
        buttonName: {name}
        label: {label}
        layout {{
            sequence: {seq}
            region: @{region}
            slot: {slot}
        }}
        appearance {{
            buttonTemplate: {tmpl}
""" + ("            hot: true\n" if hot else "") + f"""            templateOptions: {options}
""" + (f"            icon: {icon}\n" if icon else "") + f"""        }}
        behavior {{
{verhalten}        }}
{bedingung}    )

"""


NICHT_NULL = lambda it: f"""        serverSideCondition {{
            type: itemIsNotNull
            item: {it}
        }}
"""
NULL = lambda it: f"""        serverSideCondition {{
            type: itemIsNull
            item: {it}
        }}
"""

BREADCRUMB = lambda titel: f"""    region breadcrumb (
        name: Breadcrumb
        title: {titel}
        type: breadcrumb
        source {{
            breadcrumb: @breadcrumb
        }}
        layout {{
            sequence: 5
            slot: breadcrumbBar
        }}
        appearance {{
            template: @/title-bar
            templateOptions: [
                t-BreadcrumbRegion--useRegionTitle
            ]
        }}
        componentAppearance {{
            breadcrumbTemplate: @/breadcrumb
            templateOptions: #DEFAULT#
        }}
    )

"""

KOPF = lambda nr, name, alias, extra_app="", modal=False: f"""page {nr} (
    name: {name}
    alias: {alias}
    title: {name}
    appearance {{
""" + ("""        pageMode: modalDialog
        dialogTemplate: @/drawer
        templateOptions: [
            #DEFAULT#
            js-dialog-class-t-Drawer--pullOutEnd
        ]
    }
    dialog {
        chained: false
        resizable: false
    }
""" if modal else """        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }
""") + f"""    navigation {{
        cursorFocus: doNotFocusCursor
    }}
    security {{
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }}

"""


# --------------------------------------------------------------------------- Seite 10 Artikel
def _facette(name, label, spalte, seq, extra=""):
    return f"""        facet {name} (
            type: checkboxGroup
            label {{
                label: {label}
            }}
            lov {{
                type: distinctValues
            }}
            layout {{
                sequence: {seq}
            }}
            listEntries {{
                maxDisplayedEntries: 7
            }}
            source {{
                databaseColumn: {spalte}
            }}
{extra}        )

"""


def _spalte(name, heading, seq, typ="plainText", extra="", rechts=False):
    if typ == "hidden":
        return f"""        column {name} (
            type: hidden
            layout {{
                sequence: {seq}
            }}
        )

"""
    ausr = "                alignment: end\n" if rechts else ""
    lay = "                columnAlignment: end\n" if rechts else ""
    return f"""        column {name} (
            type: {typ}
            heading {{
                heading: {heading}
{ausr}            }}
{extra}            layout {{
                sequence: {seq}
{lay}            }}
            sorting {{
                sortable: false
            }}
        )

"""


def seite_10():
    """Artikelliste wie die Kundenliste (Facettensuche links, Aktiv-Icon zuerst, Artikelnummer umrahmt als Link)."""
    s = KOPF(10, "Artikel", "ARTIKEL").replace("pageTemplate: @/standard", "pageTemplate: @/left-side-column")
    s += BREADCRUMB("Artikel")
    s += """    region facets (
        name: Facetten
        type: facetedSearch
        source {
            filteredRegion: @artikel
        }
        layout {
            sequence: 20
            slot: leftColumn
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
        settings {
            compactNosThreshold: 10000
            displayChartForTopNValues: 10
        }

        facet P10_SEARCH (
            type: search
            label {
                label: Suche
            }
            layout {
                sequence: 10
            }
        )

"""
    s += _facette("P10_AKTIV", "Aktiv", "AKTIV", 20)
    s += _facette("P10_GRUPPE", "Gruppe", "GRUPPE", 30)
    s += _facette("P10_EINHEIT", "Einheit", "EINHEIT", 40)
    s += _facette("P10_MWST", "MwSt.", "MWST", 50)
    s += """    )

    region artikel (
        name: Artikel
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select a.ARTI_ID,
                       case a.ARTI_IST_AKTIV when 'Y' then 'Ja' else 'Nein' end as AKTIV,
                       case a.ARTI_IST_AKTIV when 'Y' then 'fa-check-circle u-success-text'
                                             else 'fa-times-circle u-danger-text' end as AKTIV_ICON,
                       a.ARTI_NUMMER,
                       a.ARTI_NAME,
                       coalesce(g.AGRP_BEZEICHNUNG, 'ohne Gruppe') as GRUPPE,
                       a.ARTI_VK_PREIS,
                       case a.ARTI_IST_BRUTTO when 'Y' then 'brutto' else 'netto' end as PREISBASIS,
                       coalesce(e.EINH_CODE, '-') as EINHEIT,
                       m.MWST_PROZENT || ' %' as MWST,
                       a.ARTI_EAN
                  from ARTI_ARTIKEL a
                  left join ARTI_ARTIKELGRUPPEN g on g.AGRP_ID = a.ARTI_AGRP_ID
                  left join ALLG_EINHEITEN e on e.EINH_ID = a.ARTI_EINH_ID
                  join ALLG_MWST_SAETZE m on m.MWST_ID = a.ARTI_MWST_ID
                 order by case a.ARTI_IST_AKTIV when 'Y' then 0 else 1 end,
                          to_number(regexp_substr(a.ARTI_NUMMER, '^\\d+')) nulls last, a.ARTI_NUMMER
                ```
        }
        layout {
            sequence: 30
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Region--noPadding
                t-Region--scrollBody
            ]
        }
        componentAppearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Report--stretch
                t-Report--staticRowColors
                t-Report--rowHighlight
                t-Report--horizontalBorders
            ]
        }
        pagination {
            type: rowRangesXToYOfZWithPagination
        }
        messages {
            whenNoDataFound: Keine Artikel gefunden.
        }

"""
    s += _spalte("ARTI_ID", None, 10, "hidden")
    s += """        column AKTIV (
            type: plainText
            heading {
                heading: Aktiv
                alignment: center
            }
            columnFormatting {
                htmlExpression: <span class="fa #AKTIV_ICON#" title="Aktiv: #AKTIV#" aria-label="Aktiv: #AKTIV#" style="font-size:16px"></span>
            }
            layout {
                columnAlignment: center
                sequence: 15
            }
            sorting {
                sortable: false
            }
        )

"""
    s += _spalte("AKTIV_ICON", None, 16, "hidden")
    s += """        column ARTI_NUMMER (
            type: link
            heading {
                heading: Nummer
            }
            layout {
                sequence: 20
            }
            link {
                target: {
                    page: 11
                    items: {
                        P11_ARTI_ID: #ARTI_ID#
                    }
                    clearCache: 11
                }
                linkText: <span class="thg-kundennr">#ARTI_NUMMER#</span>
            }
            sorting {
                sortable: false
            }
        )

"""
    s += _spalte("ARTI_NAME", "Name", 30)
    s += _spalte("GRUPPE", "Gruppe", 40)
    s += _spalte("ARTI_VK_PREIS", "Verkaufspreis", 50, rechts=True,
                 extra="            appearance {\n                formatMask: FML999G999G990D00\n            }\n")
    s += _spalte("PREISBASIS", "Preis", 55)
    s += _spalte("EINHEIT", "Einheit", 60)
    s += _spalte("MWST", "MwSt.", 70, rechts=True)
    s += _spalte("ARTI_EAN", None, 80, "hidden")
    s += "    )\n\n"
    s += button("up", "UP", "Zurück zum Dashboard", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options="[\n                #DEFAULT#\n                t-Button--noUI\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 1
            }
            warnOnUnsavedChanges: doNotCheck
""")
    s += button("reset", "RESET", "Zurücksetzen", 10, "breadcrumb", "next", "@/text-with-icon",
                verhalten="""            action: redirectThisApp
            target: {
                page: 10
                clearCache: 10
                action: resetPagination
            }
            warnOnUnsavedChanges: doNotCheck
""", icon="fa-undo-alt", options="[\n                t-Button--noUI\n                t-Button--iconLeft\n                t-Button--gapRight\n            ]")
    s += button("hinzufuegen", "CREATE", "Artikel hinzufügen", 20, "breadcrumb", "next", "@/text-with-icon",
                verhalten="""            action: redirectThisApp
            target: {
                page: 11
                clearCache: 11
            }
            warnOnUnsavedChanges: doNotCheck
""", icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--noUI\n                t-Button--iconRight\n            ]")
    return s + ")\n"


# --------------------------------------------------------------------------- Seite 11 Artikel (Maske)
def seite_11():
    s = KOPF(11, "Artikel bearbeiten", "ARTIKEL-BEARBEITEN").replace("title: Artikel bearbeiten", "title: &P11_TITEL.")
    s += BREADCRUMB("&P11_TITEL.")
    # Registerkarten wie im Kundenstamm/Marchler: direkt unter der Titelleiste (thg-rds, "Alle" als Ebenen-Icon per
    # thg.js), Bereiche ohne eigenen Kopf (Titel steht auf der Karte, unter "Alle" sichtbar), Aenderungsinformationen
    s += """    region rds (
        name: Bereiche
        type: regionDisplaySelector
        layout {
            sequence: 6
            slot: fullWidthContent
        }
        appearance {
            template: @/blank-with-attributes-no-grid
            templateOptions: #DEFAULT#
            cssClasses: [
                u-padding-inline-dynamic
                thg-rds
            ]
        }
        settings {
            includeShowAll: true
            rememberSelection: false
        }
    )

    region artikel (
        name: Artikel
        type: form
        source {
            location: localDatabase
            tableName: ARTI_ARTIKEL
        }
        layout {
            sequence: 10
            slot: body
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
        edit {
            enabled: true
            allowedOperations: [
                add
                update
            ]
        }
    )

"""
    tab = "        advanced {\n            regionDisplaySelector: true\n        }\n"
    ohne_kopf = "[\n                #DEFAULT#\n                t-Region--removeHeader js-removeLandmark\n            ]"
    s += region("stammdaten", "Stammdaten", 10, parent="artikel", extra=tab, options=ohne_kopf)
    s += region("tab-kommentar", "Kommentar", 20, parent="artikel", extra=tab, options=ohne_kopf)
    s += region("audit", "Änderungsinformationen", 90, template="@/collapsible", parent="artikel",
                bedingung="P11_ARTI_ID",
                options="[\n                #DEFAULT#\n                is-collapsed\n                t-Region--scrollBody\n"
                        "                t-Form--slimPadding\n            ]").replace(
        "        }\n        serverSideCondition", "            cssClasses: [\n                thg-kompakt\n            ]\n        }\n        serverSideCondition", 1)
    for i, (it, label) in enumerate((("P11_ANGELEGT_AM", "Angelegt am"), ("P11_ANGELEGT_VON", "Angelegt von"),
                                     ("P11_GEAENDERT_AM", "Geändert am"), ("P11_GEAENDERT_VON", "Geändert von"))):
        s += f"""    pageItem {it} (
        type: displayOnly
        label {{
            label: {label}
            alignment: left
        }}
        layout {{
            sequence: {(i + 1) * 10}
            region: @audit
            slot: regionBody
            alignment: left
{'' if i == 0 else '            startNewRow: false' + chr(10)}            columnSpan: 2
        }}
        appearance {{
            template: @/optional-floating
            templateOptions: #DEFAULT#
        }}
        settings {{
            sendOnPageSubmit: false
        }}
    )

"""

    s += """    pageItem P11_ARTI_ID (
        type: hidden
        layout {
            sequence: 1
            region: @stammdaten
            slot: regionBody
        }
        source {
            formRegion: @artikel
            column: ARTI_ID
            dataType: number
            primaryKey: true
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P11_TITEL (
        type: hidden
        layout {
            sequence: 2
            region: @stammdaten
            slot: regionBody
        }
    )

"""
    st = "stammdaten"
    # Artikelnummer ganz oben, daneben Aktiv; darunter Name und Preis
    s += item("P11_ARTI_NUMMER", "textField", "Nummer", 5, st, col="ARTI_NUMMER", req=True, maxlen=30, spalten=3,
              extra="""        default {
            type: sqlQuerySingleValue
            sqlQuerySingleValue:
                ```sql
                select to_char(nvl(max(to_number(ARTI_NUMMER default null on conversion error)), 0) + 1)
                  from ARTI_ARTIKEL
                ```
        }
""")
    s += item("P11_ARTI_IST_AKTIV", "switch", "Aktiv", 7, st,
              col="ARTI_IST_AKTIV", neue_zeile=False, spalten=2, extra=SWITCH("Y"))
    s += item("P11_ARTI_NAME", "textField", "Name", 10, st, col="ARTI_NAME", req=True, maxlen=200, spalten=6)
    s += item("P11_ARTI_VK_PREIS", "numberField", "Verkaufspreis", 20, st, col="ARTI_VK_PREIS", dtype="number",
              req=True, neue_zeile=False, spalten=2,
              extra="        default {\n            type: static\n            staticValue: 0\n        }\n")
    s += item("P11_ARTI_IST_BRUTTO", "switch", "brutto", 30, st, col="ARTI_IST_BRUTTO", neue_zeile=False, spalten=1,
              extra=SWITCH("N"))
    s += item("P11_ARTI_EINH_ID", "selectList", "Einheit", 60, st, col="ARTI_EINH_ID", dtype="number",
              spalten=3, extra=lov("lov-einheiten", "-"))
    s += item("P11_ARTI_AGRP_ID", "selectList", "Gruppe", 70, st, col="ARTI_AGRP_ID", dtype="number", spalten=4,
              neue_zeile=False,
              extra=lov("lov-artikelgruppen", "- keine -"))
    s += item("P11_ARTI_MWST_ID", "selectList", "MwSt. in %", 80, st, col="ARTI_MWST_ID", dtype="number", req=True,
              neue_zeile=False, spalten=3, extra=lov("lov-mwst-saetze") + """        default {
            type: sqlQuerySingleValue
            sqlQuerySingleValue:
                ```sql
                select MWST_ID from ALLG_MWST_SAETZE where MWST_IST_STANDARD = 'Y'
                ```
        }
""")
    s += item("P11_ARTI_BESCHREIBUNG", "richTextEditor", "Beschreibung (wird in die Belegposition übernommen)", 90, st,
              col="ARTI_BESCHREIBUNG", dtype="clob", spalten=12)

    s += item("P11_ARTI_KOMMENTAR", "textarea", "Kommentar (intern)", 10, "tab-kommentar", col="ARTI_KOMMENTAR",
              dtype="clob", spalten=12)

    # Buttons
    # kein Button "Abbrechen": zurueck zur Liste geht es ueber den Pfeil in der Titelleiste
    s += button("save", "SAVE", "Speichern & Schließen", 20, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P11_ARTI_ID"))
    s += button("create", "CREATE", "Anlegen", 30, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P11_ARTI_ID"))
    s += button("up", "UP", "Zurück zur Artikelliste", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options="[\n                #DEFAULT#\n                t-Button--noUI\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 10
            }
            warnOnUnsavedChanges: doNotCheck
""")
    s += """    validation nummer-eindeutig (
        name: Artikelnummer eindeutig
        execution {
            sequence: 10
        }
        validation {
            type: noRowsReturned
            sqlQuery:
                ```sql
                select 1 from ARTI_ARTIKEL
                 where ARTI_NUMMER = :P11_ARTI_NUMMER
                   and ARTI_ID <> nvl(:P11_ARTI_ID, -1)
                ```
        }
        error {
            errorMessage: Diese Artikelnummer ist bereits vergeben.
            associatedItem: @P11_ARTI_NUMMER
        }
    )

    process initialize-form-artikel (
        name: Formular Artikel initialisieren
        type: formInitialization
        formRegion: @artikel
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process titel-setzen (
        name: Seitentitel und Änderungsinformationen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                :P11_TITEL := case when :P11_ARTI_ID is null then 'Neuer Artikel'
                                   else :P11_ARTI_NUMMER || ' – ' || :P11_ARTI_NAME end;
                -- angelegt/geaendert in Wiener Zeit (Server = UTC; Umrechnung in der Abfrage, nicht in der Zuweisung)
                for l in (select to_char(from_tz(ARTI_CREATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI:SS') as AM_A,
                                 ARTI_CREATED_BY,
                                 to_char(from_tz(ARTI_UPDATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI:SS') as AM_G,
                                 ARTI_UPDATED_BY
                            from ARTI_ARTIKEL where ARTI_ID = :P11_ARTI_ID) loop
                    :P11_ANGELEGT_AM   := l.AM_A;
                    :P11_ANGELEGT_VON  := l.ARTI_CREATED_BY;
                    :P11_GEAENDERT_AM  := l.AM_G;
                    :P11_GEAENDERT_VON := l.ARTI_UPDATED_BY;
                end loop;
                ```
        }
        execution {
            sequence: 20
            point: beforeHeader
        }
    )

    process process-form-artikel (
        name: Formular Artikel verarbeiten
        type: formAutoRowProcessing
        formRegion: @artikel
        execution {
            sequence: 10
        }
        successMessage {
            successMessage: Artikel gespeichert.
        }
    )

    branch nach-anlegen (
        name: Nach dem Anlegen im Artikel bleiben
        execution {
            sequence: 10
        }
        behavior {
            target: {
                page: 11
                items: {
                    P11_ARTI_ID: &P11_ARTI_ID.
                }
            }
        }
        serverSideCondition {
            whenButtonPressed: @create
        }
    )

    branch zur-artikelliste (
        name: Zur Artikelliste
        execution {
            sequence: 20
        }
        behavior {
            target: {
                page: 10
            }
        }
    )

)
"""
    return s


def startseite():
    return """page 1 (
    name: Startseite
    alias: HOME
    title: Startseite
    appearance {
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }
    navigation {
        cursorFocus: doNotFocusCursor
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region breadcrumb (
        name: Startseite
        type: breadcrumb
        source {
            breadcrumb: @breadcrumb
        }
        layout {
            sequence: 10
            slot: breadcrumbBar
        }
        appearance {
            template: @/title-bar
            templateOptions: #DEFAULT#
        }
        componentAppearance {
            breadcrumbTemplate: @/breadcrumb
            templateOptions: #DEFAULT#
        }
    )

    region module (
        name: Artikelstamm
        type: list
        source {
            list: @startseite
        }
        layout {
            sequence: 20
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Region--noPadding
            ]
        }
        componentAppearance {
            listTemplate: @/media-list
            templateOptions: [
                #DEFAULT#
                t-MediaList--showBadges
            ]
        }
    )

)
"""


def allgemein_ergaenzen():
    """Look-Up-Values-Liste und Breadcrumbs der Allgemein-App um Einheiten, MwSt.-Saetze, Textvorlagen erweitern."""
    p = ALLG / "shared-components" / "lists.apx"
    s = p.read_text(encoding="utf-8")
    for w in WL_ALLG:
        if f"{w['seite']} as seite" in s:
            continue
        neu = (f"                    union all\n"
               f"                    select '{w['titel']}' as label, {w['seite']} as seite, '{w['icon']}' as image, "
               f"'{w['beschreibung']}' as beschreibung,\n"
               f"                           (select count(*) from {w['tabelle']}) as anzahl\n"
               f"                      from dual\n")
        s = s.replace("                   )\n             order by label", neu + "                   )\n             order by label", 1)
    s = s.replace("""                130
            ]""", """                130
                140
                150
                160
            ]""") if "                140\n" not in s else s
    p.write_text(s, encoding="utf-8")
    p = ALLG / "shared-components" / "breadcrumbs.apx"
    s = p.read_text(encoding="utf-8")
    for w in WL_ALLG:
        if f"entry lookup-{w['seite']} (" in s:
            continue
        s = s.rstrip().rstrip(")") + f"""
    entry lookup-{w['seite']} (
        name: {w['titel']}
        pageNumber: {w['seite']}
        execution {{
            sequence: {w['seite']}
        }}
        appearance {{
            parentEntry: @look-up-values
        }}
        link {{
            target: {{
                page: {w['seite']}
            }}
        }}
    )

)
"""
    p.write_text(s, encoding="utf-8")


if __name__ == "__main__":
    wl_seiten(ALLG, WL_ALLG)
    allgemein_ergaenzen()
    print("THG-ALLGEMEIN um Einheiten, MwSt.-Sätze, Textvorlagen ergänzt (Artikelseiten: gen_finanz.py)")
