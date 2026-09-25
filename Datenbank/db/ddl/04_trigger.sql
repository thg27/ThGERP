-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG)
-- 04 – Trigger: Primärschlüssel (SYS_GUID) und Audit-Spalten
-- Erzeugt: 2026-09-23
-- Voraussetzung: Oracle 12.2+ (Objektnamen > 30 Zeichen), getestet fuer 19c
-- =====================================================================

create or replace trigger LAND_BIU
  before insert or update on ALLG_LAENDER
  for each row
begin
  if inserting then
    :new.LAND_CODE := upper(:new.LAND_CODE);
    :new.LAND_CREATED_ON  := systimestamp;
    :new.LAND_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.LAND_UPDATED_ON  := null;
    :new.LAND_UPDATED_BY  := null;
    :new.LAND_ROW_VERSION := 1;
  elsif updating then
    :new.LAND_CODE          := :old.LAND_CODE;  -- Primaerschluessel ist unveraenderlich
    :new.LAND_CREATED_ON  := :old.LAND_CREATED_ON;
    :new.LAND_CREATED_BY  := :old.LAND_CREATED_BY;
    :new.LAND_UPDATED_ON  := systimestamp;
    :new.LAND_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.LAND_ROW_VERSION := nvl(:old.LAND_ROW_VERSION, 0) + 1;
  end if;
end LAND_BIU;
/

create or replace trigger ZBED_BIU
  before insert or update on ALLG_ZAHLUNGSBEDINGUNGEN
  for each row
