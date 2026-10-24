-- =====================================================================
-- ThGERP (Gruppen ARTI, ADMIN)
-- 28 – Artikelstamm in der Finanz-App (THG-FINANZ 20050), eigene App THG-ARTIKEL (20040) aufgeloest:
--      nur Rechnungen verwenden Artikel. Portal-Kachel THG-ARTIKEL entfernt, Kachel Finanz um Artikel ergaenzt.
--      Artikel laut den bisherigen Ausgangsrechnungen (Kingbill 2026 - 1 bis 13) angelegt bzw. angepasst, damit
--      sie fuer neue Rechnungen verwendet werden koennen; Positionen der uebernommenen Rechnungen verweisen auf
--      den Artikel (RPOS_ARTI_ID) – die gedruckte Artikelnummer (RPOS_ARTIKELNUMMER) bleibt wie in Kingbill.
-- Erzeugt: 2026-10-24
-- Wiederholbar (nur fehlende Zeilen, Anpassungen idempotent). Voraussetzung: 19, 20, 21
-- =====================================================================

set define off
set serveroutput on size unlimited

-- Portal: Kachel der aufgeloesten App entfernen, Finanz-Kachel beschreibt den Artikelstamm mit
delete from ADMIN_APPLIKATIONEN where APPL_APEX_APP_ID = 20040;
update ADMIN_APPLIKATIONEN
   set APPL_BESCHREIBUNG = 'Ausgangsrechnungen, Zahlungseingänge, Artikel, Nummernkreise'
 where APPL_APEX_APP_ID = 20050
   and APPL_BESCHREIBUNG <> 'Ausgangsrechnungen, Zahlungseingänge, Artikel, Nummernkreise';

-- Artikelgruppe fuer Geraete
insert into ARTI_ARTIKELGRUPPEN (AGRP_CODE, AGRP_BEZEICHNUNG, AGRP_SORTIERUNG)
  select 'HARDWARE', 'Hardware', 70 from dual where not exists (select 1 from ARTI_ARTIKELGRUPPEN where AGRP_CODE = 'HARDWARE');

declare
    -- Artikel anlegen bzw. auf den Stand der Rechnungen bringen (Nummer ist der Schluessel)
    procedure artikel(p_nummer varchar2, p_name varchar2, p_gruppe varchar2, p_einheit varchar2, p_preis number,
                      p_mwst number, p_beschreibung varchar2)
    is
        l_agrp ARTI_ARTIKELGRUPPEN.AGRP_ID%type;
        l_einh ALLG_EINHEITEN.EINH_ID%type;
        l_mwst ALLG_MWST_SAETZE.MWST_ID%type;
    begin
        select max(AGRP_ID) into l_agrp from ARTI_ARTIKELGRUPPEN where AGRP_CODE = p_gruppe;
        select EINH_ID into l_einh from ALLG_EINHEITEN where EINH_CODE = p_einheit;
        select MWST_ID into l_mwst from ALLG_MWST_SAETZE where MWST_PROZENT = p_mwst;
        merge into ARTI_ARTIKEL a
        using (select p_nummer as nr from dual) x
           on (a.ARTI_NUMMER = x.nr)
         when matched then update
              set a.ARTI_NAME = p_name, a.ARTI_AGRP_ID = coalesce(l_agrp, a.ARTI_AGRP_ID), a.ARTI_EINH_ID = l_einh,
                  a.ARTI_VK_PREIS = p_preis, a.ARTI_MWST_ID = l_mwst,
                  a.ARTI_BESCHREIBUNG = case when p_beschreibung is not null then to_clob(p_beschreibung)
                                             else a.ARTI_BESCHREIBUNG end
              where a.ARTI_NAME <> p_name or decode(a.ARTI_EINH_ID, l_einh, 0, 1) = 1 or a.ARTI_VK_PREIS <> p_preis
                 or a.ARTI_MWST_ID <> l_mwst or decode(a.ARTI_AGRP_ID, coalesce(l_agrp, a.ARTI_AGRP_ID), 0, 1) = 1
         when not matched then insert
              (ARTI_NUMMER, ARTI_NAME, ARTI_AGRP_ID, ARTI_EINH_ID, ARTI_MWST_ID, ARTI_VK_PREIS, ARTI_IST_BRUTTO,
               ARTI_BESCHREIBUNG, ARTI_AUFGENOMMEN_AM, ARTI_IST_AKTIV)
              values (p_nummer, p_name, l_agrp, l_einh, l_mwst, p_preis, 'N', p_beschreibung, trunc(sysdate), 'Y');
        dbms_output.put_line('Artikel ' || p_nummer || ' ' || p_name || ': ' || sql%rowcount);
    end artikel;
begin
    -- Rechnungen 2026 - 1, 3, 5, 7 (dansys): Stunden, steuerfrei (Reverse Charge)
    artikel('212', 'Projektunterstützung BMDV', null, 'Std.', 95, 0, null);
    -- Rechnungen 2026 - 2, 4, 6, 8, 10, 11, 13 (Beyne): monatliche Pauschale
    artikel('217', 'EDV - Betreuung', 'BEYNE', 'Pauschale', 3000, 20, null);
    -- Rechnungen 2026 - 9, 12 (Fritz): EDV-Betreuung je Monat, Office 365 je Quartal, Geraeteverkauf
    artikel('218', 'EDV - Betreuung', 'DIENSTLEISTUNG', 'Stk.', 100, 20,
            '<p>EDV Betreuung - 100€ pro Monat</p><p>Quartal</p>');
    artikel('503', 'Microsoft Office 365', 'OFFICE365', 'Pauschale', 111, 20,
            '<p>M365 Business Standard</p><p>3 Lizenzen zu € 11 / Monat</p><p>Exchange Online Plan 1</p><p>1 Lizenz zu € 4 / Monat</p>');
    artikel('600', 'Apple MacBook Air', 'HARDWARE', 'Stk.', 845, 20,
            '<p>Apple MacBook Air 13,6&quot; 2025 M4/16/512GB</p>');
end;
/

-- Positionen der uebernommenen Rechnungen mit dem Artikel verknuepfen (nur Verweis, gedruckt wird wie bisher)
update FAKT_RECHNUNGSPOSITIONEN p
   set p.RPOS_ARTI_ID = (select a.ARTI_ID from ARTI_ARTIKEL a
                          where a.ARTI_NUMMER = case
                                    when p.RPOS_ARTIKELNUMMER is not null then p.RPOS_ARTIKELNUMMER
                                    when p.RPOS_NAME = 'EDV - Betreuung' then '218'
                                    when p.RPOS_NAME like '%Microsoft Office 365%' then '503'
                                    when p.RPOS_NAME = 'Apple MacBook Air' then '600' end)
 where p.RPOS_ARTI_ID is null
   and exists (select 1 from FAKT_RECHNUNGEN r where r.RECH_ID = p.RPOS_RECH_ID and r.RECH_ALT_ID is not null);
prompt Positionen verknuepft
commit;

prompt Artikelstamm in THG-FINANZ: Kachel entfernt, Artikel laut Rechnungen angelegt.
