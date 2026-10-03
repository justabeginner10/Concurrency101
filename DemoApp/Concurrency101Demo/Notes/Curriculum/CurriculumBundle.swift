import Foundation

enum CurriculumBundle {
    static func loadMarkdown(_ note: CurriculumNote) -> String {
        // Xcode's synchronized resource group flattens .md files into the bundle root.
        if let url = Bundle.main.url(forResource: note.fileName, withExtension: "md") {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? missing
        }
        if let url = Bundle.main.url(
            forResource: note.fileName,
            withExtension: "md",
            subdirectory: note.subdirectory
        ) {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? missing
        }
        return missing
    }

    private static let missing = "This note could not be loaded from the app bundle."
}
