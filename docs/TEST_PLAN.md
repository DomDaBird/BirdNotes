# Test- und Abnahmeplan

Stand: 29. August 2026

Automatisierte Tests reduzieren Risiken, beweisen aber nicht allein, dass Pencil, iCloud und Bedienung auf echten Geräten funktionieren. Eine verlässliche Version benötigt deshalb alle Ebenen dieses Plans: statische Checks, Unit-/Integrations-/Regressionstests, Build/Analyse, manuelle Gerätetests sowie dokumentierte fachliche Prüfungen für spätere Technikmodule.

## 1. Standardisierte automatische Prüfstufen

| Stufe | Befehl | Inhalt | Pflichtzeitpunkt |
|---|---|---|---|
| Dokumentation | `./scripts/check-docs.sh` | lokale Markdown-Datei- und Verzeichnislinks | jede Doku-/Strukturänderung |
| Projekt | `./scripts/check-project.sh` | Plists, Privacy-Manifeste, Projektdatei, private Laufzeitkonfiguration, Shell-Syntax und Dokumentationslinks | jede Konfigurationsänderung |
| Security | `./scripts/check-security.sh` | einfache Secret-Suche, erzwungene Produktionsabbrüche und versionierte Symlinks | jeder Commit |
| Core | `./scripts/test.sh core` | Tests für `BirdNotesCore` und `BirdNotesTechnicalCore` mit getrennten Caches und Coverage | während Entwicklung und CI |
| App | `./scripts/test.sh app` | App-Test-Target im verfügbaren iPad-/iOS-Simulator | vor Review/Merge |
| UI | `./scripts/test.sh ui` | isolierter XCUITest-Smoke-Test im verfügbaren iPad-/iOS-Simulator | nach kritischen UI-/Persistenzänderungen |
| Address Sanitizer | `./scripts/test.sh asan` | App- und eingebettete Core-Tests mit Speicherzugriffsprüfung | vor Release Candidate sowie nach Low-Level-/Importänderungen |
| Thread Sanitizer | `./scripts/test.sh tsan` | App- und eingebettete Core-Tests mit Datenrennenprüfung | vor Release Candidate sowie nach Concurrency-/Lifecycleänderungen |
| Beide Sanitizer | `./scripts/test.sh sanitizers` | getrennte Address- und Thread-Sanitizer-Läufe | Release Candidate |
| Alle Tests | `./scripts/test.sh all` | Core, App und UI | vor Review/Merge |
| Release-Gate | `./scripts/verify.sh` | Projekt, Security, alle Tests, generischer iOS-Build und Xcode Analyze | vor Push, Tag und Release |

GitHub Actions führt das Release-Gate auf Pull Requests und Pushes zu `main` mit Xcode 26.6 aus. Lokal und CI verwenden denselben Einstieg; ein ausschließlich in Xcode manuell bestandener Lauf ersetzt das Gate nicht.

## 2. Bestehende automatische Abdeckung

### Core-Tests

Die aktuell 57 Swift-Testing-Fälle des klassischen Core decken unter anderem ab:

- Ordner-, Notizbuch-, Canvas- und PDF-Lebenszyklen,
- Seitenanlage, -reihenfolge, -duplizierung, A4/A3, Hoch-/Querformat und automatische Folgeseite,
- atomare Persistenz über neue Store-Instanzen,
- Tags, Favoriten, Verlauf, Suche und Druckschrift,
- Papierkorb, gezielte Wiederherstellung und Namenskonflikte,
- Backup, Restore, Konfliktstrategien und Transaktionsrollback,
- vorwärts reparierbare Notizbuch-/Canvas-Saves, idempotente Löschung, Prüfsummen und Journal-Traversalabwehr,
- Pfadtraversal, Symlinks, ungültige Namen und Paketinnere,
- PDF-Header/-Größe, Schemaversionen, Manifestkonsistenz und nicht-finite Canvaswerte,
- Canvasobjekte, Viewport, Kachelung und Rückwärtsmigration,
- dauerhafte Notizbuch-/Canvas-Golden-Files für Schema v1/v2 und Save-after-load-Migration,
- PDF-Annotationen bei Umbenennen, Verschieben, Löschen und Restore,
- Ablehnung eines manipulierten symbolischen PDF-Begleitordners,
- Integrität, Reihenfolge und gemischte Metadaten eines Notizbuchs mit 100 Seiten über einen erneuten Store-Start,
- vollständiges Aufzählen von 1.000 Bibliothekseinträgen und Persistenz von 2.000 Canvasobjekten über eine neue Store-Instanz.
- atomare Erzeugung der vollständigen Studiengangsstruktur mit Modulen, Cornell-Lernnotizen und Active-Recall-Notizbüchern,
- `.birdtech` durch Auflistung, Umbenennen, unabhängige Kopie, Papierkorb, Wiederherstellung und validiertes Backup.

