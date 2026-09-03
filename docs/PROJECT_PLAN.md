# BirdNotes – Projektplan

| Merkmal | Stand |
|---|---|
| Planstand | 29. August 2026 |
| Technische Baseline | Ausgangscommit `4a35765` auf `main` |
| Zielversion | BirdNotes 3.1.0, Build 6 |
| Zielplattform | iPad, iPadOS 17 oder neuer |
| Nutzungsmodell | Lokale Studien-App ohne Kauf oder Konto |
| Produktphase | iPad-Release mit optionaler Cloud-Bibliothek |

Dieses Dokument ist der führende Umsetzungsplan. Die [Roadmap](../ROADMAP.md) beschreibt den Funktionsumfang, die [Architektur](../ARCHITECTURE.md) die technische Konstruktion und die [Release-Checkliste](RELEASE_CHECKLIST.md) das verbindliche Freigabegate. Statusänderungen an Meilensteinen werden hier gepflegt.

## 1. Zielbild

BirdNotes soll eine native, lokale und langlebige iPad-App für Studium und Wissensarbeit werden. Sie verbindet:

- fortlaufende handschriftliche A4-/A3-Notizbücher,
- beschreibbare PDFs,
- einen hellen Infinite Canvas,
- eine echte, auf Wunsch über iCloud Drive nutzbare Ordnerstruktur,
- lokale Handschrift-zu-Druckschrift-Konvertierung,
- verlässlichen Export, Papierkorb und Backup,
- eine strukturierte Software-Development-Studienbibliothek mit lokalen Lernwerkzeugen.

Nach der stabilen 2.0-Basis wird BirdNotes schrittweise zu einem technischen Arbeitsbuch erweitert: semantische Schaltpläne, präzise 2D-Zeichnungen, Physik-/Mechanikmodelle, einheitengeprüfte Berechnungen sowie IT-/Informatikdiagramme. Diese Funktionen nutzen ein separates, sicheres Modul- und Dokumentmodell und werden nicht als ungeprüfte Shape-Sammlung in den bestehenden Canvas eingebaut.

Das wichtigste Qualitätsversprechen lautet: **Notizen bleiben unter Kontrolle der nutzenden Person, editierbar und ohne stillen Datenverlust zugänglich.**

## 2. Projektgrenzen

### Im aktuellen Release-Scope

- iPad-App ohne eigenes BirdNotes-Backend und ohne Benutzerkonto
- lokale oder ausdrücklich ausgewählte Dateien-/iCloud-Drive-Bibliothek
- Notizbuch, PDF, Infinite Canvas und `.birdtech` als editierbare Dokumenttypen
- Offline-Nutzung; Synchronisierung ausschließlich über Apples Dateien-/iCloud-Infrastruktur
- lokale Vision-Handschrifterkennung
- alle Funktionen ohne Kauf-, Konto- oder Freischaltprüfung
- deutschsprachige Kernoberfläche mit technisch vorbereiteter Erweiterbarkeit

### Bewusst nicht im aktuellen Release-Scope

- Android-, Windows-, Web- oder native macOS-App
- eigenes Cloud-Backend, Webkonto oder Echtzeit-Kollaboration
- serverseitige KI, Telemetrie oder Werbung
- Monetarisierung oder öffentliche App-Store-Verteilung
- formale SOC-2- oder ISO-9001-Zertifizierung

SOC 2 und ISO 9001 bleiben als Prozess- und Kontrollziele relevant. Ein Repository allein kann jedoch weder einen SOC-2-Prüfzeitraum noch ein zertifiziertes Qualitätsmanagementsystem ersetzen.

## 3. Aktuelle Baseline

### Umgesetzt

- eigenständige Bibliothek mit echten Ordnern, Suche, Tags, Favoriten und Verlauf
- portable `.birdnotebook`- und `.birdcanvas`-Packages sowie PDF-Begleitdaten
- fortlaufender, vertikal scrollbarer Notizbuchmodus mit mittig ausgerichteten A4-/A3-Seiten
- sichtbarkeitsbasierte Materialisierung der aktuellen und nahen PencilKit-Seiten statt einer Zeichenansicht für jede Notizbuchseite
- PencilKit-Werkzeuge, Apple-Pencil-/Fingereingabe, Undo/Redo und Autosave
- PDF-Annotationen und abgeflachter Export
- Infinite Canvas mit Zeichnung, Text, Bildern, Formen und Verbindungen
- Papierkorb, ZIP-Backup, validierter Restore und Konfliktbehandlung
- lokale Handschrifterkennung und Volltextsuche
- geführte Verbindung mit `iCloud Drive/Documents/Birdnotes` und atomare Erzeugung der vollständigen Pflichtmodulstruktur
- `.birdtech`-Dokumente, technischer Editor, semantischer Diagrammgraph und sichere SI-Formeln
- erste fest kompilierte Lernmodule für Elektrotechnik, Zeichnen, Mechanik und IT
- lokaler Curriculumkatalog für die 20 Pflichtmodule der Semester 1 bis 4 und wichtige Wahlvertiefungen des Softwareentwicklungs-Studiums
- Studien-Werkzeuge für Arbeitsaufwand, Wiederholungslernen, Active Recall/Feynman, Requirements, JSON, Algorithmen, Zahlensysteme, Statistik, IPv4/CIDR, Wissenschaft und Qualitätssicherung
- Softwareentwicklungs-Symbole für Requirements, Use Cases, UML, ER, CI/CD, Testfälle und Threat Modeling
- Pfad-, Symlink-, Schema-, Größen- und Komplexitätsprüfungen
- absturzsichere Redo-Journale für mehrteilige Notizbuch-/Canvas-Saves und automatische Vorwärtsreparatur
- Datenschutz-Manifeste, Bedrohungsmodell, Testplan und CI-Qualitätsgate

