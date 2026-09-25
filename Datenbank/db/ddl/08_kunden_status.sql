-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 08 – KUND_KUNDEN.KUND_STATUS nur noch AKTIV / INAKTIV (Status GESPERRT entfaellt)
--      Hintergrund: Status wird in der Kundenmaske als Switch Aktiv/Inaktiv gepflegt.
-- Erzeugt: 2026-09-24
-- Voraussetzung: Oracle 23ai+ (USER_CONSTRAINTS.SEARCH_CONDITION_VC)
--
-- Wiederholbar ausfuehrbar:
--   * Kunden mit Status GESPERRT -> INAKTIV
--   * Check-Constraint KUND_STATUS_CK wird nur neu angelegt, wenn die Bedingung abweicht
-- =====================================================================

set define off
set serveroutput on size unlimited

declare
    c_cond constant varchar2(200) := q'[KUND_STATUS in ('AKTIV', 'INAKTIV')]';
    l_cond varchar2(4000);
begin
    update KUND_KUNDEN set KUND_STATUS = 'INAKTIV' where KUND_STATUS = 'GESPERRT';
    dbms_output.put_line('KUND_KUNDEN: ' || sql%rowcount || ' Kunden von GESPERRT auf INAKTIV gesetzt');

    select search_condition_vc into l_cond
      from user_constraints
     where table_name = 'KUND_KUNDEN' and constraint_name = 'KUND_STATUS_CK';

    if lower(regexp_replace(l_cond, '\s+', ' ')) = lower(c_cond) then
        dbms_output.put_line('KUND_STATUS_CK: unveraendert');
    else
        execute immediate 'alter table KUND_KUNDEN drop constraint KUND_STATUS_CK';
        execute immediate 'alter table KUND_KUNDEN add constraint KUND_STATUS_CK check (' || c_cond || ')';
        dbms_output.put_line('KUND_STATUS_CK: neu angelegt (' || c_cond || ')');
    end if;
    commit;
end;
/

comment on column KUND_KUNDEN.KUND_STATUS is 'AKTIV oder INAKTIV (Switch in der Kundenmaske)';

prompt KUND_STATUS angepasst.