Weitere 37 Tests in `BirdNotesTechnicalCore` prüfen SI- und Temperatureinheiten, Dimensionsfehler, Parsergrenzen, Rechentraces, Diagrammreferenzen, Größenlimits, Undo/Redo-Inversen, Raster-/Winkelfang, atomare benannte Packages, SHA-256-Manipulation, Symlinks, ein dauerhaftes v1-Golden-File, sechs kompilierte Modulkataloge, Studienkataloge, CP-Planung, Wiederholungsplan, JSON, Requirements, Zahlensysteme, Komplexität, Statistik, IPv4/CIDR und SVG-Injection.

### App-nahe Tests

Die aktuell 21 App-Fälle prüfen:

- ein echtes, systemseitig erzeugtes ZIP-Backup vom Export bis zur Restore-Vorschau,
- zentrierten vertikalen A4-/A3-Seitenfluss,
- sicheren Leerzustand des fortlaufenden Layouts,
- symmetrische Nutzung der verfügbaren Editorbreite,
- ein- und ausschaltbare Zoom-Anpassung des Notizbuchs bei Gerätedrehung,
- korrekte vertauschte A4-Abmessungen im Hoch-/Querformat,
- dass ein 100-seitiges Notizbuch weniger als zehn sichtbare beziehungsweise vorgeladene PencilKit-Seitenansichten gleichzeitig materialisiert und ein Sprung zur letzten Seite den alten Bereich freigibt,
- dass auch ein 500-seitiges Notizbuch beim Sprung über Mitte und Ende weniger als zehn PencilKit-Seitenansichten materialisiert,
- dass unmittelbar aktualisierte Zeichnungsdaten beim Freigeben und erneuten Materialisieren einer Seitenansicht erhalten bleiben,
- dass Speicherdruck den Vorladepuffer freigibt, ohne die aktive Seite zu verwerfen,
- dass Fingerzeichnen, Ein-Finger-Scrollen und das Handwerkzeug ihre PencilKit-/Gestenregeln korrekt umschalten,
- Pencil-only als persistente sichere Standardeinstellung und Ein-Finger-Navigation im PDF-Editor,
- verzögertes PDF-Autosave sowie vollständigen Lifecycle-Flush mehrerer geänderter Seiten,
- dass materialisierte Seiten VoiceOver-Aktionen für vorherige und nächste Seite bereitstellen,
- dass Handschrifterkennung und alle Studienfunktionen ohne Kauf- oder Freischaltzustand verfügbar sind,
- reversible Breitenanpassung des Infinite Canvas beim Hin- und Zurückdrehen,
- unveränderten Canvas-Zoom bei abgeschalteter Automatik,
- typisierte, begrenzte und ausschließlich isolierte Performance-Startargumente,
- viewportbasierte Materialisierung von weniger als 100 Views bei 2.000 verteilten Canvasobjekten,
- einmalige Connector-Auflösung, Connector-Culling und sichere leere Projektion bei ungültiger Viewportgröße.

