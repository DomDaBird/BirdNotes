# Modulplan – IT, Informatik und Digitaltechnik

Status: geplant  
Modul-ID: `com.birdnotes.module.information-technology`

## 1. Ziel

Das IT-Modul bündelt Diagramme und kleine, lokal berechnete Lernwerkzeuge für Softwareentwicklung, Datenbanken, Netzwerke, Digitaltechnik und Cyber Security. Es soll Strukturen semantisch verstehen und konsistent halten, aber keinen Code aus Dokumenten ausführen und keine echten Systeme automatisch scannen.

## 2. Diagrammarten

### Software und Prozesse

- Ablaufdiagramm mit Start/Ende, Prozess, Entscheidung, Ein-/Ausgabe und Verbinder,
- UML-Teilmenge: Klassen-, Objekt-, Komponenten-, Paket-, Use-Case-, Aktivitäts-, Sequenz- und Zustandsdiagramm,
- C4-nahe Kontext-, Container- und Komponentensichten als eigener BirdNotes-Katalog,
- Datenfluss-, Deployment- und Architekturdiagramme,
- Pseudocode-/Codeblock als Textobjekt mit Syntaxhervorhebung, ohne Ausführung.

### Datenbanken

- Entity-Relationship-Diagramm,
- Entitäten, Attribute, Schlüssel und Beziehungen,
- Kardinalitäten und Optionalität,
- Tabellen-/Schemaansicht und einfache Normalisierungsnotizen,
- SQL-DDL-Export erst nach eindeutig definiertem Dialekt und Vorschau.

### Netzwerke und Infrastruktur

- Hosts, Clients, Server, Router, Switches, Firewall, Access Point und Cloud-Grenze,
- Subnetze, VLANs, Sicherheitszonen und Vertrauensgrenzen,
- physische und logische Verbindungen,
- IP-/CIDR-Annotationen und Port-/Protokollfelder,
- Bedrohungsmodellansicht mit Assets, Akteuren, Datenflüssen und Controls,
- keine aktive Discovery, kein Portscan und kein Credential-Import.

### Digitaltechnik

- AND, OR, NOT, NAND, NOR, XOR und XNOR,
- Flipflops, Multiplexer, Decoder, Zähler und Register in späteren Katalogen,
- Wahrheitstabellen, Boolesche Ausdrücke und Timingdiagramme,
- Übergabe grundlegender elektrischer Netze an das Elektrotechnikmodul nur über versionierte Adapter.

## 3. Rechner und Lernwerkzeuge

- Binär-, Oktal-, Dezimal- und Hexadezimalkonvertierung,
- Zweierkomplement, Bitmasken, Shifts und Wertebereiche,
- Boolesche Ausdrücke, Wahrheitstabellen und vereinfachte Formen in begrenztem Umfang,
- IPv4-/IPv6-CIDR, Netz-/Hostbereich und Subnetzaufteilung,
- Datenmenge, Übertragungsrate, Laufzeit und Overhead,
- RAID-Kapazität als Lernmodell mit klaren Ausfallannahmen,
- Speicher-/Cache-/Adressraumrechnungen,
- Laufzeitkomplexitäts-Notizen und Wachstumsvergleich,
- Unicode-/Byte-Darstellung und einfache Checksummen als didaktische Werkzeuge,
- keine Passwort-, Schlüssel- oder echte Geheimnisverarbeitung in Dokumentrechnern.

## 4. Semantische Regeln

- Verbindungen erlauben nur für den Diagrammtyp gültige Endpunkte,
- UML-Mitglieds-/Beziehungsarten werden typisiert statt nur beschriftet,
- Sequenznachrichten referenzieren vorhandene Lifelines und besitzen Ordnung,
- Zustandsübergänge referenzieren Quell-/Zielzustand und optional Guard/Aktion,
- ER-Beziehungen besitzen gültige Kardinalitäten und referenzierte Schlüssel,
- Netzwerkinterfaces gehören zu genau einem Knoten; Adresskonflikte werden gemeldet,
- CIDR-Rechner lehnt ungültige Präfixe und uneindeutige Eingaben ab,
- Wahrheitstabellen begrenzen Variablenzahl und Ergebnisgröße,
- gelöschte Elemente hinterlassen keine stillen Beziehungen.

