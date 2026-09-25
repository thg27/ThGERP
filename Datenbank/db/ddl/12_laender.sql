-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 12 – ALLG_LAENDER um die Laender der Altdaten (TBL_PLZ.PLZ_LAND) ergaenzen
--      Die Zuordnung Altkuerzel -> ISO-Code steht im Uebernahmeskript
--      (Datenbank/db/migration); hier nur die Laender selbst.
-- Erzeugt: 2026-09-25
--
-- Wiederholbar: nur fehlende Laender werden eingefuegt, vorhandene bleiben unveraendert.
-- =====================================================================

set define off
set serveroutput on

declare
    type t_land is record (code varchar2(2), bez varchar2(100), eu varchar2(1));
    type t_laender is table of t_land;
    l t_laender := t_laender(
        t_land('BE', 'Belgien', 'Y'),         t_land('BG', 'Bulgarien', 'Y'),
        t_land('DK', 'Dänemark', 'Y'),        t_land('EE', 'Estland', 'Y'),
        t_land('ES', 'Spanien', 'Y'),         t_land('FR', 'Frankreich', 'Y'),
        t_land('HR', 'Kroatien', 'Y'),        t_land('IE', 'Irland', 'Y'),
        t_land('LT', 'Litauen', 'Y'),         t_land('NL', 'Niederlande', 'Y'),
        t_land('PL', 'Polen', 'Y'),           t_land('PT', 'Portugal', 'Y'),
        t_land('RO', 'Rumänien', 'Y'),        t_land('SE', 'Schweden', 'Y'),
        t_land('CY', 'Zypern', 'Y'),
        t_land('AR', 'Argentinien', 'N'),     t_land('BR', 'Brasilien', 'N'),
        t_land('CN', 'China', 'N'),           t_land('CO', 'Kolumbien', 'N'),
        t_land('EG', 'Ägypten', 'N'),         t_land('GB', 'Vereinigtes Königreich', 'N'),
        t_land('IN', 'Indien', 'N'),          t_land('MD', 'Moldau', 'N'),
        t_land('MX', 'Mexiko', 'N'),          t_land('OM', 'Oman', 'N'),
        t_land('RS', 'Serbien', 'N'),         t_land('RU', 'Russland', 'N'),
        t_land('SA', 'Saudi-Arabien', 'N'),   t_land('SY', 'Syrien', 'N'),
        t_land('TH', 'Thailand', 'N'),        t_land('TR', 'Türkei', 'N'),
        t_land('US', 'Vereinigte Staaten', 'N'),
        t_land('VE', 'Venezuela', 'N'),       t_land('VN', 'Vietnam', 'N')
    );
    l_neu  pls_integer := 0;
    v_code varchar2(2);
    v_bez  varchar2(100);
    v_eu   varchar2(1);
begin
    for i in 1 .. l.count loop
        v_code := l(i).code; v_bez := l(i).bez; v_eu := l(i).eu;
        insert into ALLG_LAENDER (LAND_CODE, LAND_BEZEICHNUNG, LAND_IST_EU, LAND_HAT_REGISTER)
        select v_code, v_bez, v_eu, 'N' from dual
         where not exists (select 1 from ALLG_LAENDER where LAND_CODE = v_code);
        l_neu := l_neu + sql%rowcount;
    end loop;
    commit;
    dbms_output.put_line('ALLG_LAENDER: ' || l_neu || ' Laender ergaenzt');
end;
/
