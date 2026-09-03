# BirdNotes auf einem iPad installieren

Stand: 3. September 2026

Diese Anleitung beschreibt die Installation direkt aus Xcode und die optionale Verwendung einer Bibliothek aus iCloud Drive oder einem anderen Dateien-Anbieter.

## Voraussetzungen

- ein Mac mit Xcode und passendem iPadOS-SDK
- ein iPad mit iPadOS 17 oder neuer
- eine in Xcode angemeldete Apple-ID beziehungsweise Mitgliedschaft im Apple Developer Program
- ein USB-C-Kabel oder eine eingerichtete drahtlose Xcode-Verbindung

## App installieren

1. Das iPad mit dem Mac verbinden, entsperren und die Vertrauensabfrage bestätigen.
2. Falls iPadOS es verlangt, unter **Einstellungen → Datenschutz & Sicherheit** den Entwicklermodus aktivieren.
3. `BirdNotes.xcodeproj` in Xcode öffnen.
4. Das Target **BirdNotes** auswählen und unter **Signing & Capabilities** ein eigenes Development Team festlegen. **Automatically manage signing** kann aktiviert bleiben.
5. Das angeschlossene iPad als Ausführungsziel auswählen.
6. Die App mit **Product → Run** beziehungsweise `⌘R` bauen und installieren.
7. Falls iPadOS nach einer Bestätigung fragt, die Entwickler-App unter **Einstellungen → Allgemein → VPN & Geräteverwaltung** freigeben.

Bei einer kostenlosen Apple-ID ist die Entwicklungssignatur zeitlich begrenzt. Nach ihrem Ablauf muss die App erneut aus Xcode installiert werden. Die Dokumente in einem separat gewählten Cloud-Ordner bleiben davon unberührt.

## Bibliothek einrichten

BirdNotes kann vollständig im lokalen App-Speicher verwendet werden. Für eine über die Dateien-App zugängliche Bibliothek:

1. Beim ersten Start **Cloud-Ordner verbinden** wählen oder später in der Sidebar den Speicherort öffnen.
2. In der Dateien-App einen vorhandenen Ordner auswählen oder beispielsweise `iCloud Drive/BirdNotes` anlegen.
3. Den Ordner mit **Öffnen** bestätigen.
4. In der BirdNotes-Sidebar prüfen, ob der gewählte Speicherort angezeigt wird.

BirdNotes speichert die Ordnerfreigabe als Security-Scoped Bookmark im lokalen iOS-Schlüsselbund. Die App erhält keinen Zugriff auf andere Ordner des Anbieters.

## Kurzer Funktionstest

1. Ein Notizbuch anlegen und mit dem Apple Pencil schreiben.
2. Die App schließen, erneut öffnen und die gespeicherte Handschrift prüfen.
3. Eine PDF in den Bibliotheksordner kopieren und in BirdNotes öffnen.
4. Die PDF beschriften, mit einem Finger scrollen und mit zwei Fingern zoomen.
5. Falls ein Cloud-Ordner verwendet wird, die Synchronisierung in der Dateien-App oder auf einem zweiten Gerät kontrollieren.

## Fehlerbehebung

- **Ordner nicht sichtbar:** Den Cloud-Anbieter in der Dateien-App öffnen und die Synchronisierung prüfen.
- **Zugriff verloren:** In BirdNotes den Speicherort öffnen und den Ordner erneut auswählen.
- **App startet nach einiger Zeit nicht:** Die Entwicklungssignatur ist möglicherweise abgelaufen; App erneut aus Xcode installieren.
- **Entwicklerzertifikat nicht vertraut:** Die Entwickler-App unter **VPN & Geräteverwaltung** bestätigen.
- **Signierungsfehler in Xcode:** Development Team, Bundle-Identifier und automatische Signierung prüfen.
