# Tabellen-Aliase (Registry)

Jeder Alias ist 4-stellig und im gesamten Projekt eindeutig. Neue Tabellen hier eintragen, **bevor** das DDL erstellt wird.

| Gruppe | Tabelle | Alias | Beschreibung |
|---|---|---|---|
| ALLG | ALLG_LAENDER | LAND | Länder (ISO-Code), EU-Kennzeichen, Adressregister vorhanden |
| ALLG | ALLG_ZAHLUNGSBEDINGUNGEN | ZBED | Zahlungsziel, Skonto |
| ALLG | ALLG_KOMMUNIKATIONSARTEN | KART | E-Mail, Telefon, Mobil, Fax, Web |
| ALLG | ALLG_MITARBEITER | MITA | Eigene Mitarbeiter (intern) |
| ALLG | ALLG_MITARBEITER_KOMMUNIKATION | MKOM | Kommunikationsdaten Mitarbeiter |
| ALLG | ALLG_ADRESSREGISTER | AREG | Import BEV-Adressregister (AT) |
| ALLG | ALLG_ADRESSEN | ADRE | Verwendete Adressen (Register oder manuell) |
| KUND | KUND_KUNDEN | KUND | Kundenstamm inkl. Konzernhierarchie |
| KUND | KUND_STANDORTE | KSTO | Standorte eines Kunden |
| KUND | KUND_STANDORT_KOMMUNIKATION | SKOM | Kommunikationsdaten Standorte |
| KUND | KUND_ANSPRECHPARTNER | ANSP | Externe Ansprechpartner am Standort |
| KUND | KUND_ANSPRECHPARTNER_KOMMUNIKATION | AKOM | Kommunikationsdaten Ansprechpartner |
| KUND | KUND_KUNDEN_MITARBEITER | KMIT | Zuordnung Mitarbeiter–Kunde je Rolle |
| KUND | KUND_BETREUUNGSROLLEN | BROL | Sachbearbeiter, Projektleiter … |
| KUND | KUND_RECHTSFORMEN | RFRM | GmbH, KG, e.U. … |
| KUND | KUND_STANDORT_TYPEN | STYP | Hauptsitz, Filiale, Lager … |
| KUND | KUND_KUNDENGRUPPEN | KGRP | OEM, Wiederverkäufer, Endkunde |
| KUND | KUND_BRANCHEN | BRAN | Branchen der Kunden |
| KUND | KUND_UNTERKATEGORIEN | UKAT | Unterkategorien je Branche |
| KUND | KUND_KUNDEN_BRANCHEN | KBRA | Zuordnung Kunde–Branche |
| KUND | KUND_KUNDEN_UNTERKATEGORIEN | KUKA | Zuordnung Kunde-Branche–Unterkategorie |
| KUND | KUND_ABTEILUNGEN | ABTE | Abteilungen der Ansprechpartner |
| KUND | KUND_FUNKTIONEN | FUNK | Funktionen der Ansprechpartner |
| ADMIN | ADMIN_APPLIKATIONEN | APPL | APEX-Applikationen (Module) für die Portal-Startseite |
| ADMIN | ADMIN_MANDANTEN | MAND | Mandanten (THG-EDV GmbH, Thomas Geßlbauer GmbH) |
| ADMIN | ADMIN_MANDANT_BANKVERBINDUNGEN | MBNK | Bankverbindungen der Mandanten (Rechnungsfuß) |
| ADMIN | ADMIN_MANDANT_KOMMUNIKATION | MAKO | Kommunikationsdaten der Mandanten (Briefkopf) |
| ALLG | ALLG_EINHEITEN | EINH | Mengeneinheiten (Stk., Std., Pauschale …) |
| ALLG | ALLG_MWST_SAETZE | MWST | Umsatzsteuersätze (0/10/20 %) |
| ALLG | ALLG_TEXTVORLAGEN | TXVL | Textvorlagen für Belege (Zahlungsbedingungen, Vor-/Schlusstext) |
| ARTI | ARTI_ARTIKELGRUPPEN | AGRP | Artikelgruppen |
| ARTI | ARTI_ARTIKEL | ARTI | Artikelstamm |
| ARTI | ARTI_ZUSATZFELDER | ZUSF | Definition der Zusatzfelder am Artikel |
| ARTI | ARTI_ARTIKEL_ZUSATZWERTE | AZUW | Werte der Zusatzfelder je Artikel |
| ARTI | ARTI_ARTIKEL_DATEIEN | ADAT | Dateien (Anhänge) zum Artikel |
| FAKT | FAKT_NUMMERNKREISE | NKRS | Nummernkreise je Mandant, Belegart, Jahr |
| FAKT | FAKT_RECHNUNGEN | RECH | Ausgangsrechnungen (Kopf) |
| FAKT | FAKT_RECHNUNGSPOSITIONEN | RPOS | Rechnungspositionen |
| FAKT | FAKT_ZAHLUNGEN | ZAHL | Zahlungseingänge zu Rechnungen |

## Gruppencodes

| Code | Bereich |
|---|---|
| ALLG | Allgemeine, modulübergreifende Stammdaten |
| KUND | Kundenstammdaten |
| ARTI | Artikelstammdaten |
| FAKT | Fakturierung (Rechnungen, später weitere Belege) |
| ADMIN | Administration der Anwendung (Applikationen, Mandanten, Portal-Konfiguration) |

## Datenbankverbindung

| SQLcl-Verbindung | Benutzer/Schema | Verbindungszeichenfolge |
|---|---|---|
| `wksp_thgerp@pdbthg` | WKSP_THGERP | `dbthgprod.thg-edv.com:1521/pdbthg.sub04191118021.vcnthgprod.oraclevcn.com` |
