-- =====================================================================
-- ThGERP (Gruppe FAKT)
-- 31 – Zahlungsstatus automatisch: nach jeder Aenderung an FAKT_ZAHLUNGEN (Einfuegen, Aendern, Loeschen) wird der
--      Status der betroffenen Rechnungen neu bestimmt (FAKT_RECHNUNG.zahlungsstatus: GEDRUCKT/GESENDET/TEILBEZAHLT/BEZAHLT aus den Zahlungen).
--      Grund: das Raster "Zahlungen" (THG-FINANZ Seite 11) speichert per AJAX ohne die Seitenprozesse – der Status
--      blieb nach einem Zahlungseingang offen.
--      Compound Trigger: Rechnungen je Zeile merken, Status erst nach der Anweisung setzen (sonst ORA-04091).
-- Erzeugt: 2026-10-24
-- Wiederholbar.
-- =====================================================================

begin
    DDL_UTIL.trigger_pruefen('ZAHL_STATUS_AIUD', 'FAKT_ZAHLUNGEN');
end;
/

create or replace trigger ZAHL_STATUS_AIUD
  for insert or update or delete on FAKT_ZAHLUNGEN
  compound trigger

  type t_ids is table of boolean index by varchar2(40);
  g_rech t_ids;

  -- Zahlungen nur zu abgeschlossenen Rechnungen (nicht Entwurf, in Bearbeitung oder storniert); Loeschen immer
  before each row is
    l_status FAKT_RECHNUNGEN.RECH_STATUS%type;
  begin
    if inserting or updating then
      select max(RECH_STATUS) into l_status from FAKT_RECHNUNGEN where RECH_ID = :new.ZAHL_RECH_ID;
      if l_status not in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT') then
        raise_application_error(-20251, 'Zahlungen können nur zu abgeschlossenen Rechnungen erfasst werden (Status '
                                        || FAKT_RECHNUNG.status_text(l_status) || ').');
      end if;
    end if;
  end before each row;

  after each row is
  begin
    if :new.ZAHL_RECH_ID is not null then
      g_rech(to_char(:new.ZAHL_RECH_ID)) := true;
    end if;
    if :old.ZAHL_RECH_ID is not null then
      g_rech(to_char(:old.ZAHL_RECH_ID)) := true;
    end if;
  end after each row;

  after statement is
    l_id varchar2(40) := g_rech.first;
  begin
    while l_id is not null loop
      FAKT_RECHNUNG.zahlungsstatus(to_number(l_id));
      l_id := g_rech.next(l_id);
    end loop;
    g_rech.delete;
  end after statement;

end ZAHL_STATUS_AIUD;
/

-- bestehende Rechnungen einmal abgleichen
begin
    for r in (select RECH_ID from FAKT_RECHNUNGEN where RECH_STATUS in ('GEDRUCKT', 'GESENDET', 'TEILBEZAHLT', 'BEZAHLT')) loop
        FAKT_RECHNUNG.zahlungsstatus(r.RECH_ID);
    end loop;
    commit;
end;
/

prompt Zahlungsstatus-Trigger installiert.
