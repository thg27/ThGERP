-- =====================================================================
-- ThGERP (Gruppe ALLG)
-- 47 – Anmeldung mit Office 365 (Microsoft Entra ID, Portal 20000):
--      ALLG_MITARBEITER.MITA_EMAIL: Office-365-Adresse des Mitarbeiters (eindeutig, in Kleinbuchstaben). Nach der
--      Anmeldung mit Microsoft sucht das Authentifizierungsschema den Mitarbeiter ueber diese Adresse und arbeitet mit
--      seinem MITA_BENUTZERNAME weiter (Anleitung: Doku/anleitung-entra-id.md).
--      Trigger MITA_BIU wie in 17, ergaenzt um die Normalisierung der Adresse.
-- Erzeugt: 2026-10-29
-- Wiederholbar (DDL_UTIL; create or replace).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.spalte('ALLG_MITARBEITER', 'MITA_EMAIL', 'varchar2(255 char)', 'Y');
    DDL_UTIL.constraint_('ALLG_MITARBEITER', 'MITA_EMAIL_UK', 'U', 'MITA_EMAIL');
    DDL_UTIL.trigger_pruefen('MITA_BIU', 'ALLG_MITARBEITER');
end;
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
  :new.MITA_BENUTZERNAME := upper(trim(:new.MITA_BENUTZERNAME));
  -- Microsoft liefert preferred_username in beliebiger Schreibweise; gesucht wird mit lower(:APP_USER)
  :new.MITA_EMAIL := lower(trim(:new.MITA_EMAIL));
end MITA_BIU;
/

comment on column ALLG_MITARBEITER.MITA_EMAIL is 'Office-365-Adresse (Microsoft Entra ID, preferred_username) fuer die Anmeldung mit Microsoft; eindeutig, Kleinbuchstaben';

prompt ALLG_MITARBEITER.MITA_EMAIL installiert bzw. abgeglichen.
