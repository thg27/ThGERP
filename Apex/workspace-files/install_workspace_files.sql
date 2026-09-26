-- =====================================================================
-- Workspace-Dateien der ThG-Apps (Workspace THGERP) anlegen bzw. aktualisieren
-- GENERIERT mit build_install.py aus: thg.css, thg.js, thg-logo.svg, thg-app-icon.svg, thg-logo-edv.png, thg-logo-tg.png - nicht von Hand bearbeiten!
--
-- Einbindung in den Apps:
--   Theme > CSS > File URLs:        #WORKSPACE_FILES#thg.css
--   Anwendung > Logo (Custom):      #WORKSPACE_FILES#thg-logo-<mandant>.png (ADMIN_MANDANTEN.MAND_LOGO_DATEI)
-- (APEX kennt keine Subscription fuer Dateien, daher Workspace-Dateien statt App-Dateien.)
--
-- Wiederholbar: unveraenderte Dateien bleiben, geaenderte werden ersetzt.
-- Nutzt die APEX-Import-API (wie ein Workspace-Export), da es keine oeffentliche API gibt.
-- Ausfuehren mit SQLcl als Workspace-Schema (THGERP), nur DEV/TEST nach Freigabe.
-- =====================================================================

set define off
set serveroutput on

declare
    l_inhalt clob;

    procedure workspace_datei (
        p_file_name in varchar2,
        p_mime_type in varchar2,
        p_inhalt    in clob,
        p_base64    in boolean default false)
    is
    l_workspace_id number;
    l_file_id      number;
    l_alt          blob;
    l_neu          blob;
begin
    l_neu := case when p_base64 then apex_web_service.clobbase642blob(p_inhalt)
                  else apex_util.clob_to_blob(p_clob => p_inhalt, p_charset => 'AL32UTF8') end;
    select workspace_id into l_workspace_id from apex_workspaces where workspace = 'THGERP';
    begin
        select workspace_file_id, file_content into l_file_id, l_alt
          from apex_workspace_static_files
         where workspace_id = l_workspace_id and file_name = p_file_name;
    exception
        when no_data_found then l_file_id := null;
    end;

    if l_file_id is not null and dbms_lob.compare(l_alt, l_neu) = 0 then
        dbms_output.put_line(p_file_name || ': unveraendert');
        return;
    end if;

    wwv_flow_imp.import_begin(p_version_yyyy_mm_dd   => '2026.03.30',
                              p_default_workspace_id => l_workspace_id);
    wwv_flow_imp_shared.create_workspace_static_file(
        p_id           => l_file_id,
        p_file_name    => p_file_name,
        p_mime_type    => p_mime_type,
        p_file_charset => case when p_base64 then null else 'utf-8' end,
        p_file_content => l_neu);
    wwv_flow_imp.import_end;
    commit;
    dbms_output.put_line(p_file_name || ': ' || case when l_file_id is null then 'angelegt' else 'aktualisiert' end);
    end workspace_datei;
