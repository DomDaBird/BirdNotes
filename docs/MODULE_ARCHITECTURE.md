# BirdNotes – Architektur für Technik- und IT-Module

Status: v3-Grundarchitektur implementiert, Fachausbau läuft
Stand: 29. August 2026

BirdNotes soll von einer Notiz-App zu einem lokalen technischen Lern- und Arbeitsbuch wachsen. Dazu reichen zusätzliche Canvas-Symbole nicht aus. Ein Schaltplan muss elektrische Netze verstehen, eine Mechanikzeichnung Kräfte und Einheiten, eine technische Zeichnung Constraints und Maße und ein IT-Diagramm typisierte Beziehungen. Dieses Dokument definiert die gemeinsame Plattform, bevor einzelne Fachmodule gebaut werden.

## 1. Ziel und klare Grenze

Die Plattform soll:

- Handschrift, semantische Diagramme und nachvollziehbare Berechnungen auf einer Arbeitsfläche verbinden,
- offline und ohne BirdNotes-Backend arbeiten,
- auf dem iPad mit Pencil, Touch, Tastatur und VoiceOver bedienbar sein,
- Fachmodule mit gemeinsamen Werkzeugen, Einheiten, Export und Validierung versorgen,
- Dokumente stabil, portabel, versioniert und testbar speichern,
- spätere neue Module ohne Umbau des gesamten Editors ermöglichen.

Die erste Ausbaustufe ist ein **Lern-, Dokumentations- und Entwurfswerkzeug**. Sie ist kein zertifiziertes Elektroplanungs-, Statik-, CAD-, Simulations- oder Sicherheitsnachweissystem. Ergebnisse müssen ihren Gültigkeitsbereich, Einheiten, Annahmen und Warnungen zeigen. Konformitäts- oder Sicherheitsbehauptungen sind erst nach gesonderter fachlicher, rechtlicher und normativer Prüfung erlaubt.

## 2. Architekturentscheidung

Technische Dokumente erhalten den neuen Pakettyp `.birdtech`. Die bestehende `.birdcanvas`-Struktur bleibt für freie Mindmaps und Skizzen bestehen.

Warum ein eigener Typ:

- Canvas-Elemente besitzen heute Geometrie, aber keine fachlichen Ports, Netze, Constraints oder Größen.
- Schaltpläne und Mechanikmodelle müssen Beziehungen unabhängig von Pixelpositionen speichern.
- Berechnungen brauchen stabile Variablen-IDs und dürfen nicht von sichtbarem Text abhängen.
- Fachliche Validatoren benötigen eine eindeutig versionierte Modellstruktur.
- Die Trennung verhindert eine riskante Migration aller bestehenden Canvases.

Ein `.birdtech`-Dokument darf weiterhin eine freie PencilKit-Ebene besitzen. Handschrift ist dann Annotation, nicht die Quelle der technischen Semantik.

## 3. Implementierter Modul- und Target-Baum

```text
BirdNotesTechnicalCore/                  # neues Swift Package, ohne UIKit
├── Package.swift
├── Sources/BirdNotesTechnicalCore/
│   ├── Calculation/
│   │   ├── DimensionVector.swift
│   │   ├── Units.swift
│   │   └── Expression.swift
│   ├── Diagram/
│   │   ├── DiagramModels.swift
│   │   └── DiagramValidator.swift
│   ├── Document/
│   │   ├── BirdTechDocument.swift
│   │   └── BirdTechDocumentStore.swift
│   ├── Editing/
│   │   ├── DiagramCommands.swift
│   │   └── SnapEngine.swift
│   ├── Export/SVGDiagramExporter.swift
│   ├── Modules/
│   │   ├── TechnicalModule.swift
│   │   └── BuiltInModules.swift
│   └── Study/
│       ├── StudyCatalog.swift
│       └── StudyTools.swift
└── Tests/BirdNotesTechnicalCoreTests/
    ├── CalculationTests.swift
    ├── DiagramAndStoreTests.swift
    ├── EditingTests.swift
    ├── ModuleAndExportTests.swift
    └── StudyToolkitTests.swift

BirdNotes/Technical/                     # iPad-spezifische Darstellung
└── TechnicalWorkspaceView.swift         # Editor, Palette, Inspektor, Formeln und Export

BirdNotes/Study/
└── StudyToolsView.swift                 # Curriculum, Rechner und Checklisten
```

