import Foundation
import PDFKit
import PencilKit
import Testing
import UIKit
@testable import BirdNotes
import BirdNotesCore

@Suite("Sicherer ZIP-Backup-Import")
struct BackupImportSupportTests {
    @Test("Systemkomprimiertes BirdNotes-Backup wird sicher entpackt und geprüft")
    func systemArchiveRoundTrip() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("BirdNotesZIPSource-\(UUID().uuidString)", isDirectory: true)
        let targetRoot = fileManager.temporaryDirectory
            .appendingPathComponent("BirdNotesZIPTarget-\(UUID().uuidString)", isDirectory: true)
        let exports = fileManager.temporaryDirectory
            .appendingPathComponent("BirdNotesZIPExport-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: targetRoot)
            try? fileManager.removeItem(at: exports)
        }

        let sourceStore = try DocumentStore(rootURL: root)
        let notebook = try await sourceStore.createNotebook(named: "ZIP-Prüfung")
        let page = try #require(try await sourceStore.loadNotebook(at: notebook).pages.first)
        try await sourceStore.updatePageTranscription(
            "Diese Sicherung wurde komprimiert und wieder entpackt.",
            for: page.id,
            inNotebookAt: notebook
        )
        let package = try await sourceStore.createLibraryBackup(in: exports)
        let archiveURL = exports.appendingPathComponent("Sicherung.zip")
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(
            readingItemAt: package,
            options: .forUploading,
            error: &coordinationError
        ) { uploadURL in
            do {
                try fileManager.copyItem(at: uploadURL, to: archiveURL)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }

        let prepared = try BackupImportSupport.prepare(archiveURL)
        defer {
            if let cleanupURL = prepared.cleanupURL {
                try? fileManager.removeItem(at: cleanupURL)
            }
        }
        let targetStore = try DocumentStore(rootURL: targetRoot)
        let preview = try await targetStore.inspectLibraryBackup(at: prepared.packageURL)

        #expect(preview.itemNames == ["ZIP-Prüfung"])
        #expect(preview.itemCount == 1)
    }
}

@MainActor
@Suite("Pencil- und Fingereingabe", .serialized)
struct DrawingInputPolicyTests {
    @Test("Neue Installationen zeichnen nur mit dem Pencil und merken eine bewusste Fingerfreigabe")
    func pencilOnlyIsPersistentDefault() throws {
        let suiteName = "BirdNotesDrawingInputTests-\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let initial = DrawingToolController(preferences: preferences)
        #expect(!initial.fingerDraws)

        initial.fingerDraws = true
        let restored = DrawingToolController(preferences: preferences)
        #expect(restored.fingerDraws)
    }

    @Test("PDF navigiert mit einem Finger, solange nur der Pencil zeichnet")
    func pdfUsesOneFingerForNavigation() throws {
        let suiteName = "BirdNotesPDFInputTests-\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let toolController = DrawingToolController(preferences: preferences)
        let scrollView = UIScrollView()
        let pdfView = PDFView()
        pdfView.addSubview(scrollView)
        let representable = PDFKitAnnotatingView(
            document: PDFDocument(),
            drawings: [:],
            toolController: toolController,
            canvasProxy: CanvasProxy(),
            onDrawingChanged: { _, _ in },
            onDrawingEnded: { _, _ in }
        )
        let coordinator = representable.makeCoordinator()

        coordinator.updatePDFInteraction(in: pdfView)
        #expect(scrollView.panGestureRecognizer.minimumNumberOfTouches == 1)

        toolController.fingerDraws = true
        coordinator.updatePDFInteraction(in: pdfView)
        #expect(scrollView.panGestureRecognizer.minimumNumberOfTouches == 2)

        toolController.select(.hand)
        coordinator.updatePDFInteraction(in: pdfView)
        #expect(scrollView.panGestureRecognizer.minimumNumberOfTouches == 1)
    }
}

