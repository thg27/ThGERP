#!/usr/bin/env python3.13
"""Erzeugt die App THG-FINANZ (20050): Ausgangsrechnungen (Fakturierung, Tabellen FAKT_*).

Seiten: 1 Startseite, 10 Rechnungen (Liste), 11 Rechnung (Maske nach Kingbill: Allgemein, Kunde,
Texte, Positionen, Summen je Steuersatz, Zahlungen), 100 Wertelisten, 110/111 Nummernkreise.
Logik in der Datenbank: Package FAKT_RECHNUNG (21_finanz.sql).
Grundgeruest: Kopie von THG-ALLGEMEIN (beim ersten Lauf).
Aufruf:  python3.13 Apex/generator/gen_finanz.py   (f-Strings nach PEP 701)
"""
import re
import secrets
import shutil

import gen_artikel as ga
import gen_wertelisten_kunden as wl
from gen_artikel import (BREADCRUMB, KOPF, NICHT_NULL, NULL, SWITCH, button, ir_spalten, item, lov, region)

APEX = ga.APEX
FIN = APEX / "thg-finanz"
ALLG = APEX / "thg-allgemein"
BETRAG = "            appearance {\n                formatMask: FML999G999G990D00\n            }\n"

WL_FINANZ = [
    dict(seite=110, alias="NUMMERNKREISE", titel="Nummernkreise", einzahl="Nummernkreis",
         tabelle="FAKT_NUMMERNKREISE", pfx="NKRS", icon="fa-sort-numeric-asc",
         beschreibung="Belegnummern je Mandant, Belegart und Jahr (Format mit {JAHR} und {NR})",
         felder=[("MAND_ID", "Mandant", "select", True), ("BELEGART", "Belegart", "text", True),
                 ("JAHR", "Jahr", "number", True), ("FORMAT", "Format", "text", True),
                 ("LETZTE_NUMMER", "Zuletzt vergebene Nummer", "number", True)],
         lov="lov-mandanten",
         join=("ADMIN_MANDANTEN m on m.MAND_ID = t.NKRS_MAND_ID and m.MAND_ID = :MANDANT_ID", "m.MAND_KURZNAME"),
         order="m.MAND_SORTIERUNG, t.NKRS_BELEGART, t.NKRS_JAHR desc"),
]


def default_sql(sql):
    return f"""        default {{
            type: sqlQuerySingleValue
            sqlQuerySingleValue:
                ```sql
                {sql}
                ```
        }}
"""


# --------------------------------------------------------------------------- Seite 10 Rechnungen
def seite_10():
    s = KOPF(10, "Rechnungen", "RECHNUNGEN") + BREADCRUMB("Rechnungen")
    s += f"""    region rechnungen (
        name: Rechnungen &MANDANT_NAME.
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select RECH_ID,
                       MAND_KURZNAME as MANDANT,
                       RECH_NUMMER,
                       initcap(RECH_STATUS) as STATUS,
                       RECH_DATUM,
                       RECH_FAELLIG_AM,
                       KUND_NUMMER,
                       KUNDE,
                       RECH_BETREFF,
                       RECH_LEISTUNGSZEITRAUM,
                       RECH_SUMME_NETTO,
                       RECH_SUMME_BRUTTO,
                       OFFEN,
                       case IST_UEBERFAELLIG when 'Y' then 'überfällig' end as UEBERFAELLIG
                  from FAKT_RECHNUNGEN_V
                 where RECH_MAND_ID = :MANDANT_ID
                 order by RECH_DATUM desc, RECH_NUMMER desc nulls first
                ```
        }}
        layout {{
            sequence: 10
            slot: body
        }}
        appearance {{
            template: @/interactive-report
            templateOptions: #DEFAULT#
        }}
        link {{
            linkColumn: customTarget
            target: {{
                page: 11
                items: {{
                    P11_RECH_ID: #RECH_ID#
                }}
                clearCache: 11
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
            whenNoDataFound: Keine Rechnungen vorhanden.
        }}
{ir_spalten([("RECH_ID", "ID", "hidden", "NUMBER"), ("MANDANT", "Mandant", "plainText", "STRING"),
             ("RECH_NUMMER", "Nummer", "plainText", "STRING"), ("STATUS", "Status", "plainText", "STRING"),
             ("RECH_DATUM", "Datum", "plainText", "DATE"), ("RECH_FAELLIG_AM", "Fällig am", "plainText", "DATE"),
             ("KUND_NUMMER", "Kundennr.", "plainText", "STRING"), ("KUNDE", "Kunde", "plainText", "STRING"),
             ("RECH_BETREFF", "Betreff", "plainText", "STRING"),
             ("RECH_LEISTUNGSZEITRAUM", "Leistungszeitraum", "plainText", "STRING"),
             ("RECH_SUMME_NETTO", "Netto", "plainText", "NUMBER", BETRAG),
             ("RECH_SUMME_BRUTTO", "Brutto", "plainText", "NUMBER", BETRAG),
             ("OFFEN", "Offen", "plainText", "NUMBER", BETRAG),
             ("UEBERFAELLIG", "Überfällig", "plainText", "STRING")]).rstrip()}

    )

"""
    s += button("reset-report", "RESET_REPORT", "Zurücksetzen", 10, "breadcrumb", "next", "@/text-with-icon",
                verhalten="""            action: redirectThisApp
            target: {
                page: &APP_PAGE_ID.
                clearCache: &APP_PAGE_ID.
                action: resetRegions
            }
            warnOnUnsavedChanges: doNotCheck
""", icon="fa-undo-alt", options="[\n                t-Button--noUI\n                t-Button--iconLeft\n                t-Button--gapRight\n            ]")
    s += button("neue-rechnung", "CREATE", "Neue Rechnung", 20, "breadcrumb", "next", "@/text-with-icon", hot=True,
                verhalten="""            action: redirectThisApp
            target: {
                page: 11
                clearCache: 11
            }
            warnOnUnsavedChanges: doNotCheck
""", icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--iconRight\n            ]")
    return s + ")\n"


