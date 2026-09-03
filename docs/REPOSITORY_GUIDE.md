# BirdNotes – Repository- und Skripthandbuch

Stand: 29. August 2026

Dieses Dokument beantwortet drei Fragen: Wo liegt was, welche Komponente ist wofür verantwortlich und welcher Prüfweg ist für eine Änderung verpflichtend? Es beschreibt den tatsächlich vorhandenen Stand. Geplante technische Fachmodule stehen getrennt in der [Modularchitektur](MODULE_ARCHITECTURE.md).

## 1. Repository-Baum

Generierte Verzeichnisse wie `.git`, `.build`, Derived Data und lokale Xcode-Benutzerdaten sind bewusst nicht aufgeführt.

```text
BirdNotes/
├── .github/
│   └── workflows/
│       └── ci.yml
├── BirdNotes/
│   ├── App/
│   │   ├── BirdNotesApp.swift
│   │   ├── Info.plist
│   │   └── PrivacyInfo.xcprivacy
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   │   ├── AppIcon.png
│   │   │   └── Contents.json
│   │   ├── BirdLogo.imageset/
│   │   │   ├── BirdLogo.png
│   │   │   ├── BirdLogo@2x.png
│   │   │   ├── BirdLogo@3x.png
│   │   │   └── Contents.json
│   │   └── Contents.json
│   ├── Canvas/
│   │   ├── CanvasObjectLayer.swift
│   │   └── InfiniteCanvasView.swift
│   ├── Drawing/
│   │   ├── DrawingToolController.swift
│   │   ├── PaperBackgroundView.swift
│   │   └── PencilPageCanvas.swift
│   ├── Library/
│   │   ├── LibrarySupport.swift
│   │   ├── LibraryView.swift
│   │   ├── LibraryViewModel.swift
│   │   └── MoveDestinationView.swift
│   ├── Notebook/
│   │   ├── NotebookView.swift
│   │   └── NotebookViewModel.swift
│   ├── PDF/
│   │   └── PDFDocumentView.swift
│   ├── Study/
│   │   └── StudyToolsView.swift
│   ├── Technical/
│   │   └── TechnicalWorkspaceView.swift
│   └── Shared/
│       ├── BirdNotesTheme.swift
│       ├── ExportSupport.swift
│       └── PaperStyle+Display.swift
├── BirdNotesCore/
│   ├── Package.swift
│   ├── Sources/BirdNotesCore/
│   │   ├── Models/
│   │   │   ├── CanvasModels.swift
│   │   │   ├── DocumentModels.swift
│   │   │   ├── NotebookModels.swift
│   │   │   ├── NotebookPageCreationPolicy.swift
│   │   │   └── StudyWorkspaceModels.swift
│   │   ├── Storage/
│   │   │   ├── DocumentStore.swift
│   │   │   ├── DocumentStoreError.swift
│   │   │   └── JSONCoding.swift
│   │   └── PrivacyInfo.xcprivacy
│   └── Tests/BirdNotesCoreTests/
│       ├── DocumentStoreTests.swift
│       └── NotebookPageCreationPolicyTests.swift
├── BirdNotesTechnicalCore/
│   ├── Package.swift
│   ├── Sources/BirdNotesTechnicalCore/
│   │   ├── Calculation/
│   │   ├── Diagram/
│   │   ├── Document/
│   │   ├── Editing/
│   │   ├── Export/
│   │   ├── Modules/
│   │   └── Study/
│   │       ├── LearningTools.swift
│   │       ├── StudyCatalog.swift
│   │       └── StudyTools.swift
│   └── Tests/BirdNotesTechnicalCoreTests/
│       ├── CalculationTests.swift
│       ├── DiagramAndStoreTests.swift
│       ├── EditingTests.swift
│       ├── ModuleAndExportTests.swift
│       └── StudyToolkitTests.swift
├── BirdNotesTests/
│   └── BackupImportSupportTests.swift
├── BirdNotesUITests/
│   └── BirdNotesUITests.swift
├── BirdNotes.xcodeproj/
│   ├── project.pbxproj
│   ├── project.xcworkspace/
│   │   └── contents.xcworkspacedata
│   └── xcshareddata/xcschemes/
│       └── BirdNotes.xcscheme
├── docs/
│   ├── README.md
│   ├── CONTROL_MATRIX.md
│   ├── DATA_FORMATS.md
│   ├── MODULE_ARCHITECTURE.md
│   ├── IPAD_SETUP.md
│   ├── PRODUCTION_READINESS.md
│   ├── PROJECT_PLAN.md
│   ├── QUALITY_MANAGEMENT.md
│   ├── RELEASE_ACCEPTANCE.md
│   ├── RELEASE_CHECKLIST.md
│   ├── STANDARDS_REGISTER.md
│   ├── STUDY_TOOLKIT.md
│   ├── TEST_PLAN.md
│   ├── TESTFLIGHT_DEPLOYMENT.md
│   ├── THREAT_MODEL.md
│   ├── evidence/
│   │   └── RELEASE_TEST_EVIDENCE_TEMPLATE.md
│   └── modules/
│       ├── README.md
│       ├── ELECTRICAL_ENGINEERING.md
│       ├── IT_COMPUTER_SCIENCE.md
│       ├── MATHEMATICS_FOUNDATION.md
│       ├── PHYSICS_MECHANICS.md
│       └── TECHNICAL_DRAWING.md
├── scripts/
│   ├── check-project.sh
│   ├── check-docs.sh
│   ├── check-security.sh
│   ├── create-testflight-archive.sh
│   ├── prepare-release-evidence.sh
│   ├── test.sh
│   └── verify.sh
├── ARCHITECTURE.md
├── CHANGELOG.md
├── FEEDBACK.md
├── PRIVACY.md
├── README.md
├── ROADMAP.md
└── SECURITY.md
```

