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


# Abgeschlossene Rechnung nur lesen – ausser im Entwurf und nach "Rechnung bearbeiten" (Status IN_BEARBEITUNG, DDL 46)
NUR_LESEN = """        readOnly {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_STATUS not in ('ENTWURF', 'IN_BEARBEITUNG')
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


# Seitenskript Rechnung: Positionen als Baum (Haupt-/Unterpositionen) mit Detailfeldern rechts (ohne Backslashes – siehe zentrale Wissensdatenbank)
POS_JS = """    javaScript {
        executeWhenPageLoads:
            ```javascript-browser
            // Positionen der Rechnung:
            //  * links der Baum (#pos-baum): Hauptpositionen 1, 2, 3 … mit ihren Unterpositionen 10, 20, 30 …
            //    und der Summe je Zeile; Buttons Hauptposition / Unterposition / Löschen
            //  * rechts die Felder der gewaehlten Position (P11_POS_*), gespeichert per AJAX (POS_SPEICHERN)
            //  * Unterpositionen werden wie Hauptpositionen im Baum gewaehlt und rechts bearbeitet
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
                    $("#pos-kopieren").prop("disabled", !zustand.aenderbar || !zustand.id);
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
                    $("#pos-felder").hide();
                    markieren();
                };
                // Gesperrte Felder schickt der Browser nicht mit – der Schalter "Optional" kaeme beim Absenden der Seite
                // (z. B. "Rechnung drucken" einer abgeschlossenen Rechnung) leer an und scheitert an der Pruefung
                // "muss Y oder N sein". Vor dem Absenden daher wieder freigeben (gespeichert wird er nur per AJAX).
                $(window).on("apexbeforepagesubmit", function () {
                    apex.item("P11_POS_OPTIONAL").enable();
                });
                // Antwort von POS_LADEN in die Felder
                var zeigen = function (d) {
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
                    zustand.geaendert = false;
                    markieren();
                };
                // vor dem Wechsel der Position: ungespeicherte Eingaben nicht stillschweigend verwerfen
                var sicher = function (weiter) {
                    if (zustand.geaendert && zustand.aenderbar) {
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
                var oeffnen = function (id, hauptId) {
                    return server("POS_LADEN", { x01: id || "", x02: hauptId || "" }).then(function (d) {
                        zeigen(d);
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
                window.thgPositionen = { verschieben: verschieben };
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
                // gewaehlte Position kopieren (Hauptposition mit allen Unterpositionen bzw. Unterposition); die Kopie steht
                // direkt hinter dem Original und wird danach geoeffnet
                $("#pos-kopieren").on("click", function () {
                    sicher(function () {
                        server("POS_KOPIEREN", { x01: zustand.id }).then(function (d) {
                            if (d.fehler) {
                                fehler(d.fehler);
                                return;
                            }
                            apex.message.clearErrors();
                            apex.message.showPageSuccess("Position kopiert.");
                            laden().then(function () {
                                oeffnen(d.id);
                            });
                        });
                    });
                });
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
                  from table(sys.odcivarchar2list('ENTWURF', 'GEDRUCKT', 'GESENDET', 'IN_BEARBEITUNG', 'TEILBEZAHLT', 'BEZAHLT', 'STORNIERT'))
                ```
        }
        default {
            type: static
            staticValue: ENTWURF
        }
