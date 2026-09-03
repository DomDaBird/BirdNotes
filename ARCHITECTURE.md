# Architektur

## Leitlinien

BirdNotes ist Local First. Dokumentinhalte sind portable Dateien beziehungsweise Packages; SwiftUI-Views enthalten keine direkte Dateisystemlogik. Die Architektur trennt drei Verantwortungen:

1. `BirdNotesCore`: versionierte Modelle, Pfadsicherheit und persistente Operationen
2. App-ViewModels: UI-Zustand, Fehlerdarstellung und Koordination asynchroner Speicheraktionen
3. SwiftUI/UIKit: Darstellung, Navigation und PencilKit-Eingabe

Der Umfang bleibt absichtlich kleiner als eine klassische Enterprise-Schichtenarchitektur. `DocumentStore` ist ein Actor statt eines globalen Singletons und wird per Initializer injiziert.

Die geplanten Elektrotechnik-, Zeichen-, Physik-/Mechanik- und IT-Funktionen werden nicht in diese bestehenden Canvas-Modelle hineingedrückt. Dafür ist ein separates `BirdNotesTechnicalCore` mit semantischem Diagrammgraph, typisierten Einheiten, Berechnungen und dem neuen `.birdtech`-Format vorgesehen. Die verbindliche Zielarchitektur steht in [docs/MODULE_ARCHITECTURE.md](docs/MODULE_ARCHITECTURE.md); die derzeit implementierten Formate und Limits sind in [docs/DATA_FORMATS.md](docs/DATA_FORMATS.md) dokumentiert.

## Document Model

`DocumentKind` umfasst die Typen `notebook`, `infiniteCanvas` und `pdf`. Notizbücher und Canvases sind vollständig editierbar. PDFs werden als eigenständige Dateien importiert und mit einer editierbaren PencilKit-Ebene pro Seite angezeigt. Die Library basiert auf echten Ordnern und benötigt keine separate Datenbank als Quelle der Wahrheit.

`LibraryItem` ist ein flaches Anzeigemodell für einen Eintrag in einem geöffneten Ordner. Seine Identität ist der relative Pfad innerhalb des kontrollierten Dokument-Roots. Vor jeder Operation normalisiert und validiert `DocumentStore` den Pfad, damit `..` oder absolute Pfade den Root nicht verlassen können.

Eigene Notizbücher verwenden die Endung `.birdnotebook` und den exportierten Uniform Type Identifier `com.dominikvogel.birdnotes.notebook`. Das Package wird von Finder beziehungsweise Dateien-App als ein Dokument behandelt, intern bleibt seine Struktur zugänglich und migrationsfähig.

## Notebook Model

`NotebookManifest` enthält:

- `schemaVersion`
- stabile Dokument-UUID
- Dokumenttyp
- Titel
- Erstellungs- und Änderungsdatum
- geordnete Liste der Seiten-UUIDs

Die aktuelle `schemaVersion` ist `2`. Version 2 ergänzt die persistente Seitenausrichtung. Höhere unbekannte Versionen werden ausdrücklich abgewiesen statt möglicherweise beschädigt gespeichert zu werden. Die zentrale Prüfung in `readManifest` ist der Einstiegspunkt für spätere Migrationen; beim nächsten sicheren Schreibvorgang wird ein älteres unterstütztes Manifest auf die aktuelle Version angehoben.

## Page Model

Jede Seite hat eigene `NotebookPageMetadata`:

- UUID
- Erstellungs- und Änderungsdatum
- `PaperStyle` (`blank`, `lined`, `grid`, `dotted`, `cornell`)
- `PaperFormat` (`a4`, `a3`; Standard `a4`)
- `PaperOrientation` (`portrait`, `landscape`; Standard `portrait`)
- `isEmpty`
- `isBookmarked`
- optionale, editierbare `transcribedText` aus der lokalen Handschrifterkennung

Die Zeichnung ist ein separates, opakes `Data`-Feld. `BirdNotesCore` verändert diesen Payload nicht. Die App erzeugt ihn mit `PKDrawing.dataRepresentation()` und lädt ihn mit `PKDrawing(data:)`. Dadurch bleiben Strokes, Radierer- und Auswahlverhalten editierbar.

