# BirdNotes – Dokumentationsindex

Stand: 29. August 2026

## Einstieg

1. [Projektplan](PROJECT_PLAN.md) – führende Prioritäten, M0–M13, Risiken und Freigabegates
2. [Repository- und Skripthandbuch](REPOSITORY_GUIDE.md) – vollständiger Dateibaum, Zuständigkeiten, Skripte und Standardbefehle
3. [Architektur](../ARCHITECTURE.md) – tatsächlich implementierte App-, Daten- und Editorarchitektur
4. [Dateiformate](DATA_FORMATS.md) – persistente Strukturen, Schemata, Grenzen und Migrationsvertrag
5. [Roadmap](../ROADMAP.md) – Funktionsstand und geplante Ausbauphasen
6. [iPad-Installation](IPAD_SETUP.md) – Installation aus Xcode und optionaler Cloud-Ordner

## Technik- und IT-Ausbau

- [Modularchitektur](MODULE_ARCHITECTURE.md) – `.birdtech`, Diagrammgraph, Einheitensystem, Berechnungen, Security und Lieferreihenfolge
- [Modulkatalog](modules/README.md) – Übersicht vorhandener Fachpläne und späterer Erweiterungsfamilien
- [Normen-, Katalog- und Quellenregister](STANDARDS_REGISTER.md) – Ausgabe, Lizenzstatus, Prüfprozess und erlaubte Produktbehauptung
- [Mathematik-/Einheitengrundlage](modules/MATHEMATICS_FOUNDATION.md)
- [Elektrotechnik/Elektronik](modules/ELECTRICAL_ENGINEERING.md)
- [Technisches 2D-Zeichnen](modules/TECHNICAL_DRAWING.md)
- [Physik/Technische Mechanik](modules/PHYSICS_MECHANICS.md)
- [IT/Informatik/Digitaltechnik](modules/IT_COMPUTER_SCIENCE.md)
- [Studienwerkzeuge und Softwareentwicklungs-Curriculum](STUDY_TOOLKIT.md)

Die Fachpläne sind Zielarchitektur, noch keine implementierten oder normzertifizierten Produktfunktionen.

## Qualität, Security und Release

- [Test- und Abnahmeplan](TEST_PLAN.md) – automatische Stufen, Geräteablauf, Edge Cases und Freigabekriterien
- [Reproduzierbare Release-Abnahme](RELEASE_ACCEPTANCE.md) – genaue Instruments-, Soak-, Accessibility- und iCloud-Matrizen mit Nachweisregeln
- [Feedback-Runbook](../FEEDBACK.md) – praktischer iPad-/Apple-Pencil-Durchlauf
- [Produktionsreife](PRODUCTION_READINESS.md) – verbleibende Qualitäts- und Geräteblocker
- [Release-Checkliste](RELEASE_CHECKLIST.md) – verbindliches Gate für einen Release Candidate
- [TestFlight-Verteilung](TESTFLIGHT_DEPLOYMENT.md) – signiertes Archiv, Organizer-Upload und eigenständige Installation auf dem iPad
- [Release-Testnachweis-Vorlage](evidence/RELEASE_TEST_EVIDENCE_TEMPLATE.md) – ausfüllbarer, standardisierter Nachweis pro Build
- [Bedrohungsmodell](THREAT_MODEL.md) – Assets, Angriffsflächen, Risiken und Gegenmaßnahmen
- [Security-Policy](../SECURITY.md) – Melde- und Incident-Prozess
- [Technische Datenschutzinformation](../PRIVACY.md) – Datenverarbeitung und Produktgrenzen
- [Qualitätsmanagement](QUALITY_MANAGEMENT.md) – Rollen, Dokumentenlenkung, Kennzahlen und CAPA
- [Kontrollmatrix](CONTROL_MATRIX.md) – Vorbereitung auf SOC-2-/ISO-9001-nahe Nachweise ohne Zertifizierungsbehauptung
- [Changelog](../CHANGELOG.md) – versionierte Änderungen

## Dokumentationsregeln

- Der Projektplan ist führend für Status und Reihenfolge.
- Architektur und Dateiformate beschreiben nur implementierten Stand; Zukunft wird ausdrücklich als geplant markiert.
- Eine persistente oder sicherheitsrelevante Codeänderung aktualisiert Architektur, Format-/Testplan und Changelog gemeinsam.
- Meilensteinstatus ändert sich erst, wenn Exit-Kriterien nachweisbar erfüllt sind.
- Normausgabe, Lizenz, fachliche Freigabe und Testreferenzen werden pro technischem Katalog versioniert.
- SOC 2, ISO 9001 oder technische Normkonformität werden nicht allein aus Repositorydokumenten behauptet.
