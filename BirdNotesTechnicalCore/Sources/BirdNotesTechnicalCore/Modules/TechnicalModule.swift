import Foundation

public enum DiagramSymbolPrimitive: Codable, Equatable, Sendable {
    case line(from: TechnicalPoint, to: TechnicalPoint)
    case polyline([TechnicalPoint])
    case rectangle(TechnicalRect)
    case ellipse(TechnicalRect)
    case text(value: String, position: TechnicalPoint, relativeSize: Double)
}

public enum TechnicalPropertyKind: String, Codable, Sendable {
    case quantity
    case text
    case boolean
    case selection
}

public struct TechnicalPropertyDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: TechnicalPropertyKind
    public var defaultValue: DiagramPropertyValue
    public var allowedSelections: [String]

    public init(
        id: String,
        name: String,
        kind: TechnicalPropertyKind,
        defaultValue: DiagramPropertyValue,
        allowedSelections: [String] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.defaultValue = defaultValue
        self.allowedSelections = allowedSelections
    }
}

public struct TechnicalSymbolDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var defaultSize: TechnicalSize
    public var ports: [DiagramPort]
    public var properties: [TechnicalPropertyDefinition]
    public var primitives: [DiagramSymbolPrimitive]

    public init(
        id: String,
        name: String,
        defaultSize: TechnicalSize,
        ports: [DiagramPort] = [],
        properties: [TechnicalPropertyDefinition] = [],
        primitives: [DiagramSymbolPrimitive]
    ) {
        self.id = id
        self.name = name
        self.defaultSize = defaultSize
        self.ports = ports
        self.properties = properties
        self.primitives = primitives
    }
}

public struct CalculationVariableDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var dimension: DimensionVector
    public var suggestedUnitID: UnitIdentifier?

    public init(
        id: String,
        name: String,
        dimension: DimensionVector,
        suggestedUnitID: UnitIdentifier? = nil
    ) {
        self.id = id
        self.name = name
        self.dimension = dimension
        self.suggestedUnitID = suggestedUnitID
    }
}

public struct CalculationTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var expression: String
    public var variables: [CalculationVariableDefinition]

    public init(
        id: String,
        name: String,
        expression: String,
        variables: [CalculationVariableDefinition]
    ) {
        self.id = id
        self.name = name
        self.expression = expression
        self.variables = variables
    }
}

public struct TechnicalModuleDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var domain: TechnicalDomain
    public var symbols: [TechnicalSymbolDefinition]
    public var calculations: [CalculationTemplate]

    public init(
        id: String,
        name: String,
        version: String,
        domain: TechnicalDomain,
        symbols: [TechnicalSymbolDefinition],
        calculations: [CalculationTemplate] = []
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.domain = domain
        self.symbols = symbols
        self.calculations = calculations
    }
}

public struct TechnicalModuleRegistry: Sendable {
    private let modulesByID: [String: TechnicalModuleDefinition]

    public init(modules: [TechnicalModuleDefinition]) throws {
        guard modules.count <= 128 else {
            throw TechnicalCoreError.invalidDocument("Zu viele technische Module.")
        }
        var result: [String: TechnicalModuleDefinition] = [:]
        for module in modules {
            try Self.validate(module)
            guard result[module.id] == nil else {
                throw TechnicalCoreError.duplicateIdentifier(module.id)
            }
            result[module.id] = module
        }
        modulesByID = result
    }

