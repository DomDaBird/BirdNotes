# Modulplan – Elektrotechnik und Elektronik

Status: geplant  
Modul-ID: `com.birdnotes.module.electrical`

## 1. Ziel

Das Elektrotechnikmodul verbindet handschriftliche Vorlesungsnotizen mit semantischen Schaltplänen und nachvollziehbaren Rechnungen. Ein Draht ist eine elektrische Verbindung, ein Bauteil besitzt definierte Anschlüsse und Eigenschaften und ein Ergebnis verweist auf die zugehörigen Netze und Bauteile.

Die erste Version ist für Ausbildung, Studium, Dokumentation und ungefährliche Kleinspannungsentwürfe. Sie ersetzt weder Elektrofachplanung noch Schutz-, Norm- oder Sicherheitsnachweise.

## 2. Editorfunktionen

- Symbolbibliothek mit Suche, Favoriten und zuletzt verwendet,
- Platzieren, Drehen, Spiegeln, Ausrichten und Verteilen,
- elektrische Ports und fangende Anschlussziele,
- orthogonale Leitungen, Wegpunkte, Abzweige und eindeutig sichtbare Junctions,
- Netzlabels, Potentiale, Busse und Off-Page-Referenzen,
- automatische Referenzkennzeichen wie `R1`, `C3`, `U2`,
- Werte und Einheiten direkt im Inspector,
- hierarchische Funktionsblöcke in einer späteren Stufe,
- getrennte Ebenen für Schaltung, Messwerte, Kommentare und Handschrift,
- Stückliste und Netzliste aus dem semantischen Modell,
- PDF/SVG/PNG-Export; textbasierte Netzliste für freigegebene Teilmengen.

## 3. Symbolbereiche

### MVP-Lernkatalog

- Bezugspotential, Masse, Verbindung und Knoten,
- Gleichspannungs-/Stromquelle,
- Widerstand, Potentiometer, Kondensator und Spule,
- Schalter, Taster und Sicherung als didaktische Symbole,
- Diode, LED, Zenerdiode,
- NPN-/PNP-Bipolartransistor und N-/P-Kanal-MOSFET,
- idealer Operationsverstärker,
- Voltmeter, Amperemeter und Oszilloskop-Messpunkt,
- einfache Logikgatter als Brücke zum IT-Modul.

### Spätere Kataloge

- Transformatoren, Motoren, Relais und Optokoppler,
- analoge IC-Blöcke, Sensoren, Aktoren und Steckverbinder,
- Digitalelektronik, Flipflops, Zähler und Speicherblöcke,
- Mikrocontroller- und Busschnittstellen,
- Steuerungs-/Automatisierungstechnik,
- Signalfluss- und Regelungsblöcke,
- Installations- oder Energieverteilungssymbole erst nach gesondertem Sicherheits- und Normprojekt.

Jedes Symbol besitzt stabile Katalog-ID, Katalogversion, Portrollen, Defaultwerte, erlaubte Eigenschaften, Suchbegriffe und eine eigenständig erzeugte Vektorgeometrie. Normgrafiken werden nicht ohne geklärte Lizenz kopiert.

## 4. Elektrisches Datenmodell

| Modell | Kerndaten |
|---|---|
| `ElectricalComponent` | Symbol-ID, Referenzkennzeichen, Wert, Toleranz, Eigenschaften, Ports |
| `ElectricalPort` | Rolle, Domäne, Richtung, Anschlussstatus und Net-ID |
| `ElectricalNet` | UUID, Label, verbundene Ports, optionale Potential-/Signalmetadaten |
| `WireSegment` | Net-ID, orthogonale/freie Wegpunkte und Junction-Regeln |
| `ElectricalAnalysis` | Analyseart, Eingänge, Quellen, gesuchte Größen und Rechenstatus |
| `BillOfMaterialsEntry` | Referenzen, Typ, Wert, optionale Herstellerdaten ohne automatischen Netzabruf |

Kreuzende Leitungen sind ohne Junction nicht verbunden. Ein verschobenes Bauteil behält seine Port-/Netzidentität; der sichtbare Leitungsweg wird angepasst, ohne das Netz still zu trennen.

## 5. Electrical Rule Check (ERC)

Der ERC meldet Fehler, Warnungen und Hinweise, unter anderem:

- unverbundener Pflichtport oder frei hängendes Leitungsende,
- doppelte Referenzkennzeichen,
- leeres oder ungültiges Netzlabel,
- verbundene Ports inkompatibler Domäne,
- ideale Spannungsquellen mit widersprüchlichen Potentialen,
- Stromquelle ohne geschlossenen Pfad in einer unterstützten Analyse,
- Kurzschluss eines Bauteils beziehungsweise einer Quelle,
- fehlendes Bezugspotential für nodale Berechnung,
- nicht gesetzter oder dimensionsfalscher Bauteilwert,
- mehrere Ausgänge auf einem Digitalnetz, sofern nicht ausdrücklich zulässig,
- veralteter/unbekannter Symbolkatalog.

