-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 38 – Zahlungsreferenz der Rechnung (RF-Referenz nach ISO 11649) fuer Online-Ueberweisungen und die spaetere automatische
--      Zuordnung von Zahlungen: FAKT_RECHNUNGEN.RECH_ZAHLUNGSREFERENZ (eindeutig), erzeugt beim Abschliessen
--      (FAKT_RECHNUNG.abschliessen / zahlungsreferenz): RF + 2 Pruefziffern + Firma (1 = EDV, 2 = HOLDING) + Kundennummer
--      + Jahr + laufende Nummer 5-stellig, z.B. RF75 2100 2212 0260 0203 (gespeichert ohne Leerzeichen).
--      Bereits abgeschlossene Rechnungen erhalten keine Referenz. Package: Skript 21 erneut.
--      KUND_KUNDEN.KUND_IST_QR_CODE (Y/N, Vorgabe Y): EPC-QR-Code "Zahlen mit Code" auf der Rechnung (Skript 24).
-- Erzeugt: 2026-10-25
-- Wiederholbar (DDL_UTIL).
-- =====================================================================

begin
    DDL_UTIL.spalte('FAKT_RECHNUNGEN', 'RECH_ZAHLUNGSREFERENZ', 'varchar2(25 char)', 'Y');
    DDL_UTIL.index_('FAKT_RECHNUNGEN', 'RECH_ZAHLUNGSREFERENZ_UI', 'RECH_ZAHLUNGSREFERENZ', true);
    -- je Kunde: QR-Code auf der Rechnung drucken (Y/N, Vorgabe Y)
    DDL_UTIL.spalte('KUND_KUNDEN', 'KUND_IST_QR_CODE', 'varchar2(1 char)', 'N', q'~'Y'~');
    DDL_UTIL.constraint_('KUND_KUNDEN', 'KUND_IST_QR_CODE_CK', 'C', q'~KUND_IST_QR_CODE in ('Y', 'N')~');
end;
/
comment on column KUND_KUNDEN.KUND_IST_QR_CODE is 'Y = EPC-QR-Code (Zahlen mit Code) auf der Rechnung drucken';
comment on column FAKT_RECHNUNGEN.RECH_ZAHLUNGSREFERENZ is 'Zahlungsreferenz (RF-Referenz ISO 11649, ohne Leerzeichen), beim Abschliessen erzeugt';

@@21_finanz.sql

-- die neu angelegte View invalidiert das Druckpaket
alter package FAKT_RECHNUNG_PDF compile;

-- durch die neuen Spalten ungueltig gewordene Pakete neu uebersetzen (z.B. FAKT_HISTORIE, KUND_STAMMBLATT)
begin
    for o in (select object_name, object_type from user_objects
               where status <> 'VALID' and object_type in ('PACKAGE', 'PACKAGE BODY', 'TRIGGER', 'VIEW')) loop
        begin
            execute immediate 'alter ' || case o.object_type when 'PACKAGE BODY' then 'package' else lower(o.object_type) end
                              || ' ' || o.object_name || ' compile' || case o.object_type when 'PACKAGE BODY' then ' body' end;
        exception
            when others then
                dbms_output.put_line(o.object_name || ': ' || sqlerrm);
        end;
    end loop;
end;
/

prompt Zahlungsreferenz der Rechnung installiert.
