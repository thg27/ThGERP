set serveroutput on
set feedback off
set pagesize 100
set linesize 200

prompt == Listenabfrage Seite 10: Zeilen / eindeutige Kunden / mit Adresse / mit Konzern
with liste as (
    select k.KUND_ID, a.ADRE_ORT as ORT, l.LAND_BEZEICHNUNG as LAND,
           case when m.KUND_ID is not null then m.KUND_NUMMER || ' – ' || nvl(m.KUND_FIRMENNAME, m.KUND_NACHNAME) end as KONZERN
      from KUND_KUNDEN k
      left join KUND_RECHTSFORMEN r on r.RFRM_ID = k.KUND_RFRM_ID
      left join KUND_STANDORTE s on s.KSTO_KUND_ID = k.KUND_ID and s.KSTO_IST_HAUPTSITZ = 'Y'
      left join ALLG_ADRESSEN a on a.ADRE_ID = s.KSTO_ADRE_ID
      left join ALLG_LAENDER l on l.LAND_CODE = a.ADRE_LAND_CODE
      left join KUND_KUNDEN m on m.KUND_ID = k.KUND_PARENT_KUND_ID
     where k.KUND_NUMMER like 'TEST-%')
select count(*) zeilen, count(distinct KUND_ID) kunden, count(ORT) mit_adresse, count(KONZERN) mit_konzern from liste;

prompt == Facetten: Status / Typ
select KUND_STATUS, count(*) from KUND_KUNDEN where KUND_NUMMER like 'TEST-%' group by KUND_STATUS order by 1;
select KUND_TYP, count(*) from KUND_KUNDEN where KUND_NUMMER like 'TEST-%' group by KUND_TYP order by 1;
prompt == Facetten: Land
select nvl(l.LAND_BEZEICHNUNG,'(ohne)') land, count(*)
  from KUND_KUNDEN k
  left join KUND_STANDORTE s on s.KSTO_KUND_ID = k.KUND_ID and s.KSTO_IST_HAUPTSITZ = 'Y'
  left join ALLG_ADRESSEN a on a.ADRE_ID = s.KSTO_ADRE_ID
  left join ALLG_LAENDER l on l.LAND_CODE = a.ADRE_LAND_CODE
 where k.KUND_NUMMER like 'TEST-%' group by l.LAND_BEZEICHNUNG order by 1;

prompt == LOV_KUNDEN (Anzahl Testeintraege)
select count(*) from (select KUND_NUMMER || ' – ' || case KUND_TYP when 'FIRMA' then KUND_FIRMENNAME else KUND_NACHNAME || nvl2(KUND_VORNAME, ' ' || KUND_VORNAME, null) end d from KUND_KUNDEN) where d like 'TEST-%';

prompt == Negativtests (erwartet: jeweils Fehler)
declare
    l_id  number;
    l_par number;
    procedure pruefe(p_name varchar2, p_sql varchar2) is
    begin
        savepoint sp;
        execute immediate p_sql;
        dbms_output.put_line('FEHLER NICHT ERKANNT: ' || p_name);
        rollback to sp;
    exception
        when others then
            rollback to sp;
            dbms_output.put_line('OK ' || p_name || ': ' || substr(sqlerrm, 1, 90));
    end;
begin
    select KUND_ID into l_id from KUND_KUNDEN where KUND_NUMMER = 'TEST-001';
    pruefe('Kundennummer doppelt', q'[insert into KUND_KUNDEN (KUND_NUMMER, KUND_TYP, KUND_STATUS, KUND_FIRMENNAME) values ('TEST-001', 'FIRMA', 'AKTIV', 'x')]');
    pruefe('Firma ohne Firmenname', q'[insert into KUND_KUNDEN (KUND_NUMMER, KUND_TYP, KUND_STATUS) values ('TEST-X1', 'FIRMA', 'AKTIV')]');
    pruefe('Privat ohne Nachname', q'[insert into KUND_KUNDEN (KUND_NUMMER, KUND_TYP, KUND_STATUS, KUND_VORNAME) values ('TEST-X2', 'PRIVAT', 'AKTIV', 'Max')]');
    pruefe('Ungueltiger Status', q'[update KUND_KUNDEN set KUND_STATUS = 'XYZ' where KUND_NUMMER = 'TEST-003']');
    pruefe('Konzernmutter = selbst', 'update KUND_KUNDEN set KUND_PARENT_KUND_ID = KUND_ID where KUND_NUMMER = ''TEST-003''');
    pruefe('Zweiter Hauptsitz', 'insert into KUND_STANDORTE (KSTO_KUND_ID, KSTO_STYP_ID, KSTO_ADRE_ID, KSTO_BEZEICHNUNG, KSTO_IST_HAUPTSITZ) '
        || 'select KSTO_KUND_ID, KSTO_STYP_ID, KSTO_ADRE_ID, ''Zweiter'', ''Y'' from KUND_STANDORTE where KSTO_KUND_ID = ' || l_id);
    pruefe('Manuelle AT-Adresse', q'[insert into ALLG_ADRESSEN (ADRE_LAND_CODE, ADRE_QUELLE, ADRE_PLZ, ADRE_ORT) values ('AT', 'MANUELL', '1010', 'Wien')]');
    pruefe('Kreditlimit negativ', q'[update KUND_KUNDEN set KUND_KREDITLIMIT = -1 where KUND_NUMMER = 'TEST-003']');
end;
/

prompt == Audit nach Update (ROW_VERSION 1 -> 2)
update KUND_KUNDEN set KUND_KREDITLIMIT = 12345 where KUND_NUMMER = 'TEST-004';
select KUND_NUMMER, KUND_ROW_VERSION, KUND_UPDATED_BY, case when KUND_UPDATED_ON is not null then 'gesetzt' end upd from KUND_KUNDEN where KUND_NUMMER = 'TEST-004';
commit;
