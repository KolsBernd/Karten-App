# Kartabend 39

https://kolsbernd.github.io/Karten-App/

- Schniffelkopf-Ergebnisfenster nach vollständiger Partie, mit x3/x5/x10 Cent je Differenzpunkt. Die Anzeige rechnet in ganzen Centbeträgen; geteilte Erstplatzierte teilen die Gesamtsumme einschließlich offengelegter Restcent-Verteilung. Keine Punktänderung, Forderungsspeicherung oder Zahlungsübertragung. Erneut aufrufbar über Ergebnis & Ausgleich.
- Hinterlegtes Turnierlogo auch bei Bierkopf-/Schafkopftischen und QR-Erfassung. Standardlogo ohne eigenes Logo und nach Verlassen. Keine neue Zugriffsfreigabe.
- Größere, mit der Ergebnisleistenbreite skalierende Profilbilder bei Schniffelkopf und Klopfer.

Die in Version 38 getrennten Module bleiben erhalten. `schniffel-settlement.js` kapselt die reine Centberechnung und das Ergebnisfenster. `40-turniertisch-logo.sql` ergänzt die vorhandenen berechtigten Snapshots; unveränderte Polls bleiben klein. Die Migration ist für Version 39 bereits in Supabase installiert. Die Fehlertabelle zählt neue Fehler unter Version 39.0.

Handbuch und Datenschutz sind auf demselben Stand. Regressionstests: `tests/README.md`; Prüfumfang und Grenzen: `Pruefung-Version39.md`.
