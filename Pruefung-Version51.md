# Prüfung Version 51

## Schafkopf (€)

Gemeinsame Auswahl Nein/Tout/Light; Tout und Light unterdrücken sämtliche Schneider-/Durch-Zuschläge. Bettel-Tout zählt ×1,5. Bettel und Bagga erlauben kein Light. Bei Light und den ausgeschlossenen Spielen wirken auch unsichtbare Spitzen nicht. Ramsch-Klopfer 1–4 multiplizieren zusätzlich zu Legern und Ansage; Jungfrau-Porträts sind grün markiert. Ramsch und Kreuzspiel schließen sich in den Einstellungen gegenseitig aus.

Zwölf technisch verkleinerte PNG-Karten ersetzen A–D: King verwendet Könige, Solo und Geier Ober, Wenz Unter. Reihenfolge: Eichel, Gras, Herz, Schellen. Alle übrigen Kombinationen und die exakte Viertelcent-Rechnung bleiben erhalten.

## Zugriff und Datenschutz

Keine Änderungen an Datenarten, Empfängern, Sichtbarkeit, Speicherfristen oder Drittanbietern. Der Menüeintrag bleibt serverseitig auf das freigegebene Betreiberkonto begrenzt. Die statischen Testdateien enthalten keine vertraulichen Daten. Der Frame übernimmt keine Profile oder Raumstände, erlaubt keine Same-Origin-Rechte und schreibt weder Netzwerk- noch Speicherdaten. Die Datenschutzerklärung trägt denselben Versionsstand; ihr sachlicher Umfang bleibt unverändert.

## Prüfung

Erster Prüflauf: alle Funktionsregressionen und 80 Bildschirmtests bestanden (GitHub Actions 45953782736). Die endgültige Veröffentlichung prüft zusätzlich Handbuchbilder, PDF-Auslieferung, Versionsnummer und eingebettete Navigation.

Bestehende Regressionstests bleiben erhalten. Neue Tests decken ignorierte verdeckte Werte, Bettel-Tout, ungültiges Light, alle Klopferstufen und ihre Verteilung ab. Bildschirmtests prüfen die Auswahl, Bildzuordnung, Einzelmarkierung und Überlauf auf Handy und Tablet mit Chromium und WebKit. Handbuchbilder verwenden ausschließlich anonyme Testdaten. Handbuch und Datenschutz werden als HTML/PDF in Version 51 bereitgestellt und gerendert kontrolliert.

Diese Entwicklungsprüfung ist kein unabhängiges Sicherheitsgutachten. Echte Geräte und tatsächliche Geldzahlungen wurden nicht abgenommen; die Euro-Ansicht bleibt ein isolierter Rechen- und Bediendummy.
