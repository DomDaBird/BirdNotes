import Foundation

public struct UnitIdentifier: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

public enum QuantitySemantic: String, Codable, Hashable, Sendable {
    case regular
    case absoluteTemperature
    case temperatureDifference
}

public struct UnitDefinition: Codable, Equatable, Sendable {
    public let id: UnitIdentifier
    public let symbol: String
    public let dimension: DimensionVector
    public let scaleToCanonical: Double
    public let offsetToCanonical: Double
    public let semantic: QuantitySemantic

    public init(
        id: UnitIdentifier,
        symbol: String,
        dimension: DimensionVector,
        scaleToCanonical: Double = 1,
        offsetToCanonical: Double = 0,
        semantic: QuantitySemantic = .regular
    ) throws {
        guard scaleToCanonical.isFinite, scaleToCanonical != 0,
              offsetToCanonical.isFinite else {
            throw TechnicalCoreError.nonFiniteNumber
        }
        self.id = id
        self.symbol = symbol
        self.dimension = dimension
        self.scaleToCanonical = scaleToCanonical
        self.offsetToCanonical = offsetToCanonical
        self.semantic = semantic
    }

    public func canonicalValue(for displayedValue: Double) throws -> Double {
        let value = displayedValue * scaleToCanonical + offsetToCanonical
        guard value.isFinite else { throw TechnicalCoreError.nonFiniteNumber }
        return value
    }

    public func displayedValue(forCanonicalValue canonicalValue: Double) throws -> Double {
        let value = (canonicalValue - offsetToCanonical) / scaleToCanonical
        guard value.isFinite else { throw TechnicalCoreError.nonFiniteNumber }
        return value
    }
}

public struct UnitRegistry: Sendable {
    private let definitions: [UnitIdentifier: UnitDefinition]

    public init(definitions: [UnitDefinition]) throws {
        var result: [UnitIdentifier: UnitDefinition] = [:]
        for definition in definitions {
            guard !definition.id.rawValue.isEmpty,
                  definition.id.rawValue.utf8.count <= 80,
                  result[definition.id] == nil else {
                throw TechnicalCoreError.duplicateIdentifier(definition.id.rawValue)
            }
            result[definition.id] = definition
        }
        self.definitions = result
    }

    public func unit(_ id: UnitIdentifier) throws -> UnitDefinition {
        guard let definition = definitions[id] else {
            throw TechnicalCoreError.unknownUnit(id.rawValue)
        }
        return definition
    }

    public var allUnits: [UnitDefinition] {
        definitions.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public static let si: UnitRegistry = {
        do {
            return try UnitRegistry(definitions: try standardSIUnits())
        } catch {
            preconditionFailure("The compiled SI unit catalog is invalid: \(error)")
        }
    }()

    private static func standardSIUnits() throws -> [UnitDefinition] {
        [
            try .init(id: "one", symbol: "", dimension: .dimensionless),
            try .init(id: "percent", symbol: "%", dimension: .dimensionless, scaleToCanonical: 0.01),
            try .init(id: "radian", symbol: "rad", dimension: .dimensionless),
            try .init(id: "degree", symbol: "°", dimension: .dimensionless, scaleToCanonical: .pi / 180),
            try .init(id: "metre", symbol: "m", dimension: .length),
            try .init(id: "millimetre", symbol: "mm", dimension: .length, scaleToCanonical: 0.001),
            try .init(id: "centimetre", symbol: "cm", dimension: .length, scaleToCanonical: 0.01),
            try .init(id: "kilometre", symbol: "km", dimension: .length, scaleToCanonical: 1_000),
            try .init(id: "second", symbol: "s", dimension: .time),
            try .init(id: "millisecond", symbol: "ms", dimension: .time, scaleToCanonical: 0.001),
            try .init(id: "kilogram", symbol: "kg", dimension: .mass),
            try .init(id: "gram", symbol: "g", dimension: .mass, scaleToCanonical: 0.001),
            try .init(id: "ampere", symbol: "A", dimension: .electricCurrent),
            try .init(id: "milliampere", symbol: "mA", dimension: .electricCurrent, scaleToCanonical: 0.001),
            try .init(id: "kelvin", symbol: "K", dimension: .temperature, semantic: .absoluteTemperature),
            try .init(
                id: "degreeCelsius", symbol: "°C", dimension: .temperature,
                offsetToCanonical: 273.15, semantic: .absoluteTemperature
            ),
            try .init(id: "kelvinDifference", symbol: "K", dimension: .temperature, semantic: .temperatureDifference),
            try .init(id: "celsiusDifference", symbol: "Δ°C", dimension: .temperature, semantic: .temperatureDifference),
            try .init(id: "hertz", symbol: "Hz", dimension: .frequency),
            try .init(id: "metrePerSecond", symbol: "m/s", dimension: .velocity),
            try .init(id: "metrePerSecondSquared", symbol: "m/s²", dimension: .acceleration),
            try .init(id: "newton", symbol: "N", dimension: .force),
            try .init(id: "pascal", symbol: "Pa", dimension: .pressure),
            try .init(id: "joule", symbol: "J", dimension: .energy),
            try .init(id: "watt", symbol: "W", dimension: .power),
            try .init(id: "volt", symbol: "V", dimension: .voltage),
            try .init(id: "millivolt", symbol: "mV", dimension: .voltage, scaleToCanonical: 0.001),
            try .init(id: "ohm", symbol: "Ω", dimension: .resistance),
            try .init(id: "kiloohm", symbol: "kΩ", dimension: .resistance, scaleToCanonical: 1_000)
        ]
    }
}

public struct Quantity: Codable, Equatable, Sendable {
    public let canonicalValue: Double
    public let dimension: DimensionVector
    public let semantic: QuantitySemantic
    public var preferredDisplayUnit: UnitIdentifier?

