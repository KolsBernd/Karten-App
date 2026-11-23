# Entwicklung und Tests

## Voraussetzungen und Funktionstests

Node.js 22 verwenden. Im Projektstamm:

```sh
npm install --ignore-scripts --prefix tests
npm test --prefix tests
```

Die Tests benutzen anonyme Daten und simulierte Serverantworten. Sie ändern keine produktiven Räume. `tests/app-fixture.cjs` enthält den gemeinsamen Testaufbau; `app-regression.cjs` verwendet ihn für die bisherigen Abläufe. Diese Hilfsdatei ist kein Bestandteil der laufenden App.

## Isolierte Bildschirmtests

```sh
node tests/visual/build.cjs
npm install --ignore-scripts --prefix tests/visual
cd tests/visual
npx playwright install --with-deps chromium webkit
npm test
```

Der Aufbau erzeugt aus der tatsächlichen App-Oberfläche 14 anonyme Ansichten: Anmeldung, Registrierung, Raumübersicht, Profil, Einstellungen, Anfrageformular die sieben Raumspiele und die Krawallo-Teamauswahl. Alle Skripte und ausführbaren Ereignisattribute werden vor dem Öffnen entfernt. Nur in den erzeugten Loopback-Testdateien wird die HTTPS-Aufwertung entfernt, damit WebKit lokale HTTP-Testdateien laden kann; die produktive CSP bleibt unverändert. Die Testantworten sperren Skripte und Backendverbindungen zusätzlich. Der lokale Testserver bindet ausschließlich an 127.0.0.1. Ausgehende Browseranfragen und Verbindungen zum echten Backend werden gesperrt.

Getestet werden Chromium und WebKit mit Handygrößen 390 × 844 und 375 × 812 sowie Tabletgrößen 744 × 1133 und 1133 × 744. Das sind Browser-Simulationen, keine echten iPhones oder iPads. Die Prüfungen erkennen Seitenüberlauf, unerwartet außerhalb liegende Bedienelemente und verschobene Navigation. Gewollt horizontal verschiebbare Tabellen werden gesondert behandelt.

Screenshots und Geometriedaten entstehen pro Fall. Der erste Lauf erzeugt Referenzmaterial; es gibt noch keine geprüften Pixel-Baselines. Die Tests ersetzen weder die Interaktionsprüfungen noch eine Geräteabnahme, Bildschirmtastatur-, VoiceOver- oder Push-Prüfung.

## GitHub-Prüfung

`.github/workflows/screen-tests.yml` führt Funktions- und Bildschirmtests auf `main`, Prüfbranches und Pull Requests aus. Der Workflow benötigt nur lesenden Repository-Zugriff und keine App-Geheimnisse. Bilder und Bericht werden sieben Tage als Testartefakte gehalten. Die Testansichten verwenden ausschließlich anonyme Daten.

## Veröffentlichung

1. Funktions- und Bildschirmtests ausführen; Fehler tatsächlich auswerten.
2. Version in App, Fehlerprotokoll, Testpaket und Offline-Cache abgleichen.
3. Nutzerhandbuch HTML/PDF aktualisieren; betroffene Seiten rendern und ansehen. Bilder nur mit anonymen Daten veröffentlichen.
4. Bei geänderten Datenarten, Sichtbarkeit, Empfängern oder Speicherfristen auch Datenschutz HTML/PDF aktualisieren.
5. Neue benötigte Dateien in Offline-Cache, Repository und ZIP aufnehmen.
6. Veröffentlichung für den konkreten Commit bestätigen. Einen gestarteten Upload nicht als fertiges Deployment melden.

## Optimierung messen

Die Historienprüfung kontrolliert, dass 100 unveränderte Renderaufrufe dieselben Verlaufselemente erhalten. Profiländerungen und neue Serverdatensätze müssen den Cache invalidieren. Daraus folgt weniger DOM-Arbeit; eine konkrete prozentuale Beschleunigung auf einem Endgerät wird damit nicht behauptet.
