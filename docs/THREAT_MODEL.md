# Bedrohungsmodell

Stand: 29. August 2026 · Geltungsbereich: lokale iPad-App, Technik-Core und benutzergewählter Dateien-/iCloud-Ordner

## Schutzwerte

- Vertraulichkeit von Notizen, Handschrift, Bildern, PDFs und Ordnernamen
- Integrität und Verfügbarkeit der Dokumentpakete
- Zugriffsfähigkeit auf den ausdrücklich gewählten Bibliotheksordner
- Verlässliche Zuordnung von PDF-Anmerkungen und Canvas-Objekten
- Integrität lokaler Studienkataloge und nachvollziehbare Grenzen von Lernrechnern
- Lieferkette aus Quellcode, Xcode-Projekt, CI und späterer App-Store-Signatur

## Vertrauensgrenzen und Datenfluss

1. Eingabe über Apple Pencil, Touch, Tastatur, Zwischenablage und Dateiauswahl.
2. Validierung in der App sowie in `BirdNotesCore` und `BirdNotesTechnicalCore`.
3. Speicherung im App-Container oder in einem ausdrücklich freigegebenen Ordner.
4. Optionale Synchronisierung des freigegebenen Ordners durch Apples Dateianbieter.
5. Lokale Handschrifterkennung durch Apples Vision-Framework.
6. Expliziter Export über das iOS-Teilen-Menü.
7. Entwicklungssignatur über Xcode/iPadOS; BirdNotes verarbeitet selbst keine Konto- oder Berechtigungsdaten.

Es existiert aktuell keine BirdNotes-Servergrenze und kein eigener Netzwerkverkehr.

## Risiken und Kontrollen

| ID | Szenario | Auswirkung | Umgesetzte Kontrolle | Restmaßnahme |
|---|---|---|---|---|
| T-01 | `../`, absolute Pfade oder Paketinnereien | Zugriff außerhalb des vorgesehenen Bereichs | kanonische Pfadprüfung, reservierte Paketgrenzen | Fuzzing im CI ausbauen |
| T-02 | Symlink zeigt außerhalb der Bibliothek | Vertraulichkeits-/Integritätsverlust | Symlinks werden nicht angezeigt oder betreten | Gerätetest mit verschiedenen Dateianbietern |
| T-03 | Große PDF/Bild-/Drawing-Datei | Speicherüberlastung, Absturz | Größenlimits vor dem Laden; Bild-Pixelgrenze und Downsampling | Instruments-Messung auf ältestem iPad |
| T-04 | Datei nur in `.pdf` umbenannt | Parserangriff oder fehlerhafte Anzeige | PDF-Headerprüfung; PDFKit validiert beim Öffnen | PDF-Fuzz-Korpus erweitern |
| T-05 | Manipuliertes JSON, NaN, doppelte IDs | Absturz oder unbrauchbares Canvas | Schema-, Größen-, Werte- und Referenzvalidierung | Property-based Tests ergänzen |
| T-06 | Abbruch während Speichern/Wiederherstellen | Teilweiser Datenstand | atomare und koordinierte Einzeldatei-Schreibvorgänge; Journal und Rollback für Backup-Restore | paketweite Journale auch auf weitere mehrteilige Editor-Saves ausdehnen |
| T-07 | Gleichzeitige iCloud-Änderung | Überschreiben neuerer Daten | ungelöste `NSFileVersion`-Konflikte stoppen Speicherung; sichtbares Konfliktcenter mit drei Entscheidungen | Mehrgerätetest mit realem iCloud Drive |
| T-08 | Versehentliches Löschen | Datenverlust | sichtbarer Papierkorb, 30 Einträge, gezielte konfliktfreie Wiederherstellung | endgültige Leerung bleibt bewusste Nutzeraktion |
| T-13 | Manipulierte Dateien oder Symlinks im Backup | Datenabfluss oder unvollständige Sicherung | actor-isoliertes Snapshot, koordinierte Kopie, Symlinks werden nicht verfolgt, Papierkorb ausgeschlossen; vollständige Core-Strukturprüfung vor Restore | negatives Backup-Korpus erweitern |
| T-14 | ZIP-Traversal, ZIP-Bombe, CRC-Manipulation oder Pfadkollision | Überschreiben fremder Dateien, Speicherüberlastung | Streaming-Extraktion in eindeutigen Temp-Root; Traversal-/Symlink-/Typ-/Größen-/Ratio-/Duplikatprüfung und CRC32; genau ein Backup-Paket | Parser-Fuzzing und weitere Archive verschiedener Anbieter |
| T-15 | Handschrifterkennung gibt sensible Notizen preis | Vertraulichkeitsverlust | lokale Vision-Verarbeitung ohne BirdNotes-Backend; Originalzeichnung und Text bleiben im gewählten Speicher | Apple-/File-Provider-Datenflüsse in finaler Datenschutzprüfung bestätigen |
| T-16 | Abgelaufenes Personal-Team-Profil | App startet nicht mehr, Dokumente wirken unerreichbar | Cloud-Bibliothek liegt außerhalb der App-Sandbox; dokumentierte Neuinstallation über Xcode | Ablauf nach sieben Tagen praktisch testen und erneut signieren |
| T-09 | Ordner-Bookmark wird kopiert | ungewollter Dateizugriff | Migration in `ThisDeviceOnly`-Keychain | Keychain-Migration auf realem Gerät testen |
| T-10 | Abhängigkeit/CI wird manipuliert | kompromittiertes Release | keine externen Laufzeitabhängigkeiten; CI-Action an SHA gebunden | Branchschutz, signierte Releases, Zwei-Personen-Freigabe |
| T-11 | Supportbericht enthält Inhalte | Datenschutzverletzung | derzeit keine Telemetrie/automatische Berichte | später nur opt-in und Inhaltsvorschau |
| T-12 | Geräteverlust | Offenlegung lokaler Daten | iOS Data Protection im lokalen Speicher | Nutzerhinweis zu Gerätecode; Schutzklasse prüfen |

