# Reproduzierbare Release-Abnahme

Stand: 28. August 2026

Dieses Runbook schließt die Lücke zwischen automatisierten Tests und einem belastbaren iPad-Release. Ein Fall gilt nur als bestanden, wenn Gerät, iPadOS, Build, Commit, Tester, Datum, Ergebnis und Beleg im erzeugten Nachweis stehen. Nicht ausgeführte Geräte- oder iCloud-Fälle bleiben offen.

## 1. Nachweis vorbereiten

1. `./scripts/verify.sh` auf dem zu prüfenden Commit ausführen.
2. Mit `./scripts/prepare-release-evidence.sh <Zielordner>` einen neuen Nachweis erzeugen.
3. Release-Build, Bundle-ID, Version, Buildnummer, Testgerät und verwendetes Development Team eintragen. Keine Passwörter oder Tokens dokumentieren.
4. Instruments-Traces, Screenshots und Gerätefeedback mit der Nachweis-ID benennen. Persönliche Notizinhalte vor dem Archivieren entfernen.

## 2. Performance und Speicher

### Fixture und Messung

Im Debug-Scheme unter „Arguments Passed On Launch“ genau eines dieser Argumente setzen:

- `--birdnotes-performance-pages=100`
- `--birdnotes-performance-pages=500`
- `--birdnotes-performance-library-items=1000`
- `--birdnotes-performance-canvas-elements=2000`

BirdNotes erzeugt dafür bei jedem Start ausschließlich die isolierte Bibliothek `BirdNotesPerformanceFixture`. Die normale Bibliothek und ein gewählter iCloud-Ordner werden nicht geöffnet. Die Argumente sind auf 1.000 Seiten, 5.000 Bibliothekseinträge beziehungsweise 10.000 Canvasobjekte begrenzt. Nach dem Aufbau das vorbereitete Dokument antippen oder bei der Bibliotheksvariante direkt Raster und Liste verwenden.

Auf dem ältesten unterstützten iPad nacheinander mit Instruments messen:

1. **Time Profiler + Points of Interest:** 30 Sekunden durchgehend scrollen, zehnmal erste/letzte Seite sowie fünfmal Seitenübersicht/Seite wechseln.
2. **Allocations:** Ausgangswert nach 60 Sekunden Ruhe notieren, zehn Minuten scrollen/zeichnen/Undo/Redo ausführen, danach zwei Minuten ruhen und verbleibendes Wachstum notieren.
3. **Leaks:** denselben Ablauf prüfen; reproduzierbare Leaks sind P1.
4. **Hangs:** die komplette Sitzung prüfen; ein reproduzierbarer Hänger von mindestens 250 ms in einer Kernaktion ist zu analysieren.
5. Xcode „Simulate Memory Warning“ beziehungsweise realen Speicherdruck auslösen, weiterzeichnen, Hintergrund/Vordergrund wechseln und neu öffnen.

Für die Bibliothek zusätzlich wiederholt bis zum Ende scrollen, zwischen Raster/Liste wechseln, suchen und einen Eintrag öffnen/zurückkehren. Im 2.000-Objekte-Canvas mindestens fünf Minuten verschieben, zoomen, „Alles anzeigen“ verwenden, sichtbare Shapes bearbeiten und Connector-Bereiche durchfahren.

Die App zeichnet unter „Points of Interest“ nur numerische Ereignisse auf:

- `Notebook Viewport`: Gesamtseiten und gleichzeitig materialisierte Seitenansichten,
- `Notebook Memory Pressure`: Ansichten vor und nach der Bereinigung,
- `Library Reload`: sichtbare und rekursiv geladene Bibliothekseinträge sowie Dauer des Ladevorgangs,
- `Canvas Viewport`: Gesamtobjekte sowie aktuell projizierte Objektansichten und Connectoren.

Es werden keine Titel, Pfade, Zeichnungen oder erkannten Texte protokolliert.

### Vorläufige Budgets

