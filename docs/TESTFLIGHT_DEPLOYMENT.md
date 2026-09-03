# BirdNotes über TestFlight verteilen

Stand: 29. August 2026
Status: für eine spätere öffentliche Verteilung vorbereitet; die lokale Geräteinstallation steht in [IPAD_SETUP.md](IPAD_SETUP.md).

Ein über TestFlight installiertes BirdNotes läuft vollständig ohne Verbindung zum Mac. Notizbücher, PDFs und Canvases liegen entweder im lokalen App-Speicher des iPads oder in dem über die Dateien-App ausgewählten BirdNotes-Ordner. Die editierbare PDF-Handschrift bleibt in der mit der PDF wandernden `.birdannotations`-Begleitdirectory; „PDF mit Handschrift exportieren“ erzeugt zusätzlich eine überall lesbare eingebettete Kopie.

## Voraussetzungen

1. Aktive Mitgliedschaft im Apple Developer Program und ein geeignetes Development Team in Xcode.
2. In App Store Connect existiert eine iPad-App mit Bundle-ID `com.dominikvogel.BirdNotes`.
3. Xcode ist unter **Settings → Accounts** mit einer berechtigten Apple-ID angemeldet.

Ohne kostenpflichtige Mitgliedschaft bleibt der lokale Weg über **Xcode → angeschlossenes iPad → Run** vollständig nutzbar. TestFlight-Upload und App-Store-Verteilung werden erst nach der Mitgliedschaft möglich; dies verändert die lokale Dokumentfunktion nicht.

## Geprüftes Archiv erzeugen

Vom freizugebenden Commit ausführen:

```bash
./scripts/verify.sh
./scripts/test.sh sanitizers
./scripts/create-testflight-archive.sh "$HOME/Desktop/BirdNotes-TestFlight"
```

Das letzte Skript prüft Projekt, Bundle-ID, App-Icon, Export-Compliance, Buildnummer und Release-Archive-Aktion. Anschließend erzeugt Xcode ein signiertes Archiv und öffnet dieses direkt im Organizer. Das direkte Öffnen ist erforderlich, weil Archive im frei gewählten Zielordner nicht automatisch in der Organizer-Liste erscheinen. Bestehende Archive werden nicht überschrieben. Jeder erneut hochgeladene Build benötigt eine neue `CURRENT_PROJECT_VERSION`.

## In Xcode hochladen

1. **Window → Organizer → Archives** öffnen.
2. Den aktuellen BirdNotes-Build auswählen und zuerst **Validate App** ausführen.
3. **Distribute App → TestFlight & App Store → Upload** wählen und die empfohlenen automatischen Signierungsoptionen beibehalten.
4. Verarbeitung in **App Store Connect → BirdNotes → TestFlight → Build Uploads** abwarten und alle Warnungen prüfen.
5. Zuerst eine interne Testgruppe zuweisen. Für externe Personen Beta-Beschreibung, Feedback-E-Mail und Testhinweise ausfüllen und den Build zur TestFlight-Prüfung senden.

Apple beschreibt den aktuellen Organizer-Ablauf unter <https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases>. TestFlight-Builds werden bis zu 90 Tage bereitgestellt; der Build selbst muss nach der Installation weder mit Xcode noch mit dem Mac verbunden sein.

## Pflichtprüfung auf dem iPad

- PDF öffnen: ein Finger scrollt, zwei Finger zoomen, nur der Pencil schreibt.
- Mehrere PDF-Seiten beschriften, sofort wegscrollen, App in den Hintergrund schicken, beenden und neu öffnen; alle Striche müssen wieder erscheinen.
- Notizbuch und Canvas ebenfalls nach Hintergrundwechsel und Neustart prüfen.
- Lokalen Speicher sowie einen ausgewählten iCloud-Drive-Ordner getrennt testen.
- Annotierte PDF exportieren und in Vorschau öffnen.

Die extern verbleibenden Freigabepunkte – Apple-Developer-Mitgliedschaft, App-Store-Verträge, Support-/Datenschutz-URL, Testergruppen und reale iCloud-Abnahme – können nicht aus dem Repository heraus erstellt oder bestätigt werden. Sie sind für eine lokale Kabelinstallation nicht erforderlich.
