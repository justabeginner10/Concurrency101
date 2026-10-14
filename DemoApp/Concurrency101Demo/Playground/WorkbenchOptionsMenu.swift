import SwiftUI

struct WorkbenchOptionsMenu: View {
    @Binding var showCheatSheet: Bool
    let accent: Color
    let onOpenSandbox: () -> Void
    @AppStorage(DemoSourceType.storageKey) private var size = DemoSourceType.defaultSize

    var body: some View {
        Menu {
            Button(action: onOpenSandbox) {
                Label("Open in Sandbox", systemImage: "hammer")
            }
            Button {
                showCheatSheet = true
            } label: {
                Label("Cheat sheet", systemImage: "text.book.closed")
            }
            Menu {
                Picker("Font size", selection: $size) {
                    ForEach(DemoSourceType.sizes, id: \.self) { points in
                        Text(verbatim: "\(points) pt").tag(points)
                    }
                }
            } label: {
                Label("Font size", systemImage: "textformat.size")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel("Playground options")
    }
}
