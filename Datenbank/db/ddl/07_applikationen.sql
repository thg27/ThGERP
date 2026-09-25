-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 07 – ADMIN_APPLIKATIONEN: Modul-Apps fuer die Portal-Startseite
--      (ersetzt die statische Liste "Module" der Portal-App 20000, Seite 1)
-- Erzeugt: 2026-09-24
-- Voraussetzung: Oracle 23ai+ (USER_TAB_COLUMNS.DATA_DEFAULT_VC)
--
-- Wiederholbar ausfuehrbar:
--   * Tabelle fehlt            -> wird angelegt
--   * Tabelle vorhanden        -> Spalten/Constraints werden mit dem Skript verglichen:
--       - fehlende Spalte/Constraint          -> wird ergaenzt
--       - VARCHAR2 im Skript laenger          -> wird verlaengert
--       - NULL/NOT NULL, Default abweichend   -> wird angepasst
--       - Check-Bedingung abweichend          -> Constraint wird neu angelegt
--       - Typwechsel, Verkuerzung, abweichende PK/UK-Spalten,
--         zusaetzliche Spalten in der DB      -> nur WARNUNG, keine Aenderung
--   * Trigger APPL_BIU gehoert zu anderer Tabelle -> Abbruch
--   * Grunddaten per insert ... where not exists (nur fehlende Zeilen, vorhandene bleiben unveraendert)
-- =====================================================================

set define off
set serveroutput on size unlimited
whenever sqlerror exit failure rollback

