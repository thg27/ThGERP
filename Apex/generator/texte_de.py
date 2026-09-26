#!/usr/bin/env python3
"""Deutsche Texte fuer interne APEX-Meldungen (Interactive Grid, Interactive Report, Dialoge, Notifications).

Das deutsche APEX-Sprachpaket ist auf der Instanz nicht installiert – APEX erlaubt, interne Meldungen durch
Text Messages mit gleichem Namen zu uebersetzen. Die Texte werden in jeder App direkt angelegt (gleiche Liste aus
diesem Skript): eine Subscription auf das Portal scheitert beim Import (ORA-20987), weil die Referenz
@/20000/APEX.IG.SAVE wegen der Punkte im Namen nicht aufgeloest wird.
Aufruf (wiederholbar):  python3 Apex/generator/texte_de.py   (danach Portal und Sub-Apps einspielen)
"""
from pathlib import Path

APEX = Path(__file__).resolve().parent.parent
SUB_APPS = ["thg-allgemein", "thg-kunden", "thg-admin", "thg-artikel", "thg-finanz"]

TEXTE = {
    # Interactive Grid
    "APEX.IG.SAVE": "Speichern",
    "APEX.IG.EDIT": "Bearbeiten",
    "APEX.IG.ADD_ROW": "Zeile hinzufügen",
    "APEX.IG.ACTIONS": "Aktionen",
    "APEX.IG.CHANGES_SAVED": "Änderungen gespeichert",
    "APEX.IG.SEARCH": "Suchen",
    "APEX.IG.GO": "Los",
    "APEX.IG.REFRESH": "Aktualisieren",
    "APEX.IG.RESET": "Zurücksetzen",
    "APEX.IG.REVERT_CHANGES": "Änderungen verwerfen",
    "APEX.IG.DELETE": "Löschen",
    "APEX.IG.DELETE_ROWS": "Zeilen löschen",
    "APEX.IG.DUPLICATE_ROWS": "Zeilen duplizieren",
    "APEX.IG.REFRESH_ROWS": "Zeilen aktualisieren",
    "APEX.IG.COLUMNS": "Spalten",
    "APEX.IG.FILTER": "Filter",
    "APEX.IG.SORT": "Sortieren",
    "APEX.IG.DOWNLOAD": "Herunterladen",
    "APEX.IG.HELP": "Hilfe",
    "APEX.IG.REPORT": "Bericht",
    "APEX.IG.ROWS_PER_PAGE": "Zeilen pro Seite",
    "APEX.GV.SELECTION_COUNT": "%0 Zeilen ausgewählt",
    "APEX.GV.ROW_DELETED": "Gelöscht",
    "APEX.GV.ROW_ADDED": "Hinzugefügt",
    "APEX.RV.INSERT": "Hinzufügen",
    "APEX.RV.NEXT_RECORD": "Weiter",
    "APEX.RV.PREV_RECORD": "Zurück",
    "APEX.RECORD_VIEW.TOOLBAR": "Einzelzeilenansicht",
    # Dialoge, Meldungen
    "APEX.DIALOG.CANCEL": "Abbrechen",
    "APEX.DIALOG.OK": "OK",
    "APEX.DIALOG.SAVE": "Speichern",
    "APEX.DIALOG.CLOSE": "Schließen",
    "APEX.CLOSE_NOTIFICATION": "Meldung schließen",
    "APEX.POPUP.SEARCH": "Suchen",
    # Interactive Report
    "APEXIR_GO": "Los",
    "APEXIR_ACTIONS": "Aktionen",
    "APEXIR_SEARCH": "Suchen",
}


def block(name, text, sub):
    s = f"""textMessage {name} (
    message {{
        text: {text}
        language: de
        usedInJavaScript: true
    }}
"""
    if sub:
        s += f"""    subscription {{
        master: @/20000/{name}
    }}
"""
    return s + ")\n"


def schreiben(app, sub):
    ziel = APEX / app / "shared-components" / "messages.apx"
    ziel.write_text("\n".join(block(n, t, sub) for n, t in TEXTE.items()), encoding="utf-8")


for app in ["thg-portal"] + SUB_APPS:
    schreiben(app, False)
print(f"{len(TEXTE)} deutsche Texte im Portal und in {len(SUB_APPS)} Sub-Apps")
