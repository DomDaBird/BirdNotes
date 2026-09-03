import Foundation
import PDFKit
import PencilKit
import UIKit
import BirdNotesCore

final class LibraryRootMonitor: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    var onChange: (() -> Void)?
    private var pendingChange: DispatchWorkItem?

    init(url: URL) {
        presentedItemURL = url
        let queue = OperationQueue()
        queue.name = "BirdNotes library presenter"
        queue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue = queue
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
        pendingChange?.cancel()
    }

    func presentedItemDidChange() { scheduleChange() }
    func presentedSubitemDidAppear(at url: URL) { scheduleChange() }
    func presentedSubitemDidChange(at url: URL) { scheduleChange() }
    func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) { scheduleChange() }
    func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping @Sendable (Error?) -> Void) {
        scheduleChange()
        completionHandler(nil)
    }

    private func scheduleChange() {
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        pendingChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

enum LibraryThumbnailCache {
    static func image(for item: BirdNotesCore.LibraryItem, store: DocumentStore) async -> UIImage? {
        guard item.kind != .folder else { return nil }
        let cacheURL = cachedURL(for: item, rootURL: store.rootURL)
        if let image = UIImage(contentsOfFile: cacheURL.path) { return image }

        let image: UIImage?
        do {
            switch item.kind {
            case .notebook:
                let notebook = try await store.loadNotebook(at: item.relativePath)
                image = notebook.pages.first.flatMap(renderNotebookPage)
            case .pdf:
                let url = try await store.itemURL(for: item.relativePath)
                image = PDFDocument(url: url)?.page(at: 0)?.thumbnail(
                    of: CGSize(width: 480, height: 360),
                    for: .cropBox
                )
            case .infiniteCanvas:
                let canvas = try await store.loadInfiniteCanvas(at: item.relativePath)
                image = renderCanvas(canvas)
            case .technicalDiagram:
                image = nil
            case .folder:
                image = nil
            }
        } catch {
            return nil
        }

        if let data = image?.jpegData(compressionQuality: 0.82) {
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: cacheURL, options: .atomic)
        }
        return image
    }

    private static func renderNotebookPage(_ page: NotebookPage) -> UIImage? {
        let size = page.metadata.pageSize
        let target = CGSize(width: 480, height: 480 * size.height / size.width)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            drawPaper(style: page.metadata.paperStyle, in: context.cgContext, size: target)
            guard let drawing = try? PKDrawing(data: page.drawingData), !drawing.strokes.isEmpty else { return }
            drawing.image(from: CGRect(origin: .zero, size: size), scale: 0.5)
                .draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func renderCanvas(_ document: InfiniteCanvasDocument) -> UIImage? {
        let size = CGSize(width: 480, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.withAlphaComponent(0.08).setFill()
            for x in stride(from: 12, to: Int(size.width), by: 20) {
                for y in stride(from: 12, to: Int(size.height), by: 20) {
                    context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
            guard let drawing = try? PKDrawing(data: document.drawingData), !drawing.strokes.isEmpty else { return }
            let bounds = drawing.bounds.insetBy(dx: -30, dy: -30)
            drawing.image(from: bounds, scale: 0.5)
                .draw(in: CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10))
        }
    }

    private static func drawPaper(style: PaperStyle, in context: CGContext, size: CGSize) {
        guard style != .blank else { return }
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(0.6)
        let spacing: CGFloat = 16
        if style == .dotted {
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.20).cgColor)
            for x in stride(from: spacing, to: size.width, by: spacing) {
                for y in stride(from: spacing, to: size.height, by: spacing) {
                    context.fillEllipse(in: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4))
                }
            }
            return
        }
        let summaryTop = style == .cornell ? size.height * 0.82 : size.height
        for y in stride(from: spacing, to: summaryTop, by: spacing) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: size.width, y: y))
        }
        if style == .grid {
            for x in stride(from: spacing, to: size.width, by: spacing) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: size.height))
            }
        } else if style == .cornell {
            context.move(to: CGPoint(x: size.width * 0.28, y: 0))
            context.addLine(to: CGPoint(x: size.width * 0.28, y: summaryTop))
            context.move(to: CGPoint(x: 0, y: summaryTop))
            context.addLine(to: CGPoint(x: size.width, y: summaryTop))
        }
        context.strokePath()
    }

    private static func cachedURL(for item: BirdNotesCore.LibraryItem, rootURL: URL) -> URL {
        let key = "\(rootURL.path)|\(item.relativePath)|\(item.modifiedAt.timeIntervalSince1970)"
        let hash = key.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("BirdNotes/Thumbnails", isDirectory: true)
            .appendingPathComponent(String(hash, radix: 16))
            .appendingPathExtension("jpg")
    }
}