## 2. Targets und Abhängigkeiten

| Baustein | Aufgabe | Darf abhängen von |
|---|---|---|
| `BirdNotesCore` | Modelle, Pfadsicherheit, Dateiformate, atomare Operationen, Backup/Restore | Foundation und Apple-Dateisystem-APIs |
| `BirdNotesTechnicalCore` | SI-Einheiten, sicherer Parser, Diagramme, `.birdtech`, Fachmodule, Curriculum und Studienrechner | Foundation und CryptoKit |
| `BirdNotes` | iPad-Oberfläche, PencilKit, PDFKit, Vision, Systempicker und Studienwerkzeuge | `BirdNotesCore`, `BirdNotesTechnicalCore` und Apple-Systemframeworks |
| `BirdNotesCoreTests` | schnelle, plattformnahe Unit-, Integrations-, Security- und Migrationstests | `BirdNotesCore` |
| `BirdNotesTechnicalCoreTests` | Einheiten-, Parser-, Diagramm-, Format-, Modul-, Studienrechner- und Securitytests | `BirdNotesTechnicalCore` |
| `BirdNotesTests` | App-nahe ZIP-, UIKit-/Layout- und Integrationsprüfungen | App und Core |
| `BirdNotesUITests` | isolierter Ende-zu-Ende-Smoke-Test für kritische Nutzer- und Persistenzabläufe | gestartete BirdNotes-App im Simulator |

Beide nicht-visuellen Kerne besitzen ein Swift-Package-Manifest und können ohne App-Start getestet werden. Die App bindet aktuell keine fremden Laufzeitpakete ein.

Wichtige Buildparameter:

| Parameter | Aktueller Wert |
|---|---|
| App-Version | `3.1.0` |
| Buildnummer | `6` |
| Mindestversion | iPadOS 17 |
| Gerätefamilie | iPad |
| Swift-Sprachmodus | Swift 6 |
| Bundle-ID | `com.dominikvogel.BirdNotes` |
| Funktionszugriff | vollständig, ohne Kauf-/Kontologik |

## 3. Zuständigkeiten der Dateien

### App und Start

| Datei | Verantwortung |
|---|---|
| `BirdNotes/App/BirdNotesApp.swift` | App-Einstieg, Root-Komposition, geführtes Cloud-Onboarding, Auswahl und Recovery des Bibliotheksordners, Security-Scoped Bookmark, Migration sowie strikt isolierte UI-/Performance-Teststarts für Seiten, Bibliothek und Canvas |
| `BirdNotes/App/Info.plist` | Dokumenttypen, Uniform Type Identifier und private App-Konfiguration |
| `BirdNotes/App/PrivacyInfo.xcprivacy` | Apples Datenschutzmanifest für die App |
| `BirdNotes/Assets.xcassets` | App-Icon, BirdNotes-Logo und Asset-Metadaten |

