import Foundation

public indirect enum DiagramCommand: Codable, Equatable, Sendable {
    case addElement(DiagramElement)
    case removeElement(UUID)
    case replaceElement(DiagramElement)
    case moveElements(ids: [UUID], delta: TechnicalPoint)
    case addConnection(DiagramConnection)
    case removeConnection(UUID)
    case replaceConnection(DiagramConnection)
    case addLabel(DiagramLabel)
    case removeLabel(UUID)
    case replaceLabel(DiagramLabel)
    case addConstraint(DiagramConstraint)
    case removeConstraint(UUID)
    case replaceConstraint(DiagramConstraint)
    case setGrid(DiagramGrid)
    case composite([DiagramCommand])
}

public struct DiagramEditResult: Sendable {
    public let diagram: TechnicalDiagram
    public let inverseCommand: DiagramCommand

    public init(diagram: TechnicalDiagram, inverseCommand: DiagramCommand) {
        self.diagram = diagram
        self.inverseCommand = inverseCommand
    }
}

public struct DiagramCommandExecutor: Sendable {
    public let validator: DiagramValidator

    public init(validator: DiagramValidator = DiagramValidator()) {
        self.validator = validator
    }

    public func apply(_ command: DiagramCommand, to source: TechnicalDiagram) throws -> DiagramEditResult {
        var diagram = source
        let inverse = try applyUnchecked(command, to: &diagram)
        try validator.validate(diagram)
        return DiagramEditResult(diagram: diagram, inverseCommand: inverse)
    }

