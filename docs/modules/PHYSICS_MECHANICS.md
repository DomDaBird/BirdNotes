# Modulplan – Physik und Technische Mechanik

Status: geplant  
Modul-ID: `com.birdnotes.module.physics-mechanics`

## 1. Ziel

Das Modul erstellt Freikörperbilder, Vektor- und Bewegungsdiagramme und verknüpft diese mit einheitengeprüften Rechnungen. Es soll Studierende beim Modellieren und Nachvollziehen unterstützen: Was ist das System, welche Kräfte wirken, welche Annahmen gelten und wie entsteht das Ergebnis?

Es ist zunächst kein Finite-Elemente-, Tragwerks-, Maschinenfreigabe- oder Sicherheitsnachweiswerkzeug.

## 2. Zeichenobjekte

### Mechanik

- starrer Körper, Punktmasse, Stab, Balken, Seil und Feder,
- Festlager, Loslager, Einspannung, Gelenk und Führung,
- Einzelkraft, Moment, Strecken- und Dreieckslast,
- Gewichtskraft, Normalkraft, Reibkraft und Seilkraft,
- Koordinatensystem, Winkel, Abstand und Wirkungslinie,
- Schwerpunkt, Schnittufer und Reaktionskomponenten,
- Geschwindigkeits-, Beschleunigungs- und Impulsvektoren.

### Allgemeine Physik

- Strahl, Welle, Feldlinie und Potentialfläche als didaktische Objekte,
- elektrische/magnetische Vektoren in Verbindung mit dem Elektrotechnikmodul,
- Zustands- und Prozesspfeile für Thermodynamik,
- Behälter, Kolben, Rohr und Stromlinie für spätere Strömungslehre,
- Messpunkt, Sensor, Diagrammachse und Fehlerbalken.

## 3. Modellierungsablauf

1. Systemgrenze und Modellart wählen.
2. Körper/Geometrie und Bezugssystem platzieren.
3. Lager, Lasten, Vektoren und bekannte Größen zuordnen.
4. Annahmen aktiv bestätigen, zum Beispiel starr, reibungsfrei oder quasistatisch.
5. Unbekannte Größen markieren.
6. Modellvalidator ausführen.
7. Unterstützte Gleichungen aufstellen und lösen.
8. Ergebnis, Einheit, Vorzeichenkonvention und Rechenweg im Blatt anzeigen.

Ein frei gezeichneter Pfeil ist zunächst Annotation. Erst die bewusste Umwandlung in einen `ForceVector` macht ihn zur Rechengröße.

## 4. Berechnungsbereiche

### PM-1 Vektoren und Statik

- Komponenten, Betrag, Richtung und Projektion,
- Kräfteaddition und Moment um Punkt/Achse in 2D,
- Gleichgewichtsbedingungen in der Ebene,
- Lagerreaktionen statisch bestimmter einfacher Systeme,
- Schwerpunkt diskreter Massen und einfacher Flächen,
- Reibung mit klarer Haft-/Gleitannahme.

### PM-2 Kinematik und Kinetik

- gleichförmige und gleichmäßig beschleunigte Bewegung,
- Weg-, Geschwindigkeits- und Beschleunigungsdiagramme,
- Wurfbewegung ohne/mit ausdrücklich gewähltem vereinfachtem Widerstandsmodell,
- Kreisbewegung,
- Newtonsche Bewegungsgleichung für geprüfte 1D-/2D-Modelle,
- Arbeit, Energie, Leistung, Impuls und Stoßgrundfälle.

### PM-3 Festigkeitslehre

- Normal- und Schubspannung in einfachen Querschnitten,
- Dehnung, Hookesches Gesetz und Temperaturdehnung,
- Flächenträgheitsmomente ausgewählter Grundformen,
- Balkenlagerreaktionen, Querkraft- und Momentenverlauf,
- Spannungs-/Verformungsresultate nur für klar begrenzte Lehrfälle.

### PM-4 weitere Physik

- Schwingungen: Feder-Masse-Dämpfer-Grundmodelle,
- Thermodynamik: Zustandsgleichungen und einfache Prozesse,
- Strömung: Kontinuität und Bernoulli unter sichtbaren Annahmen,
- Optik/Wellen: Linsengleichung, Interferenz- und Wellenbasis,
- Messwertauswertung und Unsicherheitsfortpflanzung.

## 5. Validierungsregeln

- Vektoren benötigen Bezugskörper beziehungsweise Bezugssystem,
- Lager-/Gelenktypen erzeugen nur definierte Reaktionsfreiheitsgrade,
- dimensionsfalsche Lasten, Längen oder Winkel werden abgelehnt,
- geschlossene/unlösbare/unterbestimmte Gleichungssysteme werden unterschieden,
- Nullvektoren, parallele Wirkungslinien und singuläre Geometrie werden explizit behandelt,
- Modellannahmen müssen bei abhängigen Formeln gesetzt sein,
- Vorzeichenkonvention und Achsen sind vor der Rechnung sichtbar,
- Ergebnisse außerhalb definierter Modellgrenzen werden als „nicht unterstützt“ statt als Näherungszahl ausgegeben.

## 6. Standardisierte Tests

- Vektor-/Momentenfälle mit analytischen Referenzen,
- Freikörperbild-Graphintegrität bei Verschieben, Gruppieren und Löschen,
- statisch bestimmte Balken-/Lagerfälle mit unabhängiger Handrechnung,
- systematische Tests für Vorzeichen, Einheiten und Koordinatentransformation,
- Energie-/Impulserhaltung in dafür vorgesehenen Modellen,
- Solverstatus bei über-/unterbestimmten und singulären Systemen,
- Grenzwerte wie null Länge, null Masse, 90°/180°, sehr große/kleine Werte,
- Roundtrip, Migration, Export und Backup/Restore,
- Performance für große Vektordiagramme und lange Messreihen,
- barrierefreie Beschreibung von Vektorrichtung, Betrag, Körper und Ergebnisstatus.

## 7. Abnahmekriterien des ersten Releases

- Freikörperbilder lassen sich per Pencil schnell erstellen und anschließend semantisch korrigieren.
- Kräfte, Momente und Lager sind visuell und im Inspector eindeutig.
- mindestens 20 kuratierte Statik-/Kinematik-Referenzaufgaben bestehen mit dokumentierter Toleranz.
- Rechenweg und Modellannahmen bleiben mit dem Dokument gespeichert.
- der Nutzer kann zwischen frei gezeichneter Annotation und rechenaktivem Objekt unterscheiden.
- das Modul erzeugt keine Freigabe- oder Sicherheitsbehauptung für reale Konstruktionen.
