#!/usr/bin/env python3
"""Erzeugt die Pflegeseiten der Kunden-Wertelisten in App 20020 (THG-KUNDEN).

Je Werteliste: Berichtsseite (Interactive Report) + Bearbeitungsseite (Drawer).
Aufbau wie die Look-Up-Value-Seiten der Allgemein-App (20010).
Aufruf:  python3 Apex/generator/gen_wertelisten_kunden.py
Die Liste "wertelisten-kunden" (lists.apx) und die Breadcrumbs liefern liste_sql() und
breadcrumb_eintraege(); bei neuen Wertelisten dort ergaenzen.
Danach:  apex validate/import von thg-kunden (siehe CLAUDE.md).
"""
from pathlib import Path

APP = Path(__file__).resolve().parent.parent / "thg-kunden" / "pages"

# kind: text | number | switch | select   (select: lov = static-id der LOV)
WERTELISTEN = [
    dict(seite=110, alias="KUNDENGRUPPEN", titel="Kundengruppen", einzahl="Kundengruppe",
         tabelle="KUND_KUNDENGRUPPEN", pfx="KGRP", icon="fa-tags",
         beschreibung="Hauptgruppen der Kunden (OEM, Wiederverkäufer, Endkunde …)",
         felder=[("CODE", "Code", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("SORTIERUNG", "Sortierung", "number", False), ("IST_AKTIV", "Aktiv", "switch", True)],
         order="KGRP_SORTIERUNG nulls last, KGRP_BEZEICHNUNG"),
    dict(seite=120, alias="BRANCHEN", titel="Branchen", einzahl="Branche",
         tabelle="KUND_BRANCHEN", pfx="BRAN", icon="fa-industry",
         beschreibung="Branchen der Kunden",
         felder=[("BEZEICHNUNG", "Bezeichnung", "text", True), ("BEWERTUNG", "Bewertung", "number", False),
                 ("SORTIERUNG", "Sortierung", "number", False), ("IST_AKTIV", "Aktiv", "switch", True)],
         order="BRAN_SORTIERUNG nulls last, BRAN_BEZEICHNUNG"),
    dict(seite=130, alias="UNTERKATEGORIEN", titel="Unterkategorien", einzahl="Unterkategorie",
         tabelle="KUND_UNTERKATEGORIEN", pfx="UKAT", icon="fa-sitemap",
         beschreibung="Unterkategorien je Branche",
         felder=[("BRAN_ID", "Branche", "select", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("BEWERTUNG", "Bewertung", "number", False), ("SORTIERUNG", "Sortierung", "number", False),
                 ("IST_AKTIV", "Aktiv", "switch", True)],
         lov="lov-branchen",
         join=("KUND_BRANCHEN b on b.BRAN_ID = t.UKAT_BRAN_ID", "b.BRAN_BEZEICHNUNG"),
         order="b.BRAN_BEZEICHNUNG, t.UKAT_SORTIERUNG nulls last, t.UKAT_BEZEICHNUNG"),
    dict(seite=140, alias="ABTEILUNGEN", titel="Abteilungen", einzahl="Abteilung",
         tabelle="KUND_ABTEILUNGEN", pfx="ABTE", icon="fa-building-o",
         beschreibung="Abteilungen der Ansprechpersonen",
         felder=[("CODE", "Code", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("SORTIERUNG", "Sortierung", "number", False), ("IST_AKTIV", "Aktiv", "switch", True)],
         order="ABTE_SORTIERUNG nulls last, ABTE_BEZEICHNUNG"),
    dict(seite=150, alias="FUNKTIONEN", titel="Funktionen", einzahl="Funktion",
         tabelle="KUND_FUNKTIONEN", pfx="FUNK", icon="fa-id-badge",
         beschreibung="Funktionen der Ansprechpersonen (Geschäftsführer, Abteilungsleiter …)",
         felder=[("CODE", "Code", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("SORTIERUNG", "Sortierung", "number", False), ("IST_AKTIV", "Aktiv", "switch", True)],
         order="FUNK_SORTIERUNG nulls last, FUNK_BEZEICHNUNG"),
    dict(seite=160, alias="RECHTSFORMEN", titel="Rechtsformen", einzahl="Rechtsform",
         tabelle="KUND_RECHTSFORMEN", pfx="RFRM", icon="fa-bank",
         beschreibung="Rechtsformen von Firmenkunden (GmbH, KG, d.o.o. …)",
         felder=[("KURZ", "Kurzbezeichnung", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True)],
         order="RFRM_KURZ"),
    dict(seite=170, alias="STANDORTTYPEN", titel="Standorttypen", einzahl="Standorttyp",
         tabelle="KUND_STANDORT_TYPEN", pfx="STYP", icon="fa-map-marker",
         beschreibung="Hauptsitz, Filiale, Lager, Rechnungs-/Lieferadresse …",
         felder=[("BEZEICHNUNG", "Bezeichnung", "text", True)],
         order="STYP_BEZEICHNUNG"),
    dict(seite=180, alias="BETREUUNGSROLLEN", titel="Betreuungsrollen", einzahl="Betreuungsrolle",
         tabelle="KUND_BETREUUNGSROLLEN", pfx="BROL", icon="fa-users",
         beschreibung="Rollen der Mitarbeiter in der Kundenbetreuung",
         felder=[("CODE", "Code", "text", True), ("BEZEICHNUNG", "Bezeichnung", "text", True),
                 ("SORTIERUNG", "Sortierung", "number", False)],
         order="BROL_SORTIERUNG nulls last, BROL_BEZEICHNUNG"),
]


def bericht(w):
    s, p, t = w["seite"], w["pfx"], w["tabelle"]
    join = w.get("join")
    a = "t." if join else ""
    sel = [f"{a}{p}_ID"]
    cols = [(f"{p}_ID", "ID", "hidden", "NUMBER")]
    for col, label, kind, _ in w["felder"]:
        c = f"{p}_{col}"
        if kind == "select":
            sel.append(f"{join[1]} as {c}")
            cols.append((c, label, "plainText", "STRING"))
        elif kind in ("switch", "switchN"):
            sel.append(f"case {a}{c} when 'Y' then 'Ja' else 'Nein' end as {c}")
            cols.append((c, label, "plainText", "STRING"))
        elif kind == "textarea":
            sel.append(f"dbms_lob.substr({a}{c}, 200, 1) as {c}")
            cols.append((c, label, "plainText", "STRING"))
        else:
            sel.append(f"{a}{c}")
            cols.append((c, label, "plainText", "NUMBER" if kind == "number" else "STRING"))
    sel += [f"{a}{p}_UPDATED_ON", f"{a}{p}_UPDATED_BY"]
    cols += [(f"{p}_UPDATED_ON", "Geändert am", "plainText", "TIMESTAMP"),
             (f"{p}_UPDATED_BY", "Geändert von", "plainText", "STRING")]
    von = f"{t} t\n                  join {join[0]}" if join else t
    sql = ("select " + ",\n                       ".join(sel)
           + f"\n                  from {von}\n                 order by {w['order']}")
    spalten = ""
    for i, (c, h, typ, dt) in enumerate(cols, 1):
        spalten += f"""
        column {c} (
            type: {typ}
            heading {{
                heading: {h}
            }}
            layout {{
                sequence: {i * 10}
            }}
            source {{
                dataType: {dt}
            }}
        )
"""
    e = s + 1
    return f"""page {s} (
    name: {w['titel']}
    alias: {w['alias']}
    title: {w['titel']}
    pageGroup: @administration
    appearance {{
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }}
    navigation {{
        cursorFocus: doNotFocusCursor
    }}
    security {{
        authorizationScheme: @administration-rights
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }}

    region breadcrumb (
        name: Breadcrumb
        title: {w['titel']}
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

    region bericht (
        name: {w['titel']}
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                {sql}
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
                page: {e}
                items: {{
                    P{e}_{p}_ID: #{p}_ID#
                }}
                clearCache: {e}
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
            whenNoDataFound: Keine Einträge vorhanden.
        }}
{spalten}
    )

    button up (
        buttonName: UP
        label: Zurück zu Wertelisten
        layout {{
            sequence: 10
            region: @breadcrumb
            slot: up
        }}
        appearance {{
            buttonTemplate: @/icon
            templateOptions: [
                #DEFAULT#
                t-Button--noUI
            ]
            icon: fa-arrow-up
        }}
        behavior {{
            action: redirectThisApp
            target: {{
                page: 100
            }}
            warnOnUnsavedChanges: doNotCheck
        }}
    )

    button reset-report (
        buttonName: RESET_REPORT
        label: Zurücksetzen
        layout {{
            sequence: 10
            region: @breadcrumb
            slot: next
        }}
        appearance {{
            buttonTemplate: @/text-with-icon
            templateOptions: [
                t-Button--noUI
                t-Button--iconLeft
                t-Button--gapRight
            ]
            icon: fa-undo-alt
        }}
        behavior {{
            action: redirectThisApp
            target: {{
                page: &APP_PAGE_ID.
                clearCache: &APP_PAGE_ID.
                action: resetRegions
            }}
            warnOnUnsavedChanges: doNotCheck
        }}
    )

    button hinzufuegen (
        buttonName: CREATE
        label: {w['einzahl']} hinzufügen
        layout {{
            sequence: 20
            region: @breadcrumb
            slot: next
        }}
        appearance {{
            buttonTemplate: @/text-with-icon
            templateOptions: [
                #DEFAULT#
                t-Button--noUI
                t-Button--iconRight
            ]
            icon: fa-plus
        }}
        behavior {{
            action: redirectThisApp
            target: {{
                page: {e}
                clearCache: {e}
            }}
            warnOnUnsavedChanges: doNotCheck
        }}
    )

    dynamicAction refresh-nach-dialog (
        name: Bericht nach Dialog aktualisieren
        execution {{
            sequence: 10
        }}
        when {{
            event: apexafterclosedialog
            selectionType: region
            region: @bericht
        }}

        action refresh-bericht (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @bericht
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

    dynamicAction refresh-nach-hinzufuegen (
        name: Bericht nach Hinzufügen aktualisieren
        execution {{
            sequence: 20
        }}
        when {{
            event: apexafterclosedialog
            selectionType: button
            button: @hinzufuegen
        }}

        action refresh-bericht-2 (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @bericht
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

)
"""


def feld(w, e, i, col, label, kind, pflicht):
    p = w["pfx"]
    item = f"P{e}_{p}_{col}"
    typ = {"text": "textField", "number": "numberField", "switch": "switch", "switchN": "switch",
           "select": "selectList", "textarea": "textarea"}[kind]
    tmpl = "required-floating" if pflicht else "optional-floating"
    dt = "number" if kind in ("number", "select") else "varchar2"
    extra = ""
    if pflicht:
        extra += """
        validation {
            valueRequired: true
        }"""
    extra += f"""
        source {{
            formRegion: @formular
            column: {p}_{col}
            dataType: {dt}
        }}"""
    if kind in ("switch", "switchN"):
        extra += f"""
        settings {{
            useDefaults: false
            onValue: Y
            onLabel: Ja
            offValue: N
            offLabel: Nein
        }}
        default {{
            type: static
            staticValue: {"N" if kind == "switchN" else "Y"}
        }}"""
    if kind == "select":
        extra += f"""
        lov {{
            type: sharedComponent
            lov: @{w['lov']}
            displayNullValue: true
            nullDisplayValue: - bitte wählen -
        }}"""
    return f"""
    pageItem {item} (
        type: {typ}
        label {{
            label: {label}
            alignment: left
        }}
        layout {{
            sequence: {i * 10}
            region: @formular
            slot: regionBody
            alignment: left
        }}
        appearance {{
            template: @/{tmpl}
            templateOptions: #DEFAULT#
        }}{extra}
    )
"""


def bearbeiten(w):
    s, p = w["seite"], w["pfx"]
    e = s + 1
    felder = "".join(feld(w, e, i, *f) for i, f in enumerate(w["felder"], 1))
    return f"""page {e} (
    name: {w['einzahl']}
    alias: {w['alias']}-BEARBEITEN
    title: {w['einzahl']}
    pageGroup: @administration
    appearance {{
        pageMode: modalDialog
        dialogTemplate: @/drawer
        templateOptions: [
            #DEFAULT#
            js-dialog-class-t-Drawer--pullOutEnd
        ]
    }}
    dialog {{
        chained: false
        resizable: false
    }}
    navigation {{
        cursorFocus: firstItemOnPage
    }}
    security {{
        authorizationScheme: @administration-rights
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }}

    region buttons (
        name: Buttons
        type: staticContent
        layout {{
            sequence: 20
            slot: dialogFooter
        }}
        appearance {{
            template: @/buttons-container
            templateOptions: #DEFAULT#
        }}
        settings {{
            outputAs: text
        }}
    )

    region formular (
        name: {w['einzahl']}
        type: form
        source {{
            location: localDatabase
            tableName: {w['tabelle']}
        }}
        layout {{
            sequence: 10
            slot: contentBody
        }}
        appearance {{
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }}
        edit {{
            enabled: true
            allowedOperations: [
                add
                update
                delete
            ]
        }}
    )

    pageItem P{e}_{p}_ID (
        type: hidden
        layout {{
            sequence: 1
            region: @formular
            slot: regionBody
        }}
        source {{
            formRegion: @formular
            column: {p}_ID
            dataType: number
            primaryKey: true
        }}
        security {{
            sessionStateProtection: checksumRequiredSessionLevel
        }}
    )
{felder}
    button cancel (
        buttonName: CANCEL
        label: Abbrechen
        layout {{
            sequence: 10
            region: @buttons
            slot: close
        }}
        appearance {{
            buttonTemplate: @/text
            templateOptions: #DEFAULT#
        }}
        behavior {{
            action: definedByDynamicAction
        }}
    )

    button delete (
        buttonName: DELETE
        label: Löschen
        layout {{
            sequence: 20
            region: @buttons
            slot: delete
        }}
        appearance {{
            buttonTemplate: @/text
            templateOptions: [
                #DEFAULT#
                t-Button--danger
                t-Button--simple
            ]
        }}
        behavior {{
            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
        }}
        confirmation {{
            message: Eintrag wirklich löschen? Bereits verwendete Einträge können nicht gelöscht werden.
            style: danger
        }}
        serverSideCondition {{
            type: itemIsNotNull
            item: P{e}_{p}_ID
        }}
    )

    button save (
        buttonName: SAVE
        label: Speichern
        layout {{
            sequence: 30
            region: @buttons
            slot: next
        }}
        appearance {{
            buttonTemplate: @/text
            hot: true
            templateOptions: #DEFAULT#
        }}
        behavior {{
            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
        }}
        serverSideCondition {{
            type: itemIsNotNull
            item: P{e}_{p}_ID
        }}
    )

    button create (
        buttonName: CREATE
        label: Anlegen
        layout {{
            sequence: 40
            region: @buttons
            slot: next
        }}
        appearance {{
            buttonTemplate: @/text
            hot: true
            templateOptions: #DEFAULT#
        }}
        behavior {{
            warnOnUnsavedChanges: doNotCheck
            databaseAction: insert
        }}
        serverSideCondition {{
            type: itemIsNull
            item: P{e}_{p}_ID
        }}
    )

    dynamicAction cancel-dialog (
        name: Dialog abbrechen
        execution {{
            sequence: 10
        }}
        when {{
            event: click
            selectionType: button
            button: @cancel
        }}

        action native-dialog-cancel (
            action: cancelDialog
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

    process initialize-form (
        name: Formular initialisieren
        type: formInitialization
        formRegion: @formular
        execution {{
            sequence: 10
            point: beforeHeader
        }}
    )

    process process-form (
        name: Formular verarbeiten
        type: formAutoRowProcessing
        formRegion: @formular
        execution {{
            sequence: 10
        }}
    )

    process close-dialog (
        name: Dialog schließen
        type: closeDialog
        execution {{
            sequence: 50
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE,DELETE
        }}
    )

)
"""


def uebersicht(liste="wertelisten-kunden", region="Wertelisten zum Kunden"):
    return f"""page 100 (
    name: Wertelisten
    alias: WERTELISTEN
    title: Wertelisten
    pageGroup: @administration
    appearance {{
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }}
    navigation {{
        cursorFocus: doNotFocusCursor
    }}
    security {{
        authorizationScheme: @administration-rights
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }}

    region breadcrumb (
        name: Breadcrumb
        title: Wertelisten
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

    region wertelisten (
        name: {region}
        type: list
        source {{
            list: @{liste}
        }}
        layout {{
            sequence: 10
            slot: body
        }}
        appearance {{
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Region--noPadding
                t-Region--scrollBody
            ]
        }}
        componentAppearance {{
            listTemplate: @/media-list
            templateOptions: [
                #DEFAULT#
                t-MediaList--showBadges
            ]
        }}
    )

    button up (
        buttonName: UP
        label: Zurück zur Startseite
        layout {{
            sequence: 10
            region: @breadcrumb
            slot: up
        }}
        appearance {{
            buttonTemplate: @/icon
            templateOptions: [
                #DEFAULT#
                t-Button--noUI
            ]
            icon: fa-arrow-up
        }}
        behavior {{
            action: redirectThisApp
            target: {{
                page: 1
            }}
            warnOnUnsavedChanges: doNotCheck
        }}
    )

)
"""


def liste_sql():
    teile = []
    for w in WERTELISTEN:
        teile.append(
            f"select '{w['titel']}' as label, {w['seite']} as seite, '{w['icon']}' as image, "
            f"'{w['beschreibung']}' as beschreibung,\n"
            f"                           (select count(*) from {w['tabelle']}) as anzahl\n"
            f"                      from dual")
    return "\n                    union all\n                    ".join(teile)


def breadcrumb_eintraege():
    out = """
    entry wertelisten (
        name: Wertelisten
        pageNumber: 100
        execution {
            sequence: 100
        }
        appearance {
            parentEntry: @home
        }
        link {
            target: {
                page: 100
            }
        }
    )
"""
    for w in WERTELISTEN:
        s = w["seite"]
        out += f"""
    entry werteliste-{s} (
        name: {w['titel']}
        pageNumber: {s}
        execution {{
            sequence: {s}
        }}
        appearance {{
            parentEntry: @wertelisten
        }}
        link {{
            target: {{
                page: {s}
            }}
        }}
    )
"""
    return out


if __name__ == "__main__":
    (APP / "p00100-wertelisten.apx").write_text(uebersicht(), encoding="utf-8")
    for w in WERTELISTEN:
        s = w["seite"]
        name = w["alias"].lower()
        (APP / f"p{s:05d}-{name}.apx").write_text(bericht(w), encoding="utf-8")
        (APP / f"p{s + 1:05d}-{name}-bearbeiten.apx").write_text(bearbeiten(w), encoding="utf-8")
    print(f"{1 + 2 * len(WERTELISTEN)} Seiten erzeugt in {APP}")
