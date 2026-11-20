# Kartabend 37 · Prüfung
20. November 2026

## Funktion und Sicherheit

- Gesamte bisherige isolierte Datenbank-Regressionssuite plus Migration 38 zweimal erfolgreich. Archivlöschung verweigert anonymen Nutzern, fremden Erstellern, aktiven Turnieren und wiederholten Löschversuchen den Zugriff. Ein registrierter Teilnehmer mit Niederlage 12:21 behält 12 tatsächliche Punkte und −9 Nettopunkte vor und nach Turnier-/Raumlöschung. Schafkopf zählt positive eigene Punkte ohne Nettowertung; Gäste werden nicht dauerhaft übernommen. Allgemeine Ranglisten und Gesamtpartien bleiben vor/nach Archivlöschung gleich.
- Beide globalen Rücksetzfunktionen nochmals nach Migration 38 mit befüllten Testdaten erfolgreich: neue gespeicherte Ergebnisse und Turnierwerte geleert; registrierte Profile/Freundschaften unverändert. Keine zusätzlichen produktiven Resets oder echten Turnierlöschungen zum Test ausgeführt.
- DOM-Tests: tatsächliche Verlustpunkte und Gesamtzeile; Netto nur Teamspiele; Swipe bei Mitteilungen und bei einem als Button ausgeführten Turnierarchiv-Eintrag; Abbruch verhindert Löschen; Bestätigung führt zum vorgesehenen Aufruf. Unzugeteilter Tisch zeigt ein Popup und wird nicht geöffnet. Raum-/Anfrage-Symbole lokal aus der Navigation.
- Rücknahme mit Nein unverändert, mit Ja genau der gewünschte Aufruf. Normale Teamspiele, Schniffelkopf, Klopfer, Schafkopf und die eingeschränkte QR-Erfassung verwenden die vorgesehenen Bestätigungswege; unnötiger zusätzlicher nativer QR-Browserdialog entfernt. Gleichzeitige Dialoge im gemeinsamen Helfer abgefangen.
- Anfrage mit nur einem von vier zugesagten Spielern in Raum umgewandelt: Erstellformular verschwindet, aktive Ansicht gewählt; nach Archivwechsel keine doppelte Anfrage; neuer Erstellmodus beginnt wieder mit Online-Raum. Vollständige bisherige Anmelde-/Spielsuite, Syntax, Offline-Cache und ZIP-Inhalte geprüft.

## Darstellung und Dokumentation

Aktionsgruppen verwenden ein gemeinsames Höhenmaß und begrenzte, umbrechbare Beschriftungen. Tisch öffnen und Bisherige Partien und Runden erhalten gleiche Breite und Zielhöhe. Kartensymbole, Avatarauswahlen und Navigationsflächen bleiben ihren Funktionen entsprechend eigene Elemente. Eine pixelgenaue Gleichheit sämtlicher verschiedenartiger Schaltflächen auf jedem Gerät wird nicht behauptet.

Keine neue visuelle Live-/iPad-Prüfung: Die bestehende Browser-/Vorschau-Sperre wurde nicht umgangen. Für geänderte Handbuchabläufe wurden veraltete Screenshots aus den betreffenden Kapiteln entfernt und die Anleitung textlich aktualisiert; keine fingierten neuen Aufnahmen. Handbuch/PDF Version 37 und Datenschutz aktualisiert, gerendert und visuell geprüft. Kein unabhängiges Sicherheitsgutachten.

## Nächste sinnvolle Schritte

Die große index.html enthält weiterhin historisch gewachsene Zuständigkeiten. Gemeinsame Dialoge, Archivzugriff und Statistikprojektion sind jetzt gekapselt und kommentiert. Ein weiterer sinnvoller Schritt wäre, Anmeldung, Raumzustand und Profilauswertung schrittweise in eigene Module zu verschieben und jeweils die vorhandenen Regressionstests beizubehalten. Ein vollständiger Umbau parallel zu Spielregeländerungen wäre schwerer zuverlässig zu prüfen.