@MainActor
@Suite("PDF-Autosave", .serialized)
struct PDFAutosaveTests {
    @Test("Änderungen werden verzögert und beim Flush vollständig gesichert")
    func debounceAndLifecycleFlushPersistEveryDirtyPage() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFAutosave-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFAutosaveSource-\(UUID().uuidString).pdf")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: sourceURL)
        }
        try twoPagePDFData().write(to: sourceURL)
        let store = try DocumentStore(rootURL: rootURL)
        let relativePath = try await store.importPDF(from: sourceURL)
        let viewModel = PDFAnnotationViewModel(
            store: store,
            relativePath: relativePath,
            autosaveDelay: .milliseconds(20)
        )
        await viewModel.load()
        let firstDrawing = testDrawing(offset: 0)
        let secondDrawing = testDrawing(offset: 40)

        viewModel.drawingChanged(pageIndex: 0, drawing: firstDrawing)
        try await Task.sleep(for: .milliseconds(120))
        #expect(try await store.loadPDFDrawings(at: relativePath)[0]
            == firstDrawing.dataRepresentation())
        #expect(!viewModel.hasUnsavedChanges)

        viewModel.drawingChanged(pageIndex: 0, drawing: secondDrawing)
        viewModel.drawingChanged(pageIndex: 1, drawing: firstDrawing)
        #expect(viewModel.hasUnsavedChanges)
        await viewModel.flushAutosaves()
        let stored = try await store.loadPDFDrawings(at: relativePath)
        #expect(stored[0] == secondDrawing.dataRepresentation())
        #expect(stored[1] == firstDrawing.dataRepresentation())
        #expect(!viewModel.hasUnsavedChanges)
        #expect(viewModel.lastSavedAt != nil)
    }

    private func twoPagePDFData() -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            context.cgContext.fill(bounds)
            context.beginPage()
            context.cgContext.fill(bounds)
        }
    }

    private func testDrawing(offset: CGFloat) -> PKDrawing {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 40 + offset, y: 50),
                timeOffset: 0,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            ),
            PKStrokePoint(
                location: CGPoint(x: 140 + offset, y: 150),
                timeOffset: 0.2,
                size: CGSize(width: 4, height: 4),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        ]
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKDrawing(strokes: [
            PKStroke(ink: PKInk(.pen, color: .black), path: path)
        ])
    }
}

