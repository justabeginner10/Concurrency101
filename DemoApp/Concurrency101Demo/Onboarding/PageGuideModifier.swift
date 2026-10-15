import SwiftUI
import Observation

private struct PageGuideSessionKey: EnvironmentKey {
    static let defaultValue: PageGuideSession? = nil
}

@MainActor
@Observable
private final class PageGuidePresentation {
    var session: PageGuideSession?
    var accent: Color = DemoTheme.phosphor
}

private struct PageGuidePresentationKey: EnvironmentKey {
    static let defaultValue: PageGuidePresentation? = nil
}

extension EnvironmentValues {
    fileprivate var pageGuidePresentation: PageGuidePresentation? {
        get { self[PageGuidePresentationKey.self] }
        set { self[PageGuidePresentationKey.self] = newValue }
    }

    var pageGuideSession: PageGuideSession? {
        get { self[PageGuideSessionKey.self] }
        set { self[PageGuideSessionKey.self] = newValue }
    }
}

extension View {
    func pageGuide(_ page: PageGuidePage, accent: Color = DemoTheme.phosphor) -> some View {
        modifier(PageGuideModifier(page: page, accent: accent))
    }

    /// Mark the real view rather than guessing its position from screen dimensions.
    @ViewBuilder
    func pageGuideTarget(_ page: PageGuidePage, _ step: String, enabled: Bool = true) -> some View {
        if enabled { modifier(PageGuideTargetModifier(id: page.targetID(step))) } else { self }
    }

    func pageGuideHost() -> some View { modifier(PageGuideHostModifier()) }

    func pageGuideScroll() -> some View { modifier(PageGuideScrollModifier()) }
}

private struct PageGuideTargetModifier: ViewModifier {
    let id: String
    @Environment(\.pageGuideSession) private var session

    func body(content: Content) -> some View {
        content
            .id(id)
            .background {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    Color.clear
                        .onAppear { session?.register(id, frame: frame) }
                        .onChange(of: frame) { _, value in session?.register(id, frame: value) }
                        .onDisappear { session?.remove(id) }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

private struct PageGuideScrollModifier: ViewModifier {
    @Environment(\.pageGuideSession) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: session?.activeTargetID) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
        }
    }
}

private struct PageGuideModifier: ViewModifier {
    let page: PageGuidePage
    let accent: Color
    @State private var session: PageGuideSession
    @Environment(\.pageGuidePresentation) private var presentation

    init(page: PageGuidePage, accent: Color) {
        self.page = page
        self.accent = accent
        self._session = State(initialValue: PageGuideSession(page: page))
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                presentation?.session = session
                presentation?.accent = accent
            }
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                session.visit(page)
            }
            .onDisappear {
                session.dismiss()
                if presentation?.session === session { presentation?.session = nil }
            }
            .onChange(of: page) { _, value in session.visit(value) }
            .environment(\.pageGuideSession, session)
    }
}

/// Host above the NavigationStack so toolbar controls can also be spotlighted.
/// Each native supporting sheet has its own host, avoiding stacked guide sheets.
private struct PageGuideHostModifier: ViewModifier {
    @State private var presentation = PageGuidePresentation()

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(presentation.session?.activeTargetID != nil)
            .overlay {
                GeometryReader { geometry in
                    if let session = presentation.session, session.presentedPage != nil,
                       let step = session.currentStep,
                       let frame = session.targets[session.page.targetID(step.id)] {
                        let origin = geometry.frame(in: .global).origin
                        PageGuideView(step: step, target: frame.offsetBy(dx: -origin.x, dy: -origin.y),
                                      viewport: geometry.size, accent: presentation.accent,
                                      current: session.currentIndex + 1, total: session.steps.count,
                                      onSkip: session.dismiss, onBack: session.back, onNext: session.next)
                    }
                }
            }
            .environment(\.pageGuidePresentation, presentation)
    }
}
