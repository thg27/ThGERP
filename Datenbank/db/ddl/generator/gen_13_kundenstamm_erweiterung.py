#!/usr/bin/env python3
"""Erzeugt 13_kundenstamm_erweiterung.sql (wiederholbar, nutzt DDL_UTIL)."""
import sys

AUDIT = lambda a: [
    (f'{a}_CREATED_ON', 'timestamp', 'N', None, 'Audit: angelegt am'),
    (f'{a}_CREATED_BY', 'varchar2(255 char)', 'N', None, 'Audit: angelegt von'),
    (f'{a}_UPDATED_ON', 'timestamp', 'Y', None, 'Audit: zuletzt geaendert am'),
    (f'{a}_UPDATED_BY', 'varchar2(255 char)', 'Y', None, 'Audit: zuletzt geaendert von'),
    (f'{a}_ROW_VERSION', 'number', 'N', None, 'Audit: Versionszaehler (optimistisches Locking)'),
]

def flag(a, name, dflt, kom):
    return (f'{a}_{name}', 'varchar2(1 char)', 'N', f"'{dflt}'", kom)

# Neue Tabellen: (tabelle, alias, kommentar, spalten, constraints, indizes, zusatz_trigger)
# spalte = (name, typ, nullable, default, kommentar); constraint = (name, typ, spec)
TABELLEN = [
 ('KUND_KUNDENGRUPPEN', 'KGRP', 'Kundengruppen (OEM, Wiederverkaeufer, Endkunde)', [
    ('KGRP_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('KGRP_CODE', 'varchar2(20 char)', 'N', None, 'Kuerzel, z.B. OEM, WV, EK'),
    ('KGRP_BEZEICHNUNG', 'varchar2(100 char)', 'N', None, 'Bezeichnung'),
    ('KGRP_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('KGRP', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
  ], [('KGRP_CODE_UK', 'U', 'KGRP_CODE'), ('KGRP_IST_AKTIV_CK', 'C', "KGRP_IST_AKTIV in ('Y', 'N')")], [], ''),
 ('KUND_BRANCHEN', 'BRAN', 'Branchen der Kunden', [
    ('BRAN_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('BRAN_BEZEICHNUNG', 'varchar2(200 char)', 'N', None, 'Bezeichnung der Branche'),
    ('BRAN_BEWERTUNG', 'number(1)', 'Y', None, 'Bewertung 1 (niedrig) bis 5 (hoch)'),
    ('BRAN_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('BRAN', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
    ('BRAN_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (TBL_BRANCHE.BRAN_ID), fuer die Datenuebernahme'),
  ], [('BRAN_BEZEICHNUNG_UK', 'U', 'BRAN_BEZEICHNUNG'), ('BRAN_ALT_ID_UK', 'U', 'BRAN_ALT_ID'),
      ('BRAN_BEWERTUNG_CK', 'C', 'BRAN_BEWERTUNG between 1 and 5'), ('BRAN_IST_AKTIV_CK', 'C', "BRAN_IST_AKTIV in ('Y', 'N')")], [], ''),
 ('KUND_UNTERKATEGORIEN', 'UKAT', 'Unterkategorien je Branche', [
    ('UKAT_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('UKAT_BRAN_ID', 'number', 'N', None, 'FK: Branche'),
    ('UKAT_BEZEICHNUNG', 'varchar2(200 char)', 'N', None, 'Bezeichnung der Unterkategorie'),
    ('UKAT_BEWERTUNG', 'number(1)', 'Y', None, 'Bewertung 1 (niedrig) bis 5 (hoch)'),
    ('UKAT_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('UKAT', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
    ('UKAT_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (TBL_UNTERKATEGORIE.UNKA_ID), fuer die Datenuebernahme'),
  ], [('UKAT_UK', 'U', 'UKAT_BRAN_ID, UKAT_BEZEICHNUNG'), ('UKAT_ALT_ID_UK', 'U', 'UKAT_ALT_ID'),
      ('UKAT_BEWERTUNG_CK', 'C', 'UKAT_BEWERTUNG between 1 and 5'), ('UKAT_IST_AKTIV_CK', 'C', "UKAT_IST_AKTIV in ('Y', 'N')"),
      ('UKAT_BRAN_FK', 'R', 'UKAT_BRAN_ID references KUND_BRANCHEN (BRAN_ID)')], [('UKAT_BRAN_I', 'UKAT_BRAN_ID')], ''),
 ('KUND_KUNDEN_BRANCHEN', 'KBRA', 'Zuordnung Kunde - Branche (n:m)', [
    ('KBRA_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('KBRA_KUND_ID', 'number', 'N', None, 'FK: Kunde'),
    ('KBRA_BRAN_ID', 'number', 'N', None, 'FK: Branche'),
  ], [('KBRA_UK', 'U', 'KBRA_KUND_ID, KBRA_BRAN_ID'),
      ('KBRA_KUND_FK', 'R', 'KBRA_KUND_ID references KUND_KUNDEN (KUND_ID)'),
      ('KBRA_BRAN_FK', 'R', 'KBRA_BRAN_ID references KUND_BRANCHEN (BRAN_ID)')], [('KBRA_BRAN_I', 'KBRA_BRAN_ID')], ''),
 ('KUND_KUNDEN_UNTERKATEGORIEN', 'KUKA', 'Zuordnung Kunden-Branche - Unterkategorie (n:m)', [
    ('KUKA_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('KUKA_KBRA_ID', 'number', 'N', None, 'FK: Kunde-Branche-Zuordnung'),
    ('KUKA_UKAT_ID', 'number', 'N', None, 'FK: Unterkategorie (muss zur Branche der Zuordnung gehoeren)'),
  ], [('KUKA_UK', 'U', 'KUKA_KBRA_ID, KUKA_UKAT_ID'),
      ('KUKA_KBRA_FK', 'R', 'KUKA_KBRA_ID references KUND_KUNDEN_BRANCHEN (KBRA_ID)'),
      ('KUKA_UKAT_FK', 'R', 'KUKA_UKAT_ID references KUND_UNTERKATEGORIEN (UKAT_ID)')], [('KUKA_UKAT_I', 'KUKA_UKAT_ID')],
  '''
  -- Unterkategorie muss zur Branche der Kunden-Branche-Zuordnung gehoeren
  declare
    l_ok pls_integer;
  begin
    select count(*) into l_ok
      from KUND_KUNDEN_BRANCHEN b
      join KUND_UNTERKATEGORIEN u on u.UKAT_BRAN_ID = b.KBRA_BRAN_ID
     where b.KBRA_ID = :new.KUKA_KBRA_ID and u.UKAT_ID = :new.KUKA_UKAT_ID;
    if l_ok = 0 then
      raise_application_error(-20110, 'Unterkategorie gehoert nicht zur Branche der Zuordnung.');
    end if;
  end;'''),
 ('KUND_ABTEILUNGEN', 'ABTE', 'Abteilungen der Ansprechpartner beim Kunden', [
    ('ABTE_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('ABTE_CODE', 'varchar2(25 char)', 'N', None, 'Kuerzel, z.B. EK, VK, GF'),
    ('ABTE_BEZEICHNUNG', 'varchar2(100 char)', 'N', None, 'Bezeichnung'),
    ('ABTE_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('ABTE', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
    ('ABTE_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (TBL_ABTEILUNG.ABTE_ID), fuer die Datenuebernahme'),
  ], [('ABTE_CODE_UK', 'U', 'ABTE_CODE'), ('ABTE_ALT_ID_UK', 'U', 'ABTE_ALT_ID'), ('ABTE_IST_AKTIV_CK', 'C', "ABTE_IST_AKTIV in ('Y', 'N')")], [], ''),
 ('KUND_FUNKTIONEN', 'FUNK', 'Funktionen der Ansprechpartner beim Kunden', [
    ('FUNK_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)'),
    ('FUNK_CODE', 'varchar2(20 char)', 'N', None, 'Kuerzel, z.B. GF, ABL, SB'),
    ('FUNK_BEZEICHNUNG', 'varchar2(100 char)', 'N', None, 'Bezeichnung'),
    ('FUNK_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('FUNK', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
    ('FUNK_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (TBL_FUNKTION.FUNK_ID), fuer die Datenuebernahme'),
  ], [('FUNK_CODE_UK', 'U', 'FUNK_CODE'), ('FUNK_ALT_ID_UK', 'U', 'FUNK_ALT_ID'), ('FUNK_IST_AKTIV_CK', 'C', "FUNK_IST_AKTIV in ('Y', 'N')")], [], ''),
]

# Neue Spalten an bestehenden Tabellen: (tabelle, spalten, constraints, indizes)
ERWEITERUNGEN = [
 ('KUND_KUNDEN', [
    ('KUND_KGRP_ID', 'number', 'Y', None, 'FK: Kundengruppe (OEM, Wiederverkaeufer, Endkunde)'),
    ('KUND_KURZNAME', 'varchar2(50 char)', 'Y', None, 'Kurzname / Suchbegriff (eindeutig)'),
    ('KUND_NAMENSZUSATZ', 'varchar2(200 char)', 'Y', None, 'Namenszusatz (2. Namenszeile)'),
    ('KUND_SPRACHE', 'varchar2(2 char)', 'N', "'de'", 'Korrespondenzsprache (ISO 639-1): de, en'),
    ('KUND_UNTERNEHMENSGROESSE', 'varchar2(2 char)', 'Y', None, 'Unternehmensgroesse: KU = Kleinstunternehmen, K = klein, M = mittel, G = gross'),
    ('KUND_MITARBEITER_ANZAHL', 'varchar2(15 char)', 'Y', None, 'Mitarbeiteranzahl (Groessenklasse als Text)'),
    ('KUND_BUCHHALTUNGSNR', 'varchar2(20 char)', 'Y', None, 'Nummer in der Buchhaltung (Altsystem BUCH_NR)'),
    ('KUND_ZAHLUNGSBED_TEXT', 'varchar2(2000 char)', 'Y', None, 'Individuelle Zahlungsbedingung (Freitext, ergaenzend zu KUND_ZBED_ID)'),
    ('KUND_LIEFERBEDINGUNG', 'varchar2(2000 char)', 'Y', None, 'Lieferbedingung (Freitext)'),
    ('KUND_RABATT_TEXT', 'varchar2(4000 char)', 'Y', None, 'Rabattvereinbarung (Freitext)'),
    ('KUND_BEMERKUNG', 'clob', 'Y', None, 'Bemerkung zum Kunden'),
    ('KUND_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (TBL_KUNDE.KUND_ID), fuer die Datenuebernahme'),
    ('KUND_ALT_SI_ID', 'number', 'Y', None, 'Kontakt-ID im aelteren Altsystem (TBL_KUNDE.KUND_ID_SI = TBL_KONTAKT.ID_KONTAKT)'),
  ], [('KUND_KGRP_FK', 'R', 'KUND_KGRP_ID references KUND_KUNDENGRUPPEN (KGRP_ID)'),
      ('KUND_KURZNAME_UK', 'U', 'KUND_KURZNAME'), ('KUND_ALT_ID_UK', 'U', 'KUND_ALT_ID'),
      ('KUND_SPRACHE_CK', 'C', "KUND_SPRACHE in ('de', 'en')"),
      ('KUND_UNTERNEHMENSGROESSE_CK', 'C', "KUND_UNTERNEHMENSGROESSE in ('KU', 'K', 'M', 'G')")],
  [('KUND_KGRP_I', 'KUND_KGRP_ID')]),
 ('KUND_ANSPRECHPARTNER', [
    ('ANSP_ABTE_ID', 'number', 'Y', None, 'FK: Abteilung'),
    ('ANSP_FUNK_ID', 'number', 'Y', None, 'FK: Funktion (ANSP_FUNKTION bleibt als Freitext)'),
    ('ANSP_DURCHWAHL', 'varchar2(100 char)', 'Y', None, 'Telefon-Durchwahl'),
    ('ANSP_BEWERTUNG', 'varchar2(1 char)', 'Y', None, 'Bewertung A, B, C, U, X (aus Altsystem)'),
    ('ANSP_GEBURTSDATUM', 'date', 'Y', None, 'Geburtsdatum'),
    ('ANSP_IST_INFOMAIL', 'varchar2(1 char)', 'N', "'N'", 'Y = Einwilligung Infomail/Newsletter'),
    ('ANSP_INFOMAIL_AM', 'date', 'Y', None, 'Datum der Infomail-Einwilligung'),
    ('ANSP_BEMERKUNG', 'varchar2(4000 char)', 'Y', None, 'Bemerkung zum Ansprechpartner'),
    ('ANSP_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (TBL_ANSPRECHPERSON.APER_ID), fuer die Datenuebernahme'),
  ], [('ANSP_ABTE_FK', 'R', 'ANSP_ABTE_ID references KUND_ABTEILUNGEN (ABTE_ID)'),
      ('ANSP_FUNK_FK', 'R', 'ANSP_FUNK_ID references KUND_FUNKTIONEN (FUNK_ID)'),
      ('ANSP_ALT_ID_UK', 'U', 'ANSP_ALT_ID'),
      ('ANSP_BEWERTUNG_CK', 'C', "ANSP_BEWERTUNG in ('A', 'B', 'C', 'U', 'X')"),
      ('ANSP_IST_INFOMAIL_CK', 'C', "ANSP_IST_INFOMAIL in ('Y', 'N')")],
  [('ANSP_ABTE_I', 'ANSP_ABTE_ID'), ('ANSP_FUNK_I', 'ANSP_FUNK_ID')]),
]

def q(s):
    return s.replace("'", "''")

out = ["""-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 13 – Erweiterung Kundenstamm fuer die Altdatenuebernahme:
--      neu: KUND_KUNDENGRUPPEN, KUND_BRANCHEN, KUND_UNTERKATEGORIEN, KUND_KUNDEN_BRANCHEN,
--           KUND_KUNDEN_UNTERKATEGORIEN, KUND_ABTEILUNGEN, KUND_FUNKTIONEN
--      erweitert: KUND_KUNDEN (Kundengruppe, Kurzname, Namenszusatz, Sprache, Groesse, Bemerkung, Alt-IDs, …),
--                 KUND_ANSPRECHPARTNER (Abteilung, Funktion, Durchwahl, Bewertung, Geburtsdatum, Infomail, …)
-- GENERIERT (Definition siehe Kopf der Tabellenbloecke); nutzt Paket DDL_UTIL (11_ddl_util.sql)
-- Erzeugt: 2026-09-25
--
-- Wiederholbar: Tabellen/Spalten/Constraints/Indizes werden nur angelegt bzw. angeglichen,
-- Trigger nur ersetzt, wenn der Name zur richtigen Tabelle gehoert; Grunddaten nur fehlende Zeilen.
-- =====================================================================

set define off
set serveroutput on size unlimited
"""]

for tab, a, kom, cols, cons, idx, extra in TABELLEN:
    create_cols = ',\n  '.join(f"{c} {t}" + (f" default {d}" if d else '') + (' not null' if n == 'N' else '') for c, t, n, d, _ in cols + AUDIT(a))
    create = f"create table {tab} (\n  {create_cols},\n  constraint {a}_PK primary key ({a}_ID)\n)"
    block = [f"-- {tab} ({a}): {kom}", 'begin', f"    DDL_UTIL.tabelle('{tab}', q'~{create}~');"]
    for c, t, n, d, _ in cols + AUDIT(a):
        block.append(f"    DDL_UTIL.spalte('{tab}', '{c}', '{t}', '{n}'" + (f", q'~{d}~'" if d else '') + ');')
    block.append(f"    DDL_UTIL.constraint_('{tab}', '{a}_PK', 'P', '{a}_ID');")
    for n_, ty, sp in cons:
        if ty != 'R':
            block.append(f"    DDL_UTIL.constraint_('{tab}', '{n_}', '{ty}', q'~{sp}~');")
    block.append('end;\n/\n')
    out.append('\n'.join(block))

for tab, cols, cons, idx in ERWEITERUNGEN:
    block = [f"-- {tab}: zusaetzliche Spalten", 'begin']
    for c, t, n, d, _ in cols:
        block.append(f"    DDL_UTIL.spalte('{tab}', '{c}', '{t}', '{n}'" + (f", q'~{d}~'" if d else '') + ');')
    for n_, ty, sp in cons:
        if ty != 'R':
            block.append(f"    DDL_UTIL.constraint_('{tab}', '{n_}', '{ty}', q'~{sp}~');")
    block.append('end;\n/\n')
    out.append('\n'.join(block))

# Fremdschluessel und FK-Indizes (nach allen Tabellen)
fk = ['-- Fremdschluessel und FK-Indizes', 'begin']
for tab, a, kom, cols, cons, idx, extra in TABELLEN:
    for n_, ty, sp in cons:
        if ty == 'R':
            fk.append(f"    DDL_UTIL.constraint_('{tab}', '{n_}', 'R', '{sp}');")
    for n_, sp in idx:
        fk.append(f"    DDL_UTIL.index_('{tab}', '{n_}', '{sp}');")
for tab, cols, cons, idx in ERWEITERUNGEN:
    for n_, ty, sp in cons:
        if ty == 'R':
            fk.append(f"    DDL_UTIL.constraint_('{tab}', '{n_}', 'R', '{sp}');")
    for n_, sp in idx:
        fk.append(f"    DDL_UTIL.index_('{tab}', '{n_}', '{sp}');")
fk.append('end;\n/\n')
out.append('\n'.join(fk))

# Trigger
for tab, a, kom, cols, cons, idx, extra in TABELLEN:
    out.append(f"""begin
    DDL_UTIL.trigger_pruefen('{a}_BIU', '{tab}');
end;
/

create or replace trigger {a}_BIU
  before insert or update on {tab}
  for each row
begin
  if inserting then
    :new.{a}_ID := coalesce(:new.{a}_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.{a}_CREATED_ON  := systimestamp;
    :new.{a}_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.{a}_UPDATED_ON  := null;
    :new.{a}_UPDATED_BY  := null;
    :new.{a}_ROW_VERSION := 1;
  elsif updating then
    :new.{a}_ID          := :old.{a}_ID;  -- Primaerschluessel ist unveraenderlich
    :new.{a}_CREATED_ON  := :old.{a}_CREATED_ON;
    :new.{a}_CREATED_BY  := :old.{a}_CREATED_BY;
    :new.{a}_UPDATED_ON  := systimestamp;
    :new.{a}_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.{a}_ROW_VERSION := nvl(:old.{a}_ROW_VERSION, 0) + 1;
  end if;{extra}
end {a}_BIU;
/
""")

# Kommentare
kom_lines = []
for tab, a, kom, cols, cons, idx, extra in TABELLEN:
    kom_lines.append(f"comment on table {tab} is '{q(kom)} [Alias {a}]';")
    for c, t, n, d, k in cols + AUDIT(a):
        kom_lines.append(f"comment on column {tab}.{c} is '{q(k)}';")
    kom_lines.append('')
for tab, cols, cons, idx in ERWEITERUNGEN:
    for c, t, n, d, k in cols:
        kom_lines.append(f"comment on column {tab}.{c} is '{q(k)}';")
    kom_lines.append('')
out.append('\n'.join(kom_lines))

# Grunddaten
out.append("""-- Grunddaten Kundengruppen (aus TBL_HAUPTGRUPPE); nur fehlende Zeilen
insert into KUND_KUNDENGRUPPEN (KGRP_CODE, KGRP_BEZEICHNUNG, KGRP_SORTIERUNG)
  select 'OEM', 'Anlagenbau (OEM)', 10 from dual where not exists (select 1 from KUND_KUNDENGRUPPEN where KGRP_CODE = 'OEM');
insert into KUND_KUNDENGRUPPEN (KGRP_CODE, KGRP_BEZEICHNUNG, KGRP_SORTIERUNG)
  select 'WV', 'Wiederverkäufer', 20 from dual where not exists (select 1 from KUND_KUNDENGRUPPEN where KGRP_CODE = 'WV');
insert into KUND_KUNDENGRUPPEN (KGRP_CODE, KGRP_BEZEICHNUNG, KGRP_SORTIERUNG)
  select 'EK', 'Endkunde', 30 from dual where not exists (select 1 from KUND_KUNDENGRUPPEN where KGRP_CODE = 'EK');
commit;

prompt Kundenstamm-Erweiterung installiert bzw. abgeglichen.
""")

open(sys.argv[1], 'w', encoding='utf-8').write('\n'.join(out))
print('ok')