begin
    -- thg.css (text/css)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('/* ThG: gemeinsame Anpassungen Universal Theme (alle ThG-Apps) */

/* Farbigen Streifen oben im Header (t-Header::before) ausblenden - wie im Strategic Planner.
   Betrifft die Stile Iris/Vita; Redwood hat keinen Streifen. */
:root {
  --ut-header-strip-size: 0;
}

/* Mandantenfarben: Primaerfarbe (Banner) und Fokusfarbe (aktive Eingabefelder).
   Der aktuelle Mandant steht im Logo-Markup der App (data-mandant="<MAND_CODE>", siehe ADMIN_MANDANTEN);
   ohne Mandant (z.B. Apps mit einfachem Logo) gelten die Farben der THG-EDV GmbH. */
:root,
body:has([data-mandant="EDV"]) {
  --thg-primaer: #108024;   /* THG-EDV GmbH: Gruen */
  --thg-fokus: #e7f3e9;     /* helles Gruen fuer aktive Eingabefelder */
}
body:has([data-mandant="TG"]) {
  --thg-primaer: #003096;   /* Thomas Gesslbauer GmbH: Blau */
  --thg-fokus: #e6ecf7;     /* helles Blau */
}

/* Header (Banner ganz oben) in allen Theme-Stilen in der Mandantenfarbe mit weisser Schrift.
   !important, weil die Stil-CSS (Vita, Iris, Redwood '));
    dbms_lob.append(l_inhalt, to_clob('…) nach dieser Datei geladen wird und den Header einfaerbt;
   die Farbe kommt ausschliesslich vom Mandanten. */
body .t-Header {
  --ut-header-background-color: var(--thg-primaer) !important;
  --ut-header-border-color: var(--thg-primaer) !important;
  --ut-header-text-color: #fff !important;
  --ut-logo-text-color: #fff !important;
  background-color: var(--thg-primaer) !important;
  border-color: var(--thg-primaer) !important;
  color: #fff;
}
body .t-Header .t-Header-logo-link,
body .t-Header .t-Button--header,
body .t-Header .t-NavigationBar-item .t-Button {
  color: #fff !important;
}

/* Logo (ThG-Logo, Workspace-Datei thg-logo.svg) vor dem App-Namen */
.t-Header-logo img {
  height: 1.5rem;
  width: auto;
  margin-inline-end: .5rem;
}

/* Mandantenlogo (Logo-Typ "Custom"): Firmenlogo auf weissem Feld, da die Logos fuer hellen Grund gemacht sind */
.thg-mandant-logo {
  display: inline-flex;
  align-items: center;
  background: #fff;
  border-radius: 6px;
  padding: 2px 6px;
  m'));
    dbms_lob.append(l_inhalt, to_clob('argin-inline-end: .75rem;
  vertical-align: middle;
}
.t-Header-logo .thg-mandant-logo img {
  height: 2.25rem;
  margin: 0;
}

/* Pflichtfelder: Text "Required" unter dem Feld ausblenden - die rote Markierung im Feld genuegt.
   Hoehere Spezifitaet, weil der Theme-Stil (z.B. Redwood.css) nach dieser Datei geladen wird. */
.t-Form-fieldContainer .t-Form-itemAssistance .t-Form-itemRequired {
  display: none;
}

/* Radio-/Checkbox-Gruppen nebeneinander statt untereinander:
   am Feld Appearance > CSS Classes "thg-horizontal" setzen */
.thg-horizontal.apex-item-group--rc,
.thg-horizontal .apex-item-group--rc {
  display: flex;
  flex-wrap: wrap;
  column-gap: 1.5rem;
}

/* Aktives Eingabefeld hervorheben (Hintergrund), damit sofort sichtbar ist, wo der Cursor steht;
   Radio-/Checkbox-Gruppen ausgenommen (dort wäre die ganze Gruppe eingefärbt) */
.t-Form-fieldContainer:focus-within .t-Form-inputContainer :is(input:not([type=radio]):not([type=checkbox]), textarea, select),
.t-Form-fieldCon'));
    dbms_lob.append(l_inhalt, to_clob('tainer--floatingLabel:not(:has(.apex-item-group--rc)):focus-within .t-Form-fieldContainer-inner,
.t-Form-fieldContainer--floatingLabel:not(:has(.apex-item-group--rc)):focus-within .t-Form-itemWrapper {
  background-color: var(--thg-fokus) !important;
}

/* Kompakte Formular-Regionen: Region > Appearance > CSS Classes "thg-kompakt"
   (zusammen mit Template-Option "Slim Padding"): weniger Leerraum zwischen und in den Abschnitten */
.t-Region.thg-kompakt {
  margin-block-end: .75rem;
}
.thg-kompakt > .t-Region-header {
  padding-block: .375rem;
  min-block-size: 0;
}
.thg-kompakt > .t-Region-header .t-Region-headerItems {
  padding-block: 0;
  min-block-size: 0;
}
.thg-kompakt > .t-Region-header .t-Region-title {
  font-size: .9375rem;
}
.thg-kompakt > .t-Region-bodyWrap > .t-Region-body {
  padding: .375rem .5rem .5rem;
}

/* Dialog ohne Redwood-Musterstreifen über der Titelleiste: Klasse "thg-dialog-schlicht" am .ui-dialog
   (setzt z.B. das Kundenstammblatt, Seite 13 in 20020, per Jav'));
    dbms_lob.append(l_inhalt, to_clob('aScript) */
.ui-dialog.thg-dialog-schlicht .ui-dialog-titlebar::before {
  display: none !important;
}

/* Login-Seite (Portal): Firmenlogos mit Anschrift - Logo mit zentriertem Namen/Anschrift darunter, Thomas Gesslbauer GmbH links oben, THG-EDV GmbH rechts oben */
.thg-login-firma {
  position: fixed;
  top: 3rem;
  font-size: .875rem;
  line-height: 1.4;
  text-align: center;
}
.thg-login-firma--links  { left: clamp(2rem, 6vw, 10rem); }
.thg-login-firma--rechts { right: clamp(2rem, 6vw, 10rem); }
.thg-login-firma img {
  display: block;
  height: 10rem;
  margin: 0 auto .75rem;
}
.thg-login-firma-name { font-weight: 700; font-size: 1.75rem; line-height: 1.2; }

/* Schmale Bildschirme: Firmen nebeneinander ueber dem Anmeldeformular statt in den Ecken */
@media (max-width: 1280px) {
  .thg-login-firmen {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    padding: 1rem;
  }
  .thg-login-firma { position: static; font-size: .75rem; }
  .thg-login-firma-name { font'));
    dbms_lob.append(l_inhalt, to_clob('-size: 1rem; }
  .thg-login-firma img { height: 5rem; }
}
'));
    workspace_datei(p_file_name => 'thg.css', p_mime_type => 'text/css', p_inhalt => l_inhalt, p_base64 => false);
    dbms_lob.freetemporary(l_inhalt);

    -- thg.js (text/javascript)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('/* ThG: gemeinsames JavaScript aller ThG-Apps (Workspace-Datei, eingebunden im Theme wie thg.css) */

/* Klick auf das Logo im Banner: zuerst auf ungespeicherte Aenderungen pruefen (Seitenelemente und Grids),
   dann zur Startseite der Portal-App wechseln (gleiche Sitzung). */
document.addEventListener("click", function (ereignis) {
    var logo = ereignis.target.closest(".t-Header-logo-link");
    if (!logo || !window.apex) {
        return;
    }
    ereignis.preventDefault();
    var sitzung = (apex.env && apex.env.APP_SESSION) || apex.item("pInstance").getValue();
    var ziel = "f?p=THG-PORTAL:HOME:" + sitzung;
    var wechseln = function () {
        apex.navigation.redirect(ziel, true);   // true: eigene Abfrage statt Standardwarnung
    };
    if (apex.page.isChanged()) {
        apex.message.confirm("Es gibt ungespeicherte Änderungen. Trotzdem zum Portal wechseln? Die Änderungen gehen verloren.",
            function (ok) {
                if (ok) {
                    wechsel'));
    dbms_lob.append(l_inhalt, to_clob('n();
                }
            },
            { title: "Ungespeicherte Änderungen", confirmLabel: "Zum Portal", cancelLabel: "Abbrechen" });
    } else {
        wechseln();
    }
}, true);

/* Region Display Selector: Registerkarte "Show All" auf Deutsch (deutsche APEX-Systemtexte nicht installiert) */
document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(".apex-rds a").forEach(function (a) {
        if (a.textContent.trim() === "Show All") {
            a.querySelector("span") ? (a.querySelector("span").textContent = "Alle") : (a.textContent = "Alle");
        }
    });
});
'));
    workspace_datei(p_file_name => 'thg.js', p_mime_type => 'text/javascript', p_inhalt => l_inhalt, p_base64 => false);
    dbms_lob.freetemporary(l_inhalt);

    -- thg-logo.svg (image/svg+xml)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="39" viewBox="0 0 64 39" fill="none"><title>ThG</title><text x="0" y="31" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="32" font-weight="700" letter-spacing="-0.5" fill="#ffffff">ThG</text></svg>
'));
    workspace_datei(p_file_name => 'thg-logo.svg', p_mime_type => 'image/svg+xml', p_inhalt => l_inhalt, p_base64 => false);
    dbms_lob.freetemporary(l_inhalt);

    -- thg-app-icon.svg (image/svg+xml)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <title>ThG</title>
  <defs>
    <!-- Farben aus den Firmenlogos: Blau (Thomas Gesslbauer GmbH), Gruen (ThG - edv GmbH), Rot (beide) -->
    <linearGradient id="thg-verlauf" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#003096"/>
      <stop offset="1" stop-color="#108024"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="112" fill="url(#thg-verlauf)"/>
  <!-- T: weiss, wie in beiden Logos -->
  <path d="M92 112h208v64h-68v224h-72V176H92z" fill="#fff"/>
  <!-- hG: rot, auf weissem Feld -->
  <rect x="256" y="232" width="164" height="168" rx="36" fill="#fff"/>
  <text x="338" y="364" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif"
        font-size="120" font-weight="700" letter-spacing="-4" fill="#e83c00">hG</text>
</svg>
'));
    workspace_datei(p_file_name => 'thg-app-icon.svg', p_mime_type => 'image/svg+xml', p_inhalt => l_inhalt, p_base64 => false);
    dbms_lob.freetemporary(l_inhalt);

    -- thg-logo-edv.png (image/png)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('iVBORw0KGgoAAAANSUhEUgAAAK8AAAB4CAYAAACEqaLiAABMLklEQVR4nO29CZwV53Un+v9qu3XX7tvdt5tuoIEGAWIVQhGSQBLdQrbsWLblieKx37Mzz5mxE3neKIvnyfOcSex59sTJOImVxHtsx/aMMl5i2ZZsy7K4jQQIIQQCsQgQawPd0Nvtu9et+qq+9ztfVfXtBrQYYbT4Hqm5W+116nznO+d//gdoSEMa0pCGNKQhDWlIQxrSkIY0pCENaUhDGtKQhjSkIQ1pSEMa0pCGNKQhDXn9CnutD+DNLhsHNmZYzbgbAlxw+8Hbltw28lof05tFtNf6AN5skrV3pnGi/AHXce7fMbATf/ezL+Pw2Rdw1/LfxluXvIUU98HX+hjfLNJQ3lcp2SObV4O7943kx+7efWYv/vqrf4kXxo4jVxuDpTgQmgpw4HRlDFC0DRsHtm8xxkoZrimnepf3Fl/r438jS8Nt+BVk+8DGTNlmd4GzTx4+d7Rzz+m9OHD2CI7nT2KilgdXAFVXwTQFTDAIIaAIBYBAOtKMq9MLkFBM9C64GYu6Fl3Xd/XNO1/rc3ojS8PyvoRsO5HtrlaVD9iu8+ndZ/bh7zb+TxwaOYIzlXMou1V4CqApOlRDgaJFoDgcnu1CtQVa9DSSRhw5t4AyLOTsPDYNboPiAc1NrVjUteAOAA3lfRXSUN4pkj24ZSE8fu94KXfPHnIBfvF1HBo7guHyKKqoAboCVVPBdAWKqsFzONyqjQhMdMbbsXDGAizrXIxlM6/G8lnLMFGdwOcf/xJ+diwL3dBh6iZcx0bZKgCe1/Nan+8bXX6jlTd7+Ik18MT3Dp473L3z1B78+SOfxmD+LMatPBzmQtFUaKoGYTIwTwO3Obyqi4SIYm7zPKyctQyrulfI1572uWhLtEDX9MntD4ydQSaRgcZ0CAGwwI2wbBsQ6qLX9OTfBPK6Ud7+/v4kvYrmzjRyVQA5wDDM8Heh6xps/z1jDgdj'));
    dbms_lob.append(l_inhalt, to_clob('HKYJZnCrd/mawVeyj+wLj5O/+pV9Z/Zldgzswn9+8M8xUBqEBQuuIqBqOlTyV2MaVM7gOg6cCkdCiaK7aR5Wdq/AmnmrsWrOSsxr70ZTNAWFkU9bFzHl33SsCR2JNhhMQw0OGBg8JjBcGUHVra69jJfvN1KuuPL2792b9FTVZGfPRqVy2noUWs2Ut1szo6jkNYBxaHENmtDgMk5/jDsaSE/os6rIGTwsSxNll2e3PTGbaUwXRWegr69vgDaVHdmZxmjlQ67LP/fsqd3YObAbf/Td/4JTpSFURRXM0KHqGpSIKq2q4rpwaw4UT0WzksLc1Gys7FqG1XNWYWW3b1njZvyCGe5UZSXlZOEnARh6BC3xVsSMGKp8wld0xlCqlVCoFq70pX/TiXZFLGqsLSnKJQ3xZFpMlDQmhAZNAxOqDt0DoAOcA8zlQlWDo3I5bM4ZY1xoEY25ikUaS+/lsnIRxpnrcsFFVGiahqSxIrt/08Ef7f959K+++xkcGTuO8doEqsKGoinQVB1KXIUpErAdG7xqIwoTXbEOXJWZhxVdS7Gq+xpcPXMRZrd0IWZEL3JGpJp1FfbfMfmtgJCfpQIzwNB0zEi0IW2mMFIYB1QVCmMo2FWMFMexdV+2Z+2yvmO/7nvwZpVfm/Ju3Lg9wyJKWgg3Ca+msWhUF17RkXt0/GWEU61CS2nQ5Rdc/m8xkMVluq4LhzlCOKTUDvmMUnG45TCmB44lh4jENXALzNUtYTjr/3Xvj6Jf2v0AzHgMKilLXIHuRuBZDhy7hpiIoMVoxqLMAlzbvQrrFtyIxTOvQnsyg8gUf9XfW6CoQpDBDIQFSsqmLFG3uL4NDpcEokYUUS06aY4VhaHKK5iwcnAZMgAayvt6UN7+vf1JMWJkEFUyEG4UKjRmOxY43TmHtBXgBidDC0fh0GOaNLmuSz4sfJ+WdNjmguu+edUNgNN6dLS6xnRNF07VAeccmqYx1wVZXcEdB4LlYmYKMS0OVWgQ'));
    dbms_lob.append(l_inhalt, to_clob('NocpNHRG23HVrPlYNfMaXDfvWizq7EF7qh2mEZl2/KHlDBUy/Fcw37KG6krf1q3s9DV88X8nmZHqQGdyBp4bPyg3QEs5cDFWK4F76lIKH1/Oe/CbJJdNebNbt/bAMrpgOhocslRSIUnBSGcd+d4wIJxy1VdSg26yIzU2MFcMDqeJGWNxHfS+VnMYOadSLehFQHDLV3Qyvg64oJHd4Q7oVaiD85rnQBcaVKFi3czr8fHb78W8TA9aE81QmTrtmKdaSX//9VepjsE/U9Wy7ihMereTboOv1P4S4RqJSAzxSATCI/fI37/jcYwWR+ntegDfuFz34DdNtMvh03qaNhtMb0fJ4sw0OXQOwVEFJyUDoHAuamR2ab4S4VJvSWzO5VRcvrelpWVkkVG2YBgaYxHADhQaFGHQo9DZpNuBWFST4QBSZkfToNu5llgamqLAE0DCSGHpzCVIROLT3YDg01SlpN/Cadfkd/Lthapbt8LTtzB12fC3RDSFtlgHTMWEC1f+5nouqjZFVDD71V7/32SZHuf5FSWb3ZkWQvQwVW2XkyiNPAPuSEsrLSXnNLyHikvWlhRRCF2TljhSA+yob6Ehh3AO1Hx3wabvSKFtzhyHS323nSrKdlVIRzjYPq3rMC7fV5WRlkQb2mJtqPEahvKnMVoYmzze0Fr69vHi9pdd5A8vYaHP/+78z01mAjMSLTBVHRCe7xczYNTKwRYuWd6GXGnllVEEo9rN9GgSnFdlVABOVSoTdy1hl6s0tJOi0W+MKRZzuMVi3GKaV4KicChRzljBghLjjNkWLQc5/kc5mWtEwRGl96plw7YQIYWPcOYollRkx6kKoTtCr/luCXOKGlM3NetxuB5H0alhaGI4OGJ/OuUP7dMH/bqEal23wxdbavr3YZxh6rf1qZuiqtBVTYbJZKKCnAdFQdHKI1/OXerlb8irUV6yuPBYRgjHAWIQOqsKW1RhMC4to2GAlIspihWFakWlMiqcFTSLKRYX'));
    dbms_lob.append(l_inhalt, to_clob('lUqV/jzPc1hC4/Qq38cVLkSlSq/MYpxZCim+DJmhpnBma5a0zqTINj0UDidXROi6AxsWPG/PjOQMCM/FhD2OU6My7BtIfVC/mDvgq/XU5WSgYVos9/yIQj3CO12dw21ENAOdqU6ko2l44cYUwOIOynblUi9/Qy7V581mdyyEWukB3EFSXBici7JTlRMy23YYMzliCic/llkWt+IxeKWSk7ASeskrOSiRM5gAUAIrMy5GRkg55bZFWeMJdGooFZ0yEzwuoNHigAclETxrXhqoWhyo0nyPLDQYZxqLx7kQzq556dnwjgk4LsdQ/lxw1PXQltzPlKnX1JBXPZ4QTL5kpKEeHLtwShZK/WGg/Z4rjOLw2SN49sRubDq2GSPVEagyG0eTWQW5Wh6nC0PIPptd2beqb8+l3IffdLnECVtlKaAnoagWYEGQl2sYfto2GuWsULDAY4CiALEYYig5pUSCdNYhZQW6AS2PpnwzCqzAgTagjWbfbcDoKCqswEVqtsYKFV5u0sDytE8Gb3L3tsNazChgUpYN8rVm8ZgFp5zShlsTrdCZirJnYWB8AJ7nx1en2tvQgk5VwfqU7fxExIt7t/Qb+ddncmdxcOgwdp54Fs8M7MLh0WMYqY2jghoUTYOhaVCDB4GiGFw4qJDlVbX0pd2Dhlyi8rKFgDcAFikKCyZFD1hTlJO2sAIpY0wu5ZXgsOYy18CgFCq+QrIKR1sVvctXFylVLBUWAAGz6XNvbx2g3d+/N8kKo1w0pTTkm8DK4CIe1Rg7y8U4mV2QNdbJ/AqYWgk2mOsent82F1ElCtfzMGFXUKlVkIjGp5/BtGE+jNxOtcbnS/1Xx3NwbmIYO0/swVMvbMeuM3twJHcCY7UcbMWFYqhQFQ1qVEEU0cnHRUxxGxzPxdnSKKCr7waw6dLuw2+2aJcyUROKshTMS/etXf0v2ey2bjDXZGOVEllZtMXgVSjaUAJrbuZN+W6s7luQI8XsW75g2gyld/ny'));
    dbms_lob.append(l_inhalt, to_clob('4kt+7l1e9BUYHGx02hEzpsmohCezF0AiPu6UtWYOzePxSByGoqEkLJyeOIVz+WEkovMuSERMT+5ODXOF/u+FsdzRwgi+0v8NfHPHAxh2xuEyQbkTypdANQzExPQg2nSHBBAKk8pbYxzj1THAta/7Ve9BQy51wtbWBgiX7sL7stnswr6+GweErufkhCuZdMSIVlUqFUuJtVvMKHBS3Isp5iuWRa1SiaVFbmsDKxhy8sbI3WgCmKZx+itrzP/sJHJxI75/RqwTHC6qbg2Fqu81T3UZXjrQVbey9WV9R4NwvCVhY0KxoCVNRGMxGLrhe8ne1CBamH8LtsMYXAg43EatUgGrckS8COAiDIc05NdteYVta2CKBs9NA+o92SNHPtW3YMHIpFWmId6ouwJ4ldLb1TW5DXoA+vcOJsMHgdLRodsBgglUR+U+swc3b09HE0u9Ipfx1CMjR7Fq3nIIeOTATD8fCBQqJRwfPoGh3FmJHls4c8GkhQ6XCZU5ZSYxu6kdKS2CnFsCmOoruIRAhG4BAxcuPOHB5RyeK2B6GlrUJHoSc7CiewWum7cSM5o77o974q9f7TX6TZVfWXnJ8gm1TEkGuklLMXTu09nslvv7+tYdnuqv/rqkd/lUZZ6+v/7BQYkJhsIOdzbNhBjaAduzMFb0ExWkuKSIZauCgfEz2HdqH554YSuePb0PJyYGoDMdf9T7h5idmRUgyi4MnRE4vTnagpiRQK5alBlfGSgRkKEw7rpwHBtRZqLdbMXs9EysmrEcNyy4DplE6v6mGL65al4juvDapocVFpVBUO52Qtc+mX18y/f7bl33mpZ1T1ppD/vnNnXB81xURA3PjRzC9mO7sPvEXjxzYieeHz6EE8UzKPAiHMXzcb1RBabrYsQaRbVWkcpbt73TsWQzkhm0xVowUD4FVaW0Iu1SQPEYrsssx9sX3Y7Vs6/hUNm9rKfrR73GfAmWFzuz6dHpWKCGXFnlpYkTVTgIDZ7HoRDY'));
    dbms_lob.append(l_inhalt, to_clob('xK3Cxdrs1q2zIcTjfevWvbaWRRNDzclmRBQDlqjhBwd+hB8+9yBKTkXWn1EdmmLoMCKGD7PwKAznyWexWC2hXKui1a/ruCAZTN/EIjHEdIpehC6IkJGNpJrAv73m3fjIrb8/zYkWg/1dTsVrdhibyMzvfUVVHw35tWTY5ITNkndaCUA1pMSayuE4OrhYm92y7e6NGzcvwWskrLv58PzMPCS1pFQ2VxVwIoCZTCASMaETKJ2sqKhPqCRUUTgYyp/FWKmOh5iaWQunYe2pDGYmZ0ARwbMvGBRFgU2Wu1igKo5pxZWsq3fQWHDbAUyIJeVt2c+XtmffZ0t/vSFX1vLS/GhM4WBhyoDVnwElQuURHK7NWSTSk81mk4hERpidGqGIAa6Q9BrLi9kDT3BTM7SycIIMmZCARFLaMPglz0BMUUuFocyrfvLgoogHX9Vp0paKJOtPvox+MVi8inPFIWC4tOZ8kHmp/2GR+/Jfw31hD7SrVgK/96fBmg25stgGz+X1BD8pK5EYeKTQ3A+8qrSMBS0KYXmmMEvp/v7tXdls9gpmk8SDXcYMuCUL7WhGd7QDKlQZbwiQjuDCQ9WuoVarwXXIcVBwtjSGoSIFT8Ik8dSwlx95iJlxdKQ6kdTiMsIg/5PPsEDJKtPMbeW0I3k2283374L3/FboYgg4swvuC7tQ3JFdeOWux5tPfmXLS2Gq7KbNEB7l6EWAr/YD75OiBqQGOqWSbKBKNZWAiMc1mUWbDHVR2MufZMls22grgEPwYh2mEnN1r1JxmGFEQRngqgUkNVPifmuGBtSijEWSQrVNCJ6EqifBRQKeSAN8BDa+8Rd33ne3YB503fwMFO8D//Vn/71799h+aXIJVJlgUfTOvBndrbPw9Nln8dzYIZRrJeTKE3BcV6LBpmOA/XONGcTTkEZMM1HgJWgByN0FwxmyvAz3APj45CpJFJWICUU3IIQCQYsLDxEv9DsacilyqRevSjFMlXKgtA2F1Yu/'));
    dbms_lob.append(l_inhalt, to_clob('XIcsL/nAGhz62vBRjlYFKMWAyuhFw16EaaDJoBApAuVAlD2NkdY7jgnEo6QaKHINZiQpATlGNC3cmgahRCEUE5zROJ6E4iXA1TQmFE1jeBuEthIR1oko+/tbMzd8Ln82h2XdS2QJ+8q51+xkRf2dosn5T6VnqvcdGH8BE7UiBvJDKFoltMSbp5X5TEWTRSNxRNUoYJPv7y8iFA+WbcHhfJo/yxb05Qrf+DzhI0HAUc8lKigWVvI35Moqryhy14GqmkmAFaUp41QBQV+SQrt+Za8udOEYpOoA8/EOkzmF84RixJTkoMyZEDENUZMmgkR4QEVtVQPxqI0cB9eqIH/EoyCrkQRqVTBTg+ZRaZgjNUlFEh42QNG7JQStJoib6ZsbrvvtRRtWvL3LGDUHbVRXY5Tfx3ntjMrx0MxUh7S0Nvm81Txspzb9jKe8DydtmVQbjlVOTvrChNmteBYK/EKoI/0mByc5z1UloYmhEEipIVfY5+U5h1NJC4XLBA9IuzQZNpOhM38YFVVLYhbDAnLGylxG2s6Tvf1BciHQbAJLMoXcg6CqwgDssHRo6jNHyuoG4AbyuenP3xNpCL0vQrAiVKVLuOJzOFd7BjmnP+8MH5oojz8wPjGxslim1LHWkjSbZJUvFwKjlTxy5cIFsPR6gTvVpkUR0035yb+IhFxTMG7lMFwMYZh1kWvKGSILyouErJK+pOvfkFehvGr0cDRGIFp1IRSUaJYOz6tKCCQjZQruyZRKco9wvOiGmD37ghu2vLdLAnDCz6ROwiC/NigOIp6wiw2yqqpThfL0LykSIvy6NppMkhJ7XpEwtDbnyZptSeUhMA1VNNhEvcSZ1hnNIB1pguPZGMmfQ24yXDYVYlMH77Qm22RVsC50maAI/WLP81CzbWSPnD859aE+8mFwPZkyhscuRgzRkF9vJYWtqZrx/dODZ+jiJ6DoOam4qrR8VKfu16zJimGgKm9RQsJ4+xZMR5bVhSZroxCplK+M'));
    dbms_lob.append(l_inhalt, to_clob('NEkjtZ3MSJHpnWJ+JRWUS5yi/vLEpEO+No0Ect/0KmvNKQ5LClxVyedkPv0o8YbJzBhV9QrRHVFNJIy4/L3ELRRr/tAfYsTqSuxHIJoiSbSYTeTwBwdEcQygzCs4kx+ioWLD1LOj7YaHI9VYeKAalIZcaeVlrBuKuqettQVHjh65C4J3QmBI1nST+EWykDhBGKBqipfbZG8vTd7a0JQP3AspgWGyI3XLS3wNch8uh6tSKS6XZ0FEDXW4uv9WBC5FYC4vBjwPwrydbWYrOhMd8ruR8iiGC8N+2c60deoVa7phoCmehqlF6rFihcHxapio5gjqOC0MRjS9IXEJPTiyFF68frjifoN8XjUD4VhmLPZ7RN25a+fuD8Fz74PnDAK6BRW6n/R3QJW//kolZKqnXtEEJS7iwU2t+h6DEeguETLIB0J6EhwqPSWur6gK+dz0N3mQPvFCyLQjfIs8NXI7yWBj0SGraDJSku/B4hbyVkHCF/3FpqIcfIWO6VF0pjKyrN4NqoJ9RJmCsmuR77966jnRoYSQSfJ9g1hzY8J2RcHoe/cmxVguCs5ms5i5fc78BR9zagc/99T2HQsXLOh5qC2j388U/EDQDF+yMlXk8J1AJ5YvX/IyWbZR5JECWJkzn2dnCqcDRSsEmK7qgrwSzQW46kD1fWN4hD2cku2jYdr1HKgUYPb93zplU6iDhDNTpDFPGUnMTnciFomg4JRwOjeIfLWAdj0zzWSHNRfEOUYEeoZmwrP8Kar/rDAM5YfBPfeuaac2rXjOr2PTgwDM+SL2ZXucAtZ5HD00FfaA4YjOdrEbe7f8qvfrzSyXlqR4fDNV9qwULh5jWmT7gkWL39+UGnrg2PETODM4eO+8uXPvTaWS9xsO/6LD2IjnxcyKQuboxcVPUoxOWt5y1NBkiC1iADVPk8bXqXAhoqS5RBMFGKoOu8Khk/ur0kPC/ViU4mcBKf5MroNUPkULa8+lEjMmX5nKZEKC4q5xzYQG'));
    dbms_lob.append(l_inhalt, to_clob('TUbW8rUiqjVZaXQRhIMvrfFWtEVbcSR/QkZZ/EoJEH0pLKe+rhR6huQIUIdPOlMiaoUns+uVYrGfb81i7NOfgjNyGqiVJAZZ6Aa05g6M/fH7oa9aB33B4u+YSfZRdhnw0uKJ7JoKw/1eIbcGlXJwbB6YvIb0nuyA/FJmE6XvLh9elUqjwTIdRcPEe4zVfY/hCsul+VxE5QRtNhx7gwAeh6Ydbp818+ZMW/rLB184uvT55w8iakbunTmr697WlswjTHf/qveW5Zte7qHYu7c/OTpa4GWyvtLfzVEYlxtIajbKMjOhk5lkGne4BqhEO6NG5fEEZJNyKKbIB4XxGKtCCBNCUCSEM3hcoVIIOnHG/NIdTSdSHriuQEs8Izl1J+wihkpnMVwcxZxM9zRgpP+v/9psJpAyYr7/Sg+CjOECeauI4dL49BP0CLUWhNW4B8Y9Iv/h4tmNSyqjpf3Vb30e7nOboNgFENyJMixSgYjiiryj4UG4Z3bBefx7YK3dH6itv+sD9tPZjxjX9331V719Ym9/0s6J/2Xt2Hzn2P2fgHv2BYhKDsxzgzDe+SPFlLdTK6NocNPjSfOmd/+ysjX7YGxt33twBeUSJwwK+YE6BFuEmpOEqjws1MhO1tbylsWKugae9/XjJ06mT5wYwIkTp+5oSiXv+PFPfopkIrlTAfuqB+Wxvr61F7AjLqciTKpZY6Pcq/Aqi0WjqFZhRyjmCw1xHU6ZfF3ugGsaIjKJQWyoVZkedrkDhfjPSLHJF/YsMGaBiQkwssIsp2pKVBUsYdec5EQ+j3MjIxiZmJCQxlirGfiwHIVqEaWgfCjMr02trSCJmymkYy3QFWNayVCxVsBYcUT2YLutO+y7Fnja0toTL7AB1cGS8t69D1S++3mgdEISWxOZ0GSVHWmSHCyCLJ7JoJLLYZ1A7aH74Z058hVrW/Y+xcB1xuq+V8RgYm/LfqHw0M/usTb9K1huAEznUCmN3yTpUOQIRAoqB6lQ'));
    dbms_lob.append(l_inhalt, to_clob('UwNlnYx3+xGcwH2qwNn8PehLVt1lP5ldb9zUd8WKSS99tsuo3pxMgpKB691Flk7w9HZ24/WP9RpGS3bL9pXzXOv/GxvN3Tk4eBaHDx+hqNbqiG58xYxG8YMf/BjpFpl+fQgKHoPHnxNC7O/tXR422ZvEPFDpEdOMqChzC0luoiadCAtEcqKrUfCoBl7OyfAZkfDWHBMq64JgnQBNLsVsx6515/ITyOUmkM8XULGqsGu29Hcrto2JiQk0tyTRrDdLrEK+VsJ4ZSIYKsNTrp88SQsxn8dboSuKBPlImKU0rB4KtTKYFSUWSP9m+sEIXysokeO4KO7b/UDtB/8ItTxAZL7T5piBZ1N3NcIoBb1RVChRgO/8CYoTIz3J//vTuwHMeblbVvzlQ2Li/j+DOPYMFM0BomSE1GA+G2olxex9n57wK5NDSngMtAy5EOFxycSUAzc/BldB+g3gNihJeCIZrF+EcKsQbA3yE2nx9B66WcW+dWsIkP5OWjy75ckPwuZ/ki8WVo6OjKFULGAil8PJUycpm3ynpip3GoYhixm/+70HEY2aMM0INFUtitGJIQCDQqnmoLARlFGEQlEAZsEjlmi7HUJZCIX1uJaVtmo1lKtVlEtllCoV1EhJHUeW53jEfu554K4nGXV0TcPM2bORybShvb1jD5Jca4+3LKXkRa6Ww3DpHLjLp/WZCIVuHpFH06SNlN0hrmBQHJmhBgtny8M0iVw/qbykJ6QbHk0SGeynNsEdH5QWFwYpSqiwZHc9wKVwWsgP5dfFSeBlYI3hAsxU4b3wJMrf/ofu6pPZr0Rv6vvIi92y4v/+uij/3R+D5Y6CGeSOhAdUzxGSkioyLOKfYRhCmUR3TIZUvEkylnCEUOJxGuyKr3/l9dOchN3VIOiVLqawoNhpcH1DdsuWhUDkcN+63zpMS/atu+nbAOgP/du3d4myRQH899m2fQdZwkq1IrNS47mcvGHy8vg3LqkQJospMmYqEwpTkrV+'));
    dbms_lob.append(l_inhalt, to_clob('HLbO2ejSup4Ll5QzOFCZiyBfU1FgmBEkk3G0t7cj09Y6AqY+AqYMyGCIwAQUbwNVAtONrXEbo6UJScnUrDVdgC0jiUZi6GzqQspIoVw7J3nJwuMirghwUQelhy4AkZ+UR+AdyvrKQkN2iO3xXPAaLdoEpaUb2uweKNEovHOn4Z47DlEZAdMcWQ3C5DYBNabB2fUQ7EXLPmw/nn3IuLXv4fNvV/HnPxSVL/8XsMIxuT/hTXWChISkSPpkTk64EiRUaDk6G1d+noyLy8saIJEUWsaDsuAG6CtvqkITe17/yiuPXfiYXgZy0vw4K4lKM34lCdfuyT6xLS2cyrHbbqv32+1dI5ufTCoziZ8anlgpGLsVAmsAfoPt8AwN6zSZsqyaTOOSUkpLEQxbpCR08WhiQ8pJ4BfyG6MmWW4qS5dtL0aoIBOe2A/D2AOmHYPqaXC8JHFPQLCV8Jy18EQ3amznzKYuxNQoSrUizhaGpN/bHGuagi0j8W+kpqhIGVFEFApqTDVPTLocAHvH5DWTiTx/GaZ4crSV6iM37IFzDaJ9BfSb7kTkxlsHDIb3GDf3yT5tIptNOxrusU+f+HTt0e9CHN0Khgo8mS2kJKML+6ffgr5yzUP29o3txpr69S49kf1e9Wv/DUruOISq+JM/FjxEDk3QklA6l0Jb9lvQr74OrLlF+uTU98NzvaDmoG5hKfoRxr3pIWCaCj1mfFw38VW2+rbc6195XV4EU/1YEA1nnLAEBEYnkA4lJYixkbgVNF0AmezWnUlmcwuIFS9WURF8RzHMF41jyrJ6szMNyl5R8iISCZIVJhC1OVMS3EOTc9ua7mmNqfuPHu0SBVWDWsigYmfg1brAvYXyIRHemkK+ELXsGlRNQ6vaxKlCwlA1lJmQ1tcOExVTLO9UjEMq1ozmaBqscmYyxCwUgbHqGIpWoe4DBpMc32ISeD1UXBee0gSt99/CeOvdX03eeuHQz/rkZOwz9Gc/nr2rdmDnD+2f'));
    dbms_lob.append(l_inhalt, to_clob('fAUoH5fXnwkVfGIAtSceAbv9PXeGhNVie39X7mc/vluc3EMZSd+nlQEMYpKNQbn27TDf+QEYRvJ2o+/Kh7peI7fBI6QWXQzfGaRHVT6h9B0ljajfLl2sYPmazRFX4KFCrakuyS8Kyupfdl2y4iLFMnBKpDidYnC4G2ArAbEQnttDqW2HfGCiDiaAjKAWVqrvX3qKRty+zZFmjFYnMFQdx7nSGHo65r0IGR/QkWyTkzaMBtYomPhUHQfFKXFi/zoFv5PC0QfXg4smRN7y7xBdf+dHzJtfPuxl3Nr3oMhmW8r//s/HrS/8KYQzLq2oojM4z26Geft7Pm/393/f6O0tVrnYzff2A7zo3xo58RLwagmYv/MnSFy3/v1qX9+/4A0ql6a8hpHz+0yQIgdAGLI6U6AFISySsYgu01AVr0TkZS8nVF2BUaqmiJkKRW4pkB+LQRDlGXIQIp5ghohKRnTNTEMoCYBHJfGf4AmBYhJFNw3GusBEBh5LS5A6VFJmqnqWbgb5cQoLyKJkBT/hiUS0KZ5CwojBEy7ylQkUyjT81xkcpgbMSOLRBFLRZpleDj1wcl/y9gTOFoewcWB75rbuNSPyYadrJA2uPylyHQXaTW+Hdsud978SxZ1qicVT2ev4dXc8w595EJIWWWUQ514Af2F/Ul24jMqQttS2bMwgTyOC7GAoqaZcN4no+z8GY8XaO9W+C/3jNz+2wXWPQXg+YcFU8SYJ90l3NRCV7iQQrALGml8+lx/gfVlZ40TUJ4ShCV4wYXATSKcZK+uMEhMw01BCxVWI/tcEFCoLps+Ec6C+V0UwloOHohwtaIYsZ4MB6V04mtOchfxpBSsow5aIJMGYioJVxHgl74fLplWy1aU1ngYB2U3Z5dKft9NMnBNnBE3aSjZ1/JGZtyD25W+Ie9BmLoK54V1I3tr3R7/qLWA39O2MvPP/4krbfBmblUfGK+D7dtL5reGbsv/Je3478W3LwAIdE3XvNG75HZhr'));
    dbms_lob.append(l_inhalt, to_clob('1n4s+gZX3EtXXk3LSZdBYQkoofWWlkUPKhn8LFyoqkG/iVciPros2KIS890SAqXbNhe67QBxf7wgnj2JLNOC7kLkUweg9KkSjgZUph+mZid/qgdwZVsLh0dbIs3oTLTL5itj5XGcnTgr+XZJJkNDUxBmEd1A0ohBpbSY7xP44TLBJQskU/G2yZ1MjVgwA9rKtdBa2+7FJYppYz5bfBNAHBK0a2qcdOYQXf8NjlO+X0ycpnCdjyPmLtSOJYj99vsRSbBfOSv35lHeWo1irvsh2FKATUxCDz0aewmmGCwXAMBEOibbsMZF9GXdFDkxS6U0FjeiQnANkYrmT86ExhxDh25rQqhBI0GaFtcAR9WgG+akVk5qiLSmVGPn4xom45a+7xd6r6EltqyqBIlTlo2astSELX1fqmcLN+uvXbe+Ed1Ee6oTzdGmIHTnx0Bdz0auMkYWVqLLQqJqGe+l69M8A9riaxGp4juXdA8g3YcBfcVaiFhLGH2FVynRqXXyoy/AqxQm0ZqeqyJyy29D1dj7Lwcm4g0MRlc7wdhzZ06fpokaJQj8GT6xeUwuQikjX1dZpWKR31pRzr0kOCcU4vj1ShXfBakplBr2ew+TEMRSKi59pEqKAFU2fQS42FZ9v89HyASjN2l7nZK0YtVkZURnskNWBluehaH8ICYCvzfElE3ZomQ7b44mEKWSIAmNDBwLlaHs1igDtUIuS6EpcluCDJWS7oTS0R1GEi5ZlK6uR1iyPZgsA8LKU3nfSuf4YTC7LF0GCaRJZKAvuwF6hT2ON4lcovKKbjDtUCbTjr17dq+BwAegimG4igPFpfoaTQ7poVBJT6XyyiZr0gdNaUo7uQwWIpQ3jdAoS/3YbOq/Ro0DuYR/SXHrZ6EESiwtv4ywE6Ml1emQMpGbo4XKVydxCj4zJgnyBBdI6DEYqiEpoIq1EkqVuqGayu4b1rfFzQSS5CdT3NP/Qe7gXGmErDaliCczrzJMRvOnVAZMi2zF'));
    dbms_lob.append(l_inhalt, to_clob('qxSm4l9YssmvECEgT7kId2wMTBKn+CzsHvegtM+Dkk7vYb1vHrqpS1NeaeW8RYZh/G5LSyue2v50j1227ocOHZ45Ih0tRTVle9WaTnEpyydLf5HS4YuVwge6XotQ/5Twy7KfCZJAd5IQjC5BOHzSm1WDySO5M8Krys+upM7xRaZAz085UJGGI/3b9ng72uOt8vvB4lkM5s8Gy/mebljK44tAV7IdXfH2IH5b36JlV2AF5UQyPBbCMGlwMA06zletSGYcW7S2WVTb4T+vNCqR60DAOubJ46FEg9p9FeVCfoQ3kVxqNyALnrsQsQifObf7Y12dHdix4xkcOXj4cxDVr8vZv8CQiFJTYT/IH6u8CPL6xUTec3KVpbtcbxxIIm269K2p/p7SQfXTmTZhC7MGQThPkF2dAu2bivXzg1zg3JVVwfFITP5sORaqtu/t1CMNdd50+iPsA/WcCLcoo7iKgqrnIG/7z6OvuEG0gZZSVfr3VfuebFnfMRZphlB0f9/kElUsePKYpc/vE8Q0tdDbqa2R3vByqagywjN0o+YsQSK2s7t7/p3JZOqhg4dewOjISLq5uflbCxbMh+aye5mpPwzDKJYUrjHtpSdsYYxXSqwClD2J54WRNIWwHabHonCCcnFKgqiGLtmbydN2Q7406hcr8cYhkiQAofgVxcT7rHqKJiEZjENRVKgaxX4ZXJq01Wzo0RjS0VYJuMlZBQwVz8lsG7WlqnevqLsQTfFmzGiaAVONUGNACbyhWG+pVsJwYRTZwR0LxZN7ZTpXHiVhBfyutJcnnRox/W3KohEC+XAw15YTSHkJqPA0lSRFfsWWXmzJLnRspEFNyimy4wjKuGihHaEZCOVS9QhGjLWvTef6S1XeNARRK3nrUKpyqMojza3tS2+8Mf03pwdO33F2aAg7duwkdNj9s2bNvL+ttXUrU5S/Eaax5eXcBoo2NAGYoGYsLaZGt9ewa6BELfXM8k2XSizP9fGeqiZCq0jl'));
    dbms_lob.append(l_inhalt, to_clob('QBKBJXkcCM9LHU3I8tLFz1FDQlVjFKdIELi9Uq2i5tgoFIo4NzqCcrWGhem56Ei2SLwEdWjPlcdh2zWpvFNp/kM1TppxtEbTcr5KpXX0Cymp7PjjlMAqvB0RCk2bQDF8oIjyIqyRfnWiJAwolARxguBf4KKEWE6NEqFmjDT7ZbNEIptdWDl18ND4P34K3jgF3YPRgvxp2RSmDpGUPn/ERO5vP4nojbd83Lyx76/w+gfmaBSRp5Mw4TproRsaXOdBEWn94Myr9Mys2bPvzU/kPnz69BkcP34CJ0+eWhuLRde2tJzDxk2b6XJ8A57+YJyxXWt6JVDnPOacvclmKo2h2C6qmo0IFyJuMsPWqMW7VEWqvJW+rOQw9Vu8+0TPjoRLkvkhkJDLir6FYwnA6wK8hZZlJScm8hjL5ZDL5VAh6KTtgNLGdFMceyYSRhK6oqFGPdXKY8hVJ5CMJafY3fqzQxDidKIFST3hp4RVf1JG5R3DVp6UeQNl2Hx0Vkg64pGOXZbqYUaTNQlR9CMZVFYvCFpZJ0MkPEpQYf3SUuXWoer37wfGDlGqpw5En4ppDpOr9LkEWN9+Dmoy+Vl7W/9W4wrW2V0itkECcwJfUpLprWSCFKa6CW2tx/oWLCBwyUey2cfvgoLPDZ8b7RkeHcXp04M4c2aIOM4+FIlEPpSMx/GTn/wciWS0CKEegIIt8LydwMSpCWGMK5XKhIjPqLJyldq6asIognlNUXAyoIYJW4tCdwmWmYQRycARJhSRgYsMFLYIrruiUrWSZFULxSJK5QpqNUuyQlLPbjLSlBOLxUzMnDkTc2bPQiKZ2gOwH80wO/4iocQxao9Jvt5ipSSpJc7LKUoh/G8m3oqmaBKnrbNQPQps+P0Nc7Ljj7OWaTqYRhGMUBNkc+/LUj0s6IEgS0hQRxlx8ZmLJgcmj0O3qM+zJCN6SeED+wA3D0ERyMC6+piioCRJamwdMU+5GabZ4Id3gy9ZRdSur3PllW5P'));
    dbms_lob.append(l_inhalt, to_clob('EDKSxNIKAcNnw7I34OzZ/dnstueoS1Bf361E8y+p/rOPP3UX4N5jVcsbRkfHUSoUMDY+jtHxMdoSYXbX6Lq2RvYvUxXJaEPDMNPGZLZLURnYBE3IzsKTVkVQWZgEi0uQDedwKFogw8DBKwFvKMNEhkfWkFECATB0Ha0tLaBQ34zOjiEI9iBU/RBUtIPb74aHJUQqkjQSGLXGUeE1yZY+Xeox3zBcFtd9ytOw2JKsX6kqcb0rmRED9GhAaO1XRUzHgrwKYYHyBsBgRuTZSgSeZDIinK4HlCsELHtZQmtB8WoyTH7ZRwDlDBBw4fRBLkhoNv/sab5Ao2AAin0D1LCF4U7C8VJ3IAJ/uILIvhZB5+3Z7NYBRMxjfWtXS2e+79YbJhWZJJt9cj3A7wAT76jVnKWlYhHFSgWObUtgerlamcTt1rFc4VhFwzIhwnzQOoFo5EUOmVYDf08nrKlhIpFIIJlMojXdDFU3KLb6GBRtPzXhhuMk4TlL4NkfdCxndaVaRlM8VcrEWtEaa8GxwgmcLQ7jXGEq/1g96hBKRyKDGYkOsLOBWyBrwRQZ6x2r5DJMoegFRRiDKk2SC6iqLl1Y6OPSJI0A9VpEWkvfBwa8/DgFOKYxtl9MjAXLvujMufEed/cviJpDjkySkJvw0pKhSlJ7QVGdSdyKtM6q/OC8ESCRdSolaWZkT4qgP4XiSMCoSmVCFgHSM+cD0kn6+m6i8phNU3lsJZxRjHTCMFfDc1eDi26o6ILLOmV0Q0Ajgg/uOH4DE8akFWUMxyDYABQxAig5eO4xGFHq23oMLckRtnDhSK9hyA6bwo5mUKt0g1lLYFdXgvM7a3at0675DOoEwKZ90QgQi5AVoibXFVnKPkmiPg3R63+ViMSkz6uEzmFQF1ZzLBluI3w+RTaIWoKGdtlM8DK5DSAXIbgdEq5PZUuK4StdML/lAy/AU3FXgAt+UYmu7fuouz27pYZ7HpCtcWVWkEY+v+2RBP+7Hqwf'));
    dbms_lob.append(l_inhalt, to_clob('PwBn14/BeEBIKHPeU9npXrcTNjUqnR8f7OKzM8o6f4+qd8NUlwNX4VBsi0VS6f7+fh1ouygYPZTgN/qj8qHLgjPtH7STYv+xdDa7eaHIF5fCK6wBw1oIsdDzRJRcDMIz0HBIr4Gt72yKpNCRmgFd0SUJyWBxWDLpUBq4ju2tSzqRxqx0l2SapCYusqpDJfacKoarE6hG28CCymBpJAN6icsiCmXX/GwEowkbbdiMyQot+TPlL84eJeu7WmzLdrMb+14y3quukRjfl7z+hS/+teB7H5l0IC8+G3hdKq8IUrDhNoJ+TtOEYo0OF5wexqKMsXodTZcMRr+YUuIQEfNVNCBPNzApSqWEArNFceyEq/I0VKNbHN6RgaZ0Q0MansgAXhSeQr4fJ8s9Ha3gD/cUFkuIJjQZMRkuozq28dIYiGHSV1654GScl/6l1lctZgoGdFRFLUCqMZTsEkaKI3CSi6HHE75PPNkp83KJCPhUgq7yhg511nzwXTHAysuSHmGNwT70HNw16wlr8aqTFURMIs7zgV3+RnAbQgY8WfkuS1n9qIMPtvaHQjXw7wwbQqRNxicsDFEh8IvL3v69ydEA0BtDW7Jsck2W/RCqrFbTfIb0MoVuk+LgUxoMI4E8PR2UsDDTjCkJwcu6qxhpSOSZl5TuC83qGFGfoiSLB2XdHUUmpvd3D4s2rRoNl2m0xtpkA27LreFceRzj5Tya483T4I2T/BuKgo6mLrTF25Ar5WW9GP1Kt7hkl1GLRhFtagOnjplMwCMXwvObf796EZOzf/JJKRmizVuAWjQFURwEc2WvIzhPboSxev0nAbxqLC9Zd0keKB8ammxQ7B1XVC5x4JLo5mh97SnzTFkk6Su2iBDVuCEV2JeSVNAX2+rysMcwoRjESFUo41VBbDeELItEuNDpyTYgNF6VAX+7UoLKqlAjRDLCwVkJiu5AIaVQuJ811ujCygqKgEUn+FO0kARS/hLWGEposIsIM5AxWxFX'));
    dbms_lob.append(l_inhalt, to_clob('TQmNHCmNYKKUm0ZCMinB25QeRVw1JkvW6aZSG9dz5VHkuAVmkOUN4rESMYPLJizMPNM5cBtGsumvlLZueFQcSi6KrsAd2AXn4I7VRA7yavdHnkkwHZQ7VVUGNexi/rpWXi5o2KFqhejkHaCIg8ylB69EHUanQuQItg1hmpqSaNdH2y5CjX4RZJmUUoKKJXREQwNFD4GNyUSF32o9Kg0/jQK68KspZIl8SLV6noYQYH6yZH66sxNmz1zXlREPSlIYNGsHw1g1j/FqCI2sFwNJqxO4H82pFrQk24KKW1+bXHgoW0V/0kaZazlbI94Ij6Y3l60XmwgIduQ47jhUa/J99eobACPlR7wEVVhbqP74W3RZfin6X10fuPPYXycrU94AltehQDRFD7qla0C3wVcYfwinSlVAZ25Ayy8pQixOsEgxciEz+lRZFGAb/M7uZS4Z1QPdZU5Cl5BIBh1UOKFQoqIWhJyknxKcFU1RgtlKWJpP1laK5DGilHHUv+B+WMC/9n56lcJwLnfRkWiXITAXZHnPSd/V32TIjONitDiGp48+g6/0fxN/l/0C9o3sl3zXYSaOKFTHq0WMehWgKU7QTon8Umo1qlW9PMor/OibMunGEbBJVPXrbtmqZub6Ezqy9JRSP3sA1a//rWar4luvapfB5DbYfXjpr6jjcEk76+vrO5zdtOVvIMRnpfVV2ISEJU5VIEyFLoIYz01WCEp1XkLGsEi2syJMr4hzjYowhQToeH5cUV4pCUT3Ow8RF7Bvdn1QzqS1DZBmoeLSX8hAI4VSteTb1J1emvB4zJ+JUujMiBuI6yaYUFBxaxgqjeDE2CmcHDmJHSd245mB3Xh++CAGy0OoeDVQ6y7DiEBVifMrcB0UTfKWjVTzYIkMWCQOQZUZ/u+X8WYLP7sWniJjevzmvnW5z94nnOFjELUJMFVAjamwn3sY4uv8rurmbMFsZjMvpbLivGmunJwqAd7vSsmlB2s8+6sQ4kHuehvg'));
    dbms_lob.append(l_inhalt, to_clob('eQk5IQoPnlwHO5h50hA/rZ3EgE9nehGh70cR9oLI+6t7BEanYs/zJbxOEQKoR+scvWGkLlyHvgiU9DypoyLrGST5iRhz7Bp0REbaku0w1AjyXhFfeeqbeMcXfgfv+cYH8V83/Xc8dOpRnPAG4cUUmMm4ZNBRg0sqIZBBOIwAOkQ4TdVKVLvmD++XcZhlvusyFcoQTvuNm966FW0L601uiJoppsA5+Agm/tuHk/ktTxesbdnPXso+5SkEEE86p8vowr8iueQnv6+vL7dx48aPaEokWi5X7orHot+AqhyoT978U/HbWdmARTc10OIXcXvb4McaUimh5X3d9bFgkO6HBps2Tc0JKVwV8EMQUl1WLRM4hzJ9lDOmeHNgeYNs17SgbMBsExLcyNKyyfoyPz5bcxwql9vfHk+vJz+FFhp2xoOSGg1xOeL7yQppZaf40ZMis6bU46KM09VRlFOzEW1tgcgPTA9VvEphAc0UoyYtKvnTEnwn70P8lr51hf/5NWF9exCicibI+ipQTQWifBTWP30CTtfi+/Kfve8+c806qPH4ZxQVm1gVI1CRgxW024p5jgNF1wln3Sy00rYnJx9A6SL5ftfr320IJciavS27eetXShP5DydSqTsh2CdhqoPSB5ZuQ9BDIhBJHN10YROcwf7B5KFRsrqjyOcJFElC4WGbuktpMJKB8pb9o6begkTbJP08pstXWUFB02Bq0UMJksAMk/mb5NIPEeN+ssCfbAXKy1R4NNF0CWtE5RuJZNxISpyuxYIWc0Fowp/dTzZsmWLFw/Ig3+slvEW1UsNEuQhvRguUeDv1KJLYBqZNdvl6lSJ85ZFZu2AqOaXfRfKqnqXebf/nfutnX4XnjvvnKlsiqVQFCDG+H7V/3Qf7J18AUplPIJb6hOSTCbZHBIIeMczLAY3Mk4CYOAtRofh66HlJY3FF3YbL8qT03byWEGSPOHbthyOjY1/o6uqsQmgfh3Afp5y4dFYp3BWPoVwu'));
    dbms_lob.append(l_inhalt, to_clob('86am8gXbOAR/oia7AeUlYE1DqQTBYucdo+H3d6NOmJzKBaI6nEoVikmNA2V8w0/mS2Z0UlouuwEpwpLdMmlEFV6ROBYVIKqqmkZdgqgXjFWqSPRZtVpFLBZDuqVpoCvevtpkJkYLEzBUFXokAkWnVGmopAF1kwzcE1hI9g0HswVajGYsbl+Ja5eswB1Le5E4dAL24Bk52aGIhhBhmcirE0Ht7uATQ9MzKou468QDYGtuO2BnN18nPO8Z+6f/BOGOS2bTkLNCWm75GFkQpZNgpZDCNEjCkB0KWCHpXH26swCGKU05g6DYuHe5HsZXJpfNzBOCrL+/P9U1s+sep1r77Fhu+P5UKolYIvYIY+yriBh7eteslpmd/r1+mGa67zsKjLaBFUYlDb+IxzRmtESRs/wkhahB6J7DHFv3U+jBpI0aBRFfLz34tldPlsjWWj6+dUoZEE1MqpKYhBIEitJdq1aSuYk8ymVisNLQ2tqCuXO6N0Fh34RtbZnf1n3XO3vegtZkCwF28NDhR7FzbK+84a5wqVWrRG0xRyCOKBY0L8Dqedfghp7r0dXS8VUW9T7VO7938JNPrhOFB78GPrwfqkk8Ch4FZS7L9ReVqmSYpEgDkefJEofo9B5vRt/NO8XW7PxiS/tR63t/D1E4AYX4eUO3Kkxbyz7KYnrgOAASyQj15PdT4t30v5+neuO4DedLkGAgNP1fZR9//A647L5qqXxHrWbfYZgVZPu3EGPjg2JceSy7Y8ee3uXLJQXq+ULVFP67qG8RKMxkMy6baOsBIH3qCEWWQ5UmhKqKHTisCI0l4Xo5GQCRfeHUJOBmALGykC+hVCzJSRnxAmfaWjCzs+M7YOILfbfcsv28w5n0lrPPb/rEnnP7Pr3l5NOy1WuTnsDcVDdWdS3Htd3XYE5m7la43kf7lq3b84/nbcQePAWRH5L5FFllbERow9PASpcqQkJMlMk/yZehU2vw807EL9dh1pbsePl//1Pa2fUL'));
    dbms_lob.append(l_inhalt, to_clob('KMR1RrZA0qYG5fkBuGgaM6bUWT8tQRnCcAEfVy+gzJpH04wrWg70a3tS+m699REA9IdsdvNqKHgfhLhnfGTswzWbf5hoGH7y8C8Qj8fpku0EUwkEfhgajglPH4DtFuHYHLZlsbhmCaVJg1asQktHYXFNdpM3jCS4Y0qgEEcCTGsB57PBRDc4Fjou767m87AsC7VqTboGVNLe1NyErq6uAQj+Tejqt/vWXthi4KLisgM3dK1Bq9KGZd2LMbt15mMQkY/1LZNE2i8paqb7Ia3nujudJ05BtMwAu/oG1Dxx/2W41DCuuwXukz+BO5iHEu+A2jkXuoMXzcWb6/pa7O0bl7i/+6H9zpOPwnlmE7UIgMsLYBQqlJPZIOZGbsjUhGDImB7MF2Tj8LmrYVy/nka2K0bpLw8FV1gkI44wlwDeGjCxHvBWc+52W7YDTqU43JaTHU1VJV6AwNuUpfK7V9ZHM6q79EmkfcSpxPcGkEZajyp69YgOamuhMGUnVLEJ3NsKxPb39fmk11dSxM5sumrhE6Jc+lPEEjmu4m1NN/ZtvyzbzmbTZa827h19DlrPYpoO9Cq3vPLeEOLx7B01D19wBk/0kBKL0SG4VQvMIQ/Opwnwwh5yAdWlUBmU5ibo85dCX7zy+2ZNfJSdB3t90ynvS8nGjRszzIh3w6t1QtEWwXHSUKgRWthCIIwYKNRAmLrNV+GpOajeKTCPGhgWhVMpMtOkWp8chfNe63NqSEMa0pCGNOTNI+xXrkqooQcC6UmyO3qlrKen0Uy/LiEXnp/QkSgwppwXxJ6yjP95+s+0nuR/JjSWxwN2smCfhGMg8WqazCzQR1qW9hW+Tt2dovkEfV6wRzqW4LikyPUJMRP8HsL76F/JNEnbpd81f/vBofjeTHDgU/d9MXggfU8lxeE50xLGlCsQ/qZwSshwul4CnNgvg+0H5xxeOO28tMDkcuftP1iLrqW8F/6ydE7TjnGSa1uDv89wWTouOk76Tt6H'));
    dbms_lob.append(l_inhalt, to_clob('KSfgheUaEf/YBUb65hl7Xn/RhmolCTX2AXhiKYTqgHGq8ZYcYELxyA8lthr/ItJ7qmuT8CtBFyoqqEzIUy0/3iJTufWL7BJBiGIGYBU/kCvAZdSGmgPSq0NRdE7rRSF4EhTkF5RJI3K9oD2sD++nRAR1OaGy+MneD5OsUGEm15PHRYVqJTkDDG+qD++U1R/yaKjrkVR6lQcoumA7wXQ8NAHyvMGDKH7A7xpomjwPqZwB2o35Z+nXwvtqqMsNcQidOg4Tj49PZeXDJfxlGF0DepppP5LFhuLZUXlcFNcm1LlgutyPH9IisyEJKQSh8fzYFwGV6tRYdP0E8691eH0CFmSZxVBJaUPyEdXvAiXvG72n5QR1hcvB00Yg+M7+oxMjvfOb3zSEfg1pyOsv2pDN7kxDjayH4m7wkYmqBk0/jCrxybvrIDCARHIL65q3VQwc3wDBZwNNP+q7sWNg4+YjS5jKvgDPe6xv3VWfedl9PX14PWq1u2WvCUXfg6sWf7Evw35jIwrZx/fegZh+rO+3Fl/x0N/rQS5DkqIp/cyOXT/86cZ9uGpeBvFoBCtXXYWDhwfx7HMnkUkbsrnfu9+5Fi0tSfzwR0/ive+9fR2A36U+kF//50eTv/+Bt1Ae7SWVN7vtRHdhZLj/c3//Q8yf24FSsXr3nHmzPp3d/MJHoYoDYN7d0PBz2OJDfrmPsgssUgSz04x1fFEgtwHcaUYt+jC0iQ9B09fAwf1Q+Howt90fDvWdiER3CgfDzPNKUKy14GINhJiAiv1wdQ7NGIDrZiCsewDlAFzsgeqshHCpZWwJWmwQSuwYat5hKHw1mEgz4R0Qmjos4k05lhtdLXEIVsdOFj93Fzysg0J8FvoAFPcucN4DJnaCONPhdkMxH6OeyVDpvbenb/UCmVDJbtl36Gv//OjCTFsTspuf+5e+m1e8f/JaPbHnlx6UDQpEr++TV74OD58CEpsQ4V+Bom1ilv4dYXjvA2MZCHwVCnFo'));
    dbms_lob.append(l_inhalt, to_clob('qEMUd4fjrIFgm1ja/Gbv8vmD2R0vfAi12gYoRD+gPACoS+G63++7ZckVTUpcdsu7ceOBJf1bd++Pmkn8v//Z75l39Pgwvvj1jZjf04V/974b8dNf7MbX/vmXeO/d63HmzDl0z8xgzrwZb3t2z8Gfnzg+iH/4H3/wsseR3XqkJ5fLHX34Z8/i7/7ygxg8O4Yvfu0RtLYksGpVD36e3Y211y/Cd777BJYtmYVli+cgl6tix65j+Mh/uP2LubH8PccHRpBJx/GLjc+iZ14nli/rwZPb92H/wTOYNbMF3d0z0N7egiULZ34f3Pv29h0HHtqx+xiWLp2DRfNmyDpTci3PDI3i6MlhXLNyEeJRHU9s24+TZ0Zx9cIu2U+5Z3YGc+e2v6cwUf3h4NAEcuN55Atl3LHh2u1nh8fXVC0Hmqbg0f7nJN/BTWuuxqzONmx8YjcGh8exfu1yRHQdv+zfg5vXLkPPnFaMjOYxZ/aMj/atXfLF7M4jPYNHzhxNt6aR3bwHN9+4GCmDzyGWIrpW//T1h8XB46N4+1uu/xQMrfPb3374wx983+1DUM39n/rLb2/oW7ccN69b/rbtTz3/8207D+KPPvquTfv2HV0/syuDJ548jLMjYzIRsWTxbNx888rPPPrIU584dHQIqVQT3vHWa7Fz1yG85fbV+1nqqht7lxvFN6zlZRKEruKxzfskCnH+vHZcs2ye333GcxGLGlixrBtdszqx/9BprF7RiR07jmDOnMyn9zx3Cu9823X4h/9B1mL35558cv+fPn9kBDO6u2FGTTTHFKxePvsxlvbeIyS3IwJguYdZXc1Ye9MSPLrxGSxY1C0J0BNRA2+/bRX+w+9tQKVSw0OPPAtHUfHcnqP3zJjRglKlhuGzE1ixdD7+4PdvRzJuygdpx+7jWLa4a4/r8ZU7952kyV0XFCMZicbxzrfdgN995/U4ceocnnrqeQydm0C5auPdb7sBG3pXIGJo6O5ux/bdJ3DDNT17'));
    dbms_lob.append(l_inhalt, to_clob('xkZzK8dyJZrY5ITrwHMsaJqOQ8fH0H34zBo9ouDU6WFJYfXud6zB22+7Vmaxdu05gqVXdeP3frcXK5bPweath7A9dRxnBkcJ+I+mJqIo9Wf2zOge6eio4usPbMXKJbOQakp+HBrxnAY31YjiyLERZDfv+gvC6eTzchL9zPhE7s7rrr0auXyFSrVuICYhIxLHyZPD67ntBbRaKn7nrluwdnUP7v/ST3BuaPQTFBL52H+8CyuXdiNXqOCZZw7SBDv5osDsN4ryCl3TqGxqxoxmXLdqHlrSKQnm9itv/GmyTOe6QlqTrq6OPRXr+ZW79x1bTWClltbMe2gZ5tb+9qZ1K7fedDObDYWgYrKL5hAiys7e5XOL2Z1HMv60OwSZ++lij/tAEkKE1WwXP3tsN0bH8thwyzI0paK4el4HxsbKKJSqmDe7HSsXz8KXv/Eo/vDeL+HfvGstOjpbZckP8YbIlL0PsKrCZVaxZCG7+QBy+TIWze+Qiehrr1mAfLGKB763GY9vfR7/x3tvDlhkaOLuSrI7TfJdJ4oOJ64HjuZUHCsWd2FsNI/RQgkRXUVni4lU3MR3vvckDh8+g6vmtuHAkSFs2rIf7333b8nikGWLu1GtVnDk2FksX1ZHT4riC+84dnIYuioQj0fw/POnP3v1oll/kd1y8Jq+dYsPC4p1xVPo6MjA5i5On8rT9Wo5fXoE1yyfgyc276eH6/8huv/b1i3F0eNnUas66Jk3SwZd6HpI8sGOZvCajZGRAv7hy4+gpyeDt264FjbhnBSWhsRfv5F9XtkT2MacjiRuun4xHNfF2bMTAbZVYDxXwtbthzB8dggfeO8NFF762xkzWr716Mbn8PY7rkHfuh7JX9brU51OcpldIAQXFa4k0SM60qHBCWx7+hBmz8kgbhqwbFu2YL19/Ur8wYduQ7lYxaYtBzCzPYX2jiS+9I1f4p1vTyGaiOHPP/5ePLHtIDZu3o9/864bwyJMTsdbI0WmTpmi'));
    dbms_lob.append(l_inhalt, to_clob('1tMUj+Dud/0W3nnHapw6NYyBk+dg2S7W37ocS66eg//1/S14evcxzJmdCSNoGjX3Hhkvoscu3Tc8UpCQSUJnLl04CxOFErbtOoGVK+bCclxM5PK4bkUXChM5jI5PYMmiLiy/aw1WLu/G45sPIBHVcNW8OThy9AwO7D+D+XM7g4vB7iLr/kf33IEfPrwbu587iauvmnWq72Z/4sZdG3O70li6uOfPCB85dGbss8Vyde1zz5+G9sIgTg8WsGv3yWghN4Gb112NWMLEtx7Ygquvniubk7uei3MjEzh6cgxrOzNIJgzc9a7rce0181GrWvC4S0qeVIW+JJvdebivb3Xujek2RBSemdGEHzy8C//+j/8JiVgEN103H6bB8PNHnsYzz+yVDC7/8Q9/G/qyhS04PJBesWQunn9+EMuWzJGos1ckCueGpmLgVA5/8onvQI0omD+vEzdfv/j+QqF4b1uaKuBdbN16EKdP5TB7dis6OprRkk7QaPBn16+66tOWw7F1215syj4LcgnW3bQMimdvb0spa+A5OyOaljl1fCz5pWdP9fzWqvmfm8gV8eS2F/DM9kOYObMZ6eYmDI8V8aVvPIpjL5zC3DmdWDC36xHh1e6IUJdlYKK9PfWNvQeOf+gL//jg3Quv6sLtfSuLuYKdpFGnvaNl+6ozuTUL5rVjRiaJXzz6NH7y8Db09MzEooWzcejIEJ7eeRRz5rQhEY+gs70ZsXj0U7f3rvqLM8PECUZ06hQbjv7ZVT0z7v7SV34GPRLHWzespCTLnu39R7vW9M4fbGqi7vZUPOdwaF40ndRx/MQoVq2Yj6WL55BC373jmUMrqYG3qrDq7NmZP1g0r/VbpqEgnYrgpw9vx6O/2IHrVi9CW7rlY8mU9rnvfv8JPPLos+i7dSm4K/D9n+7Dkqu6nlqxvJP6yP093ogTNuJZEMzrgY0en+jZcSCI8I6sstuFKNOEaNl/25qWA+E62W0Hu8G1DGI41rd6wSt+'));
    dbms_lob.append(l_inhalt, to_clob('ajduH1jCHHcpmJeBoQwgPXdr3wKWy245uBCqkhbcLDKTL4KnUZXFIIzYAGo1iJamHKuWk4JTl217hDn2etl8MJXZCasKoVQSzIsFrOFqJ1yvC4qbA+NEXtINLpIQ7oBg3iBLxEqo8Yxsvg37AGxzADH0gHFqEztAYavsjucWouL1wFWOZVjb0IhRyUAzk6LkDbJYRYLEWSKVExP5hVDdpVDM/SweGxI1aza42wWuORDuEEy1KLxqTkGzLjTXBGq58Hr103UfH70VbuSUiKsOUzhnpdQQNWHM7ji4EC4dc3SEWS4XpjUbLMGhekUUqeShXEQs5jNGViZGGEvkoOkrhRZ3BC8Wmce6Zf1+tGkrK5zlIhVdiLyTgaEnDds97OgiKSJaJ1QtxwzjQO/yrkZCoiEN+fVhG47aXUL1PgBHLPTTroLSjZS69Xud+eS45D9Ocgf66U6Z1qyT8U2t5g35C6gXE8EcwxZTMm07uUxIqRqmXKn1jTP5vSKisjOQv4wOJvcf9Zuo+KnP4Gwp3emnVicbfcvjJf4Hv3O9rHc778SnrUMpY4nM9lOzIZmJX2pEy5hBeti/Nj6XApGf+fgImRSWVDqUVten8fTSNonrLaiJk+tSRbBM3wbX0gtSwmB0Dfz0rExBy3WovMk/T598pCr3IY/Bc2TLIJ/VKOA5lufgX/vwBsrrGtwvSrH7+6CfcwHHE51feL1CSlO/apv6PSviEKrOd/oWNw287tyGjQP2EsXmLXS5BPU2C2UqM6tsFzOFalgJTpZOeurCquN/p1JlBHGKvVT1KVXyhF0wp2xTfuZBexqaVDNdKMFxhZ9d4dCrvx3uH/fU5eXn4LgcZ/o2wv3RcZrh/vztyG2EEt7QqZ9fTAjcIgMmev2YJFvzhad8wbWd3K5DWAZ/Ox6dg+qfAyVS6Diov4Ye/KbQhynLhaLXN3UBykeuS8cXXq9XMk3SIUwUb+s2Jl3EhjSkIQ1pSEMa0pCGNKQhDWlI'));
    dbms_lob.append(l_inhalt, to_clob('QxrSkIY0pCENaUhDGtKQhjSkIQ1pSEMa0pCGNKQhDWlIQ3BF5P8HYCLnhcFo/2EAAAAASUVORK5CYII='));
    workspace_datei(p_file_name => 'thg-logo-edv.png', p_mime_type => 'image/png', p_inhalt => l_inhalt, p_base64 => true);
    dbms_lob.freetemporary(l_inhalt);

    -- thg-logo-tg.png (image/png)
    dbms_lob.createtemporary(l_inhalt, true);
    dbms_lob.append(l_inhalt, to_clob('iVBORw0KGgoAAAANSUhEUgAAAIIAAAB4CAYAAAA+CiqCAABH2klEQVR4nO29C3Bb2Xkm+J1zz724F8DFgyQkki1Raj2aeqsfsduOqLYTezJOZu3Ek3ESz6yTiVPl7DhVO9nK7Nq7dtVMKju18YwzG89mUhlXxZkkU/HEdpJNeh07sZPYIhS77VY/9CT1JimRFAESjwvgXtzX2frPBUi2RLW725K6PebfBQENEMDFPf/9z//4/u9neAOKlGUbkKLaYVa6AwQd6ebTLKwuA/qwFEGeWTVI029J02gzbyjHwmIUu7MrLJwdOwzZygu2gvD4DlZ7vX/L94oIvIEljONgboh71eqE+v+JfczpvVSbrNeL0r0qABtL7Vve9iEmUjqKe3EGw/bxq+Wpiv26Hvz3mHC8waVaHaJ/AUyjUiFLAVSmyvbEGeDIZRFuuXLLmyhNKAWxU8wrQpr1+mRxXL1vU16pMLxBt4YWYjNwuZX2pUhZ0gxCZuk+wi6D47cgpI1iLoaHAqswNjFfrlRsuRK8E93gSXTjL+/rdk8NjVeBIYCxRFE25XtMEeiKDnRmBQxigEszDGHVBdzrKdaKsTvgSFmxv5xl86V3R83Or09fnMPZ6Zs4f34Wdorjf/rg27FzX/OhMQ0iPTAxO1Wu2PsmSpvK8L3kI5ASuK4Uw3nSUekwdnx2Usoi2u0nsBi+N3JaHz519ixeOD2HK3NVXJtrod4U6PoGZMxxcIdEzQmxLRcXtN5nkhLQtlLqbSGbcp8UgRZP06Sw7acq/efasjwaIw68KvdoAWSlbDd0KXSdWZ00HNr26fn66cliowGkxlAcGIPtAW4lzyqXF948hnr9g3/1zasffv6z38T56Zt4cWoJF2dX0OowyDiNQAckK0CDCRgM0GK4WhdeFKJu8PqtDjD54vy7ENfsVrQyK1fKC10uRWywMJ2emL0Xv/37amuYXymP0b1J3mVROvnkrWF/731OLTqE2zjkHC8UVkM2'));
    dbms_lob.append(l_inhalt, to_clob('WZ/cBYOFuBm7iwsjaPCC99DuC2Z2mI8D8QrAFhg7XpucOV3EcnYMzPzw4tLyh56bmsfzF27hyvU6Kre6aLkAIgYIHUJLAZoGxhl8IcAiDVooIbUQEe+iNODjPe/cjwMPD2Hq/CyuXV3AO35wDG99IvcLjx9gX6bjitNxYLM1pd2UV6AIUp4oNcBss2c9IrBW/zW64ul+sQU4nOt2HAejWa6nk5cFytudWTQwm28gnwdGxlg4TZ8ZHNuFSvMYmu5Hrl+vjJ07dxVnLsziwvUKlhsBWp6JKM4CmgXoTB0l690kiyHBwGIOcB1CAlrYRsQiBJqAJiUM1kHsewgCQNd0/PxPHsA/+4m9nzi8s/aJIGAhOZClTQfy1W0NrRbQkhC04ppgXsoCGjUIZR04o2sVexZZ2ElD13LMbgWy5LRQiji8mxOzV7vYC+YeHm2sdN6/+Pzyh89fpqv9T3Hl6iJmZ1ZQqUfwQg4YWTB9BExjQCo5MBnTlwSgO3BaeAHGdTDJIJBCFASIunXIuAVpFMFkAUx2ESIFpoVgIkIQe6h36BMyBwqFQ7W1hNWmvCpFoH3/9MxkaKRZiC4w2AYW52Lz8cfXTCvF9eb2OMiwp+bLUlakd+MY2uGEvGF+5cLlOZz81lcwfaWGa7MOnHYMV5l5AxrLQ/IUkKLD4JC+hOQMTIa08wAaLZoBJgEWhUDUQRT44HEXppDYUsrh0HgBO8f24/w1ia99ax6xxtRnxlIA0geLQ7ieBLh2dEGeKI2wpyjc3LQGd1OEiizbdzOXzblSmJPDYoSdDbs75S6+hbnl9nM60o85E4w5U7sOPYK5zrsmz8997Pyfn7Ke+fZlXJiex/W5CCsNFwEMMD0F6AOQOoOmJeY9lrRAESRiaCGHJnXabsAMTs8gCj0g8MEiD5YIMFLS8cjOEo4e3InHjoxh//g27NyaRttp47f+6BlMnqogYHnKTgOSg8MAYommE6Hr+2NBh+ub0cPGIqbK0h4c'));
    dbms_lob.append(l_inhalt, to_clob('P0kXXxGA0zedJ6eP4dB4WZhdlFy3Muq6FSczwirTyFRke/QAqun3uSs3P/Tv/stX8DsfexrTl5Ywf6uNak0i1rJg0BEJE8zM0dWIGBFiHoCRveccUgpwpiEOYwhO/h9DDBcyaiHuNJDWQ2wpWDi49yEcHD+AowdHcXDXIEZHhlDImJCQau9gMeBxjlRWg9Q55aUpOQ1GFoYlidO2G6HdAarNONjlszdcyPxGEEFK0LtCHFmesltHl8zLiHFs/KQOMIeZExcnp1sWvMrPBzejf/nN0zdxduqvce5yBbM3XbQaEW0g0IwMJM9BpoW6qsEiMHLayKzDVDE+i1OJfyqZcuoQdMHCLqQMkMr42LqF4eGdQ3jy8AE89sh2PLpvO4aGLKRSBgSPEYeh8g9YGCBiDFLGEEyDEEAxn4FhMHgBVEQh6e9UBl2D2w3guh46QVYP3I73ep/0N6KIzFBiCWRZ2oifN1+IjoTwMkcX55rvry+tfOjXfudr+OR/+DNcmalifqmFVjeGT6aXnDttBLANMOYiiLtJ5YLTFUm3CAht5eprtBGwCFHYpcwCBHORMUOM7bZxcO9WPHZkBw7v24bdO0rYWszSR9L1DCCgEANSumCxBq7Rxawpcy+YRMw1sFhCJ0UopGEZGpodMmkMUoUYnLQCLbeLZtuF9PJmad/j86/3SX8jirDUhgqwCeZMfutiaeXZ61d+78++jenrPpZuLMHxAJ8ZgGFC4yUw3QLXYsQaGecYkHRF0weYYFIDDxgQh9AkRaYMQbcBoTeRTQcYfiiNR3Y9hCcO7cHBA9vx8JiFrUUThQzFAMnfA75abAnyE3QwJsBo0Wl9KWyke43CR/o/WnMGoQH5rIl0SmWY1PrTP+qwwNHt+mh5PiDEZrRwFxFwyT0nk3Ci9OIpf/SbL9zAX/ztDbDUMERqB5jOICKyt5FajJiufMbAY1qMGEIyRFKoRRJxCN+rI8VdDNo6hrdqGB8fweOHj+DIflr4'));
    dbms_lob.append(l_inhalt, to_clob('EoaHskiJGIx2+SiAjGJofoRII0dBgEsOliQMEr2g1SRhiRLQvxRFSC4RQkKQU8gY8pkUinYG1xZfavnJT/AjiY4bAF6qdLcT8f0ugvVSrVl10mK3MJiBmcohSFG6yEdE16puATKEDHxIESU7QBiB+QHiOITQfOTzAtu2pvHE0UdwZP8oHj04hoeHLQwWbRhkoelLZIgwDsGUYjHlLDJuQjKqCpBqrKW46E677f/XC9mjxG4EkMyAaWhIW/FL/oJR8okzeN0I9aZP+43KkMr6ZLGaZ+FmUmlN1nnQLJTMcrMZAV1o6IaaCuc0FiCWLUjfg+wG4HqIjB6jNKRj14489o/vwdEDIzi4bzseKpnIWylYugYNITh9PEUJMlZOIwlnZD2U7VYXPTR6gSwEhXvrlnv1YX/LWCfKWNA7KAyNIWMBoQlk0zpAyQ7lkCovVSlcGEq02j4QhUoRoEmhN176kd/vIqScLFK+Hy0pmDC8gUIRKaGj0SVz4UOXyygaNewZH8G+PeM4uG8b9uwewvbRIYxszSClBUjROZdSefGIY7BAUtZRmW+1v9M2otayt6B9cy8l+XI955KkXy/8TkLflax17x9YukCpSFUQusjpgOi7YnAmEcYSjtMFfHkAffO3qQgvEUEKoB553GPNtG6nQ6TIa48CpFiIf/bet+Kf/+Q4hgdtFLIZWEYEXRmSEEHoIe7GYNyABp0ud4Aye7RI6mqMlHKoUC7RhMR94z1DpCwFhZ+J4/dq0BFcUh2KtChRMkNjyGVTSvHoyynMlIysDikiKYJPSnO09249n8dmGLlOOKLEWWSlCSdOh0E2k4Jp0ImMoMkYDw/n8Oa9WzE2oCFrxNBlBBkHyuJT5k7XKIpIQQoNkhJFtEJaBMnDnjZwZR1IEZLC0bp9nNFmIEAB5muDyCSfT+UJ8hGK+TTlK3tWIrFSyimVDN2u0pwRSpZRhNlo9C6ATVHCWeH4atmYd4SnpYxT2awFGZrwAxM3'));
    dbms_lob.append(l_inhalt, to_clob('ZhYT0x2Rr6chjg2AwklugAkdMWVzeKzyBIxqk2qb0MBjCvvWW4J+fqH/uLdY6nWexPyvUlQcwRPPwkrpGBosJBnH1dd7IS7jaLshPN9X4SNVOl71l/13LrzvRdP9BMG5BDuVSlMSRyJiErVOgK7USQ+U6WdUBVy9FpNdPcngJcmb5EYL1P8LCgfpr+jc9xJC6vk1E/BShXklknw+hY1cCsQaObgCQzaDpb5XU5aBnEmlDJzD7QKuq/wJYTWkU1h3AWxKH8WsrTeT3Vk7nSRxSBmaLS9JxvTW93ZZt5yvAwSSnNHkOzWNI5cxkTZTibHpH0rP0rheiE43hHKMCZOwKS+R5Cz1/ISZmckiIr9SzKURRyFiLtBsd+G0XOXUqf33DSe9nCPnSJMipDRwSjVJiXhVNzltC3DaXZTnO2PkD73eR/1Gk5dszLrObMiOl7dTSfgXk0mN0fG6PWsgX4MZv7+ijL2qbDEYKR0pU0Os8Axy1feg/wI/Rsv1Ib2u2gY3ZQNFaCQgRHBOvn/NKeYscAUJ42h7EVotd1UR3jiS5A+ScJSrUnY+Z8LOUqaSHMTVoFSJH5JC+0AQqTRzv1lmUxJ5ifdsmpR8w+zo8ACo0E9RmOv6aHW8Xtbv/m0NsvcfXb2RusKTEpP6T60n5SSShVe5AiWaCg2pIjp/q4ZvnbqORstLytBkuRRkIfl7P/CVv4MwHOsjqu/bj/keFHUyCux4jTKMi4vSQXpPccCeh04JIx7B7YZwWhTrG723KCDhPT0IUoCAahlMQsRCPSYwqog1BTThmlRBCKMcBROg+tGtagdXb67ghfOLeO70Il44dxM3ln04cQaMGYhV0YqqEXS4EbpgaLkMCKOxri5Lyx0Wnp6ZxEiahZuIpdssgmWxEA6v5fNZGIaGbhfwugFW6oRRJZyKAi3fc6GrnrKVMo7BZReMElKUKNI4fK7BcQOsNH1MX63jhTNX8NzpGUxda2FxqYlGi8LcDDSRgRQZ'));
    dbms_lob.append(l_inhalt, to_clob('QCOw67qwoZeyjAjJ1CV8AxuJAuYFIRSymiAPm7JOEVRYBaA8v2IX7DRymRSaXoRIcjRbXWUHVLLovvmJyTYQahoansD8UhtzM/M4fW4ez565hMszFczdaqPlk8UgDKQJLnJgOQaNccg4UhaDtoIEFrXmQ9Ad1Rto24CUB9PLcPJabDYCHvag99/38hKLQHtnucMdLrBgGWyEnosiDZV6C14UIZWUEl6x0J6e7OvkiL78dkIOnht08Y3nL+M/fPrvcPlKgFsrLfi+DinSkCKHiA9AUk1bqtoWWESqIxXqmWAocRwnOMU+OkkVOZPvjyKg46m6xi4MqlKJutvcFhIRk7JeZMiHhEamJ+RARTDHmh7Ip0fkjZayCNXlBrp+gFTqlVYHE+nXF3pr8bLCyRmMfCwsuXjmxTbq/hYglQdPRaqRRUoNUdz/MJXnTErbCpuY6LMyAtrtDm3ighLSqeMFCMNohAg3LJ+FweFX9XP+uxZ+nBVqfSWgRAvPRh5gnB8s5JIrj5wsz1c1feWN9wEkfZG3VZZVdp/QTOTl04IleQf1WH1e32T3b2sfREWitGUhk80hZtSbwBHyEKHsKmSUJn1oMgCnPIHmQjIXUnMRk18gAkTU1KI+pwdcVVXIHoZRGnBbFDk0cY3LUjDCrE1gyprcYa8n2D4HYfyiKu2zEDEMrKx46HYjsFioHkQZJYscS0IweYjitroFUZeWX2GH3CDGUrOLb56exeXZBC+q3rNacHqpIkjCGEqJlC5h6C4gO2AU+oU6WCiooAmN9gOVLIrBIgEeG2BhcuOxrkAvKlJgulIEUgeNSWhxF9xtwq1V0Kw30Y3SxXqYtOttSiIbx9Jad74wQJdvBzLKoNXoqq1B2YIoQszi5NZTI43MrhtjqdrEzGIT5y4s4rnnLuLszBJWlhbxv/ziP8QvfuBdMBC9LPRE0zRk0mlks2ngFtmOBP1M+kqWiSDs1CORPJ9sEWShqGtCObFMQ0jVyMhD'));
    dbms_lob.append(l_inhalt, to_clob('HHSAyIWlR9hWEnjk8SLe9uZHsHN06+czy82FaJlv4hG+kyKwCPViLg/E1IDC0Gp3sNxuYwfPg9IJBE1pB8Diko8rMwv49rNXcX5qEdNXbmCh2kCjTZbEQqwXkDV24FbLgC9jGJz6EgiqtlYsWv1O2umFQC5rwk6ngNhVvkGCNqK6QdIBzblEHBEWMckRUBcF+RYxdbxGXVjCQzEL7Du0BU8cPYijh3Zgx7bBr8HUf5XtDE+NT09DJzz+2GYper1seDIk19181k6cbg1ouBJXl7rQrAauXFnCC6cv48LFW5i+vIyFShutThahNMFTWUDYiNMMTNPBpYFAxqiudBFR72KCP9+4SEklZc5gGgLpFDXCtHto5h5WgZRA+YJd8KiLIKCehhAa8zGQ07FtaxH795bw1JvHML63VEMq+igz9C9P7B5V4NyVlfIYn5UlbWnYsZ/au9kSf5tsfFXEsTMwkIKZDuDKEJUGw//1yS+h2WxjqdqGR82qLA2RKgJ8C7QsXY1J6Bar1HDi2Ev4kCFHp9NFGAaQBFlfXyK+TcgqmEYKhTyBCpd7zyZYZaUMcRc681EqcOzczrBn53Y8dmAHDuzZCmFpv4DBma/t2Nr2ZLdloi3N1BUmOuWzYxUZOyaasNLMw/5baksgzqWJ0iadTl8EQbfWdwervsdzdS+b0WDoEToh0I51nL1CAK8CoG+FZpBxDxGQv0V0CRThKTAIg0YxHTl5iBCR48a7aDpUApYopBJHkeoJt0vyig5D9zBYoDyjrkJXiaCHQ4wQxz62P5TDx3/5h7Bj//C7kUtfPJ5jF6Wc3AVgVwg8UnfkVWrf1w1ZyW6n99Wtsaws0ZbmxsyLrNhckCdMH1ObmIR1QpfabVZBirSoh4VMCmlCsUa0aClowgbTDcQsSdcmlV/yzOlmqEWksnUsyWunok+CXCKow4rTRr3prjaprIFY1sNakscEpc9ldQhO9YVVdEniqPa2j4Esw/Ftmf8PcaNy'));
    dbms_lob.append(l_inhalt, to_clob('+vRkcWGBOihx1YOc7dioDKQnZqmdv+GzEANS9JVAkvYCGAb3dvQyqZvyMlvD8BaItmcsZK3MCOopxEwokActhkbhG+lPTEkecxVSnDQlJWElXcFM05LtQmpqK1GVP5lRf77RzkDZB1p3QYpQsKBrRHLR603otbYR5M3vStQbicPPzp4NmyihcdhyrjRmgXwBpenm6pW+OFcKF+dQ0Y4umTxgVo5cjyr3spsUjN9ZEQjuz9NSIKUvWZnUCKSX2G2VvNEgpI4wIi+eqpE9rKIMkzx/r2ORsrwyDsGZrqiPXC9Grd4B2NBdIA2UBErWXAiOnJ2CYQTohCoDtdqoQm/tBjGabQ/EuzSx40hSH5HSlvkxQbXFfWvsrIqmU+YswWpZHYMI54O2u08luDYTSa/IIuSooUHDqXy6eVREN7E1n8X2sVEsOwwzcx44lXlVs2oKkuJ8Kg/zxFrwmDJ/tHcwSF0gVBYhRqPZ7q3o2lX+EiFNiCmE1GDnDAiDGmXI46TcwWoDJKKIo9X2wPSdBCxRitDPjPZlYeFEaVlyy0MVbiAdKcdcNpcOj+/bdA7vJnd4bXlC+UKa8K5+9gM//ib81q/9NP7b//MLs//+f//J33jP8b3wicWE+2CcUn3UCk8K4SMKPIRBB3G3AyMOkBUSkvgMqAk1kGg5HdUCp8pEd7EKKifJObK2CcOifEPS+6AeKOCzRrUCNJsupGUVyRJs9EmpPLceysniwJAsFseYjdkG0tW0XS5v8jPfTUS//NwXltDOVZ6rlFv7h962Ix553h3DDXv2ubHiQN78FcGpmyiDOIyAqAawDkxNYDhv4+HRLI4c2II9j+yEbg/i3//W3+DKTR/dCIq3IIkXaLmTbOGaaUgg6PSKECEKVga2SCOSRItmgEV64m8gVgDk5VYIBKlHJhh7kXgdTo4DEyXmzJyeLM7u3FfqXJp6i1yu/n7UdlDa+fAferubH28PySJiIoeDQ/D99f0cm/IyjR62'));
    dbms_lob.append(l_inhalt, to_clob('qZK0zk50bBmgKAO4xUwKsr4EbjWxbUsWhw+O4PChYbz50FZsHSh8FWntt4vbr02vGA7Y5eJ/MvXg7bTJB0GsogZqYzeUArwM5I0zWKYOK038R1RzoKRSvz+BKQdyudYG3M5In9eh/9Z0s2Sh6ViBE/z+9c/8IZxrl7Djn7zvA7ve8UPnzo/4n0Wt15OxqQSvXBGMLAsnbOasdMrFDofD0t1w784MfunnD+PNTx7Gjt0lBxn9V2Up+6WnUqnzirLuliy5S6wU+qg5Pk7ls+LttJhRlILT9tANAhhaL9K4i6hgNUUhJKWZW2u1zh5eMYw1tDsEnQqSzmaVHJqyJ0r7HF1abnFpFt3Zy8jOX4HdvInOmZPwj/3gr8vGuU+zaN9m7uDVKkJa8dsB3JIOdRRi7JaTcvccfN+xH/MY8l4BJ8UAAV6vApdOnCgtTm6Fz9yasafutDIPWVjK1raN5IHnq4hkGh1XoutHsK27fWNSSKL1TuschRxxMqxrkWO9mCTWVIELUfiEele5bLPSPmUVzhzOY980DlSWFuCGS9BSDbTqM6gtzOKhob1ju3aVXrzbt3+/y10VoV+rJ2Cr45wQxwtP1aZkOSSqnfXJGNqjB55KzDOxoO8YOVI7IRdKrBpeHcybQOwrT99peXCp7yyd5BJeKgmKoe9EGiLpbE64FcgOxL2eSqaQSYrrIIzGy7JiN85MiRk5WaRjYmfzoUjDkixAFwFMRBBRBC2KYMYQU5WyvW8TkbShvKIKXJ9se9+6+NuTk7tisLCFSVfKsorN+1T4R3A5PNsszuUog0M9lLFEqxOg41LrHKV9N/qWxHGk1JSuc+TypsosrrHn9HCIEvC8CF7HH9mKOaFZUrhISsrj5HLSVwoJPY6RJvxKpEFA28Sofgd5zaVYkx2/erfXyIpMnjsXlEp56NxQxJl110RTNaFSu3xSQl6rRCd8KQm+gSGl6ygVBXFvK8ZElVWk+zhhZPWDNKrLXezvotQC'));
    dbms_lob.append(l_inhalt, to_clob('an0FHUIVHR3CiAgWD4SMISBaPgpLPelCUf9vyoMd5SO6HnUeGbqm6hOuHyaEVi8DTenbBEEAFcuEoNVUrCfrF5AhCCI0mh0sRazl98jA1ssbqR/r+1oRVEUziGuFnIm0leQHun6IRov4jfrMWncKWX46IFKEnG3A0hN21bWDJXLmJEHV6YRoxenAt6Qg+uD78Tu+n+QVKUK5XLYnJxMOhVcmUsSpjkvNtJk0LV6MrkcsJW5ytd5xyfYIkRTDCTmLQIHqDXpCp9vveehXLIMoKWLx7LhecgnVKAURg2MV37xWzexT8hDCYdNRfB22Bmaw0NK1WtoiuBkxmwH1VgdBn+3s5Q6KS9gZHdl00riydqgJ+UZIW0PbR4x0oXDkeE2jUvpgUmS6XTZWvE15Tc7ixMSru5IobU2hWqWJU8Wc8U7c8OEHEVZWqK8gVn7Dbe9Y5zlSqMiQTgnYlqXAslJR8NHfEPlWDD9maHQ8sNnaLilPVCgtXpZl+9g00FEgmX5zTa/XAQw3O8ybnJkpsvSQJe2qidRs7XgvDK5UyvbyOotBM6SOs7XhoVOybFsNKZjOrJlAulB0jWNgZ6fDiYkkh3G/pDxVtuWwFMgTjkKKW1W+Ot5wvcz0WG/Wy1xQCmXHEvuG5tSgtMUodh9fN25pvdw3ACed1MmzNy/mcql3UoYwDGK0moEy69RGeackjEf9PgjDECAuJ0StdZc0oZaBQClCF2g33wLw59Z/SkLls8bSpBSBKPaK0sz4M6I9O+uyg7tFuibFwqUTJb/Ewno+FkstYLJ+WrB8M9zdmhTtSnmU+L7pM7kjTd8kBkeJUQ3ZWjznuZVZZ+tWaZbL5Vd9odwuk3KyOApmU86cd6Xw6kBTY16QgSBtNHwIa1E6hSvc4wdQPNsp37HoM42t7uqZtFzq7IQMx8zCLMKh5Zmgup1ls7pipn+wiqCEa/M2JYZoCSXgtH0Eikb/7tLHJaRMHTlSBDRfatqZqj+hTTDq'));
    dbms_lob.append(l_inhalt, to_clob('WB5Bb5xQTiGtljdIIdMHxhjM8AEtlmExw1rTZ213Fzti51knxOIVp7Un8SGuDDfDGLvNy1krZN6ih6gKOZQTrFMIh67POg9psblgsJAPxGLCh6hGXI/w3dP0UQsJrSyHNKlxP7CZhw6Q8YnnFlh0pVPHY1g4mjX5zenaRpsgrxZWH09M7FWKWSlL25QwG+3joT51ppKsxMZyfxUhwosjWwuAnEUQ6lhpeHADKj1RA8qdjkICcU8gamlTV4zr1K4sFeF34gAqGJxk8EJyQsVRgHtT5bLtQ6rTk4QP65DSVLSKNZocs+IPo3adH7RkLls6Lf0AWdUL6R4Hs1PLKGWvS0vGl7N0gIxDxD4cFjRb8UBjvrDvOHXpOCccWeIarJMFAm3WRK5y47s+hyMnJ8IlVGtLu0OTDQ/TT9iONCnY7OxEdS7cy1DytBfGQhclPQOHsEEKNLpO+MjUCOvZ2m5jMmDEaB6VoXcx/+0MrnbNNwl4qQr1t240FPW+KgKL4rqd1XtXMUOrQwM0ArDixgWHxIonKMiUIE4kxdd/ByEz7f3NVgS/G4zRD6qUp+yFjS1eQsAGjlrN9FjhoA7zGhCfcx91MMHn8KH24tKTM9evw12YR+PmLSw3b8FljoJBmKkM8kNDyG8dweUv/BayO/YhM1f+rGHg81dNnKtoRVHPhKsm+bXIieculabCWZuJZW8Ha5tjjctFt4ZdHRcTMfDhazdvwLt+DX71FtzqErrdRgLru90DVtDTVVyfepUsZ278IPa95x/92YuFG5+GOWKzwsSpPovefVcECjfV8fCOm8+nwYVGDIxwWgHaLlnS3Hf4BAZDaMjnLIVYIvVfvz8QQLYbSLR7MzgooxiqMzEYcqUQ69PYioYDtt0VzblmcDxTKzUEPnLr1HPvn/vyF+FcvQjhLMOKPGWnClqMPCe+SDrdHF3JcJ0avHQLWr6E7OjO9+cPPfr+sXe8Cw8P4BOzWXz6bvvuKxEm3HB4cMF8'));
    dbms_lob.append(l_inhalt, to_clob('2GRHG8v40yvPPwP38hRq16+gtTiDqNmAaLchZJ8wJFK0wnc7b30aABVfRQy1Z5/F0vDwe7dPPPGHc6lhZUWIkPyBKAI5T0oZYuaUCimkmIFuKND2PLRb1AWVaG7fu1c/gXiPVCpBU21ulFXMEWSN0syy39lEQzuo55IGdjHUHZlwRJ4dD0dYqVKulO1H5+HQkI9+lUJRfnMJkYLFh660Osv4xo0//ow1/zd/BdlYRpFzWDqdZNom1ESpHgFXcjKpRDZAjwIX3vJ1eMvXUDl9EnMn/gqP/PQHPjL6pomwLKc+QT2jZTk1Ks9Y7r5mOixtMIK4LCujEro7cTIfniT45vCsmMjPhe0z7GevffkbH5n76y/AvXkORtdFOowxpCYXMHCRXOGhyrUkKK/bRfbWNl7naDHBkPJW0PjLv8SuR5/4lbmtS79E2+jyBnH2/d0aQnhZk3oVONwIcLu+Sg3f2eOShHprEqsZTxmLQxAhQzLLY51E6HZj1AkQSxyRMglDpJ4TCfw2SVEmnN30QAMxaI3Oy9+98Of/1ap+9YuwOw3o1ILX66v1ab4UknkRhnpPPwfRow6msUFaDFuLYQRA/cYVTP3up9B1mh87IH5s7NLyiV/n1UqY2QJzYSzBUt4uY51pFOdjUZbHga31sd3xXK16Sk6e+5M/Gmt//SvItedhml0wk4GTD9QnNKRQOIGTJa7BBlg/8pvUOe+xmRAAnMcxNBbDmb8J3g2PoVFxLbldzA1RVPGAEkpkFWIeu7ZtwTTo4AL4XoQGjYS5m0lTZ7x3WEwikxKqJN2LAV/yDhr5oPwNiovZYkjWQH2SwEumNhAdMCmC5eNjiye+9K7W3/4lBpo1mHEEQYPFooi6fHq8sDRrKjmBtPAKH6Gm1cSIRdL0S2BcwkUUZIjh5iLm/9t/RnXyax/I1diPxhcyta6Upp9nd6S8yUJu7wAv3uIeexzWmHcm4BcaM899+pNj3b/7E2zr3MSQ9GAFEfWe'));
    dbms_lob.append(l_inhalt, to_clob('KkqAHnegIjanISkspnYB4odK33bLQNLcLJrVSy0GMgUWGxCxgRQpBY8Q+12M1fxwQI4J1fH+wIpOalEWw3RKc1PE448IPu1ZvZ6Eu2b7ehqt8wSllKHMpGqH7x2wYkxL6PJW6h1MLtZ3YaiKQ0NSsGCE0NcJuq03FYIWVIYdLM9Mv2/5mb9Cur6gWOeTv0lBypRyJq04hC19WLyLKNVFYHbhmx4C04Of6iLUiGvSV13grsbhkkchBQYaTSx84c8gZ+qfBPzSTGuk4uLQhnmFk+5jwONPHpVB2SxWcG7mD/8TrDN/AzuqIuYuQk4cUhr0QIceEZ+10ojEMhBWX1kENSgx4YGg/pHVyTY0IJFGKCU3Qf0lMoJLFdhCHpqVccMlFnp843D3virCcKgGMD6XtuiqpomvEpUVBzH9wDu2ucTJSeZEQaGZ7bSpmmLpZPS9iuQRpawZGg6hKt0xWFIEYBb1Mq7VGhLog0n9s0vX0frG34Fdu6j6Jmh0MHEvEN8StdF7XKClpdBkBjqRjtgzwFwDrGOAt3Xwjo4wNBBJDVTiNhRzvYAIU0iRPzE7jbmn/wgD+eAzO6NbOpGPbHQ+pBVlpTXvHqniD6584fcQnXkGeb8DjUu4gsFVTjWNNe7NM+lxWwdMR1ez0NYycEUMV/fg6i5cQbc2XNGBK3x0tBAdEcLVQnhaCJdL3GQpiH0HKIL+jwtDQ7XSOoznA/MRKCJe9PizmbR+jBplwphjudbqjfq93S/oN7YlV4DgNJElhbRlKOg85RaoWaY/7ofALm4nAFy/hD2EZSXzK20ZllfDOY0mzIU+nHMvQLsxg3zThWvqapCIHRPDSheO0NDkJnw9h1R+CKY9AI33HJI4yWlQy71Tq0JrVlAImjDgQ1M1EB2+LmFpHTS+9SUs7x9/svjUO94/KeufuUMZhoZgDZ32Di7Kf3r6i396rFr+awy6LdBgJBpy3u8WI8tJ/1GkFEd0jQv4IoUukX+YGbB0'));
    dbms_lob.append(l_inhalt, to_clob('BjGRh6nzsL5tMGkSUk/3B5pEEdJbh3HkJ34S3hb8Gfh4capSxjhZz9vQ6/dFEWhQmNfhejaQJm44F7MpAqy2EKjsIlNM6TmeTINVE/nIOJMhoH5Hor1gNAFGqOlvWYu4lQza9ogsUzlz9Dolm5s+J4DjkwAuWs/janxs0ZSXYBMxlxoSxhkip4JwyoHoBNA5MbLFYFqMII7RgQ53aAwDTzyFLW9+G/KjD7/IfXye/CvGYTEDtqGrudglN44+eOvct7H493+D5XNnMdBcQQoefJpXTZai28DS1/9fFN/01CdRXXiamm+SvouqHbfqwWPZW3rQkKJ5cfFfd7/xVRTrC9BiA66wVMOwEQXK2nQijpXcEOTwVuQLQ0gVh1B4eBz5h/fCHBoleP9CFGNFqUAyEUk5fnSRKC7KvpPL1Px0S5hYKGTxG7UGahO7maIIeOAWwe2wEKG7QLmEhEdJwml1UWu2kUvTtNhkx1s/pyl5mIz4oW0hZ1N2sb2uZTZ5FEmCv3Vp43yEdK80MeGckJfMJHzqWxbqpPch/RAROVtapMYOkUWqpDKI978J+37qZ2Ef3PXxc1vw+ZvOjhamZx0cUz6GKHWYJTsyG8WwajL9b/ftfEvx4R98y8dmvvnt9175/U8hX70Bm2j96Hs0jvr1GSx94wQO4B0TpJzHThLcvjRfnqrYc9WC99DA1G9e/vLTCGZvwqApNjyGFXoQCFHTOG4MbMGWx9+Gg0/9CAr7985aRXxZz+NUS8fFJWB+hoy6gXCIIBuE2ly3fgrMtU5SHqAHKFotlLwGFuZ8alu/u9w3RUinyauXJjQDhayhhr1HUYSOFyqWdPJ0lTO3mg1ea2tLRKrC00AhC466ouRMNo0kRo6JMJwQT7EcB5hXKZftaaR0at5eH2MQtoUa9CJO5jYGjzS4mkDmsSex62d/GXLIPnh2+wTg+0KGK8GWIcCfleLIjuO1cqUSAsuO9CzB0mPWtOFWsNP75f0Sn+Xt'));
    dbms_lob.append(l_inhalt, to_clob('f/65G3/6XxDdmkcqoi1EwqZBo8+ewLaJd/zmc5dOPL240KKctPnCoF7Uqyve0ukX3+e/8G0UOh1ElBLRJCzynSRHMLoXB/7pBzH8+Ft/49ao/MSZ7D49boXBU8ZIhUDBltTFHqmJkafsV5y8opwBi+PZkaeeqpy45JROOE7pKXvj999Xi6BpzIMfu9k0TYyjxlmJFoWQrQ4YH0gGgt2ZUej3vKphHIVCKoGeUuGsz5Km2uZo1C+NCZarFqEszxbXmucS3VJ4RYo6NCLk1JUp5nv2Y+w9P4WBvbmfa1TZ3PHJlgm2Ei7umRF4CKbVG1twG5FGjZJX5cphXLB3nPyBt73zt9ud1ocbf/EFZFZuqbY/K47gXJlC5/oFu3R0/8SVnbVn0te3B8jfKBZT1999+VuTMFYWYMgQXcnRjTQsS4bgoX3Y/4EPYeDRox8/VWT/Ed4EJmy2umAECqZSuT706oAV+5KqqPoNfE/Wu71H9IEoAk2NjFrUPm94Q8WsigK6MkKrE2Kl3uxNfSFoKkkfONBHIiW+P9c58rYFjRMDLIVDvQkxvaxhl6yL01lXQPFAoCbVM9trpKavIYfMIOfJF5Aj2zHyj34a1sF9/+qFLMpdkROl6k1vfOuS2RjmXgXbBVP45zUh2Dyq03DzsPM44zTjg+LZAvu3B37kJw6cnl18e/vvvwqzW4VBHI+tFdTPP48tR/Z/AMHsKaAYjOF62Lx55WPhxQtA6CLQI+iRQDdKob11CA//jx9C6omjHz01Yn02jp4wn7JZRU6V7SplAIeA5XGgAymMO7gsXrkcQvll33tfFCHqNccEghi1MD84mFeMrTLW4PoxHEoEqb9MUqdkGdaPeesTbVFGcqCQUZaBomTV5LLaLslVi3yr5aMuJ4tuS4orahh5kjVLGCHJiUpKNJR2jo0sSk8cx5ajP3DyMthn/aUxMMuyqo+5WEqPBE+xpHx7u0ywkjNZrxefhesWcBnSueFYcyO2vv3m'));
    dbms_lob.append(l_inhalt, to_clob('Lz38jnefu3L5PDC/giiMYIBh6dI5DLrhewd98dE0yzpD83hy5sK3Iaq3FANlV9dgBwyxlsaBH/8pDL/l6Kcv75RPxyhl0bqsoh7Vz7nv3kDrVBda4+WtyX1RBIKz0/38StnOBG6LJsIYOtAKdBUxNKhDvp8WkVJ5+AlkvS9UKwBSGseALaBTnB3pioZHWYve8JDQ53CaAUUQI7kss9DZukCNuf0cQhKQJhEEnVFt/wEU3/U/oJPCz6Zn4Tw+MfaKT/Txwh25AfX/9anJT2QPHPpIULkKFjVhxCGchWvoLsxjIDtmXZpAmH0RH3KvnkHKX1ap7G7M0OQRim99M4o/9GOVtik/taOFylY+pwcarPJKeUw25D1DPr0SPoj7mlBa1GMX6VZAjS6EZqbJ7yHF5G1a0LuTavVF1RtMA6kUMbcnINZVIZ8jopR1G0tdFpIbEcfhnX0sUiJgEo6dgXXkAIyR3Gcv7hg2q4+PfNeTXMoVaedH8ZktR5+EXyipRVa7V72N7uwcYgOPSJwRnaVbR4NbK6ApAcr98D20BnMo/MjbEWfx0UrA69FKYkVDiZAIoXqzVB6Y3FdF6Hjc276d67k0VwUkxgLFkk5s78S6subeb9z9RDT9NMsxY2mI+pQ9vb2BZjt0Q4l6s4uqM4rIS5yi26X/8XppG+wDR+GX8DQLmYVq7p40xJ60Swu58aOOHNqmilZkyyyiLL55k2oTB42bjVL72kWw2oqyZCKOoccMuQOHkTn0A6FTZV8enIVT2HG8hg6c7Wk4ehG1wxuUir9nFUEOHRMURuoGq+UzhprHEPgSjXpHMbmukmRtwKJChRZKkJAlyaQUF8+6v0mSUV7EsLjcBAvsLbbNPLZC4d5LRcX4UiC7bRfyYweQTuHU8PT87MRYKeEF/i5kosQceWZYtDT8amrbwxCCOrgl9DBAe26WMjpPjrXxFn/uCni3AxEzGDFHlC5g25PvhK/ho83OLqE8wh5TvDLj1Vdm'));
    dbms_lob.append(l_inhalt, to_clob('zl8NNuT1VYTFlkh3qainnR8oFpRTqGDtjouuR1DQ3oSVjd7bc/ioAlnIZROOhB6PUt+SUKq42fYhXbH9rsdAqdp0CvaOPTS1/uNdhy3sEffmapOyTFEEmjn5pYHR7WBGCqFCREm0Vm5Rvugob+FJb+EGJBGLsxg0kJbvHEd6/5vQDOSXxNDVcHr8pQCBezk64JUCa++rIjw1YlfOcOlARtPFHDmGugJW+F0O8u05C5I5Cyp3vjbDVUHRVV2BI2VoyBeIoY34lLjiZ0qmNCRZ+ZYTElvX26tV1JjbDLlJtdi1TCXBtUS+BHNsN6IMntF1Kaoj90YRGJtw6ocfFfWx/XOstAVdw1JVwkBQWrwNwTCiM/x80K4ra0gVjA7XYOzfD6SspxecbIUs5iq36MsItf9Tgui1HOdpOVkkpHRZTt31/fedj7iZL4WQ0ZydT4AWNJqP2tppety6hPJGUNaEglNoyNpar1OO0IykJLRV0BR4mtwWAqF/bJrMa7UKPtJPKPVKOJJB5AZhDW2j+uvV7iyw48i9u+J4J6tPZOzK7Nc+Dy2dBRoJwioOXISu4pSyQtoWFFQqRigs2GMPUzfX17k9rsuZK+7E8SPf+XjkITHI8iGFsSygQUSvUIbI8ZzCWAMIgo1agBJ5MMTUmraUz9lqqIZqkXf9pEUe2VWo2t1E14l3MauS6YrDUT3bg6HJZC5lLOODvGOJfG4d7b/6R6ohpunBYaRyAwvnx0oVTN/7n1eplG0+0wI3idwjAbcwz0PgtRG269CCpJ5AR8/TBWSGxyANnIKVxsyjD3/HNZCT9WJL5sWFRyHYCsKJHSWH0s59GoLv+H4iEZO6YMcLDz6z2BdCw0yevlEh7kSuWtQZXJol2SFFWONTIoXoJ5L6sHZazJTOVHYxyTb2SBf70HYwNZ5nZcXBkFaAUWAWpxLnOgtD+Yk4k6fK5zclxgUbrN5TbzyOWwHt6c75yVC3MoJmRRDFICPu6cCF32qA'));
    dbms_lob.append(l_inhalt, to_clob('Rd1eOl3CKA7BHNiOmsYuYmjaYRj+jmtQPpyH1Fpg2Wt2KtvAgjwxIjAVLsgTq76RQaezJ7rBwiiARemaxZDVyn7HYUE6pGpojJbJcWe6+cFYBM6dbFqHKYAuTWTtBqg1mgAeShZNrR0t8u2tcLQ1QClCyqBM4nrYCVkCAS8gaHsb733H0drsbPlOnDyRhFrEnYJZhmo4dA9NgpRle7KVFPUYwzlumEcjroEHfWZqmhxAFVLyg5gaLyAyeUhmnJu1hpzdWDJ93BnprJfJuiyyPOxRvIhddTmGqlzCrWydOMru+iYmQjDDKphV8dA++chSfrZyCVYthuk+xV6HotOqGLxmE3eiqcPzYvg+9TcQyfd3LqLousTAgAVT15USrQ6JojviXehSEeulrQVr9UsCp3DohqC6rUdKMNxJ8vW0126QLXzVwr2Gp5hfp8o12obUhBv6bqWzxPWUWII+jtJK2+TAXoxDzSw2mB3k755BpH6NqQYgG2VnV4hjlUrw9MK3TyBsJN7ler9qozNJcPz0C3uw84lHTz4+4H301NZr85P1erjR734wihC1awUDyOgu6lqaKr5YahKJvw89ThpgEk7NteGinPwBYnNVSCUBKyXQ6FDplkrJlIBKUtR+FKLWjPCcPFHafhJOK4cKOZN9h5GYYTkxusZqqpt9Np3sq6XgbHgvooYpKg4NDZJBs6TqjqTxRkBIYNeYurl98ChJc1OJjacMsnItPlzwnq3e8sbvkl4lpriFKV8MzzwvFo4Po31q8XOXPv1/Izh9AqLbRkxJFkqg92pwAcVYVHDruckhixAJDQtiEN1r7z626wM/9z+zFf9foRmE1DA8cVue4r6Gj2snTG8R7CxjUvhI43lj1BsuDXldS/1t9D71owRs00CWHLH+8Mk1dxFhFKqKZqc2YFV7iZmXy11L3VLKP3iPibkZIYV6M6lXPZz+YPXeMSkUtKZAN4IKWfTs3QeMDRKGMlwsiHD/zcXizDe/'));
    dbms_lob.append(l_inhalt, to_clob('YXWmXiBwHHRDUw1AhuAwNA6DejM0DZYQMDUdKWHAFCmkmcCg72DuG1+Du9x434GrHo5VdHG7EjwwRZBW3c2krTCTNnthH9BsEDilz6XUn/98+xuTOZP5jIkBxdBGcG4aA9BjYGOx+qxGswvZyBwovYoW9XtN0B5JZCM6mPX7Ug9106+YhlRO14Cgd9aHXuYgCAtBLffscNMSPt4Sz15HPmwjxfweYpkAtBGMOLmZsY9UHEKXscJ+ULhKcP18FMJqVtC4eh4wMQaZ33AXeCCKMJanjS66mqXCE0E4JMNy3YVPIwSVGU+SRHc7QCJhzZoEMIjWGt+TrhOVZ3KIkrfLj15yTqhJ8K9E7h5RvzoZHEzK1BFQJARWgsyl9CJVVBMmWRIC5SihhdJU8/XLCk2YSR6ZIqS6We95asOhCqeuFj1Uj41VBSBMJ03cIkiejxR8ldPQww6kV4dWkNmT++HR1vBgU8y9ppOxvJrodaqoRvTEajILLR451MlpuxPRnAhTgJZcRkcpn1bs7WukB4lFoIRRp0NOmbbrVvb1m9zG182/VP4J7QyEz6Opcz0wDeFWwk6H8kqjlHtYT1d4pwwpZxEnvRoX8kVt5y7URQYBUgh5cvNZCi434GoGPKHDE0YP8Uz+CJ0uBl/jCi5v6tQ/R/UfiO0bAFxekSJMTk6+a3JyUjGdvirR132hjJfSdGmTYYtp8QK0KZfwcoFDr4EjndJVQ+x68EpfCJSqhoJE0ROv5zwOuU4/KZpJEl4xeG8anYpgCGHecUn7R4e+YxRbhRlr5tZ4q3lhbMvctiefrFj7DqHJbDixgQYMNLmBOk+hRrfYRF0mN4eGqlEKi9EEHZqnyZLRCRFATDCUZXxNUcPx48e//BrOjSK/7sgyta7PTj53bWGgmIYGXbVzNTtdOK02tC3UZ6Cp1jJNmf0k0CIFIIVhPIQQDHaOgxH1f6+pMebUApZ0LDuBykEcHYccSaL6uAdg6de57x+/YqlX'));
    dbms_lob.append(l_inhalt, to_clob('IEq4CaiMxlTE0IfMCSMFTU2oi9ElA1FfAfPaIy6yxXK5gvjYnPkUe/yO2L6Hl3ROXJIlLC6a2S2Vd+/95f/j75a/dcKKVqqrHU59oS4o6piOuY2wPo/ga38O2a6C8wg+1f0iE7rHWkSe8Xx+Ujzw8JEGtasHXNbymTR0QWnmGK7Xswicxvb184gbfwJ1RhdsAzpnKjhb9cN7pBnE4dhyg7vSwjxokb0OPfIRDDuHSBAnPYcpY7RrTXSqS2jtzpTiiumy2cENw1jaOsiZZIxVKE+x2Lp0ddhkj2798be1WGnijhJ6RZZH05AjabBK61I4c/rCJKKZZYXifiXyQJxFJdKvZdK66igmNAHR6DaaXq/19G6SsKgRy5plCTV1Lkk1J954MgSEJZ/VcBWJF94AwvodW2QRCnkaMqKeM6BD63Tgz8/AkHiSFaLw+I4dGx7zKjahN6HmSva4Vx6aqGykBCTLJ485z1f3XSTrG0faguEL5GjGym2KoEuIdEdNVn2wikBoZvUg5ddKQzasVFKB9H2JWgJeXK0frBflbPXicK5xNSFWdVUTNJ3M4iplGofvh1hpdHBCylccNdxriftcD+qWNOpyKaEXB4Ec8RslFVQ99NC9dAEp4MPF5lm7TA7hy0Dh+o9JGfpMb2Qt1t/oubHHTxZ3Dk3tKsv2KIUYXY0T8GXN0tKFo0kRMISd9J1zsR9IZpGg2WWBWi6TUkUkosjzAo5aY635ZsM8Qj+lROwphDmkYgURLdBpXKXW5D0CzjZYtftd4xC/a1FRbaKkaiJN2rjKrewu8m188ne0LpqXzqLUqB98WBRK0/4S5cc3Rk+XNu5D2Ai4wi0p7ADmhJGZr16YDHxNKtoI1Uz7htkaLEnzPGvpjEBKcSVE8EOgstJR8O6E/KFfcFKF+wTjTFPhFRczdU5paqDH2t/1Dp9TnZ2gCG2wzsqWtVfXjQlS9YmXtoTdPaP32kLkRHq+i+I0SJRYS+Hz9padiAwj'));
    dbms_lob.append(l_inhalt, to_clob('UQQew1+8icUXT6GZx7vzD3FrI45E9dmybBNUn/oq1s+voufpVll3/23ka3M6W6DXtRC6FQJGbwrz7bKRCbrvFkH1OAwxSzZLTrEQIp8zgEUi4AQarVhV6XWa3URdrmoVpbIY6noisk36YYaB4mAGWTsD3HDBKGJQJ5pDch9hqMFpxpBdXlDV2NWrYI22l/zTDogs895KtR+zxnAk2IgaUEZHRoQWPEbg4cvW9gMfqWey4O26iia0bgfNb53AQxNv+9ciJ/5oqCLdJMkzjmPVaZX2JP/gbrjFuz0/30sUMR1mpKq5fZv60n6ybOt1sAhUmUccB6xyOWQyvpo2E1aPKNbQclrwOkRAQfkCumBpGemxhojpaAYcF2+18JVvXcOffPl53FppqZyzitKVn5A8pur0Ck0P4yGNbHjdJVbd3Qw84tSp6tg7tiGdLkD3dHTpuDUf7qULqL3wAvgSjs4uHg8p/6/qDy7sxuxr72h6rXLfv5BMsJwqo1SAXWlEs3bW2MW4C8kjNDsdNFo+cmk7AZmEHEv1Di5dX8TZi3M4c+46zlys4Nr1ZbS6AqHYCsZNlahJJEEpUTcTFZ4QaUc1YOPW75fn+fyuhQIEdd8DzZAS0FW24iEcGi5dRHHkET57A4FogfEAZnMZ83/9RRT2Hf6cIycPnlh2Rpi24NU6S+GSzkLVZtfrsqJKpHrcG1l0P+SBaB7l9TmlvBBXiHWdMxcRE6i2gGevNjH54iJePD2Hs+fmMXujisXFJto+RyANQLehaXtof+gBWilIp8iB+irpnvISxLDmUnbxnQCeTjqh1hi5FfqJb0z8ey+kLCu2dnrKpeimD6ylKTJUKtZ1aubFr4jxI0+3L51HGHWQYoCpSVTOPocbX/xj7PmZn306b7zwC9dZpnYuMJwM88y4NQcWiXBS1otxyxUsaymE0cs1sr6hFYG0uVTa59y4MjkC15/PZy1oTEcMC8+db+Jf/K+fQ9Px4PkWGE9BiByE'));
    dbms_lob.append(l_inhalt, to_clob('MQiptgCpqHsJ/awaYKnljVFaei1j2Gdk7XgBup4/oj1wo5qIzlHRdV1xPBFsPeLEyBLDaAMvPJZ5ZvTQUbS/+SXEt6rgsa4qkIXIRfVv/gJiZGjXjnf92EdqW9q/1MBY7THMiKtBx7qpp13eCXTG1TDUUKJx337dffURlKc7NAgpJ4stnbWgp+e2lrKKHSz2NHTaBmotE6GxDTy3FSxrIhASXuwrJjBKJFFaOdYCxBrNeqDqXuIfUKWNyK24pAHmvhol2HSSamRClplIQtubeI9ulYXHCxsncL476c+8pm2KQEo9XKXk0HwZ7Dw5pOdGdvy22L4bjJpgIhqfTOnzCEa7gtk//QMsn/j6u/Yu4oMYyxcnL+3F/Lmcw3lal1cW3N2nwoCoeCROi8n6TJHyC+om1+4putA7RMV4osQgi1KKpM7Qy3DSOeiHTX72ARFurhfa46RzoqRRaBCY84WcDsk8hMgo8oykUuchjuiqVzjfXndS7zE1yartgDpa6BOTAFFNr1f9DwYY68ALAlRqzZeQuq7na5VAcD8Hd0S9tHLCi5jE74RKooLz9vog0J3/TPutT3348rXzSPnU9RRRlz40JlFcrGD6078LdyX42OEfxoErT+DfdvQ8ctcrtS2NMbPAhkWnLK3Zk9Xa3ZDLNEqgmj7mdFAWBVX05Iq8o79D9qZpJdJ4wBZhdT/LslAV4GNtIZfLwDRo1IZEpBEfErWsEzknAyMHq4dCIosQ0gzqXhNMMu6PyDII2iYU20jEKdTUIGMTnmuivpLAxF4vkX2GB0YhJGkGTb4F5qixhYULA29680Vj/2OIBFVSKQSW6jenmIYBZxmz//V3cP4/f/K9Wyann338ZuNze2y8b+v43Oj5fSdbz+4mYObd66tVHKNvNGcxQS5UjT57NafSs1ZBjwBkI3lgO6rls1CCLw2kLRRNA86yA0m1errymQXO6ZRR7UEB71Zruoo4kdhSGBX3kuYRRayqFIcQwnVw'));
    dbms_lob.append(l_inhalt, to_clob('3kIqSziwNrGiELuVchbpY5T71h/gcB8lJEIOZb3IGqyBEzSTWbOYm5uROTE23PjRh9/27iszU+cRLlxEihRBEr0fnYMuitJBu/xFXHz2GfCB0V3Wrp2/nh8fx/DBw8iOyheNYXzGnZk8ry5tWjlKw/QkvlTOyhY8WUQYBX5REppF1frIdBImghjagNEJ5lDn0+uiCFQMIj8Bz69UBnMMe7aGGEh3MLp9GFZmAM+cdXCjGiiwKrW1qRQtFXQVMQYVlqjP2CedRhw4CAMfZiywtcCwd08Jb3rzbrztLY8gPcB+MW7f1GMiqexzPL+Uz/t+ia3Ody9PrvyEdUPMhsarFDmFM9qjzqO78Bvzj7/1V5onVpAnBliVdYCCIBFndIYwZl4DmHUQXZ/Cwt9+CdczNmRh6OjQ2MOfYumi6q9MajFrdPVdulaoFCMkuFuDUa8gZmQTknoMVXwjIod8vS1CC1Ls3buAyzeG3/1v/s1PfwiInmOi9lUZlX7nY7/51wfnVhoAp2bX5CrhcRL2cdYBi0OI0EfWjLB3bwGHDj2Cx4+O4eCeoQXo9r/EeHBquHXRGfXYmN/GQZWguiv47d5KpyFFnG+pIo6CpvUCGsWgSxZMgyAI/T4i5ypPoXYIn939T/7xr5yrzKL7/DPQIuKmpiGpQv1eZbhEpCgAybjnFQHYCuLqMoKlaXgJRr/fBdyz+onVSzBtRBssYQccbTKmFEZRriVe2yqaPUab10URbJbMEiqXy1/HsWNfPzZ9EsFW+cgzc9mFtGYcJNSG8u4jF5L5SKci5GwNw1sEdjxUxOMHx/DE4Z3I5tKfgOZ/5vC++VBgzqYyVK0lTX+F4XndqhzQ3Sy5mQHjMAnurhkIiN4+g1EaugFcplkoq9Ntv1vZUTheU3kEA2MJXlUgFWloEQCHhpV6CEv7j9cUGdaUJc6cwdXH9mb/wc73/dxXztcqiK+eQ4pMN20jqsKeWEFCO8foggaSGJSlBIPJ6Rar'));
    dbms_lob.append(l_inhalt, to_clob('5l+FxVhXY1bLrFOpO7kEuvSbkyS8avLRmIAZqkhudIKxO0rZDzzqpjZtVTqtbBe6PldB1z+1LR+/86HMMraMDGPbSAm7dxawb+8W7N4xDLNof4rtSn0BWJiVaDuHsYTGGcBdlKKVhRPVuO7X4TYNFsbGQybTLltJIYsp2js/JCIuTsnrAK0WeC5FSYzgXkdGzfOTrhZqsCLiQEjQU+T4donVj2Q5GWLOjCfs5/3K1bfuwE9pP/MvPnfhjz+D1MULMCJPFdliHiJUI405dGJoZxo8LhEIDqIOTNFwNEUek5S7+/seQeVXAVmq54MWl9DMoXqvkc/BIQrpu6z5A1eEhYUTJW0I1sl96RqWUdPD6h/83D9+svhzP3P8EaSNr7Js4etyxDpHtXeCuVmIs0Gd6Y4ns6zDiXvTGWvuC9mR0mo+YGZmsmgNxOYCLiGM2LQ+sgOdwRHMUTdVJo+Rwa2kCBd5o6ZLS7pent/T/sdJKYtyqvwFOTR6sK7AokDXzkLL5rECVqPXS4zuTxeBwyHzxvD3C8bXnhyVBzP/26+fm/3z38PNZ7+BeKWKdLcF2ycPI4Eu0zZHTmWKqnSUqNIICtdDZ1FmtSdJoWtNGRSXt8bgSoYwX4S1fQxzWygptfGaP4ht9CVCTmMVzJrujFNc5TyuTxctHWFnexJm6VCUtyENt9LiOCi9UAjzxCjE3BCHKqKaZ1ZAowtasSs41zWibeZScEBUOswLWghLDflrN88++8H5889haMce7HrrD89mLbznmVZ+9viRI/c8oVSWldHR+lQJ31544dRnfwtudQH7/8FPYMcPv+dTU3sPfJobZh1IO0cxaWarXL98IQ4afI/lyhHn8R0nLabJjy1dr3x46exptM+dhz83h7C6AN1bAY+60GK/RxyacMVsFAF5Se/Q6sARxdPAGao8i9F/+D48+oGf/+yLO/T/E8bBykb9jw9cEUio/u7npbg1vcU7VgUWdlWLV3WEUk/KxCyg'));
    dbms_lob.append(l_inhalt, to_clob('0nXyt0NVoLo8pBoIcvqUGMujSIpgtmSyoFkarsKT5lcPOOdvp+ni4kh0rZgzsKuuY6EZYTbVUCTdXmlsY6jXaxUir+g8BrvdyWb3zjvFmOF3WRwdTJnax89lhz4vrbTYac7VZ9PjTq4xJfZ0mM11adbmZO1Ker+H9JxdWOqIoW1SbJXSDBrsLS0X7+xGwfu71Rk0rl9H/cplxCs1cNeF6M1rul0op6JRxlIxlkuEXKJrCogDh3H0R3/yYi2Fn7r5CGb7sy7fEIrQB1uiCgfTx3DhaMtE9hKOo0MLSmZ7tRZPMa8BFlIPACFwiWae+v3ZBhk2Z+FE6fkswLJvtjF7q0Z4wMmZelEOuGLLzSve8LAUhcK9xTVOTZXt8e2wpztw/Klj4sjxBE5G6GO+B9b22bIzZjP7ZBE1iWOCYTrc3qiIRh5oVkvhOKqYnu5Vz48NqSrm+uGjxJTSGJSPyBBHdYZHVAtlP1u8ztdhJmxqXwBNd4uJ5xRBLBCmLZz+hoenWWnCPtY+WWObY5E3ZVM2ZVM25ZXJPfcR7sbr993OT/5elHLvXHw//vZNwfem/P/1Ebt5vQZ4nQAAAABJRU5ErkJggg=='));
    workspace_datei(p_file_name => 'thg-logo-tg.png', p_mime_type => 'image/png', p_inhalt => l_inhalt, p_base64 => true);
    dbms_lob.freetemporary(l_inhalt);
end;
/