`BirdNotesTechnicalCore` enthält ausschließlich deterministische Modelle, Parser, Solver, Validierung und Formatlogik. UIKit/SwiftUI, PencilKit und Rendering bleiben im App-Target. Fachmodule liefern Kataloge und Regeln an den Core, aber keine eigenen Dateisystemzugriffe.

## 4. Modulvertrag

Ein Fachmodul implementiert sinngemäß:

```swift
public protocol TechnicalModule: Sendable {
    var identifier: ModuleIdentifier { get }
    var version: SemanticVersion { get }
    var displayMetadata: ModuleDisplayMetadata { get }
    var symbolCatalogs: [SymbolCatalog] { get }
    var toolDescriptors: [ToolDescriptor] { get }
    var calculationDefinitions: [CalculationDefinition] { get }
    var validators: [TechnicalValidator] { get }
    var exporters: [TechnicalExporter] { get }
}
```

Verbindliche Eigenschaften:

- stabile Reverse-DNS-Modul-ID, zum Beispiel `com.birdnotes.module.electrical`,
- semantische Modulversion und minimale Dokumentversion,
- lokalisierbarer Name/Beschreibung ohne Logik in Übersetzungsstrings,
- Symbol- und Werkzeugkataloge mit stabilen IDs,
- deklarative Validierungs- und Berechnungsdefinitionen,
- bekannte Capability-Flags statt Laufzeit-Reflection,
- Testkorpus und Versionshinweise.

### Keine ausführbaren Drittanbieter-Plugins in der ersten Stufe

Module werden mit der App kompiliert. Importierte Dokumente oder Kataloge dürfen weder Swift, JavaScript, Shellcode noch beliebige Expressions ausführen. Das vermeidet Code-Injection, unsichere Plugin-Signaturen, App-Store-Probleme und nicht reproduzierbare Berechnungen.

Spätere herunterladbare Inhalte dürfen nur deklarative, signierte Datenpakete sein. Vor einem solchen System sind Signaturprüfung, Schlüsselrotation, Widerruf, sichere Updatekanäle, SBOM, Rechteprüfung und ein eigenes Bedrohungsmodell erforderlich.

## 5. Gemeinsames Dokumentmodell

### 5.1 Manifest

`TechnicalManifest` enthält mindestens:

- `schemaVersion`
- Dokument-UUID und Dokumenttyp `technical`
- Titel, Erstellungs- und Änderungsdatum
- verwendete Modul-ID und Modulversion
- Dokumentmodus, zum Beispiel `electricalSchematic` oder `freeBodyDiagram`
- Einheitensystem und Gebietsschema
- Blattformat, Ausrichtung und Maßstab
- optionale Vorschaumetadaten
- Hash-/Versionsangaben für verwendete Symbolkataloge

### 5.2 Diagrammgraph

| Typ | Kerndaten |
|---|---|
| `DiagramElement` | UUID, Symboltyp, Transformation, Eigenschaften, Portinstanzen, Ebene, Z-Index |
| `DiagramPort` | UUID, stabile Rollen-ID, Position im Elementsystem, Datentyp/Domäne, Richtung |
| `DiagramConnection` | UUID, Quell-/Zielport oder freies Ende, Wegpunkte, Net-ID, Stil |
| `DiagramLayer` | UUID, Name, Sichtbarkeit, Sperrstatus, Druckbarkeit |
| `DiagramGroup` | Mitglieder, Transformation, optionale fachliche Rolle |
| `DiagramLabel` | Text, Semantik, Bezug zu Element/Netz/Variable, Position |

Der Graph speichert Verbindungen über IDs, nicht über zufällige Berührung zweier Linien. Sichtbare Geometrie kann daraus rekonstruiert und validiert werden.

### 5.3 Eigenschaften

Eigenschaften werden nicht als untypisiertes `[String: Any]` gespeichert. Vorgesehen ist ein codierbarer Werttyp:

