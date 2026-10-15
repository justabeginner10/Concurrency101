import Foundation
import CoreGraphics

/// Keep the explanation within the viewport and outside the visible highlight.
/// Wide screens use the space beside a component; phones use above or below.
struct PageGuidePlacement {
    let highlight: CGRect
    let tooltip: CGRect
    let connectorStart: CGPoint
    let connectorEnd: CGPoint

    init(target: CGRect, viewport: CGSize) {
        let bounds = CGRect(origin: .zero, size: viewport).insetBy(dx: 12, dy: 12)
        let visible = target.insetBy(dx: -5, dy: -5).intersection(bounds)
        let focus = visible.isNull ? CGRect(x: bounds.midX, y: bounds.minY, width: 1, height: 1) : visible
        let width = min(340, bounds.width)
        let height = min(250, bounds.height - 40)
        let gap: CGFloat = 12
        var card: CGRect
        var hole = focus
        if bounds.maxX - focus.maxX >= width + gap {
            card = CGRect(x: focus.maxX + gap, y: min(max(bounds.minY, focus.midY - height / 2), bounds.maxY - height), width: width, height: height)
        } else if focus.minX - bounds.minX >= width + gap {
            card = CGRect(x: focus.minX - gap - width, y: min(max(bounds.minY, focus.midY - height / 2), bounds.maxY - height), width: width, height: height)
        } else {
            let below = bounds.maxY - focus.maxY - gap
            let above = focus.minY - bounds.minY - gap
            let x = min(max(bounds.minX, focus.midX - width / 2), bounds.maxX - width)
            if max(below, above) >= 170 {
                let h = min(height, max(below, above))
                card = CGRect(x: x, y: below >= above ? focus.maxY + gap : focus.minY - gap - h, width: width, height: h)
            } else {
                // A tall pane can fill the viewport. Keep its visible upper
                // portion highlighted and reserve the lower part for the tip.
                let h = min(height, bounds.height * 0.55)
                card = CGRect(x: x, y: bounds.maxY - h, width: width, height: h)
                hole = focus.intersection(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(1, card.minY - gap - bounds.minY)))
                if hole.isNull || hole.isEmpty {
                    // On a short landscape screen a small target can lie
                    // wholly below the reserved area. Put the tip above it.
                    let h = min(height, above)
                    card = CGRect(x: x, y: focus.minY - gap - h, width: width, height: h)
                    hole = focus
                }
            }
        }
        highlight = hole
        tooltip = card
        if card.minX >= hole.maxX {
            connectorStart = CGPoint(x: hole.maxX, y: hole.midY)
            connectorEnd = CGPoint(x: card.minX, y: card.midY)
        } else if card.maxX <= hole.minX {
            connectorStart = CGPoint(x: hole.minX, y: hole.midY)
            connectorEnd = CGPoint(x: card.maxX, y: card.midY)
        } else if card.minY >= hole.maxY {
            connectorStart = CGPoint(x: min(max(card.midX, hole.minX), hole.maxX), y: hole.maxY)
            connectorEnd = CGPoint(x: card.midX, y: card.minY)
        } else {
            connectorStart = CGPoint(x: min(max(card.midX, hole.minX), hole.maxX), y: hole.minY)
            connectorEnd = CGPoint(x: card.midX, y: card.maxY)
        }
    }
}
