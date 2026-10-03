import SwiftUI

/// Phone stacks doors/rooms; landscape iPhone, iPad, and Mac sit them in a row.
struct AdaptiveCardStack<Content: View>: View {
    let usesPhoneChrome: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        let cards = content()
        if usesPhoneChrome {
            VStack(spacing: 16) { cards }
        } else {
            HStack(alignment: .top, spacing: 16) { cards }
        }
    }
}
