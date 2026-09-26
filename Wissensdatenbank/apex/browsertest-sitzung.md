# Browsertests: Sitzung behalten (immer zurück ins Portal)

## Kontext
Tests im Browser (Claude in Chrome) laufen in der Sitzung des Anwenders. `apex import` einer App beendet Sitzungen
– danach muss sich der Anwender neu anmelden.

## Vorgehen
- **Nach jedem Test zur Startseite der Portal-App wechseln**
  (`https://erp.thg-edv.com/ords/r/thgerp/thg-portal/home?session=<Sitzung>`).
- Solange die **Portal-App (20000) nicht neu eingespielt** wurde, bleibt die Sitzung gültig: Sub-Apps können
  danach jederzeit wieder mit derselben Sitzung aufgerufen werden (Session Sharing), auch nachdem eine Sub-App
  eingespielt wurde.
- Sub-Apps immer mit `?session=<Sitzung>` bzw. über das Portal aufrufen; eine URL ohne Sitzung startet eine neue
  Sitzung → Anmeldeseite.
- Muss das Portal eingespielt werden, am besten gesammelt am Ende und den Anwender dann um eine neue Anmeldung bitten.

## Stolpersteine
- Beim Testen nicht zu früh prüfen: nach einem AJAX-Aufruf mit anschließendem Region-Refresh 3–4 s warten,
  bevor der neue Zustand gelesen wird.
- Testdaten (Rechnungen, Schalter) nach dem Test auf den Ausgangszustand zurücksetzen.

## Quelle / Stand
Hinweis des Anwenders, 2026-09-26.
