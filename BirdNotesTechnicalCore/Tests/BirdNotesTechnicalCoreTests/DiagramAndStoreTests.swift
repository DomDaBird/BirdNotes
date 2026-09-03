import Foundation
import Testing
@testable import BirdNotesTechnicalCore

@Suite("Semantic diagrams")
struct DiagramTests {
    @Test("A connected semantic graph validates")
    func validatesConnectedGraph() throws {
        let diagram = try sampleDiagram()
        try DiagramValidator().validate(diagram)
    }

    @Test("Dangling ports and duplicate identifiers are rejected")
    func rejectsBrokenReferences() throws {
        var dangling = try sampleDiagram()
        dangling.connections[0].destination.portID = "missing"
        #expect(throws: TechnicalCoreError.self) {
            try DiagramValidator().validate(dangling)
        }

        var duplicate = try sampleDiagram()
        duplicate.elements.append(duplicate.elements[0])
        #expect(throws: TechnicalCoreError.self) {
            try DiagramValidator().validate(duplicate)
        }
    }

    @Test("Non-finite geometry and object floods are rejected")
    func enforcesResourceLimits() throws {
        var invalid = TechnicalDiagram(domain: .general)
        invalid.canvasSize.width = .infinity
        #expect(throws: TechnicalCoreError.self) {
            try DiagramValidator().validate(invalid)
        }

        let strict = DiagramValidator(limits: DiagramLimits(maximumElements: 0))
        let diagram = try sampleDiagram()
        #expect(throws: TechnicalCoreError.self) {
            try strict.validate(diagram)
        }
    }
}

@Suite(".birdtech document packages")
struct BirdTechDocumentStoreTests {
    @Test("A document round-trips with checksums and optional data")
    func roundTrip() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try BirdTechDocumentStore(rootURL: root)
        var document = BirdTechDocument.blank(
            title: "Ohmsches Gesetz",
            domain: .electricalEngineering,
            writerVersion: "3.0.0-dev"
        )
        document.diagram = try sampleDiagram()
        document.annotationsData = Data("pencil-data".utf8)
        document.previewPNGData = Data([0x89, 0x50, 0x4E, 0x47])
        document.calculations.items = [TechnicalCalculation(name: "Spannung", expression: "current * resistance")]

        let url = try await store.save(document)
        let loaded = try await store.load(documentID: document.manifest.documentID)
        let summaries = try await store.list()

