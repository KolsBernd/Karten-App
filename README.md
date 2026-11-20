# Kartabend 34

https://kolsbernd.github.io/Karten-App/

Tischstart steht unter den Punkten. Bei Sau und Kreuzspiel müssen zwei Gewinner grün markiert werden; Kreuzspiel bleibt bei den festen Paaren 1+3 oder 2+4. Ergebnis, Ausgang und die separate Tout-Kategorie sind rot markiert. Ein Tout wird vor dem Speichern bestätigt und erzeugt nach erfolgreicher Eintragung eine interne Mitteilung mit Spieler, Tisch und Spiel an den Turnierersteller. Rücknahme entfernt die zugehörige Mitteilung; kein neuer Handy-Push.

Tische zeigen vier Spieler nebeneinander mit Startnummer, Logo, abgekürztem Namen, Punkten und – nur für den Ersteller – Ortschaft. Laufende Turniere bieten statt Gästeverwaltung eine zentrierte Tischübersicht mit Spielerpunktsumme, vier Platzständen und Status.

Migration 35-turnieransichten-und-tout.sql baut auf Version 33 auf. Sie ersetzt Funktionen und ergänzt die Mitteilungsstruktur; sie setzt keine Daten zurück. Handbuch und Datenschutz aktualisiert. Tests und Grenzen siehe Pruefung-Version34.md.
