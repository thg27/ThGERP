# Projekt ThGERP

ERP-System für die THG-EDV GmbH (operatives IT-Geschäft) und die Thomas Geßlbauer GmbH (Holding).
Basis: Portal- und Sub-Apps mit Kundenstamm-Datenmodell sowie die Strategic-Planner-App als Vorlage.

## Status / offene Entscheidungen
- Workspace `THGERP`, Schema `WKSP_THGERP`, SQLcl-Verbindung `wksp_thgerp@pdbthg` (Host dbthgprod, für ERP-Entwicklung freigegeben).
- App-IDs ab 20000: 20000 THG-PORTAL, 20010 THG-ALLGEMEIN, 20020 THG-KUNDEN, 20030 THG-ADMIN.
  Die Apps 10000–10030 im Workspace SIPA (gleiche APEX-Instanz) gehören zu einem Kundenprojekt und dürfen **nicht** verwendet werden.
- Installiert (2026-09-26): `ADMIN_APPLIKATIONEN` (07), Workspace-Dateien, App 20000. Die übrigen DDL-Skripte und die Sub-Apps sind noch nicht eingespielt.

Offen:
- DEV/PROD-Trennung
- Mandantenfähigkeit (zwei Firmen: THG-EDV GmbH, Thomas Geßlbauer GmbH)
- Farben in `thg.css` (Header-Braun `#6b5444`, Fokus `#f6ecd9`) auf THG-EDV-Farben umstellen

## Datenbank-Standards
Es gelten die THG-EDV-Datenbankstandards (Skill `thg-oracle-db-standards`).
- Gruppencodes: `KUND` (Kundenstamm), `ALLG` (allgemeine Stammdaten), `ADMIN` (Administration, bewusst 5-stellig)
- Tabellen-Aliase: `Datenbank/db/aliase.md` – vor jeder neuen Tabelle prüfen und dort eintragen
- DDL-Skripte: `Datenbank/db/ddl` (nummeriert, `00_install.sql` ruft alle auf)
- ER-Modell: `Datenbank/db/er-modell/kundenstamm_er_modell.mmd` ist die Quelle; nach Modelländerungen `.mmd` anpassen und PDF/SVG/PNG/HTML neu erzeugen
- Zieldatenbank: Oracle AI Database 26ai (Objektnamen bis 128 Zeichen)
- Nie auf Produktion ausführen. Vor jedem DDL/DML auf der Datenbank Rückfrage.
- Vor einer Installation in ein bestehendes Schema prüfen, ob Constraint-, Index- oder Triggernamen dort schon existieren –
  `create or replace trigger` würde gleichnamige Trigger ersetzen.

## APEX
- Portal-App ist Master für Shared Components; Sub-Apps abonnieren.
- **List of Values immer in der Portal-App anlegen**; in den Sub-Apps nur als Subscription (keine eigenen LOVs). LOV-Namen mit Präfix `LOV_`.
  APEXlang: `subscription { master: @/<portal-id>/<static-id> }` in der LOV und `"subscription": {"masterApps": {...}}` in `deployments/default.json` der Sub-App.
  Einspielen (einzeln nacheinander): 1. Portal, 2. Sub-Apps, 3. Subscriptions mit `apex_shared_component.refresh` aktualisieren, 4. `apex_subscribed_components` prüfen – alle `UP_TO_DATE`.
- Wertelisten-Pflege: Kunden-Wertelisten (KUND_*) in THG-KUNDEN unter Administration > Wertelisten (generiert mit `Apex/generator/gen_wertelisten_kunden.py`); allgemeine Wertelisten (ALLG_*) in THG-ALLGEMEIN unter Look Up Values.
- Gemeinsame Workspace-Dateien `thg.css` und `thg-logo.svg` in `Apex/workspace-files/`; nach Änderung `python3 build_install.py` und das erzeugte `install_workspace_files.sql` einspielen – kein App-Import nötig.
- Theme-Stil: Redwood Light; Stilauswahl im Portal setzt `apex_theme.set_current_style` für alle Apps aus `ADMIN_APPLIKATIONEN`.
- Quellen im APEXlang-Format; Einspielen per SQLcl `apex validate` + `apex import`.
- `Apex/strategic-planner` ist Vorlage und wird nicht in Git eingecheckt.

## Git
- Repository: https://github.com/thg27/ThGERP (Branch `main`)
- Nach Änderungen committen, Commit-Nachricht beschreibt den Inhalt
