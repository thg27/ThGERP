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
