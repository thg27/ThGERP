# Projekt ThGERP

ERP-System für die THG-EDV GmbH (operatives IT-Geschäft) und die Thomas Geßlbauer GmbH (Holding).
Basis: Portal- und Sub-Apps mit Kundenstamm-Datenmodell sowie die Strategic-Planner-App als Vorlage.

## Status / offene Entscheidungen
- Workspace `THGERP`, Schema `WKSP_THGERP`, SQLcl-Verbindung `wksp_thgerp@pdbthg` (Host dbthgprod, für ERP-Entwicklung freigegeben).
- App-IDs ab 20000: 20000 THG-PORTAL, 20010 THG-ALLGEMEIN, 20020 THG-KUNDEN, 20030 THG-ADMIN, 20050 THG-FINANZ (Fakturierung, Tabellen FAKT_*, mit Artikelstamm ARTI_*).
  Die App 20040 THG-ARTIKEL ist seit 2026-10-24 aufgelöst (nur Rechnungen verwenden Artikel): Artikel in THG-FINANZ Seiten 20/21,
  Werteliste Artikelgruppen 120/121 (Seiten aus `gen_artikel.py`, eingebaut von `gen_finanz.py`); DDL 28 entfernt die Portal-Kachel.
  Artikelmaske nur Stammdaten (Nummer zuerst) und Kommentar; Zusatzfelder, Artikeldateien und Artikelbild entfernt (DDL 29, auch aus dem Datenmodell).
  Die Apps 10000–10030 im Workspace SIPA (gleiche APEX-Instanz) gehören zu einem Kundenprojekt und dürfen **nicht** verwendet werden.
- Installiert (Stand 2026-10-24): alle DDL-Skripte 01–45 (ohne 14, stammt aus einem anderen Projekt), Workspace-Dateien, Apps 20000–20050; Kunden und Artikel aus Kingbill (Access) übernommen.

Offen:
- DEV/PROD-Trennung

## Datenbank-Standards
Es gelten die THG-EDV-Datenbankstandards (Skill `thg-oracle-db-standards`).
- Gruppencodes: `KUND` (Kundenstamm), `ALLG` (allgemeine Stammdaten), `ADMIN` (Administration, bewusst 5-stellig), `ARTI` (Artikelstamm, App THG-FINANZ), `FAKT` (Fakturierung)
- Tabellen-Aliase: `Datenbank/db/aliase.md` – vor jeder neuen Tabelle prüfen und dort eintragen
- DDL-Skripte: `Datenbank/db/ddl` (nummeriert, `00_install.sql` ruft alle auf)
- ER-Modelle: `Datenbank/db/er-modell/kundenstamm_er_modell.mmd` und `artikel_fakturierung_er_modell.mmd` (generiert aus `ddl/generator/gen_19_20_…`) sind die Quellen; nach Modelländerungen `.mmd` anpassen und mit `python3 build_er_modell.py` PDF/SVG/PNG/HTML neu erzeugen
- Zieldatenbank: Oracle AI Database 26ai (Objektnamen bis 128 Zeichen)
- Nie auf Produktion ausführen. Vor jedem DDL/DML auf der Datenbank Rückfrage.
- Vor einer Installation in ein bestehendes Schema prüfen, ob Constraint-, Index- oder Triggernamen dort schon existieren –
  `create or replace trigger` würde gleichnamige Trigger ersetzen.

## APEX
- Portal-App ist Master für Shared Components; Sub-Apps abonnieren.
- **Dashboards überall netto** (Portal, Finanz, Kundenstamm inkl. Kopfinfo): Umsatz `RECH_SUMME_NETTO`, offene Beträge `OFFEN_NETTO` aus `FAKT_BELEGE_V` (DDL 44, anteilig).
- Portal-Startseite (20000 Seite 1): Kennzahlen, darunter Modul-Kacheln immer in einer Zeile (`#thg-module-einzeilig`, thg.css), dann Umsatz je Monat und Top 10 Kunden über **beide Mandanten summiert** (`FAKT_BELEGE_V` ohne
  Mandantenfilter, Tooltip mit Aufteilung EDV/Holding, keine Links – die Finanz-Listen filtern auf den Mandanten der Sitzung).