- Text, Boolean, Ganzzahl, Dezimalzahl,
- `Quantity` aus Wert, Einheit und Dimension,
- Enumeration mit Katalog-ID,
- Referenz auf Element, Port, Netz, Layer oder Berechnung,
- kleine, begrenzte Listen strukturierter Werte.

Jede Symboldefinition deklariert erlaubte Felder, Pflichtstatus, Defaultwerte, Wertebereiche und Einheiten. Unbekannte Felder bleiben für Migrationen erhalten, werden aber nicht ungeprüft ausgeführt.

### 5.4 Berechnungen

Eine Berechnung besteht aus:

- stabiler Definition und Instanz-ID,
- Eingangsvariablen mit Einheit, Quelle und Gültigkeitsbereich,
- normalisierter, geparster Ausdrucksstruktur,
- Ergebnis mit Einheit, Genauigkeit und Status,
- Annahmen und Warnungen,
- nachvollziehbarem Rechenweg (`CalculationTrace`),
- Engine-/Formelversion.

Berechnungsergebnisse werden als Cache gespeichert, aber beim Öffnen gegen Eingabe- und Engineversion invalidiert. Die Quellen der Wahrheit bleiben Eingaben und Formeldefinition.

## 6. Implementiertes `.birdtech`-Grundformat

```text
Projekt.birdtech/
├── manifest.json
├── diagram.json
├── calculations.json
├── annotations.data
├── preview.png
└── resources/
    └── <UUID>.<erlaubte-endung>
```

| Datei | Inhalt |
|---|---|
| `manifest.json` | Identität, Modul, Version, Blatt/Einheiten und Katalogreferenzen |
| `diagram.json` | Elemente, Ports, Verbindungen, Layer, Constraints und Labels |
| `calculations.json` | Eingaben, Formelinstanzen, Ergebnisse, Warnungen und Trace |
| `annotations.data` | optionale freie PencilKit-Handschrift |
| `preview.png` | regenerierbarer Cache; niemals Quelle der Wahrheit |
| `resources/` | validierte Bilder oder Anhänge mit UUID-Namen |

Vorgesehene erste Schemaversion: `1`. Vor der Implementierung müssen maximale Dateigrößen, Elementzahlen, Verbindungskomplexität, Constraint-Iterationslimits, Parser-Tiefe und Rechenzeitbudgets festgelegt werden.

## 7. Editoraufbau

```text
Navigation/Toolbar
       ↓
TechnicalEditorViewModel
       ↓
Command Dispatcher ─────────────→ Undo/Redo-Verlauf
       ↓
Diagram Engine ──────→ Snap/Constraint Solver
       │                       │
       ├──────────────→ Validatoren
       ├──────────────→ Calculation Engine
       └──────────────→ Vector Renderer
                                ↓
                    Canvas + Inspector + Ergebnisfeld
```

Alle Änderungen laufen als typisierte Commands, beispielsweise `InsertElement`, `ConnectPorts`, `SetProperty`, `ApplyConstraint` oder `UpdateCalculationInput`. Ein Command kennt Vorher-/Nachherzustand und ist rückgängig machbar. Direktes Mutieren verschachtelter UI-Bindings ist nicht erlaubt.

### Gemeinsame Werkzeuge

- Auswahl, Mehrfachauswahl, Lasso und Gruppierung
- Verschieben, Drehen, Spiegeln, Skalieren je nach Fachregel
- Raster-, Objekt-, Mittelpunkt-, Endpunkt-, Tangenten- und Winkel-Snapping
- orthogonale sowie freie Verbindungen
- Ebenen, Sperren, Sichtbarkeit und Druckbarkeit
- Eigenschafteninspektor mit Einheiten und Validierung
- Suche nach Referenzkennzeichen, Label, Netz, Variable oder Symbol
- freie Handschrift als getrennte Annotationsebene
- Kommentare/Callouts ohne Einfluss auf Berechnung
- PDF-, SVG- und PNG-Export über eine gemeinsame Vektorszenen-Zwischenform

## 8. Mathematik- und Einheitenschicht