### Bibliothek

| Datei | Verantwortung |
|---|---|
| `LibraryView.swift` | Eigenständiger Arbeitsbereich mit Sidebar, Raster/Liste, Suche, Tags, Favoriten, Verlauf, Papierkorb, Konfliktcenter, Import-/Backup-/Restore-Dialogen und Dokumentnavigation |
| `LibraryViewModel.swift` | asynchroner UI-Zustand, Laden und Mutieren der Bibliothek, Sortierung, Suche, Dateiaktionen, verständliche Fehlerweitergabe und datenschutzneutraler Bibliotheks-Lademesspunkt |
| `LibrarySupport.swift` | `NSFilePresenter` für externe Änderungen sowie lokaler Thumbnail-Cache und Invalidierung |
| `MoveDestinationView.swift` | sichere Auswahl eines Zielordners für Verschiebeoperationen |

### Notizbuch und Zeichnen

| Datei | Verantwortung |
|---|---|
| `NotebookView.swift` | Notizbucheditor, Werkzeugleiste, Seitenübersicht, Seiteneinstellungen, Export und Handschrift-zu-Druckschrift-Oberfläche |
| `NotebookViewModel.swift` | Laden, seitengenaues Autosave, Lifecycle-Flush, Seitenoperationen, Lesezeichen sowie lokale Vision-Texterkennung |
| `PencilPageCanvas.swift` | UIKit-Brücke für PencilKit, fortlaufendes A4-/A3-Seitenlayout, sichtbarkeitsbasierte View-Virtualisierung, Speicherdruck-Bereinigung, Instruments-Messpunkte, stabile Zoom-Geometrie, VoiceOver-Seitennavigation und Canvas-Proxies |
| `DrawingToolController.swift` | Stiftprofile, Farben, Breiten, Radierermodi, Lasso, Handwerkzeug, Undo/Redo und Pencil-Doppeltipp |
| `PaperBackgroundView.swift` | immer helle, vektorielle Vorlagen für leer, liniert, kariert, punktiert und Cornell |

### Infinite Canvas

| Datei | Verantwortung |
|---|---|
| `InfiniteCanvasView.swift` | große helle Arbeitsfläche, PencilKit, Zoom/Pan, Viewport, Autosave, Objektimport und Bilddekodierungsgrenzen |
| `CanvasObjectLayer.swift` | viewportbasierte, rotationstolerante Materialisierung sowie Darstellung, Auswahl und Bearbeitung semantischer Text-, Bild-, Form- und Connector-Elemente; Connectoren verwenden einen einmalig aufgebauten ID-Index |

### PDF und Export

| Datei | Verantwortung |
|---|---|
| `PDFDocumentView.swift` | PDFKit-Viewer, PencilKit-Overlay pro Seite, Eingabemodus, persistente Annotationen und Export |
| `ExportSupport.swift` | Notizbuch-/Seiten-/PDF-Export, sicherer Backup-ZIP-Import, Größen-, CRC-, Pfad- und Kompressionsprüfungen |
| `PaperStyle+Display.swift` | sichtbare Namen, Icons und Maße der Papierstile/-formate |
| `BirdNotesTheme.swift` | Farben, Abstände und wiederverwendbare visuelle Konstanten |

### Technik- und Studienwerkzeuge