### Automatisch geprüft

- 57 Core-, Sicherheits-, Migrations- und Skalierungstests im Swift-Package einschließlich atomarer Studiengangsstruktur, PDF-Symlink-, Recovery-, Parallelitäts-, Golden-File-, 100-Seiten-, 1.000-Einträge- und 2.000-Objekte-Integritätsfällen
- 37 Tests für SI-Einheiten, Parsergrenzen, Diagrammreferenzen, Undo/Redo, `.birdtech`-Integrität/Golden-File, Module, Curriculum, Wiederholungsplan, JSON, Rechnergrenzen und SVG-Injection
- 21 App-, PDF-Autosave-, Eingabe-, ZIP-, Layout-, Performance-Fixture- und Virtualisierungstests im App-Testbereich
- isolierter Mehrseiten-UI-Smoke-Test für Zeichnung, Seitenwechsel, Lifecycle-Flush, Papierausrichtung und Wiederherstellen nach Neustart
- generischer iOS-Gerätebuild ohne Signierung
- statische Xcode-Analyse
- Plist-, Privacy-Manifest-, Projekt-, Dokumentations- und einfache Secret-Prüfungen über `./scripts/verify.sh`

### Noch nicht als Release-Nachweis abgeschlossen

- vollständiger Ablauf auf einem echten iPad mit Apple Pencil nach der fortlaufenden Seitenumstellung
- Mehrgerätetest mit realem iCloud Drive und echten Konflikten
- echter iCloud-Ordnerdurchlauf mit dem angelegten Mac-Pfad und dem iPad-Dateien-Picker
- dokumentierte Performance- und Speicherbudgets auf dem ältesten unterstützten iPad
- vollständige VoiceOver-, Dynamic-Type- und Bedienungshilfenprüfung
- juristische Prüfung, Anbieteridentität, Support- und Security-Kontakt
- erneute Kabelinstallation nach Ablauf des siebentägigen Personal-Team-Profils

### Bekannte technische Grenze

Der fortlaufende Notizbucheditor materialisiert nur Seiten im sichtbaren Bereich, einen Vorladepuffer sowie die aktive Zielseite. Automatisierte 100- und 500-Seiten-Fälle begrenzen die gleichzeitig vorhandenen `PKCanvasView`-Instanzen auf weniger als zehn. Eine Speicherwarnung stößt den Notebook-Autosave an und reduziert den UI-Puffer unabhängig davon auf sichtbare plus aktive Seiten; Points of Interest machen diese Zahlen in Instruments sichtbar. Die kompakten Seitenmodelle samt PencilKit-Daten bleiben jedoch für schnelle Navigation im Arbeitsspeicher; reale Spitzenwerte, Scroll-Latenz und ein möglicher weiterer Lazy-Data-Layer müssen vor dem dauerhaften Studieneinsatz mit Instruments auf dem ältesten unterstützten iPad belegt werden. Beim Freigeben einer weit entfernten Seite wird deren UIKit-Undo-Historie verworfen, nicht aber die gespeicherte Zeichnung.

## 4. Prioritäten

| Priorität | Bedeutung | Behandlung |
|---|---|---|
| P0 | Datenverlust, Sicherheitsproblem, Startblocker oder Kernfunktion unbenutzbar | blockiert den iPad-Release |
| P1 | deutlicher Funktions-, Performance-, Accessibility- oder UX-Mangel | vor Release beheben oder schriftlich mit Termin akzeptieren |
| P2 | sinnvolle Verbesserung ohne Release-Risiko | planbar nach dem Release Candidate |
| P3 | Idee oder langfristige Option | Backlog, kein Versprechen für die aktuelle 3.0-Stufe |

## 5. Arbeitsströme

