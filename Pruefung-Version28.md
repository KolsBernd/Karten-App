# Kartabend 28 · Änderungen und Prüfung

- „Aktive Räume“, „Anfragen“, „Archiv“ ersetzen die frühere Anfrage-Auswahl im Dropdown.
- Neue eigene Anfrage führt unmittelbar zu „Anfragen“. Die wählbare Freunde-Beschränkung bleibt erhalten; es werden keine privaten Anfragen öffentlich gemacht.
- Unvollständige, nicht umgewandelte Anfragen werden vier Stunden nach Termin archiviert. Ihr Chat bleibt für berechtigte Teilnehmer lesbar, aber erhält keine neuen Beiträge. Normale Räume behalten ihre getrennte Inaktivitätsregel.
- Datum und Uhrzeit bleiben innerhalb der Formularkachel. Größere Spielerlogos in der dauerhaften Ergebnisleiste; eine ältere Kurzbildschirmregel, die Team-Spielstände ausblendete, wurde behoben.
- Nutzerhandbuch mit 13 aktuellen Beispiel-Screenshots, HTML-Ansicht und 14-seitigem PDF unter Einstellungen; Download und Rückkehr zur App geprüft. Datenschutztext an die Archivierung angepasst.

## Prüfungen
JavaScript-Syntax aller Hauptdateien und eingebetteten Skripte; vollständige DOM-Abläufe; Erstellung/Anzeige eigener Anfrage; Archivtrennung und Schreibsperren; Datenbankmigration zweimal ausführbar und Rollen-/Spielregeltests; Cache und verschlüsselte Push-Erzeugung. Alle erfolgreich. Produktive Datenbankstruktur, Rollen, Zeitplan und Archiv-Trigger lesend bestätigt.

Browserprüfung der Datum-/Zeitfelder und Ergebnisleisten mit 320×740, 390×844, 744×1133, 768×1024 und 1024×768. Kein horizontaler Seitenüberlauf in den geprüften Ansichten. Kein Test auf physischem iPad Safari; dort bitte einmal bestätigen.

Das Handbuch wurde gerendert und visuell geprüft. Es ist mit Bilddateien im Offline-Paket enthalten. Ein Versionscheck und die Arbeitsanweisung im Projekt verlangen künftig eine Aktualisierung vor jeder Veröffentlichung.

Die Sicherheitsprüfung ist eine eigene Code- und Funktionsprüfung; siehe Sicherheitspruefung-Version28.md für offene Punkte. Sie ist kein unabhängiges Audit.