- **List of Values immer in der Portal-App anlegen**; in den Sub-Apps nur als Subscription (keine eigenen LOVs). LOV-Namen mit Präfix `LOV_`.
  APEXlang: `subscription { master: @/<portal-id>/<static-id> }` in der LOV und `"subscription": {"masterApps": {...}}` in `deployments/default.json` der Sub-App.
  Einspielen (einzeln nacheinander): 1. Portal, 2. Sub-Apps, 3. Subscriptions mit `apex_shared_component.refresh` aktualisieren, 4. `apex_subscribed_components` prüfen – alle `UP_TO_DATE`.
- Wertelisten-Pflege: Kunden-Wertelisten (KUND_*) in THG-KUNDEN unter Administration > Wertelisten (generiert mit `Apex/generator/gen_wertelisten_kunden.py`); allgemeine Wertelisten (ALLG_*) in THG-ALLGEMEIN unter Look Up Values.
- Gemeinsame Workspace-Dateien `thg.css`, `thg.js` (Logo-Klick → Prüfung ungespeicherter Änderungen → Portal-Startseite), Logos in `Apex/workspace-files/`; nach Änderung `python3 build_install.py` und das erzeugte `install_workspace_files.sql` einspielen – kein App-Import nötig.
- Mandant: wird im Portal gewählt (Navigationsleiste) und gilt über Session Sharing (globale Items `MANDANT_*`) in allen Apps, bis er im Portal gewechselt wird. Sub-Apps belegen nur vor (App-Prozess „Mandant vorbelegen“), wechseln nie; Logo/Bannerfarbe je Mandant. Einrichtung neuer Sub-Apps: `python3 Apex/generator/mandant_in_apps.py`.
  Mandantencodes: `EDV` (ThG - edv GmbH, grün) und `HOLDING` (Thomas Geßlbauer GmbH, Eigentümerin der ThG - edv GmbH, blau). Die Bannerfarbe hängt in `thg.css` am Code (`data-mandant`) – bei Codeänderung CSS und Grunddatenskripte 17/18/20 mitziehen.
  Kunden und Artikel sind mandantenübergreifend; Finanz (FAKT_*) ist mandantenabhängig (`RECH_MAND_ID = :MANDANT_ID`).
- Theme-Stil: Standard Redwood Light; Stilauswahl im Portal speichert den Stil beim Mitarbeiter (`MITA_THEME_STIL`) und setzt ihn per `apex_theme.set_session_style` für die Sitzung in allen Apps (App-Prozess „Theme-Stil“ in jeder App, einmal je Anmeldung). Bannerfarbe kommt in allen Stilen vom Mandanten (`thg.css`).
- **Finanz (THG-FINANZ 20050)** im Stil von Kundenstamm/Marchler (2026-10-24): Seite 1 Dashboard (Kennzahlen Umsatz/Rechnungen laufendes Jahr mit Vorjahr,
  offene, überfällige, Entwürfe; Liste offene Rechnungen; Umsatz je Monat mit Vorjahr, Top 10 Kunden – Klick öffnet die gefilterte Liste), Seite 10 Rechnungsliste mit
  Facettensuche (Status, Überfällig, Jahr, Monat, Kunde; Nummer umrahmt als Link) – beide aus `Apex/generator/finanz_dashboard_liste.py`;
  Seite 11 Registerkarten direkt unter der Titelleiste (`thg-rds`, „Alle“ als Icon, Regionen ohne Kopf), Artikel Seite 20 Liste mit Facetten (Aktiv, Gruppe, Einheit, MwSt.),
  Seite 21 Registerkarten Stammdaten/Kommentar und Änderungsinformationen. Rechnungsliste zeigt nur Netto (Brutto und Hinweis ausgeblendet). Regionstitel in Mandantenfarbe (`thg.js`: 20020, 20050).