| Arbeitsstrom | Inhalt | Verantwortliche Rolle |
|---|---|---|
| Produkt und UX | Workflows, Onboarding, Navigation, Studentenfunktionen, Feedback | Produkt |
| Editor | Notizbuch, PencilKit, PDF, Canvas, Handschrift | Entwicklung |
| Daten und Sync | Dateiformate, Autosave, iCloud, Konflikte, Backup/Restore | Entwicklung + Qualität |
| Qualität | Tests, Performance, Accessibility, Regressionen, Freigabenachweise | Qualität |
| Security und Datenschutz | Bedrohungen, Importgrenzen, Policies, Vorfälle, Rechtsabgleich | Security/Datenschutz |
| Gerätebetrieb | Kabelinstallation, Signierung, Cloud-Ordner, Backups und Wartung | Produkt + Release |
| Technische Plattform | `.birdtech`, Diagrammgraph, Constraints, Einheitensystem, Berechnungsengine | Architektur + Entwicklung |
| Fachmodule | Elektrotechnik, Zeichnen, Physik/Mechanik und IT einschließlich Fachvalidierung | Entwicklung + fachkundige Reviews |
| Studienwerkzeuge | Curriculumzuordnung, Rechner, Checklisten, Vorlagen und persönliche Lernorganisation | Produkt + Entwicklung + Studienfeedback |

Eine Person kann mehrere Rollen übernehmen. P0-Änderungen und Releases sollen trotzdem durch eine zweite Person oder einen nachvollziehbar dokumentierten unabhängigen Review geprüft werden.

## 6. Meilensteine

Die Zeitangaben sind Planwerte für eine einzelne entwickelnde Person und keine festen Veröffentlichungszusagen. Apples Prüfzeiten und juristische Arbeiten kommen gegebenenfalls hinzu.

### M0 – Dokumentierte Baseline

**Status:** abgeschlossen mit diesem Plan  
**Aufwand:** 1–2 Tage

Ergebnisse:

- aktueller Produkt- und Technikstand ist festgehalten,
- Release-Lücken und bekannte Grenze sind sichtbar,
- Roadmap, Tests, Security und Release-Gate sind verlinkt,
- nachfolgende Arbeit wird nach P0–P3 priorisiert.

Abnahme: Der Plan stimmt mit `main`, Xcode-Konfiguration und vorhandener Dokumentation überein.

### M1 – Alpha-Stabilisierung auf echtem iPad

**Status:** als Nächstes  
**Aufwand:** 1–2 Wochen

Arbeitspakete:

1. Den vollständigen Ablauf aus [FEEDBACK.md](../FEEDBACK.md) auf einem echten iPad durchführen.
2. Fortlaufende A4-/A3-Seiten mit Apple Pencil, Finger, Zoom, Rotation und Split View abnehmen.
3. Autosave, automatische Folgeseite, Undo/Redo und Neustart über mehrere Seiten prüfen.
4. PDF-Annotation und Infinite Canvas auf dem Gerät erneut testen.
5. Abgelaufene beziehungsweise entzogene Ordnerfreigabe verständlich wiederherstellen lassen.
6. Alle gefundenen P0-/P1-Befunde reproduzierbar dokumentieren und beheben.

Exit-Kriterien:

- kein offener P0-Befund,
- Pflichtablauf ohne Datenverlust bestanden,
- Kerneditor in Hoch-/Querformat und Split View benutzbar,
- Qualitätsgate nach jeder Korrektur grün.

### M2 – Skalierung, Automatisierung und Accessibility

**Status:** begonnen
**Aufwand:** 2–3 Wochen

Arbeitspakete:

1. Die implementierten isolierten 100-/500-Seiten-Fixtures mit Instruments auf echten Referenzgeräten profilieren; automatische Tests begrenzen in beiden Größen die materialisierten Ansichten auf weniger als zehn.
2. Points of Interest für View-Materialisierung und Speicherdruck auswerten und nur bei belegtem Bedarf um Lazy-Loading der kompakten PencilKit-Daten erweitern.
3. Der isolierte UI-Smoke-Test deckt Erstellen, Öffnen, getrennte Zeichnungen auf mehreren Seiten, automatische Folgeseite, Seitenwechsel, expliziten Hintergrund-/Vordergrundwechsel, Papierausrichtung und Neustart-Wiederherstellung ab.
4. Den vorbereiteten 30-Minuten-Pencil-/Autosave-Soak-Test und 100 Hintergrund-/Vordergrundwechsel auf echten Geräten durchführen; bei Speicherdruck werden ungesicherte Seiten gesichert und Vorladeansichten verworfen.
5. Die implementierten VoiceOver-Seitenaktionen, dynamisch vergrößerten Werkzeugziele sowie Finger-/Hand-Policy mit VoiceOver, maximalem Dynamic Type, Kontrast und reduzierter Bewegung abnehmen.
6. Die implementierten isolierten 1.000-Einträge-/2.000-Objekte-Fixtures auf Referenzgeräten messen; Persistenz, sichere Argumentgrenzen und begrenzte Canvas-View-Materialisierung sind automatisch getestet.

Vorläufige Qualitätsziele:

- keine kontinuierliche Speicherzunahme im Soak-Test,
- keine verlorenen bestätigten Änderungen bei den Lifecycle-Tests,
- flüssiges Schreiben ohne sichtbare editorbedingte Unterbrechungen,
- alle Kernaktionen mit VoiceOver und Touch erreichbar,
- konkrete Messwerte und getestete Geräte im Releaseprotokoll.

Exit-Kriterien: Performance- und Accessibility-Ergebnisse sind dokumentiert; P0/P1-Abweichungen sind geschlossen.

### M3 – Daten-, Sync- und Security-Abnahme

