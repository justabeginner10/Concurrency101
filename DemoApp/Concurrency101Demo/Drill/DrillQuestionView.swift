import SwiftUI
#if os(iOS)
import UIKit
#endif

struct DrillQuestionView: View {
    @Bindable var session: DrillSession

    var body: some View {
        if let current = session.current {
            VStack(spacing: 0) {
                DrillProgressBar(
                    current: session.index + 1,
                    total: session.deck.count,
                    accent: session.track.accent
                )
                DrillQuestionPage(
                    accent: session.track.accent,
                    stem: current.question.stem,
                    snippet: current.question.snippet,
                    options: current.presentedOptions,
                    correctIndex: current.question.correctIndex,
                    pick: session.currentPick,
                    isFirst: session.isFirst,
                    canGoNext: session.isLocked,
                    sourceNote: current.question.sourceNote,
                    explanation: current.question.explanation,
                    showExplain: $session.showExplain,
                    onPick: session.pick,
                    onPrevious: session.goPrevious,
                    onNext: session.goNext
                )
                .id(current.id)
            }
        }
    }
}

private struct DrillProgressBar: View {
    let current: Int
    let total: Int
    let accent: Color

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                Rectangle()
                    .fill(accent)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.25), value: fraction)
        .accessibilityElement()
        .accessibilityLabel("Drill progress")
        .accessibilityValue("Question \(current) of \(total)")
    }
}

private struct DrillQuestionPage: View {
    let accent: Color
    let stem: String
    let snippet: String?
    let options: [DrillPresentedOption]
    let correctIndex: Int
    let pick: Int?
    let isFirst: Bool
    let canGoNext: Bool
    let sourceNote: String
    let explanation: String
    @Binding var showExplain: Bool
    let onPick: (Int) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    private let marks = ["A", "B", "C", "D"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(verbatim: stem)
                        .font(.system(size: DemoLayout.typeSize(18), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if let snippet = snippet?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !snippet.isEmpty {
                        CodeSnippetView(source: snippet)
                    }

                    VStack(spacing: 8) {
                        ForEach(Array(options.enumerated()), id: \.element.id) { offset, option in
                            DrillOptionRow(
                                mark: marks[offset],
                                text: option.text,
                                isLocked: pick != nil,
                                isPicked: pick == option.originalIndex,
                                isKeyed: option.originalIndex == correctIndex,
                                action: { onPick(option.originalIndex) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            DrillQuestionBar(
                accent: accent,
                explainEnabled: pick != nil,
                previousEnabled: !isFirst,
                nextEnabled: canGoNext,
                sourceNote: sourceNote,
                explanation: explanation,
                showExplain: $showExplain,
                onPrevious: onPrevious,
                onNext: onNext
            )
        }
    }
}

private struct DrillOptionRow: View {
    let mark: String
    let text: String
    let isLocked: Bool
    let isPicked: Bool
    let isKeyed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: mark)
                    .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                    .foregroundStyle(markColor)
                    .frame(width: 18, alignment: .leading)
                Text(verbatim: text)
                    .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                    .foregroundStyle(bodyColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay(
                Rectangle()
                    .strokeBorder(border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLocked)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private var showsHit: Bool {
        isLocked && isKeyed
    }

    private var showsMiss: Bool {
        isPicked && !isKeyed
    }

    private var fill: Color {
        if showsHit { return DemoTheme.hit }
        if showsMiss { return DemoTheme.freeze }
        return Color.white.opacity(0.04)
    }

    private var border: Color {
        if showsHit { return DemoTheme.hit }
        if showsMiss { return DemoTheme.freeze }
        return Color.white.opacity(0.08)
    }

    private var markColor: Color {
        if showsHit || showsMiss { return DemoTheme.void }
        return DemoTheme.muted
    }

    private var bodyColor: Color {
        if showsHit || showsMiss { return DemoTheme.void }
        return Color.white.opacity(0.88)
    }
}

private struct DrillQuestionBar: View {
    let accent: Color
    let explainEnabled: Bool
    let previousEnabled: Bool
    let nextEnabled: Bool
    let sourceNote: String
    let explanation: String
    @Binding var showExplain: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            DrillExplainButton(
                enabled: explainEnabled,
                accent: accent,
                sourceNote: sourceNote,
                explanation: explanation,
                isPresented: $showExplain
            )
            Spacer()
            Button("Previous", action: onPrevious)
                .foregroundStyle(previousEnabled ? accent : DemoTheme.muted)
                .disabled(!previousEnabled)
            Button("Next", action: onNext)
                .foregroundStyle(nextEnabled ? accent : DemoTheme.muted)
                .disabled(!nextEnabled)
        }
        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accent.opacity(0.22))
                .frame(height: 1)
        }
    }
}

private struct DrillExplainButton: View {
    let enabled: Bool
    let accent: Color
    let sourceNote: String
    let explanation: String
    @Binding var isPresented: Bool

    var body: some View {
        Button("Explain") {
            isPresented = true
        }
        .foregroundStyle(enabled ? accent : DemoTheme.muted)
        .disabled(!enabled)
        .modifier(
            DrillExplainPresentation(
                isPresented: $isPresented,
                sourceNote: sourceNote,
                explanation: explanation,
                accent: accent
            )
        )
    }
}

private struct DrillExplainPresentation: ViewModifier {
    @Binding var isPresented: Bool
    let sourceNote: String
    let explanation: String
    let accent: Color

    func body(content: Content) -> some View {
        if DemoLayout.isPadLike {
            content.popover(isPresented: $isPresented) {
                sheet
                    .frame(
                        minWidth: 420,
                        idealWidth: 440,
                        maxWidth: 520,
                        minHeight: 360,
                        idealHeight: 480,
                        maxHeight: 640
                    )
                    .presentationBackground(DemoTheme.void)
                    #if os(iOS)
                    .background {
                        HidePopoverArrow()
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                    #endif
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                sheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(DemoTheme.void)
            }
        }
    }

    private var sheet: some View {
        DrillExplainSheet(
            sourceNote: sourceNote,
            explanation: explanation,
            accent: accent,
            onDismiss: { isPresented = false }
        )
    }
}

private struct DrillExplainSheet: View {
    let sourceNote: String
    let explanation: String
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Explain")
                    .font(.system(size: DemoLayout.typeSize(18), design: .serif))
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                Button("Done", action: onDismiss)
                    .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                    .foregroundStyle(accent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle()
                .fill(accent.opacity(0.22))
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("The rule")
                        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                        .foregroundStyle(accent)
                    Text(verbatim: explanation)
                        .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Source")
                        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                        .foregroundStyle(accent)
                        .padding(.top, 8)
                    Text(verbatim: sourceNote)
                        .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DemoTheme.void.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#if os(iOS)
private struct HidePopoverArrow: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        ArrowHidingView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? ArrowHidingView)?.hideArrow()
    }
}

private final class ArrowHidingView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        hideArrow()
        DispatchQueue.main.async { [weak self] in
            self?.hideArrow()
        }
    }

    func hideArrow() {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                controller.popoverPresentationController?.permittedArrowDirections = []
                controller.parent?.popoverPresentationController?.permittedArrowDirections = []
            }
            responder = current.next
        }
    }
}
#endif