Das Xcode-Test-Target kompiliert die Core-Testquellen zusätzlich im App-Kontext. Dadurch werden Swift-/Foundation-Unterschiede zwischen Package- und iOS-Build sichtbar; der Swift-Package-Lauf bleibt trotzdem der schnelle, isolierte Core-Nachweis.

### UI-Smoke-Test

Der XCUITest erstellt eine ausschließlich für Tests bestimmte Bibliothek und beschreibt zwei fortlaufende A4-Seiten getrennt. Er prüft die Seitenauswahl, exakte Strichzahlen je Seite, die automatisch erzeugte Folgeseite, den Autosave bei einem echten Hintergrund-/Vordergrundwechsel, das persistente Querformat und anschließend alle Inhalte nach einem vollständigen App-Neustart. Der Startparameter `--birdnotes-ui-testing` umgeht echte Ordnerfreigaben und das Cloud-Onboarding; `--birdnotes-ui-reset` darf ausschließlich den App-Sandbox-Unterordner `BirdNotesUITests` leeren. Echte Nutzernotizen werden weder geöffnet noch verändert.

## 3. Testklassifikation und Konventionen

| Klasse | Definition | Ort |
|---|---|---|
| Unit | eine reine Regel oder ein kleiner Typ ohne echtes UI/Dateisystem | `BirdNotesCoreTests` |
| Integration | mehrere Core-Komponenten mit temporärem echten Dateisystem | `BirdNotesCoreTests` |
| App-Integration | App-Framework, UIKit/PDFKit oder Systemarchive | `BirdNotesTests` |
| UI-Smoke | Nutzerablauf über XCUITest | `BirdNotesUITests` |
| Migration/Golden File | dauerhaftes Fixture je veröffentlichter Schemaversion | Core-/Technical-Core-Tests |
| Fachreferenz | unabhängig berechneter Wert/Plan gegen Engineergebnis | jeweiliges Technikmodul |
| Performance/Soak | Zeit, Speicher, Energie oder Wiederholungsstabilität | Instruments/XCTest-Messung plus Gerätelauf |
| Security/Fuzz | manipulierte Eingabe, Komplexitätslimit und Parserrobustheit | Core-/Technical-Core-Tests |

Regeln für jeden neuen Test:

- Der Name beschreibt Verhalten und erwartetes Ergebnis, nicht Implementierungsdetails.
- Ein Test besitzt isolierte, künstliche Daten und räumt temporäre Dateien auf.
- Netzwerk, echtes iCloud Drive, Uhrzeit und zufällige Reihenfolge werden nicht unkontrolliert vorausgesetzt.
- Race-, Timing- und Autosave-Tests warten auf beobachtbare Zustände statt pauschaler Sleeps.
- Dateisystem-/`NSFileCoordinator`-Integrationstests laufen innerhalb einer serialisierten Suite; reine Regeln und Renderer dürfen parallel bleiben.
- Ein Bugfix erhält zuerst oder gleichzeitig einen reproduzierenden Regressionstest.
- Tests dürfen keine echten Nutzerdaten, Zertifikate oder Accounts verwenden.
- Toleranzen numerischer Tests sind fachlich begründet und nicht so groß gewählt, dass Fehler verborgen werden.
- Ein übersprungener/flaky Test ist ein sichtbarer Befund mit Verantwortlichem und Termin, kein dauerhaft akzeptierter grüner Zustand.

## 4. Qualitätsgate je Änderungstyp

