import PencilKit
import SwiftUI
import BirdNotesCore

struct NotebookView: View {
    @StateObject private var viewModel: NotebookViewModel
    @StateObject private var toolController = DrawingToolController()
    @StateObject private var canvasProxy = CanvasProxy()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasDismissedPencilNavigationHint") private var hasDismissedPencilHint = false
    @AppStorage("notebookAutomaticallyFitsOnRotation")
    private var automaticallyFitsOnRotation = true
    @State private var showsPageOverview = false
    @State private var confirmsPageDeletion = false
    @State private var exportShareItem: ExportShareItem?
    @State private var showsTranscriptionEditor = false
    @State private var transcriptionDraft = ""
    @State private var pageNavigationRequestID: UUID?

    init(store: DocumentStore, relativePath: String, initialPageID: UUID? = nil) {
        _viewModel = StateObject(
            wrappedValue: NotebookViewModel(
                store: store,
                relativePath: relativePath,
                initialPageID: initialPageID
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.document == nil {
                ProgressView("Notizbuch wird geladen …")
            } else if let page = viewModel.currentPage {
                VStack(spacing: 0) {
                    if !hasDismissedPencilHint {
                        PencilNavigationHint {
                            withAnimation { hasDismissedPencilHint = true }
                        }
                    }
                    ZStack(alignment: .top) {
                        Color(uiColor: UIColor(white: 0.94, alpha: 1))
                            .ignoresSafeArea()
                        ContinuousNotebookCanvas(
                            pages: viewModel.pages,
                            selectedPageID: viewModel.selectedPageID,
                            pageNavigationRequestID: pageNavigationRequestID,
                            automaticallyFitsToWidth: automaticallyFitsOnRotation,
                            toolController: toolController,
                            canvasProxy: canvasProxy,
                            onPageSelected: viewModel.selectPage,
                            onDrawingChanged: { pageID, drawing in
                                viewModel.drawingChanged(drawing, for: pageID)
                            }
                        )
                        DrawingToolBar(
                            toolController: toolController,
                            canvasProxy: canvasProxy
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        if page.metadata.transcribedText?.isEmpty == false {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button {
                                        openTranscriptionEditor()
                                    } label: {
                                        Label("Druckschrift", systemImage: "text.viewfinder")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 13)
                                            .padding(.vertical, 9)
                                            .background(.ultraThinMaterial, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(BirdNotesTheme.accent)
                                }
                            }
                            .padding(18)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color(uiColor: UIColor(white: 0.94, alpha: 1)))
            } else {
                ContentUnavailableView(
                    "Keine Seite",
                    systemImage: "doc",
                    description: Text("Füge eine neue Seite hinzu.")
                )
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SaveStatusIndicator(
                    isSaving: viewModel.isSaving,
                    hasUnsavedChanges: viewModel.hasUnsavedChanges,
                    lastSavedAt: viewModel.lastSavedAt
                )
                .accessibilityIdentifier("notebook.saveStatus")
                Button {
                    showsPageOverview = true
                } label: {
                    Label("Seitenübersicht", systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("notebook.pageOverview")
                .accessibilityValue(viewModel.pagePositionText)
                Button {
                    Task { await viewModel.addPage() }
                } label: {
                    Label("Neue Seite", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .accessibilityIdentifier("notebook.addPage")
                orientationButton
                exportMenu
                pageMenu
            }
        }
        .task { await viewModel.load() }
        .onDisappear {
            Task { await viewModel.flushAutosaves() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                Task { await viewModel.flushAutosaves() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )) { _ in
            Task { await viewModel.flushAutosaves() }
        }
        .sheet(isPresented: $showsPageOverview) {
            PagesOverviewView(viewModel: viewModel) { pageID in
                viewModel.selectPage(pageID)
                pageNavigationRequestID = UUID()
            }
        }
        .sheet(item: $exportShareItem) { item in
            ExportShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showsTranscriptionEditor) {
            TranscriptionEditorSheet(
                text: $transcriptionDraft,
                onSave: { text in
                    Task { await viewModel.saveTranscription(text) }
                },
                onDelete: {
                    Task { await viewModel.saveTranscription(nil) }
                }
            )
        }
        .confirmationDialog(
            "Aktuelle Seite löschen?",
            isPresented: $confirmsPageDeletion,
            titleVisibility: .visible
        ) {
            Button("Seite löschen", role: .destructive) {
                Task { await viewModel.deleteCurrentPage() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Seite und ihre Zeichnung werden dauerhaft entfernt.")
        }
        .alert("Fehler", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            if viewModel.hasUnsavedChanges {
                Button("Speichern erneut versuchen") {
                    viewModel.errorMessage = nil
                    Task { await viewModel.flushAutosaves() }
                }
            }
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
    }

    private var pageMenu: some View {
        Menu {
            Section("Papier") {
                ForEach(PaperStyle.allCases) { style in
                    Button {
                        Task { await viewModel.setPaperStyle(style) }
                    } label: {
                        Label(style.displayName, systemImage: style.systemImage)
                    }
                }
            }
            Section("Format") {
                ForEach(PaperFormat.allCases) { format in
                    Button {
                        Task { await viewModel.setPaperFormat(format) }
                    } label: {
                        Label(
                            format.displayName,
                            systemImage: viewModel.currentPage?.metadata.paperFormat == format
                                ? "checkmark"
                                : "rectangle.portrait"
                        )
                    }
                }
            }
            Section("Ausrichtung") {
                ForEach(PaperOrientation.allCases) { orientation in
                    Button {
                        Task { await viewModel.setPaperOrientation(orientation) }
                    } label: {
                        Label(
                            orientation.displayName,
                            systemImage: viewModel.currentPage?.metadata.paperOrientation == orientation
                                ? "checkmark"
                                : orientation.systemImage
                        )
                    }
                }
                Button {
                    automaticallyFitsOnRotation.toggle()
                } label: {
                    Label(
                        automaticallyFitsOnRotation
                            ? "Automatisch anpassen: Ein"
                            : "Automatisch anpassen: Aus",
                        systemImage: automaticallyFitsOnRotation
                            ? "arrow.left.and.right.circle.fill"
                            : "arrow.left.and.right.circle"
                    )
                }
            }
            Divider()
            Button(
                viewModel.currentPage?.metadata.transcribedText == nil
                    ? "Handschrift in Druckschrift"
                    : "Handschrift erneut erkennen",
                systemImage: "text.viewfinder"
            ) {
                recognizeHandwriting()
            }
            .disabled(
                viewModel.isRecognizingHandwriting
                    || viewModel.currentDrawing.strokes.isEmpty
            )
            if viewModel.currentPage?.metadata.transcribedText != nil {
                Button("Druckschrift bearbeiten", systemImage: "character.cursor.ibeam") {
                    openTranscriptionEditor()
                }
            }
            Divider()
            Button(
                viewModel.currentPage?.metadata.isBookmarked == true
                    ? "Markierung entfernen"
                    : "Als wichtig markieren",
                systemImage: viewModel.currentPage?.metadata.isBookmarked == true
                    ? "bookmark.slash"
                    : "bookmark"
            ) {
                Task { await viewModel.toggleCurrentPageBookmark() }
            }
            .keyboardShortcut("b", modifiers: .command)
            Button("Seite duplizieren", systemImage: "plus.square.on.square") {
                Task { await viewModel.duplicateCurrentPage() }
            }
            Button("Seite löschen", systemImage: "trash", role: .destructive) {
                confirmsPageDeletion = true
            }
            .disabled(viewModel.pages.count <= 1)
        } label: {
            Label("Seitenaktionen", systemImage: "ellipsis.circle")
        }
    }

    private var orientationButton: some View {
        Button {
            Task { await viewModel.togglePaperOrientation() }
        } label: {
            let orientation = viewModel.currentPage?.metadata.paperOrientation ?? .portrait
            Label(
                orientation == .portrait ? "Auf Querformat wechseln" : "Auf Hochformat wechseln",
                systemImage: orientation == .portrait ? "rectangle" : "rectangle.portrait"
            )
        }
        .accessibilityHint("Ändert das Papierformat der aktuellen Seite, nicht die Geräteausrichtung.")
        .accessibilityIdentifier("notebook.toggleOrientation")
    }

    private var exportMenu: some View {
        Menu {
            Button("Notizbuch als PDF", systemImage: "doc.richtext") {
                exportNotebookPDF()
            }
            Button("Aktuelle Seite als PDF", systemImage: "doc") {
                exportCurrentPage(asPNG: false)
            }
            Button("Aktuelle Seite als PNG", systemImage: "photo") {
                exportCurrentPage(asPNG: true)
            }
        } label: {
            Label("Exportieren", systemImage: "square.and.arrow.up")
        }
    }

    private func exportNotebookPDF() {
        Task {
            await viewModel.flushAutosaves()
            do {
                exportShareItem = ExportShareItem(url: try ExportSupport.notebookPDF(
                    pages: viewModel.pages,
                    title: viewModel.title
                ))
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func exportCurrentPage(asPNG: Bool) {
        Task {
            await viewModel.flushAutosaves()
            guard let page = viewModel.currentPage,
                  let index = viewModel.pages.firstIndex(where: { $0.id == page.id }) else { return }
            do {
                let url: URL
                if asPNG {
                    url = try ExportSupport.notebookPagePNG(
                        page,
                        title: viewModel.title,
                        pageNumber: index + 1
                    )
                } else {
                    url = try ExportSupport.notebookPDF(
                        pages: [page],
                        title: viewModel.title,
                        fileSuffix: "Seite-\(index + 1)"
                    )
                }
                exportShareItem = ExportShareItem(url: url)
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func recognizeHandwriting() {
        Task {
            if let text = await viewModel.recognizeCurrentPage() {
                transcriptionDraft = text
                showsTranscriptionEditor = true
            }
        }
    }

    private func openTranscriptionEditor() {
        transcriptionDraft = viewModel.currentPage?.metadata.transcribedText ?? ""
        showsTranscriptionEditor = true
    }
}

private struct TranscriptionEditorSheet: View {
    @Binding var text: String
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeletion = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    "Lokal aus der Handschrift erkannt. Die ursprüngliche Zeichnung bleibt unverändert.",
                    systemImage: "hand.raised"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .accessibilityLabel("Erkannte Druckschrift")

                HStack {
                    Button("Kopieren", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = text
                    }
                    .buttonStyle(.bordered)
                    ShareLink(item: text) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if !text.isEmpty {
                        Text("\(text.count) Zeichen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Druckschrift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Entfernen", role: .destructive) { confirmsDeletion = true }
                    Button("Sichern") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .confirmationDialog(
            "Gespeicherte Druckschrift entfernen?",
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button("Druckschrift entfernen", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die handschriftliche Zeichnung bleibt erhalten.")
        }
    }
}

private struct SaveStatusIndicator: View {
    let isSaving: Bool
    let hasUnsavedChanges: Bool
    let lastSavedAt: Date?

    var body: some View {
        Group {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Notizbuch wird gesichert")
            } else if hasUnsavedChanges {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Nicht gespeicherte Änderungen")
            } else if let lastSavedAt {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "Gesichert um \(lastSavedAt.formatted(date: .omitted, time: .shortened))"
                    )
            }
        }
    }
}

private struct PencilNavigationHint: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "applepencil.and.scribble")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Standardmäßig schreibt nur der Apple Pencil. Mit einem Finger scrollst du, mit zwei Fingern zoomst du. Fingerzeichnen lässt sich in der Werkzeugleiste einschalten.")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hinweis schließen")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(BirdNotesTheme.accent.opacity(0.08))
    }
}

struct DrawingToolBar: View {
    @ObservedObject var toolController: DrawingToolController
    @ObservedObject var canvasProxy: CanvasProxy
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var supportsObjects = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(availableTools) { tool in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            toolController.select(tool)
                        }
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                            .labelStyle(.iconOnly)
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: controlLength, height: controlLength)
                            .background(
                                toolController.selectedTool == tool
                                    ? BirdNotesTheme.accent.opacity(0.16)
                                    : Color.clear,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(toolController.selectedTool == tool ? BirdNotesTheme.accent : Color.black)
                    .accessibilityLabel(tool.title)
                    .accessibilityAddTraits(toolController.selectedTool == tool ? .isSelected : [])
                }

                Divider().frame(height: 26)

                if toolController.selectedTool == .pen || toolController.selectedTool == .marker {
                    if toolController.selectedTool == .pen {
                        inkMenu
                    }

                    ForEach(Array(displayedColors.enumerated()), id: \.offset) { _, color in
                        Button {
                            applyPresetColor(color)
                        } label: {
                            Circle()
                                .fill(Color(uiColor: color))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Circle()
                                        .stroke(Color.black.opacity(0.16), lineWidth: 1)
                                }
                                .frame(width: colorControlLength, height: controlLength)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Schnellfarbe")
                    }

                    ColorPicker("Weitere Farbe", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: colorControlLength, height: controlLength)
                        .accessibilityLabel("Weitere Werkzeugfarbe")
                    widthMenu
                } else if toolController.selectedTool == .eraser {
                    eraserMenu
                }

                Divider().frame(height: 26)

                Button {
                    canvasProxy.undo()
                } label: {
                    Label("Widerrufen", systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                        .frame(width: controlLength, height: controlLength)
                }
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("Widerrufen")
                .disabled(!canvasProxy.canUndo)

                Button {
                    canvasProxy.redo()
                } label: {
                    Label("Wiederholen", systemImage: "arrow.uturn.forward")
                        .labelStyle(.iconOnly)
                        .frame(width: controlLength, height: controlLength)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityLabel("Wiederholen")
                .disabled(!canvasProxy.canRedo)

                Toggle(isOn: $toolController.fingerDraws) {
                    Label("Finger zeichnet", systemImage: "hand.point.up.left")
                        .labelStyle(.iconOnly)
                        .frame(width: controlLength, height: controlLength)
                }
                .toggleStyle(.button)
                .tint(BirdNotesTheme.accent)
                .help("Ein: Pencil und Finger zeichnen. Aus: Nur der Apple Pencil zeichnet.")
                .accessibilityLabel("Mit dem Finger zeichnen")
                .accessibilityValue(toolController.fingerDraws ? "Ein" : "Aus")
                .accessibilityHint(
                    toolController.fingerDraws
                        ? "Finger und Apple Pencil können zeichnen. Zum Scrollen zwei Finger verwenden."
                        : "Nur der Apple Pencil zeichnet. Ein Finger scrollt."
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(Color.black)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white.opacity(0.98), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zeichenwerkzeuge")
    }

    private var colorBinding: Binding<Color> {
        Binding {
            Color(uiColor: toolController.selectedTool == .marker
                ? toolController.markerColor
                : toolController.penColor)
        } set: { color in
            toolController.applyColor(UIColor(color))
        }
    }

    private var inkMenu: some View {
        Menu {
            Picker("Stiftprofil", selection: $toolController.inkPreset) {
                ForEach(InkPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
        } label: {
            Label("Stiftprofil", systemImage: "pencil.tip.crop.circle")
                .labelStyle(.iconOnly)
                .frame(width: controlLength, height: controlLength)
        }
        .accessibilityLabel("Stiftprofil")
    }

    private var eraserMenu: some View {
        Menu {
            Picker("Radierer", selection: $toolController.eraserMode) {
                ForEach(EraserMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            if toolController.eraserMode == .fixedWidth {
                Picker("Breite", selection: $toolController.eraserWidth) {
                    Text("Schmal").tag(CGFloat(14))
                    Text("Mittel").tag(CGFloat(28))
                    Text("Breit").tag(CGFloat(48))
                }
            }
        } label: {
            Label("Radierer-Modus", systemImage: "eraser.line.dashed")
                .labelStyle(.iconOnly)
                .frame(width: controlLength, height: controlLength)
        }
        .accessibilityLabel("Radierer-Modus")
    }

    private var widthMenu: some View {
        Menu {
            if toolController.selectedTool == .marker {
                Picker("Markerbreite", selection: $toolController.markerWidth) {
                    Text("Sehr schmal").tag(CGFloat(8))
                    Text("Schmal").tag(CGFloat(12))
                    Text("Mittel").tag(CGFloat(18))
                    Text("Breit").tag(CGFloat(26))
                    Text("Sehr breit").tag(CGFloat(36))
                }
            } else {
                Picker("Strichstärke", selection: $toolController.penWidth) {
                    Text("0,5").tag(CGFloat(0.5))
                    Text("1").tag(CGFloat(1))
                    Text("2").tag(CGFloat(2))
                    Text("4").tag(CGFloat(4))
                    Text("7").tag(CGFloat(7))
                    Text("10").tag(CGFloat(10))
                }
            }
        } label: {
            Label("Strichstärke", systemImage: "lineweight")
                .labelStyle(.iconOnly)
                .frame(width: controlLength, height: controlLength)
        }
        .accessibilityLabel("Strichstärke")
    }

    private var presetColors: [UIColor] {
        [.black, .systemBlue, .systemRed, .systemGreen]
    }

    private var displayedColors: [UIColor] {
        let combined = toolController.recentColors + presetColors
        var seen = Set<String>()
        return combined.filter { color in
            let key = color.description
            return seen.insert(key).inserted
        }.prefix(6).map { $0 }
    }

    private var availableTools: [DrawingTool] {
        DrawingTool.allCases.filter { supportsObjects || $0 != .objects }
    }

    private var controlLength: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 52 : 44
    }

    private var colorControlLength: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 46 : 38
    }

    private func applyPresetColor(_ color: UIColor) {
        toolController.applyColor(color)
    }
}

private struct PageStrip: View {
    @ObservedObject var viewModel: NotebookViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        Button {
                            viewModel.selectPage(page.id)
                        } label: {
                            VStack(spacing: 4) {
                                PageThumbnail(page: page)
                                    .aspectRatio(
                                        page.metadata.pageSize.width / page.metadata.pageSize.height,
                                        contentMode: .fit
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(
                                                page.id == viewModel.selectedPageID
                                                    ? Color.accentColor
                                                    : Color.secondary.opacity(0.35),
                                                lineWidth: page.id == viewModel.selectedPageID ? 3 : 1
                                            )
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if page.metadata.isBookmarked {
                                            Image(systemName: "bookmark.fill")
                                                .font(.caption2)
                                                .foregroundStyle(BirdNotesTheme.accent)
                                                .padding(4)
                                                .background(.white.opacity(0.9), in: Circle())
                                            .padding(2)
                                        }
                                    }
                                    .frame(width: 72, height: 72)
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(page.id)
                        .accessibilityLabel("Seite \(index + 1)")
                    }

                    Button {
                        Task { await viewModel.addPage() }
                    } label: {
                        Label("Neue Seite", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .frame(width: 51, height: 72)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Neue Seite")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
            }
            .frame(height: 104)
            .background(Color.white.opacity(0.98))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
            }
            .onChange(of: viewModel.selectedPageID) { _, pageID in
                if let pageID {
                    withAnimation { proxy.scrollTo(pageID, anchor: .center) }
                }
            }
        }
    }
}

private struct PageThumbnail: View {
    let page: NotebookPage
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            PaperThumbnail(style: page.metadata.paperStyle)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .task(id: PageThumbnailRenderID(
            drawingData: page.drawingData,
            paperFormat: page.metadata.paperFormat,
            paperOrientation: page.metadata.paperOrientation
        )) {
            guard !page.drawingData.isEmpty,
                  let drawing = try? PKDrawing(data: page.drawingData) else {
                image = nil
                return
            }
            image = drawing.image(
                from: CGRect(
                    origin: .zero,
                    size: PencilPageCanvas.pageSize(
                        for: page.metadata.paperFormat,
                        orientation: page.metadata.paperOrientation
                    )
                ),
                scale: 0.15
            )
        }
    }
}

private struct PageThumbnailRenderID: Hashable {
    let drawingData: Data
    let paperFormat: PaperFormat
    let paperOrientation: PaperOrientation
}

private struct PaperThumbnail: View {
    let style: PaperStyle

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            guard style != .blank else { return }
            let spacing: CGFloat = 8
            if style == .dotted {
                var dots = Path()
                var x = spacing
                while x < size.width {
                    var y = spacing
                    while y < size.height {
                        dots.addEllipse(in: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4))
                        y += spacing
                    }
                    x += spacing
                }
                context.fill(dots, with: .color(.blue.opacity(0.20)))
                return
            }

            var path = Path()
            let summaryTop = style == .cornell ? size.height * 0.82 : size.height
            var y = spacing
            while y < summaryTop {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            if style == .grid {
                var x = spacing
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
            } else if style == .cornell {
                path.move(to: CGPoint(x: size.width * 0.28, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.28, y: summaryTop))
                path.move(to: CGPoint(x: 0, y: summaryTop))
                path.addLine(to: CGPoint(x: size.width, y: summaryTop))
            }
            context.stroke(path, with: .color(.blue.opacity(0.18)), lineWidth: 0.5)
        }
    }
}

private struct PagesOverviewView: View {
    @ObservedObject var viewModel: NotebookViewModel
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showsOnlyBookmarked = false

    private var visiblePages: [(offset: Int, element: NotebookPage)] {
        Array(viewModel.pages.enumerated()).filter {
            !showsOnlyBookmarked || $0.element.metadata.isBookmarked
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visiblePages, id: \.element.id) { index, page in
                    HStack(spacing: 14) {
                        PageThumbnail(page: page)
                            .aspectRatio(
                                page.metadata.pageSize.width / page.metadata.pageSize.height,
                                contentMode: .fit
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                        VStack(alignment: .leading) {
                            Text("Seite \(index + 1)")
                            Text(page.metadata.paperStyle.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(
                                "\(page.metadata.paperFormat.displayName) · "
                                    + page.metadata.paperOrientation.displayName
                            )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if page.metadata.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(BirdNotesTheme.accent)
                                .accessibilityLabel("Als wichtig markiert")
                        }
                        if page.id == viewModel.selectedPageID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { select(page.id) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { select(page.id) }
                    .accessibilityIdentifier("notebook.page.\(index + 1)")
                    .accessibilityValue(
                        page.id == viewModel.selectedPageID ? "Ausgewählt" : "Nicht ausgewählt"
                    )
                }
                .onMove { offsets, destination in
                    guard !showsOnlyBookmarked else { return }
                    Task { await viewModel.reorder(fromOffsets: offsets, toOffset: destination) }
                }
            }
            .navigationTitle("Seiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showsOnlyBookmarked.toggle()
                    } label: {
                        Label(
                            showsOnlyBookmarked ? "Alle Seiten anzeigen" : "Nur wichtige Seiten",
                            systemImage: showsOnlyBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    EditButton()
                        .disabled(showsOnlyBookmarked)
                    Button {
                        Task { await viewModel.addPage() }
                    } label: {
                        Label("Neue Seite", systemImage: "plus")
                    }
                    .accessibilityIdentifier("notebook.pageOverview.addPage")
                }
            }
        }
    }

    private func select(_ pageID: UUID) {
        onSelect(pageID)
        dismiss()
    }
}
