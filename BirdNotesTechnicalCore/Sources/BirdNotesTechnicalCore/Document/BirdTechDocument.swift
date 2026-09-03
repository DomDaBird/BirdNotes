import Foundation

public struct TechnicalCalculation: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var expression: String
    public var variables: [String: Quantity]
    public var lastEvaluation: ExpressionEvaluation?
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        expression: String,
        variables: [String: Quantity] = [:],
        lastEvaluation: ExpressionEvaluation? = nil,
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.expression = expression
        self.variables = variables
        self.lastEvaluation = lastEvaluation
        self.modifiedAt = modifiedAt
    }
}

public struct TechnicalCalculations: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var items: [TechnicalCalculation]

    public init(schemaVersion: Int = Self.currentSchemaVersion, items: [TechnicalCalculation] = []) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

public struct BirdTechManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var documentID: UUID
    public var title: String
    public var domain: TechnicalDomain
    public var createdAt: Date
    public var modifiedAt: Date
    public var writerVersion: String
    public var moduleVersions: [String: String]
    public var diagramSHA256: String
    public var calculationsSHA256: String
    public var annotationsSHA256: String?
    public var previewSHA256: String?

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        documentID: UUID,
        title: String,
        domain: TechnicalDomain,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        writerVersion: String,
        moduleVersions: [String: String] = [:],
        diagramSHA256: String = "",
        calculationsSHA256: String = "",
        annotationsSHA256: String? = nil,
        previewSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.documentID = documentID
        self.title = title
        self.domain = domain
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.writerVersion = writerVersion
        self.moduleVersions = moduleVersions
        self.diagramSHA256 = diagramSHA256
        self.calculationsSHA256 = calculationsSHA256
        self.annotationsSHA256 = annotationsSHA256
        self.previewSHA256 = previewSHA256
    }
}

public struct BirdTechDocument: Equatable, Sendable {
    public var manifest: BirdTechManifest
    public var diagram: TechnicalDiagram
    public var calculations: TechnicalCalculations
    public var annotationsData: Data?
    public var previewPNGData: Data?

    public init(
        manifest: BirdTechManifest,
        diagram: TechnicalDiagram,
        calculations: TechnicalCalculations = TechnicalCalculations(),
        annotationsData: Data? = nil,
        previewPNGData: Data? = nil
    ) {
        self.manifest = manifest
        self.diagram = diagram
        self.calculations = calculations
        self.annotationsData = annotationsData
        self.previewPNGData = previewPNGData
    }

    public static func blank(
        title: String,
        domain: TechnicalDomain,
        writerVersion: String,
        moduleVersions: [String: String] = [:]
    ) -> Self {
        let id = UUID()
        return Self(
            manifest: BirdTechManifest(
                documentID: id,
                title: title,
                domain: domain,
                writerVersion: writerVersion,
                moduleVersions: moduleVersions
            ),
            diagram: TechnicalDiagram(domain: domain)
        )
    }
}

public struct BirdTechDocumentSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { documentID }
    public let documentID: UUID
    public let title: String
    public let domain: TechnicalDomain
    public let modifiedAt: Date
    public let url: URL

    public init(documentID: UUID, title: String, domain: TechnicalDomain, modifiedAt: Date, url: URL) {
        self.documentID = documentID
        self.title = title
        self.domain = domain
        self.modifiedAt = modifiedAt
        self.url = url
    }
}
