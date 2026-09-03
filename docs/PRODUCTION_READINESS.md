# Produktionsreife – aktueller Stand

Stand: 28. August 2026

## Erledigt

- Native iPad-App mit Notizbüchern, A4/A3, PencilKit, PDFs und hellem Endlos-Canvas
- Lokaler oder benutzergewählter Dateien-/iCloud-Ordner
- Atomare Writes, Dateikoordination, externe Konflikterkennung und Schemaversionen
- Pfad-/Symlink-/Paketgrenzen sowie Datei-, Objekt-, Text-, Pixel- und Größenlimits
- Quarantäne einer beschädigten Bibliotheksstatusdatei
- Wiederherstellbarer Papierkorb mit konfliktfreier Rücksicherung
- Gezielte Papierkorb-Verwaltung sowie koordinierter ZIP-Backup-Export ohne symbolische Links
- Validierter `.birdbackup`-/ZIP-Import mit Vorschau, Konfliktstrategien und automatischem Restore-Rollback
- Paketweite Redo-Journale für mehrteilige Notizbuch-/Canvas-Saves mit SHA-256-, Größen-, Zielpfad- und Dokument-ID-Prüfung sowie automatischer Vorwärtsreparatur
- Sichtbare Auflösung paralleler iCloud-Dateiversionen
- Lokale Handschrift-zu-Druckschrift-Konvertierung und Volltextsuche
- Vollständiger Funktionszugriff ohne Kauf-, Konto- oder Funktionssperre
- Geführte Verbindung mit einem frei gewählten Ordner aus der Dateien-App
- Atomare Software-Development-Studienstruktur für alle Pflichtmodule
- Portable Kurs-Tags, Studienvorlagen und wichtige Seitenmarkierungen
- Security-Scoped Bookmark im lokalen `ThisDeviceOnly`-Keychain
- App- und Framework-Datenschutz-Manifeste
- Standardisierte lokale/CI-Stufen für Projektkonfiguration, Security, Core-/App-/UI-Tests, Build und statische Analyse
- Isolierter Mehrseiten-UI-Smoke-Test für Zeichnung, Seitenwechsel, Hintergrund-Flush, Papierausrichtung und Neustart-Persistenz ohne Zugriff auf echte Nutzerdaten
- Automatisierter Integritäts- und Wiederöffnungstest für 100-seitige Notizbücher mit gemischten Seitenmetadaten
- Sichtbarkeitsbasierte Notizbuch-Virtualisierung mit Vorladefenster, gezieltem Seitensprung und Erhalt unmittelbar geänderter Zeichnungsdaten beim Freigeben einer Ansicht
- Automatisierte 100-/500-Seiten-Regressionen, Speicherdruck-Bereinigung mit Autosave-Flush und datenschutzneutrale Instruments-Messpunkte
- Automatisierte Integritätsfälle für 1.000 Bibliothekseinträge und 2.000 Canvasobjekte
- Dauerhafte Notizbuch-/Canvas-Golden-Files für Schema v1 und v2 einschließlich Save-after-load-Migration
- Viewportbasierte Canvas-Objektvirtualisierung, lineare Connector-Auflösung und datenschutzneutraler Canvas-/Bibliotheks-Messpunkt
- Reproduzierbare, getrennte Address- und Thread-Sanitizer-Läufe; beide am 28. August 2026 lokal ohne Sanitizer-Befund bestanden
- Reproduzierbares Release-Runbook und commitbezogener Nachweis für Performance, Soak, Accessibility und iCloud
- Pencil-only-Standard, Ein-Finger-Navigation und getestetes Lifecycle-Autosave für mehrseitige PDFs
- Release-Buildnummer 6, Export-Compliance-Angabe und Release-Preflight
- Bedrohungsmodell, Testplan, Security-, Privacy-, Qualitäts- und Release-Dokumente

## P0 vor dem iPad-Release

- Zentralen iCloud-Ordner auf dem iPad verbinden und nach Neustart wieder öffnen
- Vollständige Studienbibliothek im Cloud-Ordner erzeugen
- Manuellen Geräte-, Pencil-, PDF-, Autosave- und Cloud-Test durchführen
- Personal-Team-Signierung sowie Neuinstallation nach Profilablauf praktisch prüfen
- Backup erstellen und in einer frischen Testbibliothek wiederherstellen
- Branchschutz, verpflichtende Reviews, signierte Tags und Release-Nachweis aktivieren

## P1 vor Version 1.0

- Performance-Budgets mit Instruments auf ältestem unterstützten iPad belegen
- Barrierefreiheitsprüfung mit VoiceOver und maximalem Dynamic Type

## Später bei eigenem Backend oder Kollaboration

Identitäts- und Berechtigungsmodell, Mandantentrennung, Verschlüsselung/Schlüsselrotation, Infrastruktur als Code, zentrale Audit-Logs, Alarmierung, Backups mit Restore-Tests, Datenaufbewahrung/-löschung, DPA/Subprozessoren, Penetrationstest, Business Continuity sowie SOC-2-Prüfzeitraum. Diese Kontrollen sind absichtlich nicht vorgetäuscht, solange kein BirdNotes-Server existiert.

## Zusätzliche Gates vor einem Technikmodul-Release

- `.birdtech`-Schema, Ressourcenlimits, Migration und Backup/Restore vollständig getestet
- keine ausführbaren Inhalte oder unkontrollierten Netzwerkzugriffe aus Dokumenten/Katalogen
- Symbol-, Formel- und Normquellen mit Version und Nutzungsrecht dokumentiert
- unabhängige Fachprüfung der Referenzfälle und sichtbarer Gültigkeitsbereich
- parser-/solverbezogene Fuzz-, Komplexitäts- und Performanceprüfungen
- klare Abgrenzung gegenüber zertifizierter Planung, Sicherheits- oder Fertigungsfreigabe
- Datenschutz- und Haftungshinweise gegen den tatsächlichen Modulumfang geprüft
