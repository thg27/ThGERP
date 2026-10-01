# APEXlang: Stolpersteine beim Generieren von Seiten

## Kontext
Seiten werden per Python-Generator erzeugt (`Apex/generator/*.py`) und mit `apex validate` geprüft.
Diese Punkte haben Validierung oder Import scheitern lassen (APEX 26.1, SQLcl 26.x).

## Lösungen
| Thema | Richtig | Falsch / Meldung |
|---|---|---|
| Einträge statischer LOVs | `entry ja ( sequence: 1  display: Ja  return: Y )` | `displayValue`/`returnValue` |
| Unterregionen eines **Tabs Container** (`@/tabs-container`) | `slot: tabs` | `slot: subRegions` → Warnung *Invalid Slot value* |
| Interactive Grid: Werkzeugleiste | Block weglassen oder Controls angeben (`actionsMenu`, `saveButton` …) | leeres `controls: [ ]` → `MISSING_PROPERTY_VALUE` |
| IG-Spalte mit Vorgabe aus Seitenelement | `default { type: item  item: P21_MAND_ID }` | – |
| Seitenelement-Vorgabe per SQL | `default { type: sqlQuerySingleValue  sqlQuerySingleValue: …sql… }` | – |
| Download einer BLOB-Spalte im IR | `type: downloadBlob`, `appearance { viewFileAs: attachment }`, `blobAttributes { tableName, blobColumn, primaryKeyColumn1, mimeTypeColumn, filenameColumn }`, Spalte in der Abfrage als `dbms_lob.getlength(...)` | – |
| Datei hochladen | `fileUpload` mit `storage { type: appTempFiles }`, dann `insert … select … from apex_application_temp_files where name = :ITEM` | Speicherung direkt in BLOB-Spalte ist im Generator nicht belegt |
| Eigene Speicherlogik je IG-Zeile | Prozess `type: executeCode` mit `editableRegion: @region`, Spalten als Bind (`:AZUW_WERT`) | – |

## Stolpersteine
- Der Artikel-Generator nutzt f-Strings nach PEP 701 (verschachtelte Anführungszeichen, Backslashes) →
  **Python 3.12+** nötig: `python3.13 Apex/generator/gen_artikel.py` (System-Python ist 3.9).
- Die genaue Syntax steht in der Grammatik des Oracle-APEX-Skills:
  `~/.claude/plugins/marketplaces/oracle-skills/apex/apexlang/assets/grammar/apexlang.ebnf`.

## Quelle / Stand
App THG-ARTIKEL (20040) und THG-ADMIN (20030), 2026-09-26.

## Laufzeit-Stolpersteine (ergänzt 2026-09-26, Browsertest THG-FINANZ)
- **Werte aus dem Interactive Grid kommen als Text** in Prozessen mit `editableRegion` (`:RPOS_EINZELPREIS` usw.).
  `coalesce(:TEXT, zahl_spalte)` → `ORA-00932`. Zahlen mit `to_number(:X)`, CLOB-Spalten mit `to_clob(:X)` umwandeln.
- Solche Prozesse vor dem Einspielen **in der Datenbank ausführen**: Code aus der `.apx` nehmen, Binds durch
  Text-Literale ersetzen, am Ende `rollback` – das findet Typfehler, die `apex validate` nicht sieht.
- **`apex import` beendet die laufenden Sitzungen** der Apps (Session Sharing) → nach jedem Einspielen neu anmelden.
- APEX-Systemmeldungen („Row created.“) sind englisch, solange die deutschen APEX-Texte nicht installiert sind →
  bei Formularprozessen eigene `successMessage` setzen.
- `<…>` in Beschriftungen wird als HTML verschluckt – keine spitzen Klammern in Labels.
- **Region-Bezeichnung ≠ HTML-ID:** `region applikationen (` setzt keine DOM-ID. Für `$("#…")` bzw.
  `apex.region("…")` braucht die Region `advanced { htmlDomId: applikationen }`; sonst greifen Handler nicht
  (Klicks ohne Wirkung, keine Fehlermeldung). Handler besser an `document` binden (`$(document).on("click", "#id .klasse", …)`),
  damit sie auch nach dem Aktualisieren der Region wirken.
- **Icons in einer Auswahlliste:** Seitenelement `type: selectOne` mit einer SQL-LOV, die eine Icon-Spalte liefert
  (`columnMapping { return: R  display: D  icon: ICON }`, Icon-Spalte z. B. `'fa ' || r`). Statische LOVs haben
  keine Icon-Spalte. `selectOne` kennt kein `displayExtraValues` (→ INVALID_PROPERTY).
- **JavaScript in Python-Generatoren:** `"\n"` in einem normalen Python-String wird zum echten Zeilenumbruch – im
  JS-Code der Dynamic Action steht dann ein unterbrochenes String-Literal (`SyntaxError: Invalid or unexpected token`),
  und **alle** Dynamic Actions der Seite fallen aus (`apex.da.initDaEventList is not a function`). Im JS-Code keine
  Backslash-Escapes verwenden (z. B. `String.fromCharCode(10)`) oder `\\n` bzw. Raw-Strings im Generator.
