# Kartabend 30 · Prüfung und Änderungen

19. November 2026.

## Umgesetzt
- Normale Räume: getrennte Pop-ups mit QR für Beitritt (eigenes Konto, Einladung sieben Tage) und Zuschauerzugang (ohne Anmeldung, nur lesend).
- Zuschauer-Code nur durch Raumersteller erzeugbar. Derselbe Code bleibt während des geöffneten Raums gültig; bewusstes Erneuern sperrt den alten Code. Beenden bzw. automatisches Archivieren löscht den Zugang. Nach Wiederöffnung entsteht ein neuer Code.
- Öffentliche Antwort enthält nur Raumname, Spieler-Namen/-Bilder und freigegebene Spielstände/Verläufe. Kontokennungen, Kontaktangaben, Chats und private Profilfelder werden nicht ausgegeben. Private Schlüsselfunktion und Freigabetabelle nicht direkt aufrufbar/lesbar.
- Eigene Geräteauswahl für neue Kartabendanfragen von Freunden; von neuen Online-Räumen unabhängig. Vorhandene gemeinsame Einstellung wird erhalten und kann getrennt geändert werden. Kompatibilitätsfunktion für ältere App-Versionen erhält die neue unabhängige Auswahl.
- App-Verwaltung zwischen Datenschutz und Über die App. Handbuchhinweis und separate Download-Buttons aus Einstellungen entfernt; PDF-Download verbleibt im jeweiligen Dokumentfenster.
- Handbuch besitzt im eingebetteten Fenster nur eine Werkzeugleiste, auch nach Auswahl eines Inhaltsverzeichnispunkts. Datenschutzerklärung hat keinen eigenen doppelten Zurück-Link; äußerer Zurück-Button bleibt erhalten.
- Anfrage absagen am Ende des Detaildialogs und der Bearbeitung, volle Buttonbreite, mit Ja-/Nein-Sicherheitsdialog. Nein führt keinen Löschaufruf aus.
- Größere, responsive Logos/Namen in der Ergebnisleiste. Sechserbesetzung bei 320 Pixeln ohne horizontalen Seitenüberlauf geprüft.
- Nutzerhandbuch Version 30, 16 Seiten, aktualisierte Aufnahmen und neues QR-Kapitel. Datenschutz HTML/PDF sachlich aktualisiert; künftige Anpassungen im Versionsablauf festgehalten.

## Erfolgreiche Tests
SQL-Migration in isolierter Datenbank zweimal installiert; fremde/anonyme Code-Erstellung und ungültige Tokens abgewiesen; öffentliche Schreibaufrufe gesperrt; Sperrung nach Erneuern, Beenden und Wiederöffnen bestätigt. Unabhängige Push-Auswahl und alte Client-Schnittstelle geprüft. Keine produktiven Räume oder Anfragen für diese Tests erstellt.

Öffentliche Anzeige mit Testdaten: 3:12 und Verlauf 3:0 → 3:12, keine Eingabefelder, keine persistente Anmeldung, nur lesender Datenaufruf. Namen werden als Text behandelt, unsichere Bildquellen abgewiesen. Bestehende DOM-/Datenbanktests, Syntaxprüfungen, Cache und Push-Erzeugung erfolgreich. Keine reale Handy-Push-Testnachricht versandt.

Browserprüfung mit lokalen Testdaten: QR-Pop-ups mit sichtbarem Schließen, Dokumentnavigation, PDF-Download, Rückweg in Einstellungen, responsive Anzeige. PDF gerendert und kontrolliert. Produktive Serverinstallation erfolgreich; anschließend ACLs, private Tabelle/Schlüsselhilfe, Endetrigger und eigene Push-Spalte lesend bestätigt. Es war bei Prüfung noch kein produktiver Raum über den neuen QR-Zugang freigegeben.

## Grenzen
Kein unabhängiges Audit und keine Rechtsberatung. Echte iPadOS-Safari-Darstellung und Empfang auf einem realen Handy sind hier nicht neu getestet. Zuschauer können bereits gesehene Inhalte kopieren; Codewechsel ruft diese Kopien nicht zurück. Anzeige fragt alle fünf Sekunden ab, bei Netzwerkunterbrechung können zuletzt empfangene Werte noch sichtbar sein. Die Freigabe setzt eine geklärte Berechtigung hinsichtlich der Teilnehmerangaben voraus. Siehe `Rechtliche-Hinweise-Version30.md`. Die gespeicherte Browser-Sperre für GitHub Pages bleibt respektiert; Veröffentlichungsstatus wird über GitHub geprüft.
