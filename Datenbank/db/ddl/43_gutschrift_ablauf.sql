-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050)
-- 43 – Gutschriften wie Rechnungen: interner Nummernkreis GUTSCHRIFT ("GS 2026 - 1", je Mandant und Jahr), Ablauf
--      Entwurf -> Stundenzettel (Nummer/Datum) -> Gesendet -> Gutschrift erhalten (Offen) -> Bezahlt (Skripte 39/40/42).
--      Bestand: die bereits uebernommenen Gutschriften erhalten nachtraeglich interne Nummern nach Datum; Belegdatum des
--      Ausstellers und Nettobetrag nachgetragen.
--      View FAKT_BELEGE_V: Rechnungen und erhaltene Gutschriften gemeinsam (Finanz-Dashboard: Umsatz, offene Rechnungen,
--      ueberfaellig, Umsatz je Monat, Top 10 Kunden) – Gutschrift Offen = Rechnung offen, Bezahlt = Rechnung bezahlt.
-- Voraussetzung: 21, 39, 40, 42
-- Erzeugt: 2026-10-25
-- Wiederholbar.
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    -- interne Nummer je Mandant eindeutig (nur Zeilen mit Nummer)
    DDL_UTIL.index_('FAKT_GUTSCHRIFTEN', 'GUTS_INTERN_NUMMER_UI',
                    'case when GUTS_INTERN_NUMMER is not null then GUTS_MAND_ID end, GUTS_INTERN_NUMMER', true);
end;
/

-- Bestand: interne Nummern nach (Beleg-)Datum, Belegdatum des Ausstellers, Netto aus dem Text
declare
    l_nr varchar2(30);
begin
    for g in (select GUTS_ID, GUTS_MAND_ID, GUTS_DATUM, GUTS_TEXT
                from FAKT_GUTSCHRIFTEN
               where GUTS_INTERN_NUMMER is null and GUTS_DATEI is not null and GUTS_DATUM is not null
               order by GUTS_MAND_ID, GUTS_DATUM, GUTS_CREATED_ON) loop
        l_nr := FAKT_RECHNUNG.naechste_nummer(g.GUTS_MAND_ID, 'GUTSCHRIFT', extract(year from g.GUTS_DATUM));
        update FAKT_GUTSCHRIFTEN
           set GUTS_INTERN_NUMMER = l_nr,
               GUTS_AUSSTELLER_DATUM = coalesce(GUTS_AUSSTELLER_DATUM, GUTS_DATUM),
               GUTS_NETTO = coalesce(to_number(replace(replace(regexp_substr(regexp_substr(regexp_replace(dbms_lob.substr(g.GUTS_TEXT, 30000, 1), '[[:space:]]+', ' '),
                                                                                         'Nettobetrag [0-9.]+,[0-9]{2}'), '[0-9.]+,[0-9]{2}'), '.'), ',', '.'),
                                               '9999999999990D99', 'NLS_NUMERIC_CHARACTERS=''.,'''), GUTS_NETTO)
         where GUTS_ID = g.GUTS_ID;
        dbms_output.put_line('Gutschrift nummeriert: ' || l_nr);
    end loop;
    commit;
end;
/

-- Rechnungen und erhaltene Gutschriften gemeinsam (Dashboard); Gutschriften im Entwurf/gesendet zaehlen als Entwurf
create or replace view FAKT_BELEGE_V as
select 'RECHNUNG' as BELEGART,
       r.RECH_ID,
       r.RECH_MAND_ID,
       r.RECH_NUMMER,
       r.RECH_STATUS,
       r.RECH_DATUM,
       r.RECH_FAELLIG_AM,
       r.RECH_BETREFF,
       r.RECH_KUND_ID,
       r.KUND_NUMMER,
       r.KUNDE,
       r.RECH_SUMME_NETTO,
       r.RECH_SUMME_BRUTTO,
       r.OFFEN,
       r.IST_UEBERFAELLIG
  from FAKT_RECHNUNGEN_V r
union all
select 'GUTSCHRIFT',
       g.GUTS_ID,
       g.GUTS_MAND_ID,
       g.GUTS_INTERN_NUMMER,
       case g.GUTS_STATUS when 'OFFEN' then 'GEDRUCKT' when 'BEZAHLT' then 'BEZAHLT' else 'ENTWURF' end,
       g.GUTS_DATUM,
       g.GUTS_FAELLIG_AM,
       'Gutschrift ' || g.GUTS_NUMMER,
       g.GUTS_KUND_ID,
       k.KUND_NUMMER,
       coalesce(k.KUND_FIRMENNAME, g.GUTS_AUSSTELLER),
       coalesce(g.GUTS_NETTO, g.GUTS_BETRAG),
       g.GUTS_BETRAG,
       case g.GUTS_STATUS when 'OFFEN' then g.GUTS_BETRAG when 'BEZAHLT' then 0 end,
       case when g.GUTS_STATUS = 'OFFEN' and g.GUTS_FAELLIG_AM < trunc(cast(systimestamp at time zone 'Europe/Vienna' as date))
            then 'Y' else 'N' end
  from FAKT_GUTSCHRIFTEN g
  left join KUND_KUNDEN k on k.KUND_ID = g.GUTS_KUND_ID;

comment on table FAKT_BELEGE_V is 'Rechnungen und erhaltene Gutschriften gemeinsam (Finanz-Dashboard); Status der Gutschrift wie Rechnung';

prompt Gutschriften wie Rechnungen installiert.
