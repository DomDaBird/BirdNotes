import Foundation

public enum DocumentStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidName(String)
    case invalidPath(String)
    case itemNotFound(String)
    case itemAlreadyExists(String)
    case notAFolder(String)
    case notANotebook(String)
    case notAProjectCanvas(String)
    case notAPDF(String)
    case unsupportedFileType(String)
    case resourceLimitExceeded(String)
    case damagedDocument(String)
    case unsupportedSchemaVersion(Int)
    case cannotDeleteOnlyPage
    case invalidPageOrder
    case externalConflict(String)
    case fileOperationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let name):
            "\"\(name)\" ist kein gültiger Name."
        case .invalidPath(let path):
            "Der Pfad \"\(path)\" ist ungültig."
        case .itemNotFound(let path):
            "\"\(path)\" wurde nicht gefunden."
        case .itemAlreadyExists(let path):
            "Unter \"\(path)\" existiert bereits ein Eintrag."
        case .notAFolder(let path):
            "\"\(path)\" ist kein Ordner."
        case .notANotebook(let path):
            "\"\(path)\" ist kein Notizbuch."
        case .notAProjectCanvas(let path):
            "\"\(path)\" ist kein Canvas."
        case .notAPDF(let path):
            "\"\(path)\" ist keine PDF-Datei."
        case .unsupportedFileType(let type):
            "Dateien vom Typ \"\(type)\" werden nicht unterstützt."
        case .resourceLimitExceeded(let detail):
            "Die Datei ist zu groß oder zu komplex: \(detail)"
        case .damagedDocument(let detail):
            "Das Dokument ist beschädigt: \(detail)"
        case .unsupportedSchemaVersion(let version):
            "Dokumentversion \(version) wird nicht unterstützt."
        case .cannotDeleteOnlyPage:
            "Die einzige Seite eines Notizbuchs kann nicht gelöscht werden."
        case .invalidPageOrder:
            "Die neue Seitenreihenfolge ist ungültig."
        case .externalConflict(let path):
            "\"\(path)\" wurde auf einem anderen Gerät geändert. Bitte lade die Bibliothek neu, bevor du weiterarbeitest."
        case .fileOperationFailed(let detail):
            "Dateivorgang fehlgeschlagen: \(detail)"
        }
    }
}
