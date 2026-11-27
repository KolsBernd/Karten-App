# Architektur

## Datenfluss

1. Die Anmeldung stellt eine Supabase-Sitzung bereit. Benutzername und Anzeigename sind getrennt; ein umbenannter Anzeigename darf keine zusätzlichen Rechte verleihen.
2. Die Raumansicht lädt den vom Server freigegebenen Stand mit Revisionsnummer.
3. Eine Eingabe wird lokal vorbereitet. Der Server prüft Mitgliedschaft, Regeln und erwartete Revision, bevor er sie übernimmt.
4. Andere Teilnehmer erhalten über Realtime einen Hinweis und laden den aktuellen freigegebenen Stand.

Das Ausblenden eines Buttons ist eine Bedienhilfe. Eine Berechtigung entsteht ausschließlich durch die serverseitige Prüfung.

## Zuständigkeiten

| Datei | Aufgabe |
| --- | --- |
| `index.html` | Oberfläche, bestehende Spiellogik und Verbindung der Module; noch umfangreicher Einstiegspunkt |
| `authentication.js` | Anmeldung und Sitzungsabläufe |
| `room-state.js` | Raumwechsel, revisionsgebundenes Speichern, Realtime und Anwesenheit |
| `profile-statistics.js` | Profil- und Freundesauswertung mit Schutz gegen veraltete Dialogantworten |
| `room-games.js` | 21 rückwärts und Schafkopf im normalen Raum; Zusatzspiel-Historie |
| `krawallo.js` | Krawallo-Regeln, Vorschau, Teams und Ergebnisdialog |
| `schafkopf.js` | Gemeinsame Erfassung für Raum und Turniertisch |
| `tournament.js`, `tournament-play.js` | Turnierverwaltung und Tischbedienung |
| `evenings.js` | Kartabendanfragen und zugehörige Abläufe |
| `chat-crypto.js`, `chat-devices.js` | Verschlüsselte Nachrichten und Gerätefreigabe |
| `error-log.js` | Begrenzte Fehlerzähler ohne Rohmeldungen oder persönliche Inhalte |
| `navigation-shell.js` | Menüleisten außerhalb der scrollenden Inhalte |
| `sw.js` | Versionsgebundene Offline-Dateien; Dokumentnavigation getrennt von der App |
| nummerierte SQL-Dateien | Serverseitige Regeln und Migrationen |

## Regeln für Änderungen

- Verbindliche Punkteprüfung bleibt auf dem Server. Eine geänderte Vorschau allein reicht nicht aus.
- Abgeschlossene Ergebnisse sind unveränderliche Datensätze. Korrektur oder Rücknahme läuft über die vorgesehenen Aktionen.
- Der Historien-Cache vergleicht Datensatzreferenzen und sichtbare Profildaten. Neue Datensätze, ersetzte Serverstände, Profiländerungen und Reset leeren die Darstellung nicht versehentlich, sondern bauen sie erneut auf.
- Alte Ergebnisformate bleiben lesbar. Neue Formate benötigen ausdrückliche Kennzeichnung und Regressionstests.
- HTML für Namen und Nachrichten nicht ungeprüft einsetzen. Nutzereingaben vorzugsweise über `textContent` ausgeben.

## Technische Schulden

Die Trennung in Module ist begonnen, aber noch nicht abgeschlossen. Der große HTML-Einstiegspunkt, teilweise weiterhin sehr lange JavaScript-Zeilen (die gemeinsame Schafkopf-Erfassung wurde in Version 47 formatiert) und 41 nacheinander gewachsene Inline-Stilblöcke erschweren die Wartung. Die nächste Strukturarbeit sollte eine einzelne Zuständigkeit pro Schritt herauslösen. Eine gleichzeitige Komplettumschreibung wäre schwerer zuverlässig zu prüfen und verspricht ohne Messung keinen Geschwindigkeitsgewinn.

## Schafkopf-Serien (Version 49)

`schafSettings.target` begrenzt eine Raumserie auf 1–50 Partien. Fehlt der Wert in Altdaten, bleibt das bisherige Einzelpartie-Verhalten bestehen. Der Server berechnet die Punkte und prüft den Abschluss gegen dieselbe Vorgabe. Abgeschlossene Serien werden für Statistiken mit `HHRoomGames.records` bzw. `hh_expand_extra_history` in einzelne Partien aufgeteilt; der gemeinsame Raumverlauf bleibt unverändert.

Neuregistrierungsmeldungen entstehen nach bestätigter E-Mail bei der ersten Profilanlage. Ein eindeutiger Schlüssel verhindert doppelte Nachrichten. Empfänger ist die serverseitig festgelegte Betreiberkennung, kein vom Client übergebener Benutzername. Wiederholte Anmeldung und Profiländerungen erzeugen keine Meldung. Der Push enthält keine Kontaktdaten.

## Schafkopf-Euro-Dummy (Version 50)

Der Operator-Menüeintrag fragt vor dem Öffnen nochmals den bestehenden serverseitigen Berechtigungsstatus ab. Der Rechner läuft in einem Frame mit `sandbox="allow-scripts"`, ohne Zugriff auf Elternseite, Konten, lokalen Speicher oder Raumzustand. Seine CSP verbietet Netzwerkverbindungen. Die drei statischen Dummy-Dateien enthalten ausschließlich Testvorgaben. Sie sind als Frontend-Quelltext öffentlich, keine Zugriffssperre für vertrauliche Daten.

