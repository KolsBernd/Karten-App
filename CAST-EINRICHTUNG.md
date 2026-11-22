# Direkte Fernseherauswahl

## Stand Version 41

Google-Cast-Sender und eigener Empfänger sind vorbereitet. Ohne registrierte Empfänger-ID bleibt die Auswahl deaktiviert; die App behauptet keine aktive Übertragung. Es wird kein TV-Link mehr im Teilen-Menü erstellt oder angezeigt. Intern wird nach Geräteauswahl ein zeitlich begrenzter, widerrufbarer Lesezugang an den TV gesendet. App-Anmeldedaten bleiben auf dem Handy.

## Google Cast aktivieren

1. In der offiziellen Google Cast SDK Developer Console mit dem Betreiber-Konto eine **Custom Receiver**-App registrieren: https://cast.google.com/publish/
2. Als Empfängeradresse `https://kolsbernd.github.io/Karten-App/cast-receiver.html` hinterlegen. Die Console kann Registrierungskosten und Bedingungen verlangen; der Betreiber muss diese selbst bestätigen.
3. Die öffentliche Application ID in `config.js` unter `googleCastAppId` eintragen und veröffentlichen. Es handelt sich nicht um einen geheimen Schlüssel. Keine fremde oder Demo-ID verwenden.
4. Für die Testphase Empfängergeräte entsprechend der Google-Anleitung registrieren; für allgemeine Nutzung den Receiver in der Console veröffentlichen.
5. Ein unterstütztes Chrome-Gerät und einen Cast-fähigen TV/Chromecast im selben WLAN verwenden. Einen Raum als Ersteller öffnen, rechts oben Teilen und anschließend Fernseher auswählen wählen. Datenupdates, Widerruf, Verbindungsverlust und Handy-App-Wechsel am echten Gerät prüfen.
6. Die App lädt das Google-SDK erst nach ausdrücklichem Öffnen des Teilen-Menüs und nur mit eingerichteter App-ID. Datenschutzerklärung enthält diesen Anbieter.

Offizielle Voraussetzungen: https://developers.google.com/cast/docs/web_sender und https://developers.google.com/cast/docs/registration

## AirPlay

Die Web-App besitzt keine öffentliche Schnittstelle, um eine beliebige HTML-Spielstandsanzeige unabhängig vom Handy über einen AirPlay-Gerätepicker zu senden. Apples Web-/AVKit-Auswahl betrifft Audio-/Videoinhalte. Ein Video-Picker ohne echtes Video wäre keine funktionierende Integration. iPhone-Bildschirmspiegelung lässt sich im Kontrollzentrum starten, zeigt aber auch andere Handy-Apps. Für eine eigenständige AirPlay-Darstellung ist ein gesonderter nativer Ausbau samt passender Anzeige-/Übertragungsarchitektur und Geräteprüfung erforderlich; er ist nicht Teil dieser Web-Veröffentlichung.

https://developer.apple.com/documentation/avfoundation/supporting-airplay-in-your-app

## Fernsehprogramm neben dem Ergebnis

Multi View ist eine Funktion des TVs und hängt von Modell sowie Quellenkombination ab. Die Webseite kann diese Firmwarefunktion und die Rückkehr zum TV-Vollbild nicht universell steuern. Google Cast ist ebenfalls kein universeller Empfänger für jeden Fernseher im WLAN.
