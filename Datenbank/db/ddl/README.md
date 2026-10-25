# Kundenstamm-Datenmodell (Gruppen KUND, ALLG)

Installation (SQLcl, nur DEV-Verbindung):

    cd db/ddl
    sql <verbindung>
    @00_install.sql

| Datei | Inhalt |
|---|---|
| 00_install.sql | ruft 01–42 auf (ohne 14 und 25), bricht bei Fehler ab |
| 01_tabellen.sql | Tabellen, PK/UK/Check-Constraints |
| 02_fremdschluessel.sql | Fremdschlüssel + FK-Indizes |
| 03_indizes.sql | fachliche Unique-Indizes, Suchindizes |
| 04_trigger.sql | PK (SYS_GUID) + Audit-Spalten, Prüfung manuelle Adressen |
| 05_kommentare.sql | Tabellen- und Spaltenkommentare |
| 06_stammdaten.sql | Grunddaten der Lookup-Tabellen |
| 07_applikationen.sql | ADMIN_APPLIKATIONEN (Modul-Apps der Portal-Startseite) inkl. Trigger, Kommentare, Grunddaten; wiederholbar (legt an bzw. gleicht Spalten/Constraints ab), einzeln ausführbar |
| 08_kunden_status.sql | KUND_STATUS nur noch AKTIV/INAKTIV (GESPERRT → INAKTIV, Check-Constraint); wiederholbar |
| 09_kunden_nummer.sql | Kundennummer 6-stellig automatisch (KUND_NUMMER_SEQ, Trigger KUND_BIU), unveränderlich; wiederholbar |
| 10_adressen_quelle_migration.sql | Adressquelle MIGRATION (Altdaten, auch AT ohne Register); wiederholbar |
| 11_ddl_util.sql | Hilfspaket DDL_UTIL für wiederholbare Skripte (Tabelle/Spalte/Constraint/Index/Trigger sicherstellen) |
| 12_laender.sql | ALLG_LAENDER um die Länder der Altdaten ergänzt (34 Länder); wiederholbar |
| 13_kundenstamm_erweiterung.sql | Kundengruppen, Branchen, Unterkategorien, Kunde-Branche/-Unterkategorie, Abteilungen, Funktionen; Zusatzspalten Kunde/Ansprechpartner; wiederholbar (generiert) |
| 15_kundenstammblatt.sql | Package AS_PDF (lib/as_pdf, MIT) und KUND_STAMMBLATT: Kundenstammblatt als PDF (`KUND_STAMMBLATT.pdf(kund_id)`), genutzt von App 20020 Seite 12; wiederholbar |
| 16_rechtsformen_ausland.sql | Ausländische Rechtsformen der Altdaten (d.o.o., d.d., s.p., s.r.o., a.s., Kft., Zrt., Sp. z o.o., S.R.L., S.p.A., S.A., Ltd., eGen); wiederholbar |
| 17_mandanten.sql | ADMIN_MANDANTEN (THG-EDV GmbH, Thomas Geßlbauer GmbH) und in ALLG_MITARBEITER Benutzername (Login) und Standard-Mandant; wiederholbar |
| 18_mandanten_firmendaten.sql | Firmendaten der Mandanten (Adresse, UID, Firmenbuch), ADMIN_MANDANT_BANKVERBINDUNGEN, ADMIN_MANDANT_KOMMUNIKATION; Daten aus den Ausgangsrechnungen; wiederholbar |
| 19_artikelstamm.sql | Artikelstamm (ARTI): Artikel, Artikelgruppen, Zusatzfelder/-werte, Dateien; ALLG_EINHEITEN, ALLG_MWST_SAETZE, ALLG_TEXTVORLAGEN; Grunddaten; wiederholbar (generiert: generator/gen_19_20_artikel_fakturierung.py) |
| 20_fakturierung.sql | Fakturierung (FAKT): Nummernkreise, Rechnungen, Rechnungspositionen, Zahlungen; Nummernkreise 2026; wiederholbar (generiert) |
| 21_finanz.sql | Package FAKT_RECHNUNG (Empfänger übernehmen, Summen der Haupt-/Unterpositionen, Positionsnummer, Abschließen mit Nummernkreis, Zahlungsstatus), Views FAKT_RECHNUNGEN_V, FAKT_RECHNUNG_MWST_V; Löschen (Entwurf bzw. letzte Rechnung); Mitarbeiter, Textvorlagen, Portal-Kachel THG-FINANZ; wiederholbar |
| 22_finanz_nummernschutz.sql | Trigger RECH_NUMMER_BUD, NKRS_NUMMER_BU: Rechnungsnummer/Nummernkreis nur über das Package FAKT_RECHNUNG änderbar, abgeschlossene Rechnungen nur als letzte löschbar; wiederholbar |
| 23_mitarbeiter_theme.sql | ALLG_MITARBEITER.MITA_THEME_STIL: Theme-Stil je Mitarbeiter (gilt nach dem Login in allen Apps); wiederholbar |
| 24_rechnung_pdf.sql | Package FAKT_RECHNUNG_PDF: Rechnung als PDF (AS_PDF) im Layout der bisherigen Ausgangsrechnungen je Mandant (Logo, Anschrift, Positionen mit Rich-Text-Beschreibung, Summen je Steuersatz, Fuß mit Banken/Firmenbuch); 2026-10-24 an die Kingbill-Rechnungen (Vorlagen/Ausgangsrechnungen) angeglichen: Positionen ohne Unterpositionen mit Einzelpreis/Menge/Einheit und „Art.-Nr.“, Leistungszeitraum rechts im Kopf, Fälligkeit unter den Summen, Summen „14 155,00“; wiederholbar |
| 25_positionen_kapitel.sql | Rechnungspositionen je Kapitel nummerieren: RPOS_UK neu auf (Rechnung, Kapitel, Position) – je Kapitel 10, 20, 30 …, Positionen ohne Kapitel am Anfang; danach 21 und 24 erneut ausführen; wiederholbar. **Überholt durch 26** – wird von `00_install.sql` nicht mehr aufgerufen |
| 26_haupt_unterpositionen.sql | Rechnungspositionen als Haupt- und Unterpositionen: `RPOS_HAUPT_RPOS_ID` (Selbstreferenz, löscht kaskadierend), `RPOS_SUMME_UNTERPOS`, `RPOS_PAUSCHALSUMME`; RPOS_UK neu auf (Rechnung, Hauptposition, Position); Kapitel/Unterkapitel entfallen, Bestand wird zu Hauptpositionen 1, 2, 3 …; danach 21 und 24 erneut ausführen; wiederholbar |
| 27_kunden_dokumente.sql | Dokumente je Kunde und Mandant: `KUND_DOKUMENTARTEN` (DART, Werteliste mit Grunddaten) und `KUND_KUNDEN_DOKUMENTE` (KDOK, Datei als BLOB, Größe per Trigger); Betreuungsrolle `KB` Kundenbetreuer (Kundendetail 20020); aus Marchler DDL 38; wiederholbar |
| 28_artikel_in_finanz.sql | Artikelstamm in THG-FINANZ: Portal-Kachel THG-ARTIKEL (20040) entfernt, Kachel Finanz ergänzt; Artikel laut den Kingbill-Rechnungen 2026 angelegt/angepasst (212 Std., 217 3.000 €, neu 218 EDV-Betreuung monatlich, 503 Microsoft Office 365, 600 Apple MacBook Air, Gruppe HARDWARE), Positionen der übernommenen Rechnungen verknüpft; wiederholbar |
| 29_artikel_ohne_zusatzfelder_dateien_bild.sql | Artikelstamm verschlankt: Tabellen ARTI_ZUSATZFELDER, ARTI_ARTIKEL_ZUSATZWERTE, ARTI_ARTIKEL_DATEIEN und Spalten ARTI_BILD* entfernt (Skript 19 legt sie nicht mehr an); wiederholbar |
| 30_alt_id_je_mandant.sql | Kingbill-IDs je Mandant (eigene Kingbill-Datenbank je Firma): Unique-Index RECH_ALT_ID_UI (je Mandant, nur Zeilen mit Altsystem-ID – kein zusammengesetzter Constraint, sonst nur eine neue Rechnung je Mandant), ZAHL_ALT_ID nur indiziert; wiederholbar |
| 31_zahlungsstatus_trigger.sql | Compound Trigger ZAHL_STATUS_AIUD: nach jeder Änderung an FAKT_ZAHLUNGEN Status der Rechnung (GEDRUCKT bzw. GESENDET/TEILBEZAHLT/BEZAHLT) neu bestimmen – das Zahlungsraster speichert per AJAX ohne Seitenprozesse; wiederholbar |
| 32_status_teilbezahlt.sql | Rechnungsstatus TEILBEZAHLT: Check-Constraint, Package/View (ruft 21 auf), bestehende Rechnungen neu eingestuft; wiederholbar |
| 33_rechnung_historie.sql | Historie der Rechnung: Tabelle FAKT_RECHNUNG_HISTORIE (RHIS, ohne FK), Package FAKT_HISTORIE, Trigger auf Rechnung/Positionen/Zahlungen (wer, wann, was: alt → neu); wiederholbar |
| 34_status_gedruckt.sql | Status OFFEN aufgeteilt: GEDRUCKT („Offen – gedruckt“, nach „Rechnung drucken“) und GESENDET („Offen – gesendet“, nach E-Mail-Versand); Check-Constraint, bestehende OFFEN → GEDRUCKT (ohne Historie), ruft 21 und 33 auf; wiederholbar |
| 35_rechnung_dokumente.sql | Dokumente der Rechnung: Tabelle FAKT_RECHNUNG_DOKUMENTE (RDOK), Package FAKT_RECHNUNG_DOKUMENT – jeder Rechnungsdruck als PDF-Version abgelegt (neue Version beim ersten Druck und nach „Rechnung bearbeiten“/Storno), ältere Drucke bleiben; wiederholbar |
| 36_zahlungsreferenz.sql | Zahlungsreferenz je Zahlungseingang (`ZAHL_REFERENZ`, 140 Zeichen, Index für die automatische Zuordnung), Referenz in der Historie (ruft 33 auf); wiederholbar |
| 37_zahlung_ohne_skonto_mahnspesen.sql | Spalten ZAHL_SKONTO und ZAHL_MAHNSPESEN entfernt (nur wenn leer); Bezahlt/Status nur aus ZAHL_BETRAG, ruft 21 und 33 auf; wiederholbar |
| 38_zahlungsreferenz_rechnung.sql | Zahlungsreferenz der Rechnung (RF-Referenz ISO 11649: Firma, Kundennummer, Jahr, Nummer), eindeutig, beim Abschließen erzeugt, auf dem Ausdruck; ruft 21 auf; wiederholbar |
| 39_bankabgleich.sql | Bankabgleich: Tabellen FAKT_BANKDATEIEN (BKDT), FAKT_BANKUMSAETZE (BKUM), Tabelle FAKT_GUTSCHRIFTEN (GUTS, erhaltene Gutschriften), Package FAKT_BANK – CAMT-Datei (camt.052/053/054) einlesen (Konto des Mandanten, jede Buchung nur einmal), Eingänge per RF-Referenz, Rechnungsnummer oder Betrag+Kunde den Rechnungen zuordnen (Zahlung anlegen bzw. vorhandene verknüpfen); wiederholbar |
| 40_gutschriften.sql | Erhaltene Gutschriften: Package FAKT_GUTSCHRIFT – PDF hochladen, Text mit DBMS_VECTOR_CHAIN.UTL_TO_TEXT lesen, Aussteller/Nummer/Datum/fällig am/Betrag/Verwendungszweck per Muster vorbelegen; Bankabgleich ordnet Eingänge offenen Gutschriften zu (Skript 39); wiederholbar |
| 41_kunde_hays.sql | Kunde Hays AG (Gutschriftverfahren) aus den Angaben der Gutschriften: Anschrift, UID, Telefon/Fax/Web, Ansprechpartnerin; nur wenn fehlend; wiederholbar |
| 42_gutschrift_historie.sql | Historie der Gutschrift: Tabelle FAKT_GUTSCHRIFT_HISTORIE (GHIS, ohne FK), Trigger GUTS_HIST_AIU (Hochgeladen/Angelegt, Geändert, Bezahlt, PDF ersetzt); vorhandene Gutschriften nachgetragen; wiederholbar |
| 99_drop.sql | entfernt alle Objekte (löscht Daten!) |

## Achtung: Namenskonflikt mit dem Schema SIPA

Das Schema SIPA enthält bereits TBL_KUNDE mit Alias KUND und TBL_KUNDE_MITARBEITER.
Constraint-, Index- und Triggernamen sind pro Schema eindeutig. Vor einer Installation
in SIPA prüfen, ob Namen wie KUND_PK, KUND_BIU, KUND_NUMMER_UK bereits existieren –
`create or replace trigger KUND_BIU` würde einen bestehenden gleichnamigen Trigger
auf TBL_KUNDE ersetzen. Empfehlung: in eigenes DEV-Schema installieren.
