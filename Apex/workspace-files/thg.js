/* ThG: gemeinsames JavaScript aller ThG-Apps (Workspace-Datei, eingebunden im Theme wie thg.css) */

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
                    wechseln();
                }
            },
            { title: "Ungespeicherte Änderungen", confirmLabel: "Zum Portal", cancelLabel: "Abbrechen" });
    } else {
        wechseln();
    }
}, true);

/* Navigationsmenue beim Laden jeder Seite ausgeklappt (alle Apps). Das Universal Theme merkt sich das Zuklappen
   je App in der Session Storage (ORA_WWV_apex.toggleCore.nav.<App>.preferenceForExpanded) und klappt danach auf
   allen Seiten zu - die Vorgabe wird hier vor der Initialisierung des Themes wieder auf "ausgeklappt" gesetzt.
   Unter der Breite --js-mq-lg (992px) klappt das Theme das Menue weiterhin selbst zu. */
(function () {
    try {
        if (window.apex && apex.storage && apex.storage.getScopedSessionStorage) {
            apex.storage.getScopedSessionStorage({ prefix: "ORA_WWV_apex.toggleCore.nav", useAppId: true })
                .setItem("preferenceForExpanded", "true");
        }
    } catch (e) {
        // Session Storage gesperrt (privates Fenster): Standard des Themes gilt
    }
})();

/* Region Display Selector: Registerkarte "Show All" auf Deutsch (deutsche APEX-Systemtexte nicht installiert) */
document.addEventListener("DOMContentLoaded", function () {
    document.querySelectorAll(".apex-rds a").forEach(function (a) {
        if (a.textContent.trim() === "Show All") {
            a.querySelector("span") ? (a.querySelector("span").textContent = "Alle") : (a.textContent = "Alle");
        }
    });
});

/* Registerkarten unter der Titelleiste (CSS-Klasse thg-rds, z.B. Kundendetail 20020 Seite 11): "Alle" als Ebenen-Icon
   (fa-layers) an erster Stelle; beim Oeffnen trotzdem die erste Sachkarte (z.B. Stammdaten). Unter "Alle" zeigen die
   Bereiche ihre Ueberschrift (body-Klasse thg-rds-alle, thg.css). */
if (window.apex && apex.jQuery) {
    apex.jQuery(window).on("apexreadyend", function () {
        var leiste = document.querySelector(".thg-rds");
        if (!leiste) {
            return;
        }
        var karten = leiste.querySelectorAll(".apex-rds-item a");
        var alle = Array.prototype.find.call(karten, function (a) { return /SHOW_ALL$/.test(a.getAttribute("href") || ""); });
        if (!alle) {
            return;
        }
        alle.innerHTML = '<span class="fa fa-layers" aria-hidden="true"></span>';
        alle.title = "Alle";
        alle.setAttribute("aria-label", "Alle");
        var merken = function () {
            document.body.classList.toggle("thg-rds-alle",
                !!alle.closest(".apex-rds-item").classList.contains("apex-rds-selected"));
        };
        // Auswahl ueber die Klasse apex-rds-selected verfolgen (der Region Display Selector laesst den Klick nicht durch)
        new MutationObserver(merken).observe(alle.closest(".apex-rds-item"), { attributes: true, attributeFilter: ["class"] });
        var erste = Array.prototype.find.call(karten, function (a) { return a !== alle; });
        if (erste && alle.closest(".apex-rds-item").classList.contains("apex-rds-selected")) {
            erste.click();
        }
        merken();
    });
}

/* Kundenliste (20020 Seite 10): Facette "PLZ von – bis" – nur Ziffern, hoechstens 4 (oesterreichische PLZ).
   Ereignisse am document, weil APEX die Facetten-Felder erst nachtraeglich erzeugt. */
