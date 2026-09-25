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

## Gruppencodes

| Code | Bereich |
|---|---|
| ALLG | Allgemeine, modulübergreifende Stammdaten |
| KUND | Kundenstammdaten |
| ADMIN | Administration der Anwendung (Applikationen, Mandanten, Portal-Konfiguration) |

## Datenbankverbindung

| SQLcl-Verbindung | Benutzer/Schema | Verbindungszeichenfolge |
|---|---|---|
| `wksp_thgerp@pdbthg` | WKSP_THGERP | `dbthgprod.thg-edv.com:1521/pdbthg.sub04191118021.vcnthgprod.oraclevcn.com` |