| Änderung | Mindestens erforderlich |
|---|---|
| Dokumentation ohne ausführbaren Inhalt | Links/Struktur prüfen, `check-project.sh` falls Skripte erwähnt/geändert |
| Core-Modell oder Storage | Core-Tests, Security-Check, Migration/Negativfall, vollständiges Gate vor Merge |
| SwiftUI/UIKit/PencilKit/PDFKit | App-Tests, Build, Analyze und betroffener manueller Simulatorablauf |
| Dateiformat/Schema | Golden File alt/neu, zukünftige Version, beschädigte Datei, Migration, Save-after-load, Backup/Restore |
| Import/Archiv/Bild | Magic Bytes, Größe, Anzahl, Tiefe, Traversal, Symlink, Dekompressions-/Pixelbomben und Fuzz-Korpus |
| Gerätesignierung | echter Kabelstart, Start ohne Debugverbindung, Ablauf-/Neuinstallationsablauf |
| Security-/Privacy-relevant | Bedrohungsmodell, Privacy-Manifest, Negativtests und unabhängiger Review |
| Fachberechnung | Dimensionsfehler, Normal-/Grenz-/Singularitätsfall, unabhängige Referenz und Fachreview |
| Symbol-/Normkatalog | ID-/Portvalidierung, Rendering, Lizenz-/Versionsnachweis und Fachreview |

## 5. Automatisierungs-Backlog vor dem iPad-Release

Diese Punkte sind noch nicht vollständig automatisiert und bleiben Releasearbeit:

1. reproduzierbares Import-Negativkorpus ohne urheberrechtlich/problematische Echtdaten,
2. die standardisierten Address-/Thread-Sanitizer-Läufe je Releasecommit ausführen und deren `.xcresult` archivieren; gegebenenfalls Undefined-Behavior-Sanitizer ergänzen,
3. messbare Coverage-Baseline und ratcheting Mindestwert statt einer willkürlichen Prozentzahl,
4. gespeicherte `.xcresult`-/Coverage-Nachweise pro Releasecommit,
5. Performance-/Memory-Metriken auf mindestens dem ältesten unterstützten iPad.

## 6. Tests der Technikplattform

Automatisch umgesetzt sind:

- Unit-Tests für Einheiten, Temperaturen, Dimensionsrechnung und Undo/Redo-Inversen,
- Parsergrenzen für Länge, Tiefe, Token, Operationen, Variablen und ganzzahlige Exponenten,
- referenzielle Integrität für Elemente, Ports, Verbindungen, Ebenen und Constraints,
- deterministischer SVG-Export mit Maskierung aktiver Textfragmente,
- Paketgrößen, Prüfsummen, atomare Speicherung und Symlink-Abwehr,
- ein Referenzfall für Ohmsches Gesetz und Dimensionsprüfung der Formelvorlagen,
- eindeutige Abdeckung aller 20 Pflichtmodule der Semester 1 bis 4 und Zuordnung aller Studienwerkzeugtypen,
- Normal-, Grenz-, Fehler- und Ressourcenlimitfälle für CP-Planung, Statistik, Zahlensysteme, Algorithmusprojektionen, IPv4/CIDR und Requirements-Review,
- Validierung der Softwareentwicklungs-Symbole für Requirements, UML, ER, CI/CD, Tests und Trust Boundaries,
- Garantie durch Architektur und Testkorpus, dass Dokumente weder Skripte noch Netzwerkaktionen auslösen.

Noch offen bleiben Golden-File-Migrationen über eine zukünftige zweite `.birdtech`-Schemaversion, echtes Parser-Fuzzing, Solver-Tests nach Einführung des Constraint-Solvers, große Graph-/Katalog-Performancefälle und unabhängig fachgeprüfte Referenzkorpora je Modul.

Die detaillierten Anforderungen stehen in [MODULE_ARCHITECTURE.md](MODULE_ARCHITECTURE.md) und den [Fachmodulplänen](modules/README.md).

## 7. Kritischer manueller Ablauf auf echtem iPad

