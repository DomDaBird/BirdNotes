import Security
import SwiftUI
import UniformTypeIdentifiers
import BirdNotesCore

enum BirdNotesPerformanceFixture: Equatable {
    case notebookPages(Int)
    case libraryItems(Int)
    case canvasElements(Int)
}

enum BirdNotesRuntime {
    static var isUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--birdnotes-ui-testing")
        #else
        false
        #endif
    }

    static var resetsUITestLibrary: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--birdnotes-ui-reset")
        #else
        false
        #endif
    }

    static var performanceFixture: BirdNotesPerformanceFixture? {
        #if DEBUG
        parsePerformanceFixture(arguments: ProcessInfo.processInfo.arguments)
        #else
        nil
        #endif
    }

    static func parsePerformanceFixture(
        arguments: [String]
    ) -> BirdNotesPerformanceFixture? {
        let configurations: [(prefix: String, limit: Int, fixture: (Int) -> BirdNotesPerformanceFixture)] = [
            ("--birdnotes-performance-pages=", 1_000, BirdNotesPerformanceFixture.notebookPages),
            ("--birdnotes-performance-library-items=", 5_000, BirdNotesPerformanceFixture.libraryItems),
            ("--birdnotes-performance-canvas-elements=", 10_000, BirdNotesPerformanceFixture.canvasElements)
        ]
        for argument in arguments {
            for configuration in configurations where argument.hasPrefix(configuration.prefix) {
                guard let requestedCount = Int(argument.dropFirst(configuration.prefix.count)) else {
                    return nil
                }
                return configuration.fixture(min(max(requestedCount, 1), configuration.limit))
            }
        }
        return nil
    }

    static var usesIsolatedAutomationStorage: Bool {
        isUITesting || performanceFixture != nil
    }
}

@main
struct BirdNotesApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            BirdNotesRootView(appModel: appModel)
                .tint(BirdNotesTheme.accent)
        }
    }
}

private struct BirdNotesRootView: View {
    @ObservedObject var appModel: AppModel
    @AppStorage("hasCompletedBirdNotesCloudSetup")
    private var hasCompletedCloudSetup = false
    @State private var showsFolderPicker = false
    @State private var showsCloudSetup = false

