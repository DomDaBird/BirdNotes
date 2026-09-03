import Combine
import ImageIO
import PencilKit
import SwiftUI
import UniformTypeIdentifiers
import BirdNotesCore

enum RotationViewportPolicy {
    static func adjustedZoomScale(
        _ currentZoomScale: CGFloat,
        from previousSize: CGSize,
        to newSize: CGSize,
        automaticallyFitsWidth: Bool
    ) -> CGFloat {
        guard automaticallyFitsWidth,
              currentZoomScale.isFinite,
              previousSize.width.isFinite,
              newSize.width.isFinite,
              previousSize.width > 0,
              newSize.width > 0 else { return currentZoomScale }
        return currentZoomScale * newSize.width / previousSize.width
    }
}

struct InfiniteCanvasView: View {
    @StateObject private var viewModel: InfiniteCanvasViewModel
    @StateObject private var toolController = DrawingToolController()
    @StateObject private var canvasProxy = CanvasProxy()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("canvasAutomaticallyFitsOnRotation")
    private var automaticallyFitsOnRotation = true
    @State private var selectedElementID: UUID?
    @State private var showsTextPrompt = false
    @State private var textDraft = ""
    @State private var importsImage = false

    init(store: DocumentStore, relativePath: String) {
        _viewModel = StateObject(
            wrappedValue: InfiniteCanvasViewModel(store: store, relativePath: relativePath)
        )
    }

