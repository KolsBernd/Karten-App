# Prüfung Kartabend 40 – 22. November 2026

## Umsetzung

Schniffelkopf: Kategorie in der Kreuztabelle antippen, Punkte per numerischem Eingabefenster erfassen, Standard 0. Alte untere Kategorie-/Punktauswahl entfällt. Veraltete Dialoge schreiben nicht in einen inzwischen gewechselten Raum oder Spielstand.

Klopfer: 4–8 Spieler, Stichbuttons 0 bis 11 minus Spielerzahl. Zahl ist anfangs 0; Richtig/Falsch muss ausdrücklich gewählt werden. Richtig gibt 5 plus Stiche, falsch 0. Historische Erfassungen bleiben lesbar.

21 rückwärts: Start 21, Stich −1, aktive Null +5; Herz −2/+10. Eichel verpflichtet alle zur Teilnahme, sonst ist Aussetzen je Eingabe möglich. Kein Grundspielbonus. Ende bei ≤0, niedrigste Punktzahl gewinnt. Aussetzen wird nach jeder Eingabe verworfen. Persönliche Fortschrittspunkte sind 21 minus verbleibende Punkte, keine Nettopunkte gegen Gegner.

Normales Schafkopf verwendet vier Plätze und die reine Pluswertung aus dem Turnier. Raum-Ersteller konfigurieren Spiele und Farberfassung; neue Einstellungen gelten ab der nächsten Partie. Jeder Eintrag schließt eine Einzelpartie ab, die obere Leiste zeigt kumulierte Schafkopfpunkte des Spielabends.

Abgeschlossene Spiele können nach Ja/Nein-Bestätigung um genau den letzten Eintrag zurückgenommen und geöffnet werden. Der Server prüft Raumzugehörigkeit, Revision und Historie. Turniertische bleiben nach Start der nächsten Runde beziehungsweise Archivierung gesperrt. Navigationsleisten liegen außerhalb des scrollenden Inhalts.

TV: unabhängige schreibgeschützte Ansicht, gesondert widerrufbarer Link, höchstens 24 Stunden. Bestehende Freigaben/Anonymisierung gelten. Nach Verbindungsausfall werden veraltete Ergebnisse nach 30 Sekunden ausgeblendet. Kein automatisches TV-Multi-View, kein nativer Cast-Sender; Modell-/Quellenabhängigkeit bleibt bestehen.

## Nachweise

Alle Frontend-Regressionen bestanden: vorhandene Anmeldung, Raumzustand, Turniere, Anfragen, Datenschutz, Cache, Diagnostik, Auszahlung; zusätzlich Zahlen-/Verdict-Auswahl, Tabellen-Eingabe, Navigation, neue Spiele und TV-Widerruf. JavaScript-Syntax wird dabei für die eingebettete App und die geladenen Module geprüft.

Isolierte vollständige Datenbankregression mit PGlite: historische Migrationen plus 41–43 zweimal; ungültige Punkte/Spieler/Settings abgelehnt, Rücknahme aller abgeschlossenen Spielarten, Turnier-Rundengrenze, Statistikaufbewahrung, Zuschauer-Maskierung, fremde/ungültige TV-Zugriffe und Widerruf geprüft. Keine Produktionsresets.

Live installiert: Migrationen 41–43. Katalogprüfung: 0 hh-Tabellen ohne RLS; anonymer Direktzugriff auf TV-Tabelle und TV-Verwaltung gesperrt; Rücknahme nur für angemeldete Nutzer mit zusätzlicher Funktionsprüfung; 0 hh-Sicherheitsfunktionen ohne festgelegten Suchpfad. TV-Bereinigung aktiv. Handbuch und Datenschutz-PDFs aktualisiert, gerendert und neue Kapitel visuell kontrolliert.

## Grenzen und nächste Schritte

DOM-Tests sind keine visuelle Abnahme auf iPad Mini, iPhone oder LG-TV. Die lokale Vorschau war in dieser Umgebung gesperrt, die gesperrte Live-Domain wurde nicht umgangen. Deshalb wurden keine neuen Gerätescreenshots erfunden; ältere Handbuchbilder illustrieren weiterhin die unveränderten Bereiche. Empfohlen: echte Geräte mit langen Namen, Hoch-/Querformat und vergrößerter Schrift prüfen; CI-Regressionen automatisieren; Inline-Code weiter trennen und strengere CSP vorbereiten; Wiederherstellung von Sicherungen regelmäßig testen. Für komfortables drahtloses TV-Pairing wäre ein eigener Empfänger beziehungsweise eine native Integration der nächste Ausbau.
