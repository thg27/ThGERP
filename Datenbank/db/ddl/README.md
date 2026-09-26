# Kundenstamm-Datenmodell (Gruppen KUND, ALLG)

Installation (SQLcl, nur DEV-Verbindung):

    cd db/ddl
    sql <verbindung>
    @00_install.sql

| Datei | Inhalt |
|---|---|
| 00_install.sql | ruft 01–21 auf (ohne 14), bricht bei Fehler ab |
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
| 21_finanz.sql | Package FAKT_RECHNUNG (Empfänger übernehmen, Summen, Abschließen mit Nummernkreis, Zahlungsstatus), Views FAKT_RECHNUNGEN_V, FAKT_RECHNUNG_MWST_V; Mitarbeiter, Textvorlagen, Portal-Kachel THG-FINANZ; wiederholbar |
| 99_drop.sql | entfernt alle Objekte (löscht Daten!) |

## Achtung: Namenskonflikt mit dem Schema SIPA

Das Schema SIPA enthält bereits TBL_KUNDE mit Alias KUND und TBL_KUNDE_MITARBEITER.
Constraint-, Index- und Triggernamen sind pro Schema eindeutig. Vor einer Installation
in SIPA prüfen, ob Namen wie KUND_PK, KUND_BIU, KUND_NUMMER_UK bereits existieren –
`create or replace trigger KUND_BIU` würde einen bestehenden gleichnamigen Trigger
auf TBL_KUNDE ersetzen. Empfehlung: in eigenes DEV-Schema installieren.
