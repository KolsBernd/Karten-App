# Sicherheit und Kopierbarkeit

## Kann jemand die App kopieren?

Technisch ja: Die ausgelieferte HTML-, CSS- und JavaScript-Oberfläche ist für Browser lesbar. Ein öffentliches GitHub-Repository macht das Kopieren zusätzlich einfach. Auch ein privates Repository würde den an den Browser ausgelieferten Code nicht geheim halten. Minifizierung oder Verschleierung sind kein Zugriffsschutz.

Urheberrecht und technische Kopierbarkeit sind verschiedene Fragen. Die eigene Software bleibt urheberrechtlich geschützt; GitHub erlaubt bei öffentlichen Repositories das Ansehen und Forken innerhalb seiner Nutzungsbedingungen. Fremdbibliotheken behalten ihre eigenen Lizenzen. Quellen: [GitHub-Lizenzhinweise](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

## Gewährt der Code Zugriff auf alle Daten?

Das sollte er nicht, und die geprüften Grenzen sind vorhanden. Die Supabase-Adresse und der Browser-Schlüssel sind öffentlich vorgesehen. Entscheidend sind die Anmeldung, Tabellenregeln und die Berechtigungsprüfung jeder Serverfunktion. Eine fremde Oberfläche kann dieselben öffentlichen Schnittstellen ansprechen; sie darf dabei nur die Rechte des angemeldeten Kontos beziehungsweise eines gültigen Freigabecodes erhalten. CORS, versteckte Buttons und ein geheimer JavaScript-Dateiname ersetzen diese Kontrolle nicht.

Geheim bleiben müssen insbesondere Server-/service_role-Schlüssel, SMTP-Zugang, Datenbankpasswort, Push-Server-Schlüssel und private Schlüssel. Der Mustercheck der aktuellen lokalen App-Dateien fand keine tatsächlichen `sb_secret_`-Schlüssel, privaten Schlüsselblöcke oder Datenbank-URLs mit Zugangsdaten. Er untersucht keine vollständige Git-Historie, kein Dashboard-Geheimnis und nicht jedes mögliche Geheimnisformat.

Quellen: [Supabase API-Schlüssel](https://supabase.com/docs/guides/getting-started/api-keys), [Zeilenzugriffsschutz](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Geprüft am 23. November 2026

- Alle `hh_`-Tabellen im öffentlichen Datenbankschema haben RLS aktiviert.
- Die Rolle `anon` darf keine dieser Tabellen direkt lesen.
- Anonym ausführbare SECURITY-DEFINER-Funktionen sind auf fünf vorgesehene Zugänge begrenzt: Benutzername prüfen, Raum-/Tisch-Ergebnisse ansehen, QR-Erfassung und TV-Anzeige.
- Die vier codegebundenen anonymen Zugänge weisen ungültige Tokens in tatsächlichen Aufrufen unter der Rolle `anon` ab.
- Eine simulierte fremde angemeldete Identität erhält keine Verwaltungsrechte, keine Reset-Vorbereitung und keinen Fehlerbericht. Alle Testtransaktionen wurden zurückgerollt.
- Der veröffentlichte Browser-Schlüssel ist ein `sb_publishable_`-Schlüssel. Er ist kein Administratorzugang.

Gültige Zuschauer- und Erfassungslinks sind Berechtigungen für ihren vorgesehenen Umfang. Wer sie erhält oder weitergeleitet bekommt, kann diese freigegebenen Daten lesen beziehungsweise am freigegebenen Tisch erfassen. Sie dürfen nicht in öffentliche Fehlerprotokolle, Screenshots oder Testdaten gelangen.

## Verschlüsselung richtig einordnen

Die Anmeldung verwaltet Supabase Auth; Passwörter gehören weder in Raumstände noch in die App-Dokumentation. Telefonnummern verwenden im vorhandenen Datenmodell ein verschlüsseltes Feld mit einer begrenzten Entschlüsselungsfunktion. Chatnachrichten verwenden Web-Crypto-Verfahren und Gerätefreigaben. Spielstände sollen gemäß Betreiberentscheidung serverseitig lesbar bleiben. HTTPS schützt die Übertragung, macht solche Spielstände aber nicht Ende-zu-Ende-verschlüsselt.

Diese Prüfung bestätigt nicht die Sicherheit des gesamten eigenen Chatprotokolls. Ein übernommenes Endgerät oder ein eingeschleuster Code im Browser kann dort entschlüsselte Inhalte lesen. Fremdbibliotheken, XSS-Schutz, Serverrechte und Geräteverwaltung bleiben deshalb relevant.

## Offene Prüfungen

- Zweikonten-Tests für jede schreibende Serverfunktion, einschließlich fremder Räume, Turniertische und Chatgeräte.
- Schlüsselrotation und Wiederherstellung praktisch testen; Sicherungen und Wiederherstellungsplan dokumentieren.
- Abhängigkeiten und Git-Historie regelmäßig auf Sicherheitsprobleme beziehungsweise versehentlich veröffentlichte Geheimnisse prüfen.
- Eigene E2E-Kryptografie und Schlüsselverteilung vor breiter Vermarktung extern prüfen lassen.

Es wurde keine vollständige Penetrationsprüfung und kein unabhängiges Sicherheitsgutachten durchgeführt. Eine Garantie gegen unbefugten Zugriff lässt sich daraus nicht ableiten.
