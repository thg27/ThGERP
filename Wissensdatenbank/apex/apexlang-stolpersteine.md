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
