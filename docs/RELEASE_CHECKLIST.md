# Release-Checkliste

Für jedes Release kopieren, ausfüllen und zusammen mit dem Git-Tag ablegen.

Vor Beginn `./scripts/prepare-release-evidence.sh <Zielordner>` ausführen und die Abläufe aus [RELEASE_ACCEPTANCE.md](RELEASE_ACCEPTANCE.md) im erzeugten Nachweis protokollieren.

## Identität

- [ ] Version, Buildnummer, Commit und Veröffentlichungsdatum eingetragen
- [ ] Umfang und bekannte Einschränkungen freigegeben
- [ ] Verantwortliche für Produkt, Entwicklung, Qualität und Release benannt

## Qualität und Sicherheit

- [ ] `./scripts/verify.sh` erfolgreich; Protokoll archiviert
- [ ] Kritischer Gerätetest aus `docs/TEST_PLAN.md` bestanden
- [ ] Keine offenen P0/P1-Fehler; P2-Risiken schriftlich akzeptiert
- [ ] Migration von vorheriger öffentlicher Version und Wiederherstellung getestet
- [ ] Bibliotheks-Backup exportiert, ZIP geöffnet und stichprobenartig mit Quelle verglichen
- [ ] Backup in frische Bibliothek und mit allen drei Konfliktstrategien erfolgreich wiederhergestellt
- [ ] Wiederanlauf nach absichtlich abgebrochener Backup-Wiederherstellung geprüft
- [ ] Xcode Sanitizer für Threading/Address in separaten Testläufen geprüft
- [ ] 100-/500-Seiten-Instruments-Läufe und 30-Minuten-/100-Lifecycle-Soak dokumentiert
- [ ] Speicherdruck bereinigt Vorladeansichten ohne Datenverlust
- [ ] VoiceOver, maximales Dynamic Type und Bedienung ohne Pencil nach Abnahmematrix bestanden
- [ ] Abhängigkeiten, Lizenzen, Geheimnisse und Signaturberechtigungen geprüft
- [ ] Bedrohungsmodell und Security-Policy noch aktuell

## Datenschutz und Betrieb

- [ ] `PrivacyInfo.xcprivacy` und Xcode Privacy Report geprüft
- [ ] Datenschutzdokument entspricht dem tatsächlichen Build
- [ ] Keine Kauf-, Konto-, Telemetrie- oder Werbelogik enthalten
- [ ] Drittanbieter und Export-/Kryptografiefragen technisch geprüft

## iPad und Cloud-Betrieb

- [ ] Entwicklungssignatur, Bundle-ID, Entitlements und Personal-Team-Profil geprüft
- [ ] App-Icon und Release Notes final
- [ ] iCloud-Mehrgerät-, echter Konflikt- und Ordnerzugriff-Recovery-Test bestanden
- [ ] der gewählte Cloud-Ordner ist auf den vorgesehenen Geräten sichtbar und nach Neustart verbunden
- [ ] Kabelinstallation startet ohne aktive Xcode-Debugverbindung
- [ ] Neuinstallation nach Ablauf des Personal-Team-Profils ist dokumentiert
- [ ] Cloud-Dokumente bleiben bei Neuinstallation erhalten
- [ ] Rollback-, Backup- und Supportablauf vorhanden

## Freigabe

- Ergebnis: [ ] freigegeben [ ] abgelehnt [ ] freigegeben mit dokumentiertem Restrisiko
- Produkt: ____________________ Datum: __________
- Qualität: ___________________ Datum: __________
- Release: ___________________ Datum: __________

## Zusatzblatt für technische Fachmodule

Nur ausfüllen, wenn der Release Elektrotechnik-, Zeichen-, Mechanik-/Physik-, Mathematik- oder IT-Funktionen aktiviert:

- [ ] Modul-, Dokument-, Formel- und Symbolkatalogversion eingetragen
- [ ] Modulgrenzen und nicht unterstützte/sicherheitskritische Anwendungen in App und Release Notes sichtbar
- [ ] Nutzungsrechte für Symbole, Icons, Normbezug, Formeln und Referenzdaten belegt
- [ ] Normausgaben und Prüfdatum im Versionsregister festgehalten
- [ ] zwei fachkundige Reviews oder begründete gleichwertige unabhängige Prüfung dokumentiert
- [ ] Referenzkorpus, Dimensions-/Grenz-/Singularitätsfälle und zulässige Toleranzen bestanden
- [ ] `.birdtech`-Migration, beschädigte Pakete, unbekannte Katalogversion und Backup/Restore bestanden
- [ ] Parser-/Solverlimits, Fuzzing, Performance und Speicherbudgets bestanden
- [ ] PDF/SVG/PNG und gegebenenfalls Austauschformat auf Informationsverlust geprüft
- [ ] Keine Zertifizierungs-, Sicherheits- oder Konformitätsbehauptung ohne formalen Nachweis