| Metrik | 100 Seiten | 500 Seiten | Freigaberegel |
|---|---:|---:|---|
| materialisierte Seitenansichten | < 10 | < 10 | automatisch getestet und im Trace bestätigen |
| reproduzierbare Leaks | 0 | 0 | P1 bei Abweichung |
| Hänger in Kernaktion | keiner ≥ 250 ms | keiner ≥ 250 ms | P1 bei Abweichung |
| Speicher nach Ruhephase | Messwert festlegen | Messwert festlegen | Baseline auf ältestem iPad dokumentieren; danach Regression > 15 % blockiert |

Absolute Speicher- und Startbudgets werden erst nach der ersten Messung auf dem definierten Referenzgerät festgeschrieben, nicht aus Simulatorwerten erfunden.

| Metrik | 1.000 Bibliothekseinträge | 2.000 Canvasobjekte | Freigaberegel |
|---|---:|---:|---|
| persistierte/aufzählbare Einträge | 1.000 | 2.000 | automatisch getestet und im Gerätelauf bestätigen |
| gleichzeitig projizierte Canvas-Objektviews | – | < 100 im definierten Testviewport | automatisch getestet; tatsächlichen Tracewert dokumentieren |
| reproduzierbare Leaks | 0 | 0 | P1 bei Abweichung |
| Hänger in Kernaktion | keiner ≥ 250 ms | keiner ≥ 250 ms | P1 bei Abweichung |
| Lade-/Interaktionszeit und Ruhespeicher | Baseline festlegen | Baseline festlegen | danach Regression > 15 % ohne begründete Freigabe blockieren |

Die absoluten Bibliotheks- und Canvaswerte werden ebenfalls erst auf dem Referenzgerät festgelegt. Ein bestandener Simulator- oder Sanitizer-Lauf ersetzt diese Instruments-Messung nicht.

## 3. Langzeitsitzung und Lifecycle

1. 30 Minuten mit Pencil und Finger auf mindestens 20 Seiten schreiben, markieren, radieren, scrollen, zoomen und Undo/Redo verwenden.
2. Während ungesicherter Änderungen 100 Hintergrund-/Vordergrundwechsel durchführen; alle zehn Zyklen die App einmal vollständig beenden und neu öffnen.
3. Bei Zyklus 25, 50 und 75 Speicherdruck auslösen.
4. Nach jedem Neustart Stichproben auf der ersten, mittleren und letzten bearbeiteten Seite vergleichen.
5. Peak, Ruhespeicher, Hänger, Abstürze, Speicherdruck-Beendigungen und Datenabweichungen dokumentieren.

Erwartung: kein Datenverlust, kein kontinuierliches Wachstum nach Ruhephasen, keine beschädigte Seite und keine unbedienbare Werkzeugleiste. Datenverlust ist P0, reproduzierbarer Absturz oder monotones Wachstum ist P1.

## 4. Accessibility und Bedienung ohne Pencil

Die Matrix jeweils in Hochformat, Querformat und Split View ausführen:

| Fall | Prüfung | Erwartung |
|---|---|---|
| VoiceOver | Bibliothek, Erstellen, Notizbuch, Werkzeugleiste, Seitenaktionen, Export | verständliche Namen, Werte, Reihenfolge und keine Sackgasse |
| VoiceOver-Seiten | Rotor-Aktionen „Vorherige Seite“/„Nächste Seite“ | Seite wechselt, Position wird angesagt |
| Dynamic Type | Standard, XXXL, größte Bedienungshilfengröße | Kernaktionen bleiben erreichbar; Werkzeugleiste scrollt horizontal und vergrößert Ziele |
| Finger an | schreiben, scrollen, zoomen | ein Finger zeichnet; zwei Finger navigieren |
| Finger aus (Standard) | Notizbuch und PDF schreiben, scrollen, zoomen | Finger scrollt; zwei Finger zoomen; Pencil zeichnet; Status wird angesagt |
| Handwerkzeug | verschieben ohne Pencil | ein Finger verschiebt, ohne Striche zu erzeugen |
| Externe Tastatur | Neu, Undo, Redo, Markierung | dokumentierte Kurzbefehle funktionieren |
| Kontrast/Farbe | Graustufen, Kontrast erhöhen, Transparenz reduzieren | Zustände sind nicht nur durch Farbe erkennbar |
| Bewegung reduzieren | Navigation und Overlays | keine notwendige Information geht verloren |

