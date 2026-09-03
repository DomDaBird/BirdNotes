import Foundation

public enum ReviewConfidence: String, Codable, CaseIterable, Hashable, Sendable {
    case again
    case hard
    case good
    case easy

    public var title: String {
        switch self {
        case .again: "Noch einmal"
        case .hard: "Schwierig"
        case .good: "Gut"
        case .easy: "Sicher"
        }
    }
}

public struct StudyReviewSchedule: Equatable, Sendable {
    public let confidence: ReviewConfidence
    public let reviewDates: [Date]
}

public enum SpacedRepetitionPlanner {
    public static func schedule(
        from startDate: Date,
        confidence: ReviewConfidence,
        sessionCount: Int = 6,
        calendar: Calendar = .current
    ) throws -> StudyReviewSchedule {
        guard (1...12).contains(sessionCount) else {
            throw StudyToolkitError.invalidInput(
                "Die Anzahl der Wiederholungen muss zwischen 1 und 12 liegen."
            )
        }
        let offsets: [Int] = switch confidence {
        case .again: [1, 2, 4, 7, 14, 30, 60, 90, 120, 180, 240, 365]
        case .hard: [2, 4, 7, 14, 30, 60, 90, 120, 180, 240, 300, 365]
        case .good: [3, 7, 14, 30, 60, 90, 120, 180, 240, 300, 365, 540]
        case .easy: [7, 14, 30, 60, 90, 120, 180, 240, 300, 365, 540, 730]
        }
        let dates = try offsets.prefix(sessionCount).map { days in
            guard let date = calendar.date(byAdding: .day, value: days, to: startDate) else {
                throw StudyToolkitError.resourceLimit(
                    "Der Wiederholungstermin liegt außerhalb des unterstützten Datumsbereichs."
                )
            }
            return date
        }
        return StudyReviewSchedule(confidence: confidence, reviewDates: dates)
    }
}

public struct JSONStudyFormatResult: Equatable, Sendable {
    public let prettyPrinted: String
    public let minified: String
    public let topLevelDescription: String
}

public enum JSONStudyFormatter {
    public static let maximumInputBytes = 1 * 1_024 * 1_024
    public static let maximumOutputBytes = 4 * 1_024 * 1_024

    public static func format(_ input: String) throws -> JSONStudyFormatResult {
        guard let inputData = input.data(using: .utf8),
              !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyToolkitError.invalidInput("Bitte JSON eingeben.")
        }
        guard inputData.count <= maximumInputBytes else {
            throw StudyToolkitError.resourceLimit("JSON darf höchstens 1 MB groß sein.")
        }
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: inputData, options: [.fragmentsAllowed])
        } catch {
            throw StudyToolkitError.invalidInput("Das JSON ist syntaktisch ungültig.")
        }
        do {
            let prettyData = try JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
            )
            let compactData = try JSONSerialization.data(
                withJSONObject: value,
                options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
            )
            guard prettyData.count <= maximumOutputBytes,
                  compactData.count <= maximumOutputBytes,
                  let pretty = String(data: prettyData, encoding: .utf8),
                  let compact = String(data: compactData, encoding: .utf8) else {
                throw StudyToolkitError.resourceLimit("Das formatierte JSON ist zu groß.")
            }
            return JSONStudyFormatResult(
                prettyPrinted: pretty,
                minified: compact,
                topLevelDescription: description(of: value)
            )
        } catch let error as StudyToolkitError {
            throw error
        } catch {
            throw StudyToolkitError.invalidInput("Das JSON konnte nicht verarbeitet werden.")
        }
    }

    private static func description(of value: Any) -> String {
        switch value {
        case let dictionary as [String: Any]: "Objekt mit \(dictionary.count) Schlüsseln"
        case let array as [Any]: "Array mit \(array.count) Einträgen"
        case is String: "Zeichenkette"
        case is NSNumber: "Zahl oder Wahrheitswert"
        case is NSNull: "null"
        default: "JSON-Wert"
        }
    }
}
