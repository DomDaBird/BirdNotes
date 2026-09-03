# SOC-2-/ISO-9001-Vorbereitungsmatrix

Status: **technisch umgesetzt**, **Prozess erforderlich**, **Release-Blocker** oder **später bei Backend**.

| Bereich | Nachweis im Repository | Status | Nächster Organisationsnachweis |
|---|---|---|---|
| Risikoanalyse | `docs/THREAT_MODEL.md` | technisch umgesetzt | regelmäßiges Reviewprotokoll |
| Änderungssteuerung | Git, CI, `scripts/check-project.sh`, `scripts/test.sh`, `scripts/verify.sh`, Testplan | technisch umgesetzt | Branchschutz, Reviews, Freigabetickets und archivierte Releaseergebnisse |
| Zugriffsschutz | App Sandbox, Security Scope, Keychain | technisch umgesetzt | Entwickler-/App-Store-Rollen und Rezertifizierung |
| Datenintegrität | koordinierte atomare Writes, sichtbare Konfliktauflösung, Validierung, Restore-Journal | technisch umgesetzt | Geräte- und Wiederherstellungstests je Release |
| Verfügbarkeit/Wiederherstellung | lokaler Betrieb, Papierkorb, ZIP-Backup und validierter In-App-Restore | technisch umgesetzt | Restore-Zielwerte und dokumentierte Wiederherstellungsübungen |
| Datenschutz | Privacy-Manifeste, `PRIVACY.md`, kein Tracking | technisch vorbereitet | verantwortliche Stelle, öffentliche URL, Rechtsprüfung |
| Schwachstellenmanagement | `SECURITY.md`, `scripts/check-security.sh`, Negativtests, Analyze | teilweise | privater Meldekanal, SLA, regelmäßiger externer Scan und Abhängigkeitsreview |
| Vorfallmanagement | Ablauf in `SECURITY.md` | Prozess erforderlich | Rollen, Rufbereitschaft, Tabletop-Übung, Nachweise |
| Lieferantenmanagement | keine externen Runtime-SDKs; Apple-Systemframeworks für iCloud und Vision | teilweise | Apple/GitHub-Bewertung und jährliches Review |
| Protokollierung/Monitoring | keine inhaltsbezogene Telemetrie | später bei Backend | datensparsames Konzept, Einwilligung/Policy, Alarmierung |
| Geschäftskontinuität | Offline-Betrieb | Prozess erforderlich | Schlüsselpersonen-, Repo-, Signing- und Support-Plan |
| Qualitätsziele | `docs/QUALITY_MANAGEMENT.md` | vorbereitet | benannte Rollen, Kennzahlen, Managementbewertung |
| Kundenfeedback | `FEEDBACK.md` | vorbereitet | Eingangskanal, Triage, Trendanalyse, CAPA-Verknüpfung |
| Releasefähigkeit | `docs/RELEASE_CHECKLIST.md` | vorbereitet | ausgefülltes, unveränderbares Releaseprotokoll |
| Fach-/Normenlenkung | `docs/STANDARDS_REGISTER.md`, Modulpläne, technisches Release-Zusatzblatt | geplant für Technikmodule | Lizenzbelege, Fachprüfer, Referenzkorpus und Versionsreview je Katalog |

SOC 2 bewertet Kontrollen einer Serviceorganisation über einen definierten Zeitraum; ein Quellcode-Stand allein kann keine SOC-2-Prüfung bestehen. Ohne eigenen Onlinedienst ist der aktuelle Scope klein. Sobald Konten, Synchronisationsserver, Telemetrie oder Monetarisierung hinzukommen, müssen Identitäten, Infrastruktur, Schlüssel, Logs, Backups, Verfügbarkeit, Datenschutz und Lieferanten in den Scope aufgenommen werden.
