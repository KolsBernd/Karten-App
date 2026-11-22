# Sicherheitsprüfung Kartabend 40

Diese Prüfung durch den Mitentwickler ist kein unabhängiges Sicherheitsaudit und keine Garantie gegen sämtliche Angriffe.

## Ergebnisse

Die neuen Raumspiele werden serverseitig auf zugelassene Spieler, Regeln, Punktvergabe, Abschluss und konsistente Historie geprüft. Rücknahmen verwenden einen gesperrten Datensatz und erwartete Revision. Direkte Manipulationen wurden in einer isolierten Datenbank abgewiesen. Neue Schafkopf-Einstellungen können nur Raumersteller ändern.

Live-Katalogprüfung vom 22. November 2026: keine hh-Tabelle ohne RLS, kein anonymer Zugriff auf die private TV-Sitzungstabelle, keine anonyme TV-Verwaltung oder Rücknahme. Sicherheitsfunktionen haben einen ausdrücklich gesetzten Suchpfad. Das ist eine Katalogprüfung, kein vollständiger Angriffstest aller vorhandenen Richtlinien.

TV-Links verwenden zufällige Geheimnisse, deren Hash gespeichert wird. Nur Ersteller stellen Links aus; gültige Linkinhaber lesen die bisherige maskierte Zuschauerprojektion. Ablauf nach höchstens 24 Stunden, vorzeitiger Widerruf und Bindung an den aktuellen Raum-/Tischcode. Bereinigung abgelaufener/widerrufener Sitzungen nach zusätzlichem Tag aktiv. Wer einen gültigen Zuschauerlink besitzt, darf dessen freigegebene Daten lesen und kann ihn weitergeben; daher nur gezielt teilen.

Die untersuchten App-Quelldateien enthalten keine gefundenen privaten Schlüssel oder Service-Schlüssel; config.js verwendet einen veröffentlichbaren Supabase-Schlüssel. Kein vollständiger Scan aller historischen Git-Commits. Ein öffentlicher Schlüssel ersetzt keine Zugriffsprüfung: https://supabase.com/docs/guides/getting-started/api-keys und https://supabase.com/docs/guides/database/postgres/row-level-security

## GitHub und Kopieren

Frontend-Code ist öffentlich abrufbar und technisch kopierbar, auch bei einer späteren privaten Quellcodeablage bleiben ausgelieferte Browserdateien lesbar. Das gewährt keine administrativen Datenbankrechte. Urheberrecht begrenzt erlaubte Nutzung, verhindert Kopieren aber nicht technisch. Öffentliche GitHub-Repositories können gemäß Plattformbedingungen angesehen und geforkt werden; ohne offene Lizenz entsteht keine allgemeine freie Weiterverwendungserlaubnis: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository

## Empfohlen

Automatisierte Sicherheits-/Regressionstests vor jedem Deployment, Wiederherstellungstests für Sicherungen, schrittweise Entfernung von Inline-Skripten zugunsten strengerer CSP, echte Geräteabnahme mit großer Schrift und langsamer Verbindung. Vor kommerziellem Betrieb ein unabhängiges Audit mit Richtlinien-, Abhängigkeits- und Penetrationstests durchführen lassen. Eine bereits vorhandene Chatverschlüsselung wurde in dieser Version nicht kryptographisch neu begutachtet.