- Rechnungsstatus: ENTWURF → GEDRUCKT („Offen – gedruckt“, bei „Rechnung drucken“) → GESENDET („Offen – gesendet“, nach E-Mail-Versand aus der App – geplant)
  → TEILBEZAHLT / BEZAHLT automatisch aus den Zahlungen (Trigger ZAHL_STATUS_AIUD, DDL 31/32/34; ohne Zahlung bleibt GEDRUCKT bzw. GESENDET);
  GEDRUCKT und GESENDET gelten überall als offen (überfällig, Dashboard, Storno). Anzeigetext: `FAKT_RECHNUNG.status_text`.
  STORNIERT über Button „Rechnung stornieren“ (Dialogseite 15 mit Pflicht-Grund – kein Inline-Dialog, der blitzte auf; `FAKT_RECHNUNG.stornieren`; nur GEDRUCKT/GESENDET ohne Zahlung, behält Nummer/Datum,
  gesperrt, PDF mit Wasserzeichen STORNIERT, Grund in der Historie). Löschen nur Entwurf bzw. letzte vergebene Rechnung.
  teilbezahlte Rechnungen zählen als offen/überfällig und zum Umsatz.
- Kopf der Rechnung (Seite 11): Kopieren, Stornieren, Löschen im Kebab-Menü „Weitere Aktionen“ (⋮, versteckte Buttons `thg-akt-*`,
  Funktion `im_menue` in `gen_finanz.py`). Breadcrumb: letzter Pfadeintrag per `thg.css` ausgeblendet (sonst „Rechnung \ Rechnung 2026 - 203“).
- „Rechnung kopieren“ (Kebab-Menü im Kopf jeder Rechnung, Seite 11): `FAKT_RECHNUNG.kopieren` legt einen neuen Entwurf 1:1 an (Empfänger, Texte, Kennzeichen,
  Haupt-/Unterpositionen; ohne Nummer, Datum, Fälligkeit, Betreff, Zahlungen) und öffnet ihn.
- Drucken: im Entwurf „Rechnungsvorschau“ (PDF mit Wasserzeichen VORSCHAU, beliebig oft, bleibt Entwurf) und „Rechnung drucken“ (= abschließen: Nummer und
  Rechnungsdatum, danach öffnet das PDF automatisch – Branch mit `P11_PDF_OEFFNEN`, DA `pdf-oeffnen`); abgeschlossen „Rechnung drucken“ → PDF; nach „Rechnung bearbeiten“ schließt „Rechnung drucken“ die Bearbeitung ab
  (Änderungen gespeichert, `P11_BEARBEITEN` zurückgesetzt, Historie „Bearbeitung abgeschlossen“, Rechnung wieder gesperrt).
- Historie (Registerkarte nach Dokumente, als Timeline – Report-Vorlage `@/timeline`, Ereignis-Typ/Icon/Farbe je Aktion): `FAKT_RECHNUNG_HISTORIE` (DDL 33), Trigger auf Rechnung/Positionen/Zahlungen + Druck (Seite 12) protokollieren wer/wann/was.
- Dokumente (Registerkarte nach Zahlungen): `FAKT_RECHNUNG_DOKUMENTE` (DDL 35) – jeder Rechnungsdruck wird als PDF-Version abgelegt
  (`FAKT_RECHNUNG_DOKUMENT.ablegen` auf Seite 12): neue Version beim ersten Druck und nach „Rechnung bearbeiten“ bzw. Storno, ältere bleiben;
  Anzeige im PDF-Dialog Seite 13 mit `P13_RDOK_ID` (Seite 12 liefert dann den abgelegten Druck). Vorschauen werden nicht abgelegt.