document.addEventListener("keydown", function (ereignis) {
    var feld = ereignis.target;
    if (!feld.closest || !feld.closest(".thg-plz-bereich") || feld.tagName !== "INPUT") {
        return;
    }
    if (ereignis.ctrlKey || ereignis.metaKey || ereignis.altKey || ereignis.key.length !== 1) {
        return;   // Steuertasten (Entf, Pfeile, Tab, Enter, Kopieren ...) erlauben
    }
    if (!/[0-9]/.test(ereignis.key) || String(feld.value).length >= 4) {
        ereignis.preventDefault();
    }
}, true);
document.addEventListener("input", function (ereignis) {
    var feld = ereignis.target;
    if (feld.closest && feld.closest(".thg-plz-bereich") && feld.tagName === "INPUT") {
        var bereinigt = String(feld.value).replace(/[^0-9]/g, "").slice(0, 4);
        if (feld.value !== bereinigt) {
            feld.value = bereinigt;   // z.B. beim Einfuegen aus der Zwischenablage
        }
    }
}, true);

/* Regionstitel in Mandantenfarbe (thg.css: .thg-region-farbig) – vorerst nur in diesen Apps;
   fuer weitere Apps die App-ID ergaenzen (20020 = Kundenstammdaten, 20050 = Finanz). */
document.addEventListener("DOMContentLoaded", function () {
    var apps = ["20020", "20050"];
    if (window.apex && apex.env && apps.indexOf(String(apex.env.APP_ID)) >= 0) {
        document.body.classList.add("thg-region-farbig");
    }
});

/* Inaktive Eintraege nicht neu zuordnen (alle Apps): Wertelisten kennzeichnen inaktive Eintraege mit "– inaktiv".
   Solche Eintraege werden aus der Auswahl entfernt bzw. ausgeblendet - in Auswahllisten (auch in Grids),
   Mehrfachauswahl und Popup-Listen. Ein bereits gespeicherter (ausgewaehlter) inaktiver Wert bleibt sichtbar. */
(function () {
    var INAKTIV = "– inaktiv", geplant = false;
    var bereinigen = function () {
        geplant = false;
        document.querySelectorAll("select option").forEach(function (o) {
            if (!o.selected && o.text.indexOf(INAKTIV) >= 0) {
                o.remove();
            }
        });
        // Popup-Liste (Dialog), Mehrfachauswahl (Combobox): Zeilen bzw. Optionen ausblenden
        document.querySelectorAll(".a-PopupLOV-dialog tr, .a-PopupLOV-dialog li, [role='option']").forEach(function (el) {
            if (el.textContent.indexOf(INAKTIV) >= 0 && el.getAttribute("aria-selected") !== "true"
                    && !el.classList.contains("is-selected")) {
                el.style.display = "none";
            }
        });
    };
    var planen = function () {
        if (!geplant) {
            geplant = true;
            window.requestAnimationFrame(bereinigen);
        }
    };
    document.addEventListener("DOMContentLoaded", function () {
        bereinigen();
        new MutationObserver(planen).observe(document.body, { childList: true, subtree: true });
    });
})();

/* Dialoge (Modal/Schublade) laufen in einem iframe ohne Logo und kennen den Mandanten nicht - die Mandantenfarben in
   thg.css haengen an [data-mandant] im Logo. Den Mandanten deshalb von der aufrufenden Seite uebernehmen. */
(function () {
    try {
        if (window.parent === window || document.querySelector("[data-mandant]")) {
            return;
        }
        var quelle = window.parent.document.querySelector("[data-mandant]");
        if (quelle) {
            var marke = document.createElement("span");
            marke.hidden = true;
            marke.setAttribute("data-mandant", quelle.getAttribute("data-mandant"));
            if (document.body) {
                document.body.appendChild(marke);
            } else {
                document.addEventListener("DOMContentLoaded", function () {
                    document.body.appendChild(marke);
                });
            }
        }
    } catch (e) {
        // aufrufende Seite aus anderer Herkunft: Standardfarben
    }
})();