1. App frisch installieren, lokalen Speicher öffnen, über „Neu“ einen Studienbereich erstellen und dessen vier Ordner sowie die beschreibbare A4-Cornell-Semesterübersicht prüfen; zusätzlich ein Endlos-Canvas erstellen.
2. Mit Apple Pencil sowie optional Finger zeichnen; Werkzeugwechsel, Undo/Redo, Hintergrundwechsel und automatische Folgeseite prüfen. Zusätzlich ein Notizbuch mit mindestens 100 Seiten zügig durchscrollen und mehrfach zwischen erster und letzter Seite springen.
3. App während einer Änderung in den Hintergrund schicken, beenden und Dokument erneut öffnen. Der letzte bestätigte Inhalt muss vorhanden sein.
4. A3 und A4 jeweils im Hoch- und Querformat prüfen. Das iPad bei aktiver und inaktiver automatischer Anpassung drehen; Seiteninhalt, Mittelpunkt und Zoom müssen dem gewählten Modus folgen. Canvas bleibt auch bei System-Dark-Mode weiß.
5. Gültige PDF importieren, mehrere Seiten annotieren, schließen, erneut öffnen, umbenennen, verschieben und als annotierte PDF exportieren.
6. Bild mit hoher Auflösung in Canvas importieren; Bedienung und Speicherverbrauch bleiben stabil.
7. iCloud-Ordner „BirdNotes“ wählen, Inhalte in Dateien/Finder umbenennen oder verschieben und die App erneut aktivieren.
8. Dasselbe iCloud-Dokument auf einem zweiten Gerät ändern. Ein ungelöster Konflikt darf nicht still überschrieben werden.
9. Zwei Dokumente löschen, im Papierkorb eines gezielt wiederherstellen, das andere endgültig löschen und einen Namenskonflikt bei der Wiederherstellung prüfen.
10. Gerät sperren/entsperren, neu starten, offline verwenden und nach Rückkehr des Netzes erneut synchronisieren.
11. Tags für Semester und Fach vergeben, über die Sidebar filtern, danach Dokument und übergeordneten Ordner verschieben sowie löschen/wiederherstellen.
12. „Bibliothek sichern“ ausführen, ZIP in Dateien speichern, öffnen und Notizbuch, PDF-Handschrift, Canvas sowie Organisationsdaten stichprobenartig prüfen.
13. Dasselbe ZIP über „Backup wiederherstellen“ importieren, Vorschau und alle drei Konfliktstrategien prüfen; App während eines Restore-Versuchs beenden und kontrollieren, dass der nächste Start sauber zurückrollt.
14. Mehrere deutsch-/englischsprachige Handschriften in Druckschrift umwandeln, Text korrigieren, über die Library suchen und direkt die Fundseite öffnen. Originalzeichnung und editierter Text müssen nach Neustart erhalten sein.
15. Technik-Dokumente aller sechs Kataloggruppen erstellen, Symbole verschieben/drehen/verbinden, Formelvorlage rechnen, SVG exportieren und nach App-Neustart sowie Umbenennen erneut öffnen.
16. In der Sidebar „Studien-Werkzeuge“ öffnen, alle Pflichtsemester und mehrere Wahlbereiche prüfen; CP-Planer, Requirements-Check, Zahlensysteme, Komplexität, Statistik und IPv4/CIDR jeweils mit gültigen und ungültigen Eingaben testen.
17. Wissenschafts- und Qualitätscheckliste mit VoiceOver und Dynamic Type bedienen; anschließend UML-, ER-, CI/CD-, Test- und Trust-Boundary-Symbole in einem Technikdokument einfügen und beschriften.
18. Cloud-Onboarding, Auswahl von `Documents/Birdnotes`, Bookmark-Wiederöffnung und Recovery nach entzogenem Ordnerzugriff auf dem echten iPad prüfen.

## 8. Negativ- und Edge-Case-Matrix

