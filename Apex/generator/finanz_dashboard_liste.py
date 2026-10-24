"""THG-FINANZ (20050): Seite 1 Dashboard und Seite 10 Rechnungsliste mit Facettensuche.

Aufbau wie im Kundenstamm (20020 Seiten 1/10) bzw. in der Finanz-App des Projekts Marchler: Dashboard mit
Kennzahlen-Karten (Klick oeffnet die gefilterte Liste), offenen Rechnungen und Diagrammen; Liste mit Facetten links.
Alle Werte nur fuer den im Portal gewaehlten Mandanten (:MANDANT_ID). Umsatz = Rechnungen OFFEN/BEZAHLT netto
(ohne Entwuerfe und stornierte). Wird von gen_finanz.py geschrieben.
"""

# Status wie in der Liste angezeigt (initcap) – auch Werte der Facette P10_STATUS
_STATUS_ICON = """case r.RECH_STATUS when 'ENTWURF' then 'fa-pencil u-warning-text'
                                          when 'OFFEN' then 'fa-clock-o u-info-text'
                                          when 'BEZAHLT' then 'fa-check-circle u-success-text'
                                          else 'fa-ban u-danger-text' end"""


def dashboard():
    return r"""page 1 (
    name: Dashboard
    alias: HOME
    title: Dashboard
    appearance {
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }
    navigation {
        cursorFocus: doNotFocusCursor
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }
    help {
        helpText:
            ```html
            <p>Dashboard der Ausgangsrechnungen des im Portal gewählten Mandanten: Kennzahlen, offene Rechnungen, Umsatz je Monat und Top-Kunden. Ein Klick auf eine Karte oder ein Diagramm öffnet die gefilterte Rechnungsliste.</p>
            ```
    }

    region kennzahlen (
        name: Kennzahlen
        type: themeTemplateComponent/metricCard
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                -- Rechnungen des im Portal gewaehlten Mandanten; Umsatz = OFFEN/BEZAHLT netto (ohne Entwuerfe, stornierte)
                with r as (
                    select RECH_STATUS, RECH_DATUM, RECH_SUMME_NETTO, OFFEN, IST_UEBERFAELLIG
                      from FAKT_RECHNUNGEN_V
                     where RECH_MAND_ID = :MANDANT_ID
                ), u as (
                    select * from r where RECH_STATUS in ('OFFEN', 'BEZAHLT')
                )
                select 1 as ID, 'Umsatz ' || to_char(sysdate, 'YYYY') as TITLE,
                       to_char((select nvl(sum(RECH_SUMME_NETTO), 0) from u where RECH_DATUM >= trunc(sysdate, 'YYYY')),
                               'FM999G999G990', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €' as METRIC,
                       to_char((select nvl(sum(RECH_SUMME_NETTO), 0) from u
                                 where RECH_DATUM >= add_months(trunc(sysdate, 'YYYY'), -12)
                                   and RECH_DATUM < add_months(trunc(sysdate), -12) + 1),
                               'FM999G999G990', 'NLS_NUMERIC_CHARACTERS='',.''') || ' € im Vorjahr bis heute' as META,
                       apex_page.get_url(p_page => 10, p_clear_cache => 10, p_items => 'P10_JAHR', p_values => to_char(sysdate, 'YYYY')) as LINK
                  from dual
                union all
                select 2, 'Rechnungen ' || to_char(sysdate, 'YYYY'),
                       to_char((select count(*) from u where RECH_DATUM >= trunc(sysdate, 'YYYY')), 'FM999G999'),
                       to_char((select count(*) from u
                                 where RECH_DATUM >= add_months(trunc(sysdate, 'YYYY'), -12)
                                   and RECH_DATUM < trunc(sysdate, 'YYYY')), 'FM999G999') || ' im Vorjahr',
                       apex_page.get_url(p_page => 10, p_clear_cache => 10, p_items => 'P10_JAHR', p_values => to_char(sysdate, 'YYYY'))
                  from dual
                union all
                select 3, 'Offene Rechnungen',
                       to_char((select nvl(sum(OFFEN), 0) from r where RECH_STATUS = 'OFFEN'),
                               'FM999G999G990', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €',
                       to_char((select count(*) from r where RECH_STATUS = 'OFFEN'), 'FM999G999') || ' Rechnungen',
                       apex_page.get_url(p_page => 10, p_clear_cache => 10, p_items => 'P10_STATUS', p_values => 'Offen')
                  from dual
                union all
                select 4, 'Überfällig',
                       to_char((select nvl(sum(OFFEN), 0) from r where RECH_STATUS = 'OFFEN' and IST_UEBERFAELLIG = 'Y'),
                               'FM999G999G990', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €',
                       to_char((select count(*) from r where RECH_STATUS = 'OFFEN' and IST_UEBERFAELLIG = 'Y'), 'FM999G999') || ' Rechnungen',
                       apex_page.get_url(p_page => 10, p_clear_cache => 10, p_items => 'P10_UEBERFAELLIG', p_values => 'Ja')
                  from dual
                union all
                select 5, 'Entwürfe',
                       to_char((select count(*) from r where RECH_STATUS = 'ENTWURF'), 'FM999G999'),
                       'noch nicht abgeschlossen',
                       apex_page.get_url(p_page => 10, p_clear_cache => 10, p_items => 'P10_STATUS', p_values => 'Entwurf')
                  from dual
                ```
        }
        layout {
            sequence: 20
            slot: body
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
        advanced {
            htmlDomId: kennzahlen
        }
        componentAppearance {
            display: report
        }
        settings {
            title: &TITLE.
            metric: &METRIC.
            meta: &META.
            layout: 5Columns
        }

        column ID (
            layout {
                sequence: 10
            }
            source {
                databaseColumn: ID
                dataType: number
                primaryKey: true
            }
        )

        column TITLE (
            layout {
                sequence: 20
            }
            source {
                databaseColumn: TITLE
                dataType: varchar2
            }
        )

        column METRIC (
            layout {
                sequence: 30
            }
            source {
                databaseColumn: METRIC
                dataType: varchar2
            }
        )

        column META (
            layout {
                sequence: 40
            }
            source {
                databaseColumn: META
                dataType: varchar2
            }
        )

        column LINK (
            layout {
                sequence: 50
            }
            source {
                databaseColumn: LINK
                dataType: varchar2
            }
        )

        action karte-oeffnen (
            position: link
            layout {
                sequence: 10
            }
            behavior {
                type: redirectUrl
                targetUrl: &LINK.
            }
        )
    )

    region offene-rechnungen (
        name: Offene Rechnungen
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select r.RECH_ID,
                       r.RECH_NUMMER,
                       r.RECH_DATUM,
                       r.RECH_FAELLIG_AM,
                       case when r.IST_UEBERFAELLIG = 'Y' then 'UEBERFAELLIG'
                            when r.RECH_FAELLIG_AM <= trunc(sysdate) + 7 then 'FAELLIG'
                            else 'OFFEN' end as HINWEIS_CODE,
                       case when r.IST_UEBERFAELLIG = 'Y' then 'überfällig'
                            when r.RECH_FAELLIG_AM <= trunc(sysdate) + 7 then 'fällig in 7 Tagen'
                            else 'offen' end as HINWEIS,
                       r.KUNDE,
                       r.RECH_BETREFF,
                       r.OFFEN,
                       -- Kunde im Kundenstamm (20020 Seite 11, mit Pruefsumme)
                       apex_page.get_url(p_application => '20020', p_page => 11, p_clear_cache => 11,
                                         p_items => 'P11_KUND_ID', p_values => r.RECH_KUND_ID) as KUND_URL
                  from FAKT_RECHNUNGEN_V r
                 where r.RECH_MAND_ID = :MANDANT_ID
                   and r.RECH_STATUS = 'OFFEN'
                 order by r.RECH_FAELLIG_AM nulls last, r.RECH_NUMMER
                ```
        }
        layout {
            sequence: 25
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: #DEFAULT#
        }
        advanced {
            htmlDomId: offene-rechnungen
        }
        componentAppearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Report--stretch
                t-Report--staticRowColors
                t-Report--rowHighlight
                t-Report--horizontalBorders
            ]
        }
        pagination {
            type: rowRangesXToYOfZWithPagination
        }
        reportLayout {
            numberOfRowsType: staticValue
            numberOfRows: 10
        }
        messages {
            whenNoDataFound: Keine offenen Rechnungen.
        }

        column RECH_ID (
            type: hidden
            layout {
                sequence: 10
            }
        )

        column RECH_NUMMER (
            type: link
            heading {
                heading: Rechnung
            }
            layout {
                sequence: 20
            }
            link {
                target: {
                    page: 11
                    items: {
                        P11_RECH_ID: #RECH_ID#
                    }
                    clearCache: 11
                }
                linkText: <span class="thg-kundennr">#RECH_NUMMER#</span>
            }
            sorting {
                sortable: false
            }
        )

        column RECH_DATUM (
            type: plainText
            heading {
                heading: Datum
            }
            appearance {
                formatMask: DD.MM.YYYY
            }
            layout {
                sequence: 30
            }
            sorting {
                sortable: false
            }
        )

        column KUNDE (
            type: plainText
            heading {
                heading: Kunde
            }
            columnFormatting {
                htmlExpression: <a href="#KUND_URL#" title="Kunde öffnen">#KUNDE#</a>
            }
            layout {
                sequence: 40
            }
            sorting {
                sortable: false
            }
        )

        column RECH_BETREFF (
            type: plainText
            heading {
                heading: Betreff
            }
            layout {
                sequence: 50
            }
            sorting {
                sortable: false
            }
        )

        column RECH_FAELLIG_AM (
            type: plainText
            heading {
                heading: Fällig am
            }
            appearance {
                formatMask: DD.MM.YYYY
            }
            layout {
                sequence: 60
            }
            sorting {
                sortable: false
            }
        )

        column HINWEIS (
            type: plainText
            heading {
                heading: Hinweis
            }
            columnFormatting {
                htmlExpression: <span class="thg-badge thg-badge--#HINWEIS_CODE#">#HINWEIS#</span>
            }
            layout {
                sequence: 70
            }
            sorting {
                sortable: false
            }
        )

        column HINWEIS_CODE (
            type: hidden
            layout {
                sequence: 75
            }
        )

        column OFFEN (
            type: plainText
            heading {
                heading: Offen
                alignment: end
            }
            appearance {
                formatMask: FML999G999G990D00
            }
            layout {
                sequence: 80
                columnAlignment: end
            }
            sorting {
                sortable: false
            }
        )

        column KUND_URL (
            type: hidden
            layout {
                sequence: 95
            }
        )

    )

    region umsatz-je-monat (
        name: Umsatz je Monat (netto)
        type: chart
        layout {
            sequence: 30
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: #DEFAULT#
        }
        chart {
            type: bar
        }
        legend {
            show: true
        }

        series umsatz (
            name: Umsatz
            execution {
                sequence: 10
            }
            source {
                type: sqlQuery
                sqlQuery:
                    ```sql
                    -- letzte 12 Monate inkl. Monate ohne Rechnung (Mandant der Sitzung, ohne Entwuerfe/stornierte)
                    select to_char(m.monat, 'YYYY-MM') as LABEL,
                           nvl(sum(r.RECH_SUMME_NETTO), 0) as VALUE,
                           to_char(m.monat, 'MM/YYYY') || ': '
                           || to_char(nvl(sum(r.RECH_SUMME_NETTO), 0), 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €' as TOOLTIP
                      from (select add_months(trunc(sysdate, 'MM'), -level + 1) as monat
                              from dual connect by level <= 12) m
                      left join FAKT_RECHNUNGEN r
                        on r.RECH_MAND_ID = :MANDANT_ID
                       and r.RECH_STATUS in ('OFFEN', 'BEZAHLT')
                       and r.RECH_DATUM >= m.monat
                       and r.RECH_DATUM < add_months(m.monat, 1)
                     group by m.monat
                     order by m.monat
                    ```
            }
            link {
                type: redirectThisApp
                target: {
                    page: 10
                    items: {
                        P10_MONAT: &LABEL.
                    }
                    clearCache: 10
                }
            }
            columnMapping {
                label: LABEL
                value: VALUE
                customTooltip: TOOLTIP
            }
        )

        series vorjahr (
            name: Vorjahr
            execution {
                sequence: 20
            }
            source {
                type: sqlQuery
                sqlQuery:
                    ```sql
                    -- Vorjahresmonat auf derselben Kategorie (Monat des aktuellen Zeitraums)
                    select to_char(m.monat, 'YYYY-MM') as LABEL,
                           nvl(sum(r.RECH_SUMME_NETTO), 0) as VALUE,
                           'Vorjahr ' || to_char(add_months(m.monat, -12), 'MM/YYYY') || ': '
                           || to_char(nvl(sum(r.RECH_SUMME_NETTO), 0), 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €' as TOOLTIP
                      from (select add_months(trunc(sysdate, 'MM'), -level + 1) as monat
                              from dual connect by level <= 12) m
                      left join FAKT_RECHNUNGEN r
                        on r.RECH_MAND_ID = :MANDANT_ID
                       and r.RECH_STATUS in ('OFFEN', 'BEZAHLT')
                       and r.RECH_DATUM >= add_months(m.monat, -12)
                       and r.RECH_DATUM < add_months(m.monat, -11)
                     group by m.monat
                     order by m.monat
                    ```
            }
            columnMapping {
                label: LABEL
                value: VALUE
                customTooltip: TOOLTIP
            }
        )

        axis x (
            name: x
            value {
            }
            majorTicks {
                show: false
            }
        )

        axis y (
            name: y
            value {
                format: decimal
                decimalPlaces: 0
                formatScaling: none
            }
            majorTicks {
                show: true
            }
        )
    )

    region top-kunden (
        name: Top 10 Kunden (Umsatz letzte 12 Monate)
        type: chart
        layout {
            sequence: 40
            slot: body
            startNewRow: false
        }
        appearance {
            template: @/standard
            templateOptions: #DEFAULT#
        }
        chart {
            type: bar
        }
        legend {
            show: false
        }

        series kunden (
            name: Umsatz
            execution {
                sequence: 10
            }
            source {
                type: sqlQuery
                sqlQuery:
                    ```sql
                    -- LABEL = Kunde wie in der Rechnungsliste (Wert der Facette P10_KUNDE)
                    select KUNDE as LABEL,
                           sum(RECH_SUMME_NETTO) as VALUE,
                           KUND_NUMMER || ' – ' || KUNDE || ': '
                           || to_char(sum(RECH_SUMME_NETTO), 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS='',.''') || ' €' as TOOLTIP
                      from FAKT_RECHNUNGEN_V
                     where RECH_MAND_ID = :MANDANT_ID
                       and RECH_STATUS in ('OFFEN', 'BEZAHLT')
                       and RECH_DATUM >= add_months(trunc(sysdate), -12)
                     group by KUNDE, KUND_NUMMER
                     order by 2 desc
                     fetch first 10 rows only
                    ```
            }
            link {
                type: redirectThisApp
                target: {
                    page: 10
                    items: {
                        P10_KUNDE: &LABEL.
                    }
                    clearCache: 10
                }
            }
            columnMapping {
                label: LABEL
                value: VALUE
                customTooltip: TOOLTIP
            }
        )

        axis x (
            name: x
            value {
            }
            majorTicks {
                show: false
            }
        )

        axis y (
            name: y
            value {
                format: decimal
                decimalPlaces: 0
                formatScaling: none
            }
            majorTicks {
                show: true
            }
        )
    )

)
"""


