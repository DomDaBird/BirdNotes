# BirdNotes – Normen-, Katalog- und Quellenregister

Stand der Recherche: 27. August 2026  
Status: Planungsregister, keine Konformitätserklärung

Dieses Register wird vor jedem technischen Modulrelease geprüft und mit Releasecommit, Prüfer und Lizenznachweis archiviert. Eine Referenz in diesem Dokument erlaubt weder das Kopieren geschützter Inhalte noch die Behauptung, BirdNotes oder ein erzeugtes Dokument sei normkonform.

## 1. Aktuelle Referenzen

| ID | Bereich | Referenz/Ausgabe | Geplanter Zweck | Rechte-/Prüfstatus | Produktbehauptung |
|---|---|---|---|---|---|
| STD-EL-001 | elektrotechnische Symbole | [IEC 60617 Database](https://webstore.iec.ch/en/publication/2723), bei Recherche als 2026-Datenbank veröffentlicht | Symbolklassen, Benennung und fachliche Orientierung | IEC-Lizenz vor Nutzung offizieller Grafiken/Daten erforderlich; derzeit nicht freigegeben | MVP nur „BirdNotes Elektrotechnik-Lernkatalog“ |
| STD-EL-002 | elektrotechnische Dokumente | [IEC 61082-1:2014](https://webstore.iec.ch/en/publication/4469) | Präsentation elektrotechnischer Dokumente, Diagramme, Zeichnungen und Tabellen | Normzugang, anwendbare Teile und aktuelle Ausgabe vor Implementierung prüfen | keine Konformitätsaussage ohne dokumentierte Prüfung |
| STD-TD-001 | technische Darstellung | [ISO 128-1:2020](https://www.iso.org/standard/65296.html) | allgemeine Darstellungsregeln für technische Zeichnungen | offizielle Ausgabe für Detailimplementierung beschaffen; Rechte prüfen | „orientiert an“ nur nach Review |
| STD-TD-002 | Bemaßung/Toleranzen | [ISO 129-1:2018](https://www.iso.org/standard/64007.html) | allgemeine Darstellung von Maßen und Toleranzen | ISO-Seite weist Revisionsarbeit aus; Stand vor Release erneut prüfen | keine vollständige GPS-/Toleranzkonformität im MVP |
| STD-TD-003 | Blatt/Layout | [ISO 5457:1999](https://www.iso.org/standard/29017.html) | Zeichnungsblätter, Rahmen und Layout | Ausgabe befindet sich laut ISO-Status in Überprüfung; Nachfolger/Änderungen prüfen | eigene A4/A3-Vorlage bis zur Freigabe |
| STD-TD-004 | Schriftfeld | [ISO 7200:2004](https://www.iso.org/standard/35446.html) | Datenfelder in Schriftfeldern und Dokumentköpfen | aktuelle Bestätigung und anwendbare Felder dokumentieren | kompatible Feldstruktur, keine automatische Normfreigabe |
| STD-MA-001 | Größen/Einheiten | [BIPM SI Brochure, 9th edition](https://www.bipm.org/en/publications/si-brochure/) | kanonische SI-Basis, Definitionen und Schreibweise | frei zugängliche aktuelle Fassung/Errata je Engineversion archivieren und Lizenzhinweise beachten | SI-basierte Einheitenschicht nach Test/Fachreview |
| STD-IT-001 | Softwaremodellierung | [OMG UML 2.5.1](https://www.omg.org/spec/UML/) | Semantik einer ausdrücklich begrenzten UML-Teilmenge | normative Dokumente und maschinenlesbare Artefakte gegen Modulumfang prüfen | „UML-2.5.1-Teilmenge“, niemals vollständige Implementierung ohne Nachweis |

## 2. Pflichtfelder pro ausgeliefertem Katalog

| Feld | Beispiel/Bedeutung |
|---|---|
| Katalog-ID | stabile Reverse-DNS-ID |
| Katalogversion | semantische Version, im Dokument gespeichert |
| Referenz-ID | eine oder mehrere `STD-*`-Zeilen dieses Registers |
| verwendete Ausgabe | exakte Nummer, Jahr, Amendments/Errata |
| Bezugsdatum | Datum der inhaltlichen Prüfung |
| Lizenzbeleg | Ablageort/Vertragsreferenz, nicht geheime Vertragsdetails im öffentlichen Repo |
| fachlicher Prüfer | Name/Rolle und Freigabedatum im internen Release-Nachweis |
| unterstützte Teilmenge | konkrete Symbole, Regeln oder Diagrammarten |
| bekannte Abweichungen | bewusst nicht unterstützte/anders dargestellte Punkte |
| Tests | Referenzkorpus, Golden Files und Katalogvalidierung |
| UI-Kennzeichnung | Lernkatalog, normorientiert oder formal verifiziert |

## 3. Freigabeprozess

1. Produktumfang und beabsichtigte Aussage festlegen.
2. Aktuellen Status auf der offiziellen Herausgeberseite prüfen.
3. Benötigte Ausgabe rechtmäßig beschaffen und Nutzungsrecht dokumentieren.
4. Nur die tatsächlich benötigte Teilmenge spezifizieren.
5. Vektorgrafiken und Katalogdaten mit geklärter Urheberschaft erstellen.
6. Fachreview und Referenztests durchführen.
7. Abweichungen und UI-Kennzeichnung freigeben.
8. Katalogversion an Dokument-, App- und Testversion binden.
9. Bei Normänderung Auswirkung analysieren; bestehende Dokumente nicht still umdeuten.

## 4. Noch zu ergänzende Referenzfamilien

Erst bei tatsächlicher Priorisierung werden offizielle Referenzen für folgende Bereiche aufgenommen: geometrische Produktspezifikation, Oberflächen/Schweißen, Fluid-/Prozesssymbole, Regelungs-/Signalflussdarstellung, Messunsicherheit, ER-/BPMN-/SysML-Notation, Netzwerktechnik und digitale Logik. Eine Internetfundstelle oder verbreitete Praxis genügt nicht als alleinige Freigabegrundlage.
