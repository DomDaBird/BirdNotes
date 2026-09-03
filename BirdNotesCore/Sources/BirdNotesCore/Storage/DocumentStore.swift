import CryptoKit
import Foundation

public enum DocumentStoreLimits: Sendable {
    public static let maximumNameLength = 200
    public static let maximumPDFBytes = 512 * 1_024 * 1_024
    public static let maximumDrawingBytes = 128 * 1_024 * 1_024
    public static let maximumMetadataBytes = 2 * 1_024 * 1_024
    public static let maximumTrashMetadataBytes = 4 * 1_024 * 1_024
    public static let maximumCanvasElementsBytes = 64 * 1_024 * 1_024
    public static let maximumCanvasImageBytes = 20 * 1_024 * 1_024
    public static let maximumCanvasImageTotalBytes = 48 * 1_024 * 1_024
    public static let maximumCanvasElements = 10_000
    public static let maximumCanvasTextCharacters = 100_000
    public static let maximumNotebookPages = 10_000
    public static let maximumPDFAnnotationPages = 100_000
    public static let maximumBackupItems = 100_000
    public static let maximumBackupDepth = 100
    public static let maximumBackupBytes: Int64 = 20 * 1_024 * 1_024 * 1_024
    public static let maximumTranscriptionCharacters = 250_000
    public static let maximumTranscriptionBytes = 1 * 1_024 * 1_024
}

private struct DocumentSaveJournal: Codable {
    static let currentSchemaVersion = 1
    static let transactionType = "documentSave"
    static let maximumEntries = 16

    enum Action: String, Codable {
        case replaceFile
        case deleteDirectory
    }

    struct Entry: Codable {
        let targetRelativePath: String
        let action: Action
        let incomingName: String?
        let byteCount: Int?
        let sha256: String?
    }

    let schemaVersion: Int
    let transactionType: String
    var committed: Bool
    let documentKind: DocumentKind
    let packageRelativePath: String
    let documentID: UUID
    let entries: [Entry]
}

private struct DocumentSaveMutation {
    let targetRelativePath: String
    let action: DocumentSaveJournal.Action
    let data: Data?

    static func replace(_ targetRelativePath: String, with data: Data) -> Self {
        Self(targetRelativePath: targetRelativePath, action: .replaceFile, data: data)
    }

    static func deleteDirectory(_ targetRelativePath: String) -> Self {
        Self(targetRelativePath: targetRelativePath, action: .deleteDirectory, data: nil)
    }
}

private struct TechnicalDocumentIndexManifest: Codable {
    let schemaVersion: Int
    var documentID: UUID
    var title: String
    let createdAt: Date
    let modifiedAt: Date
    let writerVersion: String
    let moduleVersions: [String: String]
    let diagramSHA256: String
    let calculationsSHA256: String
    let annotationsSHA256: String?
    let previewSHA256: String?
}

