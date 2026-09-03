import SwiftUI
import BirdNotesCore

enum BirdNotesTheme {
    static let accent = Color(red: 0.05, green: 0.42, blue: 0.78)
    static let accentSecondary = Color(red: 0.08, green: 0.70, blue: 0.88)
    static let libraryBackground = Color(uiColor: .systemGroupedBackground)
    static let workspaceBackground = Color(uiColor: .secondarySystemBackground)
    static let sidebarBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .systemBackground)

    static func color(for item: BirdNotesCore.LibraryItem) -> Color {
        let palette: [Color] = [
            accent,
            accentSecondary,
            Color(red: 0.13, green: 0.64, blue: 0.64),
            Color(red: 0.95, green: 0.56, blue: 0.24),
            Color(red: 0.91, green: 0.34, blue: 0.48),
            Color(red: 0.31, green: 0.62, blue: 0.36)
        ]
        let value = item.name.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
        }
        return palette[value % palette.count]
    }
}

extension LibraryItemKind {
    var displayName: String {
        switch self {
        case .folder: "Ordner"
        case .notebook: "Notizbuch"
        case .infiniteCanvas: "Canvas"
        case .technicalDiagram: "Technik"
        case .pdf: "PDF"
        }
    }

    var systemImage: String {
        switch self {
        case .folder: "folder.fill"
        case .notebook: "note.text"
        case .infiniteCanvas: "scribble.variable"
        case .technicalDiagram: "point.3.connected.trianglepath.dotted"
        case .pdf: "doc.richtext.fill"
        }
    }
}
