import SwiftUI
import Concurrency101Sim

/// The run's output: the trace (log lines on the virtual clock) or the
/// per-thread timeline, ending with the verdict.
struct SandboxOutputPanel: View {
    @Bindable var session: SandboxSession
    let accent: Color
    @Environment(\.pageGuideSession) private var guide
    @State private var tabBeforeGuide: SandboxOutputTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Picker("Output", selection: $session.tab) {
                    ForEach(SandboxOutputTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer(minLength: 8)
                if let run = session.run, run.outcome != .compileFailed {
                    Text(verbatim: "t = \(SandboxFormat.seconds(session.isPlaybackDone ? run.endTime : session.playhead))")
                        .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(DemoTheme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(accent.opacity(0.25))

            output
                .pageGuideTarget(.sandbox, "trace")
                .pageGuideTarget(.sandbox, "threads")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: guide?.activeTargetID) { _, id in
            if let id {
                if tabBeforeGuide == nil { tabBeforeGuide = session.tab }
                if id == PageGuidePage.sandbox.targetID("threads") { session.tab = .threads }
                if id == PageGuidePage.sandbox.targetID("trace") { session.tab = .trace }
            } else if let previous = tabBeforeGuide {
                session.tab = previous
                tabBeforeGuide = nil
            }
        }
        .background(.ultraThinMaterial, in: Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var output: some View {
        switch session.tab {
        case .trace:
            SandboxTraceList(session: session, accent: accent)
        case .threads:
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let run = session.run, run.outcome != .compileFailed {
                        SandboxTimelineView(run: run, playhead: session.isPlaybackDone ? run.endTime : session.playhead, accent: accent)
                    } else {
                        SandboxEmptyState()
                    }
                    if let run = session.run, session.isPlaybackDone {
                        SandboxOutcomeCard(run: run)
                    }
                }
                .padding(12)
            }
            .pageGuideScroll()
        }
    }
}

enum SandboxFormat {
    static func seconds(_ t: Double) -> String {
        String(format: "%.3f s", t)
    }

    static func time(_ t: Double) -> String {
        String(format: "%.3f", t)
    }
}

private struct SandboxEmptyState: View {
    var body: some View {
        Text("Run the code. Lines appear here on a virtual clock, with the thread each one ran on.")
            .font(.system(size: DemoLayout.typeSize(13), design: .serif))
            .foregroundStyle(DemoTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}

private struct SandboxTraceList: View {
    let session: SandboxSession
    let accent: Color
    @AppStorage(DemoSourceType.storageKey) private var sourceFontSize = DemoSourceType.defaultSize

    var body: some View {
        let events = session.visibleEvents
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if session.run == nil || session.run?.outcome == .compileFailed && events.isEmpty {
                        if session.run == nil { SandboxEmptyState() }
                    }
                    ForEach(events) { event in
                        SandboxTraceRow(event: event, fontSize: CGFloat(sourceFontSize))
                            .id(event.id)
                    }
                    if let run = session.run, session.isPlaybackDone {
                        SandboxOutcomeCard(run: run)
                            .padding(.top, events.isEmpty ? 0 : 6)
                            .id("outcome")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .pageGuideScroll()
            .onChange(of: events.count) { _, _ in
                if let last = events.last {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: session.isPlaybackDone) { _, done in
                if done, session.run != nil {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo("outcome", anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct SandboxTraceRow: View {
    let event: SimEvent
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: SandboxFormat.time(event.time))
                .font(.system(size: max(10, fontSize - 1), design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DemoTheme.muted)
            Text(verbatim: event.thread)
                .font(.system(size: max(10, fontSize - 1), weight: .medium, design: .monospaced))
                .foregroundStyle(event.isMainThread ? DemoTheme.phosphor : DemoTheme.cyan)
                .frame(minWidth: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: event.kind == .warning ? "⚠︎ " + event.text : event.text)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(event.kind == .warning ? DemoTheme.syntaxCall : Color.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text(verbatim: event.context + (event.line.map { " · line \($0)" } ?? ""))
                    .font(.system(size: max(9, fontSize - 3), design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The verdict: finished (with notes), deadlock, crash, or a limit.
struct SandboxOutcomeCard: View {
    let run: SimRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                .foregroundStyle(color)
            ForEach(Array(details.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
                    .font(.system(size: DemoLayout.typeSize(13), design: .serif))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(run.notes.enumerated()), id: \.offset) { _, note in
                Text(verbatim: (note.kind == .warning ? "⚠︎ " : "· ") + note.text + (note.line.map { " (line \($0))" } ?? ""))
                    .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                    .foregroundStyle(note.kind == .warning ? DemoTheme.syntaxCall : DemoTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(color.opacity(0.7), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .accessibilityElement(children: .combine)
        .pageGuideTarget(.sandbox, "outcome")
    }

    private var threadCount: Int {
        run.lanes.filter { !$0.segments.isEmpty }.count
    }

    private var title: String {
        switch run.outcome {
        case .finished:
            return "Finished · \(SandboxFormat.seconds(run.endTime)) virtual · \(threadCount) \(threadCount == 1 ? "thread" : "threads")"
        case .deadlock(let stall):
            return stall.headline.hasPrefix("Deadlock") || stall.headline.hasPrefix("Thread-pool") ? "Deadlock" : "Stuck"
        case .crashed(_, let line, let thread):
            return "Crash on \(thread)" + (line.map { ", line \($0)" } ?? "")
        case .stepLimit:
            return "Stopped: too many steps"
        case .timeLimit:
            return "Stopped: virtual time limit"
        case .compileFailed:
            return "Fix the errors in the code first"
        }
    }

    private var details: [String] {
        switch run.outcome {
        case .finished:
            return []
        case .deadlock(let stall):
            // The card title already says "Deadlock" / "Stuck"; keep the rest.
            var headline = stall.headline
            for prefix in ["Deadlock: ", "Stuck: "] where headline.hasPrefix(prefix) {
                headline = String(headline.dropFirst(prefix.count))
                headline = headline.prefix(1).uppercased() + headline.dropFirst()
            }
            var lines = [headline]
            lines += stall.details.map { "· " + $0 }
            if stall.mainThreadFrozen {
                lines.append("In a real app the UI would be frozen here, and Xcode would be the only way out.")
            }
            return lines
        case .crashed(let message, _, _):
            return [message, "In a real app this would crash."]
        case .stepLimit:
            return ["The code ran \(run.steps.formatted()) steps without finishing. Is there a loop that never ends?"]
        case .timeLimit:
            return ["The run reached \(SandboxFormat.seconds(run.endTime)) of virtual time and was cut off."]
        case .compileFailed:
            return run.diagnostics.prefix(4).map { "line \($0.line): \($0.message)" }
        }
    }

    private var color: Color {
        switch run.outcome {
        case .finished: return run.notes.contains { $0.kind == .warning } ? DemoTheme.syntaxCall : DemoTheme.hit
        case .stepLimit, .timeLimit: return DemoTheme.syntaxCall
        case .deadlock, .crashed, .compileFailed: return DemoTheme.freeze
        }
    }
}
