-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 01 – Tabellen mit Primär-, Unique- und Check-Constraints
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

-- ALLG_LAENDER (LAND): Laender (ISO-3166-1 Alpha-2) inkl. EU-Kennzeichen und Verfuegbarkeit eines Adressregisters
create table ALLG_LAENDER (
  LAND_CODE                          varchar2(2 char) not null,
  LAND_BEZEICHNUNG                   varchar2(100 char) not null,
  LAND_IST_EU                        varchar2(1 char) default 'N' not null,
  LAND_HAT_REGISTER                  varchar2(1 char) default 'N' not null,
  LAND_CREATED_ON                    timestamp not null,
  LAND_CREATED_BY                    varchar2(255 char) not null,
  LAND_UPDATED_ON                    timestamp,
  LAND_UPDATED_BY                    varchar2(255 char),
  LAND_ROW_VERSION                   number not null,
  constraint LAND_PK primary key (LAND_CODE),
  constraint LAND_IST_EU_CK check (LAND_IST_EU in ('Y', 'N')),
  constraint LAND_HAT_REGISTER_CK check (LAND_HAT_REGISTER in ('Y', 'N'))
);

-- ALLG_ZAHLUNGSBEDINGUNGEN (ZBED): Zahlungsbedingungen (Zahlungsziel, Skonto)
create table ALLG_ZAHLUNGSBEDINGUNGEN (
  ZBED_ID                            number not null,
  ZBED_BEZEICHNUNG                   varchar2(100 char) not null,
  ZBED_ZIEL_TAGE                     number(3) not null,
  ZBED_SKONTO_TAGE                   number(3),
  ZBED_SKONTO_PROZENT                number(5,2),
  ZBED_CREATED_ON                    timestamp not null,
  ZBED_CREATED_BY                    varchar2(255 char) not null,
  ZBED_UPDATED_ON                    timestamp,
  ZBED_UPDATED_BY                    varchar2(255 char),
  ZBED_ROW_VERSION                   number not null,
  constraint ZBED_PK primary key (ZBED_ID),
  constraint ZBED_ZIEL_TAGE_CK check (ZBED_ZIEL_TAGE >= 0),
  constraint ZBED_SKONTO_TAGE_CK check (ZBED_SKONTO_TAGE >= 0),
  constraint ZBED_SKONTO_PROZENT_CK check (ZBED_SKONTO_PROZENT between 0 and 100),
  constraint ZBED_BEZEICHNUNG_UK unique (ZBED_BEZEICHNUNG)
);

-- ALLG_KOMMUNIKATIONSARTEN (KART): Kommunikationsarten (E-Mail, Telefon, Mobil, Fax ...)
create table ALLG_KOMMUNIKATIONSARTEN (
  KART_ID                            number not null,
  KART_CODE                          varchar2(20 char) not null,
  KART_BEZEICHNUNG                   varchar2(100 char) not null,
  KART_SORTIERUNG                    number(5),
  KART_CREATED_ON                    timestamp not null,
  KART_CREATED_BY                    varchar2(255 char) not null,
  KART_UPDATED_ON                    timestamp,
  KART_UPDATED_BY                    varchar2(255 char),
  KART_ROW_VERSION                   number not null,
  constraint KART_PK primary key (KART_ID),
  constraint KART_CODE_UK unique (KART_CODE)
);

-- ALLG_MITARBEITER (MITA): Eigene Mitarbeiter (intern), modulübergreifend verwendet
create table ALLG_MITARBEITER (
  MITA_ID                            number not null,
  MITA_KUERZEL                       varchar2(10 char) not null,
  MITA_NAME                          varchar2(200 char) not null,
  MITA_CREATED_ON                    timestamp not null,
  MITA_CREATED_BY                    varchar2(255 char) not null,
  MITA_UPDATED_ON                    timestamp,
  MITA_UPDATED_BY                    varchar2(255 char),
  MITA_ROW_VERSION                   number not null,
  constraint MITA_PK primary key (MITA_ID),
  constraint MITA_KUERZEL_UK unique (MITA_KUERZEL)
);

