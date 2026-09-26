"""Gemeinsame Erzeugung wiederholbarer DDL-Skripte (nutzt Paket DDL_UTIL aus 11_ddl_util.sql).

Tabelle  = (tabelle, alias, kommentar, spalten, constraints, indizes, zusatz_trigger)
Spalte   = (name, typ, nullable 'Y'/'N', default oder None, kommentar)
Constraint = (name, typ 'U'/'C'/'R', spezifikation)
Index    = (name, spalten[, unique])  – Spalten auch als Ausdruck (funktionsbasiert)
"""

AUDIT = lambda a: [
    (f'{a}_CREATED_ON', 'timestamp', 'N', None, 'Audit: angelegt am'),
    (f'{a}_CREATED_BY', 'varchar2(255 char)', 'N', None, 'Audit: angelegt von'),
    (f'{a}_UPDATED_ON', 'timestamp', 'Y', None, 'Audit: zuletzt geaendert am'),
    (f'{a}_UPDATED_BY', 'varchar2(255 char)', 'Y', None, 'Audit: zuletzt geaendert von'),
    (f'{a}_ROW_VERSION', 'number', 'N', None, 'Audit: Versionszaehler (optimistisches Locking)'),
]


def flag(a, name, dflt, kom):
    """Flag-Spalte Y/N mit Default; Check-Constraint liefert flag_ck()."""
    return (f'{a}_{name}', 'varchar2(1 char)', 'N', f"'{dflt}'", kom)


def flag_ck(a, name):
    return (f'{a}_{name}_CK', 'C', f"{a}_{name} in ('Y', 'N')")


def q(s):
    return s.replace("'", "''")


def render(kopf, tabellen, grunddaten='', schluss='installiert bzw. abgeglichen.'):
    out = [kopf.strip() + '\n\nset define off\nset serveroutput on size unlimited\n']

    for tab, a, kom, cols, cons, idx, extra in tabellen:
        alle = cols + AUDIT(a)
        create_cols = ',\n  '.join(f"{c} {t}" + (f" default {d}" if d else '') + (' not null' if n == 'N' else '')
                                   for c, t, n, d, _ in alle)
        create = f"create table {tab} (\n  {create_cols},\n  constraint {a}_PK primary key ({a}_ID)\n)"
        block = [f"-- {tab} ({a}): {kom}", 'begin', f"    DDL_UTIL.tabelle('{tab}', q'~{create}~');"]
        for c, t, n, d, _ in alle:
            block.append(f"    DDL_UTIL.spalte('{tab}', '{c}', '{t}', '{n}'" + (f", q'~{d}~'" if d else '') + ');')
        block.append(f"    DDL_UTIL.constraint_('{tab}', '{a}_PK', 'P', '{a}_ID');")
        for n_, ty, sp in cons:
            if ty != 'R':
                block.append(f"    DDL_UTIL.constraint_('{tab}', '{n_}', '{ty}', q'~{sp}~');")
        block.append('end;\n/\n')
        out.append('\n'.join(block))

    # Fremdschluessel und Indizes nach allen Tabellen (Reihenfolge der Tabellen egal)
    fk = ['-- Fremdschluessel, FK-Indizes und fachliche Indizes', 'begin']
    for tab, a, kom, cols, cons, idx, extra in tabellen:
        for n_, ty, sp in cons:
            if ty == 'R':
                fk.append(f"    DDL_UTIL.constraint_('{tab}', '{n_}', 'R', '{sp}');")
        for i in idx:
            n_, sp = i[0], i[1]
            uniq = len(i) > 2 and i[2]
            fk.append(f"    DDL_UTIL.index_('{tab}', '{n_}', q'~{sp}~'" + (', true' if uniq else '') + ');')
    fk.append('end;\n/\n')
    out.append('\n'.join(fk))

    for tab, a, kom, cols, cons, idx, extra in tabellen:
        out.append(f"""begin
    DDL_UTIL.trigger_pruefen('{a}_BIU', '{tab}');
end;
/

create or replace trigger {a}_BIU
  before insert or update on {tab}
  for each row
begin
  if inserting then
    :new.{a}_ID := coalesce(:new.{a}_ID, to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'));
    :new.{a}_CREATED_ON  := systimestamp;
    :new.{a}_CREATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.{a}_UPDATED_ON  := null;
    :new.{a}_UPDATED_BY  := null;
    :new.{a}_ROW_VERSION := 1;
  elsif updating then
    :new.{a}_ID          := :old.{a}_ID;  -- Primaerschluessel ist unveraenderlich
    :new.{a}_CREATED_ON  := :old.{a}_CREATED_ON;
    :new.{a}_CREATED_BY  := :old.{a}_CREATED_BY;
    :new.{a}_UPDATED_ON  := systimestamp;
    :new.{a}_UPDATED_BY  := coalesce(sys_context('APEX$SESSION', 'APP_USER'), user);
    :new.{a}_ROW_VERSION := nvl(:old.{a}_ROW_VERSION, 0) + 1;
  end if;{extra}
end {a}_BIU;
/
""")

    kom_lines = []
    for tab, a, kom, cols, cons, idx, extra in tabellen:
        kom_lines.append(f"comment on table {tab} is '{q(kom)} [Alias {a}]';")
        for c, t, n, d, k in cols + AUDIT(a):
            kom_lines.append(f"comment on column {tab}.{c} is '{q(k)}';")
        kom_lines.append('')
    out.append('\n'.join(kom_lines))

    if grunddaten:
        out.append('-- Grunddaten: nur fehlende Zeilen\n' + grunddaten.strip() + '\ncommit;\n')
    out.append(f"prompt {', '.join(t[0] for t in tabellen)} {schluss}\n")
    return '\n'.join(out)


