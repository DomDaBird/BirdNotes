import Foundation

public struct DiagramLimits: Sendable {
    public var maximumElements: Int
    public var maximumConnections: Int
    public var maximumLabels: Int
    public var maximumConstraints: Int
    public var maximumLayers: Int
    public var maximumRoutePointsPerConnection: Int
    public var maximumPropertyEntriesPerItem: Int
    public var maximumTextLength: Int
    public var maximumCanvasExtent: Double

    public init(
        maximumElements: Int = 10_000,
        maximumConnections: Int = 20_000,
        maximumLabels: Int = 10_000,
        maximumConstraints: Int = 20_000,
        maximumLayers: Int = 500,
        maximumRoutePointsPerConnection: Int = 1_000,
        maximumPropertyEntriesPerItem: Int = 256,
        maximumTextLength: Int = 8_192,
        maximumCanvasExtent: Double = 10_000_000
    ) {
        self.maximumElements = maximumElements
        self.maximumConnections = maximumConnections
        self.maximumLabels = maximumLabels
        self.maximumConstraints = maximumConstraints
        self.maximumLayers = maximumLayers
        self.maximumRoutePointsPerConnection = maximumRoutePointsPerConnection
        self.maximumPropertyEntriesPerItem = maximumPropertyEntriesPerItem
        self.maximumTextLength = maximumTextLength
        self.maximumCanvasExtent = maximumCanvasExtent
    }

    public static let standard = DiagramLimits()
}

public struct DiagramValidator: Sendable {
    public let limits: DiagramLimits

    public init(limits: DiagramLimits = .standard) {
        self.limits = limits
    }

    public func validate(_ diagram: TechnicalDiagram) throws {
        guard diagram.schemaVersion == TechnicalDiagram.currentSchemaVersion else {
            throw TechnicalCoreError.unsupportedSchemaVersion(diagram.schemaVersion)
        }
        guard diagram.elements.count <= limits.maximumElements,
              diagram.connections.count <= limits.maximumConnections,
              diagram.labels.count <= limits.maximumLabels,
              diagram.constraints.count <= limits.maximumConstraints,
              !diagram.layers.isEmpty,
              diagram.layers.count <= limits.maximumLayers else {
            throw TechnicalCoreError.invalidDocument("Die zulässige Anzahl von Diagrammobjekten wurde überschritten.")
        }
        try validateCanvas(diagram.canvasSize, grid: diagram.grid)

        let layerIDs = try uniqueIDs(diagram.layers.map(\.id), objectName: "Ebene")
        let elementIDs = try uniqueIDs(diagram.elements.map(\.id), objectName: "Element")
        _ = try uniqueIDs(diagram.connections.map(\.id), objectName: "Verbindung")
        _ = try uniqueIDs(diagram.labels.map(\.id), objectName: "Beschriftung")
        _ = try uniqueIDs(diagram.constraints.map(\.id), objectName: "Bedingung")

        for layer in diagram.layers {
            try validateText(layer.name, field: "Ebenenname", allowEmpty: false)
        }

        var portsByElement: [UUID: Set<String>] = [:]
        for element in diagram.elements {
            guard layerIDs.contains(element.layerID) else {
                throw TechnicalCoreError.invalidDocument("Ein Element verweist auf eine unbekannte Ebene.")
            }
            try validateIdentifier(element.moduleID, field: "Modulkennung")
            try validateIdentifier(element.symbolID, field: "Symbolkennung")
            try validateRect(element.frame)
            try validateFinite(element.rotationDegrees, field: "Drehwinkel")
            if let label = element.label {
                try validateText(label, field: "Elementbeschriftung")
            }
            guard element.properties.count <= limits.maximumPropertyEntriesPerItem else {
                throw TechnicalCoreError.invalidDocument("Ein Element enthält zu viele Eigenschaften.")
            }
            try validateProperties(element.properties)

            var portIDs = Set<String>()
            for port in element.ports {
                try validateIdentifier(port.id, field: "Portkennung")
                try validateText(port.name, field: "Portname")
                try validateIdentifier(port.kind, field: "Porttyp")
                try validatePoint(port.position)
                guard (-0.001...1.001).contains(port.position.x),
                      (-0.001...1.001).contains(port.position.y),
                      portIDs.insert(port.id).inserted else {
                    throw TechnicalCoreError.invalidDocument("Ein Port ist ungültig oder doppelt vorhanden.")
                }
            }
            portsByElement[element.id] = portIDs
        }

        for connection in diagram.connections {
            guard layerIDs.contains(connection.layerID) else {
                throw TechnicalCoreError.invalidDocument("Eine Verbindung verweist auf eine unbekannte Ebene.")
            }
            guard connection.source != connection.destination else {
                throw TechnicalCoreError.invalidDocument("Eine Verbindung darf nicht denselben Port zweimal verwenden.")
            }
            try validate(connection.source, portsByElement: portsByElement)
            try validate(connection.destination, portsByElement: portsByElement)
            guard connection.route.count <= limits.maximumRoutePointsPerConnection,
                  connection.properties.count <= limits.maximumPropertyEntriesPerItem else {
                throw TechnicalCoreError.invalidDocument("Eine Verbindung ist zu komplex.")
            }
            try connection.route.forEach(validatePoint)
            try validateProperties(connection.properties)
        }

        for label in diagram.labels {
            guard layerIDs.contains(label.layerID) else {
                throw TechnicalCoreError.invalidDocument("Eine Beschriftung verweist auf eine unbekannte Ebene.")
            }
            try validateText(label.text, field: "Beschriftung")
            try validatePoint(label.position)
            try validateFinite(label.rotationDegrees, field: "Beschriftungswinkel")
        }

        for constraint in diagram.constraints {
            guard !constraint.elementIDs.isEmpty,
                  Set(constraint.elementIDs).isSubset(of: elementIDs) else {
                throw TechnicalCoreError.invalidDocument("Eine Bedingung verweist auf unbekannte Elemente.")
            }
            if let target = constraint.target {
                try validateFinite(target.canonicalValue, field: "Bedingungswert")
            }
        }
    }

