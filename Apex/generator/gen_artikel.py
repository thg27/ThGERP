#!/usr/bin/env python3.13
"""Artikelstamm: Seiten fuer THG-FINANZ (20050) und die ALLG-Wertelisten in THG-ALLGEMEIN (20010).

Die eigene App THG-ARTIKEL (20040) ist seit 2026-10-24 aufgeloest – nur Rechnungen verwenden Artikel. Die Seiten
werden hier mit den urspruenglichen Nummern erzeugt und von gen_finanz.py per in_finanz() umnummeriert:
  Artikel (Liste) 10 -> 20, Artikel (Maske nach Kingbill: Stammdaten, Beschreibung, Bild, Registerkarten
  Kommentar / Zusatzfelder / Dokumente / Dateien) 11 -> 21, Datei (Dialog) 12 -> 22;
  Wertelisten Artikelgruppen 120/121, Zusatzfelder 130/131 (WL_ARTIKEL, Uebersicht Seite 100 der Finanz-App)
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
SEITEN_FINANZ = {10: 20, 11: 21, 12: 22}


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
    dict(seite=130, alias="ZUSATZFELDER", titel="Zusatzfelder", einzahl="Zusatzfeld",
         tabelle="ARTI_ZUSATZFELDER", pfx="ZUSF", icon="fa-list-alt",
         beschreibung="Feldnamen der Zusatzfelder in der Artikelmaske (1–10)",
         felder=[("NUMMER", "Feldnummer", "number", True), ("BEZEICHNUNG", "Feldname", "text", True),
                 ("IST_AKTIV", "In der Maske anzeigen", "switch", True)],
         order="ZUSF_NUMMER"),
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
    s += region("tab-zusatzfelder", "Zusatzfelder", 30, parent="artikel", extra=tab, options=ohne_kopf)
    s += region("tab-dokumente", "Dokumente", 40, parent="artikel", bedingung="P11_ARTI_ID", extra=tab, options=ohne_kopf)
    # Dateien: Kopf bleibt fuer den Button "Datei hinzufuegen", nur der Titel ist ausgeblendet (thg-ohne-titel)
    s += region("tab-dateien", "Dateien", 50, parent="artikel", bedingung="P11_ARTI_ID", extra=tab).replace(
        "            templateOptions: #DEFAULT#\n        }\n",
        "            templateOptions: #DEFAULT#\n            cssClasses: [\n                thg-ohne-titel\n            ]\n        }\n", 1)
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
    s += item("P11_ARTI_NAME", "textField", "Name", 10, st, col="ARTI_NAME", req=True, maxlen=200, spalten=5)
    s += item("P11_ARTI_VK_PREIS", "numberField", "Verkaufspreis", 20, st, col="ARTI_VK_PREIS", dtype="number",
              req=True, neue_zeile=False, spalten=2,
              extra="        default {\n            type: static\n            staticValue: 0\n        }\n")
    s += item("P11_ARTI_IST_BRUTTO", "switch", "brutto", 30, st, col="ARTI_IST_BRUTTO", neue_zeile=False, spalten=1,
              extra=SWITCH("N"))
    s += item("P11_ARTI_IST_AKTIV", "switch", "Aktiv", 35, st,
              col="ARTI_IST_AKTIV", neue_zeile=False, spalten=2, extra=SWITCH("Y"))
    s += item("P11_ARTI_BILD", "imageUpload", "Artikelbild", 40, st, col="ARTI_BILD", dtype="blob",
              neue_zeile=False, spalten=2)
    s += item("P11_ARTI_NUMMER", "textField", "Nummer", 50, st, col="ARTI_NUMMER", req=True, maxlen=30, spalten=6,
              extra="""        default {
            type: sqlQuerySingleValue
            sqlQuerySingleValue:
                ```sql
                select to_char(nvl(max(to_number(ARTI_NUMMER default null on conversion error)), 0) + 1)
                  from ARTI_ARTIKEL
                ```
        }
