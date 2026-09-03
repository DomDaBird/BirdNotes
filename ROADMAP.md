# Roadmap

Diese Roadmap dokumentiert den Funktionsumfang. Prioritäten, Meilensteine, Risiken und Freigabegates stehen im [zentralen Projektplan](docs/PROJECT_PLAN.md).

## Phase 1 – Technisches Grundgerüst

Status: Implementierung, gemeinsamer BirdNotes-Ordner, beschreibbare PDFs, Canvas-Grundversion, neues Arbeitsbereich-Design, App-Icon, Xcode-Build und Simulator-Tests abgeschlossen. Ausstehend ist der Praxisdurchlauf auf einem echten iPad mit Apple Pencil und iCloud Drive.

- [x] App-Navigation und Library
- [x] persistente, verschachtelte Ordnerstruktur
- [x] versionierte Dokument- und Notizbuchmodelle
- [x] sicheres `.birdnotebook`-Package-Format
- [x] PencilKit-Seite mit Stift, Marker, Radierer und Lasso
- [x] Apple Pencil und Finger zeichnen; Handwerkzeug beziehungsweise zwei Finger navigieren
- [x] leeres, liniertes und kariertes Papier als separate Ebene
- [x] A4 als Standardformat und A3 als wählbares Seitenformat
- [x] persistentes Hoch-/Querformat pro Seite und abschaltbare automatische Breitenanpassung bei Gerätedrehung
- [x] debounced Autosave und Lifecycle-Flush
- [x] mehrere Seiten, Seitennavigation und lazy Thumbnails
- [x] gut erreichbarer Neue-Seite-Button
- [x] automatische neue letzte Seite bei tatsächlichem Zeicheninhalt
- [x] Seiten hinzufügen, löschen, duplizieren und umsortieren
- [x] Storage- und Page-Policy-Tests angelegt
- [x] sichtbarer Autosave-Zustand und Wiederholungsaktion bei Speicherfehlern
- [x] Erstbenutzungshinweis für Pencil- und Fingergesten
- [x] alle 48 Core-, Sicherheits-, Migrations- und Skalierungstests mit Swift Testing erfolgreich ausgeführt
- [x] frei wählbarer BirdNotes-Ordner mit dauerhaftem Security-Scoped Bookmark
- [x] sichere Übernahme der bisherigen lokalen Bibliothek
- [x] PDF-Import, externe PDF-Erkennung und beschreibbare PDFKit-Seiten
- [x] eigenständiges Arbeitsbereich- und Sidebar-Design
- [x] BirdNotes-Vogellogo als App-Icon und Markenmotiv
- [x] vollständiges Geräte-Feedback-Runbook erstellt
- [x] Xcode-Lizenz interaktiv geprüft und akzeptiert
- [x] erfolgreicher Xcode/iPadOS-Build mit Xcode 26.6 und iOS-26.5-SDK
- [x] iPad-Test-Target in Xcode erfolgreich ausgeführt
- [x] standardisierte Projekt-, Security-, Core-, Simulator- und Release-Prüfstufen als Skripte eingerichtet
- [x] App-Start auf iPad (A16) und iPad Air 13" visuell geprüft
- [ ] Definition-of-Done-Ablauf auf einem echten iPad mit Apple Pencil verifizieren

## Phase 2 – Infinite Canvas

- [x] `.birdcanvas`-Package und Manifest
- [x] große virtuelle Arbeitsfläche
- [x] Zoom und Pan
- [x] PencilKit-Eingabe
- [x] persistenter Viewport und „Alles anzeigen“
- [x] reversible, abschaltbare Viewport-Anpassung bei Gerätedrehung
- [x] Autosave und Grundwerkzeuge
- [x] rückwärtskompatible Metadaten zur Vorbereitung auf räumliche Kachelung
- [x] viewportbasierte Objektvirtualisierung und lineare Connector-Auflösung für große Canvases
- [x] isoliertes 2.000-Objekte-Fixture, Persistenztest und Instruments-Messpunkt

## Phase 3 – Eigene Toolbar

