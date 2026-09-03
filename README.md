# BirdNotes

BirdNotes ist eine lokale Schreib- und Lernapp für das iPad. Sie verbindet handschriftliche Notizbücher, frei zoombare Arbeitsflächen, PDF-Anmerkungen und technische Lernwerkzeuge in einer nativen iPadOS-App.

> **Projektstatus:** BirdNotes wird aktiv entwickelt. Der Quellcode ist für iPadOS 17 oder neuer ausgelegt; ein öffentliches App-Store-Paket gehört derzeit nicht zum Repository.

## Funktionen

### Schreiben und Zeichnen

- mehrseitige Notizbücher mit A4- und A3-Seiten
- leeres, liniertes, kariertes, punktiertes und Cornell-Papier
- Apple-Pencil- und optionale Fingereingabe mit PencilKit
- Stifte, Marker, Radierer, Lasso, Farben und Strichbreiten
- Undo/Redo, Seitenübersicht, Umsortieren, Duplizieren und Markieren
- lokale Handschrifterkennung und Volltextsuche

### Dokumente und Arbeitsflächen

- beschreibbare PDFs mit editierbarer Handschrift pro Seite
- freie `.birdcanvas`-Arbeitsflächen mit Text, Bildern, Formen und Verbindungen
- versionierte `.birdnotebook`- und `.birdtech`-Dokumente
- PDF-, PNG- und SVG-Export für unterstützte Inhalte
- Vorschauen, Favoriten, Tags, Suche, Verlauf und Papierkorb

### Ablage und Datensicherung

- lokale Speicherung im App-Bereich
- optionaler, frei gewählter Ordner aus der Dateien-App
- Unterstützung für iCloud Drive und kompatible File Provider
- portable Backups mit geprüfter Wiederherstellung
- Konflikterkennung bei parallel geänderten Cloud-Dateien

### Lern- und Technikbereich

- lokale Rechner und Checklisten für Studium und Softwareentwicklung
- semantische Diagramme und typisierte SI-Einheiten
- Lernkataloge für technische und informatische Themen
- sichere Parser- und Ressourcenlimits für importierte Inhalte

## Datenschutz

BirdNotes arbeitet ohne Benutzerkonto, Backend, Werbung, Analyse- oder Tracking-SDK. Dokumente werden lokal oder in einem ausdrücklich ausgewählten Ordner gespeichert. Die optionale Handschrifterkennung läuft auf dem Gerät mit Apples Vision-Framework.

Die App enthält keine externe oder generative KI-Anbindung. Wird iCloud Drive oder ein anderer Dateien-Anbieter gewählt, übernimmt der jeweilige Systemdienst die Synchronisierung nach dessen Einstellungen und Bedingungen. Technische Details stehen in [PRIVACY.md](PRIVACY.md) und [SECURITY.md](SECURITY.md).

## Voraussetzungen

- Mac mit einer aktuellen Xcode-Version und passendem iPadOS-SDK
- iPad oder iPad-Simulator mit iPadOS 17 oder neuer
- für die Installation auf einem echten Gerät ein in Xcode eingerichtetes Development Team

## In Xcode starten

1. `BirdNotes.xcodeproj` in Xcode öffnen.
2. Das Scheme **BirdNotes** auswählen.
3. Unter **Signing & Capabilities** das eigene Development Team festlegen.
4. Einen iPad-Simulator oder ein angeschlossenes iPad als Ziel auswählen.
5. Die App mit **Product → Run** starten.
6. Die Tests bei Bedarf mit **Product → Test** ausführen.

Eine ausführliche Anleitung für die Installation auf einem iPad und die optionale Cloud-Bibliothek steht in [docs/IPAD_SETUP.md](docs/IPAD_SETUP.md).

## Speicherort einrichten

Ohne zusätzliche Konfiguration liegen alle Dokumente im lokalen App-Speicher. Für eine gemeinsam zugängliche Bibliothek kann in der App über **Speicher** ein Ordner aus der Dateien-App gewählt werden, zum Beispiel `iCloud Drive/BirdNotes`.

BirdNotes erhält nur Zugriff auf den ausgewählten Ordner. Eine bereits vorhandene lokale Bibliothek wird beim ersten Wechsel kopiert; das lokale Original bleibt als Rückfallkopie erhalten.

## Projektstruktur

```text
BirdNotes/                 SwiftUI-, PencilKit- und PDFKit-App
BirdNotesCore/             Dokumentmodelle und Dateispeicher
BirdNotesTechnicalCore/    Berechnungen, Diagramme und Lernwerkzeuge
BirdNotesCore/Tests/       Tests des Dokumentkerns
BirdNotesTests/            app-nahe Integrations- und Layouttests
BirdNotesUITests/          automatisierter UI-Smoke-Test
BirdNotes.xcodeproj/       Xcode-Projekt und Targets
scripts/                   Prüf-, Test- und Release-Skripte
docs/                      Architektur-, Format- und Qualitätsdokumentation
```

Die beiden nicht-visuellen Kerne besitzen eigene Swift-Package-Manifeste und lassen sich unabhängig vom iPad-Target testen.

## Qualität prüfen

```bash
./scripts/test.sh core
./scripts/test.sh app
./scripts/test.sh ui
./scripts/verify.sh
```

Das vollständige Qualitätsgate prüft Projektkonfiguration, Datenschutz-Manifeste, Sicherheitsregeln, Tests, Release-Build und statische Analyse. Reale Apple-Pencil-, Accessibility-, Performance- und Mehrgerätetests bleiben vor einer Veröffentlichung zusätzlich erforderlich.

Weitere technische Informationen:

- [Architektur](ARCHITECTURE.md)
- [Dateiformate](docs/DATA_FORMATS.md)
- [Dokumentationsindex](docs/README.md)
- [Roadmap](ROADMAP.md)
- [Changelog](CHANGELOG.md)

## Lizenz

Für das Repository wurde noch keine Open-Source-Lizenz festgelegt. Der öffentlich sichtbare Quellcode darf daher nicht automatisch als frei nutzbar oder veränderbar verstanden werden.
