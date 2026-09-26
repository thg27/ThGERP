# APEX-Apps mit SQLcl einspielen

## Vorgehen
Befehle **einzeln nacheinander** (der SQLcl-MCP-Server hat nur eine Sitzung), immer mit App-ID und Deployment:

```text
apex validate -input Apex/<app> -deployment Apex/<app>/deployments/default.json
apex import   -input Apex/<app> -deployment Apex/<app>/deployments/default.json -id <app-id>
```
Reihenfolge: Portal (20000) → Sub-Apps → Subscriptions aktualisieren:

```sql
begin
    apex_util.set_workspace(p_workspace => 'THGERP');
    for c in (select component_type, component_id from apex_subscribed_components
               where application_id in (20010, 20020, 20030, 20040)
                 and subscription_status <> apex_shared_component.c_status_up_to_date) loop
        apex_shared_component.refresh(p_component_type => c.component_type, p_component_id => c.component_id);
    end loop;
    commit;
end;
```
Kontrolle: `apex_applications` (ID, Alias, Seiten) und `apex_subscribed_components` – alle `UP_TO_DATE`.

## Stolpersteine
- `apex_shared_component.refresh` braucht **beide** Parameter (`p_component_type`, `p_component_id`); nur die ID → PLS-00306.
- Spalte heißt `subscription_status` (nicht `status`).
- `ORA-17008: Geschlossene Verbindung` nach längerer Pause: Verbindung `wksp_thgerp@pdbthg` neu herstellen.
- `commit` im MCP-Tool `sql_run` wird nicht erkannt („Unbekannter Befehl“) → über `sqlcl_run` mit `commit;`.

## Quelle / Stand
2026-09-26, APEX 26.1, SQLcl 26.x.