@MainActor
@Suite("Fortlaufendes Notizbuch-Layout")
struct ContinuousNotebookLayoutTests {
    @Test("A4- und A3-Seiten bleiben mittig und fließen nach unten")
    func mixedFormatsAreCenteredAndStackedVertically() throws {
        let a4 = makePage(format: .a4)
        let a3 = makePage(format: .a3, orientation: .landscape)
        let layout = ContinuousNotebookLayout(pages: [a4, a3])
        let a4Frame = try #require(layout.pageFrames[a4.id])
        let a3Frame = try #require(layout.pageFrames[a3.id])
        let contentCenter = layout.contentSize.width / 2

        #expect(abs(a4Frame.midX - contentCenter) < 0.001)
        #expect(abs(a3Frame.midX - contentCenter) < 0.001)
        #expect(abs(a3Frame.minY - a4Frame.maxY - ContinuousNotebookLayout.pageSpacing) < 0.001)
        #expect(a3Frame.minY > a4Frame.maxY)
        #expect(
            abs(
                layout.contentSize.width
                    - PaperFormat.a3.pageSize(for: .landscape).width
                    - ContinuousNotebookLayout.horizontalPadding * 2
            ) < 0.001
        )
    }

    @Test("Ein leeres Layout besitzt eine sichere Mindestgröße")
    func emptyLayoutHasSafeSize() {
        let layout = ContinuousNotebookLayout(pages: [])

        #expect(layout.pageFrames.isEmpty)
        #expect(layout.contentSize.width > 0)
        #expect(layout.contentSize.height > 0)
    }

    @Test("Der sichtbare Seitenstapel nutzt die verfügbare Breite symmetrisch")
    func scrollViewFitsAndCentersThePageStack() {
        let pages = [makePage(format: .a4), makePage(format: .a4)]
        let toolController = DrawingToolController()
        let canvasProxy = CanvasProxy()
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: pages.first?.id,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: canvasProxy,
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let scrollView = ContinuousNotebookScrollView(
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600)
        )
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.updateTools(toolController)
        scrollView.layoutIfNeeded()

        let renderedPages = scrollView.documentView.subviews
            .compactMap { $0 as? ContinuousNotebookPageView }
            .sorted { $0.frame.minY < $1.frame.minY }

        #expect(renderedPages.count == 2)
        #expect(abs(scrollView.documentView.frame.midX - scrollView.bounds.midX) < 1)
        #expect(renderedPages[1].frame.minY > renderedPages[0].frame.maxY)
        #expect(scrollView.contentSize.height > scrollView.bounds.height)
    }

    @Test("Große Notizbücher materialisieren nur sichtbare und nahe Seiten")
    func largeNotebooksOnlyMaterializeTheViewportWindow() throws {
        let pages = (0..<100).map { _ in makePage(format: .a4) }
        let toolController = DrawingToolController()
        let canvasProxy = CanvasProxy()
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: pages.first?.id,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: canvasProxy,
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600))
        let scrollView = ContinuousNotebookScrollView(frame: host.bounds)
        host.addSubview(scrollView)
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.updateTools(toolController)
        scrollView.activatePage(try #require(pages.first?.id), canvasProxy: canvasProxy)
        scrollView.layoutIfNeeded()

        #expect(scrollView.materializedPageCount < 10)
        #expect(scrollView.materializedPageIDs.contains(try #require(pages.first?.id)))

        let lastPageID = try #require(pages.last?.id)
        scrollView.activatePage(lastPageID, canvasProxy: canvasProxy)
        scrollView.scrollToPage(lastPageID, animated: false)
        scrollView.layoutIfNeeded()
        scrollView.updateVisiblePages()

        #expect(scrollView.materializedPageIDs.contains(lastPageID))
        #expect(scrollView.materializedPageCount < 10)
        #expect(!scrollView.materializedPageIDs.contains(try #require(pages.first?.id)))
    }

    @Test("Auch 500 Seiten halten das PencilKit-Fenster klein")
    func fiveHundredPagesRemainVirtualized() throws {
        let pages = (0..<500).map { _ in makePage(format: .a4) }
        let firstPageID = try #require(pages.first?.id)
        let middlePageID = pages[249].id
        let lastPageID = try #require(pages.last?.id)
        let toolController = DrawingToolController()
        let canvasProxy = CanvasProxy()
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: firstPageID,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: canvasProxy,
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600))
        let scrollView = ContinuousNotebookScrollView(frame: host.bounds)
        host.addSubview(scrollView)
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.updateTools(toolController)
        scrollView.activatePage(firstPageID, canvasProxy: canvasProxy)
        scrollView.layoutIfNeeded()

        for pageID in [middlePageID, lastPageID] {
            scrollView.activatePage(pageID, canvasProxy: canvasProxy)
            scrollView.scrollToPage(pageID, animated: false)
            scrollView.layoutIfNeeded()
            scrollView.updateVisiblePages()
            #expect(scrollView.materializedPageIDs.contains(pageID))
            #expect(scrollView.materializedPageCount < 10)
        }

        #expect(!scrollView.materializedPageIDs.contains(firstPageID))
    }

    @Test("Speicherdruck gibt Vorlade-Seiten frei und behält die aktive Seite")
    func memoryPressureTrimsPrefetchedPages() throws {
        let pages = (0..<100).map { _ in makePage(format: .a4) }
        let firstPageID = try #require(pages.first?.id)
        let toolController = DrawingToolController()
        let canvasProxy = CanvasProxy()
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: firstPageID,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: canvasProxy,
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600))
        let scrollView = ContinuousNotebookScrollView(frame: host.bounds)
        host.addSubview(scrollView)
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.updateTools(toolController)
        scrollView.activatePage(firstPageID, canvasProxy: canvasProxy)
        scrollView.layoutIfNeeded()
        scrollView.updateVisiblePages()
        let before = scrollView.materializedPageCount

        scrollView.trimForMemoryPressure()

        #expect(scrollView.materializedPageIDs.contains(firstPageID))
        #expect(scrollView.materializedPageCount <= before)
        #expect(scrollView.materializedPageCount < 10)
    }

    @Test("Fingerbedienung wechselt sicher zwischen Zeichnen und Scrollen")
    func fingerOnlyInputPolicyCanBeSwitched() throws {
        let pages = [makePage(format: .a4)]
        let suiteName = "BirdNotesNotebookInputTests-\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let toolController = DrawingToolController(preferences: preferences)
        toolController.fingerDraws = false
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: pages[0].id,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: CanvasProxy(),
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let scrollView = ContinuousNotebookScrollView(
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600)
        )
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.updateTools(toolController)
        let pageView = try #require(
            scrollView.documentView.subviews.compactMap { $0 as? ContinuousNotebookPageView }.first
        )

        #expect(pageView.canvasView.drawingPolicy == .pencilOnly)
        #expect(scrollView.panGestureRecognizer.minimumNumberOfTouches == 1)

        toolController.fingerDraws = true
        scrollView.updateTools(toolController)
        #expect(pageView.canvasView.drawingPolicy == .anyInput)
        #expect(scrollView.panGestureRecognizer.minimumNumberOfTouches == 2)

        toolController.select(.hand)
        scrollView.updateTools(toolController)
        #expect(!pageView.canvasView.drawingGestureRecognizer.isEnabled)
        #expect(scrollView.panGestureRecognizer.minimumNumberOfTouches == 1)
    }

    @Test("VoiceOver-Seiten bieten Vor- und Zurück-Aktionen")
    func pagesExposeAccessibilityNavigationActions() throws {
        let pages = [makePage(format: .a4), makePage(format: .a4), makePage(format: .a4)]
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: pages[1].id,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: DrawingToolController(),
            canvasProxy: CanvasProxy(),
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let scrollView = ContinuousNotebookScrollView(
            frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600)
        )
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.activatePage(pages[1].id, canvasProxy: CanvasProxy())
        let pageView = try #require(
            scrollView.documentView.subviews
                .compactMap { $0 as? ContinuousNotebookPageView }
                .first { $0.pageID == pages[1].id }
        )
        let actionNames = Set((pageView.accessibilityCustomActions ?? []).map(\.name))

        #expect(actionNames == ["Vorherige Seite", "Nächste Seite"])
    }

    @Test("Beim Freigeben einer Seitenansicht bleiben neue Zeichnungsdaten erhalten")
    func recyclingPreservesUpdatedDrawingData() throws {
        let pages = (0..<30).map { _ in makePage(format: .a4) }
        let firstPageID = try #require(pages.first?.id)
        let lastPageID = try #require(pages.last?.id)
        let toolController = DrawingToolController()
        let canvasProxy = CanvasProxy()
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: firstPageID,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: canvasProxy,
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 1_600))
        let scrollView = ContinuousNotebookScrollView(frame: host.bounds)
        host.addSubview(scrollView)
        coordinator.scrollView = scrollView
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.updateTools(toolController)
        scrollView.activatePage(firstPageID, canvasProxy: canvasProxy)
        scrollView.layoutIfNeeded()

        let updatedDrawingData = PKDrawing().dataRepresentation()
        scrollView.rememberDrawingData(updatedDrawingData, for: firstPageID)
        scrollView.activatePage(lastPageID, canvasProxy: canvasProxy)
        scrollView.scrollToPage(lastPageID, animated: false)
        scrollView.layoutIfNeeded()
        scrollView.updateVisiblePages()
        #expect(!scrollView.materializedPageIDs.contains(firstPageID))

        scrollView.activatePage(firstPageID, canvasProxy: canvasProxy)
        let restoredPageView = try #require(
            scrollView.documentView.subviews
                .compactMap { $0 as? ContinuousNotebookPageView }
                .first { $0.pageID == firstPageID }
        )
        #expect(restoredPageView.representedDrawingData == updatedDrawingData)
    }

    @Test("Gerätedrehung passt den Zoom nur bei aktivierter Automatik an")
    func rotationFitCanBeDisabled() {
        let pages = [makePage(format: .a4)]
        let toolController = DrawingToolController()
        let canvas = ContinuousNotebookCanvas(
            pages: pages,
            selectedPageID: pages.first?.id,
            pageNavigationRequestID: nil,
            automaticallyFitsToWidth: true,
            toolController: toolController,
            canvasProxy: CanvasProxy(),
            onPageSelected: { _ in },
            onDrawingChanged: { _, _ in }
        )
        let coordinator = canvas.makeCoordinator()
        let scrollView = ContinuousNotebookScrollView(
            frame: CGRect(x: 0, y: 0, width: 700, height: 1_000)
        )
        scrollView.delegate = coordinator
        scrollView.updatePages(pages, coordinator: coordinator)
        scrollView.layoutIfNeeded()
        let portraitZoom = scrollView.zoomScale

        scrollView.frame.size = CGSize(width: 1_000, height: 700)
        scrollView.layoutIfNeeded()
        let automaticallyFittedZoom = scrollView.zoomScale
        #expect(automaticallyFittedZoom > portraitZoom)

        scrollView.updateAutomaticFit(false)
        scrollView.frame.size = CGSize(width: 700, height: 1_000)
        scrollView.layoutIfNeeded()
        #expect(abs(scrollView.zoomScale - automaticallyFittedZoom) < 0.001)
    }

    @Test("Hoch- und Querformat tauschen die A4-Abmessungen")
    func orientationSwapsPageDimensions() {
        let portrait = makePage(format: .a4, orientation: .portrait)
        let landscape = makePage(format: .a4, orientation: .landscape)

        #expect(portrait.metadata.pageSize.width == landscape.metadata.pageSize.height)
        #expect(portrait.metadata.pageSize.height == landscape.metadata.pageSize.width)
    }

    private func makePage(
        format: PaperFormat,
        orientation: PaperOrientation = .portrait
    ) -> NotebookPage {
        NotebookPage(
            metadata: NotebookPageMetadata(
                paperFormat: format,
                paperOrientation: orientation
            ),
            drawingData: Data()
        )
    }
}