    private func validateCanvas(_ size: TechnicalSize, grid: DiagramGrid) throws {
        try validateSize(size)
        guard size.width <= limits.maximumCanvasExtent,
              size.height <= limits.maximumCanvasExtent,
              grid.spacing.isFinite,
              grid.spacing >= 0.000_1,
              grid.spacing <= limits.maximumCanvasExtent else {
            throw TechnicalCoreError.invalidDocument("Canvas oder Raster liegen außerhalb der zulässigen Größe.")
        }
    }

    private func validate(_ endpoint: ConnectionEndpoint, portsByElement: [UUID: Set<String>]) throws {
        guard let ports = portsByElement[endpoint.elementID], ports.contains(endpoint.portID) else {
            throw TechnicalCoreError.invalidDocument("Eine Verbindung verweist auf einen unbekannten Port.")
        }
    }

    private func validateProperties(_ properties: [String: DiagramPropertyValue]) throws {
        for (key, value) in properties {
            try validateIdentifier(key, field: "Eigenschaftskennung")
            switch value {
            case .quantity(let quantity):
                try validateFinite(quantity.canonicalValue, field: "Eigenschaftswert")
            case .text(let text), .selection(let text):
                try validateText(text, field: "Eigenschaftstext")
            case .boolean:
                break
            case .point(let point):
                try validatePoint(point)
            case .points(let points):
                guard points.count <= limits.maximumRoutePointsPerConnection else {
                    throw TechnicalCoreError.invalidDocument("Eine Punkteigenschaft ist zu groß.")
                }
                try points.forEach(validatePoint)
            }
        }
    }

    private func validateIdentifier(_ value: String, field: String) throws {
        guard !value.isEmpty,
              value.utf8.count <= 128,
              value.utf8.allSatisfy({ byte in
                  (65...90).contains(byte)
                      || (97...122).contains(byte)
                      || (48...57).contains(byte)
                      || byte == 45 || byte == 46 || byte == 95
              }) else {
            throw TechnicalCoreError.invalidDocument("\(field) ist ungültig.")
        }
    }

    private func validateText(_ value: String, field: String, allowEmpty: Bool = true) throws {
        guard (allowEmpty || !value.isEmpty), value.utf8.count <= limits.maximumTextLength else {
            throw TechnicalCoreError.invalidDocument("\(field) ist zu lang oder leer.")
        }
    }

    private func validateRect(_ rect: TechnicalRect) throws {
        try validatePoint(rect.origin)
        try validateSize(rect.size)
    }

    private func validateSize(_ size: TechnicalSize) throws {
        try validateFinite(size.width, field: "Breite")
        try validateFinite(size.height, field: "Höhe")
        guard size.width > 0, size.height > 0 else {
            throw TechnicalCoreError.invalidDocument("Größen müssen positiv sein.")
        }
    }

    private func validatePoint(_ point: TechnicalPoint) throws {
        try validateFinite(point.x, field: "X-Koordinate")
        try validateFinite(point.y, field: "Y-Koordinate")
        guard abs(point.x) <= limits.maximumCanvasExtent,
              abs(point.y) <= limits.maximumCanvasExtent else {
            throw TechnicalCoreError.invalidDocument("Eine Koordinate liegt außerhalb des Canvas-Limits.")
        }
    }

    private func validateFinite(_ value: Double, field: String) throws {
        guard value.isFinite else {
            throw TechnicalCoreError.invalidDocument("\(field) ist keine endliche Zahl.")
        }
    }

    private func uniqueIDs(_ ids: [UUID], objectName: String) throws -> Set<UUID> {
        let unique = Set(ids)
        guard unique.count == ids.count else {
            throw TechnicalCoreError.invalidDocument("\(objectName)-Kennungen sind nicht eindeutig.")
        }
        return unique
    }
}