- [x] verfeinertes Werkzeugmodell
- [x] Kugelschreiber, Monoline, Füller, Bleistift und Marker
- [x] flexible Farbpalette und zuletzt verwendete Farben
- [x] präzisere Strichbreiten
- [x] Strich-, Pixel- und Festbreitenradierer
- [x] Lasso-, Handwerkzeug- und Apple-Pencil-Doppeltipp
- [x] vollständig zustandsabhängiges Undo/Redo

## Phase 4 – Shapes und Selection

- [x] Linie und Pfeil
- [x] Rechteck und abgerundetes Rechteck
- [x] Kreis, Ellipse und Dreieck
- [x] eigenständiges, portables Canvas-Objektmodell
- [x] Auswahl, Verschieben, Skalieren und Rotieren
- [x] Copy, Paste, Cut, Delete und Duplicate

## Phase 5 – PDF

- [x] Import über Apples Dokument-Picker
- [x] PDFKit-Viewer
- [x] Zoom, Scrollen und Seitennavigation
- [x] Share Sheet für die Original-PDF
- [x] persistente PencilKit-Annotationsebene pro PDF-Seite
- [x] Export einer PDF mit abgeflachter Handschrift

## Phase 6 – Komfortfunktionen

- [x] persistenter Thumbnail-Cache mit Invalidierung
- [x] rekursive Suche, Favoriten und zuletzt geöffnet
- [x] Notizbuch- und Seitenexport als PDF/PNG in physischen A4-/A3-Abmessungen
- [x] punktierte und Cornell-Vorlagen mit Vererbung auf neue Seiten
- [x] koordinierter, systemkomprimierter Bibliotheks-Backup-Export
- [x] Kurs-/Semester-Tags mit Suche und Sidebar-Filter
- [x] wichtige Seiten markieren und in der Seitenübersicht filtern
- [x] vollständige Papierkorb-Ansicht mit gezielter Wiederherstellung und Leerung
- [x] atomarer Studienbereich-Assistent mit Semesterstruktur und A4-Cornell-Übersicht
- [x] dateibasierte Nutzung über einen wählbaren iCloud-Drive-/File-Provider-Ordner
- [x] lokale Handschrifterkennung, editierbare Druckschrift und seitenbezogene Volltextsuche
- [x] Mindmap-Nodes, Connectoren, Bilder und editierbare Textboxen
- [x] automatische Aktualisierung bei Änderungen aus Finder/iCloud/File Provider
- [x] koordinierte Schreibvorgänge und Erkennung ungelöster Dateikonflikte

## BirdNotes 2.0 – Vertrauen und Wiederherstellung

- [x] validierter `.birdbackup`-/ZIP-Import mit CRC-, Pfad-, Typ-, Größen- und Strukturprüfung
- [x] Wiederherstellungsvorschau und Strategien „Beide behalten“, „Überspringen“ und „Ersetzen“
- [x] Recovery-Journal mit Rollback für unterbrochene Backup-Wiederherstellungen
- [x] sichtbares iCloud-Konfliktcenter mit Erhalt beider Versionen
- [x] alter Kauf- und Freischaltpfad vollständig entfernt
- [x] Projektgate verhindert die versehentliche Rückkehr alter Kauf-/Paywall-Komponenten
- [x] echter ZIP-Rundtest im Simulator
- [ ] Praxisabnahme der Handschrifterkennung mit unterschiedlichen Handschriften und Sprachen

## BirdNotes 3 – technische Plattform und Ausbauplanung

Status: Sichere gemeinsame v3-Grundplattform und erste Lernkataloge sind implementiert. Fachsolver, Normprüfung, erweiterte Werkzeuge und reale iPad-Abnahme folgen inkrementell nach dem [Projektplan](docs/PROJECT_PLAN.md).

### Lokale Studienorganisation

- [x] frei wählbarer Bibliotheksordner aus der Dateien-App
- [x] geführtes iPad-Cloud-Onboarding mit dauerhaftem Security-Scoped Bookmark
- [x] atomare Bibliothek für alle Pflichtsemester und Pflichtmodule
- [x] Cornell-Lernnotizen, Active Recall, Übungen, PDFs und Prüfungsvorbereitung pro Modul
- [x] Wiederholungsplan, Active-Recall-/Feynman-Ablauf und sicherer JSON-Prüfer
- [ ] realer Kabel-, Pencil-, Cloud- und Neustarttest auf dem iPad