# --------------------------------------------------------------------------- Seite 11 Rechnung
def ig_spalte(name, typ, heading, seq, dtype, extra="", pk=False, readonly=False):
    kopf = "" if typ == "hidden" else f"""            heading {{
                heading: {heading}
            }}
"""
    s = f"""        column {name} (
            type: {typ}
{kopf}            layout {{
                sequence: {seq}
            }}
            source {{
                databaseColumn: {name}
                dataType: {dtype}
""" + ("                primaryKey: true\n" if pk else "") + "            }\n"
    if readonly:
        s += "            readOnly {\n                type: always\n            }\n"
    return s + extra + "        )\n\n"


IG_LOV = lambda sid, null=True: f"""            lov {{
                type: sharedComponent
                lov: @{sid}
                displayNullValue: {'true' if null else 'false'}
                displayExtraValues: false
            }}
"""
IG_DEFAULT = lambda wert: f"""            default {{
                type: static
                staticValue: {wert}
            }}
"""


def ig_region(sid, name, seq, sql, spalten, anzeige, bedingung, ops="add\n                update\n                delete"):
    disp = "".join(f"""            displayColumn (
                column: @{c}
                layout {{
                    sequence: {i}
                }}
            )
""" for i, c in enumerate(["APEX$ROW_ACTION"] + anzeige))
    return f"""    region {sid} (
        name: {name}
        type: interactiveGrid
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
{sql}
                ```
            pageItemsToSubmit: [
                P11_RECH_ID
            ]
        }}
        layout {{
            sequence: {seq}
            slot: body
        }}
        appearance {{
            template: @/standard
            templateOptions: #DEFAULT#
        }}
        edit {{
            enabled: true
            allowedOperations: [
                {ops}
            ]
        }}
        toolbar {{
            controls: [
                actionsMenu
                saveButton
            ]
        }}
{bedingung}
        savedReport PRIMARY (
            visibility: primary
            view {{
                default: grid
            }}
            singleRowView {{
                displayedColumns: true
            }}

{disp}        )

        column APEX$ROW_ACTION (
            type: actionsMenu
            layout {{
                sequence: 5
            }}
        )

{spalten}    )

"""