- Vor-/Schlusstext: Rich-Text-Editor (HTML; Werkzeugleiste wie Positionsbeschreibung: Überschrift, Fett, Kursiv, Listen, Rückgängig – `RTE_LEISTE` in gen_finanz.py); Klartext-Altdaten werden nur angezeigt umgewandelt
  (`FAKT_RECHNUNG.text_html`) und erst beim nächsten Speichern der Rechnung als HTML gespeichert. PDF: Fett/Kursiv innerhalb
  der Zeile (`block_rich`), auch in Positionsbeschreibungen.
- Rechnungsdruck: Seite 13 (PDF-Anzeige, Drucken/Herunterladen), Paket `FAKT_RECHNUNG_PDF` (DDL 24),
  Layout wie die Kingbill-Rechnungen in `Vorlagen/Ausgangsrechnungen` (Hauptposition ohne Unterpositionen wie eine Kingbill-Position mit Einzelpreis/Menge/Einheit, „Art.-Nr.“).
- Rechnungen EDV 2026 - 1 bis 13 aus Kingbill übernommen (2026-10-24, `Vorlagen/Access Datenbank Migration/access_rechnungen.py`, mit Zahlungen, alle bezahlt;
  `RECH_ALT_ID` = Kingbill-ID); vorher alle Test-Rechnungen gelöscht.
- Rechnungen HOLDING ab 01.04.2025 (2025 - 115 … 2026 - 202, 88 Stück) aus der Kingbill-Datenbank der Thomas Geßlbauer GmbH übernommen
  (2026-10-24, `Vorlagen/Access Datenbank Migration/access_rechnungen_holding.py`, Summen gegen Kingbill abgeglichen; Nummer = Betreff,
  Kingbill-ID 833 (Duplikat 188) nicht übernommen, 186 als bezahlt, 202 offen); dafür 6 Kunden ohne Kingbill-Stammsatz angelegt
  (Hohl, Ingenieurbüro Forst/Holz, C.S.M., Elektro ON Balk, Dr. Barbara Lenhard, ThG - edv GmbH). Kingbill-IDs je Mandant eindeutig (DDL 30).
  Nummernkreise: EDV 2026 = 13, HOLDING 2025 = 171, 2026 = 202.
- Zahlungsreferenz (DDL 38): RF-Referenz `RECH_ZAHLUNGSREFERENZ` (eindeutig) = RF + Prüfziffern + Firma (1 = EDV, 2 = HOLDING) + Kundennummer
  + Jahr + Nummer 5-stellig, erzeugt in `FAKT_RECHNUNG.abschliessen`; ältere Rechnungen haben keine. Ausdruck: „Bitte bei Online-Überweisungen
  die Zahlungsreferenz **RF75 2100 2212 0260 0203** angeben.“ und rechts darunter EPC-QR-Code „Zahlen mit Code“ (Empfänger = Mandantenname,
  bevorzugte IBAN, offener Betrag, Referenz; `APEX_BARCODE`) – je Kunde abschaltbar (`KUND_IST_QR_CODE`, THG-KUNDEN Rechtliches und Konditionen).
  Anzeige auf Seite 11 (Allgemein), Vorschlag im Dialog Zahlungseingang.
