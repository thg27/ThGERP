-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 99 – Entfernen aller Objekte (ACHTUNG: löscht Daten!)
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

drop table ADMIN_APPLIKATIONEN cascade constraints purge;
drop table KUND_KUNDEN_UNTERKATEGORIEN cascade constraints purge;
drop table KUND_KUNDEN_BRANCHEN cascade constraints purge;
drop table KUND_UNTERKATEGORIEN cascade constraints purge;
drop table KUND_BRANCHEN cascade constraints purge;
drop table KUND_KUNDENGRUPPEN cascade constraints purge;
drop table KUND_ABTEILUNGEN cascade constraints purge;
drop table KUND_FUNKTIONEN cascade constraints purge;
drop table KUND_ANSPRECHPARTNER_KOMMUNIKATION cascade constraints purge;
drop table KUND_ANSPRECHPARTNER cascade constraints purge;
drop table KUND_STANDORT_KOMMUNIKATION cascade constraints purge;
drop table KUND_STANDORTE cascade constraints purge;
drop table KUND_KUNDEN_MITARBEITER cascade constraints purge;
drop table KUND_KUNDEN cascade constraints purge;
drop table KUND_BETREUUNGSROLLEN cascade constraints purge;
drop table KUND_STANDORT_TYPEN cascade constraints purge;
drop table KUND_RECHTSFORMEN cascade constraints purge;
drop table ALLG_ADRESSEN cascade constraints purge;
drop table ALLG_ADRESSREGISTER cascade constraints purge;
drop table ALLG_MITARBEITER_KOMMUNIKATION cascade constraints purge;
drop table ALLG_MITARBEITER cascade constraints purge;
drop table ADMIN_MANDANTEN cascade constraints purge;
drop table ALLG_KOMMUNIKATIONSARTEN cascade constraints purge;
drop table ALLG_ZAHLUNGSBEDINGUNGEN cascade constraints purge;
drop table ALLG_LAENDER cascade constraints purge;
drop sequence KUND_NUMMER_SEQ;
drop package KUND_STAMMBLATT;
drop package AS_PDF;
drop package DDL_UTIL;