@Suite("Drehungsanpassung des Infinite Canvas")
struct RotationViewportPolicyTests {
    @Test("Breitenanpassung ist beim Zurückdrehen reversibel")
    func widthFitIsReversible() {
        let portrait = CGSize(width: 700, height: 1_000)
        let landscape = CGSize(width: 1_000, height: 700)
        let initialZoom: CGFloat = 0.6

        let landscapeZoom = RotationViewportPolicy.adjustedZoomScale(
            initialZoom,
            from: portrait,
            to: landscape,
            automaticallyFitsWidth: true
        )
        let restoredZoom = RotationViewportPolicy.adjustedZoomScale(
            landscapeZoom,
            from: landscape,
            to: portrait,
            automaticallyFitsWidth: true
        )

        #expect(landscapeZoom > initialZoom)
        #expect(abs(restoredZoom - initialZoom) < 0.000_1)
    }

    @Test("Abgeschaltete Automatik lässt den Canvas-Zoom unverändert")
    func disabledFitKeepsZoom() {
        let zoom = RotationViewportPolicy.adjustedZoomScale(
            0.6,
            from: CGSize(width: 700, height: 1_000),
            to: CGSize(width: 1_000, height: 700),
            automaticallyFitsWidth: false
        )

        #expect(zoom == 0.6)
    }
}