    private func applyUnchecked(_ command: DiagramCommand, to diagram: inout TechnicalDiagram) throws -> DiagramCommand {
        switch command {
        case .addElement(let element):
            guard !diagram.elements.contains(where: { $0.id == element.id }) else {
                throw TechnicalCoreError.itemAlreadyExists
            }
            try requireEditableLayer(element.layerID, in: diagram)
            diagram.elements.append(element)
            return .removeElement(element.id)

        case .removeElement(let id):
            guard let index = diagram.elements.firstIndex(where: { $0.id == id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let element = diagram.elements[index]
            try requireEditable(element, in: diagram)
            let connections = diagram.connections.filter {
                $0.source.elementID == id || $0.destination.elementID == id
            }
            let constraints = diagram.constraints.filter { $0.elementIDs.contains(id) }
            diagram.elements.remove(at: index)
            diagram.connections.removeAll {
                $0.source.elementID == id || $0.destination.elementID == id
            }
            diagram.constraints.removeAll { $0.elementIDs.contains(id) }
            return .composite(
                [.addElement(element)]
                    + connections.map(DiagramCommand.addConnection)
                    + constraints.map(DiagramCommand.addConstraint)
            )

        case .replaceElement(let replacement):
            guard let index = diagram.elements.firstIndex(where: { $0.id == replacement.id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let previous = diagram.elements[index]
            try requireEditableLayer(replacement.layerID, in: diagram)
            diagram.elements[index] = replacement
            return .replaceElement(previous)

        case .moveElements(let ids, let delta):
            guard !ids.isEmpty,
                  Set(ids).count == ids.count,
                  delta.x.isFinite,
                  delta.y.isFinite else {
                throw TechnicalCoreError.commandRejected("Ungültige Auswahl oder Verschiebung.")
            }
            for id in ids {
                guard let index = diagram.elements.firstIndex(where: { $0.id == id }) else {
                    throw TechnicalCoreError.itemNotFound
                }
                try requireEditable(diagram.elements[index], in: diagram)
                diagram.elements[index].frame.origin.x += delta.x
                diagram.elements[index].frame.origin.y += delta.y
            }
            return .moveElements(ids: ids, delta: TechnicalPoint(x: -delta.x, y: -delta.y))

        case .addConnection(let connection):
            guard !diagram.connections.contains(where: { $0.id == connection.id }) else {
                throw TechnicalCoreError.itemAlreadyExists
            }
            try requireEditableLayer(connection.layerID, in: diagram)
            diagram.connections.append(connection)
            return .removeConnection(connection.id)

        case .removeConnection(let id):
            guard let index = diagram.connections.firstIndex(where: { $0.id == id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let connection = diagram.connections[index]
            try requireEditableLayer(connection.layerID, in: diagram)
            diagram.connections.remove(at: index)
            return .addConnection(connection)

        case .replaceConnection(let replacement):
            guard let index = diagram.connections.firstIndex(where: { $0.id == replacement.id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let previous = diagram.connections[index]
            try requireEditableLayer(previous.layerID, in: diagram)
            try requireEditableLayer(replacement.layerID, in: diagram)
            diagram.connections[index] = replacement
            return .replaceConnection(previous)

        case .addLabel(let label):
            guard !diagram.labels.contains(where: { $0.id == label.id }) else {
                throw TechnicalCoreError.itemAlreadyExists
            }
            try requireEditableLayer(label.layerID, in: diagram)
            diagram.labels.append(label)
            return .removeLabel(label.id)

        case .removeLabel(let id):
            guard let index = diagram.labels.firstIndex(where: { $0.id == id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let label = diagram.labels[index]
            try requireEditableLayer(label.layerID, in: diagram)
            diagram.labels.remove(at: index)
            return .addLabel(label)

        case .replaceLabel(let replacement):
            guard let index = diagram.labels.firstIndex(where: { $0.id == replacement.id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let previous = diagram.labels[index]
            try requireEditableLayer(previous.layerID, in: diagram)
            try requireEditableLayer(replacement.layerID, in: diagram)
            diagram.labels[index] = replacement
            return .replaceLabel(previous)

        case .addConstraint(let constraint):
            guard !diagram.constraints.contains(where: { $0.id == constraint.id }) else {
                throw TechnicalCoreError.itemAlreadyExists
            }
            diagram.constraints.append(constraint)
            return .removeConstraint(constraint.id)

        case .removeConstraint(let id):
            guard let index = diagram.constraints.firstIndex(where: { $0.id == id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let constraint = diagram.constraints.remove(at: index)
            return .addConstraint(constraint)

        case .replaceConstraint(let replacement):
            guard let index = diagram.constraints.firstIndex(where: { $0.id == replacement.id }) else {
                throw TechnicalCoreError.itemNotFound
            }
            let previous = diagram.constraints[index]
            diagram.constraints[index] = replacement
            return .replaceConstraint(previous)

        case .setGrid(let grid):
            let previous = diagram.grid
            diagram.grid = grid
            return .setGrid(previous)

        case .composite(let commands):
            guard commands.count <= 10_000 else {
                throw TechnicalCoreError.commandRejected("Zu viele Änderungen in einem Vorgang.")
            }
            var inverses: [DiagramCommand] = []
            for nested in commands {
                inverses.append(try applyUnchecked(nested, to: &diagram))
            }
            return .composite(Array(inverses.reversed()))
        }
    }

    private func requireEditable(_ element: DiagramElement, in diagram: TechnicalDiagram) throws {
        guard !element.isLocked else {
            throw TechnicalCoreError.commandRejected("Das Element ist gesperrt.")
        }
        try requireEditableLayer(element.layerID, in: diagram)
    }

    private func requireEditableLayer(_ id: UUID, in diagram: TechnicalDiagram) throws {
        guard let layer = diagram.layers.first(where: { $0.id == id }) else {
            throw TechnicalCoreError.commandRejected("Die Ebene existiert nicht.")
        }
        guard !layer.isLocked else {
            throw TechnicalCoreError.commandRejected("Die Ebene ist gesperrt.")
        }
    }
}

public struct DiagramHistory: Sendable {
    public private(set) var diagram: TechnicalDiagram
    public let maximumHistoryCount: Int
    private let executor: DiagramCommandExecutor
    private var undoCommands: [DiagramCommand] = []
    private var redoCommands: [DiagramCommand] = []

    public init(
        diagram: TechnicalDiagram,
        maximumHistoryCount: Int = 500,
        executor: DiagramCommandExecutor = DiagramCommandExecutor()
    ) throws {
        try executor.validator.validate(diagram)
        self.diagram = diagram
        self.maximumHistoryCount = max(1, maximumHistoryCount)
        self.executor = executor
    }

    public var canUndo: Bool { !undoCommands.isEmpty }
    public var canRedo: Bool { !redoCommands.isEmpty }

    public mutating func apply(_ command: DiagramCommand) throws {
        let result = try executor.apply(command, to: diagram)
        diagram = result.diagram
        undoCommands.append(result.inverseCommand)
        if undoCommands.count > maximumHistoryCount {
            undoCommands.removeFirst(undoCommands.count - maximumHistoryCount)
        }
        redoCommands.removeAll(keepingCapacity: true)
    }

    public mutating func undo() throws {
        guard let command = undoCommands.popLast() else { return }
        let result = try executor.apply(command, to: diagram)
        diagram = result.diagram
        redoCommands.append(result.inverseCommand)
    }

    public mutating func redo() throws {
        guard let command = redoCommands.popLast() else { return }
        let result = try executor.apply(command, to: diagram)
        diagram = result.diagram
        undoCommands.append(result.inverseCommand)
    }

    public mutating func clearHistory() {
        undoCommands.removeAll(keepingCapacity: false)
        redoCommands.removeAll(keepingCapacity: false)
    }
}