Papier und Handschrift sind getrennte Ebenen:

```text
PaperBackgroundView (vektorielle Linien/Raster)
        ↓
PKCanvasView (editierbare PKDrawing)
        ↓
SwiftUI-Werkzeug- und Seitennavigation
```

Ein Wechsel des Papierstils oder des Papierformats berührt `drawing.data` nicht. Neue Seiten verwenden A4; A3 wird pro Seite gespeichert. Ältere Metadaten ohne Format werden rückwärtskompatibel als A4 gelesen.

## Storage

Ohne Konfiguration liegt der Root unter `Application Support/BirdNotes/Documents`. Alternativ wählt der Nutzer über den System-Dokumentpicker einen Ordner aus iCloud Drive, „Auf meinem iPad“ oder einem anderen File Provider. Die zurückgegebene Security-Scoped URL wird als Bookmark gespeichert und bei späteren Starts erneut geöffnet. Beim ersten Wechsel werden lokale Inhalte kopiert; eine versteckte Markierung verhindert eine mehrfache Migration. Das lokale Original bleibt als Rückfallkopie erhalten. Ist Bookmark oder Security Scope nicht mehr gültig, startet die App mit dem lokalen Store und bietet explizit die erneute Ordnerwahl oder das dauerhafte Entfernen des alten Bookmarks an.

Für eine geräteübergreifende Bibliothek kann beispielsweise `iCloud Drive/BirdNotes` über den Systempicker gewählt werden. Ein lokaler Mac-Pfad ist für iPadOS nicht direkt erreichbar, solange der Ordner nicht über iCloud Drive oder einen kompatiblen File Provider bereitgestellt wird.

Ordner in der UI entsprechen echten Verzeichnissen. Ein Notizbuch hat folgende Struktur:

```text
Titel.birdnotebook/
├── manifest.json
└── pages/
    ├── 44E…/
    │   ├── metadata.json
    │   └── drawing.data
    └── B18…/
        ├── metadata.json
        └── drawing.data
```

JSON verwendet ISO-8601-Datumswerte, sortierte Keys und ein explizites Schema. Einzeldateien werden über `NSFileCoordinator` atomar ersetzt; ungelöste `NSFileVersion`-Konflikte werden vor dem Überschreiben als nutzerlesbarer Fehler gemeldet. Neue Packages werden zuerst in einem temporären Geschwisterverzeichnis vollständig aufgebaut und anschließend mit einem Dateisystem-Move sichtbar gemacht.

Mehrteilige Notizbuch- und Canvas-Änderungen verwenden ein persistentes Redo-Journal. Alle neuen Payloads werden zuerst unter einer Transaktions-UUID vorbereitet und mit Bytezahl sowie SHA-256 gebunden. Erst nach Gesamtvalidierung von Dokument-ID, Schema, Ressourcenlimits und paketrelativer Zielpfad-Allowlist werden sie idempotent übernommen. Beim nächsten Start oder vor einem neuen Save wird ein unterbrochener Vorgang vorwärts fertiggestellt. Beim Anlegen gilt „neue Daten zuerst, Manifest zuletzt“; beim Löschen wird zuerst das Manifest aktualisiert und danach die verwaiste Seitendirectory entfernt. Einzelne PDF-Seitenzeichnungen bleiben ein atomarer Ein-Datei-Save. Backup-Restore verwendet unabhängig davon sein Rollback-Journal.

Der Phase-1-Store bietet:

