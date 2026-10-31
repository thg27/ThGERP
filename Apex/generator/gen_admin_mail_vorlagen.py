#!/usr/bin/env python3.13
"""E-Mail-Templates in THG-ADMIN (20030): Seite 40 E-Mail-Templates (Liste), Seite 41 E-Mail-Template (Dialog).

Vorlagen (FAKT_MAIL_VORLAGEN, DDL 48) je Mandant und Typ (MVOR_BELEGART, LOV_MAIL_TYP: RECHNUNG = Rechnungsversand):
Bcc (immer), Betreff und Text (HTML) mit Platzhaltern; verwendet von FAKT_RECHNUNG_VERSAND (THG-FINANZ Seite 17).
Menue: Admin-Startseite, Liste "Admin - Konfiguration" -> E-Mail-Templates.
Aufruf (wiederholbar):  python3.13 Apex/generator/gen_admin_mail_vorlagen.py   (danach Portal + Admin einspielen)
"""
import re

from gen_artikel import BREADCRUMB, NICHT_NULL, NULL, button, ir_spalten, item, lov
from gen_admin_mitarbeiter import ADMIN, PORTAL, SICHERHEIT
from gen_finanz import RTE_LEISTE

# Typen der E-Mail (weitere Typen auch im Check-Constraint MVOR_BELEGART_CK und im Versand-Package ergaenzen)
TYPEN = [("RECHNUNG", "Rechnungsversand")]

LOV_MAIL_TYP = "lov lov-mail-typ (\n    name: LOV_MAIL_TYP\n    source {\n        location: staticValues\n    }\n\n" + "".join(
    f"    entry {r.lower()} (\n        sequence: {i}\n        display: {d}\n        return: {r}\n    )\n\n"
    for i, (r, d) in enumerate(TYPEN, 1)) + ")\n"

PLATZHALTER = [("#ANREDE#", "Sehr geehrter Herr … / Sehr geehrte Frau … (Ansprechpartner der Rechnung), sonst Sehr geehrte Damen und Herren,"),
               ("#RECHNUNGSNUMMER#", "Rechnungsnummer (auch im Betreff)"),
               ("#RECHNUNGSDATUM#", "Rechnungsdatum"),
               ("#BETRAG#", "Rechnungsbetrag brutto"),
               ("#FAELLIG_AM#", "Fälligkeit"),
               ("#ZAHLUNGSHINWEIS#", "Absatz mit offenem Betrag, Fälligkeit, Konto und Zahlungsreferenz (bzw. „bereits beglichen“)"),
               ("#KUNDE#", "Name des Rechnungsempfängers"),
               ("#ABSENDER#", "Name des angemeldeten Mitarbeiters")]


def seite_40():
    typ_text = "case v.MVOR_BELEGART " + " ".join(f"when '{r}' then '{d}'" for r, d in TYPEN) + " else v.MVOR_BELEGART end"
    s = f"""page 40 (
    name: E-Mail-Templates
    alias: EMAIL-TEMPLATES
    title: E-Mail-Templates
    pageGroup: @administration
    appearance {{
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }}
    navigation {{
        cursorFocus: doNotFocusCursor
    }}
{SICHERHEIT}
""" + BREADCRUMB("E-Mail-Templates")
    s += f"""    region vorlagen (
        name: E-Mail-Templates
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select v.MVOR_ID,
                       m.MAND_NAME as MANDANT,
                       {typ_text} as TYP,
                       v.MVOR_BETREFF,
                       v.MVOR_BCC,
                       v.MVOR_UPDATED_ON,
                       v.MVOR_UPDATED_BY
                  from FAKT_MAIL_VORLAGEN v
                  join ADMIN_MANDANTEN m on m.MAND_ID = v.MVOR_MAND_ID
                 order by m.MAND_SORTIERUNG, m.MAND_NAME, TYP
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
                page: 41
                items: {{
                    P41_MVOR_ID: #MVOR_ID#
                }}
                clearCache: 41
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
            whenNoDataFound: Keine E-Mail-Templates vorhanden.
        }}
{ir_spalten([("MVOR_ID", "ID", "hidden", "NUMBER"), ("MANDANT", "Mandant", "plainText", "STRING"),
             ("TYP", "Typ", "plainText", "STRING"), ("MVOR_BETREFF", "Betreff", "plainText", "STRING"),
             ("MVOR_BCC", "Bcc (immer)", "plainText", "STRING"),
             ("MVOR_UPDATED_ON", "Geändert am", "plainText", "TIMESTAMP"),
             ("MVOR_UPDATED_BY", "Geändert von", "plainText", "STRING")]).rstrip()}

    )

"""
    grau = "[\n                #DEFAULT#\n                t-Button--noUI\n            ]"
    s += button("up", "UP", "Zurück zur Administration", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options=grau, verhalten="""            action: redirectThisApp
            target: {
                page: 1
            }
            warnOnUnsavedChanges: doNotCheck
""")
    s += button("hinzufuegen", "CREATE", "E-Mail-Template hinzufügen", 20, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--noUI\n                t-Button--iconRight\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 41
                clearCache: 41
            }
            warnOnUnsavedChanges: doNotCheck