def seite_11():
    s = KOPF(11, "Rechnung", "RECHNUNG").replace("title: Rechnung", "title: &P11_TITEL.")
    s += BREADCRUMB("&P11_TITEL.")
    s += """    region rechnung (
        name: Rechnung
        type: form
        source {
            location: localDatabase
            tableName: FAKT_RECHNUNGEN
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
                delete
            ]
        }
    )

"""
    s += region("allgemein", "1. Allgemein", 10, parent="rechnung")
    s += region("kunde", "2. Kunde", 20, parent="rechnung")
    s += region("details", "Texte", 30, template="@/tabs-container", parent="rechnung")
    s += region("tab-zahlungsbed", "Zahlungsbedingungen", 10, parent="details")
    s += region("tab-vortext", "Vortext", 20, parent="details")
    s += region("tab-schlusstext", "Schlusstext", 30, parent="details")
    s += region("tab-lieferadresse", "Lieferadresse", 40, parent="details")

    f = dict(form="rechnung")
    s += """    pageItem P11_RECH_ID (
        type: hidden
        layout {
            sequence: 1
            region: @allgemein
            slot: regionBody
        }
        source {
            formRegion: @rechnung
            column: RECH_ID
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
            region: @allgemein
            slot: regionBody
        }
    )

    pageItem P11_KUND_ID_ALT (
        type: hidden
        layout {
            sequence: 3
            region: @kunde
            slot: regionBody
        }
    )

"""
    a = "allgemein"
    s += item("P11_RECH_BETREFF", "textField", "Betreff (leer: „Rechnung <Nummer>“)", 10, a, col="RECH_BETREFF",
              maxlen=200, spalten=6, **f)
    s += item("P11_RECH_DATUM", "datePicker", "Datum", 20, a, col="RECH_DATUM", dtype="date", req=True,
              neue_zeile=False, spalten=3, extra="""        default {
            type: expression
            language: plsql
            plsqlExpression: trunc(sysdate)
        }
""", **f)
    s += item("P11_RECH_FAELLIG_AM", "datePicker", "Fällig am (leer: aus Zahlungsbedingung)", 30, a,
              col="RECH_FAELLIG_AM", dtype="date", neue_zeile=False, spalten=3, **f)
    s += item("P11_RECH_LEISTUNGSZEITRAUM", "textField", "Leistungszeitraum", 40, a, col="RECH_LEISTUNGSZEITRAUM",
              maxlen=100, spalten=6, **f)
    s += item("P11_RECH_REFERENZ", "textField", "Referenz", 50, a, col="RECH_REFERENZ", maxlen=200,
              neue_zeile=False, spalten=6, **f)
    s += """    pageItem P11_RECH_MAND_ID (
        type: hidden
        layout {
            sequence: 60
            region: @allgemein
            slot: regionBody
        }
        source {
            formRegion: @rechnung
            column: RECH_MAND_ID
            dataType: number
        }
        default {
            type: item
            item: MANDANT_ID
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P11_MANDANT (
        type: displayOnly
        label {
            label: Mandant (Wechsel im Portal)
            alignment: left
        }
        layout {
            sequence: 61
            region: @allgemein
            slot: regionBody
            columnSpan: 4
            alignment: left
        }
        appearance {
            template: @/optional-floating
            templateOptions: #DEFAULT#
        }
    )

"""
    s += item("P11_RECH_MITA_ID", "selectList", "Bearbeiter", 70, a, col="RECH_MITA_ID", dtype="number",
              neue_zeile=False, spalten=4, extra=lov("lov-mitarbeiter", "-") + default_sql(
                  "select MITA_ID from ALLG_MITARBEITER where MITA_BENUTZERNAME = :APP_USER"), **f)
    s += item("P11_RECH_PROJEKT", "textField", "Projekt", 80, a, col="RECH_PROJEKT", maxlen=200,
              neue_zeile=False, spalten=4, **f)
    s += item("P11_RECH_IST_BRUTTO", "switch", "Preise sind brutto", 90, a, col="RECH_IST_BRUTTO", spalten=3,
              extra=SWITCH("N"), **f)
    s += item("P11_RECH_IST_FAELLIGKEIT_ANZEIGEN", "switch", "Fälligkeit anzeigen", 100, a,
              col="RECH_IST_FAELLIGKEIT_ANZEIGEN", neue_zeile=False, spalten=3, extra=SWITCH("N"), **f)
    s += item("P11_RECH_NUMMER", "displayOnly", "Rechnungsnummer", 110, a, col="RECH_NUMMER",
              neue_zeile=False, spalten=3, **f)
    s += item("P11_RECH_STATUS", "displayOnly", "Status", 120, a, col="RECH_STATUS", neue_zeile=False, spalten=3,
              extra="""        default {
            type: static
            staticValue: ENTWURF
        }
""", **f)

    k = "kunde"
    s += item("P11_RECH_KUND_ID", "selectList", "Kunde", 10, k, col="RECH_KUND_ID", dtype="number", req=True,
              spalten=6, extra=lov("lov-kunden", "- Kunde wählen -"), **f)
    s += item("P11_RECH_ZBED_ID", "selectList", "Zahlungsbedingung (leer: vom Kunden)", 20, k, col="RECH_ZBED_ID",
              dtype="number", neue_zeile=False, spalten=3, extra=lov("lov-zahlungsbedingungen", "-"), **f)
    s += item("P11_RECH_IST_OHNE_MWST", "switch", "Keine MwSt. (Reverse Charge)", 30, k, col="RECH_IST_OHNE_MWST",
              neue_zeile=False, spalten=3, extra=SWITCH("N"), **f)
    s += """    pageItem P11_HINWEIS_EMPFAENGER (
        type: displayOnly
        layout {
            sequence: 35
            region: @kunde
            slot: regionBody
        }
        appearance {
            template: @/hidden
            templateOptions: #DEFAULT#
        }
        default {
            type: static
            staticValue: Anschrift, UID und Kontaktperson werden beim Speichern aus dem Kundenstamm übernommen, wenn der Kunde gewählt oder geändert wurde; danach hier änderbar.
        }
    )

"""
    s += item("P11_RECH_EMPF_ANREDE", "textField", "Anrede", 40, k, col="RECH_EMPF_ANREDE", maxlen=30, spalten=2, **f)
    s += item("P11_RECH_EMPF_NAME", "textarea", "Kunde (Anschrift)", 50, k, col="RECH_EMPF_NAME", maxlen=400,
              neue_zeile=False, spalten=4, **f)
    s += item("P11_RECH_EMPF_KONTAKTPERSON", "textField", "Kontaktperson", 60, k, col="RECH_EMPF_KONTAKTPERSON",
              maxlen=200, neue_zeile=False, spalten=3, **f)
    s += item("P11_RECH_EMPF_UID_NUMMER", "textField", "UID-Nr.", 70, k, col="RECH_EMPF_UID_NUMMER", maxlen=20,
              neue_zeile=False, spalten=3, **f)
    s += item("P11_RECH_EMPF_STRASSE", "textField", "Adresse", 80, k, col="RECH_EMPF_STRASSE", maxlen=250,
              spalten=6, **f)
    s += item("P11_RECH_EMPF_PLZ", "textField", "PLZ", 90, k, col="RECH_EMPF_PLZ", maxlen=10, neue_zeile=False,
              spalten=1, **f)
    s += item("P11_RECH_EMPF_ORT", "textField", "Ort", 100, k, col="RECH_EMPF_ORT", maxlen=100, neue_zeile=False,
              spalten=3, **f)
    s += item("P11_RECH_EMPF_LAND_CODE", "selectList", "Land", 110, k, col="RECH_EMPF_LAND_CODE",
              neue_zeile=False, spalten=2, extra=lov("lov-laender", "-"), **f)

    txt = lambda art: default_sql(f"select TXVL_TEXT from ALLG_TEXTVORLAGEN where TXVL_ART = '{art}' and TXVL_IST_STANDARD = 'Y'")
    s += item("P11_RECH_ZAHLUNGSBED_TEXT", "textarea", "Zahlungsbedingungen", 10, "tab-zahlungsbed",
              col="RECH_ZAHLUNGSBED_TEXT", dtype="clob", spalten=12, extra=txt("ZAHLUNGSBED"), **f)
    s += item("P11_RECH_VORTEXT", "textarea", "Vortext", 10, "tab-vortext", col="RECH_VORTEXT", dtype="clob",
              spalten=12, extra=txt("VORTEXT"), **f)
    s += item("P11_RECH_SCHLUSSTEXT", "textarea", "Schlusstext", 10, "tab-schlusstext", col="RECH_SCHLUSSTEXT",
              dtype="clob", spalten=12, extra=txt("SCHLUSSTEXT"), **f)
    s += item("P11_RECH_LIEFERADRESSE", "textarea", "Lieferadresse", 10, "tab-lieferadresse",
              col="RECH_LIEFERADRESSE", maxlen=1000, spalten=12, **f)

    # ------------------------------------------------ 3. Artikel (Positionen)
    pos = (ig_spalte("RPOS_ID", "hidden", "ID", 10, "number", pk=True)
           + ig_spalte("RPOS_POSITION", "numberField", "Pos", 20, "number")
           + ig_spalte("RPOS_KAPITEL", "textField", "Kapitel", 30, "varchar2")
           + ig_spalte("RPOS_UNTERKAPITEL", "textField", "Unterkapitel", 40, "varchar2")
           + ig_spalte("RPOS_ARTI_ID", "selectList", "Artikel", 50, "number", IG_LOV("lov-artikel"))
           + ig_spalte("RPOS_NAME", "textField", "Name (leer: vom Artikel)", 60, "varchar2")
           + ig_spalte("RPOS_MENGE", "numberField", "Menge", 70, "number", IG_DEFAULT(1))
           + ig_spalte("RPOS_EINHEIT", "selectList", "Einheit", 80, "varchar2", IG_LOV("lov-einheiten-code"))
           + ig_spalte("RPOS_EINZELPREIS", "numberField", "Einzelpreis (leer: vom Artikel)", 90, "number")
           + ig_spalte("RPOS_RABATT_PROZENT", "numberField", "Rabatt %", 100, "number")
           + ig_spalte("RPOS_MWST_PROZENT", "selectList", "MwSt. %", 110, "number", IG_LOV("lov-mwst-prozent"))
           + ig_spalte("RPOS_IST_OPTIONAL", "selectList", "Optional", 120, "varchar2",
                       IG_LOV("lov-ja-nein", False) + IG_DEFAULT("N"))
           + ig_spalte("RPOS_SUMME", "numberField", "Summe", 130, "number", readonly=True)
           + ig_spalte("RPOS_BESCHREIBUNG", "textarea", "Beschreibung (leer: vom Artikel)", 140, "clob"))
    s += ig_region("positionen", "3. Artikel (Positionen)", 40, """                select RPOS_ID, RPOS_POSITION, RPOS_KAPITEL, RPOS_UNTERKAPITEL, RPOS_ARTI_ID, RPOS_NAME,
                       RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT,
                       RPOS_IST_OPTIONAL, RPOS_SUMME, RPOS_BESCHREIBUNG
                  from FAKT_RECHNUNGSPOSITIONEN
                 where RPOS_RECH_ID = :P11_RECH_ID
                 order by RPOS_POSITION""", pos,
                   ["RPOS_POSITION", "RPOS_KAPITEL", "RPOS_ARTI_ID", "RPOS_NAME", "RPOS_MENGE", "RPOS_EINHEIT",
                    "RPOS_EINZELPREIS", "RPOS_RABATT_PROZENT", "RPOS_MWST_PROZENT", "RPOS_IST_OPTIONAL", "RPOS_SUMME"],
                   NICHT_NULL("P11_RECH_ID"))

    # ------------------------------------------------ Summen je Steuersatz
    s += f"""    region summen (
        name: Summen
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select 1 as SORT, 'Netto' as ZEILE, sum(NETTO) as BETRAG from FAKT_RECHNUNG_MWST_V where RECH_ID = :P11_RECH_ID
                union all
                select 2, to_char(MWST_PROZENT, 'FM990') || ' % MwSt.', MWST from FAKT_RECHNUNG_MWST_V where RECH_ID = :P11_RECH_ID
                union all
                select 3, 'Gesamtbetrag', sum(NETTO + MWST) from FAKT_RECHNUNG_MWST_V where RECH_ID = :P11_RECH_ID
                union all
                select 4, 'Bezahlt', BEZAHLT from FAKT_RECHNUNGEN_V where RECH_ID = :P11_RECH_ID and RECH_STATUS <> 'ENTWURF'
                union all
                select 5, 'Offen', OFFEN from FAKT_RECHNUNGEN_V where RECH_ID = :P11_RECH_ID and RECH_STATUS <> 'ENTWURF'
                order by 1, 2
                ```
            pageItemsToSubmit: [
                P11_RECH_ID
            ]
        }}
        layout {{
            sequence: 50
            slot: body
        }}
        appearance {{
            template: @/standard
            templateOptions: #DEFAULT#
        }}
        componentAppearance {{
            showNullValuesAs: -
        }}
        pagination {{
            type: rowRangesXToY
        }}
        messages {{
            whenNoDataFound: Noch keine Positionen.
        }}
{NICHT_NULL("P11_RECH_ID")}{ir_spalten([("SORT", "Sort", "hidden", "NUMBER"), ("ZEILE", "Position", "plainText", "STRING"),
                ("BETRAG", "Betrag", "plainText", "NUMBER", BETRAG)]).rstrip()}

    )

"""
    # ------------------------------------------------ Zahlungen
    zahl = (ig_spalte("ZAHL_ID", "hidden", "ID", 10, "number", pk=True)
            + ig_spalte("ZAHL_RECH_ID", "hidden", "Rechnung", 20, "number",
                        "            default {\n                type: item\n                item: P11_RECH_ID\n            }\n")
            + ig_spalte("ZAHL_DATUM", "datePicker", "Datum", 30, "date")
            + ig_spalte("ZAHL_BETRAG", "numberField", "Betrag", 40, "number")
            + ig_spalte("ZAHL_SKONTO", "numberField", "Skonto", 50, "number")
            + ig_spalte("ZAHL_MAHNSPESEN", "numberField", "Mahnspesen/Zinsen", 60, "number")
            + ig_spalte("ZAHL_BEMERKUNG", "textField", "Bemerkung", 70, "varchar2"))
    s += ig_region("zahlungen", "Zahlungen", 60, """                select ZAHL_ID, ZAHL_RECH_ID, ZAHL_DATUM, ZAHL_BETRAG, ZAHL_SKONTO, ZAHL_MAHNSPESEN, ZAHL_BEMERKUNG
                  from FAKT_ZAHLUNGEN
                 where ZAHL_RECH_ID = :P11_RECH_ID
                 order by ZAHL_DATUM""", zahl,
                   ["ZAHL_DATUM", "ZAHL_BETRAG", "ZAHL_SKONTO", "ZAHL_MAHNSPESEN", "ZAHL_BEMERKUNG"],
                   """        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_STATUS in ('OFFEN', 'BEZAHLT')
        }
""")

    # ------------------------------------------------ Buttons
    grau = "[\n                #DEFAULT#\n                t-Button--noUI\n            ]"
    s += button("cancel", "CANCEL", "Zur Liste", 10, "breadcrumb", "next", options=grau, verhalten="""            action: redirectThisApp
            target: {
                page: 10
            }
            warnOnUnsavedChanges: doNotCheck
""")
    entwurf = """        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS = 'ENTWURF'
        }
"""
    s += button("delete", "DELETE", "Rechnung löschen", 15, "breadcrumb", "next",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            requiresConfirmation: true
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and (:P11_RECH_STATUS = 'ENTWURF' or FAKT_RECHNUNG.ist_letzte(:P11_RECH_ID) = 'Y')
        }
        confirmation {
            message: Rechnung &P11_RECH_NUMMER. wirklich löschen? Positionen und Zahlungen werden mitgelöscht; bei einer abgeschlossenen Rechnung wird die Nummer wieder frei.
            style: danger
        }