- **Gutschriften** (Gutschriftverfahren, z. B. Hays – Kunde 100227; Seiten 40 Liste mit Facettensuche / 41 Gutschrift mit Registerkarten
  Gutschrift, Dokumente, Historie / 42 Dokument ausliefern / 43 PDF-Fenster; Tabellen `FAKT_GUTSCHRIFTEN`, `FAKT_GUTSCHRIFT_DOKUMENTE` (DDL 39),
  Package `FAKT_GUTSCHRIFT` (DDL 40), Historie `FAKT_GUTSCHRIFT_HISTORIE` (DDL 42), Nummernkreis/Bestand/View (DDL 43)). Ablauf wie eine Rechnung:
  Anlegen (Kunde) → Stundenzettel hochladen (vergibt interne Nummer „GS 2026 - 1“, Nummernkreis GUTSCHRIFT je Mandant/Jahr, und Gutschriftdatum)
  → „An Aussteller gesendet“ → Gutschrift des Ausstellers hochladen (`aus_pdf`, `DBMS_VECTOR_CHAIN.UTL_TO_TEXT`: Nummer beim Aussteller, Datum,
  fällig, Netto, Betrag, Skonto %, Verwendungszweck `/GSV/<Belegnummer>/<Vertragsnummer>`) → Bankabgleich bzw. „Bezahlt am“ → Bezahlt.
  Status ENTWURF → GESENDET → OFFEN → BEZAHLT (Trigger). Doppelte Datei/Nummer beim Aussteller → nur Hinweis; Löschen nur Entwurf ohne
  Nummer oder die zuletzt vergebene. Dashboard: `FAKT_BELEGE_V` (Rechnungen + erhaltene Gutschriften: offen wie Rechnung offen, bezahlt
  = Umsatz; auch Kundenstamm-Dashboard und Kopfinfo des Kunden, Link je Belegart auf Seite 11 bzw. 41). Hays-Gutschriften 06–10/2026 übernommen (GS 2026 - 1 … 5, `01_Finanz/Buchhaltung - ThG-edv/01_Belege/02_Ausgangsrechnungen/gesendet`).
- **Bankabgleich** (DDL 39, Menüpunkt „Bankdatei hochladen“, Seite 30): CAMT-Datei (camt.052/053/054, ELBA-Export) des Mandanten der Sitzung
  hochladen → `FAKT_BANK.einlesen` (Konto muss eine Bankverbindung des Mandanten sein, Datei je Nachrichten-ID nur einmal, jede Buchung nur
  einmal – `BKUM_SCHLUESSEL`), danach `FAKT_BANK.abgleichen`: Eingänge per 1. RF-Zahlungsreferenz, 2. Rechnungsnummer im Text,
  3. offener Betrag + Auftraggeber ≈ Kunde → Zahlung anlegen („Bankabgleich: …“, Status per Trigger) bzw. gleich hohe Zahlung ±7 Tage
  verknüpfen; bezahlte Rechnung nur als Hinweis (BEREITS_BEZAHLT). Tabellen `FAKT_BANKDATEIEN` (BKDT), `FAKT_BANKUMSAETZE` (BKUM).
  „Erneut abgleichen“ prüft offene Eingänge noch einmal; dieselbe Datei noch einmal hochladen = erneut abgleichen (keine Fehlermeldung).
  Auch von Hand als bezahlt erfasste Gutschriften (ohne Bankbuchung) und bezahlte Rechnungen mit gleich hoher, noch nicht verknüpfter
  Zahlung anderen Datums werden zugeordnet („vorhandene Zahlung vom …“); Rechnungsnummer ohne Trennzeichen („2026201“) nur, wenn der
  Auftraggeber der Kunde ist (`FAKT_DEBITOR.ist_kunde`). Kein „Debitor anlegen“, wenn der Auftraggeber ein Kunde ist (Hinweis „Rechnung
  bzw. Gutschrift fehlt“). Zahlungseingänge als Interactive Report (Aktionsleiste: Suche, Filter, Download; Status-Farbe und Beleg-Link per HTML-Ausdruck).
  Von Hand zuordnen: Button „Zuordnen“/„Ändern“ je Zeile → Dialog Seite 31 (Regionen Zahlungseingang, „Debitor wählen“ (Zuweisen) und
  „Rechnung bzw. Gutschrift wählen“, je Interactive Report, Zahler/Kunde/Betrag passend zuerst; Button „Neuen Debitor aus der Buchung
  anlegen“ hebt eine Zuordnung auf und öffnet Seite 51 im Hauptfenster) → `FAKT_BANK.zuordnen` (gleich hohe Zahlung verknüpfen, offene Rechnung: Zahlung „Bankabgleich (von Hand)“
  anlegen, schon bezahlt: nur verknüpfen) bzw. „Zuordnung aufheben“ (`FAKT_BANK.aufheben`, löscht nur vom Abgleich angelegte Zahlungen);
  von Hand aufgehobene Buchungen ordnet der automatische Abgleich nicht wieder zu. Holding-Datei 202699999 (3).xml am 25.10.2026 eingelesen (HEROLD → 2026 - 202).
