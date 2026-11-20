# Prüfung Kartabend 33
20. November 2026

## Veröffentlicht
Der Schutz vor unbeabsichtigtem Löschen/Ändern bleibt aktiv. Alle umfassenden DELETE/UPDATE-Anweisungen der vorhandenen Verwaltungsfunktion haben explizite Bedingungen. Die Kontobindung, Berechtigungen, kurzlebige Bestätigung und die zwei Dialoge bleiben erhalten. Die Installation ersetzt Funktionen und führt keinen Reset aus. Definition in Supabase nach Installation lesend geprüft. Die nachfolgende Schafkopf-Migration erhält die Reset-Absicherung und leert beim Statistikreset auch Vierer-Punktestände.

Die gesamte vorhandene isolierte Datenbank-Regressionssuite ist erfolgreich. Zusätzliche Prüfung: Gesamtstatistik ohne Partien/Runden/Spielerwerte nach globalem Statistikreset; persönliche Reset-Marke für alle Profile; vollständiger Reset erhält Profile und bestätigte Freundschaften. Tests wurden ausschließlich mit synthetischen Daten in PGlite durchgeführt, nicht in der produktiven App. Die Safeupdate-Erweiterung selbst ist in dieser Testdatenbank nicht geladen; die expliziten Bedingungen wurden zusätzlich im SQL geprüft. Dokumentation: https://github.com/eradman/pg-safeupdate

DOM-Test: Gästeverwaltung nur im Turnier; direkter Einstellungsbutton; Ortschaft; 3/3-Vorgabe; fertige Tische zugeklappt und aufklappbar; Zustand bleibt beim Datenabgleich erhalten; QR/Verlauf im selben Aktionsraster. Bisherige gesamte DOM-Spiel-/Anmelde-/Freigabesuite erfolgreich. JavaScript-Syntax aller Skripte erfolgreich.

Handbuch HTML/PDF Version 33 aktualisiert; betroffene alte Screenshots entfernt, übrige unveränderte Abläufe behalten ihre Bilder. Datenschutz um die operatorinterne Ortschaftsanzeige ergänzt. PDFs gerendert und visuell geprüft. Öffnen/Download/Rückweg zusätzlich in DOM-Regressionssuite; keine neue visuelle Browserprüfung. Lokaler Webserver ist durch die Umgebung gesperrt; file:-Aufruf wurde vom Browser abgelehnt. Keine Umgehung. Deshalb kein Anspruch auf neue Geräte-/Safari-Sichtprüfung oder unabhängiges Audit.

## Schafkopf
Schafkopf-Einzelwertung mit Sitzplätzen, Solo/Tout, Kreuzspiel, 30/2-Vorgaben sowie serverseitigem Regelwerk und QR-Unterstützung ist nach den bestätigten Regeln umgesetzt. Ramsch entfällt. Sau vergibt Punkte an zwei ausdrücklich ausgewählte Gewinner. 64 Solo/Tout-, 24 Kreuzspiel- und 36 Sau-Verteilungen sowie ungültige Eingaben wurden isoliert geprüft. Eintrag, Rücknahme, Zählung, Konflikt, Rollen und QR-Maskierung sind getestet. Kein Spielbetrieb mit realen Nutzern getestet.