- **Interactive Grid mit Formatmaske (z. B. `FML999G999G990D00`):** Im Modell und in den Bind-Variablen eigener
  Speicherprozesse stehen die Werte formatiert (`€1.250,00`) – `to_number(:SPALTE)` → ORA-01722. Im Prozess mit
  eigener Umwandlung arbeiten (Währungszeichen entfernen, `to_number(…, '999G999G999G990D99999',
  'NLS_NUMERIC_CHARACTERS='',.''')`); im JavaScript `apex.locale.formatNumber/toNumber` mit derselben Maske verwenden,
  sonst meldet die Prüfung „must be a valid number“. Lokale PL/SQL-Funktionen nicht direkt in SQL verwenden
  (PLS-00231) → vorher in eine Variable. Werteliste-Spalten stehen im Modell als `{v, d}`.
- **Berechnete Spalte im Interactive Grid per JavaScript setzen:** Ist die Spalte serverseitig „nur lesen“
  (`readOnly { type: always }`), bekommt jede geladene Zeile eine Prüfsumme (`ck`) und `model.setValue` scheitert mit
  „Set value not allowed for field“ – bei neuen Zeilen funktioniert es, daher leicht übersehen. Lösung: Spalte
  serverseitig nicht schreibgeschützt, im Browser `model.getOption("fields").SPALTE.readonly = true` setzen und beim
  Setzen kurz aufheben; den Wert serverseitig nicht übernehmen (Trigger/Prozess berechnet ihn).

## Dialogseite mit Formular, Popup LOV, Interactive Grid (ergänzt 2026-10-01, THG-FINANZ Seite 11/14)
- **Formularfelder stehen nicht im Sitzungsstatus:** Die Formular-Initialisierung hält die Werte nur für die
  Seitenanzeige. In AJAX-Callbacks und „Execute Server-side Code“ sind `:P11_RECH_ID`, der Primärschlüssel
  (`:P14_RPOS_ID`) usw. leer, wenn sie nicht mitgeschickt werden → `apex.server.process(…, { pageItems: "#P11_RECH_ID" })`
  bzw. `itemsToSubmit`. Symptom: URL `…?p14_rpos_id&p14_rech_id` ohne Werte, `ORA-01403` auf der Zielseite.
- **Neue Zeile im Formular:** Die Initialisierung leert alle Formularfelder – auch einen per URL übergebenen
  Fremdschlüssel. Lösung: eigenes Hidden-Element ohne Formularquelle (`P14_RECH_ID`, bleibt im Sitzungsstatus) und im
  Formularfeld `default { type: item  item: P14_RECH_ID }`.
- **`displayOnly` per Dynamic Action gesetzt** → beim Absenden „Session state protection violation … protected page
  item“. Lösung: `settings { sendOnPageSubmit: false }` und das Feld nicht in `itemsToSubmit` aufnehmen.
- **Mehrspaltige Werteliste (Popup LOV):** in der LOV je Zusatzspalte `column NAME ( heading { … } layout { sequence }
  source { dataType } )`, Anzeige-/Rückgabespalte mit `show: false` und `advanced { searchable: false }`. Element bzw.
  IG-Spalte `type: popupLov` (kein `displayExtraValues`). Die Suche geht über alle sichtbaren Spalten. Das Inline-Popup
  ist nur so breit wie das Feld/die Rasterspalte → Mindestbreite in `thg.css` (`.ui-dialog.ui-dialog-popuplov`).
- **Dialog aus JavaScript öffnen:** URL serverseitig mit `apex_page.get_url(p_page, p_items, p_values,
  p_triggering_element => 'apex.jQuery(''#region'')')` (Prüfsumme!), im Browser `apex.navigation.redirect(url)`;
  nach dem Schließen feuert `apexafterclosedialog` auf der Region → `apex.region("…").refresh()`.
- **IG-Zeilenmenü erweitern:** `ansicht.rowActionMenu$.menu("option").items.unshift({ type: "action", label, icon,
  action: function (m, el) { var satz = ansicht.getContextRecord(el)[0]; … } })`. Das Zeilenmenü gibt es **auch im
  nur lesbaren Raster** (Region `readOnly`) – der Eintrag ist dort ebenfalls sichtbar; ob das Raster änderbar ist,
  liefert `modell.getOption("editable")` (z. B. Beschriftung „Detail anzeigen“ statt „Detail bearbeiten“).
