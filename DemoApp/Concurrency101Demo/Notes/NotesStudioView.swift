import SwiftUI

struct NotesStudioView: View {
    let track: LearningTrack
    @State private var session: NotesSession
    @Environment(\.usesPhoneChrome) private var usesPhoneChrome
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(track: LearningTrack) {
        self.track = track
        _session = State(initialValue: NotesSession(track: track, sidebarOpen: true))
    }

    private var overlaySidebar: Bool {
        usesPhoneChrome
    }

    var body: some View {
        DemoCanvas {
            if overlaySidebar {
                CompactNotesLayout(session: session, accent: track.accent)
            } else {
                RegularNotesLayout(
                    session: session,
                    accent: track.accent,
                    sidebarWidth: DemoLayout.sidebarWidth(verticalSizeClass: verticalSizeClass)
                )
            }
        }
        .navigationTitle(session.selected.map(\.title) ?? "Notes")
        .demoRoomChrome()
        #if os(iOS)
        .toolbar {
            if overlaySidebar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(NotesDrawer.animation) {
                            session.sidebarOpen.toggle()
                        }
                    } label: {
                        Image(systemName: session.sidebarOpen ? "xmark" : "sidebar.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(track.accent)
                            .frame(width: 28, height: 28)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(session.sidebarOpen ? "Close notes index" : "Open notes index")
                }
            }
        }
        #endif
    }
}

private struct RegularNotesLayout: View {
    @Bindable var session: NotesSession
    let accent: Color
    let sidebarWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            NotesSidebar(
                sections: session.visibleSections,
                selectedID: session.selectedID,
                query: $session.query,
                accent: accent,
                onSelect: { session.select($0, collapseSidebar: false) }
            )
            .frame(width: sidebarWidth)

            Rectangle()
                .fill(accent.opacity(0.22))
                .frame(width: 1)

            NoteReaderPane(session: session, accent: accent, collapseOnLink: false)
        }
    }
}

private enum NotesDrawer {
    static let width: CGFloat = 320
    static let animation: Animation = .easeInOut(duration: 0.22)
}

private struct CompactNotesLayout: View {
    @Bindable var session: NotesSession
    let accent: Color

    var body: some View {
        ZStack(alignment: .trailing) {
            NoteReaderPane(session: session, accent: accent, collapseOnLink: true)

            NotesDrawerScrim(isOpen: session.sidebarOpen) {
                withAnimation(NotesDrawer.animation) {
                    session.sidebarOpen = false
                }
            }

            NotesSidebar(
                sections: session.visibleSections,
                selectedID: session.selectedID,
                query: $session.query,
                accent: accent,
                onSelect: { id in
                    session.select(id, collapseSidebar: false)
                    withAnimation(NotesDrawer.animation) {
                        session.sidebarOpen = false
                    }
                }
            )
            .frame(width: NotesDrawer.width)
            .frame(maxHeight: .infinity)
            .background(DemoTheme.void)
            .offset(x: session.sidebarOpen ? 0 : NotesDrawer.width)
            .allowsHitTesting(session.sidebarOpen)
            .accessibilityHidden(!session.sidebarOpen)
        }
        .animation(NotesDrawer.animation, value: session.sidebarOpen)
    }
}

private struct NotesDrawerScrim: View {
    let isOpen: Bool
    let onDismiss: () -> Void

    var body: some View {
        Color.black
            .opacity(isOpen ? 0.46 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(isOpen)
            .onTapGesture(perform: onDismiss)
            .accessibilityLabel("Dismiss notes index")
            .accessibilityHidden(!isOpen)
    }
}

private struct NotesSidebar: View {
    let sections: [CurriculumSection]
    let selectedID: String
    @Binding var query: String
    let accent: Color
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NotesSidebarHeader(query: $query, accent: accent)

            if sections.isEmpty {
                Text("No notes match that search.")
                    .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                    .foregroundStyle(DemoTheme.muted)
                    .padding(16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(sections) { section in
                            NotesSidebarSection(
                                title: section.title,
                                notes: section.notes,
                                selectedID: selectedID,
                                accent: accent,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color.white.opacity(0.03))
    }
}

private struct NotesSidebarHeader: View {
    @Binding var query: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: DemoLayout.typeSize(22), design: .serif))
                .foregroundStyle(accent)
            HStack(spacing: 8) {
                Text("Find")
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .foregroundStyle(DemoTheme.muted)
                TextField(
                    "Search notes",
                    text: $query,
                    prompt: Text("Search notes").foregroundStyle(DemoTheme.muted)
                )
                    .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .overlay(
                Rectangle()
                    .strokeBorder(accent.opacity(0.28), lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct NotesSidebarSection: View {
    let title: String
    let notes: [CurriculumNote]
    let selectedID: String
    let accent: Color
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title.uppercased())
                .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                .foregroundStyle(DemoTheme.muted)
                .padding(.horizontal, 8)

            ForEach(notes) { note in
                NotesSidebarRow(
                    indexLabel: note.indexLabel,
                    title: note.title,
                    isSelected: note.id == selectedID,
                    accent: accent
                ) {
                    onSelect(note.id)
                }
            }
        }
    }
}

private struct NotesSidebarRow: View {
    let indexLabel: String
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: indexLabel)
                    .font(.system(size: DemoLayout.typeSize(11), design: .monospaced))
                    .foregroundStyle(isSelected ? DemoTheme.void : accent)
                    .frame(width: 22, alignment: .leading)
                Text(verbatim: title)
                    .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                    .foregroundStyle(isSelected ? DemoTheme.void : Color.white.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? accent : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct NoteReaderPane: View {
    let session: NotesSession
    let accent: Color
    let collapseOnLink: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected = session.selected {
                NoteReaderHeader(
                    indexLabel: selected.indexLabel,
                    title: selected.title,
                    accent: accent
                )
            }

            ScrollView {
                NoteArticleView(
                    markdown: session.markdown,
                    accent: accent
                ) { url in
                    session.openWikilink(url, collapseSidebar: collapseOnLink)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)

                NotePagerBar(
                    hasPrevious: session.previousID != nil,
                    hasNext: session.nextID != nil,
                    accent: accent,
                    onPrevious: {
                        if let id = session.previousID {
                            session.select(id, collapseSidebar: false)
                        }
                    },
                    onNext: {
                        if let id = session.nextID {
                            session.select(id, collapseSidebar: false)
                        }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .id(session.selectedID)
        }
    }
}

private struct NoteReaderHeader: View {
    let indexLabel: String
    let title: String
    let accent: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: indexLabel)
                .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                .foregroundStyle(accent)
            Text(verbatim: title)
                .font(.system(size: DemoLayout.typeSize(22), design: .serif))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct NotePagerBar: View {
    let hasPrevious: Bool
    let hasNext: Bool
    let accent: Color
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button("Previous", action: onPrevious)
                .foregroundStyle(hasPrevious ? accent : DemoTheme.muted)
                .disabled(!hasPrevious)
            Spacer()
            Button("Next", action: onNext)
                .foregroundStyle(hasNext ? accent : DemoTheme.muted)
                .disabled(!hasNext)
        }
        .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
        .buttonStyle(.plain)
    }
}