- Leere, beschädigte, passwortgeschützte und sehr große PDFs
- Bilddatei mit falscher Endung, 50-MB-Grenze, extremen Pixelmaßen und ungültigen Metadaten
- Beschädigtes Manifest, fehlende Drawing-Datei, zukünftige Schemaversion, doppelte IDs und nicht-finite Canvas-Werte
- Sonderzeichen, 200-Zeichen-Grenze, Unicode-Normalformen und Namenskonflikte
- Symlink nach außerhalb, verschachtelte Paketpfade und versteckte Dateien
- Voller Datenträger, schreibgeschützter Ordner, entzogenes Security Scope und abgelaufener Bookmark
- Abgebrochener Backup-Export, sehr große Bibliothek und Symlink innerhalb eines extern bearbeiteten Ordners
- ZIP-Traversal, doppelte Unicode-/Großkleinpfade, falsche CRC, Symlink-Eintrag, Verschlüsselung, ZIP64, sehr hohe Kompressionsrate und zu wenig freier Speicher
- Leere/undeutliche Handschrift, sehr lange Erkennung, Sonderzeichen, mehrfaches Erkennen und manuell auf Größenlimit gebrachter Drucktext
- abgelaufenes Personal-Team-Profil, Neuinstallation und unveränderte Cloud-Dokumente
- 10.000 Canvas-Objekte, viele Seiten, große Zeichnungen und wiederholtes schnelles Speichern
- Wechsel zwischen Hoch-/Querformat, Split View, Stage Manager, externer Tastatur und Pencil-Doppeltipp
- leere, extrem lange, nicht-finite und syntaktisch manipulierte Studienrechner-Eingaben; Statistiklisten über dem Limit; exponentielle Projektionen über 10¹⁸
- IPv4-Präfixe /0, /31 und /32, ungültige Oktette, Überlaufwerte und codeähnliche Zeichenfolgen ohne Netzwerkaktion
- doppelte/ungültige Curriculumcodes und spätere unbekannte Katalogstände
- ungültiges oder übergroßes JSON sowie Wiederholungspläne außerhalb der Sitzungsgrenzen

## 9. Barrierefreiheit

- VoiceOver-Reihenfolge und verständliche Namen für alle Symbolschaltflächen
- Dynamic Type bis zur größten Bedienungshilfengröße ohne abgeschnittene Kernaktionen
- Kontrast, „Bewegung reduzieren“, „Transparenz reduzieren“ und ausreichende Touch-Ziele
- Bedienbarkeit ohne Apple Pencil und ohne Farberkennung

## 10. Leistungsziele vor dem dauerhaften Studieneinsatz

- Kaltstart und Öffnen typischer Dokumente auf dem ältesten unterstützten iPad messen.
- Ein 100- und ein mehrere hundert Seiten großes Notizbuch mit Instruments auf Spitzen-/Dauerspeicher, Hänger und Scroll-Latenz messen; die automatische View-Virtualisierung bleibt dabei aktiv.
- 30-minütiger Pencil-/Autosave-Soak-Test ohne kontinuierliches Speicherwachstum.
- Die isolierten 1.000-Einträge-/2.000-Objekte-Fixtures auf dem Referenzgerät profilieren; Integrität und Canvas-Culling sind bereits automatisch abgedeckt.
- Kein Datenverlust bei 100 wiederholten Hintergrund-/Vordergrundwechseln im Testlauf.

## 11. Freigabekriterien

- Automatisches Gate grün, keine offenen P0/P1-Fehler und dokumentierte Entscheidung für verbleibende P2-Risiken.
- Kritischer Geräteablauf auf mindestens zwei iPad-Generationen und der ältesten unterstützten iPadOS-Hauptversion bestanden.
- Datenschutzgrenzen, Supportweg und Entwicklungssignierung geprüft.
- Freigabeprotokoll enthält Commit, Version, Buildnummer, Tester, Datum, Geräte/OS und bekannte Einschränkungen.
- Neue technische Berechnungen besitzen zusätzlich Formel-/Katalogversion, Referenzquelle, Fachprüfer, Toleranz und klaren Gültigkeitsbereich.

Die genaue Ausführung, Messfelder und iCloud-Matrix stehen in [RELEASE_ACCEPTANCE.md](RELEASE_ACCEPTANCE.md). Pro geprüftem Build wird die Vorlage unter [evidence/RELEASE_TEST_EVIDENCE_TEMPLATE.md](evidence/RELEASE_TEST_EVIDENCE_TEMPLATE.md) mit `./scripts/prepare-release-evidence.sh <Zielordner>` erzeugt und ausgefüllt.