@Suite("Isolierte Performance-Fixtures")
struct PerformanceFixtureTests {
    @Test("Lastargumente werden typisiert und auf sichere Obergrenzen begrenzt")
    func argumentsAreTypedAndClamped() {
        #expect(BirdNotesRuntime.parsePerformanceFixture(arguments: [
            "BirdNotes",
            "--birdnotes-performance-pages=500"
        ]) == .notebookPages(500))
        #expect(BirdNotesRuntime.parsePerformanceFixture(arguments: [
            "--birdnotes-performance-library-items=1000"
        ]) == .libraryItems(1_000))
        #expect(BirdNotesRuntime.parsePerformanceFixture(arguments: [
            "--birdnotes-performance-canvas-elements=20000"
        ]) == .canvasElements(10_000))
        #expect(BirdNotesRuntime.parsePerformanceFixture(arguments: [
            "--birdnotes-performance-pages=ungültig"
        ]) == nil)
    }
}

@Suite("Infinite-Canvas-Virtualisierung")
struct InfiniteCanvasVirtualizationTests {
    @Test("Von 2.000 verteilten Objekten werden nur viewportnahe Views aufgebaut")
    func largeCanvasOnlyProjectsNearbyObjects() {
        let center = CanvasPoint(x: 8_192, y: 8_192)
        let columns = 50
        let elements = (0..<2_000).map { index in
            CanvasElement(
                kind: .shape,
                center: CanvasPoint(
                    x: center.x + Double(index % columns - columns / 2) * 300,
                    y: center.y + Double(index / columns - 20) * 260
                ),
                size: CanvasSize(width: 120, height: 80),
                shapeKind: .rectangle
            )
        }

        let projection = CanvasViewportProjection(
            elements: elements,
            viewport: CanvasViewport(center: center, zoomScale: 0.5),
            viewportSize: CGSize(width: 1_000, height: 800)
        )

        #expect(projection.snapshot.totalElements == 2_000)
        #expect(!projection.visibleElements.isEmpty)
        #expect(projection.visibleElements.count < 100)
        #expect(projection.visibleConnectors.isEmpty)
    }

