# Kartabend 31 · Prüfung
19. November 2026.

- Freiwillige Auswahl beim ersten Eintritt in normalen Raum oder Turniertisch. Nein und Ja gleich große Buttons, Fokus zunächst Nein; Datenschutz im Pop-up erreichbar. Ablehnung verhindert keinen Spieleintritt.
- Ohne persönliche Freigabe bleiben öffentliche Namen/Bilder verborgen. Gäste ohne Konto standardmäßig Anonym. Interne, berechtigte Raumansichten werden nicht umbenannt.
- Serverfilter auch für frühere Team-/Schreibernamen, Bilder und beide QR-Lese-Endpunkte. Öffentliche Raumtitel generisch, um versteckte Namensnennungen in Freitexttiteln zu vermeiden. Ergebnisverläufe bleiben im beauftragten Anonym-Modell sichtbar.
- Kontogebundene Entscheidungen mit serverseitigem Zeitpunkt, Hinweistext und Versionskennung; veraltete angezeigte Versionen können nicht als Zustimmung zur neuen Fassung gespeichert werden. Wiederholte gleiche Entscheidungen erzeugen keine neuen Ereignisse. Begrenzung häufiger positiver Freigaben; Widerruf bleibt möglich.
- Auswahl pro Raum unter Raum-Einstellungen und an Turniertischen unter Tischstatistik änderbar. Globaler Widerruf in Einstellungen funktioniert auch für frühere Räume. Raumende deaktiviert die Freigabe und verlangt nach Wiederöffnung neue Auswahl. Endgültige Scope-Löschung entfernt Nachweise.

## Prüfungen
Alle bisherigen Datenbanktests plus neue Fälle erfolgreich: Default-Denial, eigene Zustimmung/Ablehnung, fremde/unauthentifizierte Änderungen abgewiesen, private Nachweistabelle geschützt, Bilder nur mit Freigabe, Einzel-/Globalwiderruf, keine fremden Widerrufe, alte Team-/Schreibernamen maskiert, erneute Auswahl nach Wiederöffnung und Bereinigung bei Tischlöschung. Datenbankmigration zweimal ausführbar. Tests in isolierter Datenbank, keine echten Zustimmungen im Namen anderer Nutzer erteilt.

Eine nicht gespeicherte Auswahl löst ein sichtbares Fehler-Pop-up aus, das ausdrücklich keine erfolgreiche Speicherung oder keinen Widerruf bestätigt. Auch dieser Fehlerfall wurde geprüft.

DOM-Tests zu Popup, Nein-Fokus, Datenschutzzugang und Eintritt trotz Ablehnung erfolgreich; vorhandene Spiel-/Team-/Rücksetztests weiterhin erfolgreich. Syntax, Offline-Cache und verschlüsselte Push-Erzeugung erfolgreich. Lokale Handyansicht geprüft. Handbuch und Datenschutz aktualisiert, PDFs gerendert und kontrolliert. Produktive Installation und Rechteprüfung erfolgreich; bei Nachkontrolle keine durch die Installation erfasste Entscheidung, private Tabellen, drei Lifecycle-Trigger und sichere Voreinstellung bestätigt.

## Grenzen
Kein unabhängiges Audit, keine Rechtsgarantie. Maskierung direkter Kennzeichen beweist keine vollständige Anonymität; die Rechtsgrundlage verbleibender Ergebnisdaten muss getrennt geklärt werden. Bestehende externe Kopien werden nicht zurückgerufen. Fehlende Verbindung kann die Speicherung eines Widerrufs verhindern; die App bestätigt ihn dann nicht. Kein neuer Test auf physischem iPad Safari. Gespeicherte Browser-Sperre für GitHub Pages bleibt respektiert; Freigabe- und Darstellungsprüfung lokal, Veröffentlichungsprüfung über GitHub.
