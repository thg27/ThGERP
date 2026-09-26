# Mandant über alle Apps (Session Sharing, globale Items)

## Kontext
Der Mandant (THG-EDV / Thomas Geßlbauer) wird im Portal gewählt und muss in allen Apps gelten,
bis er im Portal gewechselt wird.

## Lösung
- Alle Apps: Authentifizierung mit `sessionSharing { type: workspaceSharing }` (Cookie `&WORKSPACE_COOKIE.`) –
  eine Anmeldung, eine Sitzung für alle Apps.
- Application Items `MANDANT_ID`, `MANDANT_CODE`, `MANDANT_NAME`, `MANDANT_LOGO`, `MANDANT_BENUTZER` mit
  `scope: global` in **jeder** App (gleiche Namen) → der Wert gilt app-übergreifend in der Sitzung.
- Portal: App-Prozess „Mandant setzen“ (Wechsel per Request `MANDANT_<CODE>` aus der Navigationsleiste).
- Sub-Apps: App-Prozess „Mandant vorbelegen“ – setzt nur, wenn noch leer (direkter Einstieg), wechselt nie.
- Anzeige in allen Sub-Apps: Eintrag `&MANDANT_NAME.` in der Navigationsleiste, nicht klickbar
  (`linkAttributes: tabindex="-1" aria-disabled="true" style="pointer-events:none;cursor:default"`).
- Logo-Klick (alle Apps): `thg.js` fängt den Klick ab, prüft `apex.page.isChanged()` (inkl. Grids), fragt bei
  Änderungen nach und wechselt mit `apex.navigation.redirect('f?p=THG-PORTAL:HOME:<Sitzung>', true)` ins Portal.
- Logo: `logo { type: custom }` mit `data-mandant="&MANDANT_CODE."` → Bannerfarbe per `thg.css`, Bild `#WORKSPACE_FILES#&MANDANT_LOGO.`.
- Alles für die Sub-Apps erzeugt `Apex/generator/mandant_in_apps.py` (wiederholbar).

## Stolpersteine
- Links zwischen Apps müssen die Sitzung mitgeben (`apex_page.get_url(p_application => …)` bzw. `&SESSION.`);
  eine URL ohne `session=` startet eine neue Sitzung → Anmeldeseite.
- Mandantenabhängige Seiten (Finanz) filtern mit `= :MANDANT_ID` und prüfen beim Öffnen eines Datensatzes,
  dass er zum Mandanten der Sitzung gehört.
- Default eines Seitenelements (`default { type: item item: MANDANT_ID }`) wird erst beim Rendern gesetzt – in
  Prozessen „Before Header“ ist das Element bei neuen Datensätzen noch leer (`coalesce(:P11_…, :MANDANT_ID)`).

## Quelle / Stand
2026-09-26, APEX 26.1.
