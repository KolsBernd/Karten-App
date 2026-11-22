# Regressionstests

Node.js 22 oder neuer. Im Ordner `tests` einmal `npm install` und anschließend `npm test` ausführen. Alle Konten, Räume und Zugangscodes sind Testdaten; die Tests sprechen keinen echten Supabase-Server an.

Die bisherigen Anmelde-, Raum-, Punkte-, Rücknahme-, Turnier-, Anfrage- und Cacheprüfungen bleiben enthalten. Version 38 ergänzt Freundesprofil und Fehlerprotokoll einschließlich Offline-Wiederholung, Datenminimierung und verspäteter Antworten. JSDOM prüft Abläufe und DOM, kein tatsächliches Browserlayout.

Die separate lokale Datenbankregression wurde zusätzlich mit PGlite über die gesamte vorhandene Migrationshistorie ausgeführt. Ihre historischen Basisschemata sind nicht vollständig Bestandteil dieses Web-Repositories; hierzu siehe Pruefung-Version38.md. Produktionslöschungen sind keine Testvoraussetzung.

Version 39 ergänzt den automatischen Schniffelkopf-Abschluss, Centberechnung und Gleichstandsverteilung sowie Turnierlogo/Fallback am Tisch.

Version 40 ergänzt direkte Schniffelkopf-Tabelleneingabe, Klopfer-Auswahl für 4–8 Spieler, 21 rückwärts, normales Schafkopf, Navigation außerhalb der Scrollansichten und getrennte TV-Freigabe/Widerruf. Die Tests prüfen Abläufe, Regeln und DOM, keine Pixelproportionen oder TV-Hardware. Serverregression und Live-Katalogprüfung sind in Pruefung-Version40.md dokumentiert.
