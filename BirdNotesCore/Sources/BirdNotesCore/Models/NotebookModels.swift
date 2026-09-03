import Foundation

public enum PaperStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case blank
    case lined
    case grid
    case dotted
    case cornell

    public var id: Self { self }
}

public enum PaperFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case a4
    case a3

    public var id: Self { self }

    /// A-series proportions in drawing coordinates. A4 keeps the previous
    /// 1024-point width so existing PencilKit strokes are not clipped.
    public var width: Double {
        switch self {
        case .a4: 1_024
        case .a3: 1_448.154_687_87
        }
    }

    public var height: Double {
        switch self {
        case .a4: 1_448.154_687_87
        case .a3: 2_048
        }
    }
}

public enum PaperOrientation: String, Codable, CaseIterable, Identifiable, Sendable {
    case portrait
    case landscape

    public var id: Self { self }
}

public struct NotebookManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var id: UUID
    public var documentType: DocumentKind
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var pageOrder: [UUID]

    public init(
        schemaVersion: Int = NotebookManifest.currentSchemaVersion,
        id: UUID = UUID(),
        documentType: DocumentKind = .notebook,
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        pageOrder: [UUID]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.documentType = documentType
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.pageOrder = pageOrder
    }
}

public struct NotebookPageMetadata: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var modifiedAt: Date
    public var paperStyle: PaperStyle
    public var paperFormat: PaperFormat
    public var paperOrientation: PaperOrientation
    public var isEmpty: Bool
    public var isBookmarked: Bool
    public var transcribedText: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        paperStyle: PaperStyle = .blank,
        paperFormat: PaperFormat = .a4,
        paperOrientation: PaperOrientation = .portrait,
        isEmpty: Bool = true,
        isBookmarked: Bool = false,
        transcribedText: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.paperStyle = paperStyle
        self.paperFormat = paperFormat
        self.paperOrientation = paperOrientation
        self.isEmpty = isEmpty
        self.isBookmarked = isBookmarked
        self.transcribedText = transcribedText
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case modifiedAt
        case paperStyle
        case paperFormat
        case paperOrientation
        case isEmpty
        case isBookmarked
        case transcribedText
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        paperStyle = try container.decode(PaperStyle.self, forKey: .paperStyle)
        paperFormat = try container.decodeIfPresent(PaperFormat.self, forKey: .paperFormat) ?? .a4
        paperOrientation = try container.decodeIfPresent(
            PaperOrientation.self,
            forKey: .paperOrientation
        ) ?? .portrait
        isEmpty = try container.decode(Bool.self, forKey: .isEmpty)
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        transcribedText = try container.decodeIfPresent(String.self, forKey: .transcribedText)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(paperStyle, forKey: .paperStyle)
        try container.encode(paperFormat, forKey: .paperFormat)
        try container.encode(paperOrientation, forKey: .paperOrientation)
        try container.encode(isEmpty, forKey: .isEmpty)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encodeIfPresent(transcribedText, forKey: .transcribedText)
    }
}

public struct NotebookPage: Equatable, Identifiable, Sendable {
    public var metadata: NotebookPageMetadata
    public var drawingData: Data

    public var id: UUID { metadata.id }

    public init(metadata: NotebookPageMetadata, drawingData: Data) {
        self.metadata = metadata
        self.drawingData = drawingData
    }
}

public struct NotebookDocument: Equatable, Sendable {
    public var manifest: NotebookManifest
    public var pages: [NotebookPage]

    public init(manifest: NotebookManifest, pages: [NotebookPage]) {
        self.manifest = manifest
        self.pages = pages
    }
}
