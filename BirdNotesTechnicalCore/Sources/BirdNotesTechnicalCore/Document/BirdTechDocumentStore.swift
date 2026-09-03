import CryptoKit
import Foundation

public struct BirdTechStoreLimits: Sendable {
    public var maximumManifestBytes: Int
    public var maximumDiagramBytes: Int
    public var maximumCalculationsBytes: Int
    public var maximumAnnotationsBytes: Int
    public var maximumPreviewBytes: Int
    public var maximumCalculationCount: Int

    public init(
        maximumManifestBytes: Int = 1_000_000,
        maximumDiagramBytes: Int = 50_000_000,
        maximumCalculationsBytes: Int = 10_000_000,
        maximumAnnotationsBytes: Int = 100_000_000,
        maximumPreviewBytes: Int = 20_000_000,
        maximumCalculationCount: Int = 5_000
    ) {
        self.maximumManifestBytes = maximumManifestBytes
        self.maximumDiagramBytes = maximumDiagramBytes
        self.maximumCalculationsBytes = maximumCalculationsBytes
        self.maximumAnnotationsBytes = maximumAnnotationsBytes
        self.maximumPreviewBytes = maximumPreviewBytes
        self.maximumCalculationCount = maximumCalculationCount
    }

    public static let standard = BirdTechStoreLimits()
}

