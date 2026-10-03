enum ScenarioLibrary {
    static func scenarios(for track: LearningTrack) -> [DemoScenario] {
        switch track {
        case .gcd: return GCDScenarioLibrary.all
        case .modern: return ModernScenarioLibrary.all
        }
    }
}
