import Foundation
import CoreGraphics
import Observation

/// Guide state is independent of learning progress and shared across tracks.
@MainActor
@Observable
final class PageGuideSession {
    private let defaults: UserDefaults
    private(set) var page: PageGuidePage
    private(set) var presentedPage: PageGuidePage?
    private(set) var stepID: String?
    private(set) var targets: [String: CGRect] = [:]

    init(page: PageGuidePage, defaults: UserDefaults = .standard) {
        self.page = page
        self.defaults = defaults
    }

    var steps: [PageGuideStep] {
        PageGuideCatalog.steps(for: page).filter { targets[page.targetID($0.id)] != nil }
    }

    var currentIndex: Int { steps.firstIndex { $0.id == stepID } ?? 0 }
    var currentStep: PageGuideStep? { steps.first { $0.id == stepID } ?? steps.first }
    var activeTargetID: String? {
        guard presentedPage != nil, let currentStep else { return nil }
        return page.targetID(currentStep.id)
    }

    func register(_ id: String, frame: CGRect) {
        guard frame.width > 0, frame.height > 0, targets[id] != frame else { return }
        targets[id] = frame
    }

    func remove(_ id: String) { targets.removeValue(forKey: id) }

    func visit(_ page: PageGuidePage) {
        if self.page != page {
            presentedPage = nil
            stepID = nil
            self.page = page
        }
        showIfNeeded()
    }

    private func showIfNeeded() {
        guard presentedPage == nil, !defaults.bool(forKey: Self.key(for: page)) else { return }
        // A tour is offered once, even if the learner leaves before finishing.
        defaults.set(true, forKey: Self.key(for: page))
        stepID = nil
        presentedPage = page
    }

    func back() {
        guard currentIndex > 0 else { return }
        stepID = steps[currentIndex - 1].id
    }

    func next() {
        let nextIndex = currentIndex + 1
        if nextIndex < steps.count { stepID = steps[nextIndex].id } else { dismiss() }
    }

    func dismiss() {
        presentedPage = nil
        stepID = nil
    }

    private static func key(for page: PageGuidePage) -> String {
        // Show the new spotlight tour even if an earlier sheet guide was dismissed.
        "onboarding.spotlight.v1.\(page.rawValue)"
    }
}

extension PageGuidePage {
    func targetID(_ step: String) -> String { "guide.\(rawValue).\(step)" }
}