public actor BirdTechDocumentStore {
    private enum FileName {
        static let manifest = "manifest.json"
        static let diagram = "diagram.json"
        static let calculations = "calculations.json"
        static let annotations = "annotations.data"
        static let preview = "preview.png"
    }

    public let rootURL: URL
    public let limits: BirdTechStoreLimits
    private let fileManager: FileManager
    private let diagramValidator: DiagramValidator
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootURL: URL,
        limits: BirdTechStoreLimits = .standard,
        diagramValidator: DiagramValidator = DiagramValidator(),
        fileManager: FileManager = .default
    ) throws {
        guard rootURL.isFileURL else { throw TechnicalCoreError.unsafePath }
        self.rootURL = rootURL.standardizedFileURL
        self.limits = limits
        self.fileManager = fileManager
        self.diagramValidator = diagramValidator

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: self.rootURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue,
                  try !self.rootURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink.orFalse else {
                throw TechnicalCoreError.unsafePath
            }
        } else {
            try fileManager.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
        }
    }

    @discardableResult
    public func save(_ sourceDocument: BirdTechDocument) throws -> URL {
        try persist(sourceDocument, at: packageURL(for: sourceDocument.manifest.documentID))
    }

    @discardableResult
    public func save(_ sourceDocument: BirdTechDocument, at destinationURL: URL) throws -> URL {
        try persist(sourceDocument, at: validatedPackageDestination(destinationURL))
    }

    @discardableResult
    public func create(_ sourceDocument: BirdTechDocument, at destinationURL: URL) throws -> URL {
        let destination = try validatedPackageDestination(destinationURL)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw TechnicalCoreError.itemAlreadyExists
        }
        return try persist(sourceDocument, at: destination)
    }

    private func persist(_ sourceDocument: BirdTechDocument, at destination: URL) throws -> URL {
        var document = sourceDocument
        try validate(document)

        let now = Date()
        document.manifest.modifiedAt = now
        document.manifest.domain = document.diagram.domain

        let diagramData = try encoder.encode(document.diagram)
        let calculationsData = try encoder.encode(document.calculations)
        try enforceSize(diagramData, maximum: limits.maximumDiagramBytes, name: FileName.diagram)
        try enforceSize(calculationsData, maximum: limits.maximumCalculationsBytes, name: FileName.calculations)
        if let data = document.annotationsData {
            try enforceSize(data, maximum: limits.maximumAnnotationsBytes, name: FileName.annotations)
        }
        if let data = document.previewPNGData {
            try enforceSize(data, maximum: limits.maximumPreviewBytes, name: FileName.preview)
        }

        document.manifest.diagramSHA256 = sha256(diagramData)
        document.manifest.calculationsSHA256 = sha256(calculationsData)
        document.manifest.annotationsSHA256 = document.annotationsData.map(sha256)
        document.manifest.previewSHA256 = document.previewPNGData.map(sha256)
        let manifestData = try encoder.encode(document.manifest)
        try enforceSize(manifestData, maximum: limits.maximumManifestBytes, name: FileName.manifest)

        try rejectSymbolicItemIfPresent(at: destination)
        let temporary = rootURL.appendingPathComponent(".writing-\(UUID().uuidString).birdtech", isDirectory: true)
        let backup = rootURL.appendingPathComponent(".backup-\(UUID().uuidString).birdtech", isDirectory: true)

        do {
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: false)
            try manifestData.write(to: temporary.appendingPathComponent(FileName.manifest), options: [.atomic])
            try diagramData.write(to: temporary.appendingPathComponent(FileName.diagram), options: [.atomic])
            try calculationsData.write(to: temporary.appendingPathComponent(FileName.calculations), options: [.atomic])
            if let data = document.annotationsData {
                try data.write(to: temporary.appendingPathComponent(FileName.annotations), options: [.atomic])
            }
            if let data = document.previewPNGData {
                try data.write(to: temporary.appendingPathComponent(FileName.preview), options: [.atomic])
            }

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: destination, to: backup)
            }
            do {
                try fileManager.moveItem(at: temporary, to: destination)
                if fileManager.fileExists(atPath: backup.path) {
                    try? removeInternalItem(backup)
                }
            } catch {
                if !fileManager.fileExists(atPath: destination.path),
                   fileManager.fileExists(atPath: backup.path) {
                    try fileManager.moveItem(at: backup, to: destination)
                }
                throw error
            }
        } catch {
            try? removeInternalItem(temporary)
            throw error
        }

        return destination
    }

    public func load(documentID: UUID) throws -> BirdTechDocument {
        let directURL = try packageURL(for: documentID)
        if fileManager.fileExists(atPath: directURL.path) {
            return try load(from: directURL, expectedDocumentID: documentID)
        }
        guard let summary = try list().first(where: { $0.documentID == documentID }) else {
            throw TechnicalCoreError.itemNotFound
        }
        return try load(from: summary.url, expectedDocumentID: documentID)
    }

    public func load(from packageURL: URL) throws -> BirdTechDocument {
        try load(from: packageURL, expectedDocumentID: nil)
    }

    public func list() throws -> [BirdTechDocumentSummary] {
        let urls = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        var summaries: [BirdTechDocumentSummary] = []
        for url in urls where url.pathExtension.lowercased() == "birdtech" {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory.orFalse, !values.isSymbolicLink.orFalse else { continue }
            do {
                let manifestData = try read(
                    url.appendingPathComponent(FileName.manifest),
                    maximum: limits.maximumManifestBytes
                )
                let manifest = try decoder.decode(BirdTechManifest.self, from: manifestData)
                try validate(manifest)
                summaries.append(BirdTechDocumentSummary(
                    documentID: manifest.documentID,
                    title: manifest.title,
                    domain: manifest.domain,
                    modifiedAt: manifest.modifiedAt,
                    url: url
                ))
            } catch {
                // One damaged external package must not hide healthy documents.
                continue
            }
        }
        return summaries.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func delete(documentID: UUID) throws {
        let directURL = try packageURL(for: documentID)
        let url: URL
        if fileManager.fileExists(atPath: directURL.path) {
            url = directURL
        } else if let summary = try list().first(where: { $0.documentID == documentID }) {
            url = summary.url
        } else {
            throw TechnicalCoreError.itemNotFound
        }
        try rejectSymbolicItemIfPresent(at: url)
        try fileManager.removeItem(at: url)
    }

    private func load(from sourceURL: URL, expectedDocumentID: UUID?) throws -> BirdTechDocument {
        let packageURL = sourceURL.standardizedFileURL
        try requirePackageDirectory(packageURL)

        let manifestData = try read(
            packageURL.appendingPathComponent(FileName.manifest),
            maximum: limits.maximumManifestBytes
        )
        let diagramData = try read(
            packageURL.appendingPathComponent(FileName.diagram),
            maximum: limits.maximumDiagramBytes
        )
        let calculationsData = try read(
            packageURL.appendingPathComponent(FileName.calculations),
            maximum: limits.maximumCalculationsBytes
        )
        let manifest = try decoder.decode(BirdTechManifest.self, from: manifestData)
        try validate(manifest)
        if let expectedDocumentID, manifest.documentID != expectedDocumentID {
            throw TechnicalCoreError.invalidDocument("Dokumentkennung und Dateiname stimmen nicht überein.")
        }
        guard sha256(diagramData) == manifest.diagramSHA256,
              sha256(calculationsData) == manifest.calculationsSHA256 else {
            throw TechnicalCoreError.invalidDocument("Die Prüfsumme des Dokuments ist ungültig.")
        }

        let annotationsData = try readOptional(
            packageURL.appendingPathComponent(FileName.annotations),
            maximum: limits.maximumAnnotationsBytes,
            expectedSHA256: manifest.annotationsSHA256
        )
        let previewData = try readOptional(
            packageURL.appendingPathComponent(FileName.preview),
            maximum: limits.maximumPreviewBytes,
            expectedSHA256: manifest.previewSHA256
        )
        let diagram = try decoder.decode(TechnicalDiagram.self, from: diagramData)
        let calculations = try decoder.decode(TechnicalCalculations.self, from: calculationsData)
        let document = BirdTechDocument(
            manifest: manifest,
            diagram: diagram,
            calculations: calculations,
            annotationsData: annotationsData,
            previewPNGData: previewData
        )
        try validate(document)
        return document
    }

    private func validate(_ document: BirdTechDocument) throws {
        try validate(document.manifest)
        guard document.manifest.documentID != UUID.zero,
              document.manifest.domain == document.diagram.domain,
              document.calculations.schemaVersion == TechnicalCalculations.currentSchemaVersion,
              document.calculations.items.count <= limits.maximumCalculationCount,
              Set(document.calculations.items.map(\.id)).count == document.calculations.items.count else {
            throw TechnicalCoreError.invalidDocument("Manifest oder Berechnungen sind inkonsistent.")
        }
        try diagramValidator.validate(document.diagram)

        let engine = ExpressionEngine()
        for calculation in document.calculations.items {
            guard !calculation.name.isEmpty,
                  calculation.name.utf8.count <= 1_024 else {
                throw TechnicalCoreError.invalidDocument("Eine Berechnungsbezeichnung ist ungültig.")
            }
            _ = try engine.parse(calculation.expression)
        }
    }

    private func validate(_ manifest: BirdTechManifest) throws {
        guard manifest.schemaVersion == BirdTechManifest.currentSchemaVersion else {
            throw TechnicalCoreError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        guard !manifest.title.isEmpty,
              manifest.title.utf8.count <= 1_024,
              !manifest.writerVersion.isEmpty,
              manifest.writerVersion.utf8.count <= 128,
              manifest.moduleVersions.count <= 128,
              manifest.moduleVersions.allSatisfy({ key, value in
                  !key.isEmpty && key.utf8.count <= 128 && value.utf8.count <= 64
              }) else {
            throw TechnicalCoreError.invalidDocument("Das Manifest enthält ungültige Metadaten.")
        }
    }

    private func packageURL(for documentID: UUID) throws -> URL {
        guard documentID != UUID.zero else { throw TechnicalCoreError.invalidDocument("Leere Dokumentkennung.") }
        let url = rootURL.appendingPathComponent("\(documentID.uuidString).birdtech", isDirectory: true).standardizedFileURL
        guard url.deletingLastPathComponent() == rootURL else { throw TechnicalCoreError.unsafePath }
        return url
    }

    private func validatedPackageDestination(_ rawURL: URL) throws -> URL {
        let url = rawURL.standardizedFileURL
        let name = url.deletingPathExtension().lastPathComponent
        guard url.isFileURL,
              url.deletingLastPathComponent() == rootURL,
              url.pathExtension.lowercased() == "birdtech",
              !name.isEmpty,
              name.utf8.count <= 240,
              !name.hasPrefix("."),
              name != ".",
              name != ".." else {
            throw TechnicalCoreError.unsafePath
        }
        return url
    }

    private func requirePackageDirectory(_ url: URL) throws {
        guard url.isFileURL else { throw TechnicalCoreError.unsafePath }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory.orFalse, !values.isSymbolicLink.orFalse else {
            throw TechnicalCoreError.unsafePath
        }
    }

    private func rejectSymbolicItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard !values.isSymbolicLink.orFalse else { throw TechnicalCoreError.unsafePath }
    }

    private func read(_ url: URL, maximum: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile.orFalse,
              !values.isSymbolicLink.orFalse,
              let size = values.fileSize,
              size >= 0,
              size <= maximum else {
            throw TechnicalCoreError.invalidDocument("Eine Paketdatei fehlt oder ist zu groß.")
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        try enforceSize(data, maximum: maximum, name: url.lastPathComponent)
        return data
    }

    private func readOptional(_ url: URL, maximum: Int, expectedSHA256: String?) throws -> Data? {
        let exists = fileManager.fileExists(atPath: url.path)
        guard exists == (expectedSHA256 != nil) else {
            throw TechnicalCoreError.invalidDocument("Optionale Datei und Manifest stimmen nicht überein.")
        }
        guard exists, let expectedSHA256 else { return nil }
        let data = try read(url, maximum: maximum)
        guard sha256(data) == expectedSHA256 else {
            throw TechnicalCoreError.invalidDocument("Die Prüfsumme einer optionalen Datei ist ungültig.")
        }
        return data
    }

    private func enforceSize(_ data: Data, maximum: Int, name: String) throws {
        guard data.count <= maximum else {
            throw TechnicalCoreError.invalidDocument("\(name) überschreitet das Größenlimit.")
        }
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func removeInternalItem(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == rootURL,
              url.lastPathComponent.hasPrefix(".writing-") || url.lastPathComponent.hasPrefix(".backup-") else {
            throw TechnicalCoreError.unsafePath
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

private extension Optional where Wrapped == Bool {
    var orFalse: Bool { self ?? false }
}

private extension UUID {
    static let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
