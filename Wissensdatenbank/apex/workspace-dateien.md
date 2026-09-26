# Gemeinsame Workspace-Dateien (CSS, Logo)

## Kontext
`thg.css` und `thg-logo.svg` liegen in `Apex/workspace-files/` und werden von allen Apps als Workspace-Dateien genutzt.

## Vorgehen
1. Datei in `Apex/workspace-files/` ändern.
2. `python3 build_install.py` ausführen → erzeugt `install_workspace_files.sql`.
3. `install_workspace_files.sql` per SQLcl einspielen.

Ein App-Import ist **nicht** nötig.

## Stolpersteine
- Browser-Cache: nach dem Einspielen Hard-Reload, sonst wird die alte CSS angezeigt.


## Quelle / Stand

Aus der Projektarbeit ThGERP, Stand 2026-09-26.