Alle Fachmodule verwenden dieselbe [Mathematikgrundlage](modules/MATHEMATICS_FOUNDATION.md):

- SI-Basisdimensionen und abgeleitete Größen,
- Präfixe und sichere Konvertierung,
- dimensionsgeprüfte Arithmetik,
- Vektoren, Matrizen und komplexe Zahlen,
- deterministischer Ausdrucksparser ohne allgemeine Codeausführung,
- kontrollierte numerische Verfahren mit Iterations-/Zeitlimits,
- reproduzierbare Rundung und sichtbare Genauigkeit,
- deutsche und englische Zahleneingabe bei kanonischer interner Repräsentation.

Eine Addition inkompatibler Dimensionen muss fehlschlagen. Temperaturdifferenz und absolute Temperatur, Winkel, logarithmische Einheiten sowie affine Umrechnungen benötigen explizite Typen; sie dürfen nicht wie gewöhnliche Skalare behandelt werden.

## 9. Standards und Nutzungsrechte

BirdNotes wird „standards-aware“, nicht automatisch „normkonform“. Normen können kostenpflichtig, urheberrechtlich geschützt und versionsabhängig sein.

| Bereich | Referenz für die Planung | Konsequenz |
|---|---|---|
| Elektrotechnische Symbole | IEC 60617 Database | offizielle Symbolgrafiken/-daten nur mit geklärter Lizenz; zunächst eigener klar als Lernkatalog bezeichneter Satz |
| Elektrotechnische Dokumente | IEC 61082-1 | Layout-/Dokumentationsregeln fachlich prüfen, Version je Release festhalten |
| Technische Darstellung | ISO 128-1 | allgemeine Darstellungsregeln als Anforderungsquelle, keine Konformitätsbehauptung ohne Prüfung |
| Maße/Toleranzen | ISO 129-1 | Bemaßung und Toleranzen versioniert abgleichen |
| Blattformate | ISO 5457 | Papierlayout und Zeichnungsrahmen; Status vor Umsetzung erneut prüfen |
| Schriftfeld | ISO 7200 | Metadatenfelder für Zeichnungskopf berücksichtigen |
| Einheiten | BIPM SI Brochure | kanonische Grundlage der Einheitenschicht |
| Softwarediagramme | OMG UML 2.5.1 | klar ausgewiesene UML-Teilmenge statt behaupteter Vollimplementierung |

Vor Aufnahme eines standardbezogenen Symbol- oder Vorlagenpakets sind Versionsregister, Lizenzbeleg, fachliche Freigabe und Regressionstest erforderlich. Die UI muss zwischen „BirdNotes-Lernsymbol“, „an Norm angelehnt“ und „verifizierter Normkatalog“ unterscheiden können.

## 10. Security-by-Design

### Eingaben

- keine dynamische Codeausführung,
- Parser mit Token-, Tiefe-, Länge-, Zeit- und Iterationslimits,
- endliche Zahlen und festgelegte Wertebereiche,
- UUID-basierte Ressourcenpfade ohne freie Unterpfade,
- MIME-/Magic-Byte-/Pixelprüfung für Bilder,
- keine externen URLs oder automatischen Netzwerkabrufe im Dokument,
- keine Entitäten, Makros oder eingebetteten Skripte in SVG-Importen.

### Integrität

- actor-isolierte, koordinierte, atomare Speicherung,
- Dokumentvalidierung vor und nach Migration,
- referenzielle Integrität für Port-, Netz-, Constraint- und Variablen-IDs,
- unbekannte Modul-/Katalogversionen im sicheren Nur-Lesen-Modus,
- keine stillen Ergebnisübernahmen nach Formel-/Engineänderung,
- Export rendert über eigene sichere Primitive, nicht über ungeprüftes HTML/WebView.

### Datenschutz

- lokale Berechnung und lokale Kataloge,
- keine Übertragung technischer Pläne oder Notizen,
- keine inhaltsbezogene Telemetrie,
- Vorschaubilder werden als vertrauliche Dokumentdaten behandelt,
- temporäre Exporte werden nach Abschluss entfernt und unterliegen Dateischutz.