""")
    s += item("P11_ARTI_EINH_ID", "selectList", "Einheit", 60, st, col="ARTI_EINH_ID", dtype="number",
              neue_zeile=False, spalten=3, extra=lov("lov-einheiten", "-"))
    s += item("P11_ARTI_AGRP_ID", "selectList", "Gruppe", 70, st, col="ARTI_AGRP_ID", dtype="number", spalten=6,
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

    zf = "tab-zusatzfelder"
    s += item("P11_ARTI_EAN", "textField", "Barcode EAN", 10, zf, col="ARTI_EAN", maxlen=20, spalten=3)
    s += item("P11_ARTI_AUFGENOMMEN_AM", "datePicker", "Aufgenommen am", 20, zf, col="ARTI_AUFGENOMMEN_AM",
              dtype="date", req=True, neue_zeile=False, spalten=3,
              extra="        default {\n            type: expression\n            language: plsql\n"
                    "            plsqlExpression: trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))\n        }\n")
    s += item("P11_ARTI_EK_PREIS", "numberField", "Einkaufspreis netto", 30, zf, col="ARTI_EK_PREIS",
              dtype="number", neue_zeile=False, spalten=2)
    s += item("P11_ARTI_ERLOESKONTO", "textField", "Erlöskonto", 40, zf, col="ARTI_ERLOESKONTO", maxlen=20,
              neue_zeile=False, spalten=2)

    # Zusatzfelder 1-10 (Grid: je aktivem Feld eine Zeile, Wert direkt editierbar)
    s += f"""    region zusatzwerte (
        name: Zusatzfelder
        type: interactiveGrid
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select z.ZUSF_ID,
                       z.ZUSF_NUMMER,
                       z.ZUSF_BEZEICHNUNG,
                       (select w.AZUW_WERT
                          from ARTI_ARTIKEL_ZUSATZWERTE w
                         where w.AZUW_ARTI_ID = :P11_ARTI_ID
                           and w.AZUW_ZUSF_ID = z.ZUSF_ID) as AZUW_WERT
                  from ARTI_ZUSATZFELDER z
                 where z.ZUSF_IST_AKTIV = 'Y'
                 order by z.ZUSF_NUMMER
                ```
            pageItemsToSubmit: [
                P11_ARTI_ID
            ]
        }}
        layout {{
            sequence: 60
            parentRegion: @{zf}
            slot: subRegions
        }}
        appearance {{
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }}
        edit {{
            enabled: true
            allowedOperations: [
                update
            ]
        }}
        serverSideCondition {{
            type: itemIsNotNull
            item: P11_ARTI_ID
        }}

        savedReport PRIMARY (
            visibility: primary
            view {{
                default: grid
            }}
            singleRowView {{
                displayedColumns: true
            }}

            displayColumn (
                column: @ZUSF_BEZEICHNUNG
                layout {{
                    sequence: 1
                }}
            )
            displayColumn (
                column: @AZUW_WERT
                layout {{
                    sequence: 2
                }}
            )
        )

        column ZUSF_ID (
            type: hidden
            layout {{
                sequence: 10
            }}
            source {{
                databaseColumn: ZUSF_ID
                dataType: number
                primaryKey: true
            }}
        )

        column ZUSF_NUMMER (
            type: hidden
            layout {{
                sequence: 20
            }}
            source {{
                databaseColumn: ZUSF_NUMMER
                dataType: number
            }}
        )

        column ZUSF_BEZEICHNUNG (
            type: displayOnly
            heading {{
                heading: Feld
            }}
            layout {{
                sequence: 30
            }}
            source {{
                databaseColumn: ZUSF_BEZEICHNUNG
                dataType: varchar2
            }}
        )

        column AZUW_WERT (
            type: textField
            heading {{
                heading: Wert
            }}
            layout {{
                sequence: 40
            }}
            validation {{
                maxLength: 4000
            }}
            source {{
                databaseColumn: AZUW_WERT
                dataType: varchar2
            }}
        )
    )

"""
    # Dokumente: Belege, in denen der Artikel vorkommt (derzeit Rechnungen)
    s += f"""    region dokumente (
        name: Dokumente
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select r.RECH_ID,
                       initcap(r.RECH_STATUS) as STATUS,
                       'Rechnung' as TYP,
                       r.RECH_DATUM,
                       r.RECH_NUMMER,
                       r.RECH_BETREFF,
                       k.KUND_NUMMER,
                       coalesce(k.KUND_FIRMENNAME, k.KUND_NACHNAME || ' ' || k.KUND_VORNAME) as KUNDE,
                       r.RECH_SUMME_NETTO,
                       r.RECH_SUMME_BRUTTO
                  from FAKT_RECHNUNGEN r
                  join KUND_KUNDEN k on k.KUND_ID = r.RECH_KUND_ID
                 where exists (select 1 from FAKT_RECHNUNGSPOSITIONEN p
                                where p.RPOS_RECH_ID = r.RECH_ID and p.RPOS_ARTI_ID = :P11_ARTI_ID)
                 order by r.RECH_DATUM desc
                ```
            pageItemsToSubmit: [
                P11_ARTI_ID
            ]
        }}
        layout {{
            sequence: 10
            parentRegion: @tab-dokumente
            slot: subRegions
        }}
        appearance {{
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }}
        componentAppearance {{
            showNullValuesAs: -
        }}
        pagination {{
            type: rowRangesXToY
        }}
        messages {{
            whenNoDataFound: Der Artikel kommt in keinem Beleg vor.
        }}
{ir_spalten([("RECH_ID", "ID", "hidden", "NUMBER"), ("STATUS", "Status", "plainText", "STRING"),
             ("TYP", "Typ", "plainText", "STRING"), ("RECH_DATUM", "Datum", "plainText", "DATE"),
             ("RECH_NUMMER", "Nummer", "plainText", "STRING"), ("RECH_BETREFF", "Betreff", "plainText", "STRING"),
             ("KUND_NUMMER", "Kundennummer", "plainText", "STRING"), ("KUNDE", "Kunde", "plainText", "STRING"),
             ("RECH_SUMME_NETTO", "Summe netto", "plainText", "NUMBER",
              "            appearance {\n                formatMask: FML999G999G990D00\n            }\n"),
             ("RECH_SUMME_BRUTTO", "Summe brutto", "plainText", "NUMBER",
              "            appearance {\n                formatMask: FML999G999G990D00\n            }\n")]).rstrip()}

    )