- Ordner, Notizbuch und Canvas erstellen
- auflisten, laden und sicher speichern
- umbenennen, verschieben, duplizieren und löschen
- PDFs sicher kopieren, bei Namenskonflikten erhalten und als Library-Eintrag erkennen
- PDF-Handschrift seitenweise speichern und ihre versteckte Begleitdatei bei Dateioperationen mitführen
- Canvas-Zeichnungen in versionierten `.birdcanvas`-Packages speichern
- Canvas-Viewport, Objektmodell und Kachelmetadaten rückwärtskompatibel speichern
- Favoriten und Verlauf pfadbasiert speichern und bei Verschieben/Umbenennen nachführen
- Kurs-/Semester-Tags pfadbasiert speichern, durchsuchen und bei Dateioperationen nachführen
- gezielten Papierkorb sowie koordinierte, systemkomprimierte Bibliotheks-Backups bereitstellen
- Backups vor dem Import vollständig prüfen und konfliktgesteuert transaktional wiederherstellen
- unterbrochene Backup-Wiederherstellungen beim nächsten Start anhand eines Journals zurückrollen
- unterbrochene mehrteilige Notizbuch-/Canvas-Saves prüfsummengesichert fertigstellen
- erkannte Druckschrift persistieren und über Notizbücher hinweg durchsuchen
- ungelöste externe Dateiversionen auflisten und nach Nutzerauswahl auflösen
- Bibliotheksinhalte rekursiv auflisten
- Seite hinzufügen, duplizieren, löschen und umsortieren
- Papierstil und Papierformat aktualisieren
- originalen Drawing-Payload speichern

Fehler werden als `DocumentStoreError` mit nutzerlesbaren Beschreibungen weitergegeben. Produktionscode enthält keine `try!`-Aufrufe.

## PencilKit Integration

`ContinuousNotebookCanvas` kapselt UIKit in `UIViewRepresentable`. Eine gemeinsame `UIScrollView` ordnet alle A4-/A3-Seiten mittig untereinander an und zoomt das vollständige Notizbuch. Nur Seiten im sichtbaren Rechteck, im vertikalen Vorladefenster und die aktive Zielseite besitzen gleichzeitig einen `PKCanvasView`. Beim Recycling wird der aktuelle Drawing-Payload im kompakten Seiten-Snapshot gehalten und die UIKit-Undo-Historie freigegeben. Dadurch bleiben Zeichnung und Autosave einer Seite zugeordnet, ohne hunderte Canvas-Views im Speicher zu halten. Die interne Scrollfunktion der einzelnen Canvas-Views ist deaktiviert, damit nicht mehrere Scroll-Container konkurrieren.

Standardmäßig ist `drawingPolicy = .anyInput`: Apple Pencil und Finger zeichnen. Beim Schreiben benötigt die fortlaufende Seitennavigation zwei Finger; das Handwerkzeug schaltet wieder auf Ein-Finger-Pan um. Optional kann die UI auf `.pencilOnly` wechseln. Das Handwerkzeug deaktiviert nur den Drawing-Gesture-Recognizer; Zoom und Pan bleiben aktiv. Die Seite nahe der sichtbaren Mitte wird automatisch zur aktiven Seite für Werkzeugstatus, Undo/Redo und seitengenaues Speichern. Materialisierte Seiten bieten VoiceOver-Aktionen für Vor/Zurück; die horizontal scrollbare Werkzeugleiste vergrößert ihre Ziele bei Accessibility-Dynamic-Type.

`DrawingToolController` besitzt Werkzeugzustand, Farben, Stiftprofile, Breiten und Radierermodi unabhängig vom Canvas. Ein `UIPencilInteraction` wechselt beim Doppeltipp zwischen Radierer und vorherigem Werkzeug. `CanvasProxy` stellt zustandsabhängiges Undo/Redo bereit, ohne `PKCanvasView` in eine SwiftUI-ViewModel-God-Class zu ziehen.

## Autosave

`NotebookViewModel` aktualisiert beim PencilKit-Callback zuerst die In-Memory-Seite. Normale Änderungen werden pro Seite um 800 Millisekunden debounced. Neuere Änderungen ersetzen einen noch wartenden Task. Gespeichert wird immer ein vollständiger `PKDrawing`-Payload für genau eine Seite, nicht das ganze Notizbuch.

Zusätzlich wird ein Flush ausgelöst:

- vor strukturellen Seitenoperationen
- beim Verlassen des Editors
- wenn die App den aktiven Zustand verlässt
- bei einer iOS-Speicherwarnung; parallel reduziert der Canvas seinen Vorladepuffer

Die erste Zeichnung auf der leeren letzten Seite wird sofort gespeichert, weil derselbe Vorgang die neue freie Seite persistent erzeugt.

## Page Creation Logic

