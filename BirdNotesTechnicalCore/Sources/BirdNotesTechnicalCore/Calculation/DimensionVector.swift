import Foundation

/// Exponents of the seven SI base dimensions in the order defined by the BIPM.
/// Integer exponents deliberately exclude fractional dimensions from persisted
/// technical documents. Roots are accepted only when every exponent divides
/// exactly, avoiding silently approximated physical dimensions.
public struct DimensionVector: Codable, Hashable, Sendable {
    public var length: Int
    public var mass: Int
    public var time: Int
    public var electricCurrent: Int
    public var thermodynamicTemperature: Int
    public var amountOfSubstance: Int
    public var luminousIntensity: Int

    public init(
        length: Int = 0,
        mass: Int = 0,
        time: Int = 0,
        electricCurrent: Int = 0,
        thermodynamicTemperature: Int = 0,
        amountOfSubstance: Int = 0,
        luminousIntensity: Int = 0
    ) {
        self.length = length
        self.mass = mass
        self.time = time
        self.electricCurrent = electricCurrent
        self.thermodynamicTemperature = thermodynamicTemperature
        self.amountOfSubstance = amountOfSubstance
        self.luminousIntensity = luminousIntensity
    }

    public static let dimensionless = Self()
    public static let length = Self(length: 1)
    public static let mass = Self(mass: 1)
    public static let time = Self(time: 1)
    public static let electricCurrent = Self(electricCurrent: 1)
    public static let temperature = Self(thermodynamicTemperature: 1)
    public static let amountOfSubstance = Self(amountOfSubstance: 1)
    public static let luminousIntensity = Self(luminousIntensity: 1)

    public static let area = Self.length.powered(by: 2)
    public static let volume = Self.length.powered(by: 3)
    public static let frequency = Self.time.powered(by: -1)
    public static let velocity = Self.length - Self.time
    public static let acceleration = Self.length - Self.time.powered(by: 2)
    public static let force = Self.mass + Self.length - Self.time.powered(by: 2)
    public static let pressure = Self.force - Self.length.powered(by: 2)
    public static let energy = Self.force + Self.length
    public static let power = Self.energy - Self.time
    public static let electricCharge = Self.electricCurrent + Self.time
    public static let voltage = Self.mass + Self.length.powered(by: 2)
        - Self.time.powered(by: 3) - Self.electricCurrent
    public static let resistance = Self.voltage - Self.electricCurrent

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(
            length: lhs.length + rhs.length,
            mass: lhs.mass + rhs.mass,
            time: lhs.time + rhs.time,
            electricCurrent: lhs.electricCurrent + rhs.electricCurrent,
            thermodynamicTemperature: lhs.thermodynamicTemperature + rhs.thermodynamicTemperature,
            amountOfSubstance: lhs.amountOfSubstance + rhs.amountOfSubstance,
            luminousIntensity: lhs.luminousIntensity + rhs.luminousIntensity
        )
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        lhs + rhs.powered(by: -1)
    }

    public func powered(by exponent: Int) -> Self {
        Self(
            length: length * exponent,
            mass: mass * exponent,
            time: time * exponent,
            electricCurrent: electricCurrent * exponent,
            thermodynamicTemperature: thermodynamicTemperature * exponent,
            amountOfSubstance: amountOfSubstance * exponent,
            luminousIntensity: luminousIntensity * exponent
        )
    }

    public func exactRoot(degree: Int) throws -> Self {
        guard degree > 0 else { throw TechnicalCoreError.invalidRootDegree }
        let exponents = [
            length, mass, time, electricCurrent,
            thermodynamicTemperature, amountOfSubstance, luminousIntensity
        ]
        guard exponents.allSatisfy({ $0.isMultiple(of: degree) }) else {
            throw TechnicalCoreError.fractionalDimension
        }
        return Self(
            length: length / degree,
            mass: mass / degree,
            time: time / degree,
            electricCurrent: electricCurrent / degree,
            thermodynamicTemperature: thermodynamicTemperature / degree,
            amountOfSubstance: amountOfSubstance / degree,
            luminousIntensity: luminousIntensity / degree
        )
    }

    public var isDimensionless: Bool { self == .dimensionless }
}

public enum TechnicalCoreError: Error, Equatable, LocalizedError, Sendable {
    case duplicateIdentifier(String)
    case unknownUnit(String)
    case incompatibleDimensions
    case incompatibleQuantitySemantics
    case nonFiniteNumber
    case divisionByZero
    case invalidRootDegree
    case fractionalDimension
    case invalidExpression(String)
    case expressionLimitExceeded(String)
    case unknownVariable(String)
    case unsupportedFunction(String)
    case invalidFunctionArgument(String)
    case invalidDocument(String)
    case unsupportedSchemaVersion(Int)
    case unsafePath
    case itemAlreadyExists
    case itemNotFound
    case commandRejected(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateIdentifier(let value): "Doppelte Kennung: \(value)"
        case .unknownUnit(let value): "Unbekannte Einheit: \(value)"
        case .incompatibleDimensions: "Die physikalischen Dimensionen sind nicht kompatibel."
        case .incompatibleQuantitySemantics: "Absolute und relative Größen dürfen so nicht kombiniert werden."
        case .nonFiniteNumber: "Das Ergebnis ist keine endliche Zahl."
        case .divisionByZero: "Division durch null ist nicht zulässig."
        case .invalidRootDegree: "Der Wurzelexponent ist ungültig."
        case .fractionalDimension: "Die Wurzel würde eine nicht unterstützte gebrochene Dimension erzeugen."
        case .invalidExpression(let detail): "Ungültiger Ausdruck: \(detail)"
        case .expressionLimitExceeded(let detail): "Ausdrucksgrenze überschritten: \(detail)"
        case .unknownVariable(let name): "Unbekannte Variable: \(name)"
        case .unsupportedFunction(let name): "Nicht unterstützte Funktion: \(name)"
        case .invalidFunctionArgument(let name): "Ungültiges Argument für \(name)."
        case .invalidDocument(let detail): "Ungültiges technisches Dokument: \(detail)"
        case .unsupportedSchemaVersion(let version): "Nicht unterstützte .birdtech-Version: \(version)"
        case .unsafePath: "Der Dateipfad ist unsicher."
        case .itemAlreadyExists: "Am Ziel existiert bereits ein Dokument."
        case .itemNotFound: "Das technische Dokument wurde nicht gefunden."
        case .commandRejected(let detail): "Bearbeitung nicht möglich: \(detail)"
        }
    }
}
