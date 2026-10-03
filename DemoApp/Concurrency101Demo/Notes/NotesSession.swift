import Observation

@MainActor
@Observable
final class NotesSession {
    let track: LearningTrack
    let sections: [CurriculumSection]
    var selectedID: String
    var query: String = ""
    var sidebarOpen: Bool

    private var cache: [String: String] = [:]

    init(track: LearningTrack, sidebarOpen: Bool) {
        let sections = CurriculumCatalog.sections(for: track)
        self.track = track
        self.sections = sections
        self.selectedID = sections.first?.notes.first?.id ?? ""
        self.sidebarOpen = sidebarOpen
        if let first = sections.first?.notes.first {
            cache[first.id] = Self.prepared(first, track: track)
        }
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

    var visibleSections: [CurriculumSection] {
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

    var previousID: String? {
        neighbor(offset: -1)
    }

    var nextID: String? {
        neighbor(offset: 1)
    }

    func select(_ id: String, collapseSidebar: Bool) {
        selectedID = id
        loadIfNeeded(id)
        if collapseSidebar {
            sidebarOpen = false
        }
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

    private static func prepared(_ note: CurriculumNote, track: LearningTrack) -> String {
        NoteMarkdown.prepared(CurriculumBundle.loadMarkdown(note), track: track)
    }
}
