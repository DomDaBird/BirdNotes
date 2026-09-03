import Combine
import Foundation
import PencilKit
import SwiftUI
import UIKit
import Vision
import BirdNotesCore

@MainActor
final class NotebookViewModel: ObservableObject {
    @Published private(set) var document: NotebookDocument?
    @Published var selectedPageID: UUID?
    @Published var currentDrawing = PKDrawing()
    @Published var errorMessage: String?
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published private(set) var hasUnsavedChanges = false
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var isRecognizingHandwriting = false

    let store: DocumentStore
    let relativePath: String

    private var saveTasks: [UUID: Task<Void, Never>] = [:]
    private var dirtyPageIDs = Set<UUID>()
    private var activeSaveCount = 0
    private let autosaveDelay: Duration = .milliseconds(800)

    init(store: DocumentStore, relativePath: String, initialPageID: UUID? = nil) {
        self.store = store
        self.relativePath = relativePath
        selectedPageID = initialPageID
    }

    var pages: [NotebookPage] { document?.pages ?? [] }

    var currentPage: NotebookPage? {
        guard let selectedPageID else { return nil }
        return document?.pages.first { $0.id == selectedPageID }
    }

    var title: String { document?.manifest.title ?? "Notizbuch" }

    var pagePositionText: String {
        guard let selectedPageID,
              let index = pages.firstIndex(where: { $0.id == selectedPageID }) else {
            return ""
        }
        return "Seite \(index + 1) von \(pages.count)"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await store.loadNotebook(at: relativePath)
            document = loaded
            dirtyPageIDs.removeAll()
            hasUnsavedChanges = false
            let initialPageID = selectedPageID.flatMap { selected in
                loaded.pages.contains(where: { $0.id == selected }) ? selected : nil
            } ?? loaded.pages.first?.id
            selectPageWithoutSaving(initialPageID)
        } catch {
            present(error)
        }
    }

    func selectPage(_ pageID: UUID) {
        guard pageID != selectedPageID else { return }
        selectPageWithoutSaving(pageID)
    }

    func drawingChanged(_ drawing: PKDrawing) {
        guard let pageID = selectedPageID else { return }
        drawingChanged(drawing, for: pageID)
    }

    func drawingChanged(_ drawing: PKDrawing, for pageID: UUID) {
        guard var document,
              let index = document.pages.firstIndex(where: { $0.id == pageID }) else { return }

        let data = drawing.dataRepresentation()
        let hasContent = !drawing.strokes.isEmpty
        let wasEmpty = document.pages[index].metadata.isEmpty
        let wasTrailing = index == document.pages.count - 1

        document.pages[index].drawingData = data
        document.pages[index].metadata.isEmpty = !hasContent
        document.pages[index].metadata.modifiedAt = Date()
        self.document = document
        selectedPageID = pageID
        currentDrawing = drawing
        dirtyPageIDs.insert(pageID)
        hasUnsavedChanges = true

        if hasContent && wasEmpty && wasTrailing {
            saveTasks[pageID]?.cancel()
            saveTasks[pageID] = Task { [weak self] in
                await self?.persist(pageID: pageID, drawingData: data, hasContent: true)
            }
        } else {
            scheduleAutosave(pageID: pageID, drawingData: data, hasContent: hasContent)
        }
    }

    func addPage(
        paperStyle: PaperStyle? = nil,
        paperFormat: PaperFormat? = nil,
        paperOrientation: PaperOrientation? = nil
    ) async {
        await flushAutosaves()
        do {
            let inheritedStyle = paperStyle ?? currentPage?.metadata.paperStyle ?? .blank
            let inheritedFormat = paperFormat ?? currentPage?.metadata.paperFormat ?? .a4
            let inheritedOrientation = paperOrientation
                ?? currentPage?.metadata.paperOrientation
                ?? .portrait
            let page = try await store.addPage(
                toNotebookAt: relativePath,
                paperStyle: inheritedStyle,
                paperFormat: inheritedFormat,
                paperOrientation: inheritedOrientation
            )
            lastSavedAt = Date()
            await reloadSelecting(page.id)
        } catch {
            present(error)
        }
    }

    func duplicateCurrentPage() async {
        guard let selectedPageID else { return }
        await flushAutosaves()
        do {
            let page = try await store.duplicatePage(selectedPageID, inNotebookAt: relativePath)
            lastSavedAt = Date()
            await reloadSelecting(page.id)
        } catch {
            present(error)
        }
    }

    func deleteCurrentPage() async {
        guard let selectedPageID,
              let index = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        await flushAutosaves()
        do {
            try await store.deletePage(selectedPageID, fromNotebookAt: relativePath)
            lastSavedAt = Date()
            let nextIndex = max(0, min(index, pages.count - 2))
            let nextID = pages.enumerated()
                .filter { $0.element.id != selectedPageID }
                .map(\.element.id)[safe: nextIndex]
            await reloadSelecting(nextID)
        } catch {
            present(error)
            await reloadSelecting(nil)
        }
    }

    func setPaperStyle(_ style: PaperStyle) async {
        guard let selectedPageID else { return }
        do {
            try await store.updatePaperStyle(style, for: selectedPageID, inNotebookAt: relativePath)
            lastSavedAt = Date()
            if var document,
               let index = document.pages.firstIndex(where: { $0.id == selectedPageID }) {
                document.pages[index].metadata.paperStyle = style
                self.document = document
            }
        } catch {
            present(error)
        }
    }

    func setPaperFormat(_ format: PaperFormat) async {
        guard let selectedPageID else { return }
        await flushAutosaves()
        do {
            try await store.updatePaperFormat(
                format,
                for: selectedPageID,
                inNotebookAt: relativePath
            )
            lastSavedAt = Date()
            if var document,
               let index = document.pages.firstIndex(where: { $0.id == selectedPageID }) {
                document.pages[index].metadata.paperFormat = format
                self.document = document
            }
        } catch {
            present(error)
        }
    }

    func togglePaperOrientation() async {
        let current = currentPage?.metadata.paperOrientation ?? .portrait
        await setPaperOrientation(current == .portrait ? .landscape : .portrait)
    }

    func setPaperOrientation(_ orientation: PaperOrientation) async {
        guard let selectedPageID,
              currentPage?.metadata.paperOrientation != orientation else { return }
        await flushAutosaves()
        do {
            try await store.updatePaperOrientation(
                orientation,
                for: selectedPageID,
                inNotebookAt: relativePath
            )
            lastSavedAt = Date()
            if var document,
               let index = document.pages.firstIndex(where: { $0.id == selectedPageID }) {
                document.pages[index].metadata.paperOrientation = orientation
                self.document = document
            }
        } catch {
            present(error)
        }
    }

    func toggleCurrentPageBookmark() async {
        guard let selectedPageID,
              let currentPage else { return }
        do {
            let newValue = !currentPage.metadata.isBookmarked
            try await store.updatePageBookmark(
                newValue,
                for: selectedPageID,
                inNotebookAt: relativePath
            )
            lastSavedAt = Date()
            if var document,
               let index = document.pages.firstIndex(where: { $0.id == selectedPageID }) {
                document.pages[index].metadata.isBookmarked = newValue
                self.document = document
            }
        } catch {
            present(error)
        }
    }

    func recognizeCurrentPage() async -> String? {
        guard let currentPage else { return nil }
        guard !currentDrawing.strokes.isEmpty else {
            present(DocumentStoreError.fileOperationFailed(
                "Auf dieser Seite wurde noch keine Handschrift gefunden."
            ))
            return nil
        }
        await flushAutosaves()
        isRecognizingHandwriting = true
        defer { isRecognizingHandwriting = false }
        do {
            let text = try await HandwritingRecognitionService.recognize(
                drawing: currentDrawing,
                paperFormat: currentPage.metadata.paperFormat,
                paperOrientation: currentPage.metadata.paperOrientation
            )
            guard !text.isEmpty else {
                throw DocumentStoreError.fileOperationFailed(
                    "Die Handschrift konnte nicht sicher als Text erkannt werden."
                )
            }
            return text
        } catch {
            present(error)
            return nil
        }
    }

    func saveTranscription(_ text: String?) async {
        guard let selectedPageID else { return }
        do {
            try await store.updatePageTranscription(
                text,
                for: selectedPageID,
                inNotebookAt: relativePath
            )
            if var document,
               let index = document.pages.firstIndex(where: { $0.id == selectedPageID }) {
                let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines)
                document.pages[index].metadata.transcribedText = normalized?.isEmpty == false
                    ? normalized
                    : nil
                self.document = document
            }
            lastSavedAt = Date()
        } catch {
            present(error)
        }
    }

    func reorder(fromOffsets: IndexSet, toOffset: Int) async {
        guard var document else { return }
        await flushAutosaves()
        document.pages.move(fromOffsets: fromOffsets, toOffset: toOffset)
        self.document = document
        do {
            try await store.reorderPages(document.pages.map(\.id), inNotebookAt: relativePath)
            lastSavedAt = Date()
        } catch {
            present(error)
            await load()
        }
    }

    func flushAutosaves() async {
        let dirtyIDs = dirtyPageIDs
        saveTasks.values.forEach { $0.cancel() }
        saveTasks.removeAll()

        for pageID in dirtyIDs {
            guard let page = document?.pages.first(where: { $0.id == pageID }) else { continue }
            await persist(
                pageID: pageID,
                drawingData: page.drawingData,
                hasContent: !page.metadata.isEmpty
            )
        }
    }

    private func scheduleAutosave(pageID: UUID, drawingData: Data, hasContent: Bool) {
        saveTasks[pageID]?.cancel()
        saveTasks[pageID] = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: autosaveDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await persist(pageID: pageID, drawingData: drawingData, hasContent: hasContent)
        }
    }

    private func persist(pageID: UUID, drawingData: Data, hasContent: Bool) async {
        activeSaveCount += 1
        isSaving = true
        defer {
            activeSaveCount -= 1
            isSaving = activeSaveCount > 0
        }
        do {
            let trailingPage = try await store.saveDrawing(
                drawingData,
                hasContent: hasContent,
                for: pageID,
                inNotebookAt: relativePath
            )

            if document?.pages.first(where: { $0.id == pageID })?.drawingData == drawingData {
                dirtyPageIDs.remove(pageID)
                hasUnsavedChanges = !dirtyPageIDs.isEmpty
                saveTasks[pageID] = nil
            } else if let current = document?.pages.first(where: { $0.id == pageID }) {
                scheduleAutosave(
                    pageID: pageID,
                    drawingData: current.drawingData,
                    hasContent: !current.metadata.isEmpty
                )
            }

            if let trailingPage,
               var document,
               !document.pages.contains(where: { $0.id == trailingPage.id }) {
                document.pages.append(NotebookPage(metadata: trailingPage, drawingData: Data()))
                document.manifest.pageOrder.append(trailingPage.id)
                self.document = document
            }
            lastSavedAt = Date()
        } catch is CancellationError {
            // A newer drawing change superseded this save.
        } catch {
            present(error)
        }
    }

    private func reloadSelecting(_ pageID: UUID?) async {
        do {
            document = try await store.loadNotebook(at: relativePath)
            dirtyPageIDs.removeAll()
            hasUnsavedChanges = false
            selectPageWithoutSaving(pageID ?? document?.pages.first?.id)
        } catch {
            present(error)
        }
    }

    private func selectPageWithoutSaving(_ pageID: UUID?) {
        selectedPageID = pageID
        guard let pageID,
              let data = document?.pages.first(where: { $0.id == pageID })?.drawingData else {
            currentDrawing = PKDrawing()
            return
        }

        do {
            currentDrawing = data.isEmpty ? PKDrawing() : try PKDrawing(data: data)
        } catch {
            currentDrawing = PKDrawing()
            present(DocumentStoreError.damagedDocument(
                "Die Zeichnung dieser Seite kann nicht gelesen werden."
            ))
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

private enum HandwritingRecognitionService {
    @MainActor
    static func recognize(
        drawing: PKDrawing,
        paperFormat: PaperFormat,
        paperOrientation: PaperOrientation
    ) async throws -> String {
        let pageSize = paperFormat.pageSize(for: paperOrientation)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.5
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: pageSize, format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: pageSize))
            drawing.image(from: CGRect(origin: .zero, size: pageSize), scale: 1.5)
                .draw(in: CGRect(origin: .zero, size: pageSize))
        }
        guard let cgImage = image.cgImage else {
            throw DocumentStoreError.fileOperationFailed(
                "Die Seite konnte nicht für die Handschrifterkennung vorbereitet werden."
            )
        }
        let operation = VisionTextRecognitionOperation(image: cgImage)
        return try await Task.detached(priority: .userInitiated) {
            try operation.perform()
        }.value
    }
}

private final class VisionTextRecognitionOperation: @unchecked Sendable {
    private let image: CGImage

    init(image: CGImage) {
        self.image = image
    }

    func perform() throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.minimumTextHeight = 0.006
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let observations = (request.results ?? []).sorted { lhs, rhs in
            let lineTolerance: CGFloat = 0.018
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > lineTolerance {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        return observations.compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
