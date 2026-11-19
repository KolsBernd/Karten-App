# Sicherheitsprüfung · Kartabend 28
Stand: 19. November 2026. Prüfung durch den Mitentwickler der App, **kein unabhängiges Gutachten und kein vollständiger Penetrationstest**.

## Ergebnis und Umfang
Für die geprüften Abläufe wurde keine neue ausnutzbare Zugriffslücke bestätigt. Getestet wurden die lokalen Datenbankmigrationen mit isolierten Konten/Rollen, Clientabläufe, Archivierung, Datenschutzgrenzen sowie die bekannten Schwachstellen der eingebundenen Bibliotheken. Produktive Konten, Chats und Spielstände wurden nicht für Angriffstests verändert. Die produktive Konfiguration wurde lesend kontrolliert.

| Prüfung | Ergebnis |
|---|---|
| Eigene Anfrage bei Freunde-Beschränkung | sichtbar; direkt nach Erstellung Reiter „Anfragen“ |
| Unbeteiligte, Freunde, bestätigte Teilnehmer | bestehende Sichtbarkeitsregeln bleiben erhalten |
| Vom Ersteller blockierter Nutzer / unangemeldeter Zugriff | Anfrage nicht lesbar |
| Vier Stunden nach Termin | Anfrage wird archiviert, nicht gelöscht |
| Archivierte Anfragen | nur Ersteller / bestätigte Teilnehmer im Rahmen der bisherigen Zugriffskontrolle; keine neuen Zusagen, Konvertierung oder Chatbeiträge |
| Direkte Raum-RPC mit fehlerhaften / doppelten Spielerkennungen | durch bereits vorhandenen Datenbank-Trigger abgewiesen |
| Serverregeln normaler Räume | bestehende Tests zu Wertung, Rollen und Zustandsübergängen erfolgreich |
| Anonyme Ausführung interner Archivierungsfunktion | gesperrt |
| Produktive App-Tabellen ohne aktivierte Zeilensicherheit | 0 zum Prüfzeitpunkt; dies allein beweist keine korrekte Policy |
| Termin-Bereinigung und Archiv-Chat-Schutz | Zeitplan aktiv; beide neuen Trigger aktiv |
| Bekannte Bibliotheksschwachstellen | 0 gemeldete Advisories in den geprüften Produktions-Lockfiles für Supabase-SDK, QR-Erzeugung und Push-Server; keine Aussage über unbekannte Lücken |

## Supabase Security Advisor
Der separate automatische Anbieter-Check zeigte 0 Fehler, 76 Warnungen und 38 Hinweise. Die Warnungstypen betreffen ausführbare SECURITY-DEFINER-Funktionen (anonym oder angemeldet) sowie deaktivierten Schutz vor bekannten geleakten Passwörtern. Öffentlich aufrufbare QR-Funktionen und die Benutzernamenprüfung sind beabsichtigt, müssen ihre Token-/Rollenprüfung aber selbst korrekt erzwingen; die Warnungen sind deshalb kein automatischer Beleg einer Lücke und dürfen auch nicht pauschal als behoben gelten. Der Schutz gegen geleakte Passwörter sollte aktiviert werden, sofern im verwendeten Supabase-Tarif verfügbar. Es wurden hierfür keine Tarife oder Anmeldeeinstellungen geändert. Auch dieser automatische Check ist kein unabhängiger Penetrationstest.

## Verschlüsselung und wichtige Grenzen
Passwörter werden von Supabase Auth als Hash geprüft; die App speichert sie nicht als entschlüsselbaren Text. Telefonnummern verwenden die bestehende serverseitige Verschlüsselung mit geschütztem Schlüssel. App und Datenbank-API nutzen HTTPS. Spielstände darf der Server lesen, wie beauftragt. Der Chat hat eine eigene Ende-zu-Ende-Verschlüsselung mit Geräteschlüsseln. Die getestete Push-Erzeugung verschlüsselt die Übertragung und verwendet neutrale Nachrichtentexte. Diese Verfahren wurden nicht kryptografisch durch einen externen Spezialisten begutachtet.

## Offene Empfehlungen
1. **Externes Audit vor größerer öffentlicher oder kommerzieller Nutzung.** Besonders Chatprotokoll, Schlüsselauthentizität und Gerätefreigabe unabhängig prüfen lassen. Ein selbst entwickeltes Protokoll und die erstmalige Schlüsselzuordnung bieten keine externe Identitätsgarantie. Der Betreiber liefert weiterhin den Browsercode aus.
2. **Strengere Browser-Schutzrichtlinie vorbereiten.** Die App enthält noch eingebettete Skripte und Ereignishandler; die Inhaltsrichtlinie erlaubt deshalb Inline-Code. Keine XSS-Lücke wurde bestätigt, aber ausgelagerte Skripte und eine strengere CSP verringern den möglichen Schaden. Anmeldetoken im Browserspeicher bleiben bei einem erfolgreichen XSS-Angriff gefährdet.
3. **Wiederherstellung und Schlüsselwechsel praktisch üben.** Ein Backup-Restore-Test und ein dokumentierter Umgang mit verlorenem Gerät fehlen in dieser Prüfung. Die Gerätefreigabe für alte Chats ist aktuell in der Oberfläche ausgeblendet; das Handbuch benennt diese Grenze ausdrücklich.
4. **Betriebsprüfung fortsetzen.** Missbrauchsschutz/Verkehrsbegrenzung, Auth-Konfiguration, Wiederherstellungsverfahren und Server-Protokolle regelmäßig prüfen. Die lokale Prüfung ersetzt keine laufende Überwachung.
5. **Physisches iPad Mini gegenprüfen.** Getestet wurden Browser-Ansichtsgrößen 320, 390, 744, 768 und 1024 Pixel. Die native Safari-Datumsauswahl wurde mit passenden WebKit-Regeln berücksichtigt, aber auf dieser Umgebung nicht in echtem iPadOS Safari ausgeführt.

Grundlagen: [Supabase Zeilensicherheit](https://supabase.com/docs/guides/database/postgres/row-level-security), [Passwortsicherheit](https://supabase.com/docs/guides/auth/password-security), [API-Schlüssel](https://supabase.com/docs/guides/getting-started/api-keys), [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/). Kein rechtliches oder sicherheitstechnisches Zertifikat.
