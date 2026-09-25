-- =====================================================================
-- Kundenstamm-Datenmodell (Gruppen KUND, ALLG, ADMIN)
-- 11 – Hilfspaket DDL_UTIL fuer wiederholbare Installations-/Aenderungsskripte
--      Tabellen, Spalten, Constraints, Indizes und Trigger-Namen werden nur angelegt bzw.
--      angepasst, wenn sie fehlen oder abweichen; riskante Abweichungen nur als WARNUNG.
-- Erzeugt: 2026-09-25
-- Voraussetzung: Oracle 23ai+ (DATA_DEFAULT_VC, SEARCH_CONDITION_VC)
-- =====================================================================

set define off

create or replace package DDL_UTIL
as
    -- Tabelle anlegen, falls sie fehlt (p_create = vollstaendiges CREATE TABLE)
    procedure tabelle(p_table in varchar2, p_create in varchar2);

    -- Spalte sicherstellen: fehlt -> anlegen; varchar2 im Skript laenger -> verlaengern;
    -- Default und NULL/NOT NULL angleichen; Typwechsel/Verkuerzung -> nur Warnung
    procedure spalte(p_table in varchar2, p_column in varchar2, p_type in varchar2,
                     p_nullable in varchar2 default 'Y', p_default in varchar2 default null);

    -- Constraint sicherstellen: P/U = Spaltenliste, C = Bedingung,
    -- R = "SPALTE references TABELLE (SPALTE)"; fehlt -> anlegen; C abweichend -> neu anlegen;
    -- Name gehoert zu anderer Tabelle -> Abbruch
    procedure constraint_(p_table in varchar2, p_name in varchar2, p_type in varchar2, p_spec in varchar2);

    -- Index sicherstellen (p_spalten = Spalten oder Ausdruck), fehlt -> anlegen
    procedure index_(p_table in varchar2, p_name in varchar2, p_spalten in varchar2, p_unique in boolean default false);

    -- Abbruch, wenn der Trigger-Name bereits zu einer anderen Tabelle gehoert
    procedure trigger_pruefen(p_trigger in varchar2, p_table in varchar2);
end DDL_UTIL;
/