    var body: some View {
        Group {
            if viewModel.document == nil {
                ProgressView("Canvas wird geladen …")
            } else if let document = viewModel.document {
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        Color.white.ignoresSafeArea()
                        InfinitePencilCanvas(
                            drawing: $viewModel.drawing,
                            viewport: $viewModel.viewport,
                            automaticallyFitsOnViewportChange: automaticallyFitsOnRotation,
                            canvasSize: CGSize(
                                width: document.manifest.width,
                                height: document.manifest.height
                            ),
                            toolController: toolController,
                            canvasProxy: canvasProxy,
                            onDrawingChanged: viewModel.drawingChanged,
                            onViewportChanged: viewModel.viewportChanged
                        )

                        CanvasObjectLayer(
                            elements: $viewModel.elements,
                            selectedElementID: $selectedElementID,
                            viewport: viewModel.viewport,
                            editingEnabled: toolController.selectedTool == .objects,
                            onElementsChanged: viewModel.elementsChanged,
                            onDuplicate: { selectedElementID = viewModel.duplicateElement($0) },
                            onDelete: {
                                viewModel.deleteElement($0)
                                selectedElementID = nil
                            }
                        )

                        VStack(spacing: 8) {
                            DrawingToolBar(
                                toolController: toolController,
                                canvasProxy: canvasProxy,
                                supportsObjects: true
                            )
                            CanvasInsertBar(
                                hasSelection: selectedElementID != nil,
                                onText: {
                                    textDraft = ""
                                    showsTextPrompt = true
                                },
                                onImage: { importsImage = true },
                                onShape: {
                                    selectedElementID = viewModel.addShape($0)
                                    toolController.select(.objects)
                                },
                                onMindMap: {
                                    selectedElementID = viewModel.addMindMap()
                                    toolController.select(.objects)
                                },
                                onCopy: { viewModel.copyElement(selectedElementID) },
                                onCut: {
                                    viewModel.cutElement(selectedElementID)
                                    selectedElementID = nil
                                },
                                onPaste: {
                                    selectedElementID = viewModel.pasteElement()
                                    toolController.select(.objects)
                                },
                                onDuplicate: {
                                    guard let id = selectedElementID else { return }
                                    selectedElementID = viewModel.duplicateElement(id)
                                },
                                onDelete: {
                                    guard let id = selectedElementID else { return }
                                    viewModel.deleteElement(id)
                                    selectedElementID = nil
                                }
                            )
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    viewModel.fitAll(in: geometry.size)
                                } label: {
                                    Label("Alles anzeigen", systemImage: "arrow.up.left.and.arrow.down.right")
                                        .labelStyle(.iconOnly)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.circle)
                                .accessibilityLabel("Alles anzeigen")
                            }
                        }
                        .padding(18)
                    }
                }
            }
        }
        .background {
            Color.white.ignoresSafeArea()
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    automaticallyFitsOnRotation.toggle()
                } label: {
                    Label(
                        automaticallyFitsOnRotation
                            ? "Drehung automatisch anpassen"
                            : "Drehung nicht automatisch anpassen",
                        systemImage: automaticallyFitsOnRotation
                            ? "arrow.left.and.right.circle.fill"
                            : "arrow.left.and.right.circle"
                    )
                }
                .accessibilityValue(automaticallyFitsOnRotation ? "Ein" : "Aus")
                if viewModel.isSaving {
                    ProgressView().controlSize(.small)
                } else if viewModel.lastSavedAt != nil {
                    Label("Gesichert", systemImage: "checkmark.circle")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await viewModel.load() }
        .onDisappear { Task { await viewModel.flushAutosave() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await viewModel.flushAutosave() }
            }
        }
        .alert("Text hinzufügen", isPresented: $showsTextPrompt) {
            TextField("Text", text: $textDraft)
            Button("Einfügen") {
                selectedElementID = viewModel.addText(textDraft.isEmpty ? "Text" : textDraft)
                toolController.select(.objects)
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $importsImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                if case .failure(let error) = result {
                    viewModel.errorMessage = error.localizedDescription
                }
                return
            }
            Task {
                do {
                    let imported = try await Task.detached(priority: .userInitiated) {
                        try CanvasImageImporter.load(from: url)
                    }.value
                    selectedElementID = try viewModel.addNormalizedImage(imported)
                    toolController.select(.objects)
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Fehler", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
    }
}

@MainActor
final class InfiniteCanvasViewModel: ObservableObject {
    @Published private(set) var document: InfiniteCanvasDocument?
    @Published var drawing = PKDrawing()
    @Published var elements: [CanvasElement] = []
    @Published var viewport = CanvasViewport()
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published private(set) var lastSavedAt: Date?
    @Published var errorMessage: String?

    private let store: DocumentStore
    private let relativePath: String
    private var saveTask: Task<Void, Never>?
    private var hasUnsavedChanges = false

    var title: String { document?.manifest.title ?? "Endlos-Canvas" }

    init(store: DocumentStore, relativePath: String) {
        self.store = store
        self.relativePath = relativePath
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await store.loadInfiniteCanvas(at: relativePath)
            document = loaded
            drawing = loaded.drawingData.isEmpty ? PKDrawing() : try PKDrawing(data: loaded.drawingData)
            elements = loaded.elements
            viewport = loaded.manifest.viewport
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func drawingChanged(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        scheduleAutosave()
    }

    func elementsChanged() {
        scheduleAutosave()
    }

    func viewportChanged(_ newViewport: CanvasViewport) {
        guard viewport != newViewport else { return }
        viewport = newViewport
        scheduleAutosave(delay: .milliseconds(1_000))
    }

    @discardableResult
    func addText(_ text: String) -> UUID {
        let safeText = String(text.prefix(DocumentStoreLimits.maximumCanvasTextCharacters))
        let element = CanvasElement(
            kind: .text,
            center: viewport.center,
            size: CanvasSize(width: 300, height: 130),
            text: safeText,
            strokeColor: .ink
        )
        elements.append(element)
        scheduleAutosave()
        return element.id
    }

    @discardableResult
    func addNormalizedImage(_ imported: ImportedCanvasImage) throws -> UUID {
        guard !imported.data.isEmpty,
              imported.data.count <= DocumentStoreLimits.maximumCanvasImageBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Ein Canvas-Bild darf höchstens 20 MB groß sein."
            )
        }
        let ratio = max(imported.pixelSize.width / max(imported.pixelSize.height, 1), 0.1)
        let element = CanvasElement(
            kind: .image,
            center: viewport.center,
            size: CanvasSize(width: min(520 * ratio, 720), height: min(520 / ratio, 520)),
            imageData: imported.data
        )
        elements.append(element)
        scheduleAutosave()
        return element.id
    }

    @discardableResult
    func addShape(_ shape: CanvasShapeKind) -> UUID {
        let isLine = shape == .line || shape == .arrow
        let element = CanvasElement(
            kind: .shape,
            center: viewport.center,
            size: CanvasSize(width: 260, height: isLine ? 70 : 180),
            shapeKind: shape,
            strokeColor: .accent,
            fillColor: isLine ? nil : CanvasColor(red: 0.89, green: 0.95, blue: 1),
            strokeWidth: 4
        )
        elements.append(element)
        scheduleAutosave()
        return element.id
    }

    @discardableResult
    func addMindMap() -> UUID {
        let center = CanvasElement(
            kind: .text,
            center: viewport.center,
            size: CanvasSize(width: 260, height: 100),
            text: "Zentrale Idee",
            strokeColor: .accent,
            fillColor: CanvasColor(red: 0.89, green: 0.95, blue: 1)
        )
        var additions = [center]
        let offsets = [(-360.0, -230.0), (360.0, -230.0), (-360.0, 230.0), (360.0, 230.0)]
        for (index, offset) in offsets.enumerated() {
            let node = CanvasElement(
                kind: .text,
                center: CanvasPoint(x: viewport.center.x + offset.0, y: viewport.center.y + offset.1),
                size: CanvasSize(width: 230, height: 90),
                text: "Gedanke \(index + 1)",
                strokeColor: .ink
            )
            additions.append(node)
            additions.append(CanvasElement(
                kind: .connector,
                center: viewport.center,
                size: CanvasSize(width: 1, height: 1),
                strokeColor: .accent,
                strokeWidth: 3,
                sourceElementID: center.id,
                targetElementID: node.id
            ))
        }
        elements.append(contentsOf: additions)
        scheduleAutosave()
        return center.id
    }

    @discardableResult
    func duplicateElement(_ id: UUID) -> UUID? {
        guard var copy = elements.first(where: { $0.id == id }), copy.kind != .connector else { return nil }
        copy.id = UUID()
        copy.center.x += 32
        copy.center.y += 32
        copy.createdAt = Date()
        copy.modifiedAt = copy.createdAt
        elements.append(copy)
        scheduleAutosave()
        return copy.id
    }

    func deleteElement(_ id: UUID) {
        elements.removeAll {
            $0.id == id || $0.sourceElementID == id || $0.targetElementID == id
        }
        scheduleAutosave()
    }

    func copyElement(_ id: UUID?) {
        guard let id, let element = elements.first(where: { $0.id == id }),
              let data = try? PropertyListEncoder().encode(element) else { return }
        UIPasteboard.general.setItems(
            [[Self.elementPasteboardType: data]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(60 * 60)
            ]
        )
    }

    func cutElement(_ id: UUID?) {
        guard let id else { return }
        copyElement(id)
        deleteElement(id)
    }

    @discardableResult
    func pasteElement() -> UUID? {
        guard let data = UIPasteboard.general.data(forPasteboardType: Self.elementPasteboardType),
              data.count <= DocumentStoreLimits.maximumCanvasImageBytes + 1_024_000,
              var element = try? PropertyListDecoder().decode(CanvasElement.self, from: data) else { return nil }
        if let imageData = element.imageData,
           imageData.count > DocumentStoreLimits.maximumCanvasImageBytes { return nil }
        if let text = element.text,
           text.count > DocumentStoreLimits.maximumCanvasTextCharacters { return nil }
        guard isSafePastedElement(element) else { return nil }
        element.id = UUID()
        element.center = viewport.center
        element.createdAt = Date()
        element.modifiedAt = element.createdAt
        element.sourceElementID = nil
        element.targetElementID = nil
        elements.append(element)
        scheduleAutosave()
        return element.id
    }

    func fitAll(in viewportSize: CGSize) {
        var bounds = drawing.bounds
        for element in elements where element.kind != .connector {
            let rect = CGRect(
                x: element.center.x - element.size.width / 2,
                y: element.center.y - element.size.height / 2,
                width: element.size.width,
                height: element.size.height
            )
            bounds = bounds.isNull ? rect : bounds.union(rect)
        }

        guard !bounds.isNull, bounds.width > 1, bounds.height > 1 else {
            guard let manifest = document?.manifest else { return }
            viewport = CanvasViewport(
                center: CanvasPoint(x: manifest.width / 2, y: manifest.height / 2),
                zoomScale: 0.35
            )
            scheduleAutosave()
            return
        }

        let availableWidth = max(viewportSize.width - 140, 100)
        let availableHeight = max(viewportSize.height - 220, 100)
        viewport = CanvasViewport(
            center: CanvasPoint(x: bounds.midX, y: bounds.midY),
            zoomScale: min(max(min(availableWidth / bounds.width, availableHeight / bounds.height), 0.08), 2)
        )
        scheduleAutosave()
    }

    func flushAutosave() async {
        saveTask?.cancel()
        saveTask = nil
        guard hasUnsavedChanges else { return }
        await persist(
            drawingData: drawing.dataRepresentation(),
            elements: elements,
            viewport: viewport
        )
    }

    private func scheduleAutosave(delay: Duration = .milliseconds(800)) {
        hasUnsavedChanges = true
        saveTask?.cancel()
        let drawingData = drawing.dataRepresentation()
        let elements = elements
        let viewport = viewport
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            await self?.persist(drawingData: drawingData, elements: elements, viewport: viewport)
        }
    }

    private func persist(
        drawingData: Data,
        elements: [CanvasElement],
        viewport: CanvasViewport
    ) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.saveInfiniteCanvas(
                drawingData: drawingData,
                elements: elements,
                viewport: viewport,
                at: relativePath
            )
            if drawing.dataRepresentation() == drawingData,
               self.elements == elements,
               self.viewport == viewport {
                hasUnsavedChanges = false
            }
            lastSavedAt = Date()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let elementPasteboardType = "com.dominikvogel.BirdNotes.canvas-element"

    private func isSafePastedElement(_ element: CanvasElement) -> Bool {
        guard element.kind != .connector,
              element.center.x.isFinite,
              element.center.y.isFinite,
              element.size.width.isFinite,
              element.size.height.isFinite,
              element.rotation.isFinite,
              element.strokeWidth.isFinite,
              element.size.width > 0,
              element.size.height > 0,
              element.size.width <= 1_000_000,
              element.size.height <= 1_000_000,
              (0...1_000).contains(element.strokeWidth),
              isSafeColor(element.strokeColor),
              element.fillColor.map(isSafeColor) ?? true else { return false }

        guard let imageData = element.imageData else { return element.kind != .image }
        guard element.kind == .image,
              imageData.count <= DocumentStoreLimits.maximumCanvasImageBytes,
              let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.uint64Value,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.uint64Value,
              width > 0,
              height > 0,
              width <= 80_000_000,
              height <= 80_000_000,
              width <= 80_000_000 / height else { return false }
        return true
    }

    private func isSafeColor(_ color: CanvasColor) -> Bool {
        [color.red, color.green, color.blue, color.alpha].allSatisfy {
            $0.isFinite && (0...1).contains($0)
        }
    }
}

