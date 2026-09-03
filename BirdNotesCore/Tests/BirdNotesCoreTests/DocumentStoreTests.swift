import CryptoKit
import Foundation
import Testing
@testable import BirdNotesCore

private struct TemporaryStore {
    let url: URL
    let store: DocumentStore

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesCoreTests-\(UUID().uuidString)", isDirectory: true)
        store = try DocumentStore(rootURL: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

private struct InterruptedDocumentSaveJournal: Encodable {
    struct Entry: Encodable {
        let targetRelativePath: String
        let action: String
        let incomingName: String?
        let byteCount: Int?
        let sha256: String?
    }

    let schemaVersion = 1
    let transactionType = "documentSave"
    let committed = false
    let documentKind: DocumentKind
    let packageRelativePath: String
    let documentID: UUID
    let entries: [Entry]
}

private func transactionSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func writeTechnicalPackage(named name: String, in rootURL: URL) throws -> URL {
    let packageURL = rootURL.appendingPathComponent(name).appendingPathExtension("birdtech")
    try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
    let diagram = Data(#"{"schemaVersion":1}"#.utf8)
    let calculations = Data(#"{"schemaVersion":1,"items":[]}"#.utf8)
    try diagram.write(to: packageURL.appendingPathComponent("diagram.json"))
    try calculations.write(to: packageURL.appendingPathComponent("calculations.json"))
    let timestamp = "2026-08-29T07:00:00Z"
    let manifest: [String: Any] = [
        "schemaVersion": 1,
        "documentID": UUID().uuidString,
        "title": name,
        "domain": "general",
        "createdAt": timestamp,
        "modifiedAt": timestamp,
        "writerVersion": "3.0.0",
        "moduleVersions": ["birdnotes.general": "1.0.0"],
        "diagramSHA256": transactionSHA256(diagram),
        "calculationsSHA256": transactionSHA256(calculations)
    ]
    let data = try JSONSerialization.data(
        withJSONObject: manifest,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    try data.write(to: packageURL.appendingPathComponent("manifest.json"))
    return packageURL
}

private func technicalDocumentID(at packageURL: URL) throws -> UUID {
    let data = try Data(contentsOf: packageURL.appendingPathComponent("manifest.json"))
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let identifier = try #require(object["documentID"] as? String)
    return try #require(UUID(uuidString: identifier))
}

private final class GoldenFixtureBundleToken {}

private func goldenFixtureDirectoryURL() throws -> URL {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: GoldenFixtureBundleToken.self)
    #endif
    guard let url = bundle.url(
        forResource: "Fixtures",
        withExtension: nil
    ) else {
        throw CocoaError(.fileNoSuchFile)
    }
    return url
}

private func stageInterruptedDocumentSave(
    in rootURL: URL,
    journal: InterruptedDocumentSaveJournal,
    payloads: [Data]
) throws -> URL {
    let transactionURL = rootURL.appendingPathComponent(
        ".birdnotes-transactions/\(UUID().uuidString)",
        isDirectory: true
    )
    let incomingURL = transactionURL.appendingPathComponent("incoming", isDirectory: true)
    try FileManager.default.createDirectory(at: incomingURL, withIntermediateDirectories: true)
    for (index, payload) in payloads.enumerated() {
        try payload.write(to: incomingURL.appendingPathComponent("payload-\(index)"))
    }
    try JSONCoding.encoder().encode(journal).write(
        to: transactionURL.appendingPathComponent("document-journal.json")
    )
    return transactionURL
}

@Suite("DocumentStore", .serialized)
struct DocumentStoreTests {
    @Test("Eine leere Zeichenänderung erzeugt keine Seite")
    func emptyDrawingDoesNotCreatePage() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createNotebook(named: "Leer")
        let notebook = try await context.store.loadNotebook(at: path)

        let created = try await context.store.saveDrawing(
            Data(),
            hasContent: false,
            for: notebook.pages[0].id,
            inNotebookAt: path
        )

        #expect(created == nil)
        let reloaded = try await context.store.loadNotebook(at: path)
        #expect(reloaded.pages.count == 1)
    }

    @Test("Infinite Canvas wird erstellt, gespeichert und unabhängig dupliziert")
    func infiniteCanvasPersistsAndDuplicatesIndependently() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let path = try await store.createInfiniteCanvas(named: "Projektfläche")
        let drawing = Data([0x42, 0x49, 0x52, 0x44])
        try await store.saveInfiniteCanvasDrawing(drawing, at: path)

        let copyPath = try await store.duplicateItem(at: path)
        let original = try await store.loadInfiniteCanvas(at: path)
        let copy = try await store.loadInfiniteCanvas(at: copyPath)

        #expect(original.drawingData == drawing)
        #expect(copy.drawingData == drawing)
        #expect(original.manifest.id != copy.manifest.id)
        #expect(copy.manifest.width == 16_384)
        #expect(copy.manifest.height == 16_384)
    }

    @Test("PDF-Handschrift bleibt beim Umbenennen und Verschieben erhalten")
    func pdfDrawingsFollowFileOperations() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFDrawingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let source = sourceDirectory.appendingPathComponent("Skript.pdf")
        try Data("%PDF-1.7\nBirdNotes".utf8).write(to: source)
        let pdfPath = try await context.store.importPDF(from: source)
        let drawing = Data([0x01, 0x02, 0x03])
        try await context.store.savePDFDrawing(drawing, forPageAt: 2, inPDFAt: pdfPath)

        let renamed = try await context.store.renameItem(at: pdfPath, to: "Vorlesung")
        let folder = try await context.store.createFolder(named: "Semester")
        let moved = try await context.store.moveItem(at: renamed, to: folder)
        let loaded = try await context.store.loadPDFDrawings(at: moved)

        #expect(loaded[2] == drawing)
        #expect(try await context.store.listItems(in: folder).map(\.name) == ["Vorlesung"])
    }

    @Test("PDF-Handschrift wird zusammen mit einer gelöschten PDF wiederhergestellt")
    func pdfDrawingsSurviveDeleteAndRestore() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFRestore-\(UUID().uuidString).pdf")
        try Data("%PDF-1.7\nBirdNotes".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let pdfPath = try await context.store.importPDF(from: source)
        let drawing = Data([0x42, 0x49, 0x52, 0x44])
        try await context.store.savePDFDrawing(drawing, forPageAt: 1, inPDFAt: pdfPath)

        try await context.store.deleteItem(at: pdfPath)
        let restored = try #require(try await context.store.restoreMostRecentlyDeletedItem())

        #expect(restored == pdfPath)
        #expect(try await context.store.loadPDFDrawings(at: restored)[1] == drawing)
    }

    @Test("PDF-Handschrift folgt keinem manipulierten symbolischen Begleitordner")
    func pdfDrawingSidecarRejectsSymbolicLink() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFSymlink-\(UUID().uuidString).pdf")
        let externalDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFExternal-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: externalDirectory)
        }
        try Data("%PDF-1.7\nBirdNotes".utf8).write(to: source)
        try FileManager.default.createDirectory(at: externalDirectory, withIntermediateDirectories: false)
        let sentinel = externalDirectory.appendingPathComponent("sentinel")
        try Data("unverändert".utf8).write(to: sentinel)

        let pdfPath = try await context.store.importPDF(from: source)
        let pdfURL = context.url.appendingPathComponent(pdfPath)
        let sidecarURL = pdfURL.deletingLastPathComponent().appendingPathComponent(
            ".\(pdfURL.lastPathComponent).birdannotations"
        )
        try FileManager.default.createSymbolicLink(
            at: sidecarURL,
            withDestinationURL: externalDirectory
        )

        do {
            try await context.store.savePDFDrawing(
                Data("Zeichnung".utf8),
                forPageAt: 0,
                inPDFAt: pdfPath
            )
            Issue.record("Ein symbolischer PDF-Begleitordner hätte abgelehnt werden müssen.")
        } catch let error as DocumentStoreError {
            switch error {
            case .invalidPath, .damagedDocument:
                break
            default:
                Issue.record("Unerwarteter Fehler: \(error)")
            }
        }

        #expect(try Data(contentsOf: sentinel) == Data("unverändert".utf8))
        #expect(!FileManager.default.fileExists(
            atPath: externalDirectory.appendingPathComponent("page-0.drawing").path
        ))
    }

    @Test("PDFs werden importiert, erkannt und bei Namenskonflikten nicht überschrieben")
    func importsPDFsWithoutOverwriting() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesPDFTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let source = sourceDirectory.appendingPathComponent("Skript.pdf")
        let payload = Data("%PDF-1.7\nBirdNotes".utf8)
        try payload.write(to: source)

        let first = try await context.store.importPDF(from: source)
        let second = try await context.store.importPDF(from: source)
        let items = try await context.store.listItems()

        #expect(first == "Skript.pdf")
        #expect(second == "Skript Kopie.pdf")
        #expect(items.map(\.kind) == [.pdf, .pdf])
        #expect(try Data(contentsOf: context.url.appendingPathComponent(first)) == payload)
    }

    @Test("Ordner erstellen, umbenennen, verschieben und löschen")
    func folderCreateRenameMoveAndDelete() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let studyPath = try await store.createFolder(named: "Studium")
        let archivePath = try await store.createFolder(named: "Archiv")
        let mathPath = try await store.createFolder(named: "Mathematik", in: studyPath)

        let renamedPath = try await store.renameItem(at: mathPath, to: "Analysis")
        #expect(renamedPath == "Studium/Analysis")

        let movedPath = try await store.moveItem(at: renamedPath, to: archivePath)
        #expect(movedPath == "Archiv/Analysis")
        let archiveItems = try await store.listItems(in: archivePath)
        #expect(archiveItems.map(\.name) == ["Analysis"])

        try await store.deleteItem(at: movedPath)
        let itemsAfterDeletion = try await store.listItems(in: archivePath)
        #expect(itemsAfterDeletion.isEmpty)
    }

    @Test("Zeichnung und Seiten bleiben über Store-Instanzen erhalten")
    func notebookSaveLoadAndPersistenceAcrossStoreInstances() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let studyPath = try await store.createFolder(named: "Studium")
        let notebookPath = try await store.createNotebook(named: "Vorlesung", in: studyPath)
        let initial = try await store.loadNotebook(at: notebookPath)
        let firstPageID = try #require(initial.pages.first?.id)
        let drawing = Data([0x42, 0x49, 0x52, 0x44])

        let trailing = try await store.saveDrawing(
            drawing,
            hasContent: true,
            for: firstPageID,
            inNotebookAt: notebookPath
        )
        #expect(trailing != nil)

        let reopenedStore = try DocumentStore(rootURL: context.url)
        let reopened = try await reopenedStore.loadNotebook(at: notebookPath)
        #expect(reopened.pages.count == 2)
        #expect(reopened.pages[0].drawingData == drawing)
        #expect(!reopened.pages[0].metadata.isEmpty)
        #expect(reopened.pages[1].metadata.isEmpty)

        let noThirdPage = try await reopenedStore.saveDrawing(
            Data([0x42, 0x49, 0x52, 0x44, 0x32]),
            hasContent: true,
            for: firstPageID,
            inNotebookAt: notebookPath
        )
        #expect(noThirdPage == nil)
        let afterEditingFirstPageAgain = try await reopenedStore.loadNotebook(at: notebookPath)
        #expect(afterEditingFirstPageAgain.pages.count == 2)
    }

    @Test("Duplizierte und umbenannte Notizbücher sind unabhängig")
    func duplicateAndRenameNotebookKeepIndependentDocuments() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let originalPath = try await store.createNotebook(named: "Ideen")
        let copyPath = try await store.duplicateItem(at: originalPath)
        let renamedCopyPath = try await store.renameItem(at: copyPath, to: "Ideen Archiv")

        let original = try await store.loadNotebook(at: originalPath)
        let copy = try await store.loadNotebook(at: renamedCopyPath)
        #expect(original.manifest.id != copy.manifest.id)
        #expect(copy.manifest.title == "Ideen Archiv")
        let rootItems = try await store.listItems()
        #expect(rootItems.count == 2)
    }

    @Test("Seiten hinzufügen, duplizieren, umsortieren, ändern und löschen")
    func pageAddDuplicateReorderPaperAndDelete() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let notebookPath = try await store.createNotebook(named: "Test")
        var notebook = try await store.loadNotebook(at: notebookPath)
        let firstPageID = notebook.pages[0].id
        #expect(notebook.pages[0].metadata.paperFormat == .a4)
        #expect(notebook.pages[0].metadata.paperOrientation == .portrait)

        try await store.updatePaperStyle(.grid, for: firstPageID, inNotebookAt: notebookPath)
        try await store.updatePaperFormat(.a3, for: firstPageID, inNotebookAt: notebookPath)
        try await store.updatePaperOrientation(
            .landscape,
            for: firstPageID,
            inNotebookAt: notebookPath
        )
        let secondPage = try await store.addPage(
            toNotebookAt: notebookPath,
            paperStyle: .lined,
            paperFormat: .a3,
            paperOrientation: .landscape
        )
        let copy = try await store.duplicatePage(secondPage.id, inNotebookAt: notebookPath)
        try await store.reorderPages(
            [copy.id, firstPageID, secondPage.id],
            inNotebookAt: notebookPath
        )

        notebook = try await store.loadNotebook(at: notebookPath)
        #expect(notebook.pages.map(\.id) == [copy.id, firstPageID, secondPage.id])
        #expect(notebook.pages[1].metadata.paperStyle == .grid)
        #expect(notebook.pages[1].metadata.paperFormat == .a3)
        #expect(notebook.pages[1].metadata.paperOrientation == .landscape)
        #expect(notebook.pages[2].metadata.paperStyle == .lined)
        #expect(notebook.pages[0].metadata.paperFormat == .a3)
        #expect(notebook.pages[0].metadata.paperOrientation == .landscape)
        #expect(notebook.pages[2].metadata.paperFormat == .a3)
        #expect(notebook.pages[2].metadata.paperOrientation == .landscape)

        try await store.deletePage(copy.id, fromNotebookAt: notebookPath)
        let afterDeletion = try await store.loadNotebook(at: notebookPath)
        #expect(afterDeletion.pages.count == 2)
    }

    @Test("Ein Notizbuch mit 100 Seiten behält Reihenfolge und Metadaten")
    func hundredPageNotebookRoundTripKeepsOrderAndMetadata() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let notebookPath = try await store.createNotebook(
            named: "Großes Notizbuch",
            paperStyle: .grid,
            paperFormat: .a4,
            paperOrientation: .portrait
        )
        var expectedPageIDs = try await store.loadNotebook(at: notebookPath).pages.map(\.id)

        for pageNumber in 2...100 {
            let page = try await store.addPage(
                toNotebookAt: notebookPath,
                paperStyle: pageNumber.isMultiple(of: 3) ? .grid : .lined,
                paperFormat: pageNumber.isMultiple(of: 10) ? .a3 : .a4,
                paperOrientation: pageNumber.isMultiple(of: 2) ? .landscape : .portrait
            )
            expectedPageIDs.append(page.id)
        }

        let loaded = try await store.loadNotebook(at: notebookPath)
        #expect(loaded.pages.count == 100)
        #expect(Set(loaded.pages.map(\.id)).count == 100)
        #expect(loaded.pages.map(\.id) == expectedPageIDs)
        #expect(loaded.pages[0].metadata.paperStyle == .grid)
        #expect(loaded.pages[9].metadata.paperFormat == .a3)
        #expect(loaded.pages[9].metadata.paperOrientation == .landscape)
        #expect(loaded.pages[98].metadata.paperFormat == .a4)
        #expect(loaded.pages[98].metadata.paperOrientation == .portrait)
        #expect(loaded.pages[99].metadata.paperFormat == .a3)
        #expect(loaded.pages[99].metadata.paperOrientation == .landscape)

        let reversedPageIDs = Array(expectedPageIDs.reversed())
        try await store.reorderPages(reversedPageIDs, inNotebookAt: notebookPath)

        let reopenedStore = try DocumentStore(rootURL: context.url)
        let reopened = try await reopenedStore.loadNotebook(at: notebookPath)
        #expect(reopened.pages.map(\.id) == reversedPageIDs)
        #expect(reopened.manifest.pageOrder == reversedPageIDs)
    }

    @Test("Die einzige Seite kann nicht gelöscht werden")
    func cannotDeleteOnlyPage() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store
        let notebookPath = try await store.createNotebook(named: "Test")
        let notebook = try await store.loadNotebook(at: notebookPath)
        let pageID = notebook.pages[0].id

        do {
            try await store.deletePage(pageID, fromNotebookAt: notebookPath)
            Issue.record("Das Löschen der einzigen Seite hätte abgelehnt werden müssen.")
        } catch {
            #expect(error as? DocumentStoreError == .cannotDeleteOnlyPage)
        }
    }

    @Test("Pfade dürfen den Dokument-Root nicht verlassen")
    func rejectsTraversalOutsideRoot() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }

        do {
            _ = try await context.store.listItems(in: "../Outside")
            Issue.record("Ein Traversal-Pfad hätte abgelehnt werden müssen.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidPath("../Outside"))
        }
    }

    @Test("Eine unbekannte zukünftige Schemaversion wird abgelehnt")
    func unknownFutureSchemaIsRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store
        let notebookPath = try await store.createNotebook(named: "Zukunft")
        let manifestURL = context.url
            .appendingPathComponent(notebookPath, isDirectory: true)
            .appendingPathComponent("manifest.json")
        var manifest = try JSONCoding.decoder().decode(
            NotebookManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        manifest.schemaVersion = NotebookManifest.currentSchemaVersion + 1
        try JSONCoding.encoder().encode(manifest).write(to: manifestURL, options: .atomic)

        do {
            _ = try await store.loadNotebook(at: notebookPath)
            Issue.record("Eine unbekannte Dokumentversion hätte abgelehnt werden müssen.")
        } catch {
            #expect(
                error as? DocumentStoreError ==
                    .unsupportedSchemaVersion(NotebookManifest.currentSchemaVersion + 1)
            )
        }
    }

    @Test("Ungültige und bereits vergebene Namen werden abgelehnt")
    func invalidAndDuplicateNamesAreRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        for invalidName in [
            "", "   ", "../Studium", ".versteckt", "A/B", "A:B", "A\\B", "A\nB",
            String(repeating: "🕊️", count: 100)
        ] {
            do {
                _ = try await store.createFolder(named: invalidName)
                Issue.record("Der ungültige Name \(invalidName.debugDescription) wurde akzeptiert.")
            } catch {
                guard let storeError = error as? DocumentStoreError,
                      case .invalidName = storeError else {
                    Issue.record("Für \(invalidName.debugDescription) kam der falsche Fehler: \(error)")
                    continue
                }
            }
        }

        _ = try await store.createFolder(named: "Studium")
        do {
            _ = try await store.createFolder(named: "Studium")
            Issue.record("Ein bereits vorhandener Name wurde akzeptiert.")
        } catch {
            #expect(error as? DocumentStoreError == .itemAlreadyExists("Studium"))
        }
    }

    @Test("Ein Ordner kann nicht in einen eigenen Unterordner verschoben werden")
    func folderCannotMoveIntoItsDescendant() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store

        let parent = try await store.createFolder(named: "Studium")
        let child = try await store.createFolder(named: "Semester 1", in: parent)

        do {
            _ = try await store.moveItem(at: parent, to: child)
            Issue.record("Ein Ordner wurde in seinen eigenen Unterordner verschoben.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidPath(child))
        }
    }

    @Test("Ein fehlendes Manifest wird als beschädigtes Dokument gemeldet")
    func missingManifestIsReportedAsDamage() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store
        let notebookPath = try await store.createNotebook(named: "Beschädigt")
        let manifestURL = context.url
            .appendingPathComponent(notebookPath, isDirectory: true)
            .appendingPathComponent("manifest.json")
        try FileManager.default.removeItem(at: manifestURL)

        do {
            _ = try await store.loadNotebook(at: notebookPath)
            Issue.record("Ein Notizbuch ohne Manifest wurde geladen.")
        } catch {
            guard let storeError = error as? DocumentStoreError,
                  case .damagedDocument = storeError else {
                Issue.record("Erwartet war damagedDocument, erhalten wurde \(error).")
                return
            }
        }
    }

    @Test("Eine unvollständige Seitenreihenfolge wird abgelehnt")
    func incompletePageOrderIsRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store
        let notebookPath = try await store.createNotebook(named: "Reihenfolge")
        _ = try await store.addPage(toNotebookAt: notebookPath)
        let notebook = try await store.loadNotebook(at: notebookPath)

        do {
            try await store.reorderPages(
                [notebook.pages[0].id],
                inNotebookAt: notebookPath
            )
            Issue.record("Eine unvollständige Seitenreihenfolge wurde gespeichert.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidPageOrder)
        }
    }

    @Test("Eine duplizierte Seite behält Drawing und Papierstil")
    func duplicatedPagePreservesEditableContent() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let store = context.store
        let notebookPath = try await store.createNotebook(named: "Duplikat")
        let initial = try await store.loadNotebook(at: notebookPath)
        let firstPageID = initial.pages[0].id
        let drawing = Data([0x01, 0x02, 0x03, 0x04])
        _ = try await store.saveDrawing(
            drawing,
            hasContent: true,
            for: firstPageID,
            inNotebookAt: notebookPath
        )
        try await store.updatePaperStyle(.grid, for: firstPageID, inNotebookAt: notebookPath)

        let duplicate = try await store.duplicatePage(firstPageID, inNotebookAt: notebookPath)
        let reloaded = try await store.loadNotebook(at: notebookPath)
        let duplicatedPage = try #require(reloaded.pages.first { $0.id == duplicate.id })
        #expect(duplicatedPage.drawingData == drawing)
        #expect(duplicatedPage.metadata.paperStyle == .grid)
        #expect(!duplicatedPage.metadata.isEmpty)
    }

    @Test("Canvas-Objekte, Kachelformat und Ansicht bleiben erhalten")
    func canvasElementsAndViewportPersist() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Plan")
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let element = CanvasElement(
            kind: .text,
            center: CanvasPoint(x: 2_400, y: 1_800),
            size: CanvasSize(width: 320, height: 120),
            text: "Meilenstein",
            createdAt: timestamp,
            modifiedAt: timestamp
        )
        let viewport = CanvasViewport(
            center: CanvasPoint(x: 2_500, y: 1_900),
            zoomScale: 0.72
        )

        try await context.store.saveInfiniteCanvas(
            drawingData: Data([0x01, 0x02]),
            elements: [element],
            viewport: viewport,
            at: path
        )
        let loaded = try await context.store.loadInfiniteCanvas(at: path)

        #expect(loaded.elements == [element])
        #expect(loaded.manifest.viewport == viewport)
        #expect(loaded.manifest.tileConfiguration.tileSize == 1_024)
        #expect(loaded.manifest.schemaVersion == InfiniteCanvasManifest.currentSchemaVersion)
    }

    @Test("Alte Canvases ohne Ansicht und Objektdatei werden migriert")
    func legacyCanvasLoadsWithDefaults() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Alt")
        let packageURL = context.url.appendingPathComponent(path, isDirectory: true)
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        )
        object["schemaVersion"] = 1
        object.removeValue(forKey: "viewport")
        object.removeValue(forKey: "tileConfiguration")
        try JSONSerialization.data(withJSONObject: object).write(to: manifestURL, options: .atomic)
        try FileManager.default.removeItem(at: packageURL.appendingPathComponent("elements.json"))

        let loaded = try await context.store.loadInfiniteCanvas(at: path)

        #expect(loaded.elements.isEmpty)
        #expect(loaded.manifest.viewport.center == CanvasPoint(x: 8_192, y: 8_192))
        #expect(loaded.manifest.viewport.zoomScale == 0.35)
        #expect(loaded.manifest.tileConfiguration.columns == 16)
    }

    @Test("Golden Files aller Notizbuch- und Canvas-Schemaversionen bleiben kompatibel")
    func releasedSchemaGoldenFilesLoadAndMigrate() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let fixtureNames = [
            "Notebook-v1.birdnotebook",
            "Notebook-v2.birdnotebook",
            "Canvas-v1.birdcanvas",
            "Canvas-v2.birdcanvas"
        ]
        let fixtureDirectoryURL = try goldenFixtureDirectoryURL()
        for name in fixtureNames {
            try FileManager.default.copyItem(
                at: fixtureDirectoryURL.appendingPathComponent(name),
                to: context.url.appendingPathComponent(name)
            )
        }

        let notebookV1 = try await context.store.loadNotebook(
            at: "Notebook-v1.birdnotebook"
        )
        #expect(notebookV1.manifest.schemaVersion == 1)
        #expect(notebookV1.pages[0].metadata.paperFormat == .a4)
        #expect(notebookV1.pages[0].metadata.paperOrientation == .portrait)
        #expect(!notebookV1.pages[0].metadata.isBookmarked)

        let notebookV2 = try await context.store.loadNotebook(
            at: "Notebook-v2.birdnotebook"
        )
        #expect(notebookV2.manifest.schemaVersion == 2)
        #expect(notebookV2.pages[0].metadata.paperFormat == .a3)
        #expect(notebookV2.pages[0].metadata.paperOrientation == .landscape)
        #expect(notebookV2.pages[0].metadata.isBookmarked)

        let canvasV1 = try await context.store.loadInfiniteCanvas(
            at: "Canvas-v1.birdcanvas"
        )
        #expect(canvasV1.manifest.schemaVersion == 1)
        #expect(canvasV1.manifest.viewport.center == CanvasPoint(x: 8_192, y: 8_192))
        #expect(canvasV1.elements.isEmpty)

        let canvasV2 = try await context.store.loadInfiniteCanvas(
            at: "Canvas-v2.birdcanvas"
        )
        #expect(canvasV2.manifest.schemaVersion == 2)
        #expect(canvasV2.manifest.viewport.zoomScale == 0.8)
        #expect(canvasV2.elements.map(\.text) == ["Golden Canvas"])

        // Save-after-load upgrades legacy manifests through the normal,
        // recoverable production write path.
        try await context.store.updatePageBookmark(
            true,
            for: notebookV1.pages[0].id,
            inNotebookAt: "Notebook-v1.birdnotebook"
        )
        let migratedNotebook = try await context.store.loadNotebook(
            at: "Notebook-v1.birdnotebook"
        )
        #expect(migratedNotebook.manifest.schemaVersion == 2)
        #expect(migratedNotebook.pages[0].metadata.isBookmarked)

        try await context.store.saveInfiniteCanvas(
            drawingData: canvasV1.drawingData,
            elements: canvasV1.elements,
            viewport: canvasV1.manifest.viewport,
            at: "Canvas-v1.birdcanvas"
        )
        #expect(try await context.store.loadInfiniteCanvas(
            at: "Canvas-v1.birdcanvas"
        ).manifest.schemaVersion == 2)
    }

    @Test("Favoriten und zuletzt geöffnet folgen Ordnerbewegungen")
    func libraryStateTracksMovesAndDeletion() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let source = try await context.store.createFolder(named: "Arbeit")
        let destination = try await context.store.createFolder(named: "Archiv")
        let notebook = try await context.store.createNotebook(named: "Plan", in: source)

        _ = try await context.store.toggleFavorite(at: notebook)
        _ = try await context.store.markRecent(at: notebook)
        let movedFolder = try await context.store.moveItem(at: source, to: destination)
        let movedNotebook = movedFolder + "/Plan.birdnotebook"
        var state = try await context.store.loadLibraryState()

        #expect(state.favoritePaths == [movedNotebook])
        #expect(state.recentPaths == [movedNotebook])
        #expect(try await context.store.allItems().contains { $0.relativePath == movedNotebook })

        try await context.store.deleteItem(at: movedFolder)
        state = try await context.store.loadLibraryState()
        #expect(state.favoritePaths.isEmpty)
        #expect(state.recentPaths.isEmpty)
    }

    @Test("Symbolische Links werden weder angezeigt noch betreten")
    func symbolicLinksCannotEscapeLibrary() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesOutside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outsideURL) }
        try Data("private".utf8).write(to: outsideURL.appendingPathComponent("private.pdf"))

        let linkURL = context.url.appendingPathComponent("Verknüpfung")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: outsideURL)

        #expect(try await context.store.listItems().isEmpty)
        do {
            _ = try await context.store.listItems(in: "Verknüpfung")
            Issue.record("Eine symbolische Verknüpfung hätte abgelehnt werden müssen.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidPath("Verknüpfung"))
        }
    }

    @Test("Paketinterne Ordner sind nicht als Bibliotheksordner erreichbar")
    func packageInternalsCannotBeTraversed() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let notebook = try await context.store.createNotebook(named: "Privat")

        do {
            _ = try await context.store.listItems(in: notebook + "/pages")
            Issue.record("Paketinhalte hätten nicht als Ordner geöffnet werden dürfen.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidPath(notebook + "/pages"))
        }
    }

    @Test("Nur PDFs mit gültigem Header werden importiert")
    func invalidPDFHeaderIsRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("Manipuliert-\(UUID().uuidString).pdf")
        try Data("not a pdf".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        do {
            _ = try await context.store.importPDF(from: source)
            Issue.record("Eine umbenannte Nicht-PDF hätte abgelehnt werden müssen.")
        } catch {
            #expect(error as? DocumentStoreError == .unsupportedFileType("ungültige PDF"))
        }
        #expect(try await context.store.listItems().isEmpty)
    }

    @Test("Überdimensionierte PDFs werden vor dem Kopieren abgelehnt")
    func oversizedPDFIsRejectedWithoutLoadingIt() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("Gross-\(UUID().uuidString).pdf")
        FileManager.default.createFile(atPath: source.path, contents: Data("%PDF-1.7".utf8))
        let handle = try FileHandle(forWritingTo: source)
        try handle.truncate(atOffset: UInt64(DocumentStoreLimits.maximumPDFBytes + 1))
        try handle.close()
        defer { try? FileManager.default.removeItem(at: source) }

        do {
            _ = try await context.store.importPDF(from: source)
            Issue.record("Eine zu große PDF hätte abgelehnt werden müssen.")
        } catch {
            guard let storeError = error as? DocumentStoreError,
                  case .resourceLimitExceeded = storeError else {
                Issue.record("Erwartet war resourceLimitExceeded, erhalten wurde \(error).")
                return
            }
        }
    }

    @Test("Beschädigter Bibliotheksstatus blockiert keine Dokumente")
    func damagedLibraryStateIsQuarantined() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        _ = try await context.store.createFolder(named: "Weiter nutzbar")
        try Data("{invalid".utf8).write(
            to: context.url.appendingPathComponent(".birdnotes-library.json")
        )

        let state = try await context.store.loadLibraryState()
        let items = try await context.store.listItems()
        let hiddenFiles = try FileManager.default.contentsOfDirectory(atPath: context.url.path)

        #expect(state == LibraryState())
        #expect(items.map(\.name) == ["Weiter nutzbar"])
        #expect(hiddenFiles.contains { $0.hasPrefix(".birdnotes-library-damaged-") })
    }

    @Test("Nicht-finite Canvas-Werte werden abgelehnt")
    func nonFiniteCanvasViewportIsRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let canvas = try await context.store.createInfiniteCanvas(named: "Ungültig")

        do {
            try await context.store.saveInfiniteCanvasViewport(
                CanvasViewport(center: CanvasPoint(x: .nan, y: 42), zoomScale: 1),
                at: canvas
            )
            Issue.record("Ein nicht-finiter Canvas-Wert hätte abgelehnt werden müssen.")
        } catch {
            guard let storeError = error as? DocumentStoreError,
                  case .damagedDocument = storeError else {
                Issue.record("Erwartet war damagedDocument, erhalten wurde \(error).")
                return
            }
        }
    }

    @Test("Extrem lange Namen werden abgelehnt")
    func overlyLongNamesAreRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let name = String(repeating: "A", count: DocumentStoreLimits.maximumNameLength + 1)

        do {
            _ = try await context.store.createFolder(named: name)
            Issue.record("Ein überlanger Name hätte abgelehnt werden müssen.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidName(name))
        }
    }

    @Test("Gelöschte Dokumente können wiederhergestellt werden")
    func deletedItemsCanBeRestored() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let folder = try await context.store.createFolder(named: "Projekt")
        let notebook = try await context.store.createNotebook(named: "Plan", in: folder)

        try await context.store.deleteItem(at: notebook)
        #expect(try await context.store.listItems(in: folder).isEmpty)
        #expect(try await context.store.hasRestorableItems())

        let restored = try #require(try await context.store.restoreMostRecentlyDeletedItem())
        #expect(restored == notebook)
        #expect(try await context.store.loadNotebook(at: restored).manifest.title == "Plan")
        #expect(try await !context.store.hasRestorableItems())
    }

    @Test("Wiederherstellung überschreibt keine neuere Datei")
    func restoreDoesNotOverwriteNameConflict() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let original = try await context.store.createNotebook(named: "Plan")
        try await context.store.deleteItem(at: original)
        _ = try await context.store.createNotebook(named: "Plan")

        let restored = try #require(try await context.store.restoreMostRecentlyDeletedItem())

        #expect(restored == "Plan Kopie.birdnotebook")
        #expect(
            try await context.store.listItems().map(\.name).sorted()
                == ["Plan", "Plan Kopie"]
        )
    }

    @Test("Studienvorlage und Seitenmarkierung bleiben dauerhaft erhalten")
    func studyTemplateAndBookmarkPersist() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let notebookPath = try await context.store.createNotebook(
            named: "Methodik",
            paperStyle: .cornell,
            paperFormat: .a4
        )
        let firstPage = try #require(try await context.store.loadNotebook(at: notebookPath).pages.first)
        try await context.store.updatePageBookmark(
            true,
            for: firstPage.id,
            inNotebookAt: notebookPath
        )

        let reloaded = try await context.store.loadNotebook(at: notebookPath)
        #expect(reloaded.pages[0].metadata.paperStyle == .cornell)
        #expect(reloaded.pages[0].metadata.paperFormat == .a4)
        #expect(reloaded.pages[0].metadata.isBookmarked)
    }

    @Test("Druckschrift bleibt erhalten, ist durchsuchbar und folgt duplizierten Seiten")
    func transcriptionPersistsAndIsSearchable() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let notebookPath = try await context.store.createNotebook(named: "Signale")
        let page = try #require(try await context.store.loadNotebook(at: notebookPath).pages.first)

        try await context.store.updatePageTranscription(
            "Die Fourier-Transformation zerlegt ein Signal in Frequenzen.",
            for: page.id,
            inNotebookAt: notebookPath
        )
        let copy = try await context.store.duplicatePage(page.id, inNotebookAt: notebookPath)
        let hits = try await context.store.searchTranscribedText("fourier")

        #expect(hits.count == 2)
        #expect(hits.first?.documentPath == notebookPath)
        #expect(hits.first?.pageNumber == 1)
        #expect(hits.first?.excerpt.contains("Fourier") == true)
        #expect(try await context.store.loadNotebook(at: notebookPath)
            .pages.first(where: { $0.id == copy.id })?.metadata.transcribedText
            == "Die Fourier-Transformation zerlegt ein Signal in Frequenzen.")

        try await context.store.updatePageTranscription(
            nil,
            for: page.id,
            inNotebookAt: notebookPath
        )
        #expect(try await context.store.searchTranscribedText("fourier").count == 1)
    }

    @Test("Überdimensionierte Druckschrift wird abgelehnt")
    func oversizedTranscriptionIsRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let notebook = try await context.store.createNotebook(named: "Grenzen")
        let page = try #require(try await context.store.loadNotebook(at: notebook).pages.first)

        await #expect(throws: DocumentStoreError.self) {
            try await context.store.updatePageTranscription(
                String(repeating: "a", count: DocumentStoreLimits.maximumTranscriptionCharacters + 1),
                for: page.id,
                inNotebookAt: notebook
            )
        }
        #expect(try await context.store.loadNotebook(at: notebook)
            .pages.first?.metadata.transcribedText == nil)
    }

    @Test("Ältere Seiten und Bibliotheksdaten erhalten sichere Standardwerte")
    func legacyStudyMetadataGetsDefaults() throws {
        let pageID = UUID()
        let pageJSON = """
        {
          "id": "\(pageID.uuidString)",
          "createdAt": "2026-08-16T08:00:00Z",
          "modifiedAt": "2026-08-16T08:00:00Z",
          "paperStyle": "lined",
          "isEmpty": false
        }
        """
        let stateJSON = """
        { "favoritePaths": ["Alt.birdnotebook"], "recentPaths": [] }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let page = try decoder.decode(NotebookPageMetadata.self, from: Data(pageJSON.utf8))
        let state = try decoder.decode(LibraryState.self, from: Data(stateJSON.utf8))

        #expect(page.paperFormat == .a4)
        #expect(!page.isBookmarked)
        #expect(state.tagsByPath.isEmpty)
    }

    @Test("Tags folgen Dateioperationen und werden mit Ordnern wiederhergestellt")
    func tagsFollowOperationsAndTrashRestore() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let folder = try await context.store.createFolder(named: "Semester 1")
        let notebook = try await context.store.createNotebook(named: "Analysis", in: folder)
        _ = try await context.store.setTags(["Prüfung", "Mathematik", "prüfung"], for: notebook)
        _ = try await context.store.toggleFavorite(at: notebook)
        _ = try await context.store.markRecent(at: notebook)

        let copy = try await context.store.duplicateItem(at: notebook)
        #expect(try await context.store.loadLibraryState().tagsByPath[copy] == ["Mathematik", "Prüfung"])
        let folderCopy = try await context.store.duplicateItem(at: folder)
        #expect(
            try await context.store.loadLibraryState()
                .tagsByPath[folderCopy + "/Analysis.birdnotebook"]
                == ["Mathematik", "Prüfung"]
        )

        try await context.store.deleteItem(at: folder)
        let restoredFolder = try #require(try await context.store.restoreMostRecentlyDeletedItem())
        let restoredNotebook = restoredFolder + "/Analysis.birdnotebook"
        let state = try await context.store.loadLibraryState()

        #expect(state.tagsByPath[restoredNotebook] == ["Mathematik", "Prüfung"])
        #expect(state.favoritePaths.contains(restoredNotebook))
        #expect(state.recentPaths.contains(restoredNotebook))
    }

    @Test("Tag-Grenzen und unsichere Zeichen werden abgelehnt")
    func tagLimitsAndUnsafeCharactersAreRejected() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let notebook = try await context.store.createNotebook(named: "Sicher")
        let tooManyTags = (1...(LibraryState.maximumTagsPerItem + 1)).map { "Tag \($0)" }

        do {
            _ = try await context.store.setTags(tooManyTags, for: notebook)
            Issue.record("Zu viele Tags hätten abgelehnt werden müssen.")
        } catch {
            guard let storeError = error as? DocumentStoreError,
                  case .resourceLimitExceeded = storeError else {
                Issue.record("Erwartet war resourceLimitExceeded, erhalten wurde \(error).")
                return
            }
        }

        do {
            _ = try await context.store.setTags(["Semester/Privat"], for: notebook)
            Issue.record("Ein Tag mit Pfadtrenner hätte abgelehnt werden müssen.")
        } catch {
            #expect(error as? DocumentStoreError == .invalidName("Semester/Privat"))
        }

        #expect(try await context.store.loadLibraryState().tagsByPath[notebook] == nil)
    }

    @Test("Papierkorb unterstützt gezielte Wiederherstellung und endgültiges Löschen")
    func trashSupportsTargetedRestoreAndPermanentDeletion() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let first = try await context.store.createNotebook(named: "Erste")
        let second = try await context.store.createNotebook(named: "Zweite")
        try await context.store.deleteItem(at: first)
        try await context.store.deleteItem(at: second)

        let deleted = try await context.store.listDeletedItems()
        let firstEntry = try #require(deleted.first { $0.name == "Erste" })
        let secondEntry = try #require(deleted.first { $0.name == "Zweite" })
        #expect(deleted.count == 2)

        let restored = try await context.store.restoreDeletedItem(id: firstEntry.id)
        try await context.store.deletePermanently(id: secondEntry.id)

        #expect(restored == first)
        #expect(try await context.store.listDeletedItems().isEmpty)
        #expect(try await context.store.listItems().map(\.name) == ["Erste"])
    }

    @Test("Bibliotheks-Backup enthält Dokumente und Organisation, aber keinen Papierkorb")
    func libraryBackupContainsSafeSnapshot() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesBackupTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        let folder = try await context.store.createFolder(named: "Studium")
        let notebook = try await context.store.createNotebook(
            named: "Vorlesung",
            in: folder,
            paperStyle: .dotted
        )
        _ = try await context.store.setTags(["Semester 1"], for: notebook)
        let deleted = try await context.store.createNotebook(named: "Entwurf")
        try await context.store.deleteItem(at: deleted)
        let unsafeLink = context.url
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("Unsicher")
        try FileManager.default.createSymbolicLink(
            at: unsafeLink,
            withDestinationURL: FileManager.default.temporaryDirectory
        )

        let backup = try await context.store.createLibraryBackup(in: destination)
        let manifestData = try Data(contentsOf: backup.appendingPathComponent("manifest.json"))
        let manifest = try JSONCoding.decoder().decode(LibraryBackupManifest.self, from: manifestData)
        let library = backup.appendingPathComponent("Library", isDirectory: true)

        #expect(manifest.schemaVersion == LibraryBackupManifest.currentSchemaVersion)
        #expect(manifest.itemCount == 1)
        #expect(!manifest.includesTrash)
        #expect(FileManager.default.fileExists(
            atPath: library.appendingPathComponent(notebook).path
        ))
        #expect(FileManager.default.fileExists(
            atPath: library.appendingPathComponent(".birdnotes-library.json").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: library.appendingPathComponent(folder).appendingPathComponent("Unsicher").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: backup.appendingPathComponent(".birdnotes-trash").path
        ))
    }

    @Test("Backup wird validiert und bei Konflikten als Kopie wiederhergestellt")
    func backupRestoreKeepsBothAndRestoresOrganization() async throws {
        let source = try TemporaryStore()
        let destination = try TemporaryStore()
        defer {
            source.remove()
            destination.remove()
        }
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesRestoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: exportDirectory) }

        let folder = try await source.store.createFolder(named: "Studium")
        let notebook = try await source.store.createNotebook(named: "Analysis", in: folder)
        _ = try await source.store.setTags(["Mathematik"], for: notebook)
        _ = try await destination.store.createFolder(named: "Studium")
        let backup = try await source.store.createLibraryBackup(in: exportDirectory)

        let preview = try await destination.store.inspectLibraryBackup(at: backup)
        let result = try await destination.store.restoreLibraryBackup(
            from: backup,
            conflictPolicy: .keepBoth
        )

        #expect(preview.itemCount == 1)
        #expect(preview.conflictingItemNames == ["Studium"])
        #expect(result.restoredPaths == ["Studium Kopie"])
        #expect(try await destination.store.loadNotebook(
            at: "Studium Kopie/Analysis.birdnotebook"
        ).manifest.title == "Analysis")
        #expect(try await destination.store.loadLibraryState().tagsByPath[
            "Studium Kopie/Analysis.birdnotebook"
        ] == ["Mathematik"])
        #expect(try await destination.store.listItems(in: "Studium").isEmpty)
    }

    @Test("Manipulierte Backups mit symbolischen Links werden abgelehnt")
    func backupRestoreRejectsSymbolicLinks() async throws {
        let context = try TemporaryStore()
        let target = try TemporaryStore()
        defer {
            context.remove()
            target.remove()
        }
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesUnsafeRestoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: exportDirectory) }

        _ = try await context.store.createNotebook(named: "Sicher")
        let backup = try await context.store.createLibraryBackup(in: exportDirectory)
        try FileManager.default.createSymbolicLink(
            at: backup.appendingPathComponent("Library/Fremd"),
            withDestinationURL: FileManager.default.temporaryDirectory
        )

        await #expect(throws: DocumentStoreError.self) {
            _ = try await target.store.inspectLibraryBackup(at: backup)
        }
        #expect(try await target.store.listItems().isEmpty)
    }

    @Test("Unterbrochene Backup-Wiederherstellung wird beim nächsten Start zurückgerollt")
    func interruptedBackupRestoreIsRolledBack() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let original = try await context.store.createFolder(named: "Studium")
        let originalURL = context.url.appendingPathComponent(original, isDirectory: true)
        try Data("original".utf8).write(to: originalURL.appendingPathComponent("marker"))

        let transactionID = UUID().uuidString
        let transaction = context.url
            .appendingPathComponent(".birdnotes-transactions/\(transactionID)", isDirectory: true)
        let incoming = transaction.appendingPathComponent("incoming", isDirectory: true)
        let rollback = transaction.appendingPathComponent("rollback", isDirectory: true)
        try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rollback, withIntermediateDirectories: false)
        try FileManager.default.moveItem(
            at: originalURL,
            to: rollback.appendingPathComponent("Studium", isDirectory: true)
        )
        try FileManager.default.createDirectory(at: originalURL, withIntermediateDirectories: false)
        try Data("backup".utf8).write(to: originalURL.appendingPathComponent("marker"))
        let journal = """
        {"committed":false,"hadLibraryState":false,"items":[{"sourceName":"Studium","targetName":"Studium","hadOriginal":true,"hadOriginalSidecar":false}]}
        """
        try Data(journal.utf8).write(to: transaction.appendingPathComponent("journal.json"))

        #expect(try await context.store.recoverInterruptedTransactions() == 1)
        #expect(try String(
            contentsOf: originalURL.appendingPathComponent("marker"),
            encoding: .utf8
        ) == "original")
        #expect(!FileManager.default.fileExists(
            atPath: context.url.appendingPathComponent(".birdnotes-transactions").path
        ))
    }

    @Test("Unterbrochener Canvas-Save wird aus geprüften Nutzdaten fertiggestellt")
    func interruptedCanvasSaveIsCompleted() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Labor")
        let current = try await context.store.loadInfiniteCanvas(at: path)
        let drawing = Data([0x42, 0x49, 0x52, 0x44, 0x32])
        let elements = [CanvasElement(
            kind: .text,
            center: CanvasPoint(x: 720, y: 480),
            size: CanvasSize(width: 320, height: 120),
            text: "Wiederhergestellt"
        )]
        var manifest = current.manifest
        manifest.modifiedAt = Date(timeIntervalSince1970: 1_800_000_000)
        manifest.viewport = CanvasViewport(
            center: CanvasPoint(x: 720, y: 480),
            zoomScale: 1.25
        )
        let elementData = try JSONCoding.encoder().encode(elements)
        let manifestData = try JSONCoding.encoder().encode(manifest)
        let entries = [
            InterruptedDocumentSaveJournal.Entry(
                targetRelativePath: "drawing.data",
                action: "replaceFile",
                incomingName: "payload-0",
                byteCount: drawing.count,
                sha256: transactionSHA256(drawing)
            ),
            InterruptedDocumentSaveJournal.Entry(
                targetRelativePath: "elements.json",
                action: "replaceFile",
                incomingName: "payload-1",
                byteCount: elementData.count,
                sha256: transactionSHA256(elementData)
            ),
            InterruptedDocumentSaveJournal.Entry(
                targetRelativePath: "manifest.json",
                action: "replaceFile",
                incomingName: "payload-2",
                byteCount: manifestData.count,
                sha256: transactionSHA256(manifestData)
            )
        ]
        _ = try stageInterruptedDocumentSave(
            in: context.url,
            journal: InterruptedDocumentSaveJournal(
                documentKind: .infiniteCanvas,
                packageRelativePath: path,
                documentID: manifest.id,
                entries: entries
            ),
            payloads: [drawing, elementData, manifestData]
        )

        // Simulates a process stop after only the first target was replaced.
        try drawing.write(
            to: context.url.appendingPathComponent(path).appendingPathComponent("drawing.data"),
            options: [.atomic]
        )

        #expect(try await context.store.recoverInterruptedTransactions() == 1)
        let recovered = try await context.store.loadInfiniteCanvas(at: path)
        #expect(recovered.drawingData == drawing)
        #expect(recovered.elements.map(\.id) == elements.map(\.id))
        #expect(recovered.elements.map(\.text) == elements.map(\.text))
        #expect(recovered.manifest.viewport == manifest.viewport)
        #expect(!FileManager.default.fileExists(
            atPath: context.url.appendingPathComponent(".birdnotes-transactions").path
        ))
    }

    @Test("Unterbrochene Seitenlöschung wird idempotent fertiggestellt")
    func interruptedPageDeletionIsCompleted() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createNotebook(named: "Mechanik")
        let added = try await context.store.addPage(toNotebookAt: path)
        var manifest = try await context.store.loadNotebook(at: path).manifest
        manifest.pageOrder.removeAll { $0 == added.id }
        manifest.modifiedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let manifestData = try JSONCoding.encoder().encode(manifest)
        let entries = [
            InterruptedDocumentSaveJournal.Entry(
                targetRelativePath: "manifest.json",
                action: "replaceFile",
                incomingName: "payload-0",
                byteCount: manifestData.count,
                sha256: transactionSHA256(manifestData)
            ),
            InterruptedDocumentSaveJournal.Entry(
                targetRelativePath: "pages/\(added.id.uuidString)",
                action: "deleteDirectory",
                incomingName: nil,
                byteCount: nil,
                sha256: nil
            )
        ]
        _ = try stageInterruptedDocumentSave(
            in: context.url,
            journal: InterruptedDocumentSaveJournal(
                documentKind: .notebook,
                packageRelativePath: path,
                documentID: manifest.id,
                entries: entries
            ),
            payloads: [manifestData]
        )

        // The manifest is already new, while the orphaned page directory is
        // still present. Replaying the whole journal must remain safe.
        try manifestData.write(
            to: context.url.appendingPathComponent(path).appendingPathComponent("manifest.json"),
            options: [.atomic]
        )

        #expect(try await context.store.recoverInterruptedTransactions() == 1)
        let recovered = try await context.store.loadNotebook(at: path)
        #expect(recovered.pages.count == 1)
        #expect(!FileManager.default.fileExists(
            atPath: context.url
                .appendingPathComponent(path)
                .appendingPathComponent("pages/\(added.id.uuidString)").path
        ))
    }

    @Test("Manipuliertes Speicherjournal darf das Dokumentpaket nicht verlassen")
    func documentSaveJournalRejectsPathTraversal() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Sicher")
        let documentID = try await context.store.loadInfiniteCanvas(at: path).manifest.id
        let sentinelURL = context.url.appendingPathComponent("sentinel")
        let sentinel = Data("unverändert".utf8)
        try sentinel.write(to: sentinelURL)
        let payload = Data("Angriff".utf8)
        let entry = InterruptedDocumentSaveJournal.Entry(
            targetRelativePath: "../sentinel",
            action: "replaceFile",
            incomingName: "payload-0",
            byteCount: payload.count,
            sha256: transactionSHA256(payload)
        )
        _ = try stageInterruptedDocumentSave(
            in: context.url,
            journal: InterruptedDocumentSaveJournal(
                documentKind: .infiniteCanvas,
                packageRelativePath: path,
                documentID: documentID,
                entries: [entry]
            ),
            payloads: [payload]
        )

        await #expect(throws: DocumentStoreError.self) {
            _ = try await context.store.recoverInterruptedTransactions()
        }
        #expect(try Data(contentsOf: sentinelURL) == sentinel)
    }

    @Test("Veränderte Journal-Nutzdaten werden vor dem ersten Zielschreibzugriff abgelehnt")
    func documentSaveJournalRejectsChecksumMismatch() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Prüfsumme")
        let original = try await context.store.loadInfiniteCanvas(at: path)
        let expected = Data("BIRD".utf8)
        let tampered = Data("EVIL".utf8)
        let entry = InterruptedDocumentSaveJournal.Entry(
            targetRelativePath: "drawing.data",
            action: "replaceFile",
            incomingName: "payload-0",
            byteCount: expected.count,
            sha256: transactionSHA256(expected)
        )
        _ = try stageInterruptedDocumentSave(
            in: context.url,
            journal: InterruptedDocumentSaveJournal(
                documentKind: .infiniteCanvas,
                packageRelativePath: path,
                documentID: original.manifest.id,
                entries: [entry]
            ),
            payloads: [tampered]
        )

        await #expect(throws: DocumentStoreError.self) {
            _ = try await context.store.recoverInterruptedTransactions()
        }
        #expect(try await context.store.loadInfiniteCanvas(at: path).drawingData == original.drawingData)
    }

    @Test("Parallele Canvas-Saves hinterlassen immer einen zusammengehörigen Paketstand")
    func concurrentCanvasSavesRemainConsistent() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Parallel")
        let store = context.store

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    try await store.saveInfiniteCanvas(
                        drawingData: Data([UInt8(index)]),
                        elements: [CanvasElement(
                            kind: .text,
                            center: CanvasPoint(x: Double(index), y: 100),
                            size: CanvasSize(width: 200, height: 80),
                            text: String(index)
                        )],
                        viewport: CanvasViewport(
                            center: CanvasPoint(x: Double(index), y: 100),
                            zoomScale: 1
                        ),
                        at: path
                    )
                }
            }
            try await group.waitForAll()
        }

        let loaded = try await store.loadInfiniteCanvas(at: path)
        let finalIndex = Int(try #require(loaded.drawingData.first))
        #expect(loaded.elements.first?.text == String(finalIndex))
        #expect(loaded.manifest.viewport.center.x == Double(finalIndex))
        #expect(!FileManager.default.fileExists(
            atPath: context.url.appendingPathComponent(".birdnotes-transactions").path
        ))
    }

    @Test("Papierkorb kann vollständig geleert werden")
    func trashCanBeEmptied() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let first = try await context.store.createNotebook(named: "Alt 1")
        let second = try await context.store.createInfiniteCanvas(named: "Alt 2")
        try await context.store.deleteItem(at: first)
        try await context.store.deleteItem(at: second)

        try await context.store.emptyTrash()

        #expect(try await context.store.listDeletedItems().isEmpty)
        #expect(try await !context.store.hasRestorableItems())
    }

    @Test("Studienbereich wird vollständig mit A4-Cornell-Übersicht erstellt")
    func studyWorkspaceIsCreatedAtomically() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let workspace = try await context.store.createStudyWorkspace(
            named: "1. Semester",
            now: date
        )
        let items = try await context.store.listItems(in: workspace)
        let overview = try await context.store.loadNotebook(
            at: workspace + "/Semesterübersicht.birdnotebook"
        )
        let firstPage = try #require(overview.pages.first)

        #expect(workspace == "1. Semester")
        #expect(Set(items.map(\.name)) == Set([
            "Vorlesungsnotizen",
            "Übungen",
            "Literatur und PDFs",
            "Prüfungsvorbereitung",
            "Semesterübersicht"
        ]))
        #expect(overview.manifest.title == "Semesterübersicht")
        #expect(overview.manifest.createdAt == date)
        #expect(firstPage.metadata.paperStyle == .cornell)
        #expect(firstPage.metadata.paperFormat == .a4)
        #expect(try FileManager.default.contentsOfDirectory(atPath: context.url.path)
            .allSatisfy { !$0.hasSuffix(".study-workspace") })
    }

    @Test("Vollständiger Studiengang wird atomar in Module und Lernnotizen gegliedert")
    func studyProgramWorkspaceIsCreatedAtomically() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let phases = [
            StudyProgramPhaseDefinition(
                title: "1. Semester",
                modules: [
                    StudyProgramModuleDefinition(code: "IREN", title: "Requirements Engineering"),
                    StudyProgramModuleDefinition(code: "PY-01", title: "Programmierung mit Python")
                ]
            ),
            StudyProgramPhaseDefinition(
                title: "2. Semester",
                modules: [
                    StudyProgramModuleDefinition(code: "IDBS", title: "Datenbanksysteme")
                ]
            )
        ]

        let workspace = try await context.store.createStudyProgramWorkspace(
            named: "Software Development Studium",
            phases: phases,
            now: date
        )
        let rootItems = try await context.store.listItems(in: workspace)
        let modulePath = workspace + "/1. Semester/IREN – Requirements Engineering"
        let moduleItems = try await context.store.listItems(in: modulePath)
        let notes = try await context.store.loadNotebook(
            at: modulePath + "/Lernnotizen.birdnotebook"
        )

        #expect(Set(rootItems.map(\.name)) == Set([
            "00 Studienplanung", "Wahlmodule", "Studienübersicht", "1. Semester", "2. Semester"
        ]))
        #expect(Set(moduleItems.map(\.name)) == Set([
            "Lernnotizen", "Active Recall", "Übungen", "Literatur und PDFs", "Prüfungsvorbereitung"
        ]))
        #expect(notes.manifest.createdAt == date)
        #expect(notes.pages.first?.metadata.paperStyle == .cornell)
        #expect(try FileManager.default.contentsOfDirectory(atPath: context.url.path)
            .allSatisfy { !$0.hasSuffix(".study-program") })
    }

    @Test("Eine Bibliothek mit 1.000 Einträgen bleibt vollständig aufzählbar")
    func thousandItemLibraryRemainsComplete() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }

        for index in 1...1_000 {
            _ = try await context.store.createFolder(
                named: String(format: "Lasttest %04d", index)
            )
        }

        let rootItems = try await context.store.listItems()
        let allItems = try await context.store.allItems()
        #expect(rootItems.count == 1_000)
        #expect(allItems.count == 1_000)
        #expect(Set(allItems.map(\.relativePath)).count == 1_000)
        #expect(allItems.allSatisfy { $0.kind == .folder })
    }

    @Test("Ein Canvas mit 2.000 Objekten bleibt über einen Neustart vollständig")
    func twoThousandCanvasElementsPersistAcrossStoreInstances() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        let path = try await context.store.createInfiniteCanvas(named: "Großer Canvas")
        let viewport = CanvasViewport(
            center: CanvasPoint(x: 8_192, y: 8_192),
            zoomScale: 0.42
        )
        let elements = (0..<2_000).map { index in
            CanvasElement(
                kind: .shape,
                center: CanvasPoint(
                    x: 1_000 + Double(index % 50) * 250,
                    y: 1_000 + Double(index / 50) * 190
                ),
                size: CanvasSize(width: 150, height: 100),
                shapeKind: index.isMultiple(of: 2) ? .rectangle : .ellipse,
                strokeColor: index.isMultiple(of: 3) ? .accent : .ink,
                strokeWidth: 3
            )
        }

        try await context.store.saveInfiniteCanvas(
            drawingData: Data([0x42, 0x49, 0x52, 0x44]),
            elements: elements,
            viewport: viewport,
            at: path
        )

        let reopenedStore = try DocumentStore(rootURL: context.url)
        let reopened = try await reopenedStore.loadInfiniteCanvas(at: path)
        #expect(reopened.elements.count == 2_000)
        #expect(Set(reopened.elements.map(\.id)) == Set(elements.map(\.id)))
        #expect(reopened.manifest.viewport == viewport)
    }

    @Test("Technik-Pakete funktionieren mit Bibliothek, Kopie, Papierkorb und Backup")
    func technicalPackagesParticipateInLibraryLifecycle() async throws {
        let context = try TemporaryStore()
        defer { context.remove() }
        _ = try writeTechnicalPackage(named: "Schaltung", in: context.url)

        let listed = try await context.store.listItems()
        let item = try #require(listed.first(where: { $0.name == "Schaltung" }))
        #expect(item.kind == .technicalDiagram)

        let renamed = try await context.store.renameItem(at: item.relativePath, to: "Labor")
        #expect(renamed == "Labor.birdtech")
        let renamedURL = context.url.appendingPathComponent(renamed)
        let originalID = try technicalDocumentID(at: renamedURL)

        let copied = try await context.store.duplicateItem(at: renamed)
        let copiedURL = context.url.appendingPathComponent(copied)
        #expect(copied == "Labor Kopie.birdtech")
        #expect(try technicalDocumentID(at: copiedURL) != originalID)

        try await context.store.deleteItem(at: renamed)
        let deleted = try #require(try await context.store.listDeletedItems().first)
        #expect(deleted.kind == .technicalDiagram)
        #expect(try await context.store.restoreDeletedItem(id: deleted.id) == renamed)

        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotesTechnicalBackup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: exportDirectory) }
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: false)
        let backup = try await context.store.createLibraryBackup(in: exportDirectory)
        let preview = try await context.store.inspectLibraryBackup(at: backup)
        #expect(preview.itemNames.contains("Labor"))
        #expect(preview.itemNames.contains("Labor Kopie"))
    }
}
