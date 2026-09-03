import Foundation
import os.signpost
import PencilKit
import SwiftUI
import BirdNotesCore

struct PencilPageCanvas: UIViewRepresentable {
    static func pageSize(
        for format: PaperFormat,
        orientation: PaperOrientation = .portrait
    ) -> CGSize {
        format.pageSize(for: orientation)
    }

    @Binding var drawing: PKDrawing
    let pageID: UUID
    let paperStyle: PaperStyle
    let paperFormat: PaperFormat
    let paperOrientation: PaperOrientation
    @ObservedObject var toolController: DrawingToolController
    @ObservedObject var canvasProxy: CanvasProxy
    let onDrawingChanged: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ZoomingPageScrollView {
        let scrollView = ZoomingPageScrollView(
            pageSize: Self.pageSize(for: paperFormat, orientation: paperOrientation)
        )
        scrollView.delegate = context.coordinator
        scrollView.canvasView.delegate = context.coordinator
        scrollView.canvasView.drawing = drawing
        context.coordinator.displayedPageID = pageID
        scrollView.canvasView.drawingPolicy = toolController.fingerDraws ? .anyInput : .pencilOnly
        scrollView.canvasView.tool = toolController.pencilKitTool
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        scrollView.canvasView.addInteraction(pencilInteraction)
        scrollView.panGestureRecognizer.minimumNumberOfTouches = toolController.fingerDraws ? 2 : 1
        scrollView.paperView.paperStyle = paperStyle
        canvasProxy.attach(scrollView.canvasView)
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomingPageScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.updatePageSize(Self.pageSize(for: paperFormat, orientation: paperOrientation))
        scrollView.enforceLightAppearance()
        scrollView.paperView.paperStyle = paperStyle
        scrollView.canvasView.drawingPolicy = toolController.fingerDraws ? .anyInput : .pencilOnly
        scrollView.canvasView.tool = toolController.pencilKitTool
        scrollView.canvasView.drawingGestureRecognizer.isEnabled = toolController.selectedTool != .hand
        scrollView.panGestureRecognizer.minimumNumberOfTouches =
            toolController.fingerDraws && toolController.selectedTool != .hand ? 2 : 1

        let pageChanged = context.coordinator.displayedPageID != pageID
        if pageChanged || scrollView.canvasView.drawing != drawing {
            context.coordinator.isApplyingExternalDrawing = true
            scrollView.canvasView.drawing = drawing
            if pageChanged {
                scrollView.canvasView.undoManager?.removeAllActions()
                context.coordinator.displayedPageID = pageID
            }
            context.coordinator.isApplyingExternalDrawing = false
        }
        if canvasProxy.canvasView !== scrollView.canvasView {
            canvasProxy.attach(scrollView.canvasView)
        }
    }

    static func dismantleUIView(_ scrollView: ZoomingPageScrollView, coordinator: Coordinator) {
        scrollView.canvasView.delegate = nil
        scrollView.delegate = nil
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIScrollViewDelegate, UIPencilInteractionDelegate {
        var parent: PencilPageCanvas
        var isApplyingExternalDrawing = false
        var displayedPageID: UUID?

        init(parent: PencilPageCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            let drawing = canvasView.drawing
            if parent.drawing != drawing { parent.drawing = drawing }
            parent.onDrawingChanged(drawing)
            parent.canvasProxy.objectWillChange.send()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            parent.onDrawingChanged(canvasView.drawing)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomingPageScrollView)?.pageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomingPageScrollView)?.centerPage()
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.toolController.toggleEraserFromPencil()
        }
    }
}

final class ZoomingPageScrollView: UIScrollView {
    let pageView: UIView
    let paperView: PaperBackgroundView
    let canvasView: PKCanvasView
    private var pageSize: CGSize
    private var didApplyInitialZoom = false
    private var lastFittedViewportSize = CGSize.zero

