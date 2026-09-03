import SwiftUI
import UniformTypeIdentifiers
import BirdNotesCore

private typealias StoredLibraryItem = BirdNotesCore.LibraryItem

private extension UTType {
    static let birdNotesBackup = UTType(
        exportedAs: "com.dominikvogel.birdnotes.backup",
        conformingTo: .package
    )
}

private struct DocumentRoute: Hashable {
    let kind: LibraryItemKind
    let path: String
    let pageID: UUID?
}

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var navigationPath = NavigationPath()
    @State private var showsNewFolder = false
    @State private var showsNewStudyWorkspace = false
    @State private var showsNewNotebook = false
    @State private var showsNewCanvas = false
    @State private var showsNewTechnicalDocument = false
    @State private var showsStudyTools = false
    @State private var showsPDFImporter = false
    @State private var showsBackupImporter = false
    @State private var enteredName = ""
    @State private var itemToRename: StoredLibraryItem?
    @State private var itemToDelete: StoredLibraryItem?
    @State private var itemToMove: StoredLibraryItem?
    @State private var itemToTag: StoredLibraryItem?
    @State private var showsTrash = false
    @State private var showsConflictCenter = false
    @State private var confirmsDegreeWorkspaceCreation = false
    @State private var isCreatingBackup = false
    @State private var backupShareItem: ExportShareItem?

    private let storageName: String
    private let usesSharedFolder: Bool
    private let chooseStorage: () -> Void
    private let useLocalStorage: () -> Void

    init(
        store: DocumentStore,
        storageName: String,
        usesSharedFolder: Bool,
        chooseStorage: @escaping () -> Void,
        useLocalStorage: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LibraryViewModel(store: store))
        self.storageName = storageName
        self.usesSharedFolder = usesSharedFolder
        self.chooseStorage = chooseStorage
        self.useLocalStorage = useLocalStorage
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 320)
        } detail: {
            NavigationStack(path: $navigationPath) {
                VStack(spacing: 0) {
                    libraryHeader
                    if viewModel.breadcrumbs.count > 1 {
                        breadcrumbBar
                    }
                    content
                }
                .background(BirdNotesTheme.libraryBackground)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.searchText, prompt: "Notizen und PDFs durchsuchen")
                .toolbar { libraryToolbar }
                .navigationDestination(for: DocumentRoute.self) { route in
                    switch route.kind {
                    case .notebook:
                        NotebookView(
                            store: viewModel.store,
                            relativePath: route.path,
                            initialPageID: route.pageID
                        )
                    case .pdf:
                        PDFDocumentView(store: viewModel.store, relativePath: route.path)
                    case .infiniteCanvas:
                        InfiniteCanvasView(store: viewModel.store, relativePath: route.path)
                    case .technicalDiagram:
                        TechnicalWorkspaceView(store: viewModel.store, relativePath: route.path)
                    case .folder:
                        EmptyView()
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task { await viewModel.reload() }
        .refreshable { await viewModel.reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.reload() }
            }
        }
        .fileImporter(
            isPresented: $showsPDFImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await viewModel.importPDFs(from: urls) }
            } else if case .failure(let error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showsBackupImporter,
            allowedContentTypes: [.birdNotesBackup, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await viewModel.prepareBackupImport(from: url) }
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("Neuer Ordner", isPresented: $showsNewFolder) {
            TextField("Name", text: $enteredName)
            Button("Abbrechen", role: .cancel) { enteredName = "" }
            Button("Erstellen") {
                let name = enteredName
                enteredName = ""
                Task { await viewModel.createFolder(named: name) }
            }
        }
        .alert("Neuer Studienbereich", isPresented: $showsNewStudyWorkspace) {
            TextField("Name, z. B. 1. Semester", text: $enteredName)
            Button("Abbrechen", role: .cancel) { enteredName = "" }
            Button("Erstellen") {
                let name = enteredName
                enteredName = ""
                Task { await viewModel.createStudyWorkspace(named: name) }
            }
        } message: {
            Text("Erstellt Vorlesungsnotizen, Übungen, Literatur und PDFs, Prüfungsvorbereitung sowie eine A4-Cornell-Semesterübersicht.")
        }
        .sheet(isPresented: $showsNewNotebook) {
            NewNotebookSheet { name, style, format in
                Task {
                    _ = await viewModel.createNotebook(
                        named: name,
                        paperStyle: style,
                        paperFormat: format
                    )
                }
            }
        }
        .alert("Neues Endlos-Canvas", isPresented: $showsNewCanvas) {
            TextField("Name", text: $enteredName)
            Button("Abbrechen", role: .cancel) { enteredName = "" }
            Button("Erstellen") {
                let name = enteredName
                enteredName = ""
                Task { _ = await viewModel.createInfiniteCanvas(named: name) }
            }
        } message: {
            Text("Eine große frei zoombare Fläche für Skizzen, Pläne und Mindmaps.")
        }
        .sheet(isPresented: $showsNewTechnicalDocument) {
            NewTechnicalDocumentSheet { name, domain in
                Task {
                    _ = await viewModel.createTechnicalDocument(named: name, domain: domain)
                }
            }
        }
        .sheet(isPresented: $showsStudyTools) {
            StudyToolsView()
                .presentationDetents([.large])
        }
        .alert("Umbenennen", isPresented: renameIsPresented) {
            TextField("Name", text: $enteredName)
            Button("Abbrechen", role: .cancel) { clearRename() }
            Button("Sichern") {
                guard let item = itemToRename else { return }
                let name = enteredName
                clearRename()
                Task { await viewModel.rename(item, to: name) }
            }
        }
        .confirmationDialog(
            "\(itemToDelete?.name ?? "Eintrag") wirklich löschen?",
            isPresented: deleteIsPresented,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                guard let item = itemToDelete else { return }
                itemToDelete = nil
                Task { await viewModel.delete(item) }
            }
            Button("Abbrechen", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("Der Eintrag wird in den geschützten BirdNotes-Papierkorb verschoben und kann wiederhergestellt werden.")
        }
        .sheet(item: $itemToMove) { item in
            MoveDestinationView(store: viewModel.store, item: item) { destination in
                Task { await viewModel.move(item, to: destination) }
            }
        }
        .sheet(item: $itemToTag) { item in
            TagEditorSheet(
                itemName: item.name,
                initialTags: viewModel.tags(for: item)
            ) { tags in
                Task { await viewModel.setTags(tags, for: item) }
            }
        }
        .sheet(isPresented: $showsTrash) {
            TrashView(viewModel: viewModel)
        }
        .sheet(isPresented: $showsConflictCenter) {
            ConflictCenterSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Studienbibliothek anlegen?",
            isPresented: $confirmsDegreeWorkspaceCreation,
            titleVisibility: .visible
        ) {
            Button("Software-Development-Studium anlegen") {
                Task { await viewModel.createSoftwareDevelopmentWorkspace() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("BirdNotes erstellt eine geordnete Bibliothek für alle Pflichtsemester mit Modulordnern, Cornell-Lernnotizen, Active-Recall-Seiten, Übungen, PDFs und Prüfungsvorbereitung.")
        }
        .sheet(isPresented: backupRestoreIsPresented) {
            if let preview = viewModel.backupPreview {
                BackupRestoreSheet(
                    preview: preview,
                    isRestoring: viewModel.isRestoringBackup,
                    onRestore: { policy in
                        Task { await viewModel.restorePreparedBackup(conflictPolicy: policy) }
                    },
                    onCancel: viewModel.cancelPreparedBackup
                )
            }
        }
        .sheet(item: $backupShareItem) { item in
            ExportShareSheet(items: [item.url])
        }
        .alert("Fehler", isPresented: errorIsPresented) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
        .alert("BirdNotes", isPresented: noticeIsPresented) {
            Button("OK") { viewModel.noticeMessage = nil }
        } message: {
            Text(viewModel.noticeMessage ?? "")
        }
    }

    private var sidebar: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image("BirdLogo")
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("BirdNotes")
                            .font(.title3.weight(.bold))
                        Text("Arbeitsbereich")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)

            Section("Arbeitsbereich") {
                sidebarButton(
                    title: "Alle Inhalte",
                    systemImage: "square.grid.2x2",
                    path: ""
                )
                Button {
                    viewModel.showFavorites()
                } label: {
                    sidebarCollectionLabel(
                        title: "Favoriten",
                        systemImage: "star.fill",
                        selected: viewModel.collection == .favorites
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    viewModel.collection == .favorites
                        ? BirdNotesTheme.accent.opacity(0.10)
                        : Color.clear
                )
                Button {
                    viewModel.showRecent()
                } label: {
                    sidebarCollectionLabel(
                        title: "Zuletzt geöffnet",
                        systemImage: "clock.fill",
                        selected: viewModel.collection == .recent
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    viewModel.collection == .recent
                        ? BirdNotesTheme.accent.opacity(0.10)
                        : Color.clear
                )
            }

            Section("Studium") {
                Button {
                    showsStudyTools = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundStyle(BirdNotesTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Studien-Werkzeuge")
                                .foregroundStyle(.primary)
                            Text("Module, Rechner und Checklisten")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                Button {
                    if usesSharedFolder {
                        confirmsDegreeWorkspaceCreation = true
                    } else {
                        chooseStorage()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: usesSharedFolder ? "folder.badge.plus" : "icloud")
                            .foregroundStyle(BirdNotesTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(usesSharedFolder
                                 ? "Studienbibliothek anlegen"
                                 : "Cloud-Ordner verbinden")
                                .foregroundStyle(.primary)
                            Text(usesSharedFolder
                                 ? "Alle Pflichtmodule strukturiert vorbereiten"
                                 : "Vorher iCloud Drive/Documents/Birdnotes wählen")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Bereiche") {
                ForEach(viewModel.rootFolders) { folder in
                    sidebarButton(
                        title: folder.name,
                        systemImage: "folder.fill",
                        path: folder.relativePath
                    )
                }
            }

            if !viewModel.allTags.isEmpty {
                Section("Tags") {
                    ForEach(viewModel.allTags, id: \.self) { tag in
                        Button {
                            viewModel.showTag(tag)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(
                                        viewModel.collection == .tag(tag)
                                            ? BirdNotesTheme.accent
                                            : Color.secondary
                                    )
                                    .frame(width: 24)
                                Text(tag)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            viewModel.collection == .tag(tag)
                                ? BirdNotesTheme.accent.opacity(0.10)
                                : Color.clear
                        )
                    }
                }
            }

            Section("Speicher") {
                Button(action: chooseStorage) {
                    HStack(spacing: 12) {
                        Image(systemName: usesSharedFolder ? "icloud.fill" : "ipad")
                            .foregroundStyle(usesSharedFolder ? BirdNotesTheme.accent : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(storageName)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(usesSharedFolder
                                 ? "Cloud-Bibliothek auf Mac und iPad"
                                 : "Nur auf diesem Gerät")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if usesSharedFolder {
                    Button("Lokalen Speicher verwenden", systemImage: "internaldrive") {
                        useLocalStorage()
                    }
                }

                if viewModel.canRestoreDeletion {
                    Button("Letztes Löschen rückgängig", systemImage: "arrow.uturn.backward.circle") {
                        Task { await viewModel.restoreLastDeletion() }
                    }
                }

                if !viewModel.externalConflicts.isEmpty {
                    Button {
                        showsConflictCenter = true
                    } label: {
                        Label(
                            "iCloud-Konflikte (\(viewModel.externalConflicts.count))",
                            systemImage: "exclamationmark.icloud"
                        )
                    }
                    .tint(.orange)
                }

                Button {
                    showsTrash = true
                } label: {
                    Label(
                        viewModel.deletedItems.isEmpty
                            ? "Papierkorb"
                            : "Papierkorb (\(viewModel.deletedItems.count))",
                        systemImage: "trash"
                    )
                }

                Button {
                    createBackup()
                } label: {
                    if isCreatingBackup {
                        Label("Backup wird erstellt …", systemImage: "externaldrive.badge.timemachine")
                    } else {
                        Label("Bibliothek sichern", systemImage: "externaldrive.badge.plus")
                    }
                }
                .disabled(isCreatingBackup)

                Button {
                    showsBackupImporter = true
                } label: {
                    if viewModel.isPreparingBackup {
                        Label("Backup wird geprüft …", systemImage: "checkmark.shield")
                    } else {
                        Label("Backup wiederherstellen", systemImage: "externaldrive.badge.checkmark")
                    }
                }
                .disabled(viewModel.isPreparingBackup || viewModel.isRestoringBackup)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            BirdNotesTheme.sidebarBackground
        )
    }

    private func sidebarButton(title: String, systemImage: String, path: String) -> some View {
        Button {
            Task { await viewModel.openFolder(path) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(
                        viewModel.collection == .folder && viewModel.currentFolderPath == path
                            ? BirdNotesTheme.accent
                            : Color.secondary
                    )
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            viewModel.collection == .folder && viewModel.currentFolderPath == path
                ? BirdNotesTheme.accent.opacity(0.10)
                : Color.clear
        )
    }

    private func sidebarCollectionLabel(
        title: String,
        systemImage: String,
        selected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(selected ? BirdNotesTheme.accent : Color.secondary)
                .frame(width: 24)
            Text(title).foregroundStyle(.primary)
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var libraryHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.folderTitle)
                    .font(.largeTitle.weight(.bold))
                Text(viewModel.documentCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Studienbereich", systemImage: "graduationcap") {
                    enteredName = ""
                    showsNewStudyWorkspace = true
                }
                Divider()
                Button("Notizbuch", systemImage: "note.text.badge.plus") {
                    enteredName = ""
                    showsNewNotebook = true
                }
                Button("Endlos-Canvas", systemImage: "scribble.variable") {
                    enteredName = ""
                    showsNewCanvas = true
                }
                Button("Technik-Dokument", systemImage: "point.3.connected.trianglepath.dotted") {
                    showsNewTechnicalDocument = true
                }
                Button("Ordner", systemImage: "folder.badge.plus") {
                    enteredName = ""
                    showsNewFolder = true
                }
                Divider()
                Button("PDF importieren", systemImage: "doc.badge.plus") {
                    showsPDFImporter = true
                }
            } label: {
                Label("Neu", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(BirdNotesTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Neues Dokument")
            .accessibilityIdentifier("library.new")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    Button(crumb.title) {
                        Task { await viewModel.openFolder(crumb.path) }
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(index == viewModel.breadcrumbs.count - 1 ? .semibold : .regular))
                    .foregroundStyle(index == viewModel.breadcrumbs.count - 1 ? .primary : BirdNotesTheme.accent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.items.isEmpty {
            ProgressView("Bibliothek wird geladen …")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.visibleItems.isEmpty {
            emptyState
        } else if viewModel.usesGrid {
            grid
        } else {
            list
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(BirdNotesTheme.accent.opacity(0.09))
                Image(systemName: viewModel.searchText.isEmpty ? "books.vertical" : "magnifyingglass")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(BirdNotesTheme.accent)
            }
            .frame(width: 92, height: 92)

            VStack(spacing: 6) {
                Text(viewModel.searchText.isEmpty ? "Platz für neue Ideen" : "Keine Treffer")
                    .font(.title2.weight(.semibold))
                Text(viewModel.searchText.isEmpty
                     ? "Erstelle ein Notizbuch, ein Endlos-Canvas oder lege einen Projektordner an."
                     : "Probiere einen anderen Suchbegriff.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            if viewModel.searchText.isEmpty {
                Button("Notizbuch erstellen", systemImage: "plus") {
                    enteredName = ""
                    showsNewNotebook = true
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("library.empty.createNotebook")
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 178, maximum: 236), spacing: 20)],
                spacing: 22
            ) {
                ForEach(viewModel.visibleItems) { item in
                    itemContainer(item) {
                        LibraryGridItem(
                            item: item,
                            store: viewModel.store,
                            isFavorite: viewModel.isFavorite(item),
                            tags: viewModel.tags(for: item)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.visibleItems) { item in
                    itemContainer(item) {
                        LibraryListItem(
                            item: item,
                            store: viewModel.store,
                            isFavorite: viewModel.isFavorite(item),
                            tags: viewModel.tags(for: item)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func itemContainer<Label: View>(
        _ item: StoredLibraryItem,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Group {
            switch item.kind {
            case .folder:
                Button {
                    Task { await viewModel.openFolder(item.relativePath) }
                } label: { label() }
                .buttonStyle(.plain)
            case .notebook, .pdf, .infiniteCanvas, .technicalDiagram:
                NavigationLink(value: DocumentRoute(
                    kind: item.kind,
                    path: item.relativePath,
                    pageID: viewModel.firstTextSearchHit(for: item)?.pageID
                )) {
                    label()
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    columnVisibility = .detailOnly
                    Task { await viewModel.markOpened(item) }
                })
            }
        }
        .contextMenu { contextMenu(for: item) }
        .accessibilityIdentifier("library.item.\(item.relativePath)")
    }

    @ViewBuilder
    private func contextMenu(for item: StoredLibraryItem) -> some View {
        Button(
            viewModel.isFavorite(item) ? "Aus Favoriten entfernen" : "Zu Favoriten",
            systemImage: viewModel.isFavorite(item) ? "star.slash" : "star"
        ) {
            Task { await viewModel.toggleFavorite(item) }
        }
        Button("Umbenennen", systemImage: "pencil") {
            enteredName = item.name
            itemToRename = item
        }
        Button("Verschieben", systemImage: "folder") { itemToMove = item }
        Button("Tags bearbeiten", systemImage: "tag") { itemToTag = item }
        Button("Duplizieren", systemImage: "plus.square.on.square") {
            Task { await viewModel.duplicate(item) }
        }
        ShareLink(
            item: viewModel.store.rootURL.appendingPathComponent(item.relativePath),
            label: { Label("Teilen", systemImage: "square.and.arrow.up") }
        )
        Divider()
        Button("Löschen", systemImage: "trash", role: .destructive) { itemToDelete = item }
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Aktualisieren", systemImage: "arrow.clockwise") {
                Task { await viewModel.reload() }
            }

            Menu {
                Picker("Sortierung", selection: $viewModel.sort) {
                    Text("Name").tag(LibrarySort.name)
                    Text("Erstellt").tag(LibrarySort.createdAt)
                    Text("Zuletzt bearbeitet").tag(LibrarySort.modifiedAt)
                }
                Divider()
                Button(viewModel.usesGrid ? "Listenansicht" : "Rasteransicht",
                       systemImage: viewModel.usesGrid ? "list.bullet" : "square.grid.2x2") {
                    withAnimation(.snappy) { viewModel.usesGrid.toggle() }
                }
            } label: {
                Label("Ansicht und Sortierung", systemImage: "slider.horizontal.3")
            }
        }
    }

    private var renameIsPresented: Binding<Bool> {
        Binding(get: { itemToRename != nil }, set: { if !$0 { clearRename() } })
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } })
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private var noticeIsPresented: Binding<Bool> {
        Binding(get: { viewModel.noticeMessage != nil }, set: { if !$0 { viewModel.noticeMessage = nil } })
    }

    private var backupRestoreIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.backupPreview != nil },
            set: { if !$0 { viewModel.cancelPreparedBackup() } }
        )
    }

    private func clearRename() {
        itemToRename = nil
        enteredName = ""
    }

    private func createBackup() {
        guard !isCreatingBackup else { return }
        isCreatingBackup = true
        Task {
            defer { isCreatingBackup = false }
            do {
                backupShareItem = ExportShareItem(
                    url: try await ExportSupport.libraryBackup(store: viewModel.store)
                )
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct LibraryGridItem: View {
    let item: StoredLibraryItem
    let store: DocumentStore
    let isFavorite: Bool
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryCover(item: item, store: store)
                .frame(height: 132)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(item.kind.displayName)
                    Text("·")
                    Text(item.modifiedAt, format: .dateTime.day().month().year())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                if !tags.isEmpty {
                    TagCapsules(tags: Array(tags.prefix(2)))
                }
            }
            .padding(14)
        }
        .background(BirdNotesTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 7, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(BirdNotesTheme.accent, in: Circle())
                    .padding(9)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryListItem: View {
    let item: StoredLibraryItem
    let store: DocumentStore
    let isFavorite: Bool
    let tags: [String]

    var body: some View {
        HStack(spacing: 16) {
            LibraryCover(item: item, store: store)
                .frame(width: 74, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("\(item.kind.displayName) · \(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !tags.isEmpty {
                    TagCapsules(tags: Array(tags.prefix(3)))
                }
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(BirdNotesTheme.accent)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(BirdNotesTheme.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct LibraryCover: View {
    let item: StoredLibraryItem
    let store: DocumentStore
    @State private var thumbnail: UIImage?

    private var tint: Color { BirdNotesTheme.color(for: item) }

    var body: some View {
        ZStack {
            if let thumbnail, item.kind != .folder {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                placeholder
            }
        }
        .task(id: ThumbnailRenderID(path: item.relativePath, modifiedAt: item.modifiedAt)) {
            thumbnail = await LibraryThumbnailCache.image(for: item, store: store)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch item.kind {
            case .folder:
                LinearGradient(
                    colors: [tint.opacity(0.24), tint.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "folder.fill")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.16), radius: 8, y: 4)

            case .notebook:
                Color.white
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 9)
                    VStack(spacing: 13) {
                        ForEach(0..<5, id: \.self) { _ in
                            Capsule()
                                .fill(Color.blue.opacity(0.12))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 18)
                    Spacer(minLength: 0)
                }
                Image(systemName: "applepencil")
                    .font(.title2)
                    .foregroundStyle(tint.opacity(0.82))
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            case .pdf:
                LinearGradient(
                    colors: [Color.red.opacity(0.18), Color.orange.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 7) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 42, weight: .light))
                    Text("PDF")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                }
                .foregroundStyle(Color.red.opacity(0.82))

            case .infiniteCanvas:
                LinearGradient(
                    colors: [tint.opacity(0.22), tint.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "scribble.variable")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(tint)

            case .technicalDiagram:
                LinearGradient(
                    colors: [Color.cyan.opacity(0.20), Color.blue.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 44, weight: .light))
                    Text("TECHNIK")
                        .font(.caption2.weight(.bold))
                        .tracking(1.3)
                }
                .foregroundStyle(tint)
        }
    }
}

private struct ThumbnailRenderID: Hashable {
    let path: String
    let modifiedAt: Date
}

private struct TagCapsules: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(BirdNotesTheme.accent)
                    .background(BirdNotesTheme.accent.opacity(0.09), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags: \(tags.joined(separator: ", "))")
    }
}

private struct NewNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var paperStyle: PaperStyle = .lined
    @State private var paperFormat: PaperFormat = .a4

    let onCreate: (String, PaperStyle, PaperFormat) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Notizbuch") {
                    TextField("Name, zum Beispiel Mathematik", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("newNotebook.name")
                }

                Section("Vorlage") {
                    ForEach(PaperStyle.allCases) { style in
                        Button {
                            paperStyle = style
                        } label: {
                            HStack {
                                Label(style.displayName, systemImage: style.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if paperStyle == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BirdNotesTheme.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Picker("Papierformat", selection: $paperFormat) {
                        ForEach(PaperFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Papierformat")
                } footer: {
                    Text("A4 ist der Standard. Neue Folgeseiten übernehmen Vorlage und Format automatisch.")
                }
            }
            .navigationTitle("Neues Notizbuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("newNotebook.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        onCreate(name, paperStyle, paperFormat)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("newNotebook.create")
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    let itemName: String
    let onSave: ([String]) -> Void

    init(itemName: String, initialTags: [String], onSave: @escaping ([String]) -> Void) {
        self.itemName = itemName
        self.onSave = onSave
        _text = State(initialValue: initialTags.joined(separator: ", "))
    }

    private var tags: [String] {
        text.split(separator: ",", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isValid: Bool {
        let unique = Set(tags.map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        })
        return unique.count <= LibraryState.maximumTagsPerItem
            && tags.allSatisfy {
                $0.count <= LibraryState.maximumTagLength
                    && !$0.contains("/")
                    && !$0.contains("\\")
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Zum Beispiel Semester 1, Mathematik, Prüfung", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Tags für „\(itemName)“")
                } footer: {
                    Text("Mehrere Tags mit Kommas trennen. Maximal \(LibraryState.maximumTagsPerItem) Tags mit je \(LibraryState.maximumTagLength) Zeichen.")
                }

                if !tags.isEmpty {
                    Section("Vorschau") {
                        TagCapsules(tags: Array(tags.prefix(LibraryState.maximumTagsPerItem)))
                    }
                }

                if !isValid {
                    Section {
                        Label(
                            "Bitte Anzahl, Länge und Sonderzeichen der Tags prüfen.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Tags bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(tags)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ConflictCenterSheet: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.externalConflicts.isEmpty {
                    ContentUnavailableView(
                        "Keine Konflikte",
                        systemImage: "checkmark.icloud",
                        description: Text("Alle iCloud-Dokumente besitzen eine eindeutige Fassung.")
                    )
                } else {
                    List {
                        Section {
                            Label(
                                "Wähle bewusst, welche Fassung erhalten bleibt. „Beide behalten“ ist am sichersten.",
                                systemImage: "info.circle"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        ForEach(viewModel.externalConflicts) { conflict in
                            Section(conflict.documentName) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Aktuelle Fassung", systemImage: "ipad")
                                        .font(.headline)
                                    Text(conflict.currentModifiedAt, format: .dateTime.day().month().year().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Button("Aktuelle Fassung behalten", systemImage: "checkmark.circle") {
                                    Task {
                                        await viewModel.resolveConflict(
                                            conflict,
                                            resolution: .keepCurrent
                                        )
                                    }
                                }

                                ForEach(conflict.versions) { version in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(version.deviceName ?? "Anderes Gerät")
                                                    .font(.headline)
                                                if let modifiedAt = version.modifiedAt {
                                                    Text(modifiedAt, format: .dateTime.day().month().year().hour().minute())
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Menu("Auswählen", systemImage: "ellipsis.circle") {
                                                Button("Beide behalten", systemImage: "square.on.square") {
                                                    Task {
                                                        await viewModel.resolveConflict(
                                                            conflict,
                                                            version: version,
                                                            resolution: .keepBoth
                                                        )
                                                    }
                                                }
                                                Button("Diese Fassung verwenden", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                                                    Task {
                                                        await viewModel.resolveConflict(
                                                            conflict,
                                                            version: version,
                                                            resolution: .useSelected
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("iCloud-Konflikte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

private struct BackupRestoreSheet: View {
    let preview: LibraryBackupPreview
    let isRestoring: Bool
    let onRestore: (BackupConflictPolicy) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var conflictPolicy: BackupConflictPolicy = .keepBoth

    var body: some View {
        NavigationStack {
            Form {
                Section("Sicherung") {
                    LabeledContent("Erstellt") {
                        Text(preview.createdAt, format: .dateTime.day().month().year().hour().minute())
                    }
                    LabeledContent("Inhalte", value: "\(preview.itemCount)")
                }

                if preview.itemNames.isEmpty {
                    ContentUnavailableView(
                        "Leere Sicherung",
                        systemImage: "archivebox",
                        description: Text("Dieses Backup enthält keine Bibliothekseinträge.")
                    )
                } else {
                    Section("Enthalten") {
                        ForEach(preview.itemNames.prefix(20), id: \.self) { name in
                            Label(name, systemImage: "doc")
                        }
                        if preview.itemNames.count > 20 {
                            Text("und \(preview.itemNames.count - 20) weitere …")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !preview.conflictingItemNames.isEmpty {
                    Section {
                        Picker("Bei Namenskonflikten", selection: $conflictPolicy) {
                            Text("Beide behalten").tag(BackupConflictPolicy.keepBoth)
                            Text("Vorhandene behalten").tag(BackupConflictPolicy.skip)
                            Text("Durch Backup ersetzen").tag(BackupConflictPolicy.replace)
                        }
                        Text("Betroffen: \(preview.conflictingItemNames.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("\(preview.conflictingItemNames.count) Namenskonflikte")
                    } footer: {
                        Text("„Beide behalten“ ist die sicherste Auswahl. Ersetzen bleibt durch das Wiederherstellungsjournal gegen Abbrüche geschützt.")
                    }
                }

                Section {
                    Label(
                        "Pfade, Paketstruktur, Größen, Prüfsummen und symbolische Links wurden vorab geprüft.",
                        systemImage: "checkmark.shield"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Backup wiederherstellen")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isRestoring)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isRestoring)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onRestore(conflictPolicy)
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("Wiederherstellen")
                        }
                    }
                    .disabled(isRestoring || preview.itemNames.isEmpty)
                }
            }
        }
    }
}

private struct TrashView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var itemToDeletePermanently: DeletedLibraryItem?
    @State private var confirmsEmptyTrash = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.deletedItems.isEmpty {
                    ContentUnavailableView(
                        "Papierkorb ist leer",
                        systemImage: "trash",
                        description: Text("Gelöschte Inhalte werden hier bis zu 30 Einträge lang aufbewahrt.")
                    )
                } else {
                    List(viewModel.deletedItems) { item in
                        HStack(spacing: 13) {
                            Image(systemName: item.kind?.systemImage ?? "doc")
                                .foregroundStyle(BirdNotesTheme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.headline)
                                Text("Ursprünglich: \(item.originalRelativePath)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(item.deletedAt, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("Wiederherstellen", systemImage: "arrow.uturn.backward") {
                                Task { await viewModel.restore(item) }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("\(item.name) wiederherstellen")
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Endgültig löschen", systemImage: "trash", role: .destructive) {
                                itemToDeletePermanently = item
                            }
                        }
                    }
                }
            }
            .navigationTitle("Papierkorb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                if !viewModel.deletedItems.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Leeren", role: .destructive) { confirmsEmptyTrash = true }
                    }
                }
            }
        }
        .confirmationDialog(
            "„\(itemToDeletePermanently?.name ?? "Eintrag")“ endgültig löschen?",
            isPresented: Binding(
                get: { itemToDeletePermanently != nil },
                set: { if !$0 { itemToDeletePermanently = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Endgültig löschen", role: .destructive) {
                guard let item = itemToDeletePermanently else { return }
                itemToDeletePermanently = nil
                Task { await viewModel.deletePermanently(item) }
            }
            Button("Abbrechen", role: .cancel) { itemToDeletePermanently = nil }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .confirmationDialog(
            "Papierkorb vollständig leeren?",
            isPresented: $confirmsEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Alle endgültig löschen", role: .destructive) {
                Task { await viewModel.emptyTrash() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle enthaltenen Notizbücher, PDFs und Canvases werden endgültig gelöscht.")
        }
    }
}
