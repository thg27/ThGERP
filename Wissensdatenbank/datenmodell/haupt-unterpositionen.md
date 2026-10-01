# Haupt- und Unterpositionen der Rechnung

## Kontext
Rechnungspositionen waren flach mit einem Textfeld „Kapitel“. Gewünscht: Hauptpositionen mit Unterpositionen,
Zwischensumme je Hauptposition, Rabatt auf die Hauptposition und eine Pauschalsumme, die die Zwischensumme ersetzt.

## Lösung
Eine Tabelle (`FAKT_RECHNUNGSPOSITIONEN`), weil Haupt- und Unterposition gleich aufgebaut sind (Skript `26_haupt_unterpositionen.sql`):

| Spalte | Bedeutung |
|---|---|
| `RPOS_HAUPT_RPOS_ID` | Selbstreferenz (`on delete cascade`); leer = Hauptposition. Nur zwei Ebenen. |
| `RPOS_SUMME_UNTERPOS` | Hauptposition: Summe der nicht optionalen Unterpositionen; **leer = keine Unterpositionen** |
| `RPOS_PAUSCHALSUMME` | Hauptposition: gilt statt der berechneten Zwischensumme |
| `RPOS_SUMME` | Trigger `RPOS_BIU`: `coalesce(Pauschale, round(coalesce(Summe Unterpos., Menge × Einzelpreis) × (1 − Rabatt/100), 2))` |

- `RPOS_UK` = (Rechnung, Hauptposition, Position): Hauptpositionen 1, 2, 3 …, Unterpositionen je Hauptposition 10, 20, 30 …
  (`FAKT_RECHNUNG.naechste_position(rech_id, haupt_rpos_id)`).
- `FAKT_RECHNUNG.summen_berechnen` trägt `RPOS_SUMME_UNTERPOS` nach (nur geänderte Zeilen, sonst zählt jede Berechnung
  `ROW_VERSION` hoch), der Trigger rechnet daraus die Summe der Hauptposition – ein Zeilentrigger darf die eigene
  Tabelle nicht lesen (mutating table), deshalb liegt die Summe der Unterpositionen als Spalte vor.
- Rechnungssumme = Summe der nicht optionalen Hauptpositionen. `FAKT_RECHNUNG_MWST_V` verteilt Rabatt/Pauschale anteilig
  auf die Steuersätze der Unterpositionen (Faktor = Summe Hauptposition / Summe Unterpositionen).
- Ausdruck: Hauptposition als Überschrift, Unterpositionen als `1.10`, `1.20`, danach Zwischensumme; bei Pauschale
  Unterpositionen ohne Preise.

## Stolpersteine
- Unique-Constraint mit NULL: `(Rechnung, NULL, 1)` zweimal gilt in Oracle als gleich, wenn die übrigen Spalten gleich
  sind – die Hauptpositionen sind also auch ohne Hauptverweis eindeutig nummeriert.
- Mehrere Steuersätze in einer Hauptposition mit Rabatt/Pauschale: je Steuersatz wird gerundet, die Netto-Summe kann um
  einen Cent von der Zwischensumme abweichen.
- Dass eine Unterposition an einer Hauptposition **derselben** Rechnung hängt, prüft `summen_berechnen` (ORA-20213),
  nicht ein Constraint.
- Bei einer Neuinstallation entfällt Skript 25 (Kapitel): `20_fakturierung.sql` legt schon die neue Struktur an.

## Quelle / Stand
2026-10-01, Oracle 26ai, App THG-FINANZ (20050) Seite 11.