-- ALLG_MITARBEITER_KOMMUNIKATION (MKOM): Kommunikationsdaten der Mitarbeiter
create table ALLG_MITARBEITER_KOMMUNIKATION (
  MKOM_ID                            number not null,
  MKOM_MITA_ID                       number not null,
  MKOM_KART_ID                       number not null,
  MKOM_WERT                          varchar2(255 char) not null,
  MKOM_BEZEICHNUNG                   varchar2(100 char),
  MKOM_IST_BEVORZUGT                 varchar2(1 char) default 'N' not null,
  MKOM_CREATED_ON                    timestamp not null,
  MKOM_CREATED_BY                    varchar2(255 char) not null,
  MKOM_UPDATED_ON                    timestamp,
  MKOM_UPDATED_BY                    varchar2(255 char),
  MKOM_ROW_VERSION                   number not null,
  constraint MKOM_PK primary key (MKOM_ID),
  constraint MKOM_IST_BEVORZUGT_CK check (MKOM_IST_BEVORZUGT in ('Y', 'N'))
);

-- ALLG_ADRESSREGISTER (AREG): Importierte Kopie des amtlichen Adressregisters (AT: BEV, © Österreichisches Adressregister)
create table ALLG_ADRESSREGISTER (
  AREG_ADRCD                         varchar2(7 char) not null,
  AREG_LAND_CODE                     varchar2(2 char) not null,
  AREG_GKZ                           varchar2(5 char),
  AREG_GEMEINDE                      varchar2(100 char),
  AREG_ORTSCHAFT                     varchar2(100 char),
  AREG_PLZ                           varchar2(10 char) not null,
  AREG_STRASSE                       varchar2(200 char),
  AREG_HAUSNUMMER                    varchar2(50 char),
  AREG_LAT                           number(9,6),
  AREG_LON                           number(9,6),
  AREG_IST_AKTIV                     varchar2(1 char) default 'Y' not null,
  AREG_STICHTAG                      date not null,
  AREG_CREATED_ON                    timestamp not null,
  AREG_CREATED_BY                    varchar2(255 char) not null,
  AREG_UPDATED_ON                    timestamp,
  AREG_UPDATED_BY                    varchar2(255 char),
  AREG_ROW_VERSION                   number not null,
  constraint AREG_PK primary key (AREG_ADRCD),
  constraint AREG_IST_AKTIV_CK check (AREG_IST_AKTIV in ('Y', 'N'))
);

-- ALLG_ADRESSEN (ADRE): Verwendete Adressen: aus Adressregister uebernommen oder manuell (nur Laender ohne Register)
create table ALLG_ADRESSEN (
  ADRE_ID                            number not null,
  ADRE_AREG_ADRCD                    varchar2(7 char),
  ADRE_LAND_CODE                     varchar2(2 char) not null,
  ADRE_QUELLE                        varchar2(10 char) not null,
  ADRE_STRASSE                       varchar2(200 char),
  ADRE_HAUSNUMMER                    varchar2(50 char),
  ADRE_ZUSATZ                        varchar2(50 char),
  ADRE_PLZ                           varchar2(10 char) not null,
  ADRE_ORT                           varchar2(100 char) not null,
  ADRE_REGION                        varchar2(100 char),
  ADRE_LAT                           number(9,6),
  ADRE_LON                           number(9,6),
  ADRE_REG_STICHTAG                  date,
  ADRE_CREATED_ON                    timestamp not null,
  ADRE_CREATED_BY                    varchar2(255 char) not null,
  ADRE_UPDATED_ON                    timestamp,
  ADRE_UPDATED_BY                    varchar2(255 char),
  ADRE_ROW_VERSION                   number not null,
  constraint ADRE_PK primary key (ADRE_ID),
  constraint ADRE_QUELLE_CK check (ADRE_QUELLE in ('REGISTER', 'MANUELL')),
  constraint ADRE_QUELLE_ADRCD_CK check ((ADRE_QUELLE = 'REGISTER' and ADRE_AREG_ADRCD is not null) or (ADRE_QUELLE = 'MANUELL' and ADRE_AREG_ADRCD is null))
);

