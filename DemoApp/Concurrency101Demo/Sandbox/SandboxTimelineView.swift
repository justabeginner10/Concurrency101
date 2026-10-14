import SwiftUI
import Concurrency101Sim

/// One row per thread that did anything. Solid bars are running work;
/// outlined bars are a thread held but waiting (sync, sleep, semaphore).
/// A waiting bar that runs off the end never came back.
struct SandboxTimelineView: View {
    let run: SimRun
    let playhead: Double
    let accent: Color
    @State private var selection: Selection?

    private struct Selection: Equatable {
        let lane: String
        let segment: SimSegment
    }

    private var lanes: [SimLane] {
        run.lanes.filter { !$0.segments.isEmpty }
    }

    /// Visible span, with room on the right for work that never finished.
    private var span: Double {
        max(run.endTime, 0.001) * 1.08
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: "0 s")
                Spacer()
                Text(verbatim: SandboxFormat.seconds(run.endTime))
            }
            .font(.system(size: DemoLayout.typeSize(10), design: .monospaced))
            .foregroundStyle(DemoTheme.muted)
            .padding(.leading, 56)

            ForEach(lanes) { lane in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: lane.name)
                            .font(.system(size: DemoLayout.typeSize(11), weight: .medium, design: .monospaced))
                            .foregroundStyle(color(for: lane))
                        Text(verbatim: kindLabel(lane))
                            .font(.system(size: DemoLayout.typeSize(9), design: .monospaced))
                            .foregroundStyle(DemoTheme.muted)
                    }
                    .frame(width: 48, alignment: .leading)
                    LaneTrack(lane: lane, span: span, playhead: playhead, color: color(for: lane), selected: selection?.lane == lane.name ? selection?.segment : nil) { segment in
                        selection = segment.map { Selection(lane: lane.name, segment: $0) }
                    }
                    .frame(height: 20)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary(lane))
            }

            if let selection {
                Text(verbatim: describe(selection))
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Tap a bar to see what that thread was doing.")
                    .font(.system(size: DemoLayout.typeSize(11), design: .serif))
                    .foregroundStyle(DemoTheme.muted)
            }

            HStack(spacing: 14) {
                legendSwatch(filled: true, text: "running")
                legendSwatch(filled: false, text: "holding the thread, waiting")
            }
            .font(.system(size: DemoLayout.typeSize(10), design: .monospaced))
            .foregroundStyle(DemoTheme.muted)
        }
    }

    private func legendSwatch(filled: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(filled ? accent : DemoTheme.freeze.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(filled ? Color.clear : DemoTheme.freeze, lineWidth: 1)
                }
                .frame(width: 16, height: 8)
            Text(verbatim: text)
        }
    }

    private func color(for lane: SimLane) -> Color {
        switch lane.kind {
        case .main: return DemoTheme.phosphor
        case .gcd: return DemoTheme.cyan
        case .cooperative: return DemoTheme.syntaxKeyword
        }
    }

    private func kindLabel(_ lane: SimLane) -> String {
        switch lane.kind {
        case .main: return "main"
        case .gcd: return "GCD"
        case .cooperative: return "tasks"
        }
    }

    private func describe(_ s: Selection) -> String {
        let state = s.segment.isBlocked ? "waiting in \(s.segment.label)" : "running \(s.segment.label)"
        let end = s.segment.unfinished ? "never returned" : SandboxFormat.seconds(s.segment.end)
        let line = s.segment.line.map { " · line \($0)" } ?? ""
        return "\(s.lane): \(state) · \(SandboxFormat.seconds(s.segment.start)) → \(end)\(line)"
    }

    private func accessibilitySummary(_ lane: SimLane) -> String {
        let blocked = lane.segments.filter(\.isBlocked).count
        let stuck = lane.segments.contains { $0.isBlocked && $0.unfinished }
        return "\(lane.name), \(lane.segments.count) stretches of work, \(blocked) waiting" + (stuck ? ", blocked forever" : "")
    }
}

private struct LaneTrack: View {
    let lane: SimLane
    let span: Double
    let playhead: Double
    let color: Color
    let selected: SimSegment?
    let onSelect: (SimSegment?) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Canvas { context, size in
                let track = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerRadius: 3)
                context.fill(track, with: .color(Color.white.opacity(0.04)))
                let limit = x(playhead, width)
                for segment in lane.segments {
                    guard let rect = frame(segment, width: width, height: size.height, limit: limit) else { continue }
                    let shape = Path(roundedRect: rect, cornerRadius: 2)
                    let isSelected = selected == segment
                    if segment.isBlocked {
                        context.fill(shape, with: .color(DemoTheme.freeze.opacity(isSelected ? 0.45 : 0.22)))
                        context.stroke(shape, with: .color(DemoTheme.freeze), lineWidth: 1)
                    } else {
                        context.fill(shape, with: .color(color.opacity(isSelected ? 1 : 0.78)))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                let limit = x(playhead, width)
                let hit = lane.segments.last { segment in
                    guard let rect = frame(segment, width: width, height: 20, limit: limit) else { return false }
                    return location.x >= rect.minX - 3 && location.x <= rect.maxX + 3
                }
                onSelect(hit)
            }
        }
    }

    private func x(_ t: Double, _ width: CGFloat) -> CGFloat {
        CGFloat(t / span) * width
    }

    private func frame(_ s: SimSegment, width: CGFloat, height: CGFloat, limit: CGFloat) -> CGRect? {
        let start = x(s.start, width)
        guard start <= limit + 0.5 else { return nil }
        var end = s.unfinished && s.isBlocked ? width : x(s.end, width)
        end = min(end, s.unfinished && s.isBlocked ? width : limit)
        let w = max(end - start, 2)
        return CGRect(x: start, y: 3, width: w, height: height - 6)
    }
}