| Datei | Verantwortung |
|---|---|
| `TechnicalWorkspaceView.swift` | heller semantischer Technikeditor mit Symbolpalette, Verbindungen, Snap, Drehen, Inspector, Berechnungen, Autosave und SVG-Export |
| `StudyToolsView.swift` | lokaler Curriculum-Browser, CP-/Wochenplanung, Requirements-Check, Zahlensysteme, Komplexität, Statistik, IPv4/CIDR sowie Wissenschafts-/Qualitätschecklisten |
| `TechnicalModule.swift` | deklarativer, validierter Modul-, Symbol-, Eigenschafts- und Formelvertrag |
| `BuiltInModules.swift` | kompilierte Kataloge für allgemeine Diagramme, Elektrotechnik, Zeichnen, Mechanik, IT und Softwareentwicklung/Studium |
| `StudyCatalog.swift` | versionierte Zuordnung von Pflicht- und Wahlmodulen zu Themen und Werkzeugen |
| `StudyTools.swift` | deterministische, ressourcenbegrenzte Studienrechner ohne Code- oder Netzwerkausführung |
| `BirdTechDocumentStore.swift` | atomare `.birdtech`-Packages, Prüfsummen, Größenlimits, Pfad- und Symlinkabwehr |
| `Expression.swift` / `Units.swift` | Whitelist-Ausdrucksparser, Rechenspur, Dimensionen und SI-Einheiten |

### Core-Modelle und Speicher

| Datei | Verantwortung |
|---|---|
| `DocumentModels.swift` | Bibliothekseinträge, Dokumentarten, Sortierung, Tags/Favoriten/Verlauf, Konflikte sowie Backup-Vorschau und -Ergebnis |
| `NotebookModels.swift` | Notizbuchmanifest, A4/A3, Papierstile, Seitenmetadaten und Zeichenpayload |
| `CanvasModels.swift` | Canvasmanifest, Viewport/Kachelung sowie portable Text-, Bild-, Shape- und Connector-Elemente |
| `NotebookPageCreationPolicy.swift` | reine Regel für die automatisch erzeugte freie Folgeseite |
| `DocumentStore.swift` | actor-isolierte Quelle aller Dateisystemoperationen: Pfadprüfung, CRUD, atomare Studiengangsstruktur, Pakete, PDF-Begleitdaten, Suche, Papierkorb, Konflikte, Backup/Restore und Ressourcenlimits |
| `DocumentStoreError.swift` | typisierte, vergleichbare und nutzerlesbare Speicherfehler |
| `JSONCoding.swift` | einheitliche JSON-Kodierung mit ISO-8601-Daten und stabil sortierten Schlüsseln |
| `BirdNotesCore/.../PrivacyInfo.xcprivacy` | Datenschutzmanifest des wiederverwendbaren Core-Moduls |

### Tests und Projektkonfiguration

| Datei | Verantwortung |
|---|---|
| `DocumentStoreTests.swift` | Dateioperationen, Formate, Migration, Limits, Manipulationsschutz, Papierkorb, Backup/Restore, Suchpersistenz sowie 1.000-/2.000-Einträge-Skalierungsintegrität |
| `NotebookPageCreationPolicyTests.swift` | Grenzfälle der automatischen Folgeseite und A4-Rückwärtskompatibilität |
| `BackupImportSupportTests.swift` | echtes System-ZIP-Roundtrip, A4-/A3-Layout, 100-/500-Seiten- und 2.000-Canvasobjekte-Virtualisierung, Performance-Argumente, Speicherdruck, VoiceOver und Fingerbedienung im App-Kontext |
| `BirdNotesUITests.swift` | beschreibt mehrere Seiten getrennt und prüft Seitennavigation, automatische Folgeseite, Lifecycle-Autosave, Ausrichtung sowie Persistenz nach App-Neustart |
| `BirdNotes.xcodeproj/project.pbxproj` | Targets, Quellen, Buildsettings, Version, Plattform und Signierung |
| `BirdNotes.xcscheme` | Build-, Test-, Run-, Profile- und Archive-Aktionen |
| `.github/workflows/ci.yml` | reproduzierbares GitHub-Actions-Qualitätsgate auf Push zu `main` und Pull Requests |

## 4. Skriptkatalog

Alle Skripte sind strikt (`set -euo pipefail`), arbeiten aus dem Repository-Root und brechen beim ersten relevanten Fehler mit einem Exitcode ungleich null ab.

