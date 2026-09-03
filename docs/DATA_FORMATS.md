# BirdNotes – Dateiformate und Persistenzvertrag

Stand: 29. August 2026

Dieses Dokument beschreibt die aktuell implementierten Formate. Änderungen sind kompatibilitätsrelevant: Eine veröffentlichte App darf bestehende Notizen nicht still unlesbar machen oder mit einer älteren Struktur überschreiben.

## 1. Bibliotheks-Root

Ohne Auswahl liegt der Root unter `Application Support/BirdNotes/Documents`. Alternativ verwendet BirdNotes einen ausdrücklich gewählten Ordner aus iCloud Drive, „Auf meinem iPad“ oder einem File Provider. Die URL wird nicht als frei manipulierbarer String, sondern als Security-Scoped Bookmark im Schlüsselbund gespeichert.

```text
BirdNotes/
├── Semester 1/
│   ├── Mathematik.birdnotebook/
│   ├── Lernplan.birdcanvas/
│   └── Skript.pdf
├── .Skript.pdf.birdannotations/
├── .birdnotes-library.json
├── .birdnotes-trash/
└── .birdnotes-transactions/
```

Versteckte Zustands-, Papierkorb- und Transaktionsverzeichnisse werden von der normalen Bibliotheksansicht ausgeschlossen. Symbolischen Links wird nicht gefolgt.

## 2. Notizbuchpaket `.birdnotebook`

Aktuelle Schemaversion: `2`

```text
Vorlesung.birdnotebook/
├── manifest.json
└── pages/
    └── <UUID>/
        ├── metadata.json
        └── drawing.data
```

`manifest.json` enthält Schemaversion, Dokument-UUID, Typ, Titel, Erstellungs-/Änderungsdatum und die eindeutige geordnete Liste der Seiten-UUIDs.

`metadata.json` enthält Seiten-UUID, Zeitstempel, Papierstil, A4/A3, Hoch-/Querformat, Leerstatus, Lesezeichen und optional erkannte/editierte Druckschrift. Fehlendes `paperFormat` wird für alte Dokumente als A4, fehlendes `paperOrientation` als Hochformat und fehlendes `isBookmarked` als `false` gelesen. Beim Ausrichtungswechsel bleiben die PencilKit-Daten unverändert und editierbar; nur die sichtbaren und exportierten Seitengrenzen wechseln.

`drawing.data` ist die opake, editierbare `PKDrawing.dataRepresentation()`. Der Core interpretiert oder verändert diesen Payload nicht.

## 3. Infinite-Canvas-Paket `.birdcanvas`

Aktuelle Schemaversion: `2`

```text
Ideen.birdcanvas/
├── manifest.json
├── drawing.data
└── elements.json
```

Das Manifest enthält Dokumentdaten, Fläche, Viewport und Kachelkonfiguration. `drawing.data` enthält die freie PencilKit-Zeichnung. `elements.json` enthält portable Text-, Bild-, Shape- und Connector-Elemente mit stabilen UUIDs, Geometrie, Farben, Z-Reihenfolge über Listenposition sowie Zeitstempeln.

Version 1 ohne Viewport/Kachelung und alte Pakete ohne `elements.json` werden mit sicheren Standardwerten geladen. Unbekannte höhere Versionen werden abgelehnt.

## 4. PDF und Annotationen

Die importierte PDF bleibt unverändert. Editierbare PencilKit-Daten liegen direkt daneben:

```text
Skript.pdf
.Skript.pdf.birdannotations/
├── page-0.drawing
├── page-1.drawing
└── page-7.drawing
```

Der nullbasierte Seitenindex muss eine nichtnegative ganze Zahl innerhalb der festgelegten Grenze sein. Beim Umbenennen, Verschieben, Duplizieren, Löschen, Wiederherstellen und Backup wird der Begleitordner gemeinsam mit der PDF behandelt. Der annotierte Export ist eine neue, abgeflachte PDF; er ersetzt weder Original noch editierbare Begleitdaten.

## 5. Bibliotheksstatus

`.birdnotes-library.json` speichert ausschließlich Organisationsdaten:

- relative Favoritenpfade,
- bis zu 20 zuletzt geöffnete relative Pfade,
- Tags je relativem Pfad.

Ungültige Pfade und Tags werden beim Lesen verworfen. Eine beschädigte Datei blockiert keine Dokumente, sondern wird als beschädigte Kopie quarantänisiert und durch sicheren Leerzustand ersetzt.