""", **f)
    # Zahlungsreferenz (RF, beim Abschliessen erzeugt) in Vierergruppen wie am Ausdruck – nur Anzeige (Prozess titel-setzen)
    s += item("P11_ZAHLUNGSREFERENZ", "displayOnly", "Zahlungsreferenz", 130, a, neue_zeile=False, spalten=3, form=None,
              extra="        settings {\n            sendOnPageSubmit: false\n        }\n")

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
    # Vor-/Schlusstext mit Fett/Kursiv/Aufzaehlung (Rich-Text-Editor, als HTML gespeichert – nicht Markdown, das ist die
    # Vorgabe des Editors). Klartext (Altdaten, Textvorlagen) wird nur fuer die Anzeige umgewandelt (Prozess titel-setzen,
    # FAKT_RECHNUNG.text_html); als HTML gespeichert erst beim naechsten Speichern der Rechnung
    rte = "        settings {\n            format: html\n            toolbar: full\n        }\n" + RTE_LEISTE()
    s += item("P11_RECH_VORTEXT", "richTextEditor", "Vortext", 10, "vortext", col="RECH_VORTEXT", dtype="clob",
              spalten=12, extra=rte + txt("VORTEXT"), **f)
    s += item("P11_RECH_SCHLUSSTEXT", "richTextEditor", "Schlusstext", 10, "schlusstext", col="RECH_SCHLUSSTEXT",
              dtype="clob", spalten=12, extra=rte + txt("SCHLUSSTEXT"), **f)
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
                                  + knopf("pos-kopieren", "Kopieren", "fa-copy")
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
    # als HTML speichern wie der Artikel (Vorgabe des Editors ist Markdown, das der PDF-Druck nicht versteht)
    s += item("P11_POS_BESCHREIBUNG", "richTextEditor", "Beschreibung", 150, p, spalten=12,
              extra="        settings {\n            format: html\n            toolbar: full\n        }\n"
              + RTE_LEISTE("            warnOnUnsavedChanges: ignore\n"), **ohne)

    # ------------------------------------------------ Zahlungen
    # Timeline wie die Historie (Report-Vorlage "Timeline"), chronologisch: zuerst "Rechnung erstellt" mit dem offenen
    # Betrag, dann je Zahlungseingang Betrag, Referenz, Bemerkung und der danach noch offene Betrag.
    # Erfassen per Button "Zahlungseingang" (Dialog Seite 16), Aendern/Loeschen per Klick auf die Zahlung.
    s += """    region zahlungen (
        name: Zahlungen
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                with r as (select RECH_ID, RECH_DATUM, RECH_SUMME_BRUTTO, RECH_CREATED_BY, RECH_MITA_ID
                             from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID),
                     z as (select ZAHL_ID, ZAHL_DATUM, ZAHL_BETRAG, ZAHL_REFERENZ, ZAHL_BEMERKUNG,
                                  ZAHL_CREATED_BY, ZAHL_CREATED_ON,
                                  sum(ZAHL_BETRAG)
                                      over (order by ZAHL_DATUM, ZAHL_CREATED_ON, ZAHL_ID) as KUMULIERT
                             from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = :P11_RECH_ID),
                     e as (select 0 as SORT, r.RECH_DATUM as DATUM, null as ZAHL_ID,
                                  coalesce((select MITA_NAME from ALLG_MITARBEITER where MITA_ID = r.RECH_MITA_ID),
                                           (select MITA_NAME from ALLG_MITARBEITER where MITA_BENUTZERNAME = r.RECH_CREATED_BY),
                                           r.RECH_CREATED_BY) as NAME,
                                  coalesce((select MITA_KUERZEL from ALLG_MITARBEITER where MITA_ID = r.RECH_MITA_ID),
                                           (select MITA_KUERZEL from ALLG_MITARBEITER where MITA_BENUTZERNAME = r.RECH_CREATED_BY)) as KUERZEL,
                                  'Rechnung' as TYP, 'fa-file-text-o' as ICON, 'u-info' as FARBE,
                                  'Rechnung erstellt' as TITEL,
                                  'Offen: ' || FAKT_HISTORIE.betrag(r.RECH_SUMME_BRUTTO) as TEXT
                             from r
                           union all
                           select 1, z.ZAHL_DATUM, z.ZAHL_ID,
                                  coalesce(m.MITA_NAME, z.ZAHL_CREATED_BY), m.MITA_KUERZEL,
                                  'Zahlung', 'fa-eur',
                                  case when r.RECH_SUMME_BRUTTO - z.KUMULIERT <= 0 then 'u-success' else 'u-warning' end,
                                  'Zahlungseingang ' || FAKT_HISTORIE.betrag(z.ZAHL_BETRAG),
                                  ltrim(nvl2(z.ZAHL_REFERENZ, ' · Referenz ' || z.ZAHL_REFERENZ, null)
                                        || nvl2(z.ZAHL_BEMERKUNG, ' · ' || z.ZAHL_BEMERKUNG, null)
                                        || ' · ' || case when r.RECH_SUMME_BRUTTO - z.KUMULIERT < 0
                                                         then 'Überzahlt: ' || FAKT_HISTORIE.betrag(z.KUMULIERT - r.RECH_SUMME_BRUTTO)
                                                         when r.RECH_SUMME_BRUTTO - z.KUMULIERT = 0 then 'Bezahlt'
                                                         else 'Offen: ' || FAKT_HISTORIE.betrag(r.RECH_SUMME_BRUTTO - z.KUMULIERT) end,
                                        ' ·')
                             from z cross join r
                             left join ALLG_MITARBEITER m on m.MITA_BENUTZERNAME = z.ZAHL_CREATED_BY)
                select NAME as USER_NAME,
                       coalesce(KUERZEL, upper(substr(NAME, 1, 2))) as USER_AVATAR,
                       'u-color-1' as USER_COLOR,
                       to_char(DATUM, 'DD.MM.YYYY') as EVENT_DATE,
                       TYP as EVENT_TYPE,
                       'fa ' || ICON as EVENT_ICON,
                       FARBE as EVENT_STATUS,
                       -- Zahlung: Titel als Link zum Dialog (aendern/loeschen)
                       case when ZAHL_ID is null then apex_escape.html(TITEL)
                            else '<a href="' || apex_escape.html_attribute(
                                     apex_page.get_url(p_page               => 16,
                                                       p_clear_cache        => '16',
                                                       p_items              => 'P16_ZAHL_ID,P16_RECH_ID',
                                                       p_values             => ZAHL_ID || ',' || :P11_RECH_ID,
                                                       p_triggering_element => 'apex.jQuery(''#zahlungen'')'))
                                 || '" title="Zahlung ändern">' || apex_escape.html(TITEL) || '</a>'
                       end as EVENT_TITLE,
                       TEXT as EVENT_DESC,
                       null as EVENT_MODIFIERS,
                       null as EVENT_ATTRIBUTES,
                       null as EVENT_LINK
                  from e
                 order by SORT, DATUM, ZAHL_ID
                ```
            pageItemsToSubmit: [
                P11_RECH_ID
            ]
        }
        advanced {
            regionDisplaySelector: true
            htmlDomId: zahlungen
        }
        layout {
            sequence: 60
            slot: body
        }
        appearance {
            template: @/standard
            cssClasses: thg-ohne-titel
            templateOptions: #DEFAULT#
        }
        componentAppearance {
            template: @/timeline
            templateOptions: #DEFAULT#
        }
        pagination {
            type: rowRangesXToYOfZWithPagination
        }
        reportLayout {
            numberOfRowsType: staticValue
            numberOfRows: 50
        }
        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT')
        }

""" + "".join(f"""        column {c} (
            type: plainText
            layout {{
                sequence: {i * 10}
            }}
""" + ("""            security {
                escapeSpecialChars: false
            }
""" if c == "EVENT_TITLE" else "") + """            sorting {
                sortable: false
            }
        )

""" for i, c in enumerate(("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON",
                                          "EVENT_STATUS", "EVENT_TITLE", "EVENT_DESC", "EVENT_MODIFIERS",
                                          "EVENT_ATTRIBUTES", "EVENT_LINK"), start=1)) + """    )

"""
    # Zahlungseingang erfassen (rechts oben in der Region): Dialog Seite 16 – nur offene bzw. teilbezahlte Rechnungen
    s += button("zahlungseingang", "ZAHLUNGSEINGANG", "Zahlungseingang", 10, "zahlungen", "edit", "@/text-with-icon",
                hot=True, icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 16
                items: {
                    P16_RECH_ID: &P11_RECH_ID.
                }
                clearCache: 16
            }
            warnOnUnsavedChanges: doNotCheck
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT')
        }
""")

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

    # Historie (nach Zahlungen): wer hat wann was geaendert (FAKT_RECHNUNG_HISTORIE, Trigger aus Skript 33) – als Timeline
    # (Report-Vorlage "Timeline" des Universal Theme): Avatar mit Kuerzel, Mitarbeiter, Zeitpunkt; farbiges Ereignis mit
    # Icon (Rechnung, Position, Druck, Zahlung, Bearbeitung, Storno, Versand); Aktion als Titel, Aenderungen darunter
    spalten = ("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE", "EVENT_ICON", "EVENT_STATUS",
               "EVENT_TITLE", "EVENT_DESC", "EVENT_MODIFIERS", "EVENT_ATTRIBUTES", "EVENT_LINK")
    s += """    region historie (
        name: Historie
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select nvl(m.MITA_NAME, h.RHIS_BENUTZER) as USER_NAME,
                       -- Kuerzel aus der Mitarbeiterpflege (THG-ADMIN), sonst Anfangsbuchstaben des Namens
                       coalesce(m.MITA_KUERZEL,
                                upper(substr(nvl(m.MITA_NAME, h.RHIS_BENUTZER), 1, 1)
                                      || substr(regexp_substr(nvl(m.MITA_NAME, h.RHIS_BENUTZER), '[[:space:]_.]+([^[:space:]_.])', 1, 1, null, 1), 1, 1)))
                           as USER_AVATAR,
                       'u-color-1' as USER_COLOR,
                       to_char(from_tz(h.RHIS_ZEITPUNKT, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') as EVENT_DATE,
                       e.TYP as EVENT_TYPE,
                       'fa ' || e.ICON as EVENT_ICON,
                       e.FARBE as EVENT_STATUS,
                       h.RHIS_AKTION as EVENT_TITLE,
                       h.RHIS_DETAIL as EVENT_DESC,
                       null as EVENT_MODIFIERS,
                       null as EVENT_ATTRIBUTES,
                       null as EVENT_LINK
                  from FAKT_RECHNUNG_HISTORIE h
                  left join ALLG_MITARBEITER m on m.MITA_BENUTZERNAME = h.RHIS_BENUTZER
                 cross apply (select case
                                       when h.RHIS_AKTION like 'Zahlung%' then 'Zahlung'
                                       when h.RHIS_AKTION like 'Position%' then 'Position'
                                       when h.RHIS_AKTION in ('Rechnung gedruckt', 'Vorschau gedruckt', 'Dokument abgelegt',
                                                              'Abgeschlossen') then 'Druck'
                                       when h.RHIS_AKTION in ('Zur Bearbeitung geöffnet', 'Bearbeitung abgeschlossen') then 'Bearbeitung'
                                       when h.RHIS_AKTION in ('Storniert', 'Stornogrund') then 'Storno'
                                       when h.RHIS_AKTION in ('Gesendet', 'E-Mail versendet') then 'Versand'
                                       else 'Rechnung'
                                     end as TYP,
                                     case
                                       when h.RHIS_AKTION like 'Zahlung%' then 'fa-eur'
                                       when h.RHIS_AKTION like 'Position%' then 'fa-list'
                                       when h.RHIS_AKTION = 'Dokument abgelegt' then 'fa-file-pdf-o'
                                       when h.RHIS_AKTION in ('Rechnung gedruckt', 'Vorschau gedruckt', 'Abgeschlossen') then 'fa-print'
                                       when h.RHIS_AKTION = 'Zur Bearbeitung geöffnet' then 'fa-unlock'
                                       when h.RHIS_AKTION = 'Bearbeitung abgeschlossen' then 'fa-lock'
                                       when h.RHIS_AKTION in ('Storniert', 'Stornogrund') then 'fa-ban'
                                       when h.RHIS_AKTION = 'Gesendet' then 'fa-paper-plane-o'
                                       when h.RHIS_AKTION = 'E-Mail versendet' then 'fa-envelope-o'
                                       when h.RHIS_AKTION in ('Angelegt', 'Kopiert') then 'fa-plus-circle'
                                       else 'fa-pencil'
                                     end as ICON,
                                     case
                                       when h.RHIS_AKTION like 'Zahlung%' then 'u-success'
                                       when h.RHIS_AKTION in ('Storniert', 'Stornogrund') then 'u-danger'
                                       when h.RHIS_AKTION in ('Zur Bearbeitung geöffnet', 'Bearbeitung abgeschlossen') then 'u-warning'
                                       when h.RHIS_AKTION in ('Rechnung gedruckt', 'Vorschau gedruckt', 'Dokument abgelegt',
                                                              'Abgeschlossen', 'Gesendet', 'E-Mail versendet') then 'u-info'
                                       else 'u-color-14'
                                     end as FARBE
                                from dual) e
                 where h.RHIS_RECH_ID = :P11_RECH_ID
                 order by h.RHIS_ZEITPUNKT desc, h.RHIS_ID desc
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
            template: @/timeline
            templateOptions: #DEFAULT#
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
            layout {{
                sequence: {i * 10}
            }}
            sorting {{
                sortable: false
            }}
        )

""" for i, c in enumerate(spalten, start=1)) + """    )

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
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS in ('ENTWURF', 'IN_BEARBEITUNG')
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
            plsqlExpression: :P11_RECH_ID is not null and FAKT_RECHNUNG.bearbeitbar(:P11_RECH_ID) = 'Y'
        }
        confirmation {
            message: Die Rechnung &P11_RECH_NUMMER. ist abgeschlossen. Wirklich ändern? Rechnungsnummer und Rechnungsdatum bleiben unverändert; bis zum erneuten Drucken ist die Rechnung in Bearbeitung und es können keine Zahlungen zugeordnet werden.
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
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS in ('GEDRUCKT', 'GESENDET')
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
    # Rechnungsversand per E-Mail (abgeschlossene Rechnung, nicht in Bearbeitung): Dialog Seite 17 mit Vorschau der
    # E-Mail und des Anhangs, dort "E-Mail senden" (Status GESENDET, Historie)
    s += button("versenden", "VERSENDEN", "Rechnung versenden", 18, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-envelope-o", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 17
                items: {
                    P17_RECH_ID: &P11_RECH_ID.
                }
                clearCache: 17
            }
            warnOnUnsavedChanges: doNotCheck
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P11_RECH_ID is not null and :P11_RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT')
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
    s += button("up", "UP", "Zurück zur Rechnungsliste", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options=grau, verhalten="""            action: redirectThisApp
            target: {
                page: 10
            }
            warnOnUnsavedChanges: doNotCheck
""")

    # ------------------------------------------------ Prozesse
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
    s += """    dynamicAction zahlung-nach-dialog (
        name: Nach dem Dialog Zahlungseingang die Rechnung neu laden
        execution {
            sequence: 6
        }
        when {
            event: apexafterclosedialog
            selectionType: jQuerySelector
            jquerySelector: #zahlungen
        }

        action zahlung-neu-laden (
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
    s += """    dynamicAction versand-nach-dialog (
        name: Nach dem Versenden die Rechnung neu laden
        execution {
            sequence: 7
        }
        when {
            event: apexafterclosedialog
            selectionType: button
            button: @versenden
        }

        action versand-neu-laden (
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
                -- bewusste Aktion "Rechnung bearbeiten": Status IN_BEARBEITUNG (bleibt bis "Rechnung drucken"), Maske und
                -- Positionen wieder aenderbar; Historie "Zur Bearbeitung geöffnet" per Trigger
                FAKT_RECHNUNG.bearbeiten(:P11_RECH_ID);
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
                -- "Rechnung drucken" nach "Rechnung bearbeiten" schliesst die Bearbeitung ab: Status wieder GEDRUCKT, Rechnung
                -- gesperrt (Aenderungen sind vorher gespeichert); der Druck legt eine neue Dokumentversion ab
                if :P11_PDF_OEFFNEN = 'Y' and :P11_RECH_ID is not null then
                    FAKT_RECHNUNG.bearbeitung_abschliessen(:P11_RECH_ID);
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
                -- Klartext (Altdaten, Textvorlage) fuer den Rich-Text-Editor als HTML anzeigen; gespeichert wird erst beim
                -- naechsten Speichern der Rechnung
                :P11_RECH_VORTEXT := FAKT_RECHNUNG.text_html(:P11_RECH_VORTEXT);
                :P11_RECH_SCHLUSSTEXT := FAKT_RECHNUNG.text_html(:P11_RECH_SCHLUSSTEXT);
                -- Zahlungsreferenz in Vierergruppen (wie am Ausdruck)
                :P11_ZAHLUNGSREFERENZ := null;
                for z in (select FAKT_RECHNUNG.referenz_anzeige(RECH_ZAHLUNGSREFERENZ) as REF
                            from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID) loop
                    :P11_ZAHLUNGSREFERENZ := z.REF;
                end loop;
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
                -- Artikeldaten fuer eine Position (AJAX aus den Feldern P11_POS_*):
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
                    apex_json.write('aenderbar', l_status in ('ENTWURF', 'IN_BEARBEITUNG'));
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
                            select nvl(sum(ZAHL_BETRAG), 0) into l_bezahlt
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
                    if l_status not in ('ENTWURF', 'IN_BEARBEITUNG') then
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
                    if l_status not in ('ENTWURF', 'IN_BEARBEITUNG') then
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

    process pos-kopieren (
        name: POS_KOPIEREN
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- Position kopieren (x01 = RPOS_ID): Hauptposition mit Unterpositionen bzw. Unterposition, Kopie dahinter
                declare
                    l_id     number := to_number(apex_application.g_x01);
                    l_mand   FAKT_RECHNUNGEN.RECH_MAND_ID%type;
                    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
                    l_anz    pls_integer;
                    l_neu    number;
                begin
                    select RECH_MAND_ID, RECH_STATUS into l_mand, l_status from FAKT_RECHNUNGEN where RECH_ID = :P11_RECH_ID;
                    if l_mand <> :MANDANT_ID then
                        raise_application_error(-20240, 'Diese Rechnung gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    if l_status not in ('ENTWURF', 'IN_BEARBEITUNG') then
                        raise_application_error(-20210, 'Positionen können nur im Entwurf oder nach „Rechnung bearbeiten“ geändert werden.');
                    end if;
                    select count(*) into l_anz from FAKT_RECHNUNGSPOSITIONEN where RPOS_ID = l_id and RPOS_RECH_ID = :P11_RECH_ID;
                    if l_anz = 0 then
                        raise_application_error(-20211, 'Die Position gehört nicht zu dieser Rechnung.');
                    end if;
                    l_neu := FAKT_RECHNUNG.position_kopieren(l_id);
                    apex_json.open_object;
                    apex_json.write('id', to_char(l_neu));
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
            sequence: 55
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
                    if l_status not in ('ENTWURF', 'IN_BEARBEITUNG') then
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
            plsqlExpression: :REQUEST in ('CREATE', 'SAVE', 'ABSCHLIESSEN') or (:REQUEST in ('PDF', 'VORSCHAU') and :P11_RECH_STATUS in ('ENTWURF', 'IN_BEARBEITUNG'))
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


# Werkzeugleiste der Rich-Text-Editoren (Vor-/Schlusstext, Positionsbeschreibung): Ueberschrift, Fett, Kursiv,
# Aufzaehlung, Nummerierung, Rueckgaengig/Wiederholen – ohne Code, Link, Blockzitat, Codeblock (CKEditor 5)
RTE_LEISTE = lambda zusatz="": """        advanced {
""" + zusatz + """            initJavaScriptFunction:
                ```javascript-browser
                function (options) {
                    options.editorOptions = options.editorOptions || {};
                    options.editorOptions.toolbar = {
                        items: ["heading", "|", "bold", "italic", "|", "bulletedList", "numberedList", "|", "undo", "redo"]
                    };
                    return options;
                }
                ```
        }
"""


def im_menue(btn, dom_id):
    """Button unsichtbar (u-hidden) mit fester DOM-ID: wird ueber das Aktionen-Menue (Kebab-Button) angeklickt und
    behaelt Bedingung, Bestaetigung und Verhalten."""
    i = btn.index("        appearance {\n")
    btn = btn[:i] + f"        advanced {{\n            htmlDomId: {dom_id}\n        }}\n" + btn[i:]
    return btn.replace("        appearance {\n", "        appearance {\n            cssClasses: u-hidden\n", 1)




def bericht(sid, name, seq, sql, spalten, leer, extra_region=""):
    """Classic Report (Standard-Vorlage) mit Spalten [(Name, Ueberschrift, html=False, rechts=False)]"""
    s = f"""    region {sid} (
        name: {name}
        type: classicReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
{sql}
                ```
        }}
        layout {{
            sequence: {seq}
            slot: body
        }}
        appearance {{
            template: @/standard
            templateOptions: #DEFAULT#
        }}
        componentAppearance {{
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Report--stretch
                t-Report--staticRowColors
                t-Report--rowHighlight
                t-Report--horizontalBorders
            ]
        }}
        pagination {{
            type: rowRangesXToYOfZWithPagination
        }}
        reportLayout {{
            numberOfRowsType: staticValue
            numberOfRows: 50
        }}
        messages {{
            whenNoDataFound: {leer}
        }}
{extra_region}
"""
    for i, (c, h, html, rechts) in enumerate(spalten, start=1):
        s += f"""        column {c} (
            type: {"hidden" if h is None else "plainText"}
""" + ("" if h is None else f"""            heading {{
                heading: {h}
""" + ("                alignment: end\n" if rechts else "") + """            }
""") + f"""            layout {{
                sequence: {i * 10}
""" + ("                columnAlignment: end\n" if rechts else "") + """            }
""" + ("""            security {
                escapeSpecialChars: false
            }
""" if html else "") + ("" if h is None else """            sorting {
                sortable: false
            }
""") + """        )

"""
    return s + "    )\n\n"


def seite_30():
    """Bankdatei hochladen (Menuepunkt): CAMT-Datei (camt.052/.053/.054, z.B. ELBA-Export) des Mandanten der Sitzung
    hochladen -> FAKT_BANK.einlesen speichert die Buchungen (jede nur einmal) und gleicht die Eingaenge mit den offenen
    Rechnungen ab (Zahlung anlegen bzw. vorhandene verknuepfen, Status der Rechnung per Trigger). Darunter die
    Zahlungseingaenge mit Zuordnung und die hochgeladenen Dateien. "Erneut abgleichen" prueft offene Eingaenge noch einmal
    (z.B. nachdem eine Rechnung erfasst wurde)."""
    s = KOPF(30, "Bankdatei hochladen", "BANKDATEI").replace("cursorFocus: doNotFocusCursor\n", "cursorFocus: doNotFocusCursor\n        warnOnUnsavedChanges: false\n") + BREADCRUMB("Bankdatei hochladen")
    s += region("upload", "Bankdatei hochladen", 10, extra="""        source {
            htmlCode:
                ```html
                <p>Kontoauszug als CAMT-Datei (XML, z.&nbsp;B. ELBA-Export „camt.052“ oder „camt.053“) des Kontos von
                &MANDANT_NAME. hochladen. Die Zahlungseingänge werden automatisch den offenen Rechnungen zugeordnet –
                über die Zahlungsreferenz, die Rechnungsnummer im Verwendungszweck oder den offenen Betrag und den Kunden –,
                sonst den Debitoren (z.&nbsp;B. Mieter) über die IBAN bzw. den Namen des Zahlers.</p>
                ```
        }
""")
    s += """    pageItem P30_DATEI (
        type: fileUpload
        label {
            label: Bankdatei (XML)
            alignment: left
        }
        display {
            displayAs: inlineDropzone
            dropzoneTitle: Bankdatei hierher ziehen
            dropzoneDesc: oder klicken zum Auswählen
        }
        storage {
            type: appTempFiles
        }
        layout {
            sequence: 10
            region: @upload
            slot: regionBody
            columnSpan: 12
            alignment: left
        }
        appearance {
            template: @/optional-floating
            templateOptions: #DEFAULT#
        }
    )

    pageItem P30_MELDUNG (
        type: hidden
        layout {
            sequence: 20
            region: @upload
            slot: regionBody
        }
    )

"""
    s += button("hochladen", "HOCHLADEN", "Hochladen und abgleichen", 10, "upload", "next", "@/text-with-icon", hot=True,
                icon="fa-upload", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="            warnOnUnsavedChanges: doNotCheck\n")
    s += button("abgleichen", "ABGLEICHEN", "Erneut abgleichen", 20, "upload", "next", "@/text-with-icon",
                icon="fa-refresh", options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="            warnOnUnsavedChanges: doNotCheck\n")
    # Zahlungseingaenge als Interactive Report (Aktionsleiste: Suche, Filter, Sortierung, Download); Status farbig und
    # Beleg als Link ueber HTML-Ausdruck, damit Suche/Filter auf dem Klartext arbeiten
    sql = """                -- Eingaenge des Mandanten, neueste zuerst; Beleg als Link (Rechnung, Gutschrift bzw. Debitor)
                select u.BKUM_ID,
                       u.BKUM_BUCHUNGSDATUM as DATUM,
                       u.BKUM_BETRAG as BETRAG,
                       u.BKUM_GEGEN_NAME as AUFTRAGGEBER,
                       FAKT_RECHNUNG.referenz_anzeige(u.BKUM_GEGEN_IBAN) as IBAN,
                       trim(u.BKUM_REFERENZ || ' ' || u.BKUM_VERWENDUNGSZWECK) as VERWENDUNGSZWECK,
                       FAKT_BANK.status_text(u.BKUM_STATUS) as STATUS,
                       case u.BKUM_STATUS when 'ZUGEORDNET' then 'u-success-text'
                                          when 'DEBITOR' then 'u-success-text'
                                          when 'BEREITS_BEZAHLT' then 'u-info-text'
                                          when 'OFFEN' then 'u-warning-text' end as STATUS_KLASSE,
                       case when d.DEBI_ID is not null then 'Debitor ' || d.DEBI_NAME
                            when g.GUTS_ID is not null then 'Gutschrift ' || coalesce(g.GUTS_INTERN_NUMMER, g.GUTS_NUMMER, g.GUTS_AUSSTELLER)
                            when r.RECH_ID is not null then 'Rechnung ' || r.RECH_NUMMER
                       end as BELEG,
                       case when d.DEBI_ID is not null then
                                apex_page.get_url(p_page => 51, p_clear_cache => '51', p_items => 'P51_DEBI_ID', p_values => d.DEBI_ID)
                            when g.GUTS_ID is not null then
                                apex_page.get_url(p_page => 41, p_clear_cache => '41', p_items => 'P41_GUTS_ID', p_values => g.GUTS_ID)
                            when r.RECH_ID is not null then
                                apex_page.get_url(p_page => 11, p_clear_cache => '11', p_items => 'P11_RECH_ID', p_values => r.RECH_ID)
                       end as BELEG_URL,
                       coalesce(u.BKUM_ZUORDNUNG,
                                case when k.KUNDE is not null then 'Auftraggeber ist Kunde ' || k.KUNDE
                                                                   || ' – passende Rechnung bzw. Gutschrift fehlt' end) as ZUORDNUNG,
                       -- von Hand einer Rechnung/Gutschrift zuordnen bzw. Zuordnung aendern (Dialog Seite 31)
                       '<a class="t-Button t-Button--small t-Button--icon t-Button--iconLeft" href="'
                       || apex_escape.html_attribute(apex_page.get_url(p_page => 31, p_clear_cache => '31',
                                                                       p_items => 'P31_BKUM_ID', p_values => u.BKUM_ID))
                       || '" title="Von Hand einer Rechnung, Gutschrift bzw. einem Debitor zuordnen"><span class="t-Icon t-Icon--left fa '
                       || case when u.BKUM_STATUS = 'OFFEN' then 'fa-link" aria-hidden="true"></span>Zuordnen'
                               else 'fa-pencil" aria-hidden="true"></span>Ändern' end || '</a> ' ||
                       -- nicht zuordenbarer Eingang eines Nicht-Kunden: Debitor daraus anlegen (Seite 51, Request ANLEGEN)
                       case when u.BKUM_STATUS = 'OFFEN' and u.BKUM_RECH_ID is null and u.BKUM_GUTS_ID is null
                             and k.KUNDE is null then
                           '<a class="t-Button t-Button--small t-Button--icon t-Button--iconLeft" href="'
                           || apex_escape.html_attribute(apex_page.get_url(p_page => 51, p_clear_cache => '51',
                                                                           p_items => 'P51_BKUM_ID', p_values => u.BKUM_ID,
                                                                           p_request => 'ANLEGEN'))
                           || '" title="Debitor aus dieser Buchung anlegen und zuweisen"><span class="t-Icon t-Icon--left fa fa-user-plus" aria-hidden="true"></span>'
                           || 'Debitor anlegen</a>'
                       end as AKTION
                  from FAKT_BANKUMSAETZE u
                  left join FAKT_RECHNUNGEN r on r.RECH_ID = u.BKUM_RECH_ID
                  left join FAKT_GUTSCHRIFTEN g on g.GUTS_ID = u.BKUM_GUTS_ID
                  left join FAKT_DEBITOREN d on d.DEBI_ID = u.BKUM_DEBI_ID
                  -- Auftraggeber ist ein Kunde (Name passt): kein Debitor, sondern Rechnung/Gutschrift fehlt
                  outer apply (select max(c.KUND_NUMMER || ' ' || c.KUND_FIRMENNAME) as KUNDE
                                 from KUND_KUNDEN c
                                where u.BKUM_STATUS = 'OFFEN' and u.BKUM_RECH_ID is null and u.BKUM_GUTS_ID is null
                                  and c.KUND_FIRMENNAME is not null
                                  and FAKT_DEBITOR.ist_kunde(c.KUND_FIRMENNAME, u.BKUM_GEGEN_NAME) = 'Y') k
                 where u.BKUM_MAND_ID = :MANDANT_ID
                   and u.BKUM_RICHTUNG = 'CRDT'
                 order by u.BKUM_BUCHUNGSDATUM desc, u.BKUM_ID desc"""
    def ir_spalte(name, heading, seq, dtype, maske=None, rechts=False, html=None, hidden=False, escape=True):
        return f"""
        column {name} (
            type: {"hidden" if hidden else "plainText"}
""" + f"""            heading {{
                heading: {heading or name}
""" + ("                alignment: end\n" if rechts else "") + """            }
""" + f"""            layout {{
                sequence: {seq}
""" + ("                columnAlignment: end\n" if rechts else "") + """            }
""" + (f"""            appearance {{
                formatMask: {maske}
            }}
""" if maske else "") + (f"""            columnFormatting {{
                htmlExpression: {html}
            }}
""" if html else "") + ("" if escape else """            security {
                escapeSpecialChars: false
            }
""") + f"""            source {{
                dataType: {dtype}
            }}
        )
"""
    s += f"""    region eingaenge (
        name: Zahlungseingänge
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
            sequence: 20
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
            whenNoDataFound: Noch keine Zahlungseingänge – bitte eine Bankdatei hochladen.
        }}
""" + ir_spalte("BKUM_ID", None, 5, "NUMBER", hidden=True) \
       + ir_spalte("DATUM", "Datum", 10, "DATE", maske="DD.MM.YYYY") \
       + ir_spalte("BETRAG", "Betrag", 20, "NUMBER", maske="FML999G999G990D00", rechts=True) \
       + ir_spalte("AUFTRAGGEBER", "Auftraggeber", 30, "STRING") \
       + ir_spalte("IBAN", "IBAN", 35, "STRING") \
       + ir_spalte("VERWENDUNGSZWECK", "Verwendungszweck", 40, "STRING") \
       + ir_spalte("STATUS", "Status", 50, "STRING", html='<span class="#STATUS_KLASSE#">#STATUS#</span>') \
       + ir_spalte("STATUS_KLASSE", None, 55, "STRING", hidden=True) \
       + ir_spalte("BELEG", "Rechnung / Gutschrift / Debitor", 60, "STRING", html='<a href="#BELEG_URL#">#BELEG#</a>') \
       + ir_spalte("BELEG_URL", None, 65, "STRING", hidden=True) \
       + ir_spalte("ZUORDNUNG", "Zuordnung", 70, "STRING") \
       + ir_spalte("AKTION", "Aktion", 80, "STRING", escape=False) + """
    )

"""
    s += bericht("dateien", "Hochgeladene Bankdateien", 30, """                select to_char(from_tz(d.BKDT_CREATED_ON, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') as HOCHGELADEN,
                       d.BKDT_CREATED_BY as VON,
                       d.BKDT_DATEINAME as DATEI,
                       FAKT_RECHNUNG.referenz_anzeige(d.BKDT_IBAN) as KONTO,
                       d.BKDT_FORMAT as FORMAT,
                       d.BKDT_ANZ_UMSAETZE as BUCHUNGEN,
                       d.BKDT_ANZ_NEU as NEU,
                       d.BKDT_ANZ_ZUGEORDNET as ZUGEORDNET
                  from FAKT_BANKDATEIEN d
                 where d.BKDT_MAND_ID = :MANDANT_ID
                 order by d.BKDT_CREATED_ON desc""",
                 [("HOCHGELADEN", "Hochgeladen", False, False), ("VON", "Von", False, False),
                  ("DATEI", "Datei", False, False), ("KONTO", "Konto", False, False), ("FORMAT", "Format", False, False),
                  ("BUCHUNGEN", "Buchungen", False, True), ("NEU", "Davon neu", False, True),
                  ("ZUGEORDNET", "Zugeordnet", False, True)],
                 "Noch keine Bankdatei hochgeladen.")
    s += """    dynamicAction nach-dialog (
        name: Nach dem Zuordnen die Zahlungseingänge aktualisieren
        execution {
            sequence: 10
        }
        when {
            event: apexafterclosedialog
            selectionType: jQuerySelector
            jquerySelector: body
        }

        action refresh (
            action: refresh
            affectedElements {
                selectionType: region
                region: @eingaenge
            }
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

    process bankdatei-einlesen (
        name: Bankdatei einlesen und abgleichen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                declare
                    l_blob  blob;
                    l_name  varchar2(400);
                    l_id    number;
                begin
                    if :P30_DATEI is null then
                        raise_application_error(-20263, 'Bitte eine Bankdatei auswählen.');
                    end if;
                    select blob_content, filename into l_blob, l_name
                      from apex_application_temp_files where name = :P30_DATEI;
                    l_id := FAKT_BANK.einlesen(:MANDANT_ID, l_name, l_blob);
                    -- neu eingelesen bzw. "bereits hochgeladen – Zuordnung erneut geprueft"
                    :P30_MELDUNG := FAKT_BANK.meldung;
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
            whenButtonPressed: @hochladen
        }
        successMessage {
            successMessage: &P30_MELDUNG.
        }
    )

    process erneut-abgleichen (
        name: Offene Eingänge erneut abgleichen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                :P30_MELDUNG := FAKT_BANK.abgleichen(:MANDANT_ID) || ' Zahlungseingänge zugeordnet.';
                ```
        }
        execution {
            sequence: 20
        }
        serverSideCondition {
            whenButtonPressed: @abgleichen
        }
        successMessage {
            successMessage: &P30_MELDUNG.
        }
    )

)
"""
    return s


def seite_31():
    """Zahlungseingang zuordnen (Dialog aus Seite 30): Buchung von Hand einem Debitor (eigene Region) bzw. einer Rechnung/Gutschrift des Mandanten
    zuordnen (FAKT_BANK.zuordnen) oder eine Zuordnung aufheben (FAKT_BANK.aufheben). Beide Listen als Interactive Report,
    passende (Zahler/Kunde = Auftraggeber bzw. gleicher Betrag) zuerst."""
    s = """page 31 (
    name: Zahlungseingang zuordnen
    alias: ZAHLUNG-ZUORDNEN
    title: Zahlungseingang zuordnen
    appearance {
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }
    dialog {
        width: 1200
        chained: false
        resizable: true
    }
    navigation {
        cursorFocus: doNotFocusCursor
        warnOnUnsavedChanges: false
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region buttons (
        name: Buttons
        type: staticContent
        layout {
            sequence: 90
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

"""
    s += bericht("buchung", "Zahlungseingang", 10, """                select to_char(u.BKUM_BUCHUNGSDATUM, 'DD.MM.YYYY') as DATUM,
                       FAKT_HISTORIE.betrag(u.BKUM_BETRAG) as BETRAG,
                       u.BKUM_GEGEN_NAME as AUFTRAGGEBER,
                       trim(u.BKUM_REFERENZ || ' ' || u.BKUM_VERWENDUNGSZWECK) as VERWENDUNGSZWECK,
                       FAKT_BANK.status_text(u.BKUM_STATUS) as STATUS,
                       u.BKUM_ZUORDNUNG as ZUORDNUNG
                  from FAKT_BANKUMSAETZE u
                 where u.BKUM_ID = :P31_BKUM_ID and u.BKUM_MAND_ID = :MANDANT_ID""",
                 [("DATUM", "Datum", False, False), ("BETRAG", "Betrag", False, True),
                  ("AUFTRAGGEBER", "Auftraggeber", False, False), ("VERWENDUNGSZWECK", "Verwendungszweck", False, False),
                  ("STATUS", "Status", False, False), ("ZUORDNUNG", "Zuordnung", False, False)],
                 "Buchung nicht gefunden.").replace("            slot: body\n", "            slot: contentBody\n", 1)
    for nr, (name, schutz) in enumerate((("P31_BKUM_ID", True), ("P31_BELEGART", False), ("P31_BELEG_ID", False),
                                         ("P31_ZUGEORDNET", True), ("P31_ZIEL", True)), 1):
        s += f"""    pageItem {name} (
        type: hidden
        layout {{
            sequence: {nr}
            region: @buchung
            slot: regionBody
        }}
""" + ("""        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
""" if schutz and name == "P31_BKUM_ID" else "") + ("" if schutz else """        settings {
            valueProtected: false
        }
""") + "    )\n\n"
    knopf = """'<button type="button" class="t-Button t-Button--small t-Button--hot" onclick="apex.page.submit({request:''ZUORDNEN'','
                       || 'set:{P31_BELEGART:''' || §ART || ''',P31_BELEG_ID:''' || §ID || '''}})">§TEXT</button>' as AKTION"""
    sql_debi = """                -- aktive Debitoren des Mandanten; Zahler passt (IBAN bzw. Name) bzw. gleicher Betrag zuerst
                select d.DEBI_ID,
                       d.DEBI_NAME,
                       d.DEBI_BEZEICHNUNG,
                       d.DEBI_BETRAG,
                       FAKT_DEBITOR.intervall_text(d.DEBI_INTERVALL) as INTERVALL,
                       d.RUECKSTAND,
                       d.LETZTE_ZAHLUNG,
                       FAKT_RECHNUNG.referenz_anzeige(d.DEBI_IBAN) as IBAN,
                       case when replace(upper(u.BKUM_GEGEN_IBAN), ' ') = d.DEBI_IBAN
                              or FAKT_DEBITOR.name_passt(d.DEBI_NAME, u.BKUM_GEGEN_NAME) = 'Y' then 'Ja' else 'Nein' end as ZAHLER_PASST,
                       case when u.BKUM_BETRAG = d.DEBI_BETRAG then 'Ja' else 'Nein' end as BETRAG_PASST,
                       """ + knopf.replace("§ART", "'DEBITOR'").replace("§ID", "d.DEBI_ID").replace("§TEXT", "Zuweisen") + """
                  from FAKT_DEBITOREN_V d
                  join FAKT_BANKUMSAETZE u on u.BKUM_ID = :P31_BKUM_ID and u.BKUM_MAND_ID = :MANDANT_ID
                 where d.DEBI_MAND_ID = u.BKUM_MAND_ID
                   and d.DEBI_IST_AKTIV = 'Y'
                 order by case when replace(upper(u.BKUM_GEGEN_IBAN), ' ') = d.DEBI_IBAN
                                 or FAKT_DEBITOR.name_passt(d.DEBI_NAME, u.BKUM_GEGEN_NAME) = 'Y' then 0 else 1 end,
                          case when u.BKUM_BETRAG = d.DEBI_BETRAG then 0 else 1 end,
                          upper(d.DEBI_NAME)"""
    sql = """                -- Rechnungen und Gutschriften des Mandanten (ohne Entwuerfe/stornierte); Kunde = Auftraggeber bzw. gleicher
                -- Betrag zuerst
                select b.BELEGART,
                       b.RECH_ID,
                       case b.BELEGART when 'GUTSCHRIFT' then 'Gutschrift ' else 'Rechnung ' end || b.RECH_NUMMER as BELEG,
                       b.RECH_DATUM as DATUM,
                       b.KUNDE,
                       b.RECH_SUMME_BRUTTO as BRUTTO,
                       b.OFFEN,
                       FAKT_RECHNUNG.status_text(b.RECH_STATUS) as STATUS,
                       case when FAKT_DEBITOR.ist_kunde(b.KUNDE, u.BKUM_GEGEN_NAME) = 'Y' then 'Ja' else 'Nein' end as KUNDE_PASST,
                       case when u.BKUM_BETRAG in (b.RECH_SUMME_BRUTTO, b.OFFEN) then 'Ja' else 'Nein' end as BETRAG_PASST,
                       """ + knopf.replace("§ART", "b.BELEGART").replace("§ID", "b.RECH_ID").replace("§TEXT", "Zuordnen") + """
                  from FAKT_BELEGE_V b
                  join FAKT_BANKUMSAETZE u on u.BKUM_ID = :P31_BKUM_ID and u.BKUM_MAND_ID = :MANDANT_ID
                 where b.RECH_MAND_ID = u.BKUM_MAND_ID
                   and b.RECH_STATUS not in ('ENTWURF', 'IN_BEARBEITUNG', 'STORNIERT')
                 order by case when FAKT_DEBITOR.ist_kunde(b.KUNDE, u.BKUM_GEGEN_NAME) = 'Y' then 0 else 1 end,
                          case when u.BKUM_BETRAG in (b.RECH_SUMME_BRUTTO, b.OFFEN) then 0 else 1 end,
                          b.RECH_DATUM desc"""
    def sp(name, heading, seq, dtype, maske=None, rechts=False, hidden=False, escape=True):
        return f"""
        column {name} (
            type: {"hidden" if hidden else "plainText"}
            heading {{
                heading: {heading}
""" + ("                alignment: end\n" if rechts else "") + f"""            }}
            layout {{
                sequence: {seq}
""" + ("                columnAlignment: end\n" if rechts else "") + """            }
""" + (f"""            appearance {{
                formatMask: {maske}
            }}
""" if maske else "") + ("" if escape else """            security {
                escapeSpecialChars: false
            }
""") + f"""            source {{
                dataType: {dtype}
            }}
        )
"""
    def ir(sid, name, seq, abfrage, leer, spalten):
        return f"""    region {sid} (
        name: {name}
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
{abfrage}
                ```
            pageItemsToSubmit: [
                P31_BKUM_ID
            ]
        }}
        layout {{
            sequence: {seq}
            slot: contentBody
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
            whenNoDataFound: {leer}
        }}
""" + spalten + """
    )

"""
    # Debitoren in eigener Region zwischen Zahlungseingang und Belegen
    s += ir("debitoren", "Debitor wählen", 15, sql_debi, "Keine aktiven Debitoren.",
            sp("DEBI_ID", "ID", 5, "NUMBER", hidden=True) + sp("DEBI_NAME", "Debitor", 10, "STRING")
            + sp("DEBI_BEZEICHNUNG", "Bezeichnung", 20, "STRING")
            + sp("DEBI_BETRAG", "Betrag", 30, "NUMBER", maske="FML999G999G990D00", rechts=True)
            + sp("INTERVALL", "Intervall", 40, "STRING")
            + sp("RUECKSTAND", "Rückstand", 50, "NUMBER", maske="FML999G999G990D00", rechts=True)
            + sp("LETZTE_ZAHLUNG", "Letzte Zahlung", 60, "DATE", maske="DD.MM.YYYY") + sp("IBAN", "IBAN des Zahlers", 70, "STRING")
            + sp("ZAHLER_PASST", "Zahler passt", 80, "STRING") + sp("BETRAG_PASST", "Betrag passt", 90, "STRING")
            + sp("AKTION", "Aktion", 100, "STRING", escape=False))
    s += ir("belege", "Rechnung bzw. Gutschrift wählen", 20, sql, "Keine Rechnungen oder Gutschriften gefunden.",
            sp("BELEGART", "Belegart", 5, "STRING", hidden=True) + sp("RECH_ID", "ID", 6, "NUMBER", hidden=True)
            + sp("BELEG", "Beleg", 10, "STRING") + sp("DATUM", "Datum", 20, "DATE", maske="DD.MM.YYYY")
            + sp("KUNDE", "Kunde", 30, "STRING")
            + sp("BRUTTO", "Brutto", 40, "NUMBER", maske="FML999G999G990D00", rechts=True)
            + sp("OFFEN", "Offen", 50, "NUMBER", maske="FML999G999G990D00", rechts=True)
            + sp("STATUS", "Status", 60, "STRING") + sp("KUNDE_PASST", "Kunde passt", 70, "STRING")
            + sp("BETRAG_PASST", "Betrag passt", 80, "STRING") + sp("AKTION", "Aktion", 90, "STRING", escape=False))
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("aufheben", "AUFHEBEN", "Zuordnung aufheben", 20, "buttons", "next",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            warnOnUnsavedChanges: doNotCheck
            requiresConfirmation: true
""", bedingung="""        serverSideCondition {
            type: itemIsNotNull
            item: P31_ZUGEORDNET
        }
        confirmation {
            message: Zuordnung wirklich aufheben? Eine vom Bankabgleich angelegte Zahlung wird gelöscht.
            style: danger
        }
""")
    s += button("debitor-neu", "DEBITOR_NEU", "Neuen Debitor aus der Buchung anlegen", 15, "buttons", "next",
                "@/text-with-icon", icon="fa-user-plus",
                options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
                verhalten="            warnOnUnsavedChanges: doNotCheck\n")
    s += """    dynamicAction zur-debitor-seite (
        name: Nach "Debitor anlegen" zur Debitorseite (im Hauptfenster)
        execution {
            sequence: 20
        }
        when {
            event: ready
        }
        clientSideCondition {
            type: itemIsNotNull
            item: P31_ZIEL
        }

        action weiter (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript-browser
                    apex.util.getTopApex().navigation.redirect($v("P31_ZIEL"));
                    ```
            }
            execution {
                sequence: 10
            }
        )

    )

    process debitor-neu (
        name: Zuordnung aufheben, Ziel Debitor anlegen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- bestehende Zuordnung aufheben; Seite 51 legt den Debitor aus der Buchung an (Request ANLEGEN)
                for u in (select BKUM_STATUS from FAKT_BANKUMSAETZE
                           where BKUM_ID = :P31_BKUM_ID and BKUM_MAND_ID = :MANDANT_ID) loop
                    if u.BKUM_STATUS <> 'OFFEN' then
                        FAKT_BANK.aufheben(:P31_BKUM_ID);
                    end if;
                    :P31_ZIEL := apex_page.get_url(p_page => 51, p_clear_cache => '51', p_items => 'P51_BKUM_ID',
                                                   p_values => :P31_BKUM_ID, p_request => 'ANLEGEN');
                end loop;
                ```
        }
        execution {
            sequence: 5
        }
        serverSideCondition {
            whenButtonPressed: @debitor-neu
        }
    )

    dynamicAction cancel-dialog (
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

    process kopf (
        name: Zuordnung vorhanden?
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                select max(case when BKUM_STATUS in ('ZUGEORDNET', 'DEBITOR', 'BEREITS_BEZAHLT') then 'Y' end)
                  into :P31_ZUGEORDNET
                  from FAKT_BANKUMSAETZE where BKUM_ID = :P31_BKUM_ID and BKUM_MAND_ID = :MANDANT_ID;
                ```
        }
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process zuordnen (
        name: Zuordnen bzw. aufheben
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                begin
                    if :REQUEST = 'ZUORDNEN' then
                        FAKT_BANK.zuordnen(:P31_BKUM_ID, :P31_BELEGART, :P31_BELEG_ID);
                    else
                        FAKT_BANK.aufheben(:P31_BKUM_ID);
                    end if;
                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\\\d+: '),
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
            type: requestIsContainedInValue
            value: ZUORDNEN,AUFHEBEN
        }
    )

    process close-dialog (
        name: Dialog schließen
        type: closeDialog
        execution {
            sequence: 20
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: ZUORDNEN,AUFHEBEN
        }
    )

)
"""
    return s


def seite_40():
    """Gutschriften (Menuepunkt): Liste mit Facettensuche wie die Rechnungsliste (Seite 10) – Suche, Status, Ueberfaellig,
    Jahr, Monat, Aussteller; nur Gutschriften des Mandanten der Sitzung. Neue Gutschrift: Seite 41."""
    s = (fdl.rechnungsliste()
         .replace("page 10 (\n    name: Rechnungen\n    alias: RECHNUNGEN\n    title: Rechnungen",
                  "page 40 (\n    name: Gutschriften\n    alias: GUTSCHRIFTEN\n    title: Gutschriften")
         .replace("        title: Rechnungen\n        type: breadcrumb", "        title: Gutschriften\n        type: breadcrumb")
         .replace("filteredRegion: @rechnungen", "filteredRegion: @gutschriften")
         .replace("P10_", "P40_"))
    # Facette Kunde -> Aussteller
    s = s.replace("""                label: Kunde
            }""", """                label: Aussteller
            }""", 1).replace("databaseColumn: KUNDE\n", "databaseColumn: AUSSTELLER\n", 1)
    # Bericht ersetzen
    a = s.index("    region rechnungen (")
    e = s.index("    button up (")
    bericht_neu = """    region gutschriften (
        name: Gutschriften
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select g.GUTS_ID,
                       coalesce(g.GUTS_INTERN_NUMMER, '(Entwurf)') as NUMMER,
                       g.GUTS_NUMMER as AUSSTELLER_NR,
                       g.GUTS_DATUM,
                       to_char(g.GUTS_DATUM, 'YYYY') as JAHR,
                       to_char(g.GUTS_DATUM, 'YYYY-MM') as MONAT,
                       FAKT_GUTSCHRIFT.status_text(g.GUTS_STATUS) as STATUS,
                       case when g.GUTS_STATUS = 'BEZAHLT' then 'fa-check-circle u-success-text'
                            when g.GUTS_STATUS = 'ENTWURF' then 'fa-pencil u-warning-text'
                            when g.GUTS_STATUS = 'GESENDET' then 'fa-paper-plane-o u-info-text'
                            when g.GUTS_FAELLIG_AM < trunc(sysdate) then 'fa-exclamation-triangle u-danger-text'
                            else 'fa-clock-o u-info-text' end as STATUS_ICON,
                       case when g.GUTS_STATUS = 'OFFEN' and g.GUTS_FAELLIG_AM < trunc(sysdate) then 'Ja' else 'Nein' end as UEBERFAELLIG,
                       k.KUND_NUMMER,
                       coalesce(k.KUND_FIRMENNAME, g.GUTS_AUSSTELLER) as AUSSTELLER,
                       g.GUTS_BETRAG,
                       g.GUTS_ZAHLBETRAG,
                       g.GUTS_FAELLIG_AM,
                       g.GUTS_BEZAHLT_AM,
                       g.GUTS_VERWENDUNGSZWECK
                  from FAKT_GUTSCHRIFTEN g
                  left join KUND_KUNDEN k on k.KUND_ID = g.GUTS_KUND_ID
                 where g.GUTS_MAND_ID = :MANDANT_ID   -- nur Gutschriften des im Portal gewaehlten Mandanten
                 order by g.GUTS_DATUM desc nulls first, to_number(regexp_substr(g.GUTS_INTERN_NUMMER, '[0-9]+$')) desc nulls first
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
            whenNoDataFound: Keine Gutschriften gefunden.
        }

        column GUTS_ID (
            type: hidden
            layout {
                sequence: 10
            }
        )

        column STATUS (
            type: plainText
            heading {
                heading: Status
                alignment: center
            }
            columnFormatting {
                htmlExpression: <span class="fa #STATUS_ICON#" title="#STATUS#" aria-label="#STATUS#" style="font-size:16px"></span>
            }
            layout {
                columnAlignment: center
                sequence: 15
            }
            sorting {
                sortable: false
            }
        )

        column NUMMER (
            type: link
            heading {
                heading: Gutschrift
            }
            layout {
                sequence: 20
            }
            link {
                target: {
                    page: 41
                    items: {
                        P41_GUTS_ID: #GUTS_ID#
                    }
                    clearCache: 41
                }
                linkText: <span class="thg-kundennr">#NUMMER#</span>
            }
            sorting {
                sortable: false
            }
        )

""" + "".join(f"""        column {c} (
            type: {"hidden" if h is None else "plainText"}
""" + ("" if h is None else f"""            heading {{
                heading: {h}
""" + ("                alignment: end\n" if rechts else "") + """            }
""") + (f"""            appearance {{
                formatMask: {m}
            }}
""" if m else "") + f"""            layout {{
                sequence: {seq}
""" + ("                columnAlignment: end\n" if rechts else "") + """            }
""" + ("" if h is None else """            sorting {
                sortable: false
            }
""") + """        )

""" for c, h, m, rechts, seq in (
            ("STATUS_ICON", None, None, False, 16), ("GUTS_DATUM", "Datum", "DD.MM.YYYY", False, 30),
            ("JAHR", None, None, False, 35), ("MONAT", None, None, False, 36), ("UEBERFAELLIG", None, None, False, 37),
            ("AUSSTELLER_NR", "Nr. beim Aussteller", None, False, 38),
            ("KUND_NUMMER", "Kundennr.", None, False, 40), ("AUSSTELLER", "Aussteller", None, False, 50),
            ("GUTS_BETRAG", "Betrag", "FML999G999G990D00", True, 60),
            ("GUTS_ZAHLBETRAG", "Zahlbetrag", "FML999G999G990D00", True, 70),
            ("GUTS_FAELLIG_AM", "Fällig am", "DD.MM.YYYY", False, 80),
            ("GUTS_BEZAHLT_AM", "Bezahlt am", "DD.MM.YYYY", False, 90),
            ("GUTS_VERWENDUNGSZWECK", "Verwendungszweck", None, False, 100))) + "    )\n\n"
    s = s[:a] + bericht_neu + s[e:]
    # Buttons: Zurueck zum Dashboard, Zuruecksetzen (Seite 40), Neue Gutschrift (Seite 41)
    s = (s.replace("                page: 10\n                clearCache: 10\n                action: resetPagination",
                   "                page: 40\n                clearCache: 40\n                action: resetPagination")
          .replace("    button neue-rechnung (\n        buttonName: CREATE\n        label: Neue Rechnung",
                   "    button neue-gutschrift (\n        buttonName: CREATE\n        label: Neue Gutschrift")
          .replace("                page: 11\n                clearCache: 11", "                page: 41\n                clearCache: 41"))
    assert "P10_" not in s and "@rechnungen" not in s and "page: 11" not in s, "Reste der Rechnungsliste"
    return s

def seite_41():
    """Gutschrift (Gutschriftverfahren, z.B. Hays) – Ablauf wie eine Rechnung:
    1. Anlegen (Kunde) -> 2. Stundenzettel hochladen (Registerkarte Dokumente; vergibt interne Nummer "GS 2026 - 1" und
    Gutschriftdatum) -> 3. "An Aussteller gesendet" -> 4. Gutschrift des Ausstellers hochladen (liest Nummer beim Aussteller,
    Datum, faellig am, Netto/Betrag, Skonto, Verwendungszweck aus) -> 5. Bankabgleich -> bezahlt.
    Alternativ bei einer neuen Gutschrift direkt das PDF des Ausstellers hochladen (legt an und nummeriert).
    Doppelte Gutschrift/Datei -> nur Hinweis. Registerkarten Gutschrift, Dokumente (PDF-Fenster Seite 43), Historie."""
    f = dict(form="gutschrift")
    TAB = "        advanced {\n            regionDisplaySelector: true\n        }\n"
    OHNE_KOPF = "[\n                #DEFAULT#\n                t-Region--removeHeader js-removeLandmark\n            ]"
    links = "[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]"
    s = KOPF(41, "Gutschrift", "GUTSCHRIFT") + BREADCRUMB("&P41_TITEL.")
    s += """    region gutschrift (
        name: Gutschrift
        type: form
        source {
            location: localDatabase
            tableName: FAKT_GUTSCHRIFTEN
        }
        layout {
            sequence: 20
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

    region rds (
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
        serverSideCondition {
            type: itemIsNotNull
            item: P41_GUTS_ID
        }
    )

"""
    # neue Gutschrift: direkt das PDF des Ausstellers hochladen (Alternative zum Anlegen mit Kunde)
    s += region("pdf", "Gutschrift des Ausstellers direkt hochladen", 10, extra="""        source {
            htmlCode:
                ```html
                <p>Üblicher Ablauf: Kunde wählen und <b>Anlegen</b>, dann unter <b>Dokumente</b> den Stundenzettel hochladen
                (vergibt Gutschriftnummer und -datum), an den Aussteller senden und dessen Gutschrift hochladen. Liegt die
                Gutschrift des Ausstellers schon vor, kann sie hier direkt hochgeladen werden – die Angaben werden ausgelesen.</p>
                ```
        }
        serverSideCondition {
            type: itemIsNull
            item: P41_GUTS_ID
        }
""")
    s += region("angaben", "Gutschrift", 10, parent="gutschrift", extra=TAB, options=OHNE_KOPF)
    s += """    pageItem P41_GUTS_ID (
        type: hidden
        layout {
            sequence: 1
            region: @angaben
            slot: regionBody
        }
        source {
            formRegion: @gutschrift
            column: GUTS_ID
            dataType: number
            primaryKey: true
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P41_GUTS_MAND_ID (
        type: hidden
        layout {
            sequence: 2
            region: @angaben
            slot: regionBody
        }
        source {
            formRegion: @gutschrift
            column: GUTS_MAND_ID
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

    pageItem P41_TITEL (
        type: hidden
        layout {
            sequence: 3
            region: @angaben
            slot: regionBody
        }
    )

    pageItem P41_HAT_PDF (
        type: hidden
        layout {
            sequence: 4
            region: @angaben
            slot: regionBody
        }
    )

    pageItem P41_DATEI (
        type: fileUpload
        label {
            label: Gutschrift des Ausstellers (PDF)
            alignment: left
        }
        display {
            displayAs: inlineDropzone
            dropzoneTitle: PDF der Gutschrift hierher ziehen
            dropzoneDesc: oder klicken zum Auswählen
        }
        advanced {
            warnOnUnsavedChanges: ignore
        }
        storage {
            type: appTempFiles
        }
        layout {
            sequence: 10
            region: @pdf
            slot: regionBody
            columnSpan: 12
            alignment: left
        }
        appearance {
            template: @/optional-floating
            templateOptions: #DEFAULT#
        }
    )

"""
    a = "angaben"
    # Zeile 1: interne Nummer, Gutschriftdatum, Status | Kunde
    s += hervorheben(item("P41_GUTS_INTERN_NUMMER", "displayOnly", "Gutschriftnummer", 10, a, col="GUTS_INTERN_NUMMER",
                          spalten=3, **f))
    s += hervorheben(item("P41_GUTS_DATUM", "displayOnly", "Gutschriftdatum", 20, a, col="GUTS_DATUM", dtype="date",
                          neue_zeile=False, spalten=3, **f))
    s += item("P41_GUTS_STATUS", "displayOnly", "Status", 30, a, col="GUTS_STATUS", neue_zeile=False, spalten=3,
              extra="""        settings {
            basedOn: lov
        }
        lov {
            type: sqlQuery
            sqlQuery:
                ```sql
                select FAKT_GUTSCHRIFT.status_text(column_value) d, column_value r
                  from table(sys.odcivarchar2list('ENTWURF', 'GESENDET', 'OFFEN', 'BEZAHLT'))
                ```
        }
        default {
            type: static
            staticValue: ENTWURF
        }
""", **f)
    s += item("P41_GUTS_BEZAHLT_AM", "datePicker", "Bezahlt am (Bankabgleich oder von Hand)", 40, a,
              col="GUTS_BEZAHLT_AM", dtype="date", neue_zeile=False, spalten=3, **f)
    s += item("P41_GUTS_KUND_ID", "selectList", "Kunde (Aussteller)", 50, a, col="GUTS_KUND_ID", dtype="number",
              req=True, spalten=6, extra=lov("lov-kunden", "- Kunde wählen -"), **f)
    s += item("P41_GUTS_AUSSTELLER", "textField", "Aussteller laut Gutschrift", 60, a, col="GUTS_AUSSTELLER",
              maxlen=200, neue_zeile=False, spalten=6, **f)
    # Angaben des Ausstellers (aus seinem PDF)
    s += item("P41_GUTS_NUMMER", "textField", "Nummer beim Aussteller", 70, a, col="GUTS_NUMMER", maxlen=50, spalten=3, **f)
    s += item("P41_GUTS_AUSSTELLER_DATUM", "datePicker", "Datum beim Aussteller", 80, a, col="GUTS_AUSSTELLER_DATUM",
              dtype="date", neue_zeile=False, spalten=3, **f)
    s += item("P41_GUTS_FAELLIG_AM", "datePicker", "Fällig am", 90, a, col="GUTS_FAELLIG_AM", dtype="date",
              neue_zeile=False, spalten=3, **f)
    s += maske(item("P41_GUTS_SKONTO_PROZENT", "numberField", "Skonto %", 100, a, col="GUTS_SKONTO_PROZENT",
                    dtype="number", neue_zeile=False, spalten=3, **f), "990D99")
    s += maske(item("P41_GUTS_NETTO", "numberField", "Netto €", 110, a, col="GUTS_NETTO", dtype="number", spalten=3, **f),
               "999G999G990D00")
    s += maske(item("P41_GUTS_BETRAG", "numberField", "Betrag (brutto) €", 120, a, col="GUTS_BETRAG", dtype="number",
                    neue_zeile=False, spalten=3, **f), "999G999G990D00")
    s += maske(item("P41_GUTS_ZAHLBETRAG", "displayOnly", "Zahlbetrag € (erwartete Zahlung)", 130, a,
                    col="GUTS_ZAHLBETRAG", dtype="number", neue_zeile=False, spalten=3, **f), "999G999G990D00")
    s += item("P41_GUTS_VERWENDUNGSZWECK", "textField", "Verwendungszweck (wie auf dem Kontoauszug)", 140, a,
              col="GUTS_VERWENDUNGSZWECK", maxlen=140, spalten=12, **f)
    s += item("P41_GUTS_BEMERKUNG", "textarea", "Bemerkung", 150, a, col="GUTS_BEMERKUNG", maxlen=1000, spalten=12, **f)

    # Registerkarte Dokumente: hochladen (Stundenzettel, Gutschrift des Ausstellers, sonstiges) und Liste
    s += region("dokumente", "Dokumente", 40, extra=TAB + NICHT_NULL("P41_GUTS_ID"), options=OHNE_KOPF)
    s += region("dok-hochladen", "Dokument hochladen", 10, parent="dokumente")
    s += """    pageItem P41_DOKUMENT (
        type: fileUpload
        label {
            label: Datei
            alignment: left
        }
        display {
            displayAs: inlineDropzone
            dropzoneTitle: Datei hierher ziehen
            dropzoneDesc: Stundenzettel, Gutschrift des Ausstellers (PDF) oder sonstiges Dokument
        }
        advanced {
            warnOnUnsavedChanges: ignore
        }
        storage {
            type: appTempFiles
        }
        layout {
            sequence: 10
            region: @dok-hochladen
            slot: regionBody
            columnSpan: 12
            alignment: left
        }
        appearance {
            template: @/optional-floating
            templateOptions: #DEFAULT#
        }
    )

"""
    ohne_val = "            executeValidations: false\n            warnOnUnsavedChanges: doNotCheck\n"
    s += button("stundenzettel", "STUNDENZETTEL", "Als Stundenzettel hochladen", 10, "dok-hochladen", "next",
                "@/text-with-icon", hot=True, icon="fa-clock-o", options=links, verhalten=ohne_val)
    s += button("aussteller", "AUSSTELLER", "Als Gutschrift des Ausstellers hochladen", 20, "dok-hochladen", "next",
                "@/text-with-icon", icon="fa-file-pdf-o", options=links, verhalten=ohne_val,
                bedingung=NULL("P41_HAT_PDF"))
    s += button("sonstiges", "SONSTIGES", "Als sonstiges Dokument", 30, "dok-hochladen", "next", "@/text-with-icon",
                icon="fa-paperclip", options=links, verhalten=ohne_val)
    s += bericht("dok-liste", "Abgelegte Dokumente", 20, """                select '<a href="' || apex_escape.html_attribute(apex_page.get_url(p_page => 43, p_clear_cache => '43',
                                                                                   p_items => 'P43_GUTS_ID,P43_GDOK_ID',
                                                                                   p_values => d.GUTS_ID || ',' || d.GDOK_ID))
                       || '" title="Anzeigen"><span class="fa fa-file-pdf-o" aria-hidden="true"></span></a>' as ANZEIGEN,
                       d.ART, d.DATEI,
                       to_char(round(d.GROESSE / 1024), 'FM999G999G990') || ' KB' as GROESSE,
                       to_char(from_tz(d.AM, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') as HOCHGELADEN,
                       d.VON
                  from (select g.GUTS_ID, null as GDOK_ID, 'Gutschrift des Ausstellers' as ART, g.GUTS_DATEINAME as DATEI,
                               dbms_lob.getlength(g.GUTS_DATEI) as GROESSE,
                               coalesce((select max(h.GHIS_ZEITPUNKT) from FAKT_GUTSCHRIFT_HISTORIE h
                                          where h.GHIS_GUTS_ID = g.GUTS_ID and h.GHIS_AKTION = 'Hochgeladen'), g.GUTS_CREATED_ON) as AM,
                               g.GUTS_CREATED_BY as VON
                          from FAKT_GUTSCHRIFTEN g
                         where g.GUTS_ID = :P41_GUTS_ID and g.GUTS_DATEI is not null
                        union all
                        select k.GDOK_GUTS_ID, k.GDOK_ID, case k.GDOK_ART when 'STUNDENZETTEL' then 'Stundenzettel' else 'Sonstiges' end,
                               k.GDOK_DATEINAME, k.GDOK_GROESSE, k.GDOK_CREATED_ON, k.GDOK_CREATED_BY
                          from FAKT_GUTSCHRIFT_DOKUMENTE k
                         where k.GDOK_GUTS_ID = :P41_GUTS_ID) d
                 order by d.AM""",
                 [("ANZEIGEN", "Anzeigen", True, False), ("ART", "Art", False, False), ("DATEI", "Datei", False, False),
                  ("GROESSE", "Größe", False, True), ("HOCHGELADEN", "Hochgeladen am", False, False), ("VON", "Von", False, False)],
                 "Noch keine Dokumente – bitte den Stundenzettel hochladen.").replace(
        "            sequence: 20\n            slot: body\n", "            sequence: 20\n            parentRegion: @dokumente\n            slot: subRegions\n", 1)
    # Registerkarte Historie (Timeline)
    s += bericht("historie", "Historie", 50, """                select nvl(m.MITA_NAME, h.GHIS_BENUTZER) as USER_NAME,
                       coalesce(m.MITA_KUERZEL, upper(substr(nvl(m.MITA_NAME, h.GHIS_BENUTZER), 1, 2))) as USER_AVATAR,
                       'u-color-1' as USER_COLOR,
                       to_char(from_tz(h.GHIS_ZEITPUNKT, 'UTC') at time zone 'Europe/Vienna', 'DD.MM.YYYY HH24:MI') as EVENT_DATE,
                       case when h.GHIS_AKTION in ('Hochgeladen', 'PDF ersetzt', 'Stundenzettel hochgeladen', 'Dokument hochgeladen',
                                                   'Dokument gelöscht') then 'Dokument'
                            when h.GHIS_AKTION in ('Bezahlt', 'Zahlung zurückgenommen') then 'Zahlung'
                            when h.GHIS_AKTION in ('An Aussteller gesendet', 'Gutschrift erhalten') then 'Versand'
                            else 'Gutschrift' end as EVENT_TYPE,
                       'fa ' || case when h.GHIS_AKTION in ('Hochgeladen', 'PDF ersetzt', 'Dokument hochgeladen') then 'fa-upload'
                                     when h.GHIS_AKTION = 'Stundenzettel hochgeladen' then 'fa-clock-o'
                                     when h.GHIS_AKTION = 'Dokument gelöscht' then 'fa-trash-o'
                                     when h.GHIS_AKTION = 'Nummer vergeben' then 'fa-hashtag'
                                     when h.GHIS_AKTION = 'An Aussteller gesendet' then 'fa-paper-plane-o'
                                     when h.GHIS_AKTION = 'Gutschrift erhalten' then 'fa-inbox'
                                     when h.GHIS_AKTION = 'Bezahlt' then 'fa-eur'
                                     when h.GHIS_AKTION = 'Zahlung zurückgenommen' then 'fa-undo'
                                     when h.GHIS_AKTION = 'Angelegt' then 'fa-plus-circle'
                                     else 'fa-pencil' end as EVENT_ICON,
                       case when h.GHIS_AKTION = 'Bezahlt' then 'u-success'
                            when h.GHIS_AKTION in ('Zahlung zurückgenommen', 'Dokument gelöscht') then 'u-warning'
                            when h.GHIS_AKTION in ('Geändert') then 'u-color-14'
                            else 'u-info' end as EVENT_STATUS,
                       h.GHIS_AKTION as EVENT_TITLE,
                       h.GHIS_DETAIL as EVENT_DESC,
                       null as EVENT_MODIFIERS,
                       null as EVENT_ATTRIBUTES,
                       null as EVENT_LINK
                  from FAKT_GUTSCHRIFT_HISTORIE h
                  left join ALLG_MITARBEITER m on m.MITA_BENUTZERNAME = h.GHIS_BENUTZER
                 where h.GHIS_GUTS_ID = :P41_GUTS_ID
                 order by h.GHIS_ZEITPUNKT desc, h.GHIS_ID desc""",
                 [(c, c, False, False) for c in ("USER_NAME", "USER_AVATAR", "USER_COLOR", "EVENT_DATE", "EVENT_TYPE",
                                                 "EVENT_ICON", "EVENT_STATUS", "EVENT_TITLE", "EVENT_DESC",
                                                 "EVENT_MODIFIERS", "EVENT_ATTRIBUTES", "EVENT_LINK")],
                 "Noch keine Einträge.").replace(
        "            templateOptions: #DEFAULT#\n        }\n        componentAppearance {\n            template: @/standard\n"
        "            templateOptions: [\n                #DEFAULT#\n                t-Report--stretch\n"
        "                t-Report--staticRowColors\n                t-Report--rowHighlight\n                t-Report--horizontalBorders\n"
        "            ]\n",
        "            templateOptions: " + OHNE_KOPF + "\n        }\n" + TAB + "        serverSideCondition {\n            type: itemIsNotNull\n"
        "            item: P41_GUTS_ID\n        }\n        componentAppearance {\n            template: @/timeline\n"
        "            templateOptions: #DEFAULT#\n", 1)

    # Kopf-Buttons
    s += button("up", "UP", "Zurück zu den Gutschriften", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options="[\n                #DEFAULT#\n                t-Button--noUI\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 40
            }
            warnOnUnsavedChanges: doNotCheck
""")
    s += button("auslesen", "AUSLESEN", "PDF hochladen und auslesen", 10, "pdf", "next", "@/text-with-icon", hot=True,
                icon="fa-upload", options=links, verhalten=ohne_val, bedingung=NULL("P41_GUTS_ID"))
    s += button("delete", "DELETE", "Löschen", 10, "breadcrumb", "next",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            requiresConfirmation: true
""", bedingung=NICHT_NULL("P41_GUTS_ID") + """        confirmation {
            message: Gutschrift wirklich löschen? Nur ein Entwurf ohne Nummer oder die zuletzt vergebene Gutschrift kann gelöscht werden.
            style: danger
        }
""")
    s += button("gesendet", "GESENDET", "An Aussteller gesendet", 15, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-paper-plane-o", options=links, verhalten="""            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
""", bedingung="""        serverSideCondition {
            type: expression
            language: plsql
            plsqlExpression: :P41_GUTS_STATUS = 'ENTWURF' and :P41_GUTS_INTERN_NUMMER is not null
        }
""")
    s += button("save", "SAVE", "Speichern", 20, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P41_GUTS_ID"))
    s += button("create", "CREATE", "Anlegen", 30, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P41_GUTS_ID"))

    fehler = """                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\d+: '),
                                                 p_display_location => apex_error.c_inline_in_notification);
                        else
                            raise;
                        end if;
                end;"""
    def datei_prozess(sid, name, seq, knopf, item, aufruf, meldung):
        return f"""    process {sid} (
        name: {name}
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                declare
                    l_blob blob;
                    l_name varchar2(400);
                    l_mime varchar2(255);
                begin
                    if :{item} is null then
                        raise_application_error(-20274, 'Bitte eine Datei auswählen.');
                    end if;
                    select blob_content, filename, mime_type into l_blob, l_name, l_mime
                      from apex_application_temp_files where name = :{item};
                    {aufruf}
{fehler}
                ```
        }}
        execution {{
            sequence: {seq}
        }}
        serverSideCondition {{
            whenButtonPressed: @{knopf}
        }}
        successMessage {{
            successMessage: {meldung}
        }}
    )

"""
    s += """    process initialize-form-gutschrift (
        name: Formular Gutschrift initialisieren
        type: formInitialization
        formRegion: @gutschrift
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process kopf (
        name: Mandant prüfen, Titel
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                if :P41_GUTS_ID is not null and :P41_GUTS_MAND_ID <> :MANDANT_ID then
                    raise_application_error(-20240, 'Diese Gutschrift gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                end if;
                :P41_TITEL := case when :P41_GUTS_ID is null then 'Neue Gutschrift'
                                   when :P41_GUTS_INTERN_NUMMER is null then 'Gutschrift (Entwurf)'
                                   else 'Gutschrift ' || :P41_GUTS_INTERN_NUMMER end;
                :P41_HAT_PDF := null;
                for g in (select 'Y' as J from FAKT_GUTSCHRIFTEN where GUTS_ID = :P41_GUTS_ID and GUTS_DATEI is not null) loop
                    :P41_HAT_PDF := g.J;
                end loop;
                ```
        }
        execution {
            sequence: 20
            point: beforeHeader
        }
    )

