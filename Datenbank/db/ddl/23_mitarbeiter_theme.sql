-- =====================================================================
-- ThGERP (Gruppe ALLG)
-- 23 – Theme-Stil je Mitarbeiter:
--      ALLG_MITARBEITER.MITA_THEME_STIL: im Portal gewaehlter Theme-Stil (Name, z.B. Redwood Light);
--      wird beim Anmelden fuer die Sitzung in allen ThG-Apps gesetzt (apex_theme.set_session_style)
-- Erzeugt: 2026-09-26
-- Wiederholbar (DDL_UTIL).
-- =====================================================================

set define off
set serveroutput on size unlimited

begin
    DDL_UTIL.spalte('ALLG_MITARBEITER', 'MITA_THEME_STIL', 'varchar2(100 char)', 'Y');
end;
/

comment on column ALLG_MITARBEITER.MITA_THEME_STIL is 'Gewaehlter Theme-Stil (Name aus apex_application_theme_styles), gilt nach dem Login in allen ThG-Apps; leer = Standard der App';

prompt ALLG_MITARBEITER.MITA_THEME_STIL installiert bzw. abgeglichen.
