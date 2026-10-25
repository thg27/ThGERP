-- =====================================================================
-- ThGERP (Gruppe FAKT) – App THG-FINANZ (20050), Dashboards Portal/Kundenstamm/Finanz
-- 44 – FAKT_BELEGE_V um OFFEN_NETTO erweitert: alle Dashboards zeigen Nettobetraege, auch beim offenen Betrag
--      (Rechnung: offener Betrag anteilig netto; Gutschrift: Netto, solange offen).
-- Voraussetzung: 43
-- Erzeugt: 2026-10-25
-- Wiederholbar.
-- =====================================================================

set define off

-- Rechnungen und erhaltene Gutschriften gemeinsam (Dashboards); Gutschriften im Entwurf/gesendet zaehlen als Entwurf
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
       r.IST_UEBERFAELLIG,
       -- offener Betrag netto: anteilig nach Netto/Brutto der Rechnung (Teilzahlungen enthalten die USt anteilig)
       case when r.RECH_SUMME_BRUTTO <> 0 then round(r.OFFEN * r.RECH_SUMME_NETTO / r.RECH_SUMME_BRUTTO, 2) else r.OFFEN end as OFFEN_NETTO
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
            then 'Y' else 'N' end,
       case g.GUTS_STATUS when 'OFFEN' then coalesce(g.GUTS_NETTO, g.GUTS_BETRAG) when 'BEZAHLT' then 0 end
  from FAKT_GUTSCHRIFTEN g
  left join KUND_KUNDEN k on k.KUND_ID = g.GUTS_KUND_ID;

comment on table FAKT_BELEGE_V is 'Rechnungen und erhaltene Gutschriften gemeinsam (Dashboards, Betraege netto: RECH_SUMME_NETTO, OFFEN_NETTO); Status der Gutschrift wie Rechnung';
comment on column FAKT_BELEGE_V.OFFEN_NETTO is 'Offener Betrag netto (Rechnung anteilig nach Netto/Brutto)';

prompt Offener Betrag netto installiert.
