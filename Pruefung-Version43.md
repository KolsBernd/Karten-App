# Prüfung Kartabend 43 – 22. November 2026

## Änderungen

21 rückwärts summiert vor dem Speichern ausschließlich Stiche aktiver Spieler. Erwartet sind fünf. Bei Abweichung nennt das Ja/Nein-Fenster Ist und Soll. Nein verwirft die Erfassung, Ja speichert eine ausdrücklich gekennzeichnete Ausnahme. Ausgesetzte Personen bleiben vom Stichzählen und von der Punkteänderung ausgenommen. Eichel lässt weiterhin niemanden aussetzen.

Klopfer besitzt je Spieler genau eine grün umrandete Stichzahl, Standard 0. Die korrekte Ansage zählt 5 plus Stichzahl, eine falsche zählt 0. Erwartete Gesamtsumme: 11 minus Spielerzahl, also 7/6/5/4/3 bei 4/5/6/7/8 Spielern. Auch hier kann eine abweichende Summe nur nach Ja/Nein gespeichert werden. Richtig/Falsch bleibt ausdrücklich auszuwählen.

Krawallo wählt Teams ausschließlich im Menü Spieler. Die bisherige allgemeine Teamkachel wird in dieser Spielart ausgeblendet; Bierkopf und Schleifer behalten ihre eigenen Teams. Nach dem ersten Eintrag bleiben die Krawallo-Teams unveränderlich. Nach Partieende bereitet ein eigener Button die nächste Partie vor, ohne alte Ergebnisse umzuschreiben.

Die kompakte Erfassung verwendet Solo, King, Geier, Wenz und Flatterer mit den vorhandenen Schniffelkopf-Logos. Flatterer hat dieselben vier Grundpunkte. Keine Farbauswahl. Ansage ist optional und durch erneutes Antippen abwählbar: Schneider angesagt, Schwarz angesagt, Tout, Aufsteher. Ohne Ansage gilt das Grundspiel. Geschossen bietet eine Stufe: Ohne ×1, Kontra ×2, Re ×4, Sub ×8. Ergebnis heißt Schneider frei, Schneider, Durch. Grundspiel 4/5/6; Schneider angesagt 6 beziehungsweise mit Durch 7; Schwarz angesagt 8; Tout 12. Aufsteher gibt 31 Punkte ohne Schuss und beendet sofort zugunsten des gewählten Teams. Tout und Aufsteher verlangen Bestätigung.

## Serverregeln und Kompatibilität

Migration 45 erweitert die bestehende Regelprüfung. Neue Einträge verwenden versionierte Formate. Der Server berechnet alle Punkte weiter unabhängig von der Vorschau, prüft bei den neuen Formaten die Stichsumme und ein echtes boolesches Ausnahme-Kontrollmerkmal. Alte Formate können nicht als neue Einträge angehängt werden. Ein solches Kontrollmerkmal dokumentiert die vom Client gemeldete Bestätigung; es ist kein kryptografischer Beweis einer menschlichen Interaktion.

Bereits gespeicherte Ergebnisse bleiben unverändert gültig, auch bei früher abweichenden Stichsummen oder früheren Krawallo-Farbangaben. Neue Einträge nach einer Rücknahme verwenden das neue Format. Die neue Krawallo-Erfassung speichert keine Farbe und höchstens die drei Schussstufen; vorhandene Daten behalten ihre ursprüngliche Wertung. Persönliche Statistik, Gastbegrenzung, Nettopunkte, Rücknahme und Zuschauer-Maskierung bleiben erhalten.

## Prüfungen

Alle bisherigen Frontend-Regressionen bestanden. Neue Prüfungen öffnen die vollständige App und bestätigen: Nein speichert nichts; Ja speichert genau einen als Ausnahme gekennzeichneten Eintrag. Getrennte DOM-/CSS-Prüfung: genau eine grüne Zahl pro Klopfer-Spieler, Anfangswert 0, Auswahlwechsel ersetzt den vorherigen Wert, korrekte/falsche Punkte. Krawallo-Prüfung: Teams im Spielermenü statt in der Erfassung, vorhandene Logos, keine Farbauswahl, optionale Ansage und Abwahl, Schussstufen, Durch-Punkte, sofortiger Aufsteher und gesperrte laufende Teams.

Die vollständige isolierte Datenbankregression führt die historischen Migrationen sowie 45 zweimal aus. Prüfungen über die realen Raum-Schreibfunktionen: unbestätigte Abweichung abgelehnt, bestätigte Abweichung angenommen, passende Summen ohne Ausnahme zulässig, ausgesetzte Spieler ignoriert, Herabstufung auf altes Eingabeformat abgelehnt. Flatterer, Durch, fehlende Farbe, korrekte Punkte, Aufsteher-Abschluss und Rücknahme bestanden. Keine Produktionsresets oder Test-Partien in der Live-Datenbank.

JavaScript-Syntax, lokale Dateiverweise und Cache geprüft. Handbuch 43 und Datenschutz aktualisiert; geänderte PDF-Seiten gerendert und visuell kontrolliert. Die Datenschutzerklärung erklärt das gespeicherte Kontrollmerkmal und die entfallene neue Krawallo-Farberfassung. Der Datenschutz-PDF-Text verwendet normale lateinische Wortumbrüche.

## Grenzen

Keine neue physische iPad-/iPhone-Geräteabnahme; die lokale Browser-Vorschau ist in dieser Umgebung gesperrt. DOM-/CSS-Tests ersetzen keine Pixelprüfung. Neue Abläufe sind im Handbuch beschrieben; vorhandene Bilder illustrieren unveränderte Bereiche, keine erfundenen neuen Gerätescreenshots. Diese Mitentwicklerprüfung ist kein unabhängiges Sicherheitsgutachten. Cast bleibt vorbereitet, AirPlay weiterhin gesonderter nativer Ausbau.

## Live-Installation

Migration 45 in Supabase installiert. Lesende Prüfung bestätigt Grundspiel frei/Schneider/Durch mit 4/5/6, Schneider angesagt mit Durch 7, Kontra/Re/Sub auf das Grundspiel mit 8/16/32 und Aufsteher 31. Neue Stichsummenprüfung und Versionsformate sind in den aktiven Funktionen vorhanden. Der anonyme Zugriff auf den zusätzlichen Regelhelfer bleibt gesperrt. Keine Produktions-Partie verändert. Nachweis: Version43-Serverpruefung.jpg im lokalen Ausgabeverzeichnis.