""")
    for sid, sel, typ in (("refresh-nach-dialog", "region: @vorlagen", "selectionType: region"),
                          ("refresh-nach-hinzufuegen", "button: @hinzufuegen", "selectionType: button")):
        s += f"""    dynamicAction {sid} (
        name: Bericht nach Dialog aktualisieren
        execution {{
            sequence: 10
        }}
        when {{
            event: apexafterclosedialog
            {typ}
            {sel}
        }}

        action {sid}-aktion (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @vorlagen
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

"""
    return s + ")\n"


def seite_41():
    platzhalter = "\n".join(f"                  <li><code>{p}</code> – {t}</li>" for p, t in PLATZHALTER)
    s = f"""page 41 (
    name: E-Mail-Template bearbeiten
    alias: EMAIL-TEMPLATE-BEARBEITEN
    title: E-Mail-Template
    pageGroup: @administration
    appearance {{
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }}
    dialog {{
        width: 1100
        chained: false
        resizable: true
    }}
    navigation {{
        cursorFocus: firstItemOnPage
    }}
{SICHERHEIT}
    region buttons (
        name: Buttons
        type: staticContent
        layout {{
            sequence: 90
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

    region vorlage (
        name: E-Mail-Template
        type: form
        source {{
            location: localDatabase
            tableName: FAKT_MAIL_VORLAGEN
        }}
        layout {{
            sequence: 10
            slot: contentBody
            columnSpan: 8
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

    region platzhalter (
        name: Platzhalter
        type: staticContent
        source {{
            htmlCode:
                ```html
                <p>Werden beim Versand durch die Werte der Rechnung ersetzt (in der Vorschau noch änderbar):</p>
                <ul>
{platzhalter}
                </ul>
                <p>Absender ist immer der angemeldete Mitarbeiter (Office-365-Adresse), Empfänger die Rechnungs-E-Mail des Kunden.</p>
                ```
        }}
        layout {{
            sequence: 20
            slot: contentBody
            startNewRow: false
            columnSpan: 4
        }}
        appearance {{
            template: @/standard
            templateOptions: #DEFAULT#
        }}
    )

    pageItem P41_MVOR_ID (
        type: hidden
        layout {{
            sequence: 1
            region: @vorlage
            slot: regionBody
        }}
        source {{
            formRegion: @vorlage
            column: MVOR_ID
            dataType: number
            primaryKey: true
        }}
        security {{
            sessionStateProtection: checksumRequiredSessionLevel
        }}
    )

"""
    f = dict(form="vorlage")
    v = "vorlage"
    s += item("P41_MVOR_MAND_ID", "selectList", "Mandant", 10, v, col="MVOR_MAND_ID", dtype="number", req=True,
              spalten=6, extra=lov("lov-mandanten", "- Mandant wählen -"), **f)
    s += item("P41_MVOR_BELEGART", "selectList", "Typ", 20, v, col="MVOR_BELEGART", req=True, neue_zeile=False,
              spalten=6, extra=lov("lov-mail-typ", "- Typ wählen -"), **f)
    s += item("P41_MVOR_BCC", "textField", "Bcc (immer)", 30, v, col="MVOR_BCC", maxlen=1000, spalten=12, extra="""        help {
            helpText: Blindkopie jeder E-Mail dieses Typs, z. B. office@thg-edv.com. Mehrere Adressen mit ; trennen.
        }
""", **f)
    s += item("P41_MVOR_BETREFF", "textField", "Betreff", 40, v, col="MVOR_BETREFF", req=True, maxlen=500, spalten=12, **f)
    s += item("P41_MVOR_TEXT", "richTextEditor", "Text", 50, v, col="MVOR_TEXT", dtype="clob", req=True, spalten=12,
              extra="        settings {\n            format: html\n            toolbar: full\n        }\n" + RTE_LEISTE(), **f)
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("delete", "DELETE", "Löschen", 20, "buttons", "delete", options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
""", bedingung=NICHT_NULL("P41_MVOR_ID") + """        confirmation {
            message: E-Mail-Template wirklich löschen? Ohne Template ist für diesen Mandanten kein Versand dieses Typs möglich.
            style: danger
        }
""")
    s += button("save", "SAVE", "Speichern", 30, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P41_MVOR_ID"))
    s += button("create", "CREATE", "Anlegen", 40, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P41_MVOR_ID"))
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

    validation mandant-typ-eindeutig (
        name: Je Mandant und Typ nur ein Template
        execution {
            sequence: 10
        }
        validation {
            type: noRowsReturned
            sqlQuery:
                ```sql
                select 1 from FAKT_MAIL_VORLAGEN
                 where MVOR_MAND_ID = :P41_MVOR_MAND_ID
                   and MVOR_BELEGART = :P41_MVOR_BELEGART
                   and MVOR_ID <> nvl(:P41_MVOR_ID, -1)
                ```
        }
        error {
            errorMessage: Für diesen Mandanten gibt es bereits ein Template dieses Typs.
            associatedItem: @P41_MVOR_BELEGART
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }
    )

    process initialize-form-vorlage (
        name: Formular E-Mail-Template initialisieren
        type: formInitialization
        formRegion: @vorlage
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process process-form-vorlage (
        name: Formular E-Mail-Template verarbeiten
        type: formAutoRowProcessing
        formRegion: @vorlage
        execution {
            sequence: 10
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
            value: CREATE,SAVE,DELETE
        }
    )

)
"""
    return s


if __name__ == "__main__":
    (ADMIN / "pages" / "p00040-email-templates.apx").write_text(seite_40(), encoding="utf-8")
    (ADMIN / "pages" / "p00041-email-template-bearbeiten.apx").write_text(seite_41(), encoding="utf-8")

    # LOV der Typen: Master im Portal (ersetzt bei neuen Typen), Subscription in der Admin-App
    p = PORTAL / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"\n*lov lov-mail-typ \(.*?\n\)\n", "\n", s, flags=re.S).rstrip("\n")
    p.write_text(s + "\n\n" + LOV_MAIL_TYP, encoding="utf-8")
    p = ADMIN / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"\n*lov lov-mail-typ \(.*?\n\)\n", "\n", s, flags=re.S).rstrip("\n")
    abo = LOV_MAIL_TYP.replace("    }\n\n", "    }\n    subscription {\n        master: @/20000/lov-mail-typ\n    }\n\n", 1)
    p.write_text(s + "\n\n" + abo, encoding="utf-8")

    # Eintrag in "Admin - Konfiguration" (Admin-Startseite) und Breadcrumb
    p = ADMIN / "shared-components" / "lists.apx"
    s = p.read_text(encoding="utf-8")
    if "entry email-templates (" not in s:
        a = s.index("    entry mitarbeiter (")
        e = s.index("\n    )\n", a) + len("\n    )\n")
        s = s[:e] + """
    entry email-templates (
        label: E-Mail-Templates
        icon {
            imageIconCssClasses: fa-envelope-o
        }
        layout {
            sequence: 40
        }
        link {
            target: {
                page: 40
                clearCache: 40
            }
        }
        userDefinedAttributes {
            1: E-Mail-Vorlagen je Mandant und Typ (z. B. Rechnungsversand): Betreff, Text mit Platzhaltern, Bcc
        }
    )
""" + s[e:]
        p.write_text(s, encoding="utf-8")
    p = ADMIN / "shared-components" / "breadcrumbs.apx"
    s = p.read_text(encoding="utf-8")
    if "entry email-templates (" not in s:
        s = s.replace("    entry aktivitaetsprotokoll (", """    entry email-templates (
        name: E-Mail-Templates
        pageNumber: 40
        appearance {
            parentEntry: @home
        }
        execution {
            sequence: 28
        }
        link {
            target: {
                page: 40
            }
        }
    )

    entry aktivitaetsprotokoll (""", 1)
        p.write_text(s, encoding="utf-8")
    print("E-Mail-Templates (Seiten 40/41) in THG-ADMIN erzeugt")
