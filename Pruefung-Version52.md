# Prüfung Version 52

## Änderungen

Acht freigegebene Spielsymbole aus dem bereitgestellten Kartendeck. Keine Neuzeichnung. PNG-Karten werden technisch verkleinert und als selbständige SVG-Bildkompositionen eingebettet; es gibt keine externen Bildempfänger. Spielnamen bleiben lesbar.

Spitz, Bagga und Bettel haben kein Spielergebnis und keine Schneider-/Durch-Zuschläge, auch nicht aus zuvor gespeicherten Auswahlwerten. Die gemeinsame Regel `resultAllowed` steuert Berechnung und Oberfläche. Tout ist die Überschrift bei reiner Nein-/Tout-Auswahl. Ansage heißt Ohne/Kontra/Re/Sub bei unveränderten Faktoren. Leger bleibt ohne Vorauswahl.

## Daten und Grenzen

Keine neuen Datenarten, Empfänger, Sichtbarkeiten, Speicherfristen oder Drittanbieter. Der Euro-Dummy bleibt anonym, isoliert und ohne Server-Schreibzugriffe. Die Datenschutzerklärung wird im sachlichen Umfang unverändert auf denselben Versionsstand gesetzt. Kein Ausbau echter Geldspielstände oder Zahlungen.

## Prüfung

Erster Prüflauf: alle Funktionstests und 88 Bildschirm-/Dokumenttests bestanden (GitHub Actions 45992284491).

Die vorhandenen Funktionstests bleiben bestehen. Zusätzliche Prüfungen sichern fehlende Ergebniszuschläge, kurze Auswahlbeschriftungen, SVG-Kartenanzahl und tatsächliches Laden, keine Leger-Vorauswahl sowie Dokumentaufruf und Downloads ab. Bildschirmtests verwenden anonyme Daten in Chromium/WebKit für Handy und Tablet. Handbuch und Datenschutz liegen als HTML/PDF vor; geänderte Seiten werden gerendert und visuell kontrolliert.

Dies ist eine Entwicklungsprüfung, kein unabhängiges Sicherheitsgutachten und keine Abnahme auf echten Endgeräten.