    public init(
        canonicalValue: Double,
        dimension: DimensionVector,
        semantic: QuantitySemantic = .regular,
        preferredDisplayUnit: UnitIdentifier? = nil
    ) throws {
        guard canonicalValue.isFinite else { throw TechnicalCoreError.nonFiniteNumber }
        self.canonicalValue = canonicalValue
        self.dimension = dimension
        self.semantic = semantic
        self.preferredDisplayUnit = preferredDisplayUnit
    }

    public init(value: Double, unitID: UnitIdentifier, registry: UnitRegistry = .si) throws {
        let unit = try registry.unit(unitID)
        try self.init(
            canonicalValue: unit.canonicalValue(for: value),
            dimension: unit.dimension,
            semantic: unit.semantic,
            preferredDisplayUnit: unitID
        )
    }

    public static func dimensionless(_ value: Double) throws -> Self {
        try Self(canonicalValue: value, dimension: .dimensionless)
    }

    public func value(in unitID: UnitIdentifier, registry: UnitRegistry = .si) throws -> Double {
        let unit = try registry.unit(unitID)
        guard unit.dimension == dimension else { throw TechnicalCoreError.incompatibleDimensions }
        guard unit.semantic == semantic || (unit.semantic == .regular && semantic == .regular) else {
            throw TechnicalCoreError.incompatibleQuantitySemantics
        }
        return try unit.displayedValue(forCanonicalValue: canonicalValue)
    }

    public func adding(_ other: Self) throws -> Self {
        guard dimension == other.dimension else { throw TechnicalCoreError.incompatibleDimensions }
        let resultSemantic: QuantitySemantic
        switch (semantic, other.semantic) {
        case (.regular, .regular): resultSemantic = .regular
        case (.temperatureDifference, .temperatureDifference): resultSemantic = .temperatureDifference
        case (.absoluteTemperature, .temperatureDifference), (.temperatureDifference, .absoluteTemperature):
            resultSemantic = .absoluteTemperature
        default: throw TechnicalCoreError.incompatibleQuantitySemantics
        }
        return try Self(
            canonicalValue: canonicalValue + other.canonicalValue,
            dimension: dimension,
            semantic: resultSemantic,
            preferredDisplayUnit: preferredDisplayUnit
        )
    }

    public func subtracting(_ other: Self) throws -> Self {
        guard dimension == other.dimension else { throw TechnicalCoreError.incompatibleDimensions }
        let resultSemantic: QuantitySemantic
        switch (semantic, other.semantic) {
        case (.regular, .regular): resultSemantic = .regular
        case (.temperatureDifference, .temperatureDifference): resultSemantic = .temperatureDifference
        case (.absoluteTemperature, .temperatureDifference): resultSemantic = .absoluteTemperature
        case (.absoluteTemperature, .absoluteTemperature): resultSemantic = .temperatureDifference
        default: throw TechnicalCoreError.incompatibleQuantitySemantics
        }
        return try Self(
            canonicalValue: canonicalValue - other.canonicalValue,
            dimension: dimension,
            semantic: resultSemantic,
            preferredDisplayUnit: resultSemantic == semantic ? preferredDisplayUnit : nil
        )
    }

    public func multiplied(by other: Self) throws -> Self {
        guard semantic == .regular, other.semantic == .regular else {
            throw TechnicalCoreError.incompatibleQuantitySemantics
        }
        return try Self(
            canonicalValue: canonicalValue * other.canonicalValue,
            dimension: dimension + other.dimension
        )
    }

    public func divided(by other: Self) throws -> Self {
        guard semantic == .regular, other.semantic == .regular else {
            throw TechnicalCoreError.incompatibleQuantitySemantics
        }
        guard other.canonicalValue != 0 else { throw TechnicalCoreError.divisionByZero }
        return try Self(
            canonicalValue: canonicalValue / other.canonicalValue,
            dimension: dimension - other.dimension
        )
    }

    public func powered(by exponent: Int) throws -> Self {
        guard semantic == .regular else { throw TechnicalCoreError.incompatibleQuantitySemantics }
        guard (-12...12).contains(exponent) else {
            throw TechnicalCoreError.expressionLimitExceeded("Exponent")
        }
        return try Self(
            canonicalValue: Foundation.pow(canonicalValue, Double(exponent)),
            dimension: dimension.powered(by: exponent)
        )
    }
}
