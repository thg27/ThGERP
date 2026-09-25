-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 06 – Grunddaten für Lookup-Tabellen
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

-- Laender (HAT_REGISTER = Y: nur Adressen aus dem Register zulaessig)
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('AT', 'Österreich',   'Y', 'Y');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('DE', 'Deutschland',  'Y', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('IT', 'Italien',      'Y', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('SI', 'Slowenien',    'Y', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('HU', 'Ungarn',       'Y', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('CZ', 'Tschechien',   'Y', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('SK', 'Slowakei',     'Y', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('CH', 'Schweiz',      'N', 'N');
insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER) values ('LI', 'Liechtenstein','N', 'N');

-- Kommunikationsarten
insert into ALLG_KOMMUNIKATIONSARTEN (KART_CODE, KART_BEZEICHNUNG, KART_SORTIERUNG) values ('EMAIL', 'E-Mail',  10);
insert into ALLG_KOMMUNIKATIONSARTEN (KART_CODE, KART_BEZEICHNUNG, KART_SORTIERUNG) values ('TEL',   'Telefon', 20);
insert into ALLG_KOMMUNIKATIONSARTEN (KART_CODE, KART_BEZEICHNUNG, KART_SORTIERUNG) values ('MOBIL', 'Mobil',   30);
insert into ALLG_KOMMUNIKATIONSARTEN (KART_CODE, KART_BEZEICHNUNG, KART_SORTIERUNG) values ('FAX',   'Fax',     40);
insert into ALLG_KOMMUNIKATIONSARTEN (KART_CODE, KART_BEZEICHNUNG, KART_SORTIERUNG) values ('WEB',   'Website', 50);

-- Zahlungsbedingungen
insert into ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_BEZEICHNUNG, ZBED_ZIEL_TAGE, ZBED_SKONTO_TAGE, ZBED_SKONTO_PROZENT) values ('Sofort netto',                 0, null, null);
insert into ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_BEZEICHNUNG, ZBED_ZIEL_TAGE, ZBED_SKONTO_TAGE, ZBED_SKONTO_PROZENT) values ('14 Tage netto',               14, null, null);
insert into ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_BEZEICHNUNG, ZBED_ZIEL_TAGE, ZBED_SKONTO_TAGE, ZBED_SKONTO_PROZENT) values ('30 Tage netto',               30, null, null);
insert into ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_BEZEICHNUNG, ZBED_ZIEL_TAGE, ZBED_SKONTO_TAGE, ZBED_SKONTO_PROZENT) values ('8 Tage 2 %, 30 Tage netto',   30,    8,    2);

-- Rechtsformen
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('GmbH',         'Gesellschaft mit beschränkter Haftung');
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('AG',           'Aktiengesellschaft');
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('KG',           'Kommanditgesellschaft');
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('OG',           'Offene Gesellschaft');
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('GmbH & Co KG', 'GmbH & Co Kommanditgesellschaft');
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('e.U.',         'Eingetragenes Unternehmen');
insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG) values ('Verein',       'Verein');

-- Standorttypen
insert into KUND_STANDORT_TYPEN (STYP_BEZEICHNUNG) values ('Hauptsitz');
insert into KUND_STANDORT_TYPEN (STYP_BEZEICHNUNG) values ('Filiale');
insert into KUND_STANDORT_TYPEN (STYP_BEZEICHNUNG) values ('Lager');
insert into KUND_STANDORT_TYPEN (STYP_BEZEICHNUNG) values ('Baustelle');

-- Betreuungsrollen
insert into KUND_BETREUUNGSROLLEN (BROL_CODE, BROL_BEZEICHNUNG, BROL_SORTIERUNG) values ('SB', 'Sachbearbeiter', 10);
insert into KUND_BETREUUNGSROLLEN (BROL_CODE, BROL_BEZEICHNUNG, BROL_SORTIERUNG) values ('PL', 'Projektleiter',  20);
insert into KUND_BETREUUNGSROLLEN (BROL_CODE, BROL_BEZEICHNUNG, BROL_SORTIERUNG) values ('AD', 'Außendienst',    30);
insert into KUND_BETREUUNGSROLLEN (BROL_CODE, BROL_BEZEICHNUNG, BROL_SORTIERUNG) values ('BH', 'Buchhaltung',    40);

commit;
