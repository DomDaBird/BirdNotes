# Changelog

Alle wesentlichen Änderungen werden hier dokumentiert. Das Projekt folgt bis zur ersten öffentlichen Version noch keiner stabilen semantischen Versionierung.

## Unreleased

Zielversion: 3.1.0 (Build 6)

### Added

- öffentliche README, technische Datenschutzinformation, Sicherheitsrichtlinie und allgemeine iPad-Installationsanleitung
- automatischer Repository-Check für persönliche lokale Pfade, E-Mail-Adressen und fest eingetragene Apple-Team-IDs
- geführte Verbindung mit einem frei gewählten Ordner aus der Dateien-App
- atomare Software-Development-Studienbibliothek für alle Pflichtmodule mit Cornell-Lernnotizen, Active Recall, Übungen, Literatur/PDFs und Prüfungsvorbereitung
- Wiederholungsplan nach Lernstand, Active-Recall-/Feynman-Checkliste und lokaler, größenbegrenzter JSON-Prüfer
- zwei zusätzliche Studien-Core-Tests und ein atomarer Studiengangs-Strukturtest; die Kerne umfassen jetzt 57 beziehungsweise 37 Tests

- `BirdNotesTechnicalCore` als getrenntes Swift Package mit SI-Dimensionen, affinen Temperatureinheiten, sicherem Formelparser und Rechentraces
- semantischer Diagrammgraph mit Elementen, Ports, Verbindungen, Ebenen, Labels und Constraints
- versioniertes `.birdtech`-Paket mit SHA-256-Integrität, atomarem Save, Größenlimits und Symlink-Abwehr
- transaktionale Diagrammbefehle, Undo/Redo, Raster-/Winkelfang und sicherer SVG-Export
- fest kompilierte Symbol- und Formelmodule für Elektrotechnik, Zeichnen, Mechanik, IT und allgemeine Diagramme
- nativer iPad-Technikeditor mit heller Zeichenfläche, Palette, Verbindungen, Inspektor, Autosave, Berechnungen und Export
- vollständige Bibliotheksintegration technischer Dokumente für lesbare Dateinamen, Umbenennen, Duplizieren, Papierkorb und Backup
- 26 isolierte Technik-Core-Tests mit dauerhaftem v1-Golden-File und Einbindung in das zentrale Testskript
- lokaler Studienkatalog mit allen 20 Pflichtmodulen der Semester 1 bis 4, wichtigen Wahlvertiefungen und werkzeugbezogener Modulzuordnung
- native Studien-Werkzeuge für CP-/Wochenplanung, Requirements-Review, Zahlensysteme, Komplexität, Statistik und IPv4/CIDR
- interaktive Checklisten für wissenschaftliches Arbeiten und Qualitätssicherung
- Studien-Symbolkatalog für Requirements, Use Cases, UML-Klassen, Komponenten, ER-Entitäten, CI/CD, Trust Boundaries und Testfälle
- zusätzliche Studienkatalog-, Rechner-, Security- und Negativtests; zusammen mit den neuen Lernwerkzeugen umfasst `BirdNotesTechnicalCore` jetzt 37 Tests

- Zentraler Projektplan mit Meilensteinen, Prioritäten, Risiken und Release-Gates
- Vollständiges Repository-/Skripthandbuch, Dateiformatvertrag und zentraler Dokumentationsindex
- Modularchitektur und Fachpläne für Mathematik/Einheiten, Elektrotechnik, technisches Zeichnen, Physik/Mechanik sowie IT/Digitaltechnik
- Standardisierte Skripte für Projektkonfiguration, Security-Baseline, Core-Tests, App-/Simulatortests und das vollständige Release-Gate
- Isolierter XCUITest-Modus und Mehrseiten-Smoke-Test für Zeichnen, Seitennavigation, Lifecycle-Autosave, Ausrichtungswechsel und Neustart-Persistenz
- 100-Seiten-Integritätstest für Reihenfolge, gemischte Papiermetadaten und Wiederöffnung
- Sichtbarkeitsbasierte Virtualisierung großer Notizbücher mit Vorladefenster, unmittelbaren Seitensprüngen und Regressionstests für begrenzte PencilKit-Ansichten sowie Zeichnungsdatenerhalt
- 500-Seiten-Lastfall, Speicherdruck-Bereinigung, Instruments-Points-of-Interest und isolierte 100-/500-Seiten-Performance-Fixtures
- Isolierte Last-Fixtures für 1.000 Bibliothekseinträge und 2.000 Canvasobjekte sowie automatische Persistenz- und Culling-Regressionen
- Separate, reproduzierbare Address- und Thread-Sanitizer-Testmodi
- VoiceOver-Aktionen zur fortlaufenden Seitennavigation, größere Werkzeugziele bei Accessibility-Dynamic-Type und abgesicherte Bedienung ohne Pencil
- Release-Abnahmerunbook samt erzeugbarer Nachweisvorlage für Performance, Soak, Accessibility, iCloud und Gerätesignierung
- Fortlaufender, vertikal scrollbarer Notizbuchmodus mit mittig ausgerichteten A4-/A3-Seiten
- Persistentes Hoch-/Querformat je Notizbuchseite mit direktem Umschalter, korrekten Exportabmessungen und kompatibler Migration
- Wahlweise automatische Zoom-Anpassung bei Gerätedrehung für Notizbuch und Infinite Canvas
- Datenschutz-Manifeste für App und Core-Framework
- Wiederherstellbarer Papierkorb für die letzten 30 Löschungen
- CI-Qualitätsgate, Bedrohungsmodell, Test-, Qualitäts- und Release-Dokumentation
- Negative Tests für manipulierte Pfade, PDFs, Statusdateien und Canvas-Werte
- Kurs-/Semester-Tags mit rekursiver Suche und Sidebar-Sammlungen
- Punktiertes und Cornell-Papier sowie wichtige Seitenmarkierungen
- Vollständige Papierkorb-Ansicht mit gezielter Wiederherstellung und endgültiger Leerung
- Koordinierter, systemkomprimierter Bibliotheks-Backup-Export
- Atomarer Studienbereich-Assistent mit Semesterordnern und A4-Cornell-Übersicht
- Validierter Backup-Import mit Vorschau, drei Konfliktstrategien und Recovery-Journal
- Paketweite Redo-Journale für mehrteilige Notizbuch-/Canvas-Saves mit automatischer Crash-Reparatur
- Dauerhafte Golden-File-Pakete und Save-after-load-Migrationstests für Notizbuch-/Canvas-Schema v1 und v2
- Sichtbares Konfliktcenter für parallele iCloud-Dateiversionen
- Lokale Handschrifterkennung, editierbare Druckschrift und seitenbezogene Volltextsuche
- Signierter TestFlight-Archive-Ablauf, Release-Preflight und deklarierte Export-Compliance