""")
    s += button("save", "SAVE", "Speichern", 20, "breadcrumb", "next", hot=False,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P11_RECH_ID"))
    s += button("abschliessen", "ABSCHLIESSEN", "Rechnung abschließen", 25, "breadcrumb", "next", hot=True,
                verhalten="""            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
            requiresConfirmation: true
""", bedingung=entwurf + """        confirmation {
            message: Rechnung abschließen? Die Rechnungsnummer wird vergeben und kann nicht mehr geändert werden.
            style: warning
        }
""")
    s += button("create", "CREATE", "Anlegen", 30, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P11_RECH_ID"))
    s += button("up", "UP", "Zurück zur Rechnungsliste", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options=grau, verhalten="""            action: redirectThisApp
            target: {
                page: 10
            }
            warnOnUnsavedChanges: doNotCheck
""")

    # ------------------------------------------------ Prozesse
    s += """    process initialize-form-rechnung (
        name: Formular Rechnung initialisieren
        type: formInitialization
        formRegion: @rechnung
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process mandant-pruefen (
        name: Rechnung gehört zum Mandanten der Sitzung
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                if :P11_RECH_MAND_ID <> :MANDANT_ID then
                    raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                end if;
                ```
        }
        execution {
            sequence: 15
            point: beforeHeader
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P11_RECH_ID
        }
    )

    process titel-setzen (
        name: Seitentitel und Kunde merken
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                :P11_TITEL := case when :P11_RECH_ID is null then 'Neue Rechnung'
                                   when :P11_RECH_NUMMER is null then 'Rechnungsentwurf'
                                   else 'Rechnung ' || :P11_RECH_NUMMER end;
                :P11_KUND_ID_ALT := :P11_RECH_KUND_ID;
                select max(MAND_KURZNAME) into :P11_MANDANT from ADMIN_MANDANTEN where MAND_ID = coalesce(:P11_RECH_MAND_ID, :MANDANT_ID);
                ```
        }
        execution {
            sequence: 20
            point: beforeHeader
        }
    )

    process rechnung-loeschen (
        name: Rechnung löschen (Entwurf oder letzte Rechnung)
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                FAKT_RECHNUNG.loeschen(:P11_RECH_ID);
                ```
        }
        execution {
            sequence: 5
        }
        serverSideCondition {
            whenButtonPressed: @delete
        }
        successMessage {
            successMessage: Rechnung gelöscht.
        }
    )

    process process-form-rechnung (
        name: Formular Rechnung verarbeiten
        type: formAutoRowProcessing
        formRegion: @rechnung
        execution {
            sequence: 10
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: CREATE,SAVE,ABSCHLIESSEN
        }
    )

    process empfaenger-uebernehmen (
        name: Empfänger vom Kunden übernehmen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                FAKT_RECHNUNG.empfaenger_uebernehmen(:P11_RECH_ID);
                ```
        }
        execution {
            sequence: 20
        }
        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :REQUEST in ('CREATE', 'SAVE', 'ABSCHLIESSEN') and :P11_RECH_KUND_ID <> nvl(:P11_KUND_ID_ALT, -1)
        }
    )

    process positionen-speichern (
        name: Positionen speichern (Werte vom Artikel übernehmen)
        type: executeCode
        editableRegion: @positionen
        source {
            plsqlCode:
                ```plsql
                -- Positionen nur im Entwurf aenderbar; leere Felder werden vom Artikel uebernommen
                declare
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                    a        ARTI_ARTIKEL%rowtype;
                    l_mwst   ALLG_MWST_SAETZE.MWST_PROZENT%type;
                    l_einh   ALLG_EINHEITEN.EINH_CODE%type;
                    l_pos    number := :RPOS_POSITION;
                begin
                    select RECH_STATUS into l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_status <> 'ENTWURF' then
                        raise_application_error(-20210, 'Positionen können nur im Entwurf geändert werden.');
                    end if;
                    if :APEX$ROW_STATUS = 'D' then
                        delete from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = :RPOS_ID;
                        return;
                    end if;
                    if :RPOS_ARTI_ID is not null then
                        select * into a from ARTI_ARTIKEL where ARTI_ID = :RPOS_ARTI_ID;
                        select MWST_PROZENT into l_mwst from ALLG_MWST_SAETZE where MWST_ID = a.ARTI_MWST_ID;
                        select max(EINH_CODE) into l_einh from ALLG_EINHEITEN where EINH_ID = a.ARTI_EINH_ID;
                    end if;
                    if l_pos is null then
                        select nvl(max(RPOS_POSITION), 0) + 1 into l_pos
                          from FAKT_RECHNUNGSPOSITIONEN where RPOS_RECH_ID = :P11_RECH_ID;
                    end if;
                    if :APEX$ROW_STATUS = 'C' then
                        insert into FAKT_RECHNUNGSPOSITIONEN
                              (RPOS_RECH_ID, RPOS_ARTI_ID, RPOS_POSITION, RPOS_KAPITEL, RPOS_UNTERKAPITEL, RPOS_ARTIKELNUMMER,
                               RPOS_NAME, RPOS_BESCHREIBUNG, RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT,
                               RPOS_MWST_PROZENT, RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO)
                        values (:P11_RECH_ID, :RPOS_ARTI_ID, l_pos, :RPOS_KAPITEL, :RPOS_UNTERKAPITEL, a.ARTI_NUMMER,
                                coalesce(:RPOS_NAME, a.ARTI_NAME), coalesce(:RPOS_BESCHREIBUNG, a.ARTI_BESCHREIBUNG),
                                nvl(:RPOS_MENGE, 1), coalesce(:RPOS_EINHEIT, l_einh), coalesce(:RPOS_EINZELPREIS, a.ARTI_VK_PREIS, 0),
                                :RPOS_RABATT_PROZENT, coalesce(:RPOS_MWST_PROZENT, l_mwst, 20), nvl(:RPOS_IST_OPTIONAL, 'N'),
                                a.ARTI_ERLOESKONTO)
                        returning RPOS_ID into :RPOS_ID;
                    else
                        update FAKT_RECHNUNGSPOSITIONEN
                           set RPOS_ARTI_ID        = :RPOS_ARTI_ID,
                               RPOS_POSITION       = l_pos,
                               RPOS_KAPITEL        = :RPOS_KAPITEL,
                               RPOS_UNTERKAPITEL   = :RPOS_UNTERKAPITEL,
                               RPOS_ARTIKELNUMMER  = coalesce(a.ARTI_NUMMER, RPOS_ARTIKELNUMMER),
                               RPOS_NAME           = coalesce(:RPOS_NAME, a.ARTI_NAME, RPOS_NAME),
                               RPOS_BESCHREIBUNG   = coalesce(:RPOS_BESCHREIBUNG, a.ARTI_BESCHREIBUNG),
                               RPOS_MENGE          = nvl(:RPOS_MENGE, 1),
                               RPOS_EINHEIT        = coalesce(:RPOS_EINHEIT, l_einh),
                               RPOS_EINZELPREIS    = coalesce(:RPOS_EINZELPREIS, a.ARTI_VK_PREIS, 0),
                               RPOS_RABATT_PROZENT = :RPOS_RABATT_PROZENT,
                               RPOS_MWST_PROZENT   = coalesce(:RPOS_MWST_PROZENT, l_mwst, 20),
                               RPOS_IST_OPTIONAL   = nvl(:RPOS_IST_OPTIONAL, 'N')
                         where RPOS_ID = :RPOS_ID;
                    end if;
                end;
                ```
        }
        execution {
            sequence: 30
        }
    )

    process zahlungen-speichern (
        name: Zahlungen speichern
        type: interactiveGridAutoRowProcessing
        editableRegion: @zahlungen
        execution {
            sequence: 40
        }
    )

    process summen-berechnen (
        name: Summen und Zahlungsstatus
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                FAKT_RECHNUNG.summen_berechnen(:P11_RECH_ID);
                FAKT_RECHNUNG.zahlungsstatus(:P11_RECH_ID);
                ```
        }
        execution {
            sequence: 50
        }
        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :REQUEST <> 'DELETE'
        }
    )

    process abschliessen (
        name: Rechnung abschließen (Nummer vergeben)
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                FAKT_RECHNUNG.abschliessen(:P11_RECH_ID);
                ```
        }
        execution {
            sequence: 60
        }
        serverSideCondition {
            whenButtonPressed: @abschliessen
        }
        successMessage {
            successMessage: Rechnung abgeschlossen.
        }
    )

    branch zur-liste-nach-loeschen (
        name: Nach dem Löschen zur Liste
        execution {
            sequence: 10
        }
        behavior {
            target: {
                page: 10
            }
        }
        serverSideCondition {
            whenButtonPressed: @delete
        }
    )

    branch in-rechnung-bleiben (
        name: In der Rechnung bleiben
        execution {
            sequence: 20
        }
        behavior {
            target: {
                page: 11
                items: {
                    P11_RECH_ID: &P11_RECH_ID.
                }
            }
        }
    )

)
"""
    return s


# --------------------------------------------------------------------------- Startseite, Listen, Breadcrumbs
def startseite():
    return ga.startseite().replace("name: Artikelstamm\n        type: list", "name: Finanz\n        type: list")


def listen(lists_apx):
    s = lists_apx
    i = s.index("    entry look-up-values (")
    j = s.index("\n)", i)
    s = s[:i] + """    entry rechnungen (
        label: Rechnungen
        icon {
            imageIconCssClasses: fa-file-text-o
        }
        layout {
            sequence: 20
        }
        link {
            target: {
                page: 10
            }
        }
        isCurrent {
            type: pages
            pages: [
                10
                11
            ]
        }
    )

    entry wertelisten (
        label: Wertelisten
        icon {
            imageIconCssClasses: fa-list-ul
        }
        layout {
            sequence: 90
        }
        link {
            target: {
                page: 100
            }
        }
        isCurrent {
            type: pages
            pages: [
                100
                110
                111
            ]
        }
    )""" + s[j:]
    s = re.sub(r"\nlist admin-lookup-values \(.*?\n\)\n", "\n", s, flags=re.S)
    teile = [f"""select '{w['titel']}' as label, {w['seite']} as seite, '{w['icon']}' as image, '{w['beschreibung']}' as beschreibung,
                           (select count(*) from {w['tabelle']}) as anzahl
                      from dual""" for w in WL_FINANZ]
    trenner = "\n                    union all\n                    "
    return s.rstrip("\n") + f"""

