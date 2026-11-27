# Kartabend 55

Kartabend verwaltet gemeinsame Spielstände, private Räume, Kartabendanfragen, Freundschaften und Turniere. Die Oberfläche läuft als installierbare Web-App; Supabase verwaltet Anmeldung, Zugriffsschutz und gemeinsame Daten.

- **App nutzen:** [Nutzerhandbuch öffnen](nutzerhandbuch.html), [PDF](nutzerhandbuch.pdf). Alle Spielregeln, Einladungen und Einstellungen werden dort ohne Programmierkenntnisse erklärt.
- **Code verstehen:** [Architektur](docs/ARCHITEKTUR.md) und [Entwicklung und Tests](docs/ENTWICKLUNG.md).
- **Sicherheit und Kopierbarkeit:** [Prüfumfang und Grenzen](SECURITY.md).
- **Aktueller Befund:** [Prüfung Version 53](Pruefung-Version53.md).
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

## Schafkopf (€): erster Dummy

Der zusätzliche Menüeintrag erscheint nur beim serverseitig freigegebenen Betreiberkonto Kolsbernd. Der isolierte Rechner verwendet anonyme Testspieler und speichert keine Geldspielstände. Regeln und Testgrenzen stehen im Nutzerhandbuch. `schafkopf-euro.js` rechnet intern mit ganzzahligen Viertelcent, damit die vorgegebenen Spitzenfaktoren und Salden ohne Rundung erhalten bleiben. Die statischen Dummy-Dateien sind kein vertraulicher Datenbereich; sie enthalten keine Konten oder Raumstände.

Version 51 ergänzt gemeinsame Tout-/Light-Auswahl, Bettel-Tout ×1,5, Ramsch-Klopfer und grüne Jungfrau-Porträts. Spitzen verwenden optimierte Kartenbilder (King: Könige, Solo/Geier: Ober, Wenz: Unter) in der Reihenfolge Eichel, Gras, Herz, Schellen. Verdeckte Ergebniszuschläge und Spitzen beeinflussen die Berechnung nicht.

Version 52 verwendet die freigegebenen Kartenmotive aus dem bereitgestellten Kartendeck. Spitz, Bagga und Bettel rechnen ohne Ergebniszuschläge. Tout und Ansage erhalten kürzere Beschriftungen; Leger beginnt ohne Auswahl.

Version 53 korrigiert den Verweis auf die lokal ausgelieferte Supabase-Bibliothek. Abhängigkeitsprüfung und echter anonymer Browserstart ergänzen die bisherigen Tests. Yannik erhält die isolierte Euro-Testansicht ohne Verwaltungsrechte.

Version 54: Die Euro-Testeinstellungen zeigen ausschließlich Beträge und passende Spielsymbole. Jungfrau trägt den Hinweis „Nur bei Ramsch“. Die bestehende Menüfreigabe bleibt ausschließlich bei Kolsbernd und Yannik. Keine neue serverseitige Geldspeicherung. Veröffentlichung auf ausdrücklichen Wunsch ohne weitere Tests.

Version 55 integriert Schafkopf (€) als serverseitig gespeichertes Raumspiel mit dauerhafter Ergebnisanzeige. Auswahl und Erfassung bleiben Kolsbernd und Yannik vorbehalten. Bestätigte Raummitglieder können mitlesen. Keine Übernahme in Profil-/Globalstatistiken oder Zuschauerfreigaben. Vor Veröffentlichung ist 49-euro-raumspiel.sql in Supabase einzurichten. Keine weiteren Tests auf ausdrücklichen Wunsch.
