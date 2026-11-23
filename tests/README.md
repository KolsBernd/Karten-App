# Regressionstests

Node.js 22 oder neuer. Im Ordner `tests` einmal `npm install` und anschließend `npm test` ausführen. Alle Konten, Räume und Zugangscodes sind Testdaten; die Tests sprechen keinen echten Supabase-Server an.

Die bisherigen Anmelde-, Raum-, Punkte-, Rücknahme-, Turnier-, Anfrage- und Cacheprüfungen bleiben enthalten. Version 38 ergänzt Freundesprofil und Fehlerprotokoll einschließlich Offline-Wiederholung, Datenminimierung und verspäteter Antworten. JSDOM prüft Abläufe und DOM, kein tatsächliches Browserlayout.

Die separate lokale Datenbankregression wurde zusätzlich mit PGlite über die gesamte vorhandene Migrationshistorie ausgeführt. Ihre historischen Basisschemata sind nicht vollständig Bestandteil dieses Web-Repositories; hierzu siehe Pruefung-Version38.md. Produktionslöschungen sind keine Testvoraussetzung.

Version 39 ergänzt den automatischen Schniffelkopf-Abschluss, Centberechnung und Gleichstandsverteilung sowie Turnierlogo/Fallback am Tisch.

Version 40 ergänzt direkte Schniffelkopf-Tabelleneingabe, Klopfer-Auswahl für 4–8 Spieler, 21 rückwärts, normales Schafkopf, Navigation außerhalb der Scrollansichten und getrennte TV-Freigabe/Widerruf. Die Tests prüfen Abläufe, Regeln und DOM, keine Pixelproportionen oder TV-Hardware. Serverregression und Live-Katalogprüfung sind in Pruefung-Version40.md dokumentiert.

Version 41 ergänzt Krawallo-Regeln, Teamwertung und Eingabe sowie vorbereitete Cast-Konfiguration, SDK-Aufruf, Geräteauswahl und minimalen Zuschauerzugang zum Empfänger. Die Cast-Prüfung verwendet Simulationen, kein echtes TV-Gerät. Datenbankregression einschließlich Krawallo, Profil-Nettopunkten, Aufbewahrung und Anonymisierung: Pruefung-Version41.md. Der produktive Cast-Betrieb benötigt eine registrierte Receiver-App-ID.

Version 42 prüft den tatsächlichen Krawallo-Button im vollständigen App-DOM: eigene Teams, aktive Spielwahl, Punkte speichern. Ein vor der Korrektur fehlschlagender Test schützt den Einstieg. Zusätzlich werden die beiden Kreuztabellen über die Spielbuttons geöffnet und ihre Kopfzellen auf zentrierte Profil-Wrapper geprüft. JSDOM bleibt eine DOM-/CSS-Prüfung, keine visuelle Geräteabnahme.

Version 43 ergänzt ausdrückliche Ja/Nein-Stichsummenprüfungen für 21 rückwärts und Klopfer, eindeutige grüne Stichzahlbuttons, neue kompakte Krawallo-Erfassung einschließlich Flatterer sowie Teamauswahl im Spielermenü. Alte Ablaufprüfungen bestätigen nur die neue Stichsummenwarnung automatisch; gesonderte Tests deaktivieren diese Hilfe und prüfen Nein/Ja ausdrücklich. Serverregression und Versionsformate: Pruefung-Version43.md.

Version 44 stellt Ergebnisbuttons auf rote Füllung um. Die bestehende Auswahlprüfung kontrolliert roten Rand und Hintergrund, weiterhin genau eine Stichzahl, Standard 0 und die unveränderte Punkteberechnung.

Version 45 ergänzt einen App-Ablauf für Spielartauswahl bei Start/Rücknahme/Abschluss und die gemeinsame 21-rückwärts-Kachel mit geordneter Erfassung, Verlauf und vorbereitender Spielerauswahl. Abgeschlossene Mitspieler bleiben bis Neue Partie schreibgeschützt.
