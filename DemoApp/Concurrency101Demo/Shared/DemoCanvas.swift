import SwiftUI

/// Full-screen void behind room content. One place so screens do not each
/// reinvent the same `ZStack` + `ignoresSafeArea` stack.
struct DemoCanvas<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            DemoTheme.void.ignoresSafeArea()
            content()
        }
    }
}
