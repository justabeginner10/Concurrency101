import SwiftUI

struct TrackRoomCards: View {
    let track: LearningTrack
    let noteCount: Int
    let usesPhoneChrome: Bool
    let compactVertical: Bool
    let onOpen: (PathRoom) -> Void

    var body: some View {
        let usesGrid = !usesPhoneChrome
        let layout = usesGrid
            ? AnyLayout(TrackRoomGrid())
            : AnyLayout(VStackLayout(spacing: 16))
        layout {
            ForEach(PathRoom.allCases) { room in
                PathRoomCard(
                    room: room,
                    track: track,
                    noteCount: noteCount,
                    compactVertical: !DemoLayout.isPadLike && compactVertical,
                    fillsAvailableHeight: usesGrid
                ) {
                    onOpen(room)
                }
                .pageGuideTarget(.hub, room.rawValue)
            }
        }
    }
}

/// Two columns on iPad and landscape iPhone. Every cell gets the tallest
/// card's natural height at the available column width, including its text.
struct TrackRoomGrid: Layout {
    private let spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let idealWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth * 2 + spacing
        let cell = cellSize(width: width, subviews: subviews)
        let rows = (subviews.count + 1) / 2
        return CGSize(width: width, height: CGFloat(rows) * cell.height + CGFloat(rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = cellSize(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(index % 2) * (cell.width + spacing),
                    y: bounds.minY + CGFloat(index / 2) * (cell.height + spacing)
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(cell)
            )
        }
    }

    private func cellSize(width: CGFloat, subviews: Subviews) -> CGSize {
        let columnWidth = max(0, (width - spacing) / 2)
        let proposal = ProposedViewSize(width: columnWidth, height: nil)
        let height = subviews.map { $0.sizeThatFits(proposal).height }.max() ?? 0
        return CGSize(width: columnWidth, height: height)
    }
}

private struct PathRoomCard: View {
    let room: PathRoom
    let track: LearningTrack
    let noteCount: Int
    let compactVertical: Bool
    let fillsAvailableHeight: Bool
    let action: () -> Void

    var body: some View {
        ChoiceCard(
            title: room.title,
            blurb: room.blurb(noteCount: noteCount),
            cta: room.cta,
            accent: track.accent,
            ctaOpacity: room.ctaOpacity,
            compactVertical: compactVertical && !fillsAvailableHeight,
            minHeight: compactVertical ? 160 : 240,
            fillsAvailableHeight: fillsAvailableHeight,
            action: action
        ) {
            PathRoomGlyph(room: room, track: track)
        }
    }
}
