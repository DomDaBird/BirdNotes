import CoreGraphics
import BirdNotesCore

extension PaperStyle {
    var displayName: String {
        switch self {
        case .blank: "Leer"
        case .lined: "Liniert"
        case .grid: "Kariert"
        case .dotted: "Punktiert"
        case .cornell: "Cornell-Notizen"
        }
    }

    var systemImage: String {
        switch self {
        case .blank: "doc"
        case .lined: "list.bullet"
        case .grid: "grid"
        case .dotted: "circle.grid.3x3.fill"
        case .cornell: "rectangle.split.2x1"
        }
    }
}

extension PaperFormat {
    var displayName: String { rawValue.uppercased() }

    var pageSize: CGSize {
        pageSize(for: .portrait)
    }

    func pageSize(for orientation: PaperOrientation) -> CGSize {
        switch orientation {
        case .portrait:
            CGSize(width: width, height: height)
        case .landscape:
            CGSize(width: height, height: width)
        }
    }
}

extension PaperOrientation {
    var displayName: String {
        switch self {
        case .portrait: "Hochformat"
        case .landscape: "Querformat"
        }
    }

    var systemImage: String {
        switch self {
        case .portrait: "rectangle.portrait"
        case .landscape: "rectangle"
        }
    }
}

extension NotebookPageMetadata {
    var pageSize: CGSize {
        paperFormat.pageSize(for: paperOrientation)
    }
}
