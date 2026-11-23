# Kartabend 48

Kartabend verwaltet gemeinsame Spielstände, private Räume, Kartabendanfragen, Freundschaften und Turniere. Die Oberfläche läuft als installierbare Web-App; Supabase verwaltet Anmeldung, Zugriffsschutz und gemeinsame Daten.

- **App nutzen:** [Nutzerhandbuch öffnen](nutzerhandbuch.html), [PDF](nutzerhandbuch.pdf). Alle Spielregeln, Einladungen und Einstellungen werden dort ohne Programmierkenntnisse erklärt.
- **Code verstehen:** [Architektur](docs/ARCHITEKTUR.md) und [Entwicklung und Tests](docs/ENTWICKLUNG.md).
- **Sicherheit und Kopierbarkeit:** [Prüfumfang und Grenzen](SECURITY.md).
- **Aktueller Befund:** [Prüfung Version 47](Pruefung-Version48.md).
- **Einheitliche Bedienung:** [Gestaltungsregeln](docs/BEDIENUNG.md).

## Betrieb

Die veröffentlichten Dateien liegen im Stammverzeichnis des GitHub-Pages-Repositories. Die öffentliche Supabase-Adresse und der Browser-Schlüssel stehen in `config.js`. Dieser Schlüssel ist kein Administratorpasswort. Server-Schlüssel, SMTP-Zugang, private Schlüssel und Datenbanksicherungen gehören niemals ins Repository.

Anmeldung und Online-Räume benötigen die eingerichteten Supabase-Funktionen. Eine Kopie der HTML-Dateien ist keine eigenständige Kopie des Backends. Bestehende SQL-Dateien dokumentieren die Entwicklung; sie sind keine Einladung, alle Migrationen ungeprüft erneut in einer produktiven Datenbank auszuführen.

## Änderungen in Version 47

Die mobile Menüleiste übernimmt nicht mehr die Mindesthöhe eines Anmeldefensters. Unveränderte Zusatzspiel-Historien werden bei Eingaben nicht erneut aufgebaut. Änderungen an Profilen, neue Serverstände und Rücksetzungen aktualisieren sie weiterhin. Krawallo verwendet dieselbe Berechnung für Vorschau und gespeicherten Ausgang. Das Fehlerprotokoll erklärt die bereinigten Fehlercodes. Isolierte Bildschirmtests ergänzen die bisherigen Funktionstests.

## Noch vorbereitet

Google Cast bleibt ohne öffentliche Receiver-App-ID deaktiviert. [Einrichtung](CAST-EINRICHTUNG.md). Eine unabhängige AirPlay-Ausgabe benötigt weiterhin einen nativen Ausbau.

## Urheberrecht

Die eigene Software unterliegt dem Urheberrecht von Bernd Dinkel. Enthaltene Fremdbibliotheken und deren Lizenzhinweise bleiben davon unberührt. Ein öffentliches Repository macht den Code technisch lesbar und innerhalb der GitHub-Regeln forkbar; es erteilt keine pauschale Erlaubnis zu beliebiger Weiterverwendung.

Version 48 gleicht die Krawallo-Teamauswahl mit ausdrücklichem Teams-speichern-Button an die anderen Teamspiele an. Vier getrennte, flexible Profilspalten verhindern abgeschnittene Logos.