-- ADMIN_APPLIKATIONEN (APPL): APEX-Applikationen (Module), die im Portal angezeigt werden
declare
  c_table constant varchar2(128) := 'ADMIN_APPLIKATIONEN';

  type t_col is record (name varchar2(128), typ varchar2(100), nullable varchar2(1), dflt varchar2(200));
  type t_cols is table of t_col;
  type t_con is record (name varchar2(128), typ varchar2(1), cols varchar2(4000), cond varchar2(4000));
  type t_cons is table of t_con;

  -- Soll-Spalten (Reihenfolge = Standard: PK, FK, Fachspalten, Audit)
  l_cols t_cols := t_cols(
    t_col('APPL_ID',            'number',             'N', null),
    t_col('APPL_APEX_APP_ID',   'number',             'N', null),
    t_col('APPL_APEX_ALIAS',    'varchar2(255 char)', 'N', null),
    t_col('APPL_BEZEICHNUNG',   'varchar2(100 char)', 'N', null),
    t_col('APPL_BESCHREIBUNG',  'varchar2(4000 char)','Y', null),
    t_col('APPL_ZIELSEITE',     'varchar2(255 char)', 'N', q'['HOME']'),
    t_col('APPL_ICON',          'varchar2(100 char)', 'Y', null),
    t_col('APPL_SORTIERUNG',    'number(5)',          'Y', null),
    t_col('APPL_IST_AKTIV',     'varchar2(1 char)',   'N', q'['Y']'),
    t_col('APPL_CREATED_ON',    'timestamp',          'N', null),
    t_col('APPL_CREATED_BY',    'varchar2(255 char)', 'N', null),
    t_col('APPL_UPDATED_ON',    'timestamp',          'Y', null),
    t_col('APPL_UPDATED_BY',    'varchar2(255 char)', 'Y', null),
    t_col('APPL_ROW_VERSION',   'number',             'N', null)
  );

  -- Soll-Constraints (P = Primaerschluessel, U = Unique, C = Check)
  l_cons t_cons := t_cons(
    t_con('APPL_PK',             'P', 'APPL_ID',          null),
    t_con('APPL_APEX_APP_ID_UK', 'U', 'APPL_APEX_APP_ID', null),
    t_con('APPL_APEX_ALIAS_UK',  'U', 'APPL_APEX_ALIAS',  null),
    t_con('APPL_IST_AKTIV_CK',   'C', null,               q'[APPL_IST_AKTIV in ('Y', 'N')]')
  );

  l_cnt  pls_integer;
  l_ddl  varchar2(32767);

  procedure run(p_sql varchar2) is
  begin
    dbms_output.put_line('  -> ' || p_sql);
    execute immediate p_sql;
  end;

  procedure warn(p_msg varchar2) is
  begin
    dbms_output.put_line('  WARNUNG ' || c_table || ': ' || p_msg);
  end;

  function norm(p_txt varchar2) return varchar2 is
  begin
    return lower(regexp_replace(trim(p_txt), '\s+', ' '));
  end;

  function col_def(p_col t_col) return varchar2 is
  begin
    return p_col.name || ' ' || p_col.typ
        || case when p_col.dflt is not null then ' default ' || p_col.dflt end
        || case when p_col.nullable = 'N' then ' not null' end;
  end;

  function con_def(p_con t_con) return varchar2 is
  begin
    return 'constraint ' || p_con.name || ' '
        || case p_con.typ
             when 'P' then 'primary key (' || p_con.cols || ')'
             when 'U' then 'unique (' || p_con.cols || ')'
             when 'C' then 'check (' || p_con.cond || ')'
           end;
  end;

  -- Ist-Datentyp im selben Format wie die Soll-Definition
  function ist_typ(p_c user_tab_columns%rowtype) return varchar2 is
  begin
    return lower(case
      when p_c.data_type in ('VARCHAR2', 'CHAR', 'NVARCHAR2')
        then p_c.data_type || '(' || p_c.char_length || case p_c.char_used when 'C' then ' char' else ' byte' end || ')'
      when p_c.data_type = 'NUMBER' and p_c.data_precision is null and p_c.data_scale is null
        then 'number'
      when p_c.data_type = 'NUMBER' and nvl(p_c.data_scale, 0) = 0
        then 'number(' || p_c.data_precision || ')'
      when p_c.data_type = 'NUMBER'
        then 'number(' || p_c.data_precision || ',' || p_c.data_scale || ')'
      when p_c.data_type = 'TIMESTAMP(6)'
        then 'timestamp'
      else p_c.data_type
    end);
  end;

  function varchar_len(p_typ varchar2) return number is
  begin
    return to_number(regexp_substr(p_typ, '^varchar2\((\d+) char\)$', 1, 1, 'i', 1));
  end;

  procedure pruefe_spalten is
    l_c     user_tab_columns%rowtype;
    l_ist   varchar2(200);
    l_neu   boolean;
  begin
    for i in 1 .. l_cols.count loop
      l_neu := false;
      begin
        select * into l_c from user_tab_columns
         where table_name = c_table and column_name = l_cols(i).name;
      exception
        when no_data_found then
          l_neu := true;
      end;

      if l_neu then
        -- NOT NULL ohne Default nur moeglich, wenn die Tabelle leer ist
        execute immediate 'select count(*) from ' || c_table || ' where rownum = 1' into l_cnt;
        if l_cols(i).nullable = 'N' and l_cols(i).dflt is null and l_cnt > 0 then
          run('alter table ' || c_table || ' add (' || l_cols(i).name || ' ' || l_cols(i).typ || ')');
          warn(l_cols(i).name || ' ohne NOT NULL ergaenzt (Tabelle enthaelt Daten) – befuellen und NOT NULL setzen');
        else
          run('alter table ' || c_table || ' add (' || col_def(l_cols(i)) || ')');
        end if;
      else
        -- Datentyp
        l_ist := ist_typ(l_c);
        if l_ist <> norm(l_cols(i).typ) then
          if varchar_len(l_ist) < varchar_len(l_cols(i).typ) then
            run('alter table ' || c_table || ' modify (' || l_cols(i).name || ' ' || l_cols(i).typ || ')');
          else
            warn(l_cols(i).name || ': Typ in DB ' || l_ist || ', im Skript ' || norm(l_cols(i).typ) || ' – nicht geaendert');
          end if;
        end if;

        -- Default
        if nvl(nullif(norm(l_c.data_default_vc), 'null'), '-') <> nvl(norm(l_cols(i).dflt), '-') then
          run('alter table ' || c_table || ' modify (' || l_cols(i).name || ' default ' || nvl(l_cols(i).dflt, 'null') || ')');
        end if;

        -- NULL / NOT NULL
        if l_c.nullable <> l_cols(i).nullable then
          begin
            run('alter table ' || c_table || ' modify (' || l_cols(i).name
                || case l_cols(i).nullable when 'N' then ' not null' else ' null' end || ')');
          exception
            when others then
              warn(l_cols(i).name || ': NULL/NOT NULL nicht anpassbar (' || sqlerrm || ')');
          end;
        end if;
      end if;
    end loop;

    -- Spalten in der DB, die das Skript nicht kennt
    for r in (select column_name from user_tab_columns where table_name = c_table order by column_id) loop
      l_cnt := 0;
      for i in 1 .. l_cols.count loop
        if l_cols(i).name = r.column_name then l_cnt := 1; end if;
      end loop;
      if l_cnt = 0 then
        warn('Spalte ' || r.column_name || ' existiert in der DB, aber nicht im Skript');
      end if;
    end loop;
  end;

  procedure pruefe_constraints is
    l_typ  user_constraints.constraint_type%type;
    l_tab  user_constraints.table_name%type;
    l_cond varchar2(4000);
    l_ist  varchar2(4000);
  begin
    for i in 1 .. l_cons.count loop
      begin
        select constraint_type, table_name, search_condition_vc
          into l_typ, l_tab, l_cond
          from user_constraints
         where constraint_name = l_cons(i).name;
      exception
        when no_data_found then
          l_tab := null;
      end;

      if l_tab is null then
        run('alter table ' || c_table || ' add ' || con_def(l_cons(i)));
      elsif l_tab <> c_table then
        raise_application_error(-20001, 'Constraint ' || l_cons(i).name || ' gehoert bereits zu Tabelle ' || l_tab);
      elsif l_cons(i).typ = 'C' then
        if norm(l_cond) <> norm(l_cons(i).cond) then
          run('alter table ' || c_table || ' drop constraint ' || l_cons(i).name);
          run('alter table ' || c_table || ' add ' || con_def(l_cons(i)));
        end if;
      else
        select listagg(column_name, ', ') within group (order by position)
          into l_ist
          from user_cons_columns
         where constraint_name = l_cons(i).name;
        if l_typ <> l_cons(i).typ or norm(l_ist) <> norm(l_cons(i).cols) then
          warn(l_cons(i).name || ': in DB ' || l_typ || ' (' || l_ist || '), im Skript '
               || l_cons(i).typ || ' (' || l_cons(i).cols || ') – nicht geaendert');
        end if;
      end if;
    end loop;
  end;

