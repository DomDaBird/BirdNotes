import Foundation

public struct SVGExportOptions: Sendable {
    public var lineWidth: Double
    public var fontSize: Double
    public var includesGrid: Bool
    public var maximumOutputBytes: Int

    public init(
        lineWidth: Double = 2,
        fontSize: Double = 16,
        includesGrid: Bool = false,
        maximumOutputBytes: Int = 50_000_000
    ) {
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.includesGrid = includesGrid
        self.maximumOutputBytes = maximumOutputBytes
    }
}

public struct SVGDiagramExporter: Sendable {
    public let registry: TechnicalModuleRegistry
    public let validator: DiagramValidator

    public init(
        registry: TechnicalModuleRegistry,
        validator: DiagramValidator = DiagramValidator()
    ) {
        self.registry = registry
        self.validator = validator
    }

    public func export(
        _ diagram: TechnicalDiagram,
        options: SVGExportOptions = SVGExportOptions()
    ) throws -> Data {
        try validator.validate(diagram)
        guard options.lineWidth.isFinite,
              options.lineWidth > 0,
              options.lineWidth <= 100,
              options.fontSize.isFinite,
              options.fontSize > 0,
              options.fontSize <= 1_000,
              options.maximumOutputBytes > 0 else {
            throw TechnicalCoreError.invalidDocument("Ungültige SVG-Exportoptionen.")
        }

        let visibleLayerIDs = Set(diagram.layers.filter(\.isVisible).map(\.id))
        let width = number(diagram.canvasSize.width)
        let height = number(diagram.canvasSize.height)
        var output = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)" role="img" aria-label="BirdNotes technical diagram">
        <rect width="100%" height="100%" fill="white"/>
        <g fill="none" stroke="#10243e" stroke-width="\(number(options.lineWidth))" stroke-linecap="round" stroke-linejoin="round">