### Technische Sicherheit

- jede Berechnung zeigt Einheit, Annahmen und Status,
- kritische Warnungen können nicht allein durch Farbe vermittelt werden,
- Ergebnisse werden nie als Elektro-, Bau-, Maschinen- oder Arbeitssicherheitsfreigabe bezeichnet,
- gefährliche Auslegungen wie Netzspannungsinstallation, Schutzorgandimensionierung oder Tragfähigkeitsnachweise bleiben zunächst außerhalb des Scopes.

## 11. Teststrategie der Modulplattform

| Ebene | Pflichtprüfungen |
|---|---|
| Modell | Codable-Roundtrip, Gleichheit, stabile IDs, Defaultwerte, unbekannte Felder/Versionen |
| Property-basiert | Einheitenkonvertierung, Transformationen, Undo/Redo-Inversen, Graphintegrität |
| Golden Files | je veröffentlichte Schemaversion und Symbolkatalogversion |
| Parser/Fuzzing | ungültige Tokens, extreme Tiefe/Länge, Unicode, nicht-finite und adversariale Eingaben |
| Fachreferenz | handgerechnete und unabhängig geprüfte Beispiele mit Toleranz |
| Renderer | deterministische Vektorszenen sowie Snapshot-/Pixel-Diff mit tolerierten Abweichungen |
| Integration | Erstellen, Verbinden, Berechnen, Speichern, Neuöffnen, Exportieren, Backup/Restore |
| Performance | große Graphen, viele Constraints, große Kataloge, Speicher- und Rechenzeitbudget |
| Accessibility | VoiceOver-Reihenfolge, Tastatur, Dynamic Type, Kontrast, nichtfarbliche Zustände |
| Security | Traversal, ZIP-Bomben, Referenzzyklen, Parser-DoS, Ressourcenbomben und beschädigte Pakete |

Für jede Formel werden mindestens geprüft: Normalfall, Grenzwert, dimensionsfalsche Eingabe, fehlende Eingabe, Null-/Singularitätsfall, Überlauf, Rundung und ein fachlich unabhängiger Referenzwert.

## 12. Lieferreihenfolge

1. Mathematik-, Einheiten- und Diagramm-Core ohne UI
2. `.birdtech`-Format, Validierung, Migration und Backup
3. generischer Editor mit Commands, Undo/Redo, Snap, Inspector und Export
4. Elektrotechnik-MVP mit Gleichstromnetzwerken
5. technisches 2D-Zeichnen mit Bemaßung und Constraints
6. Physik/Technische Mechanik mit Freikörperbildern und Statik
7. IT-/Informatikdiagramme und Rechner
8. gemeinsame Vorlagen, Suche, Querverlinkung und didaktische Erklärungen

Jeder Schritt besitzt ein eigenes Feature-Flag und darf erst nach Format-, Security-, Migrations- und Fachtests als produktiv markiert werden.

## 13. Entscheidungen vor Implementierungsbeginn

| Entscheidung | Empfohlener Startwert |
|---|---|
| Produktumfang | Lern- und Dokumentationsmodus, keine zertifizierte Auslegung |
| Persistenz | eigener Typ `.birdtech` |
| Erweiterung | statisch kompilierte Module, keine ausführbaren Plugins |
| Rendering | eigene Vektorprimitive, freie Handschrift separat |
| Berechnung | typisierter Parser, keine Skriptsprache |
| Einheiten | SI intern, Anzeige konvertierbar |
| erster Fachbereich | Gleichstrom-Elektrotechnik plus allgemeine Diagrammwerkzeuge |
| Export | PDF/SVG/PNG zuerst; Austauschformate erst nach Validatoren |
| Standardsymbole | nur mit geklärter Lizenz; sonst eigener Lernkatalog |
| Nutzung | lokale App; alle statisch kompilierten Module ohne Kauf- oder Freischaltlogik |

Diese Entscheidungen verhindern, dass frühe UI-Arbeit ein ungeeignetes Datenmodell festschreibt. Abweichungen werden als Architecture Decision Record mit Nutzen, Risiko, Migration und Testauswirkung dokumentiert.