private struct InfinitePencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var viewport: CanvasViewport
    let automaticallyFitsOnViewportChange: Bool
    let canvasSize: CGSize
    @ObservedObject var toolController: DrawingToolController
    @ObservedObject var canvasProxy: CanvasProxy
    let onDrawingChanged: (PKDrawing) -> Void
    let onViewportChanged: (CanvasViewport) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> InfinitePKCanvasView {
        let canvas = InfinitePKCanvasView(canvasSize: canvasSize, viewport: viewport)
        canvas.enforceLightAppearance()
        canvas.updateAutomaticViewportFit(automaticallyFitsOnViewportChange)
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.drawingPolicy = toolController.fingerDraws ? .anyInput : .pencilOnly
        canvas.tool = toolController.pencilKitTool
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvas.addInteraction(pencilInteraction)
        canvasProxy.attach(canvas)
        return canvas
    }

    func updateUIView(_ canvas: InfinitePKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.enforceLightAppearance()
        canvas.updateAutomaticViewportFit(automaticallyFitsOnViewportChange)
        canvas.drawingPolicy = toolController.fingerDraws ? .anyInput : .pencilOnly
        canvas.tool = toolController.pencilKitTool
        canvas.setViewport(viewport)
        canvas.drawingGestureRecognizer.isEnabled = toolController.selectedTool != .hand
            && toolController.selectedTool != .objects
        if canvas.drawing != drawing {
            context.coordinator.isApplyingExternalDrawing = true
            canvas.drawing = drawing
            context.coordinator.isApplyingExternalDrawing = false
        }
        if canvasProxy.canvasView !== canvas { canvasProxy.attach(canvas) }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: InfinitePencilCanvas
        var isApplyingExternalDrawing = false

        init(parent: InfinitePencilCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            let drawing = canvasView.drawing
            if parent.drawing != drawing { parent.drawing = drawing }
            parent.onDrawingChanged(drawing)
            parent.canvasProxy.objectWillChange.send()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            reportViewport(scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            reportViewport(scrollView)
        }

        private func reportViewport(_ scrollView: UIScrollView) {
            guard let canvas = scrollView as? InfinitePKCanvasView,
                  !canvas.isApplyingViewport,
                  canvas.bounds.width > 0,
                  canvas.bounds.height > 0 else { return }
            let newViewport = canvas.currentViewport
            parent.onViewportChanged(newViewport)
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.toolController.toggleEraserFromPencil()
        }
    }
}

