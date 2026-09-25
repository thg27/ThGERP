-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 02 – Fremdschlüssel und Indizes auf FK-Spalten
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

alter table ALLG_MITARBEITER_KOMMUNIKATION add constraint MKOM_MITA_FK
  foreign key (MKOM_MITA_ID) references ALLG_MITARBEITER (MITA_ID);
create index MKOM_MITA_I on ALLG_MITARBEITER_KOMMUNIKATION (MKOM_MITA_ID);

alter table ALLG_MITARBEITER_KOMMUNIKATION add constraint MKOM_KART_FK
  foreign key (MKOM_KART_ID) references ALLG_KOMMUNIKATIONSARTEN (KART_ID);
create index MKOM_KART_I on ALLG_MITARBEITER_KOMMUNIKATION (MKOM_KART_ID);

alter table ALLG_ADRESSREGISTER add constraint AREG_LAND_FK
  foreign key (AREG_LAND_CODE) references ALLG_LAENDER (LAND_CODE);
create index AREG_LAND_I on ALLG_ADRESSREGISTER (AREG_LAND_CODE);

alter table ALLG_ADRESSEN add constraint ADRE_AREG_FK
  foreign key (ADRE_AREG_ADRCD) references ALLG_ADRESSREGISTER (AREG_ADRCD);
create index ADRE_AREG_I on ALLG_ADRESSEN (ADRE_AREG_ADRCD);

alter table ALLG_ADRESSEN add constraint ADRE_LAND_FK
  foreign key (ADRE_LAND_CODE) references ALLG_LAENDER (LAND_CODE);
create index ADRE_LAND_I on ALLG_ADRESSEN (ADRE_LAND_CODE);

alter table KUND_KUNDEN add constraint KUND_PARENT_KUND_FK
  foreign key (KUND_PARENT_KUND_ID) references KUND_KUNDEN (KUND_ID);
create index KUND_PARENT_KUND_I on KUND_KUNDEN (KUND_PARENT_KUND_ID);

alter table KUND_KUNDEN add constraint KUND_RE_KUND_FK
  foreign key (KUND_RE_KUND_ID) references KUND_KUNDEN (KUND_ID);
create index KUND_RE_KUND_I on KUND_KUNDEN (KUND_RE_KUND_ID);

alter table KUND_KUNDEN add constraint KUND_RFRM_FK
  foreign key (KUND_RFRM_ID) references KUND_RECHTSFORMEN (RFRM_ID);
create index KUND_RFRM_I on KUND_KUNDEN (KUND_RFRM_ID);

alter table KUND_KUNDEN add constraint KUND_ZBED_FK
  foreign key (KUND_ZBED_ID) references ALLG_ZAHLUNGSBEDINGUNGEN (ZBED_ID);
create index KUND_ZBED_I on KUND_KUNDEN (KUND_ZBED_ID);

alter table KUND_KUNDEN_MITARBEITER add constraint KMIT_KUND_FK
  foreign key (KMIT_KUND_ID) references KUND_KUNDEN (KUND_ID);
create index KMIT_KUND_I on KUND_KUNDEN_MITARBEITER (KMIT_KUND_ID);

alter table KUND_KUNDEN_MITARBEITER add constraint KMIT_MITA_FK
  foreign key (KMIT_MITA_ID) references ALLG_MITARBEITER (MITA_ID);
create index KMIT_MITA_I on KUND_KUNDEN_MITARBEITER (KMIT_MITA_ID);

alter table KUND_KUNDEN_MITARBEITER add constraint KMIT_BROL_FK
  foreign key (KMIT_BROL_ID) references KUND_BETREUUNGSROLLEN (BROL_ID);
create index KMIT_BROL_I on KUND_KUNDEN_MITARBEITER (KMIT_BROL_ID);

alter table KUND_STANDORTE add constraint KSTO_KUND_FK
  foreign key (KSTO_KUND_ID) references KUND_KUNDEN (KUND_ID);
create index KSTO_KUND_I on KUND_STANDORTE (KSTO_KUND_ID);

alter table KUND_STANDORTE add constraint KSTO_STYP_FK
  foreign key (KSTO_STYP_ID) references KUND_STANDORT_TYPEN (STYP_ID);
create index KSTO_STYP_I on KUND_STANDORTE (KSTO_STYP_ID);

alter table KUND_STANDORTE add constraint KSTO_ADRE_FK
  foreign key (KSTO_ADRE_ID) references ALLG_ADRESSEN (ADRE_ID);
create index KSTO_ADRE_I on KUND_STANDORTE (KSTO_ADRE_ID);

alter table KUND_STANDORT_KOMMUNIKATION add constraint SKOM_KSTO_FK
  foreign key (SKOM_KSTO_ID) references KUND_STANDORTE (KSTO_ID);
create index SKOM_KSTO_I on KUND_STANDORT_KOMMUNIKATION (SKOM_KSTO_ID);

alter table KUND_STANDORT_KOMMUNIKATION add constraint SKOM_KART_FK
  foreign key (SKOM_KART_ID) references ALLG_KOMMUNIKATIONSARTEN (KART_ID);
create index SKOM_KART_I on KUND_STANDORT_KOMMUNIKATION (SKOM_KART_ID);

alter table KUND_ANSPRECHPARTNER add constraint ANSP_KSTO_FK
  foreign key (ANSP_KSTO_ID) references KUND_STANDORTE (KSTO_ID);
create index ANSP_KSTO_I on KUND_ANSPRECHPARTNER (ANSP_KSTO_ID);

alter table KUND_ANSPRECHPARTNER_KOMMUNIKATION add constraint AKOM_ANSP_FK
  foreign key (AKOM_ANSP_ID) references KUND_ANSPRECHPARTNER (ANSP_ID);
create index AKOM_ANSP_I on KUND_ANSPRECHPARTNER_KOMMUNIKATION (AKOM_ANSP_ID);

alter table KUND_ANSPRECHPARTNER_KOMMUNIKATION add constraint AKOM_KART_FK
  foreign key (AKOM_KART_ID) references ALLG_KOMMUNIKATIONSARTEN (KART_ID);
create index AKOM_KART_I on KUND_ANSPRECHPARTNER_KOMMUNIKATION (AKOM_KART_ID);
