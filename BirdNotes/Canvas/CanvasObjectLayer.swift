import Foundation
import os.signpost
import SwiftUI
import UIKit
import BirdNotesCore

struct CanvasVisibleElement: Identifiable, Equatable {
    let id: UUID
    let index: Int
}

struct CanvasVisibleConnector: Identifiable, Equatable {
    let id: UUID
    let source: CanvasPoint
    let target: CanvasPoint
    let strokeColor: CanvasColor
    let strokeWidth: Double
}

struct CanvasProjectionSnapshot: Equatable {
    let totalElements: Int
    let visibleElements: Int
    let visibleConnectors: Int
}

/// Projects only objects intersecting the current viewport. Building the ID
/// lookup once also keeps connector resolution linear instead of repeatedly
/// scanning all objects for every line.
struct CanvasViewportProjection {
    let visibleElements: [CanvasVisibleElement]
    let visibleConnectors: [CanvasVisibleConnector]
    let snapshot: CanvasProjectionSnapshot

    init(
        elements: [CanvasElement],
        viewport: CanvasViewport,
        viewportSize: CGSize,
        screenPadding: CGFloat = 160
    ) {
        guard viewport.zoomScale.isFinite,
              viewport.zoomScale > 0,
              viewportSize.width.isFinite,
              viewportSize.height.isFinite,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            visibleElements = []
            visibleConnectors = []
            snapshot = CanvasProjectionSnapshot(
                totalElements: elements.count,
                visibleElements: 0,
                visibleConnectors: 0
            )
            return
        }

        let zoomScale = viewport.zoomScale
        let horizontalRadius = Double(viewportSize.width / 2 + screenPadding) / zoomScale
        let verticalRadius = Double(viewportSize.height / 2 + screenPadding) / zoomScale
        let visibleBounds = (
            minX: viewport.center.x - horizontalRadius,
            maxX: viewport.center.x + horizontalRadius,
            minY: viewport.center.y - verticalRadius,
            maxY: viewport.center.y + verticalRadius
        )

        var elementsByID: [UUID: CanvasElement] = [:]
        elementsByID.reserveCapacity(elements.count)
        for element in elements where element.kind != .connector {
            elementsByID[element.id] = element
        }

        var projectedElements: [CanvasVisibleElement] = []
        var projectedConnectors: [CanvasVisibleConnector] = []
        projectedElements.reserveCapacity(min(elements.count, 128))
        projectedConnectors.reserveCapacity(min(elements.count / 4, 64))

        for (index, element) in elements.enumerated() {
            if element.kind == .connector {
                guard let sourceID = element.sourceElementID,
                      let targetID = element.targetElementID,
                      let source = elementsByID[sourceID],
                      let target = elementsByID[targetID],
                      Self.intersects(
                        minX: min(source.center.x, target.center.x),
                        maxX: max(source.center.x, target.center.x),
                        minY: min(source.center.y, target.center.y),
                        maxY: max(source.center.y, target.center.y),
                        visibleBounds: visibleBounds
                      ) else { continue }
                projectedConnectors.append(CanvasVisibleConnector(
                    id: element.id,
                    source: source.center,
                    target: target.center,
                    strokeColor: element.strokeColor,
                    strokeWidth: element.strokeWidth
                ))
                continue
            }

            // A rotation-safe radius deliberately over-includes objects near
            // an edge so they never disappear while being rotated.
            let radius = hypot(element.size.width, element.size.height) / 2
            if Self.intersects(
                minX: element.center.x - radius,
                maxX: element.center.x + radius,
                minY: element.center.y - radius,
                maxY: element.center.y + radius,
                visibleBounds: visibleBounds
            ) {
                projectedElements.append(CanvasVisibleElement(id: element.id, index: index))
            }
        }

        visibleElements = projectedElements
        visibleConnectors = projectedConnectors
        snapshot = CanvasProjectionSnapshot(
            totalElements: elements.count,
            visibleElements: projectedElements.count,
            visibleConnectors: projectedConnectors.count
        )
    }

    private static func intersects(
        minX: Double,
        maxX: Double,
        minY: Double,
        maxY: Double,
        visibleBounds: (minX: Double, maxX: Double, minY: Double, maxY: Double)
    ) -> Bool {
        maxX >= visibleBounds.minX
            && minX <= visibleBounds.maxX
            && maxY >= visibleBounds.minY
            && minY <= visibleBounds.maxY
    }
}

enum CanvasPerformanceDiagnostics {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dominikvogel.BirdNotes",
        category: "PointsOfInterest"
    )

    static func recordProjection(_ snapshot: CanvasProjectionSnapshot) {
        os_signpost(
            .event,
            log: log,
            name: "Canvas Viewport",
            "total=%{public}d objects=%{public}d connectors=%{public}d",
            snapshot.totalElements,
            snapshot.visibleElements,
            snapshot.visibleConnectors
        )
    }
}

