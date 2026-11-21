# Prüfung Kartabend 39 – 21. November 2026

## Verhalten

Nach dem letzten Schniffelkopf-Eintrag öffnet sich automatisch das Ergebnisfenster. x3/x5/x10 bedeuten 3/5/10 Cent je Differenzpunkt zum besten Ergebnis. Für 500:100 ergibt das 12,00/20,00/40,00 Euro. Jede Person sieht Punkte, Abstand und zu zahlenden beziehungsweise zu erhaltenden Betrag. Bei mehreren Erstplatzierten wird die Summe geteilt. Restcents gehen in der sichtbaren Reihenfolge an die Erstplatzierten; die Rundung wird erklärt. Berechnung mit ganzen Centbeträgen; Summe der Zahlungen entspricht exakt der Summe der Gutschriften. Beim erneuten Öffnen muss der Satz erneut gewählt werden. Spielpunkte bleiben unverändert, es werden weder Forderungen gespeichert noch Zahlungen ausgeführt.

Turnierlogos werden in den bereits geschützten Tisch- und QR-Erfassungssnapshots mitgeliefert. Vollständige Antworten enthalten das Logo; unveränderte Drei-Sekunden-Abfragen übertragen es nicht wiederholt. Bierkopf- und Schafkopftische nutzen das hinterlegte PNG, sonst das normale Kartabendlogo. Beim Verlassen wird das App-Logo wiederhergestellt. Zugriffsrechte bleiben unverändert.

Die dauerhaft sichtbaren Profilbilder bei Schniffelkopf/Klopfer skalieren zwischen 44 und 68 Pixeln mit der Breite ihrer Ergebnisleiste; ein Viewport-Fallback unterstützt Browser ohne Container-Einheiten. Lange Namen umbrechen innerhalb ihrer Spalte, zusätzliche Spieler bleiben seitlich erreichbar. Das neue Ergebnisfenster besitzt eine begrenzte Höhe und eine separat horizontal scrollbar gehaltene Tabelle.

## Prüfungen

- Alle bestehenden Frontend-Regressionen weiter bestanden, einschließlich Anmeldung, Module, Teams, Punktelimits, Turniere, Einladungen, Rücknahmen, Datenschutz, Cache und Fehlertabelle.
- Neuer Ende-zu-Ende-Ablauftest mit 39 vorbereiteten Schniffelkopf-Einträgen: der 40. Eintrag beendet die Partie und öffnet das Popup automatisch. Faktor x3 zeigt für 400 Punkte Abstand 12,00 Euro; die 40 Einträge bleiben erhalten.
- Rechentests für alle drei Sätze, mehrere Spieler, geteilten ersten Platz, unteilbaren Centrest, vollständigen Gleichstand, ungültige Werte und doppelte Spielerkennungen. Auszahlungssummen bleiben centgenau ausgeglichen. Namen werden als Text eingesetzt.
- Automatisierte DOM-Tests für Faktorwechsel, eindeutige Markierung, Löschen der lokalen Anzeige, eigenes Turnierlogo im Bierkopftisch sowie Standardlogo nach Verlassen. Schafkopf zeigt eigenes Logo und verwirft externe/ungültige Quellen.
- Gesamte historische Datenbankregression in isoliertem PGlite wiederholt, einschließlich neuer Migration 40 zweimal. Bierkopf/Schafkopf: Logo im berechtigten Snapshot, unveränderte Antworten bleiben kompakt, Zugriff fremder Teilnehmer wird abgelehnt. Keine Produktionsresets oder Ergebnisänderungen.
- Migration 40 in Supabase installiert und vorhandenes Logofeld sowie weiterhin gesperrter anonymer Direktzugriff live geprüft.
- Syntax aller externen und Inline-JavaScript-Dateien, Dateiverweise und neue Cache-Einträge geprüft. Handbuch und Datenschutz aktualisiert; betroffene PDF-Seiten gerendert und betrachtet.

## Grenzen

Keine neue visuelle Geräteabnahme auf physischem iPad Mini/iPhone. Die lokale Vorschau war bereits durch die Umgebung gesperrt; die gesperrte Live-Domain wurde nicht umgangen. CSS- und DOM-Prüfungen ersetzen keine Pixelkontrolle. Daher keine erfundenen neuen Gerätescreenshots im Handbuch. Auf dem iPad Mini bitte insbesondere lange Namen, mehr als sechs Spieler und Hoch-/Querformat prüfen. Diese Mitentwicklerprüfung ist kein unabhängiges Sicherheitsgutachten.
