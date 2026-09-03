import UIKit
import BirdNotesCore

final class PaperBackgroundView: UIView {
    var paperStyle: PaperStyle = .blank {
        didSet {
            if oldValue != paperStyle { setNeedsDisplay() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        overrideUserInterfaceStyle = .light
        backgroundColor = .white
        isOpaque = true
        contentMode = .redraw
        accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        overrideUserInterfaceStyle = .light
        backgroundColor = .white
        isOpaque = true
        contentMode = .redraw
        accessibilityElementsHidden = true
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        UIColor.white.setFill()
        context.fill(rect)

        guard paperStyle != .blank else { return }
        context.saveGState()
        context.setLineWidth(1 / max(window?.screen.scale ?? 2, 1))
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.19).cgColor)

        let spacing: CGFloat = 32
        if paperStyle == .dotted {
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.24).cgColor)
            var x = spacing
            while x <= bounds.maxX {
                var y = spacing
                while y <= bounds.maxY {
                    context.fillEllipse(in: CGRect(x: x - 1.15, y: y - 1.15, width: 2.3, height: 2.3))
                    y += spacing
                }
                x += spacing
            }
        } else {
            let summaryTop = paperStyle == .cornell ? bounds.maxY * 0.82 : bounds.maxY
            var y = spacing
            while y < summaryTop {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
                y += spacing
            }

            if paperStyle == .grid {
                var x = spacing
                while x <= bounds.maxX {
                    context.move(to: CGPoint(x: x, y: 0))
                    context.addLine(to: CGPoint(x: x, y: bounds.maxY))
                    x += spacing
                }
            } else if paperStyle == .cornell {
                let cueColumnX = bounds.maxX * 0.28
                context.move(to: CGPoint(x: cueColumnX, y: 0))
                context.addLine(to: CGPoint(x: cueColumnX, y: summaryTop))
                context.move(to: CGPoint(x: 0, y: summaryTop))
                context.addLine(to: CGPoint(x: bounds.maxX, y: summaryTop))
            }

            context.strokePath()
        }
        context.restoreGState()
    }
}
