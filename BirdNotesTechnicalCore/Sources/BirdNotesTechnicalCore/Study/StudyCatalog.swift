import Foundation

public enum StudyPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case semester1
    case semester2
    case semester3
    case semester4
    case elective
    case thesis

    public var title: String {
        switch self {
        case .semester1: "1. Semester"
        case .semester2: "2. Semester"
        case .semester3: "3. Semester"
        case .semester4: "4. Semester"
        case .elective: "Wahl- und Vertiefungsbereich"
        case .thesis: "Abschlussphase"
        }
    }
}

public enum StudyArea: String, Codable, CaseIterable, Hashable, Sendable {
    case softwareEngineering
    case programming
    case dataAndAI
    case cloudAndDevOps
    case security
    case mathematics
    case uxAndXR
    case embeddedAndIoT
    case scienceAndProjects
    case ethicsAndBusiness

    public var title: String {
        switch self {
        case .softwareEngineering: "Software Engineering"
        case .programming: "Programmierung"
        case .dataAndAI: "Datenbanken, Data & AI"
        case .cloudAndDevOps: "Cloud & DevOps"
        case .security: "Datenschutz & Security"
        case .mathematics: "Mathematik & Statistik"
        case .uxAndXR: "UX, Design & XR"
        case .embeddedAndIoT: "IoT, Embedded & Robotik"
        case .scienceAndProjects: "Wissenschaft & Projekte"
        case .ethicsAndBusiness: "Ethik & Wirtschaft"
        }
    }
}

public enum StudyToolIdentifier: String, Codable, CaseIterable, Hashable, Sendable {
    case workloadPlanner
    case requirementsReview
    case softwareDiagram
    case databaseDiagram
    case devOpsPipeline
    case testingMatrix
    case complexityEstimator
    case numberSystems
    case statistics
    case networkCalculator
    case threatModel
    case researchChecklist
    case reviewPlanner
    case jsonFormatter
    case learningMethods

    public var title: String {
        switch self {
        case .workloadPlanner: "CP- und Wochenplaner"
        case .requirementsReview: "Anforderungs-Check"
        case .softwareDiagram: "Software- und UML-Diagramme"
        case .databaseDiagram: "ER- und Datenbankdiagramme"
        case .devOpsPipeline: "CI/CD-Pipeline"
        case .testingMatrix: "Test- und Qualitätsmatrix"
        case .complexityEstimator: "Komplexitätsrechner"
        case .numberSystems: "Zahlensystem-Konverter"
        case .statistics: "Deskriptive Statistik"
        case .networkCalculator: "IPv4/CIDR-Rechner"
        case .threatModel: "Threat-Model-Diagramm"
        case .researchChecklist: "Wissenschafts-Checkliste"
        case .reviewPlanner: "Wiederholungsplan"
        case .jsonFormatter: "JSON-Prüfer"
        case .learningMethods: "Active Recall und Feynman"
        }
    }
}

public struct StudyModuleRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { code }
    public var code: String
    public var title: String
    public var phase: StudyPhase
    public var credits: Int
    public var area: StudyArea
    public var focus: [String]
    public var tools: [StudyToolIdentifier]

    public init(
        code: String,
        title: String,
        phase: StudyPhase,
        credits: Int = 5,
        area: StudyArea,
        focus: [String],
        tools: [StudyToolIdentifier]
    ) {
        self.code = code
        self.title = title
        self.phase = phase
        self.credits = credits
        self.area = area
        self.focus = focus
        self.tools = tools
    }
}

public struct StudyCurriculum: Codable, Equatable, Sendable {
    public var identifier: String
    public var title: String
    public var handbookDate: String
    public var modules: [StudyModuleRecord]

