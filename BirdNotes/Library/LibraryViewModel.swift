import Combine
import Foundation
import os.signpost
import BirdNotesCore
import BirdNotesTechnicalCore

enum LibraryCollection: Equatable {
    case folder
    case favorites
    case recent
    case tag(String)
}

enum LibraryPerformanceDiagnostics {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dominikvogel.BirdNotes",
        category: "PointsOfInterest"
    )

    static func beginReload() -> OSSignpostID {
        let identifier = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Library Reload", signpostID: identifier)
        return identifier
    }

    static func endReload(
        _ identifier: OSSignpostID,
        visibleItems: Int,
        totalItems: Int
    ) {
        os_signpost(
            .end,
            log: log,
            name: "Library Reload",
            signpostID: identifier,
            "visible=%{public}d total=%{public}d",
            visibleItems,
            totalItems
        )
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []
    @Published private(set) var rootFolders: [LibraryItem] = []
    @Published private(set) var allLibraryItems: [LibraryItem] = []
    @Published private(set) var libraryState = LibraryState()
    @Published private(set) var currentFolderPath = ""
    @Published private(set) var collection: LibraryCollection = .folder
    @Published var searchText = ""
    @Published var sort: LibrarySort = .name
    @Published var usesGrid = true
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var canRestoreDeletion = false
    @Published private(set) var deletedItems: [DeletedLibraryItem] = []
    @Published private(set) var backupPreview: LibraryBackupPreview?
    @Published private(set) var isPreparingBackup = false
    @Published private(set) var isRestoringBackup = false
    @Published var noticeMessage: String?
    @Published private(set) var textSearchHits: [LibraryTextSearchHit] = []
    @Published private(set) var externalConflicts: [ExternalDocumentConflict] = []

    let store: DocumentStore
    private var rootMonitor: LibraryRootMonitor?
    private var preparedBackup: PreparedBackupImport?
    private var didAttemptTransactionRecovery = false
    private var cancellables = Set<AnyCancellable>()

    init(store: DocumentStore) {
        self.store = store
        let monitor = LibraryRootMonitor(url: store.rootURL)
        monitor.onChange = { [weak self] in
            Task { @MainActor [weak self] in await self?.reload() }
        }
        rootMonitor = monitor
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] query in
                Task { @MainActor [weak self] in
                    await self?.updateTextSearch(for: query)
                }
            }
            .store(in: &cancellables)
    }

    var visibleItems: [LibraryItem] {
        let source: [LibraryItem]
        if !searchText.isEmpty {
            source = allLibraryItems
        } else {
            switch collection {
            case .folder:
                source = items
            case .favorites:
                source = items(for: libraryState.favoritePaths)
            case .recent:
                source = items(for: libraryState.recentPaths)
            case .tag(let tag):
                source = allLibraryItems.filter { tags(for: $0).contains(tag) }
            }
        }
        let filtered = searchText.isEmpty ? source : source.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
                || item.relativePath.localizedCaseInsensitiveContains(searchText)
                || tags(for: item).contains { $0.localizedCaseInsensitiveContains(searchText) }
                || textSearchHits.contains { $0.documentPath == item.relativePath }
        }
        return sort.sort(filtered)
    }

    var folderTitle: String {
        switch collection {
        case .favorites: "Favoriten"
        case .recent: "Zuletzt geöffnet"
        case .tag(let tag): "Tag: \(tag)"
        case .folder:
            currentFolderPath.isEmpty
                ? "Alle Dokumente"
                : URL(fileURLWithPath: currentFolderPath).lastPathComponent
        }
    }

    var documentCountText: String {
        let folders = visibleItems.filter { $0.kind == .folder }.count
        let documents = visibleItems.count - folders
        let documentText = documents == 1 ? "1 Dokument" : "\(documents) Dokumente"
        let folderText = folders == 1 ? "1 Ordner" : "\(folders) Ordner"
        let textMatches = textSearchHits.isEmpty ? "" : " · \(textSearchHits.count) Texttreffer"
        return "\(documentText) · \(folderText)\(textMatches)"
    }

    var breadcrumbs: [(title: String, path: String)] {
        guard collection == .folder else { return [] }
        var result = [("Bibliothek", "")]
        var path = ""
        for component in currentFolderPath.split(separator: "/") {
            path = path.isEmpty ? String(component) : path + "/" + component
            result.append((String(component), path))
        }
        return result
    }

    var allTags: [String] {
        Array(Set(libraryState.tagsByPath.values.flatMap { $0 }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func reload() async {
        let performanceIdentifier = LibraryPerformanceDiagnostics.beginReload()
        isLoading = true
        defer {
            isLoading = false
            LibraryPerformanceDiagnostics.endReload(
                performanceIdentifier,
                visibleItems: items.count,
                totalItems: allLibraryItems.count
            )
        }
        do {
            if !didAttemptTransactionRecovery {
                let recoveredCount = try await store.recoverInterruptedTransactions()
                didAttemptTransactionRecovery = true
                if recoveredCount > 0 {
                    noticeMessage = recoveredCount == 1
                        ? "Eine unterbrochene Speicheraktion wurde sicher repariert."
                        : "\(recoveredCount) unterbrochene Speicheraktionen wurden sicher repariert."
                }
            }
            async let currentItems = store.listItems(in: currentFolderPath)
            async let rootItems = store.listItems()
            async let allItems = store.allItems()
            async let storedState = store.loadLibraryState()
            async let hasRestorableItems = store.hasRestorableItems()
            async let storedDeletedItems = store.listDeletedItems()
            async let storedConflicts = store.listExternalConflicts()
            items = try await currentItems
            let root = try await rootItems
            rootFolders = root.filter { $0.kind == .folder }
            allLibraryItems = try await allItems
            libraryState = try await storedState
            canRestoreDeletion = try await hasRestorableItems
            deletedItems = try await storedDeletedItems
            externalConflicts = try await storedConflicts
        } catch {
            present(error)
        }
    }

    func openFolder(_ path: String) async {
        collection = .folder
        currentFolderPath = path
        searchText = ""
        await reload()
    }

    func showFavorites() {
        collection = .favorites
        searchText = ""
    }

    func showRecent() {
        collection = .recent
        searchText = ""
    }

    func showTag(_ tag: String) {
        collection = .tag(tag)
        searchText = ""
    }

    func isFavorite(_ item: LibraryItem) -> Bool {
        libraryState.favoritePaths.contains(item.relativePath)
    }

    func tags(for item: LibraryItem) -> [String] {
        libraryState.tagsByPath[item.relativePath] ?? []
    }

    func firstTextSearchHit(for item: LibraryItem) -> LibraryTextSearchHit? {
        textSearchHits.first { $0.documentPath == item.relativePath }
    }

    func setTags(_ tags: [String], for item: LibraryItem) async {
        do {
            libraryState = try await store.setTags(tags, for: item.relativePath)
            await reload()
        } catch {
            present(error)
        }
    }

    func toggleFavorite(_ item: LibraryItem) async {
        do {
            libraryState = try await store.toggleFavorite(at: item.relativePath)
        } catch {
            present(error)
        }
    }

    func markOpened(_ item: LibraryItem) async {
        guard item.kind != .folder else { return }
        do {
            libraryState = try await store.markRecent(at: item.relativePath)
        } catch {
            present(error)
        }
    }

    func createFolder(named name: String) async {
        do {
            try await store.createFolder(named: name, in: currentFolderPath)
            await reload()
        } catch {
            present(error)
        }
    }

    func createStudyWorkspace(named name: String) async {
        do {
            try await store.createStudyWorkspace(named: name, in: currentFolderPath)
            await reload()
        } catch {
            present(error)
        }
    }

    func createSoftwareDevelopmentWorkspace() async {
        do {
            let curriculum = try StudyCurriculum.softwareDevelopment2026()
            let includedPhases: [StudyPhase] = [
                .semester1,
                .semester2,
                .semester3,
                .semester4,
                .thesis
            ]
            let phases: [StudyProgramPhaseDefinition] = includedPhases.compactMap { phase in
                let modules = curriculum.modules(in: phase)
                guard !modules.isEmpty else { return nil }
                return StudyProgramPhaseDefinition(
                    title: phase.title,
                    modules: modules.map {
                        StudyProgramModuleDefinition(code: $0.code, title: $0.title)
                    }
                )
            }
            let path = try await store.createStudyProgramWorkspace(
                named: "Software Development Studium",
                phases: phases
            )
            noticeMessage = "Die Studienbibliothek wurde unter „\(path)“ angelegt."
            await reload()
        } catch {
            present(error)
        }
    }

    func createNotebook(
        named name: String,
        paperStyle: PaperStyle = .blank,
        paperFormat: PaperFormat = .a4
    ) async -> String? {
        do {
            let path = try await store.createNotebook(
                named: name,
                in: currentFolderPath,
                paperStyle: paperStyle,
                paperFormat: paperFormat
            )
            await reload()
            return path
        } catch {
            present(error)
            return nil
        }
    }

    func createInfiniteCanvas(named name: String) async -> String? {
        do {
            let path = try await store.createInfiniteCanvas(named: name, in: currentFolderPath)
            await reload()
            return path
        } catch {
            present(error)
            return nil
        }
    }

    func createTechnicalDocument(named rawName: String, domain: TechnicalDomain) async -> String? {
        do {
            var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = "." + DocumentStore.technicalDiagramExtension
            if name.lowercased().hasSuffix(suffix) {
                name.removeLast(suffix.count)
            }
            guard !name.isEmpty,
                  name.count <= DocumentStoreLimits.maximumNameLength,
                  name.utf8.count <= 240,
                  !name.hasPrefix("."),
                  !name.contains("/"),
                  !name.contains(":"),
                  name != ".",
                  name != ".." else {
                throw TechnicalCoreError.invalidDocument("Der Dokumentname ist ungültig.")
            }
            let parentURL = currentFolderPath.isEmpty
                ? store.rootURL
                : try await store.itemURL(for: currentFolderPath)
            let technicalStore = try BirdTechDocumentStore(rootURL: parentURL)
            let registry = try TechnicalModuleRegistry.builtIn()
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "3.1.0"
            let document = BirdTechDocument.blank(
                title: name,
                domain: domain,
                writerVersion: version,
                moduleVersions: registry.versionMap
            )
            let destination = parentURL
                .appendingPathComponent(name)
                .appendingPathExtension(DocumentStore.technicalDiagramExtension)
            _ = try await technicalStore.create(document, at: destination)
            await reload()
            return currentFolderPath.isEmpty
                ? destination.lastPathComponent
                : currentFolderPath + "/" + destination.lastPathComponent
        } catch {
            present(error)
            return nil
        }
    }

    func importPDFs(from urls: [URL]) async {
        do {
            for url in urls {
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess { url.stopAccessingSecurityScopedResource() }
                }
                _ = try await store.importPDF(from: url, in: currentFolderPath)
            }
            await reload()
        } catch {
            present(error)
        }
    }

    func prepareBackupImport(from url: URL) async {
        guard !isPreparingBackup, !isRestoringBackup else { return }
        isPreparingBackup = true
        defer { isPreparingBackup = false }
        var importToCleanUp: PreparedBackupImport?
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                try BackupImportSupport.prepare(url)
            }.value
            importToCleanUp = prepared
            let preview = try await store.inspectLibraryBackup(at: prepared.packageURL)
            cleanupPreparedBackup()
            preparedBackup = prepared
            backupPreview = preview
            importToCleanUp = nil
        } catch {
            if let cleanupURL = importToCleanUp?.cleanupURL {
                try? FileManager.default.removeItem(at: cleanupURL)
            }
            present(error)
        }
    }

    func restorePreparedBackup(conflictPolicy: BackupConflictPolicy) async {
        guard let preparedBackup, !isRestoringBackup else { return }
        isRestoringBackup = true
        defer { isRestoringBackup = false }
        let hasAccess = preparedBackup.packageURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { preparedBackup.packageURL.stopAccessingSecurityScopedResource() }
        }
        do {
            let result = try await store.restoreLibraryBackup(
                from: preparedBackup.packageURL,
                conflictPolicy: conflictPolicy
            )
            let skipped = result.skippedItemNames.isEmpty
                ? ""
                : " \(result.skippedItemNames.count) Konflikte wurden übersprungen."
            noticeMessage = "\(result.restoredPaths.count) Einträge wurden wiederhergestellt.\(skipped)"
            cancelPreparedBackup()
            await reload()
        } catch {
            present(error)
        }
    }

    func cancelPreparedBackup() {
        cleanupPreparedBackup()
        backupPreview = nil
        preparedBackup = nil
    }

    func rename(_ item: LibraryItem, to name: String) async {
        do {
            try await store.renameItem(at: item.relativePath, to: name)
            await reload()
        } catch {
            present(error)
        }
    }

    func duplicate(_ item: LibraryItem) async {
        do {
            try await store.duplicateItem(at: item.relativePath)
            await reload()
        } catch {
            present(error)
        }
    }

    func move(_ item: LibraryItem, to destination: String) async {
        do {
            try await store.moveItem(at: item.relativePath, to: destination)
            await reload()
        } catch {
            present(error)
        }
    }

    func delete(_ item: LibraryItem) async {
        do {
            try await store.deleteItem(at: item.relativePath)
            await reload()
        } catch {
            present(error)
        }
    }

    func restoreLastDeletion() async {
        do {
            _ = try await store.restoreMostRecentlyDeletedItem()
            await reload()
        } catch {
            present(error)
        }
    }

    func restore(_ item: DeletedLibraryItem) async {
        do {
            _ = try await store.restoreDeletedItem(id: item.id)
            await reload()
        } catch {
            present(error)
        }
    }

    func deletePermanently(_ item: DeletedLibraryItem) async {
        do {
            try await store.deletePermanently(id: item.id)
            await reload()
        } catch {
            present(error)
        }
    }

    func emptyTrash() async {
        do {
            try await store.emptyTrash()
            await reload()
        } catch {
            present(error)
        }
    }

    func resolveConflict(
        _ conflict: ExternalDocumentConflict,
        version: ExternalConflictVersion? = nil,
        resolution: ExternalConflictResolution
    ) async {
        do {
            let preservedPath = try await store.resolveExternalConflict(
                at: conflict.documentPath,
                selectedVersionID: version?.id,
                resolution: resolution
            )
            if let preservedPath {
                noticeMessage = "Beide Fassungen wurden erhalten. Die bisherige Version liegt unter \(preservedPath)."
            } else {
                noticeMessage = "Der iCloud-Konflikt wurde aufgelöst."
            }
            await reload()
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    private func cleanupPreparedBackup() {
        if let cleanupURL = preparedBackup?.cleanupURL {
            try? FileManager.default.removeItem(at: cleanupURL)
        }
    }

    private func updateTextSearch(for query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            textSearchHits = []
            return
        }
        do {
            textSearchHits = try await store.searchTranscribedText(trimmed)
        } catch {
            present(error)
        }
    }

    private func items(for paths: [String]) -> [LibraryItem] {
        let lookup = Dictionary(uniqueKeysWithValues: allLibraryItems.map { ($0.relativePath, $0) })
        return paths.compactMap { lookup[$0] }
    }
}
