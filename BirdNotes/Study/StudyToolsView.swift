import SwiftUI
import BirdNotesTechnicalCore

struct StudyToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    private let curriculum: StudyCurriculum?

    init() {
        curriculum = try? StudyCurriculum.softwareDevelopment2026()
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                curriculumView
                    .tabItem { Label("Module", systemImage: "graduationcap") }
                    .tag(0)
                StudyToolListView()
                    .tabItem { Label("Werkzeuge", systemImage: "wrench.and.screwdriver") }
                    .tag(1)
            }
            .navigationTitle("Studien-Werkzeuge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var curriculumView: some View {
        if let curriculum {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(curriculum.title)
                            .font(.headline)
                        Text("Modulhandbuch vom \(curriculum.handbookDate). Pflichtmodule und wichtige Vertiefungen sind passenden BirdNotes-Werkzeugen zugeordnet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                ForEach(StudyPhase.allCases, id: \.rawValue) { phase in
                    let modules = curriculum.modules(in: phase)
                    if !modules.isEmpty {
                        Section(phase.title) {
                            ForEach(modules) { module in
                                NavigationLink {
                                    StudyModuleDetailView(module: module)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(module.title)
                                        HStack(spacing: 8) {
                                            Text(module.code)
                                            Text("\(module.credits) CP")
                                            Text(module.area.title)
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "Studienkatalog nicht verfügbar",
                systemImage: "exclamationmark.triangle",
                description: Text("Der lokale Modulkatalog konnte nicht sicher geladen werden.")
            )
        }
    }
}

private struct StudyModuleDetailView: View {
    let module: StudyModuleRecord

    var body: some View {
        List {
            Section("Modul") {
                LabeledContent("Code", value: module.code)
                LabeledContent("Abschnitt", value: module.phase.title)
                LabeledContent("Umfang", value: "\(module.credits) CP / ca. \(module.credits * 30) Stunden")
                LabeledContent("Bereich", value: module.area.title)
            }
            Section("Themenschwerpunkte") {
                ForEach(module.focus, id: \.self) { focus in
                    Label(focus, systemImage: "checkmark.circle")
                }
            }
            Section("Passende BirdNotes-Werkzeuge") {
                ForEach(module.tools, id: \.rawValue) { tool in
                    Label(tool.title, systemImage: tool.systemImage)
                }
            }
        }
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StudyToolListView: View {
    var body: some View {
        List {
            Section("Lernen & Wiederholen") {
                toolLink("Wiederholungsplan", "calendar.badge.clock", ReviewPlannerView())
                toolLink("Active Recall & Feynman", "brain.head.profile", StudyChecklistView.learning)
            }
            Section("Planung & wissenschaftliches Arbeiten") {
                toolLink("CP- und Wochenplaner", "calendar.badge.clock", StudyWorkloadView())
                toolLink("Wissenschafts-Checkliste", "text.book.closed", StudyChecklistView.scientific)
            }
            Section("Software Engineering") {
                toolLink("Anforderungs-Check", "checklist.checked", RequirementReviewView())
                toolLink("Test- und Qualitätsmatrix", "checkmark.shield", StudyChecklistView.quality)
                NavigationLink {
                    DiagramToolInfoView()
                } label: {
                    Label("Diagrammwerkzeuge", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            Section("Programmierung, Daten & Infrastruktur") {
                toolLink("Komplexitätsrechner", "chart.line.uptrend.xyaxis", ComplexityCalculatorView())
                toolLink("Zahlensystem-Konverter", "number.square", NumberSystemConverterView())
                toolLink("JSON prüfen und formatieren", "curlybraces.square", JSONFormatterView())
                toolLink("Deskriptive Statistik", "chart.bar.xaxis", StatisticsCalculatorView())
                toolLink("IPv4/CIDR-Rechner", "network", NetworkCalculatorView())
            }
            Section {
                Text("Alle Berechnungen laufen lokal. Die Ergebnisse sind Lernhilfen und ersetzen keine fachliche, sicherheitsrelevante oder wissenschaftliche Prüfung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toolLink<Destination: View>(
        _ title: String,
        _ systemImage: String,
        _ destination: Destination
    ) -> some View {
        NavigationLink { destination } label: { Label(title, systemImage: systemImage) }
    }
}

private extension StudyToolIdentifier {
    var systemImage: String {
        switch self {
        case .workloadPlanner: "calendar.badge.clock"
        case .requirementsReview: "checklist.checked"
        case .softwareDiagram: "point.3.connected.trianglepath.dotted"
        case .databaseDiagram: "cylinder.split.1x2"
        case .devOpsPipeline: "arrow.triangle.branch"
        case .testingMatrix: "checkmark.shield"
        case .complexityEstimator: "chart.line.uptrend.xyaxis"
        case .numberSystems: "number.square"
        case .statistics: "chart.bar.xaxis"
        case .networkCalculator: "network"
        case .threatModel: "lock.trianglebadge.exclamationmark"
        case .researchChecklist: "text.book.closed"
        case .reviewPlanner: "calendar.badge.clock"
        case .jsonFormatter: "curlybraces.square"
        case .learningMethods: "brain.head.profile"
        }
    }
}

private struct ReviewPlannerView: View {
    @State private var startDate = Date()
    @State private var confidence: ReviewConfidence = .good
    @State private var sessionCount = 6
    @State private var schedule: StudyReviewSchedule?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Lernstand") {
                DatePicker("Erste Lerneinheit", selection: $startDate, displayedComponents: .date)
                Picker("Wie sicher sitzt das Thema?", selection: $confidence) {
                    ForEach(ReviewConfidence.allCases, id: \.rawValue) { level in
                        Text(level.title).tag(level)
                    }
                }
                Stepper("\(sessionCount) Wiederholungen", value: $sessionCount, in: 1...12)
                Button("Termine planen") { calculate() }
                    .buttonStyle(.borderedProminent)
            }
            if let schedule {
                Section("Aktive Wiederholungen") {
                    ForEach(Array(schedule.reviewDates.enumerated()), id: \.offset) { index, date in
                        LabeledContent(
                            "Wiederholung \(index + 1)",
                            value: date.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    Text("Bei jeder Wiederholung: zuerst ohne Unterlagen erklären, dann Lücken prüfen und nur die unsicheren Stellen nacharbeiten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            errorSection(error)
        }
        .navigationTitle("Wiederholungsplan")
        .onAppear { calculate() }
    }

    private func calculate() {
        do {
            schedule = try SpacedRepetitionPlanner.schedule(
                from: startDate,
                confidence: confidence,
                sessionCount: sessionCount
            )
            error = nil
        } catch {
            schedule = nil
            self.error = error.localizedDescription
        }
    }
}

private struct JSONFormatterView: View {
    @State private var input = "{\"course\":\"Software Development\",\"semester\":1}"
    @State private var result: JSONStudyFormatResult?
    @State private var showsMinified = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("JSON") {
                TextEditor(text: $input)
                    .font(.body.monospaced())
                    .frame(minHeight: 150)
                    .autocorrectionDisabled()
                Button("Prüfen und formatieren") { formatJSON() }
                    .buttonStyle(.borderedProminent)
            }
            if let result {
                Section(result.topLevelDescription) {
                    Toggle("Kompakte Darstellung", isOn: $showsMinified)
                    Text(showsMinified ? result.minified : result.prettyPrinted)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            }
            errorSection(error)
        }
        .navigationTitle("JSON-Prüfer")
        .onAppear { formatJSON() }
    }

    private func formatJSON() {
        do {
            result = try JSONStudyFormatter.format(input)
            error = nil
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

private struct StudyWorkloadView: View {
    @State private var credits = "5"
    @State private var weeks = "20"
    @State private var result: StudyWorkloadPlan?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Planung") {
                TextField("Credit Points", text: $credits)
                    .keyboardType(.decimalPad)
                TextField("Wochen", text: $weeks)
                    .keyboardType(.numberPad)
                Button("Aufwand berechnen") { calculate() }
                    .buttonStyle(.borderedProminent)
            }
            if let result {
                Section("Ergebnis") {
                    LabeledContent("Gesamtaufwand", value: "\(format(result.totalHours)) h")
                    LabeledContent("Pro Woche", value: "\(format(result.hoursPerWeek)) h")
                    Text("Grundlage: 30 Arbeitsstunden pro CP; beispielsweise entsprechen 5 CP etwa 150 Stunden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            errorSection(error)
        }
        .navigationTitle("CP- und Wochenplaner")
        .onAppear { calculate() }
    }

    private func calculate() {
        do {
            guard let credits = parseDecimal(credits), let weeks = Int(weeks) else {
                throw StudyToolkitError.invalidInput("Bitte gültige Zahlen eingeben.")
            }
            result = try StudyWorkloadPlan.calculate(credits: credits, weeks: weeks)
            error = nil
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

private struct RequirementReviewView: View {
    @State private var statement = "Als Student muss ich …"
    @State private var acceptanceCriteria = "Gegeben …, wenn …, dann …"
    @State private var review: RequirementReview?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Anforderung") {
                TextEditor(text: $statement)
                    .frame(minHeight: 90)
                Text("Akteur, Verbindlichkeit und gewünschtes Ergebnis möglichst eindeutig formulieren.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Akzeptanzkriterien") {
                TextEditor(text: $acceptanceCriteria)
                    .frame(minHeight: 90)
                Button("Qualität prüfen") { evaluate() }
                    .buttonStyle(.borderedProminent)
            }
            if let review {
                Section("Bewertung: \(review.score) / 100") {
                    if review.findings.isEmpty {
                        Label("Keine Auffälligkeiten gefunden", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                    ForEach(review.findings) { finding in
                        Label(finding.message, systemImage: finding.severity.systemImage)
                            .foregroundStyle(finding.severity.color)
                    }
                }
            }
            errorSection(error)
        }
        .navigationTitle("Anforderungs-Check")
    }

    private func evaluate() {
        do {
            review = try RequirementReviewer.review(
                statement: statement,
                acceptanceCriteria: acceptanceCriteria
            )
            error = nil
        } catch {
            review = nil
            self.error = error.localizedDescription
        }
    }
}

private extension RequirementFindingSeverity {
    var systemImage: String {
        switch self {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .suggestion: "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .error: .red
        case .warning: .orange
        case .suggestion: .blue
        }
    }
}

private struct StatisticsCalculatorView: View {
    @State private var values = "1; 2; 3; 4"
    @State private var usesSampleVariance = false
    @State private var result: DescriptiveStatisticsResult?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Daten") {
                TextEditor(text: $values)
                    .frame(minHeight: 110)
                Text("Werte mit Semikolon, Leerzeichen oder Zeilenumbruch trennen. Dezimaltrennzeichen: Komma oder Punkt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Stichprobenvarianz (n − 1)", isOn: $usesSampleVariance)
                Button("Statistik berechnen") { calculate() }
                    .buttonStyle(.borderedProminent)
            }
            if let result {
                Section("Ergebnis") {
                    LabeledContent("Anzahl", value: "\(result.count)")
                    LabeledContent("Minimum", value: format(result.minimum))
                    LabeledContent("Maximum", value: format(result.maximum))
                    LabeledContent("Mittelwert", value: format(result.mean))
                    LabeledContent("Median", value: format(result.median))
                    LabeledContent("Varianz", value: format(result.variance))
                    LabeledContent("Standardabweichung", value: format(result.standardDeviation))
                }
            }
            errorSection(error)
        }
        .navigationTitle("Deskriptive Statistik")
        .onAppear { calculate() }
    }

    private func calculate() {
        do {
            let normalized = values.replacingOccurrences(of: ",", with: ".")
            let tokens = normalized.split { $0 == ";" || $0.isWhitespace }
            guard !tokens.isEmpty else {
                throw StudyToolkitError.invalidInput("Bitte mindestens einen Wert eingeben.")
            }
            let parsed = try tokens.map { token -> Double in
                guard let value = Double(token) else {
                    throw StudyToolkitError.invalidInput("„\(token)“ ist keine gültige Zahl.")
                }
                return value
            }
            result = try DescriptiveStatistics.analyze(parsed, usesSampleVariance: usesSampleVariance)
            error = nil
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

private struct NumberSystemConverterView: View {
    @State private var input = "42"
    @State private var base: NumberBase = .decimal
    @State private var result: NumberSystemResult?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Eingabe") {
                Picker("Zahlensystem", selection: $base) {
                    ForEach(NumberBase.allCases, id: \.rawValue) { base in
                        Text("\(base.title) (Basis \(base.rawValue))").tag(base)
                    }
                }
                TextField("Zahl", text: $input)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Umrechnen") { calculate() }
                    .buttonStyle(.borderedProminent)
            }
            if let result {
                Section("Ergebnis") {
                    LabeledContent("Binär", value: result.binary)
                    LabeledContent("Oktal", value: result.octal)
                    LabeledContent("Dezimal", value: result.decimal)
                    LabeledContent("Hexadezimal", value: result.hexadecimal)
                }
                .textSelection(.enabled)
            }
            errorSection(error)
        }
        .navigationTitle("Zahlensysteme")
        .onAppear { calculate() }
    }

    private func calculate() {
        do {
            result = try NumberSystemConverter.convert(input, from: base)
            error = nil
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

private struct ComplexityCalculatorView: View {
    @State private var inputSize = "1000"
    @State private var complexity: AlgorithmComplexity = .linearithmic
    @State private var result: Double?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Algorithmus") {
                Picker("Komplexität", selection: $complexity) {
                    ForEach(AlgorithmComplexity.allCases, id: \.rawValue) { complexity in
                        Text(complexity.notation).tag(complexity)
                    }
                }
                TextField("Eingabegröße n", text: $inputSize)
                    .keyboardType(.numberPad)
                Button("Operationen schätzen") { calculate() }
                    .buttonStyle(.borderedProminent)
            }
            if let result {
                Section("Ergebnis") {
                    LabeledContent("Größenordnung", value: complexity.notation)
                    LabeledContent("Geschätzte Operationen", value: format(result))
                    Text("Die Schätzung zeigt nur das asymptotische Wachstum; Konstanten, Hardware und Implementierung bleiben unberücksichtigt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            errorSection(error)
        }
        .navigationTitle("Komplexitätsrechner")
        .onAppear { calculate() }
    }

    private func calculate() {
        do {
            guard let size = Int(inputSize) else {
                throw StudyToolkitError.invalidInput("Bitte eine ganze Eingabegröße angeben.")
            }
            result = try complexity.estimateOperations(for: size)
            error = nil
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

private struct NetworkCalculatorView: View {
    @State private var address = "192.168.1.42"
    @State private var prefix = "24"
    @State private var result: IPv4NetworkResult?
    @State private var error: String?

    var body: some View {
        Form {
            Section("IPv4-Netz") {
                TextField("IPv4-Adresse", text: $address)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                TextField("CIDR-Präfix", text: $prefix)
                    .keyboardType(.numberPad)
                Button("Netz berechnen") { calculate() }
                    .buttonStyle(.borderedProminent)
            }
            if let result {
                Section("Ergebnis") {
                    LabeledContent("Netzadresse", value: result.networkAddress)
                    LabeledContent("Broadcast", value: result.broadcastAddress)
                    LabeledContent("Erster Host", value: result.firstHost)
                    LabeledContent("Letzter Host", value: result.lastHost)
                    LabeledContent("Adressen", value: "\(result.addressCount)")
                    LabeledContent("Nutzbare Hosts", value: "\(result.usableHostCount)")
                }
                .textSelection(.enabled)
            }
            errorSection(error)
        }
        .navigationTitle("IPv4/CIDR-Rechner")
        .onAppear { calculate() }
    }

    private func calculate() {
        do {
            guard let prefix = Int(prefix) else {
                throw StudyToolkitError.invalidInput("Bitte ein ganzzahliges CIDR-Präfix angeben.")
            }
            result = try IPv4NetworkCalculator.calculate(address: address, prefixLength: prefix)
            error = nil
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }
}

private struct StudyChecklistView: View {
    let title: String
    let introduction: String
    let items: [String]
    @State private var completed: Set<Int> = []

    static let scientific = StudyChecklistView(
        title: "Wissenschafts-Checkliste",
        introduction: "Lokale Selbstkontrolle vor Abgabe oder Review.",
        items: [
            "Forschungsfrage und Ziel sind eindeutig formuliert.",
            "Primär- und Sekundärquellen wurden kritisch bewertet.",
            "Suchstrategie und Auswahlkriterien sind nachvollziehbar.",
            "Methode und Forschungsdesign passen zur Fragestellung.",
            "Alle fremden Aussagen und Abbildungen sind belegt.",
            "Zitierweise und Literaturverzeichnis sind konsistent.",
            "Ergebnisse, Interpretation und Limitationen sind getrennt.",
            "Datenschutz, Ethik und Reproduzierbarkeit sind geprüft."
        ]
    )

    static let quality = StudyChecklistView(
        title: "Test- und Qualitätsmatrix",
        introduction: "Prüfpunkte aus Softwaretechnik, DevOps und Qualitätssicherung.",
        items: [
            "Anforderungen besitzen überprüfbare Akzeptanzkriterien.",
            "Normalfälle, Grenzwerte und Fehlerfälle sind abgedeckt.",
            "Unit-, Integrations-, System- und Abnahmetests sind zugeordnet.",
            "Statische Analyse und Reviews sind eingeplant.",
            "Security-, Datenschutz- und Missbrauchsfälle sind geprüft.",
            "Performance- und Ressourcenlimits sind definiert.",
            "Accessibility und unterschiedliche Gerätegrößen sind getestet.",
            "Build, Test und Auslieferung sind reproduzierbar dokumentiert."
        ]
    )

    static let learning = StudyChecklistView(
        title: "Active Recall & Feynman",
        introduction: "Ein kurzer Lernzyklus, der Verstehen statt bloßes Wiederlesen prüft.",
        items: [
            "Lernziel als konkrete Frage formulieren.",
            "Antwort ohne Skript oder Notizen aus dem Gedächtnis erklären.",
            "Begriff, Ablauf oder Code in eigenen einfachen Worten beschreiben.",
            "Ein eigenes Beispiel und ein Gegenbeispiel entwickeln.",
            "Erklärung mit Quelle oder Musterlösung vergleichen.",
            "Wissenslücken im Active-Recall-Notizbuch festhalten.",
            "Nur die erkannten Lücken gezielt nacharbeiten.",
            "Nächste Wiederholung mit dem Wiederholungsplan terminieren."
        ]
    )

    var body: some View {
        List {
            Section {
                Text(introduction)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(completed.count), total: Double(items.count)) {
                    Text("\(completed.count) von \(items.count) geprüft")
                }
            }
            Section("Prüfpunkte") {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    Button {
                        if completed.contains(index) {
                            completed.remove(index)
                        } else {
                            completed.insert(index)
                        }
                    } label: {
                        Label(item, systemImage: completed.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(completed.contains(index) ? Color.green : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DiagramToolInfoView: View {
    var body: some View {
        List {
            Section("Im Technikdokument verfügbar") {
                Label("Anforderungen und Use Cases", systemImage: "checklist.checked")
                Label("UML-Klassen und Komponenten", systemImage: "square.3.layers.3d")
                Label("Datenbank-Entitäten", systemImage: "cylinder.split.1x2")
                Label("CI/CD-Pipeline-Schritte", systemImage: "arrow.triangle.branch")
                Label("Testfälle und Teststufen", systemImage: "checkmark.shield")
                Label("Trust Boundaries und IT-Netze", systemImage: "lock.trianglebadge.exclamationmark")
            }
            Section("Arbeitsweise") {
                Text("Lege in der Bibliothek ein Technikdokument an. Über „Bauteil“ findest du den Bereich „Softwareentwicklung & Studium“. Elemente lassen sich verschieben, drehen, beschriften, verbinden, automatisch speichern und als SVG exportieren.")
            }
        }
        .navigationTitle("Diagrammwerkzeuge")
    }
}

@ViewBuilder
private func errorSection(_ message: String?) -> some View {
    if let message {
        Section("Hinweis") {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

private func parseDecimal(_ value: String) -> Double? {
    Double(value.replacingOccurrences(of: ",", with: "."))
}

private func format(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...4)))
}
