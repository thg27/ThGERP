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

prompt Installation abgeschlossen.
