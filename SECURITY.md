# Sicherheitsrichtlinie

## Unterstützter Stand

Bis zu einer gekennzeichneten öffentlichen Version werden Sicherheitskorrekturen ausschließlich für den aktuellen Stand des `main`-Branches gepflegt. Für Entwicklungsstände besteht keine zugesicherte Supportdauer.

## Sicherheitslücken melden

Sicherheitslücken sollten vertraulich über **GitHub Private Vulnerability Reporting** im Bereich **Security** des Repositorys gemeldet werden. Falls dieser Kanal nicht verfügbar ist, sollte die Repository-Inhaberin oder der Repository-Inhaber über einen privaten Kontaktweg des GitHub-Profils kontaktiert werden.

Bitte keine Notizinhalte, Backups, Zugangsdaten oder andere personenbezogene Daten in eine Meldung aufnehmen. Sicherheitsprobleme sollten erst nach abgestimmter Behebung öffentlich beschrieben werden.

Eine hilfreiche Meldung enthält:

- betroffene Version oder Commit-ID
- nachvollziehbare Schritte zur Reproduktion
- mögliche Auswirkungen
- eine datensparsame Testdatei, sofern erforderlich

## Technische Grundsätze

- keine Netzwerkübertragung und keine Drittanbieter-Laufzeit-SDKs im aktuellen Stand
- Dateizugriff nur im App-Bereich oder in ausdrücklich freigegebenen Ordnern
- Security-Scoped Bookmarks im iOS-Schlüsselbund
- atomare, koordinierte Schreibvorgänge und erkennbare Dateikonflikte
- Schutz vor Pfad- und Paket-Traversal sowie symbolischen Links
- Größen- und Komplexitätsgrenzen für importierte oder manipulierte Dateien
- geprüfter Backup-Import mit Integritäts-, Struktur- und Kompressionskontrollen
- lokale Handschrifterkennung ohne Übertragung an einen BirdNotes-Dienst
- Datenschutz-Manifeste für App und Framework

Technische Berechnungen und Diagramme dienen dem Lernen und Dokumentieren. Sie ersetzen keine fachliche Prüfung und sind nicht für sicherheitskritische Freigaben vorgesehen.

## Umgang mit bestätigten Problemen

Bestätigte Schwachstellen werden nach Auswirkung priorisiert, im betroffenen Code behoben und mit Regressionstests abgesichert. Eine Veröffentlichung erfolgt koordiniert, sobald betroffene Personen ausreichend Zeit für ein Update hatten oder eine sofortige Warnung erforderlich ist.
