# Modulplan – Mathematik- und Einheitengrundlage

Status: geplant  
Abhängigkeit: Grundlage aller technischen Fachmodule

## 1. Ziel

Die Mathematikschicht stellt eine einzige, getestete Rechenbasis bereit. Elektrotechnik, Mechanik und IT dürfen keine eigenen widersprüchlichen Einheitenkonverter oder Formelparser entwickeln. Jede Rechnung soll Eingaben, Einheit, Annahmen, Ergebnisgenauigkeit, Warnungen und Rechenweg nachvollziehbar zeigen.

## 2. Funktionsumfang

### Größen und Einheiten

- sieben SI-Basisdimensionen und abgeleitete Dimensionen,
- SI-Präfixe einschließlich klarer Groß-/Kleinschreibung,
- Winkel, Prozent und dimensionslose Größen,
- affine Größen wie Celsius getrennt von Temperaturdifferenzen,
- benutzerseitige Anzeigeeinheit bei kanonischem internen Wert,
- konfigurierbare signifikante Stellen und wissenschaftliche Schreibweise,
- deutsch/englisch lokalisierte Ein- und Ausgabe ohne Mehrdeutigkeit im Dateiformat.

### Algebra und Numerik

- Grundrechenarten, Potenzen, Wurzeln, Logarithmen und trigonometrische Funktionen,
- komplexe Zahlen für spätere Wechselstromrechnung,
- Vektoren und Matrizen für Mechanik, Geometrie und Netze,
- lineare Gleichungssysteme mit Singularitätsprüfung,
- ein- und mehrdimensionale Interpolation in kontrollierten Grenzen,
- numerische Nullstellensuche mit Iterationslimit und Konvergenzstatus,
- Statistikbasis: Mittelwert, Median, Standardabweichung, lineare Regression und Unsicherheit.

### Didaktischer Rechenblock

- bekannte und gesuchte Größen auswählen,
- Gleichung aus geprüftem Formelkatalog wählen,
- Werte direkt oder über Diagrammelemente binden,
- automatische Dimensionsprüfung,
- Umstellung nur für freigegebene Gleichungsformen,
- Schrittansicht mit eingesetzten Werten,
- Ergebnisbox, die beim Ändern einer Eingabe aktualisiert wird,
- Ergebnis als Referenz in Notiz, Diagramm oder Tabelle einfügen.

## 3. Datenmodell

| Typ | Bedeutung |
|---|---|
| `DimensionVector` | ganzzahlige/rationale Exponenten der Basisdimensionen |
| `UnitDefinition` | stabile ID, Symbol, Dimension, Skala und gegebenenfalls Offset |
| `Quantity` | Dezimal-/Doublewert plus Dimension und bevorzugte Anzeigeeinheit |
| `ExpressionNode` | begrenzter Syntaxbaum statt frei ausführbarem Text |
| `VariableDefinition` | ID, Name, Dimension, Wertebereich und Beschreibung |
| `CalculationDefinition` | versionierte Formel, Inputs, Output, Bedingungen und Quelle |
| `CalculationInstance` | konkrete Eingaben, Bindungen, Ergebnisstatus und Trace |
| `CalculationTrace` | normalisierte Schritte, Einheitenumformung und Warnungen |

Persistente Dezimalwerte werden in einer kanonischen, locale-unabhängigen Form gespeichert. Für numerisch empfindliche Verfahren wird pro Definition festgelegt, ob `Decimal`, `Double` oder ein spezialisierter Vektor-/Matrixweg zulässig ist.

## 4. Parser- und Sicherheitsregeln

- keine allgemeine Skriptsprache und keine Reflection,
- feste Whitelist von Operatoren/Funktionen,
- maximale Ausdruckslänge, Tokenzahl, Baumtiefe und Variablenzahl,
- keine Rekursion aus Nutzereingaben,
- keine Datei-, Netzwerk-, Uhrzeit- oder Zufallszugriffe,
- Zeit-/Iterationsbudget für numerische Solver,
- Ablehnung nicht-finiter Ergebnisse und sichtbare Behandlung von Division durch null,
- keine implizite Addition inkompatibler Dimensionen,
- keine automatische Interpretation mehrdeutiger Symbole.

## 5. Ausbaustufen

### MATH-0 – Kern

- SI-Dimensionsmodell, Einheitenregistry und sichere Konvertierung
- Parser für Zahlen, Variablen und Grundoperatoren
- Rundung, Genauigkeit und Fehlerstatus
- Unit Tests und property-basierte Invarianten

### MATH-1 – Technische Rechnung

- freigegebener Formelkatalog
- Vektoren, Matrizen, komplexe Zahlen
- lineare Gleichungssysteme
- nachvollziehbarer Rechenweg

### MATH-2 – Graphen und Messwerte

- kartesische/polare Diagramme
- Tabellen, Regression und Unsicherheiten
- CSV-Import mit Größenlimit und Spaltenzuordnung

### MATH-3 – Fortgeschritten

- kontrollierte numerische Solver
- Differential-/Integralwerkzeuge für ausgewählte didaktische Fälle
- symbolische Umformungen nur über geprüfte Regeln

## 6. Standardisierte Tests

- jede SI-Basis- und freigegebene abgeleitete Einheit besitzt Roundtrip-Tests,
- `convert(a→b→a)` bleibt innerhalb definierter Toleranz,
- Addition/Mittelung erhält Dimension; inkompatible Dimensionen werden abgelehnt,
- bekannte Referenzwerte für Matrix-, Vektor- und komplexe Rechnungen,
- locale-basierte Eingaben `1,5` und `1.5` führen kontrolliert zur kanonischen Repräsentation,
- Parser-Fuzzing für Unicode, extreme Tiefe, lange Zahlen und ungültige Tokens,
- Solver melden Singularität, Divergenz, Iterationsende und Überlauf reproduzierbar,
- gespeicherte Ergebnisse werden nach Formelversionsänderung invalidiert,
- jeder Fachformeltest enthält Normalfall, Grenzfall, Dimensionsfehler und unabhängigen Referenzwert.

## 7. Abnahmekriterien

- keine Fachmodulrechnung umgeht `Quantity` und Dimensionsprüfung,
- identische Eingaben und Engineversion erzeugen reproduzierbare Resultate,
- jedes Resultat zeigt Einheit, Genauigkeit, Annahmen und Status,
- Fehler führen zu erklärbarer Meldung statt Crash oder stiller Zahl,
- Rechenblöcke bleiben nach Speichern, Migration, Export, Backup und Restore nachvollziehbar.

Als normative Größen-/Einheitenbasis dient die jeweils im Versionsregister festgehaltene Ausgabe der [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/).