begin
  select count(*) into l_cnt from user_tables where table_name = c_table;

  if l_cnt = 0 then
    dbms_output.put_line(c_table || ': wird angelegt');
    l_ddl := 'create table ' || c_table || ' (';
    for i in 1 .. l_cols.count loop
      l_ddl := l_ddl || chr(10) || '  ' || col_def(l_cols(i)) || ',';
    end loop;
    for i in 1 .. l_cons.count loop
      l_ddl := l_ddl || chr(10) || '  ' || con_def(l_cons(i)) || case when i < l_cons.count then ',' end;
    end loop;
    run(l_ddl || chr(10) || ')');
  else
    dbms_output.put_line(c_table || ': vorhanden, Abgleich mit Skript');
  end if;

  pruefe_spalten;
  pruefe_constraints;
end;
/

-- Trigger: nur anlegen/ersetzen, wenn APPL_BIU nicht zu einer anderen Tabelle gehoert
declare
  l_tab user_triggers.table_name%type;
begin
  select table_name into l_tab from user_triggers where trigger_name = 'APPL_BIU';
  if l_tab <> 'ADMIN_APPLIKATIONEN' then
    raise_application_error(-20002, 'Trigger APPL_BIU gehoert bereits zu Tabelle ' || l_tab);
  end if;
exception
  when no_data_found then null;
end;
/

create or replace trigger APPL_BIU
  before insert or update on ADMIN_APPLIKATIONEN
  for each row
