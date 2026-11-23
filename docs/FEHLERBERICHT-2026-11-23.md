# Fehlerbericht · 23. November 2026

Gelesen wurde die aktuelle Datenbanktabelle mit den zusammengefassten Fehlern der letzten 30 Tage. Zeitangaben unten sind Europe/Berlin. Der Bericht wurde nicht geleert.

| Version | Code | Anzahl | Zuletzt |
| --- | --- | ---: | --- |
| 44.0 | RPC_RULE | 1 | 23.11.2026 08:04:40 |
| 44.0 | JS_ERROR | 2 | 23.11.2026 08:04:39 |
| 42.0 | JS_ERROR | 1 | 22.11.2026 20:04:09 |
| 41.0 | NETWORK | 1 | 22.11.2026 19:20:28 |
| 41.0 | JS_ERROR | 1 | 22.11.2026 19:11:41 |
| 41.0 | JS_TYPE | 1 | 22.11.2026 19:11:13 |
| 40.0 | RPC_RULE | 2 | 22.11.2026 21:02:28 |
| 40.0 | JS_ERROR | 2 | 22.11.2026 21:02:27 |
| 39.0 | NETWORK | 76 | 22.11.2026 03:34:05 |
| 39.0 | JS_ERROR | 33 | 22.11.2026 01:32:49 |
| 39.0 | RPC_RULE | 1 | 21.11.2026 17:44:55 |
| 38.0 | JS_ERROR | 6 | 21.11.2026 14:56:48 |

Für Version 45 und 46 waren zum Lesezeitpunkt keine Einträge vorhanden. Das beweist nicht, dass diese Versionen fehlerfrei sind: Offlinegeräte, noch nicht übertragene Meldungen und geringe Nutzung können die Aussage begrenzen.

## Was muss behoben werden?

`JS_TYPE` und wiederkehrende `JS_ERROR` verdienen Untersuchung. Ohne konkrete Reproduktion können sie keinem bestimmten Programmfehler sicher zugeordnet werden. Es werden absichtlich keine Rohmeldungen, Stacktraces, Namen, Chattexte oder Raum-IDs gespeichert. Es wäre falsch, diese alten Meldungen allein aufgrund bestandener Tests als behoben zu erklären.

`NETWORK` kann durch Verbindungsabbrüche entstehen. `RPC_RULE` bedeutet eine serverseitige Ablehnung; diese kann bei unzulässigen Eingaben oder gleichzeitig geänderten Spielständen korrekt sein. Beide Codes sind nicht automatisch ein Programmdefekt.

Version 47 ergänzt im Verwaltungsdialog verständliche Erklärungen der vorhandenen Codes. Die übertragenen Daten und Speicherfristen werden dadurch nicht erweitert. Für eine weitere Fehlersuche helfen Spielart, ausgeführter Schritt, Uhrzeit und App-Version; persönliche Inhalte und Passwörter werden dafür nicht benötigt.
