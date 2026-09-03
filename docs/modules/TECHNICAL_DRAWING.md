# Modulplan – Technisches 2D-Zeichnen

Status: geplant  
Modul-ID: `com.birdnotes.module.technical-drawing`

## 1. Ziel

Das Modul ermöglicht präzise technische Skizzen und 2D-Zeichnungen mit Pencil-orientierter Bedienung. Es ergänzt freie Handschrift um messbare Geometrie, Constraints, Layer, Bemaßung und sauberen Vektorexport. Der erste Scope ist 2D; parametrische 3D-Körper, Fertigungsfreigaben und professionelle CAD-Austauschgarantien sind nicht Teil des MVP.

## 2. Geometriewerkzeuge

- Punkt, Konstruktionspunkt und Bezugssystem,
- Linie, Polyline, Rechteck, Polygon und Freiformpfad,
- Kreis, Kreisbogen, Ellipse und Langloch,
- abgerundete Ecke, Fase, Trim, Extend, Offset und Spiegeln,
- Verschieben, Drehen, Skalieren und Muster,
- Hilfs-/Mittellinien und projizierte Geometrie,
- Schraffurflächen mit explizit geschlossenen Konturen,
- Text, Hinweis, Positionsnummer und Führungslinie.

### Snapping

- Raster, Endpunkt, Mittelpunkt, Zentrum und Schnittpunkt,
- Lotfuß, Tangente und nächster Punkt,
- Winkelraster und Achsenausrichtung,
- temporäre Hilfslinien,
- sichtbare Fangpriorität und Ausschaltmöglichkeit.

## 3. Geometrische Constraints

- horizontal, vertikal, parallel und lotrecht,
- koinzident, konzentrisch, tangential und kollinear,
- gleich lang, gleicher Radius, symmetrisch,
- feste Länge, Radius, Winkel und Abstand,
- fixierte Geometrie und Referenzmaß,
- Status `unterbestimmt`, `voll bestimmt`, `überbestimmt` oder `widersprüchlich`.

Der Solver arbeitet inkrementell und besitzt Iterations-/Zeitlimits. Er darf Geometrie bei einem Widerspruch nicht in einen nicht-finiten oder zerstörten Zustand versetzen. Die letzte gültige Lösung bleibt erhalten.

## 4. Bemaßung und Darstellung

- lineare, ausgerichtete, Winkel-, Radius- und Durchmesserbemaßung,
- Ketten-, Bezugs- und Koordinatenmaße in späterer Stufe,
- Maßtext, Präzision, Einheit und Skalierung,
- obere/untere Abweichung und allgemeine Toleranzfelder,
- Oberflächen-, Passungs- und Form-/Lagetoleranzsymbole erst nach fachlicher Spezifikation,
- sichtbare Unterscheidung von treibendem Maß und Referenzmaß,
- Linienarten, Strichstärken und Layerstile,
- Ansichtsrahmen, Schnittkennzeichnung und Detailausschnitt,
- A4/A3 zuerst; weitere normnahe Blätter nach Freigabe,
- Schriftfeld mit Dokumentnummer, Titel, Revision, Maßstab, Datum, Ersteller und Status.

## 5. Dokumentmodell

| Modell | Kerndaten |
|---|---|
| `GeometricEntity` | Typ, Kontrollpunkte, Layer, Stil und stabile ID |
| `GeometricConstraint` | Typ, referenzierte Entitäten/Subelemente, Zielwert und Status |
| `DimensionAnnotation` | Referenzen, Messwert, Darstellung, Toleranz und treibend/referenziert |
| `DrawingLayer` | Name, Farbe, Linienart, Sichtbarkeit, Sperre und Druckbarkeit |
| `DrawingSheet` | Format, Ausrichtung, Rahmen, Maßstab, Projektion und Schriftfeld |
| `DrawingView` | Ausschnitt, Transformation, Maßstab und Schnitt-/Detailbezug |

Geometrie wird in dokumentweiten Modellkoordinaten und einer kanonischen Längeneinheit gespeichert. Anzeigeeinheit und Blattmaßstab verändern die Geometrie nicht.

## 6. Ausbaustufen

### TD-1 Präzise Skizze

- Grundgeometrie, Snapping, Layer und Undo/Redo
- Längen-/Winkelanzeige und PDF/SVG/PNG
- A4/A3, Rahmen und einfaches Schriftfeld

### TD-2 Parametrische 2D-Zeichnung

- geometrische Constraints und Solverstatus
- treibende Bemaßungen
- Trim/Extend/Offset/Fillet/Fase
- Schraffuren und Schnitte

### TD-3 Dokumentationsqualität

- Toleranzen, erweiterte Maßketten und Revisionen
- Vorlagen und wiederverwendbare Blöcke
- Prüfstatus und Zeichnungsfreigabe-Workflow innerhalb des Dokuments

### TD-4 Austausch

- definierte, getestete DXF-Teilmenge
- Importvorschau mit Layer-/Einheitenmapping
- verlustbehaftete Elemente werden vor Import/Export explizit ausgewiesen

## 7. Normen und Lizenzgrenzen

- allgemeine Darstellung: [ISO 128-1:2020](https://www.iso.org/standard/65296.html),
- Bemaßung/Toleranzen: [ISO 129-1:2018](https://www.iso.org/standard/64007.html),
- Blattgrößen/Layout: [ISO 5457:1999](https://www.iso.org/standard/29017.html),
- Schriftfelder: [ISO 7200:2004](https://www.iso.org/standard/35446.html).

Vor jeder Konformitätsaussage werden Ausgabe, Änderungsstand und weitere anwendbare Teile geprüft. BirdNotes darf Normtexte, Tabellen oder geschützte Symbolsammlungen nicht ungeklärt kopieren. Der MVP verwendet eigene Vorlagen und beschreibt, an welchen Regeln sie sich orientieren.

## 8. Standardisierte Tests

- Geometrie-Invarianten für Translation, Rotation, Spiegelung und Skalierung,
- property-basierte Tests für Schnittpunkte, Projektionen und Snap-Toleranzen,
- Solverfälle für lösbar, unterbestimmt, überbestimmt, widersprüchlich und singulär,
- Undo/Redo stellt exakt den semantischen Vorzustand wieder her,
- Bemaßungswerte bleiben unabhängig von Zoom, Blattmaßstab und Anzeigeeinheit korrekt,
- Roundtrip- und Migrationstests für jede Geometrie-/Constraint-Art,
- Golden-Vector-Tests für Linienarten, Maße, Schraffuren, Rahmen und Schriftfeld,
- Performancebudget für 10.000 einfache Geometrieelemente und 2.000 Constraints,
- Import-Fuzzing für extreme Koordinaten, zyklische Blöcke und unerlaubte Ressourcen,
- Accessibility und Pencil-/Touch-Treffergenauigkeit bei unterschiedlichem Zoom.

## 9. Abnahmekriterien des MVP

- eine maßhaltige 2D-Bauteilskizze lässt sich ohne Tastatur erstellen,
- Snapping ist sichtbar und reproduzierbar,
- Constraints verlieren bei Speichern/Öffnen keine Referenzen,
- Maße stimmen mit der Modellgeometrie und Einheitenschicht überein,
- A4/A3-Ausgabe ist zentriert, maßstäblich definiert und vollständig,
- widersprüchliche Constraints erzeugen eine verständliche Meldung statt Geometrieschaden,
- der Export enthält keine aktiven Inhalte oder externen Referenzen.
