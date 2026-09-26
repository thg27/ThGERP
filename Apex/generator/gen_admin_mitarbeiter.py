#!/usr/bin/env python3.13
"""Mitarbeiterverwaltung in THG-ADMIN (20030): Seite 30 Mitarbeiter (Liste), Seite 31 Mitarbeiter (Dialog).

Mitarbeiter (ALLG_MITARBEITER): Kuerzel, Name, APEX-Benutzername (Login), Standard-Mandant;
Kommunikation (ALLG_MITARBEITER_KOMMUNIKATION) als editierbares Grid im Dialog.
Der Benutzername verknuepft die Anmeldung mit dem Mitarbeiter: Standard-Mandant beim Login,
Bearbeiter-Vorschlag auf Rechnungen (THG-FINANZ).
Aufruf (wiederholbar):  python3.13 Apex/generator/gen_admin_mitarbeiter.py   (danach Portal + Admin einspielen)
"""
import re

from gen_artikel import BREADCRUMB, NICHT_NULL, NULL, SWITCH, button, ir_spalten, item, lov

import gen_artikel as ga

ADMIN = ga.APEX / "thg-admin"
PORTAL = ga.APEX / "thg-portal"
SICHERHEIT = """    security {
        authorizationScheme: @administration-rights
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }
"""

LOV_BENUTZER = """lov lov-apex-benutzer (
    name: LOV_APEX_BENUTZER
    source {
        type: sqlQuery
        sqlQuery:
            ```sql
            select user_name || nvl2(email, ' (' || email || ')', null) as d,
                   user_name as r
              from apex_workspace_apex_users
             where workspace_name = 'THGERP'
             order by user_name
            ```
    }
    columnMapping {
        return: R
        display: D
    }
)
"""


