# Projekt ThGERP

ERP-System für die THG-EDV GmbH (operatives IT-Geschäft) und die Thomas Geßlbauer GmbH (Holding).
Basis: Portal- und Sub-Apps mit Kundenstamm-Datenmodell sowie die Strategic-Planner-App als Vorlage.

## Status / offene Entscheidungen
- Workspace `THGERP`, Schema `WKSP_THGERP`, SQLcl-Verbindung `wksp_thgerp@pdbthg` (Host dbthgprod, für ERP-Entwicklung freigegeben).
- App-IDs ab 20000: 20000 THG-PORTAL, 20010 THG-ALLGEMEIN, 20020 THG-KUNDEN, 20030 THG-ADMIN, 20040 THG-ARTIKEL, 20050 THG-FINANZ (Fakturierung, Tabellen FAKT_*).
  Die Apps 10000–10030 im Workspace SIPA (gleiche APEX-Instanz) gehören zu einem Kundenprojekt und dürfen **nicht** verwendet werden.
- Installiert (Stand 2026-09-26): alle DDL-Skripte 01–23 (ohne 14, stammt aus einem anderen Projekt), Workspace-Dateien, Apps 20000–20050; Kunden und Artikel aus Kingbill (Access) übernommen.

Offen:
- DEV/PROD-Trennung

## Datenbank-Standards
Es gelten die THG-EDV-Datenbankstandards (Skill `thg-oracle-db-standards`).
- Gruppencodes: `KUND` (Kundenstamm), `ALLG` (allgemeine Stammdaten), `ADMIN` (Administration, bewusst 5-stellig), `ARTI` (Artikelstamm), `FAKT` (Fakturierung)
- Tabellen-Aliase: `Datenbank/db/aliase.md` – vor jeder neuen Tabelle prüfen und dort eintragen
- DDL-Skripte: `Datenbank/db/ddl` (nummeriert, `00_install.sql` ruft alle auf)
- ER-Modelle: `Datenbank/db/er-modell/kundenstamm_er_modell.mmd` und `artikel_fakturierung_er_modell.mmd` (generiert aus `ddl/generator/gen_19_20_…`) sind die Quellen; nach Modelländerungen `.mmd` anpassen und mit `python3 build_er_modell.py` PDF/SVG/PNG/HTML neu erzeugen
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
- Gemeinsame Workspace-Dateien `thg.css`, `thg.js` (Logo-Klick → Prüfung ungespeicherter Änderungen → Portal-Startseite), Logos in `Apex/workspace-files/`; nach Änderung `python3 build_install.py` und das erzeugte `install_workspace_files.sql` einspielen – kein App-Import nötig.
- Mandant: wird im Portal gewählt (Navigationsleiste) und gilt über Session Sharing (globale Items `MANDANT_*`) in allen Apps, bis er im Portal gewechselt wird. Sub-Apps belegen nur vor (App-Prozess „Mandant vorbelegen“), wechseln nie; Logo/Bannerfarbe je Mandant. Einrichtung neuer Sub-Apps: `python3 Apex/generator/mandant_in_apps.py`.
  Kunden und Artikel sind mandantenübergreifend; Finanz (FAKT_*) ist mandantenabhängig (`RECH_MAND_ID = :MANDANT_ID`).
- Theme-Stil: Standard Redwood Light; Stilauswahl im Portal speichert den Stil beim Mitarbeiter (`MITA_THEME_STIL`) und setzt ihn per `apex_theme.set_session_style` für die Sitzung in allen Apps (App-Prozess „Theme-Stil“ in jeder App, einmal je Anmeldung). Bannerfarbe kommt in allen Stilen vom Mandanten (`thg.css`).
- Quellen im APEXlang-Format; Einspielen per SQLcl `apex validate` + `apex import`.
- `Apex/strategic-planner` ist Vorlage und wird nicht in Git eingecheckt.

## Git
- Repository: https://github.com/thg27/ThGERP (Branch `main`)
- Nach Änderungen committen, Commit-Nachricht beschreibt den Inhalt

## Wissensdatenbank
- `Wissensdatenbank/` sammelt Praxiswissen (Oracle SQL, PL/SQL, APEX, SQLcl, ORDS, Git/GitHub, Datenmodell, Troubleshooting); Aufbau und Konventionen in `Wissensdatenbank/README.md`.
- Laufend pflegen: Wenn bei der Arbeit eine Lösung, ein Muster, ein Stolperstein oder eine Fehlerursache gefunden wird, die wieder vorkommen kann, einen Eintrag anlegen oder den bestehenden aktualisieren und im Index (`README.md` des Bereichs) eintragen. Neue Bereiche bei Bedarf ergänzen.
- Vor der Lösung eines Problems zuerst in der Wissensdatenbank nachsehen.