    @Test("Verbindungen werden einmalig aufgelöst und am Viewport begrenzt")
    func connectorsAreResolvedAndCulled() {
        let center = CanvasPoint(x: 8_192, y: 8_192)
        let left = CanvasElement(
            kind: .shape,
            center: CanvasPoint(x: center.x - 2_000, y: center.y),
            size: CanvasSize(width: 80, height: 80),
            shapeKind: .ellipse
        )
        let right = CanvasElement(
            kind: .shape,
            center: CanvasPoint(x: center.x + 2_000, y: center.y),
            size: CanvasSize(width: 80, height: 80),
            shapeKind: .ellipse
        )
        let upperLeft = CanvasElement(
            kind: .shape,
            center: CanvasPoint(x: center.x - 2_000, y: center.y + 4_000),
            size: CanvasSize(width: 80, height: 80),
            shapeKind: .ellipse
        )
        let upperRight = CanvasElement(
            kind: .shape,
            center: CanvasPoint(x: center.x + 2_000, y: center.y + 4_000),
            size: CanvasSize(width: 80, height: 80),
            shapeKind: .ellipse
        )
        let crossing = CanvasElement(
            kind: .connector,
            center: center,
            size: CanvasSize(width: 1, height: 1),
            sourceElementID: left.id,
            targetElementID: right.id
        )
        let outside = CanvasElement(
            kind: .connector,
            center: center,
            size: CanvasSize(width: 1, height: 1),
            sourceElementID: upperLeft.id,
            targetElementID: upperRight.id
        )

        let projection = CanvasViewportProjection(
            elements: [left, right, upperLeft, upperRight, crossing, outside],
            viewport: CanvasViewport(center: center, zoomScale: 0.5),
            viewportSize: CGSize(width: 1_000, height: 800)
        )

        #expect(projection.visibleElements.isEmpty)
        #expect(projection.visibleConnectors.map(\.id) == [crossing.id])
    }

    @Test("Ungültige Viewportgrößen materialisieren keine Objekte")
    func invalidViewportSizeProjectsNothing() {
        let element = CanvasElement(
            kind: .shape,
            center: CanvasPoint(x: 8_192, y: 8_192),
            size: CanvasSize(width: 100, height: 100),
            shapeKind: .rectangle
        )
        let projection = CanvasViewportProjection(
            elements: [element],
            viewport: CanvasViewport(),
            viewportSize: .zero
        )

        #expect(projection.visibleElements.isEmpty)
        #expect(projection.snapshot.totalElements == 1)
    }
}
