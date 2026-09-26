# LOVs zentral im Portal + Subscriptions

## Kontext
Die Portal-App (20000) ist Master für Shared Components. Sub-Apps (20010–20030) legen keine eigenen List of Values an, sondern abonnieren sie. Damit gibt es jede Werteliste genau einmal.

## Vorgehen
1. LOV in der Portal-App anlegen, Name mit Präfix `LOV_`.
2. In der Sub-App (APEXlang) in der LOV: `subscription { master: @/<portal-id>/<static-id> }`
3. In `deployments/default.json` der Sub-App: `"subscription": {"masterApps": {...}}`
4. Einspielen **einzeln nacheinander**: Portal → Sub-Apps.
5. Subscriptions aktualisieren:
   ```sql
   begin
     apex_shared_component.refresh( ... );
   end;
   /
   ```
6. Prüfen – alle Einträge müssen `UP_TO_DATE` sein:
   ```sql
   select * from apex_subscribed_components;
   ```

## Stolpersteine
- Wird eine Sub-App vor dem Portal importiert, zeigt die Subscription ins Leere.
- Eigene LOVs in Sub-Apps widersprechen dem Standard und führen zu Doppelpflege.


## Quelle / Stand

Aus der Projektarbeit ThGERP, Stand 2026-09-26.
