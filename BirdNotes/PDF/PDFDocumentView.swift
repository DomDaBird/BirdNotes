import Combine
import PDFKit
import PencilKit
import SwiftUI
import BirdNotesCore

struct PDFDocumentView: View {
    @StateObject private var viewModel: PDFAnnotationViewModel
    @StateObject private var toolController = DrawingToolController()
    @StateObject private var canvasProxy = CanvasProxy()
    @Environment(\.scenePhase) private var scenePhase
    @State private var exportShareItem: ExportShareItem?

    init(store: DocumentStore, relativePath: String) {
        _viewModel = StateObject(
            wrappedValue: PDFAnnotationViewModel(store: store, relativePath: relativePath)
        )
    }

    var body: some View {
        Group {
            if let document = viewModel.document {
                ZStack(alignment: .top) {
                    PDFKitAnnotatingView(
                        document: document,
                        drawings: viewModel.drawings,
                        toolController: toolController,
                        canvasProxy: canvasProxy,
                        onDrawingChanged: viewModel.drawingChanged,
                        onDrawingEnded: viewModel.drawingEnded
                    )
                    .background(BirdNotesTheme.workspaceBackground)

                    DrawingToolBar(
                        toolController: toolController,
                        canvasProxy: canvasProxy
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "PDF konnte nicht geöffnet werden",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("PDF wird geladen …")
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("PDF-Handschrift wird gesichert")
                } else if viewModel.hasUnsavedChanges {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("PDF-Handschrift wartet auf Sicherung")
                } else if viewModel.lastSavedAt != nil {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("PDF-Handschrift ist gesichert")
                }

                if let fileURL = viewModel.fileURL {
                    ShareLink(item: fileURL) {
                        Label("Original-PDF teilen", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    Task {
                        await viewModel.flushAutosaves()
                        do {
                            guard let document = viewModel.document else { return }
                            exportShareItem = ExportShareItem(
                                url: try ExportSupport.annotatedPDF(
                                    document: document,
                                    drawings: viewModel.drawings,
                                    title: viewModel.title
                                )
                            )
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("PDF mit Handschrift exportieren", systemImage: "pencil.and.outline")
                }
            }
        }
        .task { await viewModel.load() }
        .onDisappear { viewModel.flushAutosavesForLifecycle() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                viewModel.flushAutosavesForLifecycle()
            }
        }
        .sheet(item: $exportShareItem) { item in
            ExportShareSheet(items: [item.url])
        }
        .alert("Fehler", isPresented: Binding(
            get: { viewModel.errorMessage != nil && viewModel.document != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
    }
}

@MainActor
final class PDFAnnotationViewModel: ObservableObject {
    @Published private(set) var document: PDFDocument?
    @Published private(set) var fileURL: URL?
    @Published private(set) var drawings: [Int: PKDrawing] = [:]
    @Published private(set) var isSaving = false
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var lastSavedAt: Date?
    @Published var errorMessage: String?

    private let store: DocumentStore
    private let relativePath: String
    private let autosaveDelay: Duration
    private var saveTasks: [Int: Task<Void, Never>] = [:]
    private var dirtyPages = Set<Int>()
    private var activeSaveCount = 0

    var title: String {
        URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
    }

    init(
        store: DocumentStore,
        relativePath: String,
        autosaveDelay: Duration = .milliseconds(500)
    ) {
        self.store = store
        self.relativePath = relativePath
        self.autosaveDelay = autosaveDelay
    }

    func load() async {
        do {
            let url = try await store.itemURL(for: relativePath)
            let storedDrawings = try await store.loadPDFDrawings(at: relativePath)
            guard let pdf = PDFDocument(url: url) else {
                throw DocumentStoreError.damagedDocument("Die PDF-Datei ist nicht lesbar.")
            }

            var restored: [Int: PKDrawing] = [:]
            for (pageIndex, data) in storedDrawings {
                restored[pageIndex] = try PKDrawing(data: data)
            }
            fileURL = url
            drawings = restored
            document = pdf
            dirtyPages.removeAll()
            hasUnsavedChanges = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func drawingChanged(pageIndex: Int, drawing: PKDrawing) {
        drawings[pageIndex] = drawing
        dirtyPages.insert(pageIndex)
        hasUnsavedChanges = true
        scheduleAutosave(pageIndex: pageIndex, delay: autosaveDelay)
    }

    /// PencilKit sends this callback as soon as a Pencil stroke, eraser pass,
    /// or lasso edit ends. Persisting here keeps a finished edit durable even
    /// when the page is virtualized or the app moves to the background before
    /// the normal debounce interval expires.
    func drawingEnded(pageIndex: Int, drawing: PKDrawing) {
        let currentDrawing = drawings[pageIndex] ?? PKDrawing()
        guard currentDrawing != drawing || dirtyPages.contains(pageIndex) else { return }
        drawings[pageIndex] = drawing
        dirtyPages.insert(pageIndex)
        hasUnsavedChanges = true
        scheduleAutosave(pageIndex: pageIndex, delay: .zero)
    }

    func flushAutosavesForLifecycle() {
        let backgroundSave = PDFBackgroundSaveSession()
        Task { [weak self, backgroundSave] in
            await self?.flushAutosaves()
            backgroundSave.end()
        }
    }

    private func scheduleAutosave(pageIndex: Int, delay: Duration) {
        saveTasks[pageIndex]?.cancel()
        guard let data = drawings[pageIndex]?.dataRepresentation() else { return }
        saveTasks[pageIndex] = Task { [weak self] in
            if delay != .zero {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
            } else {
                await Task.yield()
            }
            await self?.persist(data, pageIndex: pageIndex)
        }
    }

    func flushAutosaves() async {
        saveTasks.values.forEach { $0.cancel() }
        saveTasks.removeAll()
        let pagesToSave = dirtyPages.sorted()
        for pageIndex in pagesToSave {
            guard let drawing = drawings[pageIndex] else { continue }
            await persist(drawing.dataRepresentation(), pageIndex: pageIndex)
        }
        hasUnsavedChanges = !dirtyPages.isEmpty
    }

    private func persist(_ data: Data, pageIndex: Int) async {
        activeSaveCount += 1
        isSaving = true
        defer {
            activeSaveCount -= 1
            isSaving = activeSaveCount > 0
        }

        do {
            try await store.savePDFDrawing(
                data,
                forPageAt: pageIndex,
                inPDFAt: relativePath
            )
            if drawings[pageIndex]?.dataRepresentation() == data {
                dirtyPages.remove(pageIndex)
                saveTasks[pageIndex] = nil
            }
            hasUnsavedChanges = !dirtyPages.isEmpty
            lastSavedAt = Date()
        } catch is CancellationError {
        } catch {
            hasUnsavedChanges = true
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private final class PDFBackgroundSaveSession {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init() {
        identifier = UIApplication.shared.beginBackgroundTask(
            withName: "BirdNotes PDF Autosave"
        ) { [weak self] in
            Task { @MainActor in self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

struct PDFKitAnnotatingView: UIViewRepresentable {
    let document: PDFDocument
    let drawings: [Int: PKDrawing]
    @ObservedObject var toolController: DrawingToolController
    @ObservedObject var canvasProxy: CanvasProxy
    let onDrawingChanged: (Int, PKDrawing) -> Void
    let onDrawingEnded: (Int, PKDrawing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.usePageViewController(false)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageShadowsEnabled = true
        view.backgroundColor = .secondarySystemBackground
        view.pageOverlayViewProvider = context.coordinator
        view.isInMarkupMode = true
        view.document = document
        context.coordinator.updatePDFInteraction(in: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        view.isInMarkupMode = true
        context.coordinator.updatePDFInteraction(in: view)
        context.coordinator.updateVisibleCanvases()
        if view.document !== document {
            view.document = document
            view.autoScales = true
            context.coordinator.updatePDFInteraction(in: view)
        }
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        view.pageOverlayViewProvider = nil
        coordinator.detachAllCanvases()
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency PDFPageOverlayViewProvider, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: PDFKitAnnotatingView
        private var pageIndices: [ObjectIdentifier: Int] = [:]
        private let visibleCanvases = NSHashTable<PKCanvasView>.weakObjects()
        private var isApplyingExternalDrawing = false

        init(parent: PDFKitAnnotatingView) {
            self.parent = parent
        }

        func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            guard let document = pdfView.document else { return nil }
            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return nil }

            let canvas = PKCanvasView()
            canvas.backgroundColor = .clear
            canvas.isOpaque = false
            canvas.isScrollEnabled = false
            canvas.contentInsetAdjustmentBehavior = .never
            canvas.minimumZoomScale = 1
            canvas.maximumZoomScale = 1
            canvas.drawing = parent.drawings[pageIndex] ?? PKDrawing()
            canvas.delegate = self
            let pencilInteraction = UIPencilInteraction()
            pencilInteraction.delegate = self
            canvas.addInteraction(pencilInteraction)
            pageIndices[ObjectIdentifier(canvas)] = pageIndex
            visibleCanvases.add(canvas)
            configure(canvas)

            let overlay = PDFDrawingOverlayView(canvasView: canvas)
            updatePDFInteraction(in: pdfView)
            return overlay
        }

        func pdfView(
            _ pdfView: PDFView,
            willDisplayOverlayView overlayView: UIView,
            for page: PDFPage
        ) {
            guard let canvas = (overlayView as? PDFDrawingOverlayView)?.canvasView,
                  let document = pdfView.document else { return }
            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return }
            pageIndices[ObjectIdentifier(canvas)] = pageIndex
            canvas.delegate = self
            updatePDFInteraction(in: pdfView)
            visibleCanvases.add(canvas)
            configure(canvas)
            if let drawing = parent.drawings[pageIndex], drawing != canvas.drawing {
                isApplyingExternalDrawing = true
                canvas.drawing = drawing
                isApplyingExternalDrawing = false
            }
            parent.canvasProxy.attach(canvas)
            if parent.toolController.selectedTool != .hand {
                canvas.becomeFirstResponder()
            }
        }

        func pdfView(
            _ pdfView: PDFView,
            willEndDisplayingOverlayView overlayView: UIView,
            for page: PDFPage
        ) {
            guard let canvas = (overlayView as? PDFDrawingOverlayView)?.canvasView else { return }
            if let pageIndex = pageIndices[ObjectIdentifier(canvas)] {
                parent.onDrawingEnded(pageIndex, canvas.drawing)
            }
            pageIndices[ObjectIdentifier(canvas)] = nil
            canvas.delegate = nil
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing,
                  let pageIndex = pageIndices[ObjectIdentifier(canvasView)] else { return }
            parent.onDrawingChanged(pageIndex, canvasView.drawing)
            parent.canvasProxy.objectWillChange.send()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard let pageIndex = pageIndices[ObjectIdentifier(canvasView)] else { return }
            parent.onDrawingEnded(pageIndex, canvasView.drawing)
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.toolController.toggleEraserFromPencil()
        }

        func updateVisibleCanvases() {
            for canvas in visibleCanvases.allObjects {
                configure(canvas)
                guard let pageIndex = pageIndices[ObjectIdentifier(canvas)],
                      let drawing = parent.drawings[pageIndex],
                      drawing != canvas.drawing else { continue }
                isApplyingExternalDrawing = true
                canvas.drawing = drawing
                isApplyingExternalDrawing = false
            }
        }

        func updatePDFInteraction(in pdfView: PDFView) {
            pdfView.documentView?.isUserInteractionEnabled = true
            enablePDFPageViews(in: pdfView.documentView)

            let navigatesWithOneFinger = !parent.toolController.fingerDraws
                || parent.toolController.selectedTool == .hand
            for scrollView in descendantScrollViews(in: pdfView) where !(scrollView is PKCanvasView) {
                scrollView.panGestureRecognizer.minimumNumberOfTouches = navigatesWithOneFinger ? 1 : 2
                scrollView.panGestureRecognizer.allowedTouchTypes = [
                    NSNumber(value: UITouch.TouchType.direct.rawValue),
                    NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
                ]
                scrollView.pinchGestureRecognizer?.isEnabled = true
            }
        }

        func detachAllCanvases() {
            for canvas in visibleCanvases.allObjects {
                if let pageIndex = pageIndices[ObjectIdentifier(canvas)] {
                    parent.onDrawingEnded(pageIndex, canvas.drawing)
                }
                canvas.delegate = nil
            }
            pageIndices.removeAll()
        }

        private func configure(_ canvas: PKCanvasView) {
            canvas.tool = parent.toolController.pencilKitTool
            canvas.drawingPolicy = parent.toolController.fingerDraws ? .anyInput : .pencilOnly
            canvas.drawingGestureRecognizer.allowedTouchTypes = parent.toolController.fingerDraws
                ? [
                    NSNumber(value: UITouch.TouchType.direct.rawValue),
                    NSNumber(value: UITouch.TouchType.pencil.rawValue)
                ]
                : [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            canvas.drawingGestureRecognizer.isEnabled = parent.toolController.selectedTool != .hand
            canvas.isUserInteractionEnabled = parent.toolController.selectedTool != .hand
        }

        private func enablePDFPageViews(in view: UIView?) {
            guard let view else { return }
            if NSStringFromClass(type(of: view)).contains("PDFPageView") {
                view.isUserInteractionEnabled = true
            }
            view.subviews.forEach { enablePDFPageViews(in: $0) }
        }

        private func descendantScrollViews(in view: UIView) -> [UIScrollView] {
            var result: [UIScrollView] = []
            if let scrollView = view as? UIScrollView {
                result.append(scrollView)
            }
            for child in view.subviews {
                result.append(contentsOf: descendantScrollViews(in: child))
            }
            return result
        }
    }
}

private final class PDFDrawingOverlayView: UIView {
    let canvasView: PKCanvasView

    init(canvasView: PKCanvasView) {
        self.canvasView = canvasView
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = true

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }
}