def insert_wenn_fehlt(tab, spalten, werte, schluessel):
    """insert ... select ... from dual where not exists (schluessel = Spalte des fachlichen Schluessels)."""
    idx = spalten.index(schluessel)
    return (f"insert into {tab} ({', '.join(spalten)})\n"
            f"  select {', '.join(werte)} from dual\n"
            f"   where not exists (select 1 from {tab} where {schluessel} = {werte[idx]});")


def mermaid(tabellen, titel, extern=()):
    """ER-Modell (Mermaid erDiagram) aus den Tabellendefinitionen; FK-Beziehungen aus den R-Constraints.
    extern: Tabellen anderer Skripte, die nur als Beziehungsziel erscheinen."""
    import re
    typ = lambda t: re.match(r'[a-z0-9]+', t).group(0)
    lines = ['---', f'title: {titel}', '---', 'erDiagram']
    for tab, a, kom, cols, cons, idx, extra in tabellen:
        for n_, ty, sp in cons:
            if ty == 'R':
                spalte, ziel = re.match(r'(\w+) references (\w+)', sp).groups()
                pflicht = next(c for c in cols if c[0] == spalte)[2] == 'N'
                label = next(c for c in cols if c[0] == spalte)[4].replace('FK: ', '').split(' (')[0].split(',')[0]
                lines.append(f'  {ziel} {"||" if pflicht else "|o"}--o{{ {tab} : "{label}"')
    for tab, a, kom, cols, cons, idx, extra in tabellen:
        uk = {s.strip() for n_, ty, sp in cons if ty == 'U' for s in sp.split(',')}
        fk = {re.match(r'(\w+)', sp).group(1) for n_, ty, sp in cons if ty == 'R'}
        lines.append(f'  {tab} {{')
        for c, t, n, d, k in cols + AUDIT(a):
            key = 'PK' if c == f'{a}_ID' else ('FK' if c in fk else ('UK' if c in uk else ''))
            note = 'Audit' if k.startswith('Audit') else k.split(', ')[0].split(' (')[0].replace('"', "'")[:40]
            lines.append(f'    {typ(t)} {c}' + (f' {key}' if key else '') + f' "{note}"')
        lines.append('  }')
    return '\n'.join(lines) + '\n'
