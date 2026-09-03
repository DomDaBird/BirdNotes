import Foundation

public struct CanvasPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CanvasSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct CanvasColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let ink = CanvasColor(red: 0.08, green: 0.12, blue: 0.18)
    public static let accent = CanvasColor(red: 0.10, green: 0.42, blue: 0.78)
    public static let paper = CanvasColor(red: 1, green: 1, blue: 1)
}

public struct CanvasViewport: Codable, Equatable, Sendable {
    public var center: CanvasPoint
    public var zoomScale: Double

    public init(
        center: CanvasPoint = CanvasPoint(x: 8_192, y: 8_192),
        zoomScale: Double = 0.35
    ) {
        self.center = center
        self.zoomScale = zoomScale
    }
}

/// Metadata for stable tile coordinates. PencilKit remains one editable
/// drawing today; a future renderer can load only visible regions without
/// another breaking document-format migration.
public struct CanvasTileConfiguration: Codable, Equatable, Sendable {
    public var tileSize: Double
    public var columns: Int
    public var rows: Int

    public init(tileSize: Double = 1_024, columns: Int = 16, rows: Int = 16) {
        self.tileSize = tileSize
        self.columns = columns
        self.rows = rows
    }
}

public enum CanvasElementKind: String, Codable, CaseIterable, Sendable {
    case text
    case image
    case shape
    case connector
}

public enum CanvasShapeKind: String, Codable, CaseIterable, Sendable {
    case line
    case arrow
    case rectangle
    case roundedRectangle
    case ellipse
    case triangle
}

public struct CanvasElement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: CanvasElementKind
    public var center: CanvasPoint
    public var size: CanvasSize
    public var rotation: Double
    public var text: String?
    public var imageData: Data?
    public var shapeKind: CanvasShapeKind?
    public var strokeColor: CanvasColor
    public var fillColor: CanvasColor?
    public var strokeWidth: Double
    public var sourceElementID: UUID?
    public var targetElementID: UUID?
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        kind: CanvasElementKind,
        center: CanvasPoint,
        size: CanvasSize,
        rotation: Double = 0,
        text: String? = nil,
        imageData: Data? = nil,
        shapeKind: CanvasShapeKind? = nil,
        strokeColor: CanvasColor = .ink,
        fillColor: CanvasColor? = nil,
        strokeWidth: Double = 3,
        sourceElementID: UUID? = nil,
        targetElementID: UUID? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.center = center
        self.size = size
        self.rotation = rotation
        self.text = text
        self.imageData = imageData
        self.shapeKind = shapeKind
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
        self.sourceElementID = sourceElementID
        self.targetElementID = targetElementID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct InfiniteCanvasManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var id: UUID
    public var documentType: DocumentKind
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var width: Double
    public var height: Double
    public var viewport: CanvasViewport
    public var tileConfiguration: CanvasTileConfiguration

    public init(
        schemaVersion: Int = InfiniteCanvasManifest.currentSchemaVersion,
        id: UUID = UUID(),
        documentType: DocumentKind = .infiniteCanvas,
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        width: Double = 16_384,
        height: Double = 16_384,
        viewport: CanvasViewport? = nil,
        tileConfiguration: CanvasTileConfiguration = CanvasTileConfiguration()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.documentType = documentType
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.width = width
        self.height = height
        self.viewport = viewport ?? CanvasViewport(
            center: CanvasPoint(x: width / 2, y: height / 2)
        )
        self.tileConfiguration = tileConfiguration
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, documentType, title, createdAt, modifiedAt
        case width, height, viewport, tileConfiguration
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        id = try values.decode(UUID.self, forKey: .id)
        documentType = try values.decode(DocumentKind.self, forKey: .documentType)
        title = try values.decode(String.self, forKey: .title)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        modifiedAt = try values.decode(Date.self, forKey: .modifiedAt)
        width = try values.decodeIfPresent(Double.self, forKey: .width) ?? 16_384
        height = try values.decodeIfPresent(Double.self, forKey: .height) ?? 16_384
        viewport = try values.decodeIfPresent(CanvasViewport.self, forKey: .viewport)
            ?? CanvasViewport(center: CanvasPoint(x: width / 2, y: height / 2))
        tileConfiguration = try values.decodeIfPresent(
            CanvasTileConfiguration.self,
            forKey: .tileConfiguration
        ) ?? CanvasTileConfiguration()
    }
}

public struct InfiniteCanvasDocument: Equatable, Sendable {
    public var manifest: InfiniteCanvasManifest
    public var drawingData: Data
    public var elements: [CanvasElement]

    public init(
        manifest: InfiniteCanvasManifest,
        drawingData: Data,
        elements: [CanvasElement] = []
    ) {
        self.manifest = manifest
        self.drawingData = drawingData
        self.elements = elements
    }
}
