-- Testdaten Kundenstamm (Kundennummern TEST-nnn), nur DEV
set serveroutput on
set define off

declare
    type t_txt is table of varchar2(100);
    l_laender  t_txt := t_txt('DE','DE','DE','CH','IT','SI','HU','CZ','SK','LI');
    l_orte     t_txt := t_txt('München','Berlin','Hamburg','Zürich','Mailand','Ljubljana','Budapest','Prag','Bratislava','Vaduz');
    l_plz      t_txt := t_txt('80331','10115','20095','8001','20121','1000','1051','11000','81101','9490');
    l_status   t_txt := t_txt('AKTIV','AKTIV','AKTIV','AKTIV','INAKTIV','INAKTIV');
    l_firmen   t_txt := t_txt('Kunststofftechnik','Recycling','Maschinenbau','Spritzguss','Verpackung','Logistik','Handel','Metallbau');
    l_vornamen t_txt := t_txt('Anna','Bernd','Clara','David','Eva','Felix','Gerda','Hans');
    l_rfrm     sys.odcinumberlist;
    l_zbed     sys.odcinumberlist;
    l_styp     number;
    l_kund_id  number;
    l_adre_id  number;
    l_parent1  number;
    l_parent2  number;
    l_i        pls_integer;
    l_typ      varchar2(10);
    v_status   varchar2(10);
    v_firma    varchar2(200);
    v_anrede   varchar2(30);
    v_vorname  varchar2(100);
    v_nachname varchar2(100);
    v_rfrm     number;
    v_zbed     number;
    v_parent   number;
begin
    select RFRM_ID bulk collect into l_rfrm from KUND_RECHTSFORMEN order by RFRM_KURZ;
    select ZBED_ID bulk collect into l_zbed from ALLG_ZAHLUNGSBEDINGUNGEN order by ZBED_ZIEL_TAGE;
    select STYP_ID into l_styp from KUND_STANDORT_TYPEN where STYP_BEZEICHNUNG = 'Hauptsitz';

    for i in 1 .. 60 loop
        l_i   := mod(i - 1, 10) + 1;
        l_typ := case when mod(i, 4) = 0 then 'PRIVAT' else 'FIRMA' end;
        v_status   := l_status(mod(i - 1, l_status.count) + 1);
        v_firma    := case when l_typ = 'FIRMA' then 'Test ' || l_firmen(mod(i - 1, l_firmen.count) + 1) || ' ' || i end;
        v_anrede   := case when l_typ = 'PRIVAT' then case when mod(i, 8) = 0 then 'Frau' else 'Herr' end end;
        v_vorname  := case when l_typ = 'PRIVAT' then l_vornamen(mod(i - 1, l_vornamen.count) + 1) end;
        v_nachname := case when l_typ = 'PRIVAT' then 'Testperson' || i end;
        v_rfrm     := case when l_typ = 'FIRMA' then l_rfrm(mod(i - 1, l_rfrm.count) + 1) end;
        v_zbed     := l_zbed(mod(i - 1, l_zbed.count) + 1);
        v_parent   := case when i > 50 then case when mod(i, 2) = 0 then l_parent1 else l_parent2 end end;

        insert into KUND_KUNDEN (KUND_NUMMER, KUND_TYP, KUND_STATUS, KUND_FIRMENNAME, KUND_ANREDE, KUND_VORNAME, KUND_NACHNAME,
                                 KUND_RFRM_ID, KUND_ZBED_ID, KUND_UID_NUMMER, KUND_KREDITLIMIT, KUND_KUNDE_SEIT,
                                 KUND_PARENT_KUND_ID)
        values ('TEST-' || to_char(i, 'FM000'), l_typ, v_status, v_firma, v_anrede, v_vorname, v_nachname,
                v_rfrm, v_zbed,
                case when l_typ = 'FIRMA' then 'DE' || to_char(100000000 + i) end,
                case when mod(i, 3) = 0 then 5000 * mod(i, 7) end,
                date '2015-01-01' + i * 50,
                v_parent)
        returning KUND_ID into l_kund_id;

        if i = 1 then l_parent1 := l_kund_id; end if;
        if i = 2 then l_parent2 := l_kund_id; end if;

        -- Hauptsitz fuer 55 von 60 Kunden (5 ohne Standort)
        if i <= 55 then
            v_firma := l_laender(l_i); v_anrede := l_plz(l_i); v_nachname := l_orte(l_i);
            insert into ALLG_ADRESSEN (ADRE_LAND_CODE, ADRE_QUELLE, ADRE_STRASSE, ADRE_HAUSNUMMER, ADRE_PLZ, ADRE_ORT)
            values (v_firma, 'MANUELL', 'Teststraße', to_char(i), v_anrede, v_nachname)
            returning ADRE_ID into l_adre_id;

            insert into KUND_STANDORTE (KSTO_KUND_ID, KSTO_STYP_ID, KSTO_ADRE_ID, KSTO_BEZEICHNUNG, KSTO_IST_HAUPTSITZ, KSTO_IST_RECHNUNGSADR)
            values (l_kund_id, l_styp, l_adre_id, 'Hauptsitz', 'Y', 'Y');
        end if;
    end loop;

    -- abweichender Rechnungsempfaenger fuer 3 Kunden
    update KUND_KUNDEN set KUND_RE_KUND_ID = l_parent1 where KUND_NUMMER in ('TEST-010', 'TEST-011', 'TEST-012');
    commit;
    dbms_output.put_line('Testdaten angelegt');
end;
/
