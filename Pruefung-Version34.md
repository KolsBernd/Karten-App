# Kartabend 34 · Prüfung
20. November 2026

- Neue Migration zweimal ausführbar. Isolierte Datenbank-Regressionssuite einschließlich bisheriger Spiel-/Freigabe-/Reset-Fälle erfolgreich.
- Tout ohne Bestätigungsflag abgewiesen; bestätigter Tout erzeugt eine Mitteilung ausschließlich für den Ersteller. Name wird serverseitig aus dem ausgewählten Spieler ermittelt; Tisch und Spiel aus dem Ergebnis. Andere Teilnehmer erhalten keine entsprechende Nachricht. Unread, Lesen, Ausblenden und Wiedereinblenden geprüft. Rücknahme entfernt die zugehörige Mitteilung. Keine neuen Push-Jobs für diese Mitteilungsart.
- Ortschaften bleiben in der Turnierantwort nur für den Ersteller sichtbar. Kreuzspiel prüft zwei ausdrücklich gewählte Spieler und die festen Paare. Vorherige Kreuzspiel-Clients werden kompatibel auf das feste Paar abgebildet. Die neue Oberfläche verlangt beide Markierungen.
- DOM-Tests: Tischstart hinter Punktleiste; separate Tout-Kategorie; Bestätigungsabbruch ohne Speicherung; zwei Gewinner; horizontale Spielerstruktur; Gästeverwaltung im laufenden Turnier verborgen; zentrierte Tischübersicht mit vier Platzständen; Rückweg und weiterhin aufklappbare fertige Tische.
- JavaScript-Syntax, vollständige bisherige DOM-Anmelde-/Spielsuite und Offline-Cache geprüft. Handbuch/PDF und Datenschutz aktualisiert und gerendert. Keine neue visuelle Browser-/iPad-Prüfung: Die lokale Vorschau ist durch die Umgebung gesperrt; die bestehende Browser-Sperre wurde nicht umgangen. Betroffene Handbuchabläufe sind textlich beschrieben; keine fingierten neuen Bildschirmbilder.
- Installation erzeugt keine echte Tout-Mitteilung und setzt keine echten Ergebnisse zurück. Keine neue Einwilligung oder zusätzliche Veröffentlichung von Ortschaften. Kein unabhängiges Sicherheitsgutachten.
