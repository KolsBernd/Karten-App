# Kartabend 38

https://kolsbernd.github.io/Karten-App/

## Änderungen

- Anmeldung, Raumzustand und Profilauswertung liegen in eigenen Modulen. Der bisherige Einstiegspunkt delegiert über explizite Adapter; die vorhandenen Regressionstests bleiben erhalten und sind unter `tests/` ausführbar.
- Turnier abbrechen steht am Ende der Verwaltung in voller Breite. Startnummern haben eine eigene Tabellenspalte. Der Archiv-Löschbutton erscheint erst nach Swipe; Entf am fokussierten Eintrag ist die Tastaturalternative.
- Ein freiwilliges Turnierlogo kann vor dem Start hochgeladen oder entfernt werden. Lokale Verkleinerung und PNG-Neucodierung entfernen ursprüngliche Metadaten; der Server begrenzt Format, Größe und Abmessungen. Überschriften verwenden das Logo in Schriftgröße.
- Profilbilder bestätigter Freunde öffnen deren aggregierte Spielstatistik. Blockierungen und Freundschaft werden serverseitig geprüft; Kontaktangaben und Raum-/Chatdetails sind nicht enthalten.
- Ein bereinigtes Fehlerprotokoll zählt Fehlercodes, Bereiche, Version und Zeitpunkte. Nur Kolsbernd darf die Übersicht abrufen. Keine Rohmeldungen, Stapelverläufe, URLs, Chat- oder Kontaktdaten. Offline-Wiederholungen sind idempotent; Datenmengen, Übertragungsrate und Speicherung sind begrenzt.
- Responsive Begrenzungen für Tabellen, Dialoge, lange Namen und Formulare; Handbuch und Datenschutz auf demselben Stand.

## Module

`authentication.js`: Anmeldung, Registrierung, Wiederherstellung und Übergang in die angemeldete Ansicht.

`room-state.js`: Laden, Übernehmen, Speichern und Anwesenheit eines Raums. Die Eigentümerschaft des gemeinsamen Zustands verbleibt zunächst im Einstiegspunkt; Live-Getter/Setter verhindern veraltete Kopien und halten diesen schrittweisen Umbau kompatibel.

`profile-statistics.js`: Ergebnisberechnung, gemeinsame Statistiktabelle sowie eigenes und befreundetes Profil. Raum- und Kontomutationen bleiben außerhalb der Auswertung.

`error-log.js`: feste Fehlercodes, begrenzte Offline-Warteschlange, idempotente Übertragung und geschützte Anzeige. Die Erfassung darf niemals Spielabläufe unterbrechen.

Die Module werden ohne Build-Schritt vor dem Online-Einstieg geladen und gehören zum Offline-Zwischenspeicher. Bestehende Funktionsnamen bleiben als schmale Delegationen erhalten. `tournament.js` ist zur leichteren Wartung lesbar formatiert.

## Datenbank und Prüfung

Migration `39-module-freundesstatistik-und-fehler.sql` baut auf Version 37 / Migration 38 auf. Sie aktualisiert Funktionen und ergänzt geschützte Diagnose-Tabellen; sie führt keinen Spielreset aus. In Supabase ist sie für Version 38 bereits installiert. Nicht durch Rücknahme auf ein altes Gesamtschema ersetzen.

Die Frontend-Regressionssuite ist unter `tests/README.md` beschrieben. Prüfumfang, Datenschutz und Grenzen der Geräteprüfung stehen in `Pruefung-Version38.md`. Eine Sichtprüfung auf physischen iPhones/iPads ist damit nicht ersetzt.