- **Debitoren** (DDL 45, Menüpunkt Debitoren, Seiten 50 Liste mit Facetten / 51 Debitor mit Registerkarten Stammdaten und Zahlungen):
  Zahler ohne Rechnung/Gutschrift (z. B. Mieter) je Mandant – Name, Bezeichnung, Betrag, Intervall (`LOV_DEBITOR_INTERVALL` im Portal),
  fällig ab/bis, IBAN des Zahlers, optional Kunde. Fällige Posten (`FAKT_DEBITOR_POSTEN`) erzeugt `FAKT_DEBITOR.posten_erzeugen` bis Ende
  des nächsten Monats (beim Öffnen von 50/51 und im Abgleich); Speichern plant künftige Posten neu (`planen`, bisherige Beträge bleiben).
  Zahlungen (`FAKT_DEBITOR_ZAHLUNGEN`) nur aus der Bankdatei: `FAKT_BANK.abgleichen` weist nach Rechnungen/Gutschriften offene Eingänge per
  IBAN bzw. Name des Zahlers (`name_passt`, Reihenfolge egal) zu → Status DEBITOR (Anzeige „Zugeordnet“ wie bei Rechnungen, damit sich alle zugeordneten ausblenden lassen), IBAN wird gemerkt.
  Registerkarte Zahlungen: Fälligkeiten mit Zahlungsstand (`FAKT_DEBITOR_POSTEN_V`, Zahlungen decken die ältesten Posten zuerst),
  Zahlungseingänge mit „Aufheben“, offene Bankeingänge mit „Zuweisen“ (Request-Links, danach Karte Zahlungen über `P51_RDS_START`).
  Seite 30: Button „Debitor anlegen“ je nicht zuordenbarem Eingang (`FAKT_DEBITOR.aus_buchung`, öffnet Seite 51). Löschen gibt Buchungen frei.
- Zahlungen (Tab auf Seite 11): Timeline – zuerst „Rechnung erstellt“ mit offenem Betrag, dann je Zahlung Betrag/Skonto/Referenz/Bemerkung
  und der danach offene Betrag; Button „Zahlungseingang“ öffnet Dialog Seite 16 (Datum Vorschlag heute, Betrag Vorschlag offener Betrag,
  Skonto, Mahnspesen, Zahlungsreferenz `ZAHL_REFERENZ` (DDL 36) für die spätere automatische Zuordnung, Bemerkung); Klick auf eine Zahlung
  öffnet sie zum Ändern/Löschen; danach lädt Seite 11 neu (Status per Trigger). Das frühere Zahlungsraster entfällt.
- Zahlungen (Tab auf Seite 11): Timeline – zuerst „Rechnung erstellt“ mit offenem Betrag, dann je Zahlung Betrag/Referenz/Bemerkung und der
  danach offene Betrag (grün = bezahlt, orange = noch offen); Button „Zahlungseingang“ (nur offen/teilbezahlt) öffnet Dialog Seite 16
  (Datum Vorschlag heute, Betrag Vorschlag offener Betrag, Zahlungsreferenz `ZAHL_REFERENZ` (DDL 36) für die spätere automatische Zuordnung,
  Bemerkung); Klick auf eine Zahlung öffnet sie zum Ändern/Löschen; danach lädt Seite 11 neu. Kein Skonto/Mahnspesen (DDL 37 entfernt).
- Rechnung (THG-FINANZ Seite 11): Regionen Allgemein, Kunde (mit Anschrift-Vorschau und Lieferadresse), Vortext, Positionen, Schlusstext, Zahlungen;
  darüber eine Tab-Leiste (Region Display Selector, erster Tab „Alle anzeigen“).
