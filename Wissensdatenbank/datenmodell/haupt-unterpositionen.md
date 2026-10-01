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
  (`FAKT_RECHNUNG.naechste_position(rech_id, haupt_rpos_id)`). Die Nummern gibt niemand ein: neue Positionen kommen
  ans Ende, nach Verschieben (Drag & Drop im Baum) und Löschen nummeriert die App die Ebene lückenlos neu – der
  Ausdruck verwendet die gespeicherten Nummern.
- `FAKT_RECHNUNG.summen_berechnen` trägt `RPOS_SUMME_UNTERPOS` nach (nur geänderte Zeilen, sonst zählt jede Berechnung
  `ROW_VERSION` hoch), der Trigger rechnet daraus die Summe der Hauptposition – ein Zeilentrigger darf die eigene
  Tabelle nicht lesen (mutating table), deshalb liegt die Summe der Unterpositionen als Spalte vor.
- Rechnungssumme = Summe der nicht optionalen Hauptpositionen. `FAKT_RECHNUNG_MWST_V` verteilt Rabatt/Pauschale anteilig
  auf die Steuersätze der Unterpositionen (Faktor = Summe Hauptposition / Summe Unterpositionen).
- Ausdruck: Hauptposition als Überschrift, Unterpositionen als `1.10`, `1.20`, danach Zwischensumme; bei Pauschale
  Unterpositionen ohne Preise.

## Hauptposition ohne eigenen Preis (ergänzt 2026-10-01)
- In Maske und Ausdruck hat eine Hauptposition keinen Einzelpreis, keine Menge/Einheit und keinen Steuersatz: ihr Betrag
  ist die Summe der Unterpositionen (abzgl. Rabatt) oder die Pauschalsumme. Die App speichert Hauptpositionen mit
  Menge 1 und Einzelpreis 0; der Steuersatz bleibt in der Spalte (Standardsatz) und gilt nur, wenn eine Pauschale ohne
  verteilbare Unterpositionen steht.
- Tabelle und Trigger sind unverändert (`RPOS_SUMME` fällt ohne Unterpositionen weiter auf Menge × Einzelpreis zurück).
  Das nutzt der Übergang: Eine Hauptposition, die noch so rechnet (Altbestand, oder eine Unterposition wurde per
  Drag & Drop zur Hauptposition), bekommt ihren Betrag beim Laden als Pauschalsumme **angeboten** und beim Speichern so
  übernommen. Umgekehrt nimmt eine Hauptposition mit Pauschale den Betrag als Menge 1 × Einzelpreis mit, wenn sie zur
  Unterposition wird (`POS_VERSCHIEBEN`) – beim Hin- und Herziehen geht kein Betrag verloren.

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
