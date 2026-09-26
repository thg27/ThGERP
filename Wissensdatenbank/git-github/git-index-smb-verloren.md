# Git-Index auf dem SMB-Laufwerk verloren

## Kontext
Das Repository liegt auf der SMB-Freigabe `/Volumes/ThG_edv`. Nach einem Commit bzw. einem automatischen
`git fetch` (VS Code) zeigte `git status` **alle** Dateien als gelöscht vorgemerkt (`D `) und gleichzeitig als
nicht versioniert (`??`). Die Dateien auf dem Laufwerk und der letzte Commit waren vollständig.

## Ursache
`.git/index` fehlte. Git schreibt den Index in eine Temp-Datei und benennt sie um; auf SMB bleiben dabei
Reste wie `.git/.smbdeleteAAA….4` zurück und die Umbenennung kann fehlschlagen.

## Lösung
```sh
git ls-files | wc -l   # 0 = Index leer
git reset -q           # Index aus HEAD neu aufbauen, Arbeitsdateien bleiben unverändert
git status --short     # jetzt nur echte Änderungen
```
**Nicht** `git add -A` / committen, solange der Index leer ist – das würde alle Dateien löschen.

## Stolpersteine
- Vor jedem Commit kurz `git status --short` prüfen: massenhaft `D ` = Index kaputt.
- `.smbdelete*`-Dateien im `.git`-Ordner sind Reste des Netzlaufwerks und harmlos.

## Quelle / Stand
Aufgetreten 2026-09-26 (nach Commit d16869f), behoben mit `git reset`.
