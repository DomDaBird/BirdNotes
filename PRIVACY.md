# Technische Datenschutzinformation

Stand: 3. September 2026

Diese Datei beschreibt die Datenverarbeitung des aktuell versionierten BirdNotes-Quellcodes. Sie ist eine technische Projektinformation und ersetzt keine rechtliche Datenschutzerklärung für eine spätere Veröffentlichung über einen App Store.

## Grundprinzip

BirdNotes ist eine lokale iPad-App. Sie benötigt kein Benutzerkonto und enthält kein eigenes Backend, keine Werbung sowie keine Analyse-, Tracking- oder Telemetrie-SDKs. Der aktuelle Quellcode überträgt keine Notizen oder Nutzungsdaten an einen BirdNotes-Dienst.

## Verarbeitete Inhalte

Abhängig von der Nutzung verarbeitet die App auf dem Gerät:

- handschriftliche und erkannte Notiztexte
- Zeichnungen, Canvas-Objekte und eingefügte Bilder
- PDFs und zugehörige handschriftliche Anmerkungen
- Dokumenttitel, Ordner, Tags, Favoriten und Verlauf
- technische Diagramme, Berechnungen und Lernnotizen

Die optionale Handschrifterkennung verwendet Apples Vision-Framework auf dem Gerät. BirdNotes enthält keine externe oder generative KI-Anbindung.

## Speicherorte

Dokumente liegen standardmäßig im lokalen App-Bereich. Alternativ kann über Apples System-Dateiauswahl ausdrücklich ein Ordner aus iCloud Drive, „Auf meinem iPad“ oder einem kompatiblen File Provider freigegeben werden. BirdNotes erhält nur einen auf diesen Ordner begrenzten Zugriff.

Bei Verwendung eines Cloud- oder File-Provider-Ordners erfolgt die Synchronisierung durch den ausgewählten Anbieter. Dafür gelten dessen Einstellungen und Datenschutzbedingungen; BirdNotes betreibt hierfür keinen eigenen Synchronisierungsdienst.

Der Zugriffsschlüssel für einen ausgewählten Ordner wird als Security-Scoped Bookmark im lokalen iOS-Schlüsselbund gespeichert. Nicht sensible Einstellungen, etwa zuletzt verwendete Farben oder ausgeblendete Bedienhinweise, liegen in den lokalen App-Einstellungen.

## Zwischenablage, Export und Weitergabe

BirdNotes greift nur im Rahmen ausdrücklich ausgelöster Kopier-, Ausschneide- und Einfügeaktionen auf die Zwischenablage zu. Inhalte werden nur weitergegeben, wenn eine Person selbst eine Export-, Backup- oder System-Teilen-Funktion startet. Das gewählte Ziel kann eigene Datenschutzbedingungen haben.

Ein Bibliotheks-Backup kann Notizen, PDFs, Bilder, PDF-Anmerkungen und Organisationsdaten enthalten. Der interne Papierkorb wird nicht in das Backup aufgenommen.

## Löschung

Gelöschte Dokumente werden zunächst in den BirdNotes-Papierkorb des jeweiligen Bibliotheksordners verschoben. Bis zu 30 Einträge können wiederhergestellt oder endgültig entfernt werden; ältere Einträge werden beim Überschreiten der Grenze gelöscht.

Beim Entfernen der App löscht iPadOS den lokalen App-Bereich nach den Systemregeln. Inhalte in einem separat ausgewählten iCloud- oder File-Provider-Ordner bleiben unter der Kontrolle der jeweiligen Person und müssen dort bei Bedarf separat gelöscht werden.

## Datenschutz-Manifeste

Die App und `BirdNotesCore` enthalten Apple-Privacy-Manifeste. Sie erklären, dass kein Tracking und keine Erfassung von Daten durch den Entwickler stattfinden. Die angegebenen Required-Reason-APIs decken lokale App-Einstellungen und Dateimetadaten im App-Bereich beziehungsweise in ausdrücklich freigegebenen Ordnern ab.

Werden zukünftig Netzwerkdienste, Telemetrie, externe KI-Dienste oder zusätzliche SDKs ergänzt, müssen Codeprüfung, Privacy-Manifeste und diese Dokumentation vor einer Veröffentlichung aktualisiert werden.
