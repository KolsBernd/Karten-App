# Architektur

## Datenfluss

1. Die Anmeldung stellt eine Supabase-Sitzung bereit. Benutzername und Anzeigename sind getrennt; ein umbenannter Anzeigename darf keine zusätzlichen Rechte verleihen.
2. Die Raumansicht lädt den vom Server freigegebenen Stand mit Revisionsnummer.
3. Eine Eingabe wird lokal vorbereitet. Der Server prüft Mitgliedschaft, Regeln und erwartete Revision, bevor er sie übernimmt.
4. Andere Teilnehmer erhalten über Realtime einen Hinweis und laden den aktuellen freigegebenen Stand.

Das Ausblenden eines Buttons ist eine Bedienhilfe. Eine Berechtigung entsteht ausschließlich durch die serverseitige Prüfung.

## Zuständigkeiten

| Datei | Aufgabe |
| --- | --- |
| `index.html` | Oberfläche, bestehende Spiellogik und Verbindung der Module; noch umfangreicher Einstiegspunkt |
| `authentication.js` | Anmeldung und Sitzungsabläufe |
| `room-state.js` | Raumwechsel, revisionsgebundenes Speichern, Realtime und Anwesenheit |
| `profile-statistics.js` | Profil- und Freundesauswertung mit Schutz gegen veraltete Dialogantworten |
| `room-games.js` | 21 rückwärts und Schafkopf im normalen Raum; Zusatzspiel-Historie |
| `krawallo.js` | Krawallo-Regeln, Vorschau, Teams und Ergebnisdialog |
| `schafkopf.js` | Gemeinsame Erfassung für Raum und Turniertisch |
| `tournament.js`, `tournament-play.js` | Turnierverwaltung und Tischbedienung |
| `evenings.js` | Kartabendanfragen und zugehörige Abläufe |
| `chat-crypto.js`, `chat-devices.js` | Verschlüsselte Nachrichten und Gerätefreigabe |
| `error-log.js` | Begrenzte Fehlerzähler ohne Rohmeldungen oder persönliche Inhalte |
| `navigation-shell.js` | Menüleisten außerhalb der scrollenden Inhalte |
| `sw.js` | Versionsgebundene Offline-Dateien; Dokumentnavigation getrennt von der App |
| nummerierte SQL-Dateien | Serverseitige Regeln und Migrationen |

## Regeln für Änderungen

- Verbindliche Punkteprüfung bleibt auf dem Server. Eine geänderte Vorschau allein reicht nicht aus.
- Abgeschlossene Ergebnisse sind unveränderliche Datensätze. Korrektur oder Rücknahme läuft über die vorgesehenen Aktionen.
- Der Historien-Cache vergleicht Datensatzreferenzen und sichtbare Profildaten. Neue Datensätze, ersetzte Serverstände, Profiländerungen und Reset leeren die Darstellung nicht versehentlich, sondern bauen sie erneut auf.
- Alte Ergebnisformate bleiben lesbar. Neue Formate benötigen ausdrückliche Kennzeichnung und Regressionstests.
- HTML für Namen und Nachrichten nicht ungeprüft einsetzen. Nutzereingaben vorzugsweise über `textContent` ausgeben.

## Technische Schulden

Die Trennung in Module ist begonnen, aber noch nicht abgeschlossen. Der große HTML-Einstiegspunkt, teilweise weiterhin sehr lange JavaScript-Zeilen (die gemeinsame Schafkopf-Erfassung wurde in Version 47 formatiert) und 41 nacheinander gewachsene Inline-Stilblöcke erschweren die Wartung. Die nächste Strukturarbeit sollte eine einzelne Zuständigkeit pro Schritt herauslösen. Eine gleichzeitige Komplettumschreibung wäre schwerer zuverlässig zu prüfen und verspricht ohne Messung keinen Geschwindigkeitsgewinn.
