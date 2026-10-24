#!/usr/bin/env python3
"""Erzeugt 19_artikelstamm.sql und 20_fakturierung.sql (wiederholbar, nutzt DDL_UTIL).

Modell: db/er-modell/rechnung_er_modell.mmd (freigegeben 2026-09-26), abgeleitet aus Kingbill
(Artikelmaske, Rechnungseingabe). Aufruf im Ordner db/ddl:  python3 generator/gen_19_20_artikel_fakturierung.py
"""
from pathlib import Path

from ddl_gen import flag, flag_ck, insert_wenn_fehlt, mermaid, render

DDL = Path(__file__).resolve().parent.parent
PK = lambda a: (f'{a}_ID', 'number', 'N', None, 'Primaerschluessel (SYS_GUID)')
BETRAG = 'number(12,2)'
PROZENT = 'number(5,2)'

# --------------------------------------------------------------------------- 19 Artikelstamm
ARTIKEL = [
 ('ALLG_EINHEITEN', 'EINH', 'Mengeneinheiten (Stk., Std., Pauschale …) fuer Artikel und Belegpositionen', [
    PK('EINH'),
    ('EINH_CODE', 'varchar2(10 char)', 'N', None, 'Kuerzel, wie auf dem Beleg angedruckt, z.B. Stk., Std.'),
    ('EINH_BEZEICHNUNG', 'varchar2(50 char)', 'N', None, 'Bezeichnung, z.B. Stueck, Stunde'),
    ('EINH_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('EINH', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
  ], [('EINH_CODE_UK', 'U', 'EINH_CODE'), flag_ck('EINH', 'IST_AKTIV')], [], ''),

 ('ALLG_MWST_SAETZE', 'MWST', 'Umsatzsteuersaetze', [
    PK('MWST'),
    ('MWST_PROZENT', PROZENT, 'N', None, 'Steuersatz in Prozent, z.B. 20'),
    ('MWST_BEZEICHNUNG', 'varchar2(50 char)', 'N', None, 'Bezeichnung, z.B. 20 % Normalsteuersatz'),
    flag('MWST', 'IST_STANDARD', 'N', 'Y = Vorschlag fuer neue Artikel/Positionen (hoechstens einer)'),
    flag('MWST', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
    ('MWST_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
  ], [('MWST_PROZENT_UK', 'U', 'MWST_PROZENT'), ('MWST_PROZENT_CK', 'C', 'MWST_PROZENT between 0 and 100'),
      flag_ck('MWST', 'IST_STANDARD'), flag_ck('MWST', 'IST_AKTIV')],
  [('MWST_STANDARD_UI', "case when MWST_IST_STANDARD = 'Y' then 'Y' end", True)], ''),

 ('ALLG_TEXTVORLAGEN', 'TXVL', 'Textvorlagen fuer Belege (Zahlungsbedingungen, Vortext, Schlusstext)', [
    PK('TXVL'),
    ('TXVL_ART', 'varchar2(20 char)', 'N', None, 'ZAHLUNGSBED, VORTEXT oder SCHLUSSTEXT'),
    ('TXVL_BEZEICHNUNG', 'varchar2(100 char)', 'N', None, 'Name der Vorlage, z.B. Banküberweisung'),
    ('TXVL_TEXT', 'clob', 'Y', None, 'Text der Vorlage'),
    flag('TXVL', 'IST_STANDARD', 'N', 'Y = Vorschlag fuer neue Belege (hoechstens einer je Art)'),
    ('TXVL_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
  ], [('TXVL_UK', 'U', 'TXVL_ART, TXVL_BEZEICHNUNG'),
      ('TXVL_ART_CK', 'C', "TXVL_ART in ('ZAHLUNGSBED', 'VORTEXT', 'SCHLUSSTEXT')"), flag_ck('TXVL', 'IST_STANDARD')],
  [('TXVL_STANDARD_UI', "case when TXVL_IST_STANDARD = 'Y' then TXVL_ART end", True)], ''),

 ('ARTI_ARTIKELGRUPPEN', 'AGRP', 'Artikelgruppen (Kingbill: Gruppe)', [
    PK('AGRP'),
    ('AGRP_CODE', 'varchar2(20 char)', 'N', None, 'Kuerzel'),
    ('AGRP_BEZEICHNUNG', 'varchar2(100 char)', 'N', None, 'Bezeichnung'),
    ('AGRP_SORTIERUNG', 'number(5)', 'Y', None, 'Reihenfolge'),
    flag('AGRP', 'IST_AKTIV', 'Y', 'Y = auswaehlbar'),
  ], [('AGRP_CODE_UK', 'U', 'AGRP_CODE'), flag_ck('AGRP', 'IST_AKTIV')], [], ''),

 ('ARTI_ARTIKEL', 'ARTI', 'Artikelstamm (Waren und Dienstleistungen)', [
    PK('ARTI'),
    ('ARTI_AGRP_ID', 'number', 'Y', None, 'FK: Artikelgruppe'),
    ('ARTI_EINH_ID', 'number', 'Y', None, 'FK: Mengeneinheit'),
    ('ARTI_MWST_ID', 'number', 'N', None, 'FK: Umsatzsteuersatz'),
    ('ARTI_NUMMER', 'varchar2(30 char)', 'N', None, 'Artikelnummer (eindeutig)'),
    ('ARTI_NAME', 'varchar2(200 char)', 'N', None, 'Artikelname (Positionstext)'),
    ('ARTI_BESCHREIBUNG', 'clob', 'Y', None, 'Beschreibung (formatiert, HTML), wird in die Belegposition uebernommen'),
    ('ARTI_VK_PREIS', BETRAG, 'N', '0', 'Verkaufspreis (netto bzw. brutto lt. ARTI_IST_BRUTTO)'),
    flag('ARTI', 'IST_BRUTTO', 'N', 'Y = Verkaufspreis ist brutto'),
    ('ARTI_EK_PREIS', BETRAG, 'Y', None, 'Einkaufspreis netto'),
    ('ARTI_EAN', 'varchar2(20 char)', 'Y', None, 'Barcode EAN/GTIN'),
    ('ARTI_ERLOESKONTO', 'varchar2(20 char)', 'Y', None, 'Erloeskonto fuer die Buchhaltung'),
    ('ARTI_AUFGENOMMEN_AM', 'date', 'N', "trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))", 'Datum der Aufnahme in den Artikelstamm'),
    ('ARTI_KOMMENTAR', 'clob', 'Y', None, 'Interner Kommentar (nicht auf Belegen)'),
    flag('ARTI', 'IST_AKTIV', 'Y', 'Y = in Belegen auswaehlbar (Artikel nie loeschen)'),
    ('ARTI_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (Kingbill Product.ID), fuer die Datenuebernahme'),
  ], [('ARTI_NUMMER_UK', 'U', 'ARTI_NUMMER'), ('ARTI_ALT_ID_UK', 'U', 'ARTI_ALT_ID'),
      ('ARTI_VK_PREIS_CK', 'C', 'ARTI_VK_PREIS >= 0'),
      flag_ck('ARTI', 'IST_BRUTTO'), flag_ck('ARTI', 'IST_AKTIV'),
      ('ARTI_AGRP_FK', 'R', 'ARTI_AGRP_ID references ARTI_ARTIKELGRUPPEN (AGRP_ID)'),
      ('ARTI_EINH_FK', 'R', 'ARTI_EINH_ID references ALLG_EINHEITEN (EINH_ID)'),
      ('ARTI_MWST_FK', 'R', 'ARTI_MWST_ID references ALLG_MWST_SAETZE (MWST_ID)')],
  [('ARTI_AGRP_I', 'ARTI_AGRP_ID'), ('ARTI_EINH_I', 'ARTI_EINH_ID'), ('ARTI_MWST_I', 'ARTI_MWST_ID'),
   ('ARTI_NAME_I', 'upper(ARTI_NAME)')], ''),
]

grund_artikel = []
for prozent, bez, std, sort in (('0', '0 % steuerfrei', 'N', 30), ('10', '10 % ermaessigt', 'N', 20), ('20', '20 % Normalsteuersatz', 'Y', 10)):
    grund_artikel.append(insert_wenn_fehlt('ALLG_MWST_SAETZE', ['MWST_PROZENT', 'MWST_BEZEICHNUNG', 'MWST_IST_STANDARD', 'MWST_SORTIERUNG'],
                                           [prozent, f"'{bez}'", f"'{std}'", str(sort)], 'MWST_PROZENT'))
for i, (code, bez) in enumerate((('Stk.', 'Stück'), ('Std.', 'Stunde'), ('Pauschale', 'Pauschale'), ('Tag', 'Tag'),
                                 ('m²', 'Quadratmeter'), ('lfm', 'Laufmeter')), start=1):
    grund_artikel.append(insert_wenn_fehlt('ALLG_EINHEITEN', ['EINH_CODE', 'EINH_BEZEICHNUNG', 'EINH_SORTIERUNG'],
                                           [f"'{code}'", f"'{bez}'", str(i * 10)], 'EINH_CODE'))
# (Zusatzfelder, Artikeldateien, Artikelbild und die eigene App THG-ARTIKEL entfallen seit 2026-10-24, siehe Skript 29)

(DDL / '19_artikelstamm.sql').write_text(render('''
-- =====================================================================
-- ThGERP (Gruppen ARTI, ALLG)
-- 19 – Artikelstamm (in der App THG-FINANZ), abgeleitet aus der Kingbill-Artikelmaske:
--      neu: ALLG_EINHEITEN, ALLG_MWST_SAETZE, ALLG_TEXTVORLAGEN, ARTI_ARTIKELGRUPPEN, ARTI_ARTIKEL
--      Grunddaten: MwSt.-Saetze 0/10/20 % (Standard 20), Einheiten
--      (Zusatzfelder, Artikeldateien und Artikelbild 2026-10-24 entfernt – bestehende Schemas: Skript 29)
-- GENERIERT mit generator/gen_19_20_artikel_fakturierung.py – nicht von Hand bearbeiten
-- Erzeugt: 2026-09-26
-- Wiederholbar (DDL_UTIL; Grunddaten nur fehlende Zeilen).
-- =====================================================================
''', ARTIKEL, '\n'.join(grund_artikel)), encoding='utf-8')

# --------------------------------------------------------------------------- 20 Fakturierung
EMPF = lambda name, typ, kom: (f'RECH_EMPF_{name}', typ, 'Y', None, f'Empfaenger (Kopie beim Anlegen): {kom}')
FAKT = [
 ('FAKT_NUMMERNKREISE', 'NKRS', 'Nummernkreise je Mandant, Belegart und Jahr', [
    PK('NKRS'),
    ('NKRS_MAND_ID', 'number', 'N', None, 'FK: Mandant'),
    ('NKRS_BELEGART', 'varchar2(20 char)', 'N', None, 'RECHNUNG oder GUTSCHRIFT'),
    ('NKRS_JAHR', 'number(4)', 'N', None, 'Geschaeftsjahr'),
    ('NKRS_FORMAT', 'varchar2(50 char)', 'N', "'{JAHR} - {NR}'", 'Format der Belegnummer mit {JAHR} und {NR}, z.B. 2026 - 13'),
    ('NKRS_LETZTE_NUMMER', 'number', 'N', '0', 'Zuletzt vergebene laufende Nummer'),
  ], [('NKRS_UK', 'U', 'NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR'),
      ('NKRS_BELEGART_CK', 'C', "NKRS_BELEGART in ('RECHNUNG', 'GUTSCHRIFT')"),
      ('NKRS_LETZTE_NUMMER_CK', 'C', 'NKRS_LETZTE_NUMMER >= 0'),
      ('NKRS_MAND_FK', 'R', 'NKRS_MAND_ID references ADMIN_MANDANTEN (MAND_ID)')], [], ''),

 ('FAKT_RECHNUNGEN', 'RECH', 'Ausgangsrechnungen (Kopf)', [
    PK('RECH'),
    ('RECH_MAND_ID', 'number', 'N', None, 'FK: Mandant (ausstellende Firma)'),
    ('RECH_KUND_ID', 'number', 'N', None, 'FK: Kunde (Rechnungsempfaenger)'),
    ('RECH_KSTO_ID', 'number', 'Y', None, 'FK: Standort (Rechnungsadresse)'),
    ('RECH_ANSP_ID', 'number', 'Y', None, 'FK: Ansprechpartner (Kontaktperson)'),
    ('RECH_MITA_ID', 'number', 'Y', None, 'FK: Mitarbeiter (Bearbeiter)'),
    ('RECH_ZBED_ID', 'number', 'Y', None, 'FK: Zahlungsbedingung'),
    ('RECH_EMPF_LAND_CODE', 'varchar2(2 char)', 'Y', None, 'Empfaenger (Kopie beim Anlegen): Land, FK ALLG_LAENDER'),
    ('RECH_NUMMER', 'varchar2(30 char)', 'Y', None, 'Rechnungsnummer (eindeutig je Mandant), vergeben beim Abschliessen'),
    ('RECH_STATUS', 'varchar2(15 char)', 'N', "'ENTWURF'", 'ENTWURF, GEDRUCKT, GESENDET, TEILBEZAHLT, BEZAHLT, STORNIERT'),
    ('RECH_BETREFF', 'varchar2(200 char)', 'Y', None, 'Betreff, z.B. Rechnung 2026 - 13'),
    ('RECH_DATUM', 'date', 'Y', None, 'Rechnungsdatum, gesetzt beim Abschliessen zusammen mit der Nummer (Entwurf: leer)'),
    ('RECH_FAELLIG_AM', 'date', 'Y', None, 'Faelligkeitsdatum'),
    ('RECH_LEISTUNGSZEITRAUM', 'varchar2(100 char)', 'Y', None, 'Leistungszeitraum als Text, z.B. Juli 2026'),
    ('RECH_LEISTUNG_VON', 'date', 'Y', None, 'Leistungszeitraum von (optional, fuer Auswertungen)'),
    ('RECH_LEISTUNG_BIS', 'date', 'Y', None, 'Leistungszeitraum bis'),
    ('RECH_REFERENZ', 'varchar2(200 char)', 'Y', None, 'Referenz, z.B. Bestellnummer des Kunden'),
    ('RECH_PROJEKT', 'varchar2(200 char)', 'Y', None, 'Projekt'),
    flag('RECH', 'IST_BRUTTO', 'N', 'Y = Preise der Positionen sind brutto'),
    flag('RECH', 'IST_OHNE_MWST', 'N', 'Y = ohne Umsatzsteuer (Reverse Charge, Ausland)'),
    flag('RECH', 'IST_FAELLIGKEIT_ANZEIGEN', 'N', 'Y = Faelligkeit auf der Rechnung andrucken'),
    EMPF('ANREDE', 'varchar2(30 char)', 'Anrede'),
    EMPF('NAME', 'varchar2(400 char)', 'Name (Firma bzw. Person, mehrzeilig)'),
    EMPF('KONTAKTPERSON', 'varchar2(200 char)', 'Kontaktperson'),
    EMPF('STRASSE', 'varchar2(250 char)', 'Strasse und Hausnummer'),
    EMPF('PLZ', 'varchar2(10 char)', 'PLZ'),
    EMPF('ORT', 'varchar2(100 char)', 'Ort'),
    EMPF('UID_NUMMER', 'varchar2(20 char)', 'UID-Nummer'),
    ('RECH_LIEFERADRESSE', 'varchar2(1000 char)', 'Y', None, 'Lieferadresse (Freitext)'),
    ('RECH_ZAHLUNGSBED_TEXT', 'clob', 'Y', None, 'Zahlungsbedingungen (Text auf der Rechnung)'),
    ('RECH_VORTEXT', 'clob', 'Y', None, 'Text vor den Positionen'),
    ('RECH_SCHLUSSTEXT', 'clob', 'Y', None, 'Text nach den Positionen'),
    ('RECH_WAEHRUNG', 'varchar2(3 char)', 'N', "'EUR'", 'Waehrung (ISO 4217)'),
    ('RECH_SUMME_NETTO', BETRAG, 'N', '0', 'Summe netto (aus den Positionen, ohne optionale)'),
    ('RECH_SUMME_MWST', BETRAG, 'N', '0', 'Summe Umsatzsteuer'),
    ('RECH_SUMME_BRUTTO', BETRAG, 'N', '0', 'Gesamtbetrag'),
    ('RECH_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (Kingbill DokumentRechnung.ID, je Mandant eine Kingbill-Datenbank), fuer die Datenuebernahme'),
  ], [  # Eindeutigkeit von RECH_ALT_ID je Mandant: Unique-Index RECH_ALT_ID_UI in Skript 30
      ('RECH_STATUS_CK', 'C', "RECH_STATUS in ('ENTWURF', 'GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT', 'STORNIERT')"),
      ('RECH_DATUM_CK', 'C', "RECH_STATUS = 'ENTWURF' or RECH_DATUM is not null"),
      ('RECH_NUMMER_CK', 'C', "RECH_STATUS = 'ENTWURF' or RECH_NUMMER is not null"),
      ('RECH_LEISTUNG_CK', 'C', 'RECH_LEISTUNG_BIS is null or RECH_LEISTUNG_VON is null or RECH_LEISTUNG_BIS >= RECH_LEISTUNG_VON'),
      flag_ck('RECH', 'IST_BRUTTO'), flag_ck('RECH', 'IST_OHNE_MWST'), flag_ck('RECH', 'IST_FAELLIGKEIT_ANZEIGEN'),
      ('RECH_MAND_FK', 'R', 'RECH_MAND_ID references ADMIN_MANDANTEN (MAND_ID)'),
      ('RECH_KUND_FK', 'R', 'RECH_KUND_ID references KUND_KUNDEN (KUND_ID)'),
      ('RECH_KSTO_FK', 'R', 'RECH_KSTO_ID references KUND_STANDORTE (KSTO_ID)'),
      ('RECH_ANSP_FK', 'R', 'RECH_ANSP_ID references KUND_ANSPRECHPARTNER (ANSP_ID)'),
      ('RECH_MITA_FK', 'R', 'RECH_MITA_ID references ALLG_MITARBEITER (MITA_ID)'),
      ('RECH_ZBED_FK', 'R', 'RECH_ZBED_ID references ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_ID)'),
      ('RECH_EMPF_LAND_FK', 'R', 'RECH_EMPF_LAND_CODE references ALLG_LAENDER (LAND_CODE)')],
  [('RECH_NUMMER_UI', "case when RECH_NUMMER is not null then RECH_MAND_ID end, RECH_NUMMER", True),
   ('RECH_MAND_I', 'RECH_MAND_ID'), ('RECH_KUND_I', 'RECH_KUND_ID'), ('RECH_KSTO_I', 'RECH_KSTO_ID'),
   ('RECH_ANSP_I', 'RECH_ANSP_ID'), ('RECH_MITA_I', 'RECH_MITA_ID'), ('RECH_ZBED_I', 'RECH_ZBED_ID'),
   ('RECH_EMPF_LAND_I', 'RECH_EMPF_LAND_CODE'), ('RECH_DATUM_I', 'RECH_DATUM')], ''),

 # Haupt- und Unterpositionen (Skript 26): Hauptposition = RPOS_HAUPT_RPOS_ID leer; mit Unterpositionen ist ihre Summe
 # die Summe der Unterpositionen abzgl. Rabatt bzw. die Pauschalsumme, ohne Unterpositionen Menge x Einzelpreis
 ('FAKT_RECHNUNGSPOSITIONEN', 'RPOS', 'Positionen der Ausgangsrechnungen (Haupt- und Unterpositionen)', [
    PK('RPOS'),
    ('RPOS_RECH_ID', 'number', 'N', None, 'FK: Rechnung'),
    ('RPOS_HAUPT_RPOS_ID', 'number', 'Y', None, 'FK: Hauptposition (leer = diese Zeile ist selbst Hauptposition)'),
    ('RPOS_ARTI_ID', 'number', 'Y', None, 'FK: Artikel (optional; Texte werden kopiert)'),
    ('RPOS_POSITION', 'number(5)', 'N', None, 'Positionsnummer: Hauptpositionen 1, 2, 3 …; Unterpositionen je Hauptposition 10, 20, 30 …'),
    ('RPOS_ARTIKELNUMMER', 'varchar2(30 char)', 'Y', None, 'Artikelnummer (Kopie)'),
    ('RPOS_NAME', 'varchar2(200 char)', 'N', None, 'Positionstext (Kopie des Artikelnamens)'),
    ('RPOS_BESCHREIBUNG', 'clob', 'Y', None, 'Beschreibung (Kopie, HTML)'),
    ('RPOS_MENGE', 'number(12,3)', 'N', '1', 'Menge'),
    ('RPOS_EINHEIT', 'varchar2(10 char)', 'Y', None, 'Einheit (Kopie), z.B. Pauschale'),
    ('RPOS_EINZELPREIS', BETRAG, 'N', '0', 'Einzelpreis (netto bzw. brutto lt. RECH_IST_BRUTTO)'),
    ('RPOS_RABATT_PROZENT', PROZENT, 'Y', None, 'Rabatt in Prozent'),
    ('RPOS_MWST_PROZENT', PROZENT, 'N', None, 'Umsatzsteuersatz (Kopie)'),
    ('RPOS_SUMME_UNTERPOS', BETRAG, 'Y', None, 'Hauptposition: Summe der nicht optionalen Unterpositionen (leer = keine Unterpositionen; FAKT_RECHNUNG.summen_berechnen)'),
    ('RPOS_PAUSCHALSUMME', BETRAG, 'Y', None, 'Hauptposition: Pauschalsumme, gilt statt der berechneten Zwischensumme'),
    ('RPOS_SUMME', BETRAG, 'N', '0', 'Summe (berechnet im Trigger): Menge x Einzelpreis bzw. Summe der Unterpositionen, abzgl. Rabatt; Hauptposition mit Pauschalsumme: die Pauschalsumme'),
    flag('RPOS', 'IST_OPTIONAL', 'N', 'Y = Alternativposition, nicht in der Rechnungssumme'),
    ('RPOS_ERLOESKONTO', 'varchar2(20 char)', 'Y', None, 'Erloeskonto (Kopie)'),
  ], [('RPOS_UK', 'U', 'RPOS_RECH_ID, RPOS_HAUPT_RPOS_ID, RPOS_POSITION'),   # je Rechnung bzw. je Hauptposition eindeutig (Skript 26)
      ('RPOS_HAUPT_CK', 'C', 'RPOS_HAUPT_RPOS_ID <> RPOS_ID'),
      ('RPOS_PAUSCHAL_CK', 'C', 'RPOS_HAUPT_RPOS_ID is null or (RPOS_PAUSCHALSUMME is null and RPOS_SUMME_UNTERPOS is null)'),
      ('RPOS_RABATT_CK', 'C', 'RPOS_RABATT_PROZENT between 0 and 100'),
      ('RPOS_MWST_CK', 'C', 'RPOS_MWST_PROZENT between 0 and 100'),
      flag_ck('RPOS', 'IST_OPTIONAL'),
      ('RPOS_RECH_FK', 'R', 'RPOS_RECH_ID references FAKT_RECHNUNGEN (RECH_ID)'),
      ('RPOS_HAUPT_RPOS_FK', 'R', 'RPOS_HAUPT_RPOS_ID references FAKT_RECHNUNGSPOSITIONEN (RPOS_ID) on delete cascade'),
      ('RPOS_ARTI_FK', 'R', 'RPOS_ARTI_ID references ARTI_ARTIKEL (ARTI_ID)')],
  [('RPOS_HAUPT_RPOS_I', 'RPOS_HAUPT_RPOS_ID'), ('RPOS_ARTI_I', 'RPOS_ARTI_ID')],
  '\n  -- Summe: Pauschalsumme, sonst Summe der Unterpositionen bzw. Menge x Einzelpreis, jeweils abzgl. Rabatt'
  '\n  :new.RPOS_SUMME := coalesce(:new.RPOS_PAUSCHALSUMME,'
  '\n                              round(coalesce(:new.RPOS_SUMME_UNTERPOS, :new.RPOS_MENGE * :new.RPOS_EINZELPREIS)'
  '\n                                    * (1 - nvl(:new.RPOS_RABATT_PROZENT, 0) / 100), 2));'),

 ('FAKT_ZAHLUNGEN', 'ZAHL', 'Zahlungseingaenge zu Ausgangsrechnungen', [
    PK('ZAHL'),
    ('ZAHL_RECH_ID', 'number', 'N', None, 'FK: Rechnung'),
    ('ZAHL_DATUM', 'date', 'N', None, 'Zahlungsdatum'),
    ('ZAHL_BETRAG', BETRAG, 'N', None, 'Gezahlter Betrag'),
    ('ZAHL_SKONTO', BETRAG, 'Y', None, 'Abgezogenes Skonto'),
    ('ZAHL_MAHNSPESEN', BETRAG, 'Y', None, 'Mahnspesen und Verzugszinsen'),
    ('ZAHL_BEMERKUNG', 'varchar2(500 char)', 'Y', None, 'Bemerkung'),
    ('ZAHL_ALT_ID', 'number', 'Y', None, 'ID im Altsystem (Kingbill Payment.ID, je Mandant eine Kingbill-Datenbank), fuer die Datenuebernahme'),
  ], [('ZAHL_RECH_FK', 'R', 'ZAHL_RECH_ID references FAKT_RECHNUNGEN (RECH_ID)')],
  [('ZAHL_RECH_I', 'ZAHL_RECH_ID'), ('ZAHL_ALT_ID_I', 'ZAHL_ALT_ID')], ''),
]

# Nummernkreise 2026: zuletzt vergebene Nummern lt. Ausgangsrechnungen (EDV: 2026 - 13, HOLDING: 2026 - 199)
grund_fakt = []
for code, letzte in (('EDV', 13), ('HOLDING', 199)):
    grund_fakt.append(f"""insert into FAKT_NUMMERNKREISE (NKRS_MAND_ID, NKRS_BELEGART, NKRS_JAHR, NKRS_LETZTE_NUMMER)
  select MAND_ID, 'RECHNUNG', 2026, {letzte} from ADMIN_MANDANTEN m
   where MAND_CODE = '{code}'
     and not exists (select 1 from FAKT_NUMMERNKREISE where NKRS_MAND_ID = m.MAND_ID and NKRS_BELEGART = 'RECHNUNG' and NKRS_JAHR = 2026);""")

(DDL / '20_fakturierung.sql').write_text(render('''
-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 20 – Fakturierung: Ausgangsrechnungen, abgeleitet aus der Kingbill-Rechnungseingabe
--      neu: FAKT_NUMMERNKREISE, FAKT_RECHNUNGEN, FAKT_RECHNUNGSPOSITIONEN, FAKT_ZAHLUNGEN
--      Grunddaten: Nummernkreise 2026 (EDV zuletzt 13, HOLDING zuletzt 199)
-- Voraussetzung: 17/18 (Mandanten), 19 (Artikelstamm)
-- GENERIERT mit generator/gen_19_20_artikel_fakturierung.py – nicht von Hand bearbeiten
-- Erzeugt: 2026-09-26
-- Wiederholbar (DDL_UTIL; Grunddaten nur fehlende Zeilen).
-- =====================================================================
''', FAKT, '\n'.join(grund_fakt)), encoding='utf-8')
# ER-Modell (Quelle fuer HTML/SVG/PNG/PDF, siehe er-modell/build_er_modell.py)
(DDL.parent / 'er-modell' / 'artikel_fakturierung_er_modell.mmd').write_text(
    mermaid(ARTIKEL + FAKT, 'ThGERP – Artikelstamm (ARTI) und Fakturierung (FAKT)'), encoding='utf-8')
print('19_artikelstamm.sql, 20_fakturierung.sql, artikel_fakturierung_er_modell.mmd erzeugt')
