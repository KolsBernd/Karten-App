# Einheitliche Bedienelemente

| Element | Einheitliche Regel |
| --- | --- |
| Hauptaktion | Roter Button #AA0B24, mindestens 48 CSS-Pixel hoch; in schmalen Kacheln volle Breite |
| Nebenaktion | Gleiche Höhe, ruhiger Rahmen, klare Beschriftung |
| Ergebniswahl | Genau eine zulässige Auswahl, rot gefüllt, weißer Text, `aria-pressed` |
| Spielerauswahl | Profilbild mit deutlich erkennbarem Auswahlrahmen; Platznummer mit eigenem Kontrast |
| Gefährliche Aktion | Klar benannter Button und Ja/Nein-Dialog mit nachvollziehbarer Folge; nicht allein per Swipe auslösen |
| Einstellungen | Beschriftung links, gleich ausgerichteter Schalter rechts; nicht verschiedene Schalterbreiten mischen |
| Eingabefelder | Gleiche Höhe und Rundung; zugehöriges Label; sichtbare Fehlermeldung direkt am Feld |
| Datum/Uhrzeit/Telefon | Native Eingabe respektieren, `min-width:0`, im Kachelrahmen halten |
| Tabellen | Gleichartige Kopfzeilen, zentrierte Profilbilder, einheitliche Zahlenformate; horizontales Scrollen klar erkennbar |
| Dialoge | Gleiche Abstände, lesbare Titel, klarer Schließen-/Zurückweg und sichtbarer Tastaturfokus |
| Navigation | Feste untere Leiste außerhalb scrollender Inhalte; aktueller Menüpunkt erkennbar |

Diese Regeln beschreiben die gemeinsame Zielgestaltung. Die bestehende App erfüllt sie noch nicht überall vollständig. Insbesondere Stilregeln sollten künftig schrittweise in gemeinsame Komponenten überführt werden, statt weitere einzelne Überschreibungen hinzuzufügen.

Für ältere Mitspieler wären eine wählbare größere Schrift, verständliche Begriffe statt Symbolen allein und ein kurzer Einstieg mit genau einem nächsten Schritt besonders hilfreich. Änderungen daran sollten mit echten Mitspielern geprüft werden.
