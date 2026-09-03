# BirdNotes Release-Testnachweis

Status: **NICHT AUSGEFÜHRT**

## Identität

- Nachweis-ID:
- Version / Build:
- Commit:
- Datum / Zeitzone:
- Tester / Review:
- Ergebnis: [ ] bestanden [ ] abgelehnt [ ] offen
- Verknüpfte Abweichungen:

## Umgebung

| Rolle | Gerät | Modell | OS | Speicher frei | Buildquelle |
|---|---|---|---|---:|---|
| Referenz-iPad | | | | | |
| zweites iCloud-Gerät | | | | | |
| TestFlight-Gerät | | | | | |

## Automatisches Gate

- Start/Ende:
- `./scripts/verify.sh`: [ ] bestanden [ ] fehlgeschlagen
- Protokoll/Artefakt:
- Bemerkung:

## Performance und Speicher

| Fixture | Start | Peak | nach Ruhe | Hänger ≥ 250 ms | Leaks | Materialisierung | Trace |
|---|---:|---:|---:|---:|---:|---:|---|
| 100 Seiten | | | | | | | |
| 500 Seiten | | | | | | | |
| 1.000 Bibliothekseinträge | | | | | | n/a | |
| 2.000 Canvasobjekte | | | | | | sichtbare Objekte/Connectoren: | |

- Speicherdruck-Ergebnis:
- `./scripts/test.sh asan`: [ ] bestanden [ ] fehlgeschlagen [ ] offen
- `./scripts/test.sh tsan`: [ ] bestanden [ ] fehlgeschlagen [ ] offen
- Sanitizer-`.xcresult`/Protokoll:
- 30-Minuten-Soak:
- 100 Lifecycle-Wechsel:
- Datenvergleich nach Neustart:
- Ergebnis: [ ] bestanden [ ] fehlgeschlagen [ ] offen

## Accessibility und Bedienung ohne Pencil

| Fall | Hoch | Quer | Split View | Beleg/Abweichung |
|---|---|---|---|---|
| VoiceOver Kernablauf | | | | |
| VoiceOver Seitennavigation | | | | |
| Dynamic Type maximal | | | | |
| Finger zeichnet ein/aus | | | | |
| Handwerkzeug | | | | |
| Externe Tastatur | | | | |
| Kontrast/Graustufen | | | | |
| Bewegung/Transparenz reduzieren | | | | |

- Ergebnis: [ ] bestanden [ ] fehlgeschlagen [ ] offen

## iCloud und Recovery

| Fall | Ergebnis | Synchronisationszeit | Beleg/Abweichung |
|---|---|---:|---|
| A nach B | | | |
| parallele Offline-Änderung | | | |
| aktuelle Version behalten | | | |
| andere Version behalten | | | |
| Finder/Dateien-Änderung | | | |
| entzogenes Security Scope | | | |
| Ordner erneut wählen | | | |
| lokaler Fallback | | | |
| Neustart/offline/online | | | |
| Backup/Restore-Stichprobe | | | |

- Ergebnis: [ ] bestanden [ ] fehlgeschlagen [ ] offen

## Gerätesignierung und Kabelinstallation

| Fall | Ergebnis | Beleg/Abweichung |
|---|---|---|
| Personal-Team-Signierung | | |
| Installation per USB-C | | |
| Start ohne Debugverbindung | | |
| Cloud-Ordner nach Neustart | | |
| PDF vom Mac sichtbar | | |
| iPad-Notiz am Mac sichtbar | | |
| entzogenes Security Scope | | |
| Neuinstallation mit bestehenden Cloud-Daten | | |

- Ablaufdatum des Profils:
- Cloud-Pfad auf Mac/iPad:
- Ergebnis: [ ] bestanden [ ] fehlgeschlagen [ ] offen

## Abweichungen und Freigabe

| ID | Priorität | Befund/Risiko | Eigentümer | Zieltermin | Entscheidung |
|---|---|---|---|---|---|
| | | | | | |

- Produkt: ____________________ Datum: __________
- Qualität: _________________ Datum: __________
- Release: ____________________ Datum: __________