`NotebookPageCreationPolicy` ist eine reine, separat getestete Regel. Sie erzeugt nur dann eine neue Seite, wenn:

1. die geänderte Seite vor dem Edit leer war,
2. sie vor dem Edit die letzte Seite war und
3. der neue Drawing-Payload tatsächlich mindestens einen Stroke enthält.

Öffnen, Antippen, Zoomen oder erneutes Zeichnen auf einer älteren Seite erzeugen keine Seite. `DocumentStore.saveDrawing` führt die Regel aus und hängt Manifest sowie Seitendaten in einer Actor-isolierten Operation an. Die UI verwendet die vom Store zurückgegebene Seitenmetadaten-Instanz; sie erfindet keine parallele Seiten-ID.

## Seiten und Performance

Der Store lädt derzeit die kompakten Drawing-Daten aller Seiten. Der fortlaufende Editor materialisiert und deserialisiert dagegen nur sichtbare, vorgeladene und aktive Seitenansichten. Bei Speicherdruck schrumpft er auf sichtbare plus aktive Ansichten. Automatische 100-/500-Seiten-Fälle begrenzen die gleichzeitig vorhandenen `PKCanvasView`-Instanzen auf weniger als zehn. `os_signpost`-Ereignisse melden Instruments ausschließlich Gesamt- und Viewzahlen, niemals Inhalte oder Pfade. Sichtbare Bibliothekseinträge erhalten gerenderte Vorschauen, die im lokalen Cache persistiert werden. Der Cache-Key enthält Pfad und Manifest-Änderungsdatum, sodass gespeicherte Zeichnungen die Vorschau invalidieren.

Ein späterer `NotebookIndex` kann bei durch reale Instruments-Messungen belegtem Bedarf zusätzlich zunächst nur Metadaten laden und Drawing-Daten seitenweise nachfordern. Das Package-Format muss dafür nicht geändert werden. Die isolierten Performance-Fixtures und Abnahmebudgets stehen in [docs/RELEASE_ACCEPTANCE.md](docs/RELEASE_ACCEPTANCE.md).

## Infinite Canvas

Infinite Canvas ist ein eigener Package-Typ `.birdcanvas`, nicht eine Sonderseite im Notizbuch. Die aktuelle Version besitzt:

- eigenes Manifest mit `schemaVersion`, Dokument-ID und Arbeitsflächengröße
- eine große virtuelle PencilKit-Arbeitsfläche mit Zoom, Pan, gespeichertem Viewport, „Alles anzeigen“ und Autosave
- denselben sicheren Root, dieselben Dateioperationen und dieselbe Fehlerstrategie
- eine bewusst immer weiße, dezent gepunktete Arbeitsfläche unabhängig vom System-Dark-Mode
- portable Text-, Bild-, Shape- und Connector-Elemente in `elements.json`
- Auswahl, Verschieben, Skalieren, Drehen sowie Zwischenablage- und Löschaktionen
- ein Kachelraster im Manifest als stabile Grundlage für späteres partielles Rendering

Das eigentliche PencilKit-Drawing bleibt derzeit eine zusammenhängende editierbare Datei. Die Kachelmetadaten vermeiden eine weitere Formatmigration, wenn sehr große Zeichnungen später räumlich partitioniert geladen werden. Die Notizbuch-Seitenmodelle bleiben frei von Canvas-Koordinaten und Shapes.

## PDF-Handschrift

`PDFPageOverlayViewProvider` legt über jede sichtbare PDF-Seite einen transparenten `PKCanvasView`. Die PDF-Seitenansicht wird für Eingaben freigeschaltet; im Zeichenmodus benötigt die PDF-Navigation zwei Finger, damit Apple-Pencil-Striche zuverlässig die darüberliegende PencilKit-Ebene erreichen. Die editierbaren `PKDrawing`-Daten werden seitenweise in einem versteckten Ordner neben der PDF gespeichert. Die PDF selbst wird dabei nicht verändert. Dadurch bleibt sie mit Finder, Dateien-App und anderen PDF-Programmen kompatibel, während BirdNotes die Handschrift verlustfrei wiederherstellen kann.

