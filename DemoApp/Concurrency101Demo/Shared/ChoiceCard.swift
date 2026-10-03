import SwiftUI

/// Landing doors and path-room cards share one layout: glyph, title, blurb, CTA.
struct ChoiceCard<Glyph: View>: View {
    let title: String
    let blurb: String
    let cta: String
    let accent: Color
    var ctaOpacity: Double = 1
    var compactVertical: Bool = false
    var minHeight: CGFloat
    let action: () -> Void
    @ViewBuilder var glyph: () -> Glyph

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                glyph()
                Text(verbatim: title)
                    .font(.system(size: DemoLayout.typeSize(22), design: .serif))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.leading)
                Text(verbatim: blurb)
                    .font(.system(size: DemoLayout.typeSize(14), design: .serif))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(compactVertical ? 3 : nil)
                    .fixedSize(horizontal: false, vertical: !compactVertical)
                    .multilineTextAlignment(.leading)
                Text(verbatim: cta)
                    .font(.system(size: DemoLayout.typeSize(13), design: .monospaced))
                    .foregroundStyle(DemoTheme.void)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(accent.opacity(ctaOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .padding(20)
            .background(Color.white.opacity(0.04))
            .overlay {
                Rectangle()
                    .strokeBorder(accent.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(cta)
    }
}
