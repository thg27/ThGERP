-- Entfernt alle Testdaten des Kundenstamms (Kundennummern TEST-nnn) inkl. Standorte und Adressen, nur DEV
set serveroutput on

declare
    l_adressen sys.odcinumberlist;
begin
    select s.KSTO_ADRE_ID bulk collect into l_adressen
      from KUND_STANDORTE s
      join KUND_KUNDEN k on k.KUND_ID = s.KSTO_KUND_ID
     where k.KUND_NUMMER like 'TEST-%';

    delete from KUND_STANDORTE
     where KSTO_KUND_ID in (select KUND_ID from KUND_KUNDEN where KUND_NUMMER like 'TEST-%');
    dbms_output.put_line('Standorte geloescht: ' || sql%rowcount);

    delete from ALLG_ADRESSEN where ADRE_ID in (select column_value from table(l_adressen));
    dbms_output.put_line('Adressen geloescht:  ' || sql%rowcount);

    -- Selbstbezuege loesen, dann Kunden loeschen
    update KUND_KUNDEN set KUND_PARENT_KUND_ID = null, KUND_RE_KUND_ID = null where KUND_NUMMER like 'TEST-%';
    delete from KUND_KUNDEN where KUND_NUMMER like 'TEST-%';
    dbms_output.put_line('Kunden geloescht:    ' || sql%rowcount);
    commit;
end;
/

select (select count(*) from KUND_KUNDEN where KUND_NUMMER like 'TEST-%') as test_kunden,
       (select count(*) from ALLG_ADRESSEN where ADRE_STRASSE = 'Teststraße') as test_adressen
  from dual;