## 6. Papierkorb

`.birdnotes-trash` enthält verschobene Einträge plus Metadaten mit ursprünglichem relativem Pfad, gespeichertem Namen, Typ und Löschdatum. Maximal 30 Einträge werden aufbewahrt; ältere Einträge werden endgültig entfernt. Eine Wiederherstellung überschreibt keinen inzwischen neueren Eintrag desselben Namens.

## 7. Backup-Paket `.birdbackup`

Aktuelle Schemaversion: `1`

```text
BirdNotes-Backup-<UUID>.birdbackup/
├── manifest.json
├── WIEDERHERSTELLEN.txt
└── Library/
    ├── <aktive Ordner und Dokumente>
    ├── <PDF-Begleitordner>
    └── .birdnotes-library.json
```

Das Backup enthält keinen Papierkorb und keine laufenden Transaktionen. Es kann direkt oder als System-ZIP importiert werden. Vor einer Wiederherstellung werden Archiv und ausgepacktes Paket vollständig validiert. Konfliktstrategien sind `keepBoth`, `skip` und `replace`. Ein persistentes Journal plus Rollback-Verzeichnis schützt vor einem Abbruch mitten im Restore.

### Laufende Transaktionen

Mehrteilige Notizbuch- und Canvas-Saves verwenden ein persistentes Redo-Journal:

```text
.birdnotes-transactions/
└── <Transaktions-UUID>/
    ├── document-journal.json
    └── incoming/
        ├── payload-0
        └── …
```

Zuerst werden sämtliche neuen Nutzdaten im versteckten Eingangsbereich geschrieben. Das anschließend atomar gespeicherte Journal bindet die Transaktion an Dokumenttyp, relativen Paketpfad und Dokument-UUID. Jeder Eintrag enthält Aktion, streng paketrelativen Zielpfad, exakte Bytezahl und SHA-256-Prüfsumme. Es sind höchstens 16 Einträge erlaubt; für Notizbuch und Canvas existieren getrennte Zielpfad-Allowlists.

Erst nach erfolgreicher Gesamtvalidierung werden die Einträge in definierter Reihenfolge idempotent angewendet und das Journal als abgeschlossen markiert. Beim nächsten Bibliotheksstart oder vor einem neuen mehrteiligen Save wird ein unvollständiger Stand vorwärts fertiggestellt. Ein Transaktionsordner ohne Journal stammt ausschließlich aus der Vorbereitungsphase und kann entfernt werden, weil zu diesem Zeitpunkt noch kein Dokumentziel berührt wurde. Backup-Restore bleibt davon getrennt und verwendet sein Rollback-Journal. PDF-Seitenzeichnungen bestehen jeweils aus nur einer atomar ersetzten Datei und benötigen deshalb kein mehrteiliges Redo-Journal.

## 8. JSON-Konventionen

- UTF-8
- ISO-8601-Zeitwerte
- sortierte Schlüssel für reproduzierbare Diffs
- UUIDs für persistente Identitäten
- explizite ganzzahlige `schemaVersion`
- keine nicht-finiten Zahlen (`NaN`, `+∞`, `-∞`)
- relative Pfade nur nach Normalisierung und Root-Prüfung

JSON darf nicht als Begründung für unbegrenzte Datenmengen dienen. Vor vollständigem Dekodieren wird, soweit möglich, die Dateigröße begrenzt; anschließend folgen semantische Anzahl-, Bereichs- und Beziehungsprüfungen.

## 9. Implementierte Ressourcenlimits

| Ressource | Grenze |
|---|---:|
| sichtbarer Name | 200 Zeichen und höchstens 240 UTF-8-Bytes im Manifest |
| importierte PDF | 512 MiB |
| einzelner PencilKit-Payload | 128 MiB |
| Manifest/Metadaten | 2 MiB |
| Papierkorbmetadaten | 4 MiB |
| Canvas-Element-JSON | 64 MiB |
| einzelnes eingebettetes Canvas-Bild | 20 MiB |
| alle Bilder eines Canvas | 48 MiB |
| Canvas-Elemente | 10.000 |
| Text eines Canvas-Elements | 100.000 Zeichen |
| Notizbuchseiten | 10.000 |
| PDF-Annotationsseiten | 100.000 |
| erkannte Druckschrift pro Seite | 250.000 Zeichen und 1 MiB UTF-8 |
| Favoriten | 10.000 |
| letzte Einträge | 20 |
| Tags pro Eintrag | 12 |
| Zeichen pro Tag | 40 |
| Backup-Einträge | 100.000 |
| Backup-Tiefe | 100 Ebenen |
| ausgepacktes Backup | 20 GiB |
| akzeptiertes ZIP | 4 GiB komprimiert, 20 GiB expandiert |
| ZIP-Kompressionsverhältnis | höchstens 500:1 pro Eintrag |
| Papierkorbeinträge | 30 |