private final class InfinitePKCanvasView: PKCanvasView {
    private let workspaceSize: CGSize
    private var desiredViewport: CanvasViewport
    private var didApplyInitialViewport = false
    private var lastViewportSize = CGSize.zero
    private var automaticallyFitsOnViewportChange = true
    private(set) var isApplyingViewport = false

    init(canvasSize: CGSize, viewport: CanvasViewport) {
        workspaceSize = canvasSize
        desiredViewport = viewport
        super.init(frame: .zero)
        enforceLightAppearance()
        contentSize = canvasSize
        minimumZoomScale = 0.08
        maximumZoomScale = 4
        bouncesZoom = true
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = true
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        enforceLightAppearance()
        contentSize = workspaceSize
        guard bounds.width > 0, bounds.height > 0 else { return }
        if !didApplyInitialViewport {
            lastViewportSize = bounds.size
            applyViewport(desiredViewport)
            didApplyInitialViewport = true
            return
        }

        let viewportChanged = abs(bounds.width - lastViewportSize.width) > 1
            || abs(bounds.height - lastViewportSize.height) > 1
        guard viewportChanged, !isApplyingViewport else { return }

        let previousSize = lastViewportSize
        let currentScale = max(zoomScale, 0.01)
        let previousCenter = CanvasPoint(
            x: (contentOffset.x + previousSize.width / 2) / currentScale,
            y: (contentOffset.y + previousSize.height / 2) / currentScale
        )
        // Width-based scaling mirrors the notebook's fit behavior and is
        // reversible when the device rotates back to its previous size.
        let adjustedZoomScale = RotationViewportPolicy.adjustedZoomScale(
            currentScale,
            from: previousSize,
            to: bounds.size,
            automaticallyFitsWidth: automaticallyFitsOnViewportChange
        )
        let adjustedViewport = CanvasViewport(
            center: previousCenter,
            zoomScale: Double(adjustedZoomScale)
        )
        lastViewportSize = bounds.size
        desiredViewport = adjustedViewport
        applyViewport(adjustedViewport)
    }

