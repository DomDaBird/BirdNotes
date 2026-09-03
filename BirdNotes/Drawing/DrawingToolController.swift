import Combine
import Foundation
import PencilKit
import UIKit

enum DrawingTool: String, CaseIterable, Identifiable {
    case pen
    case marker
    case eraser
    case lasso
    case hand
    case objects

    var id: Self { self }

    var title: String {
        switch self {
        case .pen: "Stift"
        case .marker: "Marker"
        case .eraser: "Radierer"
        case .lasso: "Lasso"
        case .hand: "Hand"
        case .objects: "Objekte"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        case .hand: "hand.draw"
        case .objects: "cursorarrow"
        }
    }
}

enum InkPreset: String, CaseIterable, Identifiable {
    case pen
    case monoline
    case fountainPen
    case pencil

    var id: Self { self }

    var title: String {
        switch self {
        case .pen: "Kugelschreiber"
        case .monoline: "Monoline"
        case .fountainPen: "Füller"
        case .pencil: "Bleistift"
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .pen: .pen
        case .monoline: .monoline
        case .fountainPen: .fountainPen
        case .pencil: .pencil
        }
    }
}

enum EraserMode: String, CaseIterable, Identifiable {
    case stroke
    case pixel
    case fixedWidth

    var id: Self { self }

    var title: String {
        switch self {
        case .stroke: "Ganze Striche"
        case .pixel: "Pixel"
        case .fixedWidth: "Feste Breite"
        }
    }
}

@MainActor
final class DrawingToolController: ObservableObject {
    @Published var selectedTool: DrawingTool = .pen
    @Published var inkPreset: InkPreset = .pen
    @Published var eraserMode: EraserMode = .stroke
    @Published var eraserWidth: CGFloat = 28
    @Published var penColor = UIColor.black
    @Published var markerColor = UIColor.systemYellow.withAlphaComponent(0.35)
    @Published var penWidth: CGFloat = 4
    @Published var markerWidth: CGFloat = 18
    @Published var fingerDraws: Bool {
        didSet {
            preferences.set(fingerDraws, forKey: Self.fingerDrawsKey)
        }
    }
    @Published private(set) var recentColors: [UIColor] = []

    private static let fingerDrawsKey = "BirdNotes.fingerDraws"
    private var toolBeforeEraser: DrawingTool = .pen
    private let recentColorsKey = "BirdNotes.recentDrawingColors"
    private let preferences: UserDefaults

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        // Pencil-only is the safe iPad default: the Apple Pencil edits while
        // one or two fingers remain available for navigation and zooming.
        fingerDraws = preferences.object(forKey: Self.fingerDrawsKey) as? Bool ?? false
        recentColors = (preferences.stringArray(forKey: recentColorsKey) ?? [])
            .compactMap(UIColor.init(birdNotesHex:))
    }

    var pencilKitTool: any PKTool {
        switch selectedTool {
        case .pen:
            PKInkingTool(inkPreset.inkType, color: penColor, width: penWidth)
        case .marker:
            PKInkingTool(.marker, color: markerColor, width: markerWidth)
        case .eraser:
            switch eraserMode {
            case .stroke: PKEraserTool(.vector)
            case .pixel: PKEraserTool(.bitmap)
            case .fixedWidth: PKEraserTool(.fixedWidthBitmap, width: eraserWidth)
            }
        case .lasso:
            PKLassoTool()
        case .hand, .objects:
            PKInkingTool(inkPreset.inkType, color: penColor, width: penWidth)
        }
    }

    func select(_ tool: DrawingTool) {
        if tool != .eraser { toolBeforeEraser = tool }
        selectedTool = tool
    }

    func toggleEraserFromPencil() {
        if selectedTool == .eraser {
            selectedTool = toolBeforeEraser == .eraser ? .pen : toolBeforeEraser
        } else {
            toolBeforeEraser = selectedTool
            selectedTool = .eraser
        }
    }

    func applyColor(_ color: UIColor) {
        let opaqueColor = color.withAlphaComponent(1)
        if selectedTool == .marker {
            markerColor = opaqueColor.withAlphaComponent(0.35)
        } else {
            penColor = opaqueColor
        }
        rememberColor(opaqueColor)
    }

    private func rememberColor(_ color: UIColor) {
        guard let hex = color.birdNotesHex else { return }
        recentColors.removeAll { $0.birdNotesHex == hex }
        recentColors.insert(color, at: 0)
        recentColors = Array(recentColors.prefix(5))
        preferences.set(recentColors.compactMap(\.birdNotesHex), forKey: recentColorsKey)
    }
}

@MainActor
final class CanvasProxy: ObservableObject {
    weak var canvasView: PKCanvasView?

    var canUndo: Bool { canvasView?.undoManager?.canUndo == true }
    var canRedo: Bool { canvasView?.undoManager?.canRedo == true }

    func attach(_ canvasView: PKCanvasView) {
        self.canvasView = canvasView
        objectWillChange.send()
    }

    func undo() {
        canvasView?.undoManager?.undo()
        refresh()
    }

    func redo() {
        canvasView?.undoManager?.redo()
        refresh()
    }

    func refresh() {
        objectWillChange.send()
    }
}

private extension UIColor {
    convenience init?(birdNotesHex: String) {
        let clean = birdNotesHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = UInt64(clean, radix: 16) else { return nil }
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }

    var birdNotesHex: String? {
        guard let components = cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        )?.components, components.count >= 3 else { return nil }
        return String(
            format: "%02X%02X%02X",
            Int(components[0] * 255),
            Int(components[1] * 255),
            Int(components[2] * 255)
        )
    }
}