## Annahmen

- Das iPad ist nicht kompromittiert und besitzt einen Gerätecode.
- Apple-ID, iCloud Drive und ausgewählte Drittanbieter-Dateidienste liegen außerhalb des BirdNotes-Kontrollbereichs.
- Personen mit Dateizugriff können Paketdateien manuell verändern; BirdNotes muss deshalb sicher scheitern, nicht jede Beschädigung automatisch reparieren.

## Technikmodule – Kontrollen und Restmaßnahmen

Die Grundkontrollen für T-17 bis T-20 sind in der v3-Plattform implementiert; Fach- und Skalierungsnachweise bleiben wie angegeben offen:

| ID | Szenario | Vorgesehene Kontrolle | Gate |
|---|---|---|---|
| T-17 | Formel-/Dokumenttext führt Code aus | typisierter Whitelist-Parser; kein JavaScript, Shell, `NSExpression` oder dynamisches Laden; Injection-Test | Fuzz-Korpus ausbauen |
| T-18 | tiefer Ausdruck, Graph oder Constraint blockiert UI | Token-, Tiefen-, Operations-, Variablen-, Element- und Dateigrößenlimits | große Geräte-/DoS-Messung; Solverlimit vor Solverfreigabe |
| T-19 | manipulierte Port-/Netz-/Variablenreferenzen | vollständige referenzielle Validierung vor Speichern, Rechnung und SVG-Export | Negativkorpus laufend erweitern |
| T-20 | eingebetteter SVG-Text lädt aktive Inhalte | eigenes passives Rendering, XML-Maskierung, keine URLs/Skripte oder importierte Renderer | Ressourcenimport erst nach Magic-Byte-/Pixelprüfung ergänzen |
| T-21 | veraltete Formel oder Katalog erzeugt falsches Ergebnis | Formel-/Katalog-/Engineversion, Cacheinvalidierung, sichtbarer Status und Nur-Lesen-Fallback | Migrations-/Referenztest |
| T-22 | falsche technische Zahl wird als sicher freigegeben | Dimensionen, Annahmen, Gültigkeitsbereich, unabhängige Fachprüfung und keine Freigabebehauptung | Fachreview/Release-Zusatzblatt |
| T-23 | unlizenzierte Normsymbole werden verteilt | Lizenz-/Versionsregister und Legal Gate; eigener Lernkatalog als Standard | Katalogfreigabe |
| T-24 | späterer Downloadkatalog wird manipuliert | in Phase 1 keine Downloads; später Signatur, Widerruf, Schlüsselrotation und eigenes Bedrohungsmodell | vor Downloadfunktion |
| T-25 | sehr lange, nicht-finite oder codeähnliche Studienrechner-Eingabe erschöpft Ressourcen oder wird ausgeführt | reine typisierte Rechner ohne Interpreter/Netzwerk; Längen-, Mengen-, Werte- und Operationslimits; Negativtests | Geräteprofiling und späteres Fuzz-Korpus |
| T-26 | Lernhilfe wird als fachlich oder wissenschaftlich geprüfter Nachweis missverstanden | sichtbare Lernhilfe-Grenze, keine automatischen Quellenbehauptungen, Ergebnisse nur temporär und keine Sicherheitsfreigabe | UX-Abnahme und fachliche Reviewtexte |

## Review-Auslöser

Das Modell ist bei Konten, eigenem Backend, Kollaboration, Telemetrie, externen SDKs, Verschlüsselungsschlüsseln, Monetarisierung, neuen Importformaten oder jedem neuen Fach-/Downloadmodul vor Implementierungsbeginn zu aktualisieren.
