struct DemoScenario: Identifiable {
    let id: String
    let title: String
    let appleAPI: String
    let blurb: String
    let teachingSnippet: String
    let appleSnippet: String
    let isDestructive: Bool
    let run: (DemoLog) -> Void
}
