import SwiftUI
import BirdNotesCore
import BirdNotesTechnicalCore

private enum TechnicalSaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Bereit"
        case .saving: "Speichert …"
        case .saved: "Gespeichert"
        case .failed: "Speicherfehler"
        }
    }

    var symbol: String {
        switch self {
        case .idle: "circle"
        case .saving: "arrow.trianglehead.2.clockwise.rotate.90"
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
private final class TechnicalWorkspaceViewModel: ObservableObject {
    @Published private(set) var document: BirdTechDocument?
    @Published private(set) var history: DiagramHistory?
    @Published private(set) var registry: TechnicalModuleRegistry?
    @Published var selectedElementID: UUID?
    @Published private(set) var pendingConnection: ConnectionEndpoint?
    @Published private(set) var saveState: TechnicalSaveState = .idle
    @Published var errorMessage: String?
    @Published var shareItem: ExportShareItem?

    let store: DocumentStore
    let relativePath: String
    private var packageURL: URL?
    private var technicalStore: BirdTechDocumentStore?
    private var saveTask: Task<Void, Never>?

    init(store: DocumentStore, relativePath: String) {
        self.store = store
        self.relativePath = relativePath
        do {
            registry = try TechnicalModuleRegistry.builtIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var title: String {
        document?.manifest.title
            ?? URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
    }

    var diagram: TechnicalDiagram? { history?.diagram }

    var selectedElement: DiagramElement? {
        guard let selectedElementID else { return nil }
        return diagram?.elements.first(where: { $0.id == selectedElementID })
    }

    var canUndo: Bool { history?.canUndo == true }
    var canRedo: Bool { history?.canRedo == true }
    var isConnecting: Bool { pendingConnection != nil }

    func load() async {
        guard document == nil else { return }
        do {
            let url = try await store.itemURL(for: relativePath)
            let technicalStore = try BirdTechDocumentStore(rootURL: url.deletingLastPathComponent())
            var loaded = try await technicalStore.load(from: url)
            let fileTitle = url.deletingPathExtension().lastPathComponent
            let needsTitleUpdate = loaded.manifest.title != fileTitle
            if needsTitleUpdate {
                loaded.manifest.title = fileTitle
            }
            let history = try DiagramHistory(diagram: loaded.diagram)
            self.packageURL = url
            self.technicalStore = technicalStore
            self.document = loaded
            self.history = history
            if needsTitleUpdate {
                scheduleSave()
            }
        } catch {
            present(error)
        }
    }

    func select(_ element: DiagramElement) {
        if let pendingConnection,
           pendingConnection.elementID != element.id,
           let sourceElement = diagram?.elements.first(where: { $0.id == pendingConnection.elementID }),
           let sourcePort = sourceElement.ports.first(where: { $0.id == pendingConnection.portID }),
           let destinationPort = element.ports.first(where: { $0.kind == sourcePort.kind }) {
            let layerID = element.layerID
            let connection = DiagramConnection(
                source: pendingConnection,
                destination: ConnectionEndpoint(elementID: element.id, portID: destinationPort.id),
                layerID: layerID
            )
            self.pendingConnection = nil
            apply(.addConnection(connection))
            selectedElementID = element.id
            return
        }
        selectedElementID = element.id
    }

    func addSymbol(moduleID: String, symbolID: String) {
        guard let registry, let diagram, let layerID = diagram.layers.first(where: { !$0.isLocked })?.id else {
            return
        }
        do {
            let offset = Double((diagram.elements.count % 12) * 24)
            let element = try registry.instantiate(
                moduleID: moduleID,
                symbolID: symbolID,
                at: TechnicalPoint(x: 120 + offset, y: 120 + offset),
                layerID: layerID
            )
            apply(.addElement(element))
            selectedElementID = element.id
        } catch {
            present(error)
        }
    }

    func move(_ elementID: UUID, by translation: CGSize, zoom: Double) {
        guard zoom.isFinite,
              zoom > 0,
              let diagram,
              let element = diagram.elements.first(where: { $0.id == elementID }) else { return }
        let proposed = TechnicalPoint(
            x: element.frame.origin.x + Double(translation.width) / zoom,
            y: element.frame.origin.y + Double(translation.height) / zoom
        )
        let snap = SnapEngine(configuration: SnapConfiguration(
            isEnabled: diagram.grid.isSnappingEnabled,
            gridSpacing: diagram.grid.spacing,
            pointTolerance: 6 / zoom,
            angleIncrementDegrees: 15
        )).snap(proposed)
        apply(.moveElements(
            ids: [elementID],
            delta: TechnicalPoint(
                x: snap.point.x - element.frame.origin.x,
                y: snap.point.y - element.frame.origin.y
            )
        ))
    }

    func rotateSelected(by degrees: Double) {
        guard var element = selectedElement else { return }
        element.rotationDegrees = (element.rotationDegrees + degrees).truncatingRemainder(dividingBy: 360)
        apply(.replaceElement(element))
    }

    func updateSelectedLabel(_ label: String) {
        guard var element = selectedElement else { return }
        element.label = String(label.prefix(512))
        apply(.replaceElement(element))
    }

    func deleteSelected() {
        guard let id = selectedElementID else { return }
        apply(.removeElement(id))
        selectedElementID = nil
        pendingConnection = nil
    }

    func beginConnection() {
        guard let element = selectedElement, let port = element.ports.first else { return }
        pendingConnection = ConnectionEndpoint(elementID: element.id, portID: port.id)
    }

    func cancelConnection() {
        pendingConnection = nil
    }

    func undo() {
        guard var history else { return }
        do {
            try history.undo()
            update(history)
        } catch {
            present(error)
        }
    }

    func redo() {
        guard var history else { return }
        do {
            try history.redo()
            update(history)
        } catch {
            present(error)
        }
    }

    func addCalculation(_ calculation: TechnicalCalculation) {
        guard var document else { return }
        document.calculations.items.append(calculation)
        self.document = document
        scheduleSave()
    }

    func deleteCalculation(_ id: UUID) {
        guard var document else { return }
        document.calculations.items.removeAll { $0.id == id }
        self.document = document
        scheduleSave()
    }

    func exportSVG() {
        guard let diagram, let registry else { return }
        do {
            let data = try SVGDiagramExporter(registry: registry).export(
                diagram,
                options: SVGExportOptions(includesGrid: false)
            )
            let cleanTitle = title
                .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
                .joined(separator: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(cleanTitle.isEmpty ? "BirdNotes-Technik" : cleanTitle)
                .appendingPathExtension("svg")
            try data.write(to: url, options: .atomic)
            shareItem = ExportShareItem(url: url)
        } catch {
            present(error)
        }
    }

    func saveNow() async {
        saveTask?.cancel()
        saveTask = nil
        await persistCurrentDocument()
    }

    private func apply(_ command: DiagramCommand) {
        guard var history else { return }
        do {
            try history.apply(command)
            update(history)
        } catch {
            present(error)
        }
    }

    private func update(_ updatedHistory: DiagramHistory) {
        history = updatedHistory
        guard var document else { return }
        document.diagram = updatedHistory.diagram
        self.document = document
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveState = .saving
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                await self?.persistCurrentDocument()
            } catch is CancellationError {
                return
            } catch {
                self?.present(error)
            }
        }
    }

    private func persistCurrentDocument() async {
        guard let document, let technicalStore, let packageURL else { return }
        saveState = .saving
        do {
            _ = try await technicalStore.save(document, at: packageURL)
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

struct TechnicalWorkspaceView: View {
    @StateObject private var viewModel: TechnicalWorkspaceViewModel
    @State private var zoom = 0.55
    @State private var showsInspector = false
    @State private var showsCalculations = false

    init(store: DocumentStore, relativePath: String) {
        _viewModel = StateObject(wrappedValue: TechnicalWorkspaceViewModel(
            store: store,
            relativePath: relativePath
        ))
    }

    var body: some View {
        Group {
            if let diagram = viewModel.diagram, let registry = viewModel.registry {
                TechnicalCanvasView(
                    diagram: diagram,
                    registry: registry,
                    selectedElementID: viewModel.selectedElementID,
                    zoom: zoom,
                    onSelect: viewModel.select,
                    onMove: viewModel.move
                )
                .overlay(alignment: .topLeading) { connectionHint }
                .overlay(alignment: .bottomTrailing) { zoomControls }
            } else if viewModel.errorMessage == nil {
                ProgressView("Technik-Dokument wird geprüft …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Dokument nicht verfügbar",
                    systemImage: "exclamationmark.shield",
                    description: Text("Das Technik-Paket konnte nicht sicher geöffnet werden.")
                )
            }
        }
        .background(BirdNotesTheme.workspaceBackground)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task { await viewModel.load() }
        .onDisappear { Task { await viewModel.saveNow() } }
        .sheet(isPresented: $showsInspector) {
            TechnicalInspectorSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsCalculations) {
            if let registry = viewModel.registry, let document = viewModel.document {
                TechnicalCalculationsSheet(
                    registry: registry,
                    calculations: document.calculations.items,
                    onAdd: viewModel.addCalculation,
                    onDelete: viewModel.deleteCalculation
                )
            }
        }
        .sheet(item: $viewModel.shareItem) { item in
            ExportShareSheet(items: [item.url])
        }
        .alert("Technik-Dokument", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: viewModel.undo) { Image(systemName: "arrow.uturn.backward") }
                .disabled(!viewModel.canUndo)
                .accessibilityLabel("Rückgängig")
            Button(action: viewModel.redo) { Image(systemName: "arrow.uturn.forward") }
                .disabled(!viewModel.canRedo)
                .accessibilityLabel("Wiederholen")

            Menu {
                if let registry = viewModel.registry {
                    ForEach(registry.modules) { module in
                        Section(module.name) {
                            ForEach(module.symbols) { symbol in
                                Button(symbol.name) {
                                    viewModel.addSymbol(moduleID: module.id, symbolID: symbol.id)
                                }
                            }
                        }
                    }
                }
            } label: {
                Label("Bauteil", systemImage: "plus.square.on.square")
            }

            Button {
                showsCalculations = true
            } label: {
                Image(systemName: "function")
            }
            .accessibilityLabel("Berechnungen")

            Button {
                showsInspector = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .disabled(viewModel.selectedElement == nil)
            .accessibilityLabel("Inspektor")

            Menu {
                Button("Als SVG exportieren", systemImage: "square.and.arrow.up") {
                    viewModel.exportSVG()
                }
                if viewModel.isConnecting {
                    Button("Verbindung abbrechen", systemImage: "xmark") {
                        viewModel.cancelConnection()
                    }
                } else {
                    Button("Verbindung beginnen", systemImage: "link") {
                        viewModel.beginConnection()
                    }
                    .disabled(viewModel.selectedElement?.ports.isEmpty != false)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }

        ToolbarItem(placement: .status) {
            Label(viewModel.saveState.label, systemImage: viewModel.saveState.symbol)
                .font(.caption)
                .foregroundStyle(viewModel.saveState == .saved ? Color.green : Color.secondary)
        }
    }

    @ViewBuilder
    private var connectionHint: some View {
        if viewModel.isConnecting {
            Label("Zielelement antippen", systemImage: "link")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(16)
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button { zoom = max(0.2, zoom - 0.1) } label: { Image(systemName: "minus") }
            Text("\(Int(zoom * 100)) %")
                .font(.caption.monospacedDigit())
                .frame(width: 52)
            Button { zoom = min(2.0, zoom + 0.1) } label: { Image(systemName: "plus") }
        }
        .buttonStyle(.bordered)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }
}

private struct TechnicalCanvasView: View {
    let diagram: TechnicalDiagram
    let registry: TechnicalModuleRegistry
    let selectedElementID: UUID?
    let zoom: Double
    let onSelect: (DiagramElement) -> Void
    let onMove: (UUID, CGSize, Double) -> Void

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Color.white
                grid
                connections
                ForEach(diagram.elements.sorted(by: { $0.zIndex < $1.zIndex })) { element in
                    TechnicalElementView(
                        element: element,
                        definition: try? registry.symbol(
                            moduleID: element.moduleID,
                            symbolID: element.symbolID
                        ),
                        isSelected: selectedElementID == element.id,
                        zoom: zoom,
                        onSelect: { onSelect(element) },
                        onMove: { onMove(element.id, $0, zoom) }
                    )
                    .position(
                        x: (element.frame.origin.x + element.frame.size.width / 2) * zoom,
                        y: (element.frame.origin.y + element.frame.size.height / 2) * zoom
                    )
                }
            }
            .frame(
                width: diagram.canvasSize.width * zoom,
                height: diagram.canvasSize.height * zoom
            )
            .environment(\.colorScheme, .light)
            .shadow(color: .black.opacity(0.12), radius: 12)
            .padding(36)
        }
        .scrollIndicators(.visible)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var grid: some View {
        Canvas { context, size in
            guard diagram.grid.isVisible else { return }
            let spacing = diagram.grid.spacing * zoom
            guard spacing >= 4 else { return }
            var path = Path()
            var x = 0.0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y = 0.0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Color.blue.opacity(0.09)), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }

    private var connections: some View {
        Canvas { context, _ in
            let elements = Dictionary(uniqueKeysWithValues: diagram.elements.map { ($0.id, $0) })
            for connection in diagram.connections {
                guard let start = endpoint(connection.source, elements: elements),
                      let end = endpoint(connection.destination, elements: elements) else { continue }
                var path = Path()
                path.move(to: start)
                for point in connection.route {
                    path.addLine(to: CGPoint(x: point.x * zoom, y: point.y * zoom))
                }
                path.addLine(to: end)
                context.stroke(path, with: .color(Color(red: 0.05, green: 0.14, blue: 0.24)), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }

    private func endpoint(
        _ endpoint: ConnectionEndpoint,
        elements: [UUID: DiagramElement]
    ) -> CGPoint? {
        guard let element = elements[endpoint.elementID],
              let port = element.ports.first(where: { $0.id == endpoint.portID }) else { return nil }
        let unrotatedX = element.frame.origin.x + port.position.x * element.frame.size.width
        let unrotatedY = element.frame.origin.y + port.position.y * element.frame.size.height
        let center = element.frame.center
        let radians = element.rotationDegrees * .pi / 180
        let dx = unrotatedX - center.x
        let dy = unrotatedY - center.y
        return CGPoint(
            x: (center.x + dx * cos(radians) - dy * sin(radians)) * zoom,
            y: (center.y + dx * sin(radians) + dy * cos(radians)) * zoom
        )
    }
}

private struct TechnicalElementView: View {
    let element: DiagramElement
    let definition: TechnicalSymbolDefinition?
    let isSelected: Bool
    let zoom: Double
    let onSelect: () -> Void
    let onMove: (CGSize) -> Void
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        Canvas { context, size in
            let stroke = Color(red: 0.04, green: 0.13, blue: 0.23)
            if let definition {
                for primitive in definition.primitives {
                    draw(primitive, context: &context, size: size, stroke: stroke)
                }
            } else {
                context.stroke(
                    Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4),
                    with: .color(stroke),
                    lineWidth: 2
                )
            }
            for port in element.ports {
                let center = CGPoint(x: port.position.x * size.width, y: port.position.y * size.height)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                    with: .color(Color.white)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                    with: .color(stroke),
                    lineWidth: 1.5
                )
            }
        }
        .frame(width: element.frame.size.width * zoom, height: element.frame.size.height * zoom)
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.07) : Color.clear)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .contentShape(Rectangle())
        .rotationEffect(.degrees(element.rotationDegrees))
        .offset(dragTranslation)
        .onTapGesture(perform: onSelect)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { dragTranslation = $0.translation }
                .onEnded {
                    dragTranslation = .zero
                    onMove($0.translation)
                }
        )
        .accessibilityLabel(element.label ?? definition?.name ?? element.symbolID)
    }

    private func draw(
        _ primitive: DiagramSymbolPrimitive,
        context: inout GraphicsContext,
        size: CGSize,
        stroke: Color
    ) {
        switch primitive {
        case .line(let from, let to):
            var path = Path()
            path.move(to: point(from, size: size))
            path.addLine(to: point(to, size: size))
            context.stroke(path, with: .color(stroke), lineWidth: 2)
        case .polyline(let points):
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: point(first, size: size))
            for pointValue in points.dropFirst() {
                path.addLine(to: point(pointValue, size: size))
            }
            context.stroke(path, with: .color(stroke), lineWidth: 2)
        case .rectangle(let rect):
            context.stroke(Path(CGRect(
                x: rect.origin.x * size.width,
                y: rect.origin.y * size.height,
                width: rect.size.width * size.width,
                height: rect.size.height * size.height
            )), with: .color(stroke), lineWidth: 2)
        case .ellipse(let rect):
            context.stroke(Path(ellipseIn: CGRect(
                x: rect.origin.x * size.width,
                y: rect.origin.y * size.height,
                width: rect.size.width * size.width,
                height: rect.size.height * size.height
            )), with: .color(stroke), lineWidth: 2)
        case .text(let value, let position, let relativeSize):
            context.draw(
                Text(value)
                    .font(.system(size: max(8, min(size.width, size.height) * relativeSize)))
                    .foregroundStyle(stroke),
                at: point(position, size: size)
            )
        }
    }

    private func point(_ value: TechnicalPoint, size: CGSize) -> CGPoint {
        CGPoint(x: value.x * size.width, y: value.y * size.height)
    }
}

private struct TechnicalInspectorSheet: View {
    @ObservedObject var viewModel: TechnicalWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""

    var body: some View {
        NavigationStack {
            Form {
                if let element = viewModel.selectedElement {
                    Section("Element") {
                        LabeledContent("Modul", value: element.moduleID)
                        LabeledContent("Symbol", value: element.symbolID)
                        TextField("Beschriftung", text: $label)
                            .onSubmit { viewModel.updateSelectedLabel(label) }
                    }
                    Section("Ausrichtung") {
                        LabeledContent("Drehung", value: "\(Int(element.rotationDegrees))°")
                        HStack {
                            Button("-15°") { viewModel.rotateSelected(by: -15) }
                            Spacer()
                            Button("+15°") { viewModel.rotateSelected(by: 15) }
                        }
                    }
                    if !element.properties.isEmpty {
                        Section("Eigenschaften") {
                            ForEach(element.properties.keys.sorted(), id: \.self) { key in
                                LabeledContent(key, value: display(element.properties[key]))
                            }
                        }
                    }
                    Section {
                        Button("Element löschen", systemImage: "trash", role: .destructive) {
                            viewModel.deleteSelected()
                            dismiss()
                        }
                    }
                } else {
                    ContentUnavailableView("Kein Element ausgewählt", systemImage: "cursorarrow")
                }
            }
            .navigationTitle("Inspektor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        viewModel.updateSelectedLabel(label)
                        dismiss()
                    }
                }
            }
            .onAppear { label = viewModel.selectedElement?.label ?? "" }
        }
    }

    private func display(_ value: DiagramPropertyValue?) -> String {
        switch value {
        case .quantity(let quantity): String(format: "%.4g", quantity.canonicalValue)
        case .text(let text), .selection(let text): text
        case .boolean(let value): value ? "Ja" : "Nein"
        case .point(let point): "\(point.x), \(point.y)"
        case .points(let points): "\(points.count) Punkte"
        case nil: "—"
        }
    }
}