list wertelisten-finanz (
    name: Wertelisten - Finanz
    source {{
        type: sqlQuery
        sqlQuery:
            ```sql
            select 1 as the_level,
                   label,
                   apex_page.get_url(p_page => seite, p_clear_cache => seite) as target,
                   null as is_current_list_entry,
                   image,
                   null as image_attribute,
                   null as image_alt_attribute,
                   beschreibung as attribute1,
                   to_char(anzahl) as attribute2
              from (
                    {trenner.join(teile)}
                   )
             order by seite
            ```
    }}
)

list startseite (
    name: Startseite
    source {{
        type: sqlQuery
        sqlQuery:
            ```sql
            select 1 as the_level,
                   label,
                   apex_page.get_url(p_page => seite, p_clear_cache => seite) as target,
                   null as is_current_list_entry,
                   image,
                   null as image_attribute,
                   null as image_alt_attribute,
                   beschreibung as attribute1,
                   anzahl as attribute2
              from (
                    select 'Rechnungen' as label, 10 as seite, 'fa-file-text-o' as image,
                           'Ausgangsrechnungen erfassen, abschließen und Zahlungen verbuchen' as beschreibung,
                           (select count(*) || ' offen' from FAKT_RECHNUNGEN where RECH_STATUS = 'OFFEN' and RECH_MAND_ID = :MANDANT_ID) as anzahl
                      from dual
                    union all
                    select 'Wertelisten', 100, 'fa-list-ul', 'Nummernkreise', null from dual
                   )
             order by seite
            ```
    }}
)
"""


def breadcrumbs():
    out = """breadcrumb breadcrumb (
    name: Breadcrumb

    entry home (
        name: Startseite
        pageNumber: 1
        execution {
            sequence: 10
        }
        link {
            target: {
                page: 1
            }
        }
    )

    entry rechnungen (
        name: Rechnungen
        pageNumber: 10
        execution {
            sequence: 20
        }
        appearance {
            parentEntry: @home
        }
        link {
            target: {
                page: 10
            }
        }
    )

    entry rechnung (
        name: Rechnung
        pageNumber: 11
        execution {
            sequence: 30
        }
        appearance {
            parentEntry: @rechnungen
        }
        link {
            target: {
                page: 11
            }
        }
    )
"""
    wl.WERTELISTEN = WL_FINANZ
    return out + wl.breadcrumb_eintraege() + ")\n"


LOVS_ABO = ["lov-mandanten", "lov-mitarbeiter", "lov-artikel", "lov-mwst-prozent", "lov-einheiten-code",
            "lov-kunden", "lov-zahlungsbedingungen", "lov-laender"]


def lovs_abonnieren():
    """Portal-LOVs kopieren und als Subscription kennzeichnen (Inhalt wie im Portal)."""
    portal = (APEX / "thg-portal" / "shared-components" / "lovs.apx").read_text(encoding="utf-8")
    p = FIN / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    for sid in LOVS_ABO:
        if f"lov {sid} (" in s:
            continue
        m = re.search(rf"lov {re.escape(sid)} \(.*?\n\)\n", portal, flags=re.S)
        blk = m.group(0).replace("    columnMapping {", f"    subscription {{\n        master: @/20000/{sid}\n    }}\n    columnMapping {{", 1)
        s = s.rstrip("\n") + "\n\n" + blk
    p.write_text(s, encoding="utf-8")


if __name__ == "__main__":
    if not FIN.exists():
        shutil.copytree(ALLG, FIN)
        for f in (FIN / "pages").glob("p001*.apx"):
            f.unlink()
    p = FIN / "application.apx"
    s = p.read_text(encoding="utf-8")
    s = (s.replace("app THG-ALLGEMEIN (", "app THG-FINANZ (").replace("name: ThG – Allgemein", "name: ThG – Finanz")
          .replace("        text: Allgemein\n", "        text: Finanz\n"))
    salz = re.search(r"checksumSalt: ([0-9A-F]+)", (ALLG / "application.apx").read_text(encoding="utf-8")).group(1)
    if salz in s:
        s = s.replace(salz, secrets.token_hex(32).upper())
    p.write_text(s, encoding="utf-8")
    p = FIN / "deployments" / "default.json"
    p.write_text(p.read_text(encoding="utf-8").replace('"id": 20010', '"id": 20050'), encoding="utf-8")
    p = FIN / "pages" / "p09999-login.apx"
    p.write_text(p.read_text(encoding="utf-8").replace("ThG – Allgemein", "ThG – Finanz"), encoding="utf-8")

    (FIN / "pages" / "p00001-home.apx").write_text(startseite(), encoding="utf-8")
    (FIN / "pages" / "p00010-rechnungen.apx").write_text(seite_10(), encoding="utf-8")
    (FIN / "pages" / "p00011-rechnung.apx").write_text(seite_11(), encoding="utf-8")
    (FIN / "pages" / "p00100-wertelisten.apx").write_text(
        wl.uebersicht("wertelisten-finanz", "Wertelisten Finanz"), encoding="utf-8")
    ga.wl_seiten(FIN, WL_FINANZ)
    lp = FIN / "shared-components" / "lists.apx"
    lp.write_text(listen((ALLG / "shared-components" / "lists.apx").read_text(encoding="utf-8")), encoding="utf-8")
    (FIN / "shared-components" / "breadcrumbs.apx").write_text(breadcrumbs(), encoding="utf-8")
    lovs_abonnieren()
    print("THG-FINANZ erzeugt")
