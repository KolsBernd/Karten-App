# Kartabend 36

https://kolsbernd.github.io/Karten-App/

Alle Funktionen der Version 35 bleiben enthalten: Klarnamen, eigene SVG-Kartenmotive nach Vorlage, optionale Schafkopf-Farberfassung und direkte Tischübersicht. Die Farbenstatistik erhält auch in der reduzierten Turnier-Gesamtansicht die gespeicherte Farbe.

Turniererstellungsrechte werden serverseitig anhand der Konto-ID freigeschaltet. Ersteller verwalten nur eigene Turniere, Gäste und Einladungen; fremde aktive Turniere bleiben ohne Zuteilung geschützt. Die globale App-Verwaltung bleibt ausschließlich beim bisher freigegebenen Verwaltungskonto. Die Oberfläche verwendet die vom Server bestätigten Rechte.

Migration 37-turnierersteller-und-pruefung.sql baut auf Version 35 auf. Sie bereitet die getrennten Turnierrechte vor, schaltet aber kein zusätzliches Konto frei und setzt keine Daten zurück. Eine Kontofreischaltung erfolgt getrennt im Projekt durch den Betreiber. Handbuch und Datenschutz sind aktualisiert.

Beide globalen Rücksetz-Buttons wurden im UI einschließlich zweier Bestätigungen und korrektem globalen Geltungsbereich geprüft; die zugehörigen Funktionen wurden mit befüllten Testdaten ausgeführt. Der ausdrücklich bestätigte einmalige produktive App-Neustart wurde erfolgreich durchgeführt: Konten, Profile und bestätigte Freundschaften unverändert; Räume, Turniere, Gäste und Statistiken leer. Kein Reset beim Laden oder Hochladen dieses Pakets.