Accessibility Inspector vor dem Gerätelauf auf fehlende Namen, kleine Touch-Ziele und Kontrastprobleme prüfen. Automatische Tests decken Finger-Policy, Werkzeugzustände und VoiceOver-Seitenaktionen ab; sie ersetzen keine Screenreader-Abnahme.

## 5. iCloud-Mehrgerät, Konflikt und Recovery

Voraussetzung: zwei iPads oder iPad plus Mac mit derselben Test-iCloud, ausreichend Speicher, iCloud Drive aktiv und ein ausschließlich für die Abnahme bestimmter Ordner `BirdNotes-Test`.

1. Auf Gerät A den Testordner als Speicher wählen, Notizbuch, PDF und Canvas anlegen und vollständige Synchronisation abwarten.
2. Auf Gerät B denselben Ordner wählen und Inhalte/Metadaten vergleichen.
3. A offline schalten. Auf A und B dasselbe Dokument unterschiedlich ändern, beide speichern, A wieder online schalten.
4. Nach iCloud-Abgleich das Konfliktcenter öffnen. Nacheinander „aktuelle Version behalten“ und „andere Version behalten“ an Testkopien prüfen. Keine Version darf still verloren gehen.
5. Im Finder/Dateien-App ein Dokument umbenennen, in einen Unterordner verschieben und eine PDF hineinlegen. App erneut aktivieren und Bibliothek abgleichen.
6. Der App den Ordnerzugriff entziehen oder Ordner verschieben. Beim nächsten Start muss BirdNotes lokal weiterlaufen und „Ordner erneut wählen“ beziehungsweise „Lokalen Speicher behalten“ anbieten.
7. Den Ordner erneut wählen, Gerät sperren, neu starten und offline starten. Nach Netzrückkehr erneut vergleichen.
8. Vor und nach dem Konflikttest ein Bibliotheksbackup erstellen und stichprobenartig wiederherstellen.

Zu dokumentieren: iCloud-Status vor jedem Schritt, Wartezeit bis zur Sichtbarkeit, Konfliktversionen, gewählte Auflösung, Dateizahlen/Prüfsummen bei Bedarf und Recovery-Ergebnis. Ein stilles Überschreiben oder Datenverlust ist P0.

## 6. Gerätesignierung und Kabelinstallation

Den in [IPAD_SETUP.md](IPAD_SETUP.md) beschriebenen Ablauf mit dem vorgesehenen Release-Build durchführen.

| Fall | Erwartung |
|---|---|
| Installation per USB-C und Xcode | App wird mit dem gewählten Development Team signiert und startet auf dem Test-iPad |
| Kabel nach erstem Start getrennt | App läuft ohne aktive Xcode-Debugverbindung weiter |
| Cloud-Ordner gewählt | `Documents/Birdnotes` wird nach App-Neustart wieder geöffnet |
| Mac fügt PDF hinzu | PDF erscheint nach iCloud-Abgleich in BirdNotes |
| iPad schreibt Notiz | Paket erscheint vollständig im Mac-Ordner |
| Ordnerzugriff entzogen | verständliche Recovery und erneute Auswahl ohne Datenlöschung |
| Profil abgelaufen | App wird erneut über Xcode installiert; Cloud-Dokumente bleiben erhalten |
| App neu installiert | derselbe Cloud-Ordner kann erneut verbunden werden |

Im Nachweis Profilablaufdatum, Netzwerkzustand beim ersten Start, iPad-Modell, sichtbaren Cloud-Pfad und Ergebnis festhalten. Niemals Apple-ID-Zugangsdaten aufnehmen.

## 7. Abschluss

- Alle P0/P1-Abweichungen schließen oder Release ablehnen; P1 darf nicht nur durch eine Notiz freigegeben werden.
- P2 mit Eigentümer, Risiko, Zieltermin und Entscheidung dokumentieren.
- Ausgefüllten Nachweis, relevante Traces und `verify.sh`-Protokoll unveränderlich zum Release-Tag archivieren.
- Erst danach die entsprechenden Punkte in `RELEASE_CHECKLIST.md` abhaken.

Installation und Cloud-Einrichtung sind in [IPAD_SETUP.md](IPAD_SETUP.md) beschrieben.