create or replace package body DDL_UTIL
as
    procedure run(p_sql in varchar2) is
    begin
        dbms_output.put_line('  -> ' || p_sql);
        execute immediate p_sql;
    end;

    procedure warn(p_table in varchar2, p_msg in varchar2) is
    begin
        dbms_output.put_line('  WARNUNG ' || p_table || ': ' || p_msg);
    end;

    function norm(p_txt in varchar2) return varchar2 is
    begin
        return lower(regexp_replace(trim(p_txt), '\s+', ' '));
    end;

    function ist_typ(p_c in user_tab_columns%rowtype) return varchar2 is
    begin
        return lower(case
            when p_c.data_type in ('VARCHAR2', 'CHAR', 'NVARCHAR2')
                then p_c.data_type || '(' || p_c.char_length || case p_c.char_used when 'C' then ' char' else ' byte' end || ')'
            when p_c.data_type = 'NUMBER' and p_c.data_precision is null and p_c.data_scale is null then 'number'
            when p_c.data_type = 'NUMBER' and nvl(p_c.data_scale, 0) = 0 then 'number(' || p_c.data_precision || ')'
            when p_c.data_type = 'NUMBER' then 'number(' || p_c.data_precision || ',' || p_c.data_scale || ')'
            when p_c.data_type = 'TIMESTAMP(6)' then 'timestamp'
            else p_c.data_type
        end);
    end;

    function varchar_len(p_typ in varchar2) return number is
    begin
        return to_number(regexp_substr(p_typ, '^varchar2\((\d+) char\)$', 1, 1, 'i', 1));
    end;

    procedure tabelle(p_table in varchar2, p_create in varchar2) is
        l_cnt pls_integer;
    begin
        select count(*) into l_cnt from user_tables where table_name = upper(p_table);
        if l_cnt = 0 then
            dbms_output.put_line(upper(p_table) || ': wird angelegt');
            run(p_create);
        else
            dbms_output.put_line(upper(p_table) || ': vorhanden, Abgleich');
        end if;
    end;

    procedure spalte(p_table in varchar2, p_column in varchar2, p_type in varchar2,
                     p_nullable in varchar2 default 'Y', p_default in varchar2 default null) is
        l_c   user_tab_columns%rowtype;
        l_ist varchar2(200);
        l_cnt pls_integer;
    begin
        begin
            select * into l_c from user_tab_columns where table_name = upper(p_table) and column_name = upper(p_column);
        exception
            when no_data_found then
                execute immediate 'select count(*) from ' || p_table || ' where rownum = 1' into l_cnt;
                if p_nullable = 'N' and p_default is null and l_cnt > 0 then
                    run('alter table ' || p_table || ' add (' || p_column || ' ' || p_type || ')');
                    warn(p_table, p_column || ' ohne NOT NULL ergaenzt (Tabelle enthaelt Daten)');
                else
                    run('alter table ' || p_table || ' add (' || p_column || ' ' || p_type
                        || case when p_default is not null then ' default ' || p_default end
                        || case when p_nullable = 'N' then ' not null' end || ')');
                end if;
                return;
        end;

        l_ist := ist_typ(l_c);
        if l_ist <> norm(p_type) then
            if varchar_len(l_ist) < varchar_len(p_type) then
                run('alter table ' || p_table || ' modify (' || p_column || ' ' || p_type || ')');
            else
                warn(p_table, p_column || ': Typ in DB ' || l_ist || ', im Skript ' || norm(p_type) || ' - nicht geaendert');
            end if;
        end if;

        if nvl(nullif(norm(l_c.data_default_vc), 'null'), '-') <> nvl(norm(p_default), '-') then
            run('alter table ' || p_table || ' modify (' || p_column || ' default ' || nvl(p_default, 'null') || ')');
        end if;

        if l_c.nullable <> p_nullable then
            begin
                run('alter table ' || p_table || ' modify (' || p_column
                    || case p_nullable when 'N' then ' not null' else ' null' end || ')');
            exception
                when others then warn(p_table, p_column || ': NULL/NOT NULL nicht anpassbar (' || sqlerrm || ')');
            end;
        end if;
    end;

    procedure constraint_(p_table in varchar2, p_name in varchar2, p_type in varchar2, p_spec in varchar2) is
        l_typ  user_constraints.constraint_type%type;
        l_tab  user_constraints.table_name%type;
        l_cond varchar2(4000);
        l_ist  varchar2(4000);
        l_def  varchar2(4000);
    begin
        l_def := 'constraint ' || p_name || ' ' ||
                 case p_type
                     when 'P' then 'primary key (' || p_spec || ')'
                     when 'U' then 'unique (' || p_spec || ')'
                     when 'C' then 'check (' || p_spec || ')'
                     when 'R' then 'foreign key (' || regexp_substr(p_spec, '^\s*(\S+)\s+references', 1, 1, 'i', 1) || ') '
                                   || regexp_substr(p_spec, 'references.*$', 1, 1, 'i')
                 end;
        begin
            select constraint_type, table_name, search_condition_vc into l_typ, l_tab, l_cond
              from user_constraints where constraint_name = upper(p_name);
        exception
            when no_data_found then l_tab := null;
        end;

        if l_tab is null then
            run('alter table ' || p_table || ' add ' || l_def);
        elsif l_tab <> upper(p_table) then
            raise_application_error(-20001, 'Constraint ' || p_name || ' gehoert bereits zu Tabelle ' || l_tab);
        elsif p_type = 'C' then
            if norm(l_cond) <> norm(p_spec) then
                run('alter table ' || p_table || ' drop constraint ' || p_name);
                run('alter table ' || p_table || ' add ' || l_def);
            end if;
        elsif p_type in ('P', 'U') then
            select listagg(column_name, ', ') within group (order by position) into l_ist
              from user_cons_columns where constraint_name = upper(p_name);
            if norm(l_ist) <> norm(p_spec) then
                warn(p_table, p_name || ': Spalten in DB (' || l_ist || '), im Skript (' || p_spec || ') - nicht geaendert');
            end if;
        end if;
    end;

    procedure index_(p_table in varchar2, p_name in varchar2, p_spalten in varchar2, p_unique in boolean default false) is
        l_tab user_indexes.table_name%type;
    begin
        select table_name into l_tab from user_indexes where index_name = upper(p_name);
        if l_tab <> upper(p_table) then
            raise_application_error(-20003, 'Index ' || p_name || ' gehoert bereits zu Tabelle ' || l_tab);
        end if;
    exception
        when no_data_found then
            run('create ' || case when p_unique then 'unique ' end || 'index ' || p_name || ' on ' || p_table || ' (' || p_spalten || ')');
    end;

    procedure trigger_pruefen(p_trigger in varchar2, p_table in varchar2) is
        l_tab user_triggers.table_name%type;
    begin
        select table_name into l_tab from user_triggers where trigger_name = upper(p_trigger);
        if l_tab <> upper(p_table) then
            raise_application_error(-20002, 'Trigger ' || p_trigger || ' gehoert bereits zu Tabelle ' || l_tab);
        end if;
    exception
        when no_data_found then null;
    end;
end DDL_UTIL;
/

prompt DDL_UTIL installiert.
