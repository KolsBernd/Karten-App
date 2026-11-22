# Prüfung Kartabend 41 – 22. November 2026

## Änderungen

Krawallo ist eine eigene Raumspielart für vier Spieler in zwei festen Zweierteams. Die vier Positionen sind zunächst Team 1 (erste zwei) und Team 2 (letzte zwei); die Teamwahl zeigt Profile und blendet die Mitglieder des anderen Teams aus. Während einer Partie bleibt die Zuordnung fest.

Wertung nach https://krawallo.weebly.com/regeln.html und den Unterseiten: Grundspiel 4, unangekündigter Schneider 5, unangekündigter Schwarz 6; Schneider angesagt 6 beziehungsweise mit Schwarz 7; Schwarz angesagt 8; Tout 12. Schuss/Re/Sup usw. verdoppeln jeweils, bis zehn Verdopplungen in der Eingabe. Aufsteher ist ein Herz-Solo mit allen Stichen, ohne Multiplikator 31 Punkte und sofortiger Abschluss. Sonst endet die Partie ab 31. Es werden keine Einsätze oder Zahlungen erfasst. Die abweichende erste Bildvorlage wird nicht mit diesen Regeln vermischt.

Die zusätzliche serverseitige Regelprüfung berechnet jede Wertung neu, prüft die vier Spieler, die Reihenfolge der festen Teams, die Punktesummen, zulässige Ansage/Ergebnis-Kombinationen sowie den Abschluss. Rücknahme nach Abschluss öffnet die Partie wieder. Persönliche Statistik zählt die eigenen Teampunkte, auch bei Niederlage; Nettopunkte sind eigene minus gegnerische Teampunkte. Registrierte Ergebnisse bleiben nach Raumlöschung erhalten, Gäste nicht.

21 rückwärts: Farbe und Stichzahl werden grün umrandet, Standardstichzahl bleibt 0. Bei Eichel müssen alle teilnehmen. Ein mit X ausgesetzter Spieler behält bei allen anderen Farben seinen Stand, auch bei Herz und 0 Stichen. Das Aussetzen gilt nur für den einzelnen Eintrag. Teilen sitzt rechts oben neben der Überschrift.

## Google Cast / AirPlay

Sender und eigener Cast-Empfänger sind vorbereitet. Das Teilen-Menü bietet keinen sichtbaren TV-Link mehr. Bei eingerichteter App-ID lädt es nach Benutzeraktion das offizielle Google-SDK; erst nach Fernseherauswahl erstellt es einen zeitlich begrenzten Lesezugang und sendet ausschließlich dessen Kennung und Geheimnis an den Empfänger. App-Anmeldedaten werden nicht übertragen. Widerruf bleibt nach einem erneuten App-Aufruf möglich.

Es ist bewusst keine Cast-App-ID eingetragen. Die Google-Konsole fordert die Anmeldung des Betreibers; dieser richtet sein separates Konto später ein. Bis dahin ist die Geräteauswahl deaktiviert und als Einrichtung erforderlich gekennzeichnet. Keine externe SDK-Anfrage ohne konfigurierte ID. Die Registrierung ist einmalig für den Betreiber, nicht für jeden Mitspieler. Anleitung: CAST-EINRICHTUNG.md.

AirPlay für eine eigenständige HTML-Spielstandsanzeige mit Gerätepicker ist nicht als Web-Funktion implementiert. Der Hinweis erklärt die vorhandene iPhone-Bildschirmspiegelung und deren Einschränkungen. Ein nativer Ausbau muss gesondert geplant und am Gerät geprüft werden. TV-Multi-View wird weiterhin am Fernseher bedient.

## Validierung

Alle bisherigen Frontend-Regressionen bestehen. Neue Tests prüfen die komplette Krawallo-Wertungsmatrix, Verdopplungen, ungültige Kombinationen, Abschluss, tatsächliche Team-Eingabe und Nettopunkte. Cast-Tests verwenden einen simulierten Empfänger: Konfiguration, verzögertes SDK-Laden, Geräteauswahlaufruf, minimale Nachricht, Ausschluss ungültiger Tokens und Widerruf. Dies ist kein Test einer realen Cast-Verbindung.

Die isolierte vollständige Datenbankregression mit PGlite führt die historischen Migrationen und Migration 44 zweimal aus. Echte Raum-Schreibfunktionen akzeptieren korrekte Krawallo-Daten und weisen manipulierte Punkte sowie Teamtausch ab. Abschluss, Rücknahme, appweite Statistik, Profil-Nettopunkte, Aufsteher, registrierte Aufbewahrung nach Raumlöschung und anonymisierte TV-Projektion bestanden. Bestehende Zugriffs-/Verschlüsselungstests bleiben enthalten. Keine Produktionsspielstände für Tests verändert.

Alle externen und eingebetteten JavaScript-Dateien syntaktisch geprüft. Handbuch 41 und Datenschutz aktualisiert, PDF-Seiten für Krawallo, TV und Datenschutz gerendert und visuell geprüft. Cache und ZIP enthalten die neuen lokalen Assets. Cast-Empfänger ist ein eigener Online-Einstieg und wird nicht vom Handy-Service-Worker vorab geladen.

## Grenzen

Diese Mitentwicklerprüfung ist kein unabhängiges Sicherheitsgutachten. Die lokale Browser-Vorschau konnte wegen gesperrter Netzwerkbindung nicht gestartet werden. Keine neue visuelle Geräteabnahme oder erfundene Screenshots. Bestehende Handbuchbilder illustrieren unveränderte Bereiche, neue Abläufe sind textlich erklärt. Vor Cast-Aktivierung echte Empfänger mit WLAN-Wechsel, Hintergrundbetrieb, Widerruf und Ablauf prüfen. AirPlay bleibt offen.

## Live-Installation

Migration 44 in Supabase installiert. Lesende Prüfung bestätigt Grundspiel 4, Schneider angesagt 6, Schwarz angesagt 8, Tout 12, Grundspiel mit einer Verdopplung 8 sowie Aufsteher 31. Anonyme direkte Ausführung der Regelmutation und Rücknahme bleibt gesperrt. Nachweis: Version41-Serverpruefung.jpg im lokalen Ausgabeverzeichnis. Google Cast bleibt ohne App-ID inaktiv.
