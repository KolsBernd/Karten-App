# Prüfung Version 53

## Anmeldung

Ursache: Die globale Versionsersetzung hatte im HTML den tatsächlichen Dateinamen `supabase-2.50.0.min.js` zu `supabase-2.52.0.min.js` geändert. Diese Datei existiert nicht. Ohne Bibliothek wurde kein Client erstellt; der spätere Loginversuch zeigte „Verbindung noch nicht bereit“. Der Verweis ist korrigiert. App-Versionsänderungen verwenden Grenzen, die eingebettete Bibliotheksversionen ausschließen.

Neue Tests prüfen echte lokale Abhängigkeiten, den anonymen Browserstart mit unveränderter Supabase-Bibliothek sowie den simulierten Anmeldeablauf. Externe Netzwerkaufrufe sind in den Browsertests gesperrt. Keine Passwörter oder echten Nutzerkonten werden dafür verwendet. Die vorherigen Mocktests allein konnten den fehlerhaften Dateiverweis nicht erkennen.

## Yannik und Schafkopf (€)

Die Menüfreigabe ist von Verwaltungs- und globalen Rücksetzrechten getrennt. Yannik benötigt seinen eigenen kanonischen Server-Profilnamen und seine bereits vorhandene serverseitige Freigabe. Eine Namensanzeige allein oder Turnierrechte eines anderen Kontos reichen nicht aus. Freigaben werden bei jedem Öffnen erneut geprüft und bei Abmeldung gelöscht. Der Dummy bleibt anonym und ohne Speichernetzwerk oder Zahlungen. Keine SQL- oder Kontorechteänderung.

## Dokumentation und Grenzen

Handbuch und Datenschutz auf Version 53 aktualisiert. Geänderte Seiten werden gerendert und visuell geprüft; anonyme Anmeldeaufnahme wird erneuert. Offline-Cache und ZIP enthalten Dokumente und Bilder. Diese Entwicklungsprüfung ist kein unabhängiges Sicherheitsgutachten. Live-Anmeldung mit echten Zugangsdaten und reale Endgeräte sind nicht Bestandteil der isolierten Tests.

Der WebKit-Vergleich deckte zudem eine Abweichung des bisherigen HTTP-Testservers auf: Die produktive Sicherheitsrichtlinie wertete seine unverschlüsselten Programmdateien auf, sodass sie dort nicht geladen wurden. Der isolierte Testserver verwendet nun wie die App HTTPS mit einem ausschließlich lokalen, kurzlebigen Testzertifikat. Die produktive HTTPS-/Zertifikatsprüfung und Sicherheitsrichtlinie bleiben unverändert.