## 5. Standardbezug

Für UML wird die [OMG UML Specification 2.5.1](https://www.omg.org/spec/UML/) als Referenz geführt. BirdNotes implementiert zunächst ausdrücklich nur eine dokumentierte Teilmenge. SysML, BPMN, ArchiMate oder herstellerspezifische Cloud-Icons werden erst nach eigener Scope-, Lizenz- und Interoperabilitätsprüfung aufgenommen.

Herstellerlogos werden nicht automatisch als frei verwendbar angesehen. Der Grundkatalog nutzt neutrale BirdNotes-Symbole; optionale Markenpakete benötigen Nutzungsrecht und Brand-Guideline-Prüfung.

## 6. Cyber-Security-Funktionen

- Datenfluss-/Trust-Boundary-Zeichnung,
- STRIDE-orientierte Bedrohungsnotizen als optionaler, lokaler Fragenkatalog,
- Asset-, Risiko-, Control- und Nachweisobjekte,
- Risikomatrix mit dokumentierter Bewertungslogik,
- Verknüpfung eines Findings mit Diagrammelement und Abhilfemaßnahme,
- Export eines lesbaren Berichts ohne versteckte aktive Inhalte,
- kein automatisches Versprechen von SOC-2-, ISO-27001- oder sonstiger Compliance.

## 7. Ausbaustufen

### IT-1 Grundlagen

- Ablaufdiagramm, Netzwerkgrundelemente, Zahlensystem-/CIDR-Rechner
- gemeinsame Auswahl-, Snap-, Layer- und Exportfunktionen

### IT-2 Softwaremodellierung

- UML-Klassen-, Sequenz-, Aktivitäts- und Zustandsdiagramm als klar definierte Teilmenge
- Modellvalidator und Querverweise

### IT-3 Daten und Digitaltechnik

- ER-Modell und kontrollierter DDL-Export
- Logikgatter, Wahrheitstabellen und Timingdiagramme

### IT-4 Architektur und Security

- Infrastruktur-, Datenfluss- und Bedrohungsmodelle
- Risiko-/Control-Verknüpfung und Berichtsexport

## 8. Standardisierte Tests

- je Diagrammtyp gültige/ungültige Verbindungen und referenzielle Integrität,
- stabile Reihenfolge in Sequenz-, Ablauf- und Zustandsdiagrammen,
- CIDR-Referenzvektoren für IPv4/IPv6 einschließlich Grenzpräfixen,
- Zahlensystem-/Zweierkomplementtests für Min/Max, Vorzeichen und Überlauf,
- Wahrheitstabellen gegen unabhängige Referenzen sowie strikte Variablenlimits,
- UML-/ER-Roundtrip ohne Beziehungsverlust,
- Exporttests für Labels, Multiplizitäten, Pfeilarten und Trust Boundaries,
- Parser-Fuzzing für Codeblöcke, Namen, Unicode und extrem große Tabellen,
- Security: keine URL-Auflösung, Codeausführung, Scans oder eingebettete aktive Inhalte,
- Accessibility: Beziehungen werden nicht nur durch Linie/Farbe, sondern sprachlich beschrieben.

## 9. Abnahmekriterien des MVP

- Ablauf- und Netzwerkdiagramme lassen sich vollständig per Touch/Pencil erstellen.
- der CIDR-/Zahlensystemrechner liefert geprüfte Werte mit Rechenweg.
- ungültige Beziehungen werden verständlich markiert, nicht still korrigiert.
- Speichern, Migration, Backup, Restore und Export erhalten alle semantischen Beziehungen.
- importierter Text oder Diagramminhalt kann niemals Code oder Netzwerkaktionen auslösen.
- die unterstützte UML-/Diagrammteilmenge ist in der App sichtbar dokumentiert.
