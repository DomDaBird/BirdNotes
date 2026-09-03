# Qualitätsmanagement für BirdNotes

Dieses Dokument schafft eine ISO-9001-nahe Arbeitsgrundlage. Es ist keine Zertifizierung: Zertifiziert wird das Qualitätsmanagementsystem der verantwortlichen Organisation durch eine unabhängige Stelle.

## Geltungsbereich und Qualitätsziel

Entwicklung, Test, Veröffentlichung, Betrieb und Support der BirdNotes-iPad-App. Qualitätsziel ist eine verständliche, offline-fähige Notiz-App, die Inhalte ohne stillen Datenverlust verarbeitet und vereinbarte Datenschutz- und Sicherheitsmerkmale einhält.

## Rollen – vor Marktstart namentlich besetzen

| Rolle | Verantwortung |
|---|---|
| Produktverantwortung | Anforderungen, Kundennutzen, Freigabeumfang |
| Entwicklungsverantwortung | Architektur, Implementierung, Wartbarkeit |
| Qualitätsverantwortung | Testnachweise, Abweichungen, Freigabeempfehlung |
| Sicherheits-/Datenschutzverantwortung | Risiken, Vorfälle, Policies, Rechtsabgleich |
| Release-Verantwortung | Signierung, App Store Connect, Rollback und Kommunikation |

Eine Person darf mehrere Rollen ausüben; die Freigabe risikoreicher Änderungen soll trotzdem durch eine zweite Prüfung belegt werden.

## Gesteuerte Prozesse

1. Anforderung mit Akzeptanzkriterien und Risiko erfassen.
2. Betroffene Datenflüsse, Datenschutzangaben und Bedrohungsmodell prüfen.
3. Änderung auf einem geschützten Branch entwickeln und testen.
4. Review, automatisches Qualitätsgate und gegebenenfalls Gerätetest durchführen.
5. Abweichungen mit Schweregrad, Entscheidung und Verantwortlichem dokumentieren.
6. Versioniert freigeben; Commit, Artefakt, Prüfer und Testergebnis aufbewahren.
7. Feedback, Fehler und Sicherheitsmeldungen auswerten; Korrektur- und Vorbeugemaßnahmen verfolgen.

Für technische Fachmodule kommen hinzu:

8. Norm-/Katalog-/Formelversion und Nutzungsrechte dokumentieren.
9. Fachreferenzfälle unabhängig prüfen und Reviewer/Ergebnis festhalten.
10. Gültigkeitsbereich, Annahmen und bewusst ausgeschlossene sicherheitskritische Anwendungen freigeben.
11. Änderungen an Formel-, Symbol- oder Solverversion wie eine Formatmigration behandeln und Regressionen nachweisen.

## Dokumentenlenkung

Quellcode, Architektur, Testplan, Bedrohungsmodell, Datenschutztext, Checklisten und Freigaben werden versioniert. Änderungen müssen Autor, Datum und Grund über Git nachvollziehbar machen. Freigaben und Auditnachweise dürfen nicht nachträglich überschrieben werden; Aufbewahrungsdauer vor Marktstart festlegen.

## Messung

Monatlich beziehungsweise je Release erfassen:

- Anteil erfolgreicher CI-Läufe und fehlgeschlagene Gates
- offene Fehler nach Schweregrad und mittlere Behebungszeit
- Crash-/Hang-freie Sitzungen, sobald datenschutzkonforme Messung eingerichtet ist
- Anzahl Datenverlust-, Sync- und Sicherheitsvorfälle
- Durchlaufzeit von Feedback bis Entscheidung
- bestandene Geräte-/OS-Kombinationen
- wiederkehrende Ursachen und Wirksamkeit abgeschlossener Maßnahmen
- bei Technikmodulen: fehlerhafte Referenzfälle, Rechenabweichungen, Katalog-/Normversionen und Fachreviewstatus

## Nichtkonformität und CAPA

Für einen schweren Defekt oder Vorfall werden Auswirkung, Eindämmung, Ursache, Korrektur, Verantwortlicher, Termin und Wirksamkeitsprüfung dokumentiert. Der Vorgang wird erst geschlossen, wenn ein Regressionstest existiert oder begründet dokumentiert ist, weshalb keiner möglich ist.

## Lieferanten

Aktuell gibt es keine externen Laufzeitbibliotheken. Apple/Xcode, App Store, iCloud und GitHub sind relevante Dienstleister. Vor Marktstart müssen Zweck, Datenzugriff, Verfügbarkeit, Vertrags-/Datenschutzlage, Änderungsbeobachtung und Exit-Strategie pro Lieferant bewertet werden.

## Managementbewertung

Mindestens quartalsweise sowie vor einer Hauptversion: Qualitätsziele, Kundenfeedback, Kennzahlen, Vorfälle, Lieferanten, Ressourcen, Risiken und Verbesserungsmaßnahmen prüfen und protokollieren.