### Security

- persönliche lokale Pfade und die fest eingetragene Development-Team-ID aus App, Projektdatei und Dokumentation entfernt
- Ignorierregeln für Provisioning-Profile, Zertifikate, Schlüssel und lokale Konfigurationsdateien ergänzt
- Kauf-, Konto- und Freischaltlogik einschließlich StoreKit-Konfiguration vollständig aus App, Scheme und Projekt entfernt
- Projektgate verhindert die versehentliche Rückkehr alter StoreKit-, Paywall- oder Commercial-Mode-Komponenten

- Security-Scoped Bookmark in den lokalen iOS-Schlüsselbund migriert
- Symlink- und Paket-Traversal verhindert
- Größen-, Pixel-, Objekt-, Seiten-, Text- und Zahlenvalidierung ergänzt
- Bildimport wird vor dem Dekodieren geprüft und auf eine sichere Größe normalisiert
- Backups folgen keinen symbolischen Links und schließen den internen Papierkorb aus
- ZIP-Import prüft Pfade, Links, Typen, Größen, Kompressionsrate, Duplikate und CRC vor dem Core-Import
- Speicherjournale sind per Dokument-ID, Zielpfad-Allowlist, Größenlimit, exakter Bytezahl und SHA-256 gegen Verwechslung oder Manipulation abgesichert
- Security-Gate verhindert typische Zugangsdaten, private Schlüssel, erzwungene Produktionsabbrüche und unerwartete versionierte Symlinks
- PDF-Handschrift-Begleitordner und ihre Zeichnungsdateien lehnen symbolische Links ab

### Fixed

- PDF-Seiten verwenden standardmäßig ausschließlich den Apple Pencil zum Bearbeiten; ein Finger scrollt, zwei Finger zoomen, und eine bewusst aktivierte Fingerzeichnung bleibt als Einstellung erhalten.
- Wiederverwendete PDFKit-Seiten erhalten ihren PencilKit-Delegate und Seitenindex erneut, sodass Änderungen nach langem Scrollen weiter automatisch gespeichert werden.
- PDF-Autosave sichert nach jedem abgeschlossenen Werkzeugvorgang, beim Ausblenden einer Seite sowie mit Hintergrundzeit bei App-Wechsel; ein Flush mehrerer geänderter Seiten mutiert seine Warteschlange nicht mehr während der Iteration.
- Der Infinite Canvas baut nur noch viewportnahe Objektansichten auf; Connector-Endpunkte werden über einen einmaligen Index statt durch wiederholte lineare Suchen aufgelöst.
- Das Projektgate schützt den vorhandenen nativen Launch-Screen-Eintrag vor versehentlichem Entfernen; die Xcode-Warnung des generierten UI-Test-Runners betrifft nicht die BirdNotes-App.
- Das Testskript ermittelt die Simulator-Destination pro Gesamtlauf nur einmal; GitHub Actions verliert damit zwischen grünem App-Test und UI-Test nicht mehr transient das bereits verwendete Ziel.
- Seitenauswahl aus der Übersicht positioniert A4-/A3-Seiten zuverlässig unter der Werkzeugleiste, ohne durch Scroll- oder Zoom-Zustände zurückzuspringen
- Mehrseitige Dokumentgeometrie bleibt beim Hinzufügen von Seiten und bei aktivem Zoom stabil
- Ein verlorener oder entzogener iCloud-/Dateien-Ordner bietet beim Start direkte Wiederwahl oder einen dauerhaften lokalen Fallback an