    init(pageSize: CGSize) {
        self.pageSize = pageSize
        pageView = UIView(frame: CGRect(origin: .zero, size: pageSize))
        paperView = PaperBackgroundView(frame: CGRect(origin: .zero, size: pageSize))
        canvasView = PKCanvasView(frame: CGRect(origin: .zero, size: pageSize))
        super.init(frame: .zero)

        enforceLightAppearance()
        minimumZoomScale = 0.2
        maximumZoomScale = 4
        bouncesZoom = true
        delaysContentTouches = false
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .never
        contentSize = pageSize

        pageView.backgroundColor = .white
        pageView.layer.shadowColor = UIColor.black.cgColor
        pageView.layer.shadowOpacity = 0.16
        pageView.layer.shadowRadius = 12
        pageView.layer.shadowOffset = CGSize(width: 0, height: 4)

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.contentSize = pageSize
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1

        pageView.addSubview(paperView)
        pageView.addSubview(canvasView)
        addSubview(pageView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        enforceLightAppearance()
        pageView.frame = CGRect(origin: .zero, size: pageSize)
        paperView.frame = pageView.bounds
        canvasView.frame = pageView.bounds
        canvasView.contentSize = pageSize

        let viewportChanged = abs(bounds.width - lastFittedViewportSize.width) > 1
            || abs(bounds.height - lastFittedViewportSize.height) > 1
        if (!didApplyInitialZoom || viewportChanged), bounds.width > 0, bounds.height > 0 {
            let availableWidth = max(bounds.width - 48, 1)
            let availableHeight = max(bounds.height - 48, 1)
            let fitScale = min(availableWidth / pageSize.width, availableHeight / pageSize.height)
            minimumZoomScale = min(max(fitScale * 0.72, 0.16), fitScale)
            lastFittedViewportSize = bounds.size
            zoomScale = min(max(fitScale, minimumZoomScale), maximumZoomScale)
            didApplyInitialZoom = true
        }
        centerPage()
    }

    func updatePageSize(_ newSize: CGSize) {
        guard pageSize != newSize else { return }
        pageSize = newSize
        contentSize = newSize
        didApplyInitialZoom = false
        lastFittedViewportSize = .zero
        setNeedsLayout()
    }

    func enforceLightAppearance() {
        overrideUserInterfaceStyle = .light
        backgroundColor = UIColor(white: 0.94, alpha: 1)
        pageView.overrideUserInterfaceStyle = .light
        pageView.backgroundColor = .white
        paperView.overrideUserInterfaceStyle = .light
        paperView.backgroundColor = .white
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.backgroundColor = .clear
        indicatorStyle = .black
    }

    func centerPage() {
        let horizontal = max((bounds.width - pageSize.width * zoomScale) / 2, 20)
        let vertical = max((bounds.height - pageSize.height * zoomScale) / 2, 20)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

struct ContinuousNotebookLayout {
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 24
    static let pageSpacing: CGFloat = 30

    let contentSize: CGSize
    let pageFrames: [UUID: CGRect]

    init(pages: [NotebookPage]) {
        let pageSizes = pages.map { ($0.id, $0.metadata.pageSize) }
        let maximumWidth = pageSizes.map(\.1.width).max() ?? PaperFormat.a4.pageSize.width
        let contentWidth = maximumWidth + Self.horizontalPadding * 2
        var y = Self.verticalPadding
        var frames: [UUID: CGRect] = [:]

        for (pageID, pageSize) in pageSizes {
            frames[pageID] = CGRect(
                x: (contentWidth - pageSize.width) / 2,
                y: y,
                width: pageSize.width,
                height: pageSize.height
            )
            y += pageSize.height + Self.pageSpacing
        }

        if !pageSizes.isEmpty {
            y -= Self.pageSpacing
        }
        y += Self.verticalPadding
        contentSize = CGSize(width: contentWidth, height: max(y, 1))
        pageFrames = frames
    }
}

enum NotebookPerformanceDiagnostics {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dominikvogel.BirdNotes",
        category: "PointsOfInterest"
    )

    static func recordViewport(totalPages: Int, materializedPages: Int) {
        os_signpost(
            .event,
            log: log,
            name: "Notebook Viewport",
            "total=%{public}d materialized=%{public}d",
            totalPages,
            materializedPages
        )
    }

    static func recordMemoryPressure(
        totalPages: Int,
        before: Int,
        after: Int
    ) {
        os_signpost(
            .event,
            log: log,
            name: "Notebook Memory Pressure",
            "total=%{public}d before=%{public}d after=%{public}d",
            totalPages,
            before,
            after
        )
    }
}

struct ContinuousNotebookCanvas: UIViewRepresentable {
    let pages: [NotebookPage]
    let selectedPageID: UUID?
    let pageNavigationRequestID: UUID?
    let automaticallyFitsToWidth: Bool
    @ObservedObject var toolController: DrawingToolController
    @ObservedObject var canvasProxy: CanvasProxy
    let onPageSelected: (UUID) -> Void
    let onDrawingChanged: (UUID, PKDrawing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ContinuousNotebookScrollView {
        let scrollView = ContinuousNotebookScrollView()
        scrollView.isAccessibilityElement = false
        scrollView.accessibilityIdentifier = "notebook.canvas"
        context.coordinator.scrollView = scrollView
        scrollView.delegate = context.coordinator
        scrollView.updateAutomaticFit(automaticallyFitsToWidth)
        scrollView.updatePages(pages, coordinator: context.coordinator)
        updateAccessibilityValue(of: scrollView)
        scrollView.updateTools(toolController)
        if let selectedPageID {
            context.coordinator.programmaticScrollTargetPageID = selectedPageID
            scrollView.activatePage(selectedPageID, canvasProxy: canvasProxy)
            DispatchQueue.main.async {
                scrollView.scrollToPage(selectedPageID, animated: false)
            }
        }
        return scrollView
    }

    func updateUIView(_ scrollView: ContinuousNotebookScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.updateAutomaticFit(automaticallyFitsToWidth)
        scrollView.updatePages(pages, coordinator: context.coordinator)
        updateAccessibilityValue(of: scrollView)
        scrollView.updateTools(toolController)
        if let selectedPageID {
            let hasNewNavigationRequest =
                context.coordinator.handledPageNavigationRequestID != pageNavigationRequestID
            context.coordinator.handledPageNavigationRequestID = pageNavigationRequestID
            let selectedPageIsNotCentered =
                scrollView.pageNearestVisibleCenter() != selectedPageID
            if hasNewNavigationRequest || selectedPageIsNotCentered {
                context.coordinator.programmaticScrollTargetPageID = selectedPageID
                scrollView.activatePage(selectedPageID, canvasProxy: canvasProxy)
                scrollView.scrollToPage(selectedPageID, animated: false)
            } else {
                scrollView.activatePage(selectedPageID, canvasProxy: canvasProxy)
            }
        }
    }

    private func updateAccessibilityValue(of scrollView: ContinuousNotebookScrollView) {
        if let selectedPageID,
           let selectedIndex = pages.firstIndex(where: { $0.id == selectedPageID }) {
            scrollView.accessibilityLabel =
                "Notizbuchseiten, Seite \(selectedIndex + 1) von \(pages.count)"
        } else {
            scrollView.accessibilityLabel = "Notizbuchseiten"
        }

        guard let selectedPageID,
              let selectedPage = pages.first(where: { $0.id == selectedPageID }),
              !selectedPage.drawingData.isEmpty,
              let drawing = try? PKDrawing(data: selectedPage.drawingData),
              !drawing.strokes.isEmpty else {
            scrollView.accessibilityValue = "Leer"
            return
        }
        let strokeCount = drawing.strokes.count
        scrollView.accessibilityValue = strokeCount == 1
            ? "1 Strich"
            : "\(strokeCount) Striche"
    }

    static func dismantleUIView(
        _ scrollView: ContinuousNotebookScrollView,
        coordinator: Coordinator
    ) {
        scrollView.delegate = nil
        scrollView.detachCanvasDelegates()
        coordinator.scrollView = nil
    }

    final class Coordinator: NSObject,
        PKCanvasViewDelegate,
        UIScrollViewDelegate,
        UIPencilInteractionDelegate,
        UIGestureRecognizerDelegate {
        var parent: ContinuousNotebookCanvas
        weak var scrollView: ContinuousNotebookScrollView?
        var applyingExternalDrawingPageIDs = Set<UUID>()
        var programmaticScrollTargetPageID: UUID?
        var handledPageNavigationRequestID: UUID?

        init(parent: ContinuousNotebookCanvas) {
            self.parent = parent
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            activate(canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard let scrollView,
                  let pageID = scrollView.pageID(for: canvasView),
                  !applyingExternalDrawingPageIDs.contains(pageID) else { return }
            let drawing = canvasView.drawing
            scrollView.rememberDrawingData(drawing.dataRepresentation(), for: pageID)
            scrollView.activatePage(pageID, canvasProxy: parent.canvasProxy)
            publishSelection(pageID)
            parent.onDrawingChanged(pageID, drawing)
            parent.canvasProxy.refresh()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard let scrollView,
                  let pageID = scrollView.pageID(for: canvasView),
                  !applyingExternalDrawingPageIDs.contains(pageID) else { return }
            parent.onDrawingChanged(pageID, canvasView.drawing)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ContinuousNotebookScrollView)?.documentView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let notebookScrollView = scrollView as? ContinuousNotebookScrollView else {
                return
            }
            notebookScrollView.centerDocumentHorizontally()
            notebookScrollView.updateVisiblePages()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let notebookScrollView = scrollView as? ContinuousNotebookScrollView else {
                return
            }
            notebookScrollView.updateVisiblePages()
            guard !notebookScrollView.isUpdatingDocumentGeometry,
                  !scrollView.isZooming,
                  let pageID = notebookScrollView.pageNearestVisibleCenter() else { return }

            if let targetPageID = programmaticScrollTargetPageID {
                notebookScrollView.activatePage(targetPageID, canvasProxy: parent.canvasProxy)
                if pageID == targetPageID {
                    programmaticScrollTargetPageID = nil
                }
                return
            }

            notebookScrollView.activatePage(pageID, canvasProxy: parent.canvasProxy)
            publishSelection(pageID)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            programmaticScrollTargetPageID = nil
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.toolController.toggleEraserFromPencil()
        }

        @objc func pageTapped(_ recognizer: UITapGestureRecognizer) {
            guard let pageView = recognizer.view as? ContinuousNotebookPageView,
                  let scrollView else { return }
            scrollView.activatePage(pageView.pageID, canvasProxy: parent.canvasProxy)
            publishSelection(pageView.pageID)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func activate(_ canvasView: PKCanvasView) {
            guard let scrollView,
                  let pageID = scrollView.pageID(for: canvasView) else { return }
            scrollView.activatePage(pageID, canvasProxy: parent.canvasProxy)
            publishSelection(pageID)
        }

        func publishSelection(_ pageID: UUID) {
            guard parent.selectedPageID != pageID else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.selectedPageID != pageID else { return }
                self.parent.onPageSelected(pageID)
            }
        }
    }
}

final class ContinuousNotebookScrollView: UIScrollView {
    let documentView = UIView()
    private var pageViews: [UUID: ContinuousNotebookPageView] = [:]
    private var pageSnapshots: [UUID: NotebookPage] = [:]
    private var pageOrder: [UUID] = []
    private var notebookLayout = ContinuousNotebookLayout(pages: [])
    private weak var canvasCoordinator: ContinuousNotebookCanvas.Coordinator?
    private weak var currentToolController: DrawingToolController?
    private weak var currentCanvasProxy: CanvasProxy?
    private var didApplyInitialZoom = false
    private var lastFittedWidth: CGFloat = 0
    private var lastReportedMaterialization: (total: Int, materialized: Int)?
    private(set) var automaticallyFitsToWidth = true
    private let toolbarClearance: CGFloat = 82
    private let verticalPrefetchScreens: CGFloat = 0.75
    private(set) var activePageID: UUID?
    private(set) var isUpdatingDocumentGeometry = false

    var materializedPageCount: Int { pageViews.count }
    var materializedPageIDs: Set<UUID> { Set(pageViews.keys) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        overrideUserInterfaceStyle = .light
        backgroundColor = UIColor(white: 0.94, alpha: 1)
        indicatorStyle = .black
        minimumZoomScale = 0.2
        maximumZoomScale = 4
        bouncesZoom = true
        alwaysBounceVertical = true
        delaysContentTouches = false
        contentInsetAdjustmentBehavior = .never
        documentView.backgroundColor = .clear
        addSubview(documentView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receivedMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for pageID in pageOrder {
            pageViews[pageID]?.frame = notebookLayout.pageFrames[pageID] ?? .zero
        }

        let widthChanged = abs(bounds.width - lastFittedWidth) > 1
        if (!didApplyInitialZoom || (widthChanged && automaticallyFitsToWidth)), bounds.width > 0 {
            let fitScale = min(bounds.width / max(notebookLayout.contentSize.width, 1), 1.25)
            minimumZoomScale = max(min(fitScale * 0.7, fitScale), 0.16)
            zoomScale = min(max(fitScale, minimumZoomScale), maximumZoomScale)
            didApplyInitialZoom = true
        }
        lastFittedWidth = bounds.width
        centerDocumentHorizontally()
        updateVisiblePages()
    }

    func updateAutomaticFit(_ enabled: Bool) {
        guard automaticallyFitsToWidth != enabled else { return }
        automaticallyFitsToWidth = enabled
        if enabled {
            didApplyInitialZoom = false
            setNeedsLayout()
        }
    }

    func updatePages(
        _ pages: [NotebookPage],
        coordinator: ContinuousNotebookCanvas.Coordinator
    ) {
        canvasCoordinator = coordinator
        let incomingIDs = Set(pages.map(\.id))
        let removedPageViews = pageViews.filter { !incomingIDs.contains($0.key) }
        for (pageID, pageView) in removedPageViews {
            recyclePageView(pageView, pageID: pageID)
        }
        if let activePageID, !incomingIDs.contains(activePageID) {
            self.activePageID = nil
        }

        pageSnapshots.removeAll(keepingCapacity: true)
        for page in pages {
            pageSnapshots[page.id] = page
        }

        let newLayout = ContinuousNotebookLayout(pages: pages)
        let documentSizeChanged = notebookLayout.contentSize != newLayout.contentSize
        if notebookLayout.contentSize.width != newLayout.contentSize.width {
            didApplyInitialZoom = false
        }
        pageOrder = pages.map(\.id)
        if documentSizeChanged {
            applyDocumentLayout(newLayout)
        } else {
            notebookLayout = newLayout
            applyPageFrames()
        }
        refreshMaterializedPages()
        updateVisiblePages()
        reportMaterializationIfNeeded()
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func applyDocumentLayout(_ newLayout: ContinuousNotebookLayout) {
        let anchorOrigin = activePageID
            .flatMap { pageViews[$0] }
            .map { $0.convert($0.bounds, to: self).origin }
        let preservedZoomScale = zoomScale

        isUpdatingDocumentGeometry = true
        if abs(zoomScale - 1) > 0.001 {
            setZoomScale(1, animated: false)
        }
        notebookLayout = newLayout
        documentView.frame = CGRect(origin: .zero, size: newLayout.contentSize)
        contentSize = newLayout.contentSize
        applyPageFrames()
        if abs(preservedZoomScale - 1) > 0.001 {
            setZoomScale(
                min(max(preservedZoomScale, minimumZoomScale), maximumZoomScale),
                animated: false
            )
        }
        layoutIfNeeded()

        if let activePageID,
           let anchorOrigin,
           let pageView = pageViews[activePageID] {
            let updatedOrigin = pageView.convert(pageView.bounds, to: self).origin
            setContentOffset(
                CGPoint(
                    x: contentOffset.x + updatedOrigin.x - anchorOrigin.x,
                    y: contentOffset.y + updatedOrigin.y - anchorOrigin.y
                ),
                animated: false
            )
        }
        isUpdatingDocumentGeometry = false
        updateVisiblePages()
    }

    private func applyPageFrames() {
        for pageID in pageOrder {
            pageViews[pageID]?.frame = notebookLayout.pageFrames[pageID] ?? .zero
        }
    }

    func updateTools(_ controller: DrawingToolController) {
        currentToolController = controller
        panGestureRecognizer.minimumNumberOfTouches =
            controller.fingerDraws && controller.selectedTool != .hand ? 2 : 1
        for pageView in pageViews.values {
            applyTools(controller, to: pageView)
        }
    }

    func activatePage(_ pageID: UUID, canvasProxy: CanvasProxy) {
        guard pageSnapshots[pageID] != nil,
              let pageView = materializePageIfNeeded(pageID) else { return }
        currentCanvasProxy = canvasProxy
        activePageID = pageID
        for (candidateID, candidateView) in pageViews {
            candidateView.setActive(candidateID == pageID)
        }
        if canvasProxy.canvasView !== pageView.canvasView {
            canvasProxy.attach(pageView.canvasView)
        }
        updateVisiblePages()
    }

    func pageID(for canvasView: PKCanvasView) -> UUID? {
        pageViews.first(where: { $0.value.canvasView === canvasView })?.key
    }

    func rememberDrawingData(_ data: Data, for pageID: UUID) {
        if var page = pageSnapshots[pageID] {
            page.drawingData = data
            pageSnapshots[pageID] = page
        }
        pageViews[pageID]?.rememberDrawingData(data)
    }

    func pageNearestVisibleCenter() -> UUID? {
        guard !pageOrder.isEmpty else { return nil }
        let viewportCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let centerInDocument = convert(viewportCenter, to: documentView)
        return pageOrder.min { lhs, rhs in
            let leftDistance = abs((notebookLayout.pageFrames[lhs]?.midY ?? 0) - centerInDocument.y)
            let rightDistance = abs((notebookLayout.pageFrames[rhs]?.midY ?? 0) - centerInDocument.y)
            return leftDistance < rightDistance
        }
    }

    func scrollToPage(_ pageID: UUID, animated: Bool) {
        guard let pageView = materializePageIfNeeded(pageID),
              let viewportContainer = superview else { return }
        layoutIfNeeded()
        let visiblePageFrame = pageView.convert(pageView.bounds, to: viewportContainer)
        let desiredOrigin = CGPoint(
            x: frame.minX + max((bounds.width - visiblePageFrame.width) / 2, 0),
            y: frame.minY + toolbarClearance + 12
        )
        let targetOffset = CGPoint(
            x: contentOffset.x + visiblePageFrame.minX - desiredOrigin.x,
            y: contentOffset.y + visiblePageFrame.minY - desiredOrigin.y
        )
        setContentOffset(targetOffset, animated: animated)
        updateVisiblePages()
    }

    func centerDocumentHorizontally() {
        let horizontal = max((bounds.width - notebookLayout.contentSize.width * zoomScale) / 2, 0)
        contentInset = UIEdgeInsets(
            top: toolbarClearance,
            left: horizontal,
            bottom: 30,
            right: horizontal
        )
    }

    func detachCanvasDelegates() {
        for pageView in pageViews.values {
            pageView.canvasView.delegate = nil
        }
    }

    func updateVisiblePages() {
        guard !isUpdatingDocumentGeometry,
              !pageOrder.isEmpty,
              bounds.width > 0,
              bounds.height > 0 else { return }

        let visibleRect = convert(bounds, to: documentView)
        let verticalPrefetch = max(
            visibleRect.height * verticalPrefetchScreens,
            ContinuousNotebookLayout.pageSpacing
        )
        let prefetchRect = visibleRect.insetBy(dx: 0, dy: -verticalPrefetch)
        var requiredPageIDs = Set(
            pageOrder.filter { pageID in
                notebookLayout.pageFrames[pageID]?.intersects(prefetchRect) == true
            }
        )
        if let activePageID {
            requiredPageIDs.insert(activePageID)
        }
        if requiredPageIDs.isEmpty, let nearestPageID = pageNearestVisibleCenter() {
            requiredPageIDs.insert(nearestPageID)
        }

        for pageID in pageOrder where requiredPageIDs.contains(pageID) {
            _ = materializePageIfNeeded(pageID)
        }
        let recyclablePageViews = pageViews.filter { !requiredPageIDs.contains($0.key) }
        for (pageID, pageView) in recyclablePageViews {
            recyclePageView(pageView, pageID: pageID)
        }
        reportMaterializationIfNeeded()
    }

    @objc private func receivedMemoryWarning() {
        trimForMemoryPressure()
    }

    func trimForMemoryPressure() {
        guard !pageViews.isEmpty else { return }
        let before = pageViews.count
        let visibleRect = convert(bounds, to: documentView)
        var retainedPageIDs = Set(pageOrder.filter { pageID in
            notebookLayout.pageFrames[pageID]?.intersects(visibleRect) == true
        })
        if let activePageID {
            retainedPageIDs.insert(activePageID)
        }
        if retainedPageIDs.isEmpty, let nearestPageID = pageNearestVisibleCenter() {
            retainedPageIDs.insert(nearestPageID)
        }

        let recyclablePageViews = pageViews.filter { !retainedPageIDs.contains($0.key) }
        for (pageID, pageView) in recyclablePageViews {
            recyclePageView(pageView, pageID: pageID)
        }
        NotebookPerformanceDiagnostics.recordMemoryPressure(
            totalPages: pageOrder.count,
            before: before,
            after: pageViews.count
        )
        reportMaterializationIfNeeded()
    }

    private func materializePageIfNeeded(_ pageID: UUID) -> ContinuousNotebookPageView? {
        if let pageView = pageViews[pageID] {
            return pageView
        }
        guard let page = pageSnapshots[pageID],
              let coordinator = canvasCoordinator else { return nil }

        let pageView = ContinuousNotebookPageView(pageID: pageID)
        pageView.canvasView.delegate = coordinator
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = coordinator
        pageView.canvasView.addInteraction(pencilInteraction)
        let tap = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(ContinuousNotebookCanvas.Coordinator.pageTapped(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = coordinator
        pageView.addGestureRecognizer(tap)
        documentView.addSubview(pageView)
        pageViews[pageID] = pageView
        apply(page, to: pageView)
        pageView.frame = notebookLayout.pageFrames[pageID] ?? .zero
        if let controller = currentToolController {
            applyTools(controller, to: pageView)
        }
        pageView.setActive(pageID == activePageID)
        return pageView
    }

    private func refreshMaterializedPages() {
        for pageID in pageOrder {
            guard let page = pageSnapshots[pageID],
                  let pageView = pageViews[pageID] else { continue }
            apply(page, to: pageView)
        }
    }

    private func apply(_ page: NotebookPage, to pageView: ContinuousNotebookPageView) {
        guard let coordinator = canvasCoordinator else { return }
        coordinator.applyingExternalDrawingPageIDs.insert(page.id)
        pageView.apply(page)
        coordinator.applyingExternalDrawingPageIDs.remove(page.id)
        if let index = pageOrder.firstIndex(of: page.id) {
            pageView.updateAccessibility(position: index + 1, total: pageOrder.count)
            pageView.accessibilityCustomActions = accessibilityActions(for: index)
        }
    }

    private func accessibilityActions(for pageIndex: Int) -> [UIAccessibilityCustomAction] {
        var actions: [UIAccessibilityCustomAction] = []
        if pageIndex > 0 {
            let previousPageID = pageOrder[pageIndex - 1]
            actions.append(UIAccessibilityCustomAction(
                name: "Vorherige Seite",
                actionHandler: { [weak self] _ in
                    self?.selectPageForAccessibility(previousPageID) ?? false
                }
            ))
        }
        if pageIndex + 1 < pageOrder.count {
            let nextPageID = pageOrder[pageIndex + 1]
            actions.append(UIAccessibilityCustomAction(
                name: "Nächste Seite",
                actionHandler: { [weak self] _ in
                    self?.selectPageForAccessibility(nextPageID) ?? false
                }
            ))
        }
        return actions
    }

    private func selectPageForAccessibility(_ pageID: UUID) -> Bool {
        guard let canvasProxy = currentCanvasProxy,
              let coordinator = canvasCoordinator,
              let index = pageOrder.firstIndex(of: pageID) else { return false }
        activatePage(pageID, canvasProxy: canvasProxy)
        scrollToPage(pageID, animated: false)
        coordinator.publishSelection(pageID)
        UIAccessibility.post(
            notification: .pageScrolled,
            argument: "Seite \(index + 1) von \(pageOrder.count)"
        )
        return true
    }

    private func applyTools(
        _ controller: DrawingToolController,
        to pageView: ContinuousNotebookPageView
    ) {
        let canvas = pageView.canvasView
        canvas.drawingPolicy = controller.fingerDraws ? .anyInput : .pencilOnly
        canvas.tool = controller.pencilKitTool
        canvas.drawingGestureRecognizer.isEnabled = controller.selectedTool != .hand
    }

    private func recyclePageView(
        _ pageView: ContinuousNotebookPageView,
        pageID: UUID
    ) {
        pageView.canvasView.delegate = nil
        pageView.canvasView.undoManager?.removeAllActions()
        pageView.accessibilityCustomActions = nil
        pageView.removeFromSuperview()
        pageViews[pageID] = nil
    }

    private func reportMaterializationIfNeeded() {
        let current = (total: pageOrder.count, materialized: pageViews.count)
        guard lastReportedMaterialization?.total != current.total
                || lastReportedMaterialization?.materialized != current.materialized else { return }
        lastReportedMaterialization = current
        NotebookPerformanceDiagnostics.recordViewport(
            totalPages: current.total,
            materializedPages: current.materialized
        )
    }
}

final class ContinuousNotebookPageView: UIView {
    let pageID: UUID
    let paperView = PaperBackgroundView()
    let canvasView = PKCanvasView()
    var representedDrawingData = Data()
    private var pageSize = PaperFormat.a4.pageSize

    init(pageID: UUID) {
        self.pageID = pageID
        super.init(frame: .zero)
        overrideUserInterfaceStyle = .light
        backgroundColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 5)

        paperView.overrideUserInterfaceStyle = .light
        paperView.backgroundColor = .white
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1
        addSubview(paperView)
        addSubview(canvasView)
        isAccessibilityElement = true
        accessibilityLabel = "Notizbuchseite"
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        paperView.frame = bounds
        canvasView.frame = bounds
        canvasView.contentSize = pageSize
    }

    func apply(_ page: NotebookPage) {
        pageSize = page.metadata.pageSize
        paperView.paperStyle = page.metadata.paperStyle
        if representedDrawingData != page.drawingData {
            representedDrawingData = page.drawingData
            canvasView.drawing = (try? PKDrawing(data: page.drawingData)) ?? PKDrawing()
            canvasView.undoManager?.removeAllActions()
        }
        updateAccessibilityValue()
        setNeedsLayout()
    }

    func rememberDrawingData(_ data: Data) {
        representedDrawingData = data
        updateAccessibilityValue()
    }

    func updateAccessibility(position: Int, total: Int) {
        accessibilityIdentifier = "notebook.pageCanvas.\(position)"
        accessibilityLabel = "Notizbuchseite \(position) von \(total)"
        updateAccessibilityValue()
    }

    private func updateAccessibilityValue() {
        let strokeCount = canvasView.drawing.strokes.count
        if strokeCount == 0 {
            accessibilityValue = "Leer"
        } else if strokeCount == 1 {
            accessibilityValue = "1 Strich"
        } else {
            accessibilityValue = "\(strokeCount) Striche"
        }
    }

    func setActive(_ isActive: Bool) {
        layer.borderColor = isActive
            ? UIColor(red: 0.05, green: 0.42, blue: 0.78, alpha: 0.65).cgColor
            : nil
        layer.borderWidth = isActive ? 2 / max(window?.screen.scale ?? 2, 1) : 0
    }
}
