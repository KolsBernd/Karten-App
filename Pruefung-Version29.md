# Kartabend 29 · Änderungen und Prüfung

19. November 2026. Die Installation führt **keinen Reset** aus.

- Neue Kartabendanfragen informieren bestätigte, nicht blockierte Freunde. Handy-Push verwendet die bestehende freiwillige Einstellung „Neue Kartabende von Freunden“ und den neutralen Text mit App-Logo. Ein späterer Block verhindert Anzeige bzw. noch ausstehende Zustellung.
- Spielerlogos in Schniffelkopf- und Klopfer-Kreuztabellen zentriert; Browsermessung auf Handybreite ergab höchstens 0,5 Pixel Abweichung durch Tabellenränder.
- App-Verwaltung exklusiv für die bei Installation fest gebundene Konto-ID von kolsbernd. Profilnamen allein verleihen keine Rechte.
- Statistik-Reset entfernt alle Spielstände, Rundenverläufe und gespeicherten persönlichen Ergebnisse; Räume, Spieler und Chats bleiben erhalten. Turniere werden mit ersten Tischen und Teilnehmern in die Vorbereitung zurückgesetzt; spätere Tische werden entfernt.
- Vollständiger Reset entfernt Räume, Gäste, Chats, Kartabendanfragen, Turniere, Mitteilungen und Ergebnisse. Registrierte Konten, Profile, bestätigte Freundschaften, Blockierungen und Konto-/Push-Einstellungen bleiben erhalten. Offene Freundschaftsanfragen werden entfernt.
- Zwei Ja-/Nein-Dialoge. Server prüft die Kontoberechtigung sowie eine kontogebundene, zweckgebundene, einmal verwendbare Bestätigung mit zwei Minuten Gültigkeit. Alle Datenänderungen laufen in einer Transaktion; gleichzeitige Schreibzugriffe auf Spieldaten werden ausgeschlossen.
- Geräte erkennen die geänderte Datengeneration und laden die Ansicht neu. Alte Raumstände können wegen Revisionsprüfung nicht versehentlich zurückgeschrieben werden.

## Erfolgreiche Prüfungen
- Migration in isolierter Datenbank zweimal installiert.
- Fremde und anonyme Konten abgewiesen; falscher Zweck, falsches Konto, abgelaufene oder wiederverwendete Bestätigung abgewiesen.
- Beide Reset-Arten ausschließlich mit Testdaten ausgeführt. Umfang, Erhalt registrierter Profile und Freundschaften sowie geleerte Ergebnisse geprüft.
- Mitteilung nur für nicht blockierte Freunde; späteres Blockieren entfernt Zugriff auf den Hinweis. Push nur für eingeschaltete Gerätepräferenz in Warteschlange.
- Beide UI-Abbruchstellen verhindern den endgültigen Aufruf. Regulärer Nutzer sieht keine Verwaltungskachel.
- Vollständige bisherige DOM- und Datenbanktests, Syntax aller Skripte, Offline-Cache, verschlüsselte Push-Erzeugung erfolgreich. Kein produktiver Test-Push und kein produktiver Reset ausgelöst.
- Nutzerhandbuch auf Version 29 aktualisiert; neues Verwaltungskapitel und geänderte Tabellenaufnahmen; PDF gerendert und visuell geprüft. Datenschutzhinweise an neue Abläufe angepasst.

## Grenzen
Kein unabhängiges Audit. Die Hinweise im Sicherheitsbericht zu Version 28 bleiben gültig. Die endgültigen Aktionen wurden bewusst nicht an produktiven Nutzerdaten getestet. Eine verschickte Pushmeldung kann durch nachträgliches Blockieren nicht vom Gerät zurückgerufen werden. Die Bestätigungen ersetzen keine vorherige Sicherung. Bereits außerhalb der App gespeicherte Sicherungen/Downloads werden durch den Reset nicht gelöscht. Eine finale visuelle Live-Prüfung auf GitHub Pages ist wegen der gespeicherten Browser-Sperre für diese Adresse nicht vorgesehen; Veröffentlichung wird über GitHub geprüft.