- **Dialog je nach Zustand der Hauptseite nur lesen statt Fehlermeldung:** Eine Prüfung mit `raise_application_error`
  im Before-Header-Prozess des Dialogs verhindert das Öffnen (Fehlerseite im Dialog). Besser: der Prozess setzt ein
  Hidden-Element (`P14_NUR_LESEN := 'Y'`), die Formularregion bekommt `readOnly { type: expression  language: plsql
  plsqlExpression: :P14_NUR_LESEN = 'Y' }` (gilt für alle Elemente der Region), die Speichern-Buttons eine
  Bedingung darauf; die harte Prüfung bleibt nur im Prozess beim Absenden. Die Regel selbst ist dieselbe wie auf der
  Hauptseite (Status aus der Tabelle + `:P11_BEARBEITEN` aus dem Sitzungsstatus – `:P11_RECH_STATUS` steht als
  Formularfeld nicht im Sitzungsstatus). Im nur lesbaren Formular sind Zahlenfelder reine Anzeige:
  `apex.item(…).getNativeValue()` liefert keinen Zahlenwert → berechnete Anzeigen (Summe) serverseitig setzen.
- **Zeile per Skript anfügen:** `modell.insertNewRecord(null, letzterSatz)`, danach
  `ansicht.view$.grid("gotoCell", id, "SPALTE")` und `grid("setEditMode", true)`.
- **Region neu laden verwirft ungespeicherte Rasteränderungen** ohne Rückfrage → vor dem Öffnen eines Dialogs, der
  das Raster neu lädt, auf Änderungen prüfen (`getRecordMetadata(...).updated/inserted/deleted`).

## Felder per AJAX neben einem Formular, Baum + Raster (ergänzt 2026-10-01, THG-FINANZ Seite 11 Positionen)
Seite 11 hat das Formular „Rechnung“ und daneben Felder einer Position (`P11_POS_*`) ohne Formularquelle, die per
`apex.server.process` geladen/gespeichert werden; links ein selbst gerenderter Baum (zwei Ebenen, einfache `div`-Liste).
- **Seitenelemente ohne Quelle auf einer Formularseite:** `advanced { warnOnUnsavedChanges: ignore }` (sonst „Seite
  verlassen?“), **kein** `valueRequired` (würde das Speichern des Formulars blockieren – Pflicht im AJAX-Prozess prüfen,
  Optik über `@/required-floating`), Anzeigefelder mit `sendOnPageSubmit: false`.
- **Schwebende Beschriftung (floating label):** Wird ein Wert mit `setValue(w, null, true)` (change unterdrückt) gesetzt,
  bleibt die Beschriftung über dem Wert liegen. Mit change-Ereignis setzen und die eigenen Handler währenddessen über
  ein Kennzeichen ignorieren.
- **Nur lesen:** nicht die Region `readOnly` setzen (Elemente werden zu Anzeige-Spans, `setValue` aktualisiert sie nicht
  zuverlässig), sondern `apex.item(name).disable()` und die Buttons ausblenden; der Server prüft ohnehin.
- **Ausblenden einzelner Felder:** `apex.item(name).hide()` lässt die Rasterspalte leer stehen → ein-/ausblendbare
  Felder in eigene Zeilen bzw. ans Zeilenende legen.
- **IDs aus SYS_GUID** sind für JavaScript-Zahlen zu groß: im JSON als Text (`to_char`), im DOM mit `attr("data-id")`
  lesen (nicht `.data("id")`).
- **Lokale PL/SQL-Funktion in SQL** (`insert … values (zahl(:X))`) → `PLS-00231`, im AJAX-Prozess erscheint nur
  „… is not valid JSON“ (Antwort beginnt mit `sqlerrm:`). Werte vorher in Variablen legen; Rohantwort mit
  `apex.server.process(…, { dataType: "text" })` ansehen.
- **Fachliche Fehler aus AJAX-Prozessen:** im `exception`-Teil `rollback` und `{"fehler": …}` zurückgeben, im Browser
  `apex.message.showErrors`.
- **Interactive Grid mit wechselndem Elternsatz:** Abfrage auf `:P11_HAUPT_ID`, das der Lade-Prozess per Bind im
  Sitzungsstatus setzt (kein clientseitig gesetztes Hidden-Element nötig), danach `region.refresh()`.
  - Ein Modell **mit Änderungen wird nicht neu geladen** – dazu zählt schon die vom Raster selbst angelegte leere Zeile,
    wenn ihr per `setValue` ein Wert gesetzt wurde → vorher `modell.clearChanges()` (echte Eingaben vorher abfragen).
  - Dieselbe Zeile macht die **Seite „geändert“** (`apex.page.isChanged()`, „Seite verlassen?“). Beim `insert`-Ereignis
    ist `autoInserted` noch nicht gesetzt → Vorgabewerte erst beim ersten `set` eines anderen Feldes schreiben.
  - Neue Zeilen haben `inserted` **und** `updated` → „ungespeichert?“ für neue Zeilen am Inhalt (Name/Artikel) festmachen.
  - War die Region ausgeblendet: nach dem Einblenden `ansicht.view$.grid("resize")`.
  - Nach dem Speichern feuert `interactivegridsave` auf der Region → Baum und Summen neu laden.
