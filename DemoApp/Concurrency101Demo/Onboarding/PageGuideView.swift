import SwiftUI

/// A spotlight and a tooltip on the existing screen. No sheet or navigation away.
struct PageGuideView: View {
    let step: PageGuideStep
    let target: CGRect
    let viewport: CGSize
    let accent: Color
    let current: Int
    let total: Int
    let onSkip: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        let placement = PageGuidePlacement(target: target, viewport: viewport)
        let isVisible = target.intersects(CGRect(origin: .zero, size: viewport).insetBy(dx: 12, dy: 12))
        ZStack(alignment: .topLeading) {
            PageGuideScrim(hole: isVisible ? placement.highlight : .zero)
                .fill(.black.opacity(0.72), style: FillStyle(eoFill: true))
                .contentShape(Rectangle())
                .onTapGesture { }
                .accessibilityHidden(true)
            if isVisible {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(accent, lineWidth: 2)
                    .frame(width: placement.highlight.width, height: placement.highlight.height)
                    .position(x: placement.highlight.midX, y: placement.highlight.midY)
                    .shadow(color: accent.opacity(0.5), radius: 8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                PageGuideTooltip(step: step, accent: accent, current: current, total: total,
                                 pointerEdge: placement.pointerEdge, pointerOffset: placement.pointerOffset,
                                 onSkip: onSkip, onBack: onBack, onNext: onNext)
                    .frame(width: placement.tooltip.width, height: placement.tooltip.height)
                    .position(x: placement.tooltip.midX, y: placement.tooltip.midY)
                    .id(step.id)
            } else {
                // The next target is scrolling into view. Keep navigation
                // blocked without drawing a spotlight at an invented location.
                Button("Skip guide", action: onSkip)
                    .buttonStyle(.bordered)
                    .tint(accent)
                    .padding(16)
            }
        }
        .frame(width: viewport.width, height: viewport.height)
    }
}

private struct PageGuideScrim: Shape {
    let hole: CGRect
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: 8, height: 8))
        return path
    }
}

struct PageGuideTooltip: View {
    let step: PageGuideStep
    let accent: Color
    let current: Int
    let total: Int
    let pointerEdge: PageGuidePlacement.PointerEdge
    let pointerOffset: CGFloat
    let onSkip: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        let bubble = PageGuideBubble(edge: pointerEdge, offset: pointerOffset)
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(step.title)
                            .font(.headline)
                            .foregroundStyle(accent)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($titleFocused)
                        Spacer(minLength: 0)
                        Text("\(current)/\(total)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(DemoTheme.muted)
                            .accessibilityLabel("Step \(current) of \(total)")
                    }
                    Text(step.message)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DemoTheme.muted)
                .accessibilityLabel("Skip guide")
                .keyboardShortcut(.cancelAction)
                Spacer(minLength: 0)
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous component")
                .disabled(current == 1)
                Button(action: onNext) {
                    Group {
                        if current == total { Text("Done") } else { Text("Next") }
                    }
                    .frame(minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DemoTheme.void)
                .keyboardShortcut(.defaultAction)
            }
            .font(.subheadline)
            .tint(accent)
            .controlSize(.regular)
        }
        .padding(14)
        .background { bubble.fill(DemoTheme.void) }
        .overlay {
            bubble.stroke(accent.opacity(0.65), lineWidth: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        .onAppear { titleFocused = true }
    }
}

/// One continuous outline avoids a seam where the pointer joins the card.
private struct PageGuideBubble: Shape {
    let edge: PageGuidePlacement.PointerEdge
    let offset: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(12, min(rect.width, rect.height) / 2)
        let halfBase: CGFloat = 9
        let depth: CGFloat = 10
        let length = (edge == .top || edge == .bottom) ? rect.width : rect.height
        let clearance = min(radius + halfBase + 2, length / 2)
        let center = min(max(offset, clearance), length - clearance)
        let base = min(halfBase, max(0, length / 2 - radius))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        if edge == .top {
            path.addLine(to: CGPoint(x: rect.minX + center - base, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + center, y: rect.minY - depth))
            path.addLine(to: CGPoint(x: rect.minX + center + base, y: rect.minY))
        }
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        if edge == .right {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + center - base))
            path.addLine(to: CGPoint(x: rect.maxX + depth, y: rect.minY + center))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + center + base))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        if edge == .bottom {
            path.addLine(to: CGPoint(x: rect.minX + center + base, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + center, y: rect.maxY + depth))
            path.addLine(to: CGPoint(x: rect.minX + center - base, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        if edge == .left {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + center + base))
            path.addLine(to: CGPoint(x: rect.minX - depth, y: rect.minY + center))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + center - base))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