struct CanvasObjectLayer: View {
    @Binding var elements: [CanvasElement]
    @Binding var selectedElementID: UUID?
    let viewport: CanvasViewport
    let editingEnabled: Bool
    let onElementsChanged: () -> Void
    let onDuplicate: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let projection = CanvasViewportProjection(
                elements: elements,
                viewport: viewport,
                viewportSize: geometry.size
            )
            ZStack {
                connectorLayer(projection.visibleConnectors, in: geometry.size)

                ForEach(projection.visibleElements) { visibleElement in
                    let element = elements[visibleElement.index]
                    CanvasElementView(
                        element: $elements[visibleElement.index],
                        isSelected: selectedElementID == element.id,
                        zoomScale: viewport.zoomScale,
                        editingEnabled: editingEnabled,
                        onSelect: { selectedElementID = element.id },
                        onCommit: onElementsChanged
                    )
                    .frame(
                        width: max(element.size.width * viewport.zoomScale, 28),
                        height: max(element.size.height * viewport.zoomScale, 28)
                    )
                    .position(screenPosition(for: element.center, in: geometry.size))
                    .rotationEffect(.radians(element.rotation))
                    .contextMenu {
                        Button("Duplizieren", systemImage: "plus.square.on.square") {
                            onDuplicate(element.id)
                        }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            onDelete(element.id)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onChange(of: projection.snapshot, initial: true) { _, snapshot in
                CanvasPerformanceDiagnostics.recordProjection(snapshot)
            }
        }
        .allowsHitTesting(editingEnabled)
    }

    private func connectorLayer(
        _ connectors: [CanvasVisibleConnector],
        in size: CGSize
    ) -> some View {
        Canvas { context, _ in
            for connector in connectors {
                let start = screenPosition(for: connector.source, in: size)
                let end = screenPosition(for: connector.target, in: size)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(
                    path,
                    with: .color(Color(connector.strokeColor)),
                    style: StrokeStyle(
                        lineWidth: max(connector.strokeWidth * viewport.zoomScale, 1.2),
                        lineCap: .round
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func screenPosition(for point: CanvasPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + (point.x - viewport.center.x) * viewport.zoomScale,
            y: size.height / 2 + (point.y - viewport.center.y) * viewport.zoomScale
        )
    }
}

private struct CanvasElementView: View {
    @Binding var element: CanvasElement
    let isSelected: Bool
    let zoomScale: Double
    let editingEnabled: Bool
    let onSelect: () -> Void
    let onCommit: () -> Void

    @State private var dragOrigin: CanvasPoint?
    @State private var sizeOrigin: CanvasSize?
    @State private var rotationOrigin: Double?

    var body: some View {
        elementContent
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BirdNotesTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                        .padding(-5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .gesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(rotationGesture)
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var elementContent: some View {
        switch element.kind {
        case .text:
            if isSelected && editingEnabled {
                TextField(
                    "Text",
                    text: Binding(
                        get: { element.text ?? "" },
                        set: {
                            element.text = $0
                            element.modifiedAt = Date()
                            onCommit()
                        }
                    ),
                    axis: .vertical
                )
                .font(.system(size: max(17 * zoomScale, 12)))
                .foregroundStyle(Color(element.strokeColor))
                .padding(10)
                .background(element.fillColor.map(Color.init) ?? Color.white.opacity(0.96))
                .textFieldStyle(.plain)
            } else {
                Text(element.text ?? "Text")
                    .font(.system(size: max(17 * zoomScale, 12)))
                    .foregroundStyle(Color(element.strokeColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
                    .background(element.fillColor.map(Color.init) ?? Color.white.opacity(0.96))
            }
        case .image:
            if let data = element.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            } else {
                ContentUnavailableView("Bild fehlt", systemImage: "photo")
            }
        case .shape:
            CanvasShapeView(element: element)
        case .connector:
            EmptyView()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard editingEnabled else { return }
                onSelect()
                if dragOrigin == nil { dragOrigin = element.center }
                guard let origin = dragOrigin else { return }
                element.center = CanvasPoint(
                    x: origin.x + value.translation.width / max(zoomScale, 0.01),
                    y: origin.y + value.translation.height / max(zoomScale, 0.01)
                )
                element.modifiedAt = Date()
            }
            .onEnded { _ in
                guard editingEnabled else { return }
                dragOrigin = nil
                onCommit()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard editingEnabled, isSelected else { return }
                if sizeOrigin == nil { sizeOrigin = element.size }
                guard let origin = sizeOrigin else { return }
                element.size = CanvasSize(
                    width: max(origin.width * scale, 48),
                    height: max(origin.height * scale, 36)
                )
                element.modifiedAt = Date()
            }
            .onEnded { _ in
                guard editingEnabled, isSelected else { return }
                sizeOrigin = nil
                onCommit()
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                guard editingEnabled, isSelected else { return }
                if rotationOrigin == nil { rotationOrigin = element.rotation }
                element.rotation = (rotationOrigin ?? 0) + angle.radians
                element.modifiedAt = Date()
            }
            .onEnded { _ in
                guard editingEnabled, isSelected else { return }
                rotationOrigin = nil
                onCommit()
            }
    }

    private var accessibilityLabel: String {
        switch element.kind {
        case .text: "Textobjekt"
        case .image: "Bildobjekt"
        case .shape: "Form"
        case .connector: "Verbindung"
        }
    }
}

private struct CanvasShapeView: View {
    let element: CanvasElement

    var body: some View {
        Canvas { context, size in
            let inset = max(element.strokeWidth, 1)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = shapePath(in: rect)
            if let fill = element.fillColor {
                context.fill(path, with: .color(Color(fill)))
            }
            context.stroke(
                path,
                with: .color(Color(element.strokeColor)),
                style: StrokeStyle(lineWidth: max(element.strokeWidth, 1), lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func shapePath(in rect: CGRect) -> Path {
        switch element.shapeKind ?? .rectangle {
        case .line:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        case .arrow:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.move(to: CGPoint(x: rect.maxX - 18, y: rect.midY - 13))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.midY + 13))
            return path
        case .rectangle:
            return Path(rect)
        case .roundedRectangle:
            return Path(roundedRect: rect, cornerRadius: min(22, rect.height / 3))
        case .ellipse:
            return Path(ellipseIn: rect)
        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

extension Color {
    init(_ color: CanvasColor) {
        self.init(
            red: min(max(color.red, 0), 1),
            green: min(max(color.green, 0), 1),
            blue: min(max(color.blue, 0), 1),
            opacity: min(max(color.alpha, 0), 1)
        )
    }
}
