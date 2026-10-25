#!/usr/bin/env python3.13
"""Erzeugt die App THG-FINANZ (20050): Ausgangsrechnungen (Fakturierung, Tabellen FAKT_*).

Seiten: 1 Dashboard, 10 Rechnungen (Liste mit Facettensuche; beide aus finanz_dashboard_liste.py), 11 Rechnung (Allgemein, Kunde mit Anschrift und Lieferadresse,
Vortext, Positionen als Baum aus Haupt- und Unterpositionen mit Detailfeldern und Summen je Steuersatz,
Schlusstext, Zahlungen),
12/13 Rechnung als PDF, 14 Unterposition (Dialog), 20 Artikel, 21 Artikel bearbeiten,
100 Wertelisten, 110/111 Nummernkreise, 120/121 Artikelgruppen.
Der Artikelstamm (vorher eigene App THG-ARTIKEL 20040) gehoert seit 2026-10-24 zur Finanz-App, da nur Rechnungen
Artikel verwenden; die Artikelseiten erzeugt gen_artikel.py (umnummeriert mit ga.in_finanz).
Logik in der Datenbank: Package FAKT_RECHNUNG (21_finanz.sql).
Grundgeruest: Kopie von THG-ALLGEMEIN (beim ersten Lauf).
Aufruf:  python3.13 Apex/generator/gen_finanz.py   (f-Strings nach PEP 701)
"""
import re
import secrets
import shutil

import finanz_dashboard_liste as fdl
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
    return fdl.rechnungsliste()


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


