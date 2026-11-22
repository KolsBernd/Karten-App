# Prüfung Kartabend 42 – 22. November 2026

## Ursache und Korrektur

In Version 41 war Krawallo als Spielart und als eigenes Eingabemodul vorhanden. Der tatsächliche Dispatcher in room-games.js rief für Krawallo jedoch noch die Schafkopf-Oberfläche auf. Dem sichtbaren Krawallo-Button fehlte außerdem data-game, wodurch Aktivmarkierung und zentrale Auswahl unvollständig waren. Die bisherigen Einzelmodultests deckten diese Verbindung nicht ab.

Version 42 ruft ausdrücklich den Krawallo-Renderer auf. Der Button besitzt dieselbe Kennung wie alle anderen Spielarten. Alle Spielbuttons verwenden einen gemeinsamen Ereignishandler, der die aktuelle Umschaltfunktion mit ihren Sperren für laufende Partien aufruft. Keine zweite Punkteberechnung und keine Umgehung der serverseitigen Regeln.

Schniffelkopf und Klopfer verwenden nun identische zentrierte Profil-Wrapper in den Spaltenüberschriften. Bildbutton und Name werden innerhalb ihrer eigenen Tabellenzelle mittig ausgerichtet; die linke Kategorie-/Rundenspalte behält ihre Breite. Lange Namen bleiben begrenzt. Die Tabellenzellen bleiben echte th-Elemente mit scope=col; keine Flex-Umwandlung der Tabellenzelle selbst.

## Tests

Ein neuer Test reproduzierte vor der Korrektur den fehlenden Krawallo-Selektor. Nach der Korrektur öffnet ein echter Button-Klick im vollständig gestarteten App-DOM Krawallo statt Schafkopf, markiert den aktiven Button, zeigt beide Teams, erfasst vier Punkte und übergibt den Krawallo-Datensatz an den vorhandenen Raum-Schreibaufruf.

Ein weiterer Test öffnet Schniffelkopf und Klopfer über die echten Spielbuttons. Beide Tabellen besitzen die gemeinsamen Kopf-Wrapper; align-items/text-align stehen auf center und beide seitlichen Bildbutton-Ränder auf auto. Die bestehenden Frontend-Regressionen einschließlich Punkteberechnung, Rücknahmen, Turniere, Datenschutz, Cast-Vorbereitung und Cache bestehen weiterhin. Alle JavaScript-Dateien und eingebetteten Skripte syntaktisch geprüft.

Keine Änderung der Spielregeln, Datenarten, Empfänger, Speicherfristen oder Freigaben. Die geprüfte Migration 44 aus Version 41 bleibt unverändert installiert; keine neue Servermigration erforderlich. Datenschutzerklärung bleibt sachlich unverändert. Nutzerhandbuch auf 42 aktualisiert, PDF gerendert und Krawallo-Kapitel visuell kontrolliert. Cache und ZIP enthalten ui42.css.

## Grenzen

DOM-/CSS-Tests sind keine Messung auf einem physischen iPad. Die lokale Browser-Vorschau ist in dieser Umgebung gesperrt; keine neuen Gerätescreenshots behauptet oder erzeugt. Handbuchbilder aus unveränderten Bereichen bleiben erhalten; der korrigierte Krawallo-Einstieg ist textlich aktualisiert. Diese Mitentwicklerprüfung ist kein unabhängiges Sicherheitsgutachten. Google Cast bleibt bis zur Betreiberregistrierung vorbereitet und inaktiv; AirPlay ist keine implementierte Web-Geräteauswahl.