    public var modules: [TechnicalModuleDefinition] {
        modulesByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public var versionMap: [String: String] {
        modulesByID.mapValues(\.version)
    }

    public func module(id: String) throws -> TechnicalModuleDefinition {
        guard let module = modulesByID[id] else { throw TechnicalCoreError.itemNotFound }
        return module
    }

    public func symbol(moduleID: String, symbolID: String) throws -> TechnicalSymbolDefinition {
        let module = try module(id: moduleID)
        guard let symbol = module.symbols.first(where: { $0.id == symbolID }) else {
            throw TechnicalCoreError.itemNotFound
        }
        return symbol
    }

    public func instantiate(
        moduleID: String,
        symbolID: String,
        at origin: TechnicalPoint,
        layerID: UUID
    ) throws -> DiagramElement {
        let definition = try symbol(moduleID: moduleID, symbolID: symbolID)
        return DiagramElement(
            moduleID: moduleID,
            symbolID: symbolID,
            frame: TechnicalRect(origin: origin, size: definition.defaultSize),
            ports: definition.ports,
            properties: Dictionary(uniqueKeysWithValues: definition.properties.map { ($0.id, $0.defaultValue) }),
            layerID: layerID
        )
    }

    private static func validate(_ module: TechnicalModuleDefinition) throws {
        try validateIdentifier(module.id)
        let versionParts = module.version.split(separator: ".", omittingEmptySubsequences: false)
        guard !module.name.isEmpty,
              module.name.utf8.count <= 256,
              versionParts.count == 3,
              versionParts.allSatisfy({ Int($0) != nil }),
              !module.symbols.isEmpty,
              module.symbols.count <= 1_000,
              module.calculations.count <= 1_000 else {
            throw TechnicalCoreError.invalidDocument("Ein technisches Modul ist ungültig.")
        }
        guard Set(module.symbols.map(\.id)).count == module.symbols.count,
              Set(module.calculations.map(\.id)).count == module.calculations.count else {
            throw TechnicalCoreError.invalidDocument("Ein Modul enthält doppelte Kennungen.")
        }

        for symbol in module.symbols {
            try validateIdentifier(symbol.id)
            guard !symbol.name.isEmpty,
                  symbol.name.utf8.count <= 256,
                  symbol.defaultSize.width.isFinite,
                  symbol.defaultSize.height.isFinite,
                  symbol.defaultSize.width > 0,
                  symbol.defaultSize.height > 0,
                  symbol.ports.count <= 128,
                  symbol.properties.count <= 256,
                  symbol.primitives.count <= 1_000,
                  Set(symbol.ports.map(\.id)).count == symbol.ports.count,
                  Set(symbol.properties.map(\.id)).count == symbol.properties.count else {
                throw TechnicalCoreError.invalidDocument("Eine Symboldefinition ist ungültig.")
            }
            for property in symbol.properties {
                try validateIdentifier(property.id)
                guard property.name.utf8.count <= 256,
                      property.allowedSelections.count <= 256,
                      property.allowedSelections.allSatisfy({ $0.utf8.count <= 256 }),
                      propertyMatchesKind(property) else {
                    throw TechnicalCoreError.invalidDocument("Eine Symboleigenschaft ist ungültig.")
                }
            }
            for port in symbol.ports {
                try validateIdentifier(port.id)
                try validateIdentifier(port.kind)
                guard port.name.utf8.count <= 256 else {
                    throw TechnicalCoreError.invalidDocument("Ein Symbolport ist ungültig.")
                }
                try validateNormalized(port.position)
            }
            try symbol.primitives.forEach(validate)
        }

        let engine = ExpressionEngine()
        for calculation in module.calculations {
            try validateIdentifier(calculation.id)
            let expression = try engine.parse(calculation.expression)
            guard !calculation.name.isEmpty,
                  calculation.name.utf8.count <= 256,
                  calculation.variables.count <= 64,
                  Set(calculation.variables.map(\.id)).count == calculation.variables.count else {
                throw TechnicalCoreError.invalidDocument("Eine Formelvorlage ist ungültig.")
            }
            try calculation.variables.forEach { try validateIdentifier($0.id) }
            guard expression.variableNames == Set(calculation.variables.map(\.id)) else {
                throw TechnicalCoreError.invalidDocument("Formel und Variablendefinition stimmen nicht überein.")
            }
        }
    }

    private static func propertyMatchesKind(_ property: TechnicalPropertyDefinition) -> Bool {
        switch (property.kind, property.defaultValue) {
        case (.quantity, .quantity), (.text, .text), (.boolean, .boolean):
            return property.allowedSelections.isEmpty
        case (.selection, .selection(let selected)):
            return !property.allowedSelections.isEmpty && property.allowedSelections.contains(selected)
        default:
            return false
        }
    }

    private static func validate(_ primitive: DiagramSymbolPrimitive) throws {
        switch primitive {
        case .line(let from, let to):
            try validateNormalized(from)
            try validateNormalized(to)
        case .polyline(let points):
            guard (2...10_000).contains(points.count) else {
                throw TechnicalCoreError.invalidDocument("Eine Symbolkontur ist ungültig.")
            }
            try points.forEach(validateNormalized)
        case .rectangle(let rect), .ellipse(let rect):
            try validateNormalized(rect.origin)
            guard rect.size.width.isFinite,
                  rect.size.height.isFinite,
                  rect.size.width > 0,
                  rect.size.height > 0,
                  rect.size.width <= 10,
                  rect.size.height <= 10 else {
                throw TechnicalCoreError.invalidDocument("Eine Symbolfläche ist ungültig.")
            }
        case .text(let value, let position, let relativeSize):
            try validateNormalized(position)
            guard value.utf8.count <= 256,
                  relativeSize.isFinite,
                  (0.001...10).contains(relativeSize) else {
                throw TechnicalCoreError.invalidDocument("Ein Symboltext ist ungültig.")
            }
        }
    }

    private static func validateNormalized(_ point: TechnicalPoint) throws {
        guard point.x.isFinite,
              point.y.isFinite,
              (-10...10).contains(point.x),
              (-10...10).contains(point.y) else {
            throw TechnicalCoreError.invalidDocument("Eine normalisierte Symbolkoordinate ist ungültig.")
        }
    }

    private static func validateIdentifier(_ value: String) throws {
        guard !value.isEmpty,
              value.utf8.count <= 128,
              value.utf8.allSatisfy({ byte in
                  (65...90).contains(byte)
                      || (97...122).contains(byte)
                      || (48...57).contains(byte)
                      || byte == 45 || byte == 46 || byte == 95
              }) else {
            throw TechnicalCoreError.invalidDocument("Ungültige Modulkennung.")
        }
    }
}