**Status:** geplant  
**Aufwand:** 1–2 Wochen

Arbeitspakete:

1. Zwei-Geräte-iCloud-Test mit parallelen Änderungen und Konfliktauflösung durchführen.
2. Große Bibliothek sichern, ZIP prüfen und in eine frische Bibliothek zurückspielen.
3. Restore-Abbruch und Wiederanlauf mit allen drei Konfliktstrategien prüfen.
4. Negative Importfälle und ein kleines reproduzierbares Testkorpus pflegen.
5. Die implementierten getrennten Address-/Thread-Sanitizer-Läufe je Release Candidate wiederholen; die lokale Baseline vom 28. August 2026 ist grün.
6. Bedrohungsmodell, Privacy Report und Security-Policy gegen den Release-Build prüfen.

Exit-Kriterien:

- kein stilles Überschreiben einer bekannten iCloud-Konfliktversion,
- Restore-Nachweis für Notizbuch, PDF-Annotation, Canvas und Organisationsdaten,
- keine offenen P0-/P1-Sicherheitsbefunde,
- Restrisiken sind schriftlich akzeptiert.

### M4 – Cloud-Einrichtung

**Status:** technisch umgesetzt; einmaliger iPad-Ordnerdialog offen
**Aufwand:** weniger als ein Tag

Arbeitspakete:

1. Einen geeigneten Bibliotheksordner in iCloud Drive oder bei einem anderen Dateien-Anbieter anlegen.
2. Den Ordner beim ersten iPad-Start über den Systempicker verbinden.
3. Security-Scoped Bookmark, Neustart und Recovery nach entzogenem Zugriff prüfen.
4. Vorhandene lokale Bibliothek verlustfrei in den Cloud-Ordner übernehmen.
5. Mac-/iPad-Sichtbarkeit und PDF-Import in beide Richtungen kontrollieren.

Exit-Kriterien: Derselbe Bibliotheksinhalt ist auf Mac und iPad sichtbar, ein Neustart erhält die Ordnerfreigabe und lokale Quelldaten bleiben als sichere Migrationsbasis unangetastet.

### M5 – iPad-Release per Kabel

**Status:** Build vorbereitet; realer Gerätelauf offen
**Aufwand:** weniger als ein Tag, anschließend periodische Neuinstallation

Arbeitspakete:

1. BirdNotes 3.1.0 Build 6 mit dem gewählten Development Team signieren.
2. Angeschlossenes iPad als Xcode-Ziel wählen und über `Product → Run` installieren.
3. Entwicklerzertifikat vertrauen und App einmal mit Internetverbindung starten.
4. Kabel trennen und Pencil-, PDF-, Autosave-, Cloud- und Studienworkflow prüfen.
5. Wegen des siebentägigen Personal-Team-Profils einen einfachen Neuinstallationsablauf beibehalten.

Exit-Kriterien:

- keine offenen P0-/P1-Fehler im Kernworkflow,
- App startet ohne aktive Xcode-Debugverbindung,
- Cloud-Dokumente bleiben auch bei einer Neuinstallation erhalten,
- Build ist eindeutig einem Commit und Testnachweis zugeordnet.

### M6 – Studienbetrieb

**Status:** nach realem iPad-Feedback
**Aufwand:** fortlaufend

Arbeitspakete:

1. Pflichtmodule über die atomare Studienbibliothek anlegen.
2. Lernnotizen, Active Recall, Übungen, Literatur/PDFs und Prüfungsvorbereitung im Alltag verwenden.
3. Nach 7 und 30 Tagen Bedienungsprobleme und Lernnutzen bewerten.
4. Backups regelmäßig erzeugen und mindestens eine Wiederherstellung praktisch prüfen.
5. Nächste Werkzeuge anhand der tatsächlichen Modulbelegung priorisieren.

Exit-Kriterium: BirdNotes unterstützt den täglichen Studienablauf stabil und besitzt einen nachvollziehbaren Wartungs- und Backup-Prozess.

## 7. Ausbau nach der stabilen 2.0-Basis

Die folgenden Meilensteine strukturieren die technische v3-Plattform und ihren weiteren Fachausbau. Die sichere gemeinsame Grundlage ist integriert; fachliche Funktionen werden weiterhin inkrementell ausgeliefert, damit ihr Umfang die Datenintegrität der Kernapp nicht gefährdet.

### M7 – Technische Plattform und Mathematikbasis

**Status:** v3-Grundlage implementiert; iPad-, Performance- und Accessibility-Abnahme offen
**Aufwand:** 6–10 Wochen

Arbeitspakete:

1. `BirdNotesTechnicalCore` als UIKit-unabhängiges Swift Package anlegen.
2. Typisierte SI-Größen, Einheitensystem, sicheren Ausdrucksparser und nachvollziehbare Rechenschritte implementieren.
3. Semantischen Diagrammgraph mit Elementen, Ports, Verbindungen, Layern und Constraints umsetzen.
4. Versioniertes `.birdtech`-Package spezifizieren, validieren, migrieren und in Library/Backup/Restore integrieren.
5. Command-basiertes Undo/Redo, Snap-Engine, Inspector und Vektorszenen-Export erstellen.
6. Parser-/Format-Fuzzing, Property-Tests, Golden Files und Performancebudgets etablieren.
7. Katalog- und Modulregistrierung ausschließlich für kompilierte, deklarative Module umsetzen.