def seite_30():
    s = f"""page 30 (
    name: Mitarbeiter
    alias: MITARBEITER
    title: Mitarbeiter
    pageGroup: @administration
    appearance {{
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }}
    navigation {{
        cursorFocus: doNotFocusCursor
    }}
{SICHERHEIT}
""" + BREADCRUMB("Mitarbeiter")
    s += f"""    region mitarbeiter (
        name: Mitarbeiter
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select m.MITA_ID,
                       m.MITA_KUERZEL,
                       m.MITA_NAME,
                       m.MITA_BENUTZERNAME,
                       d.MAND_KURZNAME as MANDANT,
                       (select listagg(k.KART_BEZEICHNUNG || ': ' || x.MKOM_WERT, ' · ') within group (order by k.KART_SORTIERUNG)
                          from ALLG_MITARBEITER_KOMMUNIKATION x
                          join ALLG_KOMMUNIKATIONSARTEN k on k.KART_ID = x.MKOM_KART_ID
                         where x.MKOM_MITA_ID = m.MITA_ID) as KOMMUNIKATION,
                       case when m.MITA_BENUTZERNAME is null then 'kein Login'
                            when not exists (select 1 from apex_workspace_apex_users u
                                              where u.workspace_name = 'THGERP' and u.user_name = m.MITA_BENUTZERNAME)
                            then 'Benutzer fehlt in APEX' end as HINWEIS,
                       m.MITA_UPDATED_ON,
                       m.MITA_UPDATED_BY
                  from ALLG_MITARBEITER m
                  left join ADMIN_MANDANTEN d on d.MAND_ID = m.MITA_MAND_ID
                 order by m.MITA_NAME
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
                page: 31
                items: {{
                    P31_MITA_ID: #MITA_ID#
                }}
                clearCache: 31
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
            whenNoDataFound: Keine Mitarbeiter vorhanden.
        }}
{ir_spalten([("MITA_ID", "ID", "hidden", "NUMBER"), ("MITA_KUERZEL", "Kürzel", "plainText", "STRING"),
             ("MITA_NAME", "Name", "plainText", "STRING"), ("MITA_BENUTZERNAME", "Benutzername (Login)", "plainText", "STRING"),
             ("MANDANT", "Standard-Mandant", "plainText", "STRING"), ("KOMMUNIKATION", "Kommunikation", "plainText", "STRING"),
             ("HINWEIS", "Hinweis", "plainText", "STRING"),
             ("MITA_UPDATED_ON", "Geändert am", "plainText", "TIMESTAMP"),
             ("MITA_UPDATED_BY", "Geändert von", "plainText", "STRING")]).rstrip()}

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
    s += button("hinzufuegen", "CREATE", "Mitarbeiter hinzufügen", 20, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--noUI\n                t-Button--iconRight\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 31
                clearCache: 31
            }
            warnOnUnsavedChanges: doNotCheck
""")
    for sid, sel, typ in (("refresh-nach-dialog", "region: @mitarbeiter", "selectionType: region"),
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
                region: @mitarbeiter
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

"""
    return s + ")\n"


def seite_31():
    s = f"""page 31 (
    name: Mitarbeiter bearbeiten
    alias: MITARBEITER-BEARBEITEN
    title: Mitarbeiter
    pageGroup: @administration
    appearance {{
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }}
    dialog {{
        width: 900
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

    region mitarbeiter (
        name: Mitarbeiter
        type: form
        source {{
            location: localDatabase
            tableName: ALLG_MITARBEITER
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

    pageItem P31_MITA_ID (
        type: hidden
        layout {{
            sequence: 1
            region: @mitarbeiter
            slot: regionBody
        }}
        source {{
            formRegion: @mitarbeiter
            column: MITA_ID
            dataType: number
            primaryKey: true
        }}
        security {{
            sessionStateProtection: checksumRequiredSessionLevel
        }}
    )

"""
    f = dict(form="mitarbeiter")
    m = "mitarbeiter"
    s += item("P31_MITA_KUERZEL", "textField", "Kürzel", 10, m, col="MITA_KUERZEL", req=True, maxlen=10, spalten=3, **f)
    s += item("P31_MITA_NAME", "textField", "Name", 20, m, col="MITA_NAME", req=True, maxlen=100,
              neue_zeile=False, spalten=9, **f)
    s += item("P31_MITA_BENUTZERNAME", "selectList", "APEX-Benutzername (Login)", 30, m, col="MITA_BENUTZERNAME",
              spalten=6, extra=lov("lov-apex-benutzer", "- kein Login -"), **f)
    s += item("P31_MITA_MAND_ID", "selectList", "Standard-Mandant beim Login", 40, m, col="MITA_MAND_ID",
              dtype="number", neue_zeile=False, spalten=6, extra=lov("lov-mandanten", "- erster aktiver Mandant -"), **f)

    s += """    region kommunikation (
        name: Kommunikation
        type: interactiveGrid
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select MKOM_ID, MKOM_MITA_ID, MKOM_KART_ID, MKOM_WERT, MKOM_BEZEICHNUNG, MKOM_IST_BEVORZUGT
                  from ALLG_MITARBEITER_KOMMUNIKATION
                 where MKOM_MITA_ID = :P31_MITA_ID
                ```
            pageItemsToSubmit: [
                P31_MITA_ID
            ]
        }
        layout {
            sequence: 20
            slot: contentBody
        }
        appearance {
            template: @/standard
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
        messages {
            whenNoDataFound: Keine Kommunikationsdaten erfasst.
        }
        toolbar {
            controls: [
                actionsMenu
                saveButton
            ]
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P31_MITA_ID
        }

        savedReport PRIMARY (
            visibility: primary
            view {
                default: grid
            }
            singleRowView {
                displayedColumns: true
            }

            displayColumn (
                column: @APEX$ROW_ACTION
                layout {
                    sequence: 0
                }
            )
            displayColumn (
                column: @MKOM_KART_ID
                layout {
                    sequence: 1
                }
            )
            displayColumn (
                column: @MKOM_WERT
                layout {
                    sequence: 2
                }
            )
            displayColumn (
                column: @MKOM_BEZEICHNUNG
                layout {
                    sequence: 3
                }
            )
            displayColumn (
                column: @MKOM_IST_BEVORZUGT
                layout {
                    sequence: 4
                }
            )
        )

        column APEX$ROW_ACTION (
            type: actionsMenu
            layout {
                sequence: 5
            }
        )

        column MKOM_ID (
            type: hidden
            layout {
                sequence: 10
            }
            source {
                databaseColumn: MKOM_ID
                dataType: number
                primaryKey: true
            }
        )

        column MKOM_MITA_ID (
            type: hidden
            layout {
                sequence: 20
            }
            source {
                databaseColumn: MKOM_MITA_ID
                dataType: number
            }
            default {
                type: item
                item: P31_MITA_ID
            }
        )

        column MKOM_KART_ID (
            type: selectList
            heading {
                heading: Art
            }
            layout {
                sequence: 30
            }
            source {
                databaseColumn: MKOM_KART_ID
                dataType: number
            }
            validation {
                valueRequired: true
            }
            lov {
                type: sharedComponent
                lov: @lov-kommunikationsarten
                displayNullValue: false
                displayExtraValues: false
            }
        )

        column MKOM_WERT (
            type: textField
            heading {
                heading: Wert
            }
            layout {
                sequence: 40
            }
            source {
                databaseColumn: MKOM_WERT
                dataType: varchar2
            }
            validation {
                valueRequired: true
                maxLength: 255
            }
        )

        column MKOM_BEZEICHNUNG (
            type: textField
            heading {
                heading: Bezeichnung
            }
            layout {
                sequence: 50
            }
            source {
                databaseColumn: MKOM_BEZEICHNUNG
                dataType: varchar2
            }
            validation {
                maxLength: 100
            }
        )

        column MKOM_IST_BEVORZUGT (
            type: selectList
            heading {
                heading: Bevorzugt
            }
            layout {
                sequence: 60
            }
            source {
                databaseColumn: MKOM_IST_BEVORZUGT
                dataType: varchar2
            }
            validation {
                valueRequired: true
            }
            lov {
                type: sharedComponent
                lov: @lov-ja-nein
                displayNullValue: false
                displayExtraValues: false
            }
            default {
                type: static
                staticValue: Y
            }
        )
    )

"""
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("delete", "DELETE", "Löschen", 20, "buttons", "delete",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
""", bedingung=NICHT_NULL("P31_MITA_ID") + """        confirmation {
            message: Mitarbeiter wirklich löschen? Nicht möglich, solange er als Bearbeiter auf Rechnungen steht.
            style: danger
        }
""")
    s += button("save", "SAVE", "Speichern", 30, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P31_MITA_ID"))
    s += button("create", "CREATE", "Anlegen", 40, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P31_MITA_ID"))
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

    validation kuerzel-eindeutig (
        name: Kürzel eindeutig
        execution {
            sequence: 10
        }
        validation {
            type: noRowsReturned
            sqlQuery:
                ```sql
                select 1 from ALLG_MITARBEITER
                 where upper(MITA_KUERZEL) = upper(:P31_MITA_KUERZEL)
                   and MITA_ID <> nvl(:P31_MITA_ID, -1)
                ```
        }
        error {
            errorMessage: Dieses Kürzel ist bereits vergeben.
            associatedItem: @P31_MITA_KUERZEL
        }
    )

    validation benutzer-eindeutig (
        name: Benutzername nur einem Mitarbeiter zugeordnet
        execution {
            sequence: 20
        }
        validation {
            type: noRowsReturned
            sqlQuery:
                ```sql
                select 1 from ALLG_MITARBEITER
                 where MITA_BENUTZERNAME = upper(:P31_MITA_BENUTZERNAME)
                   and MITA_ID <> nvl(:P31_MITA_ID, -1)
                ```
        }
        error {
            errorMessage: Dieser Benutzername ist bereits einem anderen Mitarbeiter zugeordnet.
            associatedItem: @P31_MITA_BENUTZERNAME
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P31_MITA_BENUTZERNAME
        }
    )

    process initialize-form-mitarbeiter (
        name: Formular Mitarbeiter initialisieren
        type: formInitialization
        formRegion: @mitarbeiter
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process process-form-mitarbeiter (
        name: Formular Mitarbeiter verarbeiten
        type: formAutoRowProcessing
        formRegion: @mitarbeiter
        execution {
            sequence: 10
        }
    )

    process kommunikation-speichern (
        name: Kommunikation speichern
        type: interactiveGridAutoRowProcessing
        editableRegion: @kommunikation
        execution {
            sequence: 20
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
    (ADMIN / "pages" / "p00030-mitarbeiter.apx").write_text(seite_30(), encoding="utf-8")
    (ADMIN / "pages" / "p00031-mitarbeiter-bearbeiten.apx").write_text(seite_31(), encoding="utf-8")

    # LOVs: Master im Portal, Subscription in der Admin-App
    p = PORTAL / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    if "lov lov-apex-benutzer (" not in s:
        p.write_text(s.rstrip("\n") + "\n\n" + LOV_BENUTZER, encoding="utf-8")
    portal = p.read_text(encoding="utf-8")
    p = ADMIN / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    for sid in ("lov-apex-benutzer", "lov-mandanten"):
        if f"lov {sid} (" not in s:
            blk = re.search(rf"lov {sid} \(.*?\n\)\n", portal, flags=re.S).group(0)
            blk = blk.replace("    columnMapping {", f"    subscription {{\n        master: @/20000/{sid}\n    }}\n    columnMapping {{", 1)
            s = s.rstrip("\n") + "\n\n" + blk
    p.write_text(s, encoding="utf-8")

    # Eintrag in "Admin - Konfiguration" und Breadcrumb
    p = ADMIN / "shared-components" / "lists.apx"
    s = p.read_text(encoding="utf-8")
    if "entry mitarbeiter (" not in s:
        a = s.index("    entry mandanten (")
        e = s.index("\n    )\n", a) + len("\n    )\n")
        s = s[:e] + """
    entry mitarbeiter (
        label: Mitarbeiter
        icon {
            imageIconCssClasses: fa-users
        }
        layout {
            sequence: 30
        }
        link {
            target: {
                page: 30
                clearCache: 30
            }
        }
        userDefinedAttributes {
            1: Eigene Mitarbeiter: Kürzel, Name, Login (APEX-Benutzer), Standard-Mandant, Kommunikation
        }
    )
""" + s[e:]
        p.write_text(s, encoding="utf-8")
    p = ADMIN / "shared-components" / "breadcrumbs.apx"
    s = p.read_text(encoding="utf-8")
    if "entry mitarbeiter (" not in s:
        s = s.replace("    entry aktivitaetsprotokoll (", """    entry mitarbeiter (
        name: Mitarbeiter
        pageNumber: 30
        appearance {
            parentEntry: @home
        }
        execution {
            sequence: 27
        }
        link {
            target: {
                page: 30
            }
        }
    )

    entry aktivitaetsprotokoll (""", 1)
        p.write_text(s, encoding="utf-8")
    print("Mitarbeiterverwaltung (Seiten 30/31) in THG-ADMIN erzeugt")