-- KUND_RECHTSFORMEN (RFRM): Rechtsformen (GmbH, KG, e.U. ...)
create table KUND_RECHTSFORMEN (
  RFRM_ID                            number not null,
  RFRM_KURZ                          varchar2(30 char) not null,
  RFRM_BEZEICHNUNG                   varchar2(100 char) not null,
  RFRM_CREATED_ON                    timestamp not null,
  RFRM_CREATED_BY                    varchar2(255 char) not null,
  RFRM_UPDATED_ON                    timestamp,
  RFRM_UPDATED_BY                    varchar2(255 char),
  RFRM_ROW_VERSION                   number not null,
  constraint RFRM_PK primary key (RFRM_ID),
  constraint RFRM_KURZ_UK unique (RFRM_KURZ)
);

-- KUND_STANDORT_TYPEN (STYP): Standorttypen (Hauptsitz, Filiale, Lager ...)
create table KUND_STANDORT_TYPEN (
  STYP_ID                            number not null,
  STYP_BEZEICHNUNG                   varchar2(100 char) not null,
  STYP_CREATED_ON                    timestamp not null,
  STYP_CREATED_BY                    varchar2(255 char) not null,
  STYP_UPDATED_ON                    timestamp,
  STYP_UPDATED_BY                    varchar2(255 char),
  STYP_ROW_VERSION                   number not null,
  constraint STYP_PK primary key (STYP_ID),
  constraint STYP_BEZEICHNUNG_UK unique (STYP_BEZEICHNUNG)
);

-- KUND_BETREUUNGSROLLEN (BROL): Rollen eines Mitarbeiters in der Kundenbetreuung
create table KUND_BETREUUNGSROLLEN (
  BROL_ID                            number not null,
  BROL_CODE                          varchar2(20 char) not null,
  BROL_BEZEICHNUNG                   varchar2(100 char) not null,
  BROL_SORTIERUNG                    number(5),
  BROL_CREATED_ON                    timestamp not null,
  BROL_CREATED_BY                    varchar2(255 char) not null,
  BROL_UPDATED_ON                    timestamp,
  BROL_UPDATED_BY                    varchar2(255 char),
  BROL_ROW_VERSION                   number not null,
  constraint BROL_PK primary key (BROL_ID),
  constraint BROL_CODE_UK unique (BROL_CODE)
);

