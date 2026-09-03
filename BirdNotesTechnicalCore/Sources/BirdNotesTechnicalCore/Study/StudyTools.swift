import Foundation

public enum StudyToolkitError: Error, LocalizedError, Equatable, Sendable {
    case invalidInput(String)
    case resourceLimit(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message), .resourceLimit(let message): message
        }
    }
}

public struct StudyWorkloadPlan: Equatable, Sendable {
    public let credits: Double
    public let weeks: Int
    public let totalHours: Double
    public let hoursPerWeek: Double

    public static func calculate(credits: Double, weeks: Int) throws -> StudyWorkloadPlan {
        guard credits.isFinite, credits > 0, credits <= 60 else {
            throw StudyToolkitError.invalidInput("CP müssen zwischen 0 und 60 liegen.")
        }
        guard (1...104).contains(weeks) else {
            throw StudyToolkitError.invalidInput("Die Laufzeit muss zwischen 1 und 104 Wochen liegen.")
        }
        let total = credits * 30
        return StudyWorkloadPlan(
            credits: credits,
            weeks: weeks,
            totalHours: total,
            hoursPerWeek: total / Double(weeks)
        )
    }
}

public struct DescriptiveStatisticsResult: Equatable, Sendable {
    public let count: Int
    public let minimum: Double
    public let maximum: Double
    public let mean: Double
    public let median: Double
    public let variance: Double
    public let standardDeviation: Double
}

public enum DescriptiveStatistics {
    public static func analyze(_ values: [Double], usesSampleVariance: Bool = false) throws -> DescriptiveStatisticsResult {
        guard !values.isEmpty else {
            throw StudyToolkitError.invalidInput("Mindestens ein Zahlenwert wird benötigt.")
        }
        guard values.count <= 100_000 else {
            throw StudyToolkitError.resourceLimit("Maximal 100.000 Werte können ausgewertet werden.")
        }
        guard values.allSatisfy(\.isFinite) else {
            throw StudyToolkitError.invalidInput("Alle Werte müssen endlich sein.")
        }
        guard !usesSampleVariance || values.count >= 2 else {
            throw StudyToolkitError.invalidInput("Für eine Stichprobenvarianz werden mindestens zwei Werte benötigt.")
        }

        let sorted = values.sorted()
        let mean = compensatedSum(values) / Double(values.count)
        let squaredDifferences = values.map { value in
            let difference = value - mean
            return difference * difference
        }
        let divisor = Double(usesSampleVariance ? values.count - 1 : values.count)
        let variance = compensatedSum(squaredDifferences) / divisor
        let middle = values.count / 2
        let median = values.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]

        guard mean.isFinite, variance.isFinite, median.isFinite else {
            throw StudyToolkitError.resourceLimit("Die Werte überschreiten den sicheren Rechenbereich.")
        }
        return DescriptiveStatisticsResult(
            count: values.count,
            minimum: sorted[0],
            maximum: sorted[sorted.count - 1],
            mean: mean,
            median: median,
            variance: variance,
            standardDeviation: variance.squareRoot()
        )
    }

    private static func compensatedSum(_ values: [Double]) -> Double {
        var sum = 0.0
        var compensation = 0.0
        for value in values {
            let adjusted = value - compensation
            let next = sum + adjusted
            compensation = (next - sum) - adjusted
            sum = next
        }
        return sum
    }
}

public enum NumberBase: Int, Codable, CaseIterable, Hashable, Sendable {
    case binary = 2
    case octal = 8
    case decimal = 10
    case hexadecimal = 16

    public var title: String {
        switch self {
        case .binary: "Binär"
        case .octal: "Oktal"
        case .decimal: "Dezimal"
        case .hexadecimal: "Hexadezimal"
        }
    }
}

public struct NumberSystemResult: Equatable, Sendable {
    public let decimalValue: Int64
    public let binary: String
    public let octal: String
    public let decimal: String
    public let hexadecimal: String
}

public enum NumberSystemConverter {
    public static func convert(_ input: String, from base: NumberBase) throws -> NumberSystemResult {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 64 else {
            throw StudyToolkitError.invalidInput("Die Zahl ist leer oder zu lang.")
        }
        guard !value.contains(where: { $0.isWhitespace }),
              let parsed = Int64(value, radix: base.rawValue) else {
            throw StudyToolkitError.invalidInput("Die Eingabe passt nicht zum gewählten Zahlensystem.")
        }
        return NumberSystemResult(
            decimalValue: parsed,
            binary: String(parsed, radix: 2),
            octal: String(parsed, radix: 8),
            decimal: String(parsed, radix: 10),
            hexadecimal: String(parsed, radix: 16, uppercase: true)
        )
    }
}

public enum AlgorithmComplexity: String, Codable, CaseIterable, Hashable, Sendable {
    case constant
    case logarithmic
    case linear
    case linearithmic
    case quadratic
    case cubic
    case exponential

    public var notation: String {
        switch self {
        case .constant: "O(1)"
        case .logarithmic: "O(log n)"
        case .linear: "O(n)"
        case .linearithmic: "O(n log n)"
        case .quadratic: "O(n²)"
        case .cubic: "O(n³)"
        case .exponential: "O(2ⁿ)"
        }
    }

    public func estimateOperations(for inputSize: Int) throws -> Double {
        guard (1...1_000_000_000).contains(inputSize) else {
            throw StudyToolkitError.invalidInput("n muss zwischen 1 und 1.000.000.000 liegen.")
        }
        let n = Double(inputSize)
        let result: Double = switch self {
        case .constant: 1
        case .logarithmic: log2(n)
        case .linear: n
        case .linearithmic: n * log2(n)
        case .quadratic: n * n
        case .cubic: n * n * n
        case .exponential: pow(2, n)
        }
        guard result.isFinite, result <= 1e18 else {
            throw StudyToolkitError.resourceLimit("Die geschätzte Operationszahl überschreitet 10¹⁸.")
        }
        return result
    }
}