`calculate` berechnet den Spielwert in ganzzahligen Viertelcent; `settlement` verteilt dieselbe Einheit mit Summe null. Die Anzeige konvertiert erst am Ende in Euro mit bis zu vier Nachkommastellen. Es gibt keinen Speicheraufruf für Geldspielstände und keine Überweisungsfunktion. Ein späterer echter Spielmodus benötigt eigenständige serverseitige Validierung und Datenmigrationen.

## Euro-Dummy: Sonderregeln (Version 51)

`schafkopf-euro.js` hält Berechnung und Darstellung getrennt. `calculate` prüft die Regelgültigkeit unabhängig von der sichtbaren Auswahl: Tout/Light ignorieren Schneider und Durch; Light ignoriert Spitzen. Bettel-Tout verwendet den Faktor 1,5, Bagga und Bettel verbieten Light. Ramsch-Klopfer sind eine einzelne Stufe von 0 bis 4, nur bei Ramsch wirksam; Leger und Ansage multiplizieren unabhängig davon.

Die zwölf PNG-Karten sind technisch verkleinerte Vorlagen, keine extern geladenen Bilder. Die Zuordnung A–D bleibt Eichel/Gras/Herz/Schellen. Bildbuttons erhalten zugängliche Kartennamen. Das Jungfrau-Porträt markiert die Auswahl ausdrücklich grün.

Die Änderungen erweitern keine Datenübertragung, Sichtbarkeit oder Speicherung. Der isolierte Dummy erhält weiterhin nur anonyme Testspieler und verwirft seine Werte beim Schließen. Reale Euro-Spielstände sind nicht implementiert.

## Euro-Dummy Version 52

`resultAllowed` ist die gemeinsame Quelle für Ergebniszuschläge in Berechnung und Eingabe. Ausgeblendete Werte wirken dadurch nicht im Hintergrund weiter. Freigegebene Spiellogos sind eigenständige SVGs mit eingebetteten PNG-Motiven, ohne Netzabhängigkeit. Feste, responsive Bildboxen verhindern springende Buttonhöhen. Die Bildkomposition enthält keine Benutzerinformationen.

## Anmeldung und Euro-Freigabe (Version 53)

App- und Bibliotheksversionen sind unabhängig. Die lokale Supabase-Datei `supabase-2.50.0.min.js` darf bei Versionsänderungen nicht umbenannt werden. `tests/static-assets-regression.cjs` prüft alle lokalen Script-/Stylesheet-Verweise vor den Mocktests. Der Browserstart-Test lädt zusätzlich den echten Scriptverbund mit leerem Sitzungsspeicher; alle externen Anfragen bleiben gesperrt.

`euroAllowed` ist von `resetAllowed` getrennt. Betreiberstatus stammt aus `hh_admin_reset`. Für Yannik wird zusätzlich der kanonische Kontoname aus dem eigenen serverseitigen Profildatensatz sowie seine bestehende Server-Freigabe aus `hh_tournament_capabilities` geprüft. Andere Turnierersteller erhalten keinen Zugriff. Jeder Aufruf prüft erneut; Identitätswechsel verwerfen späte Antworten. Es gibt keine neue Datenbankberechtigung und keine Weitergabe von Kontodaten an den anonymen Dummy.

Die Bildschirmtests laufen ausschließlich auf HTTPS-Loopback mit temporärem Testzertifikat. So bleibt `upgrade-insecure-requests` auch beim unveränderten App-Start wirksam. `ignoreHTTPSErrors` gilt allein für diesen abgeschotteten Testkontext, nicht für die App oder Supabase-Verbindungen.

## Schafkopf (€) als Raumspiel (Version 55)

`euro-room.js` hält Darstellung, Live-Abgleich und Raumhistorie getrennt vom normalen Raumzustand. `49-euro-raumspiel.sql` speichert ausschließlich in `hh_euro_rooms`; Geldwerte gelangen nicht in `hh_states` oder persönliche Ergebnisse. RLS sperrt direkten Zugriff; `hh_euro_room` prüft Raummitgliedschaft, Schreibrechte, Revision und eindeutige Anfragekennung. Schreibrechte werden einmalig anhand vorhandener Konten ermittelt und danach anhand der Kontokennung geprüft. Ein Freitext-Anzeigename allein verleiht keine Rechte. Alle Beträge werden serverseitig in ganzzahligen Viertelcent berechnet.

Konkurrierende Änderungen erzwingen erneute Bestätigung. Nach unsicherem Verbindungsabbruch erfolgt keine automatische Doppelbuchung. Einstellungen sind an die geöffnete Revision gebunden; unveränderte Abfragen erhalten Eingabefokus und Auswahl. Die getrennte Speicherung schließt finanzielle Daten aus Profil-/Globalstatistiken und bestehenden Zuschauer-RPCs aus. Raum- und globale Resets leeren die Euro-Verläufe; Raumlöschung wirkt über Fremdschlüssel.

Die frühere Standalone-Testseite enthält nur noch einen Verweis auf die App. Die gemeinsame Berechnungsbibliothek bleibt für vorhandene Regressionen kompatibel. Diese Veröffentlichung erfolgt auf Wunsch ohne weitere Testläufe; ältere isolierte Prüfergebnisse sind keine neue Live-Abnahme und kein unabhängiges Sicherheitsgutachten.