-- KUND_KUNDEN (KUND): Kundenstamm (Firmen und Privatpersonen) inkl. Konzernhierarchie
create table KUND_KUNDEN (
  KUND_ID                            number not null,
  KUND_PARENT_KUND_ID                number,
  KUND_RE_KUND_ID                    number,
  KUND_RFRM_ID                       number,
  KUND_ZBED_ID                       number,
  KUND_NUMMER                        varchar2(20 char) not null,
  KUND_TYP                           varchar2(10 char) not null,
  KUND_FIRMENNAME                    varchar2(200 char),
  KUND_ANREDE                        varchar2(30 char),
  KUND_VORNAME                       varchar2(100 char),
  KUND_NACHNAME                      varchar2(100 char),
  KUND_UID_NUMMER                    varchar2(20 char),
  KUND_FIRMENBUCHNR                  varchar2(20 char),
  KUND_EMAIL_RECHNUNG                varchar2(255 char),
  KUND_KREDITLIMIT                   number(12,2),
  KUND_STATUS                        varchar2(10 char) not null,
  KUND_KUNDE_SEIT                    date,
  KUND_DSGVO_MARKETING_AM            date,
  KUND_CREATED_ON                    timestamp not null,
  KUND_CREATED_BY                    varchar2(255 char) not null,
  KUND_UPDATED_ON                    timestamp,
  KUND_UPDATED_BY                    varchar2(255 char),
  KUND_ROW_VERSION                   number not null,
  constraint KUND_PK primary key (KUND_ID),
  constraint KUND_TYP_CK check (KUND_TYP in ('FIRMA', 'PRIVAT')),
  constraint KUND_KREDITLIMIT_CK check (KUND_KREDITLIMIT >= 0),
  constraint KUND_STATUS_CK check (KUND_STATUS in ('AKTIV', 'GESPERRT', 'INAKTIV')),
  constraint KUND_NUMMER_UK unique (KUND_NUMMER),
  constraint KUND_NAME_CK check ((KUND_TYP = 'FIRMA' and KUND_FIRMENNAME is not null) or (KUND_TYP = 'PRIVAT' and KUND_NACHNAME is not null)),
  constraint KUND_PARENT_CK check (KUND_PARENT_KUND_ID is null or KUND_PARENT_KUND_ID <> KUND_ID)
);

-- KUND_KUNDEN_MITARBEITER (KMIT): Zuordnung Mitarbeiter zu Kunde je Betreuungsrolle (mit Historie)
create table KUND_KUNDEN_MITARBEITER (
  KMIT_ID                            number not null,
  KMIT_KUND_ID                       number not null,
  KMIT_MITA_ID                       number not null,
  KMIT_BROL_ID                       number not null,
  KMIT_IST_HAUPTVERANTW              varchar2(1 char) default 'N' not null,
  KMIT_GUELTIG_VON                   date not null,
  KMIT_GUELTIG_BIS                   date,
  KMIT_BEMERKUNG                     varchar2(4000 char),
  KMIT_CREATED_ON                    timestamp not null,
  KMIT_CREATED_BY                    varchar2(255 char) not null,
  KMIT_UPDATED_ON                    timestamp,
  KMIT_UPDATED_BY                    varchar2(255 char),
  KMIT_ROW_VERSION                   number not null,
  constraint KMIT_PK primary key (KMIT_ID),
  constraint KMIT_IST_HAUPTVERANTW_CK check (KMIT_IST_HAUPTVERANTW in ('Y', 'N')),
  constraint KMIT_UK unique (KMIT_KUND_ID, KMIT_MITA_ID, KMIT_BROL_ID, KMIT_GUELTIG_VON),
  constraint KMIT_GUELTIG_CK check (KMIT_GUELTIG_BIS is null or KMIT_GUELTIG_BIS >= KMIT_GUELTIG_VON)
);

-- KUND_STANDORTE (KSTO): Standorte eines Kunden (Hauptsitz, Filialen, Lager ...)
create table KUND_STANDORTE (
  KSTO_ID                            number not null,
  KSTO_KUND_ID                       number not null,
  KSTO_STYP_ID                       number not null,
  KSTO_ADRE_ID                       number not null,
  KSTO_BEZEICHNUNG                   varchar2(100 char) not null,
  KSTO_IST_HAUPTSITZ                 varchar2(1 char) default 'N' not null,
  KSTO_IST_RECHNUNGSADR              varchar2(1 char) default 'N' not null,
  KSTO_IST_LIEFERADR                 varchar2(1 char) default 'N' not null,
  KSTO_GUELTIG_VON                   date,
  KSTO_GUELTIG_BIS                   date,
  KSTO_CREATED_ON                    timestamp not null,
  KSTO_CREATED_BY                    varchar2(255 char) not null,
  KSTO_UPDATED_ON                    timestamp,
  KSTO_UPDATED_BY                    varchar2(255 char),
  KSTO_ROW_VERSION                   number not null,
  constraint KSTO_PK primary key (KSTO_ID),
  constraint KSTO_IST_HAUPTSITZ_CK check (KSTO_IST_HAUPTSITZ in ('Y', 'N')),
  constraint KSTO_IST_RECHNUNGSADR_CK check (KSTO_IST_RECHNUNGSADR in ('Y', 'N')),
  constraint KSTO_IST_LIEFERADR_CK check (KSTO_IST_LIEFERADR in ('Y', 'N')),
  constraint KSTO_GUELTIG_CK check (KSTO_GUELTIG_BIS is null or KSTO_GUELTIG_VON is null or KSTO_GUELTIG_BIS >= KSTO_GUELTIG_VON)
);

