-- =====================================================================
-- ThGERP (Gruppe ARTI)
-- 29 – Artikelstamm verschlankt: Zusatzfelder (ARTI_ZUSATZFELDER, ARTI_ARTIKEL_ZUSATZWERTE), Artikeldateien
--      (ARTI_ARTIKEL_DATEIEN) und Artikelbild (ARTI_BILD, ARTI_BILD_MIMETYPE, ARTI_BILD_DATEINAME) werden nicht
--      gebraucht (Anwender 2026-10-24) – Maske THG-FINANZ Seite 21 nur noch mit Stammdaten und Kommentar.
--      Neuinstallationen legen die Objekte nicht mehr an (Skript 19); dieses Skript entfernt sie aus bestehenden
--      Schemas. Stand beim Entfernen: keine Zusatzwerte, keine Dateien, kein Bild (nur 10 Feldnamen-Definitionen).
-- Erzeugt: 2026-10-24
-- Wiederholbar (entfernt nur Vorhandenes).
-- =====================================================================

set serveroutput on size unlimited

declare
    procedure tabelle_weg(p_tabelle varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from user_tables where table_name = p_tabelle;
        if l_n > 0 then
            execute immediate 'drop table ' || p_tabelle || ' cascade constraints purge';
            dbms_output.put_line(p_tabelle || ' entfernt');
        end if;
    end;
    procedure spalte_weg(p_tabelle varchar2, p_spalte varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from user_tab_columns where table_name = p_tabelle and column_name = p_spalte;
        if l_n > 0 then
            execute immediate 'alter table ' || p_tabelle || ' drop column ' || p_spalte;
            dbms_output.put_line(p_tabelle || '.' || p_spalte || ' entfernt');
        end if;
    end;
begin
    tabelle_weg('ARTI_ARTIKEL_ZUSATZWERTE');
    tabelle_weg('ARTI_ARTIKEL_DATEIEN');
    tabelle_weg('ARTI_ZUSATZFELDER');
    spalte_weg('ARTI_ARTIKEL', 'ARTI_BILD');
    spalte_weg('ARTI_ARTIKEL', 'ARTI_BILD_MIMETYPE');
    spalte_weg('ARTI_ARTIKEL', 'ARTI_BILD_DATEINAME');
    -- drop column invalidiert den Trigger der Tabelle: gleich neu kompilieren
    execute immediate 'alter trigger ARTI_BIU compile';
end;
/

prompt Artikelstamm ohne Zusatzfelder, Dateien und Bild.