"""
    # Dateien
    s += f"""    region dateien (
        name: Dateien
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select ADAT_ID,
                       ADAT_DATEINAME,
                       dbms_lob.getlength(ADAT_INHALT) as ADAT_INHALT,
                       ADAT_MIMETYPE,
                       round(ADAT_GROESSE / 1024, 1) as GROESSE_KB,
                       ADAT_BEMERKUNG,
                       ADAT_CREATED_ON,
                       ADAT_CREATED_BY
                  from ARTI_ARTIKEL_DATEIEN
                 where ADAT_ARTI_ID = :P11_ARTI_ID
                 order by ADAT_CREATED_ON desc
                ```
            pageItemsToSubmit: [
                P11_ARTI_ID
            ]
        }}
        layout {{
            sequence: 10
            parentRegion: @tab-dateien
            slot: subRegions
        }}
        appearance {{
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }}
        link {{
            linkColumn: customTarget
            target: {{
                page: 12
                items: {{
                    P12_ADAT_ID: #ADAT_ID#
                    P12_ADAT_ARTI_ID: &P11_ARTI_ID.
                }}
                clearCache: 12
            }}
            linkIcon: <span role="img" aria-label="Bearbeiten" class="fa fa-edit" title="Bearbeiten"></span>
        }}
        componentAppearance {{
            showNullValuesAs: -
        }}
        pagination {{
            type: rowRangesXToY
        }}
        messages {{
            whenNoDataFound: Keine Dateien vorhanden.
        }}
{ir_spalten([("ADAT_ID", "ID", "hidden", "NUMBER"), ("ADAT_DATEINAME", "Dateiname", "plainText", "STRING"),
             ("ADAT_INHALT", "Datei", "downloadBlob", "NUMBER", """            appearance {
                viewFileAs: attachment
                downloadText: Herunterladen
            }
            blobAttributes {
                tableName: ARTI_ARTIKEL_DATEIEN
                blobColumn: ADAT_INHALT
                primaryKeyColumn1: ADAT_ID
                mimeTypeColumn: ADAT_MIMETYPE
                filenameColumn: ADAT_DATEINAME
                lastUpdatedColumn: ADAT_UPDATED_ON
            }
"""),
             ("ADAT_MIMETYPE", "Typ", "plainText", "STRING"), ("GROESSE_KB", "Größe (KB)", "plainText", "NUMBER"),
             ("ADAT_BEMERKUNG", "Bemerkung", "plainText", "STRING"),
             ("ADAT_CREATED_ON", "Hinzugefügt am", "plainText", "TIMESTAMP"),
             ("ADAT_CREATED_BY", "Hinzugefügt von", "plainText", "STRING")]).rstrip()}

    )

"""
    # Buttons
    s += button("cancel", "CANCEL", "Abbrechen", 10, "breadcrumb", "next", options="[\n                #DEFAULT#\n                t-Button--noUI\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 10
            }
            warnOnUnsavedChanges: doNotCheck
""")
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
    s += button("datei-hinzufuegen", "DATEI", "Datei hinzufügen", 10, "tab-dateien", "edit", "@/text-with-icon",
                icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--iconRight\n                t-Button--small\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 12
                items: {
                    P12_ADAT_ARTI_ID: &P11_ARTI_ID.
                }
                clearCache: 12
            }
            warnOnUnsavedChanges: doNotCheck
""")
    # Dynamic Actions: Dateiliste nach Dialog aktualisieren
    for sid, sel, ziel in (("dateien-nach-dialog", "region: @dateien", "selectionType: region"),
                           ("dateien-nach-hinzufuegen", "button: @datei-hinzufuegen", "selectionType: button")):
        s += f"""    dynamicAction {sid} (
        name: Dateien nach Dialog aktualisieren
        execution {{
            sequence: 10
        }}
        when {{
            event: apexafterclosedialog
            {ziel}
            {sel}
        }}

        action {sid}-refresh (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @dateien
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

"""
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

    process zusatzwerte-speichern (
        name: Zusatzfelder speichern
        type: executeCode
        editableRegion: @zusatzwerte
        source {
            plsqlCode:
                ```plsql
                -- je Zusatzfeld: Wert speichern bzw. leeren Wert entfernen
                delete from ARTI_ARTIKEL_ZUSATZWERTE
                 where AZUW_ARTI_ID = :P11_ARTI_ID and AZUW_ZUSF_ID = :ZUSF_ID;
                if :AZUW_WERT is not null then
                    insert into ARTI_ARTIKEL_ZUSATZWERTE (AZUW_ARTI_ID, AZUW_ZUSF_ID, AZUW_WERT)
                    values (:P11_ARTI_ID, :ZUSF_ID, :AZUW_WERT);
                end if;
                ```
        }
        execution {
            sequence: 20
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


# --------------------------------------------------------------------------- Seite 12 Datei
def seite_12():
    s = KOPF(12, "Datei", "DATEI", modal=True)
    s += """    region buttons (
        name: Buttons
        type: staticContent
        layout {
            sequence: 20
            slot: dialogFooter
        }
        appearance {
            template: @/buttons-container
            templateOptions: #DEFAULT#
        }
        settings {
            outputAs: text
        }
    )

    region datei (
        name: Datei
        type: form
        source {
            location: localDatabase
            tableName: ARTI_ARTIKEL_DATEIEN
        }
        layout {
            sequence: 10
            slot: contentBody
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
        edit {
            enabled: true
            allowedOperations: [
                update
                delete
            ]
        }
    )

    pageItem P12_ADAT_ID (
        type: hidden
        layout {
            sequence: 1
            region: @datei
            slot: regionBody
        }
        source {
            formRegion: @datei
            column: ADAT_ID
            dataType: number
            primaryKey: true
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P12_ADAT_ARTI_ID (
        type: hidden
        layout {
            sequence: 2
            region: @datei
            slot: regionBody
        }
        source {
            formRegion: @datei
            column: ADAT_ARTI_ID
            dataType: number
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P12_ADAT_DATEINAME (
        type: displayOnly
        label {
            label: Datei
            alignment: left
        }
        layout {
            sequence: 10
            region: @datei
            slot: regionBody
            alignment: left
        }
        appearance {
            template: @/optional-floating
            templateOptions: #DEFAULT#
        }
        source {
            formRegion: @datei
            column: ADAT_DATEINAME
            dataType: varchar2
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P12_ADAT_ID
        }
    )

    pageItem P12_UPLOAD (
        type: fileUpload
        label {
            label: Datei auswählen
            alignment: left
        }
        layout {
            sequence: 20
            region: @datei
            slot: regionBody
            alignment: left
        }
        appearance {
            template: @/required-floating
            templateOptions: #DEFAULT#
        }
        display {
            displayAs: blockDropzone
            dropzoneTitle: Datei hierher ziehen
            dropzoneDesc: oder klicken zum Auswählen
        }
        storage {
            type: appTempFiles
        }
        validation {
            valueRequired: true
        }
        serverSideCondition {
            type: itemIsNull
            item: P12_ADAT_ID
        }
    )

"""
    s += item("P12_ADAT_BEMERKUNG", "textarea", "Bemerkung", 30, "datei", form="datei", col="ADAT_BEMERKUNG", maxlen=500)
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("delete", "DELETE", "Löschen", 20, "buttons", "delete",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
""", bedingung=NICHT_NULL("P12_ADAT_ID") + """        confirmation {
            message: Datei wirklich löschen?
            style: danger
        }
""")
    s += button("save", "SAVE", "Speichern", 30, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P12_ADAT_ID"))
    s += button("hochladen", "HOCHLADEN", "Hochladen", 40, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n", bedingung=NULL("P12_ADAT_ID"))
    s += """    dynamicAction cancel-dialog (
        name: Dialog abbrechen
        execution {
            sequence: 10
        }
        when {
            event: click
            selectionType: button
            button: @cancel
        }

        action native-dialog-cancel (
            action: cancelDialog
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

    process initialize-form-datei (
        name: Formular Datei initialisieren
        type: formInitialization
        formRegion: @datei
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process datei-hochladen (
        name: Datei hochladen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                insert into ARTI_ARTIKEL_DATEIEN (ADAT_ARTI_ID, ADAT_DATEINAME, ADAT_MIMETYPE, ADAT_INHALT, ADAT_BEMERKUNG)
                select :P12_ADAT_ARTI_ID, filename, mime_type, blob_content, :P12_ADAT_BEMERKUNG
                  from apex_application_temp_files
                 where name = :P12_UPLOAD;
                ```
        }
        execution {
            sequence: 10
        }
        serverSideCondition {
            whenButtonPressed: @hochladen
        }
    )

    process process-form-datei (
        name: Formular Datei verarbeiten
        type: formAutoRowProcessing
        formRegion: @datei
        execution {
            sequence: 20
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: SAVE,DELETE
        }
    )

    process close-dialog (
        name: Dialog schließen
        type: closeDialog
        execution {
            sequence: 50
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: HOCHLADEN,SAVE,DELETE
        }
    )

)
"""
    return s


# --------------------------------------------------------------------------- Startseite, Listen, Breadcrumbs
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