Beim Export rendert BirdNotes Originalseite und PencilKit-Ebene in eine neue abgeflachte PDF. Notizbücher werden seitenweise mit echten A4- beziehungsweise A3-PDF-Abmessungen exportiert; einzelne Seiten stehen zusätzlich als PNG bereit.

## Handschrift zu Druckschrift

Die App rendert nur die ausgewählte PencilKit-Seite auf weißem Hintergrund und übergibt das Bild an Apples lokale Vision-Texterkennung. Bevorzugt werden Deutsch und Englisch; Ergebnisse werden in Leserichtung sortiert. Die erkannte Druckschrift ist ein getrenntes, editierbares Metadatenfeld. Erkennung und manuelle Bearbeitung verändern die originale Zeichnung nicht. Der Store begrenzt und validiert den Text, und die Library-Suche liefert die passende Notizbuchseite direkt zurück. Es werden dafür keine Notizinhalte an BirdNotes-Server übertragen.

## Funktionszugriff

BirdNotes 3.1 besitzt keine Kauf-, Abonnement-, Konto- oder Freischaltschicht. App-Start, Handschrifterkennung, Studienwerkzeuge, Dokumentzugriff, Backup und Export verwenden in Debug und Release denselben uneingeschränkten lokalen Ablauf. Damit existieren weder ein externer Produktkatalog noch ein Berechtigungsstatus, der den Zugriff auf eigene Dokumente beeinflussen könnte.

## Externe Änderungen

Ein `NSFilePresenter` beobachtet den gewählten Root und löst nach gebündelten Änderungen aus Finder, iCloud Drive oder einem anderen File Provider einen Bibliotheks-Reload aus. Die Library-Quelle bleibt das Dateisystem. Favoriten und zuletzt geöffnete Pfade liegen als verstecktes, synchronisierbares JSON im Root. Vorschaubilder sind bewusst nur lokaler Cache.

## Backup

Der Backup-Export erzeugt actor-isoliert zuerst ein vollständiges `.birdbackup`-Snapshot-Package in einem temporären Verzeichnis. Es enthält aktive Bibliotheksinhalte, PDF-Begleitdateien und den bereinigten Bibliotheksstatus, aber bewusst keinen Papierkorb. Die rekursive Kopie folgt keinen symbolischen Links. Erst nach vollständiger Erstellung wird das Package über `NSFileCoordinator` mit `.forUploading` systemseitig als ZIP bereitgestellt. Dadurch werden große Zeichnungen und PDFs nicht vollständig in den Arbeitsspeicher geladen. Das ZIP enthält zusätzlich ein versioniertes Manifest und eine Wiederherstellungsanleitung.

Der Import akzeptiert ein direktes `.birdbackup` oder genau ein solches Package in einem ZIP. Der ZIP-Parser lehnt Traversal, Symlinks, Verschlüsselung, unbekannte Kompressionsverfahren, ZIP64/Multi-Disk, doppelte Unicode-/Großkleinpfade, unplausible Kompressionsraten sowie Größen- und Anzahlüberschreitungen ab. CRC32 wird für jeden Eintrag geprüft. Anschließend validiert der Core Manifest, Paketstruktur und alle Dokumente, bevor eine Vorschau erscheint. Die Wiederherstellung verwendet einen separaten Eingang, Rollback-Kopien und ein persistentes Transaktionsjournal; Konflikte können übersprungen, ersetzt oder als Kopie erhalten werden.

## Verifikationsstand

Der native Geräte- und Simulator-Build wurde mit Xcode 26.6 und dem iOS-26.5-SDK erfolgreich erstellt. 57 Core-, 37 Technik-/Studien- sowie 21 app-nahe Fälle und der isolierte UI-Smoke-Ablauf bilden das automatische Gate. Der ordnerbasierte Arbeitsbereich, die dauerhaft hellen A4-/Canvas-Schreibflächen sowie Pencil-only-PDF-Navigation und PDF-Autosave wurden im iPad-Simulator geprüft. Offen und nicht als bestanden behauptet bleiben die echten Apple-Pencil-, Instruments-, VoiceOver- und iCloud-Mehrgeräteläufe nach [docs/RELEASE_ACCEPTANCE.md](docs/RELEASE_ACCEPTANCE.md).