- Rechnungspositionen (THG-FINANZ Seite 11): Haupt- und Unterpositionen in `FAKT_RECHNUNGSPOSITIONEN` (`RPOS_HAUPT_RPOS_ID` leer = Hauptposition;
  Hauptpositionen 1, 2, 3 …, Unterpositionen je Hauptposition 10, 20, 30 …; `RPOS_UK` = Rechnung + Hauptposition + Position).
  Die Positionsnummern werden nicht eingegeben: sie ergeben sich aus der Reihenfolge im Baum (Drag & Drop, AJAX `POS_VERSCHIEBEN`) und werden
  nach Verschieben/Löschen lückenlos neu vergeben; dabei kann eine Position auch Unter- bzw. Hauptposition werden.
  Summe der Hauptposition: Summe der nicht optionalen Unterpositionen abzgl. Rabatt bzw. die Pauschalsumme (`RPOS_PAUSCHALSUMME`).
  Eine Hauptposition hat in der Maske und am Ausdruck keinen eigenen Einzelpreis/Menge/Einheit/MwSt. (gespeichert: Menge 1, Einzelpreis 0);
  ohne Unterpositionen zählt nur ihre Pauschalsumme. Nach jeder Änderung `FAKT_RECHNUNG.summen_berechnen`. Rabatt/Pauschale werden anteilig auf die
  Steuersätze der Unterpositionen verteilt (`FAKT_RECHNUNG_MWST_V`).
  Maske: links Baum der Positionen (Hauptposition/Unterposition anlegen, kopieren – `FAKT_RECHNUNG.position_kopieren`, Hauptposition mit allen
  Unterpositionen, Kopie direkt dahinter –, löschen, verschieben, Unterpositionen ein-/ausklappen), darunter die Summen je Steuersatz, rechts die Felder der gewählten Position (`P11_POS_*`,
  per AJAX `POS_LADEN`/`POS_SPEICHERN`/`POS_LOESCHEN`; Hauptposition: Name, Rabatt, Summe, Pauschalsumme; Unterposition: alle Felder); Unterpositionen
  werden im Baum gewählt und rechts bearbeitet (Raster der Unterpositionen und Dialog Seite 14 entfernt, 2026-10-25);
  Artikel-Auswahl als Popup LOV mit Gruppe/Artikelnummer/Name (`LOV_ARTIKEL`). Änderbar nur im Entwurf oder nach „Rechnung bearbeiten“, sonst nur Anzeige.
- **Kundenstamm (THG-KUNDEN 20020)** – Aufbau wie im Projekt Marchler (App 10020), aber schlanker: keine Hauptgruppe/Branchen/Unterkategorien,
  keine Mandanten je Kunde (Kunden mandantenübergreifend), keine Bemerkung, keine Kundenberichte/Auswertungen.
  Seite 1 Dashboard (Kennzahlen-Karten aktive/neue Kunden, Umsatz, Kunden mit Umsatz, offene Rechnungen; Liste offene Rechnungen; Diagramme Umsatz je Monat mit Vorjahr,
  Top 10 Kunden, aktive Kunden nach Land/Bundesland – Rechnungen aus `FAKT_RECHNUNGEN_V` des Mandanten der Sitzung, ohne Entwurf/storniert; Klick öffnet Kundenliste/Kunde/Rechnung in 20050),
  Seite 10 Kundenliste (Facetten Status, Land, PLZ von–bis und Bundesland nur AT, Ort, Kunde seit Jahr), Seite 11 Kunde mit Registerkarten
  (Alle als Ebenen-Icon, Stammdaten, Kommunikation, Rechtliches und Konditionen, Konzern und Sonstiges, Adressen, Kontakte, Dokumente; Kurzname optional, eindeutig),
  Kopfinfo (Rechnungen, Umsatz netto, offen, letzte Rechnung mit Link, Kundenbetreuer) und Änderungsinformationen inkl. Detaildaten (Wiener Zeit);
  Schubladen 14 Adresse, 15 Kontakt, 16 Dokument, 19 Kommunikation; 17/18 Dokument herunterladen/anzeigen.
  Dokumente je Mandant: DDL 27 (`KUND_DOKUMENTARTEN` DART, `KUND_KUNDEN_DOKUMENTE` KDOK), Pflege der Dokumentarten unter Wertelisten (Seiten 190/191).
  Wertelisten: Abteilungen, Funktionen, Rechtsformen, Standorttypen, Betreuungsrollen, Dokumentarten (`Apex/generator/gen_wertelisten_kunden.py`).
  Übernommen 2026-10-24 per Skript aus den Marchler-Quellen; Weiterentwicklung jetzt direkt in den Dateien unter `Apex/thg-kunden/pages`.
