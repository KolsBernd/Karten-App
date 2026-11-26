# Prüfung Version 49

## Schafkopf im Online-Raum

Der Ersteller kann vor Beginn 1–50 Partien festlegen. Zwischenstände bleiben offen; der Abschluss erfolgt erst nach der Vorgabe. Die letzte Partie kann nach Bestätigung zurückgenommen werden. Die Punkte bleiben nach Abschluss erhalten. Für bestehende Daten ohne Vorgabe gilt weiterhin eine Einzelpartie. Jede Partie einer neuen Serie wird in persönlichen und globalen Statistiken einzeln gezählt.

## Turniere

Schafkopf startet mit 32 Partien und zwei Runden; beide Werte sind bis 50 wählbar. Bierkopf behält seine bisherigen Grenzen. Tischkarten und die kompakte Übersicht zeigen die gespielten Partien im Verhältnis zur Vorgabe.

## Serverprüfung

In Supabase mit vollständiger Rücknahme der Testdaten geprüft: Drei-Partien-Serie mit Zwischenständen und Abschluss, verfrühter/falscher Abschluss, Überlauf, Vorgaben 0 und 51, bisheriges Einzelpartieformat und Statistikaufteilung. Turnier mit 50/50 akzeptiert, 51 abgelehnt. Neuregistrierungsmeldung nur an die festgelegte Betreiberkennung; doppelte Auslösung erzeugt keine weitere Meldung. Profiländerung erzeugt keine Nachricht. Push-Text enthält keine Kontaktdaten.

Der vom Nutzer freigegebene einzelne Schafkopf-Testdatensatz (6 Punkte) wurde privat gesichert und gezielt gelöscht; anschließend verblieben null solche Statistikdatensätze. Andere Spielstände wurden nicht gelöscht. Die Sicherung gehört nicht zur Veröffentlichung.

## Oberflächen- und Funktionsprüfung

Die vorhandenen Regressionstests werden beibehalten und um Seriensummen, Abschluss, Rücknahme und Vorgaben ergänzt. Automatische Bildschirmtests laufen mit anonymen Testdaten auf zwei Handy- und zwei Tabletgrößen, jeweils Chromium/WebKit. Sie prüfen insbesondere Überlauf, feste Navigation, geladene Stile/Bilder und Schafkopfeinstellungen. Diese simulierten Ansichten ersetzen keinen Test auf physischen Geräten.

## Dokumentation und Datenschutz

Handbuch und Datenschutzerklärung tragen Version 49.0. Neue Betreiberbenachrichtigungen werden mit Zweck, Datenumfang, Empfänger und Löschfrist erklärt. PDFs werden gerendert und visuell geprüft. Handbuchbilder enthalten ausschließlich anonyme Testdaten.

Diese Entwicklungsprüfung ist kein unabhängiges Sicherheitsgutachten. Eine echte Neuregistrierung mit anschließendem Push-Empfang wurde nicht durch ein zusätzlich angelegtes Produktivkonto simuliert. Die bestehende Push-Einwilligung des Geräts bleibt erforderlich.
