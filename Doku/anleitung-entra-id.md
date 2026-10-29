# Anmeldung mit Office 365 (Microsoft Entra ID) in ThGERP

Ziel: Mitarbeiter melden sich im Portal (App 20000) mit ihrem Office-365-Konto an. Benutzername/Kennwort
(APEX-Konten) bleibt als Notzugang. Intern arbeitet ThGERP weiter mit dem bisherigen Benutzernamen
(`ALLG_MITARBEITER.MITA_BENUTZERNAME`, z. B. `ADMIN_THG`) – Mandant, Theme-Stil, Einstellungen und
Audit-Spalten bleiben unverändert.

Vorbild: Projekt Marchler (Portal 10000), allgemeine Beschreibung in der Wissensdatenbank
`apex/anmeldung-microsoft-entra-id.md`.

| Wer | Teil |
|---|---|
| Thomas (Entra-Administrator) | A – App-Registrierung in Entra, geheimer Schlüssel |
| Claude (nach Freigabe) | B – Datenbank und APEX |
| Thomas | C – Test |

---

## A – Entra: App-Registrierung (Thomas)

Im Entra Admin Center (<https://entra.microsoft.com>) mit einem Administrator des Tenants **thg-edv.com**:

1. **Identität > Anwendungen > App-Registrierungen > Neue Registrierung**
   - Name: `ThGERP`
   - Unterstützte Kontotypen: **Nur Konten in diesem Organisationsverzeichnis** (Single Tenant)
   - Umleitungs-URI: Plattform **Web**, `https://erp.thg-edv.com/ords/apex_authentication.callback`
2. Auf der Übersichtsseite notieren (für Teil B an Claude weitergeben – beides ist nicht geheim):
   - **Anwendungs-ID (Client)**
   - **Verzeichnis-ID (Mandant)** = Tenant-ID
3. **Zertifikate & Geheimnisse > Neuer geheimer Clientschlüssel**
   - Beschreibung `ThGERP APEX`, Ablauf 24 Monate
   - Den **Wert** sofort kopieren (wird nur einmal angezeigt) – **nicht** per Chat, Mail oder in Dateien weitergeben,
     er wird in Teil B von Thomas selbst in APEX eingetragen.
   - Ablaufdatum im Kalender eintragen (siehe Teil D).
4. **API-Berechtigungen**: Microsoft Graph, delegiert: `openid`, `profile`, `email` (und `User.Read`, ist
   voreingestellt) → **Administratorzustimmung erteilen**.
   - Später für den Rechnungsversand per E-Mail (Status „Offen – gesendet“): Anwendungsberechtigung `Mail.Send`.
     Jetzt noch nicht nötig.
5. **Benutzer**: Alle Mitarbeiter mit Konto im Tenant thg-edv.com können sich anmelden. Mitarbeiter mit einer Adresse
   aus einem anderen Tenant (z. B. einer eigenen Domain der Holding) als **Gast** einladen
   (Benutzer > Neuer Benutzer > Externen Benutzer einladen) – die App bleibt Single Tenant.

---

## B – Datenbank und APEX (Claude, nach Freigabe)

1. **Netzwerkfreigabe prüfen.** Seit dem Upgrade auf APEX 26.2 (29.10.2026) ruft das Schema `APEX_260200` die
   Microsoft-Adressen auf. Prüfen, dass es eine ACL für `login.microsoftonline.com` (und für den späteren Mailversand
   `graph.microsoft.com`) Port 443 hat; sonst als SYS ergänzen (`dbms_network_acl_admin.append_host_ace`).
   Test: `apex_web_service.make_rest_request('https://login.microsoftonline.com/<Tenant-ID>/v2.0/.well-known/openid-configuration', 'GET')`
   muss HTTP 200 liefern.
2. **DDL 47 – E-Mail-Adresse des Mitarbeiters.** `ALLG_MITARBEITER` hat noch keine Adress-Spalte:
   neue Spalte `MITA_EMAIL` (eindeutig, per Trigger in Kleinbuchstaben). Pflege in THG-ADMIN bei den Mitarbeitern,
   Anzeige in den Einstellungen (Portal Seite 20). Danach für jeden Mitarbeiter die Office-365-Adresse eintragen
   (Thomas: `thomas@thg-edv.com` → Benutzer `ADMIN_THG`).
3. **Web Credential** im Workspace THGERP: Static ID `entra-thgerp`, Typ „OAuth2 Client Credentials“, Client-ID aus
   A.2. Quelle `Apex/thg-portal/workspace-components/credentials/entra-thgerp.apx` (ohne Schlüssel).
   **Thomas** trägt danach den geheimen Schlüssel ein: App Builder > Workspace Utilities > Web Credentials >
   „Entra ThGERP“ > Client Secret.
4. **Authentifizierungsschema** „Microsoft Entra ID“ im Portal 20000 – **nicht** als aktuelles Schema
   (APEX-Konten bleiben aktuell und damit Notzugang):
   - Social Sign-In, Anbieter OpenID Connect, Discovery-URL
     `https://login.microsoftonline.com/<Tenant-ID>/v2.0/.well-known/openid-configuration`
   - Scope `profile,email`, Benutzername `preferred_username`, „Switch in Session“ = Ja, Session Sharing Workspace
   - Prozedur `nach_anmeldung` (nach der Anmeldung): Mitarbeiter mit `MITA_EMAIL = lower(:APP_USER)` suchen und mit
     `apex_custom_auth.set_user` auf seinen `MITA_BENUTZERNAME` umstellen; ohne Treffer Meldung „Für … ist kein
     Mitarbeiter eingetragen“.
5. **Anmeldeseite** des Portals (Seite 9999): Button „Mit Microsoft anmelden“ → Request
   `APEX_AUTHENTICATION=Microsoft Entra ID` (der **Name** des Schemas, nicht die Static ID).
6. **Sub-Apps** (20010, 20020, 20030, 20050): Login-URL auf die Portal-Anmeldung umstellen (`f?p=20000:LOGIN:&SESSION.`,
   wie `anmeldung_ueber_portal.py` im Projekt Marchler). Sonst landet man bei einem Direktaufruf ohne Sitzung auf der
   Anmeldeseite der Sub-App, die nur Benutzername/Kennwort kennt. Mit Session Sharing gilt die Anmeldung im Portal
   ohnehin in allen Apps.
7. Einspielen: Portal, dann Sub-Apps einzeln, Subscriptions aktualisieren; CLAUDE.md nachtragen.

---

## C – Test (Thomas)

Immer in einem **privaten Fenster** (mit einer bestehenden Sitzung übernimmt APEX diese, und der Microsoft-Weg ist
nicht zu sehen).

1. `https://erp.thg-edv.com/ords/r/thgerp/thg-portal/login` → „Mit Microsoft anmelden“ → Microsoft-Anmeldung
   mit `thomas@thg-edv.com` (beim ersten Mal Zustimmung bestätigen).
2. Erwartet: Portal-Startseite, rechts oben `ADMIN_THG`, Standard-Mandant und gespeicherter Stil sind gesetzt.
3. In eine Sub-App wechseln (z. B. Finanz) – keine erneute Anmeldung.
4. Gegenprobe: Anmeldung mit Benutzername/Kennwort funktioniert weiter (Notzugang).
5. Gegenprobe: Ein Microsoft-Konto ohne eingetragene Adresse beim Mitarbeiter wird mit Meldung abgelehnt.

Fehlerbilder:

| Meldung | Ursache |
|---|---|
| Microsoft: AADSTS50011 (Redirect URI mismatch) | Umleitungs-URI in A.1 weicht ab (https, `/ords/`, kein Schrägstrich am Ende) |
| Microsoft: AADSTS7000215 (invalid client secret) | Schlüssel falsch eingetragen oder abgelaufen (B.3 / D) |
| ORA-24247 / ORA-29273 in APEX | Netzwerkfreigabe fehlt (B.1) |
| Wieder auf der Anmeldeseite | Request mit Static ID statt Name des Schemas (B.5) |
| „Für … ist kein Mitarbeiter eingetragen“ | `MITA_EMAIL` fehlt oder andere Schreibweise (B.2) |

---

## D – Betrieb

- **Schlüssel läuft ab** (24 Monate): rechtzeitig in Entra einen neuen geheimen Schlüssel anlegen, in APEX beim Web
  Credential eintragen, alten Schlüssel danach in Entra löschen. Ohne gültigen Schlüssel geht nur noch der Notzugang.
- **Neuer Mitarbeiter:** Konto im Tenant (bzw. Gast-Einladung), in THG-ADMIN Mitarbeiter mit Benutzername und
  Office-365-Adresse anlegen.
- **Mitarbeiter scheidet aus:** Konto in Entra sperren – damit ist auch die Anmeldung in ThGERP gesperrt; den
  APEX-Konto-Zugang (falls vorhanden) zusätzlich sperren.
- **Schlüssel sichtbar geworden** (Chat, Mail, Datei): sofort in Entra einen neuen erzeugen und den alten löschen.

Stand: 2026-10-29, APEX 26.2. Teil A und B erledigt (App-Registrierung „ThG-Portal“, Client-ID `3c1fabc9-d2e8-40cb-b452-05c4a63813e7`, Tenant `c93caac8-248c-440d-afb2-3777aed55fe9`); offen: Test C mit Microsoft-Konto.