"""
    s += datei_prozess("pdf-auslesen", "Neue Gutschrift aus dem PDF des Ausstellers", 5, "auslesen", "P41_DATEI",
                       ":P41_GUTS_ID := FAKT_GUTSCHRIFT.aus_pdf(:MANDANT_ID, l_name, l_mime, l_blob);",
                       "PDF ausgelesen – bitte die Angaben prüfen und speichern.")
    s += datei_prozess("aussteller-hochladen", "Gutschrift des Ausstellers hochladen", 6, "aussteller", "P41_DOKUMENT",
                       ":P41_GUTS_ID := FAKT_GUTSCHRIFT.aus_pdf(:MANDANT_ID, l_name, l_mime, l_blob, :P41_GUTS_ID);",
                       "Gutschrift des Ausstellers übernommen – bitte die Angaben prüfen.")
    s += datei_prozess("stundenzettel-hochladen", "Stundenzettel hochladen", 7, "stundenzettel", "P41_DOKUMENT",
                       "FAKT_GUTSCHRIFT.dokument_ablegen(:P41_GUTS_ID, 'STUNDENZETTEL', l_name, l_mime, l_blob);",
                       "Stundenzettel abgelegt.")
    s += datei_prozess("sonstiges-hochladen", "Sonstiges Dokument hochladen", 8, "sonstiges", "P41_DOKUMENT",
                       "FAKT_GUTSCHRIFT.dokument_ablegen(:P41_GUTS_ID, 'SONSTIGES', l_name, l_mime, l_blob);",
                       "Dokument abgelegt.")
    s += f"""    process process-form-gutschrift (
        name: Formular Gutschrift verarbeiten
        type: formAutoRowProcessing
        formRegion: @gutschrift
        execution {{
            sequence: 10
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE,GESENDET
        }}
        successMessage {{
            successMessage: Gutschrift gespeichert.
        }}
    )

    process gesendet (
        name: An Aussteller gesendet
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                begin
                    FAKT_GUTSCHRIFT.gesendet(:P41_GUTS_ID);
{fehler}
                ```
        }}
        execution {{
            sequence: 15
        }}
        serverSideCondition {{
            whenButtonPressed: @gesendet
        }}
        successMessage {{
            successMessage: Als an den Aussteller gesendet markiert.
        }}
    )

    process gutschrift-loeschen (
        name: Gutschrift löschen
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                begin
                    FAKT_GUTSCHRIFT.loeschen(:P41_GUTS_ID);
{fehler}
                ```
        }}
        execution {{
            sequence: 12
        }}
        serverSideCondition {{
            whenButtonPressed: @delete
        }}
        successMessage {{
            successMessage: Gutschrift gelöscht.
        }}
    )

    process bank-abgleichen (
        name: Bankabgleich (offene Eingänge)
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                -- offener Bankeingang mit gleicher Nummer/gleichem Verwendungszweck -> Gutschrift bezahlt
                if FAKT_BANK.abgleichen(:MANDANT_ID) > 0 then
                    apex_application.g_print_success_message := 'Gespeichert. Bankabgleich: Zahlungseingang zugeordnet.';
                end if;
                ```
        }}
        execution {{
            sequence: 20
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE,AUSLESEN,AUSSTELLER
        }}
    )

    branch nach-speichern (
        name: Gutschrift wieder öffnen
        execution {{
            sequence: 10
        }}
        behavior {{
            target: {{
                page: 41
                items: {{
                    P41_GUTS_ID: &P41_GUTS_ID.
                }}
            }}
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: AUSLESEN,AUSSTELLER,STUNDENZETTEL,SONSTIGES,CREATE,SAVE,GESENDET
        }}
    )

    branch nach-loeschen (
        name: Zur Liste
        execution {{
            sequence: 20
        }}
        behavior {{
            target: {{
                page: 40
            }}
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: DELETE
        }}
    )

)
"""
    return s


def seite_42():
    """Dokument einer Gutschrift ausliefern (inline): P42_GDOK_ID gesetzt -> Dokument (Stundenzettel u.a.), sonst die
    Gutschrift des Ausstellers – nur Gutschriften des Mandanten der Sitzung."""
    return """page 42 (
    name: Gutschrift PDF
    alias: GUTSCHRIFT-PDF
    title: Gutschrift
    appearance {
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region gutschrift-pdf (
        name: Gutschrift PDF
        type: staticContent
        layout {
            sequence: 10
            slot: body
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
    )

    pageItem P42_GUTS_ID (
        type: hidden
        layout {
            sequence: 10
            region: @gutschrift-pdf
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P42_GDOK_ID (
        type: hidden
        layout {
            sequence: 20
            region: @gutschrift-pdf
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    process pdf-ausliefern (
        name: Dokument ausliefern
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                for d in (select k.GDOK_DATEI as DATEI, k.GDOK_DATEINAME as NAME, k.GDOK_MIME_TYPE as MIME
                            from FAKT_GUTSCHRIFT_DOKUMENTE k
                            join FAKT_GUTSCHRIFTEN g on g.GUTS_ID = k.GDOK_GUTS_ID
                           where :P42_GDOK_ID is not null and k.GDOK_ID = :P42_GDOK_ID
                             and g.GUTS_ID = :P42_GUTS_ID and g.GUTS_MAND_ID = :MANDANT_ID
                          union all
                          select GUTS_DATEI, GUTS_DATEINAME, GUTS_MIME_TYPE from FAKT_GUTSCHRIFTEN
                           where :P42_GDOK_ID is null and GUTS_ID = :P42_GUTS_ID and GUTS_MAND_ID = :MANDANT_ID
                             and GUTS_DATEI is not null) loop
                    apex_http.download(p_blob         => d.DATEI,
                                       p_content_type => nvl(d.MIME, 'application/pdf'),
                                       p_filename     => d.NAME,
                                       p_is_inline    => true);
                end loop;
                ```
        }
        execution {
            sequence: 10
            point: beforeHeader
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P42_GUTS_ID
        }
    )
)
"""

def seite_43():
    """PDF-Fenster der Gutschrift (wie Seite 13 der Rechnung): Original-PDF (Seite 42) mit Drucken/Herunterladen/Schliessen."""
    t = (FIN / "pages" / "p00013-rechnung-anzeigen.apx").read_text(encoding="utf-8")
    ersetzen = [
        ("page 13 (\n    name: Rechnung anzeigen\n    alias: RECHNUNG-ANZEIGEN\n    title: Rechnung",
         "page 43 (\n    name: Gutschrift anzeigen\n    alias: GUTSCHRIFT-ANZEIGEN\n    title: Gutschrift"),
        ("apex_page.get_url(p_page      => 12,\n                                             p_items     => 'P12_RECH_ID,P12_RDOK_ID',\n"
         "                                             p_values    => :P13_RECH_ID || ',' || :P13_RDOK_ID,",
         "apex_page.get_url(p_page      => 42,\n                                             p_items     => 'P42_GUTS_ID,P42_GDOK_ID',\n"
         "                                             p_values    => :P43_GUTS_ID || ',' || :P43_GDOK_ID,"),
        ("apex_escape.html_attribute(FAKT_RECHNUNG_DOKUMENT.dateiname(:P13_RECH_ID, :P13_RDOK_ID))",
         "apex_escape.html_attribute(FAKT_GUTSCHRIFT.dateiname(:P43_GUTS_ID, :P43_GDOK_ID))"),
        ("title=\"Rechnung\"", "title=\"Gutschrift\""),
        ("Rechnung konnte nicht", "Gutschrift konnte nicht"),
    ]
    for x, y in ersetzen:
        assert x in t, x[:60]
        t = t.replace(x, y)
    # Seitenelemente: nur P43_GUTS_ID
    i = t.index("    pageItem P13_RECH_ID (")
    j = t.index("    dynamicAction ", i)
    t = t[:i] + "".join(f"""    pageItem {n} (
        type: hidden
        layout {{
            sequence: {q}
            region: @vorschau
            slot: regionBody
        }}
        security {{
            sessionStateProtection: checksumRequiredSessionLevel
        }}
    )