begin
  if inserting then
    :new.APPL_ID := coalesce(:new.APPL_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.APPL_CREATED_ON  := systimestamp;
    :new.APPL_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.APPL_UPDATED_ON  := null;
    :new.APPL_UPDATED_BY  := null;
    :new.APPL_ROW_VERSION := 1;
  elsif updating then
    :new.APPL_ID          := :old.APPL_ID;  -- Primaerschluessel ist unveraenderlich
    :new.APPL_CREATED_ON  := :old.APPL_CREATED_ON;
    :new.APPL_CREATED_BY  := :old.APPL_CREATED_BY;
    :new.APPL_UPDATED_ON  := systimestamp;
    :new.APPL_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.APPL_ROW_VERSION := nvl(:old.APPL_ROW_VERSION, 0) + 1;
  end if;
  :new.APPL_APEX_ALIAS := upper(:new.APPL_APEX_ALIAS);
  :new.APPL_ZIELSEITE  := upper(:new.APPL_ZIELSEITE);
end APPL_BIU;
/

comment on table ADMIN_APPLIKATIONEN is 'APEX-Applikationen (Module), die im Portal als Kacheln angezeigt werden [Alias APPL]';
comment on column ADMIN_APPLIKATIONEN.APPL_ID is 'Primaerschluessel (SYS_GUID)';
comment on column ADMIN_APPLIKATIONEN.APPL_APEX_APP_ID is 'APEX-Applikations-ID, z.B. 20010';
comment on column ADMIN_APPLIKATIONEN.APPL_APEX_ALIAS is 'APEX-Applikations-Alias fuer den Link (f?p=<Alias>:<Zielseite>), z.B. THG-ALLGEMEIN';
comment on column ADMIN_APPLIKATIONEN.APPL_BEZEICHNUNG is 'Anzeigename der Kachel, z.B. Kundenstammdaten';
comment on column ADMIN_APPLIKATIONEN.APPL_BESCHREIBUNG is 'Beschreibungstext der Kachel';
comment on column ADMIN_APPLIKATIONEN.APPL_ZIELSEITE is 'Seiten-Alias oder -Nummer der Einstiegsseite, Standard HOME';
comment on column ADMIN_APPLIKATIONEN.APPL_ICON is 'Font-APEX-Iconklasse, z.B. fa-address-book';
comment on column ADMIN_APPLIKATIONEN.APPL_SORTIERUNG is 'Reihenfolge der Anzeige';
comment on column ADMIN_APPLIKATIONEN.APPL_IST_AKTIV is 'Y = wird im Portal angezeigt';
comment on column ADMIN_APPLIKATIONEN.APPL_CREATED_ON is 'Audit: angelegt am';
comment on column ADMIN_APPLIKATIONEN.APPL_CREATED_BY is 'Audit: angelegt von';
comment on column ADMIN_APPLIKATIONEN.APPL_UPDATED_ON is 'Audit: zuletzt geaendert am';
comment on column ADMIN_APPLIKATIONEN.APPL_UPDATED_BY is 'Audit: zuletzt geaendert von';
comment on column ADMIN_APPLIKATIONEN.APPL_ROW_VERSION is 'Audit: Versionszaehler (optimistisches Locking)';

-- Grunddaten (bisher statische Liste "Module" der Portal-App): nur fehlende Zeilen einfuegen, vorhandene bleiben unveraendert
-- (insert ... where not exists statt merge: ein MERGE im Skript fuehrt in SQLcl 26.2 dazu, dass der PL/SQL-Block oben nicht ausgefuehrt wird)
-- Portal selbst: nur zur Vollstaendigkeit erfasst, APPL_IST_AKTIV = 'N' -> keine Kachel, kein Menuepunkt
insert into ADMIN_APPLIKATIONEN (APPL_APEX_APP_ID, APPL_APEX_ALIAS, APPL_BEZEICHNUNG, APPL_BESCHREIBUNG, APPL_ZIELSEITE, APPL_ICON, APPL_SORTIERUNG, APPL_IST_AKTIV)
  select 20000, 'THG-PORTAL', 'Portal', 'Einstieg mit Modul-Kacheln (Master-App für Shared Components)', 'HOME', 'fa-th-large', 0, 'N'
    from dual
   where not exists (select 1 from ADMIN_APPLIKATIONEN where APPL_APEX_APP_ID = 20000);
insert into ADMIN_APPLIKATIONEN (APPL_APEX_APP_ID, APPL_APEX_ALIAS, APPL_BEZEICHNUNG, APPL_BESCHREIBUNG, APPL_ZIELSEITE, APPL_ICON, APPL_SORTIERUNG)
  select 20010, 'THG-ALLGEMEIN', 'Allgemein', 'Allgemeine Stammdaten: Länder, Zahlungsbedingungen, Kommunikationsarten, Mitarbeiter, Adressen', 'HOME', 'fa-gear', 10
    from dual
   where not exists (select 1 from ADMIN_APPLIKATIONEN where APPL_APEX_APP_ID = 20010);
insert into ADMIN_APPLIKATIONEN (APPL_APEX_APP_ID, APPL_APEX_ALIAS, APPL_BEZEICHNUNG, APPL_BESCHREIBUNG, APPL_ZIELSEITE, APPL_ICON, APPL_SORTIERUNG)
  select 20020, 'THG-KUNDEN', 'Kundenstammdaten', 'Kundenstamm: Kunden, Standorte, Ansprechpartner, Betreuung', 'HOME', 'fa-address-book', 20
    from dual
   where not exists (select 1 from ADMIN_APPLIKATIONEN where APPL_APEX_APP_ID = 20020);
insert into ADMIN_APPLIKATIONEN (APPL_APEX_APP_ID, APPL_APEX_ALIAS, APPL_BEZEICHNUNG, APPL_BESCHREIBUNG, APPL_ZIELSEITE, APPL_ICON, APPL_SORTIERUNG)
  select 20030, 'THG-ADMIN', 'Administration', 'Konfiguration der Anwendung (Applikationen/Portal-Kacheln) und Monitoring (Aktivitätsprotokoll)', 'HOME', 'fa-gears', 90
    from dual
   where not exists (select 1 from ADMIN_APPLIKATIONEN where APPL_APEX_APP_ID = 20030);

commit;

prompt ADMIN_APPLIKATIONEN installiert bzw. abgeglichen.
