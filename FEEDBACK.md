# BirdNotes-Feedback auf dem iPad

Dieses Runbook ist das letzte Gate für den aktuellen Funktionsstand. Ziel ist nicht nur „die App startet“, sondern ein vollständiger Durchlauf mit Apple Pencil, App-Neustart, iCloud-Ordner und unterschiedlichen Fenstergrößen.

## Start auf einem Test-iPad

Geräte- und Simulator-Build, alle 45 Core-, Sicherheits- und Migrationstests sowie die Xcode-Testsuite sind erfolgreich. Für den letzten Praxischeck:

1. Das iPad per Kabel oder über die Xcode-Geräteverbindung mit dem Mac verbinden.
2. Im Scheme **BirdNotes** das angeschlossene iPad als Ziel wählen.
3. Unter **Signing & Capabilities** bei Bedarf ein geeignetes Development Team wählen.
4. **Product → Run** ausführen.

Falls der Build fehlschlägt, bitte die erste rote Fehlermeldung vollständig kopieren. Folgefehler sind meist nur Konsequenzen davon.

## Pflichtdurchlauf

### 1. Library

1. App frisch starten.
2. Ordner **Studium** erstellen.
3. Darin **Semester 1** und anschließend **Mathematik** erstellen.
4. Zwischen Raster und Liste wechseln.
5. Nach „Mathematik“ suchen und die Sortierungen ausprobieren.
6. Einen Ordner umbenennen, duplizieren und verschieben.

Erwartet: Navigation und Breadcrumbs bleiben verständlich; nach App-Neustart ist die Struktur unverändert vorhanden.

### 1b. Gemeinsamer Ordner und PDF

1. In der Sidebar unter **Speicher** den Speicherort öffnen.
2. Unter **iCloud Drive** einen Ordner **BirdNotes** erstellen oder auswählen.
3. Prüfen, ob vorhandene lokale Notizbücher weiterhin sichtbar sind.
4. Auf dem Mac im Finder unter **iCloud Drive → BirdNotes** einen Unterordner und eine PDF ablegen.
5. BirdNotes auf dem iPad erneut aktivieren oder die Library nach unten ziehen.
6. Die PDF öffnen, mit dem Apple Pencil etwas darauf schreiben und wieder schließen.
7. Die PDF erneut öffnen und prüfen, ob die Handschrift weiter bearbeitbar vorhanden ist.

Erwartet: Die Finder-Ordnerstruktur erscheint in BirdNotes, PDFs lassen sich lesen und beschreiben, und ein App-Neustart behält Speicherort sowie Handschrift bei.

### 2. Notizbuch und Pencil

1. In **Mathematik** ein Notizbuch **Vorlesung** erstellen und öffnen.
2. Den Bedienhinweis lesen und schließen.
3. Beim Erstellen nacheinander punktiertes und Cornell-Papier ausprobieren.
4. Unter **Seitenaktionen → Format** zwischen **A4** und **A3** wechseln; neue Seiten sollen die aktuelle Vorlage und das aktuelle Format übernehmen.
5. Mit Apple Pencil mehrere Zeilen schreiben.
6. Nach unten zur nächsten Seite scrollen und prüfen, dass die A4-/A3-Seiten mittig und fortlaufend untereinander liegen.
7. Mit dem Handwerkzeug verschieben und mit zwei Fingern scrollen beziehungsweise zoomen.
8. Stiftbreite und Farbe wechseln, Marker verwenden.
9. Stiftprofil sowie Strich-, Pixel- und Festbreitenradierer ausprobieren.
10. Apple-Pencil-Doppeltipp, Lasso, Undo und Redo verwenden.
11. Aktuelle Seite als PDF und PNG sowie das ganze Notizbuch als PDF exportieren.
12. Eine Seite als wichtig markieren und in der Seitenübersicht auf wichtige Seiten filtern.

Erwartet: Pencil und Finger zeichnen mit dem Stiftwerkzeug; das Handwerkzeug verschiebt ohne Konflikt. Papierlinien bleiben unabhängig von der Handschrift.

### 3. Seitenautomatik

1. Auf der ersten und zunächst einzigen leeren Seite zeichnen.
2. Prüfen, ob genau eine neue leere Seite erscheint.
3. Wieder auf Seite 1 zeichnen.
4. Prüfen, dass dadurch keine dritte Seite erscheint.
5. Auf der letzten leeren Seite zeichnen.
6. Prüfen, ob erneut genau eine freie Folgeseite entsteht.
7. Zusätzlich eine Seite manuell anlegen, duplizieren und umsortieren.

### 4. Persistenz

1. Warten, bis oben das Häkchen für „gesichert“ erscheint.
2. Notizbuch schließen.
3. App aus dem App-Umschalter vollständig beenden.
4. App erneut starten und dasselbe Notizbuch öffnen.

