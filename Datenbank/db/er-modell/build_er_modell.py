#!/usr/bin/env python3
"""Erzeugt HTML, SVG, PNG und PDF der ER-Modelle aus ihren .mmd-Quellen.

Vorlage ist kundenstamm_er_modell.html (Mermaid eingebettet, Gruppenfarben, Legende); je Modell werden
Titel, Legende, Modellquelle (const SRC) und Datum gesetzt. render_er_modell.cjs (Puppeteer) erzeugt
daraus SVG (gerendertes Diagramm), PNG (Screenshot) und PDF.

Aufruf: python3 build_er_modell.py [modell ...]   (ohne Angabe: alle Modelle)
"""
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

HIER = Path(__file__).resolve().parent
VORLAGE = HIER / "kundenstamm_er_modell.html"

GRUPPEN = {
    "KUND": ("#9FE1CB", "#0F6E56", "Kundenstammdaten"),
    "ALLG": ("#CECBF6", "#534AB7", "Allgemeine Stammdaten"),
    "ADMIN": ("#FAC775", "#854F0B", "Administration"),
    "ARTI": ("#F5C4B3", "#993C1D", "Artikelstamm"),
    "FAKT": ("#B5D4F4", "#185FA5", "Fakturierung"),
}
MODELLE = {
    "kundenstamm_er_modell": ("Kundenstamm ER-Modell", "Kundenstamm-Datenmodell", ["KUND", "ALLG", "ADMIN"]),
    "artikel_fakturierung_er_modell": ("Artikel/Fakturierung ER-Modell", "Artikelstamm und Fakturierung",
                                       ["ARTI", "FAKT", "ALLG", "ADMIN", "KUND"]),
}


def bauen(name):
    titel, ueberschrift, gruppen = MODELLE[name]
    html = VORLAGE.read_text(encoding="utf-8")
    src = (HIER / f"{name}.mmd").read_text(encoding="utf-8")
    legende = "\n".join(f' <span><i class="sw" style="background:{GRUPPEN[g][0]};border-color:{GRUPPEN[g][1]}"></i>'
                        f"{g} – {GRUPPEN[g][2]}</span>" for g in gruppen)
    html = re.sub(r"<title>.*?</title>", f"<title>{titel}</title>", html, count=1)
    html = re.sub(r"<h1>.*?</h1>", f"<h1>{ueberschrift}</h1>", html, count=1)
    html = re.sub(r'<div class="lg">.*?</div>', f'<div class="lg">\n{legende}\n</div>', html, count=1, flags=re.S)
    html, n = re.subn(r'const SRC = ".*?";\n', lambda _: f"const SRC = {json.dumps(src, ensure_ascii=False)};\n",
                      html, count=1, flags=re.S)
    assert n == 1, "const SRC nicht gefunden"
    html = re.sub(r"Stand: \d{4}-\d{2}-\d{2}", f"Stand: {date.today():%Y-%m-%d}", html, count=1)
    (HIER / f"{name}.html").write_text(html, encoding="utf-8")

    # SVG, PNG, PDF mit Puppeteer (aus dem npx-Cache von @mermaid-js/mermaid-cli)
    cache = next(Path.home().glob(".npm/_npx/*/node_modules/puppeteer"), None)
    assert cache, "Puppeteer fehlt: einmal 'npx -y @mermaid-js/mermaid-cli --version' ausfuehren"
    subprocess.run(["node", str(HIER / "render_er_modell.cjs"), name], check=True,
                   env={**os.environ, "NODE_PATH": str(cache.parent)})


for modell in sys.argv[1:] or MODELLE:
    bauen(modell)
