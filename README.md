# Kartabend 37

https://kolsbernd.github.io/Karten-App/

## Änderungen

- Turnierersteller können eigene archivierte Turniere nach links wischen und nach Ja/Nein-Bestätigung löschen. Aktive und fremde Turniere sind serverseitig gesperrt. Persönliche Ergebnisse registrierter Teilnehmer bleiben erhalten, Gaststatistiken und Verläufe verschwinden mit den Tischen.
- Profilpunkte sind tatsächlich erzielte Punkte, auch bei Niederlagen. 12:21 ergibt 12 Punkte und −9 Nettopunkte. Nettopunkte nur für Bierkopf/Schleifer. Tabelle und Kennzahlen enthalten eine Gesamtsumme sowie registrierte Turnierergebnisse einschließlich Schafkopf. Allgemeine Ranglisten bleiben beim Verschieben gelöschter Turnierergebnisse in den Ergebnisnachweis stabil.
- Raumsymbole entsprechen der Navigation: Pokal, Spielkarten, Fragezeichen. Nachrichten-Swipe unterstützt mobile Zeigergesten; ein Swipe öffnet keine Karte versehentlich.
- Einheitliche Aktionshöhen in vergleichbaren Gruppen, gleich breite Tisch-/Verlaufsbuttons. Rücknahme heißt Letzte Partie zurücknehmen und verlangt stets Ja/Nein, auch im QR-Erfassungszugang. Fehlende Tischberechtigung wird als Popup erklärt.
- Anfrage-Umwandlung wechselt in aktive Räume und schließt den Erstellmodus. Umgewandelte Anfragen erscheinen nicht zusätzlich im Archiv; + aus dem Archiv wechselt zuerst zur aktiven Ansicht.

## Aufbau der geänderten Abläufe

ui37.js kapselt barrierearme Dialoge und lokale Navigationssymbole. chat-gestures.js trennt Wischen von Klicks und vertikalem Scrollen. tournament.js bündelt Tischzugriff und bestätigte Archivaktionen. Die serverseitige Ergebnisprojektion berechnet Werte mengenbasiert mit einem einzigen Aggregat statt wiederholtem Kopieren wachsender JSON-Arrays. Mutation, Rechteprüfung und Erhalt registrierter Ergebnisse erfolgen atomar in der Datenbank. Normale interne round-/stage-Bezeichner bleiben stabil; geändert wurden die sichtbaren Buttontexte.

Migration 38-archiv-und-profilpunkte.sql baut auf Version 36 auf. Die Installation aktualisiert Funktionen und Ergebnisfelder, führt keine echte Archivlöschung und keinen Reset aus. Handbuch und Datenschutz aktualisiert. Umfang und Grenzen: Pruefung-Version37.md.