public struct IPv4NetworkResult: Equatable, Sendable {
    public let networkAddress: String
    public let broadcastAddress: String
    public let firstHost: String
    public let lastHost: String
    public let addressCount: UInt64
    public let usableHostCount: UInt64
}

public enum IPv4NetworkCalculator {
    public static func calculate(address: String, prefixLength: Int) throws -> IPv4NetworkResult {
        guard (0...32).contains(prefixLength) else {
            throw StudyToolkitError.invalidInput("Das CIDR-Präfix muss zwischen 0 und 32 liegen.")
        }
        let octets = address.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else {
            throw StudyToolkitError.invalidInput("Die IPv4-Adresse muss aus vier Oktetten bestehen.")
        }
        var raw: UInt32 = 0
        for octet in octets {
            guard octet.count <= 3,
                  octet.allSatisfy(\.isNumber),
                  let value = UInt8(octet) else {
                throw StudyToolkitError.invalidInput("Die IPv4-Adresse enthält ein ungültiges Oktett.")
            }
            raw = (raw << 8) | UInt32(value)
        }

        let mask: UInt32 = prefixLength == 0 ? 0 : UInt32.max << UInt32(32 - prefixLength)
        let network = raw & mask
        let broadcast = network | ~mask
        let addressCount = UInt64(1) << UInt64(32 - prefixLength)
        let first: UInt32
        let last: UInt32
        let usable: UInt64
        if prefixLength >= 31 {
            first = network
            last = broadcast
            usable = addressCount
        } else {
            first = network + 1
            last = broadcast - 1
            usable = addressCount - 2
        }
        return IPv4NetworkResult(
            networkAddress: format(network),
            broadcastAddress: format(broadcast),
            firstHost: format(first),
            lastHost: format(last),
            addressCount: addressCount,
            usableHostCount: usable
        )
    }

    private static func format(_ value: UInt32) -> String {
        [24, 16, 8, 0]
            .map { String((value >> UInt32($0)) & 0xFF) }
            .joined(separator: ".")
    }
}

public enum RequirementFindingSeverity: String, Codable, Sendable {
    case error
    case warning
    case suggestion
}

public struct RequirementFinding: Equatable, Sendable, Identifiable {
    public var id: String { code }
    public let code: String
    public let severity: RequirementFindingSeverity
    public let message: String
}

public struct RequirementReview: Equatable, Sendable {
    public let score: Int
    public let findings: [RequirementFinding]
    public var isReadyForReview: Bool { !findings.contains { $0.severity == .error } }
}

public enum RequirementReviewer {
    private static let vagueWords = [
        "benutzerfreundlich", "einfach", "intuitiv", "möglichst", "schnell", "zeitnah",
        "optimal", "ausreichend", "gegebenenfalls", "etc."
    ]

    public static func review(statement: String, acceptanceCriteria: String) throws -> RequirementReview {
        let statement = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        let criteria = acceptanceCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        guard statement.utf8.count <= 2_000, criteria.utf8.count <= 4_000 else {
            throw StudyToolkitError.resourceLimit("Die Anforderung oder ihre Akzeptanzkriterien sind zu lang.")
        }

        var findings: [RequirementFinding] = []
        if statement.isEmpty {
            findings.append(.init(code: "statement.empty", severity: .error, message: "Eine Anforderung fehlt."))
        } else {
            let normalized = statement.lowercased()
            if ![" muss ", " soll ", " kann ", " must ", " shall "].contains(where: { " \(normalized) ".contains($0) }) {
                findings.append(.init(
                    code: "statement.priority",
                    severity: .warning,
                    message: "Die Verbindlichkeit ist nicht mit muss, soll oder kann erkennbar."
                ))
            }
            let usedVagueWords = vagueWords.filter { normalized.contains($0) }
            if !usedVagueWords.isEmpty {
                findings.append(.init(
                    code: "statement.vague",
                    severity: .warning,
                    message: "Unklare Begriffe konkretisieren: \(usedVagueWords.joined(separator: ", "))."
                ))
            }
            if statement.count < 20 {
                findings.append(.init(
                    code: "statement.short",
                    severity: .suggestion,
                    message: "Kontext, Akteur und gewünschtes Ergebnis könnten genauer beschrieben werden."
                ))
            }
        }
        if criteria.isEmpty {
            findings.append(.init(
                code: "criteria.empty",
                severity: .error,
                message: "Mindestens ein überprüfbares Akzeptanzkriterium fehlt."
            ))
        } else {
            let normalized = criteria.lowercased()
            let hasScenarioLanguage = normalized.contains("gegeben")
                || normalized.contains("wenn")
                || normalized.contains("dann")
                || normalized.contains("erwartet")
            let hasNumber = criteria.contains(where: \.isNumber)
            if !hasScenarioLanguage && !hasNumber {
                findings.append(.init(
                    code: "criteria.measurable",
                    severity: .warning,
                    message: "Das Akzeptanzkriterium sollte ein Szenario oder einen messbaren Grenzwert enthalten."
                ))
            }
        }

        let penalty = findings.reduce(0) { partial, finding in
            let value = switch finding.severity {
            case .error: 35
            case .warning: 15
            case .suggestion: 5
            }
            return partial + value
        }
        return RequirementReview(score: max(0, 100 - penalty), findings: findings)
    }
}