| Skript | Zweck | Wann ausführen |
|---|---|---|
| `scripts/check-docs.sh` | prüft alle lokalen Markdown-Datei- und Verzeichnislinks; Weblinks werden nicht automatisiert geöffnet | nach Dokumentations-, Datei- oder Verzeichnisänderungen |
| `scripts/check-project.sh` | prüft Plists, Privacy-Manifeste, Xcode-Projektdatei, private Laufzeitkonfiguration, Abwesenheit alter Kauf-/Freischaltlogik, Syntax aller Shell-Skripte und lokale Dokumentationslinks | nach Konfigurations-, Target-, Signing-, Skript- oder Dokumentationsänderungen |
| `scripts/check-security.sh` | sucht typische eingecheckte Zugangsdaten/private Schlüssel, verbietet `try!`/`fatalError` im Produktions-Swift und unerwartete versionierte Symlinks | bei jeder Änderung, insbesondere Import-/Storage-/Security-Code |
| `scripts/create-testflight-archive.sh` | prüft die Release-Identität und erzeugt mit dem in Xcode angemeldeten Apple-Team ein signiertes `.xcarchive`; Upload und Testerfreigabe bleiben bewusst im Xcode Organizer/App Store Connect | nach grünem Release-Gate auf dem freizugebenden Commit |
| `scripts/test.sh core` | führt `BirdNotesCore` und `BirdNotesTechnicalCore` mit Coverage in getrennten isolierten Caches aus | während der Entwicklung nach Core-Änderungen |
| `scripts/test.sh app` | ermittelt einen verfügbaren iPad-Simulator und führt die app-nahen Integrations-/Layouttests aus | nach UIKit-, ZIP- oder Integrationsänderungen |
| `scripts/test.sh ui` | führt den isolierten XCUITest-Smoke-Test aus; echte Bibliothek und Cloud-Onboarding bleiben unberührt | nach UI-, Navigation-, Autosave- oder Persistenzänderungen |
| `scripts/test.sh asan` | führt App- und eingebettete Core-Tests mit Address Sanitizer und deaktivierter Testparallelität aus | vor Release Candidate sowie nach Import-/Low-Level-Änderungen |
| `scripts/test.sh tsan` | führt App- und eingebettete Core-Tests mit Thread Sanitizer und deaktivierter Testparallelität aus | vor Release Candidate sowie nach Concurrency-/Lifecycle-Änderungen |
| `scripts/test.sh sanitizers` | führt Address und Thread Sanitizer strikt getrennt mit eigenen Buildverzeichnissen aus | vor jedem Release Candidate |
| `scripts/test.sh all` | kombiniert Core-, App- und UI-Teststufe | vor Review und Merge |
| `scripts/prepare-release-evidence.sh` | erzeugt aus der versionierten Vorlage einen mit Commit versehenen Nachweis für Performance, Soak, Accessibility, iCloud und Gerätesignierung; führt die externen Tests nicht selbst aus | vor jedem Geräte-Release |
| `scripts/verify.sh` | orchestriert Projektcheck, Security-Baseline, alle Tests, generischen iOS-Release-Build und statische Release-Analyse | verbindlich vor Push/Release; identisch zum CI-Gate |

Die Simulator-Modi `app`, `ui`, `asan`, `tsan` und `sanitizers` akzeptieren optional `BIRDNOTES_TEST_DESTINATION`, beispielsweise eine von `xcodebuild -showdestinations` unterstützte Destination. Ohne Vorgabe wird zuerst ein verfügbarer iPad-Simulator und ersatzweise ein anderer iOS-Simulator gewählt. Kombinierte Modi ermitteln diese Destination genau einmal, damit ein kurzzeitig beschäftigter Runner nicht zwischen den Stufen fälschlich als simulatorlos gilt.

Die Prüfskripte installieren keine Software und verändern keine Nutzerdokumente. Die Prüfungen verwenden temporäre Buildverzeichnisse; `prepare-release-evidence.sh` schreibt ausschließlich den Nachweis und `create-testflight-archive.sh` ausschließlich das explizit angeforderte Archiv in den jeweiligen Zielordner.

## 5. Automatisierung in GitHub Actions

`.github/workflows/ci.yml` startet bei jedem Pull Request und bei Pushes auf `main`. Der Workflow:

1. checkt den Commit ohne persistierte GitHub-Zugangsdaten aus,
2. wählt Xcode 26.6,
3. führt `./scripts/verify.sh` aus,
4. beendet den Lauf bei Konfigurations-, Security-, Test-, Build- oder Analysefehlern.

