# ER-Modell aus Mermaid erzeugen

## Quellen
- `Datenbank/db/er-modell/kundenstamm_er_modell.mmd`
- `Datenbank/db/er-modell/artikel_fakturierung_er_modell.mmd` (generiert aus `ddl/generator/gen_19_20_…`)

## Vorgehen
1. Nach Modelländerung die `.mmd` anpassen (bzw. neu generieren).
2. Im Ordner `er-modell`: `python3 build_er_modell.py` → erzeugt PDF, SVG, PNG, HTML.


## Quelle / Stand

Aus der Projektarbeit ThGERP, Stand 2026-09-26.

## Technik und Stolpersteine (ergänzt 2026-09-26)
- `build_er_modell.py` setzt Titel, Legende, Modellquelle (`const SRC`) in die HTML-Vorlage
  `kundenstamm_er_modell.html` (Mermaid eingebettet, Gruppenfarben KUND/ALLG/ADMIN/ARTI/FAKT) und ruft
  `render_er_modell.cjs` (Puppeteer) für SVG, PNG und PDF auf.
- Puppeteer kommt aus dem npx-Cache von Mermaid-CLI; fehlt er: einmal `npx -y @mermaid-js/mermaid-cli --version`.
- Chrome direkt (`--headless=new --virtual-time-budget --dump-dom`) blieb hängen – nicht verwenden.
- Ohne passende Fensterbreite schneidet `#erd {overflow:auto}` das Diagramm auf 800 px ab; das Skript
  setzt die Breite auf die SVG-Breite.
- Neue Modelle aus Generator-Definitionen: `ddl_gen.mermaid()` erzeugt die `.mmd` direkt aus den Tabellen
  (FK-Beziehungen aus den R-Constraints) – Modell und DDL können nicht auseinanderlaufen.
