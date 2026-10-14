import SwiftUI

struct PathSectionView: View {
    let track: LearningTrack
    let openedNoteIDs: Set<String>
    let ranLessonIDs: Set<String>
    let onOpenNote: (String) -> Void
    let onOpenLesson: (String) -> Void
    let onOpenDrill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Path")
                .font(.system(size: DemoLayout.typeSize(22), design: .serif))
                .foregroundStyle(track.accent)
            Text("Open the note, run the lessons that show it, then take the quiz. A mark means you have been there.")
                .font(.system(size: DemoLayout.typeSize(15), design: .serif))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(CurriculumPath.steps(for: track)) { step in
                PathStepRow(
                    step: step,
                    track: track,
                    noteOpened: openedNoteIDs.contains(step.noteID),
                    practiceOpened: step.practiceNoteID.map { openedNoteIDs.contains($0) } ?? false,
                    ranLessonIDs: ranLessonIDs,
                    onOpenNote: onOpenNote,
                    onOpenLesson: onOpenLesson
                )
            }

            Button(action: onOpenDrill) {
                Text("Closed-book quiz")
                    .font(.system(size: DemoLayout.typeSize(15), weight: .medium, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(track.accent)
                    .foregroundStyle(DemoTheme.void)
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.top, 4)
        }
    }
}

private struct PathStepRow: View {
    let step: CurriculumPathStep
    let track: LearningTrack
    let noteOpened: Bool
    let practiceOpened: Bool
    let ranLessonIDs: Set<String>
    let onOpenNote: (String) -> Void
    let onOpenLesson: (String) -> Void

    private var lessonsDone: Bool {
        step.lessonIDs.allSatisfy { ranLessonIDs.contains($0) }
    }

    private var practiceDone: Bool {
        step.practiceNoteID == nil || practiceOpened
    }

    private var done: Bool {
        noteOpened && lessonsDone && practiceDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onOpenNote(step.noteID)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: step.indexLabel)
                        .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                        .foregroundStyle(track.accent)
                        .frame(width: 24, alignment: .leading)
                    Text(verbatim: step.title)
                        .font(.system(size: DemoLayout.typeSize(16), design: .serif))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DemoTheme.hit)
                    }
                }
            }
            .buttonStyle(.plain)

            if !step.lessonIDs.isEmpty || step.practiceNoteID != nil {
                FlowChips {
                    ForEach(step.lessonIDs, id: \.self) { id in
                        if let title = CurriculumPath.lessonTitle(id, track: track) {
                            PathChip(
                                title: title,
                                done: ranLessonIDs.contains(id),
                                accent: track.accent
                            ) {
                                onOpenLesson(id)
                            }
                        }
                    }
                    if let practiceID = step.practiceNoteID, let title = step.practiceTitle {
                        PathChip(
                            title: title,
                            done: practiceOpened,
                            accent: track.accent
                        ) {
                            onOpenNote(practiceID)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .overlay {
            Rectangle()
                .strokeBorder(track.accent.opacity(noteOpened ? 0.45 : 0.18), lineWidth: 1)
        }
    }
}

private struct PathChip: View {
    let title: String
    let done: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(verbatim: title)
                    .font(.system(size: DemoLayout.typeSize(12), design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(done ? DemoTheme.void : accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(done ? accent : Color.white.opacity(0.04))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(accent.opacity(done ? 0 : 0.45), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping row of chips. A lazy grid would force equal columns; this follows the text.
private struct FlowChips<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            content()
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(in: width, subviews: subviews)
        let height = rows.reduce(CGFloat(0)) { partial, row in
            partial + (row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0) + spacing
        }
        return CGSize(width: width, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var used: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if used > 0, used + size.width > width {
                rows.append([view])
                used = size.width + spacing
            } else {
                rows[rows.count - 1].append(view)
                used += size.width + spacing
            }
        }
        return rows.filter { !$0.isEmpty }
    }
}