-- KUND_STANDORT_KOMMUNIKATION (SKOM): Kommunikationsdaten der Kundenstandorte
create table KUND_STANDORT_KOMMUNIKATION (
  SKOM_ID                            number not null,
  SKOM_KSTO_ID                       number not null,
  SKOM_KART_ID                       number not null,
  SKOM_WERT                          varchar2(255 char) not null,
  SKOM_BEZEICHNUNG                   varchar2(100 char),
  SKOM_IST_BEVORZUGT                 varchar2(1 char) default 'N' not null,
  SKOM_CREATED_ON                    timestamp not null,
  SKOM_CREATED_BY                    varchar2(255 char) not null,
  SKOM_UPDATED_ON                    timestamp,
  SKOM_UPDATED_BY                    varchar2(255 char),
  SKOM_ROW_VERSION                   number not null,
  constraint SKOM_PK primary key (SKOM_ID),
  constraint SKOM_IST_BEVORZUGT_CK check (SKOM_IST_BEVORZUGT in ('Y', 'N'))
);

-- KUND_ANSPRECHPARTNER (ANSP): Ansprechpartner (externe Personen) an einem Kundenstandort
create table KUND_ANSPRECHPARTNER (
  ANSP_ID                            number not null,
  ANSP_KSTO_ID                       number not null,
  ANSP_ANREDE                        varchar2(30 char),
  ANSP_TITEL                         varchar2(50 char),
  ANSP_VORNAME                       varchar2(100 char),
  ANSP_NACHNAME                      varchar2(100 char) not null,
  ANSP_FUNKTION                      varchar2(100 char),
  ANSP_IST_HAUPTKONTAKT              varchar2(1 char) default 'N' not null,
  ANSP_CREATED_ON                    timestamp not null,
  ANSP_CREATED_BY                    varchar2(255 char) not null,
  ANSP_UPDATED_ON                    timestamp,
  ANSP_UPDATED_BY                    varchar2(255 char),
  ANSP_ROW_VERSION                   number not null,
  constraint ANSP_PK primary key (ANSP_ID),
  constraint ANSP_IST_HAUPTKONTAKT_CK check (ANSP_IST_HAUPTKONTAKT in ('Y', 'N'))
);

-- KUND_ANSPRECHPARTNER_KOMMUNIKATION (AKOM): Kommunikationsdaten der Ansprechpartner
create table KUND_ANSPRECHPARTNER_KOMMUNIKATION (
  AKOM_ID                            number not null,
  AKOM_ANSP_ID                       number not null,
  AKOM_KART_ID                       number not null,
  AKOM_WERT                          varchar2(255 char) not null,
  AKOM_BEZEICHNUNG                   varchar2(100 char),
  AKOM_IST_BEVORZUGT                 varchar2(1 char) default 'N' not null,
  AKOM_CREATED_ON                    timestamp not null,
  AKOM_CREATED_BY                    varchar2(255 char) not null,
  AKOM_UPDATED_ON                    timestamp,
  AKOM_UPDATED_BY                    varchar2(255 char),
  AKOM_ROW_VERSION                   number not null,
  constraint AKOM_PK primary key (AKOM_ID),
  constraint AKOM_IST_BEVORZUGT_CK check (AKOM_IST_BEVORZUGT in ('Y', 'N'))
);
