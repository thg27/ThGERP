#!/usr/bin/env python3
"""Erzeugt HTML, SVG, PNG und PDF des ER-Modells aus der Quelle kundenstamm_er_modell.mmd.

Die HTML-Datei enthaelt Mermaid (eingebettet), die Gruppenfarben und die Modellquelle (const SRC);
dieses Skript ersetzt nur SRC und das Datum; render_er_modell.cjs (Puppeteer) erzeugt daraus
SVG (gerendertes Diagramm), PNG (Screenshot) und PDF.

Aufruf: python3 build_er_modell.py
"""
import json
import os
import re
import subprocess
from datetime import date
from pathlib import Path

HIER = Path(__file__).resolve().parent
NAME = "kundenstamm_er_modell"

html_datei = HIER / f"{NAME}.html"
html = html_datei.read_text(encoding="utf-8")
src = (HIER / f"{NAME}.mmd").read_text(encoding="utf-8")

# Modellquelle und Stand ersetzen
html, n = re.subn(r'const SRC = ".*?";\n', lambda _: f"const SRC = {json.dumps(src, ensure_ascii=False)};\n",
                  html, count=1, flags=re.S)
assert n == 1, "const SRC nicht gefunden"
html = re.sub(r"Stand: \d{4}-\d{2}-\d{2}", f"Stand: {date.today():%Y-%m-%d}", html, count=1)
html_datei.write_text(html, encoding="utf-8")


# SVG, PNG, PDF mit Puppeteer (aus dem npx-Cache von @mermaid-js/mermaid-cli)
cache = next(Path.home().glob(".npm/_npx/*/node_modules/puppeteer"), None)
assert cache, "Puppeteer fehlt: einmal 'npx -y @mermaid-js/mermaid-cli --version' ausfuehren"
subprocess.run(["node", str(HIER / "render_er_modell.cjs")], check=True,
               env={**os.environ, "NODE_PATH": str(cache.parent)})