begin
  if inserting then
    :new.ZBED_ID := coalesce(:new.ZBED_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.ZBED_CREATED_ON  := systimestamp;
    :new.ZBED_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ZBED_UPDATED_ON  := null;
    :new.ZBED_UPDATED_BY  := null;
    :new.ZBED_ROW_VERSION := 1;
  elsif updating then
    :new.ZBED_ID          := :old.ZBED_ID;  -- Primaerschluessel ist unveraenderlich
    :new.ZBED_CREATED_ON  := :old.ZBED_CREATED_ON;
    :new.ZBED_CREATED_BY  := :old.ZBED_CREATED_BY;
    :new.ZBED_UPDATED_ON  := systimestamp;
    :new.ZBED_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ZBED_ROW_VERSION := nvl(:old.ZBED_ROW_VERSION, 0) + 1;
  end if;
end ZBED_BIU;
/

create or replace trigger KART_BIU
  before insert or update on ALLG_KOMMUNIKATIONSARTEN
  for each row
begin
  if inserting then
    :new.KART_ID := coalesce(:new.KART_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KART_CREATED_ON  := systimestamp;
    :new.KART_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KART_UPDATED_ON  := null;
    :new.KART_UPDATED_BY  := null;
    :new.KART_ROW_VERSION := 1;
  elsif updating then
    :new.KART_ID          := :old.KART_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KART_CREATED_ON  := :old.KART_CREATED_ON;
    :new.KART_CREATED_BY  := :old.KART_CREATED_BY;
    :new.KART_UPDATED_ON  := systimestamp;
    :new.KART_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KART_ROW_VERSION := nvl(:old.KART_ROW_VERSION, 0) + 1;
  end if;
end KART_BIU;
/

create or replace trigger MITA_BIU
  before insert or update on ALLG_MITARBEITER
  for each row
begin
  if inserting then
    :new.MITA_ID := coalesce(:new.MITA_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MITA_CREATED_ON  := systimestamp;
    :new.MITA_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MITA_UPDATED_ON  := null;
    :new.MITA_UPDATED_BY  := null;
    :new.MITA_ROW_VERSION := 1;
  elsif updating then
    :new.MITA_ID          := :old.MITA_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MITA_CREATED_ON  := :old.MITA_CREATED_ON;
    :new.MITA_CREATED_BY  := :old.MITA_CREATED_BY;
    :new.MITA_UPDATED_ON  := systimestamp;
    :new.MITA_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MITA_ROW_VERSION := nvl(:old.MITA_ROW_VERSION, 0) + 1;
  end if;
end MITA_BIU;
/

create or replace trigger MKOM_BIU
  before insert or update on ALLG_MITARBEITER_KOMMUNIKATION
  for each row
begin
  if inserting then
    :new.MKOM_ID := coalesce(:new.MKOM_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.MKOM_CREATED_ON  := systimestamp;
    :new.MKOM_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MKOM_UPDATED_ON  := null;
    :new.MKOM_UPDATED_BY  := null;
    :new.MKOM_ROW_VERSION := 1;
  elsif updating then
    :new.MKOM_ID          := :old.MKOM_ID;  -- Primaerschluessel ist unveraenderlich
    :new.MKOM_CREATED_ON  := :old.MKOM_CREATED_ON;
    :new.MKOM_CREATED_BY  := :old.MKOM_CREATED_BY;
    :new.MKOM_UPDATED_ON  := systimestamp;
    :new.MKOM_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.MKOM_ROW_VERSION := nvl(:old.MKOM_ROW_VERSION, 0) + 1;
  end if;
end MKOM_BIU;
/

create or replace trigger AREG_BIU
  before insert or update on ALLG_ADRESSREGISTER
  for each row
begin
  if inserting then
    :new.AREG_CREATED_ON  := systimestamp;
    :new.AREG_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.AREG_UPDATED_ON  := null;
    :new.AREG_UPDATED_BY  := null;
    :new.AREG_ROW_VERSION := 1;
  elsif updating then
    :new.AREG_ADRCD          := :old.AREG_ADRCD;  -- Primaerschluessel ist unveraenderlich
    :new.AREG_CREATED_ON  := :old.AREG_CREATED_ON;
    :new.AREG_CREATED_BY  := :old.AREG_CREATED_BY;
    :new.AREG_UPDATED_ON  := systimestamp;
    :new.AREG_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.AREG_ROW_VERSION := nvl(:old.AREG_ROW_VERSION, 0) + 1;
  end if;
end AREG_BIU;
/

create or replace trigger ADRE_BIU
  before insert or update on ALLG_ADRESSEN
  for each row
declare
  l_hat_register ALLG_LAENDER.LAND_HAT_REGISTER%type;
begin
  if inserting then
    :new.ADRE_ID := coalesce(:new.ADRE_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.ADRE_CREATED_ON  := systimestamp;
    :new.ADRE_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ADRE_UPDATED_ON  := null;
    :new.ADRE_UPDATED_BY  := null;
    :new.ADRE_ROW_VERSION := 1;
  elsif updating then
    :new.ADRE_ID          := :old.ADRE_ID;  -- Primaerschluessel ist unveraenderlich
    :new.ADRE_CREATED_ON  := :old.ADRE_CREATED_ON;
    :new.ADRE_CREATED_BY  := :old.ADRE_CREATED_BY;
    :new.ADRE_UPDATED_ON  := systimestamp;
    :new.ADRE_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ADRE_ROW_VERSION := nvl(:old.ADRE_ROW_VERSION, 0) + 1;
  end if;

  -- Manuelle Adressen nur fuer Laender ohne Adressregister
  if :new.ADRE_QUELLE = 'MANUELL' then
    select max(LAND_HAT_REGISTER) into l_hat_register
      from ALLG_LAENDER
     where LAND_CODE = :new.ADRE_LAND_CODE;
    if l_hat_register = 'Y' then
      raise_application_error(-20100,
        'Fuer Land ' || :new.ADRE_LAND_CODE || ' muss die Adresse aus dem Adressregister uebernommen werden.');
    end if;
  end if;
end ADRE_BIU;
/

create or replace trigger RFRM_BIU
  before insert or update on KUND_RECHTSFORMEN
  for each row
begin
  if inserting then
    :new.RFRM_ID := coalesce(:new.RFRM_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.RFRM_CREATED_ON  := systimestamp;
    :new.RFRM_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RFRM_UPDATED_ON  := null;
    :new.RFRM_UPDATED_BY  := null;
    :new.RFRM_ROW_VERSION := 1;
  elsif updating then
    :new.RFRM_ID          := :old.RFRM_ID;  -- Primaerschluessel ist unveraenderlich
    :new.RFRM_CREATED_ON  := :old.RFRM_CREATED_ON;
    :new.RFRM_CREATED_BY  := :old.RFRM_CREATED_BY;
    :new.RFRM_UPDATED_ON  := systimestamp;
    :new.RFRM_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.RFRM_ROW_VERSION := nvl(:old.RFRM_ROW_VERSION, 0) + 1;
  end if;
end RFRM_BIU;
/

create or replace trigger STYP_BIU
  before insert or update on KUND_STANDORT_TYPEN
  for each row
begin
  if inserting then
    :new.STYP_ID := coalesce(:new.STYP_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.STYP_CREATED_ON  := systimestamp;
    :new.STYP_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.STYP_UPDATED_ON  := null;
    :new.STYP_UPDATED_BY  := null;
    :new.STYP_ROW_VERSION := 1;
  elsif updating then
    :new.STYP_ID          := :old.STYP_ID;  -- Primaerschluessel ist unveraenderlich
    :new.STYP_CREATED_ON  := :old.STYP_CREATED_ON;
    :new.STYP_CREATED_BY  := :old.STYP_CREATED_BY;
    :new.STYP_UPDATED_ON  := systimestamp;
    :new.STYP_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.STYP_ROW_VERSION := nvl(:old.STYP_ROW_VERSION, 0) + 1;
  end if;
end STYP_BIU;
/

create or replace trigger BROL_BIU
  before insert or update on KUND_BETREUUNGSROLLEN
  for each row
begin
  if inserting then
    :new.BROL_ID := coalesce(:new.BROL_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.BROL_CREATED_ON  := systimestamp;
    :new.BROL_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BROL_UPDATED_ON  := null;
    :new.BROL_UPDATED_BY  := null;
    :new.BROL_ROW_VERSION := 1;
  elsif updating then
    :new.BROL_ID          := :old.BROL_ID;  -- Primaerschluessel ist unveraenderlich
    :new.BROL_CREATED_ON  := :old.BROL_CREATED_ON;
    :new.BROL_CREATED_BY  := :old.BROL_CREATED_BY;
    :new.BROL_UPDATED_ON  := systimestamp;
    :new.BROL_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.BROL_ROW_VERSION := nvl(:old.BROL_ROW_VERSION, 0) + 1;
  end if;
end BROL_BIU;
/

create or replace trigger KUND_BIU
  before insert or update on KUND_KUNDEN
  for each row
begin
  if inserting then
    :new.KUND_ID := coalesce(:new.KUND_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KUND_CREATED_ON  := systimestamp;
    :new.KUND_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KUND_UPDATED_ON  := null;
    :new.KUND_UPDATED_BY  := null;
    :new.KUND_ROW_VERSION := 1;
  elsif updating then
    :new.KUND_ID          := :old.KUND_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KUND_CREATED_ON  := :old.KUND_CREATED_ON;
    :new.KUND_CREATED_BY  := :old.KUND_CREATED_BY;
    :new.KUND_UPDATED_ON  := systimestamp;
    :new.KUND_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KUND_ROW_VERSION := nvl(:old.KUND_ROW_VERSION, 0) + 1;
  end if;
end KUND_BIU;
/

create or replace trigger KMIT_BIU
  before insert or update on KUND_KUNDEN_MITARBEITER
  for each row
begin
  if inserting then
    :new.KMIT_ID := coalesce(:new.KMIT_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KMIT_CREATED_ON  := systimestamp;
    :new.KMIT_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KMIT_UPDATED_ON  := null;
    :new.KMIT_UPDATED_BY  := null;
    :new.KMIT_ROW_VERSION := 1;
  elsif updating then
    :new.KMIT_ID          := :old.KMIT_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KMIT_CREATED_ON  := :old.KMIT_CREATED_ON;
    :new.KMIT_CREATED_BY  := :old.KMIT_CREATED_BY;
    :new.KMIT_UPDATED_ON  := systimestamp;
    :new.KMIT_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KMIT_ROW_VERSION := nvl(:old.KMIT_ROW_VERSION, 0) + 1;
  end if;
end KMIT_BIU;
/

create or replace trigger KSTO_BIU
  before insert or update on KUND_STANDORTE
  for each row
begin
  if inserting then
    :new.KSTO_ID := coalesce(:new.KSTO_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KSTO_CREATED_ON  := systimestamp;
    :new.KSTO_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KSTO_UPDATED_ON  := null;
    :new.KSTO_UPDATED_BY  := null;
    :new.KSTO_ROW_VERSION := 1;
  elsif updating then
    :new.KSTO_ID          := :old.KSTO_ID;  -- Primaerschluessel ist unveraenderlich
    :new.KSTO_CREATED_ON  := :old.KSTO_CREATED_ON;
    :new.KSTO_CREATED_BY  := :old.KSTO_CREATED_BY;
    :new.KSTO_UPDATED_ON  := systimestamp;
    :new.KSTO_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KSTO_ROW_VERSION := nvl(:old.KSTO_ROW_VERSION, 0) + 1;
  end if;
end KSTO_BIU;
/

create or replace trigger SKOM_BIU
  before insert or update on KUND_STANDORT_KOMMUNIKATION
  for each row
begin
  if inserting then
    :new.SKOM_ID := coalesce(:new.SKOM_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.SKOM_CREATED_ON  := systimestamp;
    :new.SKOM_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.SKOM_UPDATED_ON  := null;
    :new.SKOM_UPDATED_BY  := null;
    :new.SKOM_ROW_VERSION := 1;
  elsif updating then
    :new.SKOM_ID          := :old.SKOM_ID;  -- Primaerschluessel ist unveraenderlich
    :new.SKOM_CREATED_ON  := :old.SKOM_CREATED_ON;
    :new.SKOM_CREATED_BY  := :old.SKOM_CREATED_BY;
    :new.SKOM_UPDATED_ON  := systimestamp;
    :new.SKOM_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.SKOM_ROW_VERSION := nvl(:old.SKOM_ROW_VERSION, 0) + 1;
  end if;
end SKOM_BIU;
/

create or replace trigger ANSP_BIU
  before insert or update on KUND_ANSPRECHPARTNER
  for each row
begin
  if inserting then
    :new.ANSP_ID := coalesce(:new.ANSP_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.ANSP_CREATED_ON  := systimestamp;
    :new.ANSP_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ANSP_UPDATED_ON  := null;
    :new.ANSP_UPDATED_BY  := null;
    :new.ANSP_ROW_VERSION := 1;
  elsif updating then
    :new.ANSP_ID          := :old.ANSP_ID;  -- Primaerschluessel ist unveraenderlich
    :new.ANSP_CREATED_ON  := :old.ANSP_CREATED_ON;
    :new.ANSP_CREATED_BY  := :old.ANSP_CREATED_BY;
    :new.ANSP_UPDATED_ON  := systimestamp;
    :new.ANSP_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.ANSP_ROW_VERSION := nvl(:old.ANSP_ROW_VERSION, 0) + 1;
  end if;
end ANSP_BIU;
/

create or replace trigger AKOM_BIU
  before insert or update on KUND_ANSPRECHPARTNER_KOMMUNIKATION
  for each row
begin
  if inserting then
    :new.AKOM_ID := coalesce(:new.AKOM_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.AKOM_CREATED_ON  := systimestamp;
    :new.AKOM_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.AKOM_UPDATED_ON  := null;
    :new.AKOM_UPDATED_BY  := null;
    :new.AKOM_ROW_VERSION := 1;
  elsif updating then
    :new.AKOM_ID          := :old.AKOM_ID;  -- Primaerschluessel ist unveraenderlich
    :new.AKOM_CREATED_ON  := :old.AKOM_CREATED_ON;
    :new.AKOM_CREATED_BY  := :old.AKOM_CREATED_BY;
    :new.AKOM_UPDATED_ON  := systimestamp;
    :new.AKOM_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.AKOM_ROW_VERSION := nvl(:old.AKOM_ROW_VERSION, 0) + 1;
  end if;
end AKOM_BIU;
/
