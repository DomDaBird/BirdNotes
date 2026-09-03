import Foundation
import Testing
@testable import BirdNotesCore

@Suite("Automatische letzte Seite")
struct NotebookPageCreationPolicyTests {
    @Test("Zeichnen auf der einzigen leeren Seite erzeugt eine freie Folgeseite")
    func drawingOnOnlyEmptyPageCreatesTrailingPage() {
        let first = NotebookPageMetadata(
            paperStyle: .grid,
            paperFormat: .a3,
            paperOrientation: .landscape,
            isEmpty: true
        )

        let trailing = NotebookPageCreationPolicy.trailingPage(
            afterDrawingOn: first.id,
            pagesBeforeEdit: [first]
        )

        #expect(trailing != nil)
        #expect(trailing?.isEmpty == true)
        #expect(trailing?.paperStyle == .grid)
        #expect(trailing?.paperFormat == .a3)
        #expect(trailing?.paperOrientation == .landscape)
    }

    @Test("Erneutes Zeichnen auf Seite eins erzeugt keine dritte Seite")
    func drawingAgainOnFirstPageDoesNotCreateThirdPage() {
        let first = NotebookPageMetadata(isEmpty: false)
        let second = NotebookPageMetadata(isEmpty: true)

        let trailing = NotebookPageCreationPolicy.trailingPage(
            afterDrawingOn: first.id,
            pagesBeforeEdit: [first, second]
        )

        #expect(trailing == nil)
    }

    @Test("Ältere Seiten ohne Format werden als A4 geladen")
    func legacyPageMetadataDefaultsToA4() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "createdAt": "2026-08-16T08:00:00Z",
          "modifiedAt": "2026-08-16T08:00:00Z",
          "paperStyle": "blank",
          "isEmpty": true
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let metadata = try decoder.decode(
            NotebookPageMetadata.self,
            from: Data(json.utf8)
        )

        #expect(metadata.paperFormat == .a4)
        #expect(metadata.paperOrientation == .portrait)
    }
}
