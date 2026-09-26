# Browsertests: Sitzung behalten (immer zurück ins Portal)

## Kontext
Tests im Browser (Claude in Chrome) laufen in der Sitzung des Anwenders. `apex import` einer App beendet Sitzungen
– danach muss sich der Anwender neu anmelden.

## Vorgehen
- **Nach jedem Test zur Startseite der Portal-App wechseln**
  (`https://erp.thg-edv.com/ords/r/thgerp/thg-portal/home?session=<Sitzung>`).
- Beobachtung 2026-09-26: Auch das Einspielen **einer Sub-App** (THG-ADMIN) hat die Sitzung beendet – im Portal
  und in allen Apps (Anmeldeseite, `APP_USER = nobody`). Die Annahme „Sitzung bleibt, solange das Portal nicht
  eingespielt wird“ hat sich nicht bestätigt. Nach jedem `apex import` mit einer neuen Anmeldung rechnen.
- Deshalb: Änderungen **bündeln**, alle betroffenen Apps nacheinander einspielen und erst danach den Anwender um
  eine Anmeldung bitten und in einem Durchgang testen.
- Sub-Apps immer mit `?session=<Sitzung>` bzw. über das Portal aufrufen; eine URL ohne Sitzung startet eine neue
  Sitzung → Anmeldeseite.

## Stolpersteine
- Beim Testen nicht zu früh prüfen: nach einem AJAX-Aufruf mit anschließendem Region-Refresh 3–4 s warten,
  bevor der neue Zustand gelesen wird.
- Testdaten (Rechnungen, Schalter) nach dem Test auf den Ausgangszustand zurücksetzen.

## Quelle / Stand
Hinweis des Anwenders, 2026-09-26.