struct NewTechnicalDocumentSheet: View {
    let onCreate: (String, TechnicalDomain) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var domain: TechnicalDomain = .electricalEngineering

    var body: some View {
        NavigationStack {
            Form {
                Section("Dokument") {
                    TextField("Name", text: $name)
                    Picker("Fachbereich", selection: $domain) {
                        ForEach(TechnicalDomain.allCases, id: \.self) { domain in
                            Label(domain.displayName, systemImage: domain.systemImage).tag(domain)
                        }
                    }
                }
                Section {
                    Label(
                        "Bauteile bleiben semantisch verbunden und Formeln prüfen automatisch ihre physikalischen Einheiten.",
                        systemImage: "checkmark.shield"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neues Technik-Dokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        onCreate(name, domain)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct TechnicalCalculationsSheet: View {
    let registry: TechnicalModuleRegistry
    let calculations: [TechnicalCalculation]
    let onAdd: (TechnicalCalculation) -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !calculations.isEmpty {
                    Section("Gespeicherte Berechnungen") {
                        ForEach(calculations) { calculation in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(calculation.name).font(.headline)
                                Text(calculation.expression)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button("Löschen", role: .destructive) { onDelete(calculation.id) }
                            }
                        }
                    }
                }
                ForEach(registry.modules.filter { !$0.calculations.isEmpty }) { module in
                    Section(module.name) {
                        ForEach(module.calculations) { template in
                            NavigationLink(template.name) {
                                CalculationTemplateForm(template: template) { calculation in
                                    onAdd(calculation)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Berechnungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

private struct CalculationTemplateForm: View {
    let template: CalculationTemplate
    let onSave: (TechnicalCalculation) -> Void
    @State private var values: [String: String] = [:]
    @State private var units: [String: UnitIdentifier] = [:]
    @State private var evaluation: ExpressionEvaluation?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Formel") {
                Text(template.expression)
                    .font(.body.monospaced())
            }
            Section("Werte") {
                ForEach(template.variables) { variable in
                    HStack {
                        TextField(variable.name, text: binding(for: variable.id))
                            .keyboardType(.decimalPad)
                        Picker("Einheit", selection: unitBinding(for: variable)) {
                            ForEach(compatibleUnits(for: variable), id: \.id) { unit in
                                Text(unit.symbol.isEmpty ? unit.id.rawValue : unit.symbol).tag(unit.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 120)
                    }
                }
            }
            if let evaluation {
                Section("Ergebnis") {
                    Text(formatted(evaluation.result))
                        .font(.title2.monospacedDigit().weight(.semibold))
                    Text("\(evaluation.trace.steps.count) geprüfte Rechenschritte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button("Berechnen", systemImage: "equal") { calculate() }
                Button("Im Dokument speichern", systemImage: "square.and.arrow.down") {
                    save()
                }
                .disabled(evaluation == nil)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prepareDefaults)
    }

    private func prepareDefaults() {
        for variable in template.variables {
            values[variable.id] = values[variable.id] ?? "1"
            if units[variable.id] == nil {
                units[variable.id] = variable.suggestedUnitID
                    ?? compatibleUnits(for: variable).first?.id
                    ?? "one"
            }
        }
    }

    private func calculate() {
        do {
            let variables = try quantities()
            evaluation = try ExpressionEngine().evaluate(template.expression, variables: variables)
            errorMessage = nil
        } catch {
            evaluation = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let evaluation else { return }
        do {
            onSave(TechnicalCalculation(
                name: template.name,
                expression: template.expression,
                variables: try quantities(),
                lastEvaluation: evaluation
            ))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func quantities() throws -> [String: Quantity] {
        try Dictionary(uniqueKeysWithValues: template.variables.map { variable in
            let raw = values[variable.id, default: ""].replacingOccurrences(of: ",", with: ".")
            guard let value = Double(raw), value.isFinite, let unit = units[variable.id] else {
                throw TechnicalCoreError.invalidFunctionArgument(variable.name)
            }
            let quantity = try Quantity(value: value, unitID: unit)
            guard quantity.dimension == variable.dimension else {
                throw TechnicalCoreError.incompatibleDimensions
            }
            return (variable.id, quantity)
        })
    }

    private func compatibleUnits(for variable: CalculationVariableDefinition) -> [UnitDefinition] {
        UnitRegistry.si.allUnits.filter {
            $0.dimension == variable.dimension && $0.semantic == .regular
        }
    }

    private func formatted(_ quantity: Quantity) -> String {
        if let unit = UnitRegistry.si.allUnits.first(where: {
            $0.dimension == quantity.dimension && $0.semantic == quantity.semantic
        }), let value = try? quantity.value(in: unit.id) {
            return "\(String(format: "%.6g", value)) \(unit.symbol)"
        }
        return String(format: "%.6g SI", quantity.canonicalValue)
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(get: { values[id, default: ""] }, set: { values[id] = $0 })
    }

    private func unitBinding(for variable: CalculationVariableDefinition) -> Binding<UnitIdentifier> {
        Binding(
            get: {
                units[variable.id]
                    ?? variable.suggestedUnitID
                    ?? compatibleUnits(for: variable).first?.id
                    ?? "one"
            },
            set: { units[variable.id] = $0 }
        )
    }
}

private extension TechnicalDomain {
    var displayName: String {
        switch self {
        case .general: "Allgemein"
        case .electricalEngineering: "Elektrotechnik"
        case .technicalDrawing: "Technisches Zeichnen"
        case .mechanics: "Physik & Mechanik"
        case .informationTechnology: "IT & Netzwerke"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "square.grid.2x2"
        case .electricalEngineering: "bolt"
        case .technicalDrawing: "ruler"
        case .mechanics: "gearshape.2"
        case .informationTechnology: "network"
        }
    }
}