    var currentViewport: CanvasViewport {
        let scale = max(zoomScale, 0.01)
        return CanvasViewport(
            center: CanvasPoint(
                x: (contentOffset.x + bounds.width / 2) / scale,
                y: (contentOffset.y + bounds.height / 2) / scale
            ),
            zoomScale: scale
        )
    }

    func setViewport(_ viewport: CanvasViewport) {
        desiredViewport = viewport
        guard didApplyInitialViewport, bounds.width > 0, bounds.height > 0 else { return }
        let current = currentViewport
        guard abs(current.center.x - viewport.center.x) > 1
                || abs(current.center.y - viewport.center.y) > 1
                || abs(current.zoomScale - viewport.zoomScale) > 0.002 else { return }
        applyViewport(viewport)
    }

    func updateAutomaticViewportFit(_ enabled: Bool) {
        automaticallyFitsOnViewportChange = enabled
    }

    private func applyViewport(_ viewport: CanvasViewport) {
        isApplyingViewport = true
        let scale = min(max(CGFloat(viewport.zoomScale), minimumZoomScale), maximumZoomScale)
        setZoomScale(scale, animated: false)
        contentOffset = CGPoint(
            x: max(CGFloat(viewport.center.x) * scale - bounds.width / 2, 0),
            y: max(CGFloat(viewport.center.y) * scale - bounds.height / 2, 0)
        )
        isApplyingViewport = false
    }

    func enforceLightAppearance() {
        overrideUserInterfaceStyle = .light
        isOpaque = true
        backgroundColor = Self.gridPatternColor
        indicatorStyle = .black
    }