Ältere Läufe desselben Branches werden abgebrochen, wenn ein neuer Commit eintrifft. Die Workflow-Berechtigung ist auf lesenden Repositoryzugriff beschränkt. Branchschutz sollte das erfolgreiche Gate und mindestens ein Review für `main` verpflichtend machen.

## 6. Standardbefehle

```bash
# Schnell: plattformunabhängige Core-Tests
./scripts/test.sh core

# App- und Integrationstests im Simulator
./scripts/test.sh app

# Isolierter Nutzerablauf im Simulator
./scripts/test.sh ui

# Getrennte Speicherzugriffs- und Datenrennenprüfungen
./scripts/test.sh sanitizers

# Alle automatischen Tests
./scripts/test.sh all

# Vollständiges lokales/CI-Qualitätsgate
./scripts/verify.sh
```

Direkte Befehle sind für Diagnose möglich, aber nicht der führende Freigabeweg:

```bash
swift test --package-path BirdNotesCore
swift test --package-path BirdNotesTechnicalCore

xcodebuild \
  -project BirdNotes.xcodeproj \
  -scheme BirdNotes \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 7. Zentrale Laufzeitflüsse

### Bibliothek öffnen

```text
BirdNotesApp
  → Security-Scoped Bookmark beziehungsweise lokaler Standard-Root
  → DocumentStore
  → LibraryViewModel
  → LibraryView
```

### Handschrift speichern

```text
sichtbarer Seitenbereich + Vorladepuffer
  → nur benötigte PKCanvasView-Instanzen materialisieren
  → entfernte Seitenansichten freigeben, aktive Seite behalten
PKCanvasView
  → NotebookViewModel aktualisiert In-Memory-Seite
  → 800-ms-Debounce oder Lifecycle-Flush
  → DocumentStore.saveDrawing
  → drawing.data atomar
  → metadata.json
  → manifest.json zuletzt, falls eine Folgeseite entstand
```

### PDF annotieren

```text
PDFKit-Seite
  + transparenter PKCanvasView
  → page-<index>.drawing im versteckten Begleitordner
  → beim Export PDF-Seite und Drawing in neue PDF gerendert
```

### Backup wiederherstellen

```text
ZIP oder .birdbackup
  → Pfad/CRC/Größe/Kompression prüfen
  → Paketstruktur und Dokumente prüfen
  → Vorschau und Konfliktstrategie
  → Eingang + Rollback-Kopie + persistentes Journal
  → Commit oder automatisches Rollback beim nächsten Start
```

## 8. Regeln für neue Dateien und Module

1. Fachlogik ohne UIKit gehört in ein Core-Target und erhält Unit Tests.
2. SwiftUI-/UIKit-Code enthält keine direkten, unvalidierten Dateisystemoperationen.
3. Neue persistente Felder brauchen Defaultwerte oder eine explizite Migration.
4. Neue Dateitypen brauchen UTI, Größen-/Komplexitätsgrenzen, Importvalidierung, Backup-Unterstützung und Negativtests.
5. Neue Berechnungen brauchen Einheiten, Gültigkeitsbereich, deterministische Ergebnisse und Referenztests.
6. Neue Symbolkataloge brauchen stabile IDs, Versionsangabe und geklärte Nutzungsrechte.
7. Jede Änderung aktualisiert relevante Architektur-, Test-, Security-, Datenschutz- und Changelog-Dokumente.
8. `./scripts/verify.sh` muss vor Abschluss grün sein.

## 9. Nicht versionierte und erzeugte Inhalte

Folgende Inhalte gehören nicht ins Repository:

- `.build/`, Derived Data, `.xcresult` und Simulatorzustände,
- persönliche Xcode-Schemes und Benutzeroberflächenzustände,
- Provisioning Profiles, Zertifikate und private Schlüssel,
- echte Nutzernotizen, Backups oder personenbezogene Testdaten,
- App-Store-Connect-Schlüssel und sonstige Zugangsdaten.

Testdaten müssen künstlich erzeugt, urheberrechtlich geklärt und frei von echten personenbezogenen Informationen sein.