Exit-Kriterien:

- Einheiten-/Dimensionsinvarianten und Referenzrechnungen sind grün.
- Ein generisches Testdiagramm übersteht Bearbeitung, Undo/Redo, Save/Load, Migration, Backup/Restore und PDF/SVG/PNG-Export.
- manipulierte Dokumente können weder Code ausführen noch unkontrolliert Ressourcen verbrauchen.
- unbekannte Modul-/Katalogversionen öffnen sicher im Nur-Lesen- oder verständlichen Fehlerzustand.

### M8 – Elektrotechnik-MVP

**Status:** v3-Lernkatalog und Ohm-/Leistungsformeln implementiert; ERC, Netzlisten und Fachreview offen
**Aufwand:** 6–10 Wochen plus Fach-/Lizenzprüfung

Arbeitspakete:

1. Eigenen, rechtlich geklärten Elektrotechnik-Lernkatalog mit stabilen Ports und IDs erstellen.
2. Orthogonale Leitungen, Junctions, Netzlabels und Referenzkennzeichen implementieren.
3. Electrical Rule Check für Verbindungs-, Wert- und Referenzfehler aufbauen.
4. Gleichstromnetzwerke mit R, idealen Quellen, KCL/KVL und Leistung berechnen.
5. Netzliste, Stückliste und markierten Vektorexport bereitstellen.
6. Mindestens zehn unabhängig geprüfte Referenzschaltungen und ein fachliches Review abschließen.

Exit-Kriterien stehen im [Elektrotechnik-Modulplan](modules/ELECTRICAL_ENGINEERING.md). Netzspannungs-, Schutz- und Installationsauslegung bleibt außerhalb dieses Meilensteins.

### M9 – Technisches 2D-Zeichnen

**Status:** v3-Grundformen, Bemaßungssymbol, Raster-/Winkelfang und SVG implementiert; Constraint-Solver und Normprüfung offen
**Aufwand:** 8–12 Wochen plus Normprüfung

Arbeitspakete:

1. präzise Linien-, Bogen-, Kreis-, Polygon- und Konstruktionswerkzeuge,
2. End-/Mittel-/Schnittpunkt-, Tangenten-, Winkel- und Rastersnapping,
3. inkrementeller Constraint-Solver mit sicheren Widerspruchszuständen,
4. Layer, Linienarten, Bemaßung, A4/A3-Rahmen und Schriftfeld,
5. PDF/SVG/PNG mit definierter Skala; DXF erst in einer später geprüften Teilmenge,
6. Referenzzeichnungen und unabhängige Maß-/Constraint-Abnahme.

Exit-Kriterien stehen im [Plan für technisches Zeichnen](modules/TECHNICAL_DRAWING.md).

### M10 – Physik und Technische Mechanik

**Status:** v3-Kraft-, Balken- und Lagersymbole sowie Kraft-/Momentformeln implementiert; Statiksolver und Fachreview offen
**Aufwand:** 6–10 Wochen plus Fachreview

Arbeitspakete:

1. Freikörperbilder mit Körpern, Lagern, Kräften, Momenten und Bezugssystemen,
2. Vektor-, Statik- und Kinematikberechnungen mit sichtbaren Annahmen,
3. unterstützte einfache Balken-, Reibungs-, Energie- und Impulsfälle,
4. Messwert-/Graphenbasis und Unsicherheitsdarstellung,
5. mindestens 20 unabhängig geprüfte Referenzaufgaben,
6. klare Produktgrenze gegenüber FEA, Tragfähigkeits- und Sicherheitsnachweisen.

Exit-Kriterien stehen im [Physik-/Mechanik-Modulplan](modules/PHYSICS_MECHANICS.md).

### M11 – IT, Informatik und Digitaltechnik

**Status:** v3-Netzwerk-, UML-, Komponenten-, ER-, CI/CD-, Test- und Threat-Model-Symbole sowie Zahlensystem-, Komplexitäts-, Statistik- und CIDR-Rechner implementiert; Digitaltechnik und vollständige UML-/ER-Semantik offen
**Aufwand:** 6–10 Wochen

Arbeitspakete:

1. Ablauf-, Netzwerk- und Architekturdiagramme,
2. dokumentierte UML-Teilmenge und ER-Modellierung; Grundsymbole sind implementiert, Kardinalitäten und Beziehungstypen folgen,
3. Zahlensystem-, Komplexitäts-, Statistik- und CIDR-Rechner sind implementiert; Boolescher Rechner folgt,
4. Logikgatter, Wahrheitstabellen und Timingdiagramme,
5. Trust Boundaries, Assets, Findings und Controls für lokale Bedrohungsmodelle,
6. strikte Garantie, dass importierte Dokumente keinen Code, Scan oder Netzwerkzugriff auslösen.

