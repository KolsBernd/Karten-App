# Prüfung Version 46 · 23. November 2026

## Schafkopf und Krawallo
- Schafkopf: Spieler auswählen ist in Ergebnis erfassen eingebettet, auch wenn noch nicht vier Plätze besetzt sind. Platznummern haben eigenen kontrastreichen Hintergrund und Text.
- Bettel als optionale Raum-Einstellung, Farben erfassen bleibt zuletzt. Bettel: ausgewählter Gewinner erhält 1/2/3 Punkte bei Schneider frei/Schneider/Durch; kein Tout. Sau und Kreuzspiel behalten ihre Zwei-Gewinner-Regeln.
- Krawallo: Verloren ist bei jeder Ansage verfügbar. Punkte werden dem gegnerischen Team zugeschrieben und im kanonischen bisherigen Ergebnisformat serverseitig geprüft. Ergebnisdialog zeigt beide Gewinnerbilder. Namen bleiben einzeilig mit Auslassung und erhaltenen vollständigen Angaben im Spielstand.
- Anfragen enthalten jetzt auch 21 rückwärts und Krawallo; Startzuordnung um die neuen Raumspiele ergänzt.

## Feste Navigation
Die bisher einmalige Verankerung konnte später erzeugte oder ersetzte Menüs verpassen. Die Navigation reagiert nun auch auf solche Ersetzungen. Der Lobby-Container ist selbst fest am Bildschirmrand statt display:contents; Raum- und Turniermenüs bleiben direkte feste Kinder des Dokuments. Tests prüfen verspätete Menüs, Ersetzung und Wechsel zwischen Raum/Lobby/Turnier.

## Prüfungen
- Vollständige bestehende Frontend-Regressionssuite einschließlich neuem Version-46-Test bestanden.
- JavaScript-Syntax für geänderte Module und alle Inline-Skripte bestanden; Offline-Aufnahme des neuen Stylesheets geprüft.
- Datenbank-Erweiterung vor Aktivierung mit Rollback geprüft: Bettel 1/2/3, unveränderte Sau/Kreuzspiel-Punkte, Annahme eines gültigen Bettel-Raumstands und Ablehnung manipulierter Punkte.
- Handbuch HTML/PDF Version 46, betroffene PDF-Seiten gerendert und visuell kontrolliert. Keine neuen echten Geräte-Screenshots: Geräteansichten konnten hier nicht visuell abgenommen werden. Bestehende Bilder für unveränderte Abläufe bleiben enthalten.
- Keine Änderungen an Datenarten, Empfängern, Sichtbarkeit, Speicherfristen oder Drittanbietern. Datenschutzerklärung bleibt inhaltlich unverändert. Keine Erweiterung von Zugriffsrechten und kein unabhängiges Sicherheitsgutachten.

## Empfohlene nächste Schritte
1. Gemeinsame Bedienelemente und Layoutregeln zentralisieren, damit spätere CSS-Ergänzungen bestehende Ansichten weniger beeinflussen.
2. Visuelle Regressionstests für Handy, iPad Mini und Desktop in der Veröffentlichungsprüfung ergänzen.
3. Spielbefehle längerfristig als einzelne serverseitige Aktionen statt vollständiger Raumstände speichern; Versionskonflikte klar anzeigen und wiederholte Übermittlungen eindeutig erkennen.