def rechnungsliste():
    return r"""page 10 (
    name: Rechnungen
    alias: RECHNUNGEN
    title: Rechnungen
    appearance {
        pageTemplate: @/left-side-column
        templateOptions: #DEFAULT#
    }
    navigation {
        cursorFocus: doNotFocusCursor
    }
    security {
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }

    region breadcrumb (
        name: Breadcrumb
        title: Rechnungen
        type: breadcrumb
        source {
            breadcrumb: @breadcrumb
        }
        layout {
            sequence: 10
            slot: breadcrumbBar
        }
        appearance {
            template: @/title-bar
            templateOptions: [
                t-BreadcrumbRegion--useRegionTitle
            ]
        }
        componentAppearance {
            breadcrumbTemplate: @/breadcrumb
            templateOptions: #DEFAULT#
        }
    )

    region facets (
        name: Facetten
        type: facetedSearch
        source {
            filteredRegion: @rechnungen
        }
        layout {
            sequence: 20
            slot: leftColumn
        }
        appearance {
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }
        settings {
            compactNosThreshold: 10000
            displayChartForTopNValues: 10
        }

        facet P10_SEARCH (
            type: search
            label {
                label: Suche
            }
            layout {
                sequence: 10
            }
        )

        facet P10_STATUS (
            type: checkboxGroup
            label {
                label: Status
            }
            lov {
                type: distinctValues
            }
            layout {
                sequence: 20
            }
            listEntries {
                maxDisplayedEntries: 7
            }
            source {
                databaseColumn: STATUS
            }
        )

        facet P10_UEBERFAELLIG (
            type: checkboxGroup
            label {
                label: Überfällig
            }
            lov {
                type: distinctValues
            }
            layout {
                sequence: 25
            }
            listEntries {
                maxDisplayedEntries: 7
            }
            source {
                databaseColumn: UEBERFAELLIG
            }
        )

        facet P10_JAHR (
            type: checkboxGroup
            label {
                label: Jahr
            }
            lov {
                type: distinctValues
                sortDirection: desc
            }
            layout {
                sequence: 30
            }
            listEntries {
                maxDisplayedEntries: 7
                sortByTopCounts: false
            }
            source {
                databaseColumn: JAHR
            }
        )

        facet P10_MONAT (
            type: checkboxGroup
            label {
                label: Monat
            }
            lov {
                type: distinctValues
                sortDirection: desc
            }
            layout {
                sequence: 35
            }
            listEntries {
                maxDisplayedEntries: 7
                sortByTopCounts: false
            }
            source {
                databaseColumn: MONAT
            }
            appearance {
                display: addFilterDialog
            }
        )

        facet P10_KUNDE (
            type: checkboxGroup
            label {
                label: Kunde
            }
            lov {
                type: distinctValues
            }
            layout {
                sequence: 40
            }
            listEntries {
                maxDisplayedEntries: 7
            }
            source {
                databaseColumn: KUNDE
            }
        )

    )

    region rechnungen (
        name: Rechnungen
        type: classicReport
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select r.RECH_ID,
                       coalesce(r.RECH_NUMMER, '(Entwurf)') as NUMMER,
                       r.RECH_DATUM,
                       to_char(r.RECH_DATUM, 'YYYY') as JAHR,
                       to_char(r.RECH_DATUM, 'YYYY-MM') as MONAT,
                       initcap(r.RECH_STATUS) as STATUS,
                       """ + _STATUS_ICON + r""" as STATUS_ICON,
                       case r.IST_UEBERFAELLIG when 'Y' then 'Ja' else 'Nein' end as UEBERFAELLIG,
                       case r.IST_UEBERFAELLIG when 'Y' then 'überfällig' end as UEBERFAELLIG_TEXT,
                       r.RECH_FAELLIG_AM,
                       r.KUND_NUMMER,
                       r.KUNDE,
                       r.RECH_BETREFF,
                       r.RECH_LEISTUNGSZEITRAUM,
                       r.RECH_SUMME_NETTO,
                       r.RECH_SUMME_BRUTTO,
                       r.OFFEN
                  from FAKT_RECHNUNGEN_V r
                 where r.RECH_MAND_ID = :MANDANT_ID   -- nur Rechnungen des im Portal gewaehlten Mandanten
                 order by r.RECH_DATUM desc nulls first, to_number(regexp_substr(r.RECH_NUMMER, '\d+$')) desc nulls first
                ```
        }
        layout {
            sequence: 30
            slot: body
        }
        appearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Region--noPadding
                t-Region--scrollBody
            ]
        }
        componentAppearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Report--stretch
                t-Report--staticRowColors
                t-Report--rowHighlight
                t-Report--horizontalBorders
            ]
        }
        pagination {
            type: rowRangesXToYOfZWithPagination
        }
        messages {
            whenNoDataFound: Keine Rechnungen gefunden.
        }

        column RECH_ID (
            type: hidden
            layout {
                sequence: 10
            }
        )

        column STATUS (
            type: plainText
            heading {
                heading: Status
                alignment: center
            }
            columnFormatting {
                htmlExpression: <span class="fa #STATUS_ICON#" title="#STATUS#" aria-label="#STATUS#" style="font-size:16px"></span>
            }
            layout {
                columnAlignment: center
                sequence: 15
            }
            sorting {
                sortable: false
            }
        )

        column STATUS_ICON (
            type: hidden
            layout {
                sequence: 16
            }
        )

        column NUMMER (
            type: link
            heading {
                heading: Nummer
            }
            layout {
                sequence: 20
            }
            link {
                target: {
                    page: 11
                    items: {
                        P11_RECH_ID: #RECH_ID#
                    }
                    clearCache: 11
                }
                linkText: <span class="thg-kundennr">#NUMMER#</span>
            }
            sorting {
                sortable: false
            }
        )

        column RECH_DATUM (
            type: plainText
            heading {
                heading: Datum
            }
            appearance {
                formatMask: DD.MM.YYYY
            }
            layout {
                sequence: 30
            }
            sorting {
                sortable: false
            }
        )

        column JAHR (
            type: hidden
            layout {
                sequence: 35
            }
        )

        column MONAT (
            type: hidden
            layout {
                sequence: 36
            }
        )

        column KUND_NUMMER (
            type: plainText
            heading {
                heading: Kundennr.
            }
            layout {
                sequence: 40
            }
            sorting {
                sortable: false
            }
        )

        column KUNDE (
            type: plainText
            heading {
                heading: Kunde
            }
            layout {
                sequence: 50
            }
            sorting {
                sortable: false
            }
        )

        column RECH_BETREFF (
            type: hidden
            layout {
                sequence: 60
            }
        )

        column RECH_LEISTUNGSZEITRAUM (
            type: plainText
            heading {
                heading: Leistungszeitraum
            }
            layout {
                sequence: 65
            }
            sorting {
                sortable: false
            }
        )

        column RECH_SUMME_NETTO (
            type: plainText
            heading {
                heading: Netto
                alignment: end
            }
            appearance {
                formatMask: FML999G999G990D00
            }
            layout {
                sequence: 70
                columnAlignment: end
            }
            sorting {
                sortable: false
            }
        )

        column RECH_SUMME_BRUTTO (
            type: plainText
            heading {
                heading: Brutto
                alignment: end
            }
            appearance {
                formatMask: FML999G999G990D00
            }
            layout {
                sequence: 80
                columnAlignment: end
            }
            sorting {
                sortable: false
            }
        )

        column OFFEN (
            type: plainText
            heading {
                heading: Offen
                alignment: end
            }
            appearance {
                formatMask: FML999G999G990D00
            }
            layout {
                sequence: 90
                columnAlignment: end
            }
            sorting {
                sortable: false
            }
        )

        column RECH_FAELLIG_AM (
            type: plainText
            heading {
                heading: Fällig am
            }
            appearance {
                formatMask: DD.MM.YYYY
            }
            layout {
                sequence: 100
            }
            sorting {
                sortable: false
            }
        )

        column UEBERFAELLIG (
            type: hidden
            layout {
                sequence: 105
            }
        )

        column UEBERFAELLIG_TEXT (
            type: plainText
            heading {
                heading: Hinweis
            }
            columnFormatting {
                htmlExpression: <span class="thg-badge thg-badge--UEBERFAELLIG">#UEBERFAELLIG_TEXT#</span>
            }
            layout {
                sequence: 110
            }
            sorting {
                sortable: false
            }
        )

    )

    button up (
        buttonName: UP
        label: Zurück zum Dashboard
        layout {
            sequence: 10
            region: @breadcrumb
            slot: up
        }
        appearance {
            buttonTemplate: @/icon
            templateOptions: [
                #DEFAULT#
                t-Button--noUI
            ]
            icon: fa-arrow-up
        }
        behavior {
            action: redirectThisApp
            target: {
                page: 1
            }
            warnOnUnsavedChanges: doNotCheck
        }
    )

    button reset (
        buttonName: RESET
        label: Zurücksetzen
        layout {
            sequence: 10
            region: @breadcrumb
            slot: next
        }
        appearance {
            buttonTemplate: @/text-with-icon
            templateOptions: [
                t-Button--noUI
                t-Button--iconLeft
                t-Button--gapRight
            ]
            icon: fa-undo-alt
        }
        behavior {
            action: redirectThisApp
            target: {
                page: 10
                clearCache: 10
                action: resetPagination
            }
            warnOnUnsavedChanges: doNotCheck
        }
    )

    button neue-rechnung (
        buttonName: CREATE
        label: Neue Rechnung
        layout {
            sequence: 20
            region: @breadcrumb
            slot: next
        }
        appearance {
            buttonTemplate: @/text-with-icon
            templateOptions: [
                #DEFAULT#
                t-Button--noUI
                t-Button--iconRight
            ]
            icon: fa-plus
        }
        behavior {
            action: redirectThisApp
            target: {
                page: 11
                clearCache: 11
            }
            warnOnUnsavedChanges: doNotCheck
        }
    )

)
"""