Exit-Kriterien stehen im [IT-/Informatik-Modulplan](modules/IT_COMPUTER_SCIENCE.md).

### M12 – Studienwerkzeuge für Softwareentwicklung

**Status:** erster produktintegrierter Block implementiert; persönliche Belegung, Vorlagen und iPad-Abnahme offen
**Curriculum-Basis:** IU B.Sc. Softwareentwicklung `FS-BASE-01`, Modulhandbuch vom 27. April 2026

Umgesetzt:

1. versionierter lokaler Katalog für alle 20 Pflichtmodule der Semester 1 bis 4,
2. kategorisierte wichtige Wahlvertiefungen für Security, Cloud, Data/AI, Mathematik, IoT/Embedded, UX/XR, Projekte und Wirtschaft,
3. CP-/Wochenplaner nach dem im Handbuch verwendeten Richtwert von 30 Stunden pro CP,
4. deterministischer Requirements-Check für Verbindlichkeit, vage Begriffe und überprüfbare Akzeptanzkriterien,
5. Zahlensystem-, Algorithmuskomplexitäts-, Statistik- und IPv4/CIDR-Rechner mit Ressourcenlimits,
6. Checklisten für wissenschaftliches Arbeiten und systematische Softwarequalität,
7. deklarative Studien-Symbole für Requirements, Use Cases, UML-Klassen, Komponenten, ER-Entitäten, CI/CD, Trust Boundaries und Testfälle,
8. eigenständiger Sidebar-Zugang mit Modulbrowser und Werkzeugzuordnung.

Nächste Arbeitspakete:

1. reale Modulbelegung lokal auswählbar und filterbar machen,
2. Rechnerergebnisse bewusst in Notizen übernehmen, ohne automatische Inhaltskopplung,
3. Projekt-, Seminar-, Prüfungs- und Bachelorarbeitsvorlagen ergänzen,
4. UML-/ER-Beziehungen, Kardinalitäten, Architekturentscheidungen und Threat-Model-Register ausbauen,
5. booleschen Rechner, Wahrheitstabellen und optional begrenzten CSV-Statistikimport ergänzen,
6. alle Werkzeuge auf dem iPad mit VoiceOver, Dynamic Type und Split View abnehmen.

Sicherheitsgrenze: Die Studienwerkzeuge führen keinen Programmcode aus, starten keine Netzscans, melden sich bei keinem Cloudanbieter an und erzeugen keine angeblichen Quellen. Eine spätere Codeausführung oder Hochschul-/Cloudintegration benötigt ein separates Sandbox-, Datenschutz- und Produktkonzept.

Die vollständige Modul-zu-Werkzeug-Matrix, der Implementierungsbaum und die Ausbauprioritäten stehen in [STUDY_TOOLKIT.md](STUDY_TOOLKIT.md).

Exit-Kriterien:

- alle Pflichtmodule sind eindeutig katalogisiert und alle Werkzeuge mindestens einem Modul zugeordnet,
- Rechner besitzen Normal-, Grenz-, Fehler- und Ressourcenlimit-Tests,
- UI und Technikeditor kompilieren für iPadOS 17 oder neuer,
- echter iPad- und Accessibility-Durchlauf ist dokumentiert.

### M13 – Integriertes technisches Arbeitsbuch

**Status:** langfristig  
**Aufwand:** nach Nutzung der Einzelmodule neu schätzen

Arbeitspakete:

1. technische Objekte und Rechenergebnisse mit Notizseiten/PDFs bidirektional verlinken,
2. gemeinsame Vorlagen, Symbolsuche, Favoriten und projektweite Referenzen,
3. modulübergreifende Übergaben, zum Beispiel Logikschaltung zu Elektrotechnik oder Kraftwert zu Zeichnung,
4. lokaler technischer Suchindex für Symbole, Größen, Netze, Formeln und Ergebnisse,
5. weitere Kataloge für Regelung, Signale, Mess-, Werkstoff-, Wärme- und Strömungstechnik nach dem Aufnahmeprozess,
6. fachlich kontrollierte Erweiterung von Export-/Austauschformaten.

Exit-Kriterium: Die Module teilen eine stabile Plattform, ohne ihre Fachsemantik oder Sicherheitsgrenzen gegenseitig zu verwischen.

## 8. Geordnetes Arbeits-Backlog

### P0 – vor dem iPad-Release

1. Echter iPad-/Apple-Pencil-Pflichtdurchlauf
2. Geräteprofiling großer fortlaufender Notizbücher und Abnahme der implementierten Seitenvirtualisierung
3. Mehrgerätetest mit realem iCloud Drive
4. vollständiger Backup-/Restore-Nachweis
5. Cloud-Ordnerauswahl und Wiederöffnung nach Neustart
6. vollständige Software-Development-Studienstruktur im Cloud-Ordner
7. finaler Geräte-/Signierungsnachweis

### P1 – Qualitätsniveau der Studienfassung