""" for n, q in (("P43_GUTS_ID", 10), ("P43_GDOK_ID", 20))) + t[j:]
    assert "P13_" not in t and "P12_" not in t, "Reste der Rechnungsanzeige"
    return t

def seite_42():
    """PDF einer Gutschrift ausliefern (inline, neuer Tab) – nur Gutschriften des Mandanten der Sitzung."""
    return """page 42 (
    name: Gutschrift PDF
    alias: GUTSCHRIFT-PDF
    title: Gutschrift
    appearance {
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region gutschrift-pdf (
        name: Gutschrift PDF
        type: staticContent
        layout {
            sequence: 10
            slot: body
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
    )

    pageItem P42_GUTS_ID (
        type: hidden
        layout {
            sequence: 10
            region: @gutschrift-pdf
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    process pdf-ausliefern (
        name: PDF ausliefern
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                for g in (select GUTS_DATEI, GUTS_DATEINAME, GUTS_MIME_TYPE from FAKT_GUTSCHRIFTEN
                           where GUTS_ID = :P42_GUTS_ID and GUTS_MAND_ID = :MANDANT_ID and GUTS_DATEI is not null) loop
                    apex_http.download(p_blob         => g.GUTS_DATEI,
                                       p_content_type => nvl(g.GUTS_MIME_TYPE, 'application/pdf'),
                                       p_filename     => g.GUTS_DATEINAME,
                                       p_is_inline    => true);
                end loop;
                ```
        }
        execution {
            sequence: 10
            point: beforeHeader
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P42_GUTS_ID
        }
    )
)
"""

def seite_16():
    """Dialog "Zahlungseingang" (Button im Tab Zahlungen von Seite 11; Klick auf eine Zahlung der Timeline zum Aendern):
    Datum (Vorschlag heute), eingegangener Betrag (Vorschlag: offener Betrag), Zahlungsreferenz (fuer die spaetere
    automatische Zuordnung), Bemerkung. Status der Rechnung setzt der Trigger ZAHL_STATUS_AIUD, die Historie ZAHL_HIST_AIUD."""
    f = dict(form="zahlung")
    s = """page 16 (
    name: Zahlungseingang
    alias: ZAHLUNGSEINGANG
    title: Zahlungseingang
    appearance {
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }
    dialog {
        width: 600
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

    region zahlung (
        name: Zahlung
        type: form
        source {
            location: localDatabase
            tableName: FAKT_ZAHLUNGEN
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
                delete
            ]
        }
    )

    pageItem P16_ZAHL_ID (
        type: hidden
        layout {
            sequence: 1
            region: @zahlung
            slot: regionBody
        }
        source {
            formRegion: @zahlung
            column: ZAHL_ID
            dataType: number
            primaryKey: true
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P16_RECH_ID (
        type: hidden
        layout {
            sequence: 2
            region: @zahlung
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P16_ZAHL_RECH_ID (
        type: hidden
        layout {
            sequence: 3
            region: @zahlung
            slot: regionBody
        }
        source {
            formRegion: @zahlung
            column: ZAHL_RECH_ID
            dataType: number
        }
        default {
            type: item
            item: P16_RECH_ID
        }
    )

"""
    s += item("P16_ZAHL_DATUM", "datePicker", "Datum", 10, "zahlung", col="ZAHL_DATUM", dtype="date", req=True, spalten=6,
              extra=default_sql("select trunc(cast(systimestamp at time zone 'Europe/Vienna' as date)) from dual"), **f)
    s += maske(item("P16_ZAHL_BETRAG", "numberField", "Eingegangener Betrag", 20, "zahlung", col="ZAHL_BETRAG",
                    dtype="number", req=True, neue_zeile=False, spalten=6,
                    extra=default_sql("select greatest(r.RECH_SUMME_BRUTTO - nvl((select sum(ZAHL_BETRAG) "
                                      "from FAKT_ZAHLUNGEN where ZAHL_RECH_ID = r.RECH_ID), 0), 0) "
                                      "from FAKT_RECHNUNGEN r where RECH_ID = :P16_RECH_ID"), **f), "999G999G990D00")
    s += item("P16_ZAHL_REFERENZ", "textField", "Zahlungsreferenz", 50, "zahlung", col="ZAHL_REFERENZ", maxlen=140,
              spalten=12, extra=default_sql("select FAKT_RECHNUNG.referenz_anzeige(RECH_ZAHLUNGSREFERENZ) "
                                            "from FAKT_RECHNUNGEN where RECH_ID = :P16_RECH_ID"), **f)
    s += item("P16_ZAHL_BEMERKUNG", "textField", "Bemerkung", 60, "zahlung", col="ZAHL_BEMERKUNG", maxlen=500,
              spalten=12, **f)
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("delete", "DELETE", "Löschen", 20, "buttons", "delete",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
""", bedingung=NICHT_NULL("P16_ZAHL_ID") + """        confirmation {
            message: Zahlung wirklich löschen?
            style: danger
        }
""")
    s += button("save", "SAVE", "Speichern", 30, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P16_ZAHL_ID"))
    s += button("create", "CREATE", "Zahlung erfassen", 40, "buttons", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P16_ZAHL_ID"))
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

    process initialize-form-zahlung (
        name: Formular Zahlung initialisieren
        type: formInitialization
        formRegion: @zahlung
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process rechnung-pruefen (
        name: Rechnung gehört zum Mandanten und nimmt Zahlungen an
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                declare
                    l_anz pls_integer;
                begin
                    select count(*) into l_anz
                      from FAKT_RECHNUNGEN
                     where RECH_ID = :P16_RECH_ID
                       and RECH_MAND_ID = :MANDANT_ID
                       and RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT')
                       and (:P16_ZAHL_ID is null
                            or exists (select 1 from FAKT_ZAHLUNGEN where ZAHL_ID = :P16_ZAHL_ID and ZAHL_RECH_ID = :P16_RECH_ID));
                    if l_anz = 0 then
                        raise_application_error(-20250, 'Zahlungen können nur zu abgeschlossenen Rechnungen des gewählten Mandanten erfasst werden.');
                    end if;
                end;
                ```
        }
        execution {
            sequence: 15
            point: beforeHeader
        }
    )

    process process-form-zahlung (
        name: Formular Zahlung verarbeiten
        type: formAutoRowProcessing
        formRegion: @zahlung
        execution {
            sequence: 10
        }
    )

    process close-dialog (
        name: Dialog schließen
        type: closeDialog
        execution {
            sequence: 20
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: CREATE,SAVE,DELETE
        }
    )

)
"""
    return s

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

def seite_17():
    """Dialog "Rechnung versenden" (Button im Kopf von Seite 11, abgeschlossene Rechnung): Vorschau der E-Mail aus der
    Vorlage des Mandanten (FAKT_MAIL_VORLAGEN, DDL 48) – Von (angemeldeter Mitarbeiter), An/Cc/Betreff/Text aenderbar,
    Bcc aus der Vorlage – und rechts der Anhang (zuletzt abgelegter Druck, per Blob geladen wie Seite 13).
    "E-Mail senden": FAKT_RECHNUNG_VERSAND.senden (Microsoft Graph, Status GESENDET, Historie); danach laedt Seite 11
    neu (DA versand-nach-dialog)."""
    ohne = dict(form=None)
    s = """page 17 (
    name: Rechnung versenden
    alias: VERSENDEN
    title: Rechnung versenden
    appearance {
        pageMode: modalDialog
        dialogTemplate: @/modal-dialog
        templateOptions: #DEFAULT#
    }
    dialog {
        width: 1300
        height: 860
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
            sequence: 30
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

    region mail (
        name: E-Mail
        type: staticContent
        layout {
            sequence: 10
            slot: contentBody
            columnSpan: 6
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
    )

    region anhang (
        name: Anhang
        type: dynamicContent
        source {
            plsqlFunctionBody:
                ```plsql
                -- Anhang = abgelegter Druck (Seite 12 mit P12_RDOK_ID, inline); per JavaScript als Blob geladen
                -- (DA "Anhang laden"), da die App das Einbetten eigener Seiten in Frames verbietet
                return '<div class="thg-anhang-titel"><span class="fa fa-paperclip" aria-hidden="true"></span> '
                    || apex_escape.html(FAKT_RECHNUNG_DOKUMENT.dateiname(:P17_RECH_ID, :P17_RDOK_ID)) || '</div>'
                    || '<iframe id="anhang-pdf" title="Anhang" style="width:100%;height:calc(100vh - 150px);border:0;display:block" data-src="'
                    || apex_escape.html_attribute(
                           apex_page.get_url(p_page      => 12,
                                             p_items     => 'P12_RECH_ID,P12_RDOK_ID',
                                             p_values    => :P17_RECH_ID || ',' || :P17_RDOK_ID,
                                             p_plain_url => true))
                    || '"></iframe>';
                ```
        }
        layout {
            sequence: 20
            slot: contentBody
            startNewRow: false
            columnSpan: 6
        }
        appearance {
            template: @/blank-with-attributes-no-grid
            templateOptions: #DEFAULT#
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P17_RDOK_ID
        }
    )

    pageItem P17_RECH_ID (
        type: hidden
        layout {
            sequence: 1
            region: @mail
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

    pageItem P17_RDOK_ID (
        type: hidden
        layout {
            sequence: 2
            region: @mail
            slot: regionBody
        }
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

"""
    s += item("P17_VON", "displayOnly", "Von", 10, "mail", spalten=12, **ohne)
    s += item("P17_AN", "textField", "An", 20, "mail", req=True, maxlen=1000, spalten=12, extra="""        help {
            helpText: Mehrere Empfänger mit ; trennen.
        }
""", **ohne)
    s += item("P17_CC", "textField", "Cc", 30, "mail", maxlen=1000, spalten=12, **ohne)
    s += item("P17_BCC", "displayOnly", "Bcc (immer)", 40, "mail", spalten=12, **ohne)
    s += item("P17_BETREFF", "textField", "Betreff", 50, "mail", req=True, maxlen=500, spalten=12, **ohne)
    s += item("P17_TEXT", "richTextEditor", "Text", 60, "mail", spalten=12,
              extra="        settings {\n            format: html\n            toolbar: full\n        }\n" + RTE_LEISTE(), **ohne)
    s += button("cancel", "CANCEL", "Abbrechen", 10, "buttons", "close", verhalten="            action: definedByDynamicAction\n")
    s += button("senden", "SENDEN", "E-Mail senden", 20, "buttons", "next", "@/text-with-icon", hot=True, icon="fa-paper-plane-o",
                options="[\n                #DEFAULT#\n                t-Button--iconLeft\n            ]",
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

    dynamicAction anhang-laden (
        name: Anhang laden
        execution {
            sequence: 20
        }
        when {
            event: ready
        }

        action native-js-anhang-laden (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript-browser
                    // PDF holen und als Blob-URL anzeigen (Frame-Sperre der App greift fuer blob: nicht)
                    var f = document.getElementById('anhang-pdf');
                    if (f) {
                        fetch(f.dataset.src, { credentials: 'same-origin', cache: 'no-store' })
                            .then(function (r) {
                                if (!r.ok) { throw new Error('HTTP ' + r.status); }
                                return r.blob();
                            })
                            .then(function (b) {
                                f.src = URL.createObjectURL(new Blob([b], { type: 'application/pdf' })) + '#toolbar=0&navpanes=0&view=FitH';
                            })
                            .catch(function (e) {
                                apex.message.showErrors([{ type: 'error', location: 'page',
                                    message: 'Anhang konnte nicht geladen werden (' + e.message + ').' }]);
                            });
                    }
                    ```
            }
            execution {
                sequence: 10
            }
        )

    )

    process vorbelegen (
        name: E-Mail aus der Vorlage vorbelegen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                -- nur beim Oeffnen (nach einem Fehler beim Senden bleiben die Eingaben erhalten)
                declare
                    l_text clob;
                begin
                    FAKT_RECHNUNG_VERSAND.vorbelegen(:P17_RECH_ID, :P17_VON, :P17_AN, :P17_BCC, :P17_BETREFF, l_text,
                                                     :P17_RDOK_ID);
                    :P17_TEXT := l_text;
                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\d+: '),
                                                 p_display_location => apex_error.c_on_error_page);
                        else
                            raise;
                        end if;
                end;
                ```
        }
        execution {
            sequence: 10
            point: beforeHeader
        }
        serverSideCondition {
            type: itemIsNull
            item: P17_VON
        }
    )

    process senden (
        name: E-Mail senden
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                begin
                    FAKT_RECHNUNG_VERSAND.senden(:P17_RECH_ID, :P17_AN, :P17_CC, :P17_BETREFF, :P17_TEXT, :P17_RDOK_ID);
""" + FEHLER.replace("\\\\", "\\") + """
                ```
        }
        execution {
            sequence: 10
        }
        serverSideCondition {
            whenButtonPressed: @senden
        }
    )

    process close-dialog (
        name: Dialog schließen
        type: closeDialog
        execution {
            sequence: 20
        }
        serverSideCondition {
            whenButtonPressed: @senden
        }
    )

)
"""
    return s


FEHLER = """                exception
                    when others then
                        if sqlcode between -20299 and -20200 then
                            apex_error.add_error(p_message          => regexp_replace(sqlerrm, '^ORA-\\\\d+: '),
                                                 p_display_location => apex_error.c_inline_in_notification);
                        else
                            raise;
                        end if;
                end;"""


def facette(name, label, spalte, seq, extra=""):
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


def seite_50():
    """Debitoren (Menuepunkt): Zahler ohne Rechnung/Gutschrift (z. B. Mieter) des Mandanten der Sitzung – Liste mit
    Facettensuche (Aktiv, Intervall, Rueckstand). Fehlende Posten werden beim Oeffnen erzeugt (FAKT_DEBITOR)."""
    s = KOPF(50, "Debitoren", "DEBITOREN").replace("pageTemplate: @/standard", "pageTemplate: @/left-side-column")
    s += BREADCRUMB("Debitoren")
    s += """    region facets (
        name: Facetten
        type: facetedSearch
        source {
            filteredRegion: @debitoren
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

        facet P50_SEARCH (
            type: search
            label {
                label: Suche
            }
            layout {
                sequence: 10
            }
        )

""" + facette("P50_AKTIV", "Aktiv", "AKTIV", 20) + facette("P50_INTERVALL", "Intervall", "INTERVALL", 30) \
        + facette("P50_RUECKSTAND", "Mit Rückstand", "MIT_RUECKSTAND", 40) + "    )\n\n"
    s += bericht("debitoren", "Debitoren", 30, """                -- Debitoren des im Portal gewaehlten Mandanten; Rueckstand = ueberfaellige offene Posten
                select '<a class="thg-kundennr" href="' || apex_escape.html_attribute(apex_page.get_url(p_page => 51, p_clear_cache => '51',
                                                                                                      p_items => 'P51_DEBI_ID',
                                                                                                      p_values => d.DEBI_ID))
                       || '">' || apex_escape.html(d.DEBI_NAME) || '</a>' as NAME_LINK,
                       d.DEBI_NAME,
                       d.DEBI_BEZEICHNUNG as BEZEICHNUNG,
                       FAKT_HISTORIE.betrag(d.DEBI_BETRAG) as BETRAG,
                       FAKT_DEBITOR.intervall_text(d.DEBI_INTERVALL) as INTERVALL,
                       to_char(d.NAECHSTE_FAELLIGKEIT, 'DD.MM.YYYY') as NAECHSTE,
                       case when d.RUECKSTAND > 0 then '<span class="u-danger-text">' || FAKT_HISTORIE.betrag(d.RUECKSTAND) || '</span>'
                            else '<span class="u-success-text">–</span>' end as RUECKSTAND,
                       to_char(d.LETZTE_ZAHLUNG, 'DD.MM.YYYY') as LETZTE_ZAHLUNG,
                       FAKT_RECHNUNG.referenz_anzeige(d.DEBI_IBAN) as IBAN,
                       case d.DEBI_IST_AKTIV when 'Y' then 'Ja' else 'Nein' end as AKTIV,
                       case when d.RUECKSTAND > 0 then 'Ja' else 'Nein' end as MIT_RUECKSTAND
                  from FAKT_DEBITOREN_V d
                 where d.DEBI_MAND_ID = :MANDANT_ID
                 order by upper(d.DEBI_NAME)""",
                 [("NAME_LINK", "Debitor", True, False), ("DEBI_NAME", None, False, False),
                  ("BEZEICHNUNG", "Bezeichnung", False, False), ("BETRAG", "Betrag", False, True),
                  ("INTERVALL", "Intervall", False, False), ("NAECHSTE", "Nächste Fälligkeit", False, False),
                  ("RUECKSTAND", "Rückstand", True, True), ("LETZTE_ZAHLUNG", "Letzte Zahlung", False, False),
                  ("IBAN", "IBAN des Zahlers", False, False), ("AKTIV", None, False, False),
                  ("MIT_RUECKSTAND", None, False, False)],
                 "Keine Debitoren gefunden.").replace(
        "            templateOptions: #DEFAULT#\n        }\n        componentAppearance",
        "            templateOptions: [\n                #DEFAULT#\n                t-Region--noPadding\n                t-Region--scrollBody\n"
        "            ]\n        }\n        componentAppearance", 1)
    s += button("reset", "RESET", "Zurücksetzen", 10, "breadcrumb", "next", "@/text-with-icon",
                icon="fa-undo-alt", options="[\n                t-Button--noUI\n                t-Button--iconLeft\n                t-Button--gapRight\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 50
                clearCache: 50
                action: resetPagination
            }
            warnOnUnsavedChanges: doNotCheck
""")
    s += button("neu", "CREATE", "Neuer Debitor", 20, "breadcrumb", "next", "@/text-with-icon", hot=True,
                icon="fa-plus", options="[\n                #DEFAULT#\n                t-Button--iconRight\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 51
                clearCache: 51
            }
""")
    s += """    process posten-erzeugen (
        name: Fällige Posten erzeugen
        type: executeCode
        source {
            plsqlCode:
                ```plsql
                FAKT_DEBITOR.posten_erzeugen(:MANDANT_ID);
                ```
        }
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

)
"""
    return s


def seite_51():
    """Debitor: Registerkarten Stammdaten (Name, Bezeichnung, Betrag, Intervall, faellig ab/bis, IBAN des Zahlers, Kunde,
    aktiv) und Zahlungen (Faelligkeiten mit Zahlungsstand, Zahlungseingaenge aus der Bankdatei mit "Aufheben",
    offene Bankeingaenge mit "Zuweisen"). Speichern plant die kuenftigen Posten neu und gleicht die Bank ab."""
    f = dict(form="debitor")
    TAB = "        advanced {\n            regionDisplaySelector: true\n        }\n"
    OHNE_KOPF = "[\n                #DEFAULT#\n                t-Region--removeHeader js-removeLandmark\n            ]"
    # offener Saldo rechts im Titel der Faelligkeiten (rot, nur wenn > 0)
    s = KOPF(51, "Debitor", "DEBITOR").replace("    security {", """    css {
        inline:
            ```css
            .t-Region-title:has(.thg-titel-saldo) { display: flex; align-items: baseline; gap: 1rem; }
            .thg-titel-saldo { margin-left: auto; font-weight: 600; font-variant-numeric: tabular-nums; }
            ```
    }
    security {""", 1) + BREADCRUMB("&P51_TITEL.")
    s += """    region debitor (
        name: Debitor
        type: form
        source {
            location: localDatabase
            tableName: FAKT_DEBITOREN
        }
        layout {
            sequence: 20
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

    region rds (
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
        serverSideCondition {
            type: itemIsNotNull
            item: P51_DEBI_ID
        }
    )

"""
    s += region("stammdaten", "Stammdaten", 10, parent="debitor", extra=TAB, options=OHNE_KOPF)
    a = "stammdaten"
    for nr, (name, col, dflt) in enumerate((("P51_DEBI_ID", "DEBI_ID", None), ("P51_DEBI_MAND_ID", "DEBI_MAND_ID", "MANDANT_ID")), 1):
        s += f"""    pageItem {name} (
        type: hidden
        layout {{
            sequence: {nr}
            region: @{a}
            slot: regionBody
        }}
        source {{
            formRegion: @debitor
            column: {col}
            dataType: number
""" + ("            primaryKey: true\n" if nr == 1 else "") + """        }
""" + (f"""        default {{
            type: item
            item: {dflt}
        }}
""" if dflt else "") + """        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
    )

"""
    for nr, name in enumerate(("P51_TITEL", "P51_BKUM_ID", "P51_DZAH_ID", "P51_RDS_START", "P51_MELDUNG", "P51_SALDO"), 3):
        s += f"""    pageItem {name} (
        type: hidden
        layout {{
            sequence: {nr}
            region: @{a}
            slot: regionBody
        }}
""" + ("" if name in ("P51_TITEL", "P51_RDS_START", "P51_MELDUNG", "P51_SALDO") else """        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }
""") + "    )\n\n"
    s += item("P51_DEBI_NAME", "textField", "Name (Zahler)", 10, a, col="DEBI_NAME", req=True, maxlen=200, spalten=6, **f)
    s += item("P51_DEBI_BEZEICHNUNG", "textField", "Bezeichnung (z. B. Miete Wohnung Top 3)", 20, a, col="DEBI_BEZEICHNUNG",
              maxlen=200, neue_zeile=False, spalten=6, **f)
    # Betrag und "faellig ab" nur mit Intervall Pflicht (Validierungen unten); "Kein Intervall" = nur Zahlungen sammeln
    s += maske(item("P51_DEBI_BETRAG", "numberField", "Zu überweisender Betrag €", 40, a, col="DEBI_BETRAG", dtype="number",
                    neue_zeile=False, spalten=3, tmpl="@/required-floating", **f), "999G999G990D00")
    # Intervall links vor dem Betrag: bestimmt, ob Betrag und "faellig ab" Pflicht sind (DA intervall-pflicht)
    s += item("P51_DEBI_INTERVALL", "selectList", "Intervall", 30, a, col="DEBI_INTERVALL", req=True,
              spalten=3, extra=lov("lov-debitor-intervall") + """        default {
            type: static
            staticValue: MONATLICH
        }
""", **f)
    s += item("P51_DEBI_FAELLIG_AB", "datePicker", "Fällig ab (erste Fälligkeit)", 50, a, col="DEBI_FAELLIG_AB", dtype="date",
              neue_zeile=False, spalten=3, tmpl="@/required-floating", **f)
    s += item("P51_DEBI_FAELLIG_BIS", "datePicker", "Fällig bis (leer = unbefristet)", 60, a, col="DEBI_FAELLIG_BIS",
              dtype="date", neue_zeile=False, spalten=3, **f)
    s += item("P51_DEBI_IBAN", "textField", "IBAN des Zahlers (Bankabgleich, wird bei der ersten Zuweisung übernommen)", 70, a,
              col="DEBI_IBAN", maxlen=34, spalten=6, **f)
    s += item("P51_DEBI_KUND_ID", "selectList", "Kunde (optional)", 80, a, col="DEBI_KUND_ID", dtype="number",
              neue_zeile=False, spalten=4, extra=lov("lov-kunden", "- kein Kunde -"), **f)
    s += item("P51_DEBI_IST_AKTIV", "switch", "Aktiv", 90, a, col="DEBI_IST_AKTIV", neue_zeile=False, spalten=2,
              extra=SWITCH("Y"), **f)
    s += item("P51_DEBI_BEMERKUNG", "textarea", "Bemerkung", 100, a, col="DEBI_BEMERKUNG", maxlen=1000, spalten=12, **f)

    # Registerkarte Zahlungen: Faelligkeiten, Zahlungseingaenge (Bank), offene Bankeingaenge zuweisen
    s += region("zahlungen", "Zahlungen", 30, extra=TAB + NICHT_NULL("P51_DEBI_ID"), options=OHNE_KOPF)
    def in_tab(txt, seq):
        return txt.replace(f"            sequence: {seq}\n            slot: body\n",
                           f"            sequence: {seq}\n            parentRegion: @zahlungen\n            slot: subRegions\n", 1)
    s += in_tab(bericht("faelligkeiten", 'Fälligkeiten<span class="thg-titel-saldo u-danger-text">&P51_SALDO.</span>', 10, """                -- Zahlungen decken die aeltesten Posten zuerst (FAKT_DEBITOR_POSTEN_V); neueste Faelligkeit oben
                select to_char(v.FAELLIG_AM, 'DD.MM.YYYY') as FAELLIG_AM,
                       FAKT_HISTORIE.betrag(v.BETRAG) as BETRAG,
                       FAKT_HISTORIE.betrag(v.BEZAHLT) as BEZAHLT,
                       FAKT_HISTORIE.betrag(v.OFFEN) as OFFEN,
                       '<span class="fa ' || case when v.STATUS = 'BEZAHLT' then 'fa-check-circle u-success-text'
                                                  when v.IST_UEBERFAELLIG = 'Y' then 'fa-exclamation-triangle u-danger-text'
                                                  when v.STATUS = 'TEILBEZAHLT' then 'fa-adjust u-warning-text'
                                                  else 'fa-clock-o u-info-text' end || '" aria-hidden="true"></span> '
                       || case when v.IST_UEBERFAELLIG = 'Y' and v.STATUS = 'OFFEN' then 'Überfällig'
                               else FAKT_DEBITOR.status_text(v.STATUS) end as STATUS,
                       to_char(v.BEZAHLT_AM, 'DD.MM.YYYY') as BEZAHLT_AM
                  from FAKT_DEBITOR_POSTEN_V v
                 where v.DEBI_ID = :P51_DEBI_ID
                 order by v.FAELLIG_AM desc""",
                 [("FAELLIG_AM", "Fällig am", False, False), ("BETRAG", "Betrag", False, True),
                  ("BEZAHLT", "Bezahlt", False, True), ("OFFEN", "Offen", False, True),
                  ("STATUS", "Status", True, False), ("BEZAHLT_AM", "Bezahlt am", False, False)],
                 "Noch keine Fälligkeiten."), 10)
    s += in_tab(bericht("eingaenge", "Zahlungseingänge laut Bankdatei", 20, """                select to_char(z.DZAH_DATUM, 'DD.MM.YYYY') as DATUM,
                       FAKT_HISTORIE.betrag(z.DZAH_BETRAG) as BETRAG,
                       u.BKUM_GEGEN_NAME as AUFTRAGGEBER,
                       trim(u.BKUM_REFERENZ || ' ' || u.BKUM_VERWENDUNGSZWECK) as VERWENDUNGSZWECK,
                       u.BKUM_ZUORDNUNG as ZUORDNUNG,
                       '<a href="' || apex_escape.html_attribute(apex_page.get_url(p_page => 51, p_items => 'P51_DEBI_ID,P51_DZAH_ID',
                                                                                   p_values => z.DZAH_DEBI_ID || ',' || z.DZAH_ID,
                                                                                   p_request => 'AUFHEBEN'))
                       || '" title="Zuweisung aufheben – die Buchung ist danach wieder offen"><span class="fa fa-unlink" aria-hidden="true"></span> Aufheben</a>' as AKTION
                  from FAKT_DEBITOR_ZAHLUNGEN z
                  left join FAKT_BANKUMSAETZE u on u.BKUM_ID = z.DZAH_BKUM_ID
                 where z.DZAH_DEBI_ID = :P51_DEBI_ID
                 order by z.DZAH_DATUM desc, z.DZAH_ID desc""",
                 [("DATUM", "Datum", False, False), ("BETRAG", "Betrag", False, True),
                  ("AUFTRAGGEBER", "Auftraggeber", False, False), ("VERWENDUNGSZWECK", "Verwendungszweck", False, False),
                  ("ZUORDNUNG", "Zuordnung", False, False), ("AKTION", "Aktion", True, False)],
                 "Noch keine Zahlungen – Zahlungseingänge kommen aus der Bankdatei (Menüpunkt Bankdatei hochladen)."), 20)
    s += in_tab(bericht("bank-offen", "Offene Bankeingänge zuweisen", 30, """                -- nicht zugeordnete Eingaenge des Mandanten (ohne erkannte Rechnung/Gutschrift); passender Name zuerst
                select to_char(u.BKUM_BUCHUNGSDATUM, 'DD.MM.YYYY') as DATUM,
                       FAKT_HISTORIE.betrag(u.BKUM_BETRAG) as BETRAG,
                       u.BKUM_GEGEN_NAME as AUFTRAGGEBER,
                       FAKT_RECHNUNG.referenz_anzeige(u.BKUM_GEGEN_IBAN) as IBAN,
                       trim(u.BKUM_REFERENZ || ' ' || u.BKUM_VERWENDUNGSZWECK) as VERWENDUNGSZWECK,
                       '<a href="' || apex_escape.html_attribute(apex_page.get_url(p_page => 51, p_items => 'P51_DEBI_ID,P51_BKUM_ID',
                                                                                   p_values => d.DEBI_ID || ',' || u.BKUM_ID,
                                                                                   p_request => 'ZUWEISEN'))
                       || '" title="Diesem Debitor zuweisen"><span class="fa fa-link" aria-hidden="true"></span> Zuweisen</a>' as AKTION
                  from FAKT_BANKUMSAETZE u
                  join FAKT_DEBITOREN d on d.DEBI_ID = :P51_DEBI_ID
                 where u.BKUM_MAND_ID = d.DEBI_MAND_ID
                   and u.BKUM_RICHTUNG = 'CRDT' and u.BKUM_STATUS = 'OFFEN'
                   and u.BKUM_RECH_ID is null and u.BKUM_GUTS_ID is null
                 order by case when FAKT_DEBITOR.name_passt(d.DEBI_NAME, u.BKUM_GEGEN_NAME) = 'Y'
                                 or replace(upper(u.BKUM_GEGEN_IBAN), ' ') = d.DEBI_IBAN then 0 else 1 end,
                          u.BKUM_BUCHUNGSDATUM desc""",
                 [("DATUM", "Datum", False, False), ("BETRAG", "Betrag", False, True),
                  ("AUFTRAGGEBER", "Auftraggeber", False, False), ("IBAN", "IBAN", False, False),
                  ("VERWENDUNGSZWECK", "Verwendungszweck", False, False), ("AKTION", "Aktion", True, False)],
                 "Keine offenen Bankeingänge."), 30)

    # Kopf-Buttons
    s += button("up", "UP", "Zurück zu den Debitoren", 10, "breadcrumb", "up", "@/icon", icon="fa-arrow-up",
                options="[\n                #DEFAULT#\n                t-Button--noUI\n            ]",
                verhalten="""            action: redirectThisApp
            target: {
                page: 50
            }
            warnOnUnsavedChanges: doNotCheck
""")
    s += button("delete", "DELETE", "Löschen", 10, "breadcrumb", "next",
                options="[\n                #DEFAULT#\n                t-Button--danger\n                t-Button--simple\n            ]",
                verhalten="""            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
""", bedingung=NICHT_NULL("P51_DEBI_ID") + """        confirmation {
            message: Debitor wirklich löschen? Die zugewiesenen Bankbuchungen werden wieder offen.
            style: danger
        }
""")
    s += button("save", "SAVE", "Speichern", 20, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: update\n",
                bedingung=NICHT_NULL("P51_DEBI_ID"))
    s += button("create", "CREATE", "Anlegen", 30, "breadcrumb", "next", hot=True,
                verhalten="            warnOnUnsavedChanges: doNotCheck\n            databaseAction: insert\n",
                bedingung=NULL("P51_DEBI_ID"))

    s += f"""    process initialize-form-debitor (
        name: Formular Debitor initialisieren
        type: formInitialization
        formRegion: @debitor
        execution {{
            sequence: 10
            point: beforeHeader
        }}
    )

    process aus-buchung (
        name: Debitor aus Bankbuchung anlegen
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                -- Button "Debitor anlegen" auf Seite 30: anlegen, Buchung zuweisen, danach im Formular bearbeiten
                begin
                    :P51_DEBI_ID := FAKT_DEBITOR.aus_buchung(:P51_BKUM_ID);
                    apex_application.g_print_success_message := 'Debitor aus der Bankbuchung angelegt und zugewiesen – bitte Angaben prüfen und speichern.';
                exception
                    when others then
                        if sqlcode <> -20280 then raise; end if;
                        -- Seite neu geladen: Buchung ist schon zugewiesen -> diesen Debitor zeigen
                        select max(BKUM_DEBI_ID) into :P51_DEBI_ID from FAKT_BANKUMSAETZE where BKUM_ID = :P51_BKUM_ID;
                end;
                ```
        }}
        execution {{
            sequence: 5
            point: beforeHeader
        }}
        serverSideCondition {{
            type: expression
            language: plsql
            plsqlExpression: :REQUEST = 'ANLEGEN' and :P51_BKUM_ID is not null and :P51_DEBI_ID is null
        }}
    )

    process kopf (
        name: Mandant prüfen, Titel, Posten, Zuweisen/Aufheben
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                begin
                    if :P51_DEBI_ID is not null and :P51_DEBI_MAND_ID <> :MANDANT_ID then
                        raise_application_error(-20240, 'Dieser Debitor gehört zu einem anderen Mandanten. Bitte den Mandanten im Portal wechseln.');
                    end if;
                    :P51_TITEL := case when :P51_DEBI_ID is null then 'Neuer Debitor' else 'Debitor ' || :P51_DEBI_NAME end;
                    if :P51_DEBI_ID is null then
                        :P51_BKUM_ID := null;
                    else
                        -- Link "Zuweisen" bzw. "Aufheben" (Request aus der URL); ein Neuladen der Seite schadet nicht
                        if :REQUEST = 'ZUWEISEN' and :P51_BKUM_ID is not null then
                            begin
                                FAKT_DEBITOR.zuweisen(:P51_BKUM_ID, :P51_DEBI_ID);
                                apex_application.g_print_success_message := 'Zahlungseingang zugewiesen.';
                            exception
                                when others then
                                    if sqlcode <> -20280 then raise; end if;   -- schon zugewiesen
                            end;
                        elsif :REQUEST = 'AUFHEBEN' and :P51_DZAH_ID is not null then
                            FAKT_DEBITOR.aufheben(:P51_DZAH_ID);
                            apex_application.g_print_success_message := 'Zuweisung aufgehoben – die Buchung ist wieder offen.';
                        end if;
                        -- nach Zuweisen/Aufheben die Registerkarte Zahlungen zeigen (thg.js)
                        :P51_RDS_START := case when :REQUEST in ('ZUWEISEN', 'AUFHEBEN') then 'Zahlungen' end;
                        :P51_BKUM_ID := null;
                        :P51_DZAH_ID := null;
                        FAKT_DEBITOR.posten_erzeugen(:MANDANT_ID, :P51_DEBI_ID);
                        -- offener Saldo bis heute (Titel der Faelligkeiten, Saldo 0 wird nicht angezeigt)
                        select case when sum(v.OFFEN) > 0
                                    then 'Offen per ' || to_char(sysdate, 'DD.MM.YYYY') || ': ' || FAKT_HISTORIE.betrag(sum(v.OFFEN)) end
                          into :P51_SALDO
                          from FAKT_DEBITOR_POSTEN_V v
                         where v.DEBI_ID = :P51_DEBI_ID
                           and v.FAELLIG_AM <= trunc(sysdate);
                    end if;
                end;
                ```
        }}
        execution {{
            sequence: 20
            point: beforeHeader
        }}
    )

    dynamicAction intervall-pflicht (
        name: Betrag und Fällig ab nur mit Intervall als Pflicht markieren
        execution {{
            sequence: 10
        }}
        when {{
            event: change
            selectionType: items
            items: [
                P51_DEBI_INTERVALL
            ]
        }}

        action pflicht-markieren (
            action: executeJsCode
            settings {{
                jsCode:
                    ```javascript-browser
                    var pflicht = $v("P51_DEBI_INTERVALL") !== "KEIN";
                    ["P51_DEBI_BETRAG", "P51_DEBI_FAELLIG_AB"].forEach(function (name) {{
                        // Vorlage "Required" zeichnet die Markierung; ohne Intervall ausblenden
                        var feld = $("#" + name + "_CONTAINER");
                        feld.toggleClass("is-required", pflicht);
                        feld.find(".t-Form-itemRequired-marker").toggle(pflicht);
                    }});
                    ```
            }}
            execution {{
                sequence: 10
                fireOnInit: true
            }}
        )

    )

    validation betrag-pflicht (
        name: Betrag bei Intervall Pflicht
        execution {{
            sequence: 10
        }}
        validation {{
            type: expression
            language: plsql
            plsqlExpression: :P51_DEBI_INTERVALL = 'KEIN' or :P51_DEBI_BETRAG is not null
        }}
        error {{
            errorMessage: Bitte den zu überweisenden Betrag angeben (nur bei „Kein Intervall“ optional).
            associatedItem: @P51_DEBI_BETRAG
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }}
    )

    validation faellig-ab-pflicht (
        name: Fällig ab bei Intervall Pflicht
        execution {{
            sequence: 20
        }}
        validation {{
            type: expression
            language: plsql
            plsqlExpression: :P51_DEBI_INTERVALL = 'KEIN' or :P51_DEBI_FAELLIG_AB is not null
        }}
        error {{
            errorMessage: Bitte „Fällig ab“ angeben (nur bei „Kein Intervall“ optional).
            associatedItem: @P51_DEBI_FAELLIG_AB
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }}
    )

    process zahlungen-freigeben (
        name: Vor dem Löschen Zuweisungen aufheben
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                for z in (select DZAH_ID from FAKT_DEBITOR_ZAHLUNGEN where DZAH_DEBI_ID = :P51_DEBI_ID) loop
                    FAKT_DEBITOR.aufheben(z.DZAH_ID);
                end loop;
                :P51_MELDUNG := 'Debitor gelöscht.';
                ```
        }}
        execution {{
            sequence: 5
        }}
        serverSideCondition {{
            whenButtonPressed: @delete
        }}
    )

    process meldung (
        name: Meldung beim Speichern
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                :P51_MELDUNG := 'Debitor gespeichert.';
                ```
        }}
        execution {{
            sequence: 6
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }}
    )

    process process-form-debitor (
        name: Formular Debitor verarbeiten
        type: formAutoRowProcessing
        formRegion: @debitor
        execution {{
            sequence: 10
        }}
        successMessage {{
            successMessage: &P51_MELDUNG.
        }}
    )

    process planen (
        name: Posten planen, Bank abgleichen
        type: executeCode
        source {{
            plsqlCode:
                ```plsql
                declare
                    l_anz pls_integer;
                begin
                    FAKT_DEBITOR.planen(:P51_DEBI_ID);
                    -- offene Eingaenge mit passender IBAN bzw. passendem Namen gleich zuweisen
                    l_anz := FAKT_BANK.abgleichen(:MANDANT_ID);
                    if l_anz > 0 then
                        apex_application.g_print_success_message := 'Debitor gespeichert. Bankabgleich: ' || l_anz || ' Zahlungseingänge zugeordnet.';
                    end if;
{FEHLER}
                ```
        }}
        execution {{
            sequence: 20
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }}
    )

    branch nach-speichern (
        name: Debitor wieder öffnen
        execution {{
            sequence: 10
        }}
        behavior {{
            target: {{
                page: 51
                items: {{
                    P51_DEBI_ID: &P51_DEBI_ID.
                }}
            }}
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE
        }}
    )

    branch nach-loeschen (
        name: Zur Liste
        execution {{
            sequence: 20
        }}
        behavior {{
            target: {{
                page: 50
            }}
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: DELETE
        }}
    )

)
"""
    return s


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

    entry gutschriften (
        label: Gutschriften
        icon {
            imageIconCssClasses: fa-money
        }
        layout {
            sequence: 22
        }
        link {
            target: {
                page: 40
            }
        }
        isCurrent {
            type: pages
            pages: [
                40
                41
            ]
        }
    )

    entry debitoren (
        label: Debitoren
        icon {
            imageIconCssClasses: fa-users
        }
        layout {
            sequence: 23
        }
        link {
            target: {
                page: 50
            }
        }
        isCurrent {
            type: pages
            pages: [
                50
                51
            ]
        }
    )

    entry bankdatei (
        label: Bankdatei hochladen
        icon {
            imageIconCssClasses: fa-bank
        }
        layout {
            sequence: 25
        }
        link {
            target: {
                page: 30
            }
        }
        isCurrent {
            type: pages
            pages: [
                30
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

    entry gutschriften (
        name: Gutschriften
        pageNumber: 40
        execution {
            sequence: 33
        }
        appearance {
            parentEntry: @home
        }
        link {
            target: {
                page: 40
            }
        }
    )

    entry gutschrift (
        name: Gutschrift
        pageNumber: 41
        execution {
            sequence: 34
        }
        appearance {
            parentEntry: @gutschriften
        }
        link {
            target: {
                page: 41
            }
        }
    )

    entry debitoren (
        name: Debitoren
        pageNumber: 50
        execution {
            sequence: 36
        }
        appearance {
            parentEntry: @home
        }
        link {
            target: {
                page: 50
            }
        }
    )

    entry debitor (
        name: Debitor
        pageNumber: 51
        execution {
            sequence: 37
        }
        appearance {
            parentEntry: @debitoren
        }
        link {
            target: {
                page: 51
            }
        }
    )

    entry bankdatei (
        name: Bankdatei hochladen
        pageNumber: 30
        execution {
            sequence: 35
        }
        appearance {
            parentEntry: @home
        }
        link {
            target: {
                page: 30
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
            "lov-artikelgruppen", "lov-einheiten", "lov-mwst-saetze",   # Artikelseiten 20-22
            "lov-debitor-intervall"]   # Debitoren Seite 51


def lovs_abonnieren():
    """Portal-LOVs kopieren und als Subscription kennzeichnen (Inhalt wie im Portal)."""
    portal = (APEX / "thg-portal" / "shared-components" / "lovs.apx").read_text(encoding="utf-8")
    p = FIN / "shared-components" / "lovs.apx"
    s = p.read_text(encoding="utf-8")
    for sid in LOVS_ABO:
        muster = rf"lov {re.escape(sid)} \(.*?\n\)\n"
        m = re.search(muster, portal, flags=re.S)
        abo = f"    subscription {{\n        master: @/20000/{sid}\n    }}\n"
        blk = m.group(0)
        if "    columnMapping {" in blk:
            blk = blk.replace("    columnMapping {", abo + "    columnMapping {", 1)
        else:   # statische LOV: Subscription nach der Quelle
            blk = blk.replace("        location: staticValues\n    }\n", "        location: staticValues\n    }\n" + abo, 1)
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
    (FIN / "pages" / "p00015-stornieren.apx").write_text(seite_15(), encoding="utf-8")
    (FIN / "pages" / "p00016-zahlungseingang.apx").write_text(seite_16(), encoding="utf-8")
    (FIN / "pages" / "p00017-versenden.apx").write_text(seite_17(), encoding="utf-8")
    (FIN / "pages" / "p00030-bankdatei.apx").write_text(seite_30(), encoding="utf-8")
    (FIN / "pages" / "p00031-zahlung-zuordnen.apx").write_text(seite_31(), encoding="utf-8")
    (FIN / "pages" / "p00040-gutschriften.apx").write_text(seite_40(), encoding="utf-8")
    (FIN / "pages" / "p00041-gutschrift.apx").write_text(seite_41(), encoding="utf-8")
    (FIN / "pages" / "p00042-gutschrift-pdf.apx").write_text(seite_42(), encoding="utf-8")
    pdf_seiten()
    (FIN / "pages" / "p00043-gutschrift-anzeigen.apx").write_text(seite_43(), encoding="utf-8")
    (FIN / "pages" / "p00050-debitoren.apx").write_text(seite_50(), encoding="utf-8")
    (FIN / "pages" / "p00051-debitor.apx").write_text(seite_51(), encoding="utf-8")
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
