import Foundation

public struct TechnicalPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct TechnicalSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct TechnicalRect: Codable, Hashable, Sendable {
    public var origin: TechnicalPoint
    public var size: TechnicalSize

    public init(origin: TechnicalPoint, size: TechnicalSize) {
        self.origin = origin
        self.size = size
    }

    public var center: TechnicalPoint {
        TechnicalPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }
}

public enum TechnicalDomain: String, Codable, CaseIterable, Sendable {
    case general
    case electricalEngineering
    case technicalDrawing
    case mechanics
    case informationTechnology
}

public enum PortDirection: String, Codable, Sendable {
    case input
    case output
    case bidirectional
    case passive
}

public struct DiagramPort: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var kind: String
    public var direction: PortDirection
    /// Relative position inside the element frame, normally in the range 0...1.
    public var position: TechnicalPoint

    public init(
        id: String,
        name: String,
        kind: String,
        direction: PortDirection = .passive,
        position: TechnicalPoint
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.direction = direction
        self.position = position
    }
}

public enum DiagramPropertyValue: Codable, Equatable, Sendable {
    case quantity(Quantity)
    case text(String)
    case boolean(Bool)
    case selection(String)
    case point(TechnicalPoint)
    case points([TechnicalPoint])
}

public struct DiagramElement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var moduleID: String
    public var symbolID: String
    public var frame: TechnicalRect
    public var rotationDegrees: Double
    public var ports: [DiagramPort]
    public var properties: [String: DiagramPropertyValue]
    public var label: String?
    public var layerID: UUID
    public var zIndex: Int
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        moduleID: String,
        symbolID: String,
        frame: TechnicalRect,
        rotationDegrees: Double = 0,
        ports: [DiagramPort] = [],
        properties: [String: DiagramPropertyValue] = [:],
        label: String? = nil,
        layerID: UUID,
        zIndex: Int = 0,
        isLocked: Bool = false
    ) {
        self.id = id
        self.moduleID = moduleID
        self.symbolID = symbolID
        self.frame = frame
        self.rotationDegrees = rotationDegrees
        self.ports = ports
        self.properties = properties
        self.label = label
        self.layerID = layerID
        self.zIndex = zIndex
        self.isLocked = isLocked
    }
}

public struct ConnectionEndpoint: Codable, Hashable, Sendable {
    public var elementID: UUID
    public var portID: String

    public init(elementID: UUID, portID: String) {
        self.elementID = elementID
        self.portID = portID
    }
}

public enum ConnectionStyle: String, Codable, Sendable {
    case straight
    case orthogonal
    case curved
}

public struct DiagramConnection: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var source: ConnectionEndpoint
    public var destination: ConnectionEndpoint
    public var route: [TechnicalPoint]
    public var style: ConnectionStyle
    public var properties: [String: DiagramPropertyValue]
    public var layerID: UUID

    public init(
        id: UUID = UUID(),
        source: ConnectionEndpoint,
        destination: ConnectionEndpoint,
        route: [TechnicalPoint] = [],
        style: ConnectionStyle = .orthogonal,
        properties: [String: DiagramPropertyValue] = [:],
        layerID: UUID
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.route = route
        self.style = style
        self.properties = properties
        self.layerID = layerID
    }
}

public struct DiagramLabel: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var position: TechnicalPoint
    public var rotationDegrees: Double
    public var layerID: UUID

    public init(
        id: UUID = UUID(),
        text: String,
        position: TechnicalPoint,
        rotationDegrees: Double = 0,
        layerID: UUID
    ) {
        self.id = id
        self.text = text
        self.position = position
        self.rotationDegrees = rotationDegrees
        self.layerID = layerID
    }
}

public struct DiagramLayer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isVisible: Bool
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        isVisible: Bool = true,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
    }
}

public enum DiagramConstraintKind: String, Codable, Sendable {
    case horizontal
    case vertical
    case coincident
    case parallel
    case perpendicular
    case distance
    case angle
}

public struct DiagramConstraint: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: DiagramConstraintKind
    public var elementIDs: [UUID]
    public var target: Quantity?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        kind: DiagramConstraintKind,
        elementIDs: [UUID],
        target: Quantity? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.elementIDs = elementIDs
        self.target = target
        self.isEnabled = isEnabled
    }
}

public struct DiagramGrid: Codable, Equatable, Sendable {
    public var isVisible: Bool
    public var isSnappingEnabled: Bool
    public var spacing: Double

    public init(isVisible: Bool = true, isSnappingEnabled: Bool = true, spacing: Double = 10) {
        self.isVisible = isVisible
        self.isSnappingEnabled = isSnappingEnabled
        self.spacing = spacing
    }
}

public struct TechnicalDiagram: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var domain: TechnicalDomain
    public var canvasSize: TechnicalSize
    public var grid: DiagramGrid
    public var layers: [DiagramLayer]
    public var elements: [DiagramElement]
    public var connections: [DiagramConnection]
    public var labels: [DiagramLabel]
    public var constraints: [DiagramConstraint]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        domain: TechnicalDomain,
        canvasSize: TechnicalSize = TechnicalSize(width: 2_000, height: 2_000),
        grid: DiagramGrid = DiagramGrid(),
        layers: [DiagramLayer] = [DiagramLayer(name: "Standard")],
        elements: [DiagramElement] = [],
        connections: [DiagramConnection] = [],
        labels: [DiagramLabel] = [],
        constraints: [DiagramConstraint] = []
    ) {
        self.schemaVersion = schemaVersion
        self.domain = domain
        self.canvasSize = canvasSize
        self.grid = grid
        self.layers = layers
        self.elements = elements
        self.connections = connections
        self.labels = labels
        self.constraints = constraints
    }
}
