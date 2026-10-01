# SQLcl-MCP-Server startet nicht nach Update der VS-Code-Erweiterung

## Kontext
Claude Code meldet für den MCP-Server `sqlcl`:
`ENOENT: no such file or directory, posix_spawn '…/oracle.sql-developer-26.2.1-darwin-arm64/dbtools/sqlcl/bin/sql'`.
Die MCP-Werkzeuge (`sql_run`, `sqlcl_run` …) fehlen dann in der Sitzung.

## Ursache
Der MCP-Server ist in `~/.claude.json` mit dem **versionsabhängigen** Pfad der VS-Code-Erweiterung „Oracle SQL
Developer“ eingetragen. Nach einem Update der Erweiterung heißt der Ordner anders
(2026-10-01: `oracle.sql-developer-26.3.0-darwin-arm64`), der alte Pfad existiert nicht mehr.

## Lösung
- Aktuellen Pfad feststellen: `ls -d ~/.vscode/extensions/oracle.sql-developer-*`
- In `~/.claude.json` beim MCP-Server `sqlcl` unter `command` den neuen Pfad eintragen und Claude Code neu starten.
- Übergangsweise SQLcl direkt in der Shell mit der gespeicherten Verbindung aufrufen:
  `~/.vscode/extensions/oracle.sql-developer-<version>-darwin-arm64/dbtools/sqlcl/bin/sql -S -name "wksp_thgerp@pdbthg"`
  (gespeicherte Verbindungen: `connmgr list` in `sql /nolog`).

## Stolpersteine
- `ORA-12170 … TCP connect-Timeout … dbthgprod.thg-edv.com port 1521` trotz richtigem Pfad: der Datenbankserver ist
  vom Rechner aus nicht erreichbar (Netz prüfen: `nc -vz -G 8 dbthgprod.thg-edv.com 1521`).

## Quelle / Stand
2026-10-01, SQLcl aus der VS-Code-Erweiterung Oracle SQL Developer 26.3.0.
