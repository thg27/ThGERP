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