    public init(
        identifier: String,
        title: String,
        handbookDate: String,
        modules: [StudyModuleRecord]
    ) throws {
        guard !identifier.isEmpty,
              identifier.utf8.count <= 128,
              !title.isEmpty,
              title.utf8.count <= 256,
              handbookDate.utf8.count <= 64,
              !modules.isEmpty,
              modules.count <= 200,
              Set(modules.map(\.code)).count == modules.count else {
            throw StudyToolkitError.invalidInput("Der Studienkatalog ist ungültig.")
        }
        for module in modules {
            guard Self.isSafeCode(module.code),
                  !module.title.isEmpty,
                  module.title.utf8.count <= 256,
                  (1...30).contains(module.credits),
                  !module.focus.isEmpty,
                  module.focus.count <= 32,
                  module.focus.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 }),
                  Set(module.tools).count == module.tools.count else {
                throw StudyToolkitError.invalidInput("Ein Studienmodul ist ungültig.")
            }
        }
        self.identifier = identifier
        self.title = title
        self.handbookDate = handbookDate
        self.modules = modules
    }

    public func modules(in phase: StudyPhase) -> [StudyModuleRecord] {
        modules.filter { $0.phase == phase }
    }

    public func modules(in area: StudyArea) -> [StudyModuleRecord] {
        modules.filter { $0.area == area }
    }

    public static func softwareDevelopment2026() throws -> StudyCurriculum {
        try StudyCurriculum(
            identifier: "iu.fs-base-01.2026-04-27",
            title: "B.Sc. Softwareentwicklung",
            handbookDate: "27. April 2026",
            modules: requiredModules + electiveModules + thesisModules
        )
    }

    private static func isSafeCode(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 64 && value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }
    }

    private static let requiredModules: [StudyModuleRecord] = [
        module("IGIS-01", "Grundlagen der Softwaretechnik", .semester1, .softwareEngineering,
               ["Softwarelebenszyklus", "Rollen", "Vorgehensmodelle"],
               [.softwareDiagram, .workloadPlanner]),
        module("DLBWIRITT", "Wissenschaftliches Arbeiten für IT und Technik", .semester1, .scienceAndProjects,
               ["Quellenbewertung", "Forschungsdesign", "Argumentation"],
               [.researchChecklist, .workloadPlanner, .learningMethods, .reviewPlanner]),
        module("IREN", "Requirements Engineering", .semester1, .softwareEngineering,
               ["Ermittlung", "Dokumentation", "UML und Prozessmodelle"],
               [.requirementsReview, .softwareDiagram]),
        module("DLBDSIPWP_D", "Einführung in die Programmierung mit Python", .semester1, .programming,
               ["Syntax", "Kontrollstrukturen", "Funktionen"],
               [.numberSystems, .softwareDiagram, .jsonFormatter, .reviewPlanner]),
        module("DLBFTPPP", "Projekt: Programmierung mit Python", .semester1, .programming,
               ["Projektstruktur", "Implementierung", "Dokumentation"],
               [.testingMatrix, .workloadPlanner]),

        module("IPWA1-01", "Programmierung von Webanwendungsoberflächen", .semester2, .programming,
               ["HTML", "CSS", "JavaScript"],
               [.softwareDiagram, .testingMatrix, .jsonFormatter]),
        module("DLBINGOPJ-01", "Objektorientierte Programmierung mit Java", .semester2, .programming,
               ["Klassen", "Vererbung", "Polymorphie"],
               [.softwareDiagram, .testingMatrix]),
        module("IDBS", "Datenmodellierung und Datenbanksysteme", .semester2, .dataAndAI,
               ["ER-Modell", "Normalformen", "SQL und NoSQL"],
               [.databaseDiagram, .softwareDiagram, .jsonFormatter]),
        module("ISPE", "Spezifikation", .semester2, .softwareEngineering,
               ["Formale Modelle", "Verhalten", "Schnittstellen"],
               [.requirementsReview, .softwareDiagram]),
        module("DLBITPEWP-01", "Projekt: Einstieg in die Web-Programmierung", .semester2, .programming,
               ["Webprojekt", "Usability", "Auslieferung"],
               [.testingMatrix, .workloadPlanner]),

        module("DLBIADPS-01", "Algorithmen, Datenstrukturen und Programmiersprachen", .semester3, .programming,
               ["Datenstrukturen", "Algorithmen", "Komplexität"],
               [.complexityEstimator, .numberSystems, .softwareDiagram]),
        module("DLBSEPDOCD_D", "DevOps und Continuous Delivery", .semester3, .cloudAndDevOps,
               ["Versionskontrolle", "CI/CD", "Automatisierte Tests"],
               [.devOpsPipeline, .testingMatrix, .threatModel]),
        module("DLBSESA", "Software-Architektur", .semester3, .softwareEngineering,
               ["Architekturstile", "Verteilte Systeme", "Qualitätsentscheidungen"],
               [.softwareDiagram, .databaseDiagram, .threatModel]),
        module("IQSS", "Qualitätssicherung im Softwareprozess", .semester3, .softwareEngineering,
               ["Reviews", "Testentwurf", "Teststufen"],
               [.testingMatrix, .requirementsReview]),
        module("DLBMINPAPCC", "Projekt: Allgemeine Programmierung mit C/C++", .semester3, .programming,
               ["Speicher", "C/C++", "Projektarbeit"],
               [.complexityEstimator, .testingMatrix]),

        module("DLBSEPENIT_D", "Ethik und Nachhaltigkeit in der IT", .semester4, .ethicsAndBusiness,
               ["Technikfolgen", "Nachhaltigkeit", "Verantwortung"],
               [.researchChecklist, .workloadPlanner]),
        module("DLBWIWTMAS1", "Agile Softwareentwicklung", .semester4, .softwareEngineering,
               ["Scrum", "Kanban", "Agile Planung"],
               [.workloadPlanner, .requirementsReview]),
        module("DLBCSEMSE1-01_D", "Mobile Software Engineering", .semester4, .softwareEngineering,
               ["Mobile Architektur", "Plattformen", "Qualität"],
               [.softwareDiagram, .testingMatrix]),
        module("ISSE", "Seminar: Software Engineering", .semester4, .scienceAndProjects,
               ["Literaturrecherche", "Ausarbeitung", "Präsentation"],
               [.researchChecklist, .workloadPlanner, .learningMethods, .reviewPlanner]),
        module("ISEF", "Projekt: Software Engineering", .semester4, .scienceAndProjects,
               ["Planung", "Umsetzung", "Evaluation"],
               [.workloadPlanner, .requirementsReview, .testingMatrix])
    ]

    private static let electiveModules: [StudyModuleRecord] = [
        module("DLBINGEDS", "Datenschutz und IT-Sicherheit", .elective, .security,
               ["Datenschutz", "Schutzziele", "Sicherheitsmaßnahmen"], [.threatModel, .networkCalculator]),
        module("DLBISIC2-01", "Kryptografische Verfahren", .elective, .security,
               ["Kryptografie", "Schlüssel", "Protokolle"], [.numberSystems, .threatModel]),
        module("DLBCSESPB_D", "Grundzüge des System-Pentestings", .elective, .security,
               ["Angriffsflächen", "Tests", "Dokumentation"], [.networkCalculator, .threatModel]),
        module("DLBCSEEFT1_D", "Threat Modeling", .elective, .security,
               ["Assets", "Trust Boundaries", "Bedrohungen"], [.threatModel, .softwareDiagram]),
        module("DLBCSEDCSW_D", "DevSecOps und Software-Schwachstellen", .elective, .security,
               ["Secure SDLC", "Schwachstellen", "Security Gates"], [.devOpsPipeline, .threatModel, .testingMatrix]),
        module("DLBDSCC-01_D", "Cloud Computing", .elective, .cloudAndDevOps,
               ["Cloud-Modelle", "Verteilte Systeme", "Betrieb"], [.softwareDiagram, .networkCalculator, .threatModel]),
        module("DLBSEPITI-01_D", "IT-Infrastruktur", .elective, .cloudAndDevOps,
               ["Netzwerke", "Server", "Betrieb"], [.networkCalculator, .softwareDiagram]),
        module("DLBPAWSCLES", "Project: AWS Cloud Essentials", .elective, .cloudAndDevOps,
               ["Cloud-Architektur", "Deployment", "Kosten"], [.softwareDiagram, .networkCalculator]),
        module("DLBPAWSCLAD", "Project: AWS Cloud Advanced", .elective, .cloudAndDevOps,
               ["Skalierung", "Resilienz", "Automation"], [.softwareDiagram, .devOpsPipeline, .threatModel]),
        module("DLBSEPCP_D", "Projekt: Cloud Programming", .elective, .cloudAndDevOps,
               ["Cloud-native Entwicklung", "APIs", "Deployment"], [.softwareDiagram, .devOpsPipeline]),
        module("DLBWINGM", "Grundlagen der Mathematik", .elective, .mathematics,
               ["Algebra", "Funktionen", "Analysis"], [.statistics, .complexityEstimator]),
        module("DLBDBSC", "Statistical Computing", .elective, .mathematics,
               ["Deskriptive Statistik", "Wahrscheinlichkeit", "Auswertung"], [.statistics]),
        module("DLBDSIDS-01_D", "Einführung in Data Science", .elective, .dataAndAI,
               ["Datenaufbereitung", "Analyse", "Modelle"], [.statistics, .databaseDiagram]),
        module("DLBDSEDAV", "Exploratory Data Analysis and Visualization", .elective, .dataAndAI,
               ["EDA", "Visualisierung", "Interpretation"], [.statistics, .researchChecklist]),
        module("DLBDSEDE1", "Data Engineering", .elective, .dataAndAI,
               ["Datenpipelines", "Speicher", "Qualität"], [.databaseDiagram, .devOpsPipeline]),
        module("DLBDBDL", "Deep Learning", .elective, .dataAndAI,
               ["Neuronale Netze", "Training", "Evaluation"], [.statistics, .softwareDiagram]),
        module("DLBDSEAIS1-01_D", "Artificial Intelligence", .elective, .dataAndAI,
               ["KI-Verfahren", "Modelle", "Evaluation"], [.statistics, .softwareDiagram]),
        module("DLBAIINLP_D", "Einführung in NLP", .elective, .dataAndAI,
               ["Textdaten", "Sprachmodelle", "Evaluation"], [.statistics, .softwareDiagram]),
        module("DLBINGEIT", "Einführung in das Internet of Things", .elective, .embeddedAndIoT,
               ["Sensoren", "Kommunikation", "IoT-Architektur"], [.softwareDiagram, .networkCalculator, .threatModel]),
        module("DLBROES_D", "Embedded Systems", .elective, .embeddedAndIoT,
               ["Mikrocontroller", "Echtzeit", "Schnittstellen"], [.numberSystems, .softwareDiagram]),
        module("DLBROIR-01_D", "Einführung in die Robotik", .elective, .embeddedAndIoT,
               ["Kinematik", "Steuerung", "Robotersysteme"], [.softwareDiagram, .statistics]),
        module("DLBROST_D", "Sensorik", .elective, .embeddedAndIoT,
               ["Messprinzipien", "Signalverarbeitung", "Kalibrierung"], [.statistics, .softwareDiagram]),
        module("DLBMIUEX1-01", "User Experience", .elective, .uxAndXR,
               ["Nutzerzentrierung", "Evaluation", "Interaktion"], [.researchChecklist, .testingMatrix]),
        module("DLBUXEUR", "Einführung in User Research", .elective, .uxAndXR,
               ["Forschungsfragen", "Interviews", "Auswertung"], [.researchChecklist, .statistics]),
        module("DLBMIUID1-01", "Gestaltung und Ergonomie von User Interfaces", .elective, .uxAndXR,
               ["UI-Gestaltung", "Ergonomie", "Accessibility"], [.testingMatrix, .researchChecklist]),
        module("DLBMIAMVR1", "Augmented, Mixed und Virtual Reality", .elective, .uxAndXR,
               ["XR-Grundlagen", "Interaktion", "Anwendungen"], [.softwareDiagram, .testingMatrix]),
        module("DLBAVRECC", "Einführung in Computer Graphics", .elective, .uxAndXR,
               ["Rendering", "Transformationen", "Grafikpipeline"], [.softwareDiagram, .complexityEstimator]),
        module("IPMG-01", "IT-Projektmanagement", .elective, .scienceAndProjects,
               ["Planung", "Risiken", "Steuerung"], [.workloadPlanner, .requirementsReview]),
        module("BBWL-01", "Betriebswirtschaftslehre", .elective, .ethicsAndBusiness,
               ["Unternehmen", "Investition", "Wertschöpfung"], [.workloadPlanner, .statistics]),
        module("DLBLODB-01", "Digitale Business-Modelle", .elective, .ethicsAndBusiness,
               ["Geschäftsmodelle", "Digitalisierung", "Bewertung"], [.researchChecklist, .workloadPlanner])
    ]

    private static let thesisModules: [StudyModuleRecord] = [
        StudyModuleRecord(
            code: "BBAK",
            title: "Bachelorarbeit und Kolloquium",
            phase: .thesis,
            credits: 10,
            area: .scienceAndProjects,
            focus: ["Forschungsfrage", "Methodik", "Ausarbeitung und Verteidigung"],
            tools: [.researchChecklist, .workloadPlanner]
        )
    ]

    private static func module(
        _ code: String,
        _ title: String,
        _ phase: StudyPhase,
        _ area: StudyArea,
        _ focus: [String],
        _ tools: [StudyToolIdentifier]
    ) -> StudyModuleRecord {
        StudyModuleRecord(
            code: code,
            title: title,
            phase: phase,
            area: area,
            focus: focus,
            tools: tools
        )
    }
}