        #expect(url.pathExtension == "birdtech")
        #expect(loaded.manifest.title == document.manifest.title)
        #expect(loaded.manifest.diagramSHA256.count == 64)
        #expect(loaded.annotationsData == document.annotationsData)
        #expect(loaded.diagram.elements.count == 2)
        #expect(summaries.map(\.documentID) == [document.manifest.documentID])
    }

    @Test("Readable package names support create, autosave and ID lookup")
    func namedPackageLifecycle() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try BirdTechDocumentStore(rootURL: root)
        var document = BirdTechDocument.blank(
            title: "Schaltung 1",
            domain: .electricalEngineering,
            writerVersion: "3.0.0"
        )
        let destination = root.appendingPathComponent("Schaltung 1.birdtech", isDirectory: true)

        _ = try await store.create(document, at: destination)
        await #expect(throws: TechnicalCoreError.self) {
            _ = try await store.create(document, at: destination)
        }

        document.manifest.title = "Schaltung 1 – bearbeitet"
        _ = try await store.save(document, at: destination)
        let loadedByID = try await store.load(documentID: document.manifest.documentID)

        #expect(loadedByID.manifest.title == "Schaltung 1 – bearbeitet")
        #expect(try await store.list().first?.url.lastPathComponent == "Schaltung 1.birdtech")
    }

    @Test("The published v1 golden package remains loadable and saveable")
    func goldenV1RoundTrip() async throws {
        let fixture = try #require(Bundle.module.url(
            forResource: "Technical-v1",
            withExtension: "birdtech",
            subdirectory: "Fixtures"
        ))
        let fixtureStore = try BirdTechDocumentStore(rootURL: fixture.deletingLastPathComponent())
        let loaded = try await fixtureStore.load(from: fixture)
        #expect(loaded.manifest.schemaVersion == 1)
        #expect(loaded.manifest.title == "Golden Technical v1")

        let destinationRoot = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: destinationRoot) }
        let destinationStore = try BirdTechDocumentStore(rootURL: destinationRoot)
        let destination = destinationRoot.appendingPathComponent("Golden Copy.birdtech")
        _ = try await destinationStore.create(loaded, at: destination)
        let reopened = try await destinationStore.load(from: destination)

        #expect(reopened.diagram == loaded.diagram)
        #expect(reopened.calculations == loaded.calculations)
    }

    @Test("Tampering is detected before a document is decoded")
    func detectsTampering() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try BirdTechDocumentStore(rootURL: root)
        var document = BirdTechDocument.blank(
            title: "Integrität",
            domain: .general,
            writerVersion: "3.0.0-dev"
        )
        document.diagram = TechnicalDiagram(domain: .general)
        let packageURL = try await store.save(document)
        let diagramURL = packageURL.appendingPathComponent("diagram.json")
        var data = try Data(contentsOf: diagramURL)
        data.append(0x20)
        try data.write(to: diagramURL)

        await #expect(throws: TechnicalCoreError.self) {
            _ = try await store.load(documentID: document.manifest.documentID)
        }
    }

    @Test("Symbolic-link packages are rejected")
    func rejectsSymbolicLinks() async throws {
        let root = temporaryRoot()
        let outside = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("external.birdtech")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let store = try BirdTechDocumentStore(rootURL: root)

        await #expect(throws: TechnicalCoreError.self) {
            _ = try await store.load(from: link)
        }
    }

    @Test("Delete removes only the selected package")
    func deletesSelectedPackage() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try BirdTechDocumentStore(rootURL: root)
        let first = BirdTechDocument.blank(title: "A", domain: .general, writerVersion: "3.0.0-dev")
        let second = BirdTechDocument.blank(title: "B", domain: .general, writerVersion: "3.0.0-dev")
        _ = try await store.save(first)
        _ = try await store.save(second)

        try await store.delete(documentID: first.manifest.documentID)

        #expect(try await store.list().map(\.documentID) == [second.manifest.documentID])
        await #expect(throws: TechnicalCoreError.self) {
            _ = try await store.load(documentID: first.manifest.documentID)
        }
    }
}

private func sampleDiagram() throws -> TechnicalDiagram {
    var diagram = TechnicalDiagram(domain: .electricalEngineering)
    let layerID = try #require(diagram.layers.first?.id)
    let source = DiagramElement(
        moduleID: "birdnotes.electrical",
        symbolID: "voltage-source",
        frame: TechnicalRect(
            origin: TechnicalPoint(x: 100, y: 100),
            size: TechnicalSize(width: 80, height: 80)
        ),
        ports: [
            DiagramPort(id: "positive", name: "+", kind: "electrical", position: TechnicalPoint(x: 1, y: 0.5)),
            DiagramPort(id: "negative", name: "-", kind: "electrical", position: TechnicalPoint(x: 0, y: 0.5))
        ],
        layerID: layerID
    )
    let resistor = DiagramElement(
        moduleID: "birdnotes.electrical",
        symbolID: "resistor",
        frame: TechnicalRect(
            origin: TechnicalPoint(x: 300, y: 100),
            size: TechnicalSize(width: 120, height: 50)
        ),
        ports: [
            DiagramPort(id: "a", name: "A", kind: "electrical", position: TechnicalPoint(x: 0, y: 0.5)),
            DiagramPort(id: "b", name: "B", kind: "electrical", position: TechnicalPoint(x: 1, y: 0.5))
        ],
        properties: ["resistance": .quantity(try Quantity(value: 1, unitID: "kiloohm"))],
        layerID: layerID
    )
    diagram.elements = [source, resistor]
    diagram.connections = [DiagramConnection(
        source: ConnectionEndpoint(elementID: source.id, portID: "positive"),
        destination: ConnectionEndpoint(elementID: resistor.id, portID: "a"),
        route: [TechnicalPoint(x: 220, y: 140)],
        layerID: layerID
    )]
    return diagram
}

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("BirdNotesTechnicalCoreTests-\(UUID().uuidString)", isDirectory: true)
}