def ig_region(sid, name, seq, sql, spalten, anzeige, bedingung, ops="add\n                update\n                delete", nur_lesen=""):
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
        advanced {{
            htmlDomId: {sid}
        }}
{nur_lesen}        source {{
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


# Abgeschlossene Rechnung (Status <> ENTWURF) nur lesen – ausser nach bewusstem "Rechnung bearbeiten" (P11_BEARBEITEN = Y)
NUR_LESEN = """        readOnly {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_STATUS <> 'ENTWURF' and nvl(:P11_BEARBEITEN, 'N') <> 'Y'
        }
"""


def hervorheben(s):
    """Seitenelement mit CSS-Klasse thg-hervorheben (leicht hinterlegt, Farbe des Mandanten)"""
    return s.replace("            templateOptions: #DEFAULT#\n        }\n",
                     "            templateOptions: #DEFAULT#\n            cssClasses: thg-hervorheben\n        }\n", 1)


def maske(it, m):
    """Seitenelement mit Formatmaske"""
    return it.replace("            templateOptions: #DEFAULT#\n        }\n",
                      f"            templateOptions: #DEFAULT#\n            formatMask: {m}\n        }}\n", 1)


def da_klick(sid, name, seq, knopf, js):
    """Dynamic Action: Klick auf einen Button fuehrt JavaScript aus"""
    return f"""    dynamicAction {sid} (
        name: {name}
        execution {{
            sequence: {seq}
        }}
        when {{
            event: click
            selectionType: button
            button: @{knopf}
        }}

        action {sid}-js (
            action: executeJsCode
            settings {{
                jsCode: {js}
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

"""


# Seitenskript Rechnung: Positionen als Baum (Haupt-/Unterpositionen) mit Detailfeldern und Raster der
# Unterpositionen (ohne Backslashes – siehe zentrale Wissensdatenbank)
POS_JS = """    javaScript {
        executeWhenPageLoads:
            ```javascript-browser
            // Positionen der Rechnung:
            //  * links der Baum (#pos-baum): Hauptpositionen 1, 2, 3 … mit ihren Unterpositionen 10, 20, 30 …
            //    und der Summe je Zeile; Buttons Hauptposition / Unterposition / Löschen
            //  * rechts die Felder der gewaehlten Position (P11_POS_*), gespeichert per AJAX (POS_SPEICHERN)
            //  * bei einer Hauptposition darunter das Raster ihrer Unterpositionen: Schnelleingabe (neue Zeile) oder
            //    "Zeile Detail" bzw. Zeilenmenue "Detail …" (Dialog Seite 14)
            //  * Hauptposition: kein eigener Preis – Rabatt, Summe (Unterpositionen abzgl. Rabatt), Pauschalsumme
            //  * Reihenfolge per Drag & Drop im Baum (POS_VERSCHIEBEN); die Positionsnummern vergibt der Server:
            //    Hauptpositionen 1, 2, 3 …, Unterpositionen 10, 20, 30 …
            //  * ob geaendert werden darf, liefert der Server (Status der Rechnung bzw. "Rechnung bearbeiten")
            (function () {
                // Tab-Leiste: erster Tab heisst "Alle anzeigen" (thg.js uebersetzt "Show All" allgemein mit "Alle")
                $(".apex-rds li:first-child a span").text("Alle anzeigen");
                // Kebab-Menue "Weitere Aktionen": klickt die versteckten Buttons (Bedingung, Bestaetigung, Verhalten
                // bleiben beim Button); fehlt ein Button (Bedingung), fehlt auch der Menuepunkt
                var aktionen = [["thg-akt-kopieren", "Rechnung kopieren", "fa-copy"],
                                ["thg-akt-stornieren", "Rechnung stornieren", "fa-ban"],
                                ["thg-akt-loeschen", "Rechnung löschen", "fa-trash-o"]]
                    .filter(function (a) { return document.getElementById(a[0]); })
                    .map(function (a) {
                        return { type: "action", label: a[1], icon: "fa " + a[2],
                                 action: function () { $("#" + a[0]).trigger("click"); } };
                    });
                if (aktionen.length) {
                    $("<div id='thg-aktionen-menu'></div>").appendTo("body").menu({ items: aktionen });
                    $("#thg-aktionen").attr({ "data-menu": "thg-aktionen-menu", "title": "Weitere Aktionen" });
                } else {
                    $("#thg-aktionen").hide();
                }
                if (!document.getElementById("pos-baum")) {
                    return;   // neue Rechnung: Positionen erst nach dem Anlegen
                }
                var BETRAG = "FML999G999G990D00", PREIS = "999G999G990D00";
                // Eingabefelder (werden beim Speichern mitgeschickt) und reine Anzeigen
                var EINGABE = ["P11_POS_ARTI_ID", "P11_POS_NAME", "P11_POS_OPTIONAL", "P11_POS_EINZELPREIS",
                               "P11_POS_EINHEIT", "P11_POS_MENGE", "P11_POS_MWST", "P11_POS_RABATT", "P11_POS_PAUSCHAL",
                               "P11_POS_BESCHREIBUNG"];
                // Artikel: nicht bei Hauptpositionen mit Unterpositionen
                var NUR_ARTIKEL = ["P11_POS_ARTI_ID", "P11_POS_ARTIKELNUMMER", "P11_POS_GRUPPE"];
                // Einzelpreis, Einheit, Menge, MwSt.: nur bei Unterpositionen – eine Hauptposition hat keinen eigenen Preis,
                // ihr Betrag ist die Summe der Unterpositionen (abzgl. Rabatt) bzw. die Pauschalsumme
                var NUR_UNTER = ["P11_POS_EINZELPREIS", "P11_POS_EINHEIT", "P11_POS_MENGE", "P11_POS_MWST"];
                // Pauschalsumme: nur bei Hauptpositionen
                var NUR_HAUPT = ["P11_POS_PAUSCHAL"];
                // zu: eingeklappte Hauptpositionen (ID -> true), gilt bis zum Neuladen der Seite
                var zustand = { daten: null, aenderbar: false, id: null, hauptId: null, unter: 0, summeUnter: 0, zu: {},
                                offen: false, geaendert: false, laedt: false };
                var baum$ = $("#pos-baum");

                var zahl = function (w) {
                    if (w === null || w === undefined || w === "") {
                        return 0;
                    }
                    var n = apex.locale.toNumber(String(w), BETRAG);   // mit Maske: auch Werte ohne Waehrungszeichen
                    return isNaN(n) ? (apex.locale.toNumber(String(w)) || 0) : n;
                };
                var runden = function (n) {
                    return Math.round(n * 100) / 100;
                };
                // P11_RECH_ID mitschicken: der Wert aus der Formular-Initialisierung steht nicht im Sitzungsstatus
                var server = function (prozess, daten) {
                    daten = daten || {};
                    daten.pageItems = ["P11_RECH_ID"].concat(daten.pageItems || []);
                    return apex.server.process(prozess, daten, { dataType: "json" });
                };
                var fehler = function (text) {
                    apex.message.clearErrors();
                    apex.message.showErrors([{ type: "error", location: "page", message: text, unsafe: false }]);
                };

                // ---------------------------------------------------------------- Raster der Unterpositionen
                var region = apex.region("positionen");
                var ansicht = region.widget().interactiveGrid("getViews", "grid");
                var modell = ansicht.model;
                // Summe: nur im Browser schreibgeschuetzt (serverseitig "nur lesen" haengt eine Pruefsumme an, dann
                // laesst das Modell bei gespeicherten Zeilen kein Setzen zu); berechnet wird sie im Trigger RPOS_BIU
                modell.getOption("fields").RPOS_SUMME.readonly = true;
                var zeilenSumme = function (satz) {
                    var s = zahl(modell.getValue(satz, "RPOS_MENGE")) * zahl(modell.getValue(satz, "RPOS_EINZELPREIS"))
                            * (1 - zahl(modell.getValue(satz, "RPOS_RABATT_PROZENT")) / 100);
                    // im Formatmuster der Spalte, sonst lehnt die Zahlenpruefung beim Speichern ab
                    var feld = modell.getOption("fields").RPOS_SUMME, schutz = feld.readonly;
                    feld.readonly = false;
                    try {
                        modell.setValue(satz, "RPOS_SUMME", apex.locale.formatNumber(runden(s), BETRAG));
                    } finally {
                        feld.readonly = schutz;
                    }
                };
                // Spalten mit Werteliste speichern im Modell {v: Wert, d: Anzeige}, sonst einfache Werte
                var wert = function (w) {
                    return (w && typeof w === "object") ? w.v : w;
                };
                var artikelInsRaster = function (satz) {
                    var id = wert(modell.getValue(satz, "RPOS_ARTI_ID"));
                    if (!id) {
                        return;
                    }
                    server("ARTIKEL_DATEN", { x01: id }).then(function (a) {
                        modell.setValue(satz, "RPOS_NAME", a.name || "");
                        modell.setValue(satz, "RPOS_EINHEIT", a.einheit ? { v: a.einheit, d: a.einheit } : "");
                        modell.setValue(satz, "RPOS_EINZELPREIS", a.preis ? apex.locale.formatNumber(zahl(a.preis), BETRAG) : "");
                        modell.setValue(satz, "RPOS_MWST_PROZENT", a.mwst ? { v: a.mwst, d: a.mwst_anzeige } : "");
                        modell.setValue(satz, "RPOS_BESCHREIBUNG", a.beschreibung || "");
                        if (!modell.getValue(satz, "RPOS_MENGE")) {
                            modell.setValue(satz, "RPOS_MENGE", "1");
                        }
                        zeilenSumme(satz);
                    });
                };
                modell.subscribe({
                    onChange: function (art, daten) {
                        // die Positionsnummer vergibt der Prozess beim Speichern (neue Zeilen ans Ende)
                        if (art === "set" && daten.record) {
                            if (daten.field === "RPOS_ARTI_ID") {
                                artikelInsRaster(daten.record);
                            } else if (["RPOS_MENGE", "RPOS_EINZELPREIS", "RPOS_RABATT_PROZENT"].indexOf(daten.field) >= 0) {
                                zeilenSumme(daten.record);
                            }
                        }
                    }
                });
                // ungespeicherte Aenderungen im Raster (die leere, automatisch angelegte Zeile zaehlt nicht)
                var rasterGeaendert = function () {
                    var ja = false;
                    if (!$("#positionen").is(":visible")) {
                        return false;
                    }
                    modell.forEach(function (satz) {
                        var meta = modell.getRecordMetadata(modell.getRecordId(satz)) || {};
                        // neue Zeilen: nur mit Artikel oder Name zaehlen (die leere, vom Raster angelegte Zeile nicht)
                        if (meta.inserted ? (wert(modell.getValue(satz, "RPOS_ARTI_ID")) || modell.getValue(satz, "RPOS_NAME"))
                                          : (meta.deleted || meta.updated)) {
                            ja = true;
                        }
                    });
                    return ja;
                };
                // Unterposition im Dialog (Seite 14) erfassen bzw. oeffnen; der Dialog speichert direkt in die Datenbank
                var detail = function (rposId) {
                    if (rasterGeaendert()) {
                        apex.message.alert("Bitte zuerst die Änderungen an den Unterpositionen speichern.");
                        return;
                    }
                    server("DETAIL_URL", { x01: rposId || "", x02: $v("P11_HAUPT_ID") }).then(function (d) {
                        apex.navigation.redirect(d.url);
                    });
                };
                window.thgPositionen = {
                    // neue Unterposition am Ende des Rasters, Cursor in den Artikel
                    schnelleingabe: function () {
                        var letzte = null;
                        modell.forEach(function (satz) {
                            letzte = satz;
                        });
                        var id = modell.insertNewRecord(null, letzte);
                        ansicht.view$.grid("gotoCell", id, "RPOS_ARTI_ID");
                        ansicht.view$.grid("setEditMode", true);
                    },
                    // neue Unterposition im Dialog erfassen
                    detail: function () {
                        detail(null);
                    }
                };
                // Zeilenmenue: gespeicherte Unterposition im Dialog oeffnen (aenderbar oder nur Anzeige wie die Rechnung)
                if (ansicht.rowActionMenu$) {
                    var rasterAenderbar = modell.getOption("editable");
                    ansicht.rowActionMenu$.menu("option").items.unshift({
                        type: "action",
                        label: rasterAenderbar ? "Detail bearbeiten" : "Detail anzeigen",
                        icon: rasterAenderbar ? "fa fa-pencil-square-o" : "fa fa-search",
                        action: function (menue, element) {
                            var satz = ansicht.getContextRecord(element)[0],
                                meta = modell.getRecordMetadata(modell.getRecordId(satz)) || {};
                            if (meta.inserted) {
                                apex.message.alert("Bitte die neue Unterposition zuerst speichern.");
                            } else {
                                detail(modell.getValue(satz, "RPOS_ID"));
                            }
                        }
                    });
                }
                // Dialog geschlossen (gespeichert): Baum, Summen, Felder und Raster neu laden
                $("#positionen").on("apexafterclosedialog", function () {
                    laden().then(function () {
                        if (zustand.id) {
                            oeffnen(zustand.id);
                        }
                    });
                });
                // Speichern des Rasters: leere neue Zeilen (ohne Artikel und Name) vorher entfernen – sonst meldet die
                // Datenbank einen Fehler, wenn nach "Schnelleingabe" ohne Eingabe gespeichert wird
                var speichernAktion = region.widget().interactiveGrid("getActions").lookup("save");
                if (speichernAktion) {
                    var rasterSpeichern = speichernAktion.action;
                    speichernAktion.action = function (ereignis, element) {
                        var das = this;
                        // erst die laufende Eingabe uebernehmen, dann pruefen
                        $.when(ansicht.view$.grid("finishEditing")).always(function () {
                            var leer = [];
                            modell.forEach(function (satz) {
                                var meta = modell.getRecordMetadata(modell.getRecordId(satz)) || {};
                                if (meta.inserted && !wert(modell.getValue(satz, "RPOS_ARTI_ID")) && !modell.getValue(satz, "RPOS_NAME")) {
                                    leer.push(satz);
                                }
                            });
                            if (leer.length) {
                                modell.deleteRecords(leer);
                            }
                            rasterSpeichern.call(das, ereignis, element);
                        });
                    };
                }

                // ---------------------------------------------------------------- Baum und Summen
                // Hauptposition mit Unterpositionen: Schalter +/- zum Ein- und Ausklappen; sonst gleich breiter Platzhalter
                var knoten = function (p, klasse, versteckt) {
                    var unter = p.unter ? p.unter.length : 0, zu = !!zustand.zu[p.id];
                    var schalter = unter
                        ? "<span class='thg-pos-schalter fa " + (zu ? "fa-plus-square-o" : "fa-minus-square-o") + "' role='button' title='" +
                          (zu ? "Unterpositionen einblenden" : "Unterpositionen ausblenden") + "'></span>"
                        : "<span class='thg-pos-schalter'></span>";
                    return "<div class='thg-pos-knoten " + klasse + (p.optional ? " thg-pos-optional" : "") +
                           (versteckt ? " thg-pos-versteckt" : "") +
                           "' role='treeitem' tabindex='0' data-id='" + p.id + "' data-unter='" + unter + "'" +
                           (unter ? " aria-expanded='" + (zu ? "false" : "true") + "'" : "") +
                           " draggable='" + (zustand.aenderbar ? "true" : "false") + "'>" +
                           schalter +
                           "<span class='thg-pos-nr'>" + p.pos + "</span>" +
                           "<span class='thg-pos-name'>" + apex.util.escapeHTML(p.name) +
                           (p.pauschal ? " <span class='thg-pos-hinweis thg-pos-hinweis-pauschal'>pauschal</span>" : "") +
                           (p.optional ? " <span class='thg-pos-hinweis thg-pos-hinweis-optional'>optional</span>" : "") + "</span>" +
                           "<span class='thg-pos-summe'>" + apex.util.escapeHTML(p.summe) + "</span></div>";
                };
                var markieren = function () {
                    baum$.find(".thg-pos-knoten").removeClass("is-selected").attr("aria-selected", "false")
                         .filter(function () { return zustand.id && $(this).attr("data-id") === zustand.id; })
                         .addClass("is-selected").attr("aria-selected", "true");
                    $("#pos-neu-unter").prop("disabled", !zustand.aenderbar || !(zustand.hauptId || zustand.id));
                    $("#pos-loeschen").prop("disabled", !zustand.aenderbar || !zustand.id);
                };
                var baumZeigen = function () {
                    var html = "";
                    zustand.daten.positionen.forEach(function (h) {
                        html += knoten(h, "thg-pos-haupt");
                        h.unter.forEach(function (u) {
                            html += knoten(u, "thg-pos-unter", !!zustand.zu[h.id]);
                        });
                    });
                    baum$.html(html || "<div class='thg-pos-leer'>Noch keine Positionen.</div>");
                    $("#pos-neu-haupt").prop("disabled", !zustand.aenderbar);
                    markieren();
                };
                var summenZeigen = function () {
                    var ziel = document.getElementById("summen-inhalt"), zeilen = zustand.daten.summen;
                    if (!ziel) {
                        return;
                    }
                    if (!zeilen.length) {
                        ziel.textContent = "Noch keine Positionen.";
                        return;
                    }
                    var html = "<table class='t-Report-report thg-summen-tabelle'><tbody>";
                    zeilen.forEach(function (z) {
                        html += "<tr class='" + (z.fett ? "thg-summen-fett" : "") + "'><td class='t-Report-cell'>" +
                                apex.util.escapeHTML(z.label) + "</td><td class='t-Report-cell thg-summen-betrag'>" +
                                apex.util.escapeHTML(z.betrag) + "</td></tr>";
                    });
                    ziel.innerHTML = html + "</tbody></table>";
                };
                // Baum und Summen vom Server holen
                var laden = function () {
                    return server("POSITIONEN").then(function (d) {
                        zustand.daten = d;
                        zustand.aenderbar = d.aenderbar;
                        baumZeigen();
                        summenZeigen();
                    });
                };

                // ---------------------------------------------------------------- Detail der Position
                var summeDetail = function () {
                    var n = function (name) {
                        var w = apex.item(name).getNativeValue();
                        return (typeof w === "number" && !isNaN(w)) ? w : 0;
                    };
                    // Hauptposition: Summe der Unterpositionen abzgl. Rabatt (eine Pauschalsumme ersetzt sie in der
                    // Rechnung, steht aber im eigenen Feld und im Baum); Unterposition: Menge x Einzelpreis abzgl. Rabatt
                    var summe = (!zustand.hauptId ? zustand.summeUnter : n("P11_POS_MENGE") * n("P11_POS_EINZELPREIS"))
                                * (1 - n("P11_POS_RABATT") / 100);
                    apex.item("P11_POS_SUMME").setValue(apex.locale.formatNumber(runden(summe), BETRAG));
                };
                var leeren = function () {
                    zustand.id = null;
                    zustand.hauptId = null;
                    zustand.offen = false;
                    zustand.geaendert = false;
                    $("#pos-detail_heading").text("Keine Position gewählt");
                    $(".thg-pos-speichern").hide();
                    apex.item("P11_HAUPT_ID").setValue("", null, true);
                    $("#pos-felder, #positionen").hide();
                    markieren();
                };
                // Gesperrte Felder schickt der Browser nicht mit – der Schalter "Optional" kaeme beim Absenden der Seite
                // (z. B. "Rechnung drucken" einer abgeschlossenen Rechnung) leer an und scheitert an der Pruefung
                // "muss Y oder N sein". Vor dem Absenden daher wieder freigeben (gespeichert wird er nur per AJAX).
                $(window).on("apexbeforepagesubmit", function () {
                    apex.item("P11_POS_OPTIONAL").enable();
                });
                // Antwort von POS_LADEN in die Felder
                var zeigen = function (d, ohneRaster) {
                    zustand.id = d.id || null;
                    zustand.hauptId = d.haupt_id || null;
                    zustand.unter = d.unter;
                    zustand.summeUnter = d.summe_unterpos || 0;
                    zustand.offen = true;
                    // gewaehlte Unterposition: ihre Hauptposition aufklappen
                    if (zustand.hauptId && zustand.zu[zustand.hauptId]) {
                        delete zustand.zu[zustand.hauptId];
                        baumZeigen();
                    }
                    // mit change-Ereignis (schwebende Beschriftungen richten sich danach); die eigenen Handler
                    // ignorieren es waehrend des Ladens (zustand.laedt)
                    zustand.laedt = true;
                    try {
                        Object.keys(d.felder).forEach(function (name) {
                            var w = (d.felder[name] === null || d.felder[name] === undefined) ? "" : d.felder[name];
                            if (name === "P11_POS_ARTI_ID") {
                                apex.item(name).setValue(w, d.artikel_anzeige || "");
                            } else {
                                apex.item(name).setValue(w);
                            }
                        });
                    } finally {
                        zustand.laedt = false;
                    }
                    var haupt = !zustand.hauptId, mitUnter = haupt && zustand.unter > 0;
                    $("#pos-detail_heading").text(d.titel);
                    $("#pos-felder").show();
                    NUR_ARTIKEL.forEach(function (name) {
                        apex.item(name)[mitUnter ? "hide" : "show"]();
                    });
                    NUR_UNTER.forEach(function (name) {
                        apex.item(name)[haupt ? "hide" : "show"]();
                    });
                    NUR_HAUPT.forEach(function (name) {
                        apex.item(name)[haupt ? "show" : "hide"]();
                    });
                    EINGABE.forEach(function (name) {
                        apex.item(name)[zustand.aenderbar ? "enable" : "disable"]();
                    });
                    $(".thg-pos-speichern").toggle(zustand.aenderbar);
                    // Raster der Unterpositionen nur bei einer gespeicherten Hauptposition; P11_HAUPT_ID geht mit jeder
                    // Anfrage des Rasters mit (Abfrage und Speichern)
                    var raster = haupt && !!zustand.id;
                    apex.item("P11_HAUPT_ID").setValue(raster ? zustand.id : "", null, true);
                    $("#positionen").toggle(raster);
                    if (raster) {
                        // das Raster war ausgeblendet: Werkzeugleiste und Spalten wurden mit Breite 0 aufgebaut
                        apex.widget.util.visibilityChange($("#positionen")[0], true);
                        ansicht.view$.grid("resize");
                        if (!ohneRaster) {
                            // ein Modell mit Aenderungen (auch nur die leere neue Zeile) wird nicht neu geladen;
                            // echte ungespeicherte Eingaben hat sicher() vorher abgefangen
                            modell.clearChanges();
                            region.refresh();
                        }
                    }
                    zustand.geaendert = false;
                    markieren();
                };
                // vor dem Wechsel der Position: ungespeicherte Eingaben nicht stillschweigend verwerfen
                var sicher = function (weiter) {
                    if (rasterGeaendert()) {
                        apex.message.alert("Bitte zuerst die Änderungen an den Unterpositionen speichern.");
                    } else if (zustand.geaendert && zustand.aenderbar) {
                        apex.message.confirm("Die Änderungen an der Position wurden nicht gespeichert. Verwerfen?", function (ok) {
                            if (ok) {
                                weiter();
                            }
                        });
                    } else {
                        weiter();
                    }
                };
                // x01 = Position (leer = neue Position), x02 = Hauptposition einer neuen Unterposition
                var oeffnen = function (id, hauptId, ohneRaster) {
                    return server("POS_LADEN", { x01: id || "", x02: hauptId || "" }).then(function (d) {
                        zeigen(d, ohneRaster);
                    });
                };
                // danach (optional): statt Baum und Felder neu zu laden, z.B. die Rechnung absenden
                var speichern = function (danach) {
                    server("POS_SPEICHERN", { x01: zustand.id || "", x02: zustand.hauptId || "", pageItems: EINGABE }).then(function (d) {
                        if (d.fehler) {
                            fehler(d.fehler);
                            return;
                        }
                        apex.message.clearErrors();
                        zustand.geaendert = false;
                        if (typeof danach === "function") {
                            danach();
                            return;
                        }
                        apex.message.showPageSuccess("Position gespeichert.");
                        laden().then(function () {
                            oeffnen(d.id);
                        });
                    });
                };
                var positionOffen = function () {
                    return zustand.offen && zustand.geaendert && zustand.aenderbar;
                };
                // "Speichern" / "Rechnung abschließen" der Rechnung: geaenderte Felder der Position vorher mitspeichern
                // (sie gehoeren nicht zum Formular der Rechnung und gingen sonst beim Neuladen verloren)
                var absenden = apex.page.submit;
                apex.page.submit = apex.submit = function (opt) {
                    var anfrage = (opt && typeof opt === "object") ? opt.request : opt, das = this, werte = arguments;
                    if (positionOffen() && ["SAVE", "ABSCHLIESSEN"].indexOf(anfrage) >= 0) {
                        speichern(function () {
                            absenden.apply(das, werte);
                        });
                        return;
                    }
                    return absenden.apply(this, arguments);
                };
                var loeschen = function () {
                    var haupt = !zustand.hauptId, name = $v("P11_POS_NAME");
                    apex.message.confirm((haupt ? "Hauptposition" : "Unterposition") + " „" + name + "“ löschen?" +
                            (haupt && zustand.unter > 0 ? " Ihre " + zustand.unter + " Unterposition(en) werden mitgelöscht." : ""), function (ok) {
                        if (!ok) {
                            return;
                        }
                        var zurueck = zustand.hauptId;
                        server("POS_LOESCHEN", { x01: zustand.id }).then(function (d) {
                            if (d.fehler) {
                                fehler(d.fehler);
                                return;
                            }
                            apex.message.clearErrors();
                            apex.message.showPageSuccess("Position gelöscht.");
                            leeren();
                            laden().then(function () {
                                if (zurueck) {
                                    oeffnen(zurueck);   // nach dem Loeschen einer Unterposition: ihre Hauptposition
                                }
                            });
                        });
                    });
                };

                // ---------------------------------------------------------------- Verschieben (Drag & Drop)
                // art: "vor" / "nach" dem Ziel (auf dessen Ebene) oder "in" eine Hauptposition (als letzte Unterposition)
                var verschieben = function (id, zielId, art) {
                    sicher(function () {
                        server("POS_VERSCHIEBEN", { x01: id, x02: zielId, x03: art }).then(function (d) {
                            if (d.fehler) {
                                fehler(d.fehler);
                                return;
                            }
                            apex.message.clearErrors();
                            laden().then(function () {
                                if (zustand.id) {
                                    oeffnen(zustand.id);   // Nummer, Ebene und Raster koennen sich geaendert haben
                                }
                            });
                        });
                    });
                };
                window.thgPositionen.verschieben = verschieben;
                var gezogen = null;   // { id, unter }
                var ablageLeeren = function () {
                    baum$.find(".thg-drop-vor, .thg-drop-nach, .thg-drop-in").removeClass("thg-drop-vor thg-drop-nach thg-drop-in");
                };
                // wohin wuerde auf diesem Knoten abgelegt? Hauptposition: oberes Drittel = davor, unteres Drittel = danach
                // (nur ohne Unterpositionen), sonst hinein; Unterposition: obere Haelfte = davor, untere = danach.
                // Eine Hauptposition mit Unterpositionen kann nicht selbst Unterposition werden.
                var ablageArt = function (e, ziel$) {
                    if (!gezogen || ziel$.attr("data-id") === gezogen.id) {
                        return null;
                    }
                    var r = ziel$[0].getBoundingClientRect(), y = (e.originalEvent.clientY - r.top) / r.height;
                    if (ziel$.hasClass("thg-pos-haupt")) {
                        if (y < 0.3) {
                            return "vor";
                        }
                        if (y > 0.7 && ziel$.attr("data-unter") === "0") {
                            return "nach";
                        }
                        return gezogen.unter > 0 ? null : "in";
                    }
                    return gezogen.unter > 0 ? null : (y < 0.5 ? "vor" : "nach");
                };
                baum$.on("dragstart", ".thg-pos-knoten", function (e) {
                    if (!zustand.aenderbar) {
                        e.preventDefault();
                        return;
                    }
                    gezogen = { id: $(this).attr("data-id"), unter: parseInt($(this).attr("data-unter"), 10) || 0 };
                    e.originalEvent.dataTransfer.effectAllowed = "move";
                    e.originalEvent.dataTransfer.setData("text/plain", gezogen.id);
                    $(this).addClass("is-gezogen");
                });
                baum$.on("dragover", ".thg-pos-knoten", function (e) {
                    var art = ablageArt(e, $(this));
                    ablageLeeren();
                    if (art) {
                        e.preventDefault();   // Ablegen erlauben
                        e.originalEvent.dataTransfer.dropEffect = "move";
                        $(this).addClass("thg-drop-" + art);
                    }
                });
                baum$.on("drop", ".thg-pos-knoten", function (e) {
                    var art = ablageArt(e, $(this)), quelle = gezogen;
                    e.preventDefault();
                    ablageLeeren();
                    if (art && quelle) {
                        verschieben(quelle.id, $(this).attr("data-id"), art);
                    }
                });
                // unter dem Baum ablegen: ans Ende, als Hauptposition
                $("#pos-ende").on("dragover", function (e) {
                    var letzte = baum$.find(".thg-pos-haupt").last();
                    if (gezogen && letzte.length && letzte.attr("data-id") !== gezogen.id) {
                        e.preventDefault();
                        $(this).addClass("thg-drop-vor");
                    }
                }).on("dragleave drop", function () {
                    $(this).removeClass("thg-drop-vor");
                }).on("drop", function (e) {
                    var letzte = baum$.find(".thg-pos-haupt").last();
                    e.preventDefault();
                    if (gezogen && letzte.length && letzte.attr("data-id") !== gezogen.id) {
                        verschieben(gezogen.id, letzte.attr("data-id"), "nach");
                    }
                });
                baum$.on("dragend", ".thg-pos-knoten", function () {
                    gezogen = null;
                    ablageLeeren();
                    baum$.find(".is-gezogen").removeClass("is-gezogen");
                });

                // ---------------------------------------------------------------- Bedienung
                // Schalter +/-: Unterpositionen der Hauptposition ein- bzw. ausblenden (waehlt die Position nicht)
                baum$.on("click", ".thg-pos-schalter.fa", function (e) {
                    var id = $(this).closest(".thg-pos-knoten").attr("data-id");
                    e.stopPropagation();
                    if (zustand.zu[id]) {
                        delete zustand.zu[id];
                    } else {
                        zustand.zu[id] = true;
                    }
                    baumZeigen();
                });
                baum$.on("click keydown", ".thg-pos-knoten", function (e) {
                    if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") {
                        return;
                    }
                    e.preventDefault();
                    var id = $(this).attr("data-id");
                    if (id !== zustand.id) {
                        sicher(function () {
                            oeffnen(id);
                        });
                    }
                });
                $("#pos-neu-haupt").on("click", function () {
                    sicher(function () {
                        oeffnen(null, null).then(function () {
                            apex.item("P11_POS_NAME").setFocus();
                        });
                    });
                });
                $("#pos-neu-unter").on("click", function () {
                    var haupt = zustand.hauptId || zustand.id;   // gewaehlt: Hauptposition oder eine ihrer Unterpositionen
                    sicher(function () {
                        oeffnen(null, haupt).then(function () {
                            apex.item("P11_POS_ARTI_ID").setFocus();
                        });
                    });
                });
                $("#pos-loeschen").on("click", loeschen);
                $(".thg-pos-speichern").on("click", function () {
                    speichern();
                });
                $("#pos-felder").on("change", ":input", function () {
                    if (!zustand.laedt) {
                        zustand.geaendert = true;
                    }
                });
                // Artikel gewaehlt: Name, Einheit, Einzelpreis, MwSt., Beschreibung aus dem Artikelstamm (danach aenderbar)
                $("#P11_POS_ARTI_ID").on("change", function () {
                    var id = $v("P11_POS_ARTI_ID");
                    if (zustand.laedt) {
                        return;
                    }
                    if (!id) {
                        $s("P11_POS_ARTIKELNUMMER", "");
                        $s("P11_POS_GRUPPE", "");
                        return;
                    }
                    server("ARTIKEL_DATEN", { x01: id }).then(function (a) {
                        apex.item("P11_POS_NAME").setValue(a.name || "");
                        apex.item("P11_POS_EINHEIT").setValue(a.einheit || "");
                        apex.item("P11_POS_EINZELPREIS").setValue(a.preis ? apex.locale.formatNumber(zahl(a.preis), PREIS) : "");
                        apex.item("P11_POS_MWST").setValue(a.mwst || "");
                        apex.item("P11_POS_BESCHREIBUNG").setValue(a.beschreibung || "");
                        apex.item("P11_POS_ARTIKELNUMMER").setValue(a.artikelnummer || "");
                        apex.item("P11_POS_GRUPPE").setValue(a.gruppe || "");
                        if (!$v("P11_POS_MENGE")) {
                            apex.item("P11_POS_MENGE").setValue("1");
                        }
                        summeDetail();
                    });
                });
                $("#P11_POS_MENGE, #P11_POS_EINZELPREIS, #P11_POS_RABATT").on("change", function () {
                    if (!zustand.laedt) {
                        summeDetail();
                    }
                });
                // Raster gespeichert: Baum, Summen und Felder der Hauptposition neu (das Raster hat sich selbst aktualisiert)
                // Sind zugleich Felder der Hauptposition geaendert (Rabatt, Pauschalsumme …), werden sie mitgespeichert
                $("#positionen").on("interactivegridsave", function () {
                    var id = zustand.id;
                    if (positionOffen()) {
                        speichern();
                        return;
                    }
                    laden().then(function () {
                        if (id) {
                            oeffnen(id, null, true);
                        }
                    });
                });
                // Zahlungen gespeichert: Bezahlt/Offen in den Summen
                $("#zahlungen").on("interactivegridsave", laden);

                // Button "Position speichern" in den Kopf der Region (wie "Schnelleingabe" bei den Unterpositionen)
                $("#pos-detail > .t-Region-header .t-Region-headerItems--buttons").prepend($(".thg-pos-speichern"));
                // Start: erste Hauptposition anzeigen
                leeren();
                laden().then(function () {
                    if (zustand.daten.positionen.length) {
                        oeffnen(zustand.daten.positionen[0].id);
                    }
                });
            })();
            ```
    }
    css {
        inline:
            ```css
            .thg-pos-leiste { display: flex; flex-wrap: wrap; gap: .25rem; margin-bottom: .5rem; }
            .thg-pos-baum { border: 1px solid var(--ut-component-border-color, #dcdcdc); border-radius: .25rem; max-height: 34rem; overflow: auto; background: var(--ut-component-background-color, #fff); }
            .thg-pos-knoten { display: flex; align-items: baseline; gap: .5rem; padding: .4rem .6rem; cursor: pointer; border-bottom: 1px solid var(--ut-component-inner-border-color, #eee); }
            .thg-pos-knoten:last-child { border-bottom: 0; }
            .thg-pos-knoten:hover, .thg-pos-knoten:focus { background: rgba(0, 0, 0, .04); outline: none; }
            .thg-pos-knoten.is-selected { background: rgba(0, 0, 0, .07); box-shadow: inset 4px 0 0 var(--thg-primaer, #0572ce); }
            .thg-pos-haupt { font-weight: 600; }
            .thg-pos-unter { padding-left: 2rem; }
            .thg-pos-versteckt { display: none; }
            .thg-pos-schalter { flex: 0 0 1rem; width: 1rem; align-self: center; text-align: center; opacity: .7; }
            .thg-pos-schalter.fa { cursor: pointer; }
            .thg-pos-schalter.fa:hover { opacity: 1; }
            .thg-pos-nr { min-width: 1.75rem; text-align: end; opacity: .7; font-variant-numeric: tabular-nums; }
            .thg-pos-name { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .thg-pos-summe { white-space: nowrap; font-variant-numeric: tabular-nums; }
            .thg-pos-optional .thg-pos-name, .thg-pos-optional .thg-pos-summe { font-style: italic; opacity: .7; }
            .thg-pos-hinweis { font-size: .75rem; font-weight: 400; font-style: normal; border: 1px solid transparent; border-radius: .75rem; padding: 0 .45rem; margin-left: .25rem; }
            .thg-pos-hinweis-optional { background: #fdf3c7; border-color: #ead98a; color: #6a5300; }
            .thg-pos-hinweis-pauschal { background: #fbe1df; border-color: #efb5b0; color: #8a221a; }
            .thg-pos-leer { padding: .75rem; opacity: .7; }
            /* Raster der Unterpositionen: "Zeile hinzufügen" entfaellt (dafuer "Schnelleingabe" und "Zeile Detail") */
            #positionen .a-Toolbar-group:has(> [data-action="selection-add-row"]), #positionen button[data-action="selection-add-row"] { display: none !important; }
            .thg-pos-knoten[draggable="true"] { cursor: grab; }
            .thg-pos-knoten.is-gezogen { opacity: .4; }
            .thg-pos-knoten.thg-drop-vor, .thg-pos-ende.thg-drop-vor { box-shadow: inset 0 3px 0 var(--thg-primaer, #0572ce); }
            .thg-pos-knoten.thg-drop-nach { box-shadow: inset 0 -3px 0 var(--thg-primaer, #0572ce); }
            .thg-pos-knoten.thg-drop-in { background: rgba(0, 0, 0, .1); outline: 2px dashed var(--thg-primaer, #0572ce); outline-offset: -2px; }
            .thg-pos-ende { height: 1.25rem; }
            ```
    }
"""


def seite_11():
    s = KOPF(11, "Rechnung", "RECHNUNG").replace("title: Rechnung", "title: &P11_TITEL.")
    s = s.replace("    security {", POS_JS + "    security {", 1)
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
    # Registerkarten wie im Kundenstamm/Marchler: direkt unter der Titelleiste (Slot fullWidthContent, Klasse
    # thg-rds), "Alle" als Ebenen-Icon an erster Stelle (thg.js), geoeffnet wird immer die erste Karte (Allgemein);
    # danach je Region eine Karte – Allgemein, Kunde, Vortext, Positionen, Schlusstext, Zahlungen. Die Regionen
    # zeigen ihren Titel nur unter "Alle" (Kopf ausgeblendet, thg.css: thg-rds-alle)
    s += """    region rds (
        name: Bereiche
        type: regionDisplaySelector
        layout {
            sequence: 5
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

"""
    TAB = "        advanced {\n            regionDisplaySelector: true\n        }\n"
    OHNE_KOPF = "[\n                #DEFAULT#\n                t-Region--removeHeader js-removeLandmark\n            ]"
    s += region("allgemein", "Allgemein", 10, parent="rechnung", extra=NUR_LESEN + TAB, options=OHNE_KOPF)
    s += region("kunde", "Kunde", 20, parent="rechnung", extra=NUR_LESEN + TAB, options=OHNE_KOPF)
    # Unterregionen von "Kunde" nebeneinander (je halbe Breite, ohne eigenen Rahmen)
    halb = lambda r, neue_zeile: r.replace("            slot: subRegions\n",
        "            slot: subRegions\n" + ("" if neue_zeile else "            startNewRow: false\n") +
        "            columnSpan: 6\n", 1)
    s += halb(region("empfaenger", "Empfänger", 10, template="@/blank-with-attributes", parent="kunde"), True)
    s += halb(region("anschrift-vorschau", "Anschrift-Vorschau", 20, template="@/blank-with-attributes",
                     parent="kunde"), False)
    # Vortext vor den Positionen, Schlusstext danach (wie am Ausdruck); die Lieferadresse steht unter der
    # Anschrift-Vorschau des Kunden. Ein eigener Text der Zahlungsbedingungen entfaellt (Auswahl beim Kunden).
    s += region("vortext", "Vortext", 30, parent="rechnung", extra=NUR_LESEN + TAB, options=OHNE_KOPF)
    s += region("schlusstext", "Schlusstext", 45, extra=NUR_LESEN + TAB, options=OHNE_KOPF)

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

    pageItem P11_BEARBEITEN (
        type: hidden
        layout {
            sequence: 4
            region: @kunde
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

    pageItem P11_PDF_OEFFNEN (
        type: hidden
        layout {
            sequence: 5
            region: @kunde
            slot: regionBody
        }
    )

    pageItem P11_SELBST_URL (
        type: hidden
        layout {
            sequence: 7
            region: @kunde
            slot: regionBody
        }
        settings {
            valueProtected: false
        }
    )

    pageItem P11_PDF_URL (
        type: hidden
        layout {
            sequence: 6
            region: @kunde
            slot: regionBody
        }
        settings {
            valueProtected: false
        }
    )

"""
    a = "allgemein"
    # Rechnungsnummer und Rechnungsdatum (beide vergibt "Rechnung abschliessen") nur Anzeige,
    # leicht hervorgehoben (thg.css .thg-hervorheben)
    s += hervorheben(item("P11_RECH_NUMMER", "displayOnly", "Rechnungsnummer", 10, a, col="RECH_NUMMER", spalten=3, **f))
    s += hervorheben(item("P11_RECH_DATUM", "displayOnly", "Rechnungsdatum", 20, a, col="RECH_DATUM", dtype="date",
              neue_zeile=False, spalten=3, **f))
    s += item("P11_RECH_FAELLIG_AM", "datePicker", "Fällig am (leer: aus Zahlungsbedingung)", 30, a,
              col="RECH_FAELLIG_AM", dtype="date", neue_zeile=False, spalten=6, **f)
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

"""
    s += item("P11_RECH_PROJEKT", "textField", "Projekt", 70, a, col="RECH_PROJEKT", maxlen=200,
              spalten=6, **f)
    s += item("P11_RECH_MITA_ID", "selectList", "Bearbeiter", 80, a, col="RECH_MITA_ID", dtype="number",
              neue_zeile=False, spalten=6, extra=lov("lov-mitarbeiter", "-") + default_sql(
                  "select MITA_ID from ALLG_MITARBEITER where MITA_BENUTZERNAME = :APP_USER"), **f)
    s += item("P11_RECH_IST_BRUTTO", "switch", "Preise sind brutto", 90, a, col="RECH_IST_BRUTTO", spalten=3,
              extra=SWITCH("N"), **f)
    s += item("P11_RECH_IST_FAELLIGKEIT_ANZEIGEN", "switch", "Fälligkeit anzeigen", 100, a,
              col="RECH_IST_FAELLIGKEIT_ANZEIGEN", neue_zeile=False, spalten=3, extra=SWITCH("N"), **f)
    # Status als Anzeigetext (FAKT_RECHNUNG.status_text), gespeichert bleibt der Code. Die LOV-Abfrage muss mit select
    # beginnen – ein fuehrender Kommentar laesst APEX sie als PL/SQL ausfuehren (PLS-00428)
    s += item("P11_RECH_STATUS", "displayOnly", "Status", 120, a, col="RECH_STATUS", neue_zeile=False, spalten=3,
              extra="""        settings {
            basedOn: lov
        }
        lov {
            type: sqlQuery
            sqlQuery:
                ```sql
                select FAKT_RECHNUNG.status_text(column_value) d, column_value r
                  from table(sys.odcivarchar2list('ENTWURF', 'GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT', 'STORNIERT'))
                ```
        }
        default {
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
    # Empfaenger in zwei Unterregionen nebeneinander: links die Felder untereinander (Firmenname, Kontaktperson,
    # Adresse, PLZ/Ort/Land, UID-Nr.), rechts die Anschrift wie am Ausdruck (nur Anzeige, per Dynamic Action
    # "Anschrift-Vorschau" sofort aktualisiert; thg.css .thg-anschrift: Zeilenumbrueche)
    e, v = "empfaenger", "anschrift-vorschau"
    s += item("P11_RECH_EMPF_NAME", "textField", "Firmenname", 10, e, col="RECH_EMPF_NAME", maxlen=400, **f)
    s += item("P11_RECH_EMPF_KONTAKTPERSON", "textField", "Kontaktperson", 20, e, col="RECH_EMPF_KONTAKTPERSON",
              maxlen=200, **f)
    s += item("P11_RECH_EMPF_STRASSE", "textField", "Adresse", 30, e, col="RECH_EMPF_STRASSE", maxlen=250, **f)
    s += item("P11_RECH_EMPF_PLZ", "textField", "PLZ", 40, e, col="RECH_EMPF_PLZ", maxlen=10, spalten=3, **f)
    s += item("P11_RECH_EMPF_ORT", "textField", "Ort", 50, e, col="RECH_EMPF_ORT", maxlen=100, neue_zeile=False,
              spalten=5, **f)
    s += item("P11_RECH_EMPF_LAND_CODE", "selectList", "Land", 60, e, col="RECH_EMPF_LAND_CODE",
              neue_zeile=False, spalten=4, extra=lov("lov-laender", "-"), **f)
    s += item("P11_RECH_EMPF_UID_NUMMER", "textField", "UID-Nr.", 70, e, col="RECH_EMPF_UID_NUMMER", maxlen=20, **f)
    s += item("P11_ANSCHRIFT", "displayOnly", "Kunde (Anschrift)", 10, v, **f).replace(
        "            templateOptions: #DEFAULT#\n        }\n",
        "            templateOptions: #DEFAULT#\n            cssClasses: thg-anschrift\n        }\n", 1)

    txt = lambda art: default_sql(f"select TXVL_TEXT from ALLG_TEXTVORLAGEN where TXVL_ART = '{art}' and TXVL_IST_STANDARD = 'Y'")
    s += item("P11_RECH_VORTEXT", "textarea", "Vortext", 10, "vortext", col="RECH_VORTEXT", dtype="clob",
              spalten=12, extra=txt("VORTEXT"), **f)
    s += item("P11_RECH_SCHLUSSTEXT", "textarea", "Schlusstext", 10, "schlusstext", col="RECH_SCHLUSSTEXT",
              dtype="clob", spalten=12, extra=txt("SCHLUSSTEXT"), **f)
    # Lieferadresse als Textblock unter der Anschrift des Kunden (gleiche Darstellung, thg.css .thg-anschrift)
    s += item("P11_RECH_LIEFERADRESSE", "textarea", "Lieferadresse", 20, v,
              col="RECH_LIEFERADRESSE", maxlen=1000, **f).replace(
        "            templateOptions: #DEFAULT#\n        }\n",
        "            templateOptions: #DEFAULT#\n            cssClasses: thg-anschrift\n        }\n", 1)

    # ------------------------------------------------ Positionen: Baum (links) | Felder der Position und Raster (rechts)
    s += region("positionen-bereich", "Positionen", 40, bedingung="P11_RECH_ID", extra=TAB, options=OHNE_KOPF)
    spalte = lambda r, breite, neue_zeile: r.replace(
        "            slot: subRegions\n",
        "            slot: subRegions\n" + ("" if neue_zeile else "            startNewRow: false\n")
        + f"            columnSpan: {breite}\n", 1)
    dom_id = lambda sid: f"        advanced {{\n            htmlDomId: {sid}\n        }}\n"
    html = lambda code: "        source {\n            htmlCode:\n                ```html\n" + code + "                ```\n        }\n"
    knopf = lambda sid, label, icon, klassen="": (
        f"                    <button type=\"button\" id=\"{sid}\" class=\"t-Button t-Button--small t-Button--icon t-Button--iconLeft {klassen}\">"
        f"<span class=\"t-Icon t-Icon--left fa {icon}\" aria-hidden=\"true\"></span>"
        f"<span class=\"t-Button-label\">{label}</span></button>\n")
    blank = "@/blank-with-attributes"
    s += spalte(region("pos-links", "Positionen (links)", 10, template=blank, parent="positionen-bereich"), 4, True)
    s += region("pos-baum-region", "Rechnungsübersicht", 5, parent="pos-links",
                       extra=html("                <div class=\"thg-pos-leiste\">\n"
                                  + knopf("pos-neu-haupt", "Hauptposition", "fa-plus")
                                  + knopf("pos-neu-unter", "Unterposition", "fa-plus")
                                  + knopf("pos-loeschen", "Löschen", "fa-trash-o", "t-Button--danger t-Button--simple")
                                  + "                </div>\n"
                                  + "                <div id=\"pos-baum\" class=\"thg-pos-baum\" role=\"tree\" aria-label=\"Positionen\"></div>\n"
                                  + "                <div id=\"pos-ende\" class=\"thg-pos-ende\"></div>\n"))
    s += region("summen", "Summen", 10, parent="pos-links",
                extra=html("                <div id=\"summen-inhalt\" class=\"thg-summen\"></div>\n"))
    s += spalte(region("pos-rechts", "Position", 20, template=blank, parent="positionen-bereich"), 8, False)
    # Felder der Position in einer Region im Stil von "Unterpositionen": der Titel (z.B. "Hauptposition 1: …") wird per
    # JavaScript gesetzt, der Button "Position speichern" beim Laden in den Kopf der Region verschoben
    s += region("pos-detail", "Position", 10, parent="pos-rechts",
                extra=dom_id("pos-detail")
                + html("                <button type=\"button\" class=\"t-Button t-Button--hot thg-pos-speichern\">"
                       "<span class=\"t-Button-label\">Position speichern</span></button>\n"))
    s += region("pos-felder", "Position (Felder)", 20, template=blank, parent="pos-detail", extra=dom_id("pos-felder"))
    # Felder der gewaehlten Position: ohne Formularquelle, per AJAX geladen (POS_LADEN) und gespeichert (POS_SPEICHERN).
    # Keine Pflichtfeld-Pruefung am Element (wuerde das Speichern der Rechnung blockieren) – geprueft wird im Prozess.
    p = "pos-felder"
    ohne = dict(form=None)
    ignorieren = "        advanced {\n            warnOnUnsavedChanges: ignore\n        }\n"
    # Anzeigefelder werden per JavaScript gesetzt: nicht absenden (sonst "Session state protection violation")
    nur_anzeige = "        settings {\n            sendOnPageSubmit: false\n        }\n"
    # P11_HAUPT_ID: gewaehlte Hauptposition fuer das Raster der Unterpositionen. Vom Browser gesetzt und mit jeder
    # Anfrage des Rasters mitgeschickt (pageItemsToSubmit) – nicht nur im Sitzungsstatus, damit zwei Browser-Tabs
    # derselben Sitzung einander nicht die Hauptposition unterschieben. Textfeld (frei setzbar), per CSS ausgeblendet.
    s += item("P11_HAUPT_ID", "textField", "Hauptposition (intern)", 1, p, extra=ignorieren, **ohne).replace(
        "            templateOptions: #DEFAULT#\n        }\n",
        "            templateOptions: #DEFAULT#\n            cssClasses: u-hidden\n        }\n", 1)
    # Zeile 1: Artikel | Artikelnummer | Gruppe (nur Positionen ohne Unterpositionen)
    s += item("P11_POS_ARTI_ID", "popupLov", "Artikel (Suche nach Gruppe, Artikelnummer, Name)", 10, p, spalten=6,
              extra="""        lov {
            type: sharedComponent
            lov: @lov-artikel
            displayNullValue: true
            nullDisplayValue: - ohne Artikel -
        }
""" + ignorieren, **ohne)
    s += item("P11_POS_ARTIKELNUMMER", "displayOnly", "Artikelnummer", 20, p, neue_zeile=False, spalten=3,
              extra=nur_anzeige, **ohne)
    s += item("P11_POS_GRUPPE", "displayOnly", "Gruppe", 30, p, neue_zeile=False, spalten=3, extra=nur_anzeige, **ohne)
    # Zeile 2: Name | Optional (die Positionsnummer ergibt sich aus der Reihenfolge im Baum)
    s += item("P11_POS_NAME", "textField", "Name", 50, p, maxlen=200, spalten=9,
              tmpl="@/required-floating", extra=ignorieren, **ohne)
    s += item("P11_POS_OPTIONAL", "switch", "Optional (nicht in der Summe)", 60, p, neue_zeile=False, spalten=3,
              extra=SWITCH("N") + ignorieren, **ohne)
    # Zeile 3: Einzelpreis | Einheit | Menge | MwSt. (nur Unterpositionen)
    s += maske(item("P11_POS_EINZELPREIS", "numberField", "Einzelpreis", 70, p, spalten=3, extra=ignorieren, **ohne),
               "999G999G990D00")
    s += item("P11_POS_EINHEIT", "selectList", "Einheit", 80, p, neue_zeile=False, spalten=3,
              extra=lov("lov-einheiten-code", "-") + ignorieren, **ohne)
    s += item("P11_POS_MENGE", "numberField", "Menge", 90, p, neue_zeile=False, spalten=3, extra=ignorieren, **ohne)
    s += item("P11_POS_MWST", "selectList", "MwSt. in %", 100, p, neue_zeile=False, spalten=3,
              extra=lov("lov-mwst-prozent") + ignorieren, **ohne)
    # Zeile 4: Rabatt | Summe (Unterposition bzw. Unterpositionen der Hauptposition, abzgl. Rabatt) | Pauschalsumme
    # (nur Hauptposition; gilt in der Rechnung statt der Summe)
    s += item("P11_POS_RABATT", "numberField", "Rabatt %", 120, p, spalten=3, extra=ignorieren, **ohne)
    s += hervorheben(item("P11_POS_SUMME", "displayOnly", "Summe", 130, p, neue_zeile=False, spalten=3,
                          extra=nur_anzeige, **ohne))
    s += maske(item("P11_POS_PAUSCHAL", "numberField", "Pauschalsumme der Hauptposition (statt Summe)", 140, p, neue_zeile=False,
                    spalten=4, extra=ignorieren, **ohne), "999G999G990D00")
    s += item("P11_POS_BESCHREIBUNG", "richTextEditor", "Beschreibung", 150, p, spalten=12, extra=ignorieren, **ohne)

    # Raster der Unterpositionen der gewaehlten Hauptposition (P11_HAUPT_ID, vom Browser gesetzt und mitgeschickt);
    # Artikel als Popup LOV: Suche/Einschraenkung nach Gruppe, Artikelnummer, Name (Spalten von LOV_ARTIKEL im Portal)
    pos = (ig_spalte("RPOS_ID", "hidden", "ID", 10, "number", pk=True)
           + ig_spalte("RPOS_ARTI_ID", "popupLov", "Artikel", 50, "number",
                       IG_LOV("lov-artikel").replace("                displayExtraValues: false\n", ""))
           + ig_spalte("RPOS_NAME", "textField", "Name", 60, "varchar2")
           + ig_spalte("RPOS_MENGE", "numberField", "Menge", 70, "number", IG_DEFAULT(1))
           + ig_spalte("RPOS_EINHEIT", "selectList", "Einheit", 80, "varchar2", IG_LOV("lov-einheiten-code"))
           + ig_spalte("RPOS_EINZELPREIS", "numberField", "Einzelpreis", 90, "number", BETRAG)
           + ig_spalte("RPOS_RABATT_PROZENT", "numberField", "Rabatt %", 100, "number")
           + ig_spalte("RPOS_MWST_PROZENT", "selectList", "MwSt. %", 110, "number", IG_LOV("lov-mwst-prozent"))
           + ig_spalte("RPOS_IST_OPTIONAL", "selectList", "Optional", 120, "varchar2",
                       IG_LOV("lov-ja-nein", False) + IG_DEFAULT("N"))
           + ig_spalte("RPOS_SUMME", "numberField", "Summe", 130, "number", BETRAG)
           + ig_spalte("RPOS_BESCHREIBUNG", "richTextEditor", "Beschreibung", 140, "clob"))
    s += ig_region("positionen", "Unterpositionen", 40, """                select RPOS_ID, RPOS_ARTI_ID, RPOS_NAME,
                       RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT,
                       RPOS_IST_OPTIONAL, RPOS_SUMME, RPOS_BESCHREIBUNG
                  from FAKT_RECHNUNGSPOSITIONEN
                 where RPOS_RECH_ID = :P11_RECH_ID
                   and RPOS_HAUPT_RPOS_ID = to_number(:P11_HAUPT_ID)
                 order by RPOS_POSITION""", pos,
                   ["RPOS_ARTI_ID", "RPOS_NAME", "RPOS_MENGE", "RPOS_EINHEIT",
                    "RPOS_EINZELPREIS", "RPOS_RABATT_PROZENT", "RPOS_MWST_PROZENT", "RPOS_IST_OPTIONAL", "RPOS_SUMME"],
                   "", nur_lesen=NUR_LESEN).replace(
        "            sequence: 40\n            slot: body\n",
        "            sequence: 40\n            parentRegion: @pos-rechts\n            slot: subRegions\n", 1).replace(
        "                P11_RECH_ID\n            ]", "                P11_RECH_ID\n                P11_HAUPT_ID\n            ]", 1)

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
            plsqlExpression: :P11_RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT')
        }
""").replace("            htmlDomId: zahlungen\n", "            htmlDomId: zahlungen\n            regionDisplaySelector: true\n", 1) \
       .replace("            template: @/standard\n            templateOptions: #DEFAULT#\n",
                "            template: @/standard\n            templateOptions: " + OHNE_KOPF + "\n", 1)

    # Dokumente (nach Zahlungen): abgelegte Rechnungsdrucke (FAKT_RECHNUNG_DOKUMENTE, Skript 35) – jeder Druck nach
    # "Rechnung bearbeiten" als neue Version, aeltere bleiben; Anzeigen im PDF-Dialog (Seite 13 mit P13_RDOK_ID)
    s += """    region dokumente (
        name: Dokumente
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                -- Zeitpunkt in Wiener Zeit (Server UTC), neueste Version zuerst
                select RDOK_ID,
                       RDOK_VERSION as VERSION,
                       RDOK_BEZEICHNUNG as BEZEICHNUNG,
                       FAKT_RECHNUNG.status_text(RDOK_RECH_STATUS) as STATUS,
                       to_char(from_tz(RDOK_CREATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI:SS') as GEDRUCKT_AM,
                       RDOK_CREATED_BY as GEDRUCKT_VON,
                       to_char(round(RDOK_GROESSE / 1024), 'FM999G999G990') || ' KB' as GROESSE
                  from FAKT_RECHNUNG_DOKUMENTE
                 where RDOK_RECH_ID = :P11_RECH_ID
                 order by RDOK_VERSION desc
                ```
            pageItemsToSubmit: [
                P11_RECH_ID
            ]
        }
        advanced {
            regionDisplaySelector: true
            htmlDomId: dokumente
        }
        layout {
            sequence: 65
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: """ + OHNE_KOPF + """
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
        reportLayout {
            numberOfRowsType: staticValue
            numberOfRows: 50
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P11_RECH_ID
        }
        messages {
            whenNoDataFound: Noch keine Rechnung gedruckt.
        }

        column RDOK_ID (
            type: link
            heading {
                heading: Anzeigen
                alignment: center
            }
            layout {
                sequence: 10
                columnAlignment: center
            }
            link {
                target: {
                    page: 13
                    items: {
                        P13_RECH_ID: &P11_RECH_ID.
                        P13_RDOK_ID: #RDOK_ID#
                    }
                    clearCache: 13
                }
                linkText: <span role="img" aria-label="Anzeigen" class="fa fa-file-pdf-o" title="Anzeigen"></span>
            }
            sorting {
                sortable: false
            }
        )

""" + "".join(f"""        column {c} (
            type: plainText
            heading {{
                heading: {h}
            }}
            layout {{
                sequence: {i * 10}
            }}
            sorting {{
                sortable: false
            }}
        )

""" for i, (c, h) in enumerate((("VERSION", "Version"), ("BEZEICHNUNG", "Bezeichnung"), ("STATUS", "Status beim Druck"),
                                ("GEDRUCKT_AM", "Gedruckt am"), ("GEDRUCKT_VON", "Gedruckt von"),
                                ("GROESSE", "Größe")), start=2)) + """    )

"""

    # Historie (nach Zahlungen): wer hat wann was geaendert (FAKT_RECHNUNG_HISTORIE, Trigger aus Skript 33)
    s += """    region historie (
        name: Historie
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                -- Zeitpunkt in Wiener Zeit (Server UTC), neueste Eintraege zuerst
                select to_char(from_tz(RHIS_ZEITPUNKT, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI:SS') as ZEITPUNKT,
                       RHIS_BENUTZER as BENUTZER,
                       RHIS_AKTION as AKTION,
                       RHIS_DETAIL as DETAIL
                  from FAKT_RECHNUNG_HISTORIE
                 where RHIS_RECH_ID = :P11_RECH_ID
                 order by RHIS_ZEITPUNKT desc, RHIS_ID desc
                ```
            pageItemsToSubmit: [
                P11_RECH_ID
            ]
        }
        advanced {
            regionDisplaySelector: true
            htmlDomId: historie
        }
        layout {
            sequence: 70
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: """ + OHNE_KOPF + """
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
        reportLayout {
            numberOfRowsType: staticValue
            numberOfRows: 50
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P11_RECH_ID
        }
        messages {
            whenNoDataFound: Noch keine Einträge.
        }

""" + "".join(f"""        column {c} (
            type: plainText
            heading {{
                heading: {h}
            }}
            layout {{
                sequence: {i * 10}
            }}
            sorting {{
                sortable: false
            }}
        )

""" for i, (c, h) in enumerate((("ZEITPUNKT", "Zeitpunkt"), ("BENUTZER", "Benutzer"), ("AKTION", "Aktion"),
                                ("DETAIL", "Änderungen")), start=1)) + """    )

"""


    # ------------------------------------------------ Buttons
    grau = "[\n                #DEFAULT#\n                t-Button--noUI\n            ]"
    # kein Button "Zur Liste": zurueck geht es ueber den Pfeil in der Titelleiste
    entwurf = """        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS = 'ENTWURF'
        }
"""
    s += im_menue(button("delete", "DELETE", "Rechnung löschen", 15, "breadcrumb", "next",
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
"""), "thg-akt-loeschen")
    s += button("save", "SAVE", "Speichern", 20, "breadcrumb", "next", hot=False,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and (:P11_RECH_STATUS = 'ENTWURF' or nvl(:P11_BEARBEITEN, 'N') = 'Y')
        }
""")
    s += button("bearbeiten", "BEARBEITEN", "Rechnung bearbeiten", 18, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-pencil", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            requiresConfirmation: true
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS not in ('ENTWURF', 'STORNIERT') and nvl(:P11_BEARBEITEN, 'N') <> 'Y'
        }
        confirmation {
            message: Die Rechnung &P11_RECH_NUMMER. ist abgeschlossen. Wirklich ändern? Rechnungsnummer und Rechnungsdatum bleiben unverändert.
            style: warning
        }
""")
    # Rechnung stornieren (nur offen – GEDRUCKT/GESENDET – ohne Zahlung): oeffnet die Dialogseite 15 (Grund ist Pflicht).
    # Eigene Seite statt Inline-Dialog – der Inline-Dialog blitzte beim Aufbau der Seite immer wieder kurz auf.
    s += im_menue(button("stornieren", "STORNO", "Rechnung stornieren", 14, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-ban", options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n                t-Button--iconLeft\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 15
                items: {
                    P15_RECH_ID: &P11_RECH_ID.
                }
                clearCache: 15
            }
            warnOnUnsavedChanges: doNotCheck
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS in ('GEDRUCKT', 'GESENDET') and nvl(:P11_BEARBEITEN, 'N') <> 'Y'
        }
"""), "thg-akt-stornieren")
    # Rechnung 1:1 als neuen Entwurf kopieren (FAKT_RECHNUNG.kopieren), danach die Kopie oeffnen
    s += im_menue(button("kopieren", "KOPIEREN", "Rechnung kopieren", 16, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-copy", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            requiresConfirmation: true
""", bedingung="""        serverSideCondition {
            type: itemIsNotNull
            item: P11_RECH_ID
        }
        confirmation {
            message: Rechnung als neuen Entwurf kopieren? Nummer und Datum werden beim Abschließen der Kopie vergeben.
            style: information
        }
"""), "thg-akt-kopieren")
    # PDF-Ausdruck (Vorschau-Dialog Seite 13 mit Drucken/Herunterladen), sobald die Rechnung abgeschlossen ist
    # (Seite abschicken: nach "Rechnung bearbeiten" werden Aenderungen vorher gespeichert, danach oeffnet das PDF)
    s += button("pdf", "PDF", "Rechnung drucken", 17, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-file-pdf-o", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS <> 'ENTWURF'
        }
""")
    # Rechnungsvorschau (nur Entwurf): PDF mit Wasserzeichen "VORSCHAU", beliebig oft, Rechnung bleibt Entwurf
    # (Seite abschicken: ungespeicherte Aenderungen speichern, danach oeffnet die Seite das PDF - P11_PDF_OEFFNEN)
    s += button("vorschau", "VORSCHAU", "Rechnungsvorschau", 17, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-eye", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
""", bedingung=entwurf)
    # "Rechnung drucken" im Entwurf: speichern, abschliessen (Nummer, Rechnungsdatum) und danach das PDF oeffnen
    s += button("abschliessen", "ABSCHLIESSEN", "Rechnung drucken", 25, "breadcrumb", "next", "@/text-with-icon",
                hot=True, icon="fa-file-pdf-o", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
            requiresConfirmation: true
""", bedingung=entwurf + """        confirmation {
            message: Rechnung drucken? Die Rechnung wird abgeschlossen – Rechnungsnummer und Rechnungsdatum werden vergeben und können nicht mehr geändert werden. Zum Prüfen vorher die Rechnungsvorschau verwenden.
            style: warning
        }
""")
    # Weitere Aktionen (Kebab-Menue wie das Benutzermenue im Banner): Rechnung kopieren, stornieren, loeschen –
    # Menue per JavaScript (apex menu widget, js-menuButton/data-menu), Eintraege nur fuer sichtbare Buttons
    s += button("aktionen", "AKTIONEN", "Weitere Aktionen", 40, "breadcrumb", "next", "@/icon", icon="fa-ellipsis-v",
                options="[\n                #DEFAULT#\n                t-Button--noUI\n            ]",
                verhalten="            action: definedByDynamicAction\n", bedingung=NICHT_NULL("P11_RECH_ID")).replace(
        "        appearance {\n", "        advanced {\n            htmlDomId: thg-aktionen\n        }\n        appearance {\n"
        "            cssClasses: js-menuButton\n", 1)
    s += button("create", "CREATE", "Anlegen", 30, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P11_RECH_ID"))
    # Unterpositionen erfassen: Schnelleingabe (neue Zeile im Raster) oder Detail (Dialog Seite 14) – nur wenn aenderbar
    aenderbar = """        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and (:P11_RECH_STATUS = 'ENTWURF' or nvl(:P11_BEARBEITEN, 'N') = 'Y')
        }
"""
    links = "[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]"
    s += button("schnelleingabe", "SCHNELLEINGABE", "Schnelleingabe", 10, "positionen", "edit", "@/text-with-icon",
                icon="fa-bolt", options=links, verhalten="            action: definedByDynamicAction\n", bedingung=aenderbar)
    s += button("zeile-detail", "ZEILE_DETAIL", "Zeile Detail", 20, "positionen", "edit", "@/text-with-icon",
                icon="fa-plus", options=links, verhalten="            action: definedByDynamicAction\n", bedingung=aenderbar)
    s += button("up", "UP", "Zurück zur Rechnungsliste", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options=grau, verhalten="""            action: redirectThisApp
            target: {
                page: 10
            }
            warnOnUnsavedChanges: doNotCheck
""")

    # ------------------------------------------------ Prozesse
    s += da_klick("schnelleingabe", "Schnelleingabe: neue Zeile im Raster", 30, "schnelleingabe",
                  "window.thgPositionen.schnelleingabe();")
    s += da_klick("zeile-detail", "Zeile Detail: Unterposition im Dialog erfassen", 40, "zeile-detail",
                  "window.thgPositionen.detail();")
    s += """    dynamicAction nach-pdf-neu-laden (
        name: Nach dem Schließen des PDF die Rechnung neu laden
        execution {
            sequence: 6
        }
        when {
            event: apexafterclosedialog
            selectionType: jQuerySelector
            jquerySelector: body
        }

        action neu-laden (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript-browser
                    // nur nach dem PDF-Dialog (Seite 13 schliesst mit { pdf: 'Y' }): Maske mit Nummer, Datum, Status und
                    // Historie aus der Datenbank laden (der Druck wird erst beim Laden des PDF protokolliert)
                    if (this.data && this.data.pdf === "Y" && $v("P11_SELBST_URL")) {
                        apex.navigation.redirect($v("P11_SELBST_URL"));
                    }
                    ```
            }
            execution {
                sequence: 10
            }
        )

    )

"""
    # Historie nach dem Schliessen eines Dialogs (PDF-Anzeige, Unterposition) aktualisieren - der Druck wird erst
    # beim Laden des PDF protokolliert (Seite 12), die Seite ist dann schon aufgebaut
    for sid, ereignis in (("historie-nach-dialog", "apexafterclosedialog"), ("historie-nach-dialog-abbruch", "apexafterclosecanceldialog")):
        s += f"""    dynamicAction {sid} (
        name: Historie nach Dialog aktualisieren ({ereignis})
        execution {{
            sequence: 7
        }}
        when {{
            event: {ereignis}
            selectionType: jQuerySelector
            jquerySelector: body
        }}

        action {sid}-refresh (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @historie
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

"""
    s += """    dynamicAction storno-nach-dialog (
        name: Nach dem Stornieren die Rechnung neu laden
        execution {
            sequence: 6
        }
        when {
            event: apexafterclosedialog
            selectionType: button
            button: @stornieren
        }

        action storno-neu-laden (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript-browser
                    apex.navigation.redirect($v("P11_SELBST_URL"));
                    ```
            }
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

"""
    s += """    dynamicAction pdf-oeffnen (
        name: Nach dem Abschließen das PDF öffnen
        execution {
            sequence: 5
        }
        when {
            event: ready
        }
        clientSideCondition {
            type: itemIsNotNull
            item: P11_PDF_URL
        }

        action pdf-dialog (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript-browser
                    apex.navigation.redirect($v("P11_PDF_URL"));
                    ```
            }
            execution {
                sequence: 10
            }
        )

    )

    dynamicAction anschrift-vorschau (
        name: Anschrift-Vorschau wie am Ausdruck
        execution {
            sequence: 20
        }
        when {
            event: change
            selectionType: items
            items: P11_RECH_EMPF_NAME,P11_RECH_EMPF_KONTAKTPERSON,P11_RECH_EMPF_STRASSE,P11_RECH_EMPF_PLZ,P11_RECH_EMPF_ORT,P11_RECH_EMPF_LAND_CODE,P11_RECH_EMPF_UID_NUMMER
        }

        action anschrift-zusammensetzen (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript
                    // wie der Rechnungsdruck: Firmenname / Kontaktperson / Adresse / PLZ Ort / Land / UID – leere Zeilen entfallen
                    var landFeld = document.getElementById("P11_RECH_EMPF_LAND_CODE"),
                        // Auswahlliste: Text der gewaehlten Option; schreibgeschuetzt rendert APEX ein Textfeld mit dem Anzeigewert
                        land = $v("P11_RECH_EMPF_LAND_CODE")
                               ? (landFeld.tagName === "SELECT" ? $(landFeld).find("option:selected").text() : landFeld.value).split(" (")[0]
                               : "",   // ohne Ländercode
                        uid  = $v("P11_RECH_EMPF_UID_NUMMER"),
                        kontakt = $v("P11_RECH_EMPF_KONTAKTPERSON"),
                        zeilen = [$v("P11_RECH_EMPF_NAME"),
                                  kontakt,
                                  $v("P11_RECH_EMPF_STRASSE"),
                                  ($v("P11_RECH_EMPF_PLZ") + " " + $v("P11_RECH_EMPF_ORT")).trim(),
                                  land,
                                  uid].filter(Boolean);
                    $("#P11_ANSCHRIFT_DISPLAY").text(zeilen.join(String.fromCharCode(10)));   // Zeilenumbruch
                    ```
            }
            execution {
                sequence: 10
                fireOnInit: true
            }
        )

    )

    dynamicAction kunde-gewaehlt (
        name: Kunde gewählt: Empfängerdaten übernehmen
        execution {
            sequence: 10
        }
        when {
            event: change
            selectionType: items
            items: P11_RECH_KUND_ID
        }

        action empfaenger-laden (
            action: executeServerSideCode
            settings {
                plsqlCode:
                    ```plsql
                    -- Empfaengerdaten des gewaehlten Kunden sofort in die Maske (danach aenderbar)
                    declare
                        e FAKT_RECHNUNG.t_empfaenger := FAKT_RECHNUNG.empfaenger(:P11_RECH_KUND_ID);
                    begin
                        :P11_RECH_EMPF_NAME          := e.name;
                        :P11_RECH_EMPF_KONTAKTPERSON := e.kontaktperson;
                        :P11_RECH_EMPF_UID_NUMMER    := e.uid_nummer;
                        :P11_RECH_EMPF_STRASSE       := e.strasse;
                        :P11_RECH_EMPF_PLZ           := e.plz;
                        :P11_RECH_EMPF_ORT           := e.ort;
                        :P11_RECH_EMPF_LAND_CODE     := e.land_code;
                        :P11_RECH_ZBED_ID            := e.zbed_id;
                    end;
                    ```
                itemsToSubmit: P11_RECH_KUND_ID
                itemsToReturn: P11_RECH_EMPF_NAME,P11_RECH_EMPF_KONTAKTPERSON,P11_RECH_EMPF_UID_NUMMER,P11_RECH_EMPF_STRASSE,P11_RECH_EMPF_PLZ,P11_RECH_EMPF_ORT,P11_RECH_EMPF_LAND_CODE,P11_RECH_ZBED_ID
            }
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

        action anschrift-aktualisieren (
            action: executeJsCode
            settings {
                jsCode: $("#P11_RECH_EMPF_NAME").trigger("change");
            }
            execution {
                sequence: 20
                fireOnInit: false
            }
        )

    )

    process bearbeitung-freigeben (
        name: Abgeschlossene Rechnung zur Bearbeitung freigeben
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- bewusste Aktion "Rechnung bearbeiten": Maske und Positionen fuer diese Rechnung wieder aenderbar
                :P11_BEARBEITEN := 'Y';
                FAKT_HISTORIE.protokoll(:P11_RECH_ID, 'Zur Bearbeitung geöffnet',
                                        'Rechnung ' || :P11_RECH_NUMMER || ' (Status ' || FAKT_RECHNUNG.status_text(:P11_RECH_STATUS) || ')');
                ```
        }
        execution {
            sequence: 1
        }
        serverSideCondition {
            whenButtonPressed: @bearbeiten
        }
        successMessage {
            successMessage: Rechnung zur Bearbeitung freigegeben.
        }
    )

    process pdf-oeffnen-vorbereiten (
        name: PDF nach dem Abschließen öffnen (einmalig)
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Dialog-URL (javascript:apex.navigation.dialog …) fuer die Dynamic Action beim Laden; Merker zuruecksetzen
                :P11_PDF_URL := case when :P11_PDF_OEFFNEN = 'Y' and :P11_RECH_ID is not null then
                                    apex_page.get_url(p_page => 13, p_clear_cache => 13, p_items => 'P13_RECH_ID', p_values => :P11_RECH_ID)
                                end;
                -- "Rechnung drucken" nach "Rechnung bearbeiten" schliesst die Bearbeitung ab: Rechnung wieder gesperrt,
                -- Button "Rechnung bearbeiten" wieder sichtbar (Aenderungen sind vorher gespeichert)
                if :P11_PDF_OEFFNEN = 'Y' and nvl(:P11_BEARBEITEN, 'N') = 'Y' then
                    :P11_BEARBEITEN := null;
                    FAKT_HISTORIE.protokoll(:P11_RECH_ID, 'Bearbeitung abgeschlossen', 'Rechnung ' || :P11_RECH_NUMMER);
                end if;
                :P11_PDF_OEFFNEN := null;
                -- eigene URL (mit Pruefsumme, ohne P11_PDF_OEFFNEN) zum Neuladen nach dem Schliessen des PDF-Dialogs
                :P11_SELBST_URL := case when :P11_RECH_ID is not null then
                                       apex_page.get_url(p_page => 11, p_items => 'P11_RECH_ID', p_values => :P11_RECH_ID)
                                   end;
                ```
        }
        execution {
            sequence: 2
            point: beforeHeader
        }
    )

    process initialize-form-rechnung (
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
                ```
        }
        execution {
            sequence: 20
            point: beforeHeader
        }
    )

    process artikel-daten (
        name: ARTIKEL_DATEN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Artikeldaten fuer eine Position (AJAX aus dem Raster "positionen" und den Feldern P11_POS_*):
                -- Werte im Format der Sitzung
                declare
                    a      ARTI_ARTIKEL%rowtype;
                    l_einh ALLG_EINHEITEN.EINH_CODE%type;
                    l_mwst ALLG_MWST_SAETZE.MWST_PROZENT%type;
                begin
                    select * into a from ARTI_ARTIKEL where ARTI_ID = to_number(apex_application.g_x01);
                    select max(EINH_CODE) into l_einh from ALLG_EINHEITEN where EINH_ID = a.ARTI_EINH_ID;
                    select max(MWST_PROZENT) into l_mwst from ALLG_MWST_SAETZE where MWST_ID = a.ARTI_MWST_ID;
                    apex_json.open_object;
                    apex_json.write('name', a.ARTI_NAME);
                    apex_json.write('einheit', l_einh);
                    apex_json.write('preis', to_char(a.ARTI_VK_PREIS, 'FM999999990D00'));
                    apex_json.write('mwst', to_char(l_mwst));
                    apex_json.write('mwst_anzeige', to_char(l_mwst, 'FM990D00') || ' %');   -- wie LOV_MWST_PROZENT
                    apex_json.write('beschreibung', a.ARTI_BESCHREIBUNG);
                    apex_json.write('artikelnummer', a.ARTI_NUMMER);
                    for g in (select AGRP_BEZEICHNUNG from ARTI_ARTIKELGRUPPEN where AGRP_ID = a.ARTI_AGRP_ID) loop
                        apex_json.write('gruppe', g.AGRP_BEZEICHNUNG);
                    end loop;
                    apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 10
            point: ajaxCallback
        }
    )

    process detail-url (
        name: DETAIL_URL
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- URL des Dialogs "Unterposition" (Seite 14, mit Pruefsumme): x01 = RPOS_ID (leer = neue Unterposition),
                -- x02 = Hauptposition; der Dialog meldet sein Schliessen an die Region "positionen" (apexafterclosedialog)
                declare
                    l_id    varchar2(40) := apex_application.g_x01;
                    l_haupt varchar2(40) := apex_application.g_x02;
                    l_anz   pls_integer;
                begin
                    select count(*) into l_anz
                      from FAKT_RECHNUNGSPOSITIONEN
                     where RPOS_ID = to_number(l_haupt) and RPOS_RECH_ID = :P11_RECH_ID and RPOS_HAUPT_RPOS_ID is null;
                    if l_anz = 0 then
                        raise_application_error(-20215, 'Bitte zuerst eine Hauptposition wählen.');
                    end if;
                    if l_id is not null then
                        select count(*) into l_anz
                          from FAKT_RECHNUNGSPOSITIONEN
                         where RPOS_ID = to_number(l_id) and RPOS_RECH_ID = :P11_RECH_ID and RPOS_HAUPT_RPOS_ID = to_number(l_haupt);
                        if l_anz = 0 then
                            raise_application_error(-20211, 'Die Position gehört nicht zu dieser Hauptposition.');
                        end if;
                    end if;
                    apex_json.open_object;
                    apex_json.write('url', apex_page.get_url(p_page               => 14,
                                                             p_clear_cache        => '14',
                                                             p_items              => 'P14_RPOS_ID,P14_RECH_ID,P14_HAUPT_ID',
                                                             p_values             => l_id || ',' || :P11_RECH_ID || ',' || l_haupt,
                                                             p_triggering_element => 'apex.jQuery(''#positionen'')'));
                    apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 15
            point: ajaxCallback
        }
    )

    process positionen-json (
        name: POSITIONEN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Baum der Positionen (Hauptpositionen mit Unterpositionen) und Summen der Rechnung als JSON;
                -- aenderbar: Entwurf oder nach "Rechnung bearbeiten". IDs als Text (zu gross fuer JavaScript-Zahlen).
                declare
                    l_mand    FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    l_status  FAKT_RECHNUNGEN.RECH_STATUS%type;
                    l_netto   number := 0;
                    l_mwst    number := 0;
                    l_bezahlt number;
                    l_anz     pls_integer := 0;
                    function eur(p_wert in number) return varchar2 is
                    begin
                        return to_char(p_wert, 'FML999G999G990D00');
                    end;
                    procedure knoten(p in FAKT_RECHNUNGSPOSITIONEN%rowtype) is
                    begin
                        apex_json.write('id', to_char(p.RPOS_ID));
                        apex_json.write('pos', p.RPOS_POSITION);
                        apex_json.write('name', p.RPOS_NAME);
                        apex_json.write('summe', eur(p.RPOS_SUMME));
                        apex_json.write('optional', p.RPOS_IST_OPTIONAL = 'Y');
                        apex_json.write('pauschal', p.RPOS_PAUSCHALSUMME is not null);
                    end;
                    procedure summe(p_label in varchar2, p_wert in number, p_fett in boolean default false) is
                    begin
                        apex_json.open_object;
                        apex_json.write('label', p_label);
                        apex_json.write('betrag', eur(p_wert));
                        apex_json.write('fett', p_fett);
                        apex_json.close_object;
                    end;
                begin
                    select RECH_MAND_ID, RECH_STATUS into l_mand, l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    apex_json.open_object;
                    apex_json.write('aenderbar', l_status = 'ENTWURF' or nvl(:P11_BEARBEITEN, 'N') = 'Y');
                    apex_json.open_array('positionen');
                    for h in (select * from FAKT_RECHNUNGSPOSITIONEN
                               where RPOS_RECH_ID = :P11_RECH_ID and RPOS_HAUPT_RPOS_ID is null
                               order by RPOS_POSITION)
                    loop
                        l_anz := l_anz + 1;
                        apex_json.open_object;
                        knoten(h);
                        apex_json.open_array('unter');
                        for u in (select * from FAKT_RECHNUNGSPOSITIONEN where RPOS_HAUPT_RPOS_ID = h.RPOS_ID order by RPOS_POSITION) loop
                            apex_json.open_object;
                            knoten(u);
                            apex_json.close_object;
                        end loop;
                        apex_json.close_array;
                        apex_json.close_object;
                    end loop;
                    apex_json.close_array;
                    -- Summen je Steuersatz wie am Ausdruck (FAKT_RECHNUNG_MWST_V), Bezahlt/Offen aus den Zahlungen
                    apex_json.open_array('summen');
                    if l_anz > 0 then
                        select nvl(sum(NETTO), 0), nvl(sum(MWST), 0) into l_netto, l_mwst
                          from FAKT_RECHNUNG_MWST_V where RECH_ID = :P11_RECH_ID;
                        summe('Netto', l_netto);
                        for m in (select MWST_PROZENT, MWST from FAKT_RECHNUNG_MWST_V where RECH_ID = :P11_RECH_ID
                                   order by MWST_PROZENT desc)
                        loop
                            summe(rtrim(to_char(m.MWST_PROZENT, 'FM990D99'), ',.') || ' % MwSt.', m.MWST);
                        end loop;
                        summe('Gesamtbetrag', l_netto + l_mwst, true);
                        if l_status <> 'ENTWURF' then
                            select nvl(sum(ZAHL_BETRAG + nvl(ZAHL_SKONTO, 0)), 0) into l_bezahlt
                              from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = :P11_RECH_ID;
                            summe('Bezahlt', l_bezahlt);
                            summe('Offen', l_netto + l_mwst - l_bezahlt, true);
                        end if;
                    end if;
                    apex_json.close_array;
                    apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 20
            point: ajaxCallback
        }
    )

    process pos-laden (
        name: POS_LADEN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Felder einer Position fuer die Anzeige rechts: x01 = RPOS_ID (leer = neue Position mit Vorgaben),
                -- x02 = Hauptposition einer neuen Unterposition. Zahlen im Format der Felder (Dezimalkomma).
                declare
                    c_nls constant varchar2(40) := 'NLS_NUMERIC_CHARACTERS='',.''';
                    l_id      number := to_number(apex_application.g_x01);
                    l_haupt   number := to_number(apex_application.g_x02);
                    l_mand    FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    p         FAKT_RECHNUNGSPOSITIONEN%rowtype;
                    l_unter   pls_integer := 0;
                    l_hpos    FAKT_RECHNUNGSPOSITIONEN.RPOS_POSITION%type;
                    l_artnr   ARTI_ARTIKEL.ARTI_NUMMER%type;
                    l_artname ARTI_ARTIKEL.ARTI_NAME%type;
                    l_gruppe  ARTI_ARTIKELGRUPPEN.AGRP_BEZEICHNUNG%type;
                    function preis(p_wert in number) return varchar2 is
                    begin
                        return to_char(p_wert, 'FM999G999G990D00', c_nls);
                    end;
                    -- Menge, Rabatt: ohne ueberfluessige Nachkommastellen
                    function zahl(p_wert in number) return varchar2 is
                    begin
                        return rtrim(rtrim(to_char(p_wert, 'FM999999990D999', c_nls), '0'), ',');
                    end;
                begin
                    select RECH_MAND_ID into l_mand from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    if l_id is not null then
                        select * into p from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = l_id and RPOS_RECH_ID = :P11_RECH_ID;
                        select count(*) into l_unter from FAKT_RECHNUNGSPOSITIONEN where RPOS_HAUPT_RPOS_ID = l_id;
                    else
                        p.RPOS_HAUPT_RPOS_ID := l_haupt;
                        p.RPOS_POSITION      := FAKT_RECHNUNG.naechste_position(:P11_RECH_ID, l_haupt);
                        p.RPOS_MENGE         := 1;
                        p.RPOS_EINZELPREIS   := 0;
                        p.RPOS_IST_OPTIONAL  := 'N';
                        select max(MWST_PROZENT) into p.RPOS_MWST_PROZENT from ALLG_MWST_SAETZE where MWST_IST_STANDARD = 'Y';
                    end if;
                    if p.RPOS_HAUPT_RPOS_ID is not null then
                        select RPOS_POSITION into l_hpos
                          from FAKT_RECHNUNGSPOSITIONEN
                         where RPOS_ID = p.RPOS_HAUPT_RPOS_ID and RPOS_RECH_ID = :P11_RECH_ID and RPOS_HAUPT_RPOS_ID is null;
                    end if;
                    for a in (select a.ARTI_NUMMER, a.ARTI_NAME, g.AGRP_BEZEICHNUNG
                                from ARTI_ARTIKEL a
                                left join ARTI_ARTIKELGRUPPEN g on g.AGRP_ID = a.ARTI_AGRP_ID
                               where a.ARTI_ID = p.RPOS_ARTI_ID)
                    loop
                        l_artnr   := a.ARTI_NUMMER;
                        l_artname := a.ARTI_NAME;
                        l_gruppe  := a.AGRP_BEZEICHNUNG;
                    end loop;

                    apex_json.open_object;
                    apex_json.write('id', to_char(l_id));
                    apex_json.write('haupt_id', to_char(p.RPOS_HAUPT_RPOS_ID));
                    apex_json.write('unter', l_unter);
                    apex_json.write('summe_unterpos', nvl(p.RPOS_SUMME_UNTERPOS, 0));
                    apex_json.write('titel', case when l_id is null then 'Neue ' end
                                             || case when p.RPOS_HAUPT_RPOS_ID is null then 'Hauptposition ' || p.RPOS_POSITION
                                                     else 'Unterposition ' || l_hpos || '.' || p.RPOS_POSITION end
                                             || case when l_id is not null then ': ' || p.RPOS_NAME end);
                    apex_json.write('artikel_anzeige', case when l_artnr is not null then l_artnr || ' – ' || l_artname end);
                    apex_json.open_object('felder');
                    apex_json.write('P11_POS_ARTI_ID', to_char(p.RPOS_ARTI_ID), true);
                    apex_json.write('P11_POS_ARTIKELNUMMER', l_artnr, true);
                    apex_json.write('P11_POS_GRUPPE', l_gruppe, true);
                    apex_json.write('P11_POS_NAME', p.RPOS_NAME, true);
                    apex_json.write('P11_POS_OPTIONAL', p.RPOS_IST_OPTIONAL, true);
                    apex_json.write('P11_POS_EINZELPREIS', preis(p.RPOS_EINZELPREIS), true);
                    apex_json.write('P11_POS_EINHEIT', p.RPOS_EINHEIT, true);
                    apex_json.write('P11_POS_MENGE', zahl(p.RPOS_MENGE), true);
                    apex_json.write('P11_POS_MWST', to_char(p.RPOS_MWST_PROZENT), true);
                    apex_json.write('P11_POS_RABATT', zahl(p.RPOS_RABATT_PROZENT), true);
                    -- Hauptposition ohne Unterpositionen, die noch mit Menge x Einzelpreis rechnet (aus einer Unterposition
                    -- entstanden bzw. Altbestand): ihr Betrag wird als Pauschalsumme angeboten und beim Speichern so uebernommen
                    apex_json.write('P11_POS_PAUSCHAL',
                                    preis(coalesce(p.RPOS_PAUSCHALSUMME,
                                                   case when p.RPOS_HAUPT_RPOS_ID is null and l_unter = 0 and l_id is not null
                                                        then nullif(p.RPOS_SUMME, 0) end)), true);
                    -- Summe ohne Pauschale: Hauptposition = Unterpositionen, Unterposition = Menge x Einzelpreis; abzgl. Rabatt
                    apex_json.write('P11_POS_SUMME',
                                    to_char(round(case when p.RPOS_HAUPT_RPOS_ID is null then nvl(p.RPOS_SUMME_UNTERPOS, 0)
                                                       else p.RPOS_MENGE * p.RPOS_EINZELPREIS end
                                                  * (1 - nvl(p.RPOS_RABATT_PROZENT, 0) / 100), 2), 'FML999G999G990D00'), true);
                    apex_json.write('P11_POS_BESCHREIBUNG', p.RPOS_BESCHREIBUNG, true);
                    apex_json.close_object;
                    apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 30
            point: ajaxCallback
        }
    )

    process pos-speichern (
        name: POS_SPEICHERN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Position aus den Feldern P11_POS_* speichern: x01 = RPOS_ID (leer = neu), x02 = Hauptposition einer
                -- neuen Unterposition. Fachliche Fehler kommen als {"fehler": …} zurueck.
                declare
                    l_id     number := to_number(apex_application.g_x01);
                    l_haupt  number := to_number(apex_application.g_x02);
                    l_mand   FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                    l_name   FAKT_RECHNUNGSPOSITIONEN.RPOS_NAME%type := trim(:P11_POS_NAME);
                    l_pos    number;
                    l_mwst   number;
                    l_menge  number;
                    l_preis  number;
                    l_rabatt number;
                    l_pausch number;
                    -- Zahlen kommen im Format der Felder (z.B. 1.250,00)
                    function zahl(p_wert in varchar2) return number is
                    begin
                        return to_number(replace(replace(p_wert, nchr(8364)), ' '), '999G999G999G990D99999',
                                         'NLS_NUMERIC_CHARACTERS='',.''');
                    end;
                begin
                    select RECH_MAND_ID, RECH_STATUS into l_mand, l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    if l_status <> 'ENTWURF' and nvl(:P11_BEARBEITEN, 'N') <> 'Y' then
                        raise_application_error(-20210, 'Positionen können nur im Entwurf oder nach „Rechnung bearbeiten“ geändert werden.');
                    end if;
                    if l_name is null then
                        raise_application_error(-20214, 'Bitte einen Namen für die Position eingeben.');
                    end if;
                    -- lokale Funktion nicht direkt in SQL (PLS-00231): Werte vorher in Variablen
                    l_pos    := FAKT_RECHNUNG.naechste_position(:P11_RECH_ID, l_haupt);   -- neue Position: ans Ende
                    l_menge  := nvl(zahl(:P11_POS_MENGE), 1);
                    l_preis  := nvl(zahl(:P11_POS_EINZELPREIS), 0);
                    l_rabatt := zahl(:P11_POS_RABATT);
                    l_pausch := zahl(:P11_POS_PAUSCHAL);
                    -- Hauptposition (neu: x02 leer; bestehend: ohne Hauptverweis) hat keinen eigenen Preis: Menge 1,
                    -- Einzelpreis 0, Betrag = Unterpositionen bzw. Pauschalsumme; Unterposition ohne Pauschalsumme
                    if l_id is not null then
                        select RPOS_HAUPT_RPOS_ID into l_haupt from FAKT_RECHNUNGSPOSITIONEN
                         where RPOS_ID = l_id and RPOS_RECH_ID = :P11_RECH_ID;
                    end if;
                    if l_haupt is null then
                        l_menge := 1;
                        l_preis := 0;
                    else
                        l_pausch := null;
                    end if;
                    select coalesce(to_number(:P11_POS_MWST), max(MWST_PROZENT)) into l_mwst
                      from ALLG_MWST_SAETZE where MWST_IST_STANDARD = 'Y';
                    if l_id is null then
                        insert into FAKT_RECHNUNGSPOSITIONEN
                              (RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_ARTI_ID, RPOS_POSITION, RPOS_NAME, RPOS_BESCHREIBUNG,
                               RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT, RPOS_MWST_PROZENT,
                               RPOS_IST_OPTIONAL, RPOS_PAUSCHALSUMME)
                        values (:P11_RECH_ID, l_haupt, to_number(:P11_POS_ARTI_ID),
                                l_pos, l_name, :P11_POS_BESCHREIBUNG,
                                l_menge, :P11_POS_EINHEIT, l_preis,
                                l_rabatt, nvl(l_mwst, 20), nvl(:P11_POS_OPTIONAL, 'N'), l_pausch)
                        returning RPOS_ID into l_id;
                    else
                        update FAKT_RECHNUNGSPOSITIONEN
                           set RPOS_ARTI_ID        = to_number(:P11_POS_ARTI_ID),
                               RPOS_NAME           = l_name,
                               RPOS_BESCHREIBUNG   = :P11_POS_BESCHREIBUNG,
                               RPOS_MENGE          = l_menge,
                               RPOS_EINHEIT        = :P11_POS_EINHEIT,
                               RPOS_EINZELPREIS    = l_preis,
                               RPOS_RABATT_PROZENT = l_rabatt,
                               RPOS_MWST_PROZENT   = nvl(l_mwst, RPOS_MWST_PROZENT),
                               RPOS_IST_OPTIONAL   = nvl(:P11_POS_OPTIONAL, 'N'),
                               RPOS_PAUSCHALSUMME  = l_pausch
                         where RPOS_ID = l_id and RPOS_RECH_ID = :P11_RECH_ID;
                        if sql%rowcount = 0 then
                            raise_application_error(-20211, 'Die Position gehört nicht zu dieser Rechnung.');
                        end if;
                    end if;
                    -- Artikelnummer und Erloeskonto als Kopie vom Artikel
                    update FAKT_RECHNUNGSPOSITIONEN p
                       set (RPOS_ARTIKELNUMMER, RPOS_ERLOESKONTO) =
                           (select a.ARTI_NUMMER, a.ARTI_ERLOESKONTO from ARTI_ARTIKEL a where a.ARTI_ID = p.RPOS_ARTI_ID)
                     where p.RPOS_ID = l_id;
                    FAKT_RECHNUNG.summen_berechnen(:P11_RECH_ID);
                    apex_json.open_object;
                    apex_json.write('id', to_char(l_id));
                    apex_json.close_object;
                exception
                    when others then
                        rollback;
                        apex_json.open_object;
                        apex_json.write('fehler', case
                            when sqlcode in (-1722, -6502, -1438) then 'Bitte gültige Zahlen eingeben.'
                            when sqlcode = -2290 then 'Rabatt und MwSt. müssen zwischen 0 und 100 liegen.'
                            else regexp_replace(sqlerrm, '^ORA-\\d+: ') end);
                        apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 40
            point: ajaxCallback
        }
    )

    process pos-loeschen (
        name: POS_LOESCHEN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Position loeschen (x01 = RPOS_ID); eine Hauptposition nimmt ihre Unterpositionen mit (RPOS_HAUPT_RPOS_FK)
                declare
                    l_id     number := to_number(apex_application.g_x01);
                    l_mand   FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                    l_haupt  FAKT_RECHNUNGSPOSITIONEN.RPOS_HAUPT_RPOS_ID%type;
                    -- Geschwister neu durchnummerieren: Hauptpositionen (p_haupt leer) 1, 2, 3 …, Unterpositionen 10, 20, 30 …;
                    -- p_id/p_schluessel: diese Position an die Stelle p_schluessel setzen (2 x Position des Ziels -/+ 1)
                    procedure nummerieren(p_haupt in number, p_id in number default null, p_schluessel in number default null) is
                    begin
                        update FAKT_RECHNUNGSPOSITIONEN p
                           set RPOS_POSITION = (select x.NR
                                                  from (select RPOS_ID,
                                                               row_number() over (order by case when RPOS_ID = p_id then p_schluessel
                                                                                                else RPOS_POSITION * 2 end, RPOS_ID)
                                                               * case when p_haupt is null then 1 else 10 end as NR
                                                          from FAKT_RECHNUNGSPOSITIONEN
                                                         where RPOS_RECH_ID = :P11_RECH_ID
                                                           and (RPOS_HAUPT_RPOS_ID = p_haupt or (RPOS_HAUPT_RPOS_ID is null and p_haupt is null))) x
                                                 where x.RPOS_ID = p.RPOS_ID)
                         where p.RPOS_RECH_ID = :P11_RECH_ID
                           and (p.RPOS_HAUPT_RPOS_ID = p_haupt or (p.RPOS_HAUPT_RPOS_ID is null and p_haupt is null));
                    end;
                begin
                    select RECH_MAND_ID, RECH_STATUS into l_mand, l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    if l_status <> 'ENTWURF' and nvl(:P11_BEARBEITEN, 'N') <> 'Y' then
                        raise_application_error(-20210, 'Positionen können nur im Entwurf oder nach „Rechnung bearbeiten“ geändert werden.');
                    end if;
                    delete from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = l_id and RPOS_RECH_ID = :P11_RECH_ID
                    returning RPOS_HAUPT_RPOS_ID into l_haupt;
                    if sql%rowcount = 0 then
                        raise_application_error(-20211, 'Die Position gehört nicht zu dieser Rechnung.');
                    end if;
                    nummerieren(l_haupt);   -- Luecke in der Nummerierung schliessen
                    FAKT_RECHNUNG.summen_berechnen(:P11_RECH_ID);
                    apex_json.open_object;
                    apex_json.write('ok', true);
                    apex_json.close_object;
                exception
                    when others then
                        rollback;
                        apex_json.open_object;
                        apex_json.write('fehler', regexp_replace(sqlerrm, '^ORA-\\d+: '));
                        apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 50
            point: ajaxCallback
        }
    )

    process pos-verschieben (
        name: POS_VERSCHIEBEN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Position im Baum verschieben (Drag & Drop): x01 = Position, x02 = Ziel, x03 = Art
                --   vor / nach: auf die Ebene des Ziels, vor bzw. nach dem Ziel (Ziel Hauptposition -> wird Hauptposition,
                --               Ziel Unterposition -> wird Unterposition derselben Hauptposition)
                --   in:         als letzte Unterposition in die Hauptposition x02
                -- Eine Hauptposition mit Unterpositionen kann nicht Unterposition werden (nur zwei Ebenen).
                -- Danach werden die betroffenen Ebenen neu durchnummeriert und die Summen berechnet.
                declare
                    l_id     number := to_number(apex_application.g_x01);
                    l_ziel   number := to_number(apex_application.g_x02);
                    l_art    varchar2(10) := apex_application.g_x03;
                    l_mand   FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                    q        FAKT_RECHNUNGSPOSITIONEN%rowtype;   -- verschobene Position
                    z        FAKT_RECHNUNGSPOSITIONEN%rowtype;   -- Ziel
                    l_unter  pls_integer;
                    l_neu    FAKT_RECHNUNGSPOSITIONEN.RPOS_HAUPT_RPOS_ID%type;   -- neue Hauptposition (leer = wird Hauptposition)
                    l_stelle number;
                    -- Geschwister neu durchnummerieren: Hauptpositionen (p_haupt leer) 1, 2, 3 …, Unterpositionen 10, 20, 30 …;
                    -- p_id/p_schluessel: diese Position an die Stelle p_schluessel setzen (2 x Position des Ziels -/+ 1)
                    procedure nummerieren(p_haupt in number, p_id in number default null, p_schluessel in number default null) is
                    begin
                        update FAKT_RECHNUNGSPOSITIONEN p
                           set RPOS_POSITION = (select x.NR
                                                  from (select RPOS_ID,
                                                               row_number() over (order by case when RPOS_ID = p_id then p_schluessel
                                                                                                else RPOS_POSITION * 2 end, RPOS_ID)
                                                               * case when p_haupt is null then 1 else 10 end as NR
                                                          from FAKT_RECHNUNGSPOSITIONEN
                                                         where RPOS_RECH_ID = :P11_RECH_ID
                                                           and (RPOS_HAUPT_RPOS_ID = p_haupt or (RPOS_HAUPT_RPOS_ID is null and p_haupt is null))) x
                                                 where x.RPOS_ID = p.RPOS_ID)
                         where p.RPOS_RECH_ID = :P11_RECH_ID
                           and (p.RPOS_HAUPT_RPOS_ID = p_haupt or (p.RPOS_HAUPT_RPOS_ID is null and p_haupt is null));
                    end;
                begin
                    select RECH_MAND_ID, RECH_STATUS into l_mand, l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    if l_status <> 'ENTWURF' and nvl(:P11_BEARBEITEN, 'N') <> 'Y' then
                        raise_application_error(-20210, 'Positionen können nur im Entwurf oder nach „Rechnung bearbeiten“ geändert werden.');
                    end if;
                    if l_id = l_ziel or l_art not in ('vor', 'nach', 'in') then
                        raise_application_error(-20216, 'Die Position kann nicht dorthin verschoben werden.');
                    end if;
                    select * into q from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = l_id and RPOS_RECH_ID = :P11_RECH_ID;
                    select * into z from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = l_ziel and RPOS_RECH_ID = :P11_RECH_ID;
                    select count(*) into l_unter from FAKT_RECHNUNGSPOSITIONEN where RPOS_HAUPT_RPOS_ID = l_id;
                    if l_art = 'in' then
                        if z.RPOS_HAUPT_RPOS_ID is not null then
                            raise_application_error(-20216, 'Unterpositionen können nur in eine Hauptposition verschoben werden.');
                        end if;
                        l_neu    := z.RPOS_ID;
                        l_stelle := 1e9;   -- ans Ende
                    else
                        l_neu    := z.RPOS_HAUPT_RPOS_ID;
                        l_stelle := z.RPOS_POSITION * 2 + case l_art when 'vor' then -1 else 1 end;
                    end if;
                    if l_neu is not null and l_unter > 0 then
                        raise_application_error(-20217, 'Eine Hauptposition mit Unterpositionen kann nicht selbst Unterposition werden.');
                    end if;
                    -- umhaengen (Platzhalter-Nummer -1, RPOS_UK); als Unterposition ohne Pauschalsumme (RPOS_PAUSCHAL_CK):
                    -- wird eine Hauptposition mit Pauschalsumme zur Unterposition, geht der Betrag in Menge 1 x Einzelpreis
                    update FAKT_RECHNUNGSPOSITIONEN
                       set RPOS_HAUPT_RPOS_ID  = l_neu,
                           RPOS_POSITION       = -1,
                           RPOS_MENGE          = case when l_neu is not null and RPOS_PAUSCHALSUMME is not null then 1 else RPOS_MENGE end,
                           RPOS_EINZELPREIS    = case when l_neu is not null and RPOS_PAUSCHALSUMME is not null then RPOS_PAUSCHALSUMME
                                                      else RPOS_EINZELPREIS end,
                           RPOS_RABATT_PROZENT = case when l_neu is not null and RPOS_PAUSCHALSUMME is not null then null
                                                      else RPOS_RABATT_PROZENT end,
                           RPOS_PAUSCHALSUMME  = case when l_neu is null then RPOS_PAUSCHALSUMME end,
                           RPOS_SUMME_UNTERPOS = case when l_neu is null then RPOS_SUMME_UNTERPOS end
                     where RPOS_ID = l_id;
                    nummerieren(l_neu, l_id, l_stelle);
                    if nvl(q.RPOS_HAUPT_RPOS_ID, -1) <> nvl(l_neu, -1) then
                        nummerieren(q.RPOS_HAUPT_RPOS_ID);   -- Luecke auf der bisherigen Ebene schliessen
                    end if;
                    FAKT_RECHNUNG.summen_berechnen(:P11_RECH_ID);
                    apex_json.open_object;
                    apex_json.write('ok', true);
                    apex_json.close_object;
                exception
                    when others then
                        rollback;
                        apex_json.open_object;
                        apex_json.write('fehler', regexp_replace(sqlerrm, '^ORA-\\d+: '));
                        apex_json.close_object;
                end;
                ```
        }
        execution {
            sequence: 60
            point: ajaxCallback
        }
    )

    process rechnung-loeschen (
        name: Rechnung löschen (Entwurf oder letzte Rechnung)
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- fachliche Fehler des Packages (-20200 bis -20299) als normale Meldung ohne ORA-Nummer anzeigen
                begin
                    FAKT_RECHNUNG.loeschen(:P11_RECH_ID);
                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\d+: '),
                                                 p_display_location => apex_error.c_inline_in_notification);
                        else
                            raise;
                        end if;
                end;
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
            type: expression
            language: plsql
            plsqlExpression: :REQUEST in ('CREATE', 'SAVE', 'ABSCHLIESSEN') or (:REQUEST in ('PDF', 'VORSCHAU') and (:P11_RECH_STATUS = 'ENTWURF' or nvl(:P11_BEARBEITEN, 'N') = 'Y'))
        }
        successMessage {
            successMessage: Rechnung gespeichert.
        }
    )

    process empfaenger-uebernehmen (
        name: Standort und Ansprechpartner vom Kunden übernehmen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Texte wurden bei der Auswahl des Kunden in die Maske uebernommen (Dynamic Action) und evtl. geaendert
                FAKT_RECHNUNG.empfaenger_uebernehmen(:P11_RECH_ID, p_nur_verweise => true);
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
                -- Unterpositionen der gewaehlten Hauptposition (P11_HAUPT_ID); nur im Entwurf bzw. nach
                -- "Rechnung bearbeiten" aenderbar; leere Felder werden vom Artikel uebernommen
                declare
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                    a        ARTI_ARTIKEL%rowtype;
                    l_mwst   ALLG_MWST_SAETZE.MWST_PROZENT%type;
                    l_einh   ALLG_EINHEITEN.EINH_CODE%type;
                    l_pos    number;
                    l_haupt  number := to_number(:P11_HAUPT_ID);
                    l_preis  number;
                    -- Betraege kommen im Format der Spalte (z.B. EUR 1.250,00) oder als einfache Zahl
                    function betrag(p_wert in varchar2) return number is
                    begin
                        return to_number(replace(replace(p_wert, nchr(8364)), ' '), '999G999G999G990D99999',
                                         'NLS_NUMERIC_CHARACTERS='',.''');
                    end;
                    -- Geschwister neu durchnummerieren: Hauptpositionen (p_haupt leer) 1, 2, 3 …, Unterpositionen 10, 20, 30 …;
                    -- p_id/p_schluessel: diese Position an die Stelle p_schluessel setzen (2 x Position des Ziels -/+ 1)
                    procedure nummerieren(p_haupt in number, p_id in number default null, p_schluessel in number default null) is
                    begin
                        update FAKT_RECHNUNGSPOSITIONEN p
                           set RPOS_POSITION = (select x.NR
                                                  from (select RPOS_ID,
                                                               row_number() over (order by case when RPOS_ID = p_id then p_schluessel
                                                                                                else RPOS_POSITION * 2 end, RPOS_ID)
                                                               * case when p_haupt is null then 1 else 10 end as NR
                                                          from FAKT_RECHNUNGSPOSITIONEN
                                                         where RPOS_RECH_ID = :P11_RECH_ID
                                                           and (RPOS_HAUPT_RPOS_ID = p_haupt or (RPOS_HAUPT_RPOS_ID is null and p_haupt is null))) x
                                                 where x.RPOS_ID = p.RPOS_ID)
                         where p.RPOS_RECH_ID = :P11_RECH_ID
                           and (p.RPOS_HAUPT_RPOS_ID = p_haupt or (p.RPOS_HAUPT_RPOS_ID is null and p_haupt is null));
                    end;
                begin
                    select RECH_STATUS into l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_status <> 'ENTWURF' and nvl(:P11_BEARBEITEN, 'N') <> 'Y' then
                        raise_application_error(-20210, 'Positionen können nur im Entwurf oder nach „Rechnung bearbeiten“ geändert werden.');
                    end if;
                    if :APEX$ROW_STATUS = 'D' then
                        delete from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = :RPOS_ID and RPOS_RECH_ID = :P11_RECH_ID;
                        nummerieren(l_haupt);   -- Luecke in der Nummerierung schliessen
                        FAKT_RECHNUNG.summen_berechnen(:P11_RECH_ID);   -- auch beim Speichern nur ueber das Grid
                        return;
                    end if;
                    l_preis := betrag(:RPOS_EINZELPREIS);   -- lokale Funktion nicht direkt in SQL (PLS-00231)
                    if :RPOS_ARTI_ID is not null then
                        select * into a from ARTI_ARTIKEL where ARTI_ID = to_number(:RPOS_ARTI_ID);
                        select MWST_PROZENT into l_mwst from ALLG_MWST_SAETZE where MWST_ID = a.ARTI_MWST_ID;
                        select max(EINH_CODE) into l_einh from ALLG_EINHEITEN where EINH_ID = a.ARTI_EINH_ID;
                    end if;
                    if l_haupt is null then
                        raise_application_error(-20215, 'Bitte zuerst eine Hauptposition wählen.');
                    end if;
                    -- leere Zeile (der Browser entfernt sie vor dem Speichern; hier nur die Absicherung)
                    if :RPOS_ARTI_ID is null and trim(:RPOS_NAME) is null then
                        raise_application_error(-20218, 'Bitte einen Artikel wählen oder einen Namen eingeben.');
                    end if;
                    l_pos := FAKT_RECHNUNG.naechste_position(:P11_RECH_ID, l_haupt);   -- neue Zeile: ans Ende (10, 20, 30 …)
                    if :APEX$ROW_STATUS = 'C' then
                        insert into FAKT_RECHNUNGSPOSITIONEN
                              (RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_ARTI_ID, RPOS_POSITION, RPOS_ARTIKELNUMMER,
                               RPOS_NAME, RPOS_BESCHREIBUNG, RPOS_MENGE, RPOS_EINHEIT, RPOS_EINZELPREIS, RPOS_RABATT_PROZENT,
                               RPOS_MWST_PROZENT, RPOS_IST_OPTIONAL, RPOS_ERLOESKONTO)
                        values (:P11_RECH_ID, l_haupt, to_number(:RPOS_ARTI_ID), l_pos, a.ARTI_NUMMER,
                                coalesce(:RPOS_NAME, a.ARTI_NAME), coalesce(to_clob(:RPOS_BESCHREIBUNG), a.ARTI_BESCHREIBUNG),
                                nvl(to_number(:RPOS_MENGE), 1), coalesce(:RPOS_EINHEIT, l_einh), coalesce(l_preis, a.ARTI_VK_PREIS, 0),
                                to_number(:RPOS_RABATT_PROZENT), coalesce(to_number(:RPOS_MWST_PROZENT), l_mwst, 20), nvl(:RPOS_IST_OPTIONAL, 'N'),
                                a.ARTI_ERLOESKONTO)
                        returning RPOS_ID into :RPOS_ID;
                    else
                        update FAKT_RECHNUNGSPOSITIONEN
                           set RPOS_ARTI_ID        = to_number(:RPOS_ARTI_ID),
                               RPOS_ARTIKELNUMMER  = coalesce(a.ARTI_NUMMER, RPOS_ARTIKELNUMMER),
                               RPOS_NAME           = coalesce(:RPOS_NAME, a.ARTI_NAME, RPOS_NAME),
                               RPOS_BESCHREIBUNG   = coalesce(to_clob(:RPOS_BESCHREIBUNG), a.ARTI_BESCHREIBUNG),
                               RPOS_MENGE          = nvl(to_number(:RPOS_MENGE), 1),
                               RPOS_EINHEIT        = coalesce(:RPOS_EINHEIT, l_einh),
                               RPOS_EINZELPREIS    = coalesce(l_preis, a.ARTI_VK_PREIS, 0),
                               RPOS_RABATT_PROZENT = to_number(:RPOS_RABATT_PROZENT),
                               RPOS_MWST_PROZENT   = coalesce(to_number(:RPOS_MWST_PROZENT), l_mwst, 20),
                               RPOS_IST_OPTIONAL   = nvl(:RPOS_IST_OPTIONAL, 'N')
                         where RPOS_ID = :RPOS_ID and RPOS_RECH_ID = :P11_RECH_ID;
                    end if;
                    FAKT_RECHNUNG.summen_berechnen(:P11_RECH_ID);   -- Zwischensumme der Hauptposition und Rechnungssummen
                exception
                    when dup_val_on_index then
                        raise_application_error(-20212, 'Die Positionsnummer ' || l_pos || ' ist bereits vergeben. Bitte erneut speichern.');
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
                -- fachliche Fehler des Packages (-20200 bis -20299) als normale Meldung ohne ORA-Nummer anzeigen
                begin
                    FAKT_RECHNUNG.abschliessen(:P11_RECH_ID);
                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\d+: '),
                                                 p_display_location => apex_error.c_inline_in_notification);
                        else
                            raise;
                        end if;
                end;
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

    branch nach-abschliessen-drucken (
        name: Nach Abschließen, Drucken oder Vorschau das PDF öffnen
        execution {
            sequence: 6
        }
        behavior {
            target: {
                page: 11
                items: {
                    P11_RECH_ID: &P11_RECH_ID.
                    P11_PDF_OEFFNEN: Y
                }
            }
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: ABSCHLIESSEN,PDF,VORSCHAU
        }
    )

    process kopieren (
        name: Rechnung kopieren
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- neue Rechnung (Entwurf) anlegen; die Verzweigung oeffnet sie mit der neuen ID
                :P11_RECH_ID := FAKT_RECHNUNG.kopieren(:P11_RECH_ID);
                ```
        }
        execution {
            sequence: 70
        }
        serverSideCondition {
            whenButtonPressed: @kopieren
        }
        successMessage {
            successMessage: Rechnung kopiert – neuer Entwurf.
        }
    )

    branch zur-kopie (
        name: Nach dem Kopieren die Kopie öffnen
        execution {
            sequence: 5
        }
        behavior {
            target: {
                page: 11
                items: {
                    P11_RECH_ID: &P11_RECH_ID.
                }
                clearCache: 11
            }
        }
        serverSideCondition {
            whenButtonPressed: @kopieren
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


# --------------------------------------------------------------------------- Seite 14 Unterposition (Dialog)

def im_menue(btn, dom_id):
    """Button unsichtbar (u-hidden) mit fester DOM-ID: wird ueber das Aktionen-Menue (Kebab-Button) angeklickt und
    behaelt Bedingung, Bestaetigung und Verhalten."""
    i = btn.index("        appearance {\n")
    btn = btn[:i] + f"        advanced {{\n            htmlDomId: {dom_id}\n        }}\n" + btn[i:]
    return btn.replace("        appearance {\n", "        appearance {\n            cssClasses: u-hidden\n", 1)


def seite_15():
    """Dialog "Rechnung stornieren" (Button im Kopf von Seite 11, nur GEDRUCKT/GESENDET ohne Zahlung): Grund ist Pflicht,
    FAKT_RECHNUNG.stornieren prueft Status und Zahlungen. Seite 11 laedt nach dem Schliessen neu (DA storno-nach-dialog)."""
    ohne = dict(form=None)
    s = """page 15 (
    name: Rechnung stornieren
    alias: STORNIEREN
    title: Rechnung stornieren
    appearance {
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }
    dialog {
        width: 560
        chained: false
        resizable: false
    }
    navigation {
        cursorFocus: doNotFocusCursor
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region buttons (
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

    region storno (
        name: Rechnung stornieren
        type: staticContent
        source {
            htmlCode:
                ```html
                <p>Die Rechnung &P15_RECH_NUMMER. wird storniert. Sie behält Nummer und Datum, zählt nicht mehr zum Umsatz
                und kann danach nicht mehr geändert werden.</p>
                ```
        }
        layout {
            sequence: 10
            slot: contentBody
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
    )

    region grund (
        name: Grund
        type: staticContent
        layout {
            sequence: 20
            slot: contentBody
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
    )

    pageItem P15_RECH_ID (
        type: hidden
        layout {
            sequence: 1
            region: @storno
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P15_RECH_NUMMER (
        type: hidden
        layout {
            sequence: 2
            region: @storno
            slot: regionBody
        }
    )

"""
    s += item("P15_GRUND", "textarea", "Grund für das Storno", 10, "grund", req=True, maxlen=1000, spalten=12, **ohne)
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("stornieren", "STORNIEREN", "Stornieren", 20, "buttons", "next", hot=True,
                options="[\n                #DEFAULT#\n                t-Button--danger\n            ]",
                verhalten="            warnOnUnsavedChanges: doNotCheck\n")
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

    process rechnung-laden (
        name: Rechnungsnummer laden
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                select max(RECH_NUMMER) into :P15_RECH_NUMMER from FAKT_RECHNUNGEN where RECH_ID = :P15_RECH_ID;
                ```
        }
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process stornieren (
        name: Rechnung stornieren
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                begin
                    FAKT_RECHNUNG.stornieren(:P15_RECH_ID, :P15_GRUND);
                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\d+: '),
                                                 p_display_location => apex_error.c_inline_in_notification);
                        else
                            raise;
                        end if;
                end;
                ```
        }
        execution {
            sequence: 10
        }
        serverSideCondition {
            whenButtonPressed: @stornieren
        }
    )

    process close-dialog (
        name: Dialog schließen
        type: closeDialog
        execution {
            sequence: 20
        }
        serverSideCondition {
            whenButtonPressed: @stornieren
        }
    )

)
"""
    return s

def seite_14():
    """Dialog "Unterposition": eine Unterposition der gewaehlten Hauptposition mit allen Feldern erfassen/aendern
    (Button "Zeile Detail" bzw. Zeilenmenue "Detail bearbeiten"/"Detail anzeigen" im Raster der Unterpositionen auf
    Seite 11). Anordnung wie im Artikelstamm, dazu Menge und Rabatt. Die Positionsnummer ist kein Eingabefeld: neue
    Unterpositionen kommen ans Ende ihrer Hauptposition (P14_HAUPT_ID aus der URL). Der Dialog laesst sich immer
    oeffnen; aenderbar ist er wie Seite 11 nur im Entwurf oder nach "Rechnung bearbeiten" (P14_NUR_LESEN)."""
    s = """page 14 (
    name: Unterposition
    alias: POSITION
    title: Unterposition
    appearance {
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }
    dialog {
        width: 1000
        chained: false
        resizable: true
    }
    navigation {
        cursorFocus: doNotFocusCursor
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region buttons (
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

    region position (
        name: Position
        type: form
        readOnly {
            type: expression
            language: plsql
            plsqlExpression: :P14_NUR_LESEN = 'Y'
        }
        source {
            location: localDatabase
            tableName: FAKT_RECHNUNGSPOSITIONEN
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
                add
                update
            ]
        }
    )

"""
    # P14_RECH_ID: Rechnung aus der URL – die Formular-Initialisierung leert bei einer neuen Position alle
    # Formularfelder (auch RPOS_RECH_ID), daher eigenes Element und Vorbelegung von RPOS_RECH_ID daraus
    s += """    pageItem P14_RECH_ID (
        type: hidden
        layout {
            sequence: 3
            region: @position
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P14_HAUPT_ID (
        type: hidden
        layout {
            sequence: 5
            region: @position
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P14_NUR_LESEN (
        type: hidden
        layout {
            sequence: 4
            region: @position
            slot: regionBody
        }
    )

"""
    for nr, (name, col, vorgabe) in enumerate((("P14_RPOS_ID", "RPOS_ID", None),
                                               ("P14_RPOS_RECH_ID", "RPOS_RECH_ID", "P14_RECH_ID"),
                                               ("P14_RPOS_HAUPT_RPOS_ID", "RPOS_HAUPT_RPOS_ID", "P14_HAUPT_ID"),
                                               ("P14_RPOS_POSITION", "RPOS_POSITION", None)), 1):
        s += f"""    pageItem {name} (
        type: hidden
        layout {{
            sequence: {nr}
            region: @position
            slot: regionBody
        }}
        source {{
            formRegion: @position
            column: {col}
            dataType: number
""" + ("            primaryKey: true\n" if nr == 1 else "") + "        }\n" + ("" if not vorgabe else f"""        default {{
            type: item
            item: {vorgabe}
        }}
""") + """        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

"""
    f = dict(form="position")
    r = "position"
    maske = lambda it, m: it.replace("            templateOptions: #DEFAULT#\n        }\n",
                                     f"            templateOptions: #DEFAULT#\n            formatMask: {m}\n        }}\n", 1)
    # Zeile 1: Artikel (Suche nach Gruppe, Artikelnummer, Name)
    s += item("P14_RPOS_ARTI_ID", "popupLov", "Artikel (Suche nach Gruppe, Artikelnummer, Name)", 10, r,
              col="RPOS_ARTI_ID", dtype="number", spalten=6, extra="""        lov {
            type: sharedComponent
            lov: @lov-artikel
            displayNullValue: true
            nullDisplayValue: - ohne Artikel -
        }
""", **f)
    # Zeile 2 (wie Artikelstamm): Name | Einzelpreis | Einheit
    s += item("P14_RPOS_NAME", "textField", "Name", 40, r, col="RPOS_NAME", req=True, maxlen=200, spalten=6, **f)
    s += maske(item("P14_RPOS_EINZELPREIS", "numberField", "Einzelpreis", 50, r, col="RPOS_EINZELPREIS", dtype="number",
                    req=True, neue_zeile=False, spalten=3, extra="""        default {
            type: static
            staticValue: 0
        }
""", **f), "999G999G990D00")
    s += item("P14_RPOS_EINHEIT", "selectList", "Einheit", 60, r, col="RPOS_EINHEIT", neue_zeile=False, spalten=3,
              extra=lov("lov-einheiten-code", "-"), **f)
    # Zeile 3: Artikelnummer und Gruppe (Anzeige vom Artikel) | MwSt. | Optional
    # Anzeigefelder werden per Dynamic Action gesetzt: nicht absenden (sonst "Session state protection violation")
    nur_anzeige = "        settings {\n            sendOnPageSubmit: false\n        }\n"
    s += item("P14_ARTIKELNUMMER", "displayOnly", "Artikelnummer", 70, r, spalten=3, extra=nur_anzeige, **f)
    s += item("P14_GRUPPE", "displayOnly", "Gruppe", 80, r, neue_zeile=False, spalten=3, extra=nur_anzeige, **f)
    s += item("P14_RPOS_MWST_PROZENT", "selectList", "MwSt. in %", 90, r, col="RPOS_MWST_PROZENT", dtype="number",
              req=True, neue_zeile=False, spalten=3, extra=lov("lov-mwst-prozent") + default_sql(
                  "select MWST_PROZENT from ALLG_MWST_SAETZE where MWST_IST_STANDARD = 'Y'"), **f)
    s += item("P14_RPOS_IST_OPTIONAL", "switch", "Optional (nicht in der Summe)", 100, r, col="RPOS_IST_OPTIONAL",
              neue_zeile=False, spalten=3, extra=SWITCH("N"), **f)
    # Zeile 4: Menge | Rabatt | Summe (Anzeige, berechnet)
    s += item("P14_RPOS_MENGE", "numberField", "Menge", 110, r, col="RPOS_MENGE", dtype="number", req=True, spalten=3,
              extra="""        default {
            type: static
            staticValue: 1
        }
""", **f)
    s += item("P14_RPOS_RABATT_PROZENT", "numberField", "Rabatt %", 120, r, col="RPOS_RABATT_PROZENT", dtype="number",
              neue_zeile=False, spalten=3, **f)
    s += hervorheben(item("P14_SUMME", "displayOnly", "Summe", 130, r, neue_zeile=False, spalten=3, extra=nur_anzeige, **f))
    s += item("P14_RPOS_BESCHREIBUNG", "richTextEditor", "Beschreibung", 140, r, col="RPOS_BESCHREIBUNG", dtype="clob",
              spalten=12, **f)

    # ------------------------------------------------ Buttons (Speichern/Anlegen nur, wenn die Rechnung aenderbar ist)
    aenderbar = lambda rpos_id: f"""        serverSideCondition {{
            type: expression
            language: plsql
            plsqlExpression: :P14_RPOS_ID {rpos_id} and nvl(:P14_NUR_LESEN, 'N') <> 'Y'
        }}
"""
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close",
                verhalten="            action: definedByDynamicAction\n")
    s += button("save", "SAVE", "Speichern", 20, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=aenderbar("is not null"))
    s += button("create", "CREATE", "Position anlegen", 30, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=aenderbar("is null"))

    # ------------------------------------------------ Dynamic Actions
    artikel_items = "P14_RPOS_NAME,P14_RPOS_EINHEIT,P14_RPOS_EINZELPREIS,P14_RPOS_MWST_PROZENT,P14_RPOS_BESCHREIBUNG,P14_RPOS_MENGE"
    s += f"""    dynamicAction cancel-dialog (
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

    dynamicAction artikel-gewaehlt (
        name: Artikel gewählt: Daten aus dem Artikelstamm übernehmen
        execution {{
            sequence: 20
        }}
        when {{
            event: change
            selectionType: items
            items: P14_RPOS_ARTI_ID
        }}

        action artikel-laden (
            action: executeServerSideCode
            settings {{
                plsqlCode:
                    ```plsql
                    -- Name, Einheit, Einzelpreis, MwSt., Beschreibung vom Artikel (danach aenderbar); alle Felder werden
                    -- mitgeschickt, damit ohne Artikel die bisherigen Eingaben erhalten bleiben
                    declare
                        a ARTI_ARTIKEL%rowtype;
                    begin
                        if :P14_RPOS_ARTI_ID is null then
                            :P14_ARTIKELNUMMER := null;
                            :P14_GRUPPE := null;
                            return;
                        end if;
                        select * into a from ARTI_ARTIKEL where ARTI_ID = to_number(:P14_RPOS_ARTI_ID);
                        :P14_RPOS_NAME         := a.ARTI_NAME;
                        :P14_RPOS_EINZELPREIS  := to_char(a.ARTI_VK_PREIS, 'FM999G999G990D00');
                        :P14_RPOS_BESCHREIBUNG := a.ARTI_BESCHREIBUNG;
                        :P14_ARTIKELNUMMER     := a.ARTI_NUMMER;
                        select max(EINH_CODE) into :P14_RPOS_EINHEIT from ALLG_EINHEITEN where EINH_ID = a.ARTI_EINH_ID;
                        select to_char(max(MWST_PROZENT)) into :P14_RPOS_MWST_PROZENT from ALLG_MWST_SAETZE where MWST_ID = a.ARTI_MWST_ID;
                        select max(AGRP_BEZEICHNUNG) into :P14_GRUPPE from ARTI_ARTIKELGRUPPEN where AGRP_ID = a.ARTI_AGRP_ID;
                        if :P14_RPOS_MENGE is null then
                            :P14_RPOS_MENGE := '1';
                        end if;
                    end;
                    ```
                itemsToSubmit: P14_RPOS_ARTI_ID,{artikel_items}
                itemsToReturn: {artikel_items},P14_ARTIKELNUMMER,P14_GRUPPE
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

    dynamicAction summe-anzeigen (
        name: Summe der Position sofort berechnen
        execution {{
            sequence: 40
        }}
        when {{
            event: change
            selectionType: items
            items: P14_RPOS_MENGE,P14_RPOS_EINZELPREIS,P14_RPOS_RABATT_PROZENT
        }}

        action summe-berechnen (
            action: executeJsCode
            settings {{
                jsCode:
                    ```javascript
                    // Menge x Einzelpreis abzgl. Rabatt (wie Trigger RPOS_BIU), Anzeige im Format der Betraege
                    // nur lesen: Felder sind reine Anzeige (kein Zahlenwert), die Summe kommt aus der Datenbank
                    if ($v("P14_NUR_LESEN") === "Y") {{
                        return;
                    }}
                    var n = function (name) {{
                        var w = apex.item(name).getNativeValue();
                        return (typeof w === "number" && !isNaN(w)) ? w : 0;
                    }};
                    var summe = n("P14_RPOS_MENGE") * n("P14_RPOS_EINZELPREIS") * (1 - n("P14_RPOS_RABATT_PROZENT") / 100);
                    apex.item("P14_SUMME").setValue(apex.locale.formatNumber(Math.round(summe * 100) / 100, "FML999G999G990D00"));
                    ```
            }}
            execution {{
                sequence: 10
                fireOnInit: true
            }}
        )

    )

"""
    # ------------------------------------------------ Prozesse
    # beim Oeffnen: nicht aenderbare Rechnung -> Dialog nur lesen (P14_NUR_LESEN); beim Speichern: Fehler
    nur_lesen = "                        :P14_NUR_LESEN := 'Y';"
    fehler = ("                        raise_application_error(-20210, 'Positionen können nur im Entwurf oder nach "
              "„Rechnung bearbeiten“ geändert werden.');")
    pruefen = lambda rech, gesperrt, vorher="": f"""                -- Rechnung des Mandanten der Sitzung; Positionen nur im Entwurf oder nach "Rechnung bearbeiten" (Seite 11)
                declare
                    l_mand   FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                begin
                    select RECH_MAND_ID, RECH_STATUS into l_mand, l_status
                      from FAKT_RECHNUNGEN where RECH_ID = {rech};
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
{vorher}                    if l_status <> 'ENTWURF' and nvl(:P11_BEARBEITEN, 'N') <> 'Y' then
{gesperrt}
                    end if;
                end;"""
    s += f"""    process initialize-form-position (
        name: Formular Position initialisieren
        type: formInitialization
        formRegion: @position
        execution {{
            sequence: 10
            point: beforeHeader
        }}
    )

    process rechnung-pruefen (
        name: Rechnung prüfen (Mandant), nur lesen wenn nicht änderbar
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
{pruefen('nvl(:P14_RPOS_RECH_ID, :P14_RECH_ID)', nur_lesen, vorher="                    :P14_NUR_LESEN := 'N';\n")}
                ```
        }}
        execution {{
            sequence: 20
            point: beforeHeader
        }}
    )

    process anzeige-vorbelegen (
        name: Artikelnummer, Gruppe und Summe anzeigen
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                select max(a.ARTI_NUMMER), max(g.AGRP_BEZEICHNUNG) into :P14_ARTIKELNUMMER, :P14_GRUPPE
                  from ARTI_ARTIKEL a
                  left join ARTI_ARTIKELGRUPPEN g on g.AGRP_ID = a.ARTI_AGRP_ID
                 where a.ARTI_ID = to_number(:P14_RPOS_ARTI_ID);
                -- gespeicherte Summe (Trigger RPOS_BIU); bei aenderbarer Position rechnet die Dynamic Action sofort neu
                select max(to_char(RPOS_SUMME, 'FML999G999G990D00')) into :P14_SUMME
                  from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = to_number(:P14_RPOS_ID);
                ```
        }}
        execution {{
            sequence: 30
            point: beforeHeader
        }}
    )

    process rechnung-pruefen-speichern (
        name: Rechnung prüfen (Mandant, änderbar) vor dem Speichern
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
{pruefen(':P14_RPOS_RECH_ID', fehler)}
                ```
        }}
        execution {{
            sequence: 10
        }}
    )

    process position-vorbelegen (
        name: Neue Unterposition: Positionsnummer vergeben
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                -- neue Unterposition: ans Ende ihrer Hauptposition (10, 20, 30 …); die Nummer ist kein Eingabefeld
                if :P14_RPOS_ID is null then
                    if :P14_RPOS_HAUPT_RPOS_ID is null then
                        raise_application_error(-20215, 'Bitte zuerst eine Hauptposition wählen.');
                    end if;
                    :P14_RPOS_POSITION := to_char(FAKT_RECHNUNG.naechste_position(:P14_RPOS_RECH_ID,
                                                                                    to_number(:P14_RPOS_HAUPT_RPOS_ID)));
                end if;
                ```
        }}
        execution {{
            sequence: 20
        }}
    )

    process process-form-position (
        name: Formular Position verarbeiten
        type: formAutoRowProcessing
        formRegion: @position
        execution {{
            sequence: 30
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }}
        successMessage {{
            successMessage: Position gespeichert.
        }}
    )

    process artikel-kopien (
        name: Artikelnummer und Erlöskonto vom Artikel, Rechnungssummen
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                update FAKT_RECHNUNGSPOSITIONEN p
                   set (RPOS_ARTIKELNUMMER, RPOS_ERLOESKONTO) =
                       (select a.ARTI_NUMMER, a.ARTI_ERLOESKONTO from ARTI_ARTIKEL a where a.ARTI_ID = p.RPOS_ARTI_ID)
                 where p.RPOS_ID = to_number(:P14_RPOS_ID)
                   and p.RPOS_ARTI_ID is not null;
                FAKT_RECHNUNG.summen_berechnen(:P14_RPOS_RECH_ID);
                ```
        }}
        execution {{
            sequence: 40
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
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
            value: CREATE,SAVE
        }}
    )

)
"""
    return s


# --------------------------------------------------------------------------- Startseite, Listen, Breadcrumbs
def startseite():
    return fdl.dashboard()


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

    entry artikel (
        label: Artikel
        icon {
            imageIconCssClasses: fa-cube
        }
        layout {
            sequence: 30
        }
        link {
            target: {
                page: 20
            }
        }
        isCurrent {
            type: pages
            pages: [
                20
                21
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
                120
                121
            ]
        }
    )""" + s[j:]
    s = re.sub(r"\nlist admin-lookup-values \(.*?\n\)\n", "\n", s, flags=re.S)
    s = s.replace("        label: Startseite\n        icon {\n            imageIconCssClasses: fa-home",
                  "        label: Dashboard\n        icon {\n            imageIconCssClasses: fa-dashboard", 1)
    teile = [f"""select '{w['titel']}' as label, {w['seite']} as seite, '{w['icon']}' as image, '{w['beschreibung']}' as beschreibung,
                           (select count(*) from {w['tabelle']}) as anzahl
                      from dual""" for w in WL_FINANZ + ga.WL_ARTIKEL]
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


"""


def breadcrumbs():
    out = """breadcrumb breadcrumb (
    name: Breadcrumb

    entry home (
        name: Dashboard
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

    entry artikel (
        name: Artikel
        pageNumber: 20
        execution {
            sequence: 40
        }
        appearance {
            parentEntry: @home
        }
        link {
            target: {
                page: 20
            }
        }
    )

    entry artikel-bearbeiten (
        name: Artikel bearbeiten
        pageNumber: 21
        execution {
            sequence: 50
        }
        appearance {
            parentEntry: @artikel
        }
        link {
            target: {
                page: 21
            }
        }
    )
"""
    wl.WERTELISTEN = WL_FINANZ + ga.WL_ARTIKEL
    return out + wl.breadcrumb_eintraege() + ")\n"


LOVS_ABO = ["lov-mandanten", "lov-mitarbeiter", "lov-artikel", "lov-mwst-prozent", "lov-einheiten-code",
            "lov-kunden", "lov-zahlungsbedingungen", "lov-laender",
            "lov-artikelgruppen", "lov-einheiten", "lov-mwst-saetze"]   # Artikelseiten 20-22


def lovs_abonnieren():
    """Portal-LOVs kopieren und als Subscription kennzeichnen (Inhalt wie im Portal)."""
    portal = (APEX / "thg-portal" / "shared-components" / "lovs.apx").read_text(encoding="utf-8")
    p = FIN / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    for sid in LOVS_ABO:
        muster = rf"lov {re.escape(sid)} \(.*?\n\)\n"
        m = re.search(muster, portal, flags=re.S)
        blk = m.group(0).replace("    columnMapping {", f"    subscription {{\n        master: @/20000/{sid}\n    }}\n    columnMapping {{", 1)
        if f"lov {sid} (" in s:   # schon abonniert: Definition auf den Stand des Portals bringen
            s = re.sub(muster, lambda _: blk, s, count=1, flags=re.S)
        else:
            s = s.rstrip("\n") + "\n\n" + blk
    p.write_text(s, encoding="utf-8")


def pdf_seiten():
    """Seite 12 (Rechnung als PDF, inline) und 13 (Vorschau-Dialog mit Drucken/Herunterladen/Schliessen) –
    abgeleitet vom Kundenstammblatt (THG-KUNDEN Seiten 12/13), PDF aus FAKT_RECHNUNG_PDF (Skript 24)"""
    ersetzen = [
        ("P12_KUND_ID", "P12_RECH_ID"), ("P13_KUND_ID", "P13_RECH_ID"),
        ("KUND_STAMMBLATT.", "FAKT_RECHNUNG_PDF."),
        ("region stammblatt (", "region rechnung-pdf ("), ("@stammblatt", "@rechnung-pdf"),
        ("stammblatt-pdf", "rechnung-pdf"),
        ("name: Kundenstammblatt anzeigen", "name: Rechnung anzeigen"),
        ("alias: KUNDENSTAMMBLATT-ANZEIGEN", "alias: RECHNUNG-ANZEIGEN"),
        ("alias: KUNDENSTAMMBLATT", "alias: RECHNUNG-PDF"),
        ("name: Kundenstammblatt als PDF ausliefern", "name: Rechnung als PDF ausliefern"),
        ("name: Kundenstammblatt", "name: Rechnung PDF"),
        ("title: Kundenstammblatt", "title: Rechnung"),
        ('title="Kundenstammblatt"', 'title="Rechnung"'),
        ("Kundenstammblatt konnte nicht", "Rechnung konnte nicht"),
        # Schliessen mit Kennung: Seite 11 laedt danach neu (Nummer, Datum, Status, Historie aktuell)
        ("apex.navigation.dialog.cancel(true);",
         "// Rechnungsmaske (Seite 11) direkt neu laden – auch wenn der Dialog nach dem Abschliessen ohne\n"
         "                            // ausloesenden Button geoeffnet wurde (dann kommt kein Dialog-Ereignis an der Seite an)\n"
         "                            var neu = parent.apex && parent.apex.item('P11_SELBST_URL').getValue();\n"
         "                            if (neu) { parent.apex.navigation.redirect(neu); } else { apex.navigation.dialog.close(true, { pdf: 'Y' }); }"),
        # P12_RDOK_ID gesetzt: abgelegten Druck ausliefern (Registerkarte Dokumente); sonst PDF erzeugen, jeden Druck in
        # die Historie (Vorschau im Entwurf, sonst Rechnung) und den Rechnungsdruck ablegen (FAKT_RECHNUNG_DOKUMENT)
        ("l_pdf blob := FAKT_RECHNUNG_PDF.pdf(:P12_RECH_ID);\n                begin\n",
         "l_pdf blob;\n                begin\n"
         "                    if :P12_RDOK_ID is not null then\n"
         "                        select RDOK_DATEI into l_pdf from FAKT_RECHNUNG_DOKUMENTE\n"
         "                         where RDOK_ID = :P12_RDOK_ID and RDOK_RECH_ID = :P12_RECH_ID;\n"
         "                    else\n"
         "                        l_pdf := FAKT_RECHNUNG_PDF.pdf(:P12_RECH_ID);\n"
         "                        for r in (select RECH_STATUS, RECH_NUMMER from FAKT_RECHNUNGEN where RECH_ID = :P12_RECH_ID) loop\n"
         "                            FAKT_HISTORIE.protokoll(:P12_RECH_ID, case r.RECH_STATUS when 'ENTWURF' then 'Vorschau gedruckt'\n"
         "                                                                       else 'Rechnung gedruckt' end, r.RECH_NUMMER);\n"
         "                        end loop;\n"
         "                        FAKT_RECHNUNG_DOKUMENT.ablegen(:P12_RECH_ID, l_pdf);\n"
         "                        commit;\n"
         "                    end if;\n"),
        ("FAKT_RECHNUNG_PDF.dateiname(:P12_RECH_ID)", "FAKT_RECHNUNG_DOKUMENT.dateiname(:P12_RECH_ID, :P12_RDOK_ID)"),
        ("FAKT_RECHNUNG_PDF.dateiname(:P13_RECH_ID)", "FAKT_RECHNUNG_DOKUMENT.dateiname(:P13_RECH_ID, :P13_RDOK_ID)"),
        ("p_items     => 'P12_RECH_ID',\n                                             p_values    => :P13_RECH_ID,",
         "p_items     => 'P12_RECH_ID,P12_RDOK_ID',\n                                             p_values    => :P13_RECH_ID || ',' || :P13_RDOK_ID,"),
    ]
    for nr, datei in ((12, "p00012-kundenstammblatt.apx"), (13, "p00013-kundenstammblatt-anzeigen.apx")):
        s = (APEX / "thg-kunden" / "pages" / datei).read_text(encoding="utf-8")
        for a, b in ersetzen:
            s = s.replace(a, b)
        # abgelegter Druck (Registerkarte Dokumente): ID des Dokuments neben der Rechnung
        rid = f"    pageItem P{nr}_RECH_ID ("
        blk = s[s.index(rid):s.index("\n    )\n", s.index(rid)) + 7]
        s = s.replace(blk, blk + "\n" + blk.replace(f"P{nr}_RECH_ID", f"P{nr}_RDOK_ID")
                      .replace("sequence: 10", "sequence: 20"), 1)
        assert "KUND" not in s and "stammblatt" not in s.lower(), f"Seite {nr}: Reste vom Kundenstammblatt"
        name = "p00012-rechnung-pdf.apx" if nr == 12 else "p00013-rechnung-anzeigen.apx"
        (FIN / "pages" / name).write_text(s, encoding="utf-8")


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
    (FIN / "pages" / "p00014-position.apx").write_text(seite_14(), encoding="utf-8")
    (FIN / "pages" / "p00015-stornieren.apx").write_text(seite_15(), encoding="utf-8")
    pdf_seiten()
    # Artikelstamm (Seiten aus gen_artikel.py, umnummeriert 10/11/12 -> 20/21/22)
    (FIN / "pages" / "p00020-artikel.apx").write_text(ga.in_finanz(ga.seite_10()), encoding="utf-8")
    (FIN / "pages" / "p00021-artikel-bearbeiten.apx").write_text(ga.in_finanz(ga.seite_11()), encoding="utf-8")
    (FIN / "pages" / "p00100-wertelisten.apx").write_text(
        wl.uebersicht("wertelisten-finanz", "Wertelisten Finanz"), encoding="utf-8")
    ga.wl_seiten(FIN, WL_FINANZ + ga.WL_ARTIKEL)
    lp = FIN / "shared-components" / "lists.apx"
    lp.write_text(listen((ALLG / "shared-components" / "lists.apx").read_text(encoding="utf-8")), encoding="utf-8")
    (FIN / "shared-components" / "breadcrumbs.apx").write_text(breadcrumbs(), encoding="utf-8")
    lovs_abonnieren()
    print("THG-FINANZ erzeugt")
