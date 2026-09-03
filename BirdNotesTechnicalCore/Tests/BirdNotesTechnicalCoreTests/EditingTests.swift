import Foundation
import Testing
@testable import BirdNotesTechnicalCore

@Suite("Transactional diagram editing")
struct EditingTests {
    @Test("Move, undo and redo preserve a valid diagram")
    func supportsUndoAndRedo() throws {
        var diagram = TechnicalDiagram(domain: .general)
        let layerID = try #require(diagram.layers.first?.id)
        let element = DiagramElement(
            moduleID: "birdnotes.general",
            symbolID: "box",
            frame: TechnicalRect(
                origin: TechnicalPoint(x: 10, y: 20),
                size: TechnicalSize(width: 100, height: 50)
            ),
            layerID: layerID
        )
        diagram.elements = [element]
        var history = try DiagramHistory(diagram: diagram)

        try history.apply(.moveElements(ids: [element.id], delta: TechnicalPoint(x: 30, y: -10)))
        #expect(history.diagram.elements[0].frame.origin == TechnicalPoint(x: 40, y: 10))
        #expect(history.canUndo)

        try history.undo()
        #expect(history.diagram.elements[0].frame.origin == TechnicalPoint(x: 10, y: 20))
        #expect(history.canRedo)

        try history.redo()
        #expect(history.diagram.elements[0].frame.origin == TechnicalPoint(x: 40, y: 10))
    }

    @Test("Removing an element and undoing restores its semantic edges")
    func restoresRelatedObjects() throws {
        var diagram = TechnicalDiagram(domain: .general)
        let layerID = try #require(diagram.layers.first?.id)
        let first = element(at: 0, layerID: layerID)
        let second = element(at: 200, layerID: layerID)
        diagram.elements = [first, second]
        diagram.connections = [DiagramConnection(
            source: ConnectionEndpoint(elementID: first.id, portID: "port"),
            destination: ConnectionEndpoint(elementID: second.id, portID: "port"),
            layerID: layerID
        )]
        diagram.constraints = [DiagramConstraint(kind: .horizontal, elementIDs: [first.id, second.id])]
        var history = try DiagramHistory(diagram: diagram)

        try history.apply(.removeElement(first.id))
        #expect(history.diagram.elements.count == 1)
        #expect(history.diagram.connections.isEmpty)
        #expect(history.diagram.constraints.isEmpty)

        try history.undo()
        #expect(history.diagram.elements.count == 2)
        #expect(history.diagram.connections.count == 1)
        #expect(history.diagram.constraints.count == 1)
    }

    @Test("Invalid commands do not partially alter the source")
    func rejectsInvalidTransaction() throws {
        let diagram = TechnicalDiagram(domain: .general)
        let executor = DiagramCommandExecutor()
        let impossible = DiagramConnection(
            source: ConnectionEndpoint(elementID: UUID(), portID: "missing"),
            destination: ConnectionEndpoint(elementID: UUID(), portID: "missing"),
            layerID: try #require(diagram.layers.first?.id)
        )

        #expect(throws: TechnicalCoreError.self) {
            _ = try executor.apply(.addConnection(impossible), to: diagram)
        }
        #expect(diagram.connections.isEmpty)
    }

    @Test("Grid, alignment and angle snapping are deterministic")
    func snapsGeometry() {
        let engine = SnapEngine(configuration: SnapConfiguration(
            gridSpacing: 10,
            pointTolerance: 2,
            angleIncrementDegrees: 15
        ))

        let grid = engine.snap(TechnicalPoint(x: 9, y: 23))
        #expect(grid.point == TechnicalPoint(x: 10, y: 23))
        #expect(grid.snappedX)
        #expect(!grid.snappedY)

        let aligned = engine.snap(
            TechnicalPoint(x: 31, y: 42),
            alignmentCandidates: [TechnicalPoint(x: 30, y: 41)]
        )
        #expect(aligned.point == TechnicalPoint(x: 30, y: 41))
        #expect(engine.snapAngle(22) == 15)
    }

    private func element(at x: Double, layerID: UUID) -> DiagramElement {
        DiagramElement(
            moduleID: "birdnotes.general",
            symbolID: "box",
            frame: TechnicalRect(
                origin: TechnicalPoint(x: x, y: 0),
                size: TechnicalSize(width: 100, height: 50)
            ),
            ports: [
                DiagramPort(
                    id: "port",
                    name: "Port",
                    kind: "general",
                    position: TechnicalPoint(x: 0.5, y: 0.5)
                )
            ],
            layerID: layerID
        )
    }
}