1. VoiceOver- und Dynamic-Type-Abnahme
2. Performancebudgets und Instruments-Bericht
3. verständlicher Wiederherstellungsablauf für ungültige Ordnerfreigaben
4. UI-Politur für leere, ladende, fehlerhafte und konfliktbehaftete Zustände
5. wiederholbare Migrationstests für jede veröffentlichte Schemaversion
6. Geräte- und OS-Testmatrix mit mindestens zwei iPad-Generationen

### P2 – nach stabilem Release Candidate

1. bessere Lernorganisation und Vorlagenverwaltung
2. Verlinkungen zwischen Notizen und PDFs
3. Suchindex für sehr große Bibliotheken
4. selektives Laden großer Canvasinhalte und bei Messbedarf der kompakten Notizbuch-Zeichnungsdaten
5. zusätzliche Export- und Tastaturworkflows
6. Constraint-Solver-, Katalog- und Fachreview-Ausbau auf der implementierten M7-Grundlage
7. Fachreviewer- und Norm-/Lizenzprozess für technische Kataloge

### P3 – langfristige Optionen

- native Mac-App
- freiwillige Ende-zu-Ende-verschlüsselte BirdNotes-Synchronisierung
- Kollaboration und Versionshistorie
- erweiterbare Vorlagen- oder Plugin-Struktur
- weitere Technikmodule nach dem dokumentierten Aufnahmeprozess

Diese Punkte erfordern vor ihrer Umsetzung jeweils eine ergänzte Architektur-, Datenschutz- und Bedrohungsbewertung. Die technische Modulplattform ist in [MODULE_ARCHITECTURE.md](MODULE_ARCHITECTURE.md) spezifiziert.

## 9. Risiken

| Risiko | Bewertung | Gegenmaßnahme | Release-Gate |
|---|---|---|---|
| Verlust nicht gespeicherter Handschrift | hoch | seitengenaues Autosave, Lifecycle-Flush, Soak- und Neustarttests | M1/M2 |
| Speicherverbrauch bei vielen Notebookseiten | hoch | implementierte View-Virtualisierung, Instruments, Lasttests und bei Messbedarf Lazy-Drawing-Laden | M2 |
| iCloud-Konflikt oder entzogene Ordnerfreigabe | hoch | File Coordination, sichtbare Konfliktauflösung, Mehrgerätetest, Recovery-UX | M1/M3 |
| Fehlerhafte oder manipulierte Imports | hoch | Grenzen, Traversal-/Symlink-/Schema-/CRC-Prüfung, Negativkorpus | M3 |
| Personal-Team-Signatur läuft nach sieben Tagen ab | mittel | dokumentierter Neuinstallationsablauf; Cloud-Daten außerhalb der App-Sandbox | M5 |
| Cloud-Ordner wird am iPad falsch gewählt | hoch | geführtes Onboarding, sichtbarer Speichername und erneute Ordnerauswahl | M4 |
| Unzureichende Bedienbarkeit ohne Pencil | mittel | Finger-, Tastatur-, VoiceOver- und Dynamic-Type-Tests | M2 |
| Einzelpersonenabhängigkeit | mittel | klare Dokumentation, Backups, Rollen und reproduzierbare Releases | M4–M6 |
| Compliance wird mit Zertifizierung verwechselt | mittel | Nachweise und Grenzen in der Kontrollmatrix transparent halten | laufend |
| Technik-Scope wächst unkontrolliert | hoch | gemeinsame Plattform zuerst, Module in klaren MVPs, Feature-Flags und Exit-Kriterien | M7–M13 |
| fachlich falsche Rechnung | hoch | Dimensionsprüfung, unabhängige Referenzwerte, zwei fachkundige Reviews und sichtbare Annahmen | jedes Modulrelease |
| Normen/Symbole werden unberechtigt oder veraltet genutzt | hoch | Lizenz-/Versionsregister, Legal Review, eigener Lernkatalog ohne Konformitätsbehauptung | vor Katalogrelease |
| Parser/Import ermöglicht DoS oder Codeausführung | hoch | deklarative Formate, keine Skripte, harte Komplexitäts-/Zeitlimits und Fuzzing | M7 |
| Austauschformat verliert Semantik | mittel | unterstützte Teilmenge, Importvorschau, Verlustbericht und Roundtrip-Korpus | vor Formatfreigabe |

## 10. Definition of Done

### Für ein Arbeitspaket

- Ziel und Akzeptanzkriterien sind vor der Umsetzung verständlich.
- Code ist gebaut und risikogerecht getestet.
- Datenformat, Security, Datenschutz und Accessibility wurden bei Relevanz geprüft.
- Dokumentation und Changelog sind aktualisiert.
- `./scripts/verify.sh` ist grün.
- Es gibt keine unbeabsichtigten Änderungen oder Geheimnisse im Commit.

Zusätzlich für ein Technikmodul:

- Einheiten, Annahmen, Gültigkeitsbereich und nicht unterstützte Fälle sind dokumentiert.
- Symbol-/Norm-/Formelquellen und Nutzungsrechte sind nachweisbar.
- Fachreferenzen wurden unabhängig geprüft; Formel- und ERC-Tests existieren.
- Dokumentformat, Migration, Ressourcenlimits und Manipulationstests sind vollständig.
- Das Ergebnis wird nicht als Sicherheits-, Bau-, Elektro- oder Fertigungsfreigabe missverstanden.

