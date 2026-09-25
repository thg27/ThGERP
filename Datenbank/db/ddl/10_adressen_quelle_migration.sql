-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 10 – ALLG_ADRESSEN: Adressquelle MIGRATION fuer die Uebernahme aus dem Altsystem (TBL_ADRESSE)
--      MIGRATION = aus Altdaten uebernommen, ohne Adressregister-Code; zulaessig fuer alle Laender
--      (auch AT, fuer das manuelle Adressen weiterhin nicht erlaubt sind – Trigger ADRE_BIU prueft nur MANUELL).
-- Erzeugt: 2026-09-25
-- Voraussetzung: Oracle 23ai+ (USER_CONSTRAINTS.SEARCH_CONDITION_VC)
--
-- Wiederholbar ausfuehrbar: Check-Constraints werden nur neu angelegt, wenn die Bedingung abweicht.
-- =====================================================================

set define off
set serveroutput on size unlimited

declare
    procedure check_constraint(p_name varchar2, p_cond varchar2) is
        l_cond varchar2(4000);
    begin
        begin
            select search_condition_vc into l_cond
              from user_constraints
             where table_name = 'ALLG_ADRESSEN' and constraint_name = p_name;
        exception
            when no_data_found then l_cond := null;
        end;
        if lower(regexp_replace(l_cond, '\s+', ' ')) = lower(regexp_replace(p_cond, '\s+', ' ')) then
            dbms_output.put_line(p_name || ': unveraendert');
        else
            if l_cond is not null then
                execute immediate 'alter table ALLG_ADRESSEN drop constraint ' || p_name;
            end if;
            execute immediate 'alter table ALLG_ADRESSEN add constraint ' || p_name || ' check (' || p_cond || ')';
            dbms_output.put_line(p_name || ': neu angelegt');
        end if;
    end;
begin
    check_constraint('ADRE_QUELLE_CK',
        q'[ADRE_QUELLE in ('REGISTER', 'MANUELL', 'MIGRATION')]');
    check_constraint('ADRE_QUELLE_ADRCD_CK',
        q'[(ADRE_QUELLE = 'REGISTER' and ADRE_AREG_ADRCD is not null) or (ADRE_QUELLE in ('MANUELL', 'MIGRATION') and ADRE_AREG_ADRCD is null)]');
end;
/

comment on column ALLG_ADRESSEN.ADRE_QUELLE is 'REGISTER = aus Adressregister, MANUELL = manuell erfasst (nicht fuer Laender mit Register), MIGRATION = aus Altsystem uebernommen';

prompt Adressquelle MIGRATION eingerichtet.
