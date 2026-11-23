# Prüfung Version 48 · 23. November 2026

## Änderung

Krawallo verwendet im Spielerbereich einen gemeinsamen Bereich Teams konfigurieren, eine responsive Zweiteilung und die vorhandenen Profilbild-Auswahlen. Wie bei Bierkopf und Schleifer werden Änderungen erst durch Teams speichern übernommen. Auf schmalen Bildschirmen stehen die beiden Teams untereinander. Jede Person ist höchstens einem Team zugeordnet. Die gespeicherten Teams bleiben während einer begonnenen Partie fest.

Die Krawallo-Spielstandsanzeige verwendet zwei Teamspalten mit je zwei eigenen Profilspalten. Bild und Statistik-Button erhalten eine zum verfügbaren Platz passende Größe; die umgebende Personenspalte schneidet sie nicht mehr ab. Lange Namen bleiben einzeilig mit Auslassung und vollständiger Beschriftung. Datenmodell, Punktevergabe und Berechtigungen bleiben unverändert.

## Prüfungen

- Vollständige Funktionstests und JavaScript-Syntaxprüfung.
- Neuer Ablauf-Test: Auswahl ändert nicht vorzeitig den gespeicherten Stand; Teams speichern übernimmt genau zwei verschiedene Personen je Team; gewählte Personen verschwinden auf der Gegenseite; laufende Teams bleiben gesperrt.
- 56 isolierte Bildschirmprüfungen bestanden ([Prüflauf](https://github.com/KolsBernd/Karten-App/actions/runs/45146045317)): 14 Ansichten in vier Handy-/Tablet-Konfigurationen (Chromium und WebKit), darunter Krawallo-Spielstand und Krawallo-Spielerbereich mit langen Namen. Profilbilder müssen vollständig in ihrer Spalte liegen; unerwarteter Seitenüberlauf und eine beim Scrollen wandernde Navigation werden geprüft.
- Handbuch HTML/PDF Version 48, anonyme Krawallo-Testansicht, Offline-Dateien und ZIP vor Veröffentlichung geprüft.

Browser-Simulationen ersetzen keine Abnahme auf echten Geräten. Die Prüfung ist kein unabhängiges Sicherheitsgutachten. Es ändern sich keine Datenarten, Empfänger, Sichtbarkeit oder Speicherfristen; die Datenschutzerklärung bleibt inhaltlich unverändert.

## Weitere sinnvolle Verbesserungen

Als nächster Schritt empfiehlt sich eine gemeinsame Profilbild-Komponente für alle Teamspiele, mit einheitlicher Mindestgröße, Namenskürzung und Onlinepunkt. Dadurch lassen sich spätere Größenänderungen zentral prüfen. Ein sichtbarer Hinweis auf noch nicht gespeicherte Teams könnte die Bedienung zusätzlich erleichtern.