### Gemeinsame Technikplattform

- [x] Zielarchitektur und eigener `.birdtech`-Dokumenttyp spezifiziert
- [x] Sicherheitsgrenze „deklarative Daten, keine ausführbaren Plugins“ festgelegt
- [x] gemeinsame Test-, Migrations-, Norm- und Lizenzanforderungen beschrieben
- [x] `BirdNotesTechnicalCore` als unabhängiges Swift Package anlegen
- [x] typisierte SI-Einheiten, sicherer Ausdrucksparser und Rechenspur implementieren
- [x] semantischen Diagrammgraph, Commands, Undo/Redo sowie Raster-/Winkelfang implementieren
- [x] `.birdtech` in Library, Namenssuche, Papierkorb, Backup und Restore integrieren
- [x] sicheren SVG-Vektorexport erstellen
- [ ] inkrementellen Constraint-Solver sowie PDF-/PNG-Technikexport ergänzen

### Elektrotechnik und Elektronik

- [x] MVP, Symbolbereiche, ERC, Berechnungen, Sicherheitsgrenzen und Tests geplant
- [ ] eigener rechtlich geklärter Lernsymbolkatalog
- [x] stabile elektrische Ports, einfache Verbindungen, Widerstand, Kondensator, Quelle und Masse
- [x] einheitengeprüftes Ohmsches Gesetz und elektrische Leistung
- [ ] Netze, Junctions, Referenzkennzeichen, KCL/KVL und Messpunkte
- [ ] ERC, Netzliste, Stückliste und Referenzschaltungen

### Technisches Zeichnen

- [x] 2D-Geometrie, Bemaßung, Constraints, Normbezug und Tests geplant
- [x] Linien-, Rechteck-, Kreis- und Bemaßungsgrundformen mit Raster-/Winkelfang
- [ ] Layer, Linienarten, Rahmen und Schriftfeld
- [ ] sicherer Constraint-Solver und treibende Maße
- [ ] geprüfter maßstäblicher Vektorexport

### Physik und Technische Mechanik

- [x] Freikörperbilder, Vektoren, Statik/Kinematik und Tests geplant
- [x] Balken, feste Einspannung, Kraftpfeil sowie Kraft-/Momentformeln
- [ ] Einheiten- und Annahmenprüfung
- [ ] ebene Statik, grundlegende Kinematik/Energie und Referenzaufgaben
- [ ] spätere Festigkeits-, Schwingungs-, Wärme- und Strömungsbausteine

### IT, Informatik und Digitaltechnik

- [x] Ablauf-, UML-, ER-, Netzwerk-, Logik- und Security-Umfang geplant
- [x] Ablauf-/Netzwerkgrundelemente und CIDR-/Zahlensystemrechner
- [x] UML-Klassen-, Komponenten- und ER-Entitätsgrundformen
- [ ] Logikgatter, Wahrheitstabellen und Timingdiagramme
- [x] Architektur-, Pipeline-, Testfall- und Trust-Boundary-Grundformen
- [ ] vollständige UML-/ER-Beziehungen, Kardinalitäten und Bedrohungsregister

### Studienwerkzeuge Softwareentwicklung

- [x] 20 Pflichtmodule der Semester 1 bis 4 katalogisiert und Werkzeugen zugeordnet
- [x] wichtige Wahlvertiefungen für Security, Cloud, Data/AI, Mathematik, IoT, UX/XR und Projekte erfasst
- [x] CP-/Wochenplaner, Requirements-Check, Komplexitäts-, Zahlensystem-, Statistik- und IPv4/CIDR-Rechner
- [x] Wissenschafts- und Softwarequalitätschecklisten
- [ ] persönliche Modulbelegung, Vorlagen und bewusste Ergebnisübernahme in Notizen
- [ ] realer iPad-, VoiceOver-, Dynamic-Type- und Split-View-Durchlauf

Die Detailpläne stehen im [Modulkatalog](docs/modules/README.md), in den [Studienwerkzeugen](docs/STUDY_TOOLKIT.md) und in der [Modularchitektur](docs/MODULE_ARCHITECTURE.md). Fachlich oder normativ kritische Funktionen werden erst nach unabhängiger Prüfung ausgeliefert und nicht als zertifizierte Auslegung beworben.
