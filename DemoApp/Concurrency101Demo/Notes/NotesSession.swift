import Observation
import Foundation

@MainActor
@Observable
final class NotesSession {
    let track: LearningTrack
    let sections: [CurriculumSection]
    var selectedID: String
    var query: String = "" {
        didSet { visibleSections = Self.filter(sections, matching: query) }
    }
    var sidebarOpen: Bool

    /// Filtered once per `query` change, not on every body pass.
    private(set) var visibleSections: [CurriculumSection]

    private var cache: [String: String] = [:]

    /// Cheap on purpose: SwiftUI rebuilds `@State` initial values on every
    /// view init. The first note loads in `loadSelectedIfNeeded()`.
    init(track: LearningTrack, sidebarOpen: Bool, initialNoteID: String? = nil) {
        let sections = CurriculumCatalog.sections(for: track)
        self.track = track
        self.sections = sections
        let preferred = initialNoteID ?? LearningMemory.lastNoteID(track: track)
        if let preferred, CurriculumCatalog.note(id: preferred, in: track) != nil {
            self.selectedID = preferred
        } else {
            self.selectedID = sections.first?.notes.first?.id ?? ""
        }
        self.sidebarOpen = sidebarOpen
        self.visibleSections = sections
    }

    var allNotes: [CurriculumNote] {
        sections.flatMap(\.notes)
    }

    var selected: CurriculumNote? {
        CurriculumCatalog.note(id: selectedID, in: track)
    }

    var markdown: String {
        cache[selectedID] ?? ""
    }

    var previousID: String? {
        neighbor(offset: -1)
    }

    var nextID: String? {
        neighbor(offset: 1)
    }

    func select(_ id: String, collapseSidebar: Bool) {
        selectedID = id
        loadIfNeeded(id)
        rememberPlace()
        if collapseSidebar {
            sidebarOpen = false
        }
    }

    func rememberPlace() {
        guard let selected else { return }
        LearningMemory.rememberNote(track: track, id: selected.id, title: selected.title)
    }

    func loadSelectedIfNeeded() {
        loadIfNeeded(selectedID)
    }

    func openWikilink(_ url: URL, collapseSidebar: Bool) {
        guard let id = NoteMarkdown.noteID(from: url) else { return }
        query = ""
        select(id, collapseSidebar: collapseSidebar)
    }

    private func neighbor(offset: Int) -> String? {
        let ids = allNotes.map(\.id)
        guard let index = ids.firstIndex(of: selectedID) else { return nil }
        let next = index + offset
        guard ids.indices.contains(next) else { return nil }
        return ids[next]
    }

    private func loadIfNeeded(_ id: String) {
        guard cache[id] == nil, let note = CurriculumCatalog.note(id: id, in: track) else { return }
        cache[id] = Self.prepared(note, track: track)
    }

    private static func filter(_ sections: [CurriculumSection], matching query: String) -> [CurriculumSection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sections }
        return sections.compactMap { section in
            let matches = section.notes.filter { note in
                note.title.localizedCaseInsensitiveContains(trimmed)
                    || note.id.localizedCaseInsensitiveContains(trimmed)
                    || note.indexLabel.localizedCaseInsensitiveContains(trimmed)
            }
            guard !matches.isEmpty else { return nil }
            return CurriculumSection(id: section.id, title: section.title, notes: matches)
        }
    }

    private static func prepared(_ note: CurriculumNote, track: LearningTrack) -> String {
        NoteMarkdown.prepared(CurriculumBundle.loadMarkdown(note), track: track)
    }
}
