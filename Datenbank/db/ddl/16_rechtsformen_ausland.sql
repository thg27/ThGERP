-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 16 – KUND_RECHTSFORMEN um auslaendische Rechtsformen der Altdaten ergaenzen
--      (Zuordnung zu den Kunden: Datenbank/db/migration/mig_02_rechtsform_aus_firmenname.sql)
-- Erzeugt: 2026-09-25
--
-- Wiederholbar: nur fehlende Rechtsformen (RFRM_KURZ) werden eingefuegt.
-- =====================================================================

set define off
set serveroutput on

declare
    type t_rf is record (kurz varchar2(30), bez varchar2(100));
    type t_rfs is table of t_rf;
    l t_rfs := t_rfs(
        t_rf('d.o.o.',      'Gesellschaft mit beschränkter Haftung (Slowenien, Kroatien, Serbien)'),
        t_rf('d.d.',        'Aktiengesellschaft (Slowenien, Kroatien)'),
        t_rf('s.p.',        'Einzelunternehmen (Slowenien)'),
        t_rf('s.r.o.',      'Gesellschaft mit beschränkter Haftung (Tschechien, Slowakei)'),
        t_rf('a.s.',        'Aktiengesellschaft (Tschechien, Slowakei)'),
        t_rf('Kft.',        'Gesellschaft mit beschränkter Haftung (Ungarn)'),
        t_rf('Zrt.',        'Aktiengesellschaft (Ungarn)'),
        t_rf('Sp. z o.o.',  'Gesellschaft mit beschränkter Haftung (Polen)'),
        t_rf('S.R.L.',      'Gesellschaft mit beschränkter Haftung (Italien, Rumänien)'),
        t_rf('S.p.A.',      'Aktiengesellschaft (Italien)'),
        t_rf('S.A.',        'Aktiengesellschaft (Frankreich inkl. S.A.S., Spanien, Schweiz u.a.)'),
        t_rf('Ltd.',        'Private Limited Company (Vereinigtes Königreich u.a.)'),
        t_rf('eGen',        'Eingetragene Genossenschaft')
    );
    l_neu  pls_integer := 0;
    v_kurz varchar2(30);
    v_bez  varchar2(100);
begin
    for i in 1 .. l.count loop
        v_kurz := l(i).kurz; v_bez := l(i).bez;
        insert into KUND_RECHTSFORMEN (RFRM_KURZ, RFRM_BEZEICHNUNG)
        select v_kurz, v_bez from dual
         where not exists (select 1 from KUND_RECHTSFORMEN where RFRM_KURZ = v_kurz);
        l_neu := l_neu + sql%rowcount;
    end loop;
    commit;
    dbms_output.put_line('KUND_RECHTSFORMEN: ' || l_neu || ' Rechtsformen ergaenzt');
end;
/
