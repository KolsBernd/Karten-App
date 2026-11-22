# Kartabend 40

https://kolsbernd.github.io/Karten-App/

Schniffelkopf wird direkt in der Kreuztabelle erfasst. Klopfer bietet Zahl und ausdrückliche Richtig-/Falsch-Auswahl für 4–8 Spieler. Neu sind 21 rückwärts und normales Schafkopf mit Raum-Einstellungen. Die letzte Eingabe lässt sich nach Bestätigung auch nach dem Abschluss zurücknehmen; Turniertische nur vor der nächsten Turnierrunde.

Die untere Navigation liegt außerhalb der scrollenden Ansichten. Neue Module: navigation-shell.js (Navigation), score-entry.js (Eingabe), room-games.js (zusätzliche Raumspiele), tv-share.js (TV-Freigabe). Die vorhandenen Module und Regressionstests bleiben erhalten.

Der Teilen-Button an der Ergebnisanzeige öffnet eine unabhängige Live-TV-Ansicht. Nur Ersteller können einen höchstens 24 Stunden gültigen Link ausstellen oder beenden. Bestehende Zuschauer-Anonymisierung gilt weiter. LG Multi View und Rückkehr zum Fernseh-Vollbild erfolgen mit der Fernbedienung, abhängig von Modell und Quellenkombination. Native AirPlay-/Google-Cast-Steuerung ist nicht Bestandteil dieser Version. Bildschirmspiegelung lässt das Handy nicht unabhängig nutzbar werden; dafür muss die Zuschaueransicht auf dem TV beziehungsweise einem separaten Empfangsgerät laufen.

Migrationen 41, 42 und 43 wurden in Supabase installiert. Keine Produktionsspielstände wurden für Tests geändert. Handbuch und Datenschutz sind aktualisiert. Prüfumfang, Sicherheitsbefunde und Grenzen stehen in Pruefung-Version40.md und Sicherheitspruefung-Version40.md. Tests: tests/README.md.