### Für eine Meilensteinfreigabe

- alle Exit-Kriterien sind erfüllt,
- offene Abweichungen besitzen Priorität, Verantwortliche und Entscheidung,
- Testnachweise nennen Commit, Gerät, OS, Datum und Ergebnis,
- bekannte Risiken sind sichtbar und nicht nur mündlich akzeptiert.

### Für den BirdNotes-3.1-iPad-Release

- kein offener P0- oder P1-Befund,
- realer Pencil-, iCloud- und Backup-/Restore-Test bestanden,
- Datenschutz- und Sicherheitsgrenzen nachvollziehbar dokumentiert,
- Release-Checkliste unterschrieben beziehungsweise nachvollziehbar freigegeben,
- Release-Build, Commit, Tag und Testnachweis stimmen überein,
- Neuinstallation, Rollback und Hotfix-Verfahren sind festgelegt.

## 11. Projektsteuerung

Empfohlene GitHub-Labels:

- Priorität: `P0`, `P1`, `P2`, `P3`
- Bereich: `editor`, `storage`, `pdf`, `canvas`, `icloud`, `study`, `security`, `accessibility`, `release`, `docs`
- Technikbereich ergänzend: `technical-core`, `math`, `electrical`, `mechanics`, `drawing`, `it`, `standards`
- Typ: `bug`, `feature`, `test`, `risk`, `decision`

Empfohlener Ablauf:

1. **Backlog** – beschrieben, aber noch nicht zugesagt
2. **Ready** – Akzeptanzkriterien und Abhängigkeiten geklärt
3. **In Arbeit** – aktiv umgesetzt
4. **Review/Test** – Code fertig, Nachweise fehlen noch
5. **Erledigt** – Definition of Done erfüllt

Wöchentlich beziehungsweise nach jedem größeren Feedbackdurchlauf werden P0/P1, Risiken und der nächste Meilenstein geprüft. Nach jedem Meilenstein werden Planstand, Roadmap, Changelog und Produktionsreife synchronisiert.

## 12. Dokumentationslandkarte

| Dokument | Zweck |
|---|---|
| [README](../README.md) | Einstieg, Voraussetzungen und wichtigste Nutzung |
| [Projektplan](PROJECT_PLAN.md) | Prioritäten, Meilensteine, Gates und Risiken |
| [Repository-Handbuch](REPOSITORY_GUIDE.md) | vollständiger Dateibaum, Zuständigkeiten, Skripte und Laufzeitflüsse |
| [Dateiformate](DATA_FORMATS.md) | persistente Strukturen, Limits, Migration und Schreibvertrag |
| [Modularchitektur](MODULE_ARCHITECTURE.md) | technische Plattform, `.birdtech`, Sicherheit und Lieferreihenfolge |
| [Fachmodule](modules/README.md) | Elektrotechnik, Zeichnen, Physik/Mechanik, Mathematik und IT |
| [Normenregister](STANDARDS_REGISTER.md) | Normausgaben, Lizenzstatus, Fachprüfung und Produktbehauptungen |
| [Roadmap](../ROADMAP.md) | Funktionsumfang und längerfristige Themen |
| [Architektur](../ARCHITECTURE.md) | Komponenten, Datenfluss und technische Entscheidungen |
| [Feedback-Runbook](../FEEDBACK.md) | manueller Geräte- und Pencil-Test |
| [Testplan](TEST_PLAN.md) | automatische und manuelle Teststrategie |
| [Produktionsreife](PRODUCTION_READINESS.md) | Qualitätsblocker und technischer Reifegrad |
| [Bedrohungsmodell](THREAT_MODEL.md) | Sicherheitsrisiken und Kontrollen |
| [Release-Checkliste](RELEASE_CHECKLIST.md) | verbindliche Freigabeprüfung |
| [Qualitätsmanagement](QUALITY_MANAGEMENT.md) | Rollen, Prozesse, Kennzahlen und CAPA |
| [Kontrollmatrix](CONTROL_MATRIX.md) | SOC-2-/ISO-9001-Vorbereitung ohne Zertifizierungsbehauptung |
| [Datenschutz](../PRIVACY.md) | technischer Datenschutzentwurf |
| [Security-Policy](../SECURITY.md) | Sicherheitsmeldung und Incident-Ablauf |
| [Changelog](../CHANGELOG.md) | Änderungen je Version |

## 13. Unmittelbar nächster Schritt

Der nächste sinnvolle Produktzyklus bleibt **M1 – Alpha-Stabilisierung**. Er beginnt mit dem echten iPad-/Apple-Pencil-Durchlauf. Befunde werden als P0–P3 klassifiziert; danach werden zuerst Datenintegrität, Schreibverhalten und Seitenfluss stabilisiert. Parallel darf M7 nur als isolierter Core-Prototyp ohne produktive Dokumentmigration beginnen. Erst nach einem grünen M1–M6-Gate werden technische Module standardmäßig für Kundendokumente aktiviert.