        """

        if options.includesGrid, diagram.grid.isVisible {
            output += gridSVG(diagram: diagram)
        }

        let elementsByID = Dictionary(uniqueKeysWithValues: diagram.elements.map { ($0.id, $0) })
        for connection in diagram.connections where visibleLayerIDs.contains(connection.layerID) {
            guard let start = endpointPoint(connection.source, elementsByID: elementsByID),
                  let end = endpointPoint(connection.destination, elementsByID: elementsByID) else {
                continue
            }
            let points = [start] + connection.route + [end]
            output += "<polyline points=\"\(pointList(points))\"/>\n"
            try enforceLimit(output, maximum: options.maximumOutputBytes)
        }

        for element in diagram.elements
            .filter({ visibleLayerIDs.contains($0.layerID) })
            .sorted(by: { ($0.zIndex, $0.id.uuidString) < ($1.zIndex, $1.id.uuidString) }) {
            output += elementSVG(element, options: options)
            try enforceLimit(output, maximum: options.maximumOutputBytes)
        }

        output += "</g>\n<g fill=\"#10243e\" stroke=\"none\" font-family=\"-apple-system, sans-serif\" font-size=\"\(number(options.fontSize))\">\n"
        for label in diagram.labels where visibleLayerIDs.contains(label.layerID) {
            output += "<text x=\"\(number(label.position.x))\" y=\"\(number(label.position.y))\" transform=\"rotate(\(number(label.rotationDegrees)) \(number(label.position.x)) \(number(label.position.y)))\">\(escape(label.text))</text>\n"
        }
        for element in diagram.elements where visibleLayerIDs.contains(element.layerID) {
            if let label = element.label, !label.isEmpty {
                let center = element.frame.center
                output += "<text text-anchor=\"middle\" x=\"\(number(center.x))\" y=\"\(number(element.frame.origin.y - 8))\">\(escape(label))</text>\n"
            }
        }
        output += "</g>\n</svg>\n"
        try enforceLimit(output, maximum: options.maximumOutputBytes)
        return Data(output.utf8)
    }

    private func elementSVG(_ element: DiagramElement, options: SVGExportOptions) -> String {
        let center = element.frame.center
        let transform = "rotate(\(number(element.rotationDegrees)) \(number(center.x)) \(number(center.y)))"
        guard let definition = try? registry.symbol(moduleID: element.moduleID, symbolID: element.symbolID) else {
            return "<rect x=\"\(number(element.frame.origin.x))\" y=\"\(number(element.frame.origin.y))\" width=\"\(number(element.frame.size.width))\" height=\"\(number(element.frame.size.height))\" transform=\"\(transform)\"/>\n"
        }

        var result = "<g transform=\"\(transform)\">\n"
        for primitive in definition.primitives {
            switch primitive {
            case .line(let from, let to):
                let a = absolute(from, in: element.frame)
                let b = absolute(to, in: element.frame)
                result += "<line x1=\"\(number(a.x))\" y1=\"\(number(a.y))\" x2=\"\(number(b.x))\" y2=\"\(number(b.y))\"/>\n"
            case .polyline(let points):
                result += "<polyline points=\"\(pointList(points.map { absolute($0, in: element.frame) }))\"/>\n"
            case .rectangle(let rect):
                let origin = absolute(rect.origin, in: element.frame)
                result += "<rect x=\"\(number(origin.x))\" y=\"\(number(origin.y))\" width=\"\(number(rect.size.width * element.frame.size.width))\" height=\"\(number(rect.size.height * element.frame.size.height))\"/>\n"
            case .ellipse(let rect):
                let origin = absolute(rect.origin, in: element.frame)
                let radiusX = rect.size.width * element.frame.size.width / 2
                let radiusY = rect.size.height * element.frame.size.height / 2
                result += "<ellipse cx=\"\(number(origin.x + radiusX))\" cy=\"\(number(origin.y + radiusY))\" rx=\"\(number(radiusX))\" ry=\"\(number(radiusY))\"/>\n"
            case .text(let value, let position, let relativeSize):
                let location = absolute(position, in: element.frame)
                let size = min(element.frame.size.width, element.frame.size.height) * relativeSize
                result += "</g><text fill=\"#10243e\" stroke=\"none\" text-anchor=\"middle\" x=\"\(number(location.x))\" y=\"\(number(location.y))\" font-size=\"\(number(size))\" transform=\"\(transform)\">\(escape(value))</text><g transform=\"\(transform)\">\n"
            }
        }
        result += "</g>\n"
        return result
    }

    private func endpointPoint(
        _ endpoint: ConnectionEndpoint,
        elementsByID: [UUID: DiagramElement]
    ) -> TechnicalPoint? {
        guard let element = elementsByID[endpoint.elementID],
              let port = element.ports.first(where: { $0.id == endpoint.portID }) else {
            return nil
        }
        let unrotated = absolute(port.position, in: element.frame)
        let radians = element.rotationDegrees * .pi / 180
        let center = element.frame.center
        let deltaX = unrotated.x - center.x
        let deltaY = unrotated.y - center.y
        return TechnicalPoint(
            x: center.x + deltaX * cos(radians) - deltaY * sin(radians),
            y: center.y + deltaX * sin(radians) + deltaY * cos(radians)
        )
    }

    private func gridSVG(diagram: TechnicalDiagram) -> String {
        let spacing = diagram.grid.spacing
        let columns = Int(min(diagram.canvasSize.width / spacing, 10_000))
        let rows = Int(min(diagram.canvasSize.height / spacing, 10_000))
        var result = "<g stroke=\"#dce8f5\" stroke-width=\"0.5\">\n"
        for index in 0...columns {
            let x = Double(index) * spacing
            result += "<line x1=\"\(number(x))\" y1=\"0\" x2=\"\(number(x))\" y2=\"\(number(diagram.canvasSize.height))\"/>\n"
        }
        for index in 0...rows {
            let y = Double(index) * spacing
            result += "<line x1=\"0\" y1=\"\(number(y))\" x2=\"\(number(diagram.canvasSize.width))\" y2=\"\(number(y))\"/>\n"
        }
        return result + "</g>\n"
    }

    private func absolute(_ point: TechnicalPoint, in rect: TechnicalRect) -> TechnicalPoint {
        TechnicalPoint(
            x: rect.origin.x + point.x * rect.size.width,
            y: rect.origin.y + point.y * rect.size.height
        )
    }

    private func pointList(_ points: [TechnicalPoint]) -> String {
        points.map { "\(number($0.x)),\(number($0.y))" }.joined(separator: " ")
    }

    private func number(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
            .replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(\.[0-9]*?)0+$"#, with: "$1", options: .regularExpression)
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func enforceLimit(_ value: String, maximum: Int) throws {
        guard value.utf8.count <= maximum else {
            throw TechnicalCoreError.invalidDocument("Der SVG-Export überschreitet das Größenlimit.")
        }
    }
}