Warnungen dürfen die Bearbeitung nicht unnötig blockieren. Export und Berechnung zeigen jedoch einen sichtbaren Prüfstatus.

## 6. Berechnungen

### E-1 Gleichstromgrundlagen

- Ohmsches Gesetz und elektrische Leistung,
- Reihen-/Parallelschaltung von Widerständen,
- Spannungsteiler und Stromteiler,
- Kirchhoffsche Knoten- und Maschenregeln,
- lineare DC-Netze aus idealen Quellen und Widerständen,
- Quellumwandlung sowie Thevenin-/Norton-Ersatz für geprüfte Fälle,
- Messpunktwerte direkt im Plan.

### E-2 Wechselstrom und Signale

- Impedanz von R, L und C,
- komplexe Zeigerrechnung, Betrag und Phase,
- RC/RL/RLC-Grundschaltungen und Frequenzgang,
- Wirk-, Blind- und Scheinleistung,
- Bode-Darstellung ausgewählter linearer Netzwerke.

### E-3 Elektronik

- idealisierte Dioden-/Transistor-Arbeitspunkte,
- Operationsverstärker-Grundschaltungen unter klaren Annahmen,
- Logikpegel, Wahrheitstabellen und einfache Timingdiagramme,
- keine vollständige SPICE-Kompatibilität in der ersten Fassung.

### E-4 Erweiterte Lehre

- Dreiphasen-Grundlagen,
- Übertragungsfunktionen und Regelungstechnik,
- Zustandsmodelle und Signalanalyse,
- Import/Export einer klar definierten Netzlisten-Teilmenge.

## 7. Standards, Lizenzen und Sicherheit

- Referenz für grafische Symbole ist die [IEC 60617 Database](https://webstore.iec.ch/en/publication/2723); deren Inhalte werden nur nach Lizenzprüfung übernommen.
- Regeln elektrotechnischer Dokumentation werden gegen [IEC 61082-1](https://webstore.iec.ch/en/publication/4469) geprüft.
- BirdNotes führt ein Versions- und Lizenzregister pro Katalog.
- Der MVP heißt ausdrücklich „BirdNotes Elektrotechnik-Lernkatalog“ und behauptet keine IEC-Konformität.
- Berechnungen zu Netzspannung, Schutzleiter, Kurzschlussstrom, Selektivität, Leitungsdimensionierung oder Personenschutz sind zunächst ausgeschlossen.
- Ergebnisse enthalten den Hinweis, dass Aufbau und Inbetriebnahme fachkundig und nach lokalen Vorschriften geprüft werden müssen.

## 8. Standardisierte Tests

- Symbolkatalog: eindeutige IDs, gültige Portpositionen, vollständige Lokalisierung und renderbare Geometrie,
- Graph: Verbinden/Trennen, Junction, Kreuzung ohne Verbindung, Verschieben, Copy/Paste und Undo/Redo,
- ERC: je Regel mindestens positiver und negativer Fall,
- Berechnung: handgerechnete Referenznetzwerke, KCL-/KVL-Restfehler und dimensionsfalsche Werte,
- Roundtrip: Plan speichern, neu öffnen, duplizieren, migrieren, sichern und wiederherstellen,
- Export: sichtbare Verbindungen/Labels sowie stabile PDF-/SVG-Szene,
- Performance: mindestens 1.000 Komponenten und 2.000 Verbindungen innerhalb festgelegter Budgets,
- Security: zyklische/ungültige Referenzen, extreme Netze, nicht-finite Werte, Parserlimits und beschädigte Ressourcen,
- Accessibility: jeder Port, jedes Bauteil und jede ERC-Meldung per VoiceOver und Tastatur erreichbar.

## 9. Abnahmekriterien des MVP

- Ein vollständiges lineares DC-Netz kann per Pencil/Touch erstellt und korrekt verbunden werden.
- Referenzkennzeichen und Werte bleiben nach allen Dateioperationen stabil.
- ERC erkennt die definierten Fehler ohne den Editor abstürzen zu lassen.
- Mindestens zehn unabhängig geprüfte Referenzschaltungen liefern Ergebnisse innerhalb dokumentierter Toleranzen.
- Freie Handschrift bleibt getrennt editierbar.
- PDF/SVG/PNG und Netzliste verlieren keine wesentlichen Labels oder Verbindungen.
- Kein ungeklärtes Normsymbol oder fremdes Asset wird ausgeliefert.
