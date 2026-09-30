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
- **Vor jedem `apex import` einer Sub-App** muss der Tab auf der Portal-Startseite stehen.
- Offene Beobachtung (2026-09-30): Beim Einspielen von THG-FINANZ war die Sitzung jedes Mal weg – auch bei Anmeldung
  über das Portal und Tab auf der Portal-Startseite. Ursache ungeklärt; nicht auf eine Regel verallgemeinern, sondern
  nach dem Import prüfen und den Anwender ggf. um eine neue Anmeldung bitten.
  Messung 00:10–00:15 UTC per `apex_workspace_sessions`: Sitzung aus der Anmeldung auf `thg-finanz/login` → beim
  Import von THG-FINANZ gelöscht (Import THG-ALLGEMEIN davor: blieb). Sitzung aus der Anmeldung auf
  `thg-portal/login` → einen Import von THG-FINANZ überstanden, beim nächsten Import (nachdem in der Sitzung
  Seite 11 von THG-FINANZ aufgerufen worden war) aber gelöscht. Keine verlässliche Regel – vermutlich löscht der
  Import Sitzungen, die die App schon verwendet haben. Vor/nach dem Import `apex_workspace_sessions` prüfen,
  Importe einer App bündeln und den Anwender erst danach um die Anmeldung bitten.
- Sub-Apps immer mit `?session=<Sitzung>` bzw. über das Portal aufrufen; eine URL ohne Sitzung startet eine neue
  Sitzung → Anmeldeseite.
- Muss das Portal eingespielt werden, am besten gesammelt am Ende und den Anwender dann um eine neue Anmeldung bitten.

## Stolpersteine
- Beim Testen nicht zu früh prüfen: nach einem AJAX-Aufruf mit anschließendem Region-Refresh 3–4 s warten,
  bevor der neue Zustand gelesen wird.
- Testdaten (Rechnungen, Schalter) nach dem Test auf den Ausgangszustand zurücksetzen.

## Quelle / Stand
Hinweis des Anwenders, 2026-09-26; ergänzt 2026-09-30.
