-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 09 – Kundennummer automatisch: 6-stellig aus KUND_NUMMER_SEQ (100001 - 999999),
--      vergeben im Trigger KUND_BIU beim Anlegen, danach unveraenderlich.
--      Eine beim Insert explizit angegebene Nummer (z.B. Datenuebernahme) bleibt erhalten.
-- Erzeugt: 2026-09-24
-- Voraussetzung: Oracle 23ai+ (create sequence if not exists)
--
-- Wiederholbar ausfuehrbar:
--   * Sequenz nur anlegen, wenn sie fehlt; liegt sie hinter der hoechsten numerischen
--     Kundennummer, wird sie per "restart start with" dahinter gesetzt
--   * Trigger KUND_BIU wird ersetzt (Abbruch, falls der Name zu einer anderen Tabelle gehoert)
-- =====================================================================

set define off
set serveroutput on size unlimited

create sequence if not exists KUND_NUMMER_SEQ
  start with 100001 minvalue 100001 maxvalue 999999 increment by 1 nocycle cache 20;

declare
    l_max  number;
    l_next number;
    l_tab  user_triggers.table_name%type;
begin
    -- Sequenz hinter die hoechste vorhandene 6-stellige Kundennummer setzen
    select max(to_number(KUND_NUMMER default null on conversion error))
      into l_max
      from KUND_KUNDEN
     where regexp_like(KUND_NUMMER, '^[0-9]{6}$');
    select last_number into l_next from user_sequences where sequence_name = 'KUND_NUMMER_SEQ';
    if l_max is not null and l_next <= l_max then
        execute immediate 'alter sequence KUND_NUMMER_SEQ restart start with ' || (l_max + 1);
        dbms_output.put_line('KUND_NUMMER_SEQ: neu gestartet bei ' || (l_max + 1));
    else
        dbms_output.put_line('KUND_NUMMER_SEQ: naechste Nummer ab ' || l_next);
    end if;

    -- Trigger-Name darf nicht zu einer anderen Tabelle gehoeren
    begin
        select table_name into l_tab from user_triggers where trigger_name = 'KUND_BIU';
        if l_tab <> 'KUND_KUNDEN' then
            raise_application_error(-20002, 'Trigger KUND_BIU gehoert bereits zu Tabelle ' || l_tab);
        end if;
    exception
        when no_data_found then null;
    end;
end;
/

create or replace trigger KUND_BIU
  before insert or update on KUND_KUNDEN
  for each row
begin
  if inserting then
    :new.KUND_ID := coalesce(:new.KUND_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.KUND_NUMMER := coalesce(:new.KUND_NUMMER, to_char(KUND_NUMMER_SEQ.nextval, 'FM000000'));
    :new.KUND_CREATED_ON  := systimestamp;
    :new.KUND_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KUND_UPDATED_ON  := null;
    :new.KUND_UPDATED_BY  := null;
    :new.KUND_ROW_VERSION := 1;
  elsif updating then
    :new.KUND_ID          := :old.KUND_ID;      -- Primaerschluessel ist unveraenderlich
    :new.KUND_NUMMER      := :old.KUND_NUMMER;  -- Kundennummer ist unveraenderlich
    :new.KUND_CREATED_ON  := :old.KUND_CREATED_ON;
    :new.KUND_CREATED_BY  := :old.KUND_CREATED_BY;
    :new.KUND_UPDATED_ON  := systimestamp;
    :new.KUND_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.KUND_ROW_VERSION := nvl(:old.KUND_ROW_VERSION, 0) + 1;
  end if;
end KUND_BIU;
/

comment on column KUND_KUNDEN.KUND_NUMMER is 'Fachliche Kundennummer, 6-stellig automatisch aus KUND_NUMMER_SEQ (Trigger KUND_BIU), unveraenderlich';

prompt Kundennummer-Vergabe eingerichtet.