    private static let gridPatternColor: UIColor = {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.withAlphaComponent(0.13).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 15, y: 15, width: 2, height: 2))
        }
        return UIColor(patternImage: image)
    }()
}

private struct CanvasInsertBar: View {
    let hasSelection: Bool
    let onText: () -> Void
    let onImage: () -> Void
    let onShape: (CanvasShapeKind) -> Void
    let onMindMap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onPaste: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onText) {
                Label("Text", systemImage: "textformat")
            }
            Button(action: onImage) {
                Label("Bild", systemImage: "photo")
            }
            Menu {
                ForEach(CanvasShapeKind.allCases, id: \.self) { shape in
                    Button(shape.title, systemImage: shape.systemImage) { onShape(shape) }
                }
            } label: {
                Label("Form", systemImage: "square.on.circle")
            }
            Button(action: onMindMap) {
                Label("Mindmap", systemImage: "point.3.connected.trianglepath.dotted")
            }

            Divider().frame(height: 24)

            Menu {
                Button("Kopieren", systemImage: "doc.on.doc", action: onCopy)
                    .disabled(!hasSelection)
                Button("Ausschneiden", systemImage: "scissors", action: onCut)
                    .disabled(!hasSelection)
                Button("Einfügen", systemImage: "doc.on.clipboard", action: onPaste)
                Button("Duplizieren", systemImage: "plus.square.on.square", action: onDuplicate)
                    .disabled(!hasSelection)
                Divider()
                Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
                    .disabled(!hasSelection)
            } label: {
                Label("Objektaktionen", systemImage: "ellipsis.circle")
            }
        }
        .font(.subheadline.weight(.medium))
        .buttonStyle(.borderless)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.97), in: Capsule())
        .overlay { Capsule().stroke(Color.black.opacity(0.08)) }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        .fixedSize()
    }
}

private extension CanvasShapeKind {
    var title: String {
        switch self {
        case .line: "Linie"
        case .arrow: "Pfeil"
        case .rectangle: "Rechteck"
        case .roundedRectangle: "Abgerundetes Rechteck"
        case .ellipse: "Ellipse"
        case .triangle: "Dreieck"
        }
    }

    var systemImage: String {
        switch self {
        case .line: "line.diagonal"
        case .arrow: "arrow.right"
        case .rectangle: "rectangle"
        case .roundedRectangle: "rectangle.roundedtop"
        case .ellipse: "circle"
        case .triangle: "triangle"
        }
    }
}

struct ImportedCanvasImage: Sendable {
    let data: Data
    let pixelSize: CanvasSize
}

enum CanvasImageImporter {
    private static let maximumSourceBytes = 50 * 1_024 * 1_024
    private static let maximumPixels: UInt64 = 80_000_000
    private static let maximumDimension = 2_200

    static func load(from url: URL) throws -> ImportedCanvasImage {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw DocumentStoreError.unsupportedFileType("keine reguläre Bilddatei")
        }
        if let size = values.fileSize, size > maximumSourceBytes {
            throw DocumentStoreError.resourceLimitExceeded(
                "Bildimporte dürfen höchstens 50 MB groß sein."
            )
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let actualSize = try handle.seekToEnd()
        guard actualSize <= UInt64(maximumSourceBytes) else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Bildimporte dürfen höchstens 50 MB groß sein."
            )
        }
        try handle.seek(toOffset: 0)
        let sourceData = try handle.read(upToCount: maximumSourceBytes + 1) ?? Data()
        guard sourceData.count <= maximumSourceBytes,
              let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.uint64Value,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.uint64Value,
              width > 0,
              height > 0,
              width <= maximumPixels,
              height <= maximumPixels,
              width <= maximumPixels / height else {
            throw DocumentStoreError.unsupportedFileType("ungültiges oder zu großes Bild")
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw DocumentStoreError.unsupportedFileType("Bild")
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw DocumentStoreError.fileOperationFailed("Das Bild konnte nicht normalisiert werden.")
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination),
              output.length > 0,
              output.length <= DocumentStoreLimits.maximumCanvasImageBytes else {
            throw DocumentStoreError.resourceLimitExceeded(
                "Das normalisierte Canvas-Bild überschreitet 20 MB."
            )
        }
        return ImportedCanvasImage(
            data: output as Data,
            pixelSize: CanvasSize(width: Double(width), height: Double(height))
        )
    }
}
