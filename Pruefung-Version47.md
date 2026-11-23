# Prüfung Version 47 · 23. November 2026

## Bildschirmtests für Handy und Tablet

52 automatisierte Prüfungen bestanden im [Prüflauf](https://github.com/KolsBernd/Karten-App/actions/runs/45135927531): 13 tatsächliche App-Ansichten mit anonymen Testdaten in vier Browser-/Bildschirmkonfigurationen. Chromium: 390 × 844 und 1133 × 744. WebKit: 375 × 812 und 744 × 1133. Enthalten sind Anmeldung, Registrierung, Raumübersicht, Profil, Einstellungen, Anfrageformular und sieben Raumspiele.

Geprüft werden geladene Stil- und Bilddateien, unerwarteter horizontaler Seitenüberlauf, aus dem Bildschirm laufende Bedienelemente und die unveränderte Menüposition beim Scrollen. Gewollt horizontal verschiebbare Tabellen werden berücksichtigt. Die endgültige Testfassung prüft zusätzlich die untereinander liegenden Bierkopf-/Schleifer-Kacheln.

Die Bilder für Raumübersicht, 21 rückwärts und Schafkopf wurden angesehen und ins Handbuch übernommen. Es handelt sich um isolierte Browseransichten, nicht um physische iPhones oder iPads. Bildschirmtastatur, VoiceOver, Push und alle Turnier-/Chat-Sonderfälle sind damit nicht visuell abgenommen. Es gibt noch keine freigegebenen Pixelvergleichs-Baselines.

Ein echter Befund wurde behoben: Der feste Lobby-Menücontainer erbte auf schmalen Chromium-Ansichten `min-height:100dvh` vom Anmeldepanel; die Leiste erschien deshalb oben. Der Container hat jetzt eine eigene natürliche Höhe. Lange Raumnamen werden mit Auslassung angezeigt; die ausgewählten Schafkopf-Initialen haben einen eigenen Kontrast.

Der Testaufbau musste die produktive Sperre von `<base>` und die HTTPS-Aufwertung für den isolierten HTTP-Loopbackserver berücksichtigen. Diese Anpassungen gelten ausschließlich für erzeugte Testdateien. Die produktive Sicherheitsrichtlinie wurde nicht abgeschwächt. Ausgehende Testverbindungen und Skripte sind gesperrt.

## Aktueller Fehlerbericht

Die aktuelle Datenbankauswertung der letzten 30 Tage enthält zwölf Gruppen aus Versionen 38–44. Für 45 und 46 waren beim Lesen keine Meldungen vorhanden. Die jüngsten Einträge: Version 44 mit zwei allgemeinen Fehlern und einer abgewiesenen Regelprüfung. [Vollständige Auswertung](docs/FEHLERBERICHT-2026-11-23.md).

Ohne gespeicherte Rohmeldungen oder Reproduktion können diese historischen Meldungen nicht sicher konkreten Ursachen zugeordnet und nicht pauschal als behoben erklärt werden. Netzwerkfehler und Regelablehnungen sind nicht automatisch Programmfehler. Der Verwaltungsdialog erklärt nun die vorhandenen bereinigten Codes, ohne neue persönliche Inhalte zu protokollieren.

## Code und Dokumentation

- Unveränderte Zusatzspiel-Verläufe werden nicht bei jeder Eingabe neu aufgebaut. Der Regressionstest erhält dieselben DOM-Knoten und offene Details über 100 Renderaufrufe; neue Serverdatensätze, Profilname, Bild und Reset invalidieren den Cache.
- Krawallo teilt die kanonische Ergebnisauflösung zwischen Vorschau und gespeichertem Eintrag.
- Die gemeinsame Schafkopf-Erfassung wurde lesbar formatiert. Bestehende Regressionstests bleiben erhalten.
- Der App-Testaufbau wird von Funktions- und Bildschirmtests gemeinsam verwendet.
- README, Architektur, Entwicklung/Tests, Bedienregeln und Sicherheitsgrenzen liegen getrennt und verständlich als Markdown vor. Endnutzer erhalten das aktualisierte Handbuch als HTML/PDF.

Der Code ist noch nicht vollständig bereinigt: Der große HTML-Einstiegspunkt, 41 gewachsene Inline-Stilblöcke und einige dichte Module bleiben technische Schulden. Nächste Schritte sollten gemeinsame Komponenten und einzelne Modulzuständigkeiten herauslösen. Es wurde keine prozentuale Endgeräte-Beschleunigung gemessen.

## Zugriffsschutz und Kopierbarkeit

Alle App-Tabellen haben RLS; die Rolle anon hat keine direkten Tabellen-Leserechte. Die fünf vorgesehenen anonymen Funktionen wurden geprüft. Ungültige Codes werden von den vier codegebundenen Zugängen abgewiesen. Eine fremde angemeldete Identität erhält weder Reset-Vorbereitung noch Fehlerbericht. Die Testtransaktionen wurden zurückgerollt. Der Mustercheck fand in den aktuellen lokalen App-Dateien keine tatsächlichen Secret-Keys, privaten Schlüsselblöcke oder Datenbank-URLs mit Zugangsdaten.

Das ist eine begrenzte interne Prüfung, kein unabhängiges Sicherheitsgutachten. Nicht abgedeckt sind vollständige Git-Historie, sämtliche Serverfunktionen in allen Rollen, Infrastruktur und eine externe Prüfung der eigenen Chat-Kryptografie. [Details und verbleibende Risiken](SECURITY.md).

Die Oberfläche und die veröffentlichten SQL-Regeln lassen sich aus einem öffentlichen Repository technisch kopieren. Daraus folgt kein Administratorrecht auf das vorhandene Backend. Ein Browser-Schlüssel ist öffentlich vorgesehen; Anmeldung und Serverregeln bleiben die entscheidende Grenze.

## Veröffentlichung und Dokumente

JavaScript-Syntaxprüfung und vollständige Funktionstests bestanden. Handbuch HTML/PDF, neue anonyme Bilder, Offline-Aufnahme und ZIP wurden geprüft. Datenarten, Empfänger, Sichtbarkeit und Speicherfristen der App wurden nicht geändert; die Datenschutzerklärung bleibt inhaltlich unverändert.

Die direkte Live-Browserprüfung der GitHub-Pages-Adresse blieb trotz Nutzerfreigabe durch eine gespeicherte Browser-Sperre blockiert. Diese Sperre wurde nicht umgangen. Die Bildschirmtests liefen auf einem getrennten Prüfbranch ohne echte Konten oder Produktionszugriff.