Die hohen technischen Maxima verhindern offensichtlichen Ressourcenmissbrauch; sie sind keine Zusage, dass die UI an jeder Maximalgrenze flüssig bleibt. Praxistaugliche Performancebudgets müssen deutlich darunter gemessen und als Releasekriterium dokumentiert werden.

## 10. Schreib- und Konfliktregeln

1. Der Zielpfad wird standardisiert, gegen absolute Pfade, `..`, Paketinnere und Symlinks geprüft.
2. Externe ungelöste `NSFileVersion`-Konflikte blockieren das Überschreiben.
3. Einzeldateien werden über `NSFileCoordinator` atomar ersetzt.
4. Neue Packages entstehen vollständig in einem temporären Geschwisterpfad und werden danach sichtbar verschoben.
5. Mehrteilige Notizbuch-/Canvas-Updates werden vollständig vorbereitet, über Bytezahl und SHA-256 geprüft, an die Dokument-UUID gebunden und aus einem persistierten Redo-Journal angewendet.
6. Ein unterbrochener Redo-Save wird idempotent fertiggestellt; das referenzierende Manifest wird bei Anlage zuletzt und bei Löschung vor der verwaisten Seitendirectory geschrieben.
7. Backup-Restore verwendet Eingang, Rollback und ein getrenntes Journal statt direkten Teilkopien in die Bibliothek.
8. Unerwartete Fehler werden als `DocumentStoreError` weitergegeben; Produktionscode darf nicht über `try!` oder `fatalError` abbrechen.

## 11. Kompatibilitätsregeln

Für jede Formatänderung gelten folgende Mindestanforderungen:

- Eine höhere unbekannte Haupt-Schemaversion wird nur gelesen, wenn sie ausdrücklich unterstützt wird.
- Neue optionale Felder besitzen sichere Defaultwerte.
- Eine Migration wird zuerst auf einer Kopie beziehungsweise atomar durchgeführt.
- Jede jemals veröffentlichte Schemaversion erhält ein dauerhaftes Golden File. Die aktuellen v1-/v2-Pakete für Notizbuch und Canvas liegen unter `BirdNotesCore/Tests/BirdNotesCoreTests/Fixtures` und werden einschließlich Save-after-load geprüft.
- Save-after-load darf unbekannte Daten nicht still verwerfen, wenn Vorwärtskompatibilität zugesagt wird.
- Ein Downgrade-Szenario und Exportpfad werden dokumentiert.
- Formatänderung, Migration, Limits und Sicherheitsauswirkung werden in Architektur, Testplan und Changelog festgehalten.

## 12. Technisches Dokument `.birdtech`

Elektrotechnik-, Mechanik-, technische Zeichen- und IT-Diagramme verwenden ein eigenes versioniertes Package:

```text
Schaltung.birdtech/
├── manifest.json
├── diagram.json
├── calculations.json
├── annotations.data   # optional
└── preview.png        # optional
```

Schemaversion 1 speichert Dokument-ID, Fachbereich, Modulversionen und SHA-256-Prüfsummen im Manifest. `diagram.json` enthält den semantischen Graph, `calculations.json` Formelinstanzen samt Einheiten und Rechentrace. Freie Handschrift und Vorschau sind optionale Caches beziehungsweise Annotationen und nie Quelle der technischen Semantik.

Grenzen: 10.000 Elemente, 20.000 Verbindungen, 20.000 Constraints, 50 MB Diagramm-JSON, 10 MB Berechnungen, 100 MB Handschrift und 20 MB Vorschau. Paketdateien und Symlinks werden vor dem Dekodieren geprüft; Speichern erfolgt über ein temporäres Geschwisterpaket mit Rückfallkopie. Details stehen in der [Modularchitektur](MODULE_ARCHITECTURE.md).