    var body: some View {
        Group {
            if let store = appModel.store {
                LibraryView(
                    store: store,
                    storageName: appModel.storageDisplayName,
                    usesSharedFolder: appModel.usesSharedFolder,
                    chooseStorage: { showsFolderPicker = true },
                    useLocalStorage: appModel.useLocalStorage
                )
                .id(appModel.storageIdentifier)
            } else {
                ContentUnavailableView(
                    "Dokumente nicht verfügbar",
                    systemImage: "exclamationmark.folder",
                    description: Text(appModel.errorMessage ?? "Der Speicher konnte nicht geöffnet werden.")
                )
            }
        }
        .task {
            guard !BirdNotesRuntime.usesIsolatedAutomationStorage,
                  !appModel.usesSharedFolder,
                  !hasCompletedCloudSetup else { return }
            showsCloudSetup = true
        }
        .sheet(isPresented: $showsCloudSetup) {
            CloudLibrarySetupView(
                connectCloudFolder: {
                    showsCloudSetup = false
                    Task { @MainActor in
                        await Task.yield()
                        showsFolderPicker = true
                    }
                },
                continueLocally: {
                    hasCompletedCloudSetup = true
                    showsCloudSetup = false
                }
            )
            .interactiveDismissDisabled()
        }
        .fileImporter(
            isPresented: $showsFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                appModel.useSharedFolder(url)
                hasCompletedCloudSetup = appModel.usesSharedFolder
            case .failure(let error):
                appModel.errorMessage = error.localizedDescription
            }
        }
        .fileDialogConfirmationLabel("Als BirdNotes-Ordner verwenden")
        .fileDialogMessage("Wähle einen Ordner in iCloud Drive, auf diesem iPad oder bei einem anderen Dateien-Anbieter.")
        .alert("Speicherort konnte nicht geöffnet werden", isPresented: Binding(
            get: { appModel.errorMessage != nil && appModel.store != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            if appModel.needsSharedFolderRecovery {
                Button("Ordner erneut wählen") {
                    appModel.errorMessage = nil
                    showsFolderPicker = true
                }
                Button("Lokalen Speicher behalten") {
                    appModel.errorMessage = nil
                    appModel.useLocalStorage()
                }
            } else {
                Button("OK") { appModel.errorMessage = nil }
            }
        } message: {
            Text(appModel.errorMessage ?? "Unbekannter Fehler")
        }
    }
}

private struct CloudLibrarySetupView: View {
    let connectCloudFolder: () -> Void
    let continueLocally: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(BirdNotesTheme.accent)
                    VStack(spacing: 8) {
                        Text("Zentrale Studienbibliothek")
                            .font(.largeTitle.bold())
                        Text("Verbinde einmalig einen Ordner aus der Dateien-App. Danach speichert BirdNotes Notizbücher, PDFs und Canvas-Dokumente direkt dort.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        setupStep(1, "In der Dateien-App einen Speicheranbieter öffnen.")
                        setupStep(2, "Einen vorhandenen Ordner wählen oder „BirdNotes“ anlegen.")
                        setupStep(3, "Mit „Öffnen“ als Bibliothek verbinden.")
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    Label(
                        "Der Zugriff bleibt auf den ausgewählten Ordner begrenzt.",
                        systemImage: "lock.shield"
                    )
                    .font(.subheadline)
                    Button("Cloud-Ordner verbinden", systemImage: "folder.badge.plus") {
                        connectCloudFolder()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button("Vorerst nur auf diesem iPad", action: continueLocally)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Speicher einrichten")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func setupStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(BirdNotesTheme.accent, in: Circle())
            Text(text)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var store: DocumentStore?
    @Published private(set) var storageDisplayName = "Auf diesem iPad"
    @Published private(set) var usesSharedFolder = false
    @Published private(set) var needsSharedFolderRecovery = false
    @Published var errorMessage: String?

    private let bookmarkKey = "BirdNotes.sharedLibraryBookmark"
    private let bookmarkStore = SecureBookmarkStore(account: "shared-library-bookmark")
    private let migrationMarkerName = ".birdnotes-local-library-imported"
    private let migrationJournalName = ".birdnotes-local-library-import.json"
    private var scopedURL: URL?
    private var hasActiveSecurityScope = false

    var storageIdentifier: String {
        store?.rootURL.standardizedFileURL.path ?? "unavailable"
    }

    init() {
        if BirdNotesRuntime.isUITesting {
            openUITestStorage(reset: BirdNotesRuntime.resetsUITestLibrary)
            return
        }
        if let fixture = BirdNotesRuntime.performanceFixture {
            Task { await openPerformanceFixture(fixture) }
            return
        }
        migrateLegacyBookmarkIfNeeded()
        if !restoreSharedFolder() {
            openLocalStorage()
        }
    }

    deinit {
        if hasActiveSecurityScope {
            scopedURL?.stopAccessingSecurityScopedResource()
        }
    }

    func useSharedFolder(_ selectedURL: URL) {
        let gainedAccess = selectedURL.startAccessingSecurityScopedResource()
        guard gainedAccess else {
            errorMessage = "BirdNotes hat keinen Zugriff auf diesen Ordner. Bitte wähle ihn erneut in der Dateien-App aus."
            return
        }

        do {
            let bookmark = try selectedURL.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            try copyLocalLibraryIfNeeded(to: selectedURL)
            let newStore = try DocumentStore(rootURL: selectedURL)

            releaseSecurityScope()
            scopedURL = selectedURL
            hasActiveSecurityScope = true
            try bookmarkStore.save(bookmark)
            store = newStore
            storageDisplayName = sharedLocationName(for: selectedURL)
            usesSharedFolder = true
            needsSharedFolderRecovery = false
            errorMessage = nil
        } catch {
            selectedURL.stopAccessingSecurityScopedResource()
            errorMessage = error.localizedDescription
        }
    }

    func useLocalStorage() {
        try? bookmarkStore.remove()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        releaseSecurityScope()
        needsSharedFolderRecovery = false
        openLocalStorage()
    }

    private func restoreSharedFolder() -> Bool {
        do {
            guard let bookmark = try bookmarkStore.load() else { return false }
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }

            scopedURL = url
            hasActiveSecurityScope = true
            store = try DocumentStore(rootURL: url)
            storageDisplayName = sharedLocationName(for: url)
            usesSharedFolder = true
            needsSharedFolderRecovery = false

            if isStale {
                let refreshed = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                try bookmarkStore.save(refreshed)
            }
            return true
        } catch {
            releaseSecurityScope()
            needsSharedFolderRecovery = true
            errorMessage = "Der freigegebene BirdNotes-Ordner muss erneut ausgewählt werden. Bis dahin wird der lokale Speicher verwendet."
            return false
        }
    }

    private func openLocalStorage() {
        do {
            let rootURL = try DocumentStore.defaultRootURL()
            store = try DocumentStore(rootURL: rootURL)
            storageDisplayName = "Auf diesem iPad"
            usesSharedFolder = false
        } catch {
            store = nil
            errorMessage = error.localizedDescription
        }
    }

    private func openUITestStorage(reset: Bool) {
        do {
            guard let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            let rootURL = applicationSupportURL.appendingPathComponent(
                "BirdNotesUITests",
                isDirectory: true
            )
            let standardizedRoot = rootURL.standardizedFileURL
            let standardizedParent = standardizedRoot.deletingLastPathComponent()

            // UI-Tests dürfen ausschließlich ihren expliziten Testordner leeren.
            guard standardizedRoot.lastPathComponent == "BirdNotesUITests",
                  standardizedParent == applicationSupportURL.standardizedFileURL else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            if reset, FileManager.default.fileExists(atPath: standardizedRoot.path) {
                try FileManager.default.removeItem(at: standardizedRoot)
            }

            store = try DocumentStore(rootURL: standardizedRoot)
            storageDisplayName = "Isolierte UI-Testbibliothek"
            usesSharedFolder = false
            errorMessage = nil
        } catch {
            store = nil
            errorMessage = "Die isolierte UI-Testbibliothek konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    private func openPerformanceFixture(_ fixture: BirdNotesPerformanceFixture) async {
        do {
            guard let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            let rootURL = applicationSupportURL.appendingPathComponent(
                "BirdNotesPerformanceFixture",
                isDirectory: true
            )
            let standardizedRoot = rootURL.standardizedFileURL
            guard standardizedRoot.lastPathComponent == "BirdNotesPerformanceFixture",
                  standardizedRoot.deletingLastPathComponent()
                    == applicationSupportURL.standardizedFileURL else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            if FileManager.default.fileExists(atPath: standardizedRoot.path) {
                try FileManager.default.removeItem(at: standardizedRoot)
            }

            let fixtureStore = try DocumentStore(rootURL: standardizedRoot)
            switch fixture {
            case .notebookPages(let pageCount):
                try await prepareNotebookPerformanceFixture(
                    pageCount: pageCount,
                    store: fixtureStore
                )
            case .libraryItems(let itemCount):
                try await prepareLibraryPerformanceFixture(
                    itemCount: itemCount,
                    store: fixtureStore
                )
            case .canvasElements(let elementCount):
                try await prepareCanvasPerformanceFixture(
                    elementCount: elementCount,
                    store: fixtureStore
                )
            }

            store = fixtureStore
            storageDisplayName = "Isolierte Performance-Bibliothek"
            usesSharedFolder = false
            needsSharedFolderRecovery = false
            errorMessage = nil
        } catch {
            store = nil
            errorMessage = "Die Performance-Bibliothek konnte nicht vorbereitet werden: \(error.localizedDescription)"
        }
    }

    private func prepareNotebookPerformanceFixture(
        pageCount: Int,
        store: DocumentStore
    ) async throws {
        let notebookPath = try await store.createNotebook(
            named: "Performance \(pageCount) Seiten",
            paperStyle: .grid,
            paperFormat: .a4
        )
        guard pageCount > 1 else { return }
        for _ in 1..<pageCount {
            _ = try await store.addPage(
                toNotebookAt: notebookPath,
                paperStyle: .grid,
                paperFormat: .a4
            )
        }
    }

    private func prepareLibraryPerformanceFixture(
        itemCount: Int,
        store: DocumentStore
    ) async throws {
        for index in 1...itemCount {
            _ = try await store.createFolder(
                named: String(format: "Lasttest %04d", index)
            )
        }
    }

    private func prepareCanvasPerformanceFixture(
        elementCount: Int,
        store: DocumentStore
    ) async throws {
        let path = try await store.createInfiniteCanvas(
            named: "Performance \(elementCount) Objekte"
        )
        let connectorCount = elementCount >= 10 ? elementCount / 10 : 0
        let nodeCount = elementCount - connectorCount
        let columns = max(Int(ceil(sqrt(Double(max(nodeCount, 1))))), 1)
        let center = CanvasPoint(x: 8_192, y: 8_192)
        var nodes: [CanvasElement] = []
        nodes.reserveCapacity(nodeCount)

        for index in 0..<nodeCount {
            let column = index % columns
            let row = index / columns
            nodes.append(CanvasElement(
                kind: .shape,
                center: CanvasPoint(
                    x: center.x + Double(column - columns / 2) * 190,
                    y: center.y + Double(row - columns / 2) * 150
                ),
                size: CanvasSize(width: 130, height: 90),
                shapeKind: index.isMultiple(of: 2) ? .roundedRectangle : .ellipse,
                strokeColor: index.isMultiple(of: 3) ? .accent : .ink,
                fillColor: CanvasColor(red: 0.92, green: 0.96, blue: 1),
                strokeWidth: 3
            ))
        }

        var elements = nodes
        elements.reserveCapacity(elementCount)
        if nodeCount > 1 {
            for index in 0..<connectorCount {
                let source = nodes[(index * 7) % nodeCount]
                let target = nodes[((index * 7) + 1) % nodeCount]
                elements.append(CanvasElement(
                    kind: .connector,
                    center: center,
                    size: CanvasSize(width: 1, height: 1),
                    strokeColor: .accent,
                    strokeWidth: 2,
                    sourceElementID: source.id,
                    targetElementID: target.id
                ))
            }
        }

        try await store.saveInfiniteCanvas(
            drawingData: Data(),
            elements: elements,
            viewport: CanvasViewport(center: center, zoomScale: 1),
            at: path
        )
    }

    private func migrateLegacyBookmarkIfNeeded() {
        guard let legacyBookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            if try bookmarkStore.load() == nil {
                try bookmarkStore.save(legacyBookmark)
            }
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        } catch {
            // Keep the legacy value for one more launch if the Keychain is
            // temporarily unavailable. No user document data is affected.
        }
    }

    private func copyLocalLibraryIfNeeded(to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let markerURL = destinationURL.appendingPathComponent(migrationMarkerName)
        let journalURL = destinationURL.appendingPathComponent(migrationJournalName)
        guard !fileManager.fileExists(atPath: markerURL.path) else {
            try? fileManager.removeItem(at: journalURL)
            return
        }

        let localURL = try DocumentStore.defaultRootURL()
        try fileManager.createDirectory(at: localURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let localItems = try fileManager.contentsOfDirectory(
            at: localURL,
            includingPropertiesForKeys: [.isHiddenKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter {
            let values = try? $0.resourceValues(forKeys: [.isHiddenKey, .isSymbolicLinkKey])
            return values?.isHidden != true && values?.isSymbolicLink != true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var journal = try loadMigrationJournal(at: journalURL)

        for sourceURL in localItems {
            let sourceName = sourceURL.lastPathComponent
            let entry: LibraryMigrationEntry
            if let existingEntry = journal.entries[sourceName],
               isSafeMigrationEntry(existingEntry) {
                entry = existingEntry
            } else {
                var targetURL = destinationURL.appendingPathComponent(sourceName)
                if fileManager.fileExists(atPath: targetURL.path) {
                    targetURL = uniqueLocalCopyURL(for: sourceURL, in: destinationURL)
                }
                entry = LibraryMigrationEntry(
                    targetName: targetURL.lastPathComponent,
                    stagingName: ".\(UUID().uuidString).local-import"
                )
                journal.entries[sourceName] = entry
                try saveMigrationJournal(journal, at: journalURL)
            }

            let targetURL = destinationURL.appendingPathComponent(entry.targetName)
            if fileManager.fileExists(atPath: targetURL.path) {
                let values = try targetURL.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else {
                    throw CocoaError(.fileWriteInvalidFileName)
                }
                continue
            }
            let stagingURL = destinationURL.appendingPathComponent(entry.stagingName)
            if fileManager.fileExists(atPath: stagingURL.path) {
                try fileManager.removeItem(at: stagingURL)
            }
            do {
                try fileManager.copyItem(at: sourceURL, to: stagingURL)
                try fileManager.moveItem(at: stagingURL, to: targetURL)
            } catch {
                try? fileManager.removeItem(at: stagingURL)
                throw error
            }
        }

        try Data("Imported local BirdNotes library".utf8).write(to: markerURL, options: .atomic)
        try? fileManager.removeItem(at: journalURL)
    }

    private func loadMigrationJournal(at url: URL) throws -> LibraryMigrationJournal {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LibraryMigrationJournal()
        }
        do {
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ])
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  (values.fileSize ?? 0) <= 2 * 1_024 * 1_024 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= 2 * 1_024 * 1_024 else { throw CocoaError(.fileReadCorruptFile) }
            return try JSONDecoder().decode(LibraryMigrationJournal.self, from: data)
        } catch {
            let quarantine = url.deletingLastPathComponent().appendingPathComponent(
                ".birdnotes-local-library-import-damaged-\(UUID().uuidString).json"
            )
            try? FileManager.default.moveItem(at: url, to: quarantine)
            return LibraryMigrationJournal()
        }
    }

    private func saveMigrationJournal(_ journal: LibraryMigrationJournal, at url: URL) throws {
        try JSONEncoder().encode(journal).write(to: url, options: .atomic)
    }

    private func isSafeMigrationEntry(_ entry: LibraryMigrationEntry) -> Bool {
        let suffix = ".local-import"
        let identifier = entry.stagingName.dropFirst().dropLast(suffix.count)
        return !entry.targetName.isEmpty
            && entry.targetName != "."
            && entry.targetName != ".."
            && !entry.targetName.hasPrefix(".")
            && !entry.targetName.contains("/")
            && !entry.targetName.contains("\0")
            && entry.stagingName.hasPrefix(".")
            && entry.stagingName.hasSuffix(suffix)
            && UUID(uuidString: String(identifier)) != nil
    }

    private func uniqueLocalCopyURL(for sourceURL: URL, in directoryURL: URL) -> URL {
        let fileManager = FileManager.default
        let pathExtension = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var index = 1

        while true {
            let suffix = index == 1 ? " (lokal)" : " (lokal \(index))"
            var candidate = directoryURL.appendingPathComponent(baseName + suffix)
            if !pathExtension.isEmpty { candidate.appendPathExtension(pathExtension) }
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private func sharedLocationName(for url: URL) -> String {
        url.lastPathComponent.isEmpty ? "Geteilter BirdNotes-Ordner" : url.lastPathComponent
    }

    private func releaseSecurityScope() {
        if hasActiveSecurityScope {
            scopedURL?.stopAccessingSecurityScopedResource()
        }
        scopedURL = nil
        hasActiveSecurityScope = false
    }
}

private struct LibraryMigrationEntry: Codable {
    let targetName: String
    let stagingName: String
}

private struct LibraryMigrationJournal: Codable {
    var entries: [String: LibraryMigrationEntry] = [:]
}

private struct SecureBookmarkStore {
    let account: String

    private var service: String {
        Bundle.main.bundleIdentifier.map { $0 + ".secure-bookmarks" }
            ?? "BirdNotes.secure-bookmarks"
    }

    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw keychainError(status)
        }
        return data
    }

    func save(_ data: Data) throws {
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw keychainError(updateStatus) }

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw keychainError(addStatus) }
    }

    func remove() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(_ status: OSStatus) -> Error {
        NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [
                NSLocalizedDescriptionKey:
                    SecCopyErrorMessageString(status, nil) as String?
                    ?? "Der sichere Schlüsselbund ist nicht verfügbar."
            ]
        )
    }
}
