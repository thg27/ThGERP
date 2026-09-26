# Deutsche Texte für interne APEX-Meldungen (Grid, Report, Dialoge)

## Kontext
Das deutsche APEX-Sprachpaket ist auf der Instanz nicht installiert: Interactive Grid („Edit“, „Save“, „Add Row“,
„Changes saved“), Interactive Report („Go“, „Actions“), Dialoge („Cancel“) erscheinen englisch.

## Lösung
Interne Meldungen lassen sich durch **Text Messages mit gleichem Namen** (Sprache `de`, `usedInJavaScript: true`)
übersetzen. Datei `shared-components/messages.apx` je App, erzeugt mit `python3 Apex/generator/texte_de.py`.

```
textMessage APEX.IG.SAVE (
    message {
        text: Speichern
        language: de
        usedInJavaScript: true
    }
)
```

Namen der internen Meldungen finden (statt raten):
- SQL: `select apex_lang.message('APEX.IG.SAVE') from dual` → englischer Text, sonst kommt der Name zurück.
- Browser (Seite mit Grid): die geladenen APEX-Skripte nach `"APEX.[A-Z_.]+"` durchsuchen und mit
  `apex.lang.getMessage(key)` den Text prüfen.

## Stolpersteine
- Dateiname muss `messages.apx` sein (`text-messages.apx` → „FILE_IGNORED“).
- **Keine Subscription**: `subscription { master: @/20000/APEX.IG.SAVE }` scheitert beim Import mit ORA-20987
  (Punkte im Namen) – Texte in jeder App direkt anlegen (ein Generator, gleiche Liste).
- Nicht gefunden: Name für „Total %0“ (Grid-Fußzeile) und für „Show All“ des Region Display Selectors –
  letzteres übersetzt `thg.js` im Browser.

## Quelle / Stand
2026-09-26, APEX 26.1.
