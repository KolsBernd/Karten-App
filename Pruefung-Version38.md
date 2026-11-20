# Prüfung Kartabend 38 – 21. November 2026

## Umsetzung

15 bestehende Funktionen wurden aus dem Online-Einstieg in drei explizit angebundene Module verschoben: Anmeldung (login/register/recover/signedIn), Raumzustand (adopt/fetchState/loadRoom/flush/heartbeat/stopPresence), Profilauswertung (recordsForRoom/roomPlayerStats/statTiles/renderLobbyStatistics/renderProfileMetrics). Bestehende Aufrufnamen bleiben als Delegationen erhalten. Gemeinsamer Zustand verbleibt während dieser ersten Umbauphase im Einstiegspunkt; Adapter haben Live-Zugriff statt eingefrorener Kopien. Die Profiltabelle wird für eigenes und befreundetes Profil wiederverwendet. Turniercode wurde lesbar formatiert.

Die Archivaktion ist im Ruhezustand verborgen; Swipe legt sie frei. Die Entf-Taste am fokussierten Turniereintrag bietet einen zugänglichen Alternativweg mit derselben Bestätigung. Abbrechen ist die letzte vollbreite Verwaltungsaktion. Rankingtabellen zeigen Startnummern separat, einschließlich beider Nummern bei Team-Paaren. Optionales Turnierlogo: lokale PNG-Neucodierung, maximal 5 MB Eingang / 60.000 Zeichen Speicherung, serverseitige Prüfung des PNG-Headers und maximal 256 × 256 Pixel. Das Bild wird weiterhin über den Bilddecoder dargestellt, nie als HTML/SVG ausgeführt.

## Durchgeführte Regressionen

- Syntax aller externen JavaScript-Dateien sowie ausführbarer Inline-Skripte; vollständiger DOM-Start mit den neuen Modulen.
- Bestehende Anmelde-, Profil-, Raum-, Team-, Punktelimit-, Einladungs-, QR-, Datenschutz-, Reset- und Spieltests unverändert in ihrem fachlichen Umfang. Hinzu kommen Klick auf Freundesavatar, Freundesprofil-Tabelle und verworfene verspätete Modalantworten.
- Bestehende Turnier-, Anfrage-Umwandlungs-, Schafkopf-, Gast-Erfassungs- und Cachetests. Ergänzt: eigene Startnummernspalte, kein #-Präfix in Rankingnamen, vollbreite letzte Abbruchaktion und Logofeld.
- Isolierte PGlite-Datenbank mit gesamter vorhandener Migrationshistorie, neue Migration zweimal angewandt. Neue Prüfungen: Logo gültig/ungültig/erhalten/entfernt; bestätigte Freunde, fremde und blockierte Konten, anonyme und direkte Tabellenzugriffe; Verlustpunkte 12 und Nettopunkte −9 im Freundesprofil; idempotente Fehlerzählung und geschützte Berichtsfunktion. Bestehende globale Rücksetzprüfungen weiterhin bestanden. Alle Lösch-/Resettests ausschließlich in der isolierten Testdatenbank.
- Fehlererfassung: keine Rohtexte oder Kontokennungen im gespeicherten/übertragenen Diagnosedatensatz; Zählung wiederholter Fehler, identische Übertragungskennung nach Offlinefehler, kein Versand vor Anmeldung, Zeitstempel und Berichtstabelle.
- Datenbank-Installation live anhand vorhandener Funktionen, geschützter Tabellenrechte, fehlendem anonymen Zugriff und aktivem täglichen Bereinigungslauf verifiziert. Es wurden keine Produktionsspielstände zu Testzwecken angelegt, gelöscht oder zurückgesetzt.
- Handbuch und Datenschutz HTML/PDF aktualisiert; betroffene PDF-Seiten gerendert und visuell geprüft. Historische Verifizierungsmail-Anlage datenschutz-v32.pdf unverändert.

## Diagnosedaten

Nur feste Codes, Bereich ui/global/resource, Version, Häufigkeit, erster und letzter Zeitpunkt. Keine Rohmeldung, kein Stack, keine URL, kein Raum, Chat, Passwort, Telefonnummer oder Benutzername. Lokal bis zu 20 Gruppen / sieben Tage. Angemeldeter Versand an die vorhandene Supabase-Datenbank; zufällige Batch-ID verhindert doppelte Zählung. Betreiberübersicht nur über unveränderliche Admin-Konto-ID. Serveraggregate für die letzten 30 Kalendertage, tägliche Löschung; technische Batch-Kennungen neun Tage und Konto-ID zur Ratenbegrenzung ein Tag, jeweils täglicher Bereinigungslauf. Die Auswertung ist technische Fehlerdiagnose, kein unabhängiges Sicherheitsgutachten.

## Responsive-Prüfung und Grenzen

Quellcode und DOM auf flexible Breiten, min-width:0, lokale Tabellenscroller, Wortumbruch, begrenzte Dialogbreiten und vergleichbare Mindest-Aktionshöhen geprüft. Version 38 ergänzt diese Regeln für neue Rangspalten, Freundesprofil, Fehlerbericht und Logos. Keine globale Verkleinerung der Schrift zugunsten vermeintlich fester Proportionen: Lesbarkeit und Bedienfläche haben Vorrang.

Die Live-Domain war im Browserzugriff nicht verfügbar; das Starten einer lokalen HTTP-Vorschau wurde durch die Umgebung verweigert. Deshalb keine neue visuelle Prüfung auf iPhone/iPad/Android und keine neu behaupteten Gerätescreenshots. Betroffene veraltete Handbuchbilder werden nicht als Version-38-Ansichten ausgegeben. JSDOM prüft Abläufe, nicht CSS-Layout. Eine reale Kontrolle mit langen Doppelnamen, großem Systemtext, Hell/Dunkel sowie Hoch-/Querformat auf 360, 390, 768, 820 und 1024 Pixeln bleibt sinnvoll.

## Empfehlungen

1. Wählbare größere Schrift und eine ruhigere, großzügigere Ergebnis-Eingabe für ältere Mitspieler.
2. Tabellen mit fixer Namensspalte und klarer horizontaler Scrollanzeige auf schmalen Geräten.
3. Nach dieser kompatiblen Modultrennung den gemeinsamen Raumzustand schrittweise vollständig dem Raum-Modul übertragen und die vielen historischen CSS-Ergänzungen nach realen Geräte-Screenshots konsolidieren.
4. Vor öffentlicher Vermarktung eine externe Sicherheits- und Datenschutzprüfung sowie ein dokumentiertes Backup-/Wiederherstellungsverfahren durchführen lassen.