Erwartet: Ordner, Seitenreihenfolge, Papierarten und alle PencilKit-Strokes sind vorhanden und weiterhin editierbar.

### 4b. Endlos-Canvas

1. Über **Neu → Endlos-Canvas** ein Canvas **Projektplan** erstellen.
2. Öffnen, herauszoomen und in mehrere Richtungen verschieben.
3. Mit Stift und Marker an weit auseinanderliegenden Stellen zeichnen.
4. Text, Bild, Linie, Pfeil, Formen und eine Mindmap einfügen.
5. Ein Objekt verschieben, skalieren, drehen, duplizieren, kopieren und löschen.
6. Den Ausschnitt verändern, Canvas schließen, App vollständig beenden und erneut öffnen.
7. Prüfen, ob Position und Zoom wiederhergestellt werden; anschließend **Alles anzeigen** nutzen.

Erwartet: Die große Arbeitsfläche lässt sich frei zoomen und verschieben; Strokes, Objekte, Verbindungen und der letzte Ausschnitt sind nach dem Neustart weiterhin editierbar vorhanden.

### 4c. Favoriten, Suche und externe Änderung

1. Ein Dokument über das Kontextmenü zu den Favoriten hinzufügen und öffnen.
2. **Favoriten** und **Zuletzt geöffnet** in der Sidebar prüfen.
3. Nach einem Dokument in einem tieferen Unterordner suchen.
4. Im Finder eine PDF in den gemeinsamen BirdNotes-Ordner kopieren, ohne manuell zu aktualisieren.
5. Tags **Semester 1**, **Mathematik** und **Prüfung** vergeben und den Tag-Filter in der Sidebar öffnen.

Erwartet: Favorit, Verlauf und rekursiver Suchtreffer stimmen; die externe PDF erscheint nach kurzer Zeit automatisch und zeigt eine Vorschau.

### 4d. Papierkorb und Backup

1. Zwei Testdokumente löschen und den Papierkorb öffnen.
2. Eines gezielt wiederherstellen und das andere endgültig löschen.
3. Prüfen, dass Tags und Favoriten des wiederhergestellten Dokuments erhalten sind.
4. **Bibliothek sichern** wählen und das ZIP in der Dateien-App ablegen.
5. ZIP öffnen und stichprobenartig Notizbuch, Canvas, PDF-Handschrift und `.birdnotes-library.json` prüfen.

Erwartet: Die Sicherung enthält aktive Inhalte und Organisation, aber keinen internen Papierkorb. Der Export darf die App bei einer größeren Bibliothek nicht dauerhaft blockieren.

### 5. iPad-Layouts

Den Editor jeweils kurz prüfen in:

- Hochformat
- Querformat
- Split View ungefähr halbbreit
- hellem und dunklem UI-Modus
- optional mit angeschlossener Hardware-Tastatur (`⌘Z`, `⇧⌘Z`)

Dabei eine A4-Hochformatseite geöffnet lassen, das iPad drehen und prüfen, dass die Seite bei aktiver Automatik auf die neue Breite eingepasst wird, aber Hochformat bleibt. Danach **Automatisch anpassen** ausschalten und erneut drehen: Zoom und Papierausrichtung bleiben unverändert, nur Oberfläche und Werkzeugleiste folgen dem Gerät. Abschließend über den sichtbaren Ausrichtungsbutton zwischen Hoch- und Querformat wechseln und dasselbe im Infinite Canvas mit dessen Drehungsanpassung wiederholen.

## Worauf dein subjektives Feedback besonders wertvoll ist

- Ist die Werkzeugleiste mit dem Pencil schnell genug erreichbar?
- Sind Seitenleiste und Neue-Seite-Button an der richtigen Stelle?
- Fühlt sich Zoom/Pan natürlich an?
- Ist die Standard-Strichstärke passend?
- Ist das Papier auf 11" und 13" angenehm skaliert?
- Stört der sichtbare Speicherstatus oder schafft er Vertrauen?
- Welche Aktion war nicht dort, wo du sie erwartet hast?

## Vorlage für einen Befund

```text
Gerät:
iPadOS-Version:
Apple Pencil:
Ausrichtung / Split View:

Schritte:
1.
2.
3.

Erwartet:
Tatsächlich:

Reproduzierbar: immer / manchmal / einmalig
Screenshot oder Bildschirmaufnahme: falls hilfreich
```

## Freigabe für den Praxisstand

Der aktuelle Stand ist freigegeben, sobald:

- der Xcode-Build und alle Tests erfolgreich sind,
- der Pflichtdurchlauf ohne Datenverlust funktioniert,
- Pencil und Finger nicht gegeneinander arbeiten und
- die wichtigsten UI-Rückmeldungen aus dem realen iPad-Test festgehalten sind.