- Gemeinsame Bausteine in `thg.css`/`thg.js` (aus Marchler): Registerkarten `thg-rds` (Alle-Icon, erste Karte beim Öffnen), `thg-ohne-titel`, `thg-kundenname`,
  `thg-kundennr`, `thg-badge`, Kennzahlen `#kennzahlen`, PLZ-Facette `thg-plz-bereich`, Regionstitel in Mandantenfarbe (`thg-region-farbig`, App-Liste in `thg.js`, derzeit 20020),
  inaktive LOV-Einträge („ – inaktiv“) werden ausgeblendet, Startkarte der Registerkarten per Seitenelement `P<Seite>_RDS_START` (Beschriftung), Dialoge übernehmen den Mandanten der aufrufenden Seite.
- **Als App installierbar (PWA):** nur das Portal 20000 (`progressiveWebApp` in `thg-portal/application.apx`, Scope `/ords/r/thgerp/` – deckt alle ThGERP-Apps
  inkl. Anmeldung ab und ist genauer als der Scope `/ords/` der SIPA-App auf demselben Host). Icons `app-icon-*.png` (aus `Apex/workspace-files/thg-app-icon.svg`,
  192 randlos/maskable) in allen Apps unter `shared-components/static-files/icons/`.
- **Navigationsmenü** in allen Apps standardmäßig aufgeklappt (Template-Option `js-defaultCollapsed` entfernt, `thg.js` setzt die gemerkte Vorgabe je Seite zurück).
- Quellen im APEXlang-Format; Einspielen per SQLcl `apex validate` + `apex import`. Vorher in derselben SQLcl-Sitzung
  `apex_application_install.set_keep_sessions(p_keep_sessions => true)` – sonst löscht der Import die Sitzungen der App (Anwender muss sich neu anmelden).
- `Apex/strategic-planner` ist Vorlage und wird nicht in Git eingecheckt.

## Git
- Repository: https://github.com/thg27/ThGERP (Branch `main`)
- Nach Änderungen committen, Commit-Nachricht beschreibt den Inhalt

## Wissensdatenbank
- Die Wissensdatenbank ist projektübergreifend und liegt zentral auf dem Netzlaufwerk: `//10.10.10.240/ThG_edv/Wissensdatenbank` (macOS: `/Volumes/ThG_edv/Wissensdatenbank`). Sie gehört nicht zum Repository ThGERP.
- Sie sammelt Praxiswissen (Oracle SQL, PL/SQL, APEX, SQLcl, ORDS, Git/GitHub, Datenmodell, Troubleshooting); Aufbau und Konventionen in `README.md` dort.
- Laufend pflegen: Wenn bei der Arbeit eine Lösung, ein Muster, ein Stolperstein oder eine Fehlerursache gefunden wird, die wieder vorkommen kann, dort einen Eintrag anlegen oder den bestehenden aktualisieren und im Index (`README.md` des Bereichs) eintragen. Neue Bereiche bei Bedarf ergänzen.
- Vor der Lösung eines Problems zuerst in der Wissensdatenbank nachsehen.
- Ist das Laufwerk nicht eingebunden, den Ordner zuerst verbinden (Finder > Mit Server verbinden > `smb://10.10.10.240/ThG_edv`).
