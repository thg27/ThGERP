# Testskripte (nur DEV)

Testdaten sind eindeutig markiert (Kundennummer `TEST-nnn`, Adressen `Teststraße`) und werden nach dem Test wieder gelöscht.

| Skript | Inhalt |
|---|---|
| kunden_testdaten_anlegen.sql | 60 Kunden (Firma/Privat, alle Status, Rechtsformen, Zahlungsbedingungen), 55 mit Hauptsitz-Adresse in 9 Ländern, 10 mit Konzernmutter, 3 mit abweichendem Rechnungsempfänger |
| kunden_testdaten_pruefen.sql | Listenabfrage Seite 10 (Duplikate, Joins), Facetten-Verteilungen, LOV_KUNDEN, Negativtests aller Constraints/Trigger, Audit-Spalten |
| kunden_testdaten_loeschen.sql | Entfernt alle Testkunden inkl. Standorte und Adressen, Kontrolle 0/0 |

Ausführen mit dem SQLcl-Client: `printf '@<skript>\nexit\n' | sql -S -name sipa@pdb-thg`
