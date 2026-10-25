-- =====================================================================
-- ThGERP (Gruppe KUND) – Kunde Hays AG (Gutschriftverfahren: Hays stellt Gutschriften statt Rechnungen aus)
-- 41 – Kunde aus den Angaben der Hays-Gutschriften anlegen: Firma, Rechtsform, UID, Hauptsitz mit Telefon/Fax/Web,
--      Ansprechpartnerin (Sachbearbeiterin) mit E-Mail/Telefon. Nur wenn der Kunde fehlt.
-- Erzeugt: 2026-10-25
-- Wiederholbar.
-- =====================================================================

set define off
set serveroutput on size unlimited

declare
    l_kund number;
    l_adre number;
    l_ksto number;
    l_ansp number;
    l_styp number;
    l_tel   number;
    l_fax   number;
    l_web   number;
    l_email number;
begin
    -- IDs der Kommunikationsarten vorab (lokale Funktionen sind in SQL nicht erlaubt: PLS-00231)
    select max(case KART_CODE when 'TEL' then KART_ID end), max(case KART_CODE when 'FAX' then KART_ID end),
           max(case KART_CODE when 'WEB' then KART_ID end), max(case KART_CODE when 'EMAIL' then KART_ID end)
      into l_tel, l_fax, l_web, l_email
      from ALLG_KOMMUNIKATIONSARTEN;
    select max(KUND_ID) into l_kund from KUND_KUNDEN where KUND_FIRMENNAME = 'Hays AG';
    if l_kund is not null then
        dbms_output.put_line('Kunde Hays AG ist bereits vorhanden.');
        return;
    end if;
    select STYP_ID into l_styp from KUND_STANDORT_TYPEN where STYP_BEZEICHNUNG = 'Hauptsitz';
    insert into KUND_KUNDEN (KUND_TYP, KUND_FIRMENNAME, KUND_RFRM_ID, KUND_UID_NUMMER, KUND_STATUS, KUND_SPRACHE,
                             KUND_KUNDE_SEIT, KUND_IST_QR_CODE, KUND_BEMERKUNG)
    values ('FIRMA', 'Hays AG', (select max(RFRM_ID) from KUND_RECHTSFORMEN where RFRM_KURZ = 'AG'), 'DE812871896',
            'AKTIV', 'de', date '2026-06-01', 'N',
            q'[Gutschriftverfahren: Hays stellt Gutschriften (keine Rechnungen), Zahlung innerhalb von 7 Tagen abzüglich 3 % Skonto.
Unser Konto bei Hays: 863384, Vertragsnummer (Projekteinzelvertrag): 60C2040536002.
Postanschrift: Hays AG, Postfach 100154, 68001 Mannheim. Bank: Commerzbank Mannheim, IBAN DE53 6704 0031 0604 0422 00, BIC COBADEFFXXX.
Angelegt aus den Hays-Gutschriften (2026-10-25).]')
    returning KUND_ID into l_kund;
    insert into ALLG_ADRESSEN (ADRE_LAND_CODE, ADRE_QUELLE, ADRE_STRASSE, ADRE_HAUSNUMMER, ADRE_PLZ, ADRE_ORT)
    values ('DE', 'MANUELL', 'Glücksteinallee', '67', '68163', 'Mannheim')
    returning ADRE_ID into l_adre;
    insert into KUND_STANDORTE (KSTO_KUND_ID, KSTO_STYP_ID, KSTO_ADRE_ID, KSTO_BEZEICHNUNG,
                                KSTO_IST_HAUPTSITZ, KSTO_IST_RECHNUNGSADR, KSTO_IST_LIEFERADR)
    values (l_kund, l_styp, l_adre, 'Hauptsitz', 'Y', 'Y', 'Y')
    returning KSTO_ID into l_ksto;
    insert into KUND_STANDORT_KOMMUNIKATION (SKOM_KSTO_ID, SKOM_KART_ID, SKOM_WERT, SKOM_IST_BEVORZUGT)
    values (l_ksto, l_tel, '+49 621 1788 0', 'Y');
    insert into KUND_STANDORT_KOMMUNIKATION (SKOM_KSTO_ID, SKOM_KART_ID, SKOM_WERT, SKOM_IST_BEVORZUGT)
    values (l_ksto, l_fax, '+49 621 1788 1299', 'N');
    insert into KUND_STANDORT_KOMMUNIKATION (SKOM_KSTO_ID, SKOM_KART_ID, SKOM_WERT, SKOM_IST_BEVORZUGT)
    values (l_ksto, l_web, 'https://www.hays.de', 'N');
    insert into KUND_ANSPRECHPARTNER (ANSP_KSTO_ID, ANSP_ANREDE, ANSP_VORNAME, ANSP_NACHNAME, ANSP_FUNKTION, ANSP_IST_HAUPTKONTAKT)
    values (l_ksto, 'Frau', 'Kerstin', 'Kobel', 'Sachbearbeiterin (Gutschriften)', 'Y')
    returning ANSP_ID into l_ansp;
    insert into KUND_ANSPRECHPARTNER_KOMMUNIKATION (AKOM_ANSP_ID, AKOM_KART_ID, AKOM_WERT, AKOM_IST_BEVORZUGT)
    values (l_ansp, l_email, 'kerstin.kobel@hays.de', 'Y');
    insert into KUND_ANSPRECHPARTNER_KOMMUNIKATION (AKOM_ANSP_ID, AKOM_KART_ID, AKOM_WERT, AKOM_IST_BEVORZUGT)
    values (l_ansp, l_tel, '+49 621 1788-1788', 'N');
    commit;
    dbms_output.put_line('Kunde Hays AG angelegt.');
end;
/
