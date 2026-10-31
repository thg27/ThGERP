-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 00 – Installationsskript (ruft alle Teile auf)
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

set define off
set echo on
whenever sqlerror exit failure rollback

@@01_tabellen.sql
@@02_fremdschluessel.sql
@@03_indizes.sql
@@04_trigger.sql
@@05_kommentare.sql
@@06_stammdaten.sql
@@07_applikationen.sql
@@08_kunden_status.sql
@@09_kunden_nummer.sql
@@10_adressen_quelle_migration.sql
@@11_ddl_util.sql
@@12_laender.sql
@@13_kundenstamm_erweiterung.sql
@@15_kundenstammblatt.sql
@@16_rechtsformen_ausland.sql
@@17_mandanten.sql
@@18_mandanten_firmendaten.sql
@@19_artikelstamm.sql
@@20_fakturierung.sql
@@21_finanz.sql
@@22_finanz_nummernschutz.sql
@@23_mitarbeiter_theme.sql
@@24_rechnung_pdf.sql
-- 25_positionen_kapitel.sql entfaellt bei einer Neuinstallation (Kapitel durch Haupt-/Unterpositionen ersetzt, Skript 26)
@@26_haupt_unterpositionen.sql
@@27_kunden_dokumente.sql
@@28_artikel_in_finanz.sql
@@29_artikel_ohne_zusatzfelder_dateien_bild.sql
@@30_alt_id_je_mandant.sql
@@31_zahlungsstatus_trigger.sql
@@32_status_teilbezahlt.sql
@@33_rechnung_historie.sql
@@34_status_gedruckt.sql
@@35_rechnung_dokumente.sql
@@36_zahlungsreferenz.sql
@@37_zahlung_ohne_skonto_mahnspesen.sql
@@38_zahlungsreferenz_rechnung.sql
@@39_bankabgleich.sql
@@40_gutschriften.sql
@@41_kunde_hays.sql
@@42_gutschrift_historie.sql
@@43_gutschrift_ablauf.sql
@@44_offen_netto.sql
@@45_debitoren.sql
@@46_rechnung_in_bearbeitung.sql
@@47_mitarbeiter_office365.sql
@@48_rechnung_versand.sql

prompt Installation abgeschlossen.