public actor DocumentStore {
    public static let notebookExtension = "birdnotebook"
    public static let canvasExtension = "birdcanvas"
    public static let technicalDiagramExtension = "birdtech"
    public static let backupExtension = "birdbackup"
    private static let libraryStateFileName = ".birdnotes-library.json"
    private static let trashDirectoryName = ".birdnotes-trash"
    private static let transactionDirectoryName = ".birdnotes-transactions"
    private static let maximumTrashEntries = 30

    public nonisolated let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager

        do {
            try fileManager.createDirectory(
                at: self.rootURL,
                withIntermediateDirectories: true
            )
            #if os(iOS)
            if let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first,
            self.rootURL.path.hasPrefix(applicationSupport.standardizedFileURL.path + "/") {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: self.rootURL.path
                )
            }
            #endif
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public static func defaultRootURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DocumentStoreError.fileOperationFailed(
                "Der Application-Support-Ordner ist nicht verfügbar."
            )
        }

        return applicationSupport
            .appendingPathComponent("BirdNotes", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
    }

    // MARK: - Library

    public func listItems(in relativeFolderPath: String = "") throws -> [LibraryItem] {
        let folderURL = try existingFolderURL(for: relativeFolderPath)

        do {
            return try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .creationDateKey,
                    .contentModificationDateKey,
                    .isHiddenKey,
                    .isSymbolicLinkKey
                ],
                options: [.skipsHiddenFiles]
            ).compactMap { url -> LibraryItem? in
                do {
                    let values = try url.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .creationDateKey,
                    .contentModificationDateKey,
                    .isHiddenKey,
                    .isSymbolicLinkKey
                    ])
                    guard values.isHidden != true,
                          values.isSymbolicLink != true,
                          let kind = itemKind(for: url, isDirectory: values.isDirectory == true) else {
                        return nil
                    }

                    let path = try relativePath(for: url)
                    let documentDates: (created: Date, modified: Date)?
                    switch kind {
                    case .notebook:
                        documentDates = (try? readManifest(at: url)).map { ($0.createdAt, $0.modifiedAt) }
                    case .infiniteCanvas:
                        documentDates = (try? readCanvasManifest(at: url)).map { ($0.createdAt, $0.modifiedAt) }
                    case .technicalDiagram:
                        documentDates = (try? readTechnicalIndexManifest(at: url)).map {
                            ($0.createdAt, $0.modifiedAt)
                        }
                    case .folder, .pdf:
                        documentDates = nil
                    }
                    return LibraryItem(
                        id: path,
                        name: displayName(for: url, kind: kind),
                        kind: kind,
                        relativePath: path,
                        createdAt: documentDates?.created ?? values.creationDate ?? .distantPast,
                        modifiedAt: documentDates?.modified
                            ?? values.contentModificationDate
                            ?? values.creationDate
                            ?? .distantPast
                    )
                } catch {
                    // One inaccessible external item must not make the complete
                    // user-selected library unavailable.
                    return nil
                }
            }
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public func allFolderPaths() throws -> [String] {
        var result = [""]
        var pending = [""]

        while !pending.isEmpty {
            let folder = pending.removeFirst()
            let children = try listItems(in: folder)
                .filter { $0.kind == .folder }
                .map(\.relativePath)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            result.append(contentsOf: children)
            pending.append(contentsOf: children)
        }

        return result
    }

    public func allItems() throws -> [LibraryItem] {
        var result: [LibraryItem] = []
        var pending = [""]

        while let folder = pending.first {
            pending.removeFirst()
            let children = try listItems(in: folder)
            result.append(contentsOf: children)
            pending.append(contentsOf: children.compactMap {
                $0.kind == .folder ? $0.relativePath : nil
            })
        }

        return result
    }

    public func searchTranscribedText(_ rawQuery: String) throws -> [LibraryTextSearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, query.count <= 200 else { return [] }
        var hits: [LibraryTextSearchHit] = []
        for item in try allItems() where item.kind == .notebook {
            let packageURL = try existingNotebookURL(for: item.relativePath)
            let manifest = try readManifest(at: packageURL)
            for (index, pageID) in manifest.pageOrder.enumerated() {
                let metadata = try readPageMetadata(pageID, in: packageURL)
                guard let text = metadata.transcribedText,
                      let range = text.range(
                        of: query,
                        options: [.caseInsensitive, .diacriticInsensitive]
                      ) else { continue }
                let lower = text.index(range.lowerBound, offsetBy: -60, limitedBy: text.startIndex)
                    ?? text.startIndex
                let upper = text.index(range.upperBound, offsetBy: 100, limitedBy: text.endIndex)
                    ?? text.endIndex
                var excerpt = String(text[lower..<upper])
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if lower != text.startIndex { excerpt = "…" + excerpt }
                if upper != text.endIndex { excerpt += "…" }
                hits.append(LibraryTextSearchHit(
                    documentPath: item.relativePath,
                    pageID: pageID,
                    pageNumber: index + 1,
                    excerpt: excerpt
                ))
                guard hits.count < 500 else { return hits }
            }
        }
        return hits
    }

    public func loadLibraryState() throws -> LibraryState {
        var state = try readRawLibraryState()
        state.favoritePaths = state.favoritePaths.filter {
            (try? existingItemURL(for: $0)) != nil
        }
        state.recentPaths = state.recentPaths.filter {
            (try? existingItemURL(for: $0)) != nil
        }
        state.tagsByPath = state.tagsByPath.filter {
            (try? existingItemURL(for: $0.key)) != nil
        }
        return state
    }

    @discardableResult
    public func toggleFavorite(at relativePath: String) throws -> LibraryState {
        _ = try existingItemURL(for: relativePath)
        var state = try loadLibraryState()
        if let index = state.favoritePaths.firstIndex(of: relativePath) {
            state.favoritePaths.remove(at: index)
        } else {
            state.favoritePaths.append(relativePath)
        }
        try saveLibraryState(state)
        return state
    }

    @discardableResult
    public func markRecent(at relativePath: String) throws -> LibraryState {
        _ = try existingItemURL(for: relativePath)
        var state = try loadLibraryState()
        state.recentPaths.removeAll { $0 == relativePath }
        state.recentPaths.insert(relativePath, at: 0)
        state.recentPaths = Array(state.recentPaths.prefix(LibraryState.maximumRecentItems))
        try saveLibraryState(state)
        return state
    }

    @discardableResult
    public func setTags(_ tags: [String], for relativePath: String) throws -> LibraryState {
        _ = try existingItemURL(for: relativePath)
        var state = try loadLibraryState()
        let existingTags = state.tagsByPath.values.flatMap { $0 }
        let tags = try validatedTags(tags).map { candidate in
            existingTags.first {
                $0.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            } ?? candidate
        }
        if tags.isEmpty {
            state.tagsByPath.removeValue(forKey: relativePath)
        } else {
            state.tagsByPath[relativePath] = tags
        }
        try saveLibraryState(state)
        return state
    }

    public func itemURL(for relativePath: String) throws -> URL {
        try existingItemURL(for: relativePath)
    }

    public func listExternalConflicts() throws -> [ExternalDocumentConflict] {
        try allItems().compactMap { item in
            guard item.kind != .folder else { return nil }
            let url = try existingItemURL(for: item.relativePath)
            guard let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
                  !versions.isEmpty else { return nil }
            let mappedVersions = versions
                .map { version in
                    ExternalConflictVersion(
                        id: conflictIdentifier(for: version),
                        modifiedAt: version.modificationDate,
                        deviceName: version.localizedNameOfSavingComputer,
                        localizedName: version.localizedName
                    )
                }
                .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
            return ExternalDocumentConflict(
                documentPath: item.relativePath,
                documentName: item.name,
                currentModifiedAt: item.modifiedAt,
                versions: mappedVersions
            )
        }
        .sorted { $0.documentName.localizedStandardCompare($1.documentName) == .orderedAscending }
    }

    /// Resolves a top-level document conflict only after the selected cloud
    /// revision has passed the same structural validation as an imported backup.
    /// Returns the path of the preserved current copy for `.keepBoth`.
    @discardableResult
    public func resolveExternalConflict(
        at relativePath: String,
        selectedVersionID: String? = nil,
        resolution: ExternalConflictResolution
    ) throws -> String? {
        let itemURL = try existingItemURL(for: relativePath)
        let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
        guard let kind = itemKind(for: itemURL, isDirectory: values.isDirectory == true),
              kind != .folder,
              let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: itemURL),
              !conflicts.isEmpty else {
            throw DocumentStoreError.itemNotFound(relativePath)
        }

        if resolution == .keepCurrent {
            try markConflictVersionsResolved(conflicts, at: itemURL)
            return nil
        }
        guard let selectedVersionID,
              let selected = conflicts.first(where: {
                  conflictIdentifier(for: $0) == selectedVersionID
              }) else {
            throw DocumentStoreError.itemNotFound("Konfliktversion")
        }
        let selectedURL = selected.url
        try validateBackupItem(at: selectedURL, kind: kind)

        let preservedPath: String?
        if resolution == .keepBoth {
            preservedPath = try duplicateItem(at: relativePath)
        } else {
            preservedPath = nil
        }

        let identifier = UUID().uuidString
        let candidateURL = rootURL.appendingPathComponent(".conflict-candidate-\(identifier)")
        let backupName = ".conflict-original-\(identifier)"
        let backupURL = rootURL.appendingPathComponent(backupName)
        do {
            try copyBackupItem(from: selectedURL, to: candidateURL)
            try validateBackupItem(at: candidateURL, kind: kind)
            _ = try fileManager.replaceItemAt(
                itemURL,
                withItemAt: candidateURL,
                backupItemName: backupName,
                options: []
            )
            try validateBackupItem(at: itemURL, kind: kind)
            try markConflictVersionsResolved(conflicts, at: itemURL)
            try? fileManager.removeItem(at: backupURL)
            return preservedPath
        } catch {
            try? fileManager.removeItem(at: candidateURL)
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: itemURL)
                try? fileManager.moveItem(at: backupURL, to: itemURL)
            }
            if let preservedPath,
               let preservedURL = try? resolvedURL(for: preservedPath) {
                try? fileManager.removeItem(at: preservedURL)
                try? removeTrackedPaths(at: preservedPath)
            }
            if let storeError = error as? DocumentStoreError { throw storeError }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Creates a consistent, portable snapshot without the recoverable trash.
    /// The caller may compress or share the resulting package and is responsible
    /// for removing it from the temporary destination afterwards.
    public func createLibraryBackup(
        in destinationDirectory: URL,
        now: Date = Date()
    ) throws -> URL {
        let destinationDirectory = destinationDirectory.standardizedFileURL
        let canonicalRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let canonicalDestination = destinationDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL.path
        guard canonicalDestination != canonicalRoot,
              !canonicalDestination.hasPrefix(canonicalRoot + "/") else {
            throw DocumentStoreError.invalidPath(destinationDirectory.path)
        }

        let identifier = UUID().uuidString
        let backupURL = destinationDirectory
            .appendingPathComponent("BirdNotes-Backup-\(identifier)")
            .appendingPathExtension(Self.backupExtension)
        let stagingURL = destinationDirectory
            .appendingPathComponent(".BirdNotes-Backup-\(identifier).tmp", isDirectory: true)
        let libraryURL = stagingURL.appendingPathComponent("Library", isDirectory: true)

        do {
            try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
            let items = try listItems()
            for item in items {
                let sourceURL = try existingItemURL(for: item.relativePath)
                let targetURL = libraryURL.appendingPathComponent(sourceURL.lastPathComponent)
                try coordinatedBackupCopy(from: sourceURL, to: targetURL)

                if item.kind == .pdf {
                    let sidecarURL = pdfAnnotationDirectoryURL(for: sourceURL)
                    if fileManager.fileExists(atPath: sidecarURL.path) {
                        try coordinatedBackupCopy(
                            from: sidecarURL,
                            to: libraryURL.appendingPathComponent(sidecarURL.lastPathComponent)
                        )
                    }
                }
            }

            try atomicWrite(
                JSONCoding.encoder().encode(try loadLibraryState()),
                to: libraryURL.appendingPathComponent(Self.libraryStateFileName)
            )
            try atomicWrite(
                JSONCoding.encoder().encode(
                    LibraryBackupManifest(createdAt: now, itemCount: items.count)
                ),
                to: stagingURL.appendingPathComponent("manifest.json")
            )
            try atomicWrite(
                Data("BirdNotes-Sicherung. Zum Wiederherstellen den Inhalt des Ordners Library in einen BirdNotes-Ordner kopieren.".utf8),
                to: stagingURL.appendingPathComponent("WIEDERHERSTELLEN.txt")
            )
            try fileManager.moveItem(at: stagingURL, to: backupURL)
            return backupURL
        } catch let error as DocumentStoreError {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Validates an extracted `.birdbackup` package without trusting names,
    /// symlinks, metadata counts, or document payloads supplied by the archive.
    public func inspectLibraryBackup(at backupURL: URL) throws -> LibraryBackupPreview {
        let contents = try validatedBackupContents(at: backupURL)
        let conflicts = contents.items.compactMap { item in
            fileManager.fileExists(atPath: rootURL.appendingPathComponent(item.url.lastPathComponent).path)
                ? item.url.deletingPathExtension().lastPathComponent
                : nil
        }
        return LibraryBackupPreview(
            createdAt: contents.manifest.createdAt,
            itemCount: contents.items.count,
            itemNames: contents.items.map(\.displayName),
            conflictingItemNames: conflicts
        )
    }

    /// Restores a previously extracted BirdNotes backup through a recoverable
    /// transaction. A crash can leave only a hidden transaction directory;
    /// `recoverInterruptedTransactions()` rolls it back on the next launch.
    public func restoreLibraryBackup(
        from backupURL: URL,
        conflictPolicy: BackupConflictPolicy
    ) throws -> LibraryBackupRestoreResult {
        let contents = try validatedBackupContents(at: backupURL)
        let transactionRoot = rootURL
            .appendingPathComponent(Self.transactionDirectoryName, isDirectory: true)
        try ensureSafeInternalDirectory(transactionRoot)
        let transactionURL = transactionRoot.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let incomingURL = transactionURL.appendingPathComponent("incoming", isDirectory: true)
        let rollbackURL = transactionURL.appendingPathComponent("rollback", isDirectory: true)

        do {
            try fileManager.createDirectory(at: incomingURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: rollbackURL, withIntermediateDirectories: false)

            var plannedItems: [RestoreJournal.Item] = []
            var skippedNames: [String] = []
            for item in contents.items {
                let sourceName = item.url.lastPathComponent
                let requestedTarget = rootURL.appendingPathComponent(sourceName)
                let targetURL: URL
                if fileManager.fileExists(atPath: requestedTarget.path) {
                    switch conflictPolicy {
                    case .skip:
                        skippedNames.append(item.displayName)
                        continue
                    case .keepBoth:
                        targetURL = uniqueCopyURL(for: requestedTarget, in: rootURL)
                    case .replace:
                        targetURL = requestedTarget
                    }
                } else {
                    targetURL = requestedTarget
                }

                try copyBackupItem(
                    from: item.url,
                    to: incomingURL.appendingPathComponent(sourceName)
                )
                let sidecarSourceName = item.sidecarURL?.lastPathComponent
                if let sidecarURL = item.sidecarURL, let sidecarSourceName {
                    try copyBackupItem(
                        from: sidecarURL,
                        to: incomingURL.appendingPathComponent(sidecarSourceName)
                    )
                }
                let targetName = targetURL.lastPathComponent
                let targetSidecarName = item.kind == .pdf
                    ? ".\(targetName).birdannotations"
                    : nil
                let targetSidecarURL = targetSidecarName.map {
                    rootURL.appendingPathComponent($0)
                }
                plannedItems.append(RestoreJournal.Item(
                    sourceName: sourceName,
                    targetName: targetName,
                    sourceSidecarName: sidecarSourceName,
                    targetSidecarName: targetSidecarName,
                    hadOriginal: fileManager.fileExists(atPath: targetURL.path),
                    hadOriginalSidecar: targetSidecarURL.map {
                        fileManager.fileExists(atPath: $0.path)
                    } ?? false
                ))
            }

            let stateURL = rootURL.appendingPathComponent(Self.libraryStateFileName)
            let hadLibraryState = fileManager.fileExists(atPath: stateURL.path)
            if hadLibraryState {
                try fileManager.copyItem(
                    at: stateURL,
                    to: rollbackURL.appendingPathComponent(Self.libraryStateFileName)
                )
            }
            var journal = RestoreJournal(
                committed: false,
                hadLibraryState: hadLibraryState,
                items: plannedItems
            )
            try writeRestoreJournal(journal, at: transactionURL)

            for item in plannedItems {
                let targetURL = rootURL.appendingPathComponent(item.targetName)
                if item.hadOriginal {
                    try fileManager.moveItem(
                        at: targetURL,
                        to: rollbackURL.appendingPathComponent(item.targetName)
                    )
                }
                if let targetSidecarName = item.targetSidecarName,
                   item.hadOriginalSidecar {
                    try fileManager.moveItem(
                        at: rootURL.appendingPathComponent(targetSidecarName),
                        to: rollbackURL.appendingPathComponent(targetSidecarName)
                    )
                }
                try fileManager.moveItem(
                    at: incomingURL.appendingPathComponent(item.sourceName),
                    to: targetURL
                )
                if let sourceSidecarName = item.sourceSidecarName,
                   let targetSidecarName = item.targetSidecarName {
                    try fileManager.moveItem(
                        at: incomingURL.appendingPathComponent(sourceSidecarName),
                        to: rootURL.appendingPathComponent(targetSidecarName)
                    )
                }
            }

            try mergeBackupState(
                contents.libraryState,
                mappings: Dictionary(uniqueKeysWithValues: plannedItems.map {
                    ($0.sourceName, $0.targetName)
                })
            )
            journal.committed = true
            try writeRestoreJournal(journal, at: transactionURL)
            try fileManager.removeItem(at: transactionURL)
            try? removeTransactionContainerIfEmpty(transactionRoot)
            return LibraryBackupRestoreResult(
                restoredPaths: plannedItems.map(\.targetName),
                skippedItemNames: skippedNames
            )
        } catch {
            try? rollbackRestoreTransaction(at: transactionURL)
            if let storeError = error as? DocumentStoreError { throw storeError }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Repairs incomplete document saves and rolls back incomplete backup
    /// restores. Returns the number of repaired transactions so the UI can
    /// notify the user without exposing internal file details.
    @discardableResult
    public func recoverInterruptedTransactions() throws -> Int {
        let transactionRoot = rootURL
            .appendingPathComponent(Self.transactionDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: transactionRoot.path) else { return 0 }
        let values = try transactionRoot.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("Der Wiederherstellungsbereich wurde verändert.")
        }

        var recovered = 0
        for url in try fileManager.contentsOfDirectory(
            at: transactionRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            let entryValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard entryValues.isDirectory == true,
                  entryValues.isSymbolicLink != true,
                  UUID(uuidString: url.lastPathComponent) != nil else {
                throw DocumentStoreError.damagedDocument("Eine Wiederherstellungstransaktion ist ungültig.")
            }
            let restoreJournalURL = url.appendingPathComponent("journal.json")
            let documentJournalURL = url.appendingPathComponent("document-journal.json")
            let hasRestoreJournal = fileManager.fileExists(atPath: restoreJournalURL.path)
            let hasDocumentJournal = fileManager.fileExists(atPath: documentJournalURL.path)
            guard !(hasRestoreJournal && hasDocumentJournal) else {
                throw DocumentStoreError.damagedDocument(
                    "Eine Transaktion enthält widersprüchliche Journale."
                )
            }

            if hasDocumentJournal {
                let journal = try readDocumentSaveJournal(at: url)
                if journal.committed {
                    try fileManager.removeItem(at: url)
                } else {
                    try finishDocumentSaveTransaction(journal, at: url)
                    recovered += 1
                }
            } else if hasRestoreJournal {
                let journal = try readRestoreJournal(at: url)
                if journal.committed {
                    try fileManager.removeItem(at: url)
                } else {
                    try rollbackRestoreTransaction(at: url)
                    recovered += 1
                }
            } else {
                // Preparation writes only into this hidden UUID directory. If
                // the process stopped before its journal became durable, no
                // library target was touched and the staging data is disposable.
                try fileManager.removeItem(at: url)
            }
        }
        try? removeTransactionContainerIfEmpty(transactionRoot)
        return recovered
    }

    /// Copies a PDF into the library without changing the source file. If a
    /// file with the same name exists, a Finder-style numbered copy is used.
    @discardableResult
    public func importPDF(
        from sourceURL: URL,
        in relativeFolderPath: String = ""
    ) throws -> String {
        guard sourceURL.pathExtension.lowercased() == "pdf" else {
            throw DocumentStoreError.unsupportedFileType(
                sourceURL.pathExtension.isEmpty ? sourceURL.lastPathComponent : sourceURL.pathExtension
            )
        }

        let parentURL = try existingFolderURL(for: relativeFolderPath)
        let title = try validatedDocumentTitle(
            sourceURL.deletingPathExtension().lastPathComponent,
            removingExtension: "pdf"
        )
        var targetURL = parentURL.appendingPathComponent(title).appendingPathExtension("pdf")
        if fileManager.fileExists(atPath: targetURL.path) {
            targetURL = uniqueCopyURL(for: targetURL, in: parentURL)
        }
        let stagingURL = parentURL.appendingPathComponent(
            ".\(UUID().uuidString).pdf-import"
        )

        do {
            try copyValidatedPDF(from: sourceURL, to: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: targetURL)
            return try relativePath(for: targetURL)
        } catch let error as DocumentStoreError {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            try? fileManager.removeItem(at: targetURL)
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func createFolder(named name: String, in relativeFolderPath: String = "") throws -> String {
        let name = try validatedName(name)
        let parentURL = try existingFolderURL(for: relativeFolderPath)
        let folderURL = parentURL.appendingPathComponent(name, isDirectory: true)
        try ensureDoesNotExist(folderURL)

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
            return try relativePath(for: folderURL)
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Creates a ready-to-use semester workspace as one atomic file-system operation.
    /// The structure is prepared under a hidden staging name and only becomes visible
    /// after every folder and the overview notebook have been written successfully.
    @discardableResult
    public func createStudyWorkspace(
        named name: String,
        in relativeFolderPath: String = "",
        now: Date = Date()
    ) throws -> String {
        let name = try validatedName(name)
        let parentURL = try existingFolderURL(for: relativeFolderPath)
        let workspaceURL = parentURL.appendingPathComponent(name, isDirectory: true)
        try ensureDoesNotExist(workspaceURL)

        let stagingURL = parentURL.appendingPathComponent(
            ".\(UUID().uuidString).study-workspace",
            isDirectory: true
        )
        let sectionNames = [
            "Vorlesungsnotizen",
            "Übungen",
            "Literatur und PDFs",
            "Prüfungsvorbereitung"
        ]
        let overviewTitle = "Semesterübersicht"
        let overviewURL = stagingURL
            .appendingPathComponent(overviewTitle)
            .appendingPathExtension(Self.notebookExtension)
        let firstPage = NotebookPageMetadata(
            createdAt: now,
            modifiedAt: now,
            paperStyle: .cornell,
            paperFormat: .a4
        )
        let manifest = NotebookManifest(
            title: overviewTitle,
            createdAt: now,
            modifiedAt: now,
            pageOrder: [firstPage.id]
        )

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            for sectionName in sectionNames {
                try fileManager.createDirectory(
                    at: stagingURL.appendingPathComponent(sectionName, isDirectory: true),
                    withIntermediateDirectories: false
                )
            }
            try fileManager.createDirectory(at: overviewURL, withIntermediateDirectories: false)
            try writeManifest(manifest, at: overviewURL)
            try writePage(firstPage, drawingData: Data(), in: overviewURL)
            try fileManager.moveItem(at: stagingURL, to: workspaceURL)
            return try relativePath(for: workspaceURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if let storeError = error as? DocumentStoreError { throw storeError }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Creates a complete degree workspace as one atomic file-system operation.
    /// Nothing becomes visible until all semester, module, notebook and section
    /// entries have been written successfully.
    @discardableResult
    public func createStudyProgramWorkspace(
        named name: String,
        phases: [StudyProgramPhaseDefinition],
        in relativeFolderPath: String = "",
        now: Date = Date()
    ) throws -> String {
        let name = try validatedName(name)
        guard !phases.isEmpty, phases.count <= 12 else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Ein Studienbereich muss zwischen 1 und 12 Abschnitte enthalten."
            )
        }
        let moduleCount = phases.reduce(0) { $0 + $1.modules.count }
        guard (1...200).contains(moduleCount) else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Ein Studienbereich muss zwischen 1 und 200 Module enthalten."
            )
        }

        var phaseNames = Set<String>()
        var moduleCodes = Set<String>()
        let validatedPhases = try phases.map { phase -> (String, [(String, String)]) in
            let phaseName = try validatedName(phase.title)
            guard phaseNames.insert(phaseName).inserted,
                  !phase.modules.isEmpty,
                  phase.modules.count <= 40 else {
                throw DocumentStoreError.invalidName(phase.title)
            }
            let modules = try phase.modules.map { module -> (String, String) in
                let code = try validatedName(module.code)
                let title = try validatedName(module.title)
                guard moduleCodes.insert(code).inserted else {
                    throw DocumentStoreError.invalidName(module.code)
                }
                return (code, try validatedName("\(code) – \(title)"))
            }
            return (phaseName, modules)
        }

        let parentURL = try existingFolderURL(for: relativeFolderPath)
        let workspaceURL = parentURL.appendingPathComponent(name, isDirectory: true)
        try ensureDoesNotExist(workspaceURL)
        let stagingURL = parentURL.appendingPathComponent(
            ".\(UUID().uuidString).study-program",
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            try fileManager.createDirectory(
                at: stagingURL.appendingPathComponent("00 Studienplanung", isDirectory: true),
                withIntermediateDirectories: false
            )
            try fileManager.createDirectory(
                at: stagingURL.appendingPathComponent("Wahlmodule", isDirectory: true),
                withIntermediateDirectories: false
            )
            try createStudyNotebookPackage(
                title: "Studienübersicht",
                paperStyle: .cornell,
                in: stagingURL,
                now: now
            )

            for (phaseName, modules) in validatedPhases {
                let phaseURL = stagingURL.appendingPathComponent(phaseName, isDirectory: true)
                try fileManager.createDirectory(at: phaseURL, withIntermediateDirectories: false)
                for (_, moduleFolderName) in modules {
                    let moduleURL = phaseURL.appendingPathComponent(moduleFolderName, isDirectory: true)
                    try fileManager.createDirectory(at: moduleURL, withIntermediateDirectories: false)
                    for sectionName in ["Übungen", "Literatur und PDFs", "Prüfungsvorbereitung"] {
                        try fileManager.createDirectory(
                            at: moduleURL.appendingPathComponent(sectionName, isDirectory: true),
                            withIntermediateDirectories: false
                        )
                    }
                    try createStudyNotebookPackage(
                        title: "Lernnotizen",
                        paperStyle: .cornell,
                        in: moduleURL,
                        now: now
                    )
                    try createStudyNotebookPackage(
                        title: "Active Recall",
                        paperStyle: .lined,
                        in: moduleURL,
                        now: now
                    )
                }
            }

            try fileManager.moveItem(at: stagingURL, to: workspaceURL)
            return try relativePath(for: workspaceURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if let storeError = error as? DocumentStoreError { throw storeError }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func createStudyNotebookPackage(
        title: String,
        paperStyle: PaperStyle,
        in parentURL: URL,
        now: Date
    ) throws {
        let title = try validatedDocumentTitle(title, removingExtension: Self.notebookExtension)
        let packageURL = parentURL
            .appendingPathComponent(title)
            .appendingPathExtension(Self.notebookExtension)
        try ensureDoesNotExist(packageURL)
        let firstPage = NotebookPageMetadata(
            createdAt: now,
            modifiedAt: now,
            paperStyle: paperStyle,
            paperFormat: .a4
        )
        let manifest = NotebookManifest(
            title: title,
            createdAt: now,
            modifiedAt: now,
            pageOrder: [firstPage.id]
        )
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: false)
        try writeManifest(manifest, at: packageURL)
        try writePage(firstPage, drawingData: Data(), in: packageURL)
    }

    @discardableResult
    public func createNotebook(
        named name: String,
        in relativeFolderPath: String = "",
        paperStyle: PaperStyle = .blank,
        paperFormat: PaperFormat = .a4,
        paperOrientation: PaperOrientation = .portrait,
        now: Date = Date()
    ) throws -> String {
        let title = try validatedDocumentTitle(name, removingExtension: Self.notebookExtension)
        let parentURL = try existingFolderURL(for: relativeFolderPath)
        let packageURL = parentURL
            .appendingPathComponent(title)
            .appendingPathExtension(Self.notebookExtension)
        try ensureDoesNotExist(packageURL)

        let stagingURL = parentURL.appendingPathComponent(".\(UUID().uuidString).tmp", isDirectory: true)
        let firstPage = NotebookPageMetadata(
            createdAt: now,
            modifiedAt: now,
            paperStyle: paperStyle,
            paperFormat: paperFormat,
            paperOrientation: paperOrientation
        )
        let manifest = NotebookManifest(
            title: title,
            createdAt: now,
            modifiedAt: now,
            pageOrder: [firstPage.id]
        )

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            try writeManifest(manifest, at: stagingURL)
            try writePage(firstPage, drawingData: Data(), in: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: packageURL)
            return try relativePath(for: packageURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if let storeError = error as? DocumentStoreError { throw storeError }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func createInfiniteCanvas(
        named name: String,
        in relativeFolderPath: String = "",
        now: Date = Date()
    ) throws -> String {
        let title = try validatedDocumentTitle(name, removingExtension: Self.canvasExtension)
        let parentURL = try existingFolderURL(for: relativeFolderPath)
        let packageURL = parentURL
            .appendingPathComponent(title)
            .appendingPathExtension(Self.canvasExtension)
        try ensureDoesNotExist(packageURL)

        let stagingURL = parentURL.appendingPathComponent(".\(UUID().uuidString).tmp", isDirectory: true)
        let manifest = InfiniteCanvasManifest(title: title, createdAt: now, modifiedAt: now)

        do {
            try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)
            try writeCanvasManifest(manifest, at: stagingURL)
            try atomicWrite(Data(), to: canvasDrawingURL(in: stagingURL))
            try writeCanvasElements([], at: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: packageURL)
            return try relativePath(for: packageURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if let storeError = error as? DocumentStoreError { throw storeError }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func renameItem(at relativePath: String, to newName: String) throws -> String {
        let sourceURL = try existingItemURL(for: relativePath)
        let isDirectory = (try? sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        guard let kind = itemKind(for: sourceURL, isDirectory: isDirectory) else {
            throw DocumentStoreError.itemNotFound(relativePath)
        }

        let targetName: String
        switch kind {
        case .notebook:
            let title = try validatedDocumentTitle(newName, removingExtension: Self.notebookExtension)
            targetName = title + "." + Self.notebookExtension
        case .infiniteCanvas:
            let title = try validatedDocumentTitle(newName, removingExtension: Self.canvasExtension)
            targetName = title + "." + Self.canvasExtension
        case .technicalDiagram:
            let title = try validatedDocumentTitle(newName, removingExtension: Self.technicalDiagramExtension)
            targetName = title + "." + Self.technicalDiagramExtension
        case .pdf:
            let title = try validatedDocumentTitle(newName, removingExtension: "pdf")
            targetName = title + ".pdf"
        case .folder:
            targetName = try validatedName(newName)
        }

        let targetURL = sourceURL.deletingLastPathComponent().appendingPathComponent(targetName)
        if targetURL.standardizedFileURL == sourceURL.standardizedFileURL {
            return relativePath
        }
        try ensureDoesNotExist(targetURL)

        do {
            try fileManager.moveItem(at: sourceURL, to: targetURL)
            if kind == .notebook {
                var manifest = try readManifest(at: targetURL)
                manifest.title = targetURL.deletingPathExtension().lastPathComponent
                manifest.modifiedAt = Date()
                try writeManifest(manifest, at: targetURL)
            } else if kind == .infiniteCanvas {
                var manifest = try readCanvasManifest(at: targetURL)
                manifest.title = targetURL.deletingPathExtension().lastPathComponent
                manifest.modifiedAt = Date()
                try writeCanvasManifest(manifest, at: targetURL)
            } else if kind == .technicalDiagram {
                try updateTechnicalIndexManifest(
                    at: targetURL,
                    title: targetURL.deletingPathExtension().lastPathComponent,
                    renewIdentity: false
                )
            } else if kind == .pdf {
                try movePDFSidecarIfPresent(from: sourceURL, to: targetURL)
            }
            let newPath = try self.relativePath(for: targetURL)
            try remapTrackedPaths(from: relativePath, to: newPath)
            return newPath
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func moveItem(at relativePath: String, to relativeFolderPath: String) throws -> String {
        let sourceURL = try existingItemURL(for: relativePath)
        let destinationFolderURL = try existingFolderURL(for: relativeFolderPath)

        if destinationFolderURL == sourceURL ||
            destinationFolderURL.path.hasPrefix(sourceURL.path + "/") {
            throw DocumentStoreError.invalidPath(relativeFolderPath)
        }

        let targetURL = destinationFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        if targetURL.standardizedFileURL == sourceURL.standardizedFileURL {
            return relativePath
        }
        try ensureDoesNotExist(targetURL)

        do {
            try fileManager.moveItem(at: sourceURL, to: targetURL)
            if sourceURL.pathExtension.lowercased() == "pdf" {
                try movePDFSidecarIfPresent(from: sourceURL, to: targetURL)
            }
            let newPath = try self.relativePath(for: targetURL)
            try remapTrackedPaths(from: relativePath, to: newPath)
            return newPath
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    @discardableResult
    public func duplicateItem(at relativePath: String) throws -> String {
        let sourceURL = try existingItemURL(for: relativePath)
        let parentURL = sourceURL.deletingLastPathComponent()
        let targetURL = uniqueCopyURL(for: sourceURL, in: parentURL)

        do {
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            if targetURL.pathExtension.lowercased() == Self.notebookExtension {
                var manifest = try readManifest(at: targetURL)
                manifest.id = UUID()
                manifest.title = targetURL.deletingPathExtension().lastPathComponent
                manifest.createdAt = Date()
                manifest.modifiedAt = manifest.createdAt
                try writeManifest(manifest, at: targetURL)
            } else if targetURL.pathExtension.lowercased() == Self.canvasExtension {
                var manifest = try readCanvasManifest(at: targetURL)
                manifest.id = UUID()
                manifest.title = targetURL.deletingPathExtension().lastPathComponent
                manifest.createdAt = Date()
                manifest.modifiedAt = manifest.createdAt
                try writeCanvasManifest(manifest, at: targetURL)
            } else if targetURL.pathExtension.lowercased() == Self.technicalDiagramExtension {
                try updateTechnicalIndexManifest(
                    at: targetURL,
                    title: targetURL.deletingPathExtension().lastPathComponent,
                    renewIdentity: true
                )
            } else if targetURL.pathExtension.lowercased() == "pdf" {
                try copyPDFSidecarIfPresent(from: sourceURL, to: targetURL)
            }
            let targetPath = try self.relativePath(for: targetURL)
            let state = try readRawLibraryState()
            let sourceTags = state.tagsByPath.filter {
                $0.key == relativePath || $0.key.hasPrefix(relativePath + "/")
            }
            if !sourceTags.isEmpty {
                var updatedState = state
                for (path, tags) in sourceTags {
                    let mappedPath = path == relativePath
                        ? targetPath
                        : targetPath + path.dropFirst(relativePath.count)
                    updatedState.tagsByPath[mappedPath] = tags
                }
                try saveLibraryState(updatedState)
            }
            return targetPath
        } catch let error as DocumentStoreError {
            try? fileManager.removeItem(at: targetURL)
            if targetURL.pathExtension.lowercased() == "pdf" {
                try? fileManager.removeItem(at: pdfAnnotationDirectoryURL(for: targetURL))
            }
            throw error
        } catch {
            try? fileManager.removeItem(at: targetURL)
            if targetURL.pathExtension.lowercased() == "pdf" {
                try? fileManager.removeItem(at: pdfAnnotationDirectoryURL(for: targetURL))
            }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public func deleteItem(at relativePath: String) throws {
        guard !relativePath.isEmpty else {
            throw DocumentStoreError.invalidPath(relativePath)
        }
        let url = try existingItemURL(for: relativePath)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard let kind = itemKind(for: url, isDirectory: values.isDirectory == true) else {
            throw DocumentStoreError.itemNotFound(relativePath)
        }
        let trashEntryURL = try makeTrashEntry(
            for: url,
            originalRelativePath: relativePath,
            kind: kind
        )
        let storedItemURL = trashEntryURL.appendingPathComponent(url.lastPathComponent)
        do {
            try fileManager.moveItem(at: url, to: storedItemURL)
            if url.pathExtension.lowercased() == "pdf" {
                let sidecarURL = pdfAnnotationDirectoryURL(for: url)
                if fileManager.fileExists(atPath: sidecarURL.path) {
                    try fileManager.moveItem(
                        at: sidecarURL,
                        to: trashEntryURL.appendingPathComponent(sidecarURL.lastPathComponent)
                    )
                }
            }
            try removeTrackedPaths(at: relativePath)
            try? pruneTrashIfNeeded()
        } catch {
            if fileManager.fileExists(atPath: storedItemURL.path),
               !fileManager.fileExists(atPath: url.path) {
                try? fileManager.moveItem(at: storedItemURL, to: url)
                let storedSidecar = trashEntryURL.appendingPathComponent(
                    pdfAnnotationDirectoryURL(for: url).lastPathComponent
                )
                if fileManager.fileExists(atPath: storedSidecar.path) {
                    try? fileManager.moveItem(
                        at: storedSidecar,
                        to: pdfAnnotationDirectoryURL(for: url)
                    )
                }
            }
            try? fileManager.removeItem(at: trashEntryURL)
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    /// Restores the newest recoverable deletion. If its original folder no
    /// longer exists, the item is restored at the library root. Name conflicts
    /// are resolved with the same numbered-copy rule as duplication.
    @discardableResult
    public func restoreMostRecentlyDeletedItem() throws -> String? {
        guard let entry = try trashEntries().max(by: { $0.metadata.deletedAt < $1.metadata.deletedAt })
        else { return nil }

        return try restoreDeletedItem(id: entry.id)
    }

    public func listDeletedItems() throws -> [DeletedLibraryItem] {
        try trashEntries()
            .sorted { $0.metadata.deletedAt > $1.metadata.deletedAt }
            .map { entry in
                let kind = entry.metadata.kind
                let storedName = entry.metadata.storedItemName
                let name: String
                switch kind {
                case .notebook, .infiniteCanvas, .technicalDiagram:
                    name = URL(fileURLWithPath: storedName).deletingPathExtension().lastPathComponent
                case .folder, .pdf, .none:
                    name = storedName
                }
                return DeletedLibraryItem(
                    id: entry.id,
                    name: name,
                    kind: kind,
                    originalRelativePath: entry.metadata.originalRelativePath,
                    deletedAt: entry.metadata.deletedAt
                )
            }
    }

    @discardableResult
    public func restoreDeletedItem(id: String) throws -> String {
        guard UUID(uuidString: id) != nil,
              let entry = try trashEntries().first(where: { $0.id == id }) else {
            throw DocumentStoreError.itemNotFound(id)
        }

        let originalComponents = entry.metadata.originalRelativePath.split(separator: "/")
        guard let originalName = originalComponents.last else {
            throw DocumentStoreError.damagedDocument("Ein Papierkorb-Eintrag ist ungültig.")
        }
        let originalParentPath = originalComponents.dropLast().joined(separator: "/")
        let destinationFolderURL = (try? existingFolderURL(for: originalParentPath)) ?? rootURL
        let storedItemURL = entry.url.appendingPathComponent(entry.metadata.storedItemName)
        let values = try storedItemURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values.isSymbolicLink != true,
              String(originalName) == entry.metadata.storedItemName else {
            throw DocumentStoreError.damagedDocument("Ein Papierkorb-Eintrag wurde verändert.")
        }

        var targetURL = destinationFolderURL.appendingPathComponent(entry.metadata.storedItemName)
        if fileManager.fileExists(atPath: targetURL.path) {
            targetURL = uniqueCopyURL(for: targetURL, in: destinationFolderURL)
        }
        do {
            try fileManager.moveItem(at: storedItemURL, to: targetURL)
            if targetURL.pathExtension.lowercased() == "pdf" {
                let storedSidecar = entry.url.appendingPathComponent(
                    ".\(entry.metadata.storedItemName).birdannotations"
                )
                if fileManager.fileExists(atPath: storedSidecar.path) {
                    try fileManager.moveItem(
                        at: storedSidecar,
                        to: pdfAnnotationDirectoryURL(for: targetURL)
                    )
                }
            }
            try? fileManager.removeItem(at: entry.url)
            let restoredPath = try relativePath(for: targetURL)
            try? restoreTrackedMetadata(entry.metadata, to: restoredPath)
            return restoredPath
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public func deletePermanently(id: String) throws {
        guard UUID(uuidString: id) != nil,
              let entry = try trashEntries().first(where: { $0.id == id }) else {
            throw DocumentStoreError.itemNotFound(id)
        }
        do {
            try fileManager.removeItem(at: entry.url)
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public func emptyTrash() throws {
        do {
            for entry in try trashEntries() {
                try fileManager.removeItem(at: entry.url)
            }
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public func hasRestorableItems() throws -> Bool {
        try !trashEntries().isEmpty
    }

    // MARK: - Notebook

    public func loadNotebook(at relativePath: String) throws -> NotebookDocument {
        let packageURL = try existingNotebookURL(for: relativePath)
        let manifest = try readManifest(at: packageURL)
        let pages = try manifest.pageOrder.map { pageID in
            try readPage(pageID, in: packageURL)
        }
        return NotebookDocument(manifest: manifest, pages: pages)
    }

    /// Saves original PencilKit data as an opaque payload. The Core target does
    /// not render or transform it, so the editable representation is preserved.
    /// Returns a newly-created trailing page when this edit filled the last empty page.
    @discardableResult
    public func saveDrawing(
        _ drawingData: Data,
        hasContent: Bool,
        for pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws -> NotebookPageMetadata? {
        try validateDrawingData(drawingData)
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        var metadata = try readPageMetadata(pageID, in: packageURL)
        let pagesBeforeEdit = try manifest.pageOrder.map {
            try readPageMetadata($0, in: packageURL)
        }

        metadata.isEmpty = !hasContent
        metadata.modifiedAt = now

        let trailingPage: NotebookPageMetadata?
        if hasContent {
            trailingPage = NotebookPageCreationPolicy.trailingPage(
                afterDrawingOn: pageID,
                pagesBeforeEdit: pagesBeforeEdit,
                now: now
            )
        } else {
            trailingPage = nil
        }

        if let trailingPage {
            manifest.pageOrder.append(trailingPage.id)
        }
        manifest.modifiedAt = now
        var mutations: [DocumentSaveMutation] = [
            .replace("pages/\(pageID.uuidString)/drawing.data", with: drawingData),
            .replace(
                "pages/\(pageID.uuidString)/metadata.json",
                with: try encodedPageMetadata(metadata)
            )
        ]
        if let trailingPage {
            mutations.append(.replace(
                "pages/\(trailingPage.id.uuidString)/metadata.json",
                with: try encodedPageMetadata(trailingPage)
            ))
            mutations.append(.replace(
                "pages/\(trailingPage.id.uuidString)/drawing.data",
                with: Data()
            ))
        }
        mutations.append(.replace("manifest.json", with: try encodedManifest(manifest)))
        try performDocumentSaveTransaction(
            mutations,
            for: manifest.id,
            kind: .notebook,
            at: packageURL
        )
        return trailingPage
    }

    @discardableResult
    public func addPage(
        toNotebookAt relativePath: String,
        paperStyle: PaperStyle = .blank,
        paperFormat: PaperFormat = .a4,
        paperOrientation: PaperOrientation = .portrait,
        now: Date = Date()
    ) throws -> NotebookPageMetadata {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        guard manifest.pageOrder.count < DocumentStoreLimits.maximumNotebookPages else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Ein Notizbuch kann höchstens 10.000 Seiten enthalten."
            )
        }
        let page = NotebookPageMetadata(
            createdAt: now,
            modifiedAt: now,
            paperStyle: paperStyle,
            paperFormat: paperFormat,
            paperOrientation: paperOrientation
        )
        manifest.pageOrder.append(page.id)
        manifest.modifiedAt = now
        try performDocumentSaveTransaction(
            [
                .replace(
                    "pages/\(page.id.uuidString)/metadata.json",
                    with: try encodedPageMetadata(page)
                ),
                .replace("pages/\(page.id.uuidString)/drawing.data", with: Data()),
                .replace("manifest.json", with: try encodedManifest(manifest))
            ],
            for: manifest.id,
            kind: .notebook,
            at: packageURL
        )
        return page
    }

    public func deletePage(
        _ pageID: UUID,
        fromNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        guard manifest.pageOrder.contains(pageID) else {
            throw DocumentStoreError.itemNotFound(pageID.uuidString)
        }
        guard manifest.pageOrder.count > 1 else {
            throw DocumentStoreError.cannotDeleteOnlyPage
        }

        manifest.pageOrder.removeAll { $0 == pageID }
        manifest.modifiedAt = now
        try performDocumentSaveTransaction(
            [
                .replace("manifest.json", with: try encodedManifest(manifest)),
                .deleteDirectory("pages/\(pageID.uuidString)")
            ],
            for: manifest.id,
            kind: .notebook,
            at: packageURL
        )
    }

    @discardableResult
    public func duplicatePage(
        _ pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws -> NotebookPageMetadata {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        guard manifest.pageOrder.count < DocumentStoreLimits.maximumNotebookPages else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Ein Notizbuch kann höchstens 10.000 Seiten enthalten."
            )
        }
        guard let sourceIndex = manifest.pageOrder.firstIndex(of: pageID) else {
            throw DocumentStoreError.itemNotFound(pageID.uuidString)
        }
        let source = try readPage(pageID, in: packageURL)
        let copy = NotebookPageMetadata(
            createdAt: now,
            modifiedAt: now,
            paperStyle: source.metadata.paperStyle,
            paperFormat: source.metadata.paperFormat,
            paperOrientation: source.metadata.paperOrientation,
            isEmpty: source.metadata.isEmpty,
            isBookmarked: source.metadata.isBookmarked,
            transcribedText: source.metadata.transcribedText
        )
        manifest.pageOrder.insert(copy.id, at: sourceIndex + 1)
        manifest.modifiedAt = now
        try performDocumentSaveTransaction(
            [
                .replace(
                    "pages/\(copy.id.uuidString)/metadata.json",
                    with: try encodedPageMetadata(copy)
                ),
                .replace(
                    "pages/\(copy.id.uuidString)/drawing.data",
                    with: source.drawingData
                ),
                .replace("manifest.json", with: try encodedManifest(manifest))
            ],
            for: manifest.id,
            kind: .notebook,
            at: packageURL
        )
        return copy
    }

    public func reorderPages(
        _ pageIDs: [UUID],
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        guard pageIDs.count == manifest.pageOrder.count,
              Set(pageIDs) == Set(manifest.pageOrder) else {
            throw DocumentStoreError.invalidPageOrder
        }
        manifest.pageOrder = pageIDs
        manifest.modifiedAt = now
        try writeManifest(manifest, at: packageURL)
    }

    public func updatePaperStyle(
        _ paperStyle: PaperStyle,
        for pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        var metadata = try readPageMetadata(pageID, in: packageURL)
        metadata.paperStyle = paperStyle
        metadata.modifiedAt = now
        manifest.modifiedAt = now
        try savePageMetadataAndManifest(metadata, manifest: manifest, at: packageURL)
    }

    public func updatePaperFormat(
        _ paperFormat: PaperFormat,
        for pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        var metadata = try readPageMetadata(pageID, in: packageURL)
        metadata.paperFormat = paperFormat
        metadata.modifiedAt = now
        manifest.modifiedAt = now
        try savePageMetadataAndManifest(metadata, manifest: manifest, at: packageURL)
    }

    public func updatePaperOrientation(
        _ paperOrientation: PaperOrientation,
        for pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        var metadata = try readPageMetadata(pageID, in: packageURL)
        metadata.paperOrientation = paperOrientation
        metadata.modifiedAt = now
        manifest.modifiedAt = now
        try savePageMetadataAndManifest(metadata, manifest: manifest, at: packageURL)
    }

    public func updatePageBookmark(
        _ isBookmarked: Bool,
        for pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        var metadata = try readPageMetadata(pageID, in: packageURL)
        metadata.isBookmarked = isBookmarked
        metadata.modifiedAt = now
        manifest.modifiedAt = now
        try savePageMetadataAndManifest(metadata, manifest: manifest, at: packageURL)
    }

    public func updatePageTranscription(
        _ text: String?,
        for pageID: UUID,
        inNotebookAt relativePath: String,
        now: Date = Date()
    ) throws {
        let packageURL = try existingNotebookURL(for: relativePath)
        var manifest = try readManifest(at: packageURL)
        var metadata = try readPageMetadata(pageID, in: packageURL)
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, !normalized.isEmpty {
            try validateTranscription(normalized)
            metadata.transcribedText = normalized
        } else {
            metadata.transcribedText = nil
        }
        metadata.modifiedAt = now
        manifest.modifiedAt = now
        try savePageMetadataAndManifest(metadata, manifest: manifest, at: packageURL)
    }

    // MARK: - Infinite canvas

    public func loadInfiniteCanvas(at relativePath: String) throws -> InfiniteCanvasDocument {
        let packageURL = try existingCanvasURL(for: relativePath)
        let manifest = try readCanvasManifest(at: packageURL)
        do {
            let drawingData = try readDrawingData(at: canvasDrawingURL(in: packageURL))
            let elements = try readCanvasElements(at: packageURL)
            try validateCanvasElements(elements)
            return InfiniteCanvasDocument(
                manifest: manifest,
                drawingData: drawingData,
                elements: elements
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument("Die Canvas-Zeichnung fehlt oder ist nicht lesbar.")
        }
    }

    public func saveInfiniteCanvasDrawing(
        _ drawingData: Data,
        at relativePath: String,
        now: Date = Date()
    ) throws {
        try validateDrawingData(drawingData)
        let packageURL = try existingCanvasURL(for: relativePath)
        var manifest = try readCanvasManifest(at: packageURL)
        manifest.modifiedAt = now
        try performDocumentSaveTransaction(
            [
                .replace("drawing.data", with: drawingData),
                .replace("manifest.json", with: try encodedCanvasManifest(manifest))
            ],
            for: manifest.id,
            kind: .infiniteCanvas,
            at: packageURL
        )
    }

    public func saveInfiniteCanvas(
        drawingData: Data,
        elements: [CanvasElement],
        viewport: CanvasViewport,
        at relativePath: String,
        now: Date = Date()
    ) throws {
        try validateDrawingData(drawingData)
        try validateCanvasViewport(viewport)
        try validateCanvasElements(elements)
        let packageURL = try existingCanvasURL(for: relativePath)
        var manifest = try readCanvasManifest(at: packageURL)
        manifest.schemaVersion = InfiniteCanvasManifest.currentSchemaVersion
        manifest.modifiedAt = now
        manifest.viewport = viewport
        try performDocumentSaveTransaction(
            [
                .replace("drawing.data", with: drawingData),
                .replace("elements.json", with: try encodedCanvasElements(elements)),
                .replace("manifest.json", with: try encodedCanvasManifest(manifest))
            ],
            for: manifest.id,
            kind: .infiniteCanvas,
            at: packageURL
        )
    }

    public func saveInfiniteCanvasViewport(
        _ viewport: CanvasViewport,
        at relativePath: String,
        now: Date = Date()
    ) throws {
        try validateCanvasViewport(viewport)
        let packageURL = try existingCanvasURL(for: relativePath)
        var manifest = try readCanvasManifest(at: packageURL)
        manifest.schemaVersion = InfiniteCanvasManifest.currentSchemaVersion
        manifest.modifiedAt = now
        manifest.viewport = viewport
        try writeCanvasManifest(manifest, at: packageURL)
    }

    // MARK: - PDF handwriting sidecars

    public func loadPDFDrawings(at relativePath: String) throws -> [Int: Data] {
        let pdfURL = try existingPDFURL(for: relativePath)
        let directoryURL = pdfAnnotationDirectoryURL(for: pdfURL)
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [:] }
        _ = try validatedPDFAnnotationDirectory(for: pdfURL, createIfMissing: false)

        do {
            return try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ).reduce(into: [:]) { result, url in
                guard url.pathExtension == "drawing",
                      url.deletingPathExtension().lastPathComponent.hasPrefix("page-"),
                      let pageIndex = Int(url.deletingPathExtension().lastPathComponent.dropFirst(5)) else {
                    return
                }
                guard pageIndex >= 0,
                      pageIndex < DocumentStoreLimits.maximumPDFAnnotationPages else { return }
                let values = try url.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey
                ])
                guard values.isRegularFile == true,
                      values.isSymbolicLink != true else {
                    throw DocumentStoreError.damagedDocument(
                        "PDF-Handschrift enthält einen unsicheren Dateiverweis."
                    )
                }
                let entryPath = try self.relativePath(for: url)
                try ensureURLRemainsInsideRootAfterResolvingSymlinks(
                    url,
                    relativePath: entryPath
                )
                try ensurePathContainsNoSymbolicLinks(entryPath)
                result[pageIndex] = try readDrawingData(at: url)
            }
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    public func savePDFDrawing(
        _ drawingData: Data,
        forPageAt pageIndex: Int,
        inPDFAt relativePath: String
    ) throws {
        guard pageIndex >= 0,
              pageIndex < DocumentStoreLimits.maximumPDFAnnotationPages else {
            throw DocumentStoreError.invalidPath("Seite \(pageIndex)")
        }
        try validateDrawingData(drawingData)
        let pdfURL = try existingPDFURL(for: relativePath)
        let directoryURL = try validatedPDFAnnotationDirectory(
            for: pdfURL,
            createIfMissing: true
        )
        do {
            try atomicWrite(
                drawingData,
                to: directoryURL.appendingPathComponent("page-\(pageIndex).drawing")
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    // MARK: - Package layout

    private func readManifest(at packageURL: URL) throws -> NotebookManifest {
        let url = packageURL.appendingPathComponent("manifest.json")
        do {
            let manifest = try JSONCoding.decoder().decode(
                NotebookManifest.self,
                from: readData(
                    at: url,
                    maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                    description: "Das Notizbuch-Manifest überschreitet 2 MB."
                )
            )
            guard manifest.schemaVersion <= NotebookManifest.currentSchemaVersion else {
                throw DocumentStoreError.unsupportedSchemaVersion(manifest.schemaVersion)
            }
            guard manifest.schemaVersion > 0,
                  manifest.documentType == .notebook,
                  !manifest.title.isEmpty,
                  manifest.title.count <= DocumentStoreLimits.maximumNameLength,
                  manifest.title.utf8.count <= 240,
                  !manifest.pageOrder.isEmpty,
                  manifest.pageOrder.count <= DocumentStoreLimits.maximumNotebookPages,
                  Set(manifest.pageOrder).count == manifest.pageOrder.count else {
                throw DocumentStoreError.damagedDocument("Das Manifest ist inkonsistent.")
            }
            return manifest
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument(error.localizedDescription)
        }
    }

    private func writeManifest(_ manifest: NotebookManifest, at packageURL: URL) throws {
        do {
            try atomicWrite(
                encodedManifest(manifest),
                to: packageURL.appendingPathComponent("manifest.json")
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func readPage(_ pageID: UUID, in packageURL: URL) throws -> NotebookPage {
        let metadata = try readPageMetadata(pageID, in: packageURL)
        let drawingURL = drawingURL(pageID, in: packageURL)
        do {
            return NotebookPage(metadata: metadata, drawingData: try readDrawingData(at: drawingURL))
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument(
                "Zeichnungsdaten für Seite \(pageID.uuidString) fehlen oder sind nicht lesbar."
            )
        }
    }

    private func readPageMetadata(_ pageID: UUID, in packageURL: URL) throws -> NotebookPageMetadata {
        let url = pageDirectoryURL(pageID, in: packageURL).appendingPathComponent("metadata.json")
        do {
            let metadata = try JSONCoding.decoder().decode(
                NotebookPageMetadata.self,
                from: readData(
                    at: url,
                    maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                    description: "Seitenmetadaten überschreiten 2 MB."
                )
            )
            guard metadata.id == pageID else {
                throw DocumentStoreError.damagedDocument("Eine Seiten-ID stimmt nicht überein.")
            }
            if let transcription = metadata.transcribedText {
                try validateTranscription(transcription)
            }
            return metadata
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument(
                "Metadaten für Seite \(pageID.uuidString) fehlen oder sind ungültig."
            )
        }
    }

    private func writePage(
        _ metadata: NotebookPageMetadata,
        drawingData: Data,
        in packageURL: URL
    ) throws {
        let directoryURL = pageDirectoryURL(metadata.id, in: packageURL)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try writePageMetadata(metadata, in: packageURL)
            try atomicWrite(drawingData, to: drawingURL(metadata.id, in: packageURL))
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func writePageMetadata(_ metadata: NotebookPageMetadata, in packageURL: URL) throws {
        do {
            try atomicWrite(
                encodedPageMetadata(metadata),
                to: pageDirectoryURL(metadata.id, in: packageURL)
                    .appendingPathComponent("metadata.json")
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func encodedManifest(_ manifest: NotebookManifest) throws -> Data {
        var manifest = manifest
        manifest.schemaVersion = NotebookManifest.currentSchemaVersion
        let data = try JSONCoding.encoder().encode(manifest)
        guard data.count <= DocumentStoreLimits.maximumMetadataBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Das Notizbuch-Manifest überschreitet 2 MB."
            )
        }
        return data
    }

    private func encodedPageMetadata(_ metadata: NotebookPageMetadata) throws -> Data {
        let data = try JSONCoding.encoder().encode(metadata)
        guard data.count <= DocumentStoreLimits.maximumMetadataBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Seitenmetadaten überschreiten 2 MB."
            )
        }
        return data
    }

    private func savePageMetadataAndManifest(
        _ metadata: NotebookPageMetadata,
        manifest: NotebookManifest,
        at packageURL: URL
    ) throws {
        try performDocumentSaveTransaction(
            [
                .replace(
                    "pages/\(metadata.id.uuidString)/metadata.json",
                    with: try encodedPageMetadata(metadata)
                ),
                .replace("manifest.json", with: try encodedManifest(manifest))
            ],
            for: manifest.id,
            kind: .notebook,
            at: packageURL
        )
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try ensureNoUnresolvedConflicts(at: url)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var writeError: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) {
            coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }
        if let coordinationError {
            throw DocumentStoreError.fileOperationFailed(coordinationError.localizedDescription)
        }
        if let writeError {
            throw DocumentStoreError.fileOperationFailed(writeError.localizedDescription)
        }
    }

    private func pageDirectoryURL(_ pageID: UUID, in packageURL: URL) -> URL {
        packageURL
            .appendingPathComponent("pages", isDirectory: true)
            .appendingPathComponent(pageID.uuidString, isDirectory: true)
    }

    private func drawingURL(_ pageID: UUID, in packageURL: URL) -> URL {
        pageDirectoryURL(pageID, in: packageURL).appendingPathComponent("drawing.data")
    }

    private func readCanvasManifest(at packageURL: URL) throws -> InfiniteCanvasManifest {
        let url = packageURL.appendingPathComponent("manifest.json")
        do {
            let manifest = try JSONCoding.decoder().decode(
                InfiniteCanvasManifest.self,
                from: readData(
                    at: url,
                    maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                    description: "Das Canvas-Manifest überschreitet 2 MB."
                )
            )
            guard manifest.schemaVersion <= InfiniteCanvasManifest.currentSchemaVersion else {
                throw DocumentStoreError.unsupportedSchemaVersion(manifest.schemaVersion)
            }
            guard manifest.schemaVersion > 0,
                  manifest.documentType == .infiniteCanvas,
                  !manifest.title.isEmpty,
                  manifest.title.count <= DocumentStoreLimits.maximumNameLength,
                  manifest.title.utf8.count <= 240,
                  manifest.width.isFinite,
                  manifest.height.isFinite,
                  manifest.width > 0,
                  manifest.height > 0,
                  manifest.width <= 1_000_000,
                  manifest.height <= 1_000_000,
                  manifest.tileConfiguration.tileSize.isFinite,
                  (64...16_384).contains(manifest.tileConfiguration.tileSize),
                  (1...4_096).contains(manifest.tileConfiguration.columns),
                  (1...4_096).contains(manifest.tileConfiguration.rows) else {
                throw DocumentStoreError.damagedDocument("Das Canvas-Manifest ist inkonsistent.")
            }
            try validateCanvasViewport(manifest.viewport)
            return manifest
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument(error.localizedDescription)
        }
    }

    private func writeCanvasManifest(_ manifest: InfiniteCanvasManifest, at packageURL: URL) throws {
        do {
            try atomicWrite(
                encodedCanvasManifest(manifest),
                to: packageURL.appendingPathComponent("manifest.json")
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func canvasDrawingURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent("drawing.data")
    }

    private func readCanvasElements(at packageURL: URL) throws -> [CanvasElement] {
        let url = canvasElementsURL(in: packageURL)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let elements = try JSONCoding.decoder().decode(
                [CanvasElement].self,
                from: readData(
                    at: url,
                    maximumBytes: DocumentStoreLimits.maximumCanvasElementsBytes,
                    description: "Canvas-Objekte überschreiten 64 MB."
                )
            )
            try validateCanvasElements(elements)
            return elements
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument("Die Canvas-Objekte sind nicht lesbar.")
        }
    }

    private func writeCanvasElements(_ elements: [CanvasElement], at packageURL: URL) throws {
        do {
            try atomicWrite(
                encodedCanvasElements(elements),
                to: canvasElementsURL(in: packageURL)
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func encodedCanvasManifest(_ manifest: InfiniteCanvasManifest) throws -> Data {
        let data = try JSONCoding.encoder().encode(manifest)
        guard data.count <= DocumentStoreLimits.maximumMetadataBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Das Canvas-Manifest überschreitet 2 MB."
            )
        }
        return data
    }

    private func encodedCanvasElements(_ elements: [CanvasElement]) throws -> Data {
        try validateCanvasElements(elements)
        let data = try JSONCoding.encoder().encode(elements)
        guard data.count <= DocumentStoreLimits.maximumCanvasElementsBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Canvas-Objekte dürfen zusammen höchstens 64 MB belegen."
            )
        }
        return data
    }

    private func canvasElementsURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent("elements.json")
    }

    private func saveLibraryState(_ state: LibraryState) throws {
        do {
            try atomicWrite(
                JSONCoding.encoder().encode(state),
                to: rootURL.appendingPathComponent(Self.libraryStateFileName)
            )
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func readRawLibraryState() throws -> LibraryState {
        let url = rootURL.appendingPathComponent(Self.libraryStateFileName)
        guard fileManager.fileExists(atPath: url.path) else { return LibraryState() }
        do {
            let decoded = try JSONCoding.decoder().decode(
                LibraryState.self,
                from: readData(
                    at: url,
                    maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                    description: "Der Bibliotheksstatus überschreitet 2 MB."
                )
            )
            return LibraryState(
                favoritePaths: decoded.favoritePaths.filter(isValidTrackedPath),
                recentPaths: decoded.recentPaths.filter(isValidTrackedPath),
                tagsByPath: decoded.tagsByPath.reduce(into: [:]) { result, entry in
                    guard isValidTrackedPath(entry.key),
                          let tags = try? validatedTags(entry.value),
                          !tags.isEmpty else { return }
                    result[entry.key] = tags
                }
            )
        } catch {
            quarantineDamagedLibraryState(at: url)
            return LibraryState()
        }
    }

    private func remapTrackedPaths(from oldPath: String, to newPath: String) throws {
        var state = try readRawLibraryState()
        let remap: (String) -> String = { path in
            if path == oldPath { return newPath }
            if path.hasPrefix(oldPath + "/") {
                return newPath + path.dropFirst(oldPath.count)
            }
            return path
        }
        state.favoritePaths = state.favoritePaths.map(remap)
        state.recentPaths = state.recentPaths.map(remap)
        state.tagsByPath = state.tagsByPath.reduce(into: [:]) { result, entry in
            result[remap(entry.key)] = entry.value
        }
        try saveLibraryState(state)
    }

    private func removeTrackedPaths(at deletedPath: String) throws {
        var state = try readRawLibraryState()
        let isDeleted: (String) -> Bool = {
            $0 == deletedPath || $0.hasPrefix(deletedPath + "/")
        }
        state.favoritePaths.removeAll(where: isDeleted)
        state.recentPaths.removeAll(where: isDeleted)
        state.tagsByPath = state.tagsByPath.filter { !isDeleted($0.key) }
        try saveLibraryState(state)
    }

    private func ensureNoUnresolvedConflicts(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path),
              let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !conflicts.isEmpty else { return }
        let path = (try? relativePath(for: url)) ?? url.lastPathComponent
        throw DocumentStoreError.externalConflict(path)
    }

    private func conflictIdentifier(for version: NSFileVersion) -> String {
        if let data = try? NSKeyedArchiver.archivedData(
            withRootObject: version.persistentIdentifier,
            requiringSecureCoding: false
        ) {
            return data.base64EncodedString()
        }
        return [
            version.localizedName ?? "",
            version.localizedNameOfSavingComputer ?? "",
            String(version.modificationDate?.timeIntervalSince1970 ?? 0)
        ].joined(separator: "|")
    }

    private func markConflictVersionsResolved(_ versions: [NSFileVersion], at url: URL) throws {
        for version in versions { version.isResolved = true }
        try NSFileVersion.removeOtherVersionsOfItem(at: url)
    }

    private func pdfAnnotationDirectoryURL(for pdfURL: URL) -> URL {
        pdfURL.deletingLastPathComponent().appendingPathComponent(
            ".\(pdfURL.lastPathComponent).birdannotations",
            isDirectory: true
        )
    }

    private func validatedPDFAnnotationDirectory(
        for pdfURL: URL,
        createIfMissing: Bool
    ) throws -> URL {
        let directoryURL = pdfAnnotationDirectoryURL(for: pdfURL)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            guard createIfMissing else {
                throw DocumentStoreError.itemNotFound(directoryURL.lastPathComponent)
            }
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: false
            )
        }

        let relativeDirectoryPath = try relativePath(for: directoryURL)
        try ensureURLRemainsInsideRootAfterResolvingSymlinks(
            directoryURL,
            relativePath: relativeDirectoryPath
        )
        try ensurePathContainsNoSymbolicLinks(relativeDirectoryPath)
        let values = try directoryURL.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey
        ])
        guard values.isDirectory == true,
              values.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument(
                "Der Speicherort für PDF-Handschrift wurde verändert."
            )
        }
        return directoryURL
    }

    private func movePDFSidecarIfPresent(from sourcePDFURL: URL, to targetPDFURL: URL) throws {
        let source = pdfAnnotationDirectoryURL(for: sourcePDFURL)
        guard fileManager.fileExists(atPath: source.path) else { return }
        _ = try validatedPDFAnnotationDirectory(for: sourcePDFURL, createIfMissing: false)
        let target = pdfAnnotationDirectoryURL(for: targetPDFURL)
        try ensureDoesNotExist(target)
        try fileManager.moveItem(at: source, to: target)
    }

    private func copyPDFSidecarIfPresent(from sourcePDFURL: URL, to targetPDFURL: URL) throws {
        let source = pdfAnnotationDirectoryURL(for: sourcePDFURL)
        guard fileManager.fileExists(atPath: source.path) else { return }
        _ = try validatedPDFAnnotationDirectory(for: sourcePDFURL, createIfMissing: false)
        let target = pdfAnnotationDirectoryURL(for: targetPDFURL)
        try ensureDoesNotExist(target)
        try fileManager.copyItem(at: source, to: target)
    }

    // MARK: - Recoverable deletion

    private struct TrashMetadata: Codable {
        let originalRelativePath: String
        let storedItemName: String
        let deletedAt: Date
        let kind: LibraryItemKind?
        let favoritePaths: [String]?
        let recentPaths: [String]?
        let tagsByPath: [String: [String]]?
    }

    private struct TrashEntry {
        let url: URL
        let metadata: TrashMetadata

        var id: String { url.lastPathComponent }
    }

    private func makeTrashEntry(
        for itemURL: URL,
        originalRelativePath: String,
        kind: LibraryItemKind
    ) throws -> URL {
        _ = try resolvedURL(for: originalRelativePath)
        let trashURL = rootURL.appendingPathComponent(Self.trashDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: trashURL.path) {
            let values = try trashURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw DocumentStoreError.damagedDocument("Der Papierkorb wurde verändert.")
            }
        } else {
            try fileManager.createDirectory(at: trashURL, withIntermediateDirectories: false)
        }

        let entryURL = trashURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: entryURL, withIntermediateDirectories: false)
        do {
            let state = try readRawLibraryState()
            let isTrackedPath: (String) -> Bool = {
                $0 == originalRelativePath || $0.hasPrefix(originalRelativePath + "/")
            }
            let metadata = TrashMetadata(
                originalRelativePath: originalRelativePath,
                storedItemName: itemURL.lastPathComponent,
                deletedAt: Date(),
                kind: kind,
                favoritePaths: state.favoritePaths.filter(isTrackedPath),
                recentPaths: state.recentPaths.filter(isTrackedPath),
                tagsByPath: state.tagsByPath.filter { isTrackedPath($0.key) }
            )
            let data = try JSONCoding.encoder().encode(metadata)
            guard data.count <= DocumentStoreLimits.maximumTrashMetadataBytes else {
                throw DocumentStoreError.resourceLimitExceeded(
                    "Die Organisationsdaten für den Papierkorb sind zu groß."
                )
            }
            try atomicWrite(data, to: entryURL.appendingPathComponent("metadata.json"))
            return entryURL
        } catch {
            try? fileManager.removeItem(at: entryURL)
            throw error
        }
    }

    private func restoreTrackedMetadata(_ metadata: TrashMetadata, to restoredPath: String) throws {
        let oldPath = metadata.originalRelativePath
        let remap: (String) -> String = { path in
            if path == oldPath { return restoredPath }
            if path.hasPrefix(oldPath + "/") {
                return restoredPath + path.dropFirst(oldPath.count)
            }
            return path
        }

        var state = try readRawLibraryState()
        for path in metadata.favoritePaths ?? [] where !state.favoritePaths.contains(remap(path)) {
            state.favoritePaths.append(remap(path))
        }
        state.favoritePaths = Array(state.favoritePaths.prefix(LibraryState.maximumFavoriteItems))

        let restoredRecent = (metadata.recentPaths ?? []).map(remap)
        state.recentPaths.removeAll { restoredRecent.contains($0) }
        state.recentPaths.insert(contentsOf: restoredRecent, at: 0)
        state.recentPaths = Array(state.recentPaths.prefix(LibraryState.maximumRecentItems))

        for (path, tags) in metadata.tagsByPath ?? [:] {
            if let validated = try? validatedTags(tags), !validated.isEmpty {
                state.tagsByPath[remap(path)] = validated
            }
        }
        try saveLibraryState(state)
    }

    private func trashEntries() throws -> [TrashEntry] {
        let trashURL = rootURL.appendingPathComponent(Self.trashDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: trashURL.path) else { return [] }
        let trashValues = try trashURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard trashValues.isDirectory == true, trashValues.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("Der Papierkorb wurde verändert.")
        }

        return try fileManager.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).compactMap { entryURL in
            let values = try entryURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true,
                  values.isSymbolicLink != true,
                  UUID(uuidString: entryURL.lastPathComponent) != nil else { return nil }
            let metadataURL = entryURL.appendingPathComponent("metadata.json")
            guard let data = try? readData(
                at: metadataURL,
                maximumBytes: DocumentStoreLimits.maximumTrashMetadataBytes,
                description: "Papierkorb-Metadaten überschreiten 4 MB."
            ),
            let metadata = try? JSONCoding.decoder().decode(TrashMetadata.self, from: data),
            metadata.storedItemName == URL(fileURLWithPath: metadata.storedItemName).lastPathComponent,
            (try? resolvedURL(for: metadata.originalRelativePath)) != nil else { return nil }
            let storedItemURL = entryURL.appendingPathComponent(metadata.storedItemName)
            guard fileManager.fileExists(atPath: storedItemURL.path),
                  (try? storedItemURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
            else { return nil }
            return TrashEntry(url: entryURL, metadata: metadata)
        }
    }

    private func pruneTrashIfNeeded() throws {
        let entries = try trashEntries().sorted { $0.metadata.deletedAt > $1.metadata.deletedAt }
        for entry in entries.dropFirst(Self.maximumTrashEntries) {
            try fileManager.removeItem(at: entry.url)
        }
    }

    // MARK: - Path safety

    private func existingFolderURL(for relativePath: String) throws -> URL {
        let url = try existingItemURL(for: relativePath)
        var isDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard isDirectory.boolValue,
              url.pathExtension.lowercased() != Self.notebookExtension,
              url.pathExtension.lowercased() != Self.canvasExtension else {
            throw DocumentStoreError.notAFolder(relativePath)
        }
        return url
    }

    private func existingNotebookURL(for relativePath: String) throws -> URL {
        let url = try existingItemURL(for: relativePath)
        guard url.pathExtension.lowercased() == Self.notebookExtension else {
            throw DocumentStoreError.notANotebook(relativePath)
        }
        return url
    }

    private func existingCanvasURL(for relativePath: String) throws -> URL {
        let url = try existingItemURL(for: relativePath)
        guard url.pathExtension.lowercased() == Self.canvasExtension else {
            throw DocumentStoreError.notAProjectCanvas(relativePath)
        }
        return url
    }

    private func existingPDFURL(for relativePath: String) throws -> URL {
        let url = try existingItemURL(for: relativePath)
        guard url.pathExtension.lowercased() == "pdf" else {
            throw DocumentStoreError.notAPDF(relativePath)
        }
        return url
    }

    private func existingItemURL(for relativePath: String) throws -> URL {
        let url = try resolvedURL(for: relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            throw DocumentStoreError.itemNotFound(relativePath)
        }
        try ensureURLRemainsInsideRootAfterResolvingSymlinks(url, relativePath: relativePath)
        try ensurePathContainsNoSymbolicLinks(relativePath)
        return url
    }

    private func resolvedURL(for relativePath: String) throws -> URL {
        if relativePath.isEmpty { return rootURL }
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
              !relativePath.contains("\0"),
              !components.contains(".."),
              !components.contains("."),
              !components.contains(""),
              !components.contains(where: { $0.hasPrefix(".") }),
              !components.dropLast().contains(where: {
                  let component = String($0).lowercased()
                  return component.hasSuffix(".\(Self.notebookExtension)")
                      || component.hasSuffix(".\(Self.canvasExtension)")
              }) else {
            throw DocumentStoreError.invalidPath(relativePath)
        }

        let url = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(rootURL.path + "/") else {
            throw DocumentStoreError.invalidPath(relativePath)
        }
        return url
    }

    private func relativePath(for url: URL) throws -> String {
        let standardized = url.standardizedFileURL.path
        guard standardized.hasPrefix(rootURL.path + "/") else {
            throw DocumentStoreError.invalidPath(standardized)
        }
        return String(standardized.dropFirst(rootURL.path.count + 1))
    }

    private func validatedName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.count <= DocumentStoreLimits.maximumNameLength,
              name.utf8.count <= 240,
              name != ".",
              name != "..",
              !name.hasPrefix("."),
              !name.contains("/"),
              !name.contains("\\"),
              !name.contains(":"),
              !name.contains("\0"),
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw DocumentStoreError.invalidName(rawName)
        }
        return name
    }

    private func validatedTags(_ rawTags: [String]) throws -> [String] {
        guard rawTags.count <= 1_000 else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Die Tag-Liste ist zu groß."
            )
        }

        var seen = Set<String>()
        var result: [String] = []
        for rawTag in rawTags {
            let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty,
                  tag.count <= LibraryState.maximumTagLength,
                  tag.utf8.count <= 120,
                  !tag.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                  !tag.contains("/"),
                  !tag.contains("\\") else {
                throw DocumentStoreError.invalidName(rawTag)
            }
            let comparisonKey = tag.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(comparisonKey).inserted else { continue }
            result.append(tag)
        }
        guard result.count <= LibraryState.maximumTagsPerItem else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Pro Eintrag sind höchstens \(LibraryState.maximumTagsPerItem) Tags möglich."
            )
        }
        return result.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func ensureURLRemainsInsideRootAfterResolvingSymlinks(
        _ url: URL,
        relativePath: String
    ) throws {
        let canonicalRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalURL = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard canonicalURL == canonicalRoot || canonicalURL.hasPrefix(canonicalRoot + "/") else {
            throw DocumentStoreError.invalidPath(relativePath)
        }
    }

    private func ensurePathContainsNoSymbolicLinks(_ relativePath: String) throws {
        guard !relativePath.isEmpty else { return }
        var candidate = rootURL
        for component in relativePath.split(separator: "/") {
            candidate.appendPathComponent(String(component))
            let values = try candidate.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw DocumentStoreError.invalidPath(relativePath)
            }
        }
    }

    private func isValidTrackedPath(_ path: String) -> Bool {
        !path.isEmpty && (try? resolvedURL(for: path)) != nil
    }

    private func quarantineDamagedLibraryState(at url: URL) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantineURL = rootURL.appendingPathComponent(
            ".birdnotes-library-damaged-\(timestamp)-\(UUID().uuidString).json"
        )
        try? fileManager.moveItem(at: url, to: quarantineURL)
    }

    private func validateDrawingData(_ data: Data) throws {
        guard data.count <= DocumentStoreLimits.maximumDrawingBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Zeichnungsdaten dürfen höchstens 128 MB groß sein."
            )
        }
    }

    private func validateTranscription(_ text: String) throws {
        guard text.count <= DocumentStoreLimits.maximumTranscriptionCharacters,
              text.utf8.count <= DocumentStoreLimits.maximumTranscriptionBytes,
              !text.contains("\0"),
              !text.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
                      && ![9, 10, 13].contains($0.value)
              }) else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Erkannter Text darf höchstens 250.000 Zeichen beziehungsweise 1 MB groß sein."
            )
        }
    }

    private func readDrawingData(at url: URL) throws -> Data {
        try readData(
            at: url,
            maximumBytes: DocumentStoreLimits.maximumDrawingBytes,
            description: "Zeichnungsdaten dürfen höchstens 128 MB groß sein."
        )
    }

    private func readData(at url: URL, maximumBytes: Int, description: String) throws -> Data {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw DocumentStoreError.damagedDocument("Eine erwartete Datei ist keine reguläre Datei.")
        }
        if let size = values.fileSize, size > maximumBytes {
            throw DocumentStoreError.resourceLimitExceeded(description)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else {
            throw DocumentStoreError.resourceLimitExceeded(description)
        }
        return data
    }

    private func copyValidatedPDF(from sourceURL: URL, to destinationURL: URL) throws {
        let values = try sourceURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw DocumentStoreError.unsupportedFileType("keine reguläre Datei")
        }
        if let size = values.fileSize, size > DocumentStoreLimits.maximumPDFBytes {
            throw DocumentStoreError.resourceLimitExceeded(
                "PDFs dürfen höchstens 512 MB groß sein."
            )
        }

        guard fileManager.createFile(atPath: destinationURL.path, contents: nil) else {
            throw DocumentStoreError.fileOperationFailed("Die Importdatei konnte nicht angelegt werden.")
        }
        let input = try FileHandle(forReadingFrom: sourceURL)
        let output = try FileHandle(forWritingTo: destinationURL)
        defer {
            try? input.close()
            try? output.close()
        }

        let chunkSize = 1_024 * 1_024
        var totalBytes = 0
        var header = Data()
        while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            totalBytes += chunk.count
            guard totalBytes <= DocumentStoreLimits.maximumPDFBytes else {
                throw DocumentStoreError.resourceLimitExceeded(
                    "PDFs dürfen höchstens 512 MB groß sein."
                )
            }
            if header.count < 1_024 {
                header.append(chunk.prefix(1_024 - header.count))
            }
            try output.write(contentsOf: chunk)
        }
        try output.synchronize()
        guard header.range(of: Data("%PDF-".utf8)) != nil else {
            throw DocumentStoreError.unsupportedFileType("ungültige PDF")
        }
    }

    private func coordinatedBackupCopy(from sourceURL: URL, to destinationURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: .withoutChanges,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try copyBackupItem(from: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }
        if let copyError { throw copyError }
        if let coordinationError {
            throw DocumentStoreError.fileOperationFailed(coordinationError.localizedDescription)
        }
    }

    // MARK: - Backup restore validation and recovery

    private struct ValidatedBackupItem {
        let url: URL
        let kind: LibraryItemKind
        let sidecarURL: URL?

        var displayName: String {
            switch kind {
            case .notebook, .infiniteCanvas, .technicalDiagram:
                url.deletingPathExtension().lastPathComponent
            case .folder, .pdf:
                url.lastPathComponent
            }
        }
    }

    private struct ValidatedBackupContents {
        let manifest: LibraryBackupManifest
        let libraryState: LibraryState
        let items: [ValidatedBackupItem]
    }

    private struct RestoreJournal: Codable {
        struct Item: Codable {
            let sourceName: String
            let targetName: String
            let sourceSidecarName: String?
            let targetSidecarName: String?
            let hadOriginal: Bool
            let hadOriginalSidecar: Bool
        }

        var committed: Bool
        let hadLibraryState: Bool
        let items: [Item]
    }

    private func validatedBackupContents(at rawBackupURL: URL) throws -> ValidatedBackupContents {
        let backupURL = rawBackupURL.standardizedFileURL
        let canonicalRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalBackup = backupURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard canonicalBackup != canonicalRoot,
              !canonicalBackup.hasPrefix(canonicalRoot + "/"),
              backupURL.pathExtension.lowercased() == Self.backupExtension else {
            throw DocumentStoreError.invalidPath(rawBackupURL.path)
        }
        let packageValues = try backupURL.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey
        ])
        guard packageValues.isDirectory == true, packageValues.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("Die Sicherung ist kein gültiges BirdNotes-Paket.")
        }

        var entryCount = 0
        var totalBytes: Int64 = 0
        try validateBackupResourceTree(
            at: backupURL,
            depth: 0,
            entryCount: &entryCount,
            totalBytes: &totalBytes
        )
        let packageChildren = try safeBackupChildren(of: backupURL)
        let allowedPackageNames = Set(["Library", "manifest.json", "WIEDERHERSTELLEN.txt"])
        guard packageChildren.allSatisfy({ allowedPackageNames.contains($0.lastPathComponent) }) else {
            throw DocumentStoreError.damagedDocument("Die Sicherung enthält unbekannte Paketdateien.")
        }

        let manifestURL = backupURL.appendingPathComponent("manifest.json")
        let manifest = try JSONCoding.decoder().decode(
            LibraryBackupManifest.self,
            from: readData(
                at: manifestURL,
                maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                description: "Das Backup-Manifest überschreitet 2 MB."
            )
        )
        guard manifest.schemaVersion == LibraryBackupManifest.currentSchemaVersion,
              manifest.itemCount >= 0,
              manifest.itemCount <= DocumentStoreLimits.maximumBackupItems,
              !manifest.includesTrash else {
            throw DocumentStoreError.damagedDocument("Das Backup-Manifest ist nicht kompatibel.")
        }

        let libraryURL = backupURL.appendingPathComponent("Library", isDirectory: true)
        let libraryValues = try libraryURL.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey
        ])
        guard libraryValues.isDirectory == true, libraryValues.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("Der Bibliotheksordner der Sicherung fehlt.")
        }

        let children = try safeBackupChildren(of: libraryURL)
        var items: [ValidatedBackupItem] = []
        for child in children where !child.lastPathComponent.hasPrefix(".") {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true,
                  let kind = itemKind(for: child, isDirectory: values.isDirectory == true) else {
                throw DocumentStoreError.damagedDocument(
                    "Die Sicherung enthält den unbekannten Eintrag \(child.lastPathComponent)."
                )
            }
            try validateBackupItemName(child, kind: kind)
            try validateBackupItem(at: child, kind: kind)
            let sidecarURL: URL?
            if kind == .pdf {
                let candidate = libraryURL.appendingPathComponent(
                    ".\(child.lastPathComponent).birdannotations",
                    isDirectory: true
                )
                sidecarURL = fileManager.fileExists(atPath: candidate.path) ? candidate : nil
                if let sidecarURL { try validateBackupPDFSidecar(at: sidecarURL) }
            } else {
                sidecarURL = nil
            }
            items.append(ValidatedBackupItem(url: child, kind: kind, sidecarURL: sidecarURL))
        }

        let allowedHiddenNames = Set(
            [Self.libraryStateFileName]
                + items.compactMap { $0.sidecarURL?.lastPathComponent }
        )
        guard children.filter({ $0.lastPathComponent.hasPrefix(".") }).allSatisfy({
            allowedHiddenNames.contains($0.lastPathComponent)
        }) else {
            throw DocumentStoreError.damagedDocument("Die Sicherung enthält unbekannte versteckte Daten.")
        }
        guard items.count == manifest.itemCount else {
            throw DocumentStoreError.damagedDocument("Die Anzahl der Backup-Einträge stimmt nicht.")
        }

        let stateURL = libraryURL.appendingPathComponent(Self.libraryStateFileName)
        let libraryState = fileManager.fileExists(atPath: stateURL.path)
            ? try validatedBackupLibraryState(at: stateURL, libraryURL: libraryURL)
            : LibraryState()
        return ValidatedBackupContents(
            manifest: manifest,
            libraryState: libraryState,
            items: items.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        )
    }

    private func validateBackupResourceTree(
        at url: URL,
        depth: Int,
        entryCount: inout Int,
        totalBytes: inout Int64
    ) throws {
        guard depth <= DocumentStoreLimits.maximumBackupDepth else {
            throw DocumentStoreError.resourceLimitExceeded("Die Backup-Ordnerstruktur ist zu tief.")
        }
        entryCount += 1
        guard entryCount <= DocumentStoreLimits.maximumBackupItems else {
            throw DocumentStoreError.resourceLimitExceeded("Die Sicherung enthält zu viele Einträge.")
        }
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("Symbolische Links sind in Sicherungen nicht erlaubt.")
        }
        if values.isDirectory == true {
            for child in try safeBackupChildren(of: url) {
                try validateBackupResourceTree(
                    at: child,
                    depth: depth + 1,
                    entryCount: &entryCount,
                    totalBytes: &totalBytes
                )
            }
        } else if values.isRegularFile == true {
            totalBytes += Int64(values.fileSize ?? 0)
            guard totalBytes <= DocumentStoreLimits.maximumBackupBytes else {
                throw DocumentStoreError.resourceLimitExceeded("Die Sicherung überschreitet 20 GB.")
            }
        } else {
            throw DocumentStoreError.damagedDocument("Die Sicherung enthält einen ungültigen Dateityp.")
        }
    }

    private func safeBackupChildren(of directoryURL: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: []
        )
    }

    private func readTechnicalIndexManifest(at packageURL: URL) throws -> TechnicalDocumentIndexManifest {
        let data = try readTechnicalPackageFile(
            packageURL.appendingPathComponent("manifest.json"),
            maximumBytes: 1_000_000
        )
        let manifest = try JSONCoding.decoder().decode(TechnicalDocumentIndexManifest.self, from: data)
        guard manifest.schemaVersion == 1,
              !manifest.title.isEmpty,
              manifest.title.count <= DocumentStoreLimits.maximumNameLength,
              manifest.title.utf8.count <= 240,
              !manifest.writerVersion.isEmpty,
              manifest.writerVersion.utf8.count <= 128,
              manifest.moduleVersions.count <= 128,
              isSHA256(manifest.diagramSHA256),
              isSHA256(manifest.calculationsSHA256),
              manifest.annotationsSHA256.map(isSHA256) ?? true,
              manifest.previewSHA256.map(isSHA256) ?? true else {
            throw DocumentStoreError.damagedDocument("Ein Technik-Manifest ist ungültig.")
        }
        return manifest
    }

    private func updateTechnicalIndexManifest(
        at packageURL: URL,
        title: String,
        renewIdentity: Bool
    ) throws {
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let data = try readTechnicalPackageFile(manifestURL, maximumBytes: 1_000_000)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DocumentStoreError.damagedDocument("Das Technik-Manifest ist nicht lesbar.")
        }
        object["title"] = title
        object["modifiedAt"] = ISO8601DateFormatter().string(from: Date())
        if renewIdentity {
            object["documentID"] = UUID().uuidString
            object["createdAt"] = object["modifiedAt"]
        }
        let updated = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard updated.count <= 1_000_000 else {
            throw DocumentStoreError.resourceLimitExceeded("Das Technik-Manifest ist zu groß.")
        }
        try atomicWrite(updated, to: manifestURL)
        _ = try readTechnicalIndexManifest(at: packageURL)
    }

    private func validateBackupTechnicalDiagram(at packageURL: URL) throws {
        let manifest = try readTechnicalIndexManifest(at: packageURL)
        let children = try safeBackupChildren(of: packageURL)
        let names = Set(children.map(\.lastPathComponent))
        var expected = Set(["manifest.json", "diagram.json", "calculations.json"])
        if manifest.annotationsSHA256 != nil { expected.insert("annotations.data") }
        if manifest.previewSHA256 != nil { expected.insert("preview.png") }
        guard names == expected else {
            throw DocumentStoreError.damagedDocument("Ein Technik-Paket enthält unbekannte oder fehlende Dateien.")
        }

        let diagram = try readTechnicalPackageFile(
            packageURL.appendingPathComponent("diagram.json"),
            maximumBytes: 50_000_000
        )
        let calculations = try readTechnicalPackageFile(
            packageURL.appendingPathComponent("calculations.json"),
            maximumBytes: 10_000_000
        )
        guard sha256Hex(for: diagram) == manifest.diagramSHA256,
              sha256Hex(for: calculations) == manifest.calculationsSHA256 else {
            throw DocumentStoreError.damagedDocument("Die Prüfsumme eines Technik-Pakets ist ungültig.")
        }
        _ = try JSONSerialization.jsonObject(with: diagram)
        _ = try JSONSerialization.jsonObject(with: calculations)

        if let checksum = manifest.annotationsSHA256 {
            let annotations = try readTechnicalPackageFile(
                packageURL.appendingPathComponent("annotations.data"),
                maximumBytes: 100_000_000
            )
            guard sha256Hex(for: annotations) == checksum else {
                throw DocumentStoreError.damagedDocument("Technische Handschriftdaten wurden verändert.")
            }
        }
        if let checksum = manifest.previewSHA256 {
            let preview = try readTechnicalPackageFile(
                packageURL.appendingPathComponent("preview.png"),
                maximumBytes: 20_000_000
            )
            guard sha256Hex(for: preview) == checksum else {
                throw DocumentStoreError.damagedDocument("Die Technik-Vorschau wurde verändert.")
            }
        }
    }

    private func readTechnicalPackageFile(_ url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let size = values.fileSize,
              size >= 0,
              size <= maximumBytes else {
            throw DocumentStoreError.resourceLimitExceeded("Eine Technik-Paketdatei fehlt oder ist zu groß.")
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= maximumBytes else {
            throw DocumentStoreError.resourceLimitExceeded("Eine Technik-Paketdatei ist zu groß.")
        }
        return data
    }

    private func isSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private func validateBackupItem(at url: URL, kind: LibraryItemKind) throws {
        switch kind {
        case .folder:
            for child in try safeBackupChildren(of: url) {
                if child.lastPathComponent.hasPrefix(".") {
                    guard child.lastPathComponent.hasSuffix(".birdannotations") else {
                        throw DocumentStoreError.damagedDocument("Ein Backup-Ordner enthält versteckte Fremddaten.")
                    }
                    let pdfName = String(child.lastPathComponent.dropFirst().dropLast(".birdannotations".count))
                    guard fileManager.fileExists(
                        atPath: url.appendingPathComponent(pdfName).path
                    ) else {
                        throw DocumentStoreError.damagedDocument("PDF-Handschrift ist keiner PDF zugeordnet.")
                    }
                    try validateBackupPDFSidecar(at: child)
                    continue
                }
                let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true,
                      let childKind = itemKind(for: child, isDirectory: values.isDirectory == true) else {
                    throw DocumentStoreError.damagedDocument("Ein Backup-Ordner enthält einen unbekannten Eintrag.")
                }
                try validateBackupItemName(child, kind: childKind)
                try validateBackupItem(at: child, kind: childKind)
            }
        case .notebook:
            let manifest = try readManifest(at: url)
            let childNames = Set(try safeBackupChildren(of: url).map(\.lastPathComponent))
            guard childNames == Set(["manifest.json", "pages"]) else {
                throw DocumentStoreError.damagedDocument("Ein Notizbuch-Paket enthält unbekannte Dateien.")
            }
            let pagesURL = url.appendingPathComponent("pages", isDirectory: true)
            let pageNames = Set(try safeBackupChildren(of: pagesURL).map(\.lastPathComponent))
            guard pageNames == Set(manifest.pageOrder.map(\.uuidString)) else {
                throw DocumentStoreError.damagedDocument("Die Seitenstruktur eines Backups ist inkonsistent.")
            }
            for pageID in manifest.pageOrder {
                let pageURL = pageDirectoryURL(pageID, in: url)
                guard Set(try safeBackupChildren(of: pageURL).map(\.lastPathComponent))
                    == Set(["metadata.json", "drawing.data"]) else {
                    throw DocumentStoreError.damagedDocument("Eine Backup-Seite enthält unbekannte Dateien.")
                }
                _ = try readPage(pageID, in: url)
            }
        case .infiniteCanvas:
            _ = try readCanvasManifest(at: url)
            _ = try readDrawingData(at: canvasDrawingURL(in: url))
            _ = try readCanvasElements(at: url)
            let allowed = Set(["manifest.json", "drawing.data", "elements.json"])
            guard try safeBackupChildren(of: url).allSatisfy({ allowed.contains($0.lastPathComponent) }) else {
                throw DocumentStoreError.damagedDocument("Ein Canvas-Paket enthält unbekannte Dateien.")
            }
        case .technicalDiagram:
            try validateBackupTechnicalDiagram(at: url)
        case .pdf:
            try validateBackupPDF(at: url)
        }
    }

    private func validateBackupItemName(_ url: URL, kind: LibraryItemKind) throws {
        switch kind {
        case .folder:
            _ = try validatedName(url.lastPathComponent)
        case .notebook:
            _ = try validatedDocumentTitle(
                url.lastPathComponent,
                removingExtension: Self.notebookExtension
            )
        case .infiniteCanvas:
            _ = try validatedDocumentTitle(
                url.lastPathComponent,
                removingExtension: Self.canvasExtension
            )
        case .technicalDiagram:
            _ = try validatedDocumentTitle(
                url.lastPathComponent,
                removingExtension: Self.technicalDiagramExtension
            )
        case .pdf:
            _ = try validatedDocumentTitle(url.lastPathComponent, removingExtension: "pdf")
        }
    }

    private func validateBackupPDF(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= DocumentStoreLimits.maximumPDFBytes else {
            throw DocumentStoreError.resourceLimitExceeded("Eine Backup-PDF ist ungültig oder zu groß.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 1_024) ?? Data()
        guard header.range(of: Data("%PDF-".utf8)) != nil else {
            throw DocumentStoreError.damagedDocument("Eine Backup-PDF besitzt keinen gültigen Header.")
        }
    }

    private func validateBackupPDFSidecar(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("PDF-Handschrift ist kein gültiger Ordner.")
        }
        for child in try safeBackupChildren(of: url) {
            let baseName = child.deletingPathExtension().lastPathComponent
            guard child.pathExtension == "drawing",
                  baseName.hasPrefix("page-"),
                  let index = Int(baseName.dropFirst(5)),
                  (0..<DocumentStoreLimits.maximumPDFAnnotationPages).contains(index) else {
                throw DocumentStoreError.damagedDocument("PDF-Handschrift enthält einen ungültigen Eintrag.")
            }
            _ = try readDrawingData(at: child)
        }
    }

    private func validatedBackupLibraryState(at url: URL, libraryURL: URL) throws -> LibraryState {
        let decoded = try JSONCoding.decoder().decode(
            LibraryState.self,
            from: readData(
                at: url,
                maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                description: "Der Backup-Bibliotheksstatus überschreitet 2 MB."
            )
        )
        let allPaths = decoded.favoritePaths + decoded.recentPaths + Array(decoded.tagsByPath.keys)
        for path in allPaths {
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.isEmpty,
                  !path.hasPrefix("/"),
                  !path.contains("\0"),
                  !components.contains(".."),
                  !components.contains("."),
                  !components.contains(""),
                  !components.contains(where: { $0.hasPrefix(".") }) else {
                throw DocumentStoreError.damagedDocument("Der Backup-Bibliotheksstatus enthält unsichere Pfade.")
            }
            let itemURL = libraryURL.appendingPathComponent(path).standardizedFileURL
            guard itemURL.path.hasPrefix(libraryURL.path + "/"),
                  fileManager.fileExists(atPath: itemURL.path),
                  (try itemURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
                throw DocumentStoreError.damagedDocument("Der Backup-Bibliotheksstatus verweist auf fehlende Inhalte.")
            }
        }
        for tags in decoded.tagsByPath.values {
            _ = try validatedTags(tags)
        }
        return decoded
    }

    private func mergeBackupState(_ backupState: LibraryState, mappings: [String: String]) throws {
        func mapped(_ path: String) -> String? {
            guard let first = path.split(separator: "/").first,
                  let target = mappings[String(first)] else { return nil }
            let source = String(first)
            return path == source ? target : target + path.dropFirst(source.count)
        }

        var state = try readRawLibraryState()
        for path in backupState.favoritePaths.compactMap(mapped) where !state.favoritePaths.contains(path) {
            state.favoritePaths.append(path)
        }
        let restoredRecent = backupState.recentPaths.compactMap(mapped)
        state.recentPaths = Array((restoredRecent + state.recentPaths)
            .reduce(into: [String]()) { result, path in
                if !result.contains(path) { result.append(path) }
            }
            .prefix(LibraryState.maximumRecentItems))
        for (path, tags) in backupState.tagsByPath {
            if let target = mapped(path) { state.tagsByPath[target] = tags }
        }
        state.favoritePaths = Array(state.favoritePaths.prefix(LibraryState.maximumFavoriteItems))
        try saveLibraryState(state)
    }

    // MARK: - Recoverable document saves

    /// Commits a group of package-file changes through a small redo journal.
    /// Staged payloads remain untouched until all are durable and checksummed;
    /// recovery can therefore replay every operation after an interruption.
    private func performDocumentSaveTransaction(
        _ mutations: [DocumentSaveMutation],
        for documentID: UUID,
        kind: DocumentKind,
        at packageURL: URL
    ) throws {
        guard !mutations.isEmpty,
              mutations.count <= DocumentSaveJournal.maximumEntries,
              Set(mutations.map(\.targetRelativePath)).count == mutations.count else {
            throw DocumentStoreError.damagedDocument("Eine Speichertransaktion ist inkonsistent.")
        }

        // A failed save in the same app session must be completed before a new
        // one for the same library can supersede its prepared payloads.
        _ = try recoverInterruptedTransactions()

        let packageRelativePath = try relativePath(for: packageURL)
        let transactionRoot = rootURL
            .appendingPathComponent(Self.transactionDirectoryName, isDirectory: true)
        try ensureSafeInternalDirectory(transactionRoot)
        let transactionURL = transactionRoot.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let incomingURL = transactionURL.appendingPathComponent("incoming", isDirectory: true)
        var journalWasWritten = false

        do {
            try fileManager.createDirectory(at: transactionURL, withIntermediateDirectories: false)
            try fileManager.createDirectory(at: incomingURL, withIntermediateDirectories: false)

            let entries = try mutations.enumerated().map { index, mutation in
                try validateDocumentTransactionTargetPath(
                    mutation.targetRelativePath,
                    action: mutation.action,
                    kind: kind
                )
                switch mutation.action {
                case .replaceFile:
                    guard let data = mutation.data else {
                        throw DocumentStoreError.damagedDocument(
                            "Einer Speichertransaktion fehlen vorbereitete Daten."
                        )
                    }
                    let maximumBytes = try maximumDocumentTransactionPayloadBytes(
                        for: mutation.targetRelativePath,
                        kind: kind
                    )
                    guard data.count <= maximumBytes else {
                        throw DocumentStoreError.resourceLimitExceeded(
                            "Eine vorbereitete Dokumentdatei überschreitet ihr Größenlimit."
                        )
                    }
                    let incomingName = "payload-\(index)"
                    try data.write(
                        to: incomingURL.appendingPathComponent(incomingName),
                        options: [.atomic]
                    )
                    return DocumentSaveJournal.Entry(
                        targetRelativePath: mutation.targetRelativePath,
                        action: mutation.action,
                        incomingName: incomingName,
                        byteCount: data.count,
                        sha256: sha256Hex(for: data)
                    )
                case .deleteDirectory:
                    guard mutation.data == nil else {
                        throw DocumentStoreError.damagedDocument(
                            "Eine Löschoperation enthält unerwartete Daten."
                        )
                    }
                    return DocumentSaveJournal.Entry(
                        targetRelativePath: mutation.targetRelativePath,
                        action: mutation.action,
                        incomingName: nil,
                        byteCount: nil,
                        sha256: nil
                    )
                }
            }

            let journal = DocumentSaveJournal(
                schemaVersion: DocumentSaveJournal.currentSchemaVersion,
                transactionType: DocumentSaveJournal.transactionType,
                committed: false,
                documentKind: kind,
                packageRelativePath: packageRelativePath,
                documentID: documentID,
                entries: entries
            )
            try writeDocumentSaveJournal(journal, at: transactionURL)
            journalWasWritten = true
            try finishDocumentSaveTransaction(journal, at: transactionURL)
            try? removeTransactionContainerIfEmpty(transactionRoot)
        } catch let error as DocumentStoreError {
            if !journalWasWritten {
                try? fileManager.removeItem(at: transactionURL)
                try? removeTransactionContainerIfEmpty(transactionRoot)
            }
            throw error
        } catch {
            if !journalWasWritten {
                try? fileManager.removeItem(at: transactionURL)
                try? removeTransactionContainerIfEmpty(transactionRoot)
            }
            throw DocumentStoreError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func writeDocumentSaveJournal(
        _ journal: DocumentSaveJournal,
        at transactionURL: URL
    ) throws {
        try atomicWrite(
            JSONCoding.encoder().encode(journal),
            to: transactionURL.appendingPathComponent("document-journal.json")
        )
    }

    private func readDocumentSaveJournal(at transactionURL: URL) throws -> DocumentSaveJournal {
        let journal = try JSONCoding.decoder().decode(
            DocumentSaveJournal.self,
            from: readData(
                at: transactionURL.appendingPathComponent("document-journal.json"),
                maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                description: "Das Speicherjournal überschreitet 2 MB."
            )
        )
        guard journal.schemaVersion == DocumentSaveJournal.currentSchemaVersion,
              journal.transactionType == DocumentSaveJournal.transactionType,
              journal.documentKind == .notebook || journal.documentKind == .infiniteCanvas,
              !journal.entries.isEmpty,
              journal.entries.count <= DocumentSaveJournal.maximumEntries,
              Set(journal.entries.map(\.targetRelativePath)).count == journal.entries.count,
              (try? resolvedURL(for: journal.packageRelativePath)) != nil else {
            throw DocumentStoreError.damagedDocument("Ein Speicherjournal ist inkonsistent.")
        }

        for (index, entry) in journal.entries.enumerated() {
            try validateDocumentTransactionTargetPath(
                entry.targetRelativePath,
                action: entry.action,
                kind: journal.documentKind
            )
            switch entry.action {
            case .replaceFile:
                guard entry.incomingName == "payload-\(index)",
                      let byteCount = entry.byteCount,
                      byteCount >= 0,
                      let sha256 = entry.sha256,
                      sha256.count == 64,
                      sha256.unicodeScalars.allSatisfy({
                          (48...57).contains($0.value) || (97...102).contains($0.value)
                      }) else {
                    throw DocumentStoreError.damagedDocument(
                        "Ein Speicherjournal verweist auf ungültige Nutzdaten."
                    )
                }
                let maximumBytes = try maximumDocumentTransactionPayloadBytes(
                    for: entry.targetRelativePath,
                    kind: journal.documentKind
                )
                guard byteCount <= maximumBytes else {
                    throw DocumentStoreError.resourceLimitExceeded(
                        "Eine vorbereitete Dokumentdatei überschreitet ihr Größenlimit."
                    )
                }
            case .deleteDirectory:
                guard entry.incomingName == nil,
                      entry.byteCount == nil,
                      entry.sha256 == nil else {
                    throw DocumentStoreError.damagedDocument(
                        "Eine Löschoperation enthält unerwartete Nutzdaten."
                    )
                }
            }
        }
        return journal
    }

    private func finishDocumentSaveTransaction(
        _ originalJournal: DocumentSaveJournal,
        at transactionURL: URL
    ) throws {
        guard !originalJournal.committed else {
            try? fileManager.removeItem(at: transactionURL)
            return
        }

        let packageURL: URL
        switch originalJournal.documentKind {
        case .notebook:
            packageURL = try existingNotebookURL(for: originalJournal.packageRelativePath)
            guard try readManifest(at: packageURL).id == originalJournal.documentID else {
                throw DocumentStoreError.damagedDocument(
                    "Das Ziel eines Speicherjournals wurde ausgetauscht."
                )
            }
        case .infiniteCanvas:
            packageURL = try existingCanvasURL(for: originalJournal.packageRelativePath)
            guard try readCanvasManifest(at: packageURL).id == originalJournal.documentID else {
                throw DocumentStoreError.damagedDocument(
                    "Das Ziel eines Speicherjournals wurde ausgetauscht."
                )
            }
        case .pdf:
            throw DocumentStoreError.damagedDocument(
                "Ein Speicherjournal enthält einen nicht unterstützten Dokumenttyp."
            )
        }

        // Validate every staged file before touching any package target. Each
        // payload is checked again immediately before use to close the window
        // for externally modified File-Provider data.
        for entry in originalJournal.entries where entry.action == .replaceFile {
            _ = try validatedDocumentTransactionPayload(
                for: entry,
                journal: originalJournal,
                at: transactionURL
            )
        }

        for entry in originalJournal.entries {
            let targetURL = try documentTransactionTargetURL(
                for: entry.targetRelativePath,
                packageURL: packageURL
            )
            switch entry.action {
            case .replaceFile:
                let data = try validatedDocumentTransactionPayload(
                    for: entry,
                    journal: originalJournal,
                    at: transactionURL
                )
                let parentURL = targetURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
                let rootRelativeParent = try relativePath(for: parentURL)
                try ensureURLRemainsInsideRootAfterResolvingSymlinks(
                    parentURL,
                    relativePath: rootRelativeParent
                )
                try ensurePathContainsNoSymbolicLinks(rootRelativeParent)
                if fileManager.fileExists(atPath: targetURL.path) {
                    let rootRelativeTarget = try relativePath(for: targetURL)
                    try ensureURLRemainsInsideRootAfterResolvingSymlinks(
                        targetURL,
                        relativePath: rootRelativeTarget
                    )
                    try ensurePathContainsNoSymbolicLinks(rootRelativeTarget)
                }
                try atomicWrite(data, to: targetURL)
            case .deleteDirectory:
                guard fileManager.fileExists(atPath: targetURL.path) else { continue }
                let rootRelativeTarget = try relativePath(for: targetURL)
                try ensureURLRemainsInsideRootAfterResolvingSymlinks(
                    targetURL,
                    relativePath: rootRelativeTarget
                )
                try ensurePathContainsNoSymbolicLinks(rootRelativeTarget)
                try ensureNoUnresolvedConflicts(at: targetURL)
                try fileManager.removeItem(at: targetURL)
            }
        }

        var committedJournal = originalJournal
        committedJournal.committed = true
        try writeDocumentSaveJournal(committedJournal, at: transactionURL)
        // Cleanup is deliberately best-effort after the durable commit marker.
        // Recovery recognizes this state and only removes the staging folder.
        try? fileManager.removeItem(at: transactionURL)
    }

    private func validatedDocumentTransactionPayload(
        for entry: DocumentSaveJournal.Entry,
        journal: DocumentSaveJournal,
        at transactionURL: URL
    ) throws -> Data {
        guard let incomingName = entry.incomingName,
              let expectedByteCount = entry.byteCount,
              let expectedSHA256 = entry.sha256 else {
            throw DocumentStoreError.damagedDocument(
                "Einem Speicherjournal fehlen vorbereitete Daten."
            )
        }
        let maximumBytes = try maximumDocumentTransactionPayloadBytes(
            for: entry.targetRelativePath,
            kind: journal.documentKind
        )
        let incomingDirectoryURL = transactionURL
            .appendingPathComponent("incoming", isDirectory: true)
        let incomingDirectoryValues = try incomingDirectoryURL.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard incomingDirectoryValues.isDirectory == true,
              incomingDirectoryValues.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument(
                "Der Vorbereitungsbereich einer Speichertransaktion wurde verändert."
            )
        }
        let data = try readData(
            at: incomingDirectoryURL.appendingPathComponent(incomingName),
            maximumBytes: maximumBytes,
            description: "Eine vorbereitete Dokumentdatei überschreitet ihr Größenlimit."
        )
        guard data.count == expectedByteCount,
              sha256Hex(for: data) == expectedSHA256 else {
            throw DocumentStoreError.damagedDocument(
                "Vorbereitete Dokumentdaten sind unvollständig oder wurden verändert."
            )
        }
        try validateDocumentTransactionPayload(
            data,
            targetRelativePath: entry.targetRelativePath,
            documentID: journal.documentID,
            kind: journal.documentKind
        )
        return data
    }

    private func documentTransactionTargetURL(
        for targetRelativePath: String,
        packageURL: URL
    ) throws -> URL {
        let targetURL = packageURL
            .appendingPathComponent(targetRelativePath)
            .standardizedFileURL
        guard targetURL.path.hasPrefix(packageURL.path + "/") else {
            throw DocumentStoreError.invalidPath(targetRelativePath)
        }
        return targetURL
    }

    private func validateDocumentTransactionTargetPath(
        _ path: String,
        action: DocumentSaveJournal.Action,
        kind: DocumentKind
    ) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !path.hasPrefix("/"),
              !path.contains("\0"),
              !components.isEmpty,
              !components.contains(""),
              !components.contains("."),
              !components.contains(".."),
              !components.contains(where: { $0.hasPrefix(".") }) else {
            throw DocumentStoreError.invalidPath(path)
        }

        switch kind {
        case .notebook:
            if action == .replaceFile, components == ["manifest.json"] { return }
            guard components.count >= 2,
                  components[0] == "pages",
                  UUID(uuidString: components[1]) != nil else {
                throw DocumentStoreError.invalidPath(path)
            }
            switch action {
            case .replaceFile:
                guard components.count == 3,
                      components[2] == "metadata.json" || components[2] == "drawing.data" else {
                    throw DocumentStoreError.invalidPath(path)
                }
            case .deleteDirectory:
                guard components.count == 2 else {
                    throw DocumentStoreError.invalidPath(path)
                }
            }
        case .infiniteCanvas:
            guard action == .replaceFile,
                  components.count == 1,
                  ["manifest.json", "drawing.data", "elements.json"].contains(components[0]) else {
                throw DocumentStoreError.invalidPath(path)
            }
        case .pdf:
            throw DocumentStoreError.invalidPath(path)
        }
    }

    private func maximumDocumentTransactionPayloadBytes(
        for path: String,
        kind: DocumentKind
    ) throws -> Int {
        try validateDocumentTransactionTargetPath(path, action: .replaceFile, kind: kind)
        if path.hasSuffix("drawing.data") {
            return DocumentStoreLimits.maximumDrawingBytes
        }
        if kind == .infiniteCanvas, path == "elements.json" {
            return DocumentStoreLimits.maximumCanvasElementsBytes
        }
        return DocumentStoreLimits.maximumMetadataBytes
    }

    private func validateDocumentTransactionPayload(
        _ data: Data,
        targetRelativePath: String,
        documentID: UUID,
        kind: DocumentKind
    ) throws {
        if targetRelativePath.hasSuffix("drawing.data") { return }

        do {
            switch kind {
            case .notebook where targetRelativePath == "manifest.json":
                let manifest = try JSONCoding.decoder().decode(NotebookManifest.self, from: data)
                guard manifest.id == documentID,
                      manifest.schemaVersion == NotebookManifest.currentSchemaVersion,
                      manifest.documentType == .notebook,
                      !manifest.title.isEmpty,
                      manifest.title.count <= DocumentStoreLimits.maximumNameLength,
                      manifest.title.utf8.count <= 240,
                      !manifest.pageOrder.isEmpty,
                      manifest.pageOrder.count <= DocumentStoreLimits.maximumNotebookPages,
                      Set(manifest.pageOrder).count == manifest.pageOrder.count else {
                    throw DocumentStoreError.damagedDocument(
                        "Ein vorbereitetes Notizbuch-Manifest ist inkonsistent."
                    )
                }
            case .notebook:
                let components = targetRelativePath.split(separator: "/")
                let expectedID = try requiredUUID(String(components[1]))
                let metadata = try JSONCoding.decoder().decode(
                    NotebookPageMetadata.self,
                    from: data
                )
                guard metadata.id == expectedID else {
                    throw DocumentStoreError.damagedDocument(
                        "Vorbereitete Seitenmetadaten besitzen eine falsche ID."
                    )
                }
                if let transcription = metadata.transcribedText {
                    try validateTranscription(transcription)
                }
            case .infiniteCanvas where targetRelativePath == "manifest.json":
                let manifest = try JSONCoding.decoder().decode(InfiniteCanvasManifest.self, from: data)
                guard manifest.id == documentID,
                      manifest.schemaVersion == InfiniteCanvasManifest.currentSchemaVersion,
                      manifest.documentType == .infiniteCanvas,
                      !manifest.title.isEmpty,
                      manifest.title.count <= DocumentStoreLimits.maximumNameLength,
                      manifest.title.utf8.count <= 240,
                      manifest.width.isFinite,
                      manifest.height.isFinite,
                      manifest.width > 0,
                      manifest.height > 0,
                      manifest.width <= 1_000_000,
                      manifest.height <= 1_000_000,
                      manifest.tileConfiguration.tileSize.isFinite,
                      (64...16_384).contains(manifest.tileConfiguration.tileSize),
                      (1...4_096).contains(manifest.tileConfiguration.columns),
                      (1...4_096).contains(manifest.tileConfiguration.rows) else {
                    throw DocumentStoreError.damagedDocument(
                        "Ein vorbereitetes Canvas-Manifest ist inkonsistent."
                    )
                }
                try validateCanvasViewport(manifest.viewport)
            case .infiniteCanvas:
                let elements = try JSONCoding.decoder().decode([CanvasElement].self, from: data)
                try validateCanvasElements(elements)
            case .pdf:
                throw DocumentStoreError.invalidPath(targetRelativePath)
            }
        } catch let error as DocumentStoreError {
            throw error
        } catch {
            throw DocumentStoreError.damagedDocument(
                "Vorbereitete Dokumentdaten sind nicht lesbar."
            )
        }
    }

    private func requiredUUID(_ value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw DocumentStoreError.invalidPath(value)
        }
        return id
    }

    private func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func ensureSafeInternalDirectory(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw DocumentStoreError.damagedDocument("Der interne Transaktionsbereich wurde verändert.")
            }
        } else {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        }
    }

    private func writeRestoreJournal(_ journal: RestoreJournal, at transactionURL: URL) throws {
        try atomicWrite(
            JSONCoding.encoder().encode(journal),
            to: transactionURL.appendingPathComponent("journal.json")
        )
    }

    private func readRestoreJournal(at transactionURL: URL) throws -> RestoreJournal {
        let journal = try JSONCoding.decoder().decode(
            RestoreJournal.self,
            from: readData(
                at: transactionURL.appendingPathComponent("journal.json"),
                maximumBytes: DocumentStoreLimits.maximumMetadataBytes,
                description: "Das Wiederherstellungsjournal überschreitet 2 MB."
            )
        )
        guard journal.items.count <= DocumentStoreLimits.maximumBackupItems,
              Set(journal.items.map(\.targetName)).count == journal.items.count else {
            throw DocumentStoreError.damagedDocument("Ein Wiederherstellungsjournal ist inkonsistent.")
        }
        for item in journal.items {
            _ = try validatedName(item.sourceName)
            _ = try validatedName(item.targetName)
            for sidecar in [item.sourceSidecarName, item.targetSidecarName].compactMap({ $0 }) {
                guard sidecar.hasPrefix("."),
                      sidecar.hasSuffix(".birdannotations"),
                      sidecar == URL(fileURLWithPath: sidecar).lastPathComponent else {
                    throw DocumentStoreError.damagedDocument("Ein Wiederherstellungsjournal enthält unsichere Pfade.")
                }
            }
        }
        return journal
    }

    private func rollbackRestoreTransaction(at transactionURL: URL) throws {
        let journalURL = transactionURL.appendingPathComponent("journal.json")
        guard fileManager.fileExists(atPath: journalURL.path) else {
            try? fileManager.removeItem(at: transactionURL)
            return
        }
        let journal = try readRestoreJournal(at: transactionURL)
        if journal.committed {
            try fileManager.removeItem(at: transactionURL)
            return
        }
        let incomingURL = transactionURL.appendingPathComponent("incoming", isDirectory: true)
        let rollbackURL = transactionURL.appendingPathComponent("rollback", isDirectory: true)
        for item in journal.items.reversed() {
            let targetURL = rootURL.appendingPathComponent(item.targetName)
            let incomingItemURL = incomingURL.appendingPathComponent(item.sourceName)
            let originalURL = rollbackURL.appendingPathComponent(item.targetName)
            if item.hadOriginal, fileManager.fileExists(atPath: originalURL.path) {
                if fileManager.fileExists(atPath: targetURL.path) {
                    try fileManager.removeItem(at: targetURL)
                }
                try fileManager.moveItem(at: originalURL, to: targetURL)
            } else if !item.hadOriginal,
                      !fileManager.fileExists(atPath: incomingItemURL.path),
                      fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }

            if let sourceSidecarName = item.sourceSidecarName,
               let targetSidecarName = item.targetSidecarName {
                let targetSidecarURL = rootURL.appendingPathComponent(targetSidecarName)
                let incomingSidecarURL = incomingURL.appendingPathComponent(sourceSidecarName)
                let originalSidecarURL = rollbackURL.appendingPathComponent(targetSidecarName)
                if item.hadOriginalSidecar,
                   fileManager.fileExists(atPath: originalSidecarURL.path) {
                    if fileManager.fileExists(atPath: targetSidecarURL.path) {
                        try fileManager.removeItem(at: targetSidecarURL)
                    }
                    try fileManager.moveItem(at: originalSidecarURL, to: targetSidecarURL)
                } else if !item.hadOriginalSidecar,
                          !fileManager.fileExists(atPath: incomingSidecarURL.path),
                          fileManager.fileExists(atPath: targetSidecarURL.path) {
                    try fileManager.removeItem(at: targetSidecarURL)
                }
            }
        }

        let stateURL = rootURL.appendingPathComponent(Self.libraryStateFileName)
        let originalStateURL = rollbackURL.appendingPathComponent(Self.libraryStateFileName)
        if journal.hadLibraryState, fileManager.fileExists(atPath: originalStateURL.path) {
            if fileManager.fileExists(atPath: stateURL.path) {
                try fileManager.removeItem(at: stateURL)
            }
            try fileManager.copyItem(at: originalStateURL, to: stateURL)
        } else if !journal.hadLibraryState, fileManager.fileExists(atPath: stateURL.path) {
            try fileManager.removeItem(at: stateURL)
        }
        try fileManager.removeItem(at: transactionURL)
    }

    private func removeTransactionContainerIfEmpty(_ url: URL) throws {
        if try fileManager.contentsOfDirectory(atPath: url.path).isEmpty {
            try fileManager.removeItem(at: url)
        }
    }

    private func copyBackupItem(from sourceURL: URL, to destinationURL: URL) throws {
        let values = try sourceURL.resourceValues(forKeys: [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ])
        guard values.isSymbolicLink != true else { return }

        if values.isDirectory == true {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: false)
            let children = try fileManager.contentsOfDirectory(
                at: sourceURL,
                includingPropertiesForKeys: [.isHiddenKey, .isSymbolicLinkKey],
                options: []
            )
            for child in children {
                let childValues = try child.resourceValues(forKeys: [.isHiddenKey, .isSymbolicLinkKey])
                guard childValues.isSymbolicLink != true else { continue }
                let isPDFSidecar = child.lastPathComponent.hasPrefix(".")
                    && child.lastPathComponent.hasSuffix(".birdannotations")
                guard childValues.isHidden != true || isPDFSidecar else { continue }
                try copyBackupItem(
                    from: child,
                    to: destinationURL.appendingPathComponent(child.lastPathComponent)
                )
            }
        } else if values.isRegularFile == true {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    private func validateCanvasViewport(_ viewport: CanvasViewport) throws {
        guard viewport.center.x.isFinite,
              viewport.center.y.isFinite,
              viewport.zoomScale.isFinite,
              abs(viewport.center.x) <= 1_000_000,
              abs(viewport.center.y) <= 1_000_000,
              (0.01...10).contains(viewport.zoomScale) else {
            throw DocumentStoreError.damagedDocument("Die gespeicherte Canvas-Ansicht ist ungültig.")
        }
    }

    private func validateCanvasElements(_ elements: [CanvasElement]) throws {
        guard elements.count <= DocumentStoreLimits.maximumCanvasElements else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Ein Canvas kann höchstens 10.000 Objekte enthalten."
            )
        }
        let ids = Set(elements.map(\.id))
        guard ids.count == elements.count else {
            throw DocumentStoreError.damagedDocument("Canvas-Objekt-IDs sind nicht eindeutig.")
        }

        var totalImageBytes = 0
        for element in elements {
            guard element.center.x.isFinite,
                  element.center.y.isFinite,
                  element.size.width.isFinite,
                  element.size.height.isFinite,
                  element.rotation.isFinite,
                  element.strokeWidth.isFinite,
                  abs(element.center.x) <= 1_000_000,
                  abs(element.center.y) <= 1_000_000,
                  element.size.width > 0,
                  element.size.height > 0,
                  element.size.width <= 1_000_000,
                  element.size.height <= 1_000_000,
                  (0...1_000).contains(element.strokeWidth),
                  isValidCanvasColor(element.strokeColor),
                  element.fillColor.map(isValidCanvasColor) ?? true else {
                throw DocumentStoreError.damagedDocument("Ein Canvas-Objekt enthält ungültige Werte.")
            }
            if let text = element.text,
               text.count > DocumentStoreLimits.maximumCanvasTextCharacters {
                throw DocumentStoreError.resourceLimitExceeded(
                    "Ein Textobjekt kann höchstens 100.000 Zeichen enthalten."
                )
            }
            if let imageData = element.imageData {
                guard element.kind == .image,
                      !imageData.isEmpty,
                      imageData.count <= DocumentStoreLimits.maximumCanvasImageBytes else {
                    throw DocumentStoreError.resourceLimitExceeded(
                        "Ein Canvas-Bild darf höchstens 20 MB groß sein."
                    )
                }
                totalImageBytes += imageData.count
            }
            if element.kind == .connector {
                guard let source = element.sourceElementID,
                      let target = element.targetElementID,
                      source != target,
                      ids.contains(source),
                      ids.contains(target) else {
                    throw DocumentStoreError.damagedDocument(
                        "Eine Canvas-Verbindung verweist auf ein fehlendes Objekt."
                    )
                }
            }
        }
        guard totalImageBytes <= DocumentStoreLimits.maximumCanvasImageTotalBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Canvas-Bilder dürfen zusammen höchstens 48 MB belegen."
            )
        }
    }

    private func isValidCanvasColor(_ color: CanvasColor) -> Bool {
        [color.red, color.green, color.blue, color.alpha].allSatisfy {
            $0.isFinite && (0...1).contains($0)
        }
    }

    private func validatedDocumentTitle(_ rawName: String, removingExtension: String) throws -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = "." + removingExtension
        if name.lowercased().hasSuffix(suffix.lowercased()) {
            name.removeLast(suffix.count)
        }
        return try validatedName(name)
    }

    private func ensureDoesNotExist(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            throw DocumentStoreError.itemAlreadyExists(url.lastPathComponent)
        }
    }

    private func itemKind(for url: URL, isDirectory: Bool) -> LibraryItemKind? {
        switch url.pathExtension.lowercased() {
        case Self.notebookExtension where isDirectory:
            return .notebook
        case Self.canvasExtension where isDirectory:
            return .infiniteCanvas
        case Self.technicalDiagramExtension where isDirectory:
            return .technicalDiagram
        case "pdf" where !isDirectory:
            return .pdf
        case "" where isDirectory:
            return .folder
        default:
            return isDirectory ? .folder : nil
        }
    }

    private func displayName(for url: URL, kind: LibraryItemKind) -> String {
        kind == .folder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
    }

    private func uniqueCopyURL(for sourceURL: URL, in parentURL: URL) -> URL {
        let pathExtension = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var suffix = " Kopie"
        var index = 2

        while true {
            var candidate = parentURL.appendingPathComponent(baseName + suffix)
            if !pathExtension.isEmpty { candidate.appendPathExtension(pathExtension) }
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            suffix = " Kopie \(index)"
            index += 1
        }
    }
}
